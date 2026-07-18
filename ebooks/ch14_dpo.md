# 第 14 章：DPO 与变体

> **本章目标**：理解 DPO 如何跳过显式 Reward Model、用 log-prob 差作为隐式奖励。掌握 Policy + Frozen Ref 双模型架构、DPO Loss 的推导与实现，以及 ORPO、KTO 两种变体。

## 14.0 本章路线图

上一章训练了一个显式奖励模型。本章介绍一种更简洁的方法——**DPO（Direct Preference Optimization）**：直接用偏好数据优化策略，无需奖励模型。

```
本章覆盖的链路

                 ┌─ DPO（有 reference model）
偏好数据 ──────▶ ├─ ORPO（无 reference model，SFT+对齐一步完成）
                 └─ KTO（从 unpaired 信号学习）
```

与上一章的对比：

```
传统 RLHF 流程（第 13 章 + 第 15 章）：
  SFT → Reward Model → PPO（RL 循环）

DPO 流程（本章）：
  SFT → DPO（直接优化偏好）
```

DPO 的优势：**省去了 Reward Model 和 RL 循环**，训练代码简单得多。

## 14.1 DPO 的核心直觉

### 14.1.1 从显式奖励到隐式奖励

Reward Model 的训练：

```
R(chosen) > R(rejected)     ← 显式标量奖励
```

DPO 的关键洞察：**模型对文本的 log-prob 本身就是一种隐式奖励**。

```
policy 对 chosen 的 log-prob 高  →  policy "喜欢" chosen
policy 对 rejected 的 log-prob 低 →  policy "不喜欢" rejected
```

但直接用 log-prob 有个问题：policy 训练过程中 log-prob 会不断变化，我们需要一个**稳定的参考点**。

### 14.1.2 Reference Model：稳定的参考

```python
# 训练开始前，冻结一份 policy 的副本
ref = make_frozen_copy(policy)    # 权重永远不变
```

DPO 的"奖励"是 policy 相对于 reference 的 log-prob 变化：

```
隐式奖励 = β × (log π(y|x) - log π_ref(y|x))

其中：
  π   = 当前 policy（可训练）
  π_ref = 冻结的 reference model
  β   = 温度参数（控制优化幅度）
```

直觉：

- 如果 policy 给 chosen 的 log-prob **比 reference 更高**，说明 policy 在"往好方向走"
- 如果 policy 给 rejected 的 log-prob **比 reference 更低**，说明 policy 在"避开坏方向"

### 14.1.3 DPO 的 Bradley-Terry 类比

Reward Model 的损失：

```
L_RM = -log σ(R(chosen) - R(rejected))
```

DPO 把 `R(y)` 替换为隐式奖励 `β × (log π(y|x) - log π_ref(y|x))`：

```
L_DPO = -log σ(β × [(log π(chosen) - log π_ref(chosen)) - (log π(rejected) - log π_ref(rejected))])
```

展开后：

```
L_DPO = -log σ(β × [(log π(chosen) - log π(rejected)) - (log π_ref(chosen) - log π_ref(rejected))])
```

两项之差：policy 的偏好 vs reference 的偏好。模型被训练使 policy 的偏好更强。

## 14.2 DPO Loss 详解

### 14.2.1 代码实现

```python
# src/post_training/dpo.py

def dpo_loss(
    policy_chosen_logps,      # (B,) policy 对 chosen 的总 log-prob
    policy_rejected_logps,    # (B,) policy 对 rejected 的总 log-prob
    ref_chosen_logps,         # (B,) reference 对 chosen 的总 log-prob
    ref_rejected_logps,       # (B,) reference 对 rejected 的总 log-prob
    beta=0.1,
):
    # Policy 的偏好强度
    pi_logratios = policy_chosen_logps - policy_rejected_logps
    # Reference 的偏好强度
    ref_logratios = ref_chosen_logps - ref_rejected_logps
    # Policy 相对于 Reference 的偏好提升
    logits = pi_logratios - ref_logratios
    # 类 BT 损失
    loss = -F.logsigmoid(beta * logits).mean()

    # 隐式奖励（诊断用，不参与训练）
    chosen_reward = beta * (policy_chosen_logps - ref_chosen_logps).detach()
    rejected_reward = beta * (policy_rejected_logps - ref_rejected_logps).detach()
    return loss, chosen_reward, rejected_reward
```

### 14.2.2 逐步拆解

```python
# Step 1: Policy 的偏好差
pi_logratios = log π(chosen) - log π(rejected)
#   正值 → policy 更喜欢 chosen
#   负值 → policy 更喜欢 rejected（需要修正）

# Step 2: Reference 的偏好差（基准线）
ref_logratios = log π_ref(chosen) - log π_ref(rejected)
#   SFT 模型对 chosen 和 rejected 的初始偏好

# Step 3: 相对提升
logits = pi_logratios - ref_logratios
#   正值 → policy 比 reference 更喜欢 chosen
#   训练目标：让 logits 更大

# Step 4: BT 损失
loss = -log σ(β × logits)
#   logits 大 → σ 接近 1 → loss 小 ✓
#   logits 小 → σ 接近 0 → loss 大 ✗
```

### 14.2.3 β 的作用

β 控制 policy 偏离 reference 的幅度：

| β | 效果 | 适用场景 |
|---|------|---------|
| 0.01 | 允许大幅偏离 | 需要强对齐 |
| 0.1（默认） | 适度偏离 | 大多数情况 |
| 1.0 | 几乎不偏离 | 保守微调 |

β 太小：policy 偏离 reference 太远，可能遗忘 SFT 学到的能力（catastrophic forgetting）。
β 太大：policy 几乎不变，对齐效果弱。

### 14.2.4 隐式奖励

```python
chosen_reward = beta * (policy_chosen_logps - ref_chosen_logps)
rejected_reward = beta * (policy_rejected_logps - ref_rejected_logps)
```

这些不是真正的"奖励"，而是 log-prob 的变化量。但它们的**差**等价于 DPO 损失中的 logits，所以可以用类似 Reward Model 的 accuracy 指标来评估：

```python
def implicit_accuracy(chosen_reward, rejected_reward):
    return (chosen_reward > rejected_reward).float().mean()
```

## 14.3 Policy + Frozen Ref 双模型架构

### 14.3.1 显存布局

```
GPU 显存（80GB H100）
┌─────────────────────────────┐
│  Policy（可训练）             │ ~500MB（~400M 参数 × 2B bf16）
│  ├── tok_emb                 │
│  ├── blocks[0..N]            │
│  ├── lm_head                 │
│  └── 梯度 + 优化器状态       │ ~1.5GB
├─────────────────────────────┤
│  Reference（冻结）            │ ~500MB
│  ├── tok_emb                 │
│  ├── blocks[0..N]            │
│  ├── lm_head                 │
│  └── 无梯度                  │
├─────────────────────────────┤
│  Activation + Batch          │ ~2-4GB
└─────────────────────────────┘
总计 ~5-7GB（小模型），大模型需 20-40GB
```

### 14.3.2 make_frozen_copy

```python
# src/post_training/utils.py

def make_frozen_copy(model, device=None):
    ref = copy.deepcopy(unwrap(model))    # 深拷贝
    if device is not None:
        ref = ref.to(device)
    ref.eval()                             # 推理模式
    for p in ref.parameters():
        p.requires_grad_(False)            # 冻结所有参数
    return ref
```

### 14.3.3 前向传播策略

```python
# train_dpo.py

def _compute_losses(policy, ref, batch, cfg, ctx):
    B = batch["chosen_ids"].size(0)
    ids = torch.cat([batch["chosen_ids"], batch["rejected_ids"]], dim=0)    # (2B, L)
    mask = torch.cat([batch["chosen_mask"], batch["rejected_mask"]], dim=0)

    # Policy 前向（需要梯度）
    with amp_autocast(cfg.amp_dtype, ctx.device):
        psum, pn = _logps(policy, ids, mask, requires_grad=True)
    pc, pr, ncn, nrn = psum[:B], psum[B:], pn[:B], pn[B:]

    # Reference 前向（不需要梯度）
    with torch.no_grad(), amp_autocast(cfg.amp_dtype, ctx.device):
        rsum, _ = _logps(ref, ids, mask, requires_grad=False)
    rc, rr = rsum[:B], rsum[B:]

    return dpo_loss(pc, pr, rc, rr, beta=cfg.beta)
```

**两次前向传播**：

1. Policy：`requires_grad=True`，2B 条序列，计算梯度
2. Reference：`torch.no_grad()`，2B 条序列，只计算 log-prob

### 14.3.4 sequence_logprobs：序列级 log-prob

```python
# src/post_training/rollout.py

def sequence_logprobs(model, sequences, response_mask, *, temperature=1.0, requires_grad=True):
    """返回 (sum_logprob, n_tokens) 各 shape (B,)"""
    lp, mask = compute_logprobs(model, sequences, response_mask,
                                 temperature=temperature, requires_grad=requires_grad)
    m = mask.to(lp.dtype)
    return (lp * m).sum(dim=-1), m.sum(dim=-1)
```

`compute_logprobs` 做 teacher-forced 前向，返回每个 target token 的 log-prob。`sequence_logprobs` 在 response token 上求和，得到序列级的总 log-prob。

```
序列: [prompt_1, ..., prompt_P, resp_1, ..., resp_G]
mask: [0, 0, ..., 0, 1, 1, ..., 1]

log-prob: [lp_1, ..., lp_{P+G-1}]    (T-1 个，移位后)
response mask (shifted): [0, ..., 0, 1, 1, ..., 1]

sum_logprob = Σ(lp_i × mask_i)    只在 response token 上求和
n_tokens = Σ(mask_i)              response 的 token 数
```

## 14.4 ORPO：无参考模型的 SFT+对齐

### 14.4.1 核心思想

ORPO（Odds Ratio Preference Optimization）完全不需要 reference model：

```
DPO:   SFT → 冻结 ref → DPO 训练      （两步）
ORPO:  直接从 SFT checkpoint 训练       （一步，无需 ref）
```

ORPO 把 SFT 的 NLL 损失和对齐损失合并为一个：

```
L_ORPO = NLL(chosen) + λ × OR_loss

其中 OR_loss = -log σ(log_odds(chosen) - log_odds(rejected))
     log_odds(x) = mean_logp(x) - log(1 - exp(mean_logp(x)))
```

### 14.4.2 代码实现

```python
# src/post_training/dpo.py

def orpo_loss(policy_chosen_logps, policy_rejected_logps,
              chosen_n_tokens, rejected_n_tokens, orpo_lambda=1.0):
    # 转为 per-token mean log-prob
    chosen_mean = policy_chosen_logps / chosen_n_tokens.clamp(min=1)
    rejected_mean = policy_rejected_logps / rejected_n_tokens.clamp(min=1)

    # log-odds: log(p / (1-p))，其中 p = exp(mean_logp)
    log_odds = (chosen_mean - _log1mexp(chosen_mean)) \
             - (rejected_mean - _log1mexp(rejected_mean))

    # Odds Ratio 偏好损失
    or_loss = -F.logsigmoid(log_odds).mean()

    # NLL：训练模型生成 chosen（替代 SFT 的损失）
    nll = -chosen_mean.mean()

    loss = nll + orpo_lambda * or_loss
    return loss, chosen_mean.detach(), rejected_mean.detach()
```

### 14.4.3 log-odds 的直觉

`log_odds = log(p/(1-p))` 是概率论中的对数几率：

- `p = 0.9` → `log_odds ≈ 2.2`（很有信心）
- `p = 0.5` → `log_odds = 0`（50/50）
- `p = 0.1` → `log_odds ≈ -2.2`（很没信心）

ORPO 希望 chosen 的 log-odds 高于 rejected 的 log-odds。

### 14.4.4 ORPO vs DPO 对比

| | DPO | ORPO |
|---|---|---|
| Reference model | 需要（冻结副本） | 不需要 |
| 显存开销 | 2 份模型 | 1 份模型 |
| 损失函数 | 纯偏好损失 | NLL + 偏好损失 |
| 适用场景 | SFT 质量高，只需对齐 | SFT 和对齐一起学 |
| 学习率 | 5e-7（非常保守） | 1e-5（可以更激进） |

### 14.4.5 训练脚本中的分支

```python
# train_dpo.py

policy = load_backbone_from_ckpt(cfg, cfg.sft_ckpt, ctx.device)
ref = make_frozen_copy(policy) if cfg.loss_type != "orpo" else None  # ORPO 不需要 ref
```

ORPO 不需要 reference，省了 `make_frozen_copy` 的显存开销。

## 14.5 KTO：从 Unpaired 信号学习

### 14.5.1 核心思想

KTO（Kahneman-Tversky Optimization）的灵感来自**前景理论**（Prospect Theory）：人类对"损失"比"收益"更敏感。

DPO 和 ORPO 都需要 **paired** 数据（同一个 prompt 的 chosen + rejected）。KTO 理论上可以只用 **unpaired** 数据：每条样本只需标注"好"或"坏"。

但在本项目的实现中，KTO 仍从 paired 数据训练（chosen=desirable, rejected=undesirable），利用了 batch 的统计量作为 KL 基线。

### 14.5.2 代码实现

```python
# src/post_training/dpo.py

def kto_loss(policy_chosen_logps, policy_rejected_logps,
             ref_chosen_logps, ref_rejected_logps,
             beta=0.1, desirable_weight=1.0, undesirable_weight=1.0):
    # Policy 相对于 Reference 的 log-ratio
    chosen_logratio = policy_chosen_logps - ref_chosen_logps
    rejected_logratio = policy_rejected_logps - ref_rejected_logps

    # KL 基线：batch 内的平均 log-ratio（作为"参照点"）
    kl = torch.cat([chosen_logratio, rejected_logratio]).mean().clamp(min=0).detach()

    # Desirable loss: 让 chosen 的 log-ratio 高于 KL 基线
    chosen_losses = 1.0 - torch.sigmoid(beta * (chosen_logratio - kl))

    # Undesirable loss: 让 rejected 的 log-ratio 低于 KL 基线
    rejected_losses = 1.0 - torch.sigmoid(beta * (kl - rejected_logratio))

    loss = (desirable_weight * chosen_losses).mean() \
         + (undesirable_weight * rejected_losses).mean()
    return loss, ...
```

### 14.5.3 KTO vs DPO 的直觉对比

```
DPO:
  直接比较 chosen vs rejected 的 log-ratio
  loss = -log σ(chosen_logratio - rejected_logratio)

KTO:
  分别让 chosen 高于基线、rejected 低于基线
  loss = (1 - σ(chosen_logratio - KL)) + (1 - σ(KL - rejected_logratio))
```

DPO 关注的是**相对关系**（chosen 比 rejected 好多少），KTO 关注的是**绝对关系**（chosen 和 rejected 各自相对基线的位置）。

## 14.6 训练脚本：train_dpo.py 逐行解析

### 14.6.1 配置与初始化

```python
cfg, _ = parse_config_with_json(DPOConfig, "configs/dpo.json")
ctx = ddp_setup(cfg.device)
set_seed(cfg.seed + ctx.rank)

policy = load_backbone_from_ckpt(cfg, cfg.sft_ckpt, ctx.device)
ref = make_frozen_copy(policy) if cfg.loss_type != "orpo" else None
policy = ddp_wrap(policy, ctx)
optimizer = configure_optimizer(unwrap(policy), cfg.lr, cfg.weight_decay)
```

**注意**：只有 `policy` 被 DDP 包装。`ref` 是冻结的，不需要分布式同步。

### 14.6.2 损失类型选择

```python
# configs/dpo.json
{
  "loss_type": "dpo",     // "dpo" | "orpo" | "kto"
  "beta": 0.1,            // DPO/KTO 的温度
  "orpo_lambda": 1.0,     // ORPO 的权重
  ...
}
```

通过 `--loss_type` 切换算法：

```bash
# DPO
PYTHONPATH=. python scripts/train_dpo.py --loss_type dpo --beta 0.1

# ORPO
PYTHONPATH=. python scripts/train_dpo.py --loss_type orpo --orpo_lambda 1.0

# KTO
PYTHONPATH=. python scripts/train_dpo.py --loss_type kto --beta 0.1
```

### 14.6.3 _compute_losses 的分流

```python
def _compute_losses(policy, ref, batch, cfg, ctx):
    B = batch["chosen_ids"].size(0)
    ids = torch.cat([batch["chosen_ids"], batch["rejected_ids"]], dim=0)
    mask = torch.cat([batch["chosen_mask"], batch["rejected_mask"]], dim=0)

    # Policy log-probs（需要梯度）
    with amp_autocast(cfg.amp_dtype, ctx.device):
        psum, pn = _logps(policy, ids, mask, requires_grad=True)
    pc, pr, ncn, nrn = psum[:B], psum[B:], pn[:B], pn[B:]

    # ORPO 不需要 reference
    if cfg.loss_type == "orpo":
        return orpo_loss(pc, pr, ncn, nrn, orpo_lambda=cfg.orpo_lambda)

    # DPO/KTO 需要 reference log-probs
    with torch.no_grad(), amp_autocast(cfg.amp_dtype, ctx.device):
        rsum, _ = _logps(ref, ids, mask, requires_grad=False)
    rc, rr = rsum[:B], rsum[B:]

    if cfg.loss_type == "kto":
        return kto_loss(pc, pr, rc, rr, beta=cfg.beta)
    return dpo_loss(pc, pr, rc, rr, beta=cfg.beta)
```

### 14.6.4 训练循环

```python
for step in range(total_steps):
    lr = cosine_lr(step, warmup_steps=cfg.warmup_steps,
                   max_steps=total_steps, lr=cfg.lr, min_lr=cfg.lr * 0.1)

    batch = next(train_it)
    loss, cr, rr = _compute_losses(policy, ref, batch, cfg, ctx)
    optimizer.zero_grad(set_to_none=True)
    loss.backward()
    torch.nn.utils.clip_grad_norm_(policy.parameters(), cfg.grad_clip)
    optimizer.step()
```

结构上与 reward model 训练类似——**没有 rollout**（DPO 不做自回归生成），只做 teacher-forced log-prob 计算。

### 14.6.5 日志与评估

```python
if ctx.is_main and step % 20 == 0:
    acc = implicit_accuracy(cr, rr).item()
    print(f"step {step}/{total_steps} | loss {loss.item():.4f} | acc {acc:.3f} | "
          f"r_chosen {cr.mean().item():.3f} r_rejected {rr.mean().item():.3f}")
```

日志包含：
- `loss`：DPO/ORPO/KTO 损失
- `acc`：隐式奖励准确率
- `r_chosen` / `r_rejected`：chosen/rejected 的隐式奖励均值

### 14.6.6 DPO 与 Reward Model 训练的对比

| | Reward Model | DPO |
|---|---|---|
| 模型数量 | 1（RM） | 2（policy + ref） |
| 显存 | 1 份模型 | 2 份模型 |
| 前向传播 | 1 次（合并 chosen+rejected） | 2 次（policy + ref） |
| 输出 | 标量奖励值 | 无显式奖励 |
| 评估指标 | preference accuracy | implicit accuracy |
| 下游使用 | PPO 的奖励信号 | 直接作为对齐后的策略 |

## 14.7 隐式奖励准确率

### 14.7.1 含义

隐式奖励准确率和 reward model 的 preference accuracy **概念相同**：

- RM accuracy: reward model 判断 chosen > rejected 的比例
- Implicit accuracy: DPO 的隐式奖励判断 chosen > rejected 的比例

### 14.7.2 训练过程的典型曲线

```
implicit accuracy
│
0.9 ┤
│                         ●──●──●  train_acc
│                    ●──╱
0.7 ┤              ●──╱
│            ●──╱
│       ●──╱
0.5 ┤──●──╱
│
└──┬──┬──┬──┬──┬──┬──┬──┬──▶ step
   0  50 100 150 200 250 300 350
```

与 reward model 的曲线类似，但通常收敛更快——因为 DPO 直接优化 policy，不需要先学一个独立的 reward head。

### 14.7.3 解读注意事项

1. **训练 acc 高不代表对齐好**：acc=0.9 只说明 policy 在训练集上能区分 chosen/rejected
2. **关注 test acc**：train-test gap 过大说明过拟合
3. **隐式奖励的量级**：`r_chosen - r_rejected` 的差值应该在 0.1-1.0 范围，太小说明优化不够，太大可能过拟合

## 14.8 超参数指南

### 14.8.1 DPO 的超参数

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| lr | 5e-7 | 非常保守（policy 已经 SFT 过） |
| beta | 0.1 | 控制偏离 ref 的幅度 |
| batch_size | 8 | 8 对偏好 |
| epochs | 1 | 偏好数据容易过拟合 |
| warmup_steps | 50 | 短 warmup |
| max_len | = context_length | 必须对齐 |

### 14.8.2 三种算法的超参数对比

| | DPO | ORPO | KTO |
|---|---|---|---|
| lr | 5e-7 | 8e-6 | 5e-7 |
| beta | 0.1 | N/A | 0.1 |
| orpo_lambda | N/A | 1.0 | N/A |
| ref model | 需要 | 不需要 | 需要 |

ORPO 可以用更高的学习率，因为它同时做 SFT 和对齐。

### 14.8.3 β 敏感性实验

β 是 DPO 最关键的超参数：

```
β=0.01: policy 大幅偏离 ref → 可能遗忘 SFT 能力
β=0.1:  适度偏离 → 通常最好
β=1.0:  几乎不变 → 对齐效果弱
```

## 14.9 完整运行指南

### 14.9.1 前提条件

```bash
# 需要 SFT checkpoint 和偏好数据
ls /ephemeral/ckpts/sft.pt              # SFT 模型
ls /ephemeral/data/preferences.jsonl    # 偏好数据
ls /ephemeral/data/preferences_test.jsonl
```

### 14.9.2 训练 DPO

```bash
# 单 GPU
PYTHONPATH=. python scripts/train_dpo.py --loss_type dpo --beta 0.1

# 双 GPU（DDP）
PYTHONPATH=. torchrun --standalone --nproc_per_node=2 scripts/train_dpo.py --loss_type dpo
```

预期输出：

```
DPO[dpo] from /ephemeral/ckpts/sft.pt | 78234 pairs | total_steps=4889 | beta=0.1
step 0/4889 | loss 0.6931 | acc 0.500 | r_chosen 0.000 r_rejected 0.000 | 2.1s/20
step 20/4889 | loss 0.5123 | acc 0.688 | r_chosen 0.042 r_rejected -0.031 | 1.8s/20
  [eval] step 200 | test_acc 0.645 | margin 0.123
...
Done DPO[dpo]. test_acc 0.672 margin 0.156 -> /ephemeral/ckpts/dpo.pt
```

### 14.9.3 训练 ORPO

```bash
PYTHONPATH=. python scripts/train_dpo.py --loss_type orpo --orpo_lambda 1.0 --lr 8e-6
```

### 14.9.4 训练 KTO

```bash
PYTHONPATH=. python scripts/train_dpo.py --loss_type kto --beta 0.1
```

### 14.9.5 Smoke 测试

```bash
# 快速验证（CPU，几秒完成）
PYTHONPATH=. python scripts/train_dpo.py --config configs/smoke/dpo.json --loss_type dpo
```

## 14.10 DPO 在 RLHF 流程中的位置

### 14.10.1 两条路线

```
路线 A（经典 RLHF）：
  SFT → Reward Model → PPO
  优点：Reward Model 可复用（PPO + 评估）
  缺点：训练复杂（4 个模型在显存中）

路线 B（DPO 简化路线）：
  SFT → DPO → GRPO（可选）
  优点：简单，不需要 Reward Model
  缺点：无显式奖励信号（难做 reward shaping）
```

### 14.10.2 DPO 后的下一步

DPO 输出的 checkpoint 可以：
1. **直接部署**：作为对齐后的对话模型使用
2. **GRPO 微调**：用验证器奖励进一步提升数学推理能力

```bash
# DPO 后用 GRPO 进一步提升
PYTHONPATH=. python scripts/train_grpo.py --sft_ckpt /ephemeral/ckpts/dpo.pt
```

## 14.11 本章小结

### 三种算法对比

| | DPO | ORPO | KTO |
|---|---|---|---|
| 全称 | Direct Preference Optimization | Odds Ratio Preference Optimization | Kahneman-Tversky Optimization |
| Reference model | 需要 | 不需要 | 需要 |
| 数据要求 | paired | paired | unpaired（本实现用 paired） |
| 损失函数 | BT on log-ratio | NLL + OR loss | Prospect-theory loss |
| 显存 | 2× model | 1× model | 2× model |
| 典型 lr | 5e-7 | 8e-6 | 5e-7 |
| 典型 β/λ | β=0.1 | λ=1.0 | β=0.1 |

### 核心代码流

```
train_dpo.py
├── 加载 SFT backbone → policy
├── make_frozen_copy → ref（ORPO 跳过）
├── _compute_losses:
│   ├── sequence_logprobs(policy, ...) → 有梯度
│   ├── sequence_logprobs(ref, ...) → 无梯度
│   └── dpo_loss / orpo_loss / kto_loss
├── loss.backward() + optimizer.step()
└── 评估 implicit_accuracy
```

### 关键教训

1. **β 控制对齐强度**：太小遗忘，太大保守
2. **Reference model 是锚点**：防止 policy 失控
3. **隐式奖励准确率**：类似 RM 的 preference accuracy，但基于 log-prob
4. **ORPO 省显存**：不需要 ref，但需要 NLL 损失来保持生成能力
5. **DPO 不做 rollout**：只做 teacher-forced log-prob，比 PPO 简单得多

---

## 练习

**练习 1：手动计算 DPO Loss**

给定：
- `policy_chosen_logps = [-10, -8, -12]`
- `policy_rejected_logps = [-12, -10, -11]`
- `ref_chosen_logps = [-11, -9, -12]`
- `ref_rejected_logps = [-11, -10, -12]`
- `beta = 0.1`

计算每对的：
1. `pi_logratios`
2. `ref_logratios`
3. `logits = pi - ref`
4. 每对的 DPO loss
5. 隐式奖励和 implicit accuracy

**练习 2：对比三种算法的显存**

假设模型有 400M 参数（bf16），估算以下场景的显存占用：

1. DPO（policy + ref + 梯度 + 优化器状态）
2. ORPO（policy + 梯度 + 优化器状态）
3. Reward Model（backbone + reward_head + 梯度 + 优化器状态）
4. PPO（policy + ref + value_head + old_policy + ...）

哪个最省显存？哪个最贵？

**练习 3：β 实验**

分别用 `beta=0.01`、`beta=0.1`、`beta=1.0` 训练 DPO（smoke 配置），对比：
1. 隐式奖励准确率
2. 生成质量（用 chat.py 测试几个问题）
3. 哪种 β 最好？

**练习 4：ORPO 的优势**

为什么 ORPO 可以用更高的学习率（8e-6 vs DPO 的 5e-7）？

提示：考虑 ORPO 的 NLL 损失对 policy 的约束作用。
