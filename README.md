# 《从零训练大语言模型：原理、代码与实战》


## 电子书在线阅读

> 以下为《从零训练大语言模型：原理、代码与实战》完整电子书，托管于 GitHub Pages，可直接点击章节标题在线阅读。

### 第一篇：基础理论

| 章节 | 标题 | 在线阅读 |
|------|------|----------|
| 第 1 章 | 引言——LLM 训练全链路概览 | [阅读](ebooks/ch01_introduction.md) |
| 第 2 章 | 分词（Tokenization） | [阅读](ebooks/ch02_tokenization.md) |
| 第 3 章 | Transformer 架构——从最小单元到完整模型 | [阅读](ebooks/ch03_transformer.md) |
| 第 4 章 | 关键超参数与硬件规划 | [阅读](ebooks/ch04_hyperparameters.md) |
| 第 5 章 | 优化与学习率调度 | [阅读](ebooks/ch05_optimization.md) |

### 第二篇：预训练——让模型学会语言

| 章节 | 标题 | 在线阅读 |
|------|------|----------|
| 第 6 章 | 预训练数据准备 | [阅读](ebooks/ch06_pretrain_data.md) |
| 第 7 章 | 预训练循环 | [阅读](ebooks/ch07_pretraining_loop.md) |
| 第 8 章 | 观察训练——Loss 曲线与诊断 | [阅读](ebooks/ch08_observing_training.md) |
| 第 9 章 | 文本生成 | [阅读](ebooks/ch09_text_generation.md) |

### 第三篇：后训练——从语言模型到 AI 助手

| 章节 | 标题 | 在线阅读 |
|------|------|----------|
| 第 10 章 | 后训练概览与设计哲学 | [阅读](ebooks/ch10_post_training_overview.md) |
| 第 11 章 | Chat 格式与 Loss Mask | [阅读](ebooks/ch11_chat_format_loss_mask.md) |
| 第 12 章 | 监督微调（SFT） | [阅读](ebooks/ch12_sft.md) |
| 第 13 章 | 奖励模型（Reward Model） | [阅读](ebooks/ch13_reward_model.md) |

### 第四篇：对齐——让模型做正确的事

| 章节 | 标题 | 在线阅读 |
|------|------|----------|
| 第 14 章 | DPO 与变体 | [阅读](ebooks/ch14_dpo.md) |
| 第 15 章 | PPO——经典 RLHF 循环 | [阅读](ebooks/ch15_ppo.md) |
| 第 16 章 | GRPO——DeepSeek-R1 风格推理增强 | [阅读](ebooks/ch16_grpo.md) |

### 第五篇：工程实践

| 章节 | 标题 | 在线阅读 |
|------|------|----------|
| 第 17 章 | 评估与基准测试 | [阅读](ebooks/ch17_evaluation.md) |
| 第 18 章 | 推理与对话系统 | [阅读](ebooks/ch18_inference.md) |
| 第 19 章 | 分布式训练与性能优化 | [阅读](ebooks/ch19_distributed.md) |
| 第 20 章 | 常见陷阱与调试指南 | [阅读](ebooks/ch20_pitfalls_debugging.md) |

### 第六篇：进阶与展望

| 章节 | 标题 | 在线阅读 |
|------|------|----------|
| 第 21 章 | 从 13M 到 400M——规模效应 | [阅读](ebooks/ch21_scaling.md) |
| 第 22 章 | UI 可视化控制台 | [阅读](ebooks/ch22_ui.md) |
| 第 23 章 | 从项目到产品 | [阅读](ebooks/ch23_product.md) |

### 附录

| 标题 | 在线阅读 |
|------|----------|
| 附录（A–E） | [阅读](ebooks/appendices.md) |

## 大纲

## 第一篇：基础理论

### 第 1 章：引言——LLM 训练全链路概览

- 什么是大语言模型，从 GPT 到 ChatGPT 的演进
- 本书路线图：`原始文本 → 预训练 → SFT → 对齐（DPO/PPO/GRPO）→ 评估与对话`
- 全书代码结构与配套项目说明
- 一张图看懂整个训练流水线

### 第 2 章：分词（Tokenization）

- 从文本到整数：模型永远只看到数字
- BPE 算法原理与 tiktoken（r50k_base）实践
- 特殊 token 与 `<|endoftext|>` 的设计
- 代码实现：`scripts/prepare_pretrain_data.py` 逐行解析
- 动手实验：编码 100 段文本，观察压缩率

### 第 3 章：Transformer 架构——从最小单元到完整模型

- 3.1 多层感知机（MLP）：per-token 的"思考"
- 3.2 单头注意力（Single Head Attention）：让 token 看到彼此
- 3.3 因果掩码（Causal Mask）：语言模型的核心约束
- 3.4 多头注意力（Multi-Head Attention）：并行捕捉多种模式
- 3.5 Transformer Block：注意力 + MLP + 残差连接 + LayerNorm
- 3.6 完整 Transformer：Embedding → Blocks → lm_head
- 3.7 `forward_hidden` 的设计哲学：wrap, don't rewrite
- 代码实现：`src/models/` 逐文件解析

### 第 4 章：关键超参数与硬件规划

- `n_embed`、`n_head`、`n_blocks`、`context_length`、`vocab_size` 的含义与约束
- 参数量估算公式与 Chinchilla 法则
- 显存预算分析：参数 + 优化器 + 梯度 + 激活值
- 不同 GPU（8GB/16GB/24GB/40GB）能训练多大的模型
- 混合精度（bf16/fp16）、梯度累积、梯度检查点

### 第 5 章：优化与学习率调度

- AdamW 优化器原理与参数选择
- 学习率 Warmup + Cosine Decay 的原理与实现
- 梯度裁剪（Gradient Clipping）
- 权重衰减（Weight Decay）的作用
- 代码实现：`pretrain_base.py` 中的优化循环

---

## 第二篇：预训练——让模型学会语言

### 第 6 章：预训练数据准备

- The Pile 数据集介绍
- 流式下载与批量编码
- HDF5 存储格式设计
- 代码实现：`scripts/prepare_pretrain_data.py` 和 `data_preprocess.py`
- 数据规模与训练步数的匹配

### 第 7 章：预训练循环

- Next-token prediction 目标与 Cross-Entropy Loss
- 训练循环核心代码逐行解析
- 梯度累积实现细节
- bf16 自动混合精度（amp_autocast）
- DDP 多 GPU 分布式训练
- Checkpoint 保存与恢复
- 代码实现：`scripts/pretrain_base.py` 完整解析

### 第 8 章：观察训练——Loss 曲线与诊断

- 初始 Loss 的含义：`ln(vocab_size)` 是随机猜测
- Loss 曲线解读：正常下降 vs 过拟合 vs 发散
- Dev Loss 与 Train Loss 的差距
- 吞吐量（tok/s）与训练效率
- wandb 日志集成

### 第 9 章：文本生成

- 自回归生成原理
- 采样策略：Temperature、Top-k、Top-p、Greedy
- 代码实现：`Transformer.generate()` 和 `generate_text.py`
- 预训练模型的能力上限与局限

---

## 第三篇：后训练——从语言模型到 AI 助手

### 第 10 章：后训练概览与设计哲学

- 为什么预训练模型不能直接对话
- 后训练的四层架构：SFT → Reward → DPO/PPO → GRPO
- "Wrap, don't rewrite" 设计原则
- 四层配置系统：dataclass → base.json → stage.json → CLI

### 第 11 章：Chat 格式与 Loss Mask

- 对话模板设计：`<|user|>`、`<|assistant|>` 角色标记
- 推理格式：`<think>...</think><answer>...</answer>`
- Loss Mask 的原理与实现：只训练模型生成回答
- `pack_examples`：变长对话打包为固定长度序列
- 代码实现：`src/post_training/chat_template.py` 和 `src/post_training/sft.py`

### 第 12 章：监督微调（SFT）

- SFT 的数据来源：Alpaca、Dolly-15k、GSM8K
- Masked Cross-Entropy Loss 详解
- 数据准备：`scripts/prepare_sft_data.py`
- 训练脚本：`scripts/train_sft.py` 逐行解析
- context_length 对齐的重要性（数据 × 模型 × checkpoint 三方一致）
- SFT 前后的生成效果对比

### 第 13 章：奖励模型（Reward Model）

- 人类偏好与 Bradley-Terry 模型
- 奖励头的架构：backbone + Linear(n_embed, 1)
- `gather_last`：取最后一个真实 token 的 reward
- 偏好数据准备：Anthropic HH-RLHF + UltraFeedback
- 训练脚本：`scripts/train_reward.py` 完整解析
- 偏好准确率（Preference Accuracy）指标解读
- 代码实现：`src/post_training/reward_model.py` 和 `reward_train.py`

---

## 第四篇：对齐——让模型做正确的事

### 第 14 章：DPO 与变体

- DPO 的直觉：跳过 Reward Model，用 log-prob 差作为隐式奖励
- Policy + Frozen Ref 双模型架构
- DPO Loss 推导与代码实现
- ORPO：无参考模型的 SFT+对齐一步到位
- KTO：从 unpaired 信号学习
- 训练脚本：`scripts/train_dpo.py` 完整解析
- 隐式奖励准确率指标
- 代码实现：`src/post_training/dpo.py`

### 第 15 章：PPO——经典 RLHF 循环

- PPO 全流程：Rollout → Scoring → GAE → Clipped Update
- Actor-Critic 架构与 Value Head
- 自回归 Rollout 与 log-prob 追踪
- Per-token reward = KL penalty + terminal task reward
- GAE（Generalized Advantage Estimation）从后往前递推
- Clipped Surrogate 策略损失
- Clipped Value 损失
- 训练脚本：`scripts/train_ppo.py` 完整解析
- 代码实现：`src/post_training/ppo.py` 和 `rollout.py`

### 第 16 章：GRPO——DeepSeek-R1 风格推理增强

- GRPO 的核心创新：扔掉 Value Network
- Group Sampling：每个 prompt 采样 G 个回答
- Group-Relative Advantages：`(r - mean) / std`
- K3 KL 惩罚：Schulman's k3 估计器
- Curriculum Learning：从简单算术到 GSM8K
- 训练脚本：`scripts/train_grpo.py` 完整解析
- PPO vs GRPO 的对比与选择
- 代码实现：`src/post_training/grpo.py`

---

## 第五篇：工程实践

### 第 17 章：评估与基准测试

- GSM8K 作为贯穿性指标的设计
- 贪心解码评估流程
- `<answer>` 标签解析与答案校验
- 跨阶段对比表：Base → SFT → DPO → PPO → GRPO
- 代码实现：`scripts/eval_post_training.py`

### 第 18 章：推理与对话系统

- 加载任意 Checkpoint 的通用推理引擎
- Chat 模式 vs Raw 续写模式
- Checkpoint key 兼容性问题（DDP `module.` 前缀、`torch.compile` `_orig_mod.` 前缀）
- 交互式对话实现
- 代码实现：`src/post_training/inference.py` 和 `scripts/chat.py`

### 第 19 章：分布式训练与性能优化

- PyTorch DDP 原理与 `torchrun` 启动
- bf16 混合精度训练
- 梯度累积策略
- 显存优化技巧汇总
- 多 GPU 通信开销分析

### 第 20 章：常见陷阱与调试指南

- Checkpoint key 不匹配（163 missing keys）
- 数据 context_length 与模型不一致
- `torch.compile` 环境兼容性问题
- PyTorch 版本升级的 breaking changes（`weights_only=True`）
- Loss 不下降的排查清单
- OOM 时的参数调优策略

---

## 第六篇：进阶与展望

### 第 21 章：从 13M 到 400M——规模效应

- Scaling Laws 简介
- 不同规模模型的生成质量对比（13M / 90M / 400M）
- 数据量、模型大小、训练步数的平衡

### 第 22 章：UI 可视化控制台

- Streamlit 多页面应用架构
- 每个训练阶段的可视化面板设计
- 实时 Loss 监控与模型对话
- 代码实现：`ui/` 目录解析

### 第 23 章：从项目到产品

- Smoke Test 与快速验证
- 一键全链路脚本设计（`run_posttraining.sh`）
- 代码组织与可维护性
- 进一步探索方向：MoE、RLHF 新范式、多模态

---

## 附录

- **A.** 数学基础：Softmax、Cross-Entropy、KL 散度
- **B.** PyTorch 基础速查
- **C.** 全部 CLI 命令速查表
- **D.** 配置文件完整参考
- **E.** 术语表

---

## 全书规格

- **章节**：23 章 + 5 个附录
- **字数**：约 15-18 万字
- **每章包含**：
  - 原理图解（Mermaid 流程图）
  - 核心代码片段（从项目中提取）
  - 真实训练输出示例
  - 本章小结与练习

---
