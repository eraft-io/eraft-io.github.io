# 第 16 章：GRPO——DeepSeek-R1 风格推理增强

> **本章目标**：理解 GRPO 如何通过 Group Sampling + Group-Relative Advantages 完全去掉 Value Network，掌握 K3 KL 估计器和 Curriculum Learning 的设计，逐行解析训练脚本。

## 16.0 本章路线图

上一章的 PPO 需要 4 个模型副本（policy + ref + reward model + value head），是后训练中最复杂的阶段。GRPO（Group Relative Policy Optimization）是 DeepSeek-R1 提出的简化方案——**扔掉 Value Network，用组内相对比较替代学习到的价值函数**。

```
PPO 的显存布局（4 个模型）：
  policy + ref + reward_model + value_head

GRPO 的显存布局（2 个模型）：
  policy + ref
```

GRPO 的核心循环：

```
1. Group Sampling：每个 prompt 采样 G 个回答
2. Scoring：验证器打分
3. Group Advantages：(r - mean) / std
4. Clipped Update：token 级 clipping + K3 KL 惩罚
```

## 16.1 GRPO 的核心创新：扔掉 Value Network

### 16.1.1 PPO 为什么需要 Value Network

PPO 的 GAE 需要一个价值函数 `V(s_t)` 来估计"从这个状态出发能获得多少回报"。这个价值函数是训练出来的——一个额外的 Value Head 加在 backbone 上。

训练 Value Head 的问题：
1. **显存开销**：额外的参数 + 梯度 + 优化器状态
2. **训练不稳定**：Value 学不好 → GAE 估计不准 → Policy 更新方向错误
3. **代码复杂度**：Actor-Critic 的交互增加了调试难度

### 16.1.2 GRPO 的替代方案：组内相对比较

GRPO 的关键洞察：**对于同一个 prompt 的多个回答，它们之间的相对好坏就是最好的优势估计**。

```
PPO 的 advantage：
  A(s, a) = R(s, a) - V(s)        ← V 是学习出来的

GRPO 的 advantage：
  A(g_i) = (r_i - mean(r)) / std(r)   ← 直接统计，不需要学习
```

其中 `r_i` 是第 i 个采样的奖励，`mean(r)` 和 `std(r)` 是同一组 G 个采样的统计量。

### 16.1.3 直觉图解

```
Prompt: "What is 23 + 47?"
Group of 8 samples:
  g1: "...=70"  reward=1.2  → adv = (1.2 - 0.45) / 0.52 = +1.44  ✓ 好
  g2: "...=71"  reward=0.2  → adv = (0.2 - 0.45) / 0.52 = -0.48
  g3: "...=70"  reward=1.0  → adv = (1.0 - 0.45) / 0.52 = +1.06  ✓
  g4: "...=69"  reward=0.0  → adv = (0.0 - 0.45) / 0.52 = -0.87  ✗
  g5: "...=70"  reward=1.2  → adv = +1.44
  g6: "...=70"  reward=1.0  → adv = +1.06
  g7: "...=72"  reward=0.2  → adv = -0.48
  g8: "...=68"  reward=0.0  → adv = -0.87

mean = 0.45, std = 0.52
```

正确答案 (70) 的回答获得正 advantage，错误答案获得负 advantage。**不需要任何学习**——直接用统计量。

### 16.1.4 group_advantages 实现

```python
# src/post_training/grpo.py

def group_advantages(rewards, group_size, eps=1e-4):
    r = rewards.view(-1, group_size)           # (num_prompts, group_size)
    mean = r.mean(dim=1, keepdim=True)          # 每组的均值
    std = r.std(dim=1, keepdim=True)            # 每组的标准差
    adv = (r - mean) / (std + eps)              # 标准化
    return adv.reshape(-1)
```

**eps 的作用**：当一组的所有回答奖励完全相同时（如全部正确或全部错误），`std=0`。`eps` 防止除零。

### 16.1.5 Informative Groups

```python
# 一组的所有 reward 相同 → std ≈ 0 → 所有 advantage ≈ 0 → 无训练信号
grp_std = rewards.view(-1, G).std(dim=1)
informative = (grp_std > 1e-6).float().mean()    # 有信息量的组占比
```

如果所有组都是"全对"或"全错"，GRPO 收到的信号为零——策略不会更新。这就是为什么需要 Curriculum Learning（后面讨论）。

## 16.2 Group Sampling：每个 prompt 采样 G 个回答

### 16.2.1 采样过程

```python
# train_grpo.py

G = cfg.group_size    # 默认 8
base_prompts = [encode_prompt([{"role": "user", "content": r["prompt"]}]) for r in rows]
prompts = [p for p in base_prompts for _ in range(G)]    # 每个 prompt 复制 G 份
golds = [r.get("gold") for r in rows for _ in range(G)]
```

如果有 8 个 prompt、group_size=8，总共有 64 个 rollout——每个 prompt 的 8 个回答在 tensor 中**连续排列**。

### 16.2.2 布局方式

```
Rollout 结果（64 条）：
  [prompt0_g0, prompt0_g1, ..., prompt0_g7,   ← 第 0 组的 8 个回答
   prompt1_g0, prompt1_g1, ..., prompt1_g7,   ← 第 1 组
   ...
   prompt7_g0, prompt7_g1, ..., prompt7_g7]   ← 第 7 组

Rewards（64 个标量）：
  [1.2, 0.2, 1.0, 0.0, 1.2, 1.0, 0.2, 0.0,   ← 第 0 组
   1.2, 1.2, 1.2, 1.2, 1.2, 1.2, 1.2, 1.2,   ← 第 1 组（全对，无信号）
   ...]
```

### 16.2.3 为什么是 temperature=1.0

GRPO 的采样需要足够的随机性——如果 `temperature` 太低，同一 prompt 的 G 个回答几乎一样，组内方差为零，优势为零，没有训练信号。

```
temperature=0.1: 所有回答几乎一样 → std≈0 → 无信号
temperature=1.0: 回答多样化 → std>0 → 有信号
temperature=2.0: 回答过于随机 → 大部分质量差 → 信号噪声大
```

## 16.3 K3 KL 惩罚：Schulman 的 k3 估计器

### 16.3.1 为什么 GRPO 需要不同的 KL 估计

PPO 用线性 KL 惩罚：

```python
# PPO 的 KL：简单差值
kl = log π - log π_ref    # 可正可负
```

GRPO 用 **K3 估计器**（Schulman 2020），它有两个优势：
1. **非负**：KL(P||Q) ≥ 0，数学上更正确
2. **无偏**：期望值等于真实的 KL 散度

### 16.3.2 K3 的数学

```python
def k3_kl(new_logp, ref_logp):
    diff = ref_logp - new_logp          # log(π_ref / π_new)
    return torch.exp(diff) - diff - 1.0   # e^x - x - 1
```

**为什么 `e^x - x - 1`？**

设 `x = log(π_ref/π_new)`：

```
k3 = π_ref/π_new - log(π_ref/π_new) - 1

当 π_new = π_ref（无偏离）：
  x = 0
  k3 = 1 - 0 - 1 = 0   ✓

当 π_new >> π_ref（策略偏向此处）：
  x = 大负数
  k3 ≈ 0 - x - 1 = -x - 1 > 0   ✓

当 π_new << π_ref（策略偏离此处）：
  x = 大正数
  k3 ≈ e^x - x - 1 >> 0   ✓ 惩罚很重
```

K3 曲线：

```
k3
│         ●
│        ╱
│       ╱
│      ●
│     ╱
│   ●╱
│  ●
│●
└──┬──┬──┬──┬──┬──▶ x = log(π_ref/π_new)
  -2 -1  0  1  2

x=0 时 k3=0（最小值），两侧递增
```

### 16.3.3 GRPO 的损失函数

```python
def grpo_loss(new_logp, old_logp, ref_logp, advantages, resp_mask,
              clip=0.2, kl_coef=0.04):
    adv = advantages[:, None]                      # (B, 1) 广播到 token 级
    ratio = torch.exp(new_logp - old_logp)
    surr1 = ratio * adv
    surr2 = torch.clamp(ratio, 1.0 - clip, 1.0 + clip) * adv
    surrogate = torch.min(surr1, surr2)
    kl = k3_kl(new_logp, ref_logp)

    per_token = surrogate - kl_coef * kl           # 策略收益 - KL 惩罚
    loss = -masked_mean(per_token, resp_mask)
    return loss, stats
```

### 16.3.4 GRPO vs PPO 损失的关键差异

| | PPO | GRPO |
|---|---|---|
| 优势来源 | GAE（学习 value → 递推 advantage） | 组内标准化（纯统计） |
| 优势粒度 | per-token（每个 action 不同） | per-sequence（一个 completion 共享一个值） |
| KL 处理 | 加到 reward 里（GAE 前） | 加到 loss 里（K3 估计器） |
| Value Loss | 有（需要训练 critic） | 无 |
| Clipping | 策略 + 价值函数双重 clip | 只 clip 策略 |

**GRPO 的 advantage 是 per-sequence 的**：同一个 completion 的所有 token 共享同一个 advantage 值。这比 PPO 的 per-token advantage 信息量低，但实现简单得多。

## 16.4 Curriculum Learning：从简单算术到 GSM8K

### 16.4.1 问题：冷启动

GRPO 依赖组内有"好回答"和"差回答"的对比。但如果 SFT 模型太弱：

```
GSM8K 问题："Janet has 10 snowballs..."
8 个回答全部错误 → rewards = [0, 0, 0, 0, 0, 0, 0, 0]
std = 0 → advantages = [0, 0, ..., 0]
→ 无训练信号！
```

这就是**冷启动问题**：模型答不对 → 没有信号 → 模型继续答不对 → 恶性循环。

### 16.4.2 解决方案：算术热身

先用简单的算术题（加减乘，数字 ≤ 20）训练，等模型有基础后再切到 GSM8K：

```python
# scripts/prepare_rl_prompts.py

def arithmetic_prompts(n, max_val, seed):
    ops = [("+", lambda a, b: a + b), ("-", lambda a, b: a - b), ("*", lambda a, b: a * b)]
    rows = []
    for _ in range(n):
        a, b = rng.randint(0, max_val), rng.randint(0, max_val)
        sym, fn = rng.choice(ops)
        rows.append({"prompt": f"What is {a} {sym} {b}?", "gold": float(fn(a, b))})
    return rows
```

生成 5000 道简单的算术题，如：

```
"What is 7 + 13?"        → gold = 20.0
"What is 15 - 3?"        → gold = 12.0
"What is 4 * 9?"         → gold = 36.0
```

SFT 模型即使推理能力弱，对简单算术也有一定正确率 → 组内有方差 → 有训练信号。

### 16.4.3 课程切换

```python
# train_grpo.py

warm_it = get_prompt_iterator(cfg.curriculum_path, ...)    # 算术题
main_it = get_prompt_iterator(cfg.prompt_path, ...)        # GSM8K

for it in range(cfg.iterations):
    rows = next(warm_it if it < cfg.curriculum_iters else main_it)
```

```
迭代:    0 ──── 100 ──── 200 ──── 500 ──── 1000
         │  算术热身  │     GSM8K 训练      │
         └───────────┘──────────────────────┘
              100 iters        900 iters
```

### 16.4.4 为什么是 100 步热身

```json
// configs/grpo.json
{
  "curriculum_iters": 100,
  "iterations": 1000
}
```

100 步足够让模型学会：
1. 正确使用 `<think>...<answer>` 格式
2. 对简单算术有一定正确率

然后切换到 GSM8K 时，模型已经有基础 → 组内方差非零 → GRPO 可以继续优化。

## 16.5 训练脚本：train_grpo.py 逐行解析

### 16.5.1 初始化

```python
policy = load_backbone_from_ckpt(cfg, cfg.sft_ckpt, ctx.device)
ref = make_frozen_copy(policy, device=ctx.device)
policy_ddp = ddp_wrap(policy, ctx)
optimizer = configure_optimizer(unwrap(policy_ddp), cfg.lr, weight_decay=0.0)
```

与 PPO 对比：
- **相同**：policy + frozen ref
- **不同**：没有 value_head、没有 reward_model → 显存减半

### 16.5.2 数据准备

```python
warm_it = get_prompt_iterator(cfg.curriculum_path, cfg.prompts_per_iter, ...)
main_it = get_prompt_iterator(cfg.prompt_path, cfg.prompts_per_iter, ...)
```

两个独立的 prompt iterator——算术热身和 GSM8K 主训练。

### 16.5.3 Prompt 复制与 Rollout

```python
G = cfg.group_size
base_prompts = [encode_prompt([{"role": "user", "content": r["prompt"]}]) for r in rows]
prompts = [p for p in base_prompts for _ in range(G)]    # 8 prompts × 8 = 64
golds = [r.get("gold") for r in rows for _ in range(G)]

policy.eval()
seqs, rmask, plens = rollout_prompts(policy, prompts, cfg.rollout_len, ...)
resp = rmask[:, 1:]
```

`rollout_prompts` 会按 prompt 长度分桶——因为同一个 prompt 复制了 G 份，它们的长度相同，自然在同一个 batch 中生成。

### 16.5.4 Scoring

```python
seq_lens = seq_lengths_from_mask(rmask, plens)
responses = [decode(seqs[i, plens[i]:seq_lens[i]].tolist()) for i in range(len(prompts))]
rewards = torch.tensor([reward_gsm8k(responses[i], golds[i]) for i in range(len(prompts))],
                        device=ctx.device, dtype=torch.float32)
```

每个回答用 GSM8K 验证器打分（0.0 / 0.2 / 1.0 / 1.2）。

### 16.5.5 Group Advantages

```python
adv = group_advantages(rewards, G)
```

64 个 rewards → 64 个 advantages，组内标准化。

### 16.5.6 Old Log-probs 和 Ref Log-probs

```python
with torch.no_grad():
    old_logp, _ = compute_logprobs(policy, seqs, rmask, ...)
    ref_logp, _ = compute_logprobs(ref, seqs, rmask, ...)
old_logp, ref_logp = old_logp.float(), ref_logp.float()
```

两次 teacher-forced 前向（都不需要梯度）——获取采样策略和参考策略的 log-prob。

### 16.5.7 GRPO 更新

```python
policy.train()
N = seqs.size(0)
for _ in range(cfg.grpo_epochs):           # 默认 1 轮
    perm = torch.randperm(N, device=ctx.device)
    for s in range(0, N, max(1, G)):        # minibatch = 一组的大小
        mb = perm[s:s + max(1, G)]
        new_logp, _ = compute_logprobs(policy_ddp, seqs[mb], rmask[mb], ...)
        loss, st = grpo_loss(new_logp.float(), old_logp[mb], ref_logp[mb],
                             adv[mb], resp[mb], clip=cfg.clip, kl_coef=cfg.kl_coef)
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(policy_ddp.parameters(), cfg.grad_clip)
        optimizer.step()
```

**与 PPO 更新的关键差异**：

1. `grpo_epochs=1`（默认）：PPO 用 4 轮，GRPO 只用 1 轮——因为没有 value function 需要收敛
2. `minibatch_size=G`：mini-batch 大小等于组大小，确保每组内的正负 advantage 在同一个 batch 中
3. 没有 value loss：只优化策略

### 16.5.8 日志输出

```python
mean_reward = reduce_scalar(rewards.mean().item(), ctx)
grp_std = rewards.view(-1, G).std(dim=1)
informative = reduce_scalar((grp_std > 1e-6).float().mean().item(), ctx)
```

```
iter 0[warmup]  | reward 0.312 | informative 0.62 | loss 0.0234 | KL 0.005 | clipfrac 0.080 | resp_len 42
iter 5[warmup]  | reward 0.562 | informative 0.75 | loss -0.0123 | KL 0.012 | clipfrac 0.120 | resp_len 45
iter 50[warmup] | reward 0.875 | informative 0.50 | loss -0.0456 | KL 0.034 | clipfrac 0.150 | resp_len 48
iter 100[gsm8k] | reward 0.125 | informative 0.38 | loss 0.0567 | KL 0.045 | clipfrac 0.100 | resp_len 87
iter 200[gsm8k] | reward 0.250 | informative 0.50 | loss -0.0234 | KL 0.067 | clipfrac 0.130 | resp_len 92
  [eval] iter 200 | GSM8K test acc 0.150 (30/200)
```

**`informative` 指标的含义**：有训练信号的组占比。

- warmup 阶段：算术题简单 → 模型时好时坏 → informative 较高
- 切换到 GSM8K 后：难度骤增 → informative 骤降 → 但随着训练逐渐恢复

## 16.6 PPO vs GRPO 全面对比

### 16.6.1 架构对比

| | PPO | GRPO |
|---|---|---|
| 模型副本 | policy + ref + RM + old_policy | policy + ref |
| 额外 Head | value_head | 无 |
| 优势估计 | GAE（学习 value） | 组内标准化（纯统计） |
| 奖励来源 | RM 或 verifier | 只用 verifier |
| KL 估计 | 线性差值 | K3（非负无偏） |
| 采样 | 每个 prompt 生成 1 个回答 | 每个 prompt 生成 G 个回答 |
| 更新轮数 | 4 epochs | 1 epoch |
| 代码复杂度 | 高（~170 行） | 低（~140 行） |

### 16.6.2 显存对比

```
PPO（~400M 模型）：
  policy (bf16)     ~500MB + gradients ~500MB + optimizer ~1GB
  reference         ~500MB
  reward_model      ~500MB
  value_head        ~5MB
  rollout buffer    ~1-2GB
  总计: ~4-5GB

GRPO（~400M 模型）：
  policy (bf16)     ~500MB + gradients ~500MB + optimizer ~1GB
  reference         ~500MB
  rollout buffer    ~2-3GB（G 倍大，因为每个 prompt 有 G 个回答）
  总计: ~3-4GB
```

GRPO 省了 ~1-2GB（去掉 RM 和 value_head），但 rollout buffer 更大（G 倍的回答）。

### 16.6.3 训练动态对比

```
PPO 的信号流：
  Rollout(1/prompt) → Score → GAE(per-token adv) → Clipped Update(4 epochs)
  
  优点：per-token 的优势更精细（知道哪个 token 贡献了奖励）
  缺点：Value 学不好 → 整个训练受拖累

GRPO 的信号流：
  Rollout(G/prompt) → Score → Group Adv(per-sequence) → Clipped Update(1 epoch)
  
  优点：不需要 Value，代码简单，训练稳定
  缺点：per-sequence 的优势粒度粗（不知道哪个 token 贡献了奖励）
```

### 16.6.4 何时选择 GRPO

| 场景 | PPO | GRPO |
|------|-----|------|
| 可验证任务（数学、代码） | 可用但过重 | **首选** |
| 开放任务（写作、对话） | **首选**（配合 RM） | 不适用（无 verifier） |
| 显存受限 | 不可用 | **首选** |
| 快速实验 | 复杂 | **首选** |
| 最大性能 | 可能略好 | 差距不大 |

## 16.7 超参数指南

### 16.7.1 核心超参数

| 参数 | 默认值 | 作用 | 调优建议 |
|------|--------|------|---------|
| group_size | 8 | 每个 prompt 的采样数 | 越大信号越好但 rollout 越贵 |
| curriculum_iters | 100 | 算术热身步数 | 模型越弱需要越多 |
| kl_coef | 0.04 | KL 惩罚系数 | 比 PPO 的 0.05 略小 |
| clip | 0.2 | 策略 clipping | 同 PPO |
| lr | 1e-6 | 学习率 | 同 PPO |
| grpo_epochs | 1 | 更新轮数 | 通常 1 就够 |
| temperature | 1.0 | 采样温度 | 不要降太低 |
| prompts_per_iter | 8 | 每次迭代的 prompt 数 | 越大越稳定 |
| rollout_len | 300 | 最大生成 token | 同 PPO |

### 16.7.2 group_size 的选择

| group_size | 效果 | 显存 |
|-----------|------|------|
| 4 | 信号弱（方差估计不准） | 小 |
| 8（默认） | 平衡 | 中 |
| 16 | 信号强但 rollout 贵 2 倍 | 大 |
| 32 | DeepSeek-R1 用 64，但需要大 GPU | 很大 |

**经验法则**：`group_size × prompts_per_iter` = 总 rollout 数，控制在 32-128 之间。

### 16.7.3 与 PPO 超参数的对比

| | PPO | GRPO | 说明 |
|---|---|---|---|
| kl_coef | 0.05 | 0.04 | GRPO 用 K3（值更大），系数稍小 |
| clip | 0.2 | 0.2 | 相同 |
| lr | 1e-6 | 1e-6 | 相同 |
| epochs | 4 | 1 | GRPO 不需要多轮 |
| vf_coef | 0.5 | N/A | GRPO 无 value |

## 16.8 完整运行指南

### 16.8.1 准备 RL prompts

```bash
PYTHONPATH=. HF_HOME=/ephemeral/hf_cache python scripts/prepare_rl_prompts.py --out_dir /ephemeral/data
```

输出：
- `rl_prompts_train.jsonl`：GSM8K 训练集（~7.5k 题）
- `rl_prompts_test.jsonl`：GSM8K 测试集（500 题）
- `arithmetic_prompts.jsonl`：算术热身（5000 题）

### 16.8.2 训练 GRPO

```bash
# 单 GPU
PYTHONPATH=. python scripts/train_grpo.py

# 双 GPU
PYTHONPATH=. torchrun --standalone --nproc_per_node=2 scripts/train_grpo.py
```

### 16.8.3 快速实验

```bash
# 减少迭代次数
PYTHONPATH=. python scripts/train_grpo.py --iterations 200 --eval_every 20

# 增大 group size
PYTHONPATH=. python scripts/train_grpo.py --group_size 16

# 调整 KL 系数
PYTHONPATH=. python scripts/train_grpo.py --kl_coef 0.08   # 更强约束
PYTHONPATH=. python scripts/train_grpo.py --kl_coef 0.01   # 更弱约束

# 延长算术热身
PYTHONPATH=. python scripts/train_grpo.py --curriculum_iters 200
```

## 16.9 训练过程诊断

### 16.9.1 典型的 reward 曲线

```
reward
│
1.0 ┤                        ●──●──●  GSM8K reward
│                  ●──●──╱
│           ●──╱
0.5 ┤     ●╱                    ← warmup 阶段
│  ●╱    warmup 结束
│╱
0.0 ┤─●
│
└──┬──┬──┬──┬──┬──┬──┬──┬──┬──▶ iter
   0  100 200 300 400 500 600 700 800
      ↑
   curriculum_iters=100
   切换到 GSM8K（reward 骤降）
```

### 16.9.2 informative 指标的诊断

```
informative
│
0.8 ┤──●──●
│        ╲
0.5 ┤      ●──●
│            ╲  ← 切换到 GSM8K
0.3 ┤              ●
│                ╱
0.2 ┤              ●──●──●  ← 稳定（部分组有信号）
│
└──┬──┬──┬──┬──┬──┬──▶ iter
   0  50 100 150 200 250
```

- **informative ≈ 0**：所有组全对或全错 → 无训练信号 → 需要调整 difficulty 或 temperature
- **informative ≈ 1**：所有组都有对比 → 信号最强（但也可能是噪声）
- **0.3-0.7**：健康范围

### 16.9.3 KL 的监控

```
KL 突然飙升的信号：
1. 学习率太大 → policy 更新过激
2. kl_coef 太小 → KL 约束不够
3. 切换课程时 → 新任务太难，policy 被迫大幅偏离
```

## 16.10 GRPO 在整个 Pipeline 中的位置

### 16.10.1 后训练全流程

```
Base Pretrained → SFT → DPO → GRPO（进一步提升推理能力）

或：

Base Pretrained → SFT → GRPO（跳过 DPO，直接 RLVR）
```

GRPO 从 SFT（或 DPO）checkpoint 开始，用验证器奖励进一步优化推理能力。

### 16.10.2 Checkpoint 流向

```
grpo.pt → 只包含 backbone（无 value_head）
    │
    ├──▶ evaluation.py: 评估 GSM8K 准确率
    ├──▶ chat.py: 对话测试
    └──▶ 可以和其他 checkpoint 对比
```

### 16.10.3 最终评估

整个后训练 Pipeline 的 head metric 是 GSM8K 准确率：

| 阶段 | 预期 GSM8K Acc | 说明 |
|------|---------------|------|
| Pretrained | ~0% | 不会回答问题 |
| SFT | 5-15% | 学会格式，推理弱 |
| DPO | 8-18% | 偏好优化，略有提升 |
| PPO | 10-25% | RL 提升推理 |
| GRPO | 10-25% | 类似 PPO，但更简单 |

## 16.11 本章小结

### GRPO 全流程

```
单步 GRPO 迭代：
1. Group Sampling:  每个 prompt × G → rollout_prompts → (seqs, rmask, plens)
2. Scoring:         verifier 打分 → rewards (N*G,)
3. Group Advantages: (r - mean) / std → adv (N*G,)
4. Log-probs:       old_logp + ref_logp（teacher-forced）
5. Clipped Update:  1 epoch × group-sized mini-batches

显存中的模型：
  policy — 可训练
  ref    — 冻结（KL 基准）
  无 value_head、无 reward_model
```

### GRPO 的核心组件

| 组件 | 文件 | 功能 |
|------|------|------|
| group_advantages | grpo.py | 组内标准化 |
| k3_kl | grpo.py | 非负无偏 KL 估计 |
| grpo_loss | grpo.py | token-level clipped surrogate + K3 KL |
| curriculum | prepare_rl_prompts.py | 算术热身 → GSM8K |

### PPO vs GRPO 总结

| | PPO | GRPO |
|---|---|---|
| 复杂度 | 高 | 低 |
| 显存 | 大 | 中 |
| 需要 RM | 可选 | 不需要 |
| 需要 Value | 需要 | 不需要 |
| KL 估计 | 线性 | K3 |
| 优势粒度 | per-token | per-sequence |
| 适用任务 | 通用 | 可验证 |
| 推荐场景 | 有 RM 的开放任务 | 数学/代码等可验证任务 |

### 关键教训

1. **组采样是核心**：G 个回答的相对好坏替代了 Value Network
2. **K3 KL 更准确**：非负无偏，比线性差值更合理
3. **Curriculum 解决冷启动**：简单任务热身 → 复杂任务训练
4. **informative 是关键诊断**：组内方差为零 → 无训练信号
5. **GRPO 是 RLVR 的首选**：对可验证任务，简单且有效

---

## 练习

**练习 1：Group Advantages 计算**

给定 2 个 prompt，group_size=4：

```
rewards = [1.2, 1.0, 0.2, 0.0,    # prompt 0 的 4 个回答
           0.0, 0.0, 0.0, 0.0]    # prompt 1 的 4 个回答
```

计算每组的 mean、std 和 advantage。哪组有训练信号？

**练习 2：K3 vs 线性 KL**

给定 `new_logp = [-2, -3, -4]` 和 `ref_logp = [-3, -2, -5]`，计算：
1. 线性 KL：`new_logp - ref_logp`
2. K3 KL：`exp(ref - new) - (ref - new) - 1`
3. 两者有什么区别？哪个更合理？

**练习 3：Curriculum 实验**

不用算术热身（`--curriculum_iters 0`），直接用 GSM8K 训练 GRPO。观察：
1. 前 50 步的 reward 和 informative
2. 与正常 curriculum 的训练对比
3. 最终 GSM8K 准确率有差异吗？

**练习 4：PPO vs GRPO 显存对比**

画出以下两个架构的完整参数流向图，标注哪些模块可训练、哪些冻结：

- **PPO**：policy + ref + value_head + reward_model
- **GRPO**：policy + ref

数一数每个架构需要多少次前向传播（包括 rollout 和 teacher-forced）？
