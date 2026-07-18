# 第 13 章：奖励模型（Reward Model）

> **本章目标**：理解人类偏好的数学建模（Bradley-Terry）、奖励头的架构设计、偏好数据的准备流程，以及奖励模型训练的完整代码。掌握"偏好准确率"指标的含义和调优方法。

## 13.0 本章路线图

SFT 教会了模型"回答问题"，但模型不知道**什么是好的回答**。奖励模型（Reward Model, RM）的任务是学会给回答打分——**好的回答得分高，差的回答得分低**。

```
本章覆盖的链路

prepare_preference_data.py              train_reward.py
┌──────────────────────────┐           ┌──────────────────────────────┐
│ HH-RLHF + UltraFeedback  │           │ 1. 加载 SFT backbone          │
│   ↓ _split_hh            │           │ 2. 加 reward_head             │
│   ↓ JSONL 格式           │           │ 3. Bradley-Terry 训练         │
│ → preferences.jsonl      │ ────────▶ │ 4. 偏好准确率评估              │
│ → preferences_test.jsonl │           │ 5. 保存 reward.pt             │
└──────────────────────────┘           └──────────────────────────────┘
                                                │
                                                ▼
                                        PPO 的奖励信号来源
```

奖励模型在 RLHF 流程中的位置：

```
SFT Model ──▶ Rollout（生成文本）──▶ Reward Model 打分 ──▶ PPO 更新
```

## 13.1 人类偏好与 Bradley-Terry 模型

### 13.1.1 偏好的本质

人类判断"哪个回答更好"是相对容易的任务，但直接给回答打一个绝对分数（1-10 分）很难且不一致。

**比较 vs 打分**：

```
绝对打分（难）：
  回答 A: "Paris is the capital of France."          → 7/10
  回答 B: "I believe it's Paris, if I'm not wrong."  → 5/10

相对比较（易）：
  回答 A vs 回答 B → A 更好 ✓
```

偏好数据收集的就是这种**相对比较**：给定一个 prompt 和两个回答，标注哪个更好。

### 13.1.2 Bradley-Terry 模型

Bradley-Terry 模型是偏好评判的数学基础：

```
P(A 优于 B) = σ(R(A) - R(B))

其中 σ 是 sigmoid 函数，R(A) 和 R(B) 是 A 和 B 的"内在质量分数"。
```

直觉：如果 A 的质量远高于 B，`R(A) - R(B)` 很大，`σ(大正数) ≈ 1`，即 A 几乎一定比 B 好。

### 13.1.3 训练目标

给定偏好数据 `(prompt, chosen, rejected)`，训练奖励模型使得：

```
Loss = -log σ(R(chosen) - R(rejected))
```

```python
# src/post_training/reward_train.py

def bradley_terry_loss(chosen_rewards, rejected_rewards):
    return -F.logsigmoid(chosen_rewards - rejected_rewards).mean()
```

**为什么取负 log？**

- `R(chosen) >> R(rejected)` → `σ(大正数) ≈ 1` → `-log(1) ≈ 0` → loss 小 ✓
- `R(chosen) << R(rejected)` → `σ(大负数) ≈ 0` → `-log(0) → ∞` → loss 大 ✗
- `R(chosen) ≈ R(rejected)` → `σ(0) = 0.5` → `-log(0.5) ≈ 0.69` → 中等 loss

模型被推动让 chosen 的奖励高于 rejected。

### 13.1.4 偏好准确率

```python
def preference_accuracy(chosen_rewards, rejected_rewards):
    return (chosen_rewards > rejected_rewards).float().mean()
```

这是奖励模型的 **headline metric**：

- `acc = 0.5`：随机猜测（模型没学到东西）
- `acc = 0.7`：不错（70% 的情况下能正确判断哪个更好）
- `acc = 1.0`：完美（但可能过拟合）

### 13.1.5 Reward Margin

```python
def reward_margin(chosen_rewards, rejected_rewards):
    return (chosen_rewards - rejected_rewards).mean()
```

辅助诊断指标：chosen 和 rejected 的平均奖励差。

- `margin ≈ 0`：模型无法区分好坏
- `margin > 0`：模型能区分，值越大区分越强
- `margin` 过大：可能过拟合（训练集上 100% 准确，测试集差）

## 13.2 奖励头的架构

### 13.2.1 设计：backbone + 标量头

```python
# src/post_training/reward_model.py

class RewardModel(nn.Module):
    def __init__(self, transformer: Transformer):
        super().__init__()
        self.transformer = transformer
        n_embed = transformer.lm_head.in_features     # 从 backbone 获取维度
        self.reward_head = nn.Linear(n_embed, 1, bias=False)
        nn.init.zeros_(self.reward_head.weight)       # 零初始化
```

**为什么零初始化？**

如果 reward_head 随机初始化，训练初期模型会给所有文本随机的奖励值——`R(chosen) - R(rejected)` 接近随机，梯度方向也是随机的。零初始化确保初始奖励都接近 0，模型从"无差别"开始学习，梯度信号更稳定。

### 13.2.2 forward_hidden：复用 backbone 的隐藏状态

```python
def token_rewards(self, idx):
    """逐 token 的标量奖励 (B, T)"""
    hidden = self.transformer.forward_hidden(idx)    # backbone 最后一层输出
    return self.reward_head(hidden).squeeze(-1)       # 线性映射到标量
```

`forward_hidden` 返回的是 backbone 最后一层 LayerNorm 之后的隐藏状态——正是 `lm_head` 的输入。奖励头用同样的表示，只是映射到 1 维而非 vocab_size 维。

```
Transformer Backbone:
  tok_emb → blocks[0..N] → LayerNorm → hidden (B, T, n_embed)
                                            │
                        ┌────────────────────┤
                        ▼                    ▼
                    lm_head (V)         reward_head (1)
                    用于生成              用于奖励评估
```

### 13.2.3 取最后一个真实 token 的奖励

```python
def forward(self, idx, seq_lengths=None):
    rewards = self.token_rewards(idx)    # (B, T)
    if seq_lengths is None:
        return rewards[:, -1]            # 无 padding：取最后一个
    return gather_last(rewards, seq_lengths)   # 有 padding：取最后真实 token
```

**为什么取最后一个 token？**

这是 InstructGPT 的标准做法。Transformer 的因果注意力使得最后一个 token 的隐藏状态**聚合了整个序列的信息**——它"看到"了所有前面的 token。因此，最后一个 token 的表示最适合用作整个序列的评分。

```
序列:  [t1, t2, t3, t4, t5, PAD, PAD]
seq_len: 5

token rewards: [r1, r2, r3, r4, r5, r_pad1, r_pad2]
                                   ↑
                          gather_last 取 r5（最后真实 token）
```

### 13.2.4 gather_last 的实现

```python
# src/post_training/utils.py

def gather_last(values, seq_lengths):
    """取每行最后一个真实 token 的值"""
    idx = (seq_lengths - 1).clamp(min=0).long()
    return values[torch.arange(values.size(0), device=values.device), idx]
```

向量化地取出每行第 `seq_lengths[i] - 1` 个位置的值。

### 13.2.5 为什么 reward_head 没有 bias

```python
self.reward_head = nn.Linear(n_embed, 1, bias=False)
```

偏置项只会给所有序列加一个常数偏移，对 Bradley-Terry 损失没有影响：

```
(r_chosen + b) - (rejected + b) = r_chosen - r_rejected
```

偏置 `b` 在差值中被消掉了。不加 bias 减少了无意义的参数。

## 13.3 偏好数据准备

### 13.3.1 数据来源

| 数据集 | 来源 | 特点 |
|--------|------|------|
| Anthropic HH-RLHF | 人类标注 | helpful + harmless 偏好，~170k 对 |
| UltraFeedback | LLM 判断 | GPT-4 打分排序后二值化，~60k 对 |

**为什么混合两个来源？**

- HH-RLHF：人类真实偏好，但标注噪声大、偏向安全/无害
- UltraFeedback：LLM 打分更一致，但偏向流畅/详细

混合后模型能学到更鲁棒的偏好判断。

### 13.3.2 HH-RLHF 数据格式

HH-RLHF 的原始格式是一段完整对话文本：

```
chosen:   "Human: What's the best pizza recipe?\n\nAssistant: Here's a great recipe..."
rejected: "Human: What's the best pizza recipe?\n\nAssistant: Just google it."
```

需要从中分离 prompt 和 response：

```python
# scripts/prepare_preference_data.py

_ASSISTANT_MARKER = "\n\nAssistant:"

def _split_hh(text):
    idx = text.rfind(_ASSISTANT_MARKER)    # 找最后一个 Assistant 回复
    if idx == -1:
        return None
    prompt = text[:idx].strip()
    response = text[idx + len(_ASSISTANT_MARKER):].strip()
    if not prompt or not response:
        return None
    return prompt, response
```

**为什么用 `rfind`（最后一个）？** HH-RLHF 的数据可能包含多轮对话。我们取最后一轮的 prompt（所有前面的对话作为上下文）和最终 response。

### 13.3.3 UltraFeedback 数据格式

UltraFeedback 已经结构化好了：

```python
def from_ultrafeedback(max_n, split):
    ds = load_dataset("HuggingFaceH4/ultrafeedback_binarized", split=hf_split)
    for ex in ds:
        prompt = ex["prompt"].strip()
        chosen = ex["chosen"][-1]["content"].strip()      # 取最后一个 turn
        rejected = ex["rejected"][-1]["content"].strip()
```

### 13.3.4 输出格式：JSONL

```jsonl
{"prompt": "What's the best pizza recipe?", "chosen": "Here's a great recipe...", "rejected": "Just google it."}
{"prompt": "Explain quantum computing.", "chosen": "Quantum computing uses qubits...", "rejected": "It's complicated."}
...
```

三个字段：`prompt`、`chosen`（好的回答）、`rejected`（差的回答）。

### 13.3.5 过滤条件

```python
# HH-RLHF
if not c or not r:
    continue
if chosen == rejected:    # 相同回答没有训练价值
    continue

# UltraFeedback
if not prompt or not chosen or not rejected or chosen == rejected:
    continue
```

## 13.4 数据加载器：preference_dataset.py

### 13.4.1 编码和 padding

```python
# data_loader/preference_dataset.py

def _encode_side(prompt, response, max_len):
    ids, mask = encode_chat([
        {"role": "user", "content": prompt},
        {"role": "assistant", "content": response}
    ])
    return ids[:max_len], mask[:max_len]
```

每个 `(prompt, response)` 对通过 `encode_chat` 编码为 token ids + loss mask，然后截断到 `max_len`。

### 13.4.2 _collate：动态 padding

```python
def _collate(rows, max_len, device):
    enc = [(_encode_side(r["prompt"], r["chosen"], max_len),
             _encode_side(r["prompt"], r["rejected"], max_len)) for r in rows]
    L = max(max(len(c[0]), len(j[0])) for c, j in enc)    # batch 内最大长度

    ch_ids, ch_mask, ch_len, rj_ids, rj_mask, rj_len = [], [], [], [], [], []
    for (cids, cmask), (jids, jmask) in enc:
        ch_len.append(len(cids)); rj_len.append(len(jids))
        ch_ids.append(pad(cids, EOT_ID)); ch_mask.append(pad(cmask, 0))
        rj_ids.append(pad(jids, EOT_ID)); rj_mask.append(pad(jmask, 0))
```

**关键设计**：

1. **动态 padding**：每个 batch 内找到最长的序列，其他序列右填充 `EOT_ID`
2. **记录真实长度**：`chosen_len` / `rejected_len` 用于 `gather_last`
3. **mask padding 为 0**：填充位置的 mask=0，确保 DPO 训练时忽略 padding

**为什么用 EOT 填充？**

因果注意力使得 padding 位置不会影响前面的真实 token。而 `gather_last` 根据 `seq_lengths` 只取最后一个真实 token，完全跳过 padding。

### 13.4.3 输出 batch 结构

```python
{
    "chosen_ids":     Tensor(B, L),     # chosen 的 token ids（右填充）
    "chosen_mask":    Tensor(B, L),     # chosen 的 response mask
    "chosen_len":     Tensor(B,),       # chosen 的真实长度
    "rejected_ids":   Tensor(B, L),     # rejected 的 token ids（右填充）
    "rejected_mask":  Tensor(B, L),     # rejected 的 response mask
    "rejected_len":   Tensor(B,),       # rejected 的真实长度
}
```

### 13.4.4 与 SFT 数据加载器的对比

| | SFT | Preference |
|---|---|---|
| 数据格式 | HDF5（预打包） | JSONL（动态编码） |
| 返回类型 | `(tokens, mask, epoch)` | `dict`（6 个 tensor） |
| Padding | 无（已打包为固定长度） | 有（动态右填充） |
| 编码时机 | 离线（prepare 脚本） | 在线（每次取 batch 时） |

**为什么偏好数据不预打包？**

偏好数据的 chosen 和 rejected 长度差异很大，且需要保留 `seq_lengths` 来取最后真实 token 的奖励。预打包会丢失这个信息。

## 13.5 训练脚本：train_reward.py 逐行解析

### 13.5.1 阶段 1：初始化

```python
cfg, _ = parse_config_with_json(RewardConfig, "configs/reward.json")
ctx = ddp_setup(cfg.device)
set_seed(cfg.seed + ctx.rank)
```

### 13.5.2 阶段 2：构建奖励模型

```python
backbone = load_backbone_from_ckpt(cfg, cfg.sft_ckpt, ctx.device)
rm = RewardModel(backbone).to(ctx.device)
rm = ddp_wrap(rm, ctx, find_unused_parameters=True)
```

**`find_unused_parameters=True` 的原因**：

奖励模型只使用 `forward_hidden`（backbone 的隐藏状态）和 `reward_head`，**从不使用 `lm_head`**。这意味着 `lm_head.weight` 永远没有梯度。

DDP 默认要求所有参数在每次 `backward` 中都被使用——如果某个参数没有梯度，DDP 会报错。`find_unused_parameters=True` 告诉 DDP："有些参数确实不会用到，这是正常的。"

```
RewardModel:
  ├── transformer.tok_emb        → 有梯度 ✓
  ├── transformer.blocks[0..N]   → 有梯度 ✓
  ├── transformer.ln_f           → 有梯度 ✓
  ├── transformer.lm_head        → 无梯度 ✗ （不用 lm_head）
  └── reward_head                → 有梯度 ✓
```

### 13.5.3 阶段 3：前向传播

```python
def _pair_rewards(rm, batch, cfg, ctx):
    B = batch["chosen_ids"].size(0)
    ids = torch.cat([batch["chosen_ids"], batch["rejected_ids"]], dim=0)    # (2B, L)
    lens = torch.cat([batch["chosen_len"], batch["rejected_len"]], dim=0)   # (2B,)
    with amp_autocast(cfg.amp_dtype, ctx.device):
        rewards = rm(ids, seq_lengths=lens).float()    # (2B,)
    return rewards[:B], rewards[B:]                     # chosen_rewards, rejected_rewards
```

**关键优化**：chosen 和 rejected 拼接成一个 batch（2B 条），只做一次前向传播。这比分别做两次前向快约 2 倍（GPU 利用率更高）。

```
分开做：
  chosen forward:    (B, L) → backbone → reward_head → (B,)
  rejected forward:  (B, L) → backbone → reward_head → (B,)
  总计：2 次前向传播

合并做：
  concat:            (2B, L) → backbone → reward_head → (2B,)
  总计：1 次前向传播（GPU batch 更大，更高效）
```

### 13.5.4 阶段 4：训练循环

```python
for step in range(total_steps):
    lr = cosine_lr(step, warmup_steps=cfg.warmup_steps,
                   max_steps=total_steps, lr=cfg.lr, min_lr=cfg.lr * 0.1)
    for g in optimizer.param_groups:
        g["lr"] = lr

    batch = next(train_it)
    cr, rr = _pair_rewards(rm, batch, cfg, ctx)
    loss = bradley_terry_loss(cr, rr)

    optimizer.zero_grad(set_to_none=True)
    loss.backward()
    torch.nn.utils.clip_grad_norm_(rm.parameters(), cfg.grad_clip)
    optimizer.step()
```

### 13.5.5 阶段 5：评估

```python
if step > 0 and step % cfg.eval_steps == 0:
    acc, marg = eval_accuracy(rm, cfg, ctx)
    acc, marg = reduce_scalar(acc, ctx), reduce_scalar(marg, ctx)
    if ctx.is_main:
        print(f"  [eval] step {step} | test_acc {acc:.3f} | margin {marg:.3f}")
```

评估函数：

```python
@torch.no_grad()
def eval_accuracy(rm, cfg, ctx, max_batches=100):
    rm.eval()
    it = get_preference_iterator(TEST_PATH, cfg.batch_size, cfg.max_len,
                                  device=ctx.device, ..., shuffle=False, infinite=False)
    acc, marg, n = 0.0, 0.0, 0
    for batch in it:
        cr, rr = _pair_rewards(rm, batch, cfg, ctx)
        acc += preference_accuracy(cr, rr).item()
        marg += reward_margin(cr, rr).item()
        n += 1
        if n >= max_batches:
            break
    rm.train()
    return acc / max(1, n), marg / max(1, n)
```

### 13.5.6 与 SFT 训练循环的对比

| | SFT | Reward Model |
|---|---|---|
| 起始 checkpoint | base_pretrained.pt | sft.pt |
| 模型结构 | Transformer（纯 backbone） | RewardModel（backbone + reward_head） |
| 损失函数 | Masked CE | Bradley-Terry |
| 评估指标 | dev loss + ppl | preference accuracy + margin |
| DDP 特殊处理 | 无 | `find_unused_parameters=True` |
| 数据格式 | HDF5（packed） | JSONL（动态编码） |

## 13.6 偏好准确率指标解读

### 13.6.1 训练过程的典型曲线

```
preference accuracy
│
1.0 ┤
│                              ●───●───●  train_acc
│                        ●──╱
0.8 ┤                  ●╱
│                ●──╱
│           ●──╱
0.6 ┤      ●╱
│    ●──╱
│  ●╱
0.5 ┤─●
│
└──┬──┬──┬──┬──┬──┬──┬──┬──┬──▶ step
   0  50 100 150 200 250 300 350 400
```

三个阶段：
1. **随机阶段**（acc ≈ 0.5）：reward_head 刚初始化，输出接近 0
2. **快速学习**（acc 0.5 → 0.7）：模型学会区分明显的好坏
3. **缓慢收敛**（acc 0.7 → 0.8+）：模型学习更细微的偏好

### 13.6.2 过拟合诊断

```
         train_acc    test_acc
         ────────     ────────
step 50:  0.65         0.62
step 200: 0.78         0.68
step 400: 0.92         0.65    ← 训练集 92% 准确，测试集只有 65%
```

当 `train_acc >> test_acc` 时，模型过拟合了。

**解决方案**：
1. 增加数据量（`--max_per_source`）
2. 增加 weight_decay
3. 减少训练步数（`--epochs`）
4. 早停：监控 test_acc，下降时停止

### 13.6.3 margin 的解读

| margin 范围 | 含义 |
|-------------|------|
| < 0.1 | 模型几乎无法区分好坏 |
| 0.1 - 0.5 | 适度区分（健康范围） |
| 0.5 - 2.0 | 强区分（可能过拟合） |
| > 2.0 | 极端区分（几乎一定过拟合） |

### 13.6.4 Reward Model 在 RLHF 中的角色

```python
# PPO 中使用 reward model 打分
reward = reward_model(generated_tokens, seq_lengths=gen_lengths)
# reward 作为 PPO 的奖励信号，指导策略更新
```

如果 reward model 不准（accuracy < 0.6），PPO 收到的信号噪声太大，可能：
- 训练不稳定（奖励波动大）
- 策略被误导（reward hacking：找到 reward model 的漏洞获得高分但实际质量差）

## 13.7 max_len 与 context_length 对齐

### 13.7.1 问题

`max_len` 控制偏好数据每侧（chosen/rejected）的最大 token 数。这个值**必须等于**模型的 `context_length`。

```python
# configs/reward.json
{
  "max_len": 256,     ← 必须等于 context_length
  ...
}

# configs/base.json
{
  "context_length": 256,
  ...
}
```

### 13.7.2 不匹配的后果

| 场景 | 后果 |
|------|------|
| max_len > context_length | 截断后仍然超过模型的 position embedding → IndexError |
| max_len < context_length | 不报错，但截断过多导致信息丢失 |

### 13.7.3 为什么不是自动继承

`RewardConfig` 从 `BaseModelConfig` 继承了 `context_length`，但 `max_len` 是独立的字段：

```python
@dataclass
class RewardConfig(BaseModelConfig):
    max_len: int = 768      # 独立字段，默认 768
    # context_length 继承自 BaseModelConfig，默认 1024
```

默认值 768 是 dataclass 的"生产环境"值（对应 400M 大模型）。但实际使用时通过 `configs/reward.json` 覆盖为 256（匹配小模型的 context_length）。

## 13.8 完整运行指南

### 13.8.1 准备偏好数据

```bash
export HF_HOME=/ephemeral/hf_cache
export PYTHONPATH=.

# 正式运行
python scripts/prepare_preference_data.py \
    --source both --max_per_source 40000 --out_dir /ephemeral/data

# 快速测试（少量数据）
python scripts/prepare_preference_data.py \
    --source hh --max_per_source 100 --out_dir /ephemeral/data
```

预期输出：

```
Loading Anthropic/hh-rlhf [train] ...
Loading ultrafeedback_binarized [train] ...
  wrote 78234 pairs -> /ephemeral/data/preferences.jsonl
  wrote 3912 pairs -> /ephemeral/data/preferences_test.jsonl
```

### 13.8.2 训练奖励模型

```bash
# 单 GPU
PYTHONPATH=. python scripts/train_reward.py

# 双 GPU（DDP）
PYTHONPATH=. torchrun --standalone --nproc_per_node=2 scripts/train_reward.py
```

预期输出：

```
Reward model from /ephemeral/ckpts/sft.pt | 78234 pairs | total_steps=4889
step 0/4889 | loss 0.6931 | train_acc 0.500 | lr 2.00e-07 | 1.5s/20
step 20/4889 | loss 0.5832 | train_acc 0.625 | lr 1.00e-05 | 1.2s/20
  [eval] step 200 | test_acc 0.653 | margin 0.234
step 200/4889 | loss 0.4123 | train_acc 0.750 | lr 9.67e-06 | 1.1s/20
...
Done RM. test_acc 0.687 margin 0.312 -> /ephemeral/ckpts/reward.pt
```

### 13.8.3 验证 checkpoint

```python
import torch
ck = torch.load("/ephemeral/ckpts/reward.pt", weights_only=False)
print("stage:", ck["stage"])            # "reward"
print("keys:", len(ck["model_state_dict"]))  # backbone keys + reward_head
print("metrics:", ck["metrics"])        # {"test_acc": 0.687, "test_margin": 0.312}
# 注意：reward_head.weight 在 state_dict 中
assert "reward_head.weight" in ck["model_state_dict"]
```

## 13.9 加载训练好的 Reward Model

### 13.9.1 load_reward_model

```python
# src/post_training/reward_model.py

def load_reward_model(cfg, ckpt_path, device):
    backbone = build_model_from_config(cfg)
    rm = RewardModel(backbone)
    ck = torch.load(ckpt_path, map_location="cpu", weights_only=False)
    state = ck["model_state_dict"] if "model_state_dict" in ck else ck
    # 清理 DDP 前缀
    if any(k.startswith("module.") for k in state):
        state = {k.removeprefix("module."): v for k, v in state.items()}
    rm.load_state_dict(state, strict=True)    # ← strict=True！
    rm.to(device).eval()
    for p in rm.parameters():
        p.requires_grad_(False)               # 冻结（PPO 中 RM 不训练）
    return rm
```

**`strict=True` 的原因**：

与 `load_backbone_from_ckpt` 的 `strict=False` 不同，这里加载的是完整的 RewardModel（backbone + reward_head），所有 key 都应该精确匹配。如果有 missing key，说明 checkpoint 损坏了。

### 13.9.2 PPO 中的使用方式

```python
# PPO 使用 reward model 打分
rm = load_reward_model(cfg, cfg.reward_ckpt, device)
# rm 被冻结，只做推理
reward = rm(generated_tokens, seq_lengths=gen_lengths)    # (B,)
```

## 13.10 本章小结

### 奖励模型全景

```
SFT backbone（冻结前几层？→ 不，全部可训练）
    │
    ▼ + reward_head (Linear(n_embed, 1), bias=False, 零初始化)
RewardModel
    │
    ▼ 训练数据：(prompt, chosen, rejected) 偏好对
    ▼ 损失函数：-log σ(R(chosen) - R(rejected))
    ▼ 评估指标：preference accuracy + reward margin
    │
    ▼ 输出：reward.pt → 为 PPO 提供奖励信号
```

### 关键设计决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 取哪个 token 的 reward | 最后一个真实 token | InstructGPT 惯例，聚合全序列信息 |
| reward_head 是否有 bias | 无 | 对 BT 损失无影响 |
| reward_head 初始化 | 零初始化 | 稳定训练初期 |
| chosen/rejected 前向 | 合并一次前向 | 2 倍速度 |
| DDP 的 unused params | True | lm_head 不参与前向 |
| 评估指标 | accuracy + margin | accuracy 直观，margin 诊断过拟合 |

### 超参数推荐

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| lr | 1e-5 | 和 SFT 相同（微调） |
| batch_size | 8 | 8 对偏好（16 条序列通过模型） |
| epochs | 1 | 偏好数据容易过拟合 |
| warmup_steps | 50 | 短 warmup |
| grad_clip | 1.0 | 标准 |
| max_len | = context_length | 必须对齐 |

---

## 练习

**练习 1：手动计算 Bradley-Terry Loss**

给定：
- `R(chosen) = [1.5, 2.0, 0.5]`
- `R(rejected) = [0.5, 1.0, 1.5]`

计算：
1. 每对的 `σ(R_chosen - R_rejected)`
2. 每对的 `-log σ(...)`
3. 平均 loss
4. preference accuracy

（提示：`σ(1.0) ≈ 0.731`, `σ(-1.0) ≈ 0.269`）

**练习 2：数据质量检查**

写一个脚本检查 `preferences.jsonl` 的质量：
1. 总共有多少对偏好？
2. chosen 和 rejected 的平均长度分别是多少？
3. 有多少对 chosen == rejected（应该为 0）？
4. 打印前 3 对，看看内容是否合理

**练习 3：预测过拟合行为**

假设你用 1000 条偏好数据训练 reward model，学习率设为 1e-3（10 倍于默认值）。预测：
1. train_acc 的变化趋势
2. test_acc 的变化趋势
3. margin 的变化趋势
4. 这对后续 PPO 训练有什么影响？

**练习 4：架构对比**

画出以下两个设计的参数量和前向传播差异：
- **Reward Model**：backbone + reward_head
- **Value Head**（PPO 用）：backbone + value_head

它们共享什么？不同在哪里？为什么不能共享同一个 head？
