# CS336 Spring 2025 Assignment 1: Building a Transformer LM (Basics) - 详细总结

## 1. 作业概览 (Assignment Overview)

### 1.1 核心目标
本作业要求学生**从零开始构建并训练一个标准的 Decoder-only Transformer 语言模型**。严禁直接使用 `torch.nn`、`torch.nn.functional` 或 `torch.optim` 中的现成实现（仅允许使用容器类如 `Module`, `Parameter` 等），旨在深入理解大语言模型（LLM）的底层原理。

### 1.2 主要任务模块
1.  **BPE Tokenizer**: 实现字节级 Byte-Pair Encoding (BPE) 分词器。
2.  **Transformer LM**: 构建包含 RMSNorm, SwiGLU, RoPE 等现代组件的 Transformer 架构。
3.  **损失函数与优化器**: 手动实现交叉熵损失函数 (Cross-Entropy Loss) 和 AdamW 优化器。
4.  **训练基础设施**: 编写完整的训练循环，支持数据加载、检查点保存/加载、学习率调度及梯度裁剪。
5.  **文本生成**: 实现基于 Temperature 和 Top-p 采样的解码器。

### 1.3 实验流程
*   **数据集**: 使用 **TinyStories** (小型、干净) 进行快速迭代和调试；使用 **OpenWebText** (大型、嘈杂) 进行最终评估和排行榜挑战。
*   **流程**: 训练 BPE 分词器 -> 转换数据集为 ID 序列 -> 训练 Transformer LM -> 生成文本并评估困惑度 (Perplexity)。

---

## 2. 核心技术实现细节

### 2.1 字节级 BPE 分词器 (Byte-Pair Encoding Tokenizer)
*   **原理**: 将 Unicode 字符串转换为 UTF-8 字节序列（初始词汇表为 256 个字节）。通过迭代合并出现频率最高的字节对来构建子词词汇表。
*   **关键步骤**:
    *   **Unicode 编码**: 使用 UTF-8 而非 UTF-16/32，以平衡词汇表大小和序列长度，避免 OOV (Out-of-Vocabulary) 问题。
    *   **预处理 (Pre-tokenization)**: 使用正则表达式（类似 GPT-2 的模式）将文本粗粒度分割，避免跨标点符号合并，提高计数效率。
    *   **合并算法**: 统计字节对频率，按顺序合并频率最高的一对（若频率相同，取字典序较大者），直到达到指定词汇表大小。
    *   **特殊令牌 (Special Tokens)**: 处理如 `<|endoftext|>` 等标记，确保其不被拆分且作为独立 token 存在。
*   **编码/解码**:
    *   **Encode**: 预处理 -> 应用合并规则 -> 输出 ID 序列。支持流式处理大文件 (`encode_iterable`)。
    *   **Decode**: ID 查表 -> 拼接字节 -> 解码为 Unicode 字符串（处理非法字节替换）。

### 2.2 Transformer 架构 (Transformer Architecture)
采用 **Pre-norm** 结构的 Decoder-only Transformer，包含以下现代组件：

#### 基础组件
*   **Linear & Embedding**: 手动实现线性层和嵌入层。
    *   **初始化**: 权重使用截断正态分布 `N(0, σ²)`，其中 Linear 的 $σ = \sqrt{2/(d_{in} + d_{out})}$，Embedding 的 $σ = 1$。
*   **RMSNorm (Root Mean Square Layer Normalization)**:
    *   替代传统 LayerNorm，公式：$\text{RMSNorm}(a_i) = \frac{a_i}{\text{RMS}(a)} g_i$。
    *   **数值稳定**: 计算时需将输入上cast至 `float32` 防止溢出。
*   **SwiGLU (Feed-Forward Network)**:
    *   结合 SiLU (Swish) 激活函数和门控线性单元 (GLU)。
    *   公式：$\text{FFN}(x) = W_2 (\text{SiLU}(W_1 x) \odot W_3 x)$。
    *   **维度**: 内部维度 $d_{ff} \approx \frac{8}{3} d_{model}$ (需为 64 的倍数)。
*   **RoPE (Rotary Positional Embeddings)**:
    *   通过旋转矩阵注入位置信息，作用于 Query 和 Key 向量。
    *   **实现**: 预计算 $\sin/\cos$ 缓冲值，利用复数旋转性质高效实现，无学习参数。

#### 注意力机制
*   **Scaled Dot-Product Attention**:
    *   实现数值稳定的 Softmax (减去最大值)。
    *   支持 **Masking**: 通过添加 $-\infty$ 屏蔽不需要关注的位置。
*   **Causal Multi-Head Self-Attention**:
    *   实现因果掩码 (Causal Mask)，防止关注未来 token。
    *   **多头机制**: 将 $d_{model}$ 分割为 $h$ 个头，独立计算后拼接。
    *   **RoPE 应用**: 在每个头上独立应用相同的旋转操作。

#### 整体结构
*   **Pre-norm Block**: $x \leftarrow x + \text{SubLayer}(\text{RMSNorm}(x))$。
*   **输出层**: 输入嵌入 -> $N$ 个 Transformer Block -> 最终 RMSNorm -> 线性投影 (LM Head) -> Logits。

### 2.3 训练基础设施 (Training Infrastructure)
*   **损失函数**:
    *   **Cross-Entropy**: 实现数值稳定的交叉熵损失，直接计算 $-\log(\text{softmax}(logits)[target])$，避免显式计算 softmax。
    *   **困惑度 (Perplexity)**: $PPL = \exp(\text{mean\_loss})$。
*   **优化器 (AdamW)**:
    *   实现动量估计 ($m_t, v_t$) 和偏差修正。
    *   **解耦权重衰减 (Decoupled Weight Decay)**: 在梯度更新后单独应用权重衰减。
*   **学习率调度 (LR Scheduler)**:
    *   **Cosine Annealing with Warmup**: 线性热身至 $α_{max}$，随后余弦退火至 $α_{min}$。
*   **梯度裁剪 (Gradient Clipping)**:
    *   限制梯度的 $\ell_2$ 范数，防止梯度爆炸。
*   **数据加载**:
    *   使用 `np.memmap` 高效加载大规模数据集，支持随机采样 batch。
    *   数据格式：连续 token 序列，滑动窗口构建 `(input, target)` 对。
*   **检查点 (Checkpointing)**:
    *   保存/加载模型状态 (`state_dict`)、优化器状态及当前步数，支持断点续训。

### 2.4 文本生成 (Text Generation)
*   **解码策略**:
    *   **Temperature Scaling**: 调整概率分布的平滑度 ($\tau \to 0$ 趋向贪婪搜索)。
    *   **Top-p (Nucleus) Sampling**: 动态截断低概率词，保留累积概率 $p$ 的最小词集。
*   **流程**: 输入 Prompt -> 模型预测 -> 采样下一个 token -> 追加到输入 -> 循环直到 `<|endoftext|>` 或达到最大长度。

---

## 3. 实验与消融研究 (Experiments & Ablations)

### 3.1 超参数调优
*   **学习率**: 寻找“稳定性边缘”的最佳学习率。观察过大学习率导致的发散现象。
*   **批次大小 (Batch Size)**: 测试从 1 到显存上限的不同 batch size，分析其对训练效率和收敛性的影响。
*   **资源估算**: 计算模型的参数量、显存占用 (Parameters, Activations, Gradients, Optimizer State) 及 FLOPs。

### 3.2 架构消融实验
学生需修改架构并对比效果（需在 TinyStories 上验证）：
1.  **移除 RMSNorm**: 验证层归一化对训练稳定性的必要性（通常会导致发散或极难训练）。
2.  **Post-norm vs Pre-norm**: 对比归一化位置，验证 Pre-norm 在深层网络中的优势。
3.  **NoPE (无位置编码)**: 移除 RoPE，验证 Decoder-only 架构是否能隐式学习位置信息（通常性能下降）。
4.  **SwiGLU vs SiLU**: 对比带门控 (SwiGLU) 和不带门控 (SiLU) 的激活函数性能，需匹配参数量。

### 3.3 数据集对比
*   **TinyStories**: 用于快速验证架构正确性和超参数敏感性。
*   **OpenWebText**: 用于评估模型在真实嘈杂数据上的泛化能力。对比两者在相同计算预算下的 Loss 和生成质量。

### 3.4 排行榜挑战 (Leaderboard)
*   **目标**: 在 **1.5 小时 (H100 GPU)** 的限制内，在 OpenWebText 上获得最低的验证损失。
*   **策略**: 鼓励尝试权重绑定 (Weight Tying)、架构微调、更高效的实现等创新方法。
*   **基线**: 需击败 Loss 5.0 的朴素基线。

---

## 4. 提交要求 (Deliverables)

### 4.1 代码 (`code.zip`)
*   包含所有从头实现的模块：
    *   `cs336_basics/`: 用户编写的核心逻辑。
    *   `adapters.py`: 适配层（仅调用用户代码，无实质逻辑）。
    *   必须通过所有提供的 `test_*.py` 单元测试。

### 4.2 报告 (`writeup.pdf`)
*   **理论问题**: 回答关于 Unicode 编码、FLOPs 计算、资源估算等书面问题。
*   **实验结果**:
    *   展示学习曲线 (Loss vs Steps/Time)。
    *   提供生成的文本样本。
    *   分析消融实验的结果和发现（如：为什么移除 Norm 会导致发散？）。
*   **实验日志**: 记录所有尝试过的超参数配置和对应的结果。

### 4.3 排行榜提交 (可选但推荐)
*   提交最佳模型的验证损失至 GitHub 排行榜仓库。

---

## 5. 注意事项与资源提示

### 5.1 AI 工具使用政策
*   **允许**: 使用 LLM 解答概念性问题或低级编程错误。
*   **禁止**: 直接让 AI 生成解决方案代码。
*   **建议**: 关闭 IDE 的 AI 自动补全功能，以加深对相关内容的理解。

### 5.2 低资源环境支持
*   **Apple Silicon / CPU**: 提供了降维运行指南（如减小数据集、模型尺寸），确保无高端 GPU 也能完成作业。
    *   TinyStories 训练可在 M3 Max 上约 30-40 分钟完成。
    *   建议使用 `torch.compile` 加速 (CPU/MPS)。
*   **调试技巧**:
    *   **Overfitting**: 先尝试在单个 mini-batch 上过拟合，验证代码逻辑正确性。
    *   **形状检查**: 使用断点检查中间张量的形状是否符合预期。
    *   **数值监控**: 监控激活值、权重和梯度的范数，防止爆炸或消失。

### 5.3 效率优化
*   **Einsum/Einops**: 强烈建议使用 `einsum`  notation 或 `einops` 库进行张量操作，以提高代码可读性和执行效率。
*   **Profiling**: 使用 `cProfile` 或 `scalene` 定位瓶颈（通常是 Pre-tokenization 或数据加载阶段）。
*   **并行化**: BPE 训练中的 Pre-tokenization 步骤可使用 `multiprocessing` 并行加速。

---

## 6. 评分标准概览
*   **代码实现**: 各模块功能正确性 (Tokenizer, Model, Optimizer, etc.) - 占比最大。
*   **实验分析**: 消融实验的深度、图表质量及结论的合理性。
*   **理论问答**: 对 Unicode, FLOPs, 资源估算等问题的回答准确性。
*   **排行榜表现**: (额外加分项) 在限定时间内达到的最低 Loss。

> **注**: 本作业不仅考察编程能力，更强调对 Transformer 架构设计选择（如 Pre-norm, RoPE, SwiGLU）背后原理的深刻理解。通过亲手复现，学生将掌握大模型训练的全流程技术栈。
