# 第 4 章：关键超参数与硬件规划

> **本章目标**：理解 5 个核心超参数的含义和相互约束关系，学会估算显存预算，根据手头的硬件规划合适的模型配置。

## 4.0 本章路线图

训练一个 LLM 之前，你必须回答两个问题：

1. **模型要多大？** —— 由 `n_embed`、`n_head`、`n_blocks` 决定
2. **能跑起来吗？** —— 由 GPU 显存和显存预算决定

这两个问题的答案互相制约：模型越大越好，但显存有限。本章就是教你如何在这两者之间找到最佳平衡。

```
超参数选择
    │
    ├── 5 个核心超参数（含义、取值范围、相互约束）
    ├── 参数量估算公式（快速心算）
    ├── Chinchilla 法则（数据 vs 参数的黄金比例）
    ├── 显存预算分析（4 个组成部分）
    ├── GPU 选型指南（8GB / 16GB / 24GB / 40GB / 80GB）
    └── 显存优化三件套（混合精度 + 梯度累积 + 梯度检查点）
```

## 4.1 五个核心超参数

本项目的模型由 5 个超参数完全定义：

```python
# config/post_training_config.py — BaseModelConfig
vocab_size: int = 50304        # 词汇表大小
context_length: int = 1024     # 上下文窗口长度
n_embed: int = 1024            # 嵌入维度（"模型的宽度"）
n_head: int = 16               # 注意力头数
n_blocks: int = 24             # Transformer Block 层数（"模型的深度"）
```

### 4.1.1 `vocab_size`：词汇表大小

**含义**：模型能"认识"的不同 token 数量。

**约束**：
- 由分词器决定，不能随意修改
- 本项目使用 `tiktoken.get_encoding("r50k_base")`，共 50257 个 token
- 实际取 50304 = 50257 + 47（向上对齐到 64 的倍数，对矩阵运算更友好）

**影响**：
- Token Embedding：`vocab_size × n_embed` 个参数
- lm_head：`n_embed × vocab_size + vocab_size` 个参数
- 越大 → Embedding 层参数越多，但覆盖的语言越丰富

**典型取值**：

| 分词器 | vocab_size | 模型 |
|--------|-----------|------|
| r50k_base | 50257 | GPT-3 |
| cl100k_base | 100256 | GPT-4 |
| 自定义 | 32000 | LLaMA |

### 4.1.2 `context_length`：上下文窗口长度

**含义**：模型一次能处理的最大 token 数。

**约束**：
- 决定了 Position Embedding 的大小：`context_length × n_embed`
- 决定了注意力矩阵的大小：`T × T`（T 是实际序列长度）
- **注意力计算是 O(T²)**，这是最大的性能瓶颈

**显存影响**（注意力矩阵部分）：

```
context_length=256:   256 × 256 × n_head × 4 bytes = ~1 MB
context_length=1024:  1024 × 1024 × n_head × 4 bytes = ~16 MB
context_length=4096:  4096 × 4096 × n_head × 4 bytes = ~256 MB
context_length=8192:  8192 × 8192 × n_head × 4 bytes = ~1 GB
```

每翻一倍，注意力显存需求翻 4 倍。这就是为什么长上下文是大模型的核心挑战。

**典型取值**：

| context_length | 场景 | 示例 |
|----------------|------|------|
| 256 | 单轮短对话、分类 | 本项目小模型 |
| 1024 | 标准对话、短文生成 | 本项目中型模型 |
| 4096 | 长文档、代码 | LLaMA-2 |
| 8192+ | 超长上下文 | GPT-4 Turbo |

### 4.1.3 `n_embed`：嵌入维度（模型的"宽度"）

**含义**：每个 token 用多少个浮点数来表示。

**约束**：
- 必须是 `n_head` 的整数倍（否则每个头的 `head_size` 不是整数）
- 通常是 64 的倍数（方便矩阵运算，对 GPU 更友好）
- 决定了模型中**所有**线性层的维度

**影响**：
- 几乎所有组件的参数量都和 `n_embed` 成正比
- 更大的 `n_embed` → 更强的表达能力 → 更多的参数和显存

**典型取值**：

| n_embed | 场景 | 参数量级 |
|---------|------|----------|
| 128 | 学习/实验 | ~15M |
| 256 | 小模型/快速验证 | ~30M |
| 512 | 中型模型 | ~150M |
| 768 | 中型模型 | ~350M |
| 1024 | 大型模型 | ~500M |
| 2048 | 旗舰模型 | ~1.5B |

### 4.1.4 `n_head`：注意力头数

**含义**：模型从多少个"视角"同时看序列。

**约束**：
- `n_embed % n_head == 0`（必须整除）
- `head_size = n_embed // n_head`（每个头的维度）
- 通常保持 `head_size = 64` 或 `128`

**经验公式**：

```python
n_head = n_embed // 64   # 保持每个头 64 维
```

所以：

| n_embed | 推荐 n_head | head_size |
|---------|-------------|-----------|
| 128 | 2 | 64 |
| 256 | 4 | 64 |
| 512 | 8 | 64 |
| 1024 | 16 | 64 |
| 2048 | 32 | 64 |

> 详见第 3 章 3.4.4 节：改变 `n_head` 不改变参数量，但改变模型从多少个视角看问题。

### 4.1.5 `n_blocks`：Transformer Block 层数（模型的"深度"）

**含义**：模型有多少层 Transformer Block。

**约束**：
- 每个 Block 独立增加参数量
- 层数越多 → 越深的网络 → 越难训练（需要更精细的学习率和更长的训练）
- 残差连接让深层网络可以训练，但超过一定深度收益递减

**影响**：
- 参数量线性增加：`n_blocks × 单个Block参数`
- 前向传播时间线性增加
- 激活值显存线性增加

**典型取值**：

| n_blocks | 场景 | 代表模型 |
|----------|------|----------|
| 2-6 | 快速实验 | 本项目小模型 |
| 12 | 中型模型 | GPT-2 Small |
| 24 | 大型模型 | 本项目中型 |
| 36 | 旗舰模型 | GPT-2 Large |
| 96+ | 超大规模 | LLaMA-70B |

## 4.2 参数量快速估算

### 4.2.1 精确公式

在第 3 章 3.8 节，我们详细拆解了每个组件的参数量。这里给出一个可以直接心算的**近似公式**：

```
总参数 ≈ vocab_size × n_embed × 2  +  n_blocks × 12 × n_embed²
         ─────────────────────       ─────────────────────────
         Embedding + lm_head         Transformer Blocks
         (首尾两层)                   (中间 N 层)
```

**为什么是 `12 × n_embed²`？**

一个 Block 包含：
- MultiHeadAttention: K/Q/V 投影 + 输出投影 ≈ `4 × n_embed²`
- MLP: hidden + proj ≈ `8 × n_embed²`（因为 4 倍扩展）
- LayerNorm × 2: 可忽略
- 合计: ≈ `12 × n_embed²`

### 4.2.2 心算示例

以本项目的三种配置为例：

```python
# 配置 1: configs/base.json（小模型）
# vocab_size=50304, n_embed=256, n_blocks=6

Embedding + lm_head:  50304 × 256 × 2 ≈ 25.8M
Blocks:               6 × 12 × 256²    ≈ 4.7M
总计:                 ≈ 30.5M ✓（精确值 30,605,952）
```

```python
# 配置 2: BaseModelConfig 默认（中型模型）
# vocab_size=50304, n_embed=1024, n_blocks=24

Embedding + lm_head:  50304 × 1024 × 2 ≈ 103M
Blocks:               24 × 12 × 1024²   ≈ 302M
总计:                 ≈ 405M ✓（精确值约 400M）
```

```python
# 配置 3: config/config.py（旗舰模型）
# vocab_size=50304, n_embed=2048, n_blocks=64

Embedding + lm_head:  50304 × 2048 × 2 ≈ 206M
Blocks:               64 × 12 × 2048²   ≈ 3.2G
总计:                 ≈ 3.4B
```

### 4.2.3 关键洞察

观察上面的三个例子：

| 配置 | Embedding 占比 | Block 占比 |
|------|---------------|-----------|
| 小模型 (31M) | 84% | 16% |
| 中型模型 (405M) | 25% | 75% |
| 旗舰模型 (3.4B) | 6% | 94% |

**小模型**的参数量几乎全在 Embedding 里，真正的"智能"（注意力+MLP）只占 16%。这也是为什么小模型效果有限——它没有足够的"思考空间"。

**大模型**的参数量主要在 Block 里，Embedding 几乎可以忽略。这说明扩大模型应该优先增加 `n_embed` 和 `n_blocks`，而不是 `vocab_size`。

## 4.3 Chinchilla 法则：数据 vs 参数的黄金比例

有了模型，下一个问题是：**需要多少训练数据？**

### 4.3.1 什么是 Chinchilla 法则

2022 年 DeepMind 的论文《Training Compute-Optimal Large Language Models》（"Chinchilla 论文"）发现了一个经验法则：

> **数据 token 数 ≈ 参数量 × 20**

也就是说，每个参数大约需要 20 个 token 的训练数据。

| 模型参数量 | 推荐数据量 | 训练步数（batch=192, ctx=1024） |
|-----------|-----------|-------------------------------|
| 30M | ~600M tokens | ~3,000 steps |
| 125M | ~2.5B tokens | ~12,000 steps |
| 400M | ~8B tokens | ~40,000 steps |
| 7B | ~140B tokens | ~700,000 steps |

### 4.3.2 本项目的数据量

```python
# 数据路径
train_path = "/ephemeral/data/pile_train.h5"   # 约 6.3 GB

# 估算 token 数
# HDF5 存储的是 int32 (4 bytes/token)
# 6.3 GB / 4 bytes ≈ 1.575B tokens
```

以中型模型（400M 参数）为例：
- Chinchilla 推荐：400M × 20 = 8B tokens
- 实际数据：~1.5B tokens
- **数据量只有推荐值的 19%** —— 这意味着模型可能"吃不饱"

解决方案：
1. **缩小模型**：用 90M 参数的模型，1.5B tokens 基本够用（推荐 1.8B）
2. **增加数据**：下载更多 Pile 数据或使用数据重复
3. **接受欠拟合**：对于学习目的，1.5B tokens 足以看到模型学到有意义的语言模式

### 4.3.3 训练步数估算

```python
# 每步处理的 token 数
tokens_per_step = batch_size × context_length × grad_accum × world_size
                = 8 × 256 × 12 × 1        # 单 GPU
                = 24,576 tokens/step

# 总训练步数
total_steps = total_tokens / tokens_per_step
            = 1,500,000,000 / 24,576
            ≈ 61,000 steps

# 本项目实际配置
# pretrain.json: train_steps = 1000（快速验证）
# PretrainConfig: train_steps = 200,000（完整训练）
```

实际训练时，1000 步足以看到 loss 明显下降，但远未达到最优。完整训练需要数万步。

## 4.4 显存预算分析

训练一个 LLM 需要多少显存？显存被 4 个部分瓜分：

```
总显存 = ① 模型参数 + ② 优化器状态 + ③ 梯度 + ④ 激活值
         ────────   ────────────   ────   ──────
         ~20%        ~40%           ~20%   ~20%
```

### 4.4.1 ① 模型参数

每个参数在 fp32 下占 4 字节：

```
参数显存 = 参数量 × 4 bytes
```

以 400M 模型为例：`400M × 4 = 1.6 GB`

### 4.4.2 ② 优化器状态（AdamW 的大头）

AdamW 为每个参数维护两个额外的状态：
- **一阶动量（m）**：梯度的指数移动平均 → 每个参数 4 bytes
- **二阶动量（v）**：梯度平方的指数移动平均 → 每个参数 4 bytes

```
优化器显存 = 参数量 × 8 bytes (m + v, 都是 fp32)
```

以 400M 模型为例：`400M × 8 = 3.2 GB`

**注意**：即使在 bf16 混合精度训练中，优化器状态**始终是 fp32**（这是数值稳定性的要求）。

### 4.4.3 ③ 梯度

每个参数有一个梯度，和参数同精度：

```
梯度显存 = 参数量 × 4 bytes (fp32)
```

以 400M 模型为例：`400M × 4 = 1.6 GB`

### 4.4.4 ④ 激活值（最容易被忽视的大头）

激活值是前向传播过程中每一层的中间结果。反向传播时需要它们来计算梯度。

激活值的显存取决于：
- `batch_size`：每多一个样本，激活值翻一倍
- `context_length`：序列越长，激活值越多
- `n_embed`：维度越大，每个激活值占越多空间
- `n_blocks`：层数越多，保存的中间结果越多

粗略估算：

```
激活值显存 ≈ batch_size × context_length × n_embed × n_blocks × 18 bytes
             ──────────────────────────────────────────────────────
             每个 token 每层有 ~18 个中间值（attention 的 QKV + MLP 的中间扩展 + 残差等）
```

以 batch_size=8, context_length=256, n_embed=1024, n_blocks=24 为例：

```
8 × 256 × 1024 × 24 × 18 ≈ 850 MB
```

### 4.4.5 总预算

| 组件 | 公式 | 400M 模型 (fp32) |
|------|------|-----------------|
| ① 参数 | P × 4 | 1.6 GB |
| ② 优化器 | P × 8 | 3.2 GB |
| ③ 梯度 | P × 4 | 1.6 GB |
| ④ 激活值 | ~估算 | ~0.9 GB |
| **总计** | **P × 16 + 激活** | **~7.3 GB** |

**经验法则：fp32 训练，每个参数约需 16 字节显存。**

```
显存 ≈ 参数量 × 16 bytes + 激活值
```

## 4.5 GPU 选型与最大模型估算

根据上面的公式，我们可以反推不同 GPU 能训练多大的模型：

```
最大参数量 = (显存 - 激活值) / 16
```

### 4.5.1 各 GPU 最大模型

| GPU | 显存 | 可用显存（留 20% 余量） | 最大参数量（fp32） | 最大参数量（bf16） |
|-----|------|----------------------|-------------------|-------------------|
| RTX 3060 | 12 GB | 9.6 GB | ~500M | ~800M |
| RTX 3070 | 8 GB | 6.4 GB | ~350M | ~550M |
| RTX 4060 Ti | 16 GB | 12.8 GB | ~700M | ~1.1B |
| RTX 3090 | 24 GB | 19.2 GB | ~1.1B | ~1.8B |
| RTX 4090 | 24 GB | 19.2 GB | ~1.1B | ~1.8B |
| A100 | 40 GB | 32 GB | ~1.8B | ~3B |
| A100 | 80 GB | 64 GB | ~3.8B | ~6B |
| H100 | 80 GB | 64 GB | ~3.8B | ~6B |

> bf16 混合精度下，参数和梯度各占 2 bytes（而非 4），优化器状态仍然是 fp32（8 bytes），所以每参数约 12 bytes。

### 4.5.2 本项目的配置选择

```python
# config/post_training_config.py — BaseModelConfig 默认值
n_embed = 1024
n_head = 16
n_blocks = 24
# 约 400M 参数

# 在 H100 80GB 上的显存预算:
# 400M × 16 bytes = 6.4 GB（fp32 训练）
# 即使 batch_size=24, context_length=1024，激活值约 3.6 GB
# 总计约 10 GB —— 80 GB 绰绰有余！
```

```python
# configs/base.json — 小模型配置
n_embed = 256
n_head = 4
n_blocks = 6
# 约 31M 参数

# 在 16 GB 显卡上的显存预算:
# 31M × 16 bytes = ~500 MB
# 激活值可忽略
# 总计约 500 MB —— 16 GB 极其充裕
```

### 4.5.3 实际配置建议

**16 GB 显卡（如 RTX 4060 Ti）**

```python
# 舒适配置：~90M 参数
n_embed = 384   # 384 × 384 × 12 × 12 ≈ 212M blocks
n_head = 6
n_blocks = 12
# 实际约 90M（含 Embedding）

# 激进配置：~200M 参数（需要 bf16 + 梯度累积）
n_embed = 512
n_head = 8
n_blocks = 12
```

**24 GB 显卡（如 RTX 3090 / 4090）**

```python
# 舒适配置：~400M 参数
n_embed = 1024
n_head = 16
n_blocks = 24
```

**80 GB 显卡（如 H100）**

```python
# 舒适配置：~1.5B 参数
n_embed = 2048
n_head = 32
n_blocks = 24

# 大配置：~3B 参数（需要 bf16）
n_embed = 2048
n_head = 32
n_blocks = 48
```

## 4.6 显存优化三件套

当模型太大显存不够时，有三个递进的优化手段：

### 4.6.1 混合精度训练（bf16 / fp16）

**原理**：前向和反向传播用低精度（bf16，2 bytes），优化器状态保持高精度（fp32，4 bytes）。

**显存节省**：参数和梯度从 4 bytes → 2 bytes，节省约 40%。

```python
# config/config.py
USE_AMP = True          # 启用混合精度
AMP_DTYPE = "bf16"      # 推荐 bf16（不需要 GradScaler）

# 代码中的使用
with amp_autocast(cfg.amp_dtype, ctx.device):
    _, loss = model(xb, yb)
```

**bf16 vs fp16**：

| | bf16 | fp16 |
|---|------|------|
| 数值范围 | 和 fp32 一样大 | 较小，容易溢出 |
| 精度 | 较低（尾数更短） | 较高 |
| GradScaler | 不需要 | 需要 |
| GPU 要求 | Ampere+ (RTX 30xx+) | 所有支持 FP16 的 GPU |
| **推荐** | **首选** | 旧 GPU 备选 |

本项目的 `amp_autocast` 封装了混合精度的上下文管理：

```python
# src/post_training/utils.py
@contextlib.contextmanager
def amp_autocast(dtype_str, device):
    if dtype_str and device == "cuda":
        dtype = torch.bfloat16 if dtype_str == "bf16" else torch.float16
        with torch.autocast(device_type="cuda", dtype=dtype):
            yield
    else:
        yield
```

**显存对比**（400M 模型）：

| 组件 | fp32 | bf16 混合精度 |
|------|------|-------------|
| 参数 | 1.6 GB | 0.8 GB |
| 优化器状态 | 3.2 GB | 3.2 GB（不变！） |
| 梯度 | 1.6 GB | 0.8 GB |
| 激活值 | 0.9 GB | ~0.5 GB |
| **总计** | **7.3 GB** | **~5.3 GB** |

### 4.6.2 梯度累积（Gradient Accumulation）

**原理**：不一次性处理完整的 batch，而是分成多个 micro-batch，累积梯度后再更新参数。

**显存节省**：激活值按 micro-batch 大小缩放。

```python
# config/post_training_config.py — PretrainConfig
batch_size: int = 24     # 每个 micro-batch 的大小
grad_accum: int = 8      # 累积多少次后更新

# 有效 batch = batch_size × grad_accum × world_size
# = 24 × 8 × 1 = 192 sequences/step
```

**训练循环中的实现**（`pretrain_base.py`）：

```python
for step in range(start_step, cfg.train_steps):
    optimizer.zero_grad(set_to_none=True)

    for micro in range(cfg.grad_accum):
        xb, yb = next(batch_iter)

        # 只在最后一个 micro-step 同步梯度（DDP 优化）
        sync = (micro == cfg.grad_accum - 1) or not ctx.enabled
        cm = model.no_sync() if (ctx.enabled and not sync) else _nullcm()

        with cm, amp_autocast(cfg.amp_dtype, ctx.device):
            _, loss = model(xb, yb)
            loss = loss / cfg.grad_accum   # 缩放 loss 使得累积梯度正确

        loss.backward()

    optimizer.step()  # 累积完所有 micro-batch 后更新
```

关键细节：
- `loss / cfg.grad_accum`：每个 micro-batch 的 loss 缩小 N 倍，这样累积的梯度和一次完整 batch 的梯度等价
- `model.no_sync()`：DDP 模式下，前面的 micro-batch 不需要同步梯度（节省通信时间），只在最后一个 micro-batch 同步

**显存对比**（400M 模型，bf16，有效 batch=192）：

| | 一次完整 batch=192 | micro-batch=24, accum=8 |
|---|-------------------|------------------------|
| 激活值 | ~10 GB | ~1.3 GB |
| **总显存** | ~16 GB | **~7 GB** |

### 4.6.3 梯度检查点（Gradient Checkpointing）

**原理**：前向传播时不保存所有激活值，只保存每 N 层的"检查点"。反向传播时重新计算中间层的激活值。

**显存节省**：激活值从 O(N) 降到 O(√N)（N 是层数）。

**代价**：训练速度降低约 20-30%（因为要重新计算一次前向传播）。

```python
# config/config.py
USE_GRADIENT_CHECKPOINTING = True

# src/models/transformer.py — forward_hidden
def forward_hidden(self, idx):
    x = self._pre_attn_pass(idx)
    for block in self.attn_blocks:
        if self.gradient_checkpointing and self.training:
            # 不保存中间激活值，反向传播时重新计算
            x = checkpoint.checkpoint(block, x, use_reentrant=False)
        else:
            x = block(x)
    return self.layer_norm(x)
```

`use_reentrant=False` 是 PyTorch 推荐的新写法，比旧版 `use_reentrant=True` 更安全。

**显存对比**（400M 模型，bf16，batch=24，24 层）：

| | 不用检查点 | 用检查点 |
|---|----------|---------|
| 激活值 | ~1.3 GB | ~0.3 GB |
| 训练速度 | 100% | ~75% |

### 4.6.4 优化手段组合

| 优化手段 | 显存节省 | 速度代价 | 推荐场景 |
|----------|---------|---------|---------|
| bf16 混合精度 | ~30% | 无（甚至更快） | **始终启用** |
| 梯度累积 | 按倍数降低激活值 | 无 | batch_size 受限 |
| 梯度检查点 | ~75% 激活值 | ~25% 减速 | 模型层数多时 |
| 三者组合 | ~80-90% | ~25% 减速 | 训练大模型 |

## 4.7 项目配置体系

本项目的配置通过四层系统确定优先级，从低到高：

```
1. dataclass 默认值      (config/post_training_config.py)
   ↓ 被覆盖
2. base.json             (configs/base.json)
   ↓ 被覆盖
3. stage.json            (configs/pretrain.json / sft.json / ...)
   ↓ 被覆盖
4. CLI 命令行参数         (--batch_size 16 --lr 3e-4)
```

### 4.7.1 配置加载流程

```python
# scripts/pretrain_base.py
cfg, extras = parse_config_with_json(
    PretrainConfig,              # dataclass 提供默认值
    "configs/pretrain.json",     # JSON 文件覆盖
    extra={...}                  # CLI 参数再覆盖
)
```

### 4.7.2 不同阶段的配置

| 阶段 | 配置文件 | 关键超参 |
|------|---------|---------|
| 预训练 | `pretrain.json` | `batch_size`, `grad_accum`, `lr`, `train_steps` |
| SFT | `sft.json` | `batch_size`, `epochs`, `lr`（更小的学习率） |
| Reward | `reward.json` | `batch_size`, `max_len` |
| DPO | `dpo.json` | `beta`, `loss_type` |
| PPO | `ppo.json` | `clip`, `kl_coef`, `rollout_len` |
| GRPO | `grpo.json` | `group_size`, `kl_coef` |

模型架构（`n_embed`, `n_head`, `n_blocks`, `context_length`, `vocab_size`）在所有阶段**必须一致**——后训练只改变训练策略，不改变模型结构。

## 4.8 本章小结

### 超参数速查

| 超参数 | 含义 | 典型值 | 约束 |
|--------|------|--------|------|
| `vocab_size` | 词汇表大小 | 50304 | 由分词器决定 |
| `context_length` | 上下文窗口 | 256-4096 | 注意力 O(T²) |
| `n_embed` | 嵌入维度 | 256-2048 | 64 的倍数 |
| `n_head` | 注意力头数 | 4-32 | `n_embed % n_head == 0` |
| `n_blocks` | Block 层数 | 6-96 | 无硬约束 |

### 显存公式速查

```
参数量 ≈ vocab_size × n_embed × 2 + n_blocks × 12 × n_embed²
显存（fp32）≈ 参数量 × 16 + 激活值
显存（bf16）≈ 参数量 × 12 + 激活值
激活值 ≈ batch × ctx_len × n_embed × n_blocks × 18 bytes
数据量（Chinchilla）≈ 参数量 × 20 tokens
```

### 优化手段优先级

```
1. bf16 混合精度     → 免费提速，始终启用
2. 梯度累积          → 免费降显存，batch 受限时用
3. 梯度检查点        → 牺牲 25% 速度换 75% 激活值，大模型用
```

---

## 练习

**练习 1：配置一个 16 GB 显卡的模型**

你有一张 16 GB 的 RTX 4060 Ti。请设计一个模型配置，使得：
- 参数量尽可能大
- 能用 bf16 混合精度训练
- batch_size=8, context_length=256
- 激活值不超过 2 GB

提示：从 `n_embed=384, n_head=6, n_blocks=12` 开始，逐步调大，用公式估算显存。

**练习 2：Chinchilla 计算**

如果你有 10 GB 的训练数据（HDF5 int32 格式），根据 Chinchilla 法则，你应该训练多大的模型？如果 `n_embed=512`，应该设多少 `n_blocks`？

**练习 3：梯度累积的等价性验证**

编写一段代码，验证 `batch_size=16, grad_accum=1` 和 `batch_size=4, grad_accum=4` 在相同数据上的梯度是否相同（提示：用 `torch.allclose` 比较）。

**练习 4：显存预算计算器**

编写一个 Python 函数，输入 `n_embed, n_head, n_blocks, vocab_size, context_length, batch_size, precision`（"fp32" 或 "bf16"），输出各项显存预算和总显存：

```python
def vram_budget(n_embed, n_head, n_blocks, vocab_size, context_length, batch_size, precision="fp32"):
    # 计算参数量
    # 计算参数显存
    # 计算优化器显存
    # 计算梯度显存
    # 计算激活值显存
    # 返回总显存
    pass
```

用这个函数计算：400M 模型在 bf16 下，batch_size=16, context_length=1024 需要多少显存？
