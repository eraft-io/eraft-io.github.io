## 课程介绍与讲座目标
让我们开始吧。在进入今天的讲座内容之前，我想先跟大家同步一下课程进度。由于目前的推进速度稍慢，且学期已接近尾声，这将是我和 Tatsu 主讲的最后一节课。我们现在正式开始。此前，我们从可验证奖励(Verifiable Rewards)的角度概述了强化学习(Reinforcement Learning, RL)，并探讨了诸如近端策略优化(Proximal Policy Optimization, PPO)和群组相对策略优化(Group Relative Policy Optimization, GRPO)等策略梯度(Policy Gradient)算法。在本次课程中，我们将深入剖析策略梯度的运作机制，重点聚焦于 GRPO。我们不会引入全新的概念，而是基于已有理论进行深度挖掘，并结合代码实现与数学推导展开详细分析。
![关键帧](keyframes/part000_frame_00000000.jpg)
![关键帧](keyframes/part000_frame_00006000.jpg)
![关键帧](keyframes/part000_frame_00020066.jpg)

## 语言模型的强化学习框架
为了奠定讨论的基础，我们将强化学习应用于语言模型，这需要明确定义状态(State)、动作(Action)和奖励(Reward)。状态由提示词(Prompt)以及截至目前已生成的文本序列共同构成。每个动作通常对应于预测下一个词元(Token)。奖励则用于衡量完整回复的质量。在本课程中，我们聚焦于结果奖励(Outcome Rewards)，即奖励是整个回复序列的确定性函数，无需依赖人工标注。这种可验证奖励的设定会带来稀疏且延迟的反馈，因为我们仅在生成过程结束时才能接收到信号。尽管这带来了一定的挑战，但它通过免除中间奖励机制中常见的折扣(Discounting)和自举(Bootstrapping)等复杂操作，极大地简化了整体的概念框架。
![关键帧](keyframes/part000_frame_00058100.jpg)
![关键帧](keyframes/part000_frame_00084266.jpg)

## 状态转移动态与状态灵活性
考虑一个典型场景：给定一道数学题，模型首先生成思维链(Chain of Thought, CoT)，最后输出类似“因此，答案是三英里”的结论。奖励函数会提取该答案，并与真实答案(Ground Truth)进行比对验证。在传统强化学习中，状态转移动态(State Transition Dynamics)通常非常复杂，但在此处，它仅仅是一个简单的字符串拼接操作：将新生成的词元追加到现有状态之后。对这种状态转移动态的完全掌控，使得推理期计算与规划(Test-time Compute and Planning)成为可能，而这正是机器人学研究者梦寐以求的能力。此外，大语言模型(Large Language Models, LLMs)中的状态完全由词元序列构成，具有极高的灵活性。与机器人领域中受物理规律限制且难以遍历的状态空间不同，LLM 能够生成任意的文本状态。因此，真正的挑战已从“状态可达性”转变为“确保生成的词元序列在逻辑上能够正确推导出最终答案”。这从根本上重塑了在自然语言处理领域中应用强化学习时所面临的核心难点。

## 策略定义与优化目标
策略(Policy)本质上即为语言模型本身，它以当前状态（提示词 + 已生成文本）为条件概率输入，通常由预训练模型检查点(Pre-trained Checkpoint)经过微调得到。一次轨迹采样(Rollout)始于初始状态，模型逐步生成一系列词元动作，并最终获得一个标量奖励(Scalar Reward)作为终结。我们的核心目标是最大化期望奖励(Expected Reward)，该期望值是相对于环境分发的提示词分布以及由待优化策略 $\pi$ 生成的回复序列共同计算的。深入理解这一设定，能够确保我们对强化学习目标的把控更加精准。
![关键帧](keyframes/part000_frame_00287333.jpg)

## 策略梯度的数学推导
现在我们将转向策略梯度方法，该方法通过梯度优化迭代改进策略。为了在结果奖励设定下简化数学符号，我们用 $A$ 表示整个回复序列，而非单个词元。期望奖励被定义为对状态分布的积分，即策略在给定状态 $S$ 下生成动作序列 $A$ 的概率，乘以对应的奖励 $R$。为了对其进行优化，我们针对策略参数计算梯度。关键在于，梯度仅作用于策略分布部分。利用对数导数技巧（Log-Derivative Trick，常被称为策略梯度定理(Policy Gradient Theorem)的核心），该梯度表达式可转化为 $\nabla \log \pi(A|S) R$ 的形式。将其重写为关于状态 $S$ 和动作序列 $A$ 联合分布的期望，即可推导出标准的策略梯度更新规则。
![关键帧](keyframes/part000_frame_00292800.jpg)
![关键帧](keyframes/part000_frame_00328766.jpg)
在实际应用中，我们首先从数据集中采样一个提示词，接着从当前策略中采样一条回复轨迹，并利用该采样结果计算梯度估计值以更新模型参数。这一过程在机制上非常类似于监督学习中的随机梯度下降(Stochastic Gradient Descent, SGD)。
![关键帧](keyframes/part000_frame_00365000.jpg)

## 直觉理解：与监督微调（SFT）的对比
从直觉上理解，朴素策略梯度(Vanilla Policy Gradient)的工作机制与监督微调(Supervised Fine-Tuning, SFT)颇为相似，但存在一个关键差异：参数更新会根据奖励值进行加权。在 SFT 中，人类提供标准的目标序列 $A$，模型通过最大化似然估计(Maximum Likelihood Estimation, MLE)来模仿该序列。而在策略梯度中，序列 $A$ 由模型自主生成，且梯度更新的步长由奖励 $R$ 进行缩放。若考虑二值奖励(Binary Reward)设定（即 $R \in \{0, 1\}$），算法将仅对正确的回复（$R=1$）进行参数更新，并完全忽略错误的回复（$R=0$）。这实际上等价于在由成功轨迹采样(Successful Rollouts)构成的动态数据集上执行 SFT。每次参数更新后，策略分布随之改变，从而在下一次迭代中生成全新的数据分布。
![关键帧](keyframes/part000_frame_00477233.jpg)
![关键帧](keyframes/part000_frame_00491099.jpg)

## 高方差与稀疏奖励的挑战
策略梯度方法面临的主要挑战在于其众所周知的高方差(High Variance)与高噪声问题。尽管监督学习中的 SGD 同样存在噪声，但在使用较大批次大小(Batch Size)时通常仍能稳定收敛。相比之下，强化学习引入了本质更高的随机性。在稀疏奖励(Sparse Reward)设定下（例如，要求模型以二值正确性解决复杂的数学问题），次优策略生成的绝大多数轨迹采样都会获得 $R=0$ 的奖励。因此，有效的学习信号变得极其微弱且充满噪声，导致模型难以高效地发现并巩固正确的行为模式。如何有效降低或管理这种方差，正是各类高级策略梯度算法旨在解决的核心议题。
![关键帧](keyframes/part000_frame_00572666.jpg)

---

## 稀疏奖励与模型停滞的挑战
在稀疏奖励(Sparse Reward)设定下，绝大多数模型生成的回复都会获得零奖励。若初始策略(Initial Policy)性能过差，以至于无法生成任何正确答案，则计算出的梯度更新将趋近于零，从而导致训练过程陷入完全停滞。与监督学习(Supervised Learning)不同（在监督学习中，模型始终能接收到指向明确已知目标的梯度信号），基于稀疏奖励的强化学习在训练初期缺乏此类“安全网”。
![关键帧](keyframes/part001_frame_00000000.jpg)

## 动态数据分布与迭代式课程
一个很自然的问题是：为何训练数据集会随时间动态变化？这是因为该数据集完全由从当前策略(Current Policy)中直接采样得到的回复组成。随着梯度更新不断调整模型参数，模型生成回复的基础概率分布也会随之发生偏移。这种动态性无形中构建了一种隐式课程学习(Implicit Curriculum Learning)机制：当策略成功解决较简单的问题并获得非零奖励时，随后的参数更新便会逐步提升模型的泛化能力(Generalization Capability)。随着迭代的推进，策略会自然而然地过渡到处理难度更高的提示词(Prompts)，从而带动采样数据集的整体质量与平均奖励稳步上升。
![关键帧](keyframes/part001_frame_00046366.jpg)
![关键帧](keyframes/part001_frame_00063633.jpg)
![关键帧](keyframes/part001_frame_00093433.jpg)

## 可验证结果奖励与连续型 RLHF 的对比
此种可验证结果奖励(Verifiable Outcome Rewards)框架与基于人类反馈的强化学习(Reinforcement Learning from Human Feedback, RLHF)形成了鲜明对比。尽管 RLHF 依赖于预先训练好的奖励模型(Reward Model)为每条回复分配连续且细粒度的标量分数，但可验证奖励通常是离散的（例如二值奖励 0 或 1），其计算方式是将模型的最终输出与确定性的标准答案进行解析比对。尽管两者底层的优化算法（如近端策略优化 Proximal Policy Optimization, PPO）在数学形式上可能完全一致，但可验证奖励所具有的离散性与稀疏性从根本上重塑了训练直觉，并要求采用截然不同的超参数调优(Hyperparameter Tuning)策略。
![关键帧](keyframes/part001_frame_00312366.jpg)
![关键帧](keyframes/part001_frame_00324700.jpg)

## 过程奖励与中间反馈
尽管为简化讨论，本文主要聚焦于基于结果的奖励(Outcome-based Rewards)，但过程奖励(Process Rewards)（或称过程监督 Process Supervision）通过在生成过程的中间步骤提供反馈，提供了一条可行的替代路径。从理论上讲，能够尽早对模型进行评估与参数更新无疑具有显著优势。然而，为语言模型设计高效的过程奖励机制极具挑战性，因为很难在不干扰模型后续生成轨迹（甚至导致其完全偏离正轨）的前提下，准确评估其局部推理进展。因此，在回复末尾依赖可验证的结果奖励，依然是当前更为稳健且实用的主流方法。
![关键帧](keyframes/part001_frame_00330300.jpg)
![关键帧](keyframes/part001_frame_00342599.jpg)
![关键帧](keyframes/part001_frame_00348300.jpg)

## 朴素策略梯度中的高方差问题
朴素策略梯度(Vanilla Policy Gradient)方法长期饱受高方差(High Variance)与随机噪声的困扰。为阐明这一问题，我们考虑一个仅包含两个状态(States)的简化场景。在相对简单的状态 $S_1$ 中，执行动作 $A_1$ 可获得 11 的奖励，而执行动作 $A_2$ 则获得 9。在较困难的状态 $S_2$ 中，$A_1$ 的奖励为 0，而 $A_2$ 的奖励为 2。显然，最优策略(Optimal Policy)理应在 $S_1$ 中选择 $A_1$，在 $S_2$ 中选择 $A_2$。然而，由于 $S_1$ 中次优动作 $A_2$ 的绝对奖励（9）远高于 $S_2$ 中最优动作 $A_2$ 的绝对奖励（2），朴素的梯度更新会不成比例地强化对动作 $A_2$ 的偏好。这种奖励量级上的错位可能导致策略陷入次优的局部最优解(Suboptimal Local Optimum)，使其过度偏好那些“表现尚可”的动作，而非真正的全局最优解(Global Optimum)。
![关键帧](keyframes/part001_frame_00441300.jpg)

## 通过基线函数降低方差
为了解决这一关键的方差问题，高级策略梯度算法引入了基线函数(Baseline Function) $B(S)$。算法不再直接针对原始奖励 $R$ 进行优化，而是转而优化优势(Advantage) $(R - B(S))$。其数学关键在于，由于策略概率分布在所有可能动作(Actions)上的积分恒为 1，因此基线函数 $B(S)$ 的期望值实际上与当前策略 $\pi$ 无关。因此，从奖励中减去 $B(S)$ 并不会为梯度估计(Gradient Estimation)引入额外的偏差(Bias)。相反，基线通过提供一个状态相关的参考基准大幅降低了方差，从而确保模型能够依据相对表现而非具有误导性的绝对奖励量级来更新参数。
![关键帧](keyframes/part001_frame_00564500.jpg)

---

## 基线概念与优化不变性
从数学上看，优化期望奖励(Expected Reward) $E[R]$ 等同于优化 $E[R - B(S)]$。这是因为基线函数(Baseline Function) $B(S)$ 被定义为与动作(Action) $A$ 无关。因此，在给定策略 $\pi$ 下对其求期望时，它仅充当一个常数偏移量。减去该常数会改变目标函数的绝对数值，但完全不会改变梯度的方向。因此，任何独立于动作的函数 $B(S)$ 均可被直接引入策略梯度更新公式中，且不会改变底层的优化问题(Optimization Problem)。
![关键帧](keyframes/part002_frame_00000000.jpg)

## 方差降低：双状态示例
为直观理解基线(Baseline)的实际效果，我们考虑一个简化的双状态(Two-State)场景。在使用均匀策略(Uniform Policy)的朴素策略梯度(Vanilla Policy Gradient)算法中，原始奖励序列 11、9、0 和 2 将导致梯度方差(Gradient Variance)高达约 5.3。若引入状态依赖的基线（即设定 $B(S_1)=10$ 和 $B(S_2)=1$），并从对应奖励中减去这些基线值，调整后的奖励值将紧密围绕在零附近，从而使方差大幅降至约 1.1。这表明，精心设计的基线能够极大地稳定训练信号并加速模型收敛(Convergence)，同时确保期望梯度的无偏性。
![关键帧](keyframes/part002_frame_00065800.jpg)
![关键帧](keyframes/part002_frame_00073100.jpg)
![关键帧](keyframes/part002_frame_00086666.jpg)
![关键帧](keyframes/part002_frame_00113033.jpg)
![关键帧](keyframes/part002_frame_00129833.jpg)

## 实践实现：冻结基线
工程实现中的一个关键考量是确保基线在梯度计算期间保持数学上的恒定。理论上，$B(S)$ 绝不能依赖于当前正在更新的策略参数(Policy Parameters)。在实际操作中，这意味着算法必须维护策略网络或价值网络(Value Network)的一个冻结副本(Frozen Copy)来专门计算基线。若在梯度求导过程中基线同步发生变化，将破坏算法的数学无偏性保证，并可能引入梯度偏差(Gradient Bias)。因此，标准实践是：在固定基线的状态下执行一批次策略更新(Policy Update)，随后再刷新基线估计值。
![关键帧](keyframes/part002_frame_00216799.jpg)
![关键帧](keyframes/part002_frame_00227700.jpg)
![关键帧](keyframes/part002_frame_00239266.jpg)
![关键帧](keyframes/part002_frame_00249266.jpg)
![关键帧](keyframes/part002_frame_00257366.jpg)
![关键帧](keyframes/part002_frame_00265866.jpg)

## 最优基线与启发式近似
尽管使方差最小化的最优基线存在闭式解(Closed-form Solution)，但该解涉及复杂的协方差项(Covariance Terms)与高维导数计算，在大语言模型(Large Language Models, LLMs)的规模下计算上完全不可行。相反，一种高效且被广泛采用的启发式方法(Heuristic Approach)是将基线近似为给定状态下的期望奖励：$B(S) \approx E[R|S]$。尽管这并非严格的数学最优解，但该方法能有效对奖励分布进行中心化(Centering)，并为稳定策略更新提供了坚实的实践指导框架。
![关键帧](keyframes/part002_frame_00283833.jpg)

## 与优势函数的联系
这一启发式基线设置直接将策略梯度方法与标准强化学习理论紧密相连。状态价值函数(State-Value Function) $V(S)$ 定义为 $E[R|S]$，而动作价值函数(Action-Value Function) $Q(S,A)$ 则表示为 $E[R|S,A]$。优势函数(Advantage Function) 定义为 $A(S,A) = Q(S,A) - V(S)$，用于量化执行特定动作相较于该状态下平均动作所能带来的额外收益。当我们将基线 $B(S)$ 设定为对 $V(S)$ 的近似时，优化目标 $R - B(S)$ 在数学上即等价于优化优势函数。这为基于优势的更新机制(Advantage-based Update)提供了清晰的理论支撑。
![关键帧](keyframes/part002_frame_00369833.jpg)
![关键帧](keyframes/part002_frame_00391266.jpg)
![关键帧](keyframes/part002_frame_00412866.jpg)

## 策略梯度算法的通用形式
包括近端策略优化(Proximal Policy Optimization, PPO)和群组相对策略优化(Group Relative Policy Optimization, GRPO)在内的现代策略梯度方法，均遵循一种通用的数学结构：$\nabla \log \pi(A|S) \times \Delta$。各类算法的核心差异与创新点在于 $\Delta$ 如何从奖励信号中构建。它既可以是原始奖励，也可以是减去基线后的优势估计，抑或是如 GRPO 中所采用的组内标准化(Group-wise Standardization)指标 $(R - \mu)/\sigma$。尽管具体的工程实现与归一化技术(Normalization Techniques)仍在不断演进，但利用奖励派生的权重来缩放对数概率梯度(Log-Probability Gradient)这一基础机制，始终是驱动所有策略梯度优化(Policy Gradient Optimization)的核心支柱。
![关键帧](keyframes/part002_frame_00463033.jpg)
![关键帧](keyframes/part002_frame_00470266.jpg)
![关键帧](keyframes/part002_frame_00506866.jpg)

---

## 基线概念与 GRPO 的演进
让我们先厘清关于策略梯度(Policy Gradient)和基线(Baseline)的几个基础概念。基线本质上是一个仅依赖于状态(State)而与动作(Action)无关的函数 $B(S)$，将其引入策略梯度更新中旨在降低方差(Variance)。这一概念直接对应于统计学中的控制变量法(Control Variates)。从理论转向实践，我们接下来的讨论将主要围绕群组相对策略优化(Group Relative Policy Optimization, GRPO)算法展开。从演进历史来看，GRPO 可视为对近端策略优化(Proximal Policy Optimization, PPO)的一种有趣简化，它诞生于直接偏好优化(Direct Preference Optimization, DPO)和 GPO 等中间算法之后。其近期的流行，主要归因于该算法在大语言模型训练中所展现出的独特结构优势。
![关键帧](keyframes/part003_frame_00000000.jpg)
![关键帧](keyframes/part003_frame_00014499.jpg)
![关键帧](keyframes/part003_frame_00037766.jpg)
![关键帧](keyframes/part003_frame_00047766.jpg)
![关键帧](keyframes/part003_frame_00055033.jpg)

## 语言模型中的分组结构与方差降低
语言建模(Language Modeling)的设定天然契合 GRPO，因为它提供了一种内置的分组结构(Group Structure)。针对单个提示词(Prompt)，我们可以并行生成多个回复，从而构成一个自然的比较集合。此时，基线(Baseline)可直接计算为该组回复的平均奖励。这种相对评估方法有效最小化了方差，避免了经典强化学习（如机器人控制）中所需的复杂全局价值函数(Value Function)（在那些场景中，每次轨迹采样(Rollout)的结构差异巨大）。GRPO 充分利用了针对同一提示词所生成回复的经验分布(Empirical Distribution)，使其在大语言模型上的训练兼具极高的计算效率与概念上的简洁性。
![关键帧](keyframes/part003_frame_00075666.jpg)
![关键帧](keyframes/part003_frame_00091100.jpg)
![关键帧](keyframes/part003_frame_00101466.jpg)
![关键帧](keyframes/part003_frame_00213433.jpg)

## 任务设计与奖励工程
为在实际环境中演示上述概念，我们定义了一个简化任务：数字序列排序。提示词(Prompt)会提供一个未排序的列表，模型回复需输出排序后的版本。在此过程中，奖励函数(Reward Function)的设计至关重要。若采用二值奖励(Binary Reward)（即完全正确得 1 分，否则得 0 分），模型将陷入稀疏奖励(Sparse Reward)的困境，导致在弱策略(Weak Policy)下训练停滞。为此，我们引入了部分计分(Partial Credit)机制。一种简单方法是统计回复中与标准答案(Ground Truth)位置匹配的字符数量。更细粒度的(Fine-grained)替代方案则是：对包含正确词元(Token)且相邻词元相对顺序正确的回复赋予相应分数。第二种奖励函数能提供更密集的学习信号(Dense Learning Signal)，为更接近正确答案的回复分配更高分数，从而显著加速训练进程，尽管该设计在逻辑严密性上可能存在少量漏洞。
![关键帧](keyframes/part003_frame_00223699.jpg)
![关键帧](keyframes/part003_frame_00229133.jpg)
![关键帧](keyframes/part003_frame_00274733.jpg)
![关键帧](keyframes/part003_frame_00307799.jpg)
![关键帧](keyframes/part003_frame_00319133.jpg)
![关键帧](keyframes/part003_frame_00374900.jpg)
![关键帧](keyframes/part003_frame_00397233.jpg)
![关键帧](keyframes/part003_frame_00402933.jpg)
![关键帧](keyframes/part003_frame_00411566.jpg)
![关键帧](keyframes/part003_frame_00449066.jpg)

## 简化模型架构与推理设置
在模型架构(Model Architecture)方面，我们采用高度简化的设计，以严格聚焦于强化学习机制的剖析。我们假设提示词(Prompt)与回复(Completion)的长度固定，并引入了专用的位置参数(Positional Parameters)，因为位置信息对排序任务至关重要。为简化代码实现并规避自回归生成(Autoregressive Generation)的复杂性，模型将独立解码回复的每一个位置。该架构主要由一个嵌入矩阵(Embedding Matrix)以及用于编码和解码的特定位置变换矩阵(Positional Transformation Matrices)构成。在推理(Inference)阶段，我们利用清晰的张量维度(Tensor Dimensions)来组织计算流程：包括表示提示词数量的批次大小(Batch Size)、固定的提示词长度、针对每个提示词采样的多条回复（用于构建 GRPO 分组），以及固定的回复长度。此设置使我们能够高效地批量生成与评估分组回复，进而顺利执行策略梯度更新。
![关键帧](keyframes/part003_frame_00456433.jpg)
![关键帧](keyframes/part003_frame_00521500.jpg)
![关键帧](keyframes/part003_frame_00539200.jpg)
![关键帧](keyframes/part003_frame_00573366.jpg)
![关键帧](keyframes/part003_frame_00599700.jpg)

---

## 模型架构与前向传播
讲座首先通过一个简化玩具模型(Toy Model)的前向传播(Forward Pass)过程展开。该模型旨在阐明策略梯度(Policy Gradient)的运作机制，同时避免了完整 Transformer 架构带来的计算开销。提示词(Prompts)首先被映射为固定维度的嵌入向量(Embeddings)。为捕获位置信息，模型引入了逐位置变换矩阵(Position-specific Transformation Matrices)，有效地将批次(Batch)维度与位置(Position)维度融合为统一的表示空间。随后，该聚合向量输入至各位置对应的解码矩阵(Decoding Matrices)，最终为每个词元(Token)位置生成词表(Vocabulary)上的原始对数几率(Logits)。尽管为保持代码清晰，该架构绕过了自回归生成(Autoregressive Generation)，但它清晰地展示了模型如何将提示词映射为词元概率分布(Probability Distribution)。
![关键帧](keyframes/part004_frame_00000000.jpg)
![关键帧](keyframes/part004_frame_00012633.jpg)
![关键帧](keyframes/part004_frame_00018966.jpg)
![关键帧](keyframes/part004_frame_00049900.jpg)
![关键帧](keyframes/part004_frame_00076233.jpg)

## 回复采样与张量管理
生成对数几率(Logits)后，下一步是为每个提示词采样多条回复，以构建群组相对策略优化(Group Relative Policy Optimization, GRPO)所需的分组(Group)。为适配 PyTorch 的张量运算，Logits 首先从 `(batch, position, vocab)` 展平(Flatten)为 `(batch * position, vocab)`。随后，模型针对每个位置独立采样 `num_responses` 条回复（此处记为试验 Trial）。采样结果随后被重塑(Reshape)并转置为 `(batch, trial, position)` 的张量结构。需注意的是，尽管标准大语言模型采用自回归生成(Autoregressive Generation)方式逐词元输出，但本简化设置改为从同一分布中独立采样每个位置的词元。这一近似处理在保持算法核心保真度(Algorithmic Fidelity)的同时，出于教学演示目的大幅降低了代码实现的复杂度。
![关键帧](keyframes/part004_frame_00083066.jpg)
![关键帧](keyframes/part004_frame_00090300.jpg)

## 奖励计算与 Delta 变换
完成分组回复采样后，需对每条试验(Trial)轨迹应用奖励函数(Reward Function)以评估其生成质量。在实际应用中，原始奖励往往缺乏足够的方差（如本演示中因固定随机种子(Random Seed)所致），因此需要借助 `compute_deltas` 函数将原始分数转化为有效的梯度信号(Gradient Signal)。常见的处理策略包括：直接使用原始奖励、通过减去组内均值(Group Mean)实现奖励中心化(Reward Centering)，或采用 GRPO 风格的标准化处理（即中心化后除以标准差 Standard Deviation）。中心化处理尤为有效，因为它能将稀疏的奖励分布（例如单个 `1` 与大量 `0`）转化为包含正负 Delta 值的混合分布。此时，低于平均水平的回复将接收到负向更新信号，从而主动驱使策略偏离次优行为(Suboptimal Behavior)，而非简单地将其忽略。
![关键帧](keyframes/part004_frame_00133833.jpg)
![关键帧](keyframes/part004_frame_00154100.jpg)
![关键帧](keyframes/part004_frame_00177033.jpg)
![关键帧](keyframes/part004_frame_00191033.jpg)
![关键帧](keyframes/part004_frame_00200266.jpg)
![关键帧](keyframes/part004_frame_00208766.jpg)
![关键帧](keyframes/part004_frame_00230933.jpg)
![关键帧](keyframes/part004_frame_00266400.jpg)
![关键帧](keyframes/part004_frame_00278233.jpg)
![关键帧](keyframes/part004_frame_00288300.jpg)
![关键帧](keyframes/part004_frame_00322566.jpg)
![关键帧](keyframes/part004_frame_00342466.jpg)

## 边界情况：均匀奖励与最大化策略
Delta 变换(Delta Transformation)机制的引入也带来了一些有趣的行为边界情况(Edge Cases)。若策略生成的所有回复均获得相同奖励（例如全为 `5` 分），中心化操作将产生全零的 Delta 值，导致参数更新(Parameter Update)完全停滞。这在直观上完全合理：若组内不存在相对性能差异，梯度便无法提供任何偏向特定回复的优化信号。为规避部分得分机制(Partial Credit Mechanism)可能诱使模型陷入局部最优解(Local Optimum)的风险，可采用一种替代性的“仅保留最大值”策略。该策略将批次(Batch)中所有非最高分回复的 Delta 值强制置零，从而实施一种“全有或全无”的学习动态(Learning Dynamics)。这迫使策略持续追求全局最优解(Global Optimum)，而非安于轻易可达的次优表现。
![关键帧](keyframes/part004_frame_00349599.jpg)
![关键帧](keyframes/part004_frame_00396999.jpg)
![关键帧](keyframes/part004_frame_00414866.jpg)
![关键帧](keyframes/part004_frame_00420433.jpg)
![关键帧](keyframes/part004_frame_00426533.jpg)
![关键帧](keyframes/part004_frame_00463733.jpg)

## 对数概率提取与损失函数准备
为完成策略梯度更新，模型需精确计算其实际生成的各词元的对数概率(Log-Probabilities)。原始 Logits 首先需经过 Softmax 与对数运算，转化为词表(Vocabulary)上的对数概率分布。随后，借助张量广播(Tensor Broadcasting)与高级索引(Advanced Indexing)技术，精准提取与采样回复相对应的特定对数概率，最终构建出形状为 `(batch, trial, position)` 的对数概率张量(Log-Prob Tensors)。在获取 Delta 信号（源自奖励的加权权重）与对数概率后，即可正式组装损失函数(Loss Function)。在最基础的策略梯度公式中，只需将 Delta 值与对数概率逐元素相乘(Element-wise Multiplication)，并对所有位置与试验维度求均值，即可得到最终的损失标量。该结果将直接用于后续的反向传播(Backpropagation)与模型参数更新。
![关键帧](keyframes/part004_frame_00476299.jpg)
![关键帧](keyframes/part004_frame_00496099.jpg)
![关键帧](keyframes/part004_frame_00526033.jpg)
![关键帧](keyframes/part004_frame_00536866.jpg)
![关键帧](keyframes/part004_frame_00555866.jpg)
![关键帧](keyframes/part004_frame_00566400.jpg)
![关键帧](keyframes/part004_frame_00596833.jpg)

---

## 朴素策略梯度与张量广播
朴素策略梯度(Vanilla Policy Gradient)损失的计算十分直接：只需将生成回复的对数概率(Log-Probabilities)与源自奖励的 Delta 值相乘，随后在整个批次(Batch)上求均值。由于我们处于结果奖励(Outcome Reward)设定中，每个回复对应的 Delta 值是一个标量，与具体的词元(Token)位置完全无关。因此，在与具有“批次-试验-位置”三维张量的对数概率进行逐元素乘法(Element-wise Multiplication)时，Delta 值会通过张量广播(Tensor Broadcasting)机制自动扩展至序列的每一个位置。若采用过程奖励(Process Reward)，则 Delta 值会按位置独立计算，此时无需广播机制，从而能够实现更细粒度的信用分配(Credit Assignment)。
![关键帧](keyframes/part005_frame_00000000.jpg)

## 冻结参数的关键作用
在 GRPO 和 PPO 等算法中，一个关键的实现细节在于正确处理概率比率(Probability Ratio)。当计算形如 $P_{\theta}(a|s) / P_{\text{old}}(a|s)$ 的比率时，必须将旧策略的概率分布视为数学常数。若分子与分母均依赖于当前可训练参数，该比率将恒等于 1，其梯度(Gradient)将严格为零，从而导致学习过程完全停滞。为避免此问题，旧模型的前向传播(Forward Pass)必须置于 `no_grad` 上下文(Context)中执行。此举会切断分母部分的计算图(Computational Graph)，使深度学习框架将其数值视作固定参考基准，同时确保反向传播(Backpropagation)能够顺畅作用于当前策略网络。
![关键帧](keyframes/part005_frame_00031400.jpg)
![关键帧](keyframes/part005_frame_00038733.jpg)
![关键帧](keyframes/part005_frame_00079233.jpg)
![关键帧](keyframes/part005_frame_00099433.jpg)
![关键帧](keyframes/part005_frame_00113200.jpg)
![关键帧](keyframes/part005_frame_00128233.jpg)

## 结果奖励与信用分配
一个常见的疑问是：既然序列末端的词元似乎对最终答案更为关键，为何不对结果奖励应用时间折扣(Temporal Discounting)？在实际应用中，将信用(Credit)精准归因于特定的早期或晚期决策极具挑战性，尤其是在反馈稀疏(Sparse Feedback)的场景下。早期的策略性决策往往主导了整个生成轨迹(Generation Trajectory)，这使得我们难以先验地判定哪些词元应承担更多的“功劳”或“过失”。因此，在结果奖励设定中，标准做法是将奖励信号或误差责任均匀地归因于生成序列的每一个位置，从而有效规避了复杂的信用分配(Credit Assignment)难题。
![关键帧](keyframes/part005_frame_00161866.jpg)

## GRPO 损失构建与梯度截断
核心 GRPO 损失函数在朴素策略梯度公式的基础上，引入了概率比率(Probability Ratio)与截断(Clipping)机制以稳定训练过程。首先，计算当前策略与旧策略的概率比率（通常通过对数概率相减后取指数实现）。随后，将该比率与 Delta 信号相乘。为防止因更新步长过大而引发策略崩溃(Policy Collapse)，该比率会被硬性截断至安全区间 $[1-\epsilon, 1+\epsilon]$。接着，损失函数会取“未截断乘积”与“截断后乘积”二者中的较小值。这一 `min` 操作有效约束了策略更新的幅度，确保新策略在单次迭代中不会过度偏离旧策略。最后，对目标函数取负号，从而将期望奖励最大化问题转化为适用于梯度下降(Gradient Descent)的标准损失最小化问题。
![关键帧](keyframes/part005_frame_00220399.jpg)
![关键帧](keyframes/part005_frame_00228366.jpg)
![关键帧](keyframes/part005_frame_00248133.jpg)
![关键帧](keyframes/part005_frame_00258733.jpg)

## 降方差的 KL 惩罚项
为维持策略稳定性并防止灾难性遗忘(Catastrophic Forgetting)，损失函数中额外引入了 KL 散度惩罚项(KL Divergence Penalty)。KL 散度的标准定义涉及对数概率比 $\log(P/Q)$ 的期望。然而，直接通过采样估计该值会引入极高的噪声。一种巧妙的数学变换利用了概率比率 $Q/P$ 的期望值恒为 1 这一性质。通过将 KL 估计器重写为 $Q/P - \log(Q/P) - 1$，我们实际上减去了一个期望为零的常数项，从而显著降低了蒙特卡洛估计(Monte Carlo Estimation)的方差。该无偏且低方差的估计器通过对词表(Vocabulary)维度求和，并在批次、试验及位置维度上取均值进行计算，在整个训练周期内提供了更为平稳的正则化信号(Regularization Signal)。
![关键帧](keyframes/part005_frame_00376466.jpg)
![关键帧](keyframes/part005_frame_00383466.jpg)
![关键帧](keyframes/part005_frame_00492566.jpg)

## 端到端 RL 训练流水线
完整的强化学习(Reinforcement Learning)训练循环可概括为一条高度模块化(Modular)与解耦(Decoupled)的流水线。首先，固定策略(Fixed Policy)会针对给定的一组提示词(Prompts)批量生成回复序列。其次，这些回复由外部奖励函数(External Reward Function)进行独立评估，该过程完全游离于模型的计算图(Computational Graph)之外（评估方式涵盖从简单的精确匹配(Exact Match)验证到复杂的环境交互模拟）。与此同时，模型会分别基于当前参数与旧参数，计算已生成序列的对数概率(Log-Probabilities)。随后，两条核心数据流——源自奖励评估的 Delta 信号与模型输出的对数概率——被整合至统一的损失函数中，并按需接入截断(Clipping)机制与 KL 正则化(KL Regularization)。最后，执行单次梯度更新(Gradient Update)以调整策略参数，随后加载新批次数据并循环往复，直至模型收敛。
![关键帧](keyframes/part005_frame_00511266.jpg)
![关键帧](keyframes/part005_frame_00577966.jpg)
![关键帧](keyframes/part005_frame_00601066.jpg)

---

## GRPO 训练循环架构
让我们将完整的算法整合为一个连贯的训练循环(Training Loop)。代码架构采用嵌套循环(Nested Loop)设计，旨在最大化计算效率并分摊推理开销(Inference Overhead)。外层循环对应一个完整的轮次(Epoch)，负责采样一批提示词(Prompts)并生成对应的多条回复。生成完毕后，我们计算这些回复的奖励(Rewards)，并将其转化为用于梯度更新(Gradient Update)的 Delta 信号。关键在于，我们并非在每次参数更新时都重新生成新的轨迹(Trajectory)，而是在内层循环(Inner Loop)中，将同一批固定的回复重复用于多次梯度步进(Gradient Steps)。内层循环负责计算所需的对数概率(Log-Probabilities)、构建损失函数(Loss Function)并执行优化器步进(Optimizer Step)。通过在重新采样前对固定轨迹执行多次低开销的更新，我们显著降低了高昂模型推理带来的计算负担。
![关键帧](keyframes/part006_frame_00000000.jpg)
![关键帧](keyframes/part006_frame_00006833.jpg)
![关键帧](keyframes/part006_frame_00012466.jpg)
![关键帧](keyframes/part006_frame_00018900.jpg)
![关键帧](keyframes/part006_frame_00030699.jpg)
![关键帧](keyframes/part006_frame_00036466.jpg)
![关键帧](keyframes/part006_frame_00091500.jpg)
![关键帧](keyframes/part006_frame_00104166.jpg)
![关键帧](keyframes/part006_frame_00111666.jpg)
![关键帧](keyframes/part006_frame_00123733.jpg)
![关键帧](keyframes/part006_frame_00139299.jpg)
![关键帧](keyframes/part006_frame_00148566.jpg)
![关键帧](keyframes/part006_frame_00156733.jpg)

## 三模型范式与内存优化
从概念层面来看，该算法涉及三种不同的模型状态(Model States)，且更新频率各不相同。**当前模型(Current Model)**（$\pi_\theta$）在内层优化步骤中持续更新。**旧模型(Old Model)**（$\pi_{old}$）在内层循环伊始即被冻结(Frozen)，仅用于计算 PPO/GRPO 截断机制(Clipping Mechanism)所需的概率比率(Probability Ratio)。值得注意的是，我们无需在内存中保存 $\pi_{old}$ 的完整权重副本(Weight Copy)；只需缓存(Cache)当前采样回复的对数概率即可，这能显著降低显存占用。相比之下，**参考模型(Reference Model)**（$\pi_{ref}$）则充当 KL 散度惩罚项(KL Divergence Penalty)的长期锚点(Long-term Anchor)。其更新频率极低，通常仅在完成一个完整的轮次(Epoch)后才进行。尽管 $\pi_{ref}$ 提供了稳定的正则化目标(Regularization Target)，但其代价是必须在显存(VRAM)中额外维护一份完整的模型权重副本。
![关键帧](keyframes/part006_frame_00162733.jpg)
![关键帧](keyframes/part006_frame_00177099.jpg)
![关键帧](keyframes/part006_frame_00183733.jpg)
![关键帧](keyframes/part006_frame_00189533.jpg)
![关键帧](keyframes/part006_frame_00206233.jpg)
![关键帧](keyframes/part006_frame_00227566.jpg)
![关键帧](keyframes/part006_frame_00279533.jpg)
![关键帧](keyframes/part006_frame_00310133.jpg)

## KL 惩罚与截断机制：不同的正则化作用
一个常见的疑问是：为何 KL 惩罚(KL Penalty)是针对更新缓慢的参考模型进行正则化，而非针对即时的旧策略(Old Policy)？答案在于二者承担着不同的数学角色。截断机制(Clipping Mechanism)充当**短期信任域约束(Short-term Trust Region Constraint)**，确保当前策略在单次更新批次内不会过度偏离 $\pi_{old}$。相反，KL 惩罚旨在强制执行**长期目标稳定性(Long-term Objective Stability)**。在强化学习中，我们定义并优化一个代理目标函数(Surrogate Objective Function)；若参考目标移动过快，优化尚未完成目标本身就已发生漂移，从而破坏算法的理论收敛保证。通过在较长周期内固定 $\pi_{ref}$，我们确保了模型始终在最大化一个定义明确的优化目标。在工程实践中，可通过调整 $\pi_{ref}$ 的更新频率来权衡这两种机制，但在概念层面将其解耦(Decouple)，能为训练稳定性提供更为精细的控制。
![关键帧](keyframes/part006_frame_00373599.jpg)
![关键帧](keyframes/part006_frame_00402099.jpg)
![关键帧](keyframes/part006_frame_00434166.jpg)
![关键帧](keyframes/part006_frame_00439999.jpg)
![关键帧](keyframes/part006_frame_00482333.jpg)

## 训练动态与实验结果
将本玩具实验(Toy Experiment)在“每个轮次(Epoch)包含 10 个内层步骤(Inner Steps)”的设置下运行 100 个轮次，清晰地揭示了实际的学习轨迹(Learning Trajectory)。在初始迭代中，模型生成的序列杂乱无章。策略梯度(Policy Gradient)机制会自然地将概率质量(Probability Mass)向高奖励回复倾斜，优先强化得分为 `3` 的序列而非得分为 `2` 的序列。有趣的是，即便所有采样回复均获得相同奖励，算法仍会执行参数更新，此时主要依赖对数概率的差异来维持或微调当前分布。随着训练的推进及中心化奖励(Centered Rewards)的引入，平均奖励呈现稳步上升趋势。然而，检视生成的文本可知，尽管模型已学会复现提示词中的数字并有效提升奖励得分，但它尚未完全内化底层的排序算法(Sorting Algorithm)。这一现象既印证了基于结果的奖励(Outcome-based Rewards)在引导文本生成方面的强大效力，也凸显了核心难题：在缺乏密集监督(Dense Supervision)的情况下，仅依赖纯强化学习(Pure Reinforcement Learning)来教会模型进行复杂逻辑推理具有固有的困难。
![关键帧](keyframes/part006_frame_00490633.jpg)
![关键帧](keyframes/part006_frame_00501466.jpg)
![关键帧](keyframes/part006_frame_00507533.jpg)
![关键帧](keyframes/part006_frame_00537633.jpg)
![关键帧](keyframes/part006_frame_00546066.jpg)
![关键帧](keyframes/part006_frame_00553200.jpg)
![关键帧](keyframes/part006_frame_00559133.jpg)
![关键帧](keyframes/part006_frame_00564500.jpg)
![关键帧](keyframes/part006_frame_00579733.jpg)
![关键帧](keyframes/part006_frame_00587333.jpg)
![关键帧](keyframes/part006_frame_00598833.jpg)

---

## 中心化奖励与部分得分的影响
让我们深入考察应用中心化奖励(Centered Rewards)时的训练动态(Training Dynamics)。在一个典型批次(Batch)中，各回复可能会获得 2 或 3 的原始分数(Raw Scores)。中心化机制会自然地将策略(Policy)推向高得分示例，同时抑制低得分示例。更重要的是，当所有采样回复的表现同样糟糕时，它能有效防止无意义的参数更新(Parameter Update)；若组内每条回复均获得完全相同的奖励，中心化操作将退化为产生零梯度(Zero Gradient)的空操作(No-op)，从而明智地跳过本次更新。然而，部分得分奖励(Partial Credit Rewards)已被证明是一把双刃剑。尽管它们相较于二值奖励(Binary Rewards)能提供更密集的学习信号(Learning Signal)，但也极易诱使模型陷入局部最优(Local Optimum)。例如，某条回复可能完整包含了正确数字并因此获得较高的部分得分，但却完全未执行排序操作。若策略固守这种“尚可接受”的信号，便会停止探索真正的全局最优解。这表明，审慎的奖励塑造(Reward Shaping)对于避免过早收敛(Premature Convergence)至关重要。
![关键帧](keyframes/part007_frame_00000000.jpg)
![关键帧](keyframes/part007_frame_00008766.jpg)
![关键帧](keyframes/part007_frame_00033566.jpg)
![关键帧](keyframes/part007_frame_00039533.jpg)
![关键帧](keyframes/part007_frame_00057900.jpg)

## 强化学习中损失曲线的假象
在监控训练过程时，您可能会观察到一个反直觉(Counter-intuitive)的现象：尽管平均奖励(Average Reward)稳步攀升，损失曲线(Loss Curve)却呈现出波动甚至恶化的趋势。这是因为在强化学习语境下，盲目追求损失最小化在某种程度上是一种“假象(Illusion)”。与监督学习(Supervised Learning)在固定验证集(Validation Set)上计算损失不同，强化学习的优化对象是持续动态演变的自生成数据分布(Self-generated Data Distribution)。该损失函数具有高度的自我参照性(Self-referential)，它仅依据模型当前的输出分布来评估自身的置信度(Confidence)。由于底层数据分布随每次策略更新(Policy Update)而不断漂移，缺乏稳定的参考基准，使得在时间维度上追踪损失失去了实际意义。因此，监控训练损失(Training Loss)的指导价值极为有限；奖励指标(Reward Metric)才是衡量模型真实优化进展的唯一可靠标尺。
![关键帧](keyframes/part007_frame_00068066.jpg)
![关键帧](keyframes/part007_frame_00122566.jpg)

## 强化学习：通向超人类能力的路径
尽管存在上述监控层面的复杂性，强化学习(Reinforcement Learning)依然是构建具备真正超人类能力(Superhuman Capabilities)模型的最具前景的范式(Paradigm)。依赖静态人工标注数据集(Static Human-annotated Datasets)的监督学习，从根本上将模型的能力上限(Capability Ceiling)禁锢于对现有行为的模仿(Imitation)之中。相比之下，强化学习实现了模型能力与人类演示(Human Demonstrations)的彻底解耦(Decoupling)。驱动该领域发展的核心理念极为直观：只要能够可靠地量化某一结果，便能在数学层面针对该目标进行定向优化。这使得模型得以自主发掘新颖的推理策略(Reasoning Strategies)，探索超越人类直觉的解空间(Solution Space)，并直接最大化复杂且可验证的目标(Verifiable Objectives)，而非仅仅复刻历史数据。
![关键帧](keyframes/part007_frame_00128533.jpg)
![关键帧](keyframes/part007_frame_00135166.jpg)

## 现实世界 RL 系统的工程复杂性
从概念层面审视，策略梯度(Policy Gradient)框架显得极为优雅：定义期望奖励(Expected Reward)，减去基线(Baseline)以降低方差(Variance)，随后执行优化。然而，构建生产级(Production-grade)强化学习系统的复杂度远超标准预训练(Pre-training)任务。其核心瓶颈在于模型推理(Inference)，这不仅带来庞大的计算开销(Computational Overhead)，更引发了工程调度层面的协同难题。一个高鲁棒性(Robustness)的强化学习流水线(RL Pipeline)必须高效协调多个异构模型组件：持续训练的当前策略(Current Policy)、用于 PPO 截断(PPO Clipping)的冻结旧策略(Frozen Old Policy)、服务于 KL 正则化(KL Regularization)的参考模型(Reference Model)、价值网络(Critic Network)，以及通常独立部署的环境模拟器(Environment Simulator)或智能体工作节点(Agent Worker Nodes)。在分布式硬件(Distributed Hardware)上协调这些组件、执行模型权重同步(Model Weight Synchronization)、优化显存占用(Memory Footprint)，并维持高吞吐量(High Throughput)的推理流水线，需要投入海量的系统工程(System Engineering)资源。尽管其数学基础在理论上清晰明了，但支撑强化学习高效扩展(Scaling)的底层基础设施，依然是当代人工智能研究中最活跃且最具挑战性的前沿领域之一。
![关键帧](keyframes/part007_frame_00140966.jpg)
![关键帧](keyframes/part007_frame_00182699.jpg)
![关键帧](keyframes/part007_frame_00206899.jpg)
![关键帧](keyframes/part007_frame_00214966.jpg)
![关键帧](keyframes/part007_frame_00295933.jpg)
![关键帧](keyframes/part007_frame_00364299.jpg)