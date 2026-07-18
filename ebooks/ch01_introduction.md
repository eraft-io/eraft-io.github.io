# 第 1 章：引言——LLM 训练全链路概览

2022 年底，ChatGPT 横空出世。几乎一夜之间，"大语言模型"（Large Language Model, LLM）从一个学术圈内的术语变成了人人挂在嘴边的热词。人们惊叹于它能写诗、编代码、做翻译、聊天——甚至能通过律师资格考试。

但在这层"智能"的表象之下，到底发生了什么？

本书的答案是：**它只是在做下一个词的预测。** 给定前面所有的文字，模型计算出下一个词的概率分布，然后从中采样一个词，再把这个词拼到末尾，继续预测下下个词。如此反复，直到生成一段完整的文本。

就这么简单？是的——但又没那么简单。当模型的参数量达到数亿甚至数千亿，训练数据覆盖数十亿个词时，这个简单的"下一个词预测"任务会涌现出令人惊叹的能力：逻辑推理、数学解题、代码生成、多语言翻译。这正是本书要带你从零开始构建的东西。

## 1.1 从 GPT 到 ChatGPT：一段简短的家谱

要理解 LLM 是怎么工作的，我们得先看看它是怎么来的。

**2017：Transformer。** 一切的起点是 Google 的那篇论文 *"Attention Is All You Need"*。它提出了一种全新的神经网络架构——Transformer，核心机制是自注意力（Self-Attention）。相比之前的 RNN/LSTM，Transformer 能并行处理整个序列，大幅提升了训练效率。

**2018-2020：GPT 系列。** OpenAI 在 Transformer 的基础上做了两个关键改动：(1) 只用解码器（decoder-only），不做双向编码；(2) 用因果遮罩（causal mask）确保模型只能看到前面的词，不能偷看后面的。GPT-2（1.5B 参数）展示了"零样本"能力——不用任何微调，仅靠 prompt 就能完成翻译、摘要等任务。GPT-3（175B 参数）更是将这一范式推向了极致。

**2022：InstructGPT / ChatGPT。** 单纯的预训练模型虽然能续写文本，但它不会"听话"——你问它"巴黎在哪里？"，它可能会续写"在法国的南部，有一座美丽的城市……"，而不是直接回答"法国"。InstructGPT 引入了三阶段后训练流程：**监督微调（SFT）→ 奖励模型（Reward Model）→ 强化学习（PPO）**，也就是后来广为人知的 RLHF（Reinforcement Learning from Human Feedback）。这一步让模型从"会续写"变成了"会对话"。

**2023-2024：百花齐放。** DPO（Direct Preference Optimization）绕过了奖励模型和强化学习，直接在偏好数据上做优化，大幅简化了流程。PPO 之外的变体——ORPO、KTO——也相继提出。

**2025：GRPO / DeepSeek-R1。** DeepSeek 提出的 GRPO（Group Relative Policy Optimization）代表了最新的方向：不再需要价值网络（Value Network），而是用组内对比的方式计算优势函数（Advantage），让模型在数学推理等可验证任务上展现出强大的推理能力。

本书的代码实现覆盖了以上所有方法——SFT、Reward Model、DPO/ORPO/KTO、PPO、GRPO——全部用纯 PyTorch 从零手写，不依赖 `transformers`、`trl`、`peft` 等高级库。

## 1.2 一张图看懂训练流水线

整个 LLM 的训练可以分为两大阶段：**预训练（Pretraining）** 和 **后训练（Post-Training）**。用一张图来概括：

```
原始文本（The Pile）
    │
    ▼
┌─────────────────────┐
│  分词（Tokenization） │  文本 → 整数序列 → HDF5 文件
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│  预训练（Pretrain）   │  下一个 token 预测（Cross-Entropy Loss）
│  ~90M 参数 base 模型  │  在 The Pile 上训练数万步
└─────────────────────┘
    │
    ▼
 base_pretrained.pt
    │
    ├──► ┌──────────────────────┐
    │    │  SFT（监督微调）       │  学习对话格式，只在 assistant 回复上算 loss
    │    │  Alpaca + Dolly + GSM │
    │    └──────────────────────┘
    │         │
    │         ▼
    │    sft.pt
    │         │
    │         ├──► ┌──────────────────────┐
    │         │    │  Reward Model         │  学习人类偏好（Bradley-Terry Loss）
    │         │    └──────────────────────┘
    │         │         │
    │         │         ▼
    │         │    reward.pt
    │         │         │
    │         │         ▼
    │         │    ┌──────────────────────┐
    │         │    │  PPO（RLHF）          │  GAE + Clipped Surrogate + KL 惩罚
    │         │    └──────────────────────┘
    │         │         │
    │         │         ▼
    │         │    ppo.pt ──► 评估 / 对话
    │         │
    │         ├──► ┌──────────────────────┐
    │         │    │  DPO / ORPO / KTO     │  偏好学习，无需 RL 循环
    │         │    └──────────────────────┘
    │         │         │
    │         │         ▼
    │         │    dpo.pt ──► 评估 / 对话
    │         │
    │         └──► ┌──────────────────────┐
    │              │  GRPO（DeepSeek-R1）  │  组内对比 + 可验证奖励
    │              └──────────────────────┘
    │                   │
    │                   ▼
    │              grpo.pt ──► 评估 / 对话
    │
    └──► base_pretrained.pt ──► 文本续写（raw 模式）
```

从上到下，我们只做一件事：**改数据、改 loss，模型不变。** 这就是全部的秘密。

### 预训练：学语言

预训练的目标是让模型学会"语言"本身——语法、语义、常识、推理模式。我们把海量的无标注文本（The Pile，约 800GB）分词成整数序列，然后让模型反复做一件事：**给定前面的 token，预测下一个 token。**

训练目标是最经典的交叉熵损失（Cross-Entropy Loss）：

$$
\mathcal{L} = -\sum_{t=1}^{T} \log P(x_t \mid x_1, \ldots, x_{t-1})
$$

预训练完成后，我们得到一个 **base 模型**。它"会说话"，但还"不会听话"——你给它一个问题，它只会续写更多的问题，而不是给出答案。

### SFT：学对话

SFT（Supervised Fine-Tuning，监督微调）是后训练的第一步。我们用人工标注的"指令-回答"对来继续训练模型。关键的设计是 **loss mask**：只在 assistant 的回复部分计算损失，不对 prompt 部分计算。这样模型学会的是"如何回答问题"，而不是"如何复述问题"。

SFT 之后，模型就具备了基本的对话能力——能理解 `<|user|>` 和 `<|assistant|>` 的角色标记，并给出结构化的回答。

### 奖励模型：学偏好

要让模型的回答"更好"，我们需要一种量化"好坏"的方式。奖励模型（Reward Model）的做法是：给模型看同一个问题的两个回答（一个人类标注为"好"的 chosen，一个标注为"差"的 rejected），训练一个打分头（scalar head），使得 `reward(chosen) > reward(rejected)`。

训练用的是 Bradley-Terry 损失：

$$
\mathcal{L} = -\log \sigma(r_{\text{chosen}} - r_{\text{rejected}})
$$

### DPO：跳过奖励模型

DPO（Direct Preference Optimization）的思路非常优雅：不需要训练奖励模型，也不需要跑强化学习循环。它直接在偏好数据上优化策略模型，用 log 概率差作为隐式奖励：

$$
\mathcal{L}_{\text{DPO}} = -\log \sigma\Big(\beta \cdot \big[\underbrace{(\log \pi_\theta(y_w|x) - \log \pi_{\text{ref}}(y_w|x))}_{\text{chosen 的隐式奖励}} - \underbrace{(\log \pi_\theta(y_l|x) - \log \pi_{\text{ref}}(y_l|x))}_{\text{rejected 的隐式奖励}}\big]\Big)
$$

其中 π_θ 是正在训练的策略模型，π_ref 是冻结的参考模型（通常是 SFT 模型的副本）。

### PPO：经典 RLHF

PPO（Proximal Policy Optimization）是 ChatGPT 使用的经典方法。它需要同时维护多个模型：

- **策略模型（Actor）**：生成回答
- **价值网络（Critic）**：估计每个 token 的价值（GAE）
- **参考模型（Reference）**：提供 KL 惩罚基线
- **奖励模型（Reward Model）**：给回答打分

训练流程是：rollout（生成回答）→ scoring（打分）→ GAE（计算优势）→ clipped update（更新策略）。

### GRPO：不要价值网络

GRPO（Group Relative Policy Optimization）是 DeepSeek-R1 的核心算法。它的创新在于：**用组内对比替代价值网络**。对同一个 prompt 采样 G 个回答（比如 8 个），用组内的均值和标准差做归一化，得到相对优势：

$$
\hat{A}_i = \frac{r_i - \text{mean}(r_1, \ldots, r_G)}{\text{std}(r_1, \ldots, r_G) + \epsilon}
$$

这种方式特别适合数学推理等"答案可验证"的任务——奖励函数可以直接检查答案是否正确，不需要人类标注偏好。

## 1.3 项目代码结构

本书的代码组织在一个名为 `train-llm-from-scratch` 的项目中。整体结构如下：

```
train-llm-from-scratch/
│
├── src/
│   ├── models/                    ← Transformer 模型，从最小零件堆叠而成
│   │   ├── mlp.py                 ← MLP：per-token 的"思考"
│   │   ├── attention.py           ← 注意力：让 token 看到彼此
│   │   ├── transformer_block.py   ← Transformer Block：注意力 + MLP + 残差
│   │   └── transformer.py         ← 完整模型：Embedding → Blocks → lm_head
│   │
│   └── post_training/             ← 后训练全家桶
│       ├── sft.py                 ← SFT loss（masked cross-entropy）
│       ├── reward_model.py        ← 奖励模型架构
│       ├── dpo.py                 ← DPO / ORPO / KTO loss
│       ├── ppo.py                 ← PPO：GAE + clipped surrogate
│       ├── grpo.py                ← GRPO：group-relative advantages
│       ├── rollout.py             ← 自回归采样 + log-prob 追踪
│       ├── chat_template.py       ← 对话格式与 loss mask
│       ├── evaluation.py          ← GSM8K 评估
│       └── inference.py           ← 推理与对话
│
├── config/                        ← 配置系统
│   ├── config.py                  ← 旧版预训练配置
│   ├── post_training_config.py    ← 后训练 dataclass 配置
│   └── loader.py                  ← JSON 配置加载与合并
│
├── configs/                       ← 各阶段的 JSON 配置文件
│   ├── base.json                  ← 模型结构参数
│   ├── pretrain.json / sft.json   ← 各阶段训练超参
│   └── smoke/                     ← 冒烟测试配置（秒级完成）
│
├── scripts/                       ← 可执行脚本（每个阶段一个入口）
│   ├── prepare_pretrain_data.py   ← 预训练数据准备
│   ├── prepare_sft_data.py        ← SFT 数据准备
│   ├── pretrain_base.py           ← 预训练主脚本
│   ├── train_sft.py               ← SFT 训练
│   ├── train_reward.py            ← 奖励模型训练
│   ├── train_dpo.py               ← DPO 训练
│   ├── train_ppo.py               ← PPO 训练
│   ├── train_grpo.py              ← GRPO 训练
│   ├── chat.py                    ← 对话测试
│   └── eval_post_training.py      ← 跨阶段评估
│
├── data_loader/                   ← 数据加载器
├── ui/                            ← Streamlit 可视化控制台
├── tests/                         ← 测试与验证
├── images/                        ← 图解（Mermaid + PNG）
└── docs/                          ← MkDocs 文档站点
```

### 核心设计原则：wrap, don't rewrite

整个后训练体系建立在原始 `Transformer` 模型之上，我们只在模型上加了一个 `forward_hidden` 方法，返回最终隐藏状态（layer_norm 之后的输出）。所有后训练组件——奖励模型的 scalar head、PPO 的 value head、DPO/GRPO 的 log-prob 计算——都围绕这个核心方法做组合，而不修改模型本身。

```python
class Transformer(nn.Module):
    def forward_hidden(self, idx):
        """返回最终隐藏状态，供后训练的各种 head 使用"""
        x = self._pre_attn_pass(idx)          # token + position embedding
        for block in self.attn_blocks:         # 逐层过 transformer block
            x = block(x)
        return self.layer_norm(x)              # 最终 layer norm
```

这种设计意味着：你在第 3 章学到的 Transformer 知识，在后面的每一个阶段都用得上。模型始终没变，变的是数据和 loss。

## 1.4 配置系统：四层覆盖

项目采用四层配置覆盖机制，从低到高优先级依次为：

```
dataclass 默认值  ←  configs/base.json  ←  阶段 JSON（如 sft.json）←  CLI 参数
```

举个例子，`n_embed` 这个参数：

1. `post_training_config.py` 中的 `BaseModelConfig` 默认值是 `1024`
2. `configs/base.json` 可能设为 `512`（覆盖默认值）
3. `configs/sft.json` 如果也有 `n_embed`，会再次覆盖
4. 命令行 `--n_embed 256` 优先级最高，覆盖一切

这种设计让你在实验时不用反复编辑配置文件，一个命令行参数就能切换。

## 1.5 你需要什么

### 硬件

- **最低要求**：一块 GPU，16GB 显存即可训练 ~90M 参数的模型
- **推荐配置**：24GB+ 显存（如 RTX 3090/4090），可训练 ~200M 参数
- **云端方案**：Colab / Kaggle 的 T4（16GB）可以跑 smoke 测试和小模型

### 软件

- Python 3.9+
- PyTorch 2.x（支持 bf16 混合精度）
- 基本依赖：`tiktoken`、`h5py`、`numpy`、`datasets`

安装项目：

```bash
git clone https://github.com/FareedKhan-dev/train-llm-from-scratch.git
cd train-llm-from-scratch
pip install -e .
pip install -e ".[train]"   # 安装 datasets, wandb 等训练依赖
```

### 前置知识

- **Python 编程**：类、函数、列表推导式
- **PyTorch 基础**：张量操作、`nn.Module`、自动微分
- **深度学习概念**：梯度下降、损失函数、过拟合（了解即可）

如果你不确定自己的基础够不够，试试能不能看懂这段代码：

```python
x = torch.randn(2, 3, 128)     # (batch, seq_len, n_embed)
y = self.ln1(x)                # layer norm
z = x + self.attn(y)           # 残差连接 + 注意力
loss = F.cross_entropy(logits, targets)
loss.backward()
optimizer.step()
```

如果每个函数调用你都知道在做什么，那你的基础完全够用。

## 1.6 本书的阅读路线

本书按训练流水线的顺序组织，建议按顺序阅读：

| 篇章 | 章节 | 你将学到 |
|------|------|----------|
| **第一篇：基础理论** | 2-5 章 | 分词、Transformer 架构、超参数选择、优化器 |
| **第二篇：预训练** | 6-9 章 | 数据准备、训练循环、loss 诊断、文本生成 |
| **第三篇：后训练** | 10-13 章 | Chat 格式、SFT、奖励模型 |
| **第四篇：对齐** | 14-16 章 | DPO/ORPO/KTO、PPO、GRPO |
| **第五篇：工程实践** | 17-20 章 | 评估、推理、分布式训练、调试 |
| **第六篇：进阶** | 21-23 章 | 规模效应、可视化、工程化 |

如果你时间有限，可以走"快速路线"：

1. 读第 1-3 章（概览 + 分词 + Transformer）
2. 读第 6-7 章（预训练数据和训练）
3. 读第 11-12 章（Chat 格式 + SFT）
4. 读第 14 章（DPO，最简单的对齐方法）

这条路线大约覆盖全书 40% 的内容，但能让你理解并跑通从预训练到对齐的最小闭环。

## 1.7 本章小结

让我们回顾一下本章的核心要点：

1. **LLM 的本质是"下一个 token 预测"。** 预训练学语言，SFT 学对话，对齐学偏好——都是通过改变数据和 loss 来实现的。

2. **训练流水线：预训练 → SFT → {Reward Model → PPO, DPO, GRPO} → 评估。** 每个阶段产出一个 checkpoint，下一个阶段在此基础上继续。

3. **代码设计原则：wrap, don't rewrite。** 后训练的所有组件都围绕原始 Transformer 做组合，模型架构始终不变。

4. **四层配置覆盖：dataclass 默认值 < base.json < 阶段 JSON < CLI 参数。**

在下一章，我们将从最底层开始——分词。文本是怎么变成模型能处理的数字的？分词器的设计对模型能力有什么影响？我们会一一解答。

---

> **练习 1.1**：安装项目依赖，运行 `python tests/test_post_training_smoke.py`，确认环境可用。
>
> **练习 1.2**：浏览 `configs/smoke/` 目录下的各个 JSON 文件，观察每个阶段配置中的 `n_embed`、`n_blocks`、`context_length` 等参数。思考：为什么 smoke 配置的模型这么小？
>
> **思考题**：如果预训练模型只会"续写文本"而不会"回答问题"，那 SFT 是如何教会它"回答问题"的？Loss mask 在其中扮演了什么角色？
