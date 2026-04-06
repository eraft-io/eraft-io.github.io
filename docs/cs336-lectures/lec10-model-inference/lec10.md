## 模型推理简介
本次讲座标志着课程重点从缩放定律(Scaling Laws)正式转向模型推理(Model Inference)这一核心主题。推理旨在解决一个明确的问题：在给定固定预训练模型(Pre-trained Model)的前提下，我们如何针对用户的提示词(Prompt)生成准确的回复？尽管推理是一项技术性极强的课题，且为今年课程新增内容，但它却是理解大语言模型(Large Language Models, LLMs)运作的基石。它远不止于部署一个简单的聊天机器人(Chatbot)演示；相反，它是支撑现代 AI 系统核心运转功能的基础。

![关键帧](keyframes/part000_frame_00000000.jpg)
![关键帧](keyframes/part000_frame_00006600.jpg)
![关键帧](keyframes/part000_frame_00014766.jpg)

## 推理的广泛应用
模型推理贯穿于 AI 部署与开发的众多环节。最直观的应用包括交互式聊天界面以及 Cursor 等实时代码补全工具。除直接的用户交互外，推理对于批量数据处理流水线(Data Processing Pipelines)、模型评估基准测试(Model Evaluation Benchmarks，例如衡量指令遵循能力(Instruction Following))，以及测试时计算(Test-Time Compute)等新兴范式都至关重要。在测试时计算中，模型会在输出最终答案前生成推理词元(Reasoning Tokens)，从而进行更长时间的“思考”。此外，推理本身也是模型训练过程中的关键环节，尤其是在强化学习(Reinforcement Learning)流程中，系统需根据奖励信号(Reward Signal)对模型的响应进行采样与评估。

![关键帧](keyframes/part000_frame_00054766.jpg)
![关键帧](keyframes/part000_frame_00086300.jpg)

## 规模、成本与性能指标
推理效率的重要性源于其高频、反复执行的特性。训练通常属于一次性计算成本(One-time Computational Cost)，而推理操作则需要在大规模用户请求下持续运行。现实世界的数据凸显了这一需求：据报道，OpenAI 等平台每日处理数千亿个词元(Tokens)，而编程辅助工具每日生成的被采纳代码行数高达数十亿行。衡量推理性能通常依赖三个关键指标：首词元延迟(Time to First Token, TTFT)，它决定了交互式应用的初始响应时间；生成延迟(Generation Latency)，用于追踪后续词元的生成速度；以及吞吐量(Throughput)，即系统每秒为所有用户生成的词元总数，该指标对批量处理尤为关键。需注意的是，高吞吐量并不等同于低延迟，因为延迟往往反映的是单个用户所经历的最坏情况等待时间。

![关键帧](keyframes/part000_frame_00154133.jpg)
![关键帧](keyframes/part000_frame_00163233.jpg)
![关键帧](keyframes/part000_frame_00187366.jpg)
![关键帧](keyframes/part000_frame_00208333.jpg)

## 顺序工作负载的挑战
与模型训练相比，推理优化带来了独特的底层架构挑战。在训练阶段，模型能够访问完整的词元序列，从而在时间步(Timesteps)上实现大规模并行计算(Massive Parallelization)。相比之下，推理本质上是自回归的(Autoregressive)：每个新生成的词元都依赖于此前生成的所有词元，这迫使计算过程必须严格串行执行。这种串行依赖性使得充分利用现有硬件算力变得异常困难，导致推理工作负载通常高度受限于内存带宽(Memory-bound)。认识到这些瓶颈后，无论是闭源还是开源模型提供商，均在推理优化工程上投入了大量资源；相比之下，学术界对此方向的关注相对较少，因为学术研究的重心往往更侧重于模型训练与基准测试得分，而非生产环境下的服务部署(Serving Deployment)。

![关键帧](keyframes/part000_frame_00318133.jpg)
![关键帧](keyframes/part000_frame_00332833.jpg)
![关键帧](keyframes/part000_frame_00352866.jpg)

## 数学基础与计算强度
为了量化推理工作负载(Inference Workload)，我们需要深入考察底层 Transformer 架构的数学原理。关键参数包括批次大小(Batch Size, $B$)、序列长度(Sequence Length, $T$)、提示词长度(Prompt Length, $A$)、模型维度(Model Dimension, $D$)、词表大小(Vocabulary Size, $V$)以及多层感知机隐藏层维度(MLP Hidden Dimension, $F$)。其计算图(Computational Graph)通过查询-键-值投影(QKV Projections)、注意力机制(Attention Mechanism)和 MLP 层对输入进行处理。一次标准的前向传播(Forward Pass)所需的浮点运算次数(Floating Point Operations, FLOPs)约为 $6 \times$ 参数量 $\times$ 词元数。此外，注意力机制还会引入与序列长度平方($T^2$)成正比的额外计算依赖。 

![关键帧](keyframes/part000_frame_00371733.jpg)
![关键帧](keyframes/part000_frame_00380099.jpg)
![关键帧](keyframes/part000_frame_00385966.jpg)
![关键帧](keyframes/part000_frame_00395966.jpg)

要判定工作负载属于计算受限(Compute-bound)还是访存受限(Memory-bound)，我们需要计算计算强度(Arithmetic Intensity)，即总 FLOPs 与在高带宽内存(High Bandwidth Memory, HBM)与计算单元之间传输的字节数之比。以形状为 $B \times D$ 的输入矩阵 $X$ 和形状为 $D \times F$ 的权重矩阵 $W$ 的标准矩阵乘法(Matrix Multiplication)为例，系统必须先从内存中读取这两个矩阵，执行乘加运算，再将结果写回内存。总内存访问量(Memory Traffic)与 $2(BD + DF + BF)$ 字节成正比（假设采用 BF16 精度(BF16 Precision)），而计算产生的 FLOPs 为 $2BDF$。因此，计算强度为 $\frac{2BDF}{2(BD + DF + BF)}$。深入理解该比率至关重要，因为它直接决定了推理过程中的硬件利用率究竟是受限于计算吞吐量(Compute Throughput)还是内存带宽(Memory Bandwidth)。

![关键帧](keyframes/part000_frame_00471700.jpg)
![关键帧](keyframes/part000_frame_00499833.jpg)
![关键帧](keyframes/part000_frame_00512800.jpg)
![关键帧](keyframes/part000_frame_00541333.jpg)
![关键帧](keyframes/part000_frame_00571633.jpg)
![关键帧](keyframes/part000_frame_00589900.jpg)
![关键帧](keyframes/part000_frame_00597600.jpg)

---

## 计算强度与硬件极限
在矩阵乘法工作负载中，批次大小(Batch Size, `B`)通常远小于模型维度(Model Dimension, `D`)和多层感知机隐藏层维度(MLP Hidden Dimension, `F`)。通过渐近分析(Asymptotic Analysis)，计算强度(Arithmetic Intensity)可近似简化为 `B`。该指标表示系统每从内存传输一个字节所执行的浮点运算次数(Floating Point Operations, FLOPs)。为评估硬件利用率，我们将该值与**加速器强度(Accelerator Intensity)**进行对比，后者通过将 GPU 的峰值浮点运算能力(Peak FLOPS)除以其内存带宽(Memory Bandwidth)计算得出。以 NVIDIA H100 为例（约 989 TFLOPS / 约 3.35 TB/s），该阈值约为 295。当批次大小超过 295 时，工作负载处于计算受限(Compute-bound)状态，可高效饱和 GPU 的计算单元；若低于该阈值，操作则转为访存受限(Memory-bound)状态，导致计算单元利用率低下。

![关键帧](keyframes/part001_frame_00000000.jpg)
![关键帧](keyframes/part001_frame_00044466.jpg)
![关键帧](keyframes/part001_frame_00060566.jpg)
![关键帧](keyframes/part001_frame_00077566.jpg)

## 单序列生成的访存受限挑战
在顺序生成词元(Token)时，有效批次大小为 `B=1`，这使得计算退化为矩阵-向量乘法(Matrix-Vector Multiplication, GEMV)。在此场景下，计算强度骤降至约 1，效率极低。由于浮点运算量与内存读取量的比值接近 1:1，系统大部分时间均消耗于从内存中加载权重参数，而非执行实际计算。这一根本性瓶颈解释了为何自回归生成(Autoregressive Generation)天生受限于内存带宽，且其生成速度远低于并行训练(Parallel Training)。尽管通过对多请求进行批处理(Batching)可缓解该问题，但实时交互式应用通常仅能以极小的批次大小运行，迫使硬件在远低于其理论算力上限的状态下工作。

![关键帧](keyframes/part001_frame_00113266.jpg)
![关键帧](keyframes/part001_frame_00134933.jpg)
![关键帧](keyframes/part001_frame_00208199.jpg)

## 通过 KV 缓存克服冗余计算
一种朴素的词元生成方法是，在每一步都将完整提示词(Prompt)与所有已生成的词元重新输入 Transformer 模型，这将导致 $O(T^2)$ 的计算复杂度。然而，此举会在每一步重复计算相同的前缀序列。在因果自回归 Transformer(Causal Autoregressive Transformer)中，历史上下文(Historical Context)始终保持不变。业界的标准化优化方案是采用 **KV 缓存(KV Cache)**：将提示词编码阶段计算得到的键(Key)与值(Value)向量预先存储在高带宽内存(High Bandwidth Memory, HBM)中。通过复用这些缓存向量，并仅针对新生成的词元计算注意力机制(Attention Mechanism)，单步生成的计算复杂度得以从 $O(T^2)$ 降至 $O(T)$，从而大幅削减了冗余的浮点运算量。

![关键帧](keyframes/part001_frame_00218299.jpg)
![关键帧](keyframes/part001_frame_00236933.jpg)
![关键帧](keyframes/part001_frame_00242333.jpg)
![关键帧](keyframes/part001_frame_00262533.jpg)
![关键帧](keyframes/part001_frame_00270000.jpg)

## 推理的两个阶段：预填充与生成
Transformer 推理过程可划分为两个截然不同的阶段。**预填充阶段(Prefill Phase)**负责一次性处理完整的输入提示词。由于此时全序列数据已就绪，计算可高度并行化且通常处于计算受限(Compute-bound)状态，因此该阶段执行迅速且高效。随后进入**解码生成阶段(Generation/Decoding Phase)**，模型逐个输出回复词元。在此阶段，工作负载高度依赖 KV 缓存且必须串行执行。受限于单词元生成的 `B=1` 特性以及模型权重的持续重载，该阶段严格受限于内存带宽。此外，KV 缓存的显存占用随批次大小、序列长度、网络层数(Layers)、注意力头数(Attention Heads)及头维度(Head Dimension)呈显著增长，因此需要精细的内存管理策略以避免发生内存溢出(Out of Memory, OOM)错误。

![关键帧](keyframes/part001_frame_00311233.jpg)
![关键帧](keyframes/part001_frame_00335233.jpg)

## Transformer 中 FLOPs 与内存 I/O 的量化
为精确评估推理效率，需逐一追踪 Transformer 各子模块的浮点运算次数(FLOPs)与内存数据传输量，通常将多层感知机层(MLP Layer)与注意力层(Attention Layer)分开建模计算。设定 `S` 表示上下文/提示词长度，`T` 表示生成/查询长度，我们即可对张量形状(Tensor Shapes)与数据搬运(Data Movement)进行精确建模。以 MLP 层为例，输入张量(`B × T × D`)及权重矩阵（包括上投影层(Up-projection)、门控层(Gate)与下投影层(Down-projection)）均需从 HBM 中读取，计算时需采用 BF16 精度(BF16 Precision，即每个元素占 2 字节)。每次矩阵乘法产生的 FLOPs 均与 `B × T × D × F` 成正比，且在应用非线性激活函数(Non-linear Activation Function)前，中间激活值(Intermediate Activations)通常需写回内存。这种细粒度的资源核算(Fine-grained Accounting)对于准确预测推理延迟以及优化生成阶段的硬件利用率至关重要。

![关键帧](keyframes/part001_frame_00362399.jpg)
![关键帧](keyframes/part001_frame_00372733.jpg)
![关键帧](keyframes/part001_frame_00432566.jpg)
![关键帧](keyframes/part001_frame_00449599.jpg)
![关键帧](keyframes/part001_frame_00473433.jpg)
![关键帧](keyframes/part001_frame_00516366.jpg)
![关键帧](keyframes/part001_frame_00525466.jpg)
![关键帧](keyframes/part001_frame_00540000.jpg)
![关键帧](keyframes/part001_frame_00572266.jpg)
![关键帧](keyframes/part001_frame_00593533.jpg)

---

## MLP 计算强度与批次扩展
多层感知机层(MLP Layer)中的下投影(Down-projection)步骤需要 $B \times T \times D \times F$ 次浮点运算(Floating Point Operations, FLOPs)，其计算规模与上投影(Up-projection)和门控投影(Gate projection)相当。在标准假设 $B \times D \ll D \times F$ 下，计算强度(Arithmetic Intensity)可近似简化为 $B \times T$。该指标直接决定了硬件利用率(Hardware Utilization)：强度越高，意味着每从内存传输一个字节所执行的计算量越大。在**预填充阶段(Prefill Phase)**，$T$（序列长度 Sequence Length）较大，自然会将工作负载推向计算受限(Compute-bound)状态，此时 GPU 能够高效运行。然而，在**生成阶段(Generation Phase)**，由于词元(Token)是顺序生成的，因此 $T=1$。这使得计算强度骤降至仅剩 $B$，意味着系统效率完全取决于批次大小(Batch Size)，即并发请求的数量。若缺乏充分的批处理(Batching)，硬件仍将处于利用率不足的状态，这凸显了请求延迟(Request Latency)与系统吞吐量(System Throughput)之间的根本性权衡。

![关键帧](keyframes/part002_frame_00000000.jpg)
![关键帧](keyframes/part002_frame_00013066.jpg)
![关键帧](keyframes/part002_frame_00021133.jpg)
![关键帧](keyframes/part002_frame_00032600.jpg)
![关键帧](keyframes/part002_frame_00059333.jpg)

## 注意力计算强度与生成瓶颈
注意力层(Attention Layer)带来了更为严峻的效率挑战。综合考量查询-键-值(QKV)矩阵的读取、核心的 $Q \times K$ 与注意力-V(Attention-V)乘法运算，以及相应的内存数据传输（在渐近分析 Asymptotic Analysis 中忽略 Flash Attention 的常数项优化），计算强度可简化为 $\frac{S \times T}{S + T}$。其中，$S$ 代表上下文/前缀长度(Context/Prefix Length)，$T$ 代表生成长度(Generation Length)。在**预填充阶段**（$T=S$），计算强度随序列长度线性增长（$\sim S$），从而使计算过程保持在计算受限状态。而在**生成阶段**（$T=1$），该公式退化为 $\frac{S}{S+1} \approx 1$。该状态极其低效，因为它表明系统每从内存传输一个字节仅执行约一次浮点运算。这也意味着，无论输入提示词(Prompt)有多长，注意力机制都严格受限于内存带宽(Memory-bound)。

![关键帧](keyframes/part002_frame_00089033.jpg)
![关键帧](keyframes/part002_frame_00126400.jpg)
![关键帧](keyframes/part002_frame_00133799.jpg)
![关键帧](keyframes/part002_frame_00143399.jpg)

## 为何批处理无法提升注意力效率
多层感知机层与注意力层之间存在一个关键区别：注意力的计算强度**与批次大小 $B$ 完全无关**。从数学推导上看，$B$ 同时出现在浮点运算计数(FLOPs Count)与内存传输量(Memory Transfer)的计算公式中，导致两者相除时被约去。直观而言，这是因为 MLP 层在所有序列间共享权重(Weight Sharing)，使得批处理请求能够有效分摊内存读取开销(Memory Read Overhead)。相比之下，注意力机制依赖于 KV 缓存(KV Cache)，而该缓存内容对每个序列而言都是独一无二的（即“每个序列都是一片独特的雪花”）。对请求进行批处理并不能降低注意力机制中单个词元的内存开销。这意味着，无论并发工作负载(Concurrent Workload)规模多大，计算强度都顽固地维持在约 1 的水平，系统严格受限于内存带宽。

![关键帧](keyframes/part002_frame_00188299.jpg)
![关键帧](keyframes/part002_frame_00210733.jpg)
![关键帧](keyframes/part002_frame_00217433.jpg)
![关键帧](keyframes/part002_frame_00232133.jpg)
![关键帧](keyframes/part002_frame_00258700.jpg)

## 阶段总结：计算受限与访存受限瓶颈
推理效率可根据处理阶段与网络层类型进行清晰划分：
* **预填充阶段：** 计算受限。MLP 与注意力层均受益于长序列（$T$ 或 $S$），从而实现高度并行化与高效的 GPU 利用率。
* **生成阶段：** 访存受限。MLP 的计算效率随 $B$ 增长（依赖于较大的并发批次），但注意力机制的效率从根本上被限制在约 1。注意力层中这种固有的内存瓶颈决定了自回归词元生成(Autoregressive Token Generation)的极限速度，导致在单 token 解码期间无法完全饱和加速器(Accelerator)的计算单元。

![关键帧](keyframes/part002_frame_00307799.jpg)
![关键帧](keyframes/part002_frame_00326066.jpg)
![关键帧](keyframes/part002_frame_00344400.jpg)
![关键帧](keyframes/part002_frame_00383699.jpg)

## 理论延迟与吞吐量建模：Llama 13B 案例研究
为量化这些理论极限(Theoretical Limits)，我们可以针对具体硬件配置进行粗略估算(Napkin Math)：以在单张 H100 GPU 上运行 Llama 13B 模型为例。假设内存传输与计算能够实现理想重叠(Compute-Memory Overlap，此为一种理想化的理论上限 Theoretical Upper Bound)，我们设定以下基线超参数(Baseline Hyperparameters)：序列长度 $S=1000$，隐藏层维度 $D=5120$，并采用 H100 的标准内存带宽。首先，需根据网络层数、注意力头数及投影维度计算出总参数量(Total Parameter Count)。将该数值乘以 2 字节（对应推理常用的 BF16 精度 BF16 Precision），即可得出模型权重的基线内存占用(Model Weight Memory Footprint)。此项基础核算为推导访存受限生成阶段中单个词元的理论延迟(Theoretical Latency)与系统吞吐量奠定了坚实基础。

![关键帧](keyframes/part002_frame_00405933.jpg)
![关键帧](keyframes/part002_frame_00424399.jpg)
![关键帧](keyframes/part002_frame_00436166.jpg)
![关键帧](keyframes/part002_frame_00462233.jpg)
![关键帧](keyframes/part002_frame_00473033.jpg)
![关键帧](keyframes/part002_frame_00486733.jpg)
![关键帧](keyframes/part002_frame_00512333.jpg)
![关键帧](keyframes/part002_frame_00525233.jpg)
![关键帧](keyframes/part002_frame_00559200.jpg)
![关键帧](keyframes/part002_frame_00566200.jpg)
![关键帧](keyframes/part002_frame_00574900.jpg)

---

## 内存占用：模型参数与 KV 缓存
模型推理(Inference)的内存需求与模型训练(Training)存在根本性差异。由于推理过程无需保留梯度(Gradients)与优化器状态(Optimizer States)，显存主要被静态模型参数(Model Parameters)与动态 KV 缓存(KV Cache)所占据。以 BF16 精度(BF16 Precision)格式存储的参数占用 `num_parameters × 2` 字节。然而，KV 缓存的规模会随上下文长度(Context Length)与并发请求数(Concurrent Requests)的动态增加而显著增长。对于每个序列(Sequence)，系统需在所有 Transformer 层(Transformer Layers)中存储键(Key)与值(Value)的激活值(Activations)，其计算公式为：`sequence_length × num_kv_heads × head_dim × num_layers × 2（对应 K 和 V）× 2（对应 BF16 字节数）`。总内存占用(Total Memory Footprint)等于模型参数大小加上 `batch_size × cache_per_sequence`，这使得内存管理对批次配置(Batch Configuration)极为敏感。

![关键帧](keyframes/part003_frame_00000000.jpg)
![关键帧](keyframes/part003_frame_00008433.jpg)
![关键帧](keyframes/part003_frame_00015433.jpg)
![关键帧](keyframes/part003_frame_00051966.jpg)

## 延迟、吞吐量与批次大小的权衡
由于词元生成(Token Generation)过程严格受限于内存带宽，即处于访存受限(Memory-bound)状态，其延迟(Latency)主要取决于总数据传输量(Total Data Transfer Volume)与 GPU 显存带宽(GPU Memory Bandwidth)的比值。系统吞吐量(Throughput)则近似为单请求延迟的倒数乘以批次大小(Batch Size, `B`)。以在 H100 GPU 上运行 Llama 13B 模型为例：当 `B=1` 时，单词元延迟(Per-Token Latency)约为 8 毫秒，吞吐量约为 124 tokens/秒。当批次大小增至 `B=16` 时，受 KV 缓存开销(Cache Overhead)与串行化处理(Serial Processing)影响，单个请求的延迟会有所上升，但系统总吞吐量将显著提升。若进一步将批次推至 `B=256`，理论吞吐量虽可达峰值，但会立即触及硬件容量瓶颈(Hardware Capacity Limit)：模型参数与 KV 缓存的总占用将超出 H100 的 80GB 显存(VRAM)上限。这揭示了推理系统核心的工程权衡(Engineering Trade-off)：小批次配置旨在优化低延迟，适用于交互式场景(Interactive Workloads)；而大批次配置旨在最大化吞吐量，适用于离线批处理场景(Batch/Offline Workloads)，且其性能上限严格受限于可用显存容量。

![关键帧](keyframes/part003_frame_00090933.jpg)
![关键帧](keyframes/part003_frame_00107766.jpg)
![关键帧](keyframes/part003_frame_00142399.jpg)
![关键帧](keyframes/part003_frame_00149033.jpg)
![关键帧](keyframes/part003_frame_00170333.jpg)
![关键帧](keyframes/part003_frame_00177499.jpg)

## 多 GPU 扩展与首 Token 延迟（TTFT）
与模型训练需采用复杂的并行策略(Parallelization Strategies，如张量并行 Tensor Parallelism、数据并行 Data Parallelism 或流水线并行 Pipeline Parallelism)并承受繁重的同步开销(Synchronization Overhead)不同，跨多 GPU 扩展推理(Multi-GPU Inference Scaling)的逻辑相对直观。只要单张加速卡(Accelerator)能够完整加载模型权重，只需部署 `M` 个独立的模型副本(Model Replicas)即可。由于推理过程中的模型权重是静态的，副本间完全无需跨 GPU 通信(Cross-GPU Communication)。此时，单个请求的延迟保持不变，而系统总吞吐量将与副本数量 `M` 呈线性增长。此外，首词元延迟(Time to First Token, TTFT)主要由预填充阶段(Prefill Phase)决定，该阶段会并行处理整个输入提示词(Prompt)。此阶段通常处于计算受限(Compute-bound)状态，对内存带宽的敏感度较低；但需注意，过大的批次大小仍可能在进入预填充计算前引入显著的排队延迟(Queueing Latency)。

![关键帧](keyframes/part003_frame_00232166.jpg)
![关键帧](keyframes/part003_frame_00243799.jpg)
![关键帧](keyframes/part003_frame_00297433.jpg)

## 架构优化：攻克 KV 缓存瓶颈
自回归生成(Autoregressive Generation)的根本瓶颈在于内存带宽，而庞大的 KV 缓存进一步加剧了该问题。尽管系统级优化(System-level Optimizations，如自定义计算内核 Kernels 与连续批处理 Continuous Batching)能带来一定性能增益，但最具变革性的突破仍源于模型架构层面的改进(Architectural Improvements)。这类改进旨在不显著牺牲模型质量(Model Quality)的前提下，大幅削减内存数据传输量(Memory Transfer Volume)。这一工程现实直接塑造了现代大语言模型(Large Language Models, LLMs)的演进方向。传统标准的多头注意力机制(Multi-Head Attention, MHA)维持查询(Query)、键(Key)与值(Value)注意力头(Attention Heads) 1:1 的比例，导致 KV 缓存占用达到峰值。为缓解此问题，业界相继引入了多查询注意力(Multi-Query Attention, MQA)，使所有 Query 头共享单一组 KV 头；以及分组查询注意力(Grouped-Query Attention, GQA)，将多个 Query 头划分为若干组以共享少量的 KV 头。这些架构调整大幅降低了 KV 缓存的显存需求，直接打破了访存受限(Memory-bound)瓶颈，从而显著提升了词元生成(Token Generation)的吞吐速率。

![关键帧](keyframes/part003_frame_00316400.jpg)
![关键帧](keyframes/part003_frame_00348399.jpg)
![关键帧](keyframes/part003_frame_00373466.jpg)
![关键帧](keyframes/part003_frame_00415000.jpg)
![关键帧](keyframes/part003_frame_00437266.jpg)
![关键帧](keyframes/part003_frame_00456233.jpg)
![关键帧](keyframes/part003_frame_00541866.jpg)
![关键帧](keyframes/part003_frame_00560266.jpg)
![关键帧](keyframes/part003_frame_00575533.jpg)
![关键帧](keyframes/part003_frame_00581700.jpg)
![关键帧](keyframes/part003_frame_00595800.jpg)

---

## 分组查询注意力（GQA）：平衡表达能力与缓存大小
多查询注意力(Multi-Query Attention, MQA)被证明在模型表达能力(Expressive Capacity)上过于受限，因为强制所有查询头(Query Heads)共享单一组键值头(Key-Value Heads)会导致模型性能下降。分组查询注意力(Grouped-Query Attention, GQA)作为一种优异的架构折中方案(Architectural Compromise)应运而生，它在保留标准查询头数量的同时，大幅减少了 KV 头的数量。通过将多个查询头分组并共享同一组 KV 头，GQA 在不改变序列长度(Sequence Length)或批次大小(Batch Size)的情况下，直接缩减了 KV 缓存(KV Cache)的显存占用。实证基准测试(Empirical Benchmarks)表明，通过优化 KV 分组数量，系统的延迟(Latency)与吞吐量(Throughput)均得到显著改善。例如，将 Llama 2 13B 架构的查询头与 KV 头比例(Query-to-KV Ratio)调整为特定配置，不仅降低了内存开销(Memory Overhead)，还因减少了内存数据搬运(Data Movement)而自动加速了词元生成(Token Generation)，同时使更大的批次大小能够轻松适配 H100 显存(VRAM)的容量限制。关键在于，此类效率提升仅带来微乎其微的精度损失(Accuracy Degradation)，这促使其在 Llama 3 等现代大模型中得到广泛采用。

![关键帧](keyframes/part004_frame_00000000.jpg)
![关键帧](keyframes/part004_frame_00015533.jpg)
![关键帧](keyframes/part004_frame_00036433.jpg)
![关键帧](keyframes/part004_frame_00044500.jpg)
![关键帧](keyframes/part004_frame_00075966.jpg)
![关键帧](keyframes/part004_frame_00084366.jpg)
![关键帧](keyframes/part004_frame_00092033.jpg)
![关键帧](keyframes/part004_frame_00098433.jpg)
![关键帧](keyframes/part004_frame_00135333.jpg)
![关键帧](keyframes/part004_frame_00143200.jpg)
![关键帧](keyframes/part004_frame_00177499.jpg)
![关键帧](keyframes/part004_frame_00185233.jpg)
![关键帧](keyframes/part004_frame_00198933.jpg)
![关键帧](keyframes/part004_frame_00214666.jpg)

## 多头潜在注意力（MLA）：维度投影
DeepSeek V2 引入了多头潜在注意力(Multi-Head Latent Attention, MLA)，这是一种基于维度压缩(Dimensionality Compression)而非单纯削减注意力头数量的替代性缓存优化策略。MLA 并未减少 KV 头的数量，而是在将其写入缓存前，先把 KV 向量投影(Project)至一个高度压缩的潜在空间(Latent Space)。该方法大幅压缩了缓存维度（例如从 16,000 维降至 512 维），同时完整保留了原始的注意力头数量。为保持与旋转位置编码(Rotary Position Embeddings, RoPE)的兼容性，系统会在潜在表示(Latent Representations)后拼接额外的维度。其结果是 KV 缓存体积急剧缩减，带来了与 GQA 同等的访存受限(Memory-bound)场景下的性能提升，且基准测试表明其模型精度不仅与标准注意力机制持平，部分指标甚至实现超越。

![关键帧](keyframes/part004_frame_00221233.jpg)
![关键帧](keyframes/part004_frame_00227033.jpg)
![关键帧](keyframes/part004_frame_00232333.jpg)
![关键帧](keyframes/part004_frame_00242399.jpg)
![关键帧](keyframes/part004_frame_00269533.jpg)
![关键帧](keyframes/part004_frame_00287566.jpg)
![关键帧](keyframes/part004_frame_00299633.jpg)
![关键帧](keyframes/part004_frame_00314699.jpg)
![关键帧](keyframes/part004_frame_00321299.jpg)
![关键帧](keyframes/part004_frame_00329433.jpg)
![关键帧](keyframes/part004_frame_00337533.jpg)
![关键帧](keyframes/part004_frame_00344200.jpg)

## 跨层注意力（CLA）：跨深度共享
跨层注意力(Cross-Layer Attention, CLA)从网络深度(Network Depth)维度入手，旨在解决内存开销问题。标准 Transformer 架构为每一网络层独立计算并存储键值(Key-Value, KV)向量。CLA 改变了这一范式，使多个连续层(Consecutive Layers)共享同一组 KV 投影。正如 GQA 在单层内实现跨注意力头(Attention Heads)的键值共享，CLA 则在网络深度维度上实现了跨层共享。实证评估(Empirical Evaluation)表明，CLA 显著优化了模型困惑度(Perplexity, PPL)与 KV 缓存大小之间的帕累托前沿(Pareto Frontier)，在提供可观显存节省的同时维持了模型性能。尽管在激进配置下验证困惑度(Validation Perplexity)可能微幅上升，但此举对提升推理吞吐量(Inference Throughput)极为有利，使其成为资源受限环境(Resource-constrained Environments)下极具实用价值的架构选择。

![关键帧](keyframes/part004_frame_00373166.jpg)
![关键帧](keyframes/part004_frame_00381433.jpg)
![关键帧](keyframes/part004_frame_00392033.jpg)
![关键帧](keyframes/part004_frame_00399399.jpg)
![关键帧](keyframes/part004_frame_00407633.jpg)
![关键帧](keyframes/part004_frame_00416466.jpg)

## 局部注意力与混合架构
局部注意力(Local Attention)机制将模型的上下文感受野(Contextual Receptive Field)限制为仅关注最近的 $K$ 个词元(Tokens)。这为 KV 缓存大小设定了硬性上限(Hard Upper Bound)，有效防止了长上下文(Long Context)生成过程中的显存无限膨胀，并允许旧词元在滑出滑动窗口(Sliding Window)后被安全释放。尽管该机制效率极高，但严格的局部注意力牺牲了长程依赖建模能力(Long-range Dependency Modeling)，而这正是促使架构从循环神经网络(Recurrent Neural Networks, RNNs)转向 Transformer 的核心动因。为缓解由此带来的精度损失，现代模型架构广泛采用了混合注意力机制(Hybrid Attention Mechanisms)。通过在局部层之间定期穿插完整的全局注意力层(Global Attention Layers，例如每五个局部层配置一个全局层），模型在维持平均缓存大小(Average Cache Size)恒定的同时，有效恢复了对长程上下文依赖(Long-range Contextual Dependencies)的捕捉能力，从而将局部滑动窗口的高效性与全局注意力的强表达能力(Expressive Power)完美融合。

![关键帧](keyframes/part004_frame_00449000.jpg)
![关键帧](keyframes/part004_frame_00464833.jpg)
![关键帧](keyframes/part004_frame_00470833.jpg)
![关键帧](keyframes/part004_frame_00477666.jpg)
![关键帧](keyframes/part004_frame_00537633.jpg)
![关键帧](keyframes/part004_frame_00557000.jpg)
![关键帧](keyframes/part004_frame_00572433.jpg)
![关键帧](keyframes/part004_frame_00588666.jpg)
![关键帧](keyframes/part004_frame_00598433.jpg)

---

## 混合注意力架构与缓存优化
现代专为推理优化(Inference-Optimized)的模型越来越多地融合多种架构策略(Architectural Strategies)以缓解显存限制(Memory Constraints)。一种主流范式是将全局注意力层(Global Attention Layers)与局部注意力窗口(Local Attention Windows)交替部署——例如，每隔固定层数（如六层）应用一次全局注意力，其余层则采用局部注意力。此类混合架构(Hybrid Architecture)通常辅以跨层 KV 缓存共享(Cross-Layer KV Cache Sharing)机制（覆盖局部与全局组件），以消除冗余的显存存储(Redundant Memory Storage)。总体而言，这些优化措施直击自回归生成(Autoregressive Generation)的核心显存瓶颈。实现高效的缓存缩减(Cache Reduction)可通过多种机制达成：降低 KV 向量维度、减少 KV 头总数、压缩向量表示(Vector Representation)、跨网络深度共享缓存，或将注意力计算约束于局部滑动窗口(Local Sliding Window)内。

![关键帧](keyframes/part005_frame_00000000.jpg)
![关键帧](keyframes/part005_frame_00017066.jpg)
![关键帧](keyframes/part005_frame_00034433.jpg)
![关键帧](keyframes/part005_frame_00069000.jpg)

## 关于权重共享与长上下文限制的澄清
针对跨层注意力(Cross-Layer Attention)机制，一个常被探讨的核心问题是：模型权重(Model Weights)与 KV 缓存是否需同步共享。实际上，为确保数学一致性(Mathematical Consistency)，投影层权重(Projection Weights)必须在跨层间共享，这意味着多个网络层将复用同一组 KV 投影参数及共享缓存。另一项严峻挑战源于超长上下文窗口(Ultra-long Context Windows)。无论采用何种架构优化技巧，其本质均会导致 KV 缓存呈线性膨胀。当上下文长度(Context Length)突破硬件阈值时，常规的缓存优化手段往往难以奏效。在此类场景下，工程实践通常引入先进的上下文摘要(Context Summarization)技术或词元压缩(Token Compression)算法，在历史信息超出显存预算(VRAM Budget)前对其进行关键信息提取与凝练。

![关键帧](keyframes/part005_frame_00088300.jpg)
![关键帧](keyframes/part005_frame_00098366.jpg)
![关键帧](keyframes/part005_frame_00130699.jpg)
![关键帧](keyframes/part005_frame_00140399.jpg)
![关键帧](keyframes/part005_frame_00158466.jpg)
![关键帧](keyframes/part005_frame_00168833.jpg)

## 状态空间模型与 Mamba 的突破
为从根本上规避标准注意力机制(Standard Attention Mechanism)的二次时间复杂度(Quadratic Time Complexity)与显存开销，研究人员探索了状态空间模型(State Space Models, SSMs)，其理论灵感源于经典控制理论(Classical Control Theory)与信号处理(Signal Processing)。早期实现如 S4 模型，虽能以线性推理时间(Linear Inference Time)成功处理长上下文合成任务，但在自然语言建模(Natural Language Modeling)初期却表现不佳。通过“关联召回(Associative Recall)”基准测试，研究者定位了其核心缺陷：模型需精准定位并检索深藏于长序列中的特定键值对(Key-Value Pairs)。早期的线性动力系统在序列中缺乏 Transformer 那种精准的基于内容寻址(Content-Based Addressing)的检索机制。后续迭代模型（如 Hyena、H3）逐步填补了这一能力空白，并最终催生了 Mamba 架构。Mamba 引入了数据依赖型选择机制(Data-Dependent Selection Mechanism)，在优异完成关联召回任务的同时，保留了类循环神经网络(RNN-like)的线性推理速度。值得注意的是，即便是高度优化的 Mamba 变体，在实际部署中也常采用混合架构，定期（如每隔 8 层）穿插标准 Transformer 层，以保留模型关键的长程建模能力。

![关键帧](keyframes/part005_frame_00175433.jpg)
![关键帧](keyframes/part005_frame_00185700.jpg)
![关键帧](keyframes/part005_frame_00217099.jpg)
![关键帧](keyframes/part005_frame_00222999.jpg)
![关键帧](keyframes/part005_frame_00228799.jpg)
![关键帧](keyframes/part005_frame_00254066.jpg)
![关键帧](keyframes/part005_frame_00272699.jpg)
![关键帧](keyframes/part005_frame_00319566.jpg)
![关键帧](keyframes/part005_frame_00362233.jpg)
![关键帧](keyframes/part005_frame_00377433.jpg)
![关键帧](keyframes/part005_frame_00385033.jpg)
![关键帧](keyframes/part005_frame_00403533.jpg)
![关键帧](keyframes/part005_frame_00410766.jpg)
![关键帧](keyframes/part005_frame_00431233.jpg)

## 线性注意力与后 Transformer 范式
另一项极具潜力的演进方向是线性注意力机制(Linear Attention Mechanism)的复兴。该机制通常利用泰勒级数展开(Taylor Series Expansion)或核近似方法来拟合标准的 Softmax 注意力核(Softmax Attention Kernel)。通过将注意力计算重构为线性递推形式(Linear Recurrent Form)，模型成功规避了 $O(N^2)$ 的显存与计算量爆炸，实现了类 RNN 的推理特性，其计算复杂度(Computational Complexity)与序列长度呈线性关系。该路径已被验证具备极高的模型可扩展性(Model Scalability)；例如 MiniMax 等团队已成功基于线性注意力基元，训练出参数规模达 456B 的混合专家模型(Mixture of Experts, MoE)。在实际工程部署中，纯线性注意力架构极少被独立使用。前沿模型架构普遍采用稀疏混合策略(Sparse Hybrid Strategy)：以线性注意力与局部注意力层为主体以保障推理效率，并稀疏穿插少量全局注意力层以维持长程上下文一致性(Long-range Context Consistency)。随着推理成本(Inference Cost)逐渐成为模型架构选型的主导约束，业界正加速摆脱密集全局注意力(Dense Global Attention)的依赖。这标志着技术范式正加速向高效、稀疏或线性注意力架构演进，而非继续固守传统的 Softmax 注意力机制。

![关键帧](keyframes/part005_frame_00438700.jpg)
![关键帧](keyframes/part005_frame_00445799.jpg)
![关键帧](keyframes/part005_frame_00489700.jpg)
![关键帧](keyframes/part005_frame_00518200.jpg)
![关键帧](keyframes/part005_frame_00529100.jpg)
![关键帧](keyframes/part005_frame_00534533.jpg)
![关键帧](keyframes/part005_frame_00568366.jpg)
![关键帧](keyframes/part005_frame_00580033.jpg)
![关键帧](keyframes/part005_frame_00588800.jpg)
![关键帧](keyframes/part005_frame_00597000.jpg)

---

## 超越标准注意力的架构演进
Transformer 架构(Transformer Architecture)的演进正直接针对推理瓶颈(Inference Bottleneck)，特别是 KV 缓存(KV Cache)随序列长度(Sequence Length)呈 $O(T)$ 线性增长的问题。通过集成局部注意力(Local Attention)和线性注意力(Linear Attention)等轻量级组件，现代模型能够以固定大小的显存占用(Memory Footprint)替代随序列长度动态扩展的缓存。研究揭示了 KV 缓存容量与模型关联召回(Associative Recall)能力之间的基础权衡曲线(Trade-off Curve)；尽管激进压缩缓存可能削弱模型处理特定长程依赖(Long-range Dependencies)的性能，但精细的架构调优(Architectural Tuning)能使系统在大幅缓解内存带宽(Memory Bandwidth)压力的同时，维持较高的模型精度。

![关键帧](keyframes/part006_frame_00000000.jpg)
![关键帧](keyframes/part006_frame_00021399.jpg)
![关键帧](keyframes/part006_frame_00044200.jpg)
![关键帧](keyframes/part006_frame_00051000.jpg)
![关键帧](keyframes/part006_frame_00065433.jpg)
![关键帧](keyframes/part006_frame_00072466.jpg)
![关键帧](keyframes/part006_frame_00079766.jpg)

## 用于并行生成的扩散模型
扩散模型(Diffusion Models)通过并行生成所有词元(Token)并迭代优化(Iterative Optimization)输出直至收敛(Convergence)，提供了一条与自回归生成(Autoregressive Generation)截然不同的技术路径。该并行范式完全绕过了顺序依赖瓶颈(Sequential Dependency Bottleneck)，确保无论上下文长度(Context Length)如何，GPU 计算单元(GPU Compute Units)均能保持高负载饱和状态。近期的代码生成(Code Generation)演示清晰地展示了这一工作流程：初始并行输出可能呈现碎片化或存在语法缺陷，但通过快速的迭代优化(Iterative Refinement)，结果能迅速收敛为高度连贯且功能完备的代码。基准测试(Benchmarks)对比表明，基于扩散的文本生成模型在词元每秒吞吐量(Token Throughput)方面显著超越标准 Transformer，甚至优于 Mamba-Transformer 混合状态空间架构(Hybrid State Space Architectures)。

![关键帧](keyframes/part006_frame_00090033.jpg)
![关键帧](keyframes/part006_frame_00097433.jpg)
![关键帧](keyframes/part006_frame_00107166.jpg)
![关键帧](keyframes/part006_frame_00117300.jpg)
![关键帧](keyframes/part006_frame_00123900.jpg)
![关键帧](keyframes/part006_frame_00146033.jpg)
![关键帧](keyframes/part006_frame_00152000.jpg)
![关键帧](keyframes/part006_frame_00171399.jpg)
![关键帧](keyframes/part006_frame_00178166.jpg)
![关键帧](keyframes/part006_frame_00203099.jpg)

## 克服根本性的推理瓶颈
向新型架构的迁移标志着推理优化(Inference Optimization)领域的范式转变(Paradigm Shift)。传统工程手段致力于从自回归 Transformer 中极限挖掘性能潜力，而状态空间模型(State Space Models, SSMs)与扩散方法则通过重构计算图(Computational Graph)，从根本上绕过了原有的数学限制。状态空间模型将推理内存需求压缩至恒定大小(Constant Memory Footprint)，而扩散模型则彻底摒弃了词元的顺序生成机制。只要模型质量(Model Quality)保持竞争力，此类架构创新便能通过打破长期制约推理可扩展性(Scalability)的核心结构瓶颈，实现指数级的效率跃升。

![关键帧](keyframes/part006_frame_00223866.jpg)
![关键帧](keyframes/part006_frame_00237233.jpg)
![关键帧](keyframes/part006_frame_00277200.jpg)

## 量化策略与异常值处理
模型量化(Model Quantization)通过降低数值精度(Numerical Precision)（例如从 BF16 降至 INT8 或 INT4）来加速推理，直接削减了内存带宽(Memory Bandwidth)需求并显著提升了吞吐量(Throughput)。该过程将浮点数的动态范围(Dynamic Range)映射至固定整数刻度，但大语言模型(LLMs)在推理时常会生成破坏低精度算术稳定性的离群激活值(Outlier Activations)。先进的训练后量化(Post-Training Quantization, PTQ)技术通过精准识别极端离群值(Extreme Outliers)来化解此难题：将这些异常值保留为完整的 16 位精度单独计算，而将其余绝大部分矩阵参数量化为 INT8。更为激进的方案（如激活感知权重量化 Activation-aware Weight Quantization, AWQ）则基于校准数据(Calibration Data)动态隔离敏感权重(Sensitive Weights)，从而实现极低位宽的稳定部署。在模型精度损失可忽略不计的前提下，此类方法可带来高达 3 倍的推理加速效果。

![关键帧](keyframes/part006_frame_00300333.jpg)
![关键帧](keyframes/part006_frame_00307299.jpg)
![关键帧](keyframes/part006_frame_00328966.jpg)
![关键帧](keyframes/part006_frame_00338666.jpg)
![关键帧](keyframes/part006_frame_00354566.jpg)
![关键帧](keyframes/part006_frame_00374566.jpg)
![关键帧](keyframes/part006_frame_00403033.jpg)
![关键帧](keyframes/part006_frame_00415099.jpg)
![关键帧](keyframes/part006_frame_00462599.jpg)
![关键帧](keyframes/part006_frame_00474066.jpg)
![关键帧](keyframes/part006_frame_00487033.jpg)
![关键帧](keyframes/part006_frame_00493699.jpg)
![关键帧](keyframes/part006_frame_00500166.jpg)
![关键帧](keyframes/part006_frame_00506266.jpg)

## 模型剪枝与知识蒸馏恢复
模型剪枝(Model Pruning)通过精准剔除预训练网络(Pre-trained Networks)中的冗余计算组件来加速推理。借助小型校准数据集(Calibration Dataset)，系统会精准计算各网络层、注意力头(Attention Heads)或隐藏维度(Hidden Dimensions)的重要性分数(Importance Scores)。随后系统会永久移除冗余度最高的元素，从而实质性降低模型参数量(Parameter Count)与显存占用(Memory Footprint)。鉴于激进剪枝不可避免地会引发初始性能衰减，系统通常引入知识蒸馏(Knowledge Distillation)进行恢复性微调：原始的未剪枝教师模型(Teacher Model)将指导剪枝后的学生网络(Student Network)进行参数优化。该恢复过程直接基于剪枝后的初始化状态(Initialization State)展开，而非从头训练(Training from Scratch)，从而在保留结构效率(Structural Efficiency)优势的同时，高效重塑模型精度。

![关键帧](keyframes/part006_frame_00512600.jpg)
![关键帧](keyframes/part006_frame_00520133.jpg)
![关键帧](keyframes/part006_frame_00533833.jpg)
![关键帧](keyframes/part006_frame_00549066.jpg)
![关键帧](keyframes/part006_frame_00557666.jpg)
![关键帧](keyframes/part006_frame_00564866.jpg)
![关键帧](keyframes/part006_frame_00577033.jpg)
![关键帧](keyframes/part006_frame_00583666.jpg)
![关键帧](keyframes/part006_frame_00594566.jpg)

---

## 模型剪枝与知识蒸馏恢复
模型剪枝(Model Pruning)通过精准剔除预训练网络(Pre-trained Networks)中冗余的网络层、注意力头(Attention Heads)或隐藏维度(Hidden Dimensions)来降低推理成本(Inference Cost)。与从头训练(Training from Scratch)小型模型不同，剪枝后的架构保留了原始模型的拓扑结构(Topological Structure)，但其初始状态通常伴随性能衰减且未经校准(Uncalibrated)。为恢复模型性能，系统引入知识蒸馏(Knowledge Distillation)技术，利用原始大模型作为教师模型(Teacher Model)对剪枝后的学生模型(Student Model)进行微调(Fine-tuning)。该方法可实现显著的模型压缩(Model Compression)（例如将 15B 参数模型精简至 8B 或 4B），同时在 MMLU 等基准测试(Benchmark Tests)中维持原有精度。这实质上是以微小的质量损失(Quality Degradation)换取计算开销(Computational Overhead)的大幅削减。

![关键帧](keyframes/part007_frame_00000000.jpg)
![关键帧](keyframes/part007_frame_00017666.jpg)
![关键帧](keyframes/part007_frame_00038233.jpg)

## 推测性解码：核心概念
推测性解码(Speculative Decoding)提供了一种数学上可严格保证的无损加速技术，其核心在于利用模型验证（预填充阶段, Prefill）与词元生成(Token Generation)之间固有的效率鸿沟。自回归生成(Autoregressive Generation)严格受限于内存带宽(Memory Bandwidth)且必须串行执行；相反，对固定词元序列的验证则属于计算受限(Compute-bound)且高度可并行化的预填充操作。该方法引入轻量级的“草稿”模型(Draft Model)进行前瞻推理，快速生成 $K$ 个候选词元(Candidate Tokens)。随后，参数量更大的目标模型(Target Model)会并行验证这些候选项，并基于对数概率(Log Probability)对其进行评估打分。

![关键帧](keyframes/part007_frame_00045966.jpg)
![关键帧](keyframes/part007_frame_00055033.jpg)
![关键帧](keyframes/part007_frame_00060566.jpg)
![关键帧](keyframes/part007_frame_00071933.jpg)
![关键帧](keyframes/part007_frame_00080166.jpg)
![关键帧](keyframes/part007_frame_00087866.jpg)

## 接受算法与精确采样
该验证流程依赖于受 Metropolis-Hastings 算法启发的拒绝采样(Rejection Sampling)机制。每个草稿词元以 $\min(1, Q/P)$ 的概率被接受，其中 $Q$ 代表目标模型(Target Model)的生成概率，$P$ 为草稿模型(Draft Model)的对应概率。该接受准则确保了最终输出分布(Output Distribution)与目标模型严格一致。即便草稿模型仅进行近似计算，整个流程仍保持了严格的数学保真度(Mathematical Fidelity)。若某词元被拒绝，系统将直接丢弃后续所有草稿词元，并转而依据目标模型修正后的分布采样一个新词元。该机制在确保采样结果完全符合目标模型分布的同时，大幅缓解了顺序执行(Sequential Execution)带来的性能瓶颈。

![关键帧](keyframes/part007_frame_00093566.jpg)
![关键帧](keyframes/part007_frame_00099766.jpg)
![关键帧](keyframes/part007_frame_00109433.jpg)
![关键帧](keyframes/part007_frame_00128799.jpg)
![关键帧](keyframes/part007_frame_00135033.jpg)
![关键帧](keyframes/part007_frame_00143333.jpg)
![关键帧](keyframes/part007_frame_00161333.jpg)

## 草稿模型优化与高级变体
系统的加速比(Speedup Ratio)与草稿模型的接受率(Acceptance Rate)直接成正比，这凸显了草稿模型与目标模型在输出分布上保持对齐(Alignment)的必要性。前沿推理框架通过架构创新进一步优化该流程：例如 Medusa 架构使草稿模型能够非自回归地并行生成多个词元；EAGLE 方法则将目标模型的高层隐藏特征(Hidden Features)注入草稿模型，使其有效“窥视”目标模型的内部状态以显著提升预测精度。此外，利用目标模型对草稿模型进行知识蒸馏可进一步推高接受率，确保在不牺牲输出质量(Output Quality)的前提下，稳定实现 2 倍以上的吞吐量(Throughput)提升。

![关键帧](keyframes/part007_frame_00168766.jpg)
![关键帧](keyframes/part007_frame_00174766.jpg)
![关键帧](keyframes/part007_frame_00188599.jpg)
![关键帧](keyframes/part007_frame_00195266.jpg)
![关键帧](keyframes/part007_frame_00276133.jpg)
![关键帧](keyframes/part007_frame_00307733.jpg)
![关键帧](keyframes/part007_frame_00330033.jpg)

## 面向异构流量的连续批处理
现实世界的推理服务(Inference Serving)具有高度动态性，请求通常异步到达(Asynchronous Arrival)，其完成时间各异且序列长度(Sequence Lengths)参差不齐。连续批处理(Continuous Batching)技术通过将新请求即时插入计算流水线(Compute Pipeline)，摒弃了传统静态批处理(Static Batching)中等待凑满批次(Waiting for Full Batch)的低效机制。调度器(Scheduler)在每次生成步骤(Generation Step)后动态释放控制权，实现预填充(Prefill)与解码(Decoding)任务的无缝交错执行。为高效处理可变长度序列，系统采用动态批处理策略(Dynamic Batching Strategy)：将不同序列长度的 MLP 张量(MLP Tensors)重塑并拼接为统一的批次维度以进行并行计算，而注意力机制(Attention Mechanism)的计算则严格按各序列独立执行。

![关键帧](keyframes/part007_frame_00339966.jpg)
![关键帧](keyframes/part007_frame_00345799.jpg)
![关键帧](keyframes/part007_frame_00358266.jpg)
![关键帧](keyframes/part007_frame_00363966.jpg)
![关键帧](keyframes/part007_frame_00375566.jpg)
![关键帧](keyframes/part007_frame_00387933.jpg)

## PagedAttention 与虚拟内存管理
PagedAttention 是 vLLM 框架的核心创新，专门用于解决 KV 缓存(KV Cache)的内存碎片化(Memory Fragmentation)问题。传统推理引擎通常为新序列预分配连续的显存块(Contiguous Memory Blocks)，当实际生成的词元数量未填满分配空间时，便会引发严重的内部碎片(Internal Fragmentation)。PagedAttention 借鉴了操作系统(Operating System)的虚拟内存分页(Virtual Memory Paging)机制，将 KV 缓存切分为固定大小的物理块(Physical Blocks)，并允许其分散存储于非连续的 GPU 显存(GPU VRAM)中。该设计彻底消除了显存空间浪费，实现了内存利用率(Memory Utilization)的最大化。即使在严格的显存容量限制下，系统也能支持显著更大的批次大小(Batch Size)，从而从根本上重塑了长上下文工作负载(Long-Context Workloads)的服务效率。

![关键帧](keyframes/part007_frame_00403866.jpg)
![关键帧](keyframes/part007_frame_00418533.jpg)
![关键帧](keyframes/part007_frame_00435533.jpg)
![关键帧](keyframes/part007_frame_00441866.jpg)
![关键帧](keyframes/part007_frame_00455266.jpg)
![关键帧](keyframes/part007_frame_00474866.jpg)
![关键帧](keyframes/part007_frame_00481299.jpg)
![关键帧](keyframes/part007_frame_00488266.jpg)
![关键帧](keyframes/part007_frame_00502199.jpg)
![关键帧](keyframes/part007_frame_00507999.jpg)
![关键帧](keyframes/part007_frame_00542733.jpg)
![关键帧](keyframes/part007_frame_00554500.jpg)
![关键帧](keyframes/part007_frame_00564966.jpg)
![关键帧](keyframes/part007_frame_00578400.jpg)
![关键帧](keyframes/part007_frame_00585533.jpg)
![关键帧](keyframes/part007_frame_00592766.jpg)
![关键帧](keyframes/part007_frame_00600900.jpg)

---

## 使用 PagedAttention 解决 KV 缓存碎片化问题
传统 KV 缓存(KV Cache)的内存分配同时面临内部碎片(Internal Fragmentation)与外部碎片(External Fragmentation)问题，这主要源于序列长度(Sequence Length)的不可预测性以及请求间的强制填充(Forced Padding)机制。PagedAttention 通过将操作系统(Operating System)的虚拟内存(Virtual Memory)管理理念引入 GPU 推理(GPU Inference)场景，有效解决了该难题。在此机制下，KV 缓存不再需要预先分配连续显存(Contiguous Memory)，而是被划分为固定大小的物理块(Physical Blocks)。这些物理块可动态映射至 GPU 显存(GPU VRAM)中的任意空闲位置，使系统能够高效处理多个长度各异的并发请求(Concurrent Requests)，彻底避免了显存浪费及因连续内存分配失败导致的阻塞问题。

![关键帧](keyframes/part008_frame_00000000.jpg)
![关键帧](keyframes/part008_frame_00011733.jpg)
![关键帧](keyframes/part008_frame_00024566.jpg)
![关键帧](keyframes/part008_frame_00031466.jpg)

## 共享上下文的写时复制机制
除动态分配机制外，PagedAttention 还引入了写时复制(Copy-on-Write, CoW)语义，以优化多生成请求间的共享前缀(Shared Prefixes)。通过为每个内存块维护引用计数器(Reference Counter)，系统允许多个不同的序列安全地指向并复用相同的前缀块。当特定序列生成分支并需要独立的后继内容时，推理引擎会按需创建目标物理块的副本(Physical Copy)，并相应递减原始块的引用计数。结合其他受虚拟内存机制启发的优化策略，该方法大幅降低了在具有重叠提示词(Overlapping Prompts)的批量生成(Batch Generation)过程中的冗余显存占用。

![关键帧](keyframes/part008_frame_00043633.jpg)
![关键帧](keyframes/part008_frame_00053733.jpg)
![关键帧](keyframes/part008_frame_00073500.jpg)

## 推理工作负载的动态特性
与模型训练相比，推理(Inference)呈现出截然不同的计算范式(Computational Paradigm)。其工作负载严格受限于内存带宽(Memory-bound)且高度动态，主要表现为请求长度参差不齐、到达时间异步(Asynchronous Arrival)以及完成时间不可预测。这些特性带来了复杂的任务调度(Task Scheduling)与资源管理挑战，亟需专门的系统级解决方案(System-level Solutions)。与训练阶段静态且计算密集型(Compute-intensive)的流水线不同，推理引擎必须实时适应波动的负载(Fluctuating Workloads)，实现计算与内存访问的重叠(Compute-Memory Overlap)，并动态执行请求批处理(Dynamic Request Batching)，从而在维持高吞吐量(Throughput)的同时保障低延迟(Latency)。

![关键帧](keyframes/part008_frame_00081533.jpg)
![关键帧](keyframes/part008_frame_00089700.jpg)

## 架构创新作为终极杠杆
尽管推测性解码(Speculative Decoding)、模型量化(Model Quantization)、网络剪枝(Network Pruning)及内存分页(Memory Paging)等系统级优化技术已带来显著性能增益，但最具变革潜力的突破仍源于模型架构(Model Architecture)本身的创新。业界正逐步摆脱单纯针对固定且计算密集型 Transformer 架构优化推理流水线(Inference Pipeline)的传统思路，转而致力于设计原生具备推理友好性(Inference-Friendly)的新型架构。通过削减 KV 缓存依赖、集成线性注意力(Linear Attention)或局部注意力(Local Attention)机制，以及引入状态空间模型(State Space Models, SSMs)，开发者得以从根本上绕过传统的性能瓶颈。这一范式转变(Paradigm Shift)的核心在于在严苛的资源预算(Resource Budget)约束下最大化模型精度。它充分证明：最高效的推理优化策略往往始于前期的建模阶段(Modeling Phase)，而非后期的推理服务层(Inference Serving Layer)。

![关键帧](keyframes/part008_frame_00121066.jpg)
![关键帧](keyframes/part008_frame_00145999.jpg)
![关键帧](keyframes/part008_frame_00154299.jpg)
![关键帧](keyframes/part008_frame_00167866.jpg)