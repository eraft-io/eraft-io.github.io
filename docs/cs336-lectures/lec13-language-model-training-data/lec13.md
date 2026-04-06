## 数据在语言模型训练中的关键作用
因此，今天的讲座将聚焦于数据。在之前的讲座中，我们一直探讨的是在给定数据的前提下如何训练模型。我们讨论了模型架构(Model Architecture)、优化器(Optimizer)、词元化(Tokenization)、缩放定律(Scaling Laws)以及并行计算(Parallel Computing)。这些讨论均建立在数据固定的基础之上。而现在，我们要探讨的核心问题是：我们究竟使用什么样的数据来训练模型。我明确提出一个观点：数据是决定语言模型性能表现的最关键因素。当然，你可能对此持有不同意见，也有人认为缩放定律才是最重要的。以下是我持此观点的理由。
![关键帧](keyframes/part000_frame_00000000.jpg)
![关键帧](keyframes/part000_frame_00006400.jpg)
![关键帧](keyframes/part000_frame_00023966.jpg)

## 企业的保密性与数据策展的可扩展性
我们来看看各公司在论文中实际披露了哪些内容。以 Llama 3 和 Qwen 等开源权重模型(Open-weight Models)为例，它们会完全公开模型架构，论文中也花了大量篇幅详细阐述训练流程及其运作机制。然而，它们对具体训练数据几乎只字不提。以内容详实的 Llama 3 论文为例，关于数据部分，他们基本只给出了一句描述：“我们的数据集由截至 2023 年底的多种知识数据源构成。”客观来说，他们确实在宏观层面上用了一定篇幅介绍数据过滤的方法，但关于数据集本身的具体细节依然极少。这背后主要有两方面原因：一是出于商业机密与市场竞争的考量；二是为了规避法律风险。实际上，潜在的版权诉讼可能远比目前已曝光的还要多。众所周知，在基础模型(BFoundation Models)兴起之前，数据的重要性就已得到广泛认可，因为监督学习(Supervised Learning)严重依赖高质量的标注数据。如今，尽管人工标注的工作量有所减少，但数据处理环节依然不可或缺，且包含了大量的数据策展(Data Curation)与清洗工作。因此，在某种程度上，我们对数据的依赖并未发生根本性改变。数据问题本质上是一个典型的长尾问题(Long-tail Problem)。我认为业界之所以如此重视数据，是因为数据处理具有极强的可扩展性(Scalability)。如果你想构建一个能够胜任多种任务的模型，完全可以轻松组建一支数百人的团队，让他们分工处理不同领域的数据，如多语言文本、代码等；若开发多模态模型(Multimodal Models)，还可以并行处理图像、音频等不同模态的数据。相比之下，模型架构设计通常只有一种主流方案，由核心小团队定义即可完成。因此，若在语言模型开发团队中进行资源分配，你会发现数据准备工作具有高度的可并行性。
![关键帧](keyframes/part000_frame_00034400.jpg)
![关键帧](keyframes/part000_frame_00062966.jpg)
![关键帧](keyframes/part000_frame_00116000.jpg)
![关键帧](keyframes/part000_frame_00172499.jpg)

## 训练阶段：预训练、中训练与后训练
模型训练通常分为多个阶段。首先是预训练(Pre-training)，这也是本课程的重点内容，主要利用原始数据（通常来源于互联网）进行大规模训练。其次是中期训练(Mid-training)，在此阶段，研究团队会筛选出一组规模较小但质量较高的数据文档，旨在针对性地强化模型的特定能力，如数学推理、代码生成或长上下文(Long Context)处理。最后是后训练(Post-training)，模型将在指令微调数据(Instruction Tuning Data)或对话数据上进行微调，并结合强化学习(Reinforcement Learning)技术，使其真正转化为能够自然交互的智能体。通常，模型对齐(Alignment)与安全性(Safety)等相关工作也会在这一阶段进行。但在实际工程中，这些阶段的边界往往是模糊的。在近期的一些先进模型中，训练阶段的划分更加细化，但具体细节外界无从得知。不过，其核心逻辑非常清晰：即从海量、相对粗糙的数据开始训练，随后逐步过渡到使用规模较小、质量更高的数据进行精炼。在此，明确几个常见术语：“基础模型(Base Model)”通常指完成预训练和中期训练后保存的模型检查点(Model Checkpoint)；而“指令模型(Instruct Model)”则指在此基础上进一步完成后训练阶段的最终模型。
![关键帧](keyframes/part000_frame_00223099.jpg)
![关键帧](keyframes/part000_frame_00243566.jpg)

## 现实案例：AI2 的数据混合比例
我们来看一个具体案例。该案例来自 AI2（艾伦人工智能研究所），由于他们发布了众多开源模型，因此我们能够确切了解其训练数据集的构成。在预训练阶段，开源模型通常采用如下典型的数据混合比例(Data Mixing Ratios)：包含来自 DCLM基准数据集(DCLM Baseline)的网页数据（稍后详细讨论）、代码、学术论文、数学题集以及维基百科，总规模约为 3.9 万亿个词元(Token)。接下来观察中期训练阶段，你会发现数据源基本保持一致，但经过了严格筛选。DCLM基准数据集的数据量从原先占主导地位的 3.7 万亿词元大幅缩减至 7000 亿。此外还加入了部分 FLAD数据集(FLAD Dataset)以及维基百科（看来业界确实对其青睐有加）。随后引入了一些全新的合成数据集(Synthetic Datasets)，并且顺带加入了 GSM8K训练集(GSM8K Training Set)，这无疑是提升数学能力的明智之举。该阶段的数据总量约为 100 亿训练词元。最后，还有一篇关于 Tulu模型(Tulu)的独立论文，详细阐述了实际的后训练流程，其中列出了具体的数据混合比例。该阶段主要包含来自多渠道的对话数据，以及大量用于覆盖不同能力维度的合成数据。
![关键帧](keyframes/part000_frame_00250666.jpg)
![关键帧](keyframes/part000_frame_00259333.jpg)
![关键帧](keyframes/part000_frame_00281066.jpg)
![关键帧](keyframes/part000_frame_00293699.jpg)
![关键帧](keyframes/part000_frame_00300899.jpg)
![关键帧](keyframes/part000_frame_00308466.jpg)
![关键帧](keyframes/part000_frame_00315633.jpg)
![关键帧](keyframes/part000_frame_00322633.jpg)

## 数据集选择理念与历史渊源
那么，这些数据集究竟是什么？它们又是如何被筛选和处理的呢？为了合理管理大家的预期，避免后续产生落差，我必须说明：目前业界尚无一套完善的形式化理论(Formal Theory)或严格原则来指导数据集的选择。考虑到本课程的技术定位，这或许并不令人意外，毕竟即便在模型架构设计上，我们也尚未找到放之四海而皆准的完美准则。具体到数据层面，我认为它极难通过纯理论讲授来掌握，因为数据工程高度依赖实践经验。因此，我将逐一梳理历史上被广泛采用的各类数据集，阐明其来源与特性，希望大家能够通过自主归纳，逐步建立起判断“何为优质数据、何为劣质数据”的直觉。接下来，我将从预训练阶段讲起，随后涵盖中期训练与后训练，但核心篇幅仍将聚焦于预训练。让我们将时间回溯至 2018 年。大家应该还记得具有里程碑意义的 BERT模型。当时，BERT 的训练数据主要由书籍和维基百科构成。接下来，我们将深入剖析这一选择背后的具体含义。
![关键帧](keyframes/part000_frame_00340566.jpg)
![关键帧](keyframes/part000_frame_00375733.jpg)
![关键帧](keyframes/part000_frame_00402799.jpg)
![关键帧](keyframes/part000_frame_00409500.jpg)
![关键帧](keyframes/part000_frame_00415066.jpg)
![关键帧](keyframes/part000_frame_00431766.jpg)

## BooksCorpus 与维基百科：核心数据源
我认为，数据集往往在学术讨论中被低估，因为公众和研究者的注意力通常集中在模型本身、评估基准(Benchmarks)及其能力表现上。以 Smashwords 网站为例，该平台成立于 2008 年，允许任何人免费发布电子书。截至去年，该网站已收录约 50 万本书籍。而在 2015 年，一篇视觉-语言论文(Vision-Language Paper)的研究人员爬取了该平台数据，构建了著名的书籍语料库(BooksCorpus)，主要收录标价为零的免费电子书，最终收集了约 7000 本书。不过，由于此举违反了平台服务条款(Terms of Service)，该语料库随后被强制下架。2015 年尚处于互联网数据的“拓荒时代”，业界对人工智能版权问题的重视程度远不及今日。因此，若今后在文献中再看到 BooksCorpus，大家便能了解其历史背景。尽管它是一个年代久远的数据集，但它在一定程度上奠定了学界对书籍数据价值的认可基础。接下来谈谈维基百科，相信大家都对其非常熟悉。
![关键帧](keyframes/part000_frame_00444800.jpg)
![关键帧](keyframes/part000_frame_00463933.jpg)
![关键帧](keyframes/part000_frame_00489799.jpg)
出于演示目的，我们可以随机打开一篇维基百科文章。比如这篇随机跳转的文章，再次点击又会跳转到另一篇。这里展示的是一栋随机建筑的词条……维基百科已运行二十余年，拥有海量多语言条目。明确维基百科的内容属性至关重要：它不收录原创研究(Original Research)，所有内容均必须附带引用来源，因此其中大量引用了真实的一手资料。原则上，维基百科不包含个人观点、宣传内容或私人网页。同时，它严格遵循“关注度原则”(Notability Principle)，即收录的主题必须已被多个独立、可靠的第三方来源报道过。了解这些规则，大家便能大致把握维基百科的内容边界。显然，维基百科之外仍存在大量高价值信息。例如许多极具参考价值的个人观点，或生活类内容（如菜谱等），均不会出现在维基百科中。尽管维基百科理论上允许任何人编辑，但实际上，极少数核心用户贡献了绝大部分内容。例如，曾有单一用户完成了超过五百万次编辑，推测其可能使用了自动化脚本或工具。作为网站运营方，维基百科会定期生成完整的数据转储(Data Dump)供外界下载。
![关键帧](keyframes/part000_frame_00507099.jpg)
![关键帧](keyframes/part000_frame_00513200.jpg)
![关键帧](keyframes/part000_frame_00521933.jpg)
![关键帧](keyframes/part000_frame_00530833.jpg)
![关键帧](keyframes/part000_frame_00585500.jpg)

---

## 维基百科数据与数据投毒的脆弱性
维基百科会定期生成数据转储文件(Data Dumps)，用户可下载包含其全部内容的 ZIP 压缩包。尽管与普通网络文章相比，维基百科通常被视为高质量且可靠的数据源，但它并非对安全风险免疫。在训练数据领域，一个备受关注的重大隐患是“数据投毒”(Data Poisoning)。Carlin 等人的研究揭示了攻击者如何在预定的数据快照生成之前，将恶意编辑注入维基百科。通过精准的时间控制，这些恶意编辑得以被收录进转储文件中，且抢在维基百科的自动回滚系统将其撤销之前，攻击者便成功将有害内容嵌入了训练数据。由于掌控训练数据将直接左右模型的行为输出，这暴露出一个关键的安全漏洞。尽管这一特定漏洞可能已得到修复，但它揭示了一个更普遍的事实：源自开放互联网的数据极易受到出于各种动机的恶意行为体(Malicious Actors)操纵，这使得全面的数据监管变得异常困难。
![关键帧](keyframes/part001_frame_00000000.jpg)
![关键帧](keyframes/part001_frame_00006533.jpg)
![关键帧](keyframes/part001_frame_00037400.jpg)
![关键帧](keyframes/part001_frame_00042966.jpg)

## 预训练数据的演进：从 BERT 到 GPT-2 的 WebText
回顾模型发展的历史节点，广为人知的是 BERT 模型最初基于书籍和维基百科数据进行训练。尽管以当下的标准来看略显陈旧，但 BERT 将训练范式从孤立的句子片段升级为完整的文档，这标志着语言建模的关键转折，也与早期的十亿词语料库(Billion Word Corpus)等基准形成了鲜明对比。随后，GPT-2 引入了一个名为 WebText 的创新性数据集。开发者意识到原始网页虽然规模庞大但质量良莠不齐，因此设计了一条简单却高效的启发式规则(Heuristic Rule)来筛选高质量且多样化的内容：他们爬取了 Reddit 社区中获点赞数（Karma）超过 3 分的帖子内所含的网页链接。该方法最终构建出一个包含约 100 万个网页、文本量达 40 GB 的精选数据集。尽管 OpenAI 从未公开发布 WebText 数据集，但它催生了众多开源复刻项目(Open-source Replicas)，这些数据集至今仍在学术研究中被广泛沿用。
![关键帧](keyframes/part001_frame_00112700.jpg)
![关键帧](keyframes/part001_frame_00139933.jpg)
![关键帧](keyframes/part001_frame_00168966.jpg)

## Common Crawl：揭秘“在互联网上训练”的真相
业界普遍存在一个误解，即语言模型是直接在完整的互联网上进行训练的。实际上，模型训练依赖的是类似 Common Crawl 这样的结构化数据集，它充当了互联网数据的学术级近似样本(Academic-grade Approximation)。Common Crawl 项目始于 2007 年，每月执行一次网络爬虫(Web Crawler)作业，在过去 17 年间已累计发布了约 100 次独立的爬取快照。尽管数据规模极其庞大，但相较于模型训练的高昂成本，爬取过程本身的性价比极高，仅依靠租赁的云计算算力(Cloud Computing)即可在两周内轻松完成。作为参考，最近的一次爬取任务便新增了约 27 亿个网页。每次爬取的覆盖范围会略有波动，其内置的启发式策略旨在确保数据来源的多样性，并优先高频回访内容更新较快的动态网站，而非静态网站。
![关键帧](keyframes/part001_frame_00208166.jpg)
![关键帧](keyframes/part001_frame_00234433.jpg)
![关键帧](keyframes/part001_frame_00256033.jpg)
![关键帧](keyframes/part001_frame_00272700.jpg)

## 爬取架构与数据输出格式
Common Crawl 的基础架构运行机制类似于网络上的广度优先搜索(Breadth-First Search, BFS)算法。系统从一个包含数亿个 URL 的庞大种子列表(Seed List)起步，并维护一个分布式存储在多台服务器上的“爬取边界”(Crawl Frontier)队列。该系统在设计上严格遵循“网络爬虫礼仪”(Crawler Etiquette)，遵守服务器访问限制并严格遵从 `robots.txt` 协议，以避免对目标网站造成过载压力。此外，它还能有效应对动态 URL 解析与内容去重(Content Deduplication)等复杂技术挑战。原始爬取数据主要提供两种存储格式：WARC 文件(Web ARChive)包含完整的原始 HTTP 响应数据（通常为 HTML），而 WET 文件(Web Extracted Text)则是已提取并清洗为纯文本的版本。这种从 HTML 到纯文本的转换本质上是一种有损处理(Lossy Process)，因为网页的原始结构与排版信息会被直接丢弃。
![关键帧](keyframes/part001_frame_00315633.jpg)
![关键帧](keyframes/part001_frame_00345299.jpg)
![关键帧](keyframes/part001_frame_00364000.jpg)
![关键帧](keyframes/part001_frame_00377766.jpg)

## HTML 到文本转换的隐性影响
尽管原始 WARC 文件可供研究者独立解析，但许多团队仍倾向于直接使用预转换好的 WET 文本文件。然而，HTML 到文本提取工具的选择会显著影响下游模型(Downstream Models)的性能表现。DataComp 基准测试(DataComp Benchmark)等研究表明，与 Trafilatura 等高级提取工具相比，使用默认的文本解析方法会导致模型性能下降约 4 个百分点。这充分说明，底层数据预处理(Data Preprocessing)策略的选择绝非无关紧要。此外，Common Crawl 在设计之初便有意放弃“全网全覆盖”的目标；其遵循网络礼仪的爬取策略意味着并非所有网页（甚至包括部分维基百科条目）都会被收录，且该数据集在默认状态下并不会主动过滤冒犯性或有害内容(Toxic Content)。
![关键帧](keyframes/part001_frame_00424400.jpg)
![关键帧](keyframes/part001_frame_00432533.jpg)
![关键帧](keyframes/part001_frame_00439233.jpg)
![关键帧](keyframes/part001_frame_00454933.jpg)

## 退出机制与网络爬取格局的演变
由于缺乏内置的自动化内容过滤机制，如何界定“冒犯性内容”依然是一个复杂的语义理解挑战，通常需交由下游研究人员自行解决。不过，网站运营方确实拥有控制自身内容是否被抓取的权限与机制。网站管理员可通过配置 `robots.txt` 文件来设定访问规则，明确授权或禁止特定爬虫(Crawlers/Bots)抓取其内容。例如，《纽约时报》等大型出版机构便维护着严格的 `robots.txt` 配置，明确禁止各类人工智能与大语言模型(LLM)爬虫进行数据抓取。这种日益普及的定向爬虫屏蔽规则，凸显了 AI 训练数据收集与网络出版商版权权益(Copyright Interests)之间持续的博弈，也预示着未来可供模型训练的开放互联网数据生态正在发生深刻变革。
![关键帧](keyframes/part001_frame_00477366.jpg)
![关键帧](keyframes/part001_frame_00484000.jpg)
![关键帧](keyframes/part001_frame_00500366.jpg)
![关键帧](keyframes/part001_frame_00555166.jpg)
![关键帧](keyframes/part001_frame_00567066.jpg)
![关键帧](keyframes/part001_frame_00584066.jpg)
![关键帧](keyframes/part001_frame_00600233.jpg)

---

## 专有爬虫、媒体处理与版权现实
尽管 `robots.txt` 是网络爬虫(Network Crawler)的标准规范，但其缺乏正式的强制约束力，因此部分前沿模型开发者选择运行自有的私有爬虫(Private Crawlers)。这主要是因为，尽管 Common Crawl 规模庞大，但相对于浩瀚的互联网，其数据覆盖率实际上相当有限（采样相对稀疏）。当这些爬虫抓取原始 HTTP 响应时，偶尔会捕获图像等非文本媒体内容，尽管其数据处理流水线(Data Processing Pipeline)通常仍以文本为主。一个关键且复杂的现实是，Common Crawl 中的绝大多数数据均包含受版权保护(Copyright Protection)的内容。在现代 AI 开发中，如何合法合规地使用这些数据是一个需要审慎权衡法律与伦理(Legal and Ethical Considerations)的重要议题。
![关键帧](keyframes/part002_frame_00000000.jpg)
![关键帧](keyframes/part002_frame_00005966.jpg)
![关键帧](keyframes/part002_frame_00023766.jpg)
![关键帧](keyframes/part002_frame_00054233.jpg)
![关键帧](keyframes/part002_frame_00074700.jpg)

## CCNet：基于模型的质量过滤
众所周知，源自 Common Crawl 的原始样本充满噪声，因此必须依赖强大的数据过滤流水线(Data Filtering Pipeline)进行处理。其中最早且最具影响力的方法之一是 Meta 推出的 CCNet，该方案被设计为一套用于提取高质量多语言数据的通用处理框架。CCNet 融合了去重(Deduplication)、语言识别(Language Identification)以及一种创新的质量过滤器：一个基于维基百科文本训练的 5-gram 模型(N-gram Model)。该流程将维基百科视为高质量写作的参照基准(Benchmark)，对候选文档进行概率评分，并保留在统计分布(Statistical Distribution)上与维基百科结构和文体风格相似的文本。这种基于模型(Model-based)的过滤方法成功提升了 BERT 模型的性能（相较于仅使用维基百科训练），但其局限性在于，本质上将数据分布收敛至与维基百科特定文体风格高度一致的范畴内。
![关键帧](keyframes/part002_frame_00103200.jpg)
![关键帧](keyframes/part002_frame_00109233.jpg)
![关键帧](keyframes/part002_frame_00115333.jpg)
![关键帧](keyframes/part002_frame_00124933.jpg)
![关键帧](keyframes/part002_frame_00135833.jpg)

## C4：启发式过滤及其权衡
与基于模型的过滤方法不同，Google 在发布 T5 模型时引入了“超大规模清洗爬取语料库”(Colossal Clean Crawled Corpus, C4)，该数据集完全依赖启发式规则(Heuristic Rules)进行构建。其处理流水线(Processing Pipeline)保留了以标准标点符号结尾的行，删除了篇幅少于三句话的页面，过滤了包含不当词汇的内容，剔除了大括号出现频率过高的文本（这导致大量编程代码被误删），并且仅保留英文语料。这种基于规则(Rule-based)的方法与 CCNet 形成高度互补：它能够捕捉维基百科风格局限之外、语法通顺的自然语言文本，但也存在保留那些语法正确但属于垃圾营销(Spam)内容的风险。此外，当研究人员尝试利用 Reddit 链接的启发式规则从 C4 中重建 OpenWebText 数据集时，仅成功恢复了原始规模的一半，这凸显了 Common Crawl 本身固有的数据不完整性。尽管如此，C4 的数据构成（涵盖维基百科、专利文档、新闻报道等）已被证实对提升自然语言处理(Natural Language Processing, NLP)基准测试(Benchmark)的表现极为有效。
![关键帧](keyframes/part002_frame_00228333.jpg)
![关键帧](keyframes/part002_frame_00235933.jpg)
![关键帧](keyframes/part002_frame_00256700.jpg)
![关键帧](keyframes/part002_frame_00264500.jpg)
![关键帧](keyframes/part002_frame_00278566.jpg)
![关键帧](keyframes/part002_frame_00304300.jpg)
![关键帧](keyframes/part002_frame_00339133.jpg)
![关键帧](keyframes/part002_frame_00347566.jpg)
![关键帧](keyframes/part002_frame_00354999.jpg)
![关键帧](keyframes/part002_frame_00385400.jpg)

## GPT-3 时代与质量分类器
GPT-3 的发布标志着数据集构建迈入更为复杂的阶段。GPT-3 的训练数据混合了经过过滤的 Common Crawl、WebText2、未公开详情的书籍语料库以及维基百科，总词元(Token)量约为 4000 亿。其中一项关键创新是引入了质量分类器(Quality Classifier)：研究人员不再依赖简单的启发式规则或 N-gram 模型，而是训练了一个二分类器(Binary Classifier)，用于精准区分高质量数据源（如 WebText、维基百科、书籍）与低质量的网络噪声。这种以正样本为驱动(Positive-sample Driven)的方法使其能够更智能地对庞大的 Common Crawl 数据池进行评分与过滤，从而筛选出在统计分布上与精心构建的高质量基准集高度吻合的文档。
![关键帧](keyframes/part002_frame_00436366.jpg)
![关键帧](keyframes/part002_frame_00458466.jpg)
![关键帧](keyframes/part002_frame_00480866.jpg)
![关键帧](keyframes/part002_frame_00500899.jpg)

## The Pile：开源与社区协作构建
作为对 GPT-3 等模型封闭性与专有性(Proprietary Nature)的直接回应，EleutherAI 发起了一项去中心化、社区驱动(Community-driven)的项目，旨在构建透明且开源的数据集。该项目被命名为“The Pile”，主要由志愿者协作推进，他们贡献、筛选并整理了来自 22 个高质量垂直领域(Domains)的数据。最终构建的混合数据集融合了经过过滤的 Common Crawl、OpenWebText、StackExchange 问答数据、维基百科历史存档以及专业的学术与技术文献。通过优先保障数据多样性、透明度与开放获取(Open Access)，The Pile 为开源 AI 社区奠定了一项基础性基准(Baseline)，有力证明了协作式、领域特定的数据策展(Data Curation)完全能够有效媲美商业公司的专有数据处理流水线。
![关键帧](keyframes/part002_frame_00547500.jpg)
![关键帧](keyframes/part002_frame_00556633.jpg)
![关键帧](keyframes/part002_frame_00569900.jpg)
![关键帧](keyframes/part002_frame_00582733.jpg)
![关键帧](keyframes/part002_frame_00593066.jpg)

---

## The Pile 的多样性与专业化数据构建
尽管理论上 Common Crawl 包含了海量的网络文本，但数据集构建者通常会跳过通用爬取流程，直接获取特定领域的高质量数据并进行专门处理。The Pile 便是这一策略的典型代表，它聚合了大量需特殊处理的高度专业化数据源。其中包括 PubMed Central (PMC)，该数据库收录了美国国立卫生研究院（NIH）强制要求开放获取（Open Access）的生物医学文献，这凸显了科学领域相较于其他领域拥有更为丰富的学术资源。此外，该数据集还纳入了安然邮件语料库（Enron Email Corpus）。该语料库源于联邦调查传票，尽管受限于固有的隐私问题且可能带有特定的企业内部偏见，但它仍是目前为数不多的大规模真实世界邮件数据集之一。
![关键帧](keyframes/part003_frame_00000000.jpg)
![关键帧](keyframes/part003_frame_00042633.jpg)

## 古腾堡计划与长上下文建模
在文学与历史文本领域，古腾堡计划（Project Gutenberg）是至关重要的基础数据源，提供了约 7.5 万本英文书籍。这些作品大多已进入公有领域（Public Domain）（通常指出版超过 75 年），为模型训练提供了版权清晰且质量上乘的文学素材。基于此衍生的 PG-19 数据集（PG-19 Dataset）专门利用这些书籍来评估模型的长上下文能力（Long-Context Capabilities）。与新闻报道或学术论文不同，书籍能够在数千个词元（Token）的跨度内维持连贯的叙事脉络，这使得它们对于训练模型理解与生成长篇幅、结构复杂的文本而言不可或缺。
![关键帧](keyframes/part003_frame_00087033.jpg)
![关键帧](keyframes/part003_frame_00100866.jpg)

## 专有平台与竞争性数据护城河
获取 Twitter/X 帖子、YouTube 字幕或 Facebook 互动等平台专属数据（Platform-specific Data），通常被视为大型科技公司的核心竞争优势。然而，拥有数据访问权限并不自动等同于拥有模型训练权；严格的隐私法规（Privacy Regulations）、服务条款（Terms of Service）与用户协议（User Agreements）极大地限制了此类数据的使用范围。尽管 Google 和 Meta 等平台坐拥海量数据储备，但它们通常无法自由地将 Gmail 邮件或私人通讯等用户隐私内容用于模型训练。尽管如此，独占公开平台数据确实能构建起战略性数据护城河（Data Moat），有望推动未来的市场差异化与垂直领域专业化发展。值得注意的是，模型的成功并非完全依赖于专有数据；已有实践表明，部分公司通过采用替代性数据策略（Alternative Data Strategies）同样取得了卓越的性能表现。
![关键帧](keyframes/part003_frame_00133333.jpg)
![关键帧](keyframes/part003_frame_00201133.jpg)

## 影子图书馆与版权争议
对构建全面书籍语料库的追求，促使数据集构建者引入了 Books3 等数据集，其数据主要源自 Library Genesis (Libgen) 等影子图书馆（Shadow Libraries）。这些平台托管了数百万本受版权保护且设有付费墙的书籍，直接触碰了知识产权法（Intellectual Property Law）的边界。支持者主张此类平台促进了知识获取的民主化（Democratization of Knowledge），但法律界定依然严格，导致相关平台频繁遭遇封禁并面临重大诉讼。两者规模差异悬殊：Libgen 托管了数百万册书籍，而古腾堡计划仅收录数万册。随着头部模型开发者被曝出利用此类影子图书馆数据训练模型，该行为引发了更严厉的法律审查，使得版权合规（Copyright Compliance）已成为现代数据集构建中不可回避的核心挑战。
![关键帧](keyframes/part003_frame_00318799.jpg)
![关键帧](keyframes/part003_frame_00326833.jpg)
![关键帧](keyframes/part003_frame_00337099.jpg)

## Stack Exchange：问答数据与预/后训练界限的模糊
Stack Exchange 平台提供了一种独特的数据结构，本质上构成了一个大规模、垂直领域的问答（Q&A）数据集。其问答格式辅以点赞（Upvotes）机制与社区审核（Community Moderation），高度契合现代 AI 助手所需的指令遵循（Instruction Following）与多轮对话交互模式。这种结构上的天然相似性，模糊了传统预训练（Pre-training，即从原始文档中学习）与后训练（Post-training，即针对对话场景微调）之间的界限。即便在预训练阶段，让模型接触问答格式的数据也能隐式地教会其如何构建逻辑严密的回复。尽管点赞数等元数据（Metadata）为复杂的质量过滤提供了支撑，但如今此类数据集的商业化应用已需要明确的授权许可（Licensing），这使其在性质上逐渐区别于纯粹的开放学术资源。
![关键帧](keyframes/part003_frame_00394500.jpg)
![关键帧](keyframes/part003_frame_00403066.jpg)
![关键帧](keyframes/part003_frame_00421366.jpg)
![关键帧](keyframes/part003_frame_00427900.jpg)
![关键帧](keyframes/part003_frame_00433866.jpg)
![关键帧](keyframes/part003_frame_00439733.jpg)

## GitHub：代码数据与推理能力
GitHub 是训练模型掌握编程语言（Programming Languages）的核心数据源。业界普遍认为，接触代码数据不仅能提升模型的语法理解与代码补全（Code Completion）能力，还能显著增强其逻辑推理（Logical Reasoning）与结构化思维能力。然而，GitHub 上超过 2800 万个公开仓库（Public Repositories）的质量实则参差不齐。随机抽样结果表明，尽管大量仓库已处于弃用状态、缺乏技术文档或仅包含琐碎代码，但庞大的基数仍确保了海量高质量且活跃维护的项目储备。这揭示了一个关键经验：单纯追求仓库数量极具误导性；高效的数据构建必须严格过滤代码质量与文档完整度，而不能仅仅依赖宏观的统计指标。
![关键帧](keyframes/part003_frame_00447499.jpg)
![关键帧](keyframes/part003_frame_00519000.jpg)
![关键帧](keyframes/part003_frame_00524900.jpg)
![关键帧](keyframes/part003_frame_00558900.jpg)
![关键帧](keyframes/part003_frame_00565366.jpg)
![关键帧](keyframes/part003_frame_00571000.jpg)

---

## 从原始仓库到 The Stack：GitHub 代码的处理流程
GitHub 仓库(GitHub Repositories)远比简单的代码文件复杂；它们包含提交历史(Commit History)、Issue 跟踪列表(Issue Tracking)、技术文档以及大量重复内容(Duplicate Content)。将这种原始、非结构化的数据生态系统转化为高质量的训练词元(Training Tokens)需要大量的数据工程(Data Engineering)工作。GitHub Archive 提供了可通过 Google BigQuery 访问的事件数据快照(Event Data Snapshots)，这构成了 **The Stack** 等开源项目的基础。该项目克隆(Clone)了超过 1.37 亿个仓库，严格筛选出采用宽松许可协议(Permissive Licenses)的项目，执行了去重处理，最终生成了约 3.1 TB 的代码数据。代码数据的一个关键优势在于其版权许可(Copyright Licensing)状态明确，这与普通网页上通常模糊不清的授权状况形成了鲜明对比。然而，“在 GitHub 数据上训练”并非一个单一概念；它涉及一条从在线服务获取、原始快照提取到精心构建的数据集(Curated Datasets)的完整处理流水线(Data Pipeline)，这凸显了采用透明数据处理方法的至关重要性。
![关键帧](keyframes/part004_frame_00000000.jpg)
![关键帧](keyframes/part004_frame_00033366.jpg)
![关键帧](keyframes/part004_frame_00047200.jpg)
![关键帧](keyframes/part004_frame_00059700.jpg)
![关键帧](keyframes/part004_frame_00086966.jpg)
![关键帧](keyframes/part004_frame_00099466.jpg)
![关键帧](keyframes/part004_frame_00108533.jpg)
![关键帧](keyframes/part004_frame_00114633.jpg)
![关键帧](keyframes/part004_frame_00122033.jpg)
![关键帧](keyframes/part004_frame_00129899.jpg)

## Gopher 与 MASSIVE Text：为避免偏见而采用的启发式过滤
2021 年，DeepMind 推出了 MASSIVE Text 数据集以训练其 Gopher 模型。该数据集由 MASSIVE Web、C4、书籍、新闻和 GitHub 数据组成，但其处理细节缺乏完全的可复现性(Reproducibility)。MASSIVE Web 的一个显著特点是严格依赖人工设计的启发式规则(Handcrafted Heuristic Rules)，而非基于机器学习的过滤器(Machine Learning-based Filters)。过滤规则要求文档中至少 80% 的单词需包含字母字符，并调用 Google SafeSearch 进行有害内容(Toxic Content)过滤。此举旨在防止早期性能较弱的分类器模型(Classifier Models)引入算法偏见(Algorithmic Bias)，并避免误过滤掉偏离维基百科规范的非标准写作或边缘化群体的表达方式。最终构建的语料库(Corpus)总规模约为 10 TB（约 4-5 万亿个词元/Tokens），尽管 Gopher 模型本身仅在 3000 亿词元的子集(Subsets)上进行了训练。
![关键帧](keyframes/part004_frame_00142799.jpg)
![关键帧](keyframes/part004_frame_00174533.jpg)
![关键帧](keyframes/part004_frame_00271099.jpg)

## LLaMA、维基百科引用与“精炼网络”理念
2022 年发布的 LLaMA 引入了一种针对 Common Crawl 数据的精细化过滤策略(Refined Filtering Strategy)。其分类器(Classifier)不再单纯依据文档“外观”是否类似维基百科进行筛选，而是精准识别那些*被维基百科条目引用为参考文献(References)*的网页。该方法巧妙利用引用网络(Citation Network)来挖掘高质量数据源，而无需强迫文本在文体风格上迎合百科全书的固定格式。该数据集还整合了 C4、GitHub、古腾堡计划(Project Gutenberg)以及颇具争议的 Books3 等数据源，总词元量达 1.2 万亿。原始数据处理透明度的缺失，直接催生了 **RedPajama** 和 **RefinedWeb** 等开源复刻项目(Open-source Replica Projects)。RefinedWeb 的核心理念在于：经过充分过滤的网络爬取数据(Web Crawled Data)足以替代各类垂直领域的专用数据集(Specialized Datasets)。通过采用 Trafilatura 等高级 HTML 转文本工具、启发式规则(Heuristic Rules)以及模糊去重技术(Fuzzy Deduplication)，该项目生成了包含 5 万亿词元的语料库（其中公开开源了 6000 亿词元）。其后继项目 **FineWeb** 整合了所有可用的 Common Crawl 数据转储文件(Data Dumps)，将数据规模扩展至 15 万亿词元，为后续研究提供了一个经过轻度过滤(Lightly Filtered)且高容量的基线数据集(Baseline Dataset)。
![关键帧](keyframes/part004_frame_00330466.jpg)
![关键帧](keyframes/part004_frame_00339099.jpg)
![关键帧](keyframes/part004_frame_00359066.jpg)
![关键帧](keyframes/part004_frame_00392799.jpg)
![关键帧](keyframes/part004_frame_00399500.jpg)
![关键帧](keyframes/part004_frame_00431766.jpg)
![关键帧](keyframes/part004_frame_00438300.jpg)
![关键帧](keyframes/part004_frame_00449000.jpg)
![关键帧](keyframes/part004_frame_00465933.jpg)
![关键帧](keyframes/part004_frame_00474533.jpg)
![关键帧](keyframes/part004_frame_00483399.jpg)
![关键帧](keyframes/part004_frame_00504200.jpg)
![关键帧](keyframes/part004_frame_00536800.jpg)

## Dolma 数据集与平台数据访问权的转变
AI2 的 OLMo 模型基于 **Dolma** 数据集进行训练，这是一套专为数据透明度与开放研究(Open Research)而精心构建的数据集合(Data Mix)。Dolma 聚合了 Common Crawl、The Stack（代码数据）、C4、Semantic Scholar 学术论文库、古腾堡计划以及维基百科。它同时纳入了 Reddit 数据，并进行了结构化处理(Structuring Processing)以严格区分主帖(Submissions)与评论(Comments)，从而有效规避了传统网页爬取中常见的非正式噪声(Informal Noise)。然而，这一数据获取格局在 2023 年前后发生了剧变。随着 AI 公司不断扩张模型训练规模，Reddit 和 Stack Exchange 等平台深刻意识到其用户生成内容(User-Generated Content, UGC)的商业价值，随即实施了严格的 API 访问限制(API Restrictions)与付费墙(Paywalls)策略。这标志着一个关键转折点：曾经可公开获取的社区数据(Community Data)正式转变为受到严密保护的商业资产(Commercial Assets)，从根本上重塑了未来训练数据集的构建范式。
![关键帧](keyframes/part004_frame_00547833.jpg)
![关键帧](keyframes/part004_frame_00558866.jpg)
![关键帧](keyframes/part004_frame_00570566.jpg)

---

## Dolma 数据集与标准预处理流水线
随着 2023 年前后平台数据访问权限的收紧，研究人员将目光转向了精选的学术资源与开放网络数据源。用于训练 AI2 OLMo 模型的 Dolma 数据集，整合了来自 Semantic Scholar 的 4000 万篇学术论文以及常规的网络数据源。其预处理(Preprocessing)遵循相对标准的处理流水线(Data Pipeline)：首先通过语言识别(Language Identification)筛选出英文文本，利用人工规则(Handcrafted Rules)进行初步清理，并在去重(Deduplication)前使用专用分类器(Specialized Classifier)进行有害内容(Toxic Content)过滤。该流程最终产出了约 3 万亿个词元(Tokens)，为开放、可复现的语言模型训练建立了一个基准(Baseline)，且全程无需依赖不透明的专有过滤器(Proprietary Filters)。
![关键帧](keyframes/part005_frame_00000000.jpg)
![关键帧](keyframes/part005_frame_00017399.jpg)
![关键帧](keyframes/part005_frame_00048866.jpg)
![关键帧](keyframes/part005_frame_00054600.jpg)

## DCLM 倡议与激进的数据集过滤
DataComp for LMs (DCLM) 项目作为一项协作倡议应运而生，旨在标准化数据集构建流程并设立基准测试(Benchmark)竞赛。以原始的 Common Crawl 数据转储(Data Dumps)为基础，研究人员汇编了 DCLM-POOL，这是一个规模高达 243 万亿词元(Tokens)的庞大数据池(Data Pool)。鉴于原始网络数据天然充满噪声(Noisy)，DCLM 采用了一套极为严格的过滤策略(Filtering Strategy)，由此生成了 DCLM-BASELINE。该数据处理流水线(Data Processing Pipeline)大幅缩减了语料库规模，仅保留了约 1.4% 的原始数据。其核心目标是为数据整理(Data Curation)算法的训练与评估提供一个干净、标准化的基准平台。
![关键帧](keyframes/part005_frame_00064033.jpg)
![关键帧](keyframes/part005_frame_00096866.jpg)
![关键帧](keyframes/part005_frame_00115700.jpg)

## 基于模型的过滤与范式转变
DCLM 的核心过滤机制依赖于一个 FastText 分类器(FastText Classifier)，该分类器基于精心筛选的正负样本(Positive/Negative Samples)训练而成。正样本提取自 OpenHermes（由 GPT-4 生成的指令微调数据(Instruction-tuning Data)）和 ELI5（“解释给我听，就像我五岁一样”）子版块(Subreddit)，从而有效利用高质量的对话与教学型文本来指导预训练数据(Pre-training Data)的筛选。负样本则采样自数据清洗程度较低的 RefinedWeb 数据集。由此构建的基于模型的过滤器(Model-based Filter)显著优于基于规则的替代方案(Rule-based Alternatives)，使基准测试(Benchmark)得分提升了 1-3%。这一成功标志着行业发生了决定性转变：业界在很大程度上摒弃了对分类器偏差(Classifier Bias)的过度担忧，转而全面采用“模型在环”(Model-in-the-loop)的过滤范式(Filtering Paradigm)。该方法能够持续产出质量更高、性能更优的数据集。
![关键帧](keyframes/part005_frame_00142433.jpg)
![关键帧](keyframes/part005_frame_00180899.jpg)
![关键帧](keyframes/part005_frame_00195366.jpg)
![关键帧](keyframes/part005_frame_00205799.jpg)
![关键帧](keyframes/part005_frame_00223766.jpg)
![关键帧](keyframes/part005_frame_00240766.jpg)
![关键帧](keyframes/part005_frame_00279700.jpg)

## NeMoTron-CC：在不牺牲质量的前提下实现规模扩展
英伟达(NVIDIA)推出的 NeMoTron-CC 有效解决了 DCLM-BASELINE 的一个关键局限：其激进的过滤策略将原始数据从 240 万亿词元(Tokens)大幅削减至仅 3.8 万亿，这对于训练超大规模前沿模型(State-of-the-art Models)而言规模严重不足。为在扩大数据规模的同时保障数据质量，NeMoTron-CC 优化了文本提取流水线(Text Extraction Pipeline)，将解析工具从 `trafilatura` 替换为 `justtext`，从而保留了更多的有效词元。数据质量评分采用双重评估策略：其一为从英伟达大型 NeMoTron 模型（经专项训练用于评估文本的“教育价值”）中蒸馏(Distilled)出的轻量级分类器，其二为 DCLM 分类器。该流水线并未单纯截取评分最高的头部文档，而是采用跨评分分布的分桶采样(Bucketed Sampling)策略，以确保数据集能够涵盖不同专家视角下的多样化质量层次。
![关键帧](keyframes/part005_frame_00320266.jpg)
![关键帧](keyframes/part005_frame_00329066.jpg)
![关键帧](keyframes/part005_frame_00373099.jpg)

## 合成转换与指令感知预训练
NeMoTron-CC 引入了创新的数据合成技术(Data Synthesis Techniques)，以最大化数据集的利用效率。面对低质量文档，系统并非直接丢弃，而是利用大语言模型(Large Language Model, LLM)将其重写为质量更高、逻辑更连贯的文本。相反，针对维基百科等高质量数据源，系统则自动生成指令式任务对(Instruction-style Task Pairs)，涵盖问答(Q&A)、摘要生成(Summarization)及关键信息提取(Key Information Extraction)等任务。这种主动式数据增强(Proactive Data Augmentation)方法将指令遵循能力(Instruction-following Capabilities)直接嵌入预训练阶段，使模型在正式进入后训练(Post-training)前便建立起显著的初始优势。凭借上述创新，该方案成功将高质量语料库的规模扩展至 6.3 万亿个词元。
![关键帧](keyframes/part005_frame_00443133.jpg)
![关键帧](keyframes/part005_frame_00516666.jpg)
![关键帧](keyframes/part005_frame_00531466.jpg)

## 基准测试表现与数据集规模背景
尽管 6.3 万亿词元的规模对于开源项目而言已相当可观，但仍小于 Llama 3（15 万亿词元）或 Qwen 1.5（36 万亿词元）等闭源专有语料库(Proprietary Corpora)。然而，NeMoTron-CC 在各项基准测试(Benchmarks)中的表现均优于 DCLM 和 FineWeb，其经过精心筛选的 1 万亿词元精英子集(Elite Subset)更是取得了更为卓越的性能表现。这一技术演进清晰地勾勒出现代数据策展(Data Curation)的发展轨迹：从依赖人工启发式规则(Handcrafted Heuristics)与硬性过滤，逐步迈向复杂的模型驱动评分(Model-driven Scoring)与合成数据增强(Synthetic Data Augmentation)，从根本上重塑了现代语言模型训练数据的构建范式。
![关键帧](keyframes/part005_frame_00551300.jpg)
![关键帧](keyframes/part005_frame_00558800.jpg)
![关键帧](keyframes/part005_frame_00582433.jpg)

---

## 多语言数据与研究重心
尽管当前大多数研究与主流模型仍高度聚焦于英语，但多语言数据(Multilingual Data)依然是全球人工智能(Artificial Intelligence)发展的关键前沿。Common Crawl 本身涵盖数十种语言的内容，研究人员也正积极构建专门的多语言数据集(Multilingual Datasets)，以强化模型的非英语处理能力。然而，由于语言识别(Language Identification)、文本规范化(Text Normalization)以及针对低资源语言(Low-Resource Languages)的质量过滤(Quality Filtering)具有高度复杂性，以英语为中心的数据处理流水线在学术基准测试(Academic Benchmarks)与工业训练实践中依然占据主导地位。
![关键帧](keyframes/part006_frame_00000000.jpg)

## 版权法基础
版权法(Copyright Law)是规范训练数据使用的核心法律框架。美国通过 1976 年《版权法》(Copyright Act of 1976)确立了相关制度，旨在通过保护“固定于有形表达媒介上的原创性作者作品”来激励知识产权(Intellectual Property)的创造。其核心原则在于，版权保护的是思想的*表达形式*(Expression of Ideas)，而非思想本身——你可以为源代码(Source Code)申请版权，但无法为底层的算法(Algorithms)或数学概念(Mathematical Concepts)申请版权保护。作品在创作完成时即自动获得保护；正式注册(Registration)通常仅为提起侵权诉讼的前置条件。版权保护期一般为数十年（依具体法域而定，原文提及为 75 年），期满后作品将进入公有领域(Public Domain)。因此，实际上几乎所有现代网络内容在默认状态下均受版权保护。
![关键帧](keyframes/part006_frame_00031000.jpg)
![关键帧](keyframes/part006_frame_00048666.jpg)
![关键帧](keyframes/part006_frame_00064733.jpg)

## 授权策略与企业数据协议
为合法使用受版权保护的材料，开发者通常会寻求明确的授权协议(Licensing Agreements)或依托知识共享(Creative Commons)许可框架。知识共享许可协议在严格的版权限制与公有领域(Public Domain)之间架起了桥梁，使创作者能够在保留署名权等特定权利的前提下，授权他人自由分发、修改或进行商业使用。大型人工智能公司正日益频繁地与 Reddit、Shutterstock 和 Stack Exchange 等平台直接洽谈数据授权协议(Data Licensing Deals)，以确保获取权属清晰的训练语料库(Training Corpora)。然而，为去中心化的开放网络逐一获取授权在实操中几乎不可行，这迫使众多项目转而依赖法律例外条款(Legal Exceptions)，而非逐一签订商业合同。
![关键帧](keyframes/part006_frame_00086700.jpg)
![关键帧](keyframes/part006_frame_00095933.jpg)
![关键帧](keyframes/part006_frame_00122633.jpg)

## 合理使用原则与法律评估
当明确授权难以获取时，开发者通常会援引“合理使用”(Fair Use)原则。该原则允许在特定法定条件下，未经许可有限度地使用受版权保护的材料。法院在裁决时主要评估四项关键因素(Four-Factor Test)：（1）使用的目的与性质（倾向于具有转换性(Transformative)、教育性或非商业用途）；（2）受版权保护作品的性质（事实性内容(Factual Works)通常比高度虚构的文学作品更符合合理使用条件）；（3）所使用部分的数量与实质性(Substantiality)；（4）使用行为对原作品潜在市场(Potential Market)或价值的影响。“谷歌图书案”(Google Books Case)等标志性判例进一步巩固了这一法律共识：将受版权保护的文本用于构建搜索索引与生成摘要，属于高度转换性使用(Highly Transformative Use)，且不会对原作品市场产生替代效应。值得注意的是，版权的保护边界不仅限于逐字复制(Verbatim Copying)，还延伸至情节、人物设定与叙事结构。这意味着在语义层面(Semantic Level)的复现或高度模仿，同样可能引发潜在的法律风险。
![关键帧](keyframes/part006_frame_00139833.jpg)
![关键帧](keyframes/part006_frame_00178366.jpg)
![关键帧](keyframes/part006_frame_00194266.jpg)

## AI 训练、转换性使用与记忆化
机器学习(Machine Learning)模型的训练本质上涉及海量数据的摄入(Ingestion)与临时复制(Temporary Copying)，这一过程在技术层面会触发版权合规审查。技术支持者辩称，模型训练具有高度的转换性(Transformative Nature)，因为算法提取的是统计规律(Statistical Patterns)、句法规则(Syntactic Rules)与泛化的世界知识(Generalized World Knowledge)，而非单纯复制原始表达形式。然而，实证研究(Empirical Evidence)表明，语言模型在特定提示词(Prompts)的诱导下，确实能够记忆(Memorization)并逐字复述训练数据，这令“转换性使用”的法律辩护变得更为复杂。此外，开源开发(Open-source Development)还面临独特的法律障碍：公开托管(Hosting)与分发经过策展的数据集(Curated Datasets)本身即可能构成直接版权侵权，无论下游模型最终是否实际使用了这些数据。
![关键帧](keyframes/part006_frame_00207333.jpg)
![关键帧](keyframes/part006_frame_00229799.jpg)
![关键帧](keyframes/part006_frame_00250466.jpg)

## 服务条款、市场影响与法律边界
除版权法外，AI 开发者还必须严格遵守各平台特定的服务条款(Terms of Service, ToS)。即使数据本身已获得版权授权或属于公有领域，服务条款仍可能对数据抓取与访问施加额外限制。例如，通过自动化脚本抓取(Automated Scraping)YouTube 视频即直接违反其服务条款，无论上传者是否采用了知识共享许可协议。此外，AI 模型的经济影响(Economic Impact)仍是司法裁决中的决定性因素；若训练生成的模型直接与原作者形成市场竞争或实质性替代其商业市场，合理使用的辩护理由将被大幅削弱。版权原则(Copyright Principles)、转换性机器学习(Transformative Machine Learning)与平台治理(Platform Governance)的相互交织，构建了一个高度复杂且快速演进的法律环境(Legal Landscape)，这将从根本上重塑未来训练数据集的构建策略与合规路径。
![关键帧](keyframes/part006_frame_00331133.jpg)
![关键帧](keyframes/part006_frame_00336500.jpg)
![关键帧](keyframes/part006_frame_00374766.jpg)
![关键帧](keyframes/part006_frame_00426133.jpg)
![关键帧](keyframes/part006_frame_00532266.jpg)
![关键帧](keyframes/part006_frame_00571766.jpg)
![关键帧](keyframes/part006_frame_00583766.jpg)
![关键帧](keyframes/part006_frame_00600433.jpg)

---

## 模糊的界限：中训练、后训练与长上下文扩展
中期训练(Mid-training)与后训练(Post-training)之间的界限日益模糊，研发焦点已从单纯追求原始数据规模，转向有针对性地注入特定模型能力。这一阶段的核心驱动力之一是长上下文扩展(Long Context Extension)。由于自注意力机制(Self-Attention Mechanism)的计算开销呈平方级增长(Quadratic Complexity)，基础模型(Base Models)通常在较短的序列长度上进行训练，而当前的前沿模型(State-of-the-art Models)已支持超过 1000 万词元(Token)的上下文窗口(Context Window)。为高效实现这一目标，开发者避免在尚未成熟的模型上浪费算力(Compute)，转而在中期训练阶段引入长上下文数据(Long-context Data)。这需要精心策划或合成具有内在长距离依赖性(Long-range Dependencies)的数据集，例如完整书籍与复杂的数学证明，从而训练模型在长序列中维持逻辑连贯性并有效检索信息。
![关键帧](keyframes/part007_frame_00000000.jpg)
![关键帧](keyframes/part007_frame_00009299.jpg)
![关键帧](keyframes/part007_frame_00040266.jpg)
![关键帧](keyframes/part007_frame_00045800.jpg)
![关键帧](keyframes/part007_frame_00063800.jpg)

## 指令微调与任务格式的标准化
能力构建(Capability Building)的一个基础步骤是将传统的自然语言处理(Natural Language Processing, NLP)基准测试(Benchmarks)转换为统一的指令遵循格式(Instruction-following Format)。诸如 *Super-Natural Instructions* 等数据集将社区贡献的 1600 余项任务聚合为标准化提示词(Standardized Prompts)，而 *FLAN* 项目则证实，在此类多样化混合数据上进行训练，能够实现跨不相关任务的强大迁移学习(Transfer Learning)。其主要优势在于赋予模型多任务能力(Multi-task Capabilities)，使其具备强大的零样本泛化(Zero-shot Generalization)能力。然而，一个显著缺陷是这些提示词高度模板化(Highly Templated)，往往缺乏真实用户交互中自然、多变的语言特性。这一局限性促使研究社区转向优先采用更具动态性与开放性的指令数据(Instruction Data)，以更真实地反映用户与聊天机器人(Chatbots)的交互模式。
![关键帧](keyframes/part007_frame_00118233.jpg)
![关键帧](keyframes/part007_frame_00158666.jpg)
![关键帧](keyframes/part007_frame_00175566.jpg)
![关键帧](keyframes/part007_frame_00200666.jpg)

## 向合成数据生成的转变
为克服基于基准测试的提示词所固有的僵化性(Rigidity)，研究人员迅速转向采用合成数据生成技术(Synthetic Data Generation)。*Alpaca* 项目开创了“自我指令”(Self-Instruct)方法，即利用大语言模型从少量种子数据(Seed Data)中生成多样化的训练样本。*Vicuna* 则利用了 SharedGPT 等平台上用户分享的真实对话数据，而其他演进方法则包括模型自我对话(Self-Chat)或使用“Evol-Instruct”技术迭代式地提升问题复杂度(Iterative Complexity Enhancement)。此外，大规模网络爬取数据(Web Crawled Data)也可经由大语言模型(Large Language Models, LLMs)进行二次处理，自动从教育类与问答类网站中提取高质量的问答对(Q&A Pairs)。上述方法最终催生了诸如 *OpenHermes* 等开源协作数据集，它们通过聚合多源合成数据与人工精选数据，构建出用于监督微调(Supervised Fine-Tuning, SFT)的强大语料库。
![关键帧](keyframes/part007_frame_00209799.jpg)
![关键帧](keyframes/part007_frame_00232566.jpg)
![关键帧](keyframes/part007_frame_00247633.jpg)
![关键帧](keyframes/part007_frame_00254399.jpg)

## 人工标注与合成规模的权衡
尽管合成数据(Synthetic Data)具备优异的可扩展性(Scalability)，但人工构建的指令集因其精确性(Precision)仍备受业界重视。以 *Llama 2 Chat* 为例，该项目依赖人工标注员(Human Annotators)编写高质量的指令-响应(Instruction-Response)配对，其核心假设是：精心策划的数据在性能上显著优于海量但充满噪声的开源替代方案。然而，该方法成本高昂，也引发了广泛讨论：人类反馈强化学习(Reinforcement Learning from Human Feedback, RLHF)是否能作为模型对齐(Model Alignment)的更高效路径。近期的后训练数据混合策略(Post-training Data Mixing Strategies)（如 Llama 与 NeMoTron 模型所采用的方案）通常融合了公开聊天数据集(Open Chat Datasets)（例如 UltraChat）、基于宽松许可协议(Permissive Licenses)的开放权重模型(Open-weight Models)所合成的数据，以及受 R1 等前沿模型启发的高级推理轨迹数据(Advanced Reasoning Trajectories)。
![关键帧](keyframes/part007_frame_00277599.jpg)
![关键帧](keyframes/part007_frame_00295099.jpg)
![关键帧](keyframes/part007_frame_00305133.jpg)
![关键帧](keyframes/part007_frame_00318999.jpg)
![关键帧](keyframes/part007_frame_00336666.jpg)

## 许可限制与生成策略
合成数据的创建引入了复杂的许可协议(Licensing Agreements)与法律合规考量。使用 GPT-4 等专有闭源模型(Proprietary Models)生成数据虽便捷高效，但若将其输出用于训练竞争性商业模型，通常直接违反服务条款(Terms of Service, ToS)。因此，开源社区更倾向于利用开放权重模型(Open-weight Models)（如 Llama 或 Mistral）进行数据蒸馏(Data Distillation)，此类模型通常提供更为宽松的许可授权，明确允许数据生成及下游模型训练。若追求极致的法律安全性(Legal Safety)，开发者可选择完全依赖人工标注，但该方法不仅耗时且成本高昂。此外，其中还存在一种颇具讽刺意味的风险：标注员可能私下使用专有 AI 工具以加速工作流，从而在无意中再次引入潜在的版权许可责任(Copyright Liability)。
![关键帧](keyframes/part007_frame_00384633.jpg)
![关键帧](keyframes/part007_frame_00391033.jpg)
![关键帧](keyframes/part007_frame_00402333.jpg)

## 结论：数据作为核心差异化因素
现代数据集构建(Modern Dataset Construction)的核心启示在于：高质量数据并非天然可得，而是必须经过深度的数据工程化处理(Data Engineering)。原始的网络数据转储(Raw Web Data Dumps)通常过于嘈杂、高度非结构化且法律权属模糊，无法直接用于模型训练。将其转化为可用的训练词元(Training Tokens)需要依赖严格的数据处理流水线(Data Processing Pipelines)，涵盖文本提取、质量过滤(Quality Filtering)、去重(Deduplication)及格式标准化等关键步骤。随着模型架构逐渐收敛于同构的 Transformer 与混合专家(Mixture of Experts, MoE)设计，数据构成(Data Composition)已成为决定模型性能差异化的核心驱动力。尽管该领域仍面临严峻的法律、伦理与技术挑战，且当前实践在很大程度上仍依赖启发式方法(Heuristic Methods)，但这无疑为未来的算法研究与数据工艺迭代留下了广阔的探索空间。
![关键帧](keyframes/part007_frame_00448966.jpg)
![关键帧](keyframes/part007_frame_00456366.jpg)
![关键帧](keyframes/part007_frame_00498333.jpg)
![关键帧](keyframes/part007_frame_00543866.jpg)