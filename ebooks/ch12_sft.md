# 第 12 章：监督微调（SFT）

> **本章目标**：逐行解析 SFT 的完整训练流程——从数据准备到训练循环到 checkpoint 保存。理解每一步的设计决策，掌握如何在实际环境中运行和调试 SFT。

## 12.0 本章路线图

上一章介绍了 Chat 格式和 Loss Mask 的基础设施。本章将这些组件组装成一个完整的训练系统。

```
本章覆盖的完整链路

prepare_sft_data.py                    train_sft.py
┌──────────────────────┐              ┌────────────────────────────┐
│ Alpaca + Dolly + GSM8K│             │ 1. 加载配置                 │
│   ↓ encode_chat       │             │ 2. 初始化 DDP               │
│   ↓ pack_examples     │             │ 3. 加载预训练 backbone       │
│   ↓ write_packed      │             │ 4. 构建优化器               │
│ → sft_packed.h5       │ ──────────▶ │ 5. 训练循环                 │
│ → sft_dev_packed.h5   │             │ 6. 评估 + 保存              │
└──────────────────────┘              └────────────────────────────┘
```

第 11 章已经解释了 `encode_chat` 和 `sft_loss` 的内部原理。本章聚焦于**端到端的训练流程**——数据如何流入、梯度如何更新、checkpoint 如何保存。

## 12.1 SFT 的数据来源

### 12.1.1 三个数据集的定位

| 数据集 | 来源 | 规模 | 角色 |
|--------|------|------|------|
| Alpaca | Stanford (GPT-4 生成) | ~52k 条 | 通用指令跟随 |
| Dolly-15k | Databricks (人工标注) | ~15k 条 | 通用指令跟随（高质量） |
| GSM8K | OpenAI | ~7.5k 条（train） | 数学推理 + CoT 格式 |

**为什么选择这三个？**

- **Alpaca**：覆盖面广，52k 条涵盖写作、编程、问答等多种任务类型
- **Dolly-15k**：人工标注质量高，弥补 Alpaca 中 GPT 生成数据的噪声
- **GSM8K**：教会模型 `<think>...<answer>` 格式，为后续 RLVR/GRPO 做准备

### 12.1.2 Alpaca 数据格式

```json
{
  "instruction": "Translate the following English sentence to French.",
  "input": "Hello, how are you?",
  "output": "Bonjour, comment allez-vous ?"
}
```

转换为 chat 消息：

```python
# scripts/prepare_sft_data.py

def alpaca_to_messages(ex):
    instr = ex["instruction"].strip()
    inp = (ex.get("input") or "").strip()
    user = f"{instr}\n\n{inp}" if inp else instr
    return [
        {"role": "user", "content": user},
        {"role": "assistant", "content": ex["output"].strip()}
    ]
```

注意 `input` 字段是可选的——有些指令不需要额外输入（如 "Write a haiku about cats"）。

### 12.1.3 Dolly-15k 数据格式

```json
{
  "instruction": "What is the boiling point of water?",
  "context": "",
  "response": "Water boils at 100°C (212°F) at standard atmospheric pressure.",
  "category": "open_qa"
}
```

Dolly 的 `context` 字段类似于 Alpaca 的 `input`，但还可能包含需要回答问题的上下文信息。

### 12.1.4 GSM8K 的特殊处理

GSM8K 是数学题，需要转换为 `<think>...<answer>` 格式：

```
原始数据：
  question: "Janet has 10 snowballs. She gives 3 to her friend..."
  answer:   "Janet started with 10... <<10-3=7>> ...\n#### 7"

转换后：
  user:      "Janet has 10 snowballs..."
  assistant: "<think>Janet started with 10...</think><answer>7</answer>"
```

```python
def gsm8k_to_messages(question, answer):
    # 1. 移除 <<>> 计算器标注（噪声）
    answer = re.sub(r"<<[^>]*>>", "", answer).strip()
    # 2. 提取 #### 后的最终答案
    m = re.search(r"####\s*(.+)\s*$", answer)
    final = m.group(1).strip() if m else answer
    # 3. 推理过程（去掉 #### 部分）
    reasoning = re.sub(r"####\s*.+\s*$", "", answer).strip()
    # 4. 组装为 CoT 格式
    completion = f"<think>{reasoning}</think><answer>{final}</answer>"
    return [
        {"role": "user", "content": question.strip()},
        {"role": "assistant", "content": completion}
    ]
```

**为什么移除 `<<>>` 计算器标注？**

原始 GSM8K 的答案中包含 `<<10-3=7>>` 这样的计算器注解。这些是数据收集过程中的辅助标记，对模型学习推理没有价值，反而可能让模型学到输出计算过程。

### 12.1.5 数据过滤

```python
def add(messages):
    ids, mask = encode_chat(messages)
    if len(ids) <= context_length and sum(mask) > 0:
        examples.append((ids, mask))
        n_kept += 1
    else:
        n_skipped += 1
```

两个过滤条件：

1. **`len(ids) <= context_length`**：超长对话直接丢弃。为什么不截断？因为截断可能切在 assistant 的回复中间，导致 loss mask 不完整——模型看到了"半个回答"却不需要预测它。
2. **`sum(mask) > 0`**：确保有至少一个需要训练的 token。极端情况下（如空回复），mask 全为 0，这条数据没有训练价值。

### 12.1.6 数据混合比例

三个数据集直接拼接，没有做加权采样：

```
Alpaca:  ~52k 条  →  占比约 70%
Dolly:   ~15k 条  →  占比约 20%
GSM8K:   ~7.5k 条 →  占比约 10%
```

这意味着每个 epoch 中，模型看到通用指令的次数远多于数学题。这是一种有意的设计——通用指令跟随是 SFT 的主要目标，数学推理是附加能力。

## 12.2 数据准备：prepare_sft_data.py 逐行解析

### 12.2.1 完整流程

```python
# scripts/prepare_sft_data.py

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--context_length", type=int, default=1024)
    p.add_argument("--out_dir", default="/ephemeral/data")
    p.add_argument("--dev_frac", type=float, default=0.02)
    p.add_argument("--limit_per_set", type=int, default=None)
    p.add_argument("--seed", type=int, default=42)
    args = p.parse_args()

    # 1. 收集所有数据
    examples = collect_examples(args.context_length, args.limit_per_set)

    # 2. 打乱
    rng = np.random.default_rng(args.seed)
    rng.shuffle(examples)

    # 3. 拆分 train/dev
    n_dev = max(1, int(len(examples) * args.dev_frac))
    dev, train = examples[:n_dev], examples[n_dev:]

    # 4. 打包并写入 HDF5
    write_packed(train, args.context_length, os.path.join(args.out_dir, "sft_packed.h5"))
    write_packed(dev, args.context_length, os.path.join(args.out_dir, "sft_dev_packed.h5"))
```

### 12.2.2 命令行参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--context_length` | 1024 | 打包行的长度（必须和模型一致） |
| `--out_dir` | /ephemeral/data | 输出目录 |
| `--dev_frac` | 0.02 | 验证集比例（2%） |
| `--limit_per_set` | None | 每个数据集最多取多少条（调试用） |
| `--seed` | 42 | 随机种子 |

### 12.2.3 打包过程回顾

```python
def write_packed(examples, context_length, out_path):
    tokens, masks = pack_examples(examples, context_length)
    with h5py.File(out_path, "w") as f:
        f.create_dataset("tokens", data=tokens)      # int32, (N, context_length)
        f.create_dataset("loss_mask", data=masks)     # int8,  (N, context_length)
```

**输出文件**：

```
/ephemeral/data/
├── sft_packed.h5       # 训练集（~74k 条 → 若干 packed rows）
└── sft_dev_packed.h5   # 验证集（2% 的 packed rows）
```

### 12.2.4 实际运行

```bash
# 正式运行（全量数据）
PYTHONPATH=. HF_HOME=/ephemeral/hf_cache python scripts/prepare_sft_data.py \
    --context_length 256 --out_dir /ephemeral/data

# 快速测试（每个数据集只取 100 条）
PYTHONPATH=. HF_HOME=/ephemeral/hf_cache python scripts/prepare_sft_data.py \
    --context_length 256 --limit_per_set 100
```

## 12.3 训练脚本：train_sft.py 逐行解析

### 12.3.1 阶段 1：配置加载

```python
cfg, _ = parse_config_with_json(SFTConfig, "configs/sft.json")
```

解析后的配置（以 `configs/base.json` + `configs/sft.json` 为例）：

```json
{
  // 来自 base.json
  "vocab_size": 50304,
  "context_length": 256,
  "n_embed": 256,
  "n_head": 4,
  "n_blocks": 6,
  "device": "cuda",
  "amp_dtype": "bf16",

  // 来自 sft.json
  "pretrained_ckpt": "/ephemeral/ckpts/base_pretrained.pt",
  "data_path": "/ephemeral/data/sft_packed.h5",
  "out_ckpt": "/ephemeral/ckpts/sft.pt",
  "batch_size": 16,
  "grad_accum": 2,
  "epochs": 3,
  "lr": 1e-5,
  "warmup_steps": 100
}
```

### 12.3.2 阶段 2：DDP 初始化

```python
ctx = ddp_setup(cfg.device)
set_seed(cfg.seed + ctx.rank)
```

- `ddp_setup` 返回 `DDPContext`（包含 `rank`, `world_size`, `device`, `is_main`）
- **种子偏移**：`seed + rank`，确保每个 GPU 的 dropout 等随机操作不同
- 单 GPU 时 `rank=0, world_size=1`，DDP 透明

### 12.3.3 阶段 3：加载预训练 backbone

```python
model = load_backbone_from_ckpt(cfg, cfg.pretrained_ckpt, ctx.device)
if cfg.compile:
    model = torch.compile(model)
model = ddp_wrap(model, ctx)
```

加载过程：

```
base_pretrained.pt
    │
    ├── torch.load → checkpoint dict
    │     ├── "model_state_dict": {...}   ← 取这个
    │     ├── "optimizer_state_dict": ...  ← 不用
    │     ├── "stage": "pretrain"
    │     └── ...
    │
    ├── _strip_ddp_prefix()              ← 清理 module. / _orig_mod. 前缀
    │
    ├── build_model_from_config(cfg)      ← 从 config 构建新模型
    │
    └── model.load_state_dict(filtered, strict=False)
          ├── backbone keys 匹配 → 加载
          └── head keys 不匹配 → 忽略（strict=False）
```

**为什么 `strict=False`？** 预训练 checkpoint 可能包含额外的 key（如 `torch.compile` 的前缀），或者缺少某些 key（如果模型架构有微小变化）。`strict=False` + 过滤 `backbone_keys` 确保只加载匹配的权重。

### 12.3.4 阶段 4：构建优化器

```python
optimizer = configure_optimizer(unwrap(model), cfg.lr, cfg.weight_decay)
```

`configure_optimizer` 的实现（第 7 章已介绍）：

```python
# src/post_training/optim.py

def configure_optimizer(model, lr, weight_decay, betas=(0.9, 0.95)):
    decay, no_decay = [], []
    for name, p in model.named_parameters():
        if not p.requires_grad:
            continue
        if p.dim() >= 2:      # 权重矩阵：加 weight_decay
            decay.append(p)
        else:                  # bias / LayerNorm / embedding：不加
            no_decay.append(p)
    groups = [
        {"params": decay, "weight_decay": weight_decay},
        {"params": no_decay, "weight_decay": 0.0},
    ]
    return torch.optim.AdamW(groups, lr=lr, betas=betas)
```

**SFT 的优化器特点**：

| 参数 | SFT | 预训练 | 说明 |
|------|-----|--------|------|
| lr | 1e-5 | 3e-4 | SFT 学习率小 30 倍（微调要保守） |
| weight_decay | 0.0 | 0.1 | SFT 不用 weight decay（数据少，不需要正则化） |
| betas | (0.9, 0.95) | (0.9, 0.95) | 相同 |

### 12.3.5 阶段 5：估算总步数

```python
import h5py
with h5py.File(cfg.data_path, "r") as f:
    n_rows = f["tokens"].shape[0]
steps_per_epoch = max(1, n_rows // (cfg.batch_size * ctx.world_size))
total_steps = cfg.max_steps if cfg.max_steps > 0 else steps_per_epoch * cfg.epochs
```

**为什么需要估算步数？**

`cosine_lr` 学习率调度需要知道 `max_steps` 来计算衰减曲线。预训练的步数是固定的（`train_steps=200_000`），但 SFT 的步数由数据量决定：

```
n_rows = 1000（packed rows）
batch_size = 16
world_size = 2

steps_per_epoch = 1000 // (16 × 2) = 31
total_steps = 31 × 3 = 93（3 个 epoch）
```

**`max_steps` 覆盖**：如果 `cfg.max_steps > 0`，忽略 epochs，按固定步数训练。用于快速实验。

### 12.3.6 阶段 6：训练循环

```python
model.train()
t0 = time.perf_counter()
for step in range(total_steps):
    # 1. 设置学习率
    lr = cosine_lr(step, warmup_steps=cfg.warmup_steps,
                   max_steps=total_steps, lr=cfg.lr, min_lr=cfg.min_lr)
    for g in optimizer.param_groups:
        g["lr"] = lr

    # 2. 取一个 batch
    tokens, mask, epoch = next(train_it)
    if epoch >= cfg.epochs and cfg.max_steps <= 0:
        break

    # 3. 前向传播
    optimizer.zero_grad(set_to_none=True)
    with amp_autocast(cfg.amp_dtype, ctx.device):
        logits, _ = model(tokens)         # (B, T, V)
        loss = sft_loss(logits, tokens, mask)

    # 4. 反向传播 + 梯度裁剪 + 更新
    loss.backward()
    torch.nn.utils.clip_grad_norm_(model.parameters(), cfg.grad_clip)
    optimizer.step()
```

### 12.3.7 训练循环与预训练的差异

| | 预训练 | SFT |
|---|---|---|
| 梯度累积 | `loss / grad_accum`，多步累积 | 无累积，每步直接更新 |
| 数据来源 | `PretrainDataLoader`（分片 + 随机偏移） | `get_sft_batch_iterator`（shuffle + DDP 分片） |
| Loss 函数 | 标准 CE | Masked CE |
| `no_sync()` | DDP 累积步跳过梯度同步 | 不需要（无累积） |
| 步数控制 | 固定 `train_steps` | 数据驱动（epochs × steps_per_epoch） |

**为什么 SFT 不用梯度累积？**

预训练用梯度累积是因为 batch_size 受显存限制（如 batch_size=24 × grad_accum=8 = 有效 192）。SFT 的 batch_size=16 已经足够大（指令数据的梯度方差小于随机文本），且 SFT 的数据量小、总步数少，每步更新不会导致训练不稳定。

### 12.3.8 日志输出

```python
if ctx.is_main and step % 20 == 0:
    dt = time.perf_counter() - t0; t0 = time.perf_counter()
    print(f"step {step}/{total_steps} | loss {loss.item():.4f} "
          f"| ppl {math.exp(min(20, loss.item())):.2f} "
          f"| lr {lr:.2e} | {dt:.1f}s/20")
```

输出示例：

```
step 0/93   | loss 5.2341 | ppl 187.56 | lr 1.00e-07 | 3.2s/20
step 20/93  | loss 3.8765 | ppl 48.26  | lr 1.00e-05 | 2.1s/20
step 40/93  | loss 3.2156 | ppl 24.92  | lr 8.53e-06 | 2.0s/20
step 60/93  | loss 3.0234 | ppl 20.56  | lr 5.67e-06 | 2.0s/20
step 80/93  | loss 2.9876 | ppl 19.83  | lr 2.13e-06 | 1.9s/20
```

**perplexity 的 clamp**：`math.exp(min(20, loss.item()))` 防止 loss 过大时 `exp()` 溢出。当 loss > 20 时，ppl 显示为 `exp(20) ≈ 4.85e8`。

### 12.3.9 评估

```python
if step > 0 and step % cfg.eval_steps == 0:
    dev = reduce_scalar(eval_dev(model, cfg, ctx, DEV_PATH), ctx)
    if ctx.is_main:
        print(f"  [eval] step {step} | dev_loss {dev:.4f} | dev_ppl {math.exp(min(20, dev)):.2f}")
```

`eval_dev` 的实现：

```python
@torch.no_grad()
def eval_dev(model, cfg, ctx, dev_path, max_batches=50):
    model.eval()
    it = get_sft_batch_iterator(
        dev_path, cfg.batch_size, device=ctx.device,
        rank=ctx.rank, world_size=ctx.world_size,
        shuffle=False, infinite=False    # 只遍历一次
    )
    total, n = 0.0, 0
    for tokens, mask, _ in it:
        with amp_autocast(cfg.amp_dtype, ctx.device):
            logits, _ = model(tokens)
            loss = sft_loss(logits, tokens, mask)
        total += loss.item(); n += 1
        if n >= max_batches:
            break
    model.train()
    return total / max(1, n)
```

**关键设计**：

- `shuffle=False, infinite=False`：按顺序遍历验证集一次
- `reduce_scalar`：DDP 下对所有 rank 的 dev loss 取平均
- `model.eval()` → `model.train()`：切换模式影响 dropout 和 BatchNorm（虽然本项目不用 BN）

### 12.3.10 最终评估的陷阱

```python
if ctx.is_main:
    # ⚠️ 用 unwrap(model) 而不是 model！
    dev = eval_dev(unwrap(model), cfg, ctx, DEV_PATH)
    save_stage_ckpt(cfg.out_ckpt, model, optimizer, ...)
```

**为什么最终评估用 `unwrap(model)`？**

训练循环结束后，其他 rank 的进程已经调用了 `cleanup(ctx)` 退出了 DDP 进程组。如果此时在 main rank 上调用 DDP 包装的模型，NCCL 会尝试发起集合通信，但没有其他 rank 响应——**导致 NCCL 超时挂死**。

`unwrap(model)` 取出了底层的裸模型，绕过了 DDP，所以不需要跨 rank 通信。

而训练期间的周期性评估不需要 unwrap，因为那时所有 rank 都还在运行。

## 12.4 学习率调度

### 12.4.1 Cosine with Warmup

```python
# src/post_training/optim.py

def cosine_lr(step, *, warmup_steps, max_steps, lr, min_lr):
    if step < warmup_steps:
        # 线性预热
        return lr * (step + 1) / max(1, warmup_steps)
    if step >= max_steps:
        # 训练结束：保持最小学习率
        return min_lr
    # 余弦衰减
    progress = (step - warmup_steps) / max(1, max_steps - warmup_steps)
    coeff = 0.5 * (1.0 + math.cos(math.pi * progress))
    return min_lr + coeff * (lr - min_lr)
```

### 12.4.2 SFT 的学习率曲线

```
lr
│
1e-5 ┤           ╭────╮
│          ╱        ╲
│        ╱            ╲
│      ╱                ╲
│    ╱                    ╲
1e-6 ┤──╱                      ╲────────
│
└──┬──┬──┬──┬──┬──┬──┬──┬──┬──▶ step
   0  10 20 30 40 50 60 70 80 93
      ↑warmup    cosine decay
```

SFT 的参数：

| 参数 | 值 | 说明 |
|------|------|------|
| warmup_steps | 100 | 前 100 步线性升温 |
| lr | 1e-5 | 峰值学习率 |
| min_lr | 1e-6 | 衰减后的最低学习率 |
| max_steps | ~93 | 由数据量 × epochs 决定 |

**注意**：当 `max_steps < warmup_steps` 时，学习率可能永远到不了峰值。这是小数据集 SFT 的常见问题——解决办法是减少 `warmup_steps`。

## 12.5 Checkpoint 保存

### 12.5.1 保存格式

```python
# src/post_training/utils.py

def save_stage_ckpt(path, model, optimizer, *, stage, cfg, step, metrics=None):
    payload = {
        "model_state_dict": unwrap(model).state_dict(),
        "optimizer_state_dict": optimizer.state_dict() if optimizer else None,
        "stage": stage,           # "sft"
        "cfg": asdict(cfg),       # 完整配置（用于复现）
        "step": step,
        "metrics": metrics or {},
        "pytorch_version": torch.__version__,
        "cuda_version": torch.version.cuda,
    }
    torch.save(payload, path)
```

### 12.5.2 Checkpoint 结构

```python
# SFT checkpoint 内容
{
    "model_state_dict": {
        "tok_emb.weight":       Tensor(50304, 256),
        "pos_emb":              Tensor(256, 256),
        "blocks.0.attn.q_proj": Tensor(256, 256),
        ...
    },
    "optimizer_state_dict": {
        "state": {...},
        "param_groups": [
            {"lr": 1e-5, "weight_decay": 0.0, "betas": (0.9, 0.95), ...},
            {"lr": 1e-5, "weight_decay": 0.0, ...}
        ]
    },
    "stage": "sft",
    "cfg": {"vocab_size": 50304, "context_length": 256, ...},
    "step": 93,
    "metrics": {"dev_loss": 2.8765},
    "pytorch_version": "2.6.0+cu121",
    "cuda_version": "12.1"
}
```

### 12.5.3 Checkpoint 的下游消费者

```
sft.pt
    │
    ├──▶ Reward Model（加载 backbone，加 reward_head）
    │
    ├──▶ DPO（加载为 policy + frozen reference）
    │
    ├──▶ PPO（加载为 actor，加 value_head）
    │
    ├──▶ GRPO（加载为 policy + frozen reference）
    │
    └──▶ inference.py（直接加载用于推理/评估）
```

所有下游阶段都通过 `load_backbone_from_ckpt` 加载，只取 `model_state_dict` 中的 backbone keys。

### 12.5.4 周期性保存 vs 最终保存

```python
# 周期性保存（训练中）
if ctx.is_main and step > 0 and step % cfg.save_every == 0:
    save_stage_ckpt(cfg.out_ckpt, model, optimizer,
                    stage="sft", cfg=cfg, step=step,
                    metrics={"train_loss": loss.item()})

# 最终保存（训练后）
if ctx.is_main:
    dev = eval_dev(unwrap(model), cfg, ctx, DEV_PATH)
    save_stage_ckpt(cfg.out_ckpt, model, optimizer,
                    stage="sft", cfg=cfg, step=total_steps,
                    metrics={"dev_loss": dev})
```

两者都写到同一个路径 `cfg.out_ckpt`（`/ephemeral/ckpts/sft.pt`），后保存的覆盖前一个。这意味着：

- 如果训练中断，重启后可以从最近的周期性 checkpoint 恢复
- 最终 checkpoint 包含了 dev_loss，方便后续选择最佳模型

## 12.6 context_length 对齐：三方一致

### 12.6.1 一致性要求

```
┌──────────────────────┐    ┌──────────────────────┐    ┌──────────────────────┐
│ prepare_sft_data.py  │    │  configs/base.json    │    │  base_pretrained.pt  │
│ --context_length 256 │    │  context_length: 256  │    │  pos_emb shape (256) │
└──────────────────────┘    └──────────────────────┘    └──────────────────────┘
        ↓ 必须一致                  ↓ 必须一致                  ↓ 必须一致
        └───────────────────────────┴───────────────────────────┘
```

### 12.6.2 不匹配的实际后果

| 不匹配场景 | 后果 | 修复方法 |
|-----------|------|---------|
| 数据 1024 > 模型 256 | `IndexError`：位置编码越界 | `--context_length 256` |
| 数据 256 < 模型 1024 | 不报错，但浪费上下文窗口 | 增大数据 `--context_length` |
| 模型 A (256) 的 ckpt → 模型 B (1024) | position embedding shape 不匹配 | 确保架构一致 |
| 数据 256 + 模型 256，但 ckpt 是 1024 | `load_state_dict` shape mismatch | 重新预训练或调整模型 |

### 12.6.3 验证一致性的方法

```bash
# 1. 检查配置中的 context_length
PYTHONPATH=. python scripts/train_sft.py --print-config | grep context_length
# 输出: "context_length": 256

# 2. 检查数据的实际长度
python3 -c "
import h5py
f = h5py.File('/ephemeral/data/sft_packed.h5', 'r')
print('tokens shape:', f['tokens'].shape)
print('mask shape:', f['loss_mask'].shape)
"
# 输出: tokens shape: (1234, 256)

# 3. 检查 checkpoint 的 position embedding
python3 -c "
import torch
ck = torch.load('/ephemeral/ckpts/base_pretrained.pt', weights_only=False)
pos = ck['model_state_dict']['pos_emb']
print('pos_emb shape:', pos.shape)
"
# 输出: pos_emb shape: torch.Size([256, 256])
```

## 12.7 完整运行指南

### 12.7.1 准备数据

```bash
# 确保环境变量
export HF_HOME=/ephemeral/hf_cache
export PYTHONPATH=.

# 准备数据（context_length 必须和 base.json 一致）
python scripts/prepare_sft_data.py --context_length 256 --out_dir /ephemeral/data
```

预期输出：

```
Loading tatsu-lab/alpaca ...
Loading databricks/databricks-dolly-15k ...
Loading openai/gsm8k (main/train) ...
Collected 72456 examples (skipped 1234 that exceeded context_length).
  wrote 2834 packed rows x 256 -> /ephemeral/data/sft_packed.h5
  wrote 56 packed rows x 256 -> /ephemeral/data/sft_dev_packed.h5
```

### 12.7.2 单 GPU 训练

```bash
# 单 GPU（使用 configs/base.json + configs/sft.json）
PYTHONPATH=. python scripts/train_sft.py
```

### 12.7.3 多 GPU 训练（DDP）

```bash
# 双 GPU（torchrun 自动设置环境变量）
PYTHONPATH=. torchrun --standalone --nproc_per_node=2 scripts/train_sft.py
```

### 12.7.4 Smoke 测试（快速验证）

```bash
# 用 smoke 配置（小模型 + CPU，几秒钟完成）
PYTHONPATH=. python scripts/train_sft.py --config configs/smoke/sft.json
```

`configs/smoke/` 目录提供了：

```json
// configs/smoke/base.json
{
  "vocab_size": 50304,
  "context_length": 256,
  "n_embed": 128,
  "n_head": 4,
  "n_blocks": 2,
  "device": "cpu",
  "amp_dtype": null
}
```

### 12.7.5 自定义参数

```bash
# 调整学习率和 batch size
PYTHONPATH=. python scripts/train_sft.py --lr 2e-5 --batch_size 8

# 只训练 100 步（快速实验）
PYTHONPATH=. python scripts/train_sft.py --max_steps 100

# 禁用 bf16（CPU 或不支持 bf16 的 GPU）
PYTHONPATH=. python scripts/train_sft.py --amp_dtype null
```

## 12.8 SFT 前后的生成效果对比

### 12.8.1 通用指令

**SFT 前（预训练模型）**：

```
Prompt: "Write a poem about the ocean."

Output: "Write a poem about the ocean. The ocean is vast and deep.
         Write a poem about the mountains. The mountains are tall..."
         （续写模式，不断产生新的 QA 对）
```

**SFT 后**：

```
Prompt: "<|user|>
Write a poem about the ocean.
<|assistant|>"

Output: "Waves crash upon the shore,
         Salt spray fills the air,
         The deep blue stretches evermore,
         A beauty beyond compare."
         （直接回答，然后停止）
```

### 12.8.2 数学推理（GSM8K）

**SFT 前**：

```
Prompt: "Janet has 10 snowballs..."

Output: "Janet has 10 snowballs. She gives 3 to her friend.
         Janet has 7 snowballs. She gives 2 more to her brother..."
         （续写模式，不会停止）
```

**SFT 后**：

```
Prompt: "<|user|>
Janet has 10 snowballs. She gives 3 to her friend. How many does she have left?
<|assistant|>"

Output: "<think>Janet starts with 10 snowballs. She gives 3 away.
         10 - 3 = 7.</think><answer>7</answer>"
         （正确的 CoT 格式，虽然推理可能不总是对的）
```

### 12.8.3 Loss 的变化轨迹

```
loss
│
5.5 ┤●
│  ╲
5.0 ┤   ●
│     ╲
4.5 ┤      ●
│        ╲
4.0 ┤         ●
│           ╲
3.5 ┤            ●────●
│                   ╲
3.0 ┤                    ●────●────●
│
└──┬──┬──┬──┬──┬──┬──┬──┬──┬──▶ step
   0  10 20 30 40 50 60 70 80 93

   ↑ warmup    ↑ 快速下降    ↑ 收敛
```

三个阶段：
1. **Warmup**（前 100 步）：学习率从 0 线性增长，loss 下降慢
2. **快速下降**（100-50 步）：模型快速学会对话格式
3. **缓慢收敛**（50-93 步）：模型优化回答质量

### 12.8.4 量化指标

| 指标 | SFT 前 | SFT 后 | 说明 |
|------|--------|--------|------|
| Masked Dev Loss | ~5.5 | ~3.0 | 模型在对话数据上的困惑度大幅降低 |
| GSM8K 格式正确率 | 0% | ~80% | 学会了 `<think>...<answer>` 格式 |
| GSM8K 准确率 | ~0% | ~5-15% | 格式对了，但推理能力有限 |

**为什么 GSM8K 准确率只有 5-15%？**

SFT 只是教模型"模仿"正确格式的推理过程。256 tokens 的上下文长度和 ~2M 参数的模型，无法进行复杂的多步数学推理。后续的 PPO/GRPO 阶段可以通过强化学习进一步提升准确率。

## 12.9 常见问题与调试

### 12.9.1 训练 loss 不下降

```
step 0/93   | loss 5.2341 | ppl 187.56
step 20/93  | loss 5.2100 | ppl 183.45   ← 几乎没变化
step 40/93  | loss 5.1900 | ppl 179.82
```

**可能原因**：
- 学习率太小（`--lr 1e-7` 而非 `1e-5`）
- 预训练 checkpoint 质量差（还没收敛就做了 SFT）
- 数据准备有误（mask 全为 0）

**排查方法**：

```bash
# 检查 mask 是否有 1
python3 -c "
import h5py, numpy as np
f = h5py.File('/ephemeral/data/sft_packed.h5', 'r')
mask = np.asarray(f['loss_mask'])
print('mask sum:', mask.sum(), '/', mask.size, f'= {mask.mean():.3f}')
"
# 正常应该 mask.mean() ≈ 0.3-0.5
```

### 12.9.2 DDP 挂死

```
[E ProcessGroupNCCL.cpp:821] [Rank 0] Watchdog caught collective operation timeout
```

**常见原因**：
- 最终评估用了 `model` 而非 `unwrap(model)`
- 某个 rank 提前退出（`cleanup` 后还调用 DDP 模型）
- `eval_dev` 中 `max_batches` 太大导致各 rank 处理时间差异大

### 12.9.3 显存不足（OOM）

```
CUDA out of memory. Tried to allocate 2.00 GiB
```

**解决方案**（按优先级）：

1. 减小 `batch_size`：`--batch_size 8`
2. 确认 `amp_dtype` 是 `bf16`：减少一半显存
3. 减小 `context_length`（需重新准备数据）

### 12.9.4 Checkpoint 加载失败

```
RuntimeError: Error(s) in loading state_dict:
    size mismatch for pos_emb: copying a param with shape [1024, 256] to [256, 256]
```

**原因**：预训练 checkpoint 的 `context_length` 和当前配置不一致。

**修复**：确保 `configs/base.json` 的 `context_length` 和预训练时一致。

## 12.10 本章小结

### SFT 完整流程

```
prepare_sft_data.py → sft_packed.h5 + sft_dev_packed.h5
                              │
                              ▼
                     train_sft.py
                     ├── 加载 base_pretrained.pt
                     ├── 构建 AdamW（lr=1e-5, wd=0）
                     ├── 训练循环（masked CE, bf16, grad_clip）
                     ├── 周期性评估（masked dev loss）
                     └── 保存 sft.pt
```

### 与预训练的核心差异

| 方面 | 预训练 | SFT |
|------|--------|-----|
| 数据 | 连续文本流 | 结构化对话 + mask |
| Loss | 标准 CE | Masked CE |
| 学习率 | 3e-4 | 1e-5（保守） |
| Weight Decay | 0.1 | 0.0 |
| 训练步数 | 200k（固定） | epochs × steps（数据驱动） |
| 梯度累积 | 有 | 无 |
| 评估指标 | dev loss + ppl | dev loss + ppl（masked） |

### 关键教训

1. **context_length 三方一致**：数据 × 模型 × checkpoint
2. **最终评估用 unwrap**：避免 DDP 挂死
3. **学习率要保守**：SFT 是微调，不是从头训练
4. **mask 验证**：确保数据准备正确（mask.mean() ≈ 0.3-0.5）

---

## 练习

**练习 1：完整 SFT 流水线**

在 smoke 配置下跑完整个流程：

```bash
# 准备数据（smoke 模型 context_length=256）
PYTHONPATH=. python scripts/prepare_sft_data.py --context_length 256 --limit_per_set 50

# 训练（smoke 配置）
PYTHONPATH=. python scripts/train_sft.py --config configs/smoke/sft.json

# 验证 checkpoint 可以加载
python3 -c "
import torch
ck = torch.load('/ephemeral/ckpts/sft.pt', weights_only=False)
print('stage:', ck['stage'])
print('step:', ck['step'])
print('keys:', len(ck['model_state_dict']))
print('metrics:', ck['metrics'])
"
```

**练习 2：数据质量检查**

写一个脚本检查 `sft_packed.h5` 的质量：
1. mask 的平均值是多少？
2. 有多少行的 mask 全为 0？
3. 随机打印一行，decode 看看内容

**练习 3：预测行为**

如果不做 Loss Mask（mask 全为 1），SFT 后的模型会怎样？
- A. 模型的回答质量更高
- B. 模型会学会复述用户输入
- C. 没有影响
- D. 模型无法停止生成

解释你的答案。

**练习 4：学习率实验**

分别用 `lr=1e-4`、`lr=1e-5`、`lr=1e-6` 训练 SFT（smoke 配置），对比：
1. loss 下降速度
2. 最终 dev loss
3. 哪种学习率最好？为什么？
