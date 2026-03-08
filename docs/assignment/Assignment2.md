# CS336 Spring 2024 Assignment 2: Systems and Parallelism - 详细总结

## 1. 作业概览 (Assignment Overview)

### 1.1 核心目标
本作业旨在让学生**亲手优化单 GPU 训练速度**并**将训练扩展至多 GPU 环境**。通过从零实现关键系统组件，深入理解大语言模型（LLM）训练背后的系统工程原理，包括性能分析、自定义 GPU 内核编写、分布式数据并行（DDP）及优化器状态分片。

### 1.2 主要任务模块
1.  **基准测试与性能分析 (Benchmarking & Profiling)**: 构建分析工具，定位模型在时间和内存上的瓶颈。
2.  **融合 RMSNorm Triton 内核 (Fused RMSNorm Triton Kernel)**: 使用 Triton 编写自定义 GPU 内核，优化归一化层性能。
3.  **分布式数据并行训练 (Distributed Data Parallel, DDP)**: 实现从朴素 DDP 到支持梯度通信与计算重叠的高级 DDP。
4.  **优化器状态分片 (Optimizer State Sharding)**: 实现类似 ZeRO-1 的机制，减少多 GPU 训练中的显存冗余。

### 1.3 代码结构
*   `cs336-basics/`: 包含 Assignment 1 的代码，作为本次作业的基线模型。
*   `cs336-systems/`: 学生需在此编写所有新代码（Triton 内核、DDP 包装器、分片优化器等）。
*   `tests/`: 提供单元测试，确保实现正确性。

---

## 2. 单 GPU 性能优化 (Optimizing Single-GPU Performance)

### 2.1 性能分析与基准测试 (Profiling and Benchmarking)
在优化前，必须先定位瓶颈。作业要求实现三种分析路径：
*   **端到端基准测试**: 使用 Python `timeit` 和 `torch.cuda.synchronize()` 精确测量前向/后向传播时间。
    *   **关键点**: 必须执行 Warm-up 步骤以消除 CUDA 初始化开销；必须同步 CUDA 流以避免异步执行导致的计时错误。
*   **PyTorch Profiler**: 使用 `torch.profiler` 生成函数级统计表和火焰图（Flame Graph）。
    *   **分析内容**: 识别耗时最多的 CUDA 内核（通常是 MatMul，但也包括 Norm 和 Softmax）；分析前向、后向及优化器步骤的时间分布。
*   **内存分析 (Memory Profiling)**: 使用 `torch.cuda.memory._record_memory_history` 记录内存分配时间线。
    *   **工具**: 通过 `memory_viz` 可视化内存峰值，区分模型权重、优化器状态、激活值等占用情况。
    *   **混合精度影响**: 分析 FP16/BF16 混合精度训练对显存占用的具体影响。

### 2.2 混合精度训练 (Mixed Precision)
*   **原理**: 利用 Tensor Cores 加速低精度（FP16/BF16）矩阵乘法，同时保留部分操作（如累加、归一化）为 FP32 以保证数值稳定性。
*   **实现**: 使用 `torch.autocast` 上下文管理器。
*   **注意事项**:
    *   **LayerNorm/RMSNorm**: 在 FP16 下可能因动态范围不足导致溢出或精度丢失，通常需保持 FP32 计算；BF16 因动态范围与 FP32 相同，对此类操作更友好。
    *   **Loss Scaling**: 防止 FP16 梯度过小变为零。

### 2.3 编写融合 RMSNorm Triton 内核 (Writing a Fused RMSNorm Kernel)
针对性能分析中发现的归一化层瓶颈，手动编写 Triton 内核进行优化。
*   **前向传播 (Forward Pass)**:
    *   公式：$\text{RMSNorm}(x, g) = \frac{x}{\sqrt{\frac{1}{d}\sum x_i^2 + \epsilon}} \odot g$。
    *   **实现**: 每个 Triton 程序实例处理一行数据，加载输入和权重，计算均方根，归一化并缩放。
*   **后向传播 (Backward Pass)**:
    *   **挑战**: 需要计算关于输入 $x$ 和权重 $g$ 的梯度。
    *   **重计算 (Recomputation)**: 为避免存储中间结果占用显存，在后向传播时重新计算前向过程中的中间变量（如 RMS 值），以计算换存储，提升整体效率。
    *   **JVP 推导**: 手动推导雅可比向量积（Jacobian-Vector Product），将其转化为高效的 Triton 核操作。
*   **性能对比**: 对比纯 PyTorch 实现、PyTorch 原生 LayerNorm 以及 Triton 融合内核的速度差异。通常 Triton 实现能显著减少内核启动开销和内存读写次数。

### 2.4 PyTorch JIT 编译器 (PyTorch JIT / torch.compile)
*   **功能**: 利用 PyTorch 2.0+ 的 `torch.compile` 自动融合算子。
*   **实验**: 对比手动编写的 Triton 内核与 `torch.compile` 自动优化的性能。
    *   测试单独编译 RMSNorm 层。
    *   测试编译整个 Transformer 模型。
    *   分析在不同模型规模下的加速比。

---

## 3. 分布式数据并行训练 (Distributed Data Parallel Training)

### 3.1 分布式通信基础 (Distributed Communication Basics)
*   **概念**:
    *   **World Size**: 总进程数。
    *   **Rank**: 进程唯一 ID（Global Rank 和 Local Rank）。
    *   **Backend**: `Gloo` (CPU/通用) vs `NCCL` (GPU 专用，高性能)。
    *   **Collective Operations**: 重点掌握 `all-reduce` (求和/平均)。
*   **单节点 vs 多节点**:
    *   单节点使用 `torch.multiprocessing.spawn`。
    *   多节点通常配合 Slurm 调度系统，通过 `srun` 启动，需正确设置 `MASTER_ADDR` 和 `MASTER_PORT`。
*   **基准测试最佳实践**: 多轮 Warm-up、同步 CUDA、多 Rank 结果聚合。

### 3.2 朴素 DDP 实现 (Naïve DDP Implementation)
*   **流程**:
    1.  **广播权重**: Rank 0 将模型参数广播给其他 Rank。
    2.  **数据分片**: 每个 Rank 处理 Batch 的一部分。
    3.  **独立计算**: 各 Rank 独立进行前向和后向传播，计算局部梯度。
    4.  **梯度同步**: 对每个参数张量单独执行 `all-reduce` 操作，平均梯度。
    5.  **优化器步**: 各 Rank 使用平均后的梯度更新本地参数。
*   **局限性**:
    *   **通信开销大**: 每个参数一次通信调用，启动延迟高。
    *   **无重叠**: 必须等待整个后向传播完成后才开始通信，计算与通信串行。

### 3.3 改进 DDP 实现 (Improving DDP)
针对朴素实现的局限，逐步优化：

#### 3.3.1 梯度扁平化 (Gradient Flattening / Bucketing)
*   **策略**: 将所有参数的梯度拼接（flatten）成一个大张量，执行**单次** `all-reduce`。
*   **效果**: 大幅减少通信调用次数，降低延迟开销。

#### 3.3.2 计算与通信重叠 (Overlapping Computation and Communication)
*   **策略**: 利用后向传播逐层计算梯度的特性。
    *   注册 `register_post_accumulate_grad_hook`。
    *   一旦某层梯度计算完成，立即发起**异步** `all-reduce` (`async_op=True`)。
    *   继续计算剩余层的梯度，同时后台进行通信。
    *   在 `optimizer.step()` 前调用 `wait()` 确保所有通信完成。
*   **效果**: 隐藏通信延迟，缩短单步训练时间。

#### 3.3.3 分桶重叠 (Bucketed Overlapping)
*   **策略**: 结合上述两者。将参数分组为多个“桶”（Buckets），每个桶大小固定（如 25MB）。
    *   当桶内所有参数的梯度就绪时，对该桶执行异步 `all-reduce`。
*   **权衡**: 桶太小 -> 通信调用过多；桶太大 -> 重叠效果变差（需等待更多梯度）。需通过实验寻找最优桶大小。
*   **理论建模**: 建立通信开销模型 $T_{overhead} = n_b \cdot o + \frac{S}{w}$，推导最优桶大小公式。

---

## 4. 优化器状态分片 (Optimizer State Sharding)

### 4.1 背景与动机
*   **问题**: 标准 DDP 中，每个 Rank 都保存完整的模型参数和优化器状态（如 AdamW 需要保存动量和方差，占用参数量 2 倍的显存）。对于大模型，这限制了可训练的模型规模。
*   **目标**: 参考 **ZeRO Stage 1** 思想，分片优化器状态，减少单卡显存占用。

### 4.2 实现细节
*   **分片策略**:
    *   将模型参数划分为 $N$ 份（$N$ = World Size）。
    *   每个 Rank 的优化器实例仅维护属于自己分片的参数状态（动量、方差）。
*   **训练流程修改**:
    1.  **梯度同步**: 同 DDP，所有 Rank 拥有完整的平均梯度。
    2.  **优化器步**: 每个 Rank 仅更新自己负责的那部分参数。
    3.  **参数同步**: 更新完成后，各 Rank 将自己更新的参数分片**广播** (Broadcast) 或 **All-Gather** 给其他 Rank，确保所有 Rank 的模型参数保持一致。
*   **收益**: 显存占用显著降低（优化器状态减少为原来的 $1/N$），但增加了参数同步的通信开销。

### 4.3 实验与分析
*   **显存分析**: 对比开启/关闭分片前后的峰值显存，验证理论节省量。
*   **速度分析**: 测量因额外参数同步带来的时间开销，评估在不同网络带宽（单节点 NVLink vs 多节点以太网/InfiniBand）下的性能影响。
*   **与 ZeRO-1 对比**: 分析实现差异（如通信时机、分片粒度）。

---

## 5. 实验与消融研究 (Experiments & Analysis)

### 5.1 模型规格
作业定义了从小型到 2.7B 参数的多种模型配置（Small, Medium, Large, XL, 2.7B），用于测试不同规模下的扩展性。

### 5.2 关键实验任务
1.  **基准测试对比**:
    *   纯 PyTorch vs Triton vs `torch.compile` 的 RMSNorm 性能。
    *   不同混合精度策略（FP16 vs BF16）的稳定性与速度。
2.  **分布式扩展性**:
    *   单节点多卡 vs 多节点多卡的 `all-reduce` 延迟。
    *   朴素 DDP vs 扁平化 DDP vs 重叠 DDP vs 分桶 DDP 的训练吞吐量。
3.  **显存优化**:
    *   优化器分片前后的显存峰值对比。
    *   分片带来的通信开销占比分析。
4.  **可视化分析**:
    *   提交 PyTorch Profiler 生成的火焰图和 Chrome Trace，直观展示计算与通信的重叠效果。
    *   提交内存时间线图，分析显存分配模式。

---

## 6. 提交要求 (Deliverables)

### 6.1 代码 (`code.zip`)
*   `cs336_systems/`: 包含所有实现的核心模块。
    *   Triton 内核 (RMSNorm forward/backward)。
    *   DDP 包装器 (支持重叠、分桶)。
    *   分片优化器包装器。
    *   基准测试与分析脚本。
*   必须通过所有提供的单元测试 (`pytest`)。

### 6.2 报告 (`writeup.pdf`)
*   **理论推导**: RMSNorm 的梯度推导、通信开销数学建模。
*   **实验结果**:
    *   表格与图表：展示不同优化策略下的时间、显存数据。
    *   截图：火焰图、Chrome Trace（证明重叠效果）、内存时间线。
*   **分析与讨论**:
    *   解释实验现象（如为什么某些设置下重叠无效？桶大小如何影响性能？）。
    *   对比不同后端（Gloo vs NCCL）的表现。
    *   总结优化器分片的优缺点及适用场景。

---

## 7. 注意事项与资源提示

### 7.1 开发环境
*   **依赖**: 需安装 `triton`, `torch`, `numpy`, `matplotlib` 等。
*   **硬件**: 推荐使用带有 NVIDIA GPU 的机器（支持 NCCL）。若无多卡环境，可使用单卡模拟多进程（需注意性能差异）或利用学校集群/云资源。
*   **Slurm**: 多节点实验需熟悉 Slurm 脚本编写 (`sbatch`, `srun`)。

### 7.2 调试技巧
*   ** correctness first**: 先确保逻辑正确（通过单元测试），再追求性能。使用小模型、小数据量进行快速验证。
*   **确定性**: 分布式调试时，注意随机种子的设置，确保多 Rank 间结果可比。
*   **异步陷阱**: 在使用异步通信时，务必确保在需要使用梯度前调用 `wait()`，否则会导致数据未就绪错误。

### 7.3 评分重点
*   **代码正确性**: 是否通过所有测试用例。
*   **性能提升**: 优化策略是否有效提升了训练速度或降低了显存占用。
*   **深度分析**: 报告是否深入理解了系统瓶颈，并能合理解释实验数据。
*   **工程规范**: 代码结构清晰，注释完整，复现性强。

> **注**: 本作业是连接深度学习算法与系统工程的桥梁。通过亲手实现这些底层机制，学生将具备训练大规模模型所需的系统设计与调优能力，为后续研究或工业界应用打下坚实基础。
