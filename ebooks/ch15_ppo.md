# 第 15 章：PPO——经典 RLHF 循环

> **本章目标**：完整理解 PPO 的 RLHF 循环——从 Rollout 生成到打分到 GAE 优势估计到 Clipped Update。掌握 Actor-Critic 架构、KL 惩罚、以及 PPO 在 GSM8K 上的训练全流程。

## 15.0 本章路线图

DPO 跳过了奖励模型和 RL 循环。PPO 则是**完整的经典 RLHF**——需要 Rollout、Reward、GAE、Clipped Update 四个阶段协作。

```
PPO 的单次迭代

1. Rollout：策略自回归生成回复
2. Scoring：验证器/RM 打分 + KL 惩罚
3. GAE：从后往前递推优势估计
4. Clipped Update：多轮 mini-batch 更新策略和价值函数
```

完整循环：

```
                 ┌──────────────────────────────────────────────┐
                 │              PPO 迭代循环                      │
                 │                                              │
  prompt ──────▶ │  Rollout ──▶ Scoring ──▶ GAE ──▶ Update ──▶ │ ── 下一迭代
                 │     ↑                              │         │
                 │     └──────────────────────────────┘         │
                 └──────────────────────────────────────────────┘
```

## 15.1 Actor-Critic 架构

### 15.1.1 为什么需要 Value Head

PPO 的 GAE 需要每个 token 位置的价值估计 `V(s_t)`——"从这个状态出发，预期能获得多少总奖励"。

- **Policy（Actor）**：给定状态，输出动作的概率分布 → 用 Transformer + lm_head
- **Value Function（Critic）**：给定状态，输出一个标量价值 → 需要额外的 value_head

### 15.1.2 TransformerWithValueHead

```python
# src/post_training/value_head.py

class TransformerWithValueHead(nn.Module):
    def __init__(self, transformer: Transformer):
        super().__init__()
        self.transformer = transformer
        n_embed = transformer.lm_head.in_features
        self.value_head = nn.Sequential(
            nn.Linear(n_embed, n_embed),    # 隐藏层
            nn.ReLU(),
            nn.Linear(n_embed, 1),          # 输出标量
        )
        # 零初始化：让初始价值估计接近 0
        nn.init.zeros_(self.value_head[-1].weight)
        nn.init.zeros_(self.value_head[-1].bias)

    def forward(self, idx):
        hidden = self.transformer.forward_hidden(idx)      # (B, T, n_embed)
        logits = self.transformer.lm_head(hidden)          # (B, T, vocab)
        values = self.value_head(hidden).squeeze(-1)       # (B, T)
        return logits, values
```

### 15.1.3 架构对比：三个 Head 共享 Backbone

```
Transformer Backbone（共享）
  tok_emb → blocks[0..N] → LayerNorm → hidden (B, T, n_embed)
                                            │
                    ┌───────────────────────┤
                    │                       │
                    ▼                       ▼
              lm_head (vocab)         reward_head (1)        value_head (n_embed→1)
              Policy 策略              Reward Model            Value Function
              SFT/DPO/PPO/GRPO        第 13 章                 本章（PPO）
```

三个 Head 都复用同一个 backbone 的隐藏状态，只是最后一层的映射不同。

### 15.1.4 value_head 的设计选择

```python
# value_head 比 reward_head 更复杂
value_head = nn.Sequential(
    nn.Linear(n_embed, n_embed),    # 多一层隐藏层
    nn.ReLU(),
    nn.Linear(n_embed, 1),
)

# reward_head 只有一层
reward_head = nn.Linear(n_embed, 1, bias=False)
```

**为什么 value_head 需要额外隐藏层？**

价值函数需要学习"状态的预期回报"，这比"单次评分"更复杂——它需要理解序列的全局结构。一层隐藏层 + ReLU 提供了足够的表达能力。

### 15.1.5 显存布局

PPO 是显存最密集的阶段：

```
GPU 显存
┌───────────────────────────────┐
│  Actor（可训练）                │ ~500MB + value_head
│  ├── backbone + lm_head        │
│  ├── value_head                │
│  ├── 梯度                      │ ~500MB
│  └── 优化器状态                │ ~1GB
├───────────────────────────────┤
│  Reference（冻结）             │ ~500MB
├───────────────────────────────┤
│  Reward Model（冻结，如果用 RM）│ ~500MB + reward_head
├───────────────────────────────┤
│  Rollout Buffer               │ ~1-2GB
│  (seqs, logprobs, values, ...) │
└───────────────────────────────┘
总计 ~4-6GB（小模型），大模型需 40-80GB
```

## 15.2 自回归 Rollout 与 log-prob 追踪

### 15.2.1 Rollout 的目的

给定 prompt，策略自回归生成回复，同时记录每个 token 的 log-prob——这些是后续 GAE 和 PPO update 的输入。

### 15.2.2 rollout_prompts 的使用

```python
# train_ppo.py

actor.eval()
seqs, rmask, plens = rollout_prompts(
    actor, prompts, cfg.rollout_len,
    device=ctx.device,
    temperature=cfg.temperature,
    top_p=cfg.top_p if cfg.top_p < 1 else None
)
```

`rollout_prompts`（第 9 章已详细介绍）做了三件事：
1. 按 prompt 长度分桶（等长 prompt 一起生成）
2. 自回归采样直到遇到 stop token 或达到 max_new_tokens
3. 返回 `(sequences, response_mask, prompt_lens)`

### 15.2.3 response_mask 的含义

```
sequences:     [p1, p2, ..., pP, g1, g2, ..., gG, PAD, PAD, ...]
response_mask: [0,  0,  ..., 0,  1,  1,  ..., 1,  0,   0,   ...]
                ^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^
                prompt（不训练） response（训练）   padding（不训练）
```

### 15.2.4 Action Frame（T-1 对齐）

PPO 的后续计算都在 **action frame** 中——长度为 T-1，索引 `t` 对应"从位置 t 生成 token t+1"：

```python
resp = rmask[:, 1:]    # action-frame response mask (N, T-1)
```

```
原始序列:    [t0, t1, t2, t3, t4, t5]     长度 T=6
action frame: [a0, a1, a2, a3, a4]         长度 L=T-1=5

a0: 从 t0 生成 t1
a1: 从 t0,t1 生成 t2
...
a4: 从 t0..t4 生成 t5
```

## 15.3 Scoring：奖励信号构建

### 15.3.1 两种奖励来源

```python
if cfg.reward_source == "rm":
    # 使用训练好的 Reward Model
    task_r = rm(seqs, seq_lengths=seq_lens).float().tolist()
else:
    # 使用验证器（verifier）直接检查答案
    task_r = [reward_gsm8k(responses[i], golds[i]) for i in range(len(rows))]
```

| 奖励来源 | 优点 | 缺点 |
|---------|------|------|
| Verifier（验证器） | 信号准确、无噪声 | 只适用于可验证任务（数学） |
| RM（奖励模型） | 通用、可用于开放任务 | 有噪声、可能被 hack |

### 15.3.2 GSM8K 验证器奖励

```python
# src/post_training/rewards/verifiers.py

CORRECT_BONUS = 1.0      # 答案正确
FORMAT_BONUS = 0.2       # 格式正确（有且仅有一个 <answer>...</answer>）
REWARD_CLIP = 1.2        # 上限

def reward_gsm8k(text, gold):
    r = 0.0
    if _answers_match(extract_answer(text), gold):
        r += CORRECT_BONUS
    if has_well_formed_answer(text):
        r += FORMAT_BONUS
    return min(r, REWARD_CLIP)
```

奖励分解：

| 场景 | 奖励 |
|------|------|
| 答案正确 + 格式正确 | 1.0 + 0.2 = 1.2 |
| 答案正确 + 格式错误 | 1.0 |
| 答案错误 + 格式正确 | 0.2 |
| 答案错误 + 格式错误 | 0.0 |

**为什么正确性奖励远大于格式奖励？**

如果格式奖励太大，小模型会学会"输出空的 `<answer></answer>` 标签"来骗取奖励（reward hacking）。正确性奖励主导，确保模型必须给出正确答案才能获高分。

### 15.3.3 Per-Token 奖励构建

PPO 需要**每个 action 位置**的奖励，而任务奖励只有一个标量。构建方式：

```python
# KL 惩罚：每个 response token 都有
rewards = -cfg.kl_coef * (old_logp - ref_logp) * resp.float()

# 任务奖励：只在最后一个 response token 上
last_idx = seq_lens - 2    # action frame 的最后位置
task_t = torch.tensor(task_r, device=ctx.device, dtype=torch.float32)
rewards[torch.arange(len(rows), device=ctx.device), last_idx] += task_t
```

```
rewards 时间线：
  [KL_0, KL_1, ..., KL_{n-2}, KL_{n-1} + task_reward]
   ↑                              ↑
   每步都有 KL 惩罚               最后一步加上任务奖励
```

### 15.3.4 KL 惩罚的作用

```python
kl_penalty = -kl_coef * (log π(a|s) - log π_ref(a|s))
```

- `log π > log π_ref`：policy 比 ref 更喜欢这个 action → **负惩罚**（鼓励偏离）
- `log π < log π_ref`：policy 比 ref 不喜欢这个 action → **正惩罚**（抑制偏离）
- `kl_coef = 0.05`：适中的约束强度

**为什么需要 KL 惩罚？**

没有 KL 约束，策略会偏离 SFT 初始化太远——可能学会"reward hacking"（找奖励函数的漏洞），而非真正提升质量。KL 惩罚像一条"弹性绳"，把策略拴在 reference 附近。

## 15.4 GAE：从后往前递推

### 15.4.1 直觉

GAE（Generalized Advantage Estimation）回答一个关键问题：**每个 action 比"平均水平"好多少？**

```
advantage_t = (实际获得的总回报) - (Value 函数估计的回报)
```

- advantage > 0：这个 action 比预期好 → 应该增加其概率
- advantage < 0：这个 action 比预期差 → 应该降低其概率

### 15.4.2 代码实现

```python
# src/post_training/ppo.py

def compute_gae(rewards, values, values_next, resp_mask,
                gamma=1.0, lam=0.95):
    B, L = rewards.shape
    adv = torch.zeros_like(rewards)
    lastgae = torch.zeros(B, device=rewards.device)
    m = resp_mask.float()

    for t in reversed(range(L)):
        # 如果下一个位置不是 response token，不 bootstrap
        nonterminal = m[:, t + 1] if t + 1 < L else torch.zeros(B, ...)
        # TD error: δ = r + γV(s') - V(s)
        delta = rewards[:, t] + gamma * values_next[:, t] * nonterminal - values[:, t]
        # GAE 递推: A = δ + γλ * A_next（如果不是 terminal）
        lastgae = delta + gamma * lam * nonterminal * lastgae
        adv[:, t] = lastgae

    returns = adv + values    # GAE + V(s) = target return
    return adv * m, returns * m
```

### 15.4.3 递推过程图解

```
时间:      t=0    t=1    t=2    t=3    t=4
rewards:   KL_0   KL_1   KL_2   KL_3   KL_4 + R_task
values:    V_0    V_1    V_2    V_3    V_4
values_next:V_1    V_2    V_3    V_4    0

从后往前：
  t=4: δ_4 = (KL_4 + R_task) + γ·0·V_next - V_4
        A_4 = δ_4

  t=3: δ_3 = KL_3 + γ·V_4·1 - V_3
        A_3 = δ_3 + γ·λ·1·A_4

  t=2: δ_2 = KL_2 + γ·V_3·1 - V_2
        A_2 = δ_2 + γ·λ·1·A_3

  ...以此类推
```

### 15.4.4 γ 和 λ 的作用

| 参数 | 含义 | 影响 |
|------|------|------|
| γ (gamma) | 折扣因子 | γ=1：不折扣（远期奖励同等重要）<br>γ<1：更重视近期奖励 |
| λ (lam) | GAE 平滑参数 | λ=0：只看单步 TD error<br>λ=1：用完整 Monte Carlo return |

本项目设置：`gamma=1.0, gae_lambda=0.95`——不折扣（episode 短）+ 高平滑（利用完整序列信息）。

### 15.4.5 Terminal 处理

```python
nonterminal = m[:, t + 1] if t + 1 < L else torch.zeros(B, ...)
```

response 的最后一个 token 之后是 **terminal state**——没有后续价值可以 bootstrap。`nonterminal=0` 确保：
- 不引用终端之后的 value
- GAE 递推在 episode 结束时重置

### 15.4.6 Advantage 白化

```python
def whiten(advantages, mask):
    m = mask.float()
    mean = masked_mean(advantages, m)
    var = masked_mean((advantages - mean) ** 2, m)
    return ((advantages - mean) / (var.sqrt() + 1e-8)) * m
```

白化（标准化）让优势值均值为 0、方差为 1——稳定训练，防止某些 batch 的优势值过大导致策略更新过激。

## 15.5 Clipped Surrogate 策略损失

### 15.5.1 核心思想

PPO 的策略损失使用 **ratio clipping**——限制新旧策略的比率，防止更新步幅过大：

```
ratio = π_new(a|s) / π_old(a|s) = exp(log π_new - log π_old)
```

- ratio > 1：新策略更喜欢这个 action
- ratio < 1：新策略更不喜欢这个 action
- ratio = 1：没有变化

### 15.5.2 代码实现

```python
def ppo_policy_loss(new_logp, old_logp, advantages, mask, clip=0.2):
    ratio = torch.exp(new_logp - old_logp)
    surr1 = ratio * advantages
    surr2 = torch.clamp(ratio, 1.0 - clip, 1.0 + clip) * advantages
    loss = -masked_mean(torch.min(surr1, surr2), mask)
    clipped = ((ratio - 1.0).abs() > clip).float()
    return loss, masked_mean(clipped, mask)
```

### 15.5.3 Clipping 的直觉

```
当 advantage > 0（好的 action）：
  surr1 = ratio × adv         → 越大越好（鼓励增加概率）
  surr2 = clamp(ratio) × adv  → 最多 1.2 × adv

  min(surr1, surr2) 的效果：
    ratio < 0.8:  surr1 < surr2 → 用 surr1（正常梯度）
    0.8 ≤ ratio ≤ 1.2:  surr1 ≤ surr2 → 用 surr1（正常梯度）
    ratio > 1.2:  surr1 > surr2 → 用 surr2（截断，不再鼓励更大）

当 advantage < 0（差的 action）：
  同理，ratio < 0.8 时被截断
```

**Clipping 的效果**：无论优势多大，单次更新的策略变化不超过 `clip=0.2`（±20%）。这是 PPO 的核心稳定性保证。

### 15.5.4 clip_fraction 诊断

```python
clipped = ((ratio - 1.0).abs() > clip).float()
clip_fraction = masked_mean(clipped, mask)
```

`clip_fraction` 表示被截断的 action 比例：

| clip_fraction | 含义 |
|---------------|------|
| 0.0 | 无截断（更新步幅小，可能学习太慢） |
| 0.1-0.3 | 健康范围 |
| > 0.5 | 大量截断（可能优势值太大或学习率太高） |

## 15.6 Clipped Value 损失

### 15.6.1 代码实现

```python
def ppo_value_loss(new_values, old_values, returns, mask, vf_clip=0.2):
    v_clipped = old_values + torch.clamp(new_values - old_values, -vf_clip, vf_clip)
    loss_unclipped = (new_values - returns) ** 2
    loss_clipped = (v_clipped - returns) ** 2
    return 0.5 * masked_mean(torch.max(loss_unclipped, loss_clipped), mask)
```

### 15.6.2 Clipping 的直觉

和策略损失类似——限制 Value 函数的更新幅度：

- `new_values - old_values` 被截断到 `[-vf_clip, vf_clip]`
- 取 `max(未截断损失, 截断损失)` → 更保守的梯度

### 15.6.3 为什么取 max 而不是 min

策略损失取 `min`（保守更新），价值损失取 `max`（保守估计）：

- **策略**：怕更新太大（min 截断大优势）
- **价值**：怕估计太乐观（max 惩罚大偏差）

## 15.7 完整的 PPO 迭代

### 15.7.1 训练脚本结构

```python
# scripts/train_ppo.py

for it in range(cfg.iterations):
    # 1. 取一批 prompts
    rows = next(prompt_it)
    prompts = [encode_prompt([{"role": "user", "content": r["prompt"]}]) for r in rows]
    golds = [r.get("gold") for r in rows]

    # 2. Rollout（生成回复）
    actor.eval()
    seqs, rmask, plens = rollout_prompts(actor, prompts, cfg.rollout_len, ...)
    resp = rmask[:, 1:]

    # 3. Scoring（计算奖励）
    task_r = [reward_gsm8k(responses[i], golds[i]) for i in range(len(rows))]

    # 4. 计算 old log-probs 和 values
    old_logp, old_values = actor_logp_values(actor, seqs, cfg.temperature)
    ref_logp, _ = compute_logprobs(ref, seqs, rmask, ...)

    # 5. 构建 per-token rewards（KL + task）
    rewards = -cfg.kl_coef * (old_logp - ref_logp) * resp.float()
    rewards[last_idx] += task_t

    # 6. GAE
    adv, returns = compute_gae(rewards, old_values, values_next, resp, ...)
    adv = whiten(adv, resp)

    # 7. Clipped PPO update epochs
    for _ in range(cfg.ppo_epochs):
        for minibatch in random_minibatches:
            new_logp, new_values = actor_logp_values(actor, seqs[mb], ...)
            p_loss, clipf = ppo_policy_loss(new_logp, old_logp[mb], adv[mb], ...)
            v_loss = ppo_value_loss(new_values, old_values[mb], returns[mb], ...)
            loss = p_loss + cfg.vf_coef * v_loss
            loss.backward()
            optimizer.step()
```

### 15.7.2 actor_logp_values：一次前向获取两样东西

```python
def actor_logp_values(actor, seqs, temperature):
    logits, values = actor(seqs)           # (B, T, V), (B, T)
    logits = logits[:, :-1, :]             # action frame
    logp_all = F.log_softmax(logits.float() / max(temperature, 1e-6), dim=-1)
    logp = logp_all.gather(-1, seqs[:, 1:, None]).squeeze(-1)
    return logp, values[:, :-1]            # (B, T-1), (B, T-1)
```

一次前向传播同时获得策略的 log-prob 和价值估计——因为 Actor-Critic 共享 backbone。

### 15.7.3 PPO epochs：多次复用 rollout

```python
for _ in range(cfg.ppo_epochs):    # 默认 4 轮
    perm = torch.randperm(N, device=ctx.device)
    for s in range(0, N, cfg.minibatch_size):
        mb = perm[s:s + cfg.minibatch_size]
        # 用 old_logp / old_values 作为基准
        # 计算 new_logp / new_values（随策略更新而变化）
```

**为什么多轮？** Rollout 很贵（自回归生成），但 PPO 的 clipped update 允许多次复用同一批数据——只要 ratio 不超过 clip 范围。4 轮 × 32 prompts = 128 次有效梯度更新。

**为什么不太多轮？** 轮数太多，old_logp 和 new_logp 差异太大，clipping 失效，训练不稳定。

### 15.7.4 保存 checkpoint：只保存 backbone

```python
save_stage_ckpt(cfg.out_ckpt, unwrap(actor_ddp).transformer, optimizer,
                stage="ppo", cfg=cfg, step=it, metrics={"reward": mean_reward})
```

**注意**：保存的是 `actor.transformer`（backbone），不包含 `value_head`。下游（GRPO、推理）只需要策略，不需要价值函数。

## 15.8 日志指标解读

### 15.8.1 每次迭代的输出

```
iter 0  | reward 0.125 | KL_ref 0.012 | ploss 0.0234 | vloss 0.0456 | clipfrac 0.150 | resp_len 87
iter 5  | reward 0.219 | KL_ref 0.023 | ploss 0.0187 | vloss 0.0321 | clipfrac 0.180 | resp_len 92
iter 50 | reward 0.438 | KL_ref 0.089 | ploss 0.0312 | vloss 0.0234 | clipfrac 0.250 | resp_len 105
  [eval] iter 50 | GSM8K test acc 0.185 (37/200)
```

### 15.8.2 各指标的含义

| 指标 | 健康范围 | 异常信号 |
|------|---------|---------|
| reward | 0.1 → 0.5+ | 不增长 → 学习停滞 |
| KL_ref | 0.01 → 0.1 | > 0.5 → 策略偏离太远 |
| ploss | 接近 0 | 剧烈波动 → 学习率太高 |
| vloss | 逐渐下降 | 不下降 → Value 学不动 |
| clipfrac | 0.1-0.3 | > 0.5 → 更新步幅太大 |
| resp_len | 稳定 | 突增 → 模型不生成 stop token |
| GSM8K acc | 逐渐上升 | 下降 → reward hacking |

### 15.8.3 KL 和 reward 的关系

```
理想情况：
  reward ↑ 且 KL 适度增长 → 策略在变好，但没有偏离太远

危险信号：
  reward ↑ 但 KL 飙升 → 策略偏离 SFT 太远，可能 reward hacking
  reward ↑ 但 GSM8K acc ↓ → 格式奖励 hack（模型学会输出空 answer 标签）
```

## 15.9 超参数指南

### 15.9.1 核心超参数

| 参数 | 默认值 | 作用 |
|------|--------|------|
| iterations | 1000 | 总迭代次数 |
| prompts_per_iter | 32 | 每次 rollout 的 prompt 数 |
| rollout_len | 300 | 最大生成 token 数 |
| ppo_epochs | 4 | 每批 rollout 数据复用的更新轮数 |
| minibatch_size | 16 | mini-batch 大小 |
| clip | 0.2 | 策略 clipping 范围 |
| vf_clip | 0.2 | 价值函数 clipping 范围 |
| vf_coef | 0.5 | 价值损失权重 |
| gamma | 1.0 | 折扣因子 |
| gae_lambda | 0.95 | GAE 平滑参数 |
| kl_coef | 0.05 | KL 惩罚系数 |
| lr | 1e-6 | 学习率（非常保守） |

### 15.9.2 与 DPO/GRPO 的超参数对比

| | PPO | DPO | GRPO |
|---|---|---|---|
| lr | 1e-6 | 5e-7 | 1e-6 |
| 模型副本数 | 3-4（policy+ref+RM+old） | 2（policy+ref） | 2（policy+ref） |
| 是否做 rollout | 是 | 否 | 是 |
| 训练复杂度 | 高 | 低 | 中 |

## 15.10 完整运行指南

### 15.10.1 前提条件

```bash
ls /ephemeral/ckpts/sft.pt                    # SFT checkpoint
ls /ephemeral/ckpts/reward.pt                  # Reward Model（如果用 RM）
ls /ephemeral/data/rl_prompts_train.jsonl      # RL prompts
ls /ephemeral/data/rl_prompts_test.jsonl       # 评估 prompts
```

### 15.10.2 使用验证器奖励（RLVR）

```bash
# 单 GPU
PYTHONPATH=. python scripts/train_ppo.py --reward_source verifier

# 双 GPU
PYTHONPATH=. torchrun --standalone --nproc_per_node=2 scripts/train_ppo.py --reward_source verifier
```

### 15.10.3 使用 Reward Model

```bash
PYTHONPATH=. python scripts/train_ppo.py --reward_source rm
```

### 15.10.4 快速实验

```bash
# 减少迭代次数
PYTHONPATH=. python scripts/train_ppo.py --iterations 100 --eval_every 20

# 调 KL 系数
PYTHONPATH=. python scripts/train_ppo.py --kl_coef 0.1    # 更强的 KL 约束
PYTHONPATH=. python scripts/train_ppo.py --kl_coef 0.01   # 更弱的 KL 约束
```

## 15.11 PPO 的优缺点

### 15.11.1 优点

1. **理论完备**：经典 RL 算法，有充分的收敛性分析
2. **灵活性**：可以配合任何奖励信号（RM、verifier、混合）
3. **稳定性**：Clipping + KL 双重保护
4. **可监控**：丰富的诊断指标（KL、clip_fraction、value_loss）

### 15.11.2 缺点

1. **显存密集**：需要 3-4 个模型副本
2. **实现复杂**：Rollout + Scoring + GAE + Clipped Update 四个阶段
3. **超参数敏感**：ppo_epochs、clip、kl_coef 等需要仔细调
4. **训练不稳定**：小模型 + 短序列容易出现 reward hacking

### 15.11.3 何时选 PPO vs GRPO

| 场景 | 推荐 |
|------|------|
| 显存充足（80GB+） | PPO |
| 有高质量 Reward Model | PPO |
| 可验证任务（数学、代码） | GRPO（更简单、同样有效） |
| 显存受限（40GB） | GRPO |

## 15.12 本章小结

### PPO 全流程

```
单步 PPO 迭代：
1. Rollout:        策略自回归生成 → (seqs, rmask, plens)
2. Scoring:        verifier/RM 打分 + KL 惩罚 → rewards (B, T-1)
3. GAE:            从后往前递推 → (advantages, returns)
4. Clipped Update: 4 轮 × mini-batch → 更新 policy + value

显存中的模型：
  actor (policy + value_head) — 可训练
  reference (frozen copy)     — KL 基准
  reward_model (frozen)       — 仅 reward_source=rm 时
```

### 四个核心组件

| 组件 | 文件 | 功能 |
|------|------|------|
| Actor-Critic | value_head.py | 共享 backbone 的策略 + 价值函数 |
| GAE | ppo.py:compute_gae | 从后往前递推优势估计 |
| Clipped Policy | ppo.py:ppo_policy_loss | 限制策略更新幅度 |
| Clipped Value | ppo.py:ppo_value_loss | 限制价值函数更新幅度 |

### 关键教训

1. **KL 惩罚是安全绳**：防止策略偏离 SFT 太远
2. **Clipping 是稳定器**：限制单次更新步幅
3. **Value Head 需要零初始化**：早期训练稳定
4. **只保存 backbone**：value_head 不需要保留（下游不用）
5. **监控 KL + clip_fraction**：异常信号早于 loss 异常

---

## 练习

**练习 1：GAE 手动计算**

给定长度为 3 的 response（action frame），所有位置都是 response token：

```
rewards:    [0.1, -0.05, 1.0]     (前两个是 KL 惩罚，最后一个是 KL + task reward)
values:     [0.2, 0.3, 0.1]
values_next:[0.3, 0.1, 0.0]       (最后是 terminal，value=0)
gamma=1.0, lambda=0.95
```

手动计算每个位置的 δ、A、和 return。

**练习 2：Clipping 行为分析**

假设 advantage = 2.0，clip = 0.2。

对于 ratio ∈ {0.5, 0.8, 1.0, 1.2, 1.5, 2.0}，计算：
1. surr1 = ratio × adv
2. surr2 = clamp(ratio) × adv
3. min(surr1, surr2)
4. 哪些 ratio 被 clip 了？

**练习 3：显存计算**

假设模型有 400M 参数（bf16），估算 PPO 的总显存需求：
1. actor（policy + value_head）+ 梯度 + 优化器
2. reference model
3. reward model（如果加载）
4. rollout buffer（32 prompts × 300 tokens）

和 DPO 对比，PPO 多用了多少显存？

**练习 4：对比 PPO 和 DPO 的训练循环**

画出以下两个训练循环的数据流图：
- **PPO**：Rollout → Score → GAE → Clipped Update
- **DPO**：Teacher-forced log-prob → DPO Loss → Update

数一数每个循环需要多少次前向传播（包括有梯度和无梯度的）？
