# 第 21 章：从 13M 到 400M——规模效应

> **本章目标**：理解 Scaling Laws 的核心思想，对比不同规模模型（13M / 90M / 400M）的生成质量差异，掌握数据量、模型大小、训练步数的平衡策略。

## 21.0 本章路线图

前 20 章完整实现了从零训练 LLM 的全流程。但一个关键问题尚未回答：**模型应该多大？**

```
本章覆盖的内容

规模效应
├── Scaling Laws 简介
├── 本项目的三种模型配置（13M / 90M / 400M）
├── 参数量精确计算
├── 不同规模的生成质量对比
├── Chinchilla 最优：数据与模型的平衡
└── 实际训练中的规模选择
```

## 21.1 Scaling Laws 简介

### 21.1.1 核心发现

2020 年 OpenAI 的论文 "Scaling Laws for Neural Language Models" 揭示了一个惊人的规律：

```
模型性能（loss）与三个因素呈幂律关系：

  L(N) ∝ N^(-0.076)    ← 模型参数量
  L(D) ∝ D^(-0.095)    ← 训练数据量（token 数）
  L(C) ∝ C^(-0.050)    ← 计算量（FLOPs）

其中 L 是交叉熵 loss，N/D/C 分别是参数量/数据量/计算量
```

**关键洞察**：在合理范围内，**模型越大、数据越多、计算越多 → 性能越好**。而且这个关系是可预测的——可以用小模型的结果外推大模型的性能。

### 21.1.2 Kaplan 法则 vs Chinchilla 法则

**Kaplan 法则（2020）**：当计算预算固定时，优先增大模型，数据量够用就行。

**Chinchilla 法则（2022, DeepMind）**：Kaplan 的结论有误——最优策略是**模型和数据同步增大**。

```
Chinchilla 的核心结论：

对于 C FLOPs 的计算预算，最优的模型大小和数据量满足：
  N_opt ∝ C^0.5
  D_opt ∝ C^0.5

经验法则：每个参数需要约 20 个 token 的训练数据

示例：
  125M 参数 → 需要 ~2.5B tokens
  1B 参数   → 需要 ~20B tokens
  10B 参数  → 需要 ~200B tokens
  175B 参数 → 需要 ~3.5T tokens（GPT-3 只用了 300B，欠训练）
```

### 21.1.3 涌现能力

Scaling Laws 的一个有趣推论是**涌现能力**（Emergent Abilities）：

```
某些能力在模型规模达到阈值时才突然出现：

  < 10B params:  无法做 few-shot 数学推理
  > 10B params:  突然可以做简单的算术
  > 100B params: 可以做复杂的多步推理

这不是魔法——只是大模型在 loss 足够低时，涌现出了这些能力
```

本项目在 13M-400M 的规模上，不会观察到涌现能力。但我们可以观察到**渐进的质量提升**。

## 21.2 本项目的三种模型配置

### 21.2.1 配置总览

| 配置 | n_embed | n_head | n_blocks | 参数量 | 适用硬件 |
|------|---------|--------|----------|--------|---------|
| Smoke | 128 | 4 | 2 | ~13M | CPU / 16GB GPU |
| Mid | 256 | 4 | 6 | ~40M | 单 GPU (24GB) |
| Base | 1024 | 16 | 24 | ~350M | 2× H100 (80GB) |

### 21.2.2 配置文件

```json
// configs/smoke/base.json（Smoke 配置）
{
    "vocab_size": 50304,
    "context_length": 256,
    "n_embed": 128,
    "n_head": 4,
    "n_blocks": 2,
    "device": "cpu"
}

// configs/base.json（Mid 配置）
{
    "vocab_size": 50304,
    "context_length": 256,
    "n_embed": 256,
    "n_head": 4,
    "n_blocks": 6,
    "device": "cuda"
}
```

## 21.3 参数量精确计算

### 21.3.1 Transformer 参数构成

本项目的 Transformer 架构参数分布如下：

```
全局参数（与 block 数无关）：
  token_embed:    vocab_size × n_embed
  position_embed: context_length × n_embed
  layer_norm:     2 × n_embed
  lm_head:        n_embed × vocab_size + vocab_size
                  ──────────────────────
                  ≈ 2 × vocab_size × n_embed  （主导项）

每个 Block 的参数：
  ln1:            2 × n_embed
  Attention:      3 × n_embed² + n_embed² + n_embed = 4n_embed² + n_embed
  ln2:            2 × n_embed
  MLP:            4n_embed² + 4n_embed + 4n_embed² + n_embed = 8n_embed² + 5n_embed
                  ──────────────────────
                  12n_embed² + 8n_embed ≈ 12n_embed²  （主导项）
```

### 21.3.2 公式化计算

```
总参数量 ≈ 2 × vocab_size × n_embed + N_blocks × 12 × n_embed²

其中：
  vocab_size = 50304
  context_length = 256
```

### 21.3.3 三种配置的具体计算

**13M 模型（Smoke 配置）**：

```
n_embed=128, n_head=4, n_blocks=2

全局: 2 × 50304 × 128 = 12,877,824    (~12.9M)
Blocks: 2 × 12 × 128² = 393,216       (~0.4M)
总计: ~13.3M
```

**~40M 模型（Mid 配置）**：

```
n_embed=256, n_head=4, n_blocks=6

全局: 2 × 50304 × 256 = 25,755,648    (~25.8M)
Blocks: 6 × 12 × 256² = 4,718,592     (~4.7M)
总计: ~30.5M
```

**~350M 模型（Base 配置）**：

```
n_embed=1024, n_head=16, n_blocks=24

全局: 2 × 50304 × 1024 = 103,022,592  (~103M)
Blocks: 24 × 12 × 1024² = 301,989,888 (~302M)
总计: ~405M
```

### 21.3.4 参数分布图解

```
13M 模型（参数分布）：
  ┌──────────────────────────────────────────┐
  │ Embedding (12.9M) ██████████████████████ │ 97%
  │ Blocks    (0.4M)  █                      │  3%
  └──────────────────────────────────────────┘

350M 模型（参数分布）：
  ┌──────────────────────────────────────────┐
  │ Embedding (103M) ████████                │ 25%
  │ Blocks    (302M) ████████████████████████│ 75%
  └──────────────────────────────────────────┘
```

**关键观察**：

| 模型 | Embedding 占比 | Block 占比 | 主导部分 |
|------|---------------|-----------|---------|
| 13M | 97% | 3% | Embedding（vocab 太大） |
| 40M | 85% | 15% | Embedding |
| 350M | 25% | 75% | Blocks（Transformer 主体） |

**对于小模型，vocab_size 是最大的参数消耗者**。50304 × 128 = 6.4M 个 embedding 参数，几乎占据了整个 13M 模型的半壁江山。

### 21.3.5 验证计算

```python
# 用代码验证参数量
from src.models.transformer import Transformer

configs = [
    {"n_embed": 128,  "n_head": 4,  "n_blocks": 2,  "label": "13M"},
    {"n_embed": 256,  "n_head": 4,  "n_blocks": 6,  "label": "40M"},
    {"n_embed": 1024, "n_head": 16, "n_blocks": 24, "label": "350M"},
]

for c in configs:
    model = Transformer(
        n_head=c["n_head"], n_embed=c["n_embed"],
        context_length=256, vocab_size=50304, N_BLOCKS=c["n_blocks"]
    )
    total = sum(p.numel() for p in model.parameters())
    print(f"{c['label']:>5s}: {total/1e6:.1f}M params")
```

## 21.4 不同规模的生成质量对比

### 21.4.1 预训练阶段对比

| 配置 | 预期 train loss | 预期 dev loss | 生成能力 |
|------|----------------|--------------|---------|
| 13M | ~4.0 | ~4.5 | 生成连贯的短句 |
| 40M | ~3.2 | ~3.7 | 生成有意义的段落 |
| 350M | ~2.5 | ~3.0 | 生成较长的连贯文本 |

**loss 与困惑度（Perplexity）的关系**：

```
Perplexity = exp(loss)

13M:  exp(4.0) = 55   → 每个位置平均在 55 个候选词中犹豫
40M:  exp(3.2) = 25   → 每个位置平均在 25 个候选词中犹豫
350M: exp(2.5) = 12   → 每个位置平均在 12 个候选词中犹豫

困惑度越低 → 模型对下一个 token 的预测越确定 → 生成质量越高
```

### 21.4.2 SFT 后的对话能力对比

| 配置 | GSM8K 准确率 | 格式正确率 | 推理能力 |
|------|-------------|-----------|---------|
| 13M | 0-2% | 30-50% | 几乎无法推理 |
| 40M | 3-8% | 60-80% | 简单算术 |
| 350M | 5-15% | 80-95% | 多步推理 |

### 21.4.3 生成样例对比

**13M 模型的典型输出**：

```
you> What is 13 + 29?
bot> The answer is 7. The number 3.
```

输出短小、无逻辑、但可能格式正确（学会了 `<answer>` 标签）。

**40M 模型的典型输出**：

```
you> What is 13 + 29?
bot> <think>I need to add 13 and 29. 13 + 29 = 42.</think><answer>42</answer>
```

格式正确，推理过程可见，答案可能正确也可能错误。

**350M 模型的典型输出**：

```
you> What is 13 + 29?
bot> <think>To add 13 and 29, I can break it down:
13 + 29 = 13 + 20 + 9 = 33 + 9 = 42.</think><answer>42</answer>
```

推理过程更详细，格式稳定，准确率更高。

### 21.4.4 RL 阶段的提升对比

| 配置 | SFT acc | +DPO | +GRPO | 总提升 |
|------|---------|------|-------|--------|
| 13M | 0-2% | +0-1% | +0-2% | 微小 |
| 40M | 3-8% | +1-3% | +2-5% | 适度 |
| 350M | 5-15% | +2-5% | +3-10% | 显著 |

**小模型从 RL 中获得的提升更少**——因为模型容量有限，即使奖励信号明确，也无法学到更复杂的策略。

## 21.5 Chinchilla 最优：数据与模型的平衡

### 21.5.1 本项目的数据规模

| 数据 | 来源 | 大小 |
|------|------|------|
| 预训练 | The Pile | ~数 GB（HDF5 格式） |
| SFT | Alpaca + Dolly + GSM8K | ~10k 对话 |
| Preference | HH-RLHF + UltraFeedback | ~50k 对 |
| RL Prompts | GSM8K train | ~7.5k 题 |

### 21.5.2 是否 Chinchilla 最优？

```
经验法则：每个参数需要约 20 个 token

13M 模型：需要 13M × 20 = 260M tokens
  实际预训练数据：The Pile 的子集 ≈ 几百 M tokens
  → 数据可能不足，但可以接受

40M 模型：需要 40M × 20 = 800M tokens
  实际预训练数据：同上
  → 数据可能不足

350M 模型：需要 350M × 20 = 7B tokens
  实际预训练数据：The Pile 子集 < 7B
  → 明确欠训练（under-trained）
```

**本项目的所有模型都是欠训练的**——这是教学项目的常见妥协。完整的 The Pile 有 ~800GB，但下载和处理成本很高。

### 21.5.3 训练步数的影响

```python
# configs/pretrain.json
{
    "train_steps": 1000,     # 只训练 1000 步
    "batch_size": 8,
    "grad_accum": 12         # 有效 batch = 96
}
```

1000 步 × 96 样本/步 = 96,000 样本 ≈ 24M tokens（context_length=256）

这远少于 Chinchilla 最优所需的数据量。**但对于教学目的，1000 步足以展示训练过程和模型行为的变化**。

### 21.5.4 如何改进

| 策略 | 效果 | 成本 |
|------|------|------|
| 增加 train_steps | 更多数据 → 更低 loss | 更多训练时间 |
| 增大 batch_size | 更稳定的梯度 | 更多显存 |
| 增大模型 | 更多容量 | 更多显存 + 更多数据需求 |
| 增加数据 | 更丰富的知识 | 更多存储 + 下载时间 |

## 21.6 实际训练中的规模选择

### 21.6.1 硬件约束

| 硬件 | 可用显存 | 最大模型 | 推荐配置 |
|------|---------|---------|---------|
| CPU | 系统内存 | ~50M | Smoke (13M) |
| 16GB GPU | 16 GB | ~125M | Mid (40M) |
| 24GB GPU | 24 GB | ~200M | Mid+ (60-80M) |
| 40GB GPU | 40 GB | ~400M | Base (350M) |
| 80GB GPU | 80 GB | ~1B | Base+ (>500M) |

### 21.6.2 训练时间估算

```
单步训练时间 ∝ batch_size × context_length × 参数量

以 A100 GPU 为例：

13M 模型, batch=32, ctx=256:    ~5 ms/step
40M 模型, batch=16, ctx=256:    ~15 ms/step
350M 模型, batch=8, ctx=256:    ~80 ms/step

1000 步预训练时间：
  13M:  ~5 秒
  40M:  ~15 秒
  350M: ~80 秒

后训练全流程（SFT + Reward + DPO + GRPO）：
  13M:  ~5 分钟
  40M:  ~15 分钟
  350M: ~2 小时
```

### 21.6.3 规模 vs 效果的权衡

```
选择模型规模时的决策树：

1. 目的是快速验证代码正确性？
   → Smoke (13M)，几分钟跑完

2. 目的是观察后训练效果？
   → Mid (40M)，15 分钟跑完，能看到格式学习和简单推理

3. 目的是追求最佳效果？
   → Base (350M)，需要 80GB GPU，2 小时跑完

4. 目的是研究 Scaling Laws？
   → 训练多个规模的模型，对比 loss 曲线
```

### 21.6.4 渐进式开发策略

```
推荐的开发流程：

Phase 1: Smoke Test（13M, CPU, 几分钟）
  → 验证所有阶段的代码能跑通
  → 不需要 GPU

Phase 2: Mid Test（40M, 单 GPU, 15 分钟）
  → 验证训练逻辑正确（loss 下降、格式学习）
  → 快速迭代超参数

Phase 3: Full Run（350M, 2× H100, 2 小时）
  → 最终训练 + 评估
  → 生成跨阶段对比表
```

## 21.7 模型大小对后训练各阶段的影响

### 21.7.1 SFT 阶段

| 模型大小 | 格式学习 | 推理能力 | Loss 下降速度 |
|---------|---------|---------|-------------|
| 13M | 能学会 `<answer>` | 无推理 | 快（容量小，容易过拟合） |
| 40M | 格式稳定 | 简单算术 | 适中 |
| 350M | 格式完美 | 多步推理 | 慢（需要更多数据） |

### 21.7.2 Reward Model 阶段

| 模型大小 | 偏好准确率 | Reward Margin | 训练稳定性 |
|---------|-----------|--------------|-----------|
| 13M | 55-60% | 0.1-0.3 | 不稳定 |
| 40M | 60-70% | 0.3-0.8 | 较稳定 |
| 350M | 65-75% | 0.5-1.5 | 稳定 |

### 21.7.3 DPO 阶段

| 模型大小 | Implicit Accuracy | 需要 Reference？ | 训练稳定性 |
|---------|------------------|-----------------|-----------|
| 13M | 55-65% | 是 | 容易崩溃 |
| 40M | 60-70% | 是 | 较稳定 |
| 350M | 65-80% | 是 | 稳定 |

### 21.7.4 PPO/GRPO 阶段

| 模型大小 | 显存需求 | 可行性 | 推荐方法 |
|---------|---------|--------|---------|
| 13M | ~1 GB | 可行但效果差 | 仅用于验证代码 |
| 40M | ~3 GB | 可行 | GRPO（不需要 Value Head） |
| 350M | ~10 GB | 最佳 | PPO 或 GRPO |

## 21.8 超越 Scaling Laws

### 21.8.1 Scaling Laws 的局限

```
Scaling Laws 告诉我们的：
  ✓ 模型越大 → loss 越低（在数据充足时）
  ✓ 数据越多 → loss 越低（在模型够大时）
  ✓ 关系是幂律的，可外推

Scaling Laws 没有告诉我们的：
  ✗ 哪些能力会出现（涌现能力不可预测）
  ✗ 特定任务需要什么规模（如数学推理）
  ✗ 后训练（RLHF）如何改变 scaling 曲线
  ✗ 架构改进（如 MoE、Flash Attention）的效果
```

### 21.8.2 架构改进 vs 规模增大

| 策略 | 效果 | 成本 |
|------|------|------|
| 增大 n_embed | 每个 block 更强 | 二次方增加参数 |
| 增加 n_blocks | 更深的表示 | 线性增加参数 |
| 增加 n_head | 更多注意力头 | 参数不变（head_size 减小） |
| MoE（混合专家） | 条件计算，稀疏激活 | 实现复杂 |
| Flash Attention | 更快的注意力计算 | 不改变参数量 |
| 更好的数据 | 高质量 token | 数据筛选成本 |

### 21.8.3 本项目的定位

```
本项目（~400M 参数）在 LLM 规模谱中的位置：

  13M ──── 400M ──── 7B ──── 70B ──── 175B ──── 1T+
  │          │         │       │        │         │
  本项目    nanoGPT   LLaMA   LLaMA2   GPT-3     GPT-4
  (教学)    (教学)    (开源)   (开源)   (闭源)    (闭源)

本项目处于"玩具模型"和"实用模型"之间的过渡区域：
  - 足够大：能展示真实的训练动态和后训练效果
  - 足够小：能在消费级 GPU 上运行
```

## 21.9 本章小结

### Scaling Laws 核心要点

```
L(N) ∝ N^(-0.076)    模型越大 → loss 越低
L(D) ∝ D^(-0.095)    数据越多 → loss 越低
L(C) ∝ C^(-0.050)    计算越多 → loss 越低

Chinchilla 法则：N_opt ∝ C^0.5, D_opt ∝ C^0.5
  → 模型和数据同步增大是最优策略
  → 经验法则：每个参数 ~20 tokens
```

### 本项目的三种规模

| 配置 | 参数量 | Embedding 占比 | 适用场景 |
|------|--------|---------------|---------|
| Smoke (13M) | 13M | 97% | 代码验证 |
| Mid (40M) | 40M | 85% | 快速实验 |
| Base (350M) | 350M | 25% | 最终训练 |

### 关键教训

1. **参数量不等于能力**：13M 和 350M 的差距不仅是数字，而是质的飞跃
2. **小模型的 Embedding 陷阱**：vocab_size × n_embed 可能占据大部分参数
3. **Chinchilla 最优很难达到**：教学项目通常欠训练
4. **渐进式开发**：先 Smoke → 再 Mid → 最后 Full
5. **规模效应需要数据配合**：大模型 + 少数据 = 浪费计算

---

## 练习

**练习 1：参数量验证**

用代码验证三种配置的参数量，并与公式计算结果对比：

```python
from src.models.transformer import Transformer

def count_params(n_embed, n_head, n_blocks, vocab_size=50304, ctx=256):
    model = Transformer(n_head, n_embed, ctx, vocab_size, n_blocks)
    total = sum(p.numel() for p in model.parameters())
    formula = 2 * vocab_size * n_embed + n_blocks * 12 * n_embed**2
    print(f"n_embed={n_embed:5d} blocks={n_blocks:2d} | "
          f"actual={total/1e6:.1f}M  formula={formula/1e6:.1f}M  "
          f"diff={abs(total-formula)/total*100:.1f}%")

count_params(128, 4, 2)
count_params(256, 4, 6)
count_params(1024, 16, 24)
```

**练习 2：参数量 vs n_embed 曲线**

固定 `n_blocks=6`，绘制参数量随 `n_embed` 变化的曲线：

```python
import matplotlib.pyplot as plt

n_embeds = [64, 128, 256, 512, 768, 1024]
params = []
for ne in n_embeds:
    nh = max(1, ne // 64)
    model = Transformer(nh, ne, 256, 50304, 6)
    params.append(sum(p.numel() for p in model.parameters()) / 1e6)

plt.plot(n_embeds, params, 'o-')
plt.xlabel("n_embed")
plt.ylabel("Parameters (M)")
plt.title("Model Size vs n_embed (n_blocks=6)")
plt.grid(True)
plt.savefig("scaling_curve.png")
```

观察：参数量与 n_embed 的关系是线性还是二次方？

**练习 3：Scaling 实验**

如果有多块 GPU，分别训练 13M 和 40M 的模型，走完 SFT → DPO → GRPO 全流程，对比最终 GSM8K 准确率：

```bash
# 13M
PYTHONPATH=. python scripts/train_sft.py --config configs/smoke/sft.json
PYTHONPATH=. python scripts/eval_post_training.py --ckpt /ephemeral/ckpts/sft.pt --label "13M-sft"

# 40M
PYTHONPATH=. python scripts/train_sft.py --config configs/sft.json
PYTHONPATH=. python scripts/eval_post_training.py --ckpt /ephemeral/ckpts/sft.pt --label "40M-sft"
```

**练习 4：Chinchilla 计算**

假设你有 1B tokens 的训练数据：
1. 按照 Chinchilla 法则，最优的模型大小是多少参数？
2. 对应的 n_embed 和 n_blocks 应该是多少？
3. 需要多少训练步数（batch_size=32, context_length=256）？

```
提示：
  D_opt = 20 × N  →  N = D / 20
  1B tokens → N = 50M params
  50M = 2 × 50304 × n_embed + n_blocks × 12 × n_embed²
  解方程找 n_embed 和 n_blocks 的组合
```
