# 第 10 章：后训练概览与设计哲学

> **本章目标**：理解后训练的完整架构，掌握"为什么预训练模型不能直接对话"，以及本项目后训练系统的设计原则。

## 10.0 本章路线图

在第 6-9 章中，我们从数据准备到训练循环到文本生成，完成了预训练的全流程。我们得到了一个"懂语言"的模型——但还不能"对话"。

本章是第三篇的总纲，介绍后训练的整体设计：

```
后训练的四层架构
│
├── 第 1 层：SFT（监督微调）
│   └── 教会模型"回答问题"的格式
│
├── 第 2 层：Reward Model（奖励模型）
│   └── 教会模型"什么是好的回答"
│
├── 第 3 层：DPO / PPO（偏好优化）
│   └── 用偏好数据推动模型对齐
│
└── 第 4 层：GRPO（强化学习 + 验证奖励）
    └── 用外部验证器（如数学答案检查器）奖励正确输出
```

## 10.1 为什么预训练模型不能直接对话

### 10.1.1 预训练的目标是续写，不是回答

回顾第 7 章，预训练的目标函数是 **Next-Token Prediction**：

```
输入:  ["The", "capital", "of", "France", "is"]
目标:  ["capital", "of", "France", "is", "Paris"]
```

模型学到的是："给定一段文本的前缀，续写后面的内容。" 这是一个**文本续写机器**。

### 10.1.2 实际效果

如果你给预训练模型输入一个问题：

```
输入: "What is the capital of France?"

期望输出: "The capital of France is Paris."

实际输出: "What is the capital of France? The capital of France is Paris.
           What is the capital of Germany? The capital of Germany is Berlin.
           What is the capital of Italy? ..."
```

模型把"问题"也当成了要续写的文本——它不"理解"这是一个需要回答的问题，它只是在做模式续写。

### 10.1.3 根本原因

| | 预训练 | 对话 |
|---|---|---|
| 输入形式 | 任意文本前缀 | 结构化的用户消息 |
| 输出形式 | 续写文本 | 有针对性的回答 |
| 训练目标 | 最大化续写概率 | 满足用户意图 |
| 数据分布 | 互联网文本（含问题+答案） | 指令-回复对 |

预训练数据里有无数"问答对"，但模型学到的是"问题后面跟着答案"这个模式，而不是"看到问题就回答"这个行为。

### 10.1.4 后训练解决什么

后训练要教给模型三件事：

1. **格式**：看到 `<|user|>...<|assistant|>` 就输出回答（SFT 负责）
2. **质量**：在多种可能的回答中选择更好的（Reward Model / DPO / PPO 负责）
3. **正确性**：对可以验证的任务（如数学），输出正确答案（GRPO / RLVR 负责）

## 10.2 后训练的四层架构

### 10.2.1 架构总览

```
Base (pretrained)  ──▶  SFT  ──▶  Reward Model ──▶  PPO ┐
                          │                            ├─▶  GRPO / RLVR
                          └────────▶  DPO / ORPO / KTO ─┘
```

每个阶段都从上一个阶段的 checkpoint 开始，逐步优化模型。

### 10.2.2 第 1 层：SFT（监督微调）

**目标**：教会模型"回答问题"的格式。

**数据**：指令-回复对（Alpaca、Dolly-15k、GSM8K）

```
输入: <|user|>
What is 2+2?<|endoftext|><|assistant|>
2+2=4<|endoftext|>

Loss Mask: 0 0 0 0 0 0 0 0 0 0  1 1 1 1 1  1
           ^^^^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^
           不训练（prompt）        训练（回答）
```

**关键设计**：Loss Mask——只在 assistant 的回复 token 上计算损失，不训练模型生成 prompt 部分。

**效果**：SFT 后，模型学会了"看到问题就回答"的行为。

### 10.2.3 第 2 层：Reward Model（奖励模型）

**目标**：教会模型"什么是好的回答"。

**数据**：人类偏好数据（Anthropic HH-RLHF、UltraFeedback）

```
给定 prompt P，有两个回复 A 和 B：
  A: "Paris is the capital of France."      (chosen)
  B: "I think it might be Paris maybe?"     (rejected)

Reward Model 学习：R(P, A) > R(P, B)
```

**架构**：复用 SFT 的 backbone，加一个 `Linear(n_embed, 1)` 奖励头。

**用途**：为 PPO 提供奖励信号（评估生成文本的质量）。

### 10.2.4 第 3 层：DPO / PPO（偏好优化）

**DPO（Direct Preference Optimization）**：

跳过 Reward Model，直接用偏好数据优化策略。

```
DPO Loss = -log σ(β × (log π(A|P)/π_ref(A|P) - log π(B|P)/π_ref(B|P)))
```

直觉：增大 chosen 回复的 log-prob，减小 rejected 回复的 log-prob。

**PPO（Proximal Policy Optimization）**：

经典 RLHF 循环：

```
SFT Policy  ──▶  Rollout（生成文本）
                      │
                      ▼
                Reward Model 打分
                      │
                      ▼
                PPO 更新策略
```

### 10.2.5 第 4 层：GRPO（Group Relative Policy Optimization）

**目标**：对可验证任务（如数学），用外部验证器奖励正确答案。

**核心思想**：不需要 Reward Model，直接检查答案是否正确。

```
对于每个 prompt，生成 G 个回答（一组）：
  g1: "...=42"  ✓ correct
  g2: "...=43"  ✗ wrong
  g3: "...=42"  ✓ correct
  ...

用组内的相对好坏（正确 vs 错误）作为优势，更新策略。
```

### 10.2.6 各阶段对比

| 阶段 | 输入 | 训练什么 | 评估指标 |
|------|------|---------|---------|
| SFT | 指令-回复对 | 回答格式 | Masked Loss, GSM8K acc |
| Reward | 偏好对 (chosen/rejected) | 奖励头 | Preference Accuracy |
| DPO | 偏好对 | 策略（log-prob 差） | Implicit Reward Acc |
| PPO | 提示 + Reward 信号 | 策略 + 价值头 | GSM8K acc |
| GRPO | 提示 + 验证器 | 策略 | GSM8K acc |

## 10.3 "Wrap, don't rewrite" 设计原则

### 10.3.1 核心思想

整个后训练系统遵循一个设计原则：**不修改原始的 Transformer 代码，通过包装来扩展功能**。

```
src/models/transformer.py          ← 原始模型（不修改）
    │
    ├── + Reward Head              → reward_model.py
    ├── + Value Head               → value_head.py
    ├── + Chat Template            → chat_template.py
    └── + Rollout / Log-prob       → rollout.py
```

### 10.3.2 为什么要这样做

1. **简单性**：原始 Transformer 代码保持干净，学生先学会基础架构
2. **组合性**：不同的包装可以独立组合（Reward + Rollout = PPO）
3. **兼容性**：所有包装都复用同一个 backbone，checkpoint 可以在阶段间传递
4. **教学性**：每一层包装都对应一个清晰的概念（奖励、价值、rollout）

### 10.3.3 实际体现

**Reward Model**：backbone + 奖励头

```python
# src/post_training/reward_model.py

class RewardModel(nn.Module):
    def __init__(self, transformer: Transformer):
        super().__init__()
        self.transformer = transformer                    # 复用 backbone
        self.reward_head = nn.Linear(transformer.n_embed, 1)  # 新增奖励头
```

**Value Head**（PPO 用）：backbone + 价值头

```python
# src/post_training/value_head.py

class ValueHead(nn.Module):
    def __init__(self, transformer: Transformer):
        super().__init__()
        self.transformer = transformer                    # 复用 backbone
        self.value_head = nn.Linear(transformer.n_embed, 1)   # 新增价值头
```

**Rollout 工具**：自由函数，不修改模型

```python
# src/post_training/rollout.py — 纯函数，接受任意模型

def generate_with_logprobs(model, prompt_ids, max_new_tokens, ...):
    # 使用 model(idx) 获取 logits，不关心 model 是什么类型
    ...

def compute_logprobs(model, sequences, response_mask, ...):
    # Teacher-forced 计算 log-prob，同样不关心模型类型
    ...
```

### 10.3.4 Checkpoint 兼容性

因为所有阶段共用同一个 backbone，checkpoint 的结构是一致的：

```python
# 保存：只保存 backbone 的 state_dict
payload = {
    "model_state_dict": unwrap(model).state_dict(),  # backbone 权重
    "optimizer_state_dict": ...,
    "stage": "sft",  # 或 "dpo", "ppo", "grpo"
    ...
}

# 加载：只取 backbone 的 key
backbone_keys = set(model.state_dict().keys())
filtered = {k: v for k, v in state.items() if k in backbone_keys}
model.load_state_dict(filtered, strict=False)
```

这意味着：
- SFT checkpoint 可以被 Reward Model 加载
- SFT checkpoint 可以被 DPO 加载（作为 policy + reference）
- 任何 checkpoint 可以被 `load_model_from_ckpt` 加载用于推理

## 10.4 四层配置系统

### 10.4.1 配置的四层覆盖

后训练的配置采用四层优先级系统，低优先级被高优先级覆盖：

```
第 1 层：dataclass 默认值      ← 最低优先级
    ↓ 被覆盖
第 2 层：configs/base.json      ← 共享的模型 + 运行时配置
    ↓ 被覆盖
第 3 层：configs/sft.json 等    ← 特定阶段的超参数
    ↓ 被覆盖
第 4 层：CLI --field 参数        ← 最高优先级
```

### 10.4.2 第 1 层：Dataclass 默认值

```python
# config/post_training_config.py

@dataclass
class BaseModelConfig:
    vocab_size: int = 50304
    context_length: int = 1024
    n_embed: int = 1024
    n_head: int = 16
    n_blocks: int = 24
    device: str = "cuda"
    amp_dtype: str | None = "bf16"
    ...

@dataclass
class SFTConfig(BaseModelConfig):
    pretrained_ckpt: str = f"{CKPT_DIR}/base_pretrained.pt"
    batch_size: int = 16
    lr: float = 1e-5
    epochs: int = 3
    ...
```

Dataclass 提供了类型安全的默认值，每个字段都有明确的类型和默认值。

### 10.4.3 第 2 层：base.json（共享配置）

```json
// configs/base.json
{
  "vocab_size": 50304,
  "context_length": 256,
  "n_embed": 256,
  "n_head": 4,
  "n_blocks": 6,
  "device": "cuda",
  "amp_dtype": "bf16",
  "seed": 1337,
  "compile": false
}
```

`base.json` 存放所有阶段共享的配置——通常是模型架构和运行时参数。

**关键设计**：当使用 `configs/smoke/sft.json` 时，系统会自动加载同目录的 `configs/smoke/base.json`（更小模型，用于快速测试）。

### 10.4.4 第 3 层：stage.json（阶段配置）

```json
// configs/sft.json
{
  "pretrained_ckpt": "/ephemeral/ckpts/base_pretrained.pt",
  "data_path": "/ephemeral/data/sft_packed.h5",
  "out_ckpt": "/ephemeral/ckpts/sft.pt",
  "batch_size": 16,
  "grad_accum": 2,
  "epochs": 3,
  "lr": 1e-05,
  "warmup_steps": 100
}
```

每个阶段的 JSON 只包含该阶段特有的超参数，不重复 `base.json` 中的字段。

### 10.4.5 第 4 层：CLI 覆盖

```bash
# 直接覆盖任何字段
PYTHONPATH=. python3 scripts/train_sft.py --lr 2e-5 --batch_size 8

# 指定不同的 stage JSON
PYTHONPATH=. python3 scripts/train_sft.py --config configs/smoke/sft.json

# 打印最终解析的配置
PYTHONPATH=. python3 scripts/train_sft.py --print-config
```

CLI 参数拥有最高优先级，适合快速实验不同的超参数。

### 10.4.6 配置加载代码

```python
# config/loader.py

def load_config(cfg_cls, json_path=None, overrides=None, *, base_path=None):
    # 第 2 层：base.json
    base = _resolve_base(json_path, base_path)
    merged = {}
    for path in (base, json_path):
        if path and os.path.exists(path):
            _deep_merge(merged, json.load(path))

    # 第 4 层：CLI 覆盖
    if overrides:
        merged.update({k: v for k, v in overrides.items()
                       if k in field_names and v is not None})

    return cfg_cls(**merged)    # 第 1 层：dataclass 补全缺失字段
```

### 10.4.7 SMOKE 配置（快速测试）

```python
# config/post_training_config.py

SMOKE = dict(
    vocab_size=256, context_length=64, n_embed=64,
    n_head=4, n_blocks=2, device="cpu", amp_dtype=None
)

def smoke(cfg_cls):
    return replace(cfg_cls(), **SMOKE)
```

`configs/smoke/` 目录提供了一组超小配置，可以在 CPU 上几秒钟内跑完全部阶段——用于验证代码是否正确，不关心效果。

## 10.5 后训练阶段的依赖关系

### 10.5.1 Checkpoint 依赖图

```
base_pretrained.pt
    │
    ├──▶ sft.pt ─────────────────┬──▶ dpo.pt
    │                            │
    │                            ├──▶ reward.pt ──▶ ppo.pt
    │                            │
    │                            └──▶ grpo.pt
    │
    └──▶ （也可以直接从 base 开始 SFT）
```

### 10.5.2 每个阶段的输入和输出

| 阶段 | 输入 Checkpoint | 输出 Checkpoint | 额外输入 |
|------|----------------|----------------|---------|
| SFT | base_pretrained.pt | sft.pt | sft_packed.h5 |
| Reward | sft.pt | reward.pt | preferences.jsonl |
| DPO | sft.pt | dpo.pt | preferences.jsonl |
| PPO | sft.pt + reward.pt | ppo.pt | rl_prompts.jsonl |
| GRPO | sft.pt | grpo.pt | rl_prompts.jsonl + verifier |

### 10.5.3 配置中的 Checkpoint 路径

```python
@dataclass
class SFTConfig(BaseModelConfig):
    pretrained_ckpt: str = f"{CKPT_DIR}/base_pretrained.pt"   # 从预训练开始
    out_ckpt: str = f"{CKPT_DIR}/sft.pt"                      # 输出 SFT 模型

@dataclass
class DPOConfig(BaseModelConfig):
    sft_ckpt: str = f"{CKPT_DIR}/sft.pt"                      # 从 SFT 开始
    out_ckpt: str = f"{CKPT_DIR}/dpo.pt"

@dataclass
class PPOConfig(BaseModelConfig):
    sft_ckpt: str = f"{CKPT_DIR}/sft.pt"                      # 策略从 SFT 初始化
    reward_ckpt: str = f"{CKPT_DIR}/reward.pt"                # 奖励从 Reward Model
    out_ckpt: str = f"{CKPT_DIR}/ppo.pt"
```

## 10.6 本章小结

### 后训练全景

```
预训练模型（语言续写机器）
    │
    ▼ SFT
指令跟随模型（学会了回答问题）
    │
    ├─▶ DPO（用偏好数据直接优化）
    │
    ├─▶ Reward + PPO（经典 RLHF）
    │
    └─▶ GRPO（验证器奖励，无需 Reward Model）
```

### 设计原则

| 原则 | 体现 |
|------|------|
| Wrap, don't rewrite | 不修改 Transformer，通过包装扩展 |
| 统一 backbone | 所有阶段共享同一个模型结构 |
| Checkpoint 兼容 | 阶段间通过 state_dict 传递 |
| 四层配置 | dataclass → base.json → stage.json → CLI |
| 单一评估轴 | 所有阶段的 head metric 都是 GSM8K 准确率 |

### 关键概念

| 概念 | 含义 |
|------|------|
| Loss Mask | 只在 assistant token 上计算损失 |
| Reference Model | 冻结的原始策略，用于 KL 约束 |
| Rollout | 自回归生成 + 记录 log-prob |
| Group Advantage | GRPO 中用组内相对好坏作为优势 |
| KL Penalty | 防止策略偏离 reference 太远 |

---

## 练习

**练习 1：配置系统实验**

打印 SFT 的最终解析配置，然后尝试覆盖几个字段：

```bash
# 打印默认配置
PYTHONPATH=. python3 scripts/train_sft.py --print-config

# 覆盖学习率和 batch size
PYTHONPATH=. python3 scripts/train_sft.py --lr 5e-5 --batch_size 8 --print-config

# 使用 smoke 配置
PYTHONPATH=. python3 scripts/train_sft.py --config configs/smoke/sft.json --print-config
```

观察每层覆盖是如何生效的。

**练习 2：预测模型行为**

在不运行代码的情况下，预测以下行为：

1. 给预训练模型输入 `"def add(a, b):"` —— 它最可能输出什么？
2. 给 SFT 模型输入 `<|user|>What is 1+1?<|endoftext|><|assistant|>` —— 它最可能输出什么？
3. 给 DPO 模型输入同样的 prompt —— 与 SFT 模型相比，输出有什么不同？

**练习 3：架构对比**

画出以下两个架构的参数流向：

- **PPO**：Policy（可训练）+ Reference（冻结）+ Reward Model（冻结）+ Value Head（可训练）
- **GRPO**：Policy（可训练）+ Reference（冻结）+ Verifier（外部函数）

数一数每个架构需要多少个模型副本在显存中？
