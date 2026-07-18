# 第 7 章：预训练循环

> **本章目标**：理解预训练循环的每一行代码，从数据加载到参数更新，从单 GPU 到多 GPU 分布式训练。

## 7.0 本章路线图

在第 6 章中，我们已经把文本变成了 HDF5 文件中的 token 序列。本章要回答的问题是：

```
给定 15 亿个 token 和一个随机初始化的 Transformer，
如何一步步把它训练成一个"懂语言"的模型？
```

本章会逐行解析 `scripts/pretrain_base.py`——这是整个项目的核心训练脚本。所有后训练阶段（SFT、DPO、PPO、GRPO）都从这个脚本产出的 checkpoint 开始。

```
pretrain_base.py 的执行流程
│
├── ① 加载配置（PretrainConfig + JSON + CLI）
├── ② 初始化 DDP 分布式环境
├── ③ 构建模型（随机初始化）
├── ④ 可选：从 checkpoint 恢复（模型 + 优化器状态）
├── ⑤ 可选：torch.compile 编译加速
├── ⑥ DDP 包装（多 GPU 时）
├── ⑦ 构建 AdamW 优化器
├── ⑧ 构建数据加载器
└── ⑨ 训练循环（核心）
    ├── 计算学习率（cosine schedule）
    ├── 梯度累积（N 个 micro-batch）
    │   ├── 前向传播（bf16 autocast）
    │   ├── Loss / grad_accum
    │   ├── 反向传播（累积梯度）
    │   └── DDP 梯度同步（只在最后一个 micro-batch）
    ├── 梯度裁剪
    ├── 优化器 step
    ├── 日志记录（每 20 步）
    ├── 验证评估（每 eval_steps 步）
    └── Checkpoint 保存（每 save_every 步）
```

## 7.1 Next-Token Prediction 与 Cross-Entropy Loss

### 7.1.1 训练目标

预训练的目标只有一个：**给定前面的 token，预测下一个 token。**

```
输入:  ["The", "cat", "sat", "on"]
目标:  ["cat", "sat", "on", "the"]
```

模型在每个位置都输出一个概率分布（vocab_size 维），交叉熵衡量这个分布和真实下一个 token 之间的"距离"。

### 7.1.2 代码实现

```python
# src/models/transformer.py — Transformer.forward

def forward(self, idx, targets=None):
    x = self.forward_hidden(idx)        # (B, T, n_embed)
    logits = self.lm_head(x)            # (B, T, vocab_size)

    loss = None
    if targets is not None:
        B, T, C = logits.shape
        flat_logits = logits.reshape(B * T, C)   # (B*T, vocab_size)
        targets = targets.reshape(B * T).long()   # (B*T,)
        loss = F.cross_entropy(flat_logits, targets)
    return logits, loss
```

### 7.1.3 为什么用 reshape 而不是 view？

注意这里用的是 `reshape` 而不是 `view`。区别在于：

- `view`：要求张量在内存中**连续**（contiguous），否则会报错
- `reshape`：自动判断——如果连续就用 view（零拷贝），否则先拷贝再变形

`targets` 来自数据加载器的切片操作（`yb = random_samples[:, 1:context_length+1]`），切片后的张量可能不是内存连续的。用 `reshape` 更安全。

### 7.1.4 初始 Loss 的含义

训练刚开始时，模型参数是随机的，`lm_head` 输出的 logits 也接近随机。此时 softmax 输出的概率接近均匀分布：

```
P(每个 token) ≈ 1/vocab_size ≈ 1/50304

Cross-Entropy = -ln(1/50304) = ln(50304) ≈ 10.83
```

如果你看到训练开始时的 loss 在 **10-11** 之间，说明一切正常。如果远高于这个值，可能是初始化有问题。

## 7.2 训练脚本逐行解析

### 7.2.1 配置加载

```python
# scripts/pretrain_base.py — main() 开始

cfg, extras = parse_config_with_json(
    PretrainConfig, "configs/pretrain.json",
    extra={"--resume": dict(type=str, default=None,
                             help="checkpoint to resume from")})
resume = extras.resume
```

配置加载的三层覆盖：

```
PretrainConfig 默认值          ← 最低优先级
    ↓ 被覆盖
configs/pretrain.json          ← 中间优先级
    ↓ 被覆盖
CLI 参数 --batch_size 16       ← 最高优先级
```

`--resume` 是一个额外的 CLI 参数，不在 PretrainConfig 中定义，用于指定恢复训练的 checkpoint 路径。

### 7.2.2 DDP 初始化

```python
ctx = ddp_setup(cfg.device)
set_seed(cfg.seed + ctx.rank)
```

`ddp_setup` 检测是否通过 `torchrun` 启动：

- **单 GPU**（`python pretrain_base.py`）：返回 `world_size=1`，不初始化分布式
- **多 GPU**（`torchrun --nproc_per_node=2 pretrain_base.py`）：初始化 NCCL 后端，每个进程绑定一个 GPU

`set_seed(cfg.seed + ctx.rank)` 确保每个 rank 使用不同的随机种子——这样不同 GPU 看到的数据 shuffle 顺序不同，增加训练多样性。

### 7.2.3 模型构建与恢复

```python
model = build_model_from_config(cfg).to(ctx.device)
start_step = 0

if resume and os.path.exists(resume):
    ck = torch.load(resume, map_location="cpu", weights_only=False)
    unwrap(model).load_state_dict(ck["model_state_dict"])
    start_step = ck.get("step", 0)
```

`build_model_from_config` 根据配置创建一个**随机初始化**的 Transformer。如果提供了 `--resume`，则从 checkpoint 加载权重，并从保存的 `step` 继续训练。

`unwrap(model)` 的作用：如果模型被 DDP 包装（`DistributedDataParallel(model)`），`model.module` 才是原始模型。`unwrap` 统一处理这两种情况。

### 7.2.4 可选编译与 DDP 包装

```python
if cfg.compile:
    model = torch.compile(model)
model = ddp_wrap(model, ctx)
```

**执行顺序很重要**：先 `torch.compile`，再 DDP 包装。如果反过来，DDP 的通信钩子和编译器会冲突。

`torch.compile` 会把模型编译成优化后的 CUDA 内核，通常能带来 20-50% 的加速。但第一次编译需要几十秒（"warmup"），且某些环境可能不兼容。

### 7.2.5 优化器构建

```python
optimizer = configure_optimizer(unwrap(model), cfg.lr, cfg.weight_decay)

if resume and os.path.exists(resume):
    ck = torch.load(resume, map_location="cpu", weights_only=False)
    if ck.get("optimizer_state_dict"):
        optimizer.load_state_dict(ck["optimizer_state_dict"])
```

`configure_optimizer` 把参数分为两组（详见第 5 章）：
- **衰减组**（dim ≥ 2）：权重矩阵，应用 weight_decay
- **非衰减组**（dim < 2）：bias、LayerNorm 参数，不应用 weight_decay

恢复训练时，优化器的动量状态（m、v）也会被恢复——这是 AdamW 训练连续性的关键。

## 7.3 训练循环核心

### 7.3.1 整体结构

```python
batch_iter = get_batch_iterator(cfg.train_path, cfg.batch_size,
                                 cfg.context_length, device=ctx.device)
tokens_per_step = cfg.batch_size * cfg.context_length * cfg.grad_accum * ctx.world_size

model.train()
for step in range(start_step, cfg.train_steps):
    # ① 更新学习率
    # ② 清零梯度
    # ③ 梯度累积循环
    # ④ 梯度裁剪
    # ⑤ 参数更新
    # ⑥ 日志 / 评估 / 保存
```

### 7.3.2 学习率更新

```python
lr = cosine_lr(step, warmup_steps=cfg.warmup_steps,
               max_steps=cfg.train_steps,
               lr=cfg.lr, min_lr=cfg.min_lr)
for g in optimizer.param_groups:
    g["lr"] = lr
```

每一步都重新计算学习率。`optimizer.param_groups` 包含两组参数（衰减组和非衰减组），两组共用同一个学习率，只是 weight_decay 不同。

### 7.3.3 梯度累积

这是预训练循环最精妙的部分。让我们拆解 `grad_accum=12` 的情况：

```python
optimizer.zero_grad(set_to_none=True)
accum_loss = 0.0

for micro in range(cfg.grad_accum):          # 12 次 micro-batch
    xb, yb = next(batch_iter)

    # DDP 优化：只在最后一个 micro-batch 同步梯度
    sync = (micro == cfg.grad_accum - 1) or not ctx.enabled
    cm = model.no_sync() if (ctx.enabled and not sync) else _nullcm()

    with cm, amp_autocast(cfg.amp_dtype, ctx.device):
        _, loss = model(xb, yb)
        loss = loss / cfg.grad_accum         # 缩放 loss

    loss.backward()                          # 梯度累积到 .grad
    accum_loss += loss.item()
```

**为什么不直接用大 batch？**

`batch_size=8, grad_accum=12` 等价于 `batch_size=96`，但显存只需要 `batch_size=8` 的量。

| 方案 | 有效 batch | 显存占用 | 速度 |
|------|-----------|---------|------|
| batch=96, accum=1 | 96 | 12x | 最快（但 OOM） |
| batch=8, accum=12 | 96 | 1x | 稍慢（12 次前向传播） |
| batch=8, accum=1 | 8 | 1x | 最快（但 batch 太小） |

### 7.3.4 `loss / grad_accum` 的数学正确性

这个缩放为什么是对的？推导如下：

```
完整 batch 的梯度 = (1/N) × Σᵢ ∇Lᵢ    （N = 总样本数）

分 M 个 micro-batch（每个 m = N/M 个样本）：
  micro-batch k 的梯度 = (1/m) × Σᵢ∈batch_k ∇Lᵢ

如果直接累加 M 次：
  累积梯度 = Σₖ (1/m) × Σᵢ∈batch_k ∇Lᵢ
           = (M/N) × Σᵢ ∇Lᵢ
           = M × 完整 batch 梯度

要让累积梯度 = 完整 batch 梯度，需要每次除以 M：
  累积梯度 = Σₖ (1/m) × Σᵢ∈batch_k ∇Lᵢ × (1/M)
           = (1/N) × Σᵢ ∇Lᵢ              ✓
```

在代码中，我们在 `loss.backward()` 之前把 loss 除以 `grad_accum`（即 M），这样 `backward()` 计算出的梯度也自动被缩放了。

### 7.3.5 DDP 梯度同步优化

```python
sync = (micro == cfg.grad_accum - 1) or not ctx.enabled
cm = model.no_sync() if (ctx.enabled and not sync) else _nullcm()
```

在 DDP 模式下，每个 `loss.backward()` 都会触发一次 AllReduce（跨 GPU 梯度同步）。如果做 12 次 micro-batch，就会同步 12 次——但前 11 次的同步是浪费的，因为我们只需要最终的累积梯度。

解决方案：
- 前 11 次：用 `model.no_sync()` 抑制梯度同步
- 最后 1 次：正常同步

这样通信量减少了 **12 倍**。

### 7.3.6 bf16 自动混合精度

```python
with cm, amp_autocast(cfg.amp_dtype, ctx.device):
    _, loss = model(xb, yb)
    loss = loss / cfg.grad_accum
```

`amp_autocast` 是一个上下文管理器：

```python
# src/post_training/utils.py

def amp_autocast(amp_dtype, device):
    if amp_dtype == "bf16" and str(device).startswith("cuda"):
        return torch.autocast(device_type="cuda", dtype=torch.bfloat16)
    return contextlib.nullcontext()  # CPU 或不需要时，什么都不做
```

在 `autocast` 上下文中，PyTorch 自动把矩阵运算转为 bf16（更快、更省显存），但保持 LayerNorm、Softmax 等数值敏感操作在 fp32。

**关键点**：模型参数仍然存储在 fp32，只是计算时用 bf16。优化器状态（m、v）也保持 fp32。

### 7.3.7 梯度裁剪与参数更新

```python
torch.nn.utils.clip_grad_norm_(model.parameters(), cfg.grad_clip)
optimizer.step()
```

梯度裁剪确保全局梯度范数不超过 `grad_clip`（默认 1.0）。这防止偶尔出现的梯度爆炸毁掉整个训练。

完整的训练步骤示意图：

```
Step 开始
    │
    ▼
┌──────────────────┐
│ 计算学习率         │  cosine_lr(step, ...)
│ 清零梯度           │  optimizer.zero_grad(set_to_none=True)
└──────────────────┘
    │
    ▼
┌─ micro 0 ────────┐
│ forward(x, y)    │  bf16 autocast
│ loss / 12        │  缩放 loss
│ loss.backward()  │  梯度累积，不同步
└──────────────────┘
    │
┌─ micro 1 ────────┐
│ ...（同上）       │
└──────────────────┘
    │
    ... × 12 次
    │
┌─ micro 11 ───────┐
│ forward(x, y)    │  bf16 autocast
│ loss / 12        │  缩放 loss
│ loss.backward()  │  梯度累积 + DDP 同步  ← 关键！
└──────────────────┘
    │
    ▼
┌──────────────────┐
│ clip_grad_norm_  │  裁剪梯度范数 ≤ 1.0
│ optimizer.step() │  AdamW 更新参数
└──────────────────┘
    │
    ▼
  Step 结束
```

## 7.4 日志与评估

### 7.4.1 训练日志

```python
if ctx.is_main and step % 20 == 0:
    dt = time.perf_counter() - t0
    tok_s = tokens_per_step * 20 / dt if step > start_step else 0.0
    t0 = time.perf_counter()
    print(f"step {step} | loss {accum_loss:.4f} | lr {lr:.2e} | {tok_s:,.0f} tok/s")
```

每 20 步打印一次，包含：
- **step**：当前步数
- **loss**：这 20 步的平均训练 loss（实际上 `accum_loss` 是当前 step 的 loss）
- **lr**：当前学习率
- **tok/s**：吞吐量（每秒处理的 token 数）

### 7.4.2 MetricsLogger

```python
logger = MetricsLogger("pretrain", cfg.log_dir,
                        use_wandb=cfg.use_wandb,
                        wandb_project=cfg.wandb_project,
                        config=vars(cfg).copy())
```

`MetricsLogger` 同时写两种日志：

1. **JSONL 文件**：每行一个 JSON 对象，可以用 pandas 加载和绘图
2. **Weights & Biases**（可选）：实时仪表盘，支持多实验对比

```python
# src/post_training/logging_utils.py

def log(self, step, metrics):
    record = {"step": step, "wall": time.time(), **metrics}
    self._fh.write(json.dumps(record) + "\n")
    self._fh.flush()
    if self._wandb is not None:
        self._wandb.log(metrics, step=step)
```

### 7.4.3 验证评估

```python
@torch.no_grad()
def estimate_loss(model, cfg, ctx, iters: int) -> dict[str, float]:
    model.eval()
    out = {}
    for split, path in [("train", cfg.train_path), ("dev", cfg.dev_path)]:
        if not os.path.exists(path):
            continue
        it = get_batch_iterator(path, cfg.batch_size, cfg.context_length,
                                device=ctx.device)
        losses = torch.zeros(iters)
        for k in range(iters):
            xb, yb = next(it)
            with amp_autocast(cfg.amp_dtype, ctx.device):
                _, loss = model(xb, yb)
            losses[k] = loss.item()
        out[split] = losses.mean().item()
    model.train()
    return out
```

每隔 `eval_steps` 步，在训练集和验证集上各算 100 次 loss 取平均。

关键细节：
- **`@torch.no_grad()`**：评估时不计算梯度，节省显存和计算
- **`model.eval()` / `model.train()`**：切换模式。对于 Transformer 来说影响不大（没有 Dropout），但这是好习惯
- **`reduce_scalar`**：多 GPU 时，把所有 rank 的 loss 取平均

### 7.4.4 典型输出解读

```
step 0     | loss 10.8265 | lr 1.50e-07 | 0 tok/s       ← 随机初始化，loss ≈ ln(50304)
step 20    | loss 10.7843 | lr 3.00e-06 | 125,430 tok/s  ← Warmup 中，loss 开始下降
step 100   | loss 9.8421  | lr 1.50e-05 | 128,200 tok/s  ← 加速学习
step 2000  | loss 5.6312  | lr 3.00e-04 | 131,500 tok/s  ← Warmup 结束，lr 达到峰值
  [eval] step 2000 | train 5.6234 | dev 5.6891           ← Dev loss 略高于 train
step 10000 | loss 4.2156  | lr 2.31e-04 | 130,800 tok/s  ← 稳定下降
  [eval] step 10000 | train 4.1823 | dev 4.2567
step 50000 | loss 3.4521  | lr 8.72e-05 | 131,200 tok/s  ← Cosine decay 中
step 100000| loss 3.1245  | lr 3.15e-05 | 130,900 tok/s  ← 接近尾部
step 200000| loss 2.9876  | lr 3.00e-05 | 131,000 tok/s  ← 训练结束
```

## 7.5 Checkpoint 保存与恢复

### 7.5.1 保存格式

```python
# src/post_training/utils.py — save_stage_ckpt

payload = {
    "model_state_dict": unwrap(model).state_dict(),
    "optimizer_state_dict": optimizer.state_dict(),
    "stage": "pretrain",
    "cfg": _cfg_to_dict(cfg),
    "step": step,
    "metrics": {"train_loss": accum_loss},
    "pytorch_version": torch.__version__,
    "cuda_version": torch.version.cuda,
}
torch.save(payload, path)
```

Checkpoint 包含：
- **模型权重**：`unwrap(model)` 去掉 DDP 包装，保存原始模型
- **优化器状态**：动量 m 和方差 v，恢复后训练无缝继续
- **元数据**：阶段名、配置、步数、性能指标、PyTorch/CUDA 版本

### 7.5.2 恢复训练

```python
# 恢复模型
ck = torch.load(resume, map_location="cpu", weights_only=False)
unwrap(model).load_state_dict(ck["model_state_dict"])
start_step = ck.get("step", 0)

# 恢复优化器
optimizer.load_state_dict(ck["optimizer_state_dict"])
```

恢复时需要同时恢复模型权重和优化器状态。如果只恢复模型权重，AdamW 的动量会被重置为零——相当于冷启动，训练初期会有明显的"抖动"。

### 7.5.3 保存时机

```python
# 定期保存
if ctx.is_main and step > start_step and step % cfg.save_every == 0:
    save_stage_ckpt(cfg.out_ckpt, model, optimizer, ...)

# 最终保存
if ctx.is_main:
    save_stage_ckpt(cfg.out_ckpt, model, optimizer, ...)
```

- **定期保存**：每 `save_every` 步保存一次（默认 2000 步）
- **最终保存**：训练结束时再保存一次

只在主进程（`rank=0`）保存，避免多 GPU 时多个进程同时写文件导致损坏。

### 7.5.4 实战踩坑：`torch.compile` 导致的 Key 前缀问题

这是一个我们在项目中**真实遇到**的问题，值得详细记录。

#### 背景

预训练脚本支持 `torch.compile` 编译加速：

```python
if cfg.compile:
    model = torch.compile(model)    # 编译后的模型
model = ddp_wrap(model, ctx)        # 再包一层 DDP
```

编译后保存 checkpoint 时，我们以为 `unwrap(model)` 已经去掉了所有包装层，但实际保存的 key 是这样的：

```
_orig_mod.tok_emb.weight
_orig_mod.pos_emb.weight
_orig_mod.blocks.0.attn.c_attn.weight
...
（共 163 个 key，全部带 _orig_mod. 前缀）
```

而 `unwrap()` 只去掉了 DDP 的 `module.` 前缀，`torch.compile` 添加的 `_orig_mod.` 前缀被原封不动地保存到了 checkpoint 中。

#### 问题现象

在后训练阶段（SFT、DPO 等）加载预训练权重时，模型输出全是乱码。我们用诊断脚本检查 checkpoint 的 key 匹配情况：

```python
# 诊断脚本：检查 checkpoint key 匹配
import torch
from src.models.transformer import Transformer

m = Transformer(n_head=4, n_embed=256, context_length=256, vocab_size=50304, N_BLOCKS=6)
model_keys = set(m.state_dict().keys())

for name in ['ephemeral/ckpts/base_pretrained.pt', 'ephemeral/ckpts/sft.pt']:
    ck = torch.load(name, map_location='cpu', weights_only=False)
    state = ck.get('model_state_dict', ck)
    ck_keys = set(state.keys())
    matched = model_keys & ck_keys
    missing = model_keys - ck_keys
    print(f'{name}:')
    print(f'  total ckpt keys: {len(ck_keys)}, matched: {len(matched)}, missing: {len(missing)}')
    if missing:
        print(f'  missing examples: {list(missing)[:5]}')
```

**运行结果**：

```
ephemeral/ckpts/base_pretrained.pt:
  total ckpt keys: 163, matched: 0, missing: 163
  missing examples: ['attn_blocks.3.attn.heads.0.key.weight', 'attn_blocks.4.attn.heads.3.tril', 'attn_blocks.1.attn.heads.3.value.weight', 'attn_blocks.3.ln2.bias', 'attn_blocks.5.attn.heads.2.value.weight']

ephemeral/ckpts/sft.pt:
  total ckpt keys: 163, matched: 0, missing: 163
  missing examples: ['attn_blocks.3.attn.heads.0.key.weight', 'attn_blocks.4.attn.heads.3.tril', ...]
```

**163 个 key 全部不匹配（0 matched）**——checkpoint 里的 163 个参数全部没加载上，模型相当于从头随机初始化，整个预训练白做了。

进一步检查 checkpoint 实际的 key 名：

```python
ck = torch.load('ephemeral/ckpts/base_pretrained.pt', map_location='cpu', weights_only=False)
state = ck.get('model_state_dict', ck)
for k in sorted(state.keys())[:10]:
    print(k)
```

**输出**：

```
_orig_mod.attn_blocks.0.attn.heads.0.key.weight
_orig_mod.attn_blocks.0.attn.heads.0.query.weight
_orig_mod.attn_blocks.0.attn.heads.0.tril
_orig_mod.attn_blocks.0.attn.heads.0.value.weight
_orig_mod.attn_blocks.0.attn.heads.1.key.weight
...
```

看到了！所有 key 都带 `_orig_mod.` 前缀，但加载逻辑只去掉了 `module.` 前缀。

#### 根因分析

两种包装机制各自添加不同的前缀：

| 包装层 | 添加的前缀 | 示例 key |
|--------|-----------|----------|
| DDP (`DistributedDataParallel`) | `module.` | `module.tok_emb.weight` |
| `torch.compile` | `_orig_mod.` | `_orig_mod.tok_emb.weight` |
| DDP + compile（嵌套） | `module._orig_mod.` | `module._orig_mod.tok_emb.weight` |

原来的 `_strip_ddp_prefix` 函数只处理了 `module.` 前缀：

```python
# 旧版（有 bug）
def _strip_ddp_prefix(state_dict):
    out = {}
    for k, v in state_dict.items():
        if k.startswith("module."):
            k = k[7:]            # 只去掉 module.
        out[k] = v
    return out
```

当 key 是 `_orig_mod.tok_emb.weight` 时，它不以 `module.` 开头，所以**前缀被完整保留**，和模型期望的 `tok_emb.weight` 不匹配。

#### 修复方案

用 `while` 循环反复剥离两种前缀，直到没有前缀为止。这样可以处理任意组合和嵌套：

```python
# src/post_training/utils.py — 修复后的版本

def _strip_ddp_prefix(state_dict: dict) -> dict:
    """Remove leading module. (DDP) and _orig_mod. (torch.compile) prefixes."""
    out = {}
    for k, v in state_dict.items():
        # 用 while 循环反复剥离，处理任意组合
        while k.startswith("module.") or k.startswith("_orig_mod."):
            k = k.removeprefix("module.").removeprefix("_orig_mod.")
        out[k] = v
    return out
```

#### 为什么用 `while` 而不是 `if`？

因为前缀可能**嵌套出现**。在极端情况下（DDP + compile 混合），一个 key 可能同时带有两层前缀：

```
module._orig_mod.tok_emb.weight
  ↓ removeprefix("module.")
_orig_mod.tok_emb.weight
  ↓ removeprefix("_orig_mod.")
tok_emb.weight                  ✓ 正确
```

如果用 `if` 只剥一次，遇到嵌套前缀就会残留。

#### 验证

修复后的验证代码：

```python
# 检查 checkpoint 中的实际 key
ckpt = torch.load("/ephemeral/models/base_model.pt", map_location="cpu")
raw_keys = list(ckpt["model_state_dict"].keys())
print("原始 key 示例:", raw_keys[:3])
# 输出: ['_orig_mod.tok_emb.weight', '_orig_mod.pos_emb.weight', ...]

# 应用 strip 后的 key
cleaned = _strip_ddp_prefix(ckpt["model_state_dict"])
print("清理后 key 示例:", list(cleaned.keys())[:3])
# 输出: ['tok_emb.weight', 'pos_emb.weight', ...]

# 加载验证
model = build_model_from_config(cfg)
missing, unexpected = model.load_state_dict(cleaned, strict=False)
print(f"missing: {len(missing)}, unexpected: {len(unexpected)}")
# 输出: missing: 0, unexpected: 0  ← 完美匹配
```

#### 同样的问题：inference.py 也有相同的 bug

修复了 `utils.py` 之后，问题并没有完全结束。`chat.py` 和评估脚本共用的 `load_model_from_ckpt`（位于 `src/post_training/inference.py`）有**自己独立的一套前缀处理逻辑**：

```python
# src/post_training/inference.py — 旧版（有 bug）

state = {k.removeprefix("module.").removeprefix("transformer."): v
         for k, v in state.items()}
```

这段代码存在两个问题：

1. **没有处理 `_orig_mod.` 前缀**——`torch.compile` 产生的前缀完全被忽略
2. **只剥一层**——遇到嵌套前缀（如 `module._orig_mod.tok_emb.weight`）会残留

举例：

```
原始 key:                    module._orig_mod.tok_emb.weight
  ↓ removeprefix("module.")    →  _orig_mod.tok_emb.weight
  ↓ removeprefix("transformer.")→  _orig_mod.tok_emb.weight  ← 没变！
最终:                              _orig_mod.tok_emb.weight  ← 不匹配 ✗
```

#### 修复方案

与其在每个加载点都写一遍前缀清理，不如直接复用 `utils.py` 的 `_strip_ddp_prefix`：

```python
# src/post_training/inference.py — 修复后的版本

from src.post_training.utils import _strip_ddp_prefix

def load_model_from_ckpt(ckpt_path, device, overrides=None):
    # ... 构建模型 ...
    state = ck["model_state_dict"] if "model_state_dict" in ck else ck
    state = _strip_ddp_prefix(state)   # 复用统一的清理函数
    keys = set(model.state_dict().keys())
    model.load_state_dict({k: v for k, v in state.items() if k in keys}, strict=False)
    return model.to(device).eval()
```

#### 教训：前缀清理应该只有一个地方

这个 bug 的深层原因是：项目中**两个不同的地方**各自实现了一遍前缀清理，而且两边都没有处理全。

| 文件 | 旧版处理方式 | 缺陷 |
|------|-----------|------|
| `utils.py` (`_strip_ddp_prefix`) | `if k.startswith("module.")` | 不处理 `_orig_mod.` |
| `inference.py` (`load_model_from_ckpt`) | `removeprefix("module.").removeprefix("transformer.")` | 不处理 `_orig_mod.`，只剥一层 |

修复后，所有 checkpoint 加载路径都统一调用 `_strip_ddp_prefix`，避免重复造轮子（且每个轮子都有 bug）。

#### 经验总结

> **规则**：`torch.compile` 和 DDP 都会给模型参数添加前缀，保存和加载时必须同时处理两种前缀。
>
> **防御式编程**：用 `while` 循环而不是 `if` 判断，确保无论前缀如何组合都能正确清理。
>
> **单一职责**：前缀清理逻辑只在一个地方实现（`_strip_ddp_prefix`），所有加载函数统一调用它。分散实现 = 分散 bug。
>
> **调试技巧**：加载 checkpoint 后先打印前几个 key 看看有没有前缀，不要等到 163 个 missing keys 报错才发现问题。

## 7.6 DDP 分布式训练

### 7.6.1 单 GPU vs 多 GPU

```bash
# 单 GPU
PYTHONPATH=. python3 scripts/pretrain_base.py

# 多 GPU（2 卡）
PYTHONPATH=. torchrun --standalone --nproc_per_node=2 scripts/pretrain_base.py
```

`torchrun` 会自动设置环境变量：
- `RANK`：全局 rank（0, 1, 2, ...）
- `LOCAL_RANK`：本机 GPU 编号
- `WORLD_SIZE`：总进程数

### 7.6.2 DDPContext

```python
# src/post_training/distributed.py

@dataclass
class DDPContext:
    rank: int
    local_rank: int
    world_size: int
    device: str

    @property
    def is_main(self) -> bool:
        return self.rank == 0

    @property
    def enabled(self) -> bool:
        return self.world_size > 1
```

`DDPContext` 封装了分布式训练的所有上下文信息。代码中大量使用 `ctx.is_main` 来决定是否执行日志打印、模型保存等操作——这些操作只需要一个进程做。

### 7.6.3 DDP 的工作原理

```
    进程 0 (GPU 0)              进程 1 (GPU 1)
    ┌─────────────┐            ┌─────────────┐
    │ 完整模型副本  │            │ 完整模型副本  │
    │ 不同的数据    │            │ 不同的数据    │
    │ 前向传播     │            │ 前向传播     │
    │ 反向传播     │            │ 反向传播     │
    │     │       │            │     │       │
    │     ▼       │            │     ▼       │
    │  ┌──────┐   │            │  ┌──────┐   │
    │  │AllReduce│◄├────────────┤►│AllReduce│  │
    │  │梯度平均 │   │            │  │梯度平均 │  │
    │  └──────┘   │            │  └──────┘   │
    │     │       │            │     │       │
    │     ▼       │            │     ▼       │
    │ optimizer   │            │ optimizer   │
    │ step()      │            │ step()      │
    └─────────────┘            └─────────────┘
```

每个进程：
1. 持有模型的**完整副本**（不是模型并行）
2. 处理**不同的数据**
3. 计算本地梯度
4. 通过 **AllReduce** 同步梯度（所有进程得到平均梯度）
5. 用**相同的平均梯度**更新参数

因为所有进程用相同的梯度更新相同的初始参数，所以参数始终一致。

### 7.6.4 有效 Batch Size

```python
tokens_per_step = cfg.batch_size * cfg.context_length * cfg.grad_accum * ctx.world_size
#                 8             × 256                × 12            × 2
#               = 49,152 tokens/step（双 GPU）
```

有效 batch = `batch_size × grad_accum × world_size`。这是模型"看到"的真实 batch 大小。

## 7.7 完整代码一览

最后，把 `pretrain_base.py` 的完整代码再展示一遍，每一段都对应本章的一个小节：

```python
def main():
    # ─── 配置 ─────────────────────────────────────────
    cfg, extras = parse_config_with_json(
        PretrainConfig, "configs/pretrain.json",
        extra={"--resume": dict(type=str, default=None)})
    resume = extras.resume

    # ─── 分布式 ────────────────────────────────────────
    ctx = ddp_setup(cfg.device)
    set_seed(cfg.seed + ctx.rank)

    # ─── 模型 ─────────────────────────────────────────
    model = build_model_from_config(cfg).to(ctx.device)
    start_step = 0
    if resume and os.path.exists(resume):
        ck = torch.load(resume, map_location="cpu", weights_only=False)
        unwrap(model).load_state_dict(ck["model_state_dict"])
        start_step = ck.get("step", 0)

    if cfg.compile:
        model = torch.compile(model)
    model = ddp_wrap(model, ctx)

    # ─── 优化器 ────────────────────────────────────────
    optimizer = configure_optimizer(unwrap(model), cfg.lr, cfg.weight_decay)
    if resume and os.path.exists(resume):
        ck = torch.load(resume, map_location="cpu", weights_only=False)
        if ck.get("optimizer_state_dict"):
            optimizer.load_state_dict(ck["optimizer_state_dict"])

    # ─── 日志 ─────────────────────────────────────────
    if ctx.is_main:
        n_params = sum(p.numel() for p in unwrap(model).parameters())
        print(f"Model parameters: {n_params:,} (~{n_params/1e6:.0f}M)")
        logger = MetricsLogger("pretrain", cfg.log_dir, ...)

    # ─── 数据 ─────────────────────────────────────────
    batch_iter = get_batch_iterator(cfg.train_path, cfg.batch_size,
                                     cfg.context_length, device=ctx.device)
    tokens_per_step = cfg.batch_size * cfg.context_length * cfg.grad_accum * ctx.world_size

    # ─── 训练循环 ──────────────────────────────────────
    model.train()
    for step in range(start_step, cfg.train_steps):
        lr = cosine_lr(step, ...)
        for g in optimizer.param_groups:
            g["lr"] = lr

        optimizer.zero_grad(set_to_none=True)
        for micro in range(cfg.grad_accum):
            xb, yb = next(batch_iter)
            sync = (micro == cfg.grad_accum - 1) or not ctx.enabled
            cm = model.no_sync() if (ctx.enabled and not sync) else _nullcm()
            with cm, amp_autocast(cfg.amp_dtype, ctx.device):
                _, loss = model(xb, yb)
                loss = loss / cfg.grad_accum
            loss.backward()

        torch.nn.utils.clip_grad_norm_(model.parameters(), cfg.grad_clip)
        optimizer.step()

        # 日志 / 评估 / 保存 ...
```

## 7.8 本章小结

### 训练循环五要素

| 要素 | 代码 | 作用 |
|------|------|------|
| 学习率调度 | `cosine_lr()` | 控制训练节奏：小→大→小 |
| 梯度累积 | `loss / grad_accum` | 用有限显存模拟大 batch |
| 混合精度 | `amp_autocast("bf16")` | 加速计算，节省显存 |
| 梯度裁剪 | `clip_grad_norm_(1.0)` | 防止梯度爆炸 |
| 权重衰减 | `configure_optimizer(wd=0.1)` | 防止过拟合 |

### 分布式训练三原则

1. **数据并行，模型复制**：每个 GPU 持有完整模型，处理不同的数据
2. **梯度同步，参数一致**：AllReduce 保证所有 GPU 用相同的梯度更新
3. **主进程特权**：只有 rank=0 做日志、保存等 I/O 操作

### Checkpoint 保存了什么

```
{
    "model_state_dict":    模型权重（去掉 DDP 包装）
    "optimizer_state_dict": 优化器动量（m, v）
    "step":                当前步数（用于恢复）
    "cfg":                 训练配置（用于重建模型）
    "metrics":             当前性能（用于对比）
}
```

---

## 练习

**练习 1：计算有效 Batch Size**

给定以下配置，计算有效 batch size 和每步处理的 token 数：
- `batch_size=16, grad_accum=4, context_length=512, world_size=4`

**练习 2：Loss 分析**

运行训练 1000 步后，从日志文件中画出 loss 曲线：

```python
import json
import matplotlib.pyplot as plt

steps, losses, lrs = [], [], []
with open("/ephemeral/logs/pretrain_*.jsonl") as f:
    for line in f:
        d = json.loads(line)
        steps.append(d["step"])
        losses.append(d["train_loss"])
        lrs.append(d["lr"])

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8), sharex=True)
ax1.plot(steps, losses)
ax1.set_ylabel("Loss")
ax2.plot(steps, lrs, color='red')
ax2.set_ylabel("Learning Rate")
ax2.set_xlabel("Step")
plt.show()
```

观察：
- Loss 下降的三个阶段（warmup → 快速下降 → 缓慢收敛）
- 学习率和 loss 的对应关系

**练习 3：Resume 实验**

1. 训练 500 步，保存 checkpoint
2. 从 checkpoint 恢复，继续训练到 1000 步
3. 对比：从头训练 1000 步 vs 恢复训练的 loss 曲线应该几乎重合

**练习 4：吞吐量分析**

在你的 GPU 上测试不同配置的 tok/s，找出最优配置：

```bash
# 测试 1：小 batch
PYTHONPATH=. python3 scripts/pretrain_base.py \
    --batch_size 4 --grad_accum 24 --train_steps 100

# 测试 2：大 batch
PYTHONPATH=. python3 scripts/pretrain_base.py \
    --batch_size 16 --grad_accum 6 --train_steps 100

# 测试 3：开启 compile
PYTHONPATH=. python3 scripts/pretrain_base.py \
    --batch_size 8 --grad_accum 12 --compile true --train_steps 100
```

记录每种配置的 tok/s，分析为什么某些配置更快。

