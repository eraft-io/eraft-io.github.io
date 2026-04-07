## 课程引言与数据处理流程概览
这是关于数据的第二讲。在上一讲中，我们探讨了用于训练各类语言模型(Large Language Models)的不同数据集，梳理了从 BERT 到 Homo 以及其间诸多模型的发展历程。核心要点在于：数据并非凭空产生，而是分布于各类在线服务中，必须通过定向爬取(Web Crawling)或数据转储(Data Dump)来获取。获取后还需经过大量处理流程：将原始 HTML 转换为纯文本，并进行质量评估、语言识别、毒性过滤(Toxicity Filtering)以及去重(Deduplication)处理。
![关键帧](keyframes/part000_frame_00000000.jpg)
![关键帧](keyframes/part000_frame_00005200.jpg)
![关键帧](keyframes/part000_frame_00011933.jpg)
在本讲中，我们将深入剖析质量过滤(Quality Filtering)与去重的工作原理。我们将探讨基于模型的过滤算法，演示如何将这些基础算法模块灵活应用于各类过滤任务，并研究经典的去重算法。本次课程将聚焦于经典的大数据处理(Big Data Processing)技术，同时穿插一些有趣的数学原理。
![关键帧](keyframes/part000_frame_00031599.jpg)
![关键帧](keyframes/part000_frame_00039600.jpg)
![关键帧](keyframes/part000_frame_00048600.jpg)

## 过滤算法的核心目标与设计要求
数据过滤的宏观目标非常明确：给定少量高质量目标数据集 $T$ 与海量原始数据池（例如 Common Crawl），算法的目标是从原始语料库中筛选出一个与 $T$ 高度相似的子集 $T'$。这一范式构成了几乎所有数据过滤流水线(Data Pipeline)的基础。
![关键帧](keyframes/part000_frame_00088266.jpg)
![关键帧](keyframes/part000_frame_00094566.jpg)
一个成功的过滤算法必须满足两项核心要求。首先，它必须具备泛化能力(Generalization)，能够覆盖现有目标数据 $T$ 之外的样本；否则，仅检索完全一致的样本将毫无意义。其次，它必须拥有极高的运行效率。由于该算法需处理互联网规模的海量数据，若部署庞大的神经模型(Neural Models)，其计算成本将与下游模型的实际训练成本相当，这显然违背了数据预处理的初衷。因此，我们将重点探讨如何采用高效且高度可扩展的方法，来实现这一基础算法组件。
![关键帧](keyframes/part000_frame_00100600.jpg)
![关键帧](keyframes/part000_frame_00115200.jpg)
![关键帧](keyframes/part000_frame_00124866.jpg)
![关键帧](keyframes/part000_frame_00131633.jpg)
![关键帧](keyframes/part000_frame_00138433.jpg)
![关键帧](keyframes/part000_frame_00144533.jpg)
![关键帧](keyframes/part000_frame_00154766.jpg)
![关键帧](keyframes/part000_frame_00161299.jpg)

## N-Gram 语言模型与 Kneser-Ney 平滑技术
第一种过滤方法基于 N-Gram 语言模型(N-Gram Language Model)，通常借助 KenLM 等工具并结合 Kneser-Ney 平滑(Kneser-Ney Smoothing)技术进行训练。该方法虽源于传统自然语言处理(Natural Language Processing, NLP)时代，但凭借其简洁高效的特点至今依然广受青睐。拟合 N-Gram 模型的本质在于统计 N-Gram 序列的出现频次并进行归一化处理，从而估计最大似然语言模型(Maximum Likelihood Language Model)。对于给定上下文，条件概率 $P(w | \text{context})$ 的计算方式，是将该 N-Gram 的频次除以对应的 $(n-1)$-gram 上下文频次。
![关键帧](keyframes/part000_frame_00171299.jpg)
![关键帧](keyframes/part000_frame_00207333.jpg)
![关键帧](keyframes/part000_frame_00229633.jpg)
N-Gram 模型面临的主要挑战在于数据稀疏性。随着 $n$ 值增大，许多合乎语法的 N-Gram 在训练语料库中的出现频次为零，模型极易遭遇维度灾难(Curse of Dimensionality)。为缓解这一问题，研究者提出了 Kneser-Ney 平滑技术。该技术通过回退至低阶上下文（例如，移除上下文中的某个词并检查其剩余频次）来处理未见过的 N-Gram，并采用插值法(Interpolation)为其分配合理的概率。即便在当今深度神经网络(Deep Neural Networks)盛行的时代，深入理解这些经典的 N-Gram 机制仍具有重要的学术与工程价值。
![关键帧](keyframes/part000_frame_00241199.jpg)
![关键帧](keyframes/part000_frame_00285299.jpg)
![关键帧](keyframes/part000_frame_00317666.jpg)
![关键帧](keyframes/part000_frame_00324766.jpg)

## 困惑度评估与 CCNet 过滤实践
若要将 N-Gram 模型应用于数据过滤，我们可以下载在特定语料（如 Wikipedia）上预训练的模型，并利用困惑度(Perplexity)对候选文本进行打分。困惑度用于衡量概率语言模型预测样本的准确程度；得分越低，表明文本越自然、语法越规范。例如，“Stanford University was found in 1885”这类标准句子的困惑度约为 187，处于合理区间。而来自专业课程网站等领域的文本，尽管语法正确，但由于其表达风格在维基百科语料中较为罕见，因此会获得较高的困惑度。相反，诸如“ASDF”这类无意义的随机乱码，则会获得极高的困惑度得分。
![关键帧](keyframes/part000_frame_00335466.jpg)
![关键帧](keyframes/part000_frame_00341466.jpg)
![关键帧](keyframes/part000_frame_00350066.jpg)
![关键帧](keyframes/part000_frame_00356900.jpg)
![关键帧](keyframes/part000_frame_00368133.jpg)
尽管 N-Gram 模型相对粗糙，偶尔会对特定短语产生误判，但数据过滤算法无需追求完美。其核心诉求在于运行速度足够快，且在过滤任务中能达到可接受的精度。一个典型的成功案例是 Facebook 提出的 CCNet 流水线。该方法正是运用了这一启发式策略(Heuristic Strategy)：对 Common Crawl 中的网页段落进行困惑度评分与排序，并保留得分最优的前三分之一数据作为高质量语料。该过滤后的数据集在构建初代 LLaMA 模型的训练数据中发挥了关键作用，充分验证了简单高效的启发式算法在大规模工程应用中的巨大价值。
![关键帧](keyframes/part000_frame_00402666.jpg)
![关键帧](keyframes/part000_frame_00413699.jpg)
![关键帧](keyframes/part000_frame_00438599.jpg)
![关键帧](keyframes/part000_frame_00445599.jpg)
![关键帧](keyframes/part000_frame_00455333.jpg)
![关键帧](keyframes/part000_frame_00466766.jpg)
![关键帧](keyframes/part000_frame_00487533.jpg)

## FastText：高效的线性文本分类器
除基于困惑度的过滤外，另一种广受欢迎的方案是 FastText 文本分类器，该工具同样由 Facebook 研发。FastText 于 2016 年发布，彼时学术界正热衷于构建复杂的深度学习架构。FastText 的出现证明，近乎线性的分类模型同样能够取得与深度神经网络相媲美的性能，且其训练与推理速度实现了数量级的提升，因而成为处理海量数据的理想选择。
![关键帧](keyframes/part000_frame_00493766.jpg)
![关键帧](keyframes/part000_frame_00501166.jpg)
![关键帧](keyframes/part000_frame_00511533.jpg)
![关键帧](keyframes/part000_frame_00519000.jpg)
FastText 的设计初衷旨在突破传统词袋模型(Bag-of-Words, BoW)在文本分类中的局限。假设句子长度为 $L$，词汇表大小为 $V$，类别数为 $K$，传统的直接线性分类器(Linear Classifier)需要维护一个维度为 $V \times K$ 的参数矩阵。当 $V$ 与 $K$ 极大时，这将引发严重的参数稀疏性问题与巨大的内存开销。FastText 通过高效的矩阵运算优化与线性分类策略成功克服了这一瓶颈。作为一个强大且高度可扩展的基础组件，它常被部署于数据预处理阶段，用于在原始网页数据输入下游模型训练前进行快速筛选与过滤。
![关键帧](keyframes/part000_frame_00526600.jpg)
![关键帧](keyframes/part000_frame_00536200.jpg)
![关键帧](keyframes/part000_frame_00544166.jpg)
![关键帧](keyframes/part000_frame_00558033.jpg)
![关键帧](keyframes/part000_frame_00564500.jpg)
![关键帧](keyframes/part000_frame_00587400.jpg)
![关键帧](keyframes/part000_frame_00598166.jpg)

---

## FastText 架构与降维技术
FastText 通过降维技术(Dimensionality Reduction)有效解决了传统词袋模型(Bag-of-Words, BoW)中的参数量爆炸(Parameter Explosion)问题。它并非将整个词汇空间直接映射至输出类别，而是先将词汇投影至一个规模小得多的隐藏维度(Hidden Dimension) $h$ 中，该维度可远小于类别数 $K$（例如 $h=16$）。随后，前向传播(Forward Propagation)转化为基于隐藏层 $h$ 的直接线性分类过程，其原理类似于矩阵分解(Matrix Factorization)，从而大幅削减了模型参数量。该架构针对计算性能进行了深度优化，实现了完全并行化(Fully Parallelized)，并采用异步随机梯度下降(Asynchronous SGD)以加速训练。
![关键帧](keyframes/part001_frame_00000000.jpg)
![关键帧](keyframes/part001_frame_00009999.jpg)
![关键帧](keyframes/part001_frame_00036800.jpg)
![关键帧](keyframes/part001_frame_00043366.jpg)

## 用于 N-Gram 特征的哈希技巧
尽管词袋模型能够捕获基础的词汇信息，但引入 N-Gram 特征可提供更为丰富的上下文语义。然而，N-Gram 的词表规模极易急剧膨胀甚至趋于无限。FastText 借助哈希技巧(Hashing Trick)巧妙化解了这一难题。系统预先设定固定数量的哈希桶(Hash Buckets)（例如 1000 万个），并将每个 N-Gram 映射至对应的桶中。尽管该操作会引入哈希冲突(Hash Collisions)，但模型在损失函数最小化(Loss Minimization)过程中能够优雅地处理此类冲突：共享权重会自然收敛至冲突特征的统计均值。该方法在处理二分类任务(Binary Classification)（如鉴别优质与劣质文档）时尤为高效，可作为高速线性二分类器(Linear Binary Classifier)使用。
![关键帧](keyframes/part001_frame_00050766.jpg)
![关键帧](keyframes/part001_frame_00056666.jpg)
![关键帧](keyframes/part001_frame_00065500.jpg)
![关键帧](keyframes/part001_frame_00074700.jpg)
![关键帧](keyframes/part001_frame_00091433.jpg)
![关键帧](keyframes/part001_frame_00097233.jpg)
![关键帧](keyframes/part001_frame_00102800.jpg)
![关键帧](keyframes/part001_frame_00112433.jpg)
![关键帧](keyframes/part001_frame_00120433.jpg)

## 大规模过滤中的计算权衡
尽管 FastText 等线性模型相较于现代深度学习架构显得较为简易，但理论上完全可以直接部署 BERT 或 LLaMA 等复杂模型执行数据过滤。其核心瓶颈在于计算开销(Computational Cost)。由于网页语料库(Web Corpus)规模极其庞大，若需从中筛选出极小比例（例如 1%）的高质量数据，则要求过滤流水线(Processing Pipeline)本身的运行成本必须极低。若采用大型神经网络模型(Large Neural Network Models)进行分类，过滤阶段消耗的计算资源甚至可能逼近或超越最终目标模型的训练成本。因此，在处理 TB 级(Terabyte-scale)原始网页数据时，轻量级模型(Lightweight Models)的推理速度与计算效率显得尤为关键。
![关键帧](keyframes/part001_frame_00204633.jpg)

## 用于数据选择的重要性重采样
另一种具备坚实理论支撑的数据筛选方法是重要性重采样(Importance Resampling)，该技术广泛应用于粒子滤波(Particle Filtering)与蒙特卡洛方法(Monte Carlo Methods)中。其核心逻辑在于：当仅能从提议分布(Proposal Distribution) $Q$ 中获取样本时，如何有效实现从目标分布(Target Distribution) $P$ 中采样。具体步骤为：首先从 $Q$ 中抽取样本，并计算每个样本的重要性权重(Importance Weights)，即概率密度比值 $P/Q$。该权重用于校正采样偏差(Sampling Bias)，经归一化(Normalization)处理后，再依新权重执行重采样(Resampling)。此过程能有效重新平衡数据集，将概率质量(Probability Mass)从 $Q$ 中过采样(Over-represented)的区域，转移至 $P$ 中欠采样(Under-represented)却极具价值的区域。
![关键帧](keyframes/part001_frame_00210666.jpg)
![关键帧](keyframes/part001_frame_00216333.jpg)
![关键帧](keyframes/part001_frame_00239799.jpg)
![关键帧](keyframes/part001_frame_00246499.jpg)
![关键帧](keyframes/part001_frame_00263766.jpg)
![关键帧](keyframes/part001_frame_00272066.jpg)
![关键帧](keyframes/part001_frame_00281166.jpg)
![关键帧](keyframes/part001_frame_00289300.jpg)
![关键帧](keyframes/part001_frame_00300966.jpg)
![关键帧](keyframes/part001_frame_00325799.jpg)
![关键帧](keyframes/part001_frame_00340066.jpg)

## 用于分布估计的哈希 N-Grams
将重要性重采样应用于真实数据集时，首要任务是对小型目标数据集与海量原始（提议）数据集的概率分布进行估计。由于目标数据集规模通常过小，难以拟合稳健的统计模型，因此再次引入基于哈希的 N-Gram 方法。具体而言，文本首先被拆分为一元语法(Unigram)，随后将每个词哈希映射至固定桶中，并通过统计桶内频次来估算概率。在评估新文本时，将其各哈希成分的概率值相乘。尽管哈希函数(Hash Function)在不同次运行中可能存在差异，且哈希冲突难以完全避免，但引入平滑技术(Smoothing Techniques)可有效规避零概率问题(Zero-Probability Issue)。这种虽显粗犷但具备卓越可扩展性(Scalability)的概率估计方法，在数据选择(Data Selection)任务中已被证实极为有效。
![关键帧](keyframes/part001_frame_00349266.jpg)
![关键帧](keyframes/part001_frame_00365033.jpg)
![关键帧](keyframes/part001_frame_00379433.jpg)
![关键帧](keyframes/part001_frame_00398833.jpg)
![关键帧](keyframes/part001_frame_00408299.jpg)
![关键帧](keyframes/part001_frame_00419633.jpg)
![关键帧](keyframes/part001_frame_00450899.jpg)
![关键帧](keyframes/part001_frame_00467733.jpg)

## 方法对比与通用过滤框架
相较于 FastText，重要性重采样具备一项显著优势：其优化目标明确指向拟合目标分布，从而能显著提升筛选数据的多样性(Data Diversity)。反观 FastText，其仅负责判别样本是否属于目标类别，无法保证输出数据与目标分布的一致性(Distributional Consistency)。上述两种方法均可通过替换更强大的基础模型(Base Models)（如高阶 N-Gram 或神经网络架构）进行迭代优化，但其核心逻辑在所有现代数据过滤技术中保持高度一致。面对“小规模目标数据集 + 海量原始数据集”的场景，通用流水线(Universal Pipeline)的标准范式为：训练一个评分模型(Scoring Model)，将其应用于原始语料库进行批量打分，并截留得分最高的优质样本。这一简洁且高度可扩展(Scalable)的方案，正是构建大语言模型(Large Language Models, LLMs)高质量训练数据的基石。
![关键帧](keyframes/part001_frame_00478033.jpg)
![关键帧](keyframes/part001_frame_00484133.jpg)
![关键帧](keyframes/part001_frame_00555933.jpg)
![关键帧](keyframes/part001_frame_00566166.jpg)
![关键帧](keyframes/part001_frame_00573733.jpg)
![关键帧](keyframes/part001_frame_00599066.jpg)

---

## 数据过滤的统一框架
本文探讨的各类过滤技术均建立在相同的底层架构之上。在 KenLM 中，评分(Score)即为文本在目标 N-Gram 模型下的概率或归一化困惑度(Normalized Perplexity)，仅保留超过设定阈值（可能包含轻微随机扰动）的样本。对于 FastText 等判别式分类器(Discriminative Classifier)，评分代表给定样本来源于目标数据集（而非原始语料库）的概率，同样依赖阈值机制(Thresholding Mechanism)进行筛选。重要性重采样则采用生成式方法(Generative Approach)，以两个生成模型的概率比值（如目标分布与原始分布之比）作为评分，并依据这些重要性权重(Importance Weights)按比例执行重采样。宏观而言，所有方法均遵循统一的范式：训练一个模型以刻画目标数据特征，据此对原始数据集进行批量评分，并最终截留得分最高的优质样本。
![关键帧](keyframes/part002_frame_00000000.jpg)
![关键帧](keyframes/part002_frame_00044300.jpg)
![关键帧](keyframes/part002_frame_00091466.jpg)

## 局部上下文模型的局限性
针对此类模型（尤其是 N-Gram 方法），一个普遍的疑问在于：它们仅评估局部的词语共现关系(Word Co-occurrence)，缺乏全局语义理解(Global Semantic Understanding)能力。因此，一篇 N-Gram 组合完全合法但句序被彻底打乱的文档，仍可能获得高分。尽管这使模型在一定程度上易受对抗性干扰(Adversarial Perturbation)或“局部连贯但整体无意义”文本的影响，但其在数据处理流水线(Data Processing Pipeline)中的核心目的并非确保深层逻辑一致性，而是高效剔除真正的低质乱码与无意义文本。若需捕获更广泛的上下文信息，可通过提升 N-Gram 模型中的 `n` 值或引入更复杂的模型架构来缓解此局限。然而在大规模预处理场景中，此类轻量级模型(Lightweight Models)能够以极低的计算开销，高效滤除质量最差的样本。
![关键帧](keyframes/part002_frame_00127233.jpg)
![关键帧](keyframes/part002_frame_00143399.jpg)
![关键帧](keyframes/part002_frame_00157533.jpg)

## 语言识别与计算权衡
该过滤机制具备高度通用性，不仅适用于通用质量过滤，还可广泛应用于语言识别(Language Identification)等任务。在计算资源受限的前提下，若专为特定语言（如英语或日语）清洗数据，直接使用庞大的多语言语料库(Multilingual Corpus)进行训练反而可能适得其反。将 Token 数量分配给无关语言会稀释计算预算(Computational Budget)，进而可能导致模型在目标语言上的性能受损。例如，BLOOM 模型仅分配了 30% 的训练数据给英语，相较于专注单语言的模型，这在一定程度上限制了其英语能力。然而，只要模型容量(Model Capacity)充足，大规模多语言训练不仅切实可行，甚至能产生积极的跨语言正迁移(Cross-lingual Positive Transfer)效应。
![关键帧](keyframes/part002_frame_00167466.jpg)
![关键帧](keyframes/part002_frame_00210466.jpg)
![关键帧](keyframes/part002_frame_00227299.jpg)

## 基于 FastText 的实际应用
一种切实可行的方案是直接复用现成模型，例如在多语言维基百科与新闻语料库上预训练的 FastText 语言识别分类器。Dolma 等数据集便采用了该策略，仅保留英语概率高于 0.5 的文档。实测表明该模型性能稳健：它能准确识别英语与德语，且对文本重复复制不敏感，输出概率保持稳定；面对混合语言输入时，模型亦会倾向于识别占主导地位的语言(Dominant Language)。然而，该模型在处理短句、低资源语言(Low-Resource Languages)、与标准英语高度近似的方言，以及语码转换(Code-Switching)场景时表现欠佳。上述局限表明，尽管此类分类器部署便捷，但在实际工程应用中，仍需针对具体场景精细调整阈值(Threshold Tuning)并进行充分验证。
![关键帧](keyframes/part002_frame_00242066.jpg)
![关键帧](keyframes/part002_frame_00250099.jpg)

## 案例研究：OpenWebMath 数据筛选
相同的过滤流水线在垂直领域数据筛选中同样表现优异，OpenWebMath 项目便是一个典型案例。该项目将数学文本视为一种独立“语言”，研究团队首先部署了基于规则的过滤器(Rule-based Filter)，随后在 ProofPile 数据集上训练 KenLM 模型，利用困惑度阈值对数学相关内容进行打分。此外，团队还结合了一个针对数学文本识别专项调优的 FastText 分类器，并引入动态阈值策略(Dynamic Thresholding Strategy)：对于已被规则标记为数学内容的文档，适当降低分类器置信度阈值(Confidence Threshold)；而对于边界模糊的文档，则要求更高的得分方可保留。这种混合方法(Hybrid Approach)成功构建了一个包含 150 亿 Token 的高质量数学语料库。值得注意的是，在该精选数据集上训练的模型，其性能显著超越了使用规模大 20 倍但缺乏针对性筛选的数据集所训练的基线模型(Baseline Model)，这充分印证了精准数据选择(Precise Data Selection)的核心价值。
![关键帧](keyframes/part002_frame_00343366.jpg)
![关键帧](keyframes/part002_frame_00397099.jpg)
![关键帧](keyframes/part002_frame_00405633.jpg)
![关键帧](keyframes/part002_frame_00413799.jpg)
![关键帧](keyframes/part002_frame_00420033.jpg)
![关键帧](keyframes/part002_frame_00437366.jpg)
![关键帧](keyframes/part002_frame_00481533.jpg)
![关键帧](keyframes/part002_frame_00539466.jpg)

---

## 定向数据过滤的实用价值
OpenWebMath 案例充分展示了定向数据过滤(Targeted Data Filtering)的实用价值。与其在海量且未经筛选的原始语料库(Raw Corpus)上进行训练，不如聚焦于数学等特定垂直领域，从而实现高度数据高效(Data-Efficient)的模型训练。通过有针对性地筛选与整理领域数据集(Domain-Specific Dataset)，研究人员能够以显著更少的 Token 数量获得卓越的性能，其效果远胜于在缺乏专业聚焦的通用数据(General-purpose Data)上进行训练。
![关键帧](keyframes/part003_frame_00000000.jpg)
![关键帧](keyframes/part003_frame_00023933.jpg)

## 质量过滤策略的演进
质量过滤(Quality Filtering)已从早期的宽泛概念演进为现代数据处理流水线(Data Processing Pipeline)的基石。尽管早期研究有时倾向于回避基于模型的过滤方法(Model-based Filtering)，但近期工作已充分证实其有效性。例如，GPT-3 训练了一个线性分类器(Linear Classifier)，将高质量的非 Common Crawl 数据作为正例(Positive Examples)，原始 Common Crawl 数据作为负例(Negative Examples)，并通过设定更严格的阈值(Threshold)仅保留最优文档。同样，初代 LLaMA 的研究将引用维基百科来源的网页作为正例，与 Common Crawl 负例进行对比训练，从而筛选并保留高信息密度(Information Density)的文档。
![关键帧](keyframes/part003_frame_00051500.jpg)
![关键帧](keyframes/part003_frame_00063733.jpg)

## Phi-1 范式：大语言模型引导的数据筛选
Phi-1 论文引入了一种以教科书为导向(Textbook-Oriented)的高效过滤理念，旨在训练小型语言模型(Small Language Models, SLMs)。作者并未依赖静态的数据源启发式规则(Static Data Source Heuristics)，而是利用 GPT-4 依据对初学者的教育价值(Educational Value)，对 10 万份 Python 代码文档进行了标注。这些标注数据构成目标数据集，结合预训练代码模型提取的嵌入向量(Embeddings)，用于训练一个随机森林分类器(Random Forest Classifier)。随后，该经知识蒸馏(Knowledge Distillation)得到的分类器被应用于完整的 Stack 数据集，以筛选高质量的教育类代码。结果令人瞩目：经此过滤的数据训练出的模型仅需 3.6 万步(Training Steps)，便在 HumanEval 基准测试上达到了 17% 的通过率(Pass@1)，显著优于训练 9.6 万步（通过率 12%）的基线模型(Baseline Model)。
![关键帧](keyframes/part003_frame_00093766.jpg)
![关键帧](keyframes/part003_frame_00101600.jpg)
![关键帧](keyframes/part003_frame_00200966.jpg)
该方法凸显了一种范式转变(Paradigm Shift)：研究人员无需再手动整理维基百科或专业书籍等目标数据源，先进的大语言模型(Large Language Models, LLMs)现已能够按需生成高质量的目标分布(Target Distribution)。在小规模子集（如 10 万个样本）上使用 GPT-4 等强大模型进行标注，进而提炼出一个快速且低成本的轻量级分类器，在计算上完全可行。这种“大模型标注、小模型筛选”的策略，有效规避了直接在数亿份文档上运行大语言模型所带来的高昂计算成本(Computational Cost)。
![关键帧](keyframes/part003_frame_00237733.jpg)

## 实践中的毒性过滤
除了数据质量与领域特异性(Domain Specificity)之外，毒性过滤(Toxicity Filtering)对于模型的安全部署(Safe Deployment)至关重要。Dolma 数据集流水线采用了 Jigsaw 有毒评论数据集(Jigsaw Toxic Comment Dataset)来应对这一挑战。该数据集源于改善网络言论环境的倡议，对维基百科讨论页中的评论进行了毒性(Toxicity)、严重毒性(Severe Toxicity)、威胁(Threat)及淫秽内容(Obscenity)的多维度标注。Dolma 基于此训练了两个独立的 FastText 分类器：一个专门用于检测仇恨言论(Hate Speech)，另一个用于识别 NSFW（Not Safe For Work，不适宜工作场所）内容。测试表明，这些分类器能有效区分良性讨论与被标记的有害内容，为训练前过滤有害语言提供了一套高度可扩展(Scalable)的解决方案。
![关键帧](keyframes/part003_frame_00264800.jpg)
![关键帧](keyframes/part003_frame_00271099.jpg)
![关键帧](keyframes/part003_frame_00322433.jpg)

## 去重：精确重复与近似重复
过滤流程完成后，去重(Deduplication)环节变得至关重要。网络爬取(Web Crawling)的数据天然包含海量冗余，主要呈现为两种形式。精确重复(Exact Duplicates)通常源于网站镜像(Website Mirroring)；例如，在爬取古登堡计划(Project Gutenberg)时，多个不同的 URL 往往返回完全一致的内容。近似重复(Near Duplicates)则指仅存在少量 Token 差异的文本，例如被广泛复制粘贴的开源许可证（如 MIT 协议）、因缺失逗号等产生的微小处理错误，或是基于模板生成的文章（仅替换了国家名称等命名实体，而上下文结构完全一致）。在此类冗余数据上进行训练不仅会导致模型学习的边际收益递减(Diminishing Marginal Returns)，还可能引发模型分布偏移(Model Distribution Shift)。
![关键帧](keyframes/part003_frame_00329000.jpg)
![关键帧](keyframes/part003_frame_00337133.jpg)
![关键帧](keyframes/part003_frame_00371700.jpg)
![关键帧](keyframes/part003_frame_00378333.jpg)
![关键帧](keyframes/part003_frame_00384766.jpg)

## 数据冗余的极端案例
原始网页数据集中的冗余规模往往令人震惊。在 C4 数据集中，研究人员发现某一句连贯的英文句子重复出现了超过 6.1 万次。经溯源分析，此类极端重复通常可归因于样板文本(Boilerplate Text)，例如 Cookie 同意横幅(Cookie Consent Banners)或数百万网站通用的标准化法律声明。识别并剔除这些精确重复与近似重复是数据预处理(Data Preprocessing)中的关键步骤，因为它们会无谓消耗宝贵的训练计算资源，却无法为模型贡献任何具有实际价值的语言模式或事实多样性(Factual Diversity)。
![关键帧](keyframes/part003_frame_00393933.jpg)
![关键帧](keyframes/part003_frame_00415200.jpg)
![关键帧](keyframes/part003_frame_00426900.jpg)
![关键帧](keyframes/part003_frame_00447766.jpg)
![关键帧](keyframes/part003_frame_00481633.jpg)
![关键帧](keyframes/part003_frame_00496099.jpg)
![关键帧](keyframes/part003_frame_00502333.jpg)
![关键帧](keyframes/part003_frame_00521633.jpg)
![关键帧](keyframes/part003_frame_00536800.jpg)
![关键帧](keyframes/part003_frame_00591166.jpg)
![关键帧](keyframes/part003_frame_00598733.jpg)
![关键帧](keyframes/part003_frame_00604466.jpg)

---

## 去重的作用与优势
原始网页爬取数据(Raw Web Crawled Data)通常包含极高的冗余度。例如，亚马逊产品描述中的某句连贯英文可能在互联网的不同网站上重复出现超过 6.1 万次。尽管这些文本本身质量尚可，但在 6.1 万个完全相同的副本上训练模型是对计算资源的极大浪费。这凸显了质量过滤(Quality Filtering)与去重(Deduplication)的核心区别：前者会直接剔除不合格数据，而后者则旨在保留有效但高度重复内容的单一代表性实例(Representative Instance)。实施去重主要带来两大优势：一是通过减少冗余 Token 的处理显著提升了训练效率(Training Efficiency)；二是有效降低了模型记忆(Model Memorization)的风险，这对于缓解版权纠纷与隐私泄露问题至关重要。
![关键帧](keyframes/part004_frame_00000000.jpg)
![关键帧](keyframes/part004_frame_00007533.jpg)
![关键帧](keyframes/part004_frame_00016866.jpg)
![关键帧](keyframes/part004_frame_00053666.jpg)

## 设计空间与算法挑战
去重算法的设计通常围绕三个关键维度展开：比较粒度(Granularity)（如句子、段落或文档）、匹配标准(Matching Criteria)（精确匹配 Exact Match vs. 模糊/部分重叠 Fuzzy/Partial Overlap）以及移除策略(Removal Strategy)（删除所有副本 vs. 仅保留单一实例）。其核心算法挑战在于，去重本质上是一个两两比较(Pairwise Comparison)问题。质量分类(Quality Classification)可独立且并行地作用于各个数据项，而去重则必须执行数据项间的交叉比对。对于包含数亿文档的数据集，朴素的 $O(N^2)$ 复杂度比较算法(Naive Quadratic Complexity Algorithm)在计算上完全不可行。因此，具备可扩展性(Scalability)的去重方案必须依赖能够维持并行处理能力(Parallel Processing)的线性时间(Linear Time)或近似线性时间(Near-Linear Time)算法。
![关键帧](keyframes/part004_frame_00099866.jpg)
![关键帧](keyframes/part004_frame_00143533.jpg)

## 哈希函数：核心基础组件
实现可扩展去重(Scalable Deduplication)的基础构建模块(Fundamental Building Block)是哈希函数(Hash Function)，它负责将大型对象（如字符串或完整文档）映射为紧凑的整数或字符串表示。在密码学场景(Cryptographic Applications)中，系统的安全性高度依赖抗碰撞性(Collision Resistance)，因此哈希冲突(Hash Collisions)通常不可接受；但在优先考虑处理速度的数据流水线中，这类冲突是可控且易于管理的。针对去重任务，业界普遍采用 MurmurHash 等快速、非密码学哈希函数(Non-cryptographic Hash Function)。此类算法以牺牲严格的抗碰撞性为代价，换取了极高的计算效率(Computational Efficiency)，从而能够在海量语料库(Massive Corpus)中实现极速的索引建立与数据比对。
![关键帧](keyframes/part004_frame_00173799.jpg)
![关键帧](keyframes/part004_frame_00182600.jpg)
![关键帧](keyframes/part004_frame_00219733.jpg)

## 基于哈希映射的精确去重
实现精确去重(Exact Deduplication)的一种直观方法是：为每个数据项计算哈希值，将哈希值相同的项映射至同一分组(Bucket)，并在各组内仅保留单一实例。该方法精度极高、实现简单，且在 MapReduce 等分布式框架(Distributed Frameworks)中展现出优异的可扩展性。例如，C4 数据集对包含三句话的文本片段(Text Snippets)实施精确去重，在剔除冗余内容的同时保留一个副本。然而，这种细粒度方法存在显著缺陷：精准剔除重复片段可能会破坏文档的连贯性，导致文本碎片化(Text Fragmentation)或上下文断裂(Contextual Disruption)。尽管部分处理流水线选择容忍此问题，但它仍是细粒度精确匹配(Fine-grained Exact Matching)在实际应用中的主要局限性。
![关键帧](keyframes/part004_frame_00258066.jpg)
![关键帧](keyframes/part004_frame_00266766.jpg)
![关键帧](keyframes/part004_frame_00279533.jpg)
![关键帧](keyframes/part004_frame_00296666.jpg)
![关键帧](keyframes/part004_frame_00328333.jpg)
![关键帧](keyframes/part004_frame_00345799.jpg)

## 布隆过滤器简介
为追求更高的内存效率(Memory Efficiency)与可扩展性，布隆过滤器(Bloom Filter)提供了一种极为强大的概率数据结构(Probabilistic Data Structure)。该结构用于近似集合成员资格查询(Approximate Set Membership Query)，具备两大核心特性：保证无假阴性(Guaranteed Zero False Negatives)（即若判定某元素不存在，则必然不存在）；但允许出现假阳性(False Positives)（即若判定某元素存在，则该元素可能存在，但不保证绝对存在）。通过调整位数组大小与哈希函数数量，可灵活控制假阳性率(False Positive Rate)。布隆过滤器空间占用高度紧凑(Space-efficient)，支持常数时间的快速更新，且无需存储原始数据项，使其成为内存受限环境(Memory-constrained Environments)下执行流式去重(Streaming Deduplication)的理想方案。
![关键帧](keyframes/part004_frame_00356066.jpg)
![关键帧](keyframes/part004_frame_00401666.jpg)
![关键帧](keyframes/part004_frame_00412166.jpg)
![关键帧](keyframes/part004_frame_00441666.jpg)

## 布隆过滤器的工作原理与假阳性
构建布隆过滤器需初始化一个固定长度的位数组(Bit Array)（例如 8 位），并对每个输入元素应用一个或多个独立的哈希函数。哈希值计算出的索引位置将被置为 1。在执行成员资格查询(Member Query)时，对测试元素应用相同的哈希函数；若所有对应的位均已被置为 1，则过滤器判定该元素“可能存在”。在一个包含 5 个元素与 8 个位的示例中，所有已插入元素均被正确识别。然而，当查询未插入的元素时，由于哈希映射导致的位重叠(Bit Overlap)，某些非成员元素可能错误地触发“存在”判定，从而产生假阳性(False Positives)（在此微型示例中假阳性率达 0.44）。在实际生产环境(Production Environments)中，通过扩大位数组容量并优化哈希函数数量，可将假阳性率压缩至极低水平，进而支撑高效的大规模去重(Large-scale Deduplication)作业。
![关键帧](keyframes/part004_frame_00478766.jpg)
![关键帧](keyframes/part004_frame_00500000.jpg)
![关键帧](keyframes/part004_frame_00506466.jpg)
![关键帧](keyframes/part004_frame_00520433.jpg)
![关键帧](keyframes/part004_frame_00539600.jpg)
![关键帧](keyframes/part004_frame_00551900.jpg)
![关键帧](keyframes/part004_frame_00565033.jpg)
![关键帧](keyframes/part004_frame_00598966.jpg)

---

## 通过多哈希函数优化布隆过滤器
布隆过滤器(Bloom Filter)的假阳性率(False Positive Rate)与可用哈希位(Hash Bits)的数量成反比。然而，若仅通过盲目扩大位数组(Bit Array)来追求极低的错误概率（例如 $10^{-10}$），将导致内存消耗难以承受。一种更高效的解决方案是在固定大小的位数组上并行应用多个哈希函数($k$ 个)。与仅对元素执行单次哈希不同，该策略对每个元素执行 $k$ 次独立哈希，并将对应的 $k$ 个位位置全部置为 1。在执行成员资格查询(Membership Query)时，仅当 *所有* $k$ 个哈希位均已被置为 1 时，才判定该元素存在。这种多哈希策略(Multi-Hash Strategy)在不增加内存占用的前提下显著降低了假阳性率，使工程师能够以适度的计算开销(Computational Overhead)将错误率压制至极低水平。
![关键帧](keyframes/part005_frame_00000000.jpg)
![关键帧](keyframes/part005_frame_00030033.jpg)
![关键帧](keyframes/part005_frame_00035733.jpg)
![关键帧](keyframes/part005_frame_00043133.jpg)
![关键帧](keyframes/part005_frame_00051566.jpg)
![关键帧](keyframes/part005_frame_00074000.jpg)
![关键帧](keyframes/part005_frame_00082400.jpg)
![关键帧](keyframes/part005_frame_00103666.jpg)
![关键帧](keyframes/part005_frame_00120566.jpg)

## 假阳性率的数学分析
从数学形式上，假阳性概率(False Positive Probability)可进行逐步推导。对于单个元素与单个哈希函数，其命中特定位的概率仅为 $1/m$（其中 $m$ 为位数组总位数）。当对 $n$ 个元素应用 $k$ 个哈希函数时，在所有元素插入完毕后，某一特定位仍保持为 0 的概率为 $(1 - 1/m)^{kn}$。相应地，该位被置为 1 的概率则为 $1 - (1 - 1/m)^{kn}$。若要使某个待测元素触发假阳性，其对应的 $k$ 个哈希位必须恰好全部为 1，由此推导出假阳性率公式 $f = [1 - (1 - 1/m)^{kn}]^k$。通过调节哈希函数数量 $k$，该错误率可呈指数级下降（例如从 0.63 骤降至 0.01）。数学分析表明，存在最优参数 $k \approx (m/n) \ln 2$ 可使误差最小化，理论上能将假阳性率压缩至 $(0.5)^k$。
![关键帧](keyframes/part005_frame_00153766.jpg)
![关键帧](keyframes/part005_frame_00160333.jpg)
![关键帧](keyframes/part005_frame_00196799.jpg)
![关键帧](keyframes/part005_frame_00280966.jpg)
![关键帧](keyframes/part005_frame_00291666.jpg)
![关键帧](keyframes/part005_frame_00312799.jpg)
![关键帧](keyframes/part005_frame_00341766.jpg)
![关键帧](keyframes/part005_frame_00379099.jpg)
![关键帧](keyframes/part005_frame_00398333.jpg)
![关键帧](keyframes/part005_frame_00407066.jpg)
![关键帧](keyframes/part005_frame_00415700.jpg)
![关键帧](keyframes/part005_frame_00430099.jpg)
![关键帧](keyframes/part005_frame_00437433.jpg)

## 超参数调优与实际应用
哈希函数数量($k$)与假阳性率之间呈非单调关系(Non-monotonic Relationship)。哈希函数过少会导致判别力不足(Discriminatory Power)，而过多的哈希函数则会迅速使位数组趋于全 1 状态（即饱和 Saturation），反而会导致假阳性率上升。工程师必须仔细权衡内存容量($m$)、预期数据规模($n$)、计算开销($k$)以及可接受的错误容忍度(Error Tolerance)。在 Dolma 等生产级流水线(Production Pipeline)中，这些原则得到了严格贯彻：系统针对段落级精确去重(Paragraph-level Exact Deduplication)专门配置了布隆过滤器，并将假阳性率目标设定为极其严格的 $10^{-15}$，从而确保了近乎完美的过滤精度(Filtering Precision)。
![关键帧](keyframes/part005_frame_00454200.jpg)
![关键帧](keyframes/part005_frame_00466733.jpg)
![关键帧](keyframes/part005_frame_00500266.jpg)
![关键帧](keyframes/part005_frame_00519000.jpg)
![关键帧](keyframes/part005_frame_00525533.jpg)

## 近似去重与 Jaccard 相似度
尽管精确去重(Exact Deduplication)能高效剔除完全一致的副本，但它无法识别“近似重复”(Near Duplicates)——即核心语义相同，仅存在细微编辑、标点遗漏或轻微改写(Paraphrasing)的文本。解决该问题需引入基于定量相似度度量的近似成员检测(Approximate Membership Detection)。该场景下的标准评估指标为 Jaccard 相似度(Jaccard Similarity)，其定义为两个 Token 集合的交集大小除以并集大小（$|A \cap B| / |A \cup B|$）。例如，集合 $\{1,2,3,4\}$ 与 $\{1,2,3,5\}$ 的 Jaccard 相似度得分为 $0.6$。若两篇文档的 Jaccard 相似度超过预设阈值(Preset Threshold)（如 $0.9$），则会被标记为近似重复。然而，该方法存在一个关键局限：Jaccard 相似度纯粹基于词表(Vocabulary)与 Token 的机械匹配，完全不具备语义理解(Semantic Understanding)能力。因此，它极易将仅相差关键否定词（如“not”）的文本误判为重复项；尽管两者的 Token 重叠度(Token Overlap)极高，但实际语义已截然相反。
![关键帧](keyframes/part005_frame_00549300.jpg)
![关键帧](keyframes/part005_frame_00563200.jpg)
![关键帧](keyframes/part005_frame_00586900.jpg)

---

## 近似重复检测的挑战
Jaccard 相似度(Jaccard Similarity)衡量的是表层词汇重叠(Surface-level Lexical Overlap)，而非深层语义内涵(Deep Semantic Meaning)。缺失一个关键否定词（如“not”）可能彻底逆转句意，但 Jaccard 得分依然居高不下。该领域的核心算法挑战在于：如何在超大规模数据集中以近似线性时间(Approximate Linear Time)高效识别近似重复项(Near Duplicates)，从而彻底摆脱计算成本高昂的成对比较(Pairwise Comparison)范式。
![关键帧](keyframes/part006_frame_00000000.jpg)
![关键帧](keyframes/part006_frame_00011233.jpg)

## MinHash：概率化的 Jaccard 估计
为突破成对比较(Pairwise Comparison)的性能瓶颈，可借助专用哈希函数对 Jaccard 相似度进行概率化估计(Probabilistic Estimation)。MinHash 算法具备一项关键特性：两个集合发生哈希碰撞(Hash Collision)的概率，在数学期望上严格等于其 Jaccard 相似度。与传统密码学哈希严格规避碰撞的设计初衷不同，MinHash 刻意利用碰撞频率来量化集合间的相似程度。集合间的相似度越高，其 MinHash 签名(MinHash Signature)发生碰撞的概率便越大。
![关键帧](keyframes/part006_frame_00036500.jpg)
![关键帧](keyframes/part006_frame_00116233.jpg)

## MinHash 背后的排列直觉
MinHash 的核心机制是对集合内所有元素应用随机哈希函数(Random Hash Function)，并提取计算结果中的最小值作为签名。其背后的数学直觉源自随机排列理论(Random Permutation Theory)：一个理想的随机哈希函数实质上会在全域元素空间(Universal Element Space)上诱导出一个均匀随机排列(Uniform Random Permutation)。当考察两个集合的“首个”（即哈希值最小）元素时，该元素恰好落入两者交集(Intersection)的概率，严格等于交集大小与并集大小(Union Size)的比值——这正是 Jaccard 相似度的数学定义。若最小哈希值落在交集内，两集合的 MinHash 值将发生碰撞；若落在对称差集(Symmetric Difference)中，则两者发散。实证测试充分验证了该理论概率，可稳定且可靠地将重叠集合的 Jaccard 得分估算为约 0.6。
![关键帧](keyframes/part006_frame_00141266.jpg)
![关键帧](keyframes/part006_frame_00272233.jpg)

## 从 MinHash 到局部敏感哈希（LSH）
尽管 MinHash 将成对度量(Pairwise Metric)转化为概率性独立函数，但仅依赖单次哈希碰撞仍不足以支撑可靠的去重决策。我们需要一种能够明确区分高相似度文本对与低相似度文本对的筛选机制。这正是局部敏感哈希(Locality Sensitive Hashing, LSH)的核心应用场景。LSH 的设计目标在于构建一套映射系统，使相似度超过预设阈值(Preset Threshold)的文本对以极高概率发生碰撞，而相似度低于该阈值的文本对碰撞概率则趋近于零。
![关键帧](keyframes/part006_frame_00310800.jpg)
![关键帧](keyframes/part006_frame_00319400.jpg)

## LSH 分带与概率放大
LSH 借助“分带策略(Banding Strategy)”实现概率分布的锐化。该算法不再依赖单一哈希函数，而是为每篇文档生成 $n$ 个 MinHash 签名，随后将其均匀划分为 $b$ 个数据带(Band)，每个带包含 $r$ 个哈希值。判定规则为：若*至少存在一个*数据带内的*全部* $r$ 个哈希值均完全匹配(Exact Match)，则将这两篇文档标记为近似重复候选对。从数学角度推导，若两文档的 Jaccard 相似度为 $s$，则单个特定带内所有哈希值均匹配的概率为 $s^r$。进而，$b$ 个带中至少有一个带发生完全匹配的概率可表述为 $1 - (1 - s^r)^b$。这种“与-或”逻辑结构(AND-OR Logical Structure)能够显著放大高于阈值的碰撞概率，同时强力抑制低于阈值的噪声匹配。
![关键帧](keyframes/part006_frame_00341233.jpg)
![关键帧](keyframes/part006_frame_00365766.jpg)
![关键帧](keyframes/part006_frame_00390033.jpg)
![关键帧](keyframes/part006_frame_00433033.jpg)
![关键帧](keyframes/part006_frame_00443599.jpg)

## 调整 S 型曲线以优化实际去重
经 LSH 变换后生成的概率曲线呈现典型的 S 型特征(Sigmoid Curve)。以相似度(Similarity)为横轴、碰撞概率(Collision Probability)为纵轴作图，可直观展现 LSH 如何将连续的相似关系映射为陡峭的阶跃函数(Steep Step Function)。例如，当配置参数 $b=10$ 且 $r=10$ 时，低相似度样本的碰撞概率被急剧压缩至趋近于 0，而高相似度样本的概率则被迅速推升至 1。为进一步提升阈值的选择性与判别锐度，可增加每个数据带内的哈希值数量（即行数 $r$）。通过精细调节 $b$（带数）与 $r$（行/哈希数）这两个核心超参数(Hyperparameters)，工程师能够精准控制近似重复检测流水线(Near-duplicate Detection Pipeline)的灵敏度(Sensitivity)，从而在召回率(Recall Rate)与计算效率(Computational Efficiency)之间实现最优权衡(Trade-off)。
![关键帧](keyframes/part006_frame_00454366.jpg)
![关键帧](keyframes/part006_frame_00461500.jpg)
![关键帧](keyframes/part006_frame_00543366.jpg)
![关键帧](keyframes/part006_frame_00565500.jpg)
![关键帧](keyframes/part006_frame_00572200.jpg)

---

## 调整 LSH 超参数以设定锐化阈值
增加每个数据带的行数（$r$）会使碰撞概率曲线(Collision Probability Curve)向右平移，从而收紧匹配条件并锐化决策边界(Decision Boundary)。此举能有效抑制低相似度样本产生的假阳性(False Positives)（例如，将相似度 0.7 时的碰撞概率从 0.24 骤降至 0.007）。然而，若曲线过度右移，将背离近似重复检测(Near-Duplicate Detection)的初衷。为平衡此效应，增加数据带数量（$b$）可将曲线向左牵引。通过精细协同调优 $r$ 与 $b$，工程师可构建出具备高度选择性(Selectivity)的 S 型函数(Sigmoid Function)，在强力滤除噪声的同时，精准保留处于目标阈值(Target Threshold)附近的真实匹配项。
![关键帧](keyframes/part007_frame_00000000.jpg)
![关键帧](keyframes/part007_frame_00012299.jpg)
![关键帧](keyframes/part007_frame_00058966.jpg)
![关键帧](keyframes/part007_frame_00067033.jpg)

## 实际应用：严格的近似重复检测
在 MinHash LSH 的实际工程部署中，近期某研究论文采用了 $b=20$ 与 $r=450$ 的参数配置。极高的 $r$ 值强制设定了约 0.99 的严苛相似度阈值(Similarity Threshold)，这意味着仅当文档间每百词差异控制在约 1 个词以内时，才会被判定为近似重复。在此精确阈值边界处，带匹配(Band Matching)的理论概率在数学上收敛于 $1 - 1/e \approx 0.63$。这表明处于临界阈值的样本具有约半数的碰撞概率(Collision Probability)，但系统响应在此点之后会急剧分化：高于阈值的样本碰撞概率趋近 100%，而低于阈值的样本则几乎不可能被匹配。
![关键帧](keyframes/part007_frame_00099766.jpg)
![关键帧](keyframes/part007_frame_00107433.jpg)
![关键帧](keyframes/part007_frame_00123233.jpg)
![关键帧](keyframes/part007_frame_00165500.jpg)
![关键帧](keyframes/part007_frame_00208866.jpg)
![关键帧](keyframes/part007_frame_00214899.jpg)

## 问答：合成数据与释义数据的去重
随着合成数据生成(Synthetic Data Generation)技术的日益普及，处理释义文本(Paraphrased Text)或语义相似(Semantically Similar)的重复项带来了全新挑战。传统的 MinHash 等纯词法层面(Lexical-level)方法极易遗漏此类语义变体。有效的解决方案是采用基于嵌入的查重(Embedding-based Deduplication)：借助大语言模型将文档映射至稠密向量空间(Dense Vector Space)，并利用近似最近邻搜索(Approximate Nearest Neighbor, ANN)算法识别语义高度重合的样本。尽管生成嵌入向量(Embeddings)的计算开销远高于 Token 哈希，但其能实现鲁棒性强(Robust)的“模糊去重”(Fuzzy Deduplication)。然而，研究人员需谨慎设定过滤强度，过度激进的语义清洗可能意外剔除高价值且具备多样性的数据，进而损害语料库(Corpus)的信息丰富度。
![关键帧](keyframes/part007_frame_00222599.jpg)
![关键帧](keyframes/part007_frame_00228466.jpg)
![关键帧](keyframes/part007_frame_00259799.jpg)
![关键帧](keyframes/part007_frame_00346133.jpg)

## 高质量数据重复的作用
另一个核心议题是：是否应允许高质量数据重复参与训练。答案是肯定的，尤其在模型预训练中后期或微调(Fine-tuning)阶段，对精选的高价值数据集进行多轮次(Multiple Epochs)训练裨益显著。严格去重(Strict Deduplication)主要在大规模预训练(Large-scale Pre-training)初期不可或缺，因为原始网页爬取数据中往往包含海量完全一致的样板文本(Boilerplate Text)副本，这不仅徒耗算力(Computational Resources)，还极易诱发模型记忆(Model Memorization)问题。最优策略绝非简单的“非删即留”二元决策；针对高频出现的高质量文档，可有意识地予以保留，但需通过对数缩放(Logarithmic Scaling)或平方根缩放(Square-root Scaling)等技术对其训练权重进行降权处理。此举既能在训练调度(Training Schedule)中凸显其核心价值，又能有效规避单一数据源对训练分布(Training Distribution)的过度主导。
![关键帧](keyframes/part007_frame_00387200.jpg)
![关键帧](keyframes/part007_frame_00417733.jpg)

## 课程总结与未来方向
本讲为同学们构建了现代数据整理(Data Curation)所需的完整算法工具箱。在质量过滤(Quality Filtering)模块，我们深入剖析了 N-Gram 模型、线性分类器(Linear Classifiers)与重要性重采样(Importance Resampling)技术，演示了如何从中提取目标分布(Target Distribution)，并将其应用于语言识别、垂直领域适配(Vertical Domain Adaptation)及毒性内容过滤(Toxic Content Filtering)等任务。在去重模块，我们系统介绍了可扩展哈希技术(Scalable Hashing Techniques)——涵盖用于精确匹配的布隆过滤器(Bloom Filters)，以及专攻高效近似相似度检测的 MinHash 与局部敏感哈希(Locality Sensitive Hashing, LSH)。然而，算法流水线(Algorithmic Pipeline)仅是基石。真正精通数据工程(Data Engineering)离不开亲自下场实践、迭代优化过滤策略以及持续的模型训练反馈，从而培养工程直觉(Engineering Intuition)。在夯实上述数据工程原理后，本课程将迈入最终章：强化学习(Reinforcement Learning)与模型对齐(Model Alignment)。
![关键帧](keyframes/part007_frame_00517200.jpg)
![关键帧](keyframes/part007_frame_00539833.jpg)
![关键帧](keyframes/part007_frame_00551766.jpg)