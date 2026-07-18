# 第 5 章：优化与学习率调度

> **本章目标**：理解 AdamW 优化器、Warmup + Cosine Decay 学习率调度、梯度裁剪和权重衰减的工作原理，并能在训练循环中正确使用它们。

## 5.0 本章路线图

训练一个神经网络本质上是求解一个优化问题：

```
找到一组参数 θ，使得 Loss(θ) 最小
```

但 LLM 的参数规模动辄上亿，不可能一次性算出最优解。我们需要一个"向导"，在每一步告诉我们：
1. 往哪个方向走？（梯度）
2. 走多远？（学习率）
3. 怎么走才稳？（优化器 + 正则化）

本章就是这个"向导"的完整说明。

```
优化系统
│
├── AdamW 优化器：自适应学习率 + 解耦权重衰减
├── 学习率调度：Warmup + Cosine Decay
├── 梯度裁剪：防止梯度爆炸
├── 权重衰减：防止过拟合
└── 训练循环：把以上组件串起来
```

## 5.1 优化器演进：从 SGD 到 AdamW

### 5.1.1 随机梯度下降（SGD）

最朴素的优化方法：沿梯度反方向更新参数。

```
θ_{t+1} = θ_t - η × g_t
```

其中 `η` 是学习率，`g_t` 是当前 batch 的梯度。

**问题**：每个参数都用同一个学习率。但不同参数的梯度大小差异巨大——Embedding 层的梯度可能很小，注意力层的梯度可能很大。固定学习率无法适应这种差异。

### 5.1.2 Adam：自适应学习率

Adam 的核心思想是：**为每个参数维护独立的学习率**。

它追踪两个移动平均：

```
m_t = β₁ × m_{t-1} + (1 - β₁) × g_t          ← 一阶动量（梯度的均值）
v_t = β₂ × v_{t-1} + (1 - β₂) × g_t²          ← 二阶动量（梯度平方的均值）
```

直觉理解：
- **m_t**：梯度的"方向"。如果梯度一直指向同一个方向，m_t 会越来越大，加速前进
- **v_t**：梯度的"波动程度"。如果梯度忽大忽小，v_t 会变大，减缓更新

参数更新：

```
θ_{t+1} = θ_t - η × m̂_t / (√v̂_t + ε)
```

其中 `m̂_t` 和 `v̂_t` 是偏差校正后的动量（因为初始值为 0，早期会偏小）。

标准超参：`β₁=0.9`，`β₂=0.999`，`ε=1e-8`。

### 5.1.3 AdamW：解耦权重衰减

**Adam 的一个问题**：传统实现把权重衰减（L2 正则化）混进了梯度更新。但 Adam 的自适应学习率会"吃掉"权重衰减的效果。

**AdamW 的解决方案**：把权重衰减从梯度更新中分离出来，直接作用于参数。

```
Adam（L2 耦合）：
  g_t' = g_t + λ × θ_t          ← 把正则化塞进梯度
  θ_{t+1} = θ_t - η × m̂_t / (√v̂_t + ε)    ← 自适应学习率"吃掉"了正则化

AdamW（L2 解耦）：
  θ_{t+1} = θ_t - η × (m̂_t / (√v̂_t + ε) + λ × θ_t)
                        ──────────────────────   ────────────
                        梯度更新（自适应LR）      权重衰减（直接用原始LR）
```

AdamW 在实践中效果更好，已成为 LLM 训练的**标准优化器**。本项目也使用 AdamW。

## 5.2 AdamW 的实现

### 5.2.1 构建优化器

本项目的 `configure_optimizer` 函数构建 AdamW，并做了一个关键的设计决策：**权重衰减只作用于矩阵参数，不作用于偏置和归一化层**。

```python
# src/post_training/optim.py

def configure_optimizer(model, lr, weight_decay, betas=(0.9, 0.95)):
    decay, no_decay = [], []
    for name, p in model.named_parameters():
        if not p.requires_grad:
            continue
        if p.dim() >= 2:       # 2D 或更高维 → 矩阵参数
            decay.append(p)
        else:                   # 1D 参数 → bias, LayerNorm 的 weight/bias
            no_decay.append(p)

    groups = [
        {"params": decay, "weight_decay": weight_decay},    # 衰减
        {"params": no_decay, "weight_decay": 0.0},          # 不衰减
    ]
    return torch.optim.AdamW(groups, lr=lr, betas=betas)
```

### 5.2.2 为什么分两组？

| 参数类型 | 维度 | 示例 | 权重衰减？ | 原因 |
|----------|------|------|-----------|------|
| Linear weight | 2D | `nn.Linear(256, 1024).weight` | 是 | 大矩阵，正则化防过拟合 |
| Embedding weight | 2D | `nn.Embedding(50304, 256).weight` | 是 | 大矩阵 |
| Bias | 1D | `nn.Linear(256, 1024).bias` | 否 | 参数少，正则化会限制表达力 |
| LayerNorm weight | 1D | `nn.LayerNorm(256).weight` | 否 | 归一化的缩放因子，需要精确控制 |
| LayerNorm bias | 1D | `nn.LayerNorm(256).bias` | 否 | 同上 |

这是 **GPT 系列的标准做法**（"GPT recipe"）。对大的权重矩阵做衰减可以防止它们长得太大（过拟合），而小的 1D 参数（总共才几百个）不需要衰减。

### 5.2.3 betas 的选择

```python
betas = (0.9, 0.95)   # 而不是 Adam 默认的 (0.9, 0.999)
```

`β₂` 从 0.999 降低到 0.95，意味着二阶动量对最近梯度的权重更大。这使优化器对梯度变化更敏感，在 LLM 训练中通常更稳定。

### 5.2.4 各阶段的超参对比

不同训练阶段对优化器的要求不同：

| 阶段 | 学习率 | 权重衰减 | betas | 训练步数 |
|------|--------|---------|-------|---------|
| 预训练 | 3e-4 | 0.1 | (0.9, 0.95) | 200,000 |
| SFT | 1e-5 | 0.0 | (0.9, 0.95) | ~3,000 |
| Reward | 1e-5 | 0.0 | (0.9, 0.95) | ~1,000 |
| DPO | 5e-7 | 0.0 | (0.9, 0.95) | ~1,000 |
| PPO | 1e-6 | 默认 | (0.9, 0.95) | 1,000 |
| GRPO | 1e-6 | 默认 | (0.9, 0.95) | 1,000 |

规律：**越往后的阶段学习率越小**。预训练需要从随机初始化大幅调整参数，所以用较大的学习率。SFT 和后续阶段只是微调已有知识，所以学习率小 1-2 个数量级。

## 5.3 学习率调度：Warmup + Cosine Decay

学习率不应该是固定的。训练初期需要小学习率（参数随机，大步走容易发散），中期需要大学习率（快速收敛），末期需要小学习率（精细调整）。

### 5.3.1 三阶段调度

```
学习率 η
  │
  │          ╱╲
  │        ╱    ╲
  │      ╱        ╲
  │    ╱            ╲
  │  ╱                ╲___
  │╱                        ─── min_lr
  └──────────────────────────→ 步数
  0    warmup              max_steps
```

**阶段 1：线性 Warmup**（step < warmup_steps）

```
η(step) = η_max × (step + 1) / warmup_steps
```

从接近 0 线性增长到 `η_max`。

**为什么需要 Warmup？**

训练刚开始时，模型参数是随机的，梯度的方向很不稳定。如果此时学习率很大，一次更新可能把参数推到很远的地方，导致 loss 暴涨甚至 NaN。Warmup 让模型先用小步"探路"，等梯度方向稳定后再加速。

**阶段 2：Cosine Decay**（warmup_steps ≤ step < max_steps）

```
progress = (step - warmup_steps) / (max_steps - warmup_steps)
η(step) = η_min + 0.5 × (1 + cos(π × progress)) × (η_max - η_min)
```

学习率从 `η_max` 沿余弦曲线平滑下降到 `η_min`。

**为什么用 Cosine 而不是线性？**

余弦衰减在训练中期保持较高的学习率（相比线性衰减），只在末期快速下降。这让模型有更长的时间以较大的步长探索参数空间，在末期再精细收敛。

**阶段 3：恒定最小值**（step ≥ max_steps）

```
η(step) = η_min
```

训练结束后，学习率保持在 `η_min`，用于后续的评估或继续训练。

### 5.3.2 代码实现

```python
# src/post_training/optim.py

def cosine_lr(step, *, warmup_steps, max_steps, lr, min_lr):
    # 阶段 1：Warmup
    if step < warmup_steps:
        return lr * (step + 1) / max(1, warmup_steps)

    # 阶段 3：训练结束
    if step >= max_steps:
        return min_lr

    # 阶段 2：Cosine Decay
    progress = (step - warmup_steps) / max(1, max_steps - warmup_steps)
    coeff = 0.5 * (1.0 + math.cos(math.pi * progress))
    return min_lr + coeff * (lr - min_lr)
```

### 5.3.3 在训练循环中的使用

```python
# scripts/pretrain_base.py — 训练循环

for step in range(start_step, cfg.train_steps):
    # 计算当前 step 的学习率
    lr = cosine_lr(step,
                   warmup_steps=cfg.warmup_steps,
                   max_steps=cfg.train_steps,
                   lr=cfg.lr,
                   min_lr=cfg.min_lr)

    # 把学习率应用到优化器的所有参数组
    for g in optimizer.param_groups:
        g["lr"] = lr

    # ... 前向传播、反向传播、梯度累积 ...
    optimizer.step()
```

注意：学习率是**每步**重新计算的，不是创建优化器时一次性设定的。这是通过直接修改 `optimizer.param_groups` 中的 `"lr"` 字段实现的。

### 5.3.4 动手可视化

```python
import matplotlib.pyplot as plt

warmup_steps = 2000
max_steps = 200000
lr = 3e-4
min_lr = 3e-5

steps = range(max_steps + 1000)
lrs = [cosine_lr(s, warmup_steps=warmup_steps, max_steps=max_steps,
                 lr=lr, min_lr=min_lr) for s in steps]

plt.plot(steps, lrs)
plt.xlabel("Step")
plt.ylabel("Learning Rate")
plt.title("Warmup + Cosine Decay Schedule")
plt.axvline(x=warmup_steps, color='r', linestyle='--', label='Warmup end')
plt.legend()
plt.show()
```

你会看到一条曲线：先线性上升到 3e-4，然后沿余弦下降到 3e-5。

### 5.3.5 各阶段的调度差异

| 阶段 | warmup_steps | lr (max) | min_lr | 总步数 |
|------|-------------|----------|--------|--------|
| 预训练 | 2,000 | 3e-4 | 3e-5 | 200,000 |
| SFT | 100 | 1e-5 | 1e-6 | ~3,000 |
| Reward | 50 | 1e-5 | — | ~1,000 |
| DPO | 50 | 5e-7 | — | ~1,000 |

预训练的 warmup 最长（2000 步），因为从随机初始化开始训练，梯度最不稳定。后训练阶段只需几百步 warmup。

## 5.4 梯度裁剪（Gradient Clipping）

### 5.4.1 为什么需要梯度裁剪

在某些情况下，梯度可能突然变得非常大（"梯度爆炸"）：

- **长序列训练**：反向传播经过很多层，梯度连乘导致指数级增长
- **RL 训练**：奖励信号不稳定，导致 loss 剧烈波动
- **数据异常**：某个 batch 的数据特别"极端"

如果不加控制，巨大的梯度会让参数一次更新过远，之前的训练成果全部白费。

### 5.4.2 工作原理

梯度裁剪限制梯度的**全局 L2 范数**：

```
如果 ||g||₂ > c:
    g ← g × (c / ||g||₂)    ← 等比例缩小
否则:
    g 不变                    ← 梯度正常，不干预
```

其中 `c` 是阈值（本项目取 1.0）。

**关键点**：这不是逐元素裁剪，而是对整个梯度向量做等比例缩放。这保证了梯度的**方向不变**，只是限制了**大小**。

### 5.4.3 代码实现

```python
# scripts/pretrain_base.py

# 梯度累积完成后，裁剪
torch.nn.utils.clip_grad_norm_(model.parameters(), cfg.grad_clip)

# 然后更新参数
optimizer.step()
```

`clip_grad_norm_` 是 PyTorch 的内置函数，计算所有参数的梯度全局范数，如果超过阈值就等比例缩小。

### 5.4.4 典型配置

| 阶段 | grad_clip | 说明 |
|------|-----------|------|
| 预训练 | 1.0 | 标准值 |
| SFT | 1.0 | 标准值 |
| PPO/GRPO | 1.0 | RL 训练更需要裁剪 |

1.0 是几乎所有 LLM 训练的标准值。如果你发现梯度范数经常超过 1.0（训练日志中会打印），可能说明学习率太大或数据有问题。

## 5.5 权重衰减（Weight Decay）

### 5.5.1 直觉理解

权重衰减是一种正则化手段，防止模型参数"长得太大"：

```
θ_{t+1} = θ_t - η × λ × θ_t   ← 权重衰减项
```

每步都把参数往 0 方向缩小一点。效果等价于 **L2 正则化**（在 loss 中加 `λ/2 × ||θ||²`），但 AdamW 把它从梯度更新中解耦出来，效果更好。

### 5.5.2 为什么只对矩阵参数做衰减

回顾 5.2.2 节的分组：

```python
if p.dim() >= 2:
    decay.append(p)       # 大矩阵：需要正则化
else:
    no_decay.append(p)    # 1D 参数：不需要
```

**1D 参数为什么不需要衰减？**

- **Bias**：数量少（每层才几个到几千个），衰减会限制模型调整偏移的能力
- **LayerNorm 的 weight**：它是归一化的缩放因子，需要精确控制每维的尺度
- **Embedding 虽然也是 2D**，但它本质上是一个大查找表，和 Linear 的权重矩阵类似，也需要衰减

### 5.5.3 各阶段的权重衰减

| 阶段 | weight_decay | 说明 |
|------|-------------|------|
| 预训练 | 0.1 | 从随机初始化训练，需要较强正则化 |
| SFT | 0.0 | 微调，不需要额外正则化 |
| Reward | 0.0 | 同上 |
| DPO | 0.0 | 同上 |

预训练是唯一使用权重衰减的阶段（`weight_decay=0.1`，这是 GPT-3 论文推荐的值）。后训练阶段数据量小、训练步数少，过拟合风险低，不需要额外的正则化。

## 5.6 训练循环全解析

现在把所有组件串起来，看看完整的训练循环长什么样。

### 5.6.1 单步训练流程

```
┌─────────────────────────────────────────────────────────────┐
│                     一个 optimizer step                      │
│                                                             │
│  ┌─── micro-batch 0 ───┐                                   │
│  │ forward(x, y) → loss │                                   │
│  │ loss /= grad_accum   │                                   │
│  │ loss.backward()       │  → 梯度累积到 .grad              │
│  └──────────────────────┘                                   │
│  ┌─── micro-batch 1 ───┐                                   │
│  │ forward(x, y) → loss │                                   │
│  │ loss /= grad_accum   │                                   │
│  │ loss.backward()       │  → 梯度继续累积                   │
│  └──────────────────────┘                                   │
│          ...                                                │
│  ┌─── micro-batch N-1 ─┐                                   │
│  │ forward(x, y) → loss │                                   │
│  │ loss /= grad_accum   │                                   │
│  │ loss.backward()       │  → 梯度累积完成                   │
│  └──────────────────────┘                                   │
│                                                             │
│  clip_grad_norm_(params, 1.0)    ← 梯度裁剪                 │
│  set_lr(optimizer, cosine_lr)    ← 更新学习率               │
│  optimizer.step()                ← AdamW 更新参数           │
│  optimizer.zero_grad()           ← 清零梯度                 │
└─────────────────────────────────────────────────────────────┘
```

### 5.6.2 核心代码

```python
# scripts/pretrain_base.py — 完整训练循环

model.train()
for step in range(start_step, cfg.train_steps):
    # ① 计算学习率
    lr = cosine_lr(step, warmup_steps=cfg.warmup_steps,
                   max_steps=cfg.train_steps,
                   lr=cfg.lr, min_lr=cfg.min_lr)
    for g in optimizer.param_groups:
        g["lr"] = lr

    # ② 清零梯度（set_to_none=True 比 zero 更省显存）
    optimizer.zero_grad(set_to_none=True)

    # ③ 梯度累积
    accum_loss = 0.0
    for micro in range(cfg.grad_accum):
        xb, yb = next(batch_iter)
        with amp_autocast(cfg.amp_dtype, ctx.device):
            _, loss = model(xb, yb)
            loss = loss / cfg.grad_accum    # 缩放 loss
        loss.backward()                      # 梯度累积到 .grad
        accum_loss += loss.item()

    # ④ 梯度裁剪
    torch.nn.utils.clip_grad_norm_(model.parameters(), cfg.grad_clip)

    # ⑤ 参数更新
    optimizer.step()

    # ⑥ 日志
    if step % 20 == 0:
        print(f"step {step} | loss {accum_loss:.4f} | lr {lr:.2e}")
```

### 5.6.3 `zero_grad(set_to_none=True)` 的妙用

传统写法：

```python
optimizer.zero_grad()   # 把所有 .grad 设为 0 的张量
```

优化写法：

```python
optimizer.zero_grad(set_to_none=True)   # 把 .grad 设为 None
```

设为 `None` 比设为全零张量更好：
- **省显存**：不需要分配全零张量的内存
- **省计算**：下一次 `backward()` 时直接赋值，而不是累加到零

### 5.6.4 `loss / grad_accum` 的数学正确性

为什么要在反向传播前除以 `grad_accum`？

```
完整 batch 的梯度 = (1/B) × Σᵢ ∇Lᵢ

分成 N 个 micro-batch 后:
  micro-batch k 的梯度 = (1/b) × Σᵢ∈batch_k ∇Lᵢ    （b = B/N）

累积 N 次后:
  累积梯度 = Σₖ (1/b) × Σᵢ∈batch_k ∇Lᵢ
           = (N/b) × (1/B) × Σᵢ ∇Lᵢ
           = (N/b) × 完整 batch 梯度

要让它等于完整 batch 梯度，需要除以 N：
  累积梯度 / N = 完整 batch 梯度

在代码中，我们对每个 micro-batch 的 loss 除以 N（= grad_accum），
这样反向传播得到的梯度也自动除以 N，累积 N 次后正好等于完整 batch 的梯度。
```

## 5.7 优化器的状态管理

### 5.7.1 AdamW 的额外显存

AdamW 为**每个参数**维护 4 个额外的值：

```
参数 θ:  4 bytes (fp32)
动量 m:  4 bytes (fp32)   ← 梯度的指数移动平均
方差 v:  4 bytes (fp32)   ← 梯度平方的指数移动平均
梯度 g:  4 bytes (fp32)   ← 当前梯度
─────────────────────────
合计:    16 bytes/参数
```

这就是第 4 章中"每个参数约 16 字节"的来源。

### 5.7.2 保存和恢复优化器状态

训练中断后可以从 checkpoint 恢复，包括优化器状态：

```python
# 保存
save_stage_ckpt(cfg.out_ckpt, model, optimizer, ...)

# 恢复
ck = torch.load(resume, map_location="cpu", weights_only=False)
unwrap(model).load_state_dict(ck["model_state_dict"])
optimizer.load_state_dict(ck["optimizer_state_dict"])
start_step = ck.get("step", 0)
```

恢复优化器状态意味着 `m` 和 `v` 都被恢复，模型可以无缝继续训练，不会丢失自适应学习率的历史信息。

## 5.8 各阶段优化策略对比

| | 预训练 | SFT | Reward | DPO | PPO | GRPO |
|---|--------|-----|--------|-----|-----|------|
| 优化器 | AdamW | AdamW | AdamW | AdamW | AdamW | AdamW |
| lr | 3e-4 | 1e-5 | 1e-5 | 5e-7 | 1e-6 | 1e-6 |
| min_lr | 3e-5 | 1e-6 | — | — | — | — |
| weight_decay | 0.1 | 0.0 | 0.0 | 0.0 | — | — |
| grad_clip | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| warmup_steps | 2,000 | 100 | 50 | 50 | — | — |
| betas | (0.9, 0.95) | (0.9, 0.95) | (0.9, 0.95) | (0.9, 0.95) | (0.9, 0.95) | (0.9, 0.95) |
| 调度 | Cosine | Cosine | Cosine | Cosine | 固定 | 固定 |

**关键观察**：

1. **学习率逐阶段递减**：3e-4 → 1e-5 → 5e-7 → 1e-6，每降低一个数量级，参数更新的幅度越小
2. **只有预训练使用权重衰减**：因为预训练从随机初始化开始，数据量大、训练步数多，过拟合风险最高
3. **Warmup 逐阶段缩短**：2000 → 100 → 50，因为后训练从已有的好 checkpoint 开始，不需要长时间"探路"
4. **PPO/GRPO 用固定学习率**：RL 训练步数少（~1000），调度带来的收益有限

## 5.9 本章小结

### 优化器选择

```
始终使用 AdamW + betas=(0.9, 0.95)
```

### 学习率调度公式

```
Warmup 阶段:  η = η_max × (step + 1) / warmup_steps
Cosine 阶段:  η = η_min + 0.5 × (1 + cos(π × progress)) × (η_max - η_min)
```

### 训练循环五步

```
① 计算学习率（cosine_lr）
② 清零梯度（zero_grad set_to_none）
③ 梯度累积（N 个 micro-batch 的 loss/grad_accum + backward）
④ 梯度裁剪（clip_grad_norm 1.0）
⑤ 参数更新（optimizer.step）
```

### 权重衰减分组

```
dim ≥ 2 的矩阵参数 → 衰减（weight_decay=0.1，仅预训练）
dim < 2 的 1D 参数 → 不衰减（weight_decay=0.0）
```

---

## 练习

**练习 1：学习率曲线可视化**

用 matplotlib 画出以下配置的学习率曲线：
- 预训练：warmup=2000, lr=3e-4, min_lr=3e-5, max_steps=200000
- SFT：warmup=100, lr=1e-5, min_lr=1e-6, max_steps=3000

画在同一个图上（用两个 y 轴或两个子图），对比两者的差异。

**练习 2：梯度裁剪实验**

编写代码验证 `clip_grad_norm_` 的行为：

```python
import torch

model = torch.nn.Linear(10, 10)
# 手动设置一个很大的梯度
for p in model.parameters():
    p.grad = torch.randn_like(p) * 100

# 裁剪前
total_norm = torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
print(f"原始梯度范数: {total_norm:.2f}")

# 裁剪后
new_norm = 0
for p in model.parameters():
    new_norm += p.grad.norm().item() ** 2
print(f"裁剪后梯度范数: {new_norm**0.5:.2f}")
```

观察：裁剪后范数应该是 1.0（或更小，如果原始范数小于 1.0）。

**练习 3：Warmup 的重要性**

修改 `pretrain_base.py`，把 `warmup_steps` 设为 0（不做 Warmup），观察前 100 步的 loss 变化。和正常 Warmup 对比：
- 没有 Warmup 时，前几步的 loss 是不是会突然暴涨？
- 多少步后才恢复正常？

**练习 4：权重衰减分组统计**

编写代码，统计 31M 模型（`n_embed=256, n_head=4, n_blocks=6`）中，有多少参数需要权重衰减，有多少不需要：

```python
from src.post_training.utils import build_model_from_config
# ... 构建模型 ...
decay_params = 0
no_decay_params = 0
for name, p in model.named_parameters():
    if p.dim() >= 2:
        decay_params += p.numel()
    else:
        no_decay_params += p.numel()
print(f"衰减组: {decay_params:,}")
print(f"不衰减组: {no_decay_params:,}")
```

观察：不衰减组的参数占总参数的多少？（提示：主要来自 LayerNorm 的 weight 和 bias）
