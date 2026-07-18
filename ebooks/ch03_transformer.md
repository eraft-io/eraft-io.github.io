# 第 3 章：Transformer 架构——从最小单元到完整模型

> **本章目标**：从零开始构建一个完整的 Transformer 模型。我们会像搭积木一样，从最小的零件开始，一步步堆叠出一个能处理语言的神经网络。

## 3.0 本章路线图

在开始写代码之前，先看看我们要构建什么。一个完整的 Transformer 模型由四个层次的组件组成：

```
Transformer 模型
│
├── Token Embedding      ← 把 token ID 变成向量
├── Position Embedding   ← 告诉模型 token 的位置
│
├── Transformer Block × N  ← 核心处理单元（重复 N 次）
│   ├── LayerNorm
│   ├── Multi-Head Attention  ← 多个注意力头并行
│   │   └── Head × n_head      ← 单个注意力头
│   ├── 残差连接
│   ├── LayerNorm
│   ├── MLP                    ← 前馈网络
│   └── 残差连接
│
├── LayerNorm（最终）
└── lm_head（输出层）     ← 把向量变成词汇表上的概率分布
```

我们会自底向上构建：**MLP → Head → MultiHeadAttention → Block → Transformer**。每完成一个组件，都会用一段代码验证它的输入输出形状。

## 3.1 Embedding：把 token 变成向量

### 3.1.1 为什么需要 Embedding

在上一章，我们把文本变成了整数序列。但模型不能直接在整数上做运算——它需要连续的、稠密的向量。

Embedding 就是一个查找表（lookup table）：每个 token ID 对应一个固定长度的向量。

```python
# 假设 vocab_size = 50304, n_embed = 256
token_embed = nn.Embedding(50304, 256)

# 输入 token ID: 31373 ("hello")
# 输出: 一个 256 维的向量
vector = token_embed(torch.tensor([31373]))
print(vector.shape)  # torch.Size([1, 256])
```

直觉上，你可以把 Embedding 想象成一本"词典"：

```
token ID 31373 ("hello")  →  [0.12, -0.34, 0.56, ..., 0.78]  (256 个浮点数)
token ID 995 (" world")   →  [-0.21, 0.45, -0.12, ..., 0.33]  (256 个浮点数)
token ID 4673 ("learning") →  [0.67, -0.89, 0.11, ..., -0.44]  (256 个浮点数)
```

这些向量一开始是随机的，在训练过程中，模型会逐渐学会让语义相近的词拥有相近的向量。

### 3.1.2 位置编码：告诉模型"顺序"

Token Embedding 有一个问题：它不包含位置信息。`"hello world"` 和 `"world hello"` 的 token embedding 之和是一样的——但这两句话的含义完全不同。

我们需要告诉模型每个 token 在序列中的位置。最简单的做法是再加一个 Embedding 表：

```python
# context_length = 256, n_embed = 256
position_embed = nn.Embedding(256, 256)

# 位置 0, 1, 2, ..., T-1 各有一个 256 维的向量
pos_idxs = torch.arange(T)  # [0, 1, 2, ..., T-1]
pos_vectors = position_embed(pos_idxs)  # (T, 256)
```

然后把 token embedding 和 position embedding **相加**：

```python
# tok_embedding: (B, T, 256)  ← 每个 token 的内容向量
# pos_embedding: (T, 256)     ← 每个位置的位置向量
# 广播相加后: (B, T, 256)     ← 内容 + 位置
x = tok_embedding + pos_embedding
```

为什么是相加而不是拼接？因为相加后向量维度不变，不增加计算量。而且实验证明，这种简单的位置编码在实践中效果很好。

### 3.1.3 代码实现

在项目的 `Transformer` 类中，这两层 Embedding 在 `_pre_attn_pass` 方法里完成：

```python
# src/models/transformer.py

class Transformer(nn.Module):
    def __init__(self, n_head, n_embed, context_length, vocab_size, N_BLOCKS):
        super().__init__()
        self.context_length = context_length
        self.token_embed = nn.Embedding(vocab_size, n_embed)      # 内容嵌入
        self.position_embed = nn.Embedding(context_length, n_embed)  # 位置嵌入
        self.register_buffer('pos_idxs', torch.arange(context_length))
        # ... 其他组件稍后初始化

    def _pre_attn_pass(self, idx):
        """把 token ID 变成 内容向量 + 位置向量"""
        B, T = idx.shape
        tok_embedding = self.token_embed(idx)              # (B, T, n_embed)
        pos_embedding = self.position_embed(self.pos_idxs[:T])  # (T, n_embed)
        return tok_embedding + pos_embedding               # (B, T, n_embed)
```

`register_buffer` 的作用是把 `pos_idxs` 注册为模型的一部分，它会跟着模型一起 `.to(device)`，但不会被优化器更新。

> **形状追踪**：输入 `(B, T)` 的 token ID 矩阵，经过 Embedding 后变成 `(B, T, n_embed)` 的三维张量。后面所有的处理都在这个三维空间里进行。

## 3.2 MLP：per-token 的"思考"

MLP（Multi-Layer Perceptron）是 Transformer Block 中负责"思考"的部分。它对每个 token 独立做相同的非线性变换。

### 3.2.1 架构

```
输入 (n_embed)  →  线性层 (n_embed → 4×n_embed)  →  ReLU  →  线性层 (4×n_embed → n_embed)  →  输出 (n_embed)
```

核心思想是"先扩展再压缩"：把 256 维的向量扩展到 1024 维，在高维空间里做非线性混合，再投影回 256 维。这个扩展给了模型更大的"工作空间"来组合特征。

### 3.2.2 代码实现

```python
# src/models/mlp.py

class MLP(nn.Module):
    def __init__(self, n_embed):
        super().__init__()
        self.hidden = nn.Linear(n_embed, 4 * n_embed)   # 扩展到 4 倍
        self.relu = nn.ReLU()                            # 非线性激活
        self.proj = nn.Linear(4 * n_embed, n_embed)      # 投影回原维度

    def forward(self, x):
        x = self.relu(self.hidden(x))  # (B, T, n_embed) → (B, T, 4*n_embed)
        x = self.proj(x)               # (B, T, 4*n_embed) → (B, T, n_embed)
        return x
```

### 3.2.3 动手验证

```python
import torch
from src.models.mlp import MLP

mlp = MLP(n_embed=256)
x = torch.randn(2, 10, 256)  # (batch=2, seq_len=10, n_embed=256)
out = mlp(x)
print(f"输入: {x.shape}, 输出: {out.shape}")
# 输入: torch.Size([2, 10, 256]), 输出: torch.Size([2, 10, 256])
```

输入输出形状完全相同——这是 MLP 的一个重要性质，它让 Block 可以无缝堆叠。

### 3.2.4 参数量

MLP 有多少参数？

```
hidden 层: 256 × 1024 + 1024 (bias) = 263,168
proj 层:   1024 × 256 + 256 (bias)   = 262,400
总计:                                  525,568 参数
```

## 3.3 单头注意力（Head）：让 token 看到彼此

注意力机制是 Transformer 的灵魂。它让每个 token 能够"看到"序列中的其他 token，并根据相关性来决定"关注"哪些信息。

### 3.3.1 直觉理解

想象你在读一句话："The cat sat on the mat because **it** was tired."

当模型处理 "it" 这个词时，它需要知道 "it" 指的是什么。注意力机制让 "it" 能够回头看序列中的每个词，并给每个词打一个"相关性分数"。在这个例子中，"cat" 应该得到最高的分数。

```
"it" 的注意力分布:
The:   0.02
cat:   0.65  ← 最高！"it" 指的是 "cat"
sat:   0.05
on:    0.01
the:   0.02
mat:   0.15
because: 0.03
it:    0.07
```

### 3.3.2 Query-Key-Value 机制

注意力用三个角色来实现这个过程：

- **Query（查询）**：当前 token 在问"我在找什么信息？"
- **Key（键）**：每个 token 在说"我包含什么信息？"
- **Value（值）**：每个 token 在说"如果你选中了我，我能提供什么信息？"

计算过程：

1. 当前 token 的 Query 和所有 token 的 Key 做点积 → 得到"相关性分数"
2. 分数做 softmax → 变成"注意力权重"（和为 1）
3. 用注意力权重对所有 token 的 Value 做加权求和 → 得到输出

```
注意力分数 = softmax(Query × Key^T / √d) × Value
```

除以 `√d`（head_size 的平方根）是为了防止点积太大导致 softmax 饱和。

### 3.3.3 因果遮罩（Causal Mask）

语言模型有一个核心约束：**位置 t 的 token 只能看到位置 0 到 t 的 token，不能偷看未来。**

这通过一个"下三角矩阵"来实现：

```
注意力权重矩阵 (T × T):

位置:   0    1    2    3    4
  0   [1.0  -∞   -∞   -∞   -∞ ]   ← 位置 0 只能看自己
  1   [0.6  0.4  -∞   -∞   -∞ ]   ← 位置 1 能看 0, 1
  2   [0.2  0.3  0.5  -∞   -∞ ]   ← 位置 2 能看 0, 1, 2
  3   [0.1  0.1  0.2  0.6  -∞ ]   ← 位置 3 能看 0, 1, 2, 3
  4   [0.05 0.1  0.1  0.25 0.5]   ← 位置 4 能看所有
```

`-∞` 在 softmax 之后变成 0，所以模型"看不到"未来的 token。

### 3.3.4 代码实现

```python
# src/models/attention.py

class Head(nn.Module):
    def __init__(self, head_size, n_embed, context_length):
        super().__init__()
        self.key   = nn.Linear(n_embed, head_size, bias=False)
        self.query = nn.Linear(n_embed, head_size, bias=False)
        self.value = nn.Linear(n_embed, head_size, bias=False)
        # 下三角矩阵，用于因果遮罩
        self.register_buffer('tril', torch.tril(torch.ones(context_length, context_length)))

    def forward(self, x):
        B, T, C = x.shape
        head_size = self.key.out_features

        # 1. 计算 Q, K, V
        k = self.key(x)     # (B, T, head_size)
        q = self.query(x)   # (B, T, head_size)
        v = self.value(x)   # (B, T, head_size)

        # 2. 计算注意力分数
        scale_factor = 1 / math.sqrt(head_size)
        attn_weights = q @ k.transpose(-2, -1) * scale_factor  # (B, T, T)

        # 3. 因果遮罩：把未来位置设为 -inf
        attn_weights = attn_weights.masked_fill(self.tril[:T, :T] == 0, float('-inf'))

        # 4. Softmax：把分数变成概率
        attn_weights = F.softmax(attn_weights, dim=-1)         # (B, T, T)

        # 5. 加权求和
        out = attn_weights @ v                                  # (B, T, head_size)
        return out
```

> **形状追踪**：输入 `(B, T, n_embed)`，输出 `(B, T, head_size)`。注意输出的维度是 `head_size`，不是 `n_embed`——因为每个头只负责一个子空间。

### 3.3.5 动手验证

```python
import torch
from src.models.attention import Head

head = Head(head_size=64, n_embed=256, context_length=256)
x = torch.randn(2, 10, 256)
out = head(x)
print(f"输入: {x.shape}, 输出: {out.shape}")
# 输入: torch.Size([2, 10, 256]), 输出: torch.Size([2, 10, 64])
```

## 3.4 多头注意力（MultiHeadAttention）：并行捕捉多种模式

一个注意力头只能学到一种"关注模式"。但语言中有多种关系需要同时捕捉：

- 主语和谓语的关系
- 代词和它指代的名词
- 形容词和它修饰的名词
- 长距离的语法依赖

解决方案：**运行多个注意力头，然后把结果拼接起来。**

### 3.4.1 架构

```
输入 (B, T, n_embed=256)
    │
    ├── Head 0 (head_size=64) → (B, T, 64)
    ├── Head 1 (head_size=64) → (B, T, 64)
    ├── Head 2 (head_size=64) → (B, T, 64)
    ├── Head 3 (head_size=64) → (B, T, 64)
    │
    └── 拼接 → (B, T, 256) → 线性投影 → (B, T, 256)
```

每个头的 `head_size = n_embed / n_head`，所以拼接后正好回到 `n_embed` 维度。

### 3.4.2 代码实现

```python
# src/models/attention.py

class MultiHeadAttention(nn.Module):
    def __init__(self, n_head, n_embed, context_length):
        super().__init__()
        self.heads = nn.ModuleList([
            Head(n_embed // n_head, n_embed, context_length)
            for _ in range(n_head)
        ])
        self.proj = nn.Linear(n_embed, n_embed)  # 混合各头的输出

    def forward(self, x):
        # 每个头独立计算注意力，然后拼接
        x = torch.cat([h(x) for h in self.heads], dim=-1)  # (B, T, n_embed)
        # 最后的线性层让各头的信息互相交流
        x = self.proj(x)                                    # (B, T, n_embed)
        return x
```

### 3.4.3 关键设计决策

**为什么 `head_size = n_embed // n_head`？**

这样设计的好处是：多头注意力的总计算量和单头全注意力差不多，但每个头可以在不同的子空间里学习不同的模式。相当于用同样的预算，获得了更丰富的表示能力。

**为什么需要最后的 `self.proj`？**

拼接只是简单地把各头的输出排在一起，各头之间没有信息交流。`self.proj` 这个线性层让不同头学到的特征可以相互组合。

### 3.4.4 深入理解：`n_head` 如何影响模型行为？

一个常见的疑问是：**"`n_embed` 不变，改变 `n_head` 对参数量有影响吗？"**

答案是：**参数量完全相同，但模型的行为不同。**

**参数量验证**

以 `n_embed=256` 为例，对比 `n_head=4` 和 `n_head=8`：

```
n_head=4:
  head_size = 256 // 4 = 64
  单 Head 参数: 256 × 64 = 16,384  (K/Q/V 各 256×64, 无 bias)
  4 个 Head: 4 × 16,384 = 65,536
  输出投影: 256 × 256 + 256 = 65,792
  合计: 65,536 + 65,792 = 131,328

n_head=8:
  head_size = 256 // 8 = 32
  单 Head 参数: 256 × 32 = 8,192
  8 个 Head: 8 × 8,192 = 65,536  ← 和上面完全一样！
  输出投影: 256 × 256 + 256 = 65,792
  合计: 65,536 + 65,792 = 131,328  ← 和上面完全一样！
```

总参数量完全一样，因为不管分几份，`n_head × head_size = n_embed` 是固定的。

**行为区别**

既然参数量相同，那 `n_head` 改变了什么？改变了**每个头的"视野宽度"**。

把 256 维的嵌入空间想象成一间 **256 平米的办公室**：

| | n_head=4 | n_head=8 |
|--|----------|----------|
| 团队数 | 4 个小组 | 8 个小组 |
| 每组负责空间 | 64 平米 | 32 平米 |
| 每组"视力" | 看得更细致（64 维子空间） | 看得更粗（32 维子空间） |
| 并行视角 | 4 个视角 | 8 个视角 |

具体来说，每个头负责嵌入空间的一个"切片"：

```
n_head=4:
  Head 0: 维度 [0:64]   → 可能学到"语法结构"
  Head 1: 维度 [64:128] → 可能学到"语义相似性"
  Head 2: 维度 [128:192] → 可能学到"位置关系"
  Head 3: 维度 [192:256] → 可能学到"指代关系"

n_head=8:
  Head 0~7: 各负责 32 维 → 8 个更细粒度的视角
  每个头学到的模式更"专"，但每个头的表达能力更弱
```

- **n_head=4（少头、大子空间）**：每个头在更大的空间里工作，可以学习更复杂的局部关系，但只能从 4 个角度看问题
- **n_head=8（多头、小子空间）**：从 8 个不同角度看问题，捕捉更多样化的模式，但每个角度的"分辨率"更低

**如何选择 `n_head`？**

| 场景 | 推荐 | head_size |
|------|------|----------|
| 小模型（n_embed ≤ 256） | n_head=4 | 64 |
| 中等模型（n_embed = 512） | n_head=8 | 64 |
| 大模型（n_embed ≥ 1024） | n_head=16+ | 64 或 128 |

经验法则：**`head_size` 通常取 64 或 128**。所以 `n_head = n_embed // 64` 是一个不错的起点。本项目的配置中，小模型用 `n_head=4`，大模型用 `n_head=8`，都保持了 `head_size=64` 不变，是一个合理的设计。

### 3.4.5 动手验证

```python
import torch
from src.models.attention import MultiHeadAttention

mha = MultiHeadAttention(n_head=4, n_embed=256, context_length=256)
x = torch.randn(2, 10, 256)
out = mha(x)
print(f"输入: {x.shape}, 输出: {out.shape}")
# 输入: torch.Size([2, 10, 256]), 输出: torch.Size([2, 10, 256])

# 验证：改变 n_head，参数量不变
mha4 = MultiHeadAttention(n_head=4, n_embed=256, context_length=256)
mha8 = MultiHeadAttention(n_head=8, n_embed=256, context_length=256)
params4 = sum(p.numel() for p in mha4.parameters())
params8 = sum(p.numel() for p in mha8.parameters())
print(f"n_head=4 参数: {params4:,}")  # 131,328
print(f"n_head=8 参数: {params8:,}")  # 131,328 ← 完全相同！
```

## 3.5 Transformer Block：注意力 + MLP + 残差

现在我们有了两个核心组件：
- **MultiHeadAttention**：让 token 互相交流
- **MLP**：让每个 token 独立思考

怎么把它们组合起来？答案是 **Transformer Block**。

### 3.5.1 架构

```
输入 x (B, T, n_embed)
    │
    ├──→ LayerNorm → MultiHeadAttention → + → x' (残差连接)
    │                                      │
    ├──→ LayerNorm → MLP → + → 输出 (残差连接)
    │                      │
    └──────────────────────┘
```

### 3.5.2 残差连接（Residual Connection）

残差连接的核心思想是：**不是让网络直接学目标映射 F(x)，而是学残差 F(x) - x。**

```python
x = x + self.attn(self.ln1(x))   # 而不是 x = self.attn(self.ln1(x))
x = x + self.mlp(self.ln2(x))    # 而不是 x = self.mlp(self.ln2(x))
```

为什么这么重要？因为：

1. **梯度流动**：没有残差连接，梯度要经过每一层的权重矩阵才能传回前面的层。有了残差，梯度有一条"高速公路"直接流过——`∂L/∂x` 里总是包含一个 `1`。
2. **信息保留**：每一层只需要学习"增量"，而不是从头重建整个表示。
3. **深度堆叠**：没有残差，10 层以上的网络就很难训练。有了残差，几百层都没问题。

### 3.5.3 Pre-Norm vs Post-Norm

本项目使用 **Pre-Norm**（先归一化再做子层运算）：

```python
# Pre-Norm（本项目使用）
x = x + self.attn(self.ln1(x))

# Post-Norm（原始 Transformer 论文使用）
x = self.ln1(x + self.attn(x))
```

Pre-Norm 在实践中更稳定，更容易训练深层模型。Post-Norm 理论上表示能力更强，但对学习率和初始化更敏感。

### 3.5.4 LayerNorm 的作用

LayerNorm 对每个 token 的向量做归一化：

```
输入:  [0.5, -0.3, 1.2, -0.8, ...]  (n_embed 维)
       ↓ 减均值，除标准差
输出:  [0.12, -0.08, 0.45, -0.31, ...]  (均值≈0, 方差≈1)
```

它确保每层的输入都在合理的数值范围内，防止梯度爆炸或消失。

### 3.5.5 代码实现

```python
# src/models/transformer_block.py

class Block(nn.Module):
    def __init__(self, n_head, n_embed, context_length):
        super().__init__()
        self.ln1 = nn.LayerNorm(n_embed)
        self.attn = MultiHeadAttention(n_head, n_embed, context_length)
        self.ln2 = nn.LayerNorm(n_embed)
        self.mlp = MLP(n_embed)

    def forward(self, x):
        x = x + self.attn(self.ln1(x))   # 注意力子层 + 残差
        x = x + self.mlp(self.ln2(x))    # MLP 子层 + 残差
        return x
```

这两行代码是整个 Transformer 的核心。读懂它们，你就理解了模型的大部分行为：

- `self.ln1(x)` → 归一化
- `self.attn(...)` → 让 token 互相看
- `x + ...` → 把学到的东西加回原向量
- `self.ln2(x)` → 再归一化
- `self.mlp(...)` → 每个 token 独立思考
- `x + ...` → 把思考结果加回原向量

### 3.5.6 参数量

一个 Block 有多少参数（n_embed=256, n_head=4）？

```
MultiHeadAttention:
  每个 Head: 3 × (256 × 64) = 49,152  (K, Q, V 无 bias)
  4 个 Head: 4 × 49,152 = 196,608
  输出投影: 256 × 256 + 256 = 65,792
  小计: 262,400

MLP:
  hidden: 256 × 1024 + 1024 = 263,168
  proj: 1024 × 256 + 256 = 262,400
  小计: 525,568

LayerNorm × 2: 2 × (256 + 256) = 1,024

Block 总计: 262,400 + 525,568 + 1,024 = 788,992 参数
```

## 3.6 完整 Transformer：组装所有零件

现在我们把所有组件拼在一起。

### 3.6.1 前向传播流程

```
token IDs (B, T)
    │
    ▼
Token Embedding + Position Embedding → (B, T, n_embed)
    │
    ▼
Block 1: Attention + MLP + 残差 → (B, T, n_embed)
    │
    ▼
Block 2: Attention + MLP + 残差 → (B, T, n_embed)
    │
    ▼
  ... (重复 N_BLOCKS 次)
    │
    ▼
Block N: Attention + MLP + 残差 → (B, T, n_embed)
    │
    ▼
Final LayerNorm → (B, T, n_embed)
    │
    ▼
lm_head (Linear) → (B, T, vocab_size)  ← logits
    │
    ▼
Cross-Entropy Loss (如果提供了 targets)
```

### 3.6.2 代码实现

```python
# src/models/transformer.py

class Transformer(nn.Module):
    def __init__(self, n_head, n_embed, context_length, vocab_size, N_BLOCKS):
        super().__init__()
        self.context_length = context_length
        self.N_BLOCKS = N_BLOCKS
        self.gradient_checkpointing = False

        # 输入层
        self.token_embed = nn.Embedding(vocab_size, n_embed)
        self.position_embed = nn.Embedding(context_length, n_embed)
        self.register_buffer('pos_idxs', torch.arange(context_length))

        # 中间层：N 个 Transformer Block
        self.attn_blocks = nn.ModuleList([
            Block(n_head, n_embed, context_length)
            for _ in range(N_BLOCKS)
        ])

        # 输出层
        self.layer_norm = nn.LayerNorm(n_embed)
        self.lm_head = nn.Linear(n_embed, vocab_size)

    def _pre_attn_pass(self, idx):
        """Token Embedding + Position Embedding"""
        B, T = idx.shape
        tok_embedding = self.token_embed(idx)                    # (B, T, n_embed)
        pos_embedding = self.position_embed(self.pos_idxs[:T])   # (T, n_embed)
        return tok_embedding + pos_embedding                     # (B, T, n_embed)

    def forward_hidden(self, idx):
        """骨干网络：返回最终隐藏状态（供后训练的各种 head 使用）"""
        x = self._pre_attn_pass(idx)
        for block in self.attn_blocks:
            x = block(x)
        return self.layer_norm(x)

    def forward(self, idx, targets=None):
        """完整前向传播：返回 logits 和 loss"""
        x = self.forward_hidden(idx)           # (B, T, n_embed)
        logits = self.lm_head(x)               # (B, T, vocab_size)

        loss = None
        if targets is not None:
            B, T, C = logits.shape
            flat_logits = logits.reshape(B * T, C)
            targets = targets.reshape(B * T).long()
            loss = F.cross_entropy(flat_logits, targets)

        return logits, loss
```

### 3.6.3 `forward_hidden` 的设计哲学

注意 `forward_hidden` 这个方法——它是后训练所有组件的"锚点"。奖励模型、PPO 的价值头、DPO/GRPO 的 log-prob 计算，都是在这个方法的输出上构建的。

这就是第 1 章提到的 **"wrap, don't rewrite"** 原则：
- `forward_hidden` 返回最终隐藏状态（layer_norm 之后）
- `forward` 在 `forward_hidden` 的基础上加 `lm_head`
- 后训练的各种 head 在 `forward_hidden` 的基础上加自己的 head

模型的核心从未被修改，只是被不断地"包装"。

### 3.6.4 Cross-Entropy Loss 详解

`forward` 方法的 loss 计算看似简单，但有几个细节值得注意：

```python
flat_logits = logits.reshape(B * T, C)   # (B*T, vocab_size)
targets = targets.reshape(B * T).long()   # (B*T,)
loss = F.cross_entropy(flat_logits, targets)
```

为什么用 `reshape` 而不是 `view`？因为 `targets` 来自 batch 张量的切片，可能不是内存连续的。`view` 要求内存连续，会报错；`reshape` 自动处理两种情况。

### 3.6.5 动手验证

```python
import torch
from src.models.transformer import Transformer

model = Transformer(
    n_head=4,
    n_embed=256,
    context_length=256,
    vocab_size=50304,
    N_BLOCKS=6
)

# 查看参数量
total_params = sum(p.numel() for p in model.parameters())
print(f"总参数量: {total_params:,}")
# 总参数量: 17,586,576 (约 17M)

# 前向传播
idx = torch.randint(0, 50304, (2, 10))
logits, loss = model(idx, targets=idx)
print(f"logits: {logits.shape}, loss: {loss.item():.4f}")
# logits: torch.Size([2, 10, 50304]), loss: ~10.83 (≈ ln(50304))
```

随机初始化的模型，loss 应该接近 `ln(vocab_size) ≈ ln(50304) ≈ 10.83`。这是因为模型在随机猜测——对 50304 个选项做均匀分布，交叉熵就是 `ln(50304)`。

## 3.7 文本生成：自回归采样

模型训练好之后，怎么用它生成文本？答案是**自回归生成**：

```
1. 输入一个起始序列（prompt）
2. 模型预测下一个 token 的概率分布
3. 从分布中采样一个 token
4. 把采样的 token 拼到序列末尾
5. 重复 2-4，直到生成足够多的 token
```

### 3.7.1 代码实现

```python
# src/models/transformer.py

def generate(self, idx, max_new_tokens):
    for _ in range(max_new_tokens):
        # 截取最后 context_length 个 token（不超出上下文窗口）
        idx_cond = idx[:, -self.context_length:]

        # 前向传播，获取最后一个位置的 logits
        logits, _ = self(idx_cond)
        logits = logits[:, -1, :]  # (B, vocab_size)

        # softmax → 概率分布 → 采样
        probs = F.softmax(logits, dim=-1)
        idx_next = torch.multinomial(probs, num_samples=1)  # (B, 1)

        # 拼接到序列
        idx = torch.cat((idx, idx_next), dim=1)

    return idx
```

### 3.7.2 为什么用 `softmax + multinomial` 而不是 `argmax`？

`argmax` 总是选概率最高的 token，生成结果会非常单调和重复。`multinomial` 按概率随机采样，能生成更多样化的文本。

后训练阶段的 `rollout.py` 会提供更精细的采样策略（Temperature、Top-k、Top-p），但这里的基础版本已经足够理解原理。

## 3.8 参数量估算

让我们以 `n_embed=256, n_head=4, N_BLOCKS=6, vocab_size=50304` 为例，逐层精确计算参数量。

### 3.8.1 一个 `nn.Linear(in, out)` 有多少参数？

在拆解之前，先记住 PyTorch 中 `nn.Linear` 的参数量公式：

```
nn.Linear(in_features, out_features, bias=True):
  weight: out_features × in_features    (权重矩阵)
  bias:   out_features                  (偏置向量)
  合计:   out_features × in_features + out_features

nn.Linear(in_features, out_features, bias=False):
  weight: out_features × in_features    (只有权重矩阵，无偏置)
  合计:   out_features × in_features
```

### 3.8.2 拆解一个 Block（788,992 参数）

一个 Block 由 **MultiHeadAttention** + **MLP** + **2 个 LayerNorm** 组成。我们分别计算：

**（1）单头注意力 Head 的参数**

```python
# src/models/attention.py — Head.__init__
self.key   = nn.Linear(n_embed, head_size, bias=False)   # 256 × 64 = 16,384
self.query = nn.Linear(n_embed, head_size, bias=False)   # 256 × 64 = 16,384
self.value = nn.Linear(n_embed, head_size, bias=False)   # 256 × 64 = 16,384
```

其中 `head_size = n_embed // n_head = 256 // 4 = 64`。

三个投影都设置了 `bias=False`（这是标准做法，注意力层的 K/Q/V 投影通常不加偏置）。

```
单 Head 参数 = 3 × (256 × 64) = 3 × 16,384 = 49,152
```

**（2）MultiHeadAttention 的参数**

```python
# src/models/attention.py — MultiHeadAttention.__init__
self.heads = nn.ModuleList([...])  # 4 个 Head
self.proj  = nn.Linear(n_embed, n_embed)  # 输出投影（有 bias）
```

```
4 × Head:           4 × 49,152           = 196,608
输出投影 (bias=True): 256 × 256 + 256     = 65,792
                                    小计   = 262,400
```

**（3）MLP 的参数**

```python
# src/models/mlp.py — MLP.__init__
self.hidden = nn.Linear(n_embed, 4 * n_embed)   # 有 bias
self.proj   = nn.Linear(4 * n_embed, n_embed)   # 有 bias
```

```
hidden 层: 1024 × 256 + 1024  = 263,168
proj 层:    256 × 1024 + 256   = 262,400
                         小计  = 525,568
```

**（4）2 个 LayerNorm 的参数**

```python
# src/models/transformer_block.py — Block.__init__
self.ln1 = nn.LayerNorm(n_embed)   # weight: 256, bias: 256
self.ln2 = nn.LayerNorm(n_embed)   # weight: 256, bias: 256
```

```
LayerNorm × 2: 2 × (256 + 256) = 1,024
```

**（5）Block 汇总**

```
MultiHeadAttention:   262,400
MLP:                  525,568
LayerNorm × 2:          1,024
──────────────────────────────
单个 Block 合计:      788,992
```

### 3.8.3 拆解 lm_head（12,928,128 参数）

```python
# src/models/transformer.py — Transformer.__init__
self.lm_head = nn.Linear(n_embed, vocab_size)  # bias=True（默认）
```

`lm_head` 是一个标准的线性层，把 `n_embed` 维的隐藏状态映射到 `vocab_size` 维的 logits 向量：

```
weight: vocab_size × n_embed = 50304 × 256 = 12,877,824
bias:   vocab_size           =                 50,304
─────────────────────────────────────────────────────────
合计:                                      = 12,928,128
```

为什么这么大？因为模型需要为词汇表中的**每一个 token** 输出一个分数（logit）。`n_embed=256` 表示每个 token 用 256 个数来描述它的语义，而模型要从这 256 维映射到 50304 维的输出空间，自然需要 50304 × 256 个权重。

> **注意**：Token Embedding 的大小也是 `vocab_size × n_embed = 12,877,824`。这两层"首尾呼应"——一个把 token 从离散空间嵌入到连续空间，另一个把连续空间的表示映射回离散空间。它们的参数量完全相等。

### 3.8.4 总参数量汇总

```
┌──────────────────────────────────────────────────────────────────────┐
│ 组件                    │ 计算公式              │ 参数量             │
├──────────────────────────────────────────────────────────────────────┤
│ Token Embedding         │ 50304 × 256           │  12,877,824       │
│ Position Embedding      │ 256 × 256             │      65,536       │
│ Block × 6               │ 6 × 788,992           │   4,733,952       │
│ Final LayerNorm         │ 256 + 256             │         512       │
│ lm_head                 │ 256 × 50304 + 50304   │  12,928,128       │
├──────────────────────────────────────────────────────────────────────┤
│ 总计                    │                       │  30,605,952 (~31M)│
└──────────────────────────────────────────────────────────────────────┘
```

可以用一行代码验证：

```python
print(sum(p.numel() for p in model.parameters()))
# 30,605,952 ✓
```

### 3.8.5 参数分布的直觉

从上面的拆解可以看出一个有趣的规律：

| 组件类别 | 参数量 | 占比 |
|----------|--------|------|
| Token Embedding | 12,877,824 | 42.1% |
| lm_head | 12,928,128 | 42.2% |
| 6 × Block | 4,733,952 | 15.5% |
| Position Embedding + LayerNorm | 66,048 | 0.2% |

**Embedding 和 lm_head 占了总参数的 84%！** 真正的"智能"——注意力和 MLP 只占 15.5%。这就是为什么增大 `n_embed` 或增加 Block 层数对参数的影响远没有增 `vocab_size` 那么夸张。

### 3.8.6 不同配置的参数量

| 配置 | n_embed | n_head | N_BLOCKS | 参数量 | 显存需求 |
|------|---------|--------|----------|--------|----------|
| 小型 | 128 | 8 | 1 | ~13M | < 1 GB |
| 中型 | 256 | 4 | 6 | ~31M | ~2 GB |
| 大型 | 512 | 8 | 12 | ~200M | ~6 GB |
| 旗舰 | 1024 | 16 | 24 | ~400M | ~12 GB |

参数量最大的部分通常是 **Token Embedding** 和 **lm_head**——因为它们都和 `vocab_size × n_embed` 成正比。当 `vocab_size` 很大时（比如 50304），这两层可能占总参数量的 40-60%。

## 3.9 本章小结

| 组件 | 功能 | 输入 → 输出 |
|------|------|-------------|
| **Token Embedding** | 把 token ID 变成稠密向量 | `(B, T)` → `(B, T, n_embed)` |
| **Position Embedding** | 编码位置信息 | `(T,)` → `(T, n_embed)` |
| **MLP** | per-token 的非线性变换 | `(B, T, C)` → `(B, T, C)` |
| **Head** | 单头注意力 + 因果遮罩 | `(B, T, C)` → `(B, T, head_size)` |
| **MultiHeadAttention** | 多头并行 + 拼接 + 投影 | `(B, T, C)` → `(B, T, C)` |
| **Block** | Attention + MLP + 残差 + LayerNorm | `(B, T, C)` → `(B, T, C)` |
| **Transformer** | 完整模型 | `(B, T)` → `(B, T, vocab_size)` |

核心要点：

1. **自底向上构建**：MLP → Head → MultiHeadAttention → Block → Transformer
2. **形状不变原则**：除了 Head 的输出是 `head_size`，其他组件都保持 `(B, T, n_embed)` 不变
3. **残差连接**是训练深层网络的关键——让梯度有"高速公路"直接流过
4. **因果遮罩**是语言模型的核心约束——位置 t 只能看 0 到 t 的 token
5. **`forward_hidden`** 是后训练所有组件的锚点——wrap, don't rewrite

---

## 练习

**练习 1：参数量计算**

计算以下配置的 Transformer 参数量：
- `n_embed=384, n_head=6, N_BLOCKS=12, vocab_size=50304, context_length=256`

提示：分别计算 Embedding 层、Block 层（× N_BLOCKS）、输出层的参数量。

**练习 2：注意力可视化**

修改 `Head` 的 `forward` 方法，让它返回 `attn_weights`。然后用以下代码可视化注意力矩阵：

```python
import torch
import matplotlib.pyplot as plt

# 创建一个小模型
head = Head(head_size=16, n_embed=64, context_length=32)
x = torch.randn(1, 10, 64)
# ... 获取 attn_weights ...
# plt.imshow(attn_weights[0].detach().numpy(), cmap='hot')
# plt.colorbar()
# plt.show()
```

观察：注意力矩阵的下三角部分有值，上三角全是 0（因果遮罩生效）。

**练习 3：去掉残差连接**

修改 `Block.forward`，去掉残差连接：

```python
def forward(self, x):
    x = self.attn(self.ln1(x))   # 去掉 x +
    x = self.mlp(self.ln2(x))    # 去掉 x +
    return x
```

然后用 `Transformer.generate` 生成文本，观察输出质量的变化。思考：为什么残差连接如此重要？

**练习 4：思考题**

如果把因果遮罩去掉（让每个 token 能看到所有位置），模型会变成什么？它能用于语言建模吗？（提示：想想 BERT 和 GPT 的区别）
