#  Lecture 5： GPUs

生成时间: 2026-03-08 17:35:00

---

## 段落 1

**英文**: So hopefully everyone's having a good time with assignment one. It's due tonight. Let us know if you need an extension. Assignment due two is coming out soon. We're putting on the finishing touches onto some of the triton stuff. Hopefully you'll enjoy it. You'll get to implement Flash attention two or parts of Flash attention two, which I think will be nice. So today we're going to talk about GPUs. GPUs are the things that makes our language models go. So they're pretty critical to get, right? And if you haven't really studied the hardware that makes your models run, they can seem pretty mysterious.

**中文**: 因此，希望每位同学都能顺利愉快地完成第一次作业。作业今晚截止。如需延期，请及时告知我们。第二次作业即将发布，我们正在对部分Triton相关内容进行最后的完善工作，希望大家会喜欢。你们将有机会实现Flash Attention 2或其部分功能，我认为这会很有意思。今天，我们将探讨GPU。GPU是驱动我们语言模型运行的核心硬件，因此深入理解它至关重要。如果你此前并未系统学习过支撑模型运行的硬件知识，GPU可能会显得颇为神秘。

## 段落 2

**英文**: So my goal today is to try to make CUDA and GPUs less magic. And one of the things that I want to demystify, you don't have to understand the plot. There's a lot on the slide, I know. You know, why do GPUs get slow? And they get slow in very mysterious ways. You know, I will try to talk through this plot towards the end of lecture. As you increase the size of your matrix multiplies, you might expect, you know, either gets slower or faster or whatever, you get these very unpredictable looking wave-like patterns. And you're like, why is my GPU fast at certain multiples of certain numbers and slow at others? Right? It's very mysterious. I'll try to understand that. The other thing is we would like to understand how to make fast algorithms. I think almost all of you have heard of flash attention.

**中文**: 因此，我今天的目标是让CUDA和GPU显得不那么“玄乎”。我想澄清的一个问题是：你不必理解这张图。幻灯片上的内容很多，我知道。大家知道，GPU为什么会变慢？而且它们的变慢方式往往非常神秘。我会在讲座快结束时详细讲解这张图。当你增大矩阵乘法的规模时，你可能会预期其运行速度要么变慢、要么变快，或呈现其他某种规律，但实际却观察到这些极难预测的波浪状模式。你会不禁疑惑：为什么GPU在某些特定数值的整数倍时运行很快，而在另一些整数倍时却很慢？这确实非常神秘，而我将尝试揭示其中的原因。另一点是，我们希望理解如何设计高效的算法。我想在座的各位几乎都听说过FlashAttention。

## 段落 3

**英文**: It's the thing that makes, you know, much longer context possible by very cleverly computing the attention operation inside a transformer. And so maybe you would like to, you know, come up with new algorithms or new implementations like flash attention, right? Like what primitives and what components do we need to understand in order to be able. to do that, right? So those are kind of the two learning goals of today. The first one is, you know, by the end of the lecture, you should feel kind of comfortable with GPUs. You should kind of understand how they work. And the second one is you should feel comfortable accelerating certain parts of your algorithms. You make a new architecture. You should hopefully feel like you can try to accelerate that with CUDA. And because hardware is not necessarily the domain in which I work, you know, there's special resources that I have to give a lot of credit to, especially Horus. He's blog where he's got a lot of fun GPU facts that you can learn about.

**中文**: 它通过在Transformer内部极为巧妙地计算注意力操作，从而实现了更长上下文的支持。因此，你或许希望提出新的算法或新实现（例如FlashAttention），对吧？那么，为了实现这一点，我们需要理解哪些基础原语和组件呢？这正是我们今天要达成的两大学习目标：第一，在本节课结束时，你应对GPU感到较为熟悉，大致理解其工作原理；第二，你应能自如地加速算法中的某些部分——例如，当你设计出一种新架构时，应有信心尝试使用CUDA对其进行加速。由于硬件并非我的专业领域，我必须特别感谢一些宝贵的资源，尤其是Horus的博客，其中包含大量有趣且实用的GPU知识。

## 段落 4

**英文**: For example, why are matrix multiplies that are filled with zeros faster than ones that are not filled with zeros? You can learn by going to his blog. There's also other resources that I've drawn from, like the CUDA mode group and the nice TPU book from Google. If this topic interests you, you know, I'd encourage you to go and look at those resources to learn more. Because this is in some ways like a shallow, but hopefully, you know, complete coverage of the hardware. So today, we're only going to focus on, you know, non-parallel parts of the hardware stack. So we're going to study the GPU, like a single accelerator in depth, how they work in some important parts. I'm also going to talk very, very briefly about TPUs. Because in some ways, they're very similar, conceptually, to a GPU. And so my discussion here is going to carry over. And then once we understand kind of the hardware and execution model of the GPU, then we're going to try to understand what makes GPUs go fast on certain workloads, what makes them slow.

**中文**: 例如，为什么填充了零的矩阵乘法比未填充零的矩阵乘法更快？你可以通过访问他的博客来了解原因。此外，我还参考了其他一些资源，例如CUDA模式小组以及谷歌出版的优秀TPU专著。如果你对这一主题感兴趣，我建议你去查阅这些资料以深入学习。因为本部分内容在某种程度上属于浅层介绍，但希望至少能对硬件作一次完整覆盖。因此，今天我们仅聚焦于硬件栈中非并行的部分，即深入研究GPU——将其视为单个加速器，重点剖析其若干关键工作原理。我还会非常简要地介绍TPU，因为从概念上讲，TPU与GPU在某些方面非常相似，因此此处的讨论也适用于TPU。随后，在我们理解了GPU的硬件架构与执行模型之后，将进一步探讨：究竟哪些因素使GPU在特定工作负载下运行迅速，又有哪些因素导致其性能下降。

## 段落 5

**英文**: And then we're going to understand the performance. And then the last part, this is kind of going to be almost like a hands-on piece. I'm going to try to walk through flash attention. I'm going to take all of the lessons that we've learned and try to walk you through flash attention saying, see, here's how it all comes together. So that's the last part of today's lecture. So many of you have taken an NLP course. And these days in an NLP course, I think you teach some amount of scaling laws. And so you've probably seen this. And so this is just setting the context. We know that having more compute is helpful for training large language models.

**中文**: 然后我们将理解其性能表现。最后部分则近乎实践操作环节：我将带大家逐步剖析Flash Attention，综合运用此前所学的全部知识，向大家展示这些知识点是如何融会贯通的。这便是今天讲座的最后一部分内容。  
在座的许多同学都修读过自然语言处理（NLP）课程；而如今的NLP课程中，我想大家多少都会学到一些关于扩展定律（scaling laws）的内容，因此你们很可能已接触过相关内容。此处仅作背景铺垫：我们已知，更多算力有助于大语言模型的训练。

## 段落 6

**英文**: This is a pre-training scaling chart, but you could replace this with an inference scaling chart if you would like. It's generally agreed upon that the more compute you have, the more processing you can do on your data, you can ingest more data, you can train larger models, all of those lead to improved performance. So you might think of, of course, deep learning is really important. But what's really driven performance is faster hardware, better utilization, improved parallelization. So that's kind of setting the stage of why hardware is important to understand. And of course, once you think about compute scaling, you ask, OK, how do we get compute scaling? How do we get our models to train faster? So kind of in the early days of semi-contactor scaling, if you were thinking about, OK, CPUs, how do they get faster, they would scale under something called dendered scaling. With Moore's law, you would sort of double the amount of transistors on a chip every year. And if you have this doubling, what you end up is dendered scaling where smaller and smaller. transistors can be driven at faster and faster clock speeds with lower and lower power, which in turn give you more performance, right? And then in the 1980s to 2000s, this sort of tapped out. You can kind of see in this chart here by Hennessy and Patterson that single-threat performance, that's the blue dots here, that basically started paper out.

**中文**: 这是一张预训练扩展性图表，但您也可以根据需要将其替换为推理扩展性图表。人们普遍认为，计算资源越多，就能对数据执行更多的处理任务，能够摄入更多数据，并训练出更大的模型，而这些因素都会带来性能提升。因此，您可能会想到，深度学习固然非常重要，但真正推动性能提升的却是更快的硬件、更高的资源利用率以及更优的并行化技术。这也为理解硬件的重要性奠定了基础。当然，一旦考虑计算能力的扩展性，您自然会问：那么，我们该如何实现计算能力的扩展？又该如何加快模型的训练速度？在半导体工艺扩展的早期阶段，若以CPU为例，其性能提升遵循一种被称为“登纳德缩放定律”（Dennard Scaling）的规律。根据摩尔定律，芯片上的晶体管数量大约每年翻一番；而借助这种翻倍效应，最终实现了登纳德缩放——即晶体管尺寸不断缩小，同时可在更高时钟频率下运行，且功耗持续降低，从而整体提升了性能。然而，自20世纪80年代至21世纪初，这一规律逐渐趋于极限。您可从亨尼西（Hennessy）和帕特森（Patterson）绘制的这张图表中看出：单线程性能（图中蓝色圆点所示）基本已停滞不前。

## 段落 7

**英文**: Of course, the number of transistors didn't really start falling off. You did have chips with higher and higher transistor densities, but that wasn't helpful. It wasn't giving you higher throughput on single-threats. And so this means that we can't just do computation faster in absolute terms. What we have to make up for it with is parallel scaling, right? So the story of scaling for deep learning and neural networks is going from single-threat scaling, which is doing your computation faster in absolute terms to parallel scaling, where you have a lot of workloads that are all computed at once. And this is one of my favorite compute scaling charts by Bill Daly and his keynote, where he's showing the super-exponential increase in the number of integer operations per second, going from the earliest K20s to the H100. Right? It's kind of like this really remarkable super-exponential curve. And so we have to really understand how to take advantage of this curve in order to really get the most out of our language model. So that's kind of going to be our goal. And so I've already hinted at this kind of important difference.

**中文**: 当然，晶体管数量实际上并未真正开始下降。你确实拥有了晶体管密度越来越高的芯片，但这并无助益——它并未提升单线程任务的吞吐量。因此，这意味着我们无法单纯依靠绝对意义上的计算速度提升来加速运算；而必须转而借助并行扩展来弥补这一不足，对吧？于是，深度学习与神经网络的扩展演进历程，便从单线程扩展（即在绝对意义上加快计算速度）转向了并行扩展（即同时处理大量工作负载）。这是比尔·戴利（Bill Daly）在其主题演讲中展示的一张我最钟爱的计算能力扩展图表：图中清晰呈现了整数运算每秒操作次数（OPS）从最早的K20显卡到H100显卡所实现的超指数级增长。没错，这是一条极为显著的超指数曲线。因此，我们必须深入理解如何充分利用这条曲线，才能真正将语言模型的性能发挥到极致——而这正是我们接下来的目标。此前，我已隐约提示过这一关键差异。

## 段落 8

**英文**: CPU is something that I think everyone's familiar with once you start doing programming. If it's execution model, if you have a program, it goes through, and in a single-threat,. it executes step-by-step what's happening. And in order to support that kind of an execution model, what do you need? Well, you need big control units. You just need to generally run these things very quickly because you have a lot of branching and you have a lot of conditional control logic, right? So the CPU, this is an abstracted diagram, is going to dedicate a lot of its chip towards large control branch prediction, and it's going to run these very quickly because it doesn't have that many threads. There's CPUs with lots and lots of cores now, but compared to a GPU, it's almost nothing. And so in contrast, the GPU has really tons and tons of compute units, ALUs, right? So there's the little green boxes. And there's much smaller amounts of the chip dedicated to control. So there's a little bit of control logic sort of orchestrating tons and tons of compute units. And so there's a lot of different things that are operating in parallel.

**中文**: CPU 是一种只要开始编程，大家就都会熟悉的部件。就执行模型而言，当你运行一个程序时，它会按顺序逐步执行——在单线程模式下，指令是逐条执行的。为了支持这种执行模型，我们需要什么？显然，我们需要庞大的控制单元；而且这些单元通常必须高速运行，因为程序中存在大量分支和条件控制逻辑，对吧？因此，CPU（此处为抽象示意图）会将芯片的大部分面积用于构建大型控制单元和分支预测电路，并以极高的速度运行这些单元，毕竟其线程数量非常有限。如今虽已出现拥有大量核心的 CPU，但与 GPU 相比，其核心数量几乎可以忽略不计。相比之下，GPU 则拥有海量的计算单元（即算术逻辑单元，ALU），图中那些小小的绿色方块就代表这些单元；而 GPU 芯片中仅有一小部分面积用于控制逻辑，仅需少量控制逻辑即可协调成百上千个计算单元协同工作。因此，GPU 中有大量不同的部件在并行运行。

## 段落 9

**英文**: And I think mentally, so this is kind of the picture of what is being emphasized in. a CPU versus GPU. But if you kind of look at what the design goals are, they are designed for very different sort of goals. So you can think about CPUs as optimizing for latency. I want to finish my tasks as quickly as possible. So if I have tasks, T1 through T4 here on the right side, in a CPU, I'm going to try to finish each task as quickly as possible. And so if you want any one of these tasks to be finished quickly, T1 is going to complete. really quickly. In GPU, you're optimizing for high throughput. I don't care about latency.

**中文**: 从思维层面来看，这大致体现了CPU与GPU各自强调的重点。但若审视二者的设计目标，便会发现它们旨在实现截然不同的目标。可以将CPU理解为以降低延迟（latency）为优化目标：即尽可能快地完成任务。因此，若右侧列出了T1至T4等若干任务，在CPU中，我会尽力使每一项任务都尽快完成；换言之，若希望其中任一任务快速结束，则T1将极快完成。而GPU则以高吞吐量（throughput）为优化目标，对延迟并不在意。

## 段落 10

**英文**: I just want all of my tasks that I have an aggregate to complete as quickly as possible. And to support that, maybe you have lots of threads. And these threads can go to sleep and wake up very quickly. And in the end, you finish all of your workload, T1 through T4, before the CPU one does. Even though individually, all of these have sort of higher latency, right?. So they have different sort of design principles and design goals. OK. And so a GPU has a pretty different anatomy. And I don't know if you all have ever looked at what a GPU sort of layout diagram looks. Like I'll actually show you the chip figures in a moment here.

**中文**: 我只想尽快完成所有需要聚合处理的任务。为支持这一点，系统可能拥有大量线程；这些线程可以极快地进入休眠和唤醒状态。最终，您能在CPU1完成之前，就全部处理完T1至T4的所有工作负载——尽管单个任务的延迟实际上更高，对吧？因此，它们遵循的是截然不同的设计原则与设计目标。好的，GPU的架构与此大相径庭。大家是否曾了解过GPU的布局结构图？稍后我将为大家展示芯片的实际结构图。

## 段落 11

**英文**: But the core idea, and this is important conceptual concept behind a GPU, is that a GPU executes many, many SM streaming multi-processors. And a streaming multi-processor, you can kind of think of as an atomic unit. When you're programming in something like Triton, they're going to operate at the level of SM. And within each SM, it contains many SPs, streaming processors. And a streaming processor is going to execute a whole bunch of threads in parallel. So one way to think about it is SM has a bunch of control logic. It can decide what to execute. It can do, for example, branching. SPs are going to take the same instruction and apply it to many different pieces of data. And so you can do tons and tons of parallel computation under this model.

**中文**: 但其核心思想——这也是GPU背后一个重要的概念——在于，GPU可同时执行大量流式多处理器（SM）。流式多处理器可视为一种原子单元；当你使用Triton等工具进行编程时，操作粒度即为SM级别。每个SM内部包含多个流式处理器（SP），而每个流式处理器则并行执行大量线程。换言之，SM具备一套控制逻辑，能够决定执行何种指令（例如支持分支操作）；而SP则对大量不同的数据并行执行同一条指令。因此，该模型可实现海量的并行计算。

## 段落 12

**英文**: And SM is sort of each granular unit of control. SP can do a lot of computation individually. And if you look at an A100, which is the previous generation GPU at this point, you've got 128 SMs. That's a lot more than the most cores for CPUs. And each of these SMs is going to have a very large number of SPs and specialize sort of matrix multiply units inside them. And so that's kind of the compute model. Was there a question? Sorry. So the question was, is this GPU the same as that? Yes. This is a cartoon version of this. You can kind of think of each row as being SM.

**中文**: 而流式多处理器（SM）是一种细粒度的控制单元。流处理器（SP）可独立执行大量计算。以A100为例——当前这一代GPU的上一代产品，其拥有128个SM，数量远超CPU的核心数。每个SM内部均配备大量SP，并集成专用的矩阵乘法运算单元。这便是其计算模型的基本架构。请问有疑问吗？抱歉，刚才的问题是：这个GPU是否与那个相同？是的，此处展示的是该GPU的示意图，您可将图中每一行理解为一个SM。

## 段落 13

**英文**: It's got its own control units. Each green block might be sort of one of these green blocks here, like a SP32 sort of processing unit inside of it. And each SM can sort of operate various pieces that it owns like the tensor cores to do computation. Cool. Okay. And there's going to be two important things. You think of GPU as computers. They compute. But actually, computation is only one of the two important things we have to keep track of. Memory is arguably more important at this point.

**中文**: 它拥有自己的控制单元。每个绿色方块可能就代表此处的一个绿色方块，例如内部集成的SP32类处理单元。每个流式多处理器（SM）可调度并运行其所属的各种计算单元（如张量核心）来执行计算任务。很棒！好的。接下来有两个关键点需要关注：我们通常将GPU视作计算机，用于执行计算；但实际上，计算仅是我们需重点关注的两大要素之一，而内存在此阶段甚至更为重要。

## 段落 14

**英文**: And it will continue to be more important in terms of the performance profiles of how we run our programs on the GPU. And so to understand memory, you kind of have to understand the physical layout of the GPU and the chip. Because in some sense, when you're operating at such fast speeds, the physical proximity. of the memory starts to matter quite a bit. And so I will show you kind of the physical proximity of how things are laid out and how that relates to how you should think about memory access and performance. So the closer a piece of memory is to each SM, the faster it's going to be. So there's going to be certain very, very, very fast kinds of memory like L1 and shared memory. And that's going to live inside of the SM, right? And that's going to be really fast, right?. Things like registers, things like things you're reading and writing very frequently. You're going to want to put into the L1 and shared memory.

**中文**: 而且，它在GPU程序运行性能特征方面将变得愈发重要。因此，要理解内存，就必须了解GPU及其芯片的物理布局。因为在如此高速运行的情况下，内存的物理位置远近会显著影响性能。接下来，我将向您展示内存等组件的物理布局方式，并说明这种布局如何影响您对内存访问和性能的思考方式。简而言之，内存距离每个流式多处理器（SM）越近，其访问速度就越快。因此，存在某些极快的内存类型，例如L1缓存和共享内存，它们就位于SM内部，因而速度极快。像寄存器这类频繁读写的数据，就应存放在L1缓存或共享内存中。

## 段落 15

**英文**: L2 cache, as you can kind of see, there's these green areas, which are SMs. And then there's these blue areas. This is on the GPU chip, right? These are L2 memory that's sort of right next to the SMs, right? So they're not inside the SMs, but they're physically still quite close, right? And these are still pretty fast. They're still a factor of 10 slower, but they're still reasonably fast. And then outside of the chip itself, this is sort of a, you know, I think this is like a 3090 card or something like this, or maybe a PCIe A100. Oh, this is a PCIe A100. You know, you've got your GPU here, and you've got actually DRAM sort of living next to the chip, right? So it has to actually go physically outside of the chip and connect. And you can kind of see on this chip diagram here, these yellow connectors at the edges. These are HBM connectors. These are connecting to the DRAM chips that are outside of the actual GPU.

**中文**: 二级缓存（L2 cache）——如您大致可见，图中这些绿色区域代表流式多处理器（SM），而蓝色区域则代表位于GPU芯片上的二级内存，它们紧邻SM，但并未集成在SM内部；不过从物理位置上看，它们仍非常靠近SM，因此访问速度依然相当快——尽管比SM内部的存储慢约10倍，但仍属于高速存储。而芯片外部的存储，则对应于某款显卡，例如RTX 3090或PCIe接口的A100加速卡（此处为PCIe A100）。您可以看到，GPU芯片旁边实际布置着DRAM内存，数据必须经由芯片外部的物理连接进行传输。从这张芯片结构图上可清晰看到边缘处的黄色连接器，这些即为高带宽内存（HBM）接口，用于连接位于GPU芯片外部的DRAM芯片。

## 段落 16

**英文**: And you can kind of see the speed that it takes to access these, right? The on SM memory is much, much faster, like 20 clock cycles to access something from there, whereas it's going to take something like 200 or 300 clock cycles to access something from the L2 cache or global memory, right? And this factor of 10 is going to hurt you real bad, right? So if you have a piece of computation that requires you to access global memory, right?. It might mean that you actually run out of work to do on your SM. You've multiplied all the matrices. You run out, now you just have to idle, right? So utilization won't be good. And this will be a really key theme, thinking about memories, in some sense, the key to thinking about how GPUs work. And in assignment two, you're going to actually be writing high performance code for a GPU. So you have to actually think about the execution model of how a GPU actually executes things. And this is somewhat complicated, but not insanely so. There's sort of three granularities of things that you need to think about. There's blocks, there's warps, and there's threads.

**中文**: 你能大致看出访问这些存储器所需的速度差异，对吧？片上SM内存的访问速度要快得多，例如从其中读取数据仅需约20个时钟周期；而从L2缓存或全局内存中读取数据则需要约200至300个时钟周期，对吧？这种10倍的性能差距会严重拖累你的程序运行效率，对吧？因此，如果你的某段计算任务需要频繁访问全局内存，就可能导致SM无事可做——你已将所有矩阵乘法运算完成，却只能空等，对吧？这样一来，硬件利用率就会很低。而内存访问问题，某种意义上正是理解GPU工作原理的关键所在。在第二次作业中，你将实际编写面向GPU的高性能代码，因此必须深入思考GPU的实际执行模型。这一模型虽有一定复杂性，但并非难以理解。总体而言，你需要从三个粒度层级来思考：线程块（block）、线程束（warp）和线程（thread）。

## 段落 17

**英文**: And that's the order in which kind of the granularity narrows down, right? Blocks are kind of these big groups of threads. And each block is going to be assigned to a SM. So think about this as each SM is kind of a worker, it's its own autonomous unit. And a block is going to be assigned to an SM to process, right?. So this is each granular unit. Now, then within these blocks are a whole bunch of threads. Each thread is a piece of task that needs to be done. And when these threads execute, they're going to execute in groups. And this is a thing called a warp, right? So you take a block, which is a collection of threads. And you're going to take threads from that block.

**中文**: 这正是粒度逐级细化的顺序，对吧？线程块（Block）是线程组成的大组；每个线程块将被分配给一个流式多处理器（SM）。可以将每个SM想象成一名“工人”，它是一个独立自主的处理单元；而一个线程块则会被分配给某个SM进行处理，对吧？这就是每个粒度层级上的基本处理单元。接着，在这些线程块内部，包含大量线程；每个线程代表一项待执行的任务。当这些线程运行时，它们将以组为单位执行，这种线程组称为“线程束”（Warp），对吧？也就是说，你从一个由多个线程组成的线程块中，取出其中的线程来构成线程束。

## 段落 18

**英文**: And they're going to execute in groups of 32, consecutively number threads each time. And that's sort of called warps. And so you can kind of see at this diagram here what's happening, you've got a bunch of blocks. Each block is assigned to a different SM. And within each block there's going to be many different warps. And each warp is going to consist of a whole bunch of threads. And all of these threads are going to execute the same instruction on different data, right? And so this is kind of the execution model. Right now it seems probably mysterious what these blocks and warp and threads are. They will have important implications for performance in how we design things like kuda kernels later. So hopefully you can kind of remember this.

**中文**: 它们将以每组32个线程的方式执行，每次连续编号的线程构成一组，这种线程组被称为“warp”（线程束）。从图中可以看出，当前有一组线程块（block），每个线程块被分配到不同的流式多处理器（SM）上；而每个线程块内又包含多个不同的线程束，每个线程束则由大量线程组成。所有这些线程将同时执行同一条指令，但处理各自不同的数据，这便是其执行模型。目前，线程块、线程束和线程的具体含义可能尚不清晰，但它们在后续设计CUDA核函数时对性能具有重要影响。希望你能对此有所记忆。

## 段落 19

**英文**: I'll refresh your memory kind of as we go. Hopefully that's clear. So that was the kind of logical execution model of a GPU. And if you understand that, you kind of understand how GPUs execute things. There's also a logical sort of memory model of a GPU. So now I'm not showing you the physical hardware. This is just kind of how you think about the programming of a GPU. And so there's registers. So these are really fast, storing single numbers type storage. You've got local memory, you've got shared memory, and you've got global memory, right? And that increases in sort of the memory hierarchy.

**中文**: 我将在讲解过程中适时帮您回顾相关要点，希望这样能更清晰明了。以上便是GPU的逻辑执行模型，若您理解了这一点，也就基本掌握了GPU的执行方式。此外，GPU还存在一种逻辑上的内存模型。此时我所展示的并非实际硬件结构，而仅是您在对GPU进行编程时应具备的抽象思维框架。其中包含寄存器——这是速度极快、专用于存储单个数值的存储单元；此外还有本地内存、共享内存和全局内存，它们共同构成了逐级递增的内存层次结构。

## 段落 20

**英文**: You get slower and slower and slower. And your code can sort of write to global memory. You can also write the constant memory, which is not something that's used too often. And so each thread can access its own register and shared memory. But information that goes across blocks need to be written to global memory. This is actually quite important, right? So now it means that whenever you write a thread that executes something, ideally it's operating on sort of the same small amount of data. So you load that small amount of data into shared memory. All the threads are very happy accessing that shared memory. It terminates, it's done, right?. That would be a great execution model.

**中文**: 你的执行速度会变得越来越慢。同时，你的代码可以向全局内存写入数据，也可以向常量内存写入数据（不过后者并不常用）。因此，每个线程均可访问其自身的寄存器和共享内存。但跨线程块传递的信息则必须写入全局内存。这一点实际上非常重要，对吧？因此，现在意味着：当你编写一个执行某项任务的线程时，理想情况下它应操作同一小块数据。于是，你将这一小块数据加载到共享内存中；所有线程都能高效地访问该共享内存。线程执行完毕后即终止，对吧？这将是一种极佳的执行模型。

## 段落 21

**英文**: Instead, if you have a thread that needs to access data all over the place, that's going to have to access global memory. That's very, very slow. This theme will come back as we talk about different ways of operating on a GPU. Hopefully that's clear. That's kind of the very high level four slide overview of a GPU. If you have questions about how on your networks feel free to ask me as I go. Okay, so here's a side thread. Last year I didn't cover this because I think resources on TPUs was a little thin. But the nice TPU book or internet website that I mentioned at the start of the lecture came out. And that has actually a lot of nice details.

**中文**: 相反，如果你有一个线程需要在各处访问数据，那么它就不得不访问全局内存，而全局内存的速度非常、非常慢。这一主题将在我们讨论GPU上不同运算方式时反复出现。希望这一点已经讲清楚了。以上便是关于GPU的高层次、仅四页幻灯片的概览。如果大家对网络相关的问题有任何疑问，欢迎在我讲解过程中随时提问。好的，接下来我们另起一个话题。去年我没有讲这部分内容，因为当时关于TPU的资料还比较匮乏。但我在本讲座开头提到的那本优秀的TPU专著或网站现已出版上线，其中实际上包含了许多详尽而精彩的内容。

## 段落 22

**英文**: And I talked to a few Google people about the TPU. And at the high level, it's very, very similar to a GPU. And so I want to just talk for a moment about TPUs. You may never operate on a TPU, but I think it's important to understand. that these alternative accelerators operate in many ways very similarly. So here's a diagram of what a TPU looks like. There's something called a tensor core. And mentally you can think about a tensor core as being similar to SM or streaming multi-processory. Each of these are kind of its own atomic units that can operate on data. There's a scalar unit which is basically a control unit.

**中文**: 我还与几位谷歌员工讨论了TPU。从高层架构来看，TPU与GPU非常、非常相似。因此，我想花一点时间谈谈TPU。你可能永远不会直接操作TPU，但我认为理解这些替代加速器在许多方面运作方式高度相似，这一点非常重要。下图展示了TPU的结构：其中有一个称为“张量核心”（tensor core）的部件。你可以将其在概念上类比为SM（流式多处理器）。每个张量核心都可视为一个独立的原子运算单元，能够对数据执行操作；此外还有一个标量单元，其本质上是一个控制单元。

## 段落 23

**英文**: And it can also do CP like arbitrary things. You've got a vector unit that can operate on vector. So if you got a vector and you want to operate entry wise on it, that's a good place to do it. And then it's got a very big specialized part of the chip dedicated to just doing matrix multiplies called the MXU. And then it's got very fast memory for vector memory and SMEM. Both of these are very fast on chip or like on tensor core memory. And then there's high bandwidth memory that lives outside of the chip. So hopefully you see the similarities to an SM, right? There's slow memory outside, very fast memory inside, and there's specialized hardware to do matrix multiplication. Core structure is very much the same. The difference is, I'll talk about this in the parallelism lecture next week.

**中文**: 它还能执行类似任意操作的CP（协处理器）功能。你拥有一个可对向量进行运算的向量单元，因此若你有一个向量并希望对其各元素分别进行运算，这正是理想的执行位置。芯片中还设有一个规模庞大的专用部件——矩阵乘法单元（MXU），专用于执行矩阵乘法运算。此外，它配备了高速的向量内存和标量内存（SMEM），这两类内存均位于芯片内部，速度极快，类似于张量核心内存。芯片外部则配备高带宽内存。因此，你应当能察觉到其与流式多处理器（SM）的相似之处：外部是较慢的内存，内部是极快的内存，并配有专门用于矩阵乘法的硬件。其核心结构也基本相同。至于差异部分，我将在下周的并行性课程中详细讲解。

## 段落 24

**英文**: You know how the accelerators are networked together is a little bit different. And then also, you know, mention I didn't notice I didn't talk about warps. I didn't talk about any of that other stuff. Tensor cores are in some ways very simple because they're optimized to just do matrix multiplies, right? Like the tensor core, unlike the GPU, doesn't attempt to do anything but that. And so that's in some ways very, very simple, much simpler in architecture,. but conceptually doing the same thing. Yes? So the question was, you know, is it called tensor because it can operate on arbitrary tensors? So it can operate on arbitrary tensors, like in new indexing. The operations that a MXU performs is a matrix multiply. And so it would always be like a batch matrix multiply operating on a tensor. So it's kind of both a yes and a no answer, if that makes sense.

**中文**: 您知道，这些加速器之间的组网方式略有不同。另外，您可能注意到了，我之前并未提及“线程束”（warps），也未讨论其他相关内容。张量核心（Tensor Core）在某些方面非常简单，因为其设计初衷就是专门优化矩阵乘法运算，对吧？也就是说，与通用GPU不同，张量核心仅专注于执行矩阵乘法，别无他用。因此，从某种意义上说，其架构极为简洁，远比GPU简单，但在概念上实现的功能是相同的。  
是的？刚才的问题是：之所以称为“张量核心”，是否因为它能处理任意张量（例如支持新型索引方式）？  
实际上，它确实可以处理任意张量，但其计算单元（MXU）所执行的基本操作始终是矩阵乘法，具体而言通常是批处理矩阵乘法（batch matrix multiply），即在张量上执行该操作。因此，这个问题的答案既可说是“是”，也可说是“否”，不知您是否理解这一说法。

## 段落 25

**英文**: So they operate on tensors, but the operations they always perform are matrix multiplies,. not more complicated tensor operations that you can do. Cool. The reason why the GPU has been so successful is that, you know, it scales up really easily. If you want more processing power, just add more SMs, right? You don't have to worry about driving the clock faster and getting more heat dissipation problems. Programming wise, CUDA is intimidating, but it's actually, you know, not as horrendous the program because of the programming model. Like the way it works is within each SM, right?. You have a thread and it executes the same instruction on a bunch of different pieces of data, right? That's conceptually sort of easy to reason about. You can think through what that means. And especially it's nice if you're operating over a matrix and you're doing sort of very simple operations.

**中文**: 因此，它们在张量上运行，但执行的操作始终是矩阵乘法，而非更复杂的张量运算。很棒！GPU之所以如此成功，原因在于其扩展性极佳：若需更强的处理能力，只需增加更多流式多处理器（SM）即可，无需担心提升时钟频率所带来的散热问题。就编程而言，CUDA看似令人生畏，但实际上并不像人们想象中那般可怕，这得益于其编程模型——其工作方式是在每个SM内部，线程以相同指令对大量不同的数据执行操作，这种概念在逻辑上相对容易理解，你可以清晰地推演其含义；尤其当你对矩阵进行操作且执行的是较为简单的运算时，这种设计尤为便利。

## 段落 26

**英文**: It's exactly this kind of SIMC model. Finally, each of these threads are very lightweight and they can be kind of stopped and started. at any time. So if you need to wait for another thread or if you need to sort of like evict something and like start another process, all these threads are very lightweight. So this just kind of means that there's not much state associated with the threads and they can kind of be stopped and started, which allows GPUs to get high utilization within sort of each SM. So GPUs, you know, obviously graphics processing units. And for much of its life, you know, in the early days, it was not used to do scientific. computing. But people, because it was programmable, researchers figured out how to use early Nvidia GPUs to do fast matrix multiplies. This is one of the early papers on doing fast matrix multiplies with graphics hardware.

**中文**: 这正是此类SIMC模型。最终，每个线程都非常轻量，可随时暂停和恢复。因此，当需要等待其他线程，或需要将某些任务“驱逐”并启动另一进程时，所有这些线程均极为轻量。这意味着线程关联的状态极少，因而可随时暂停与恢复，从而使GPU在每个流式多处理器（SM）内实现高利用率。GPU即图形处理单元，众所周知；在其发展早期，主要并非用于科学计算。但由于其具备可编程性，研究人员发现可利用早期NVIDIA GPU高效执行矩阵乘法运算。这篇论文便是最早探讨如何借助图形硬件实现快速矩阵乘法的研究之一。

## 段落 27

**英文**: And it shows how you can hack kind of things like the texture buffer and so on to get it to do matrix multiplies. And so even without specific support for map moles, researchers figured out how to do it. But I think now, you know, especially in this day and age, Nvidia and others have realized. matrix multiplies are special. Like if you're doing deep learning, right, most of your workload is matrix multiplies. And so matrix multiplies are in some sense blessed operations. So this is a chart showing the number of tariff flops per second by different generations of Nvidia GPUs. And the orange line is your map mole flops, right? Like with your performance, you can get if you're doing map moles. The blue line is your non-map mole flops, right?. And you see kind of this big gap at V100s when they started putting in sort of tensor cores that were specialized hardware to do matrix multiplies.

**中文**: 它展示了如何通过“黑入”纹理缓冲区等机制，使其执行矩阵乘法运算。因此，即使没有对矩阵乘法（map mole）的专门硬件支持，研究人员也找到了实现方法。但如今，尤其是当下，英伟达等厂商已充分认识到：矩阵乘法具有特殊性——例如在深度学习中，大部分计算负载正是矩阵乘法。因此，矩阵乘法在某种意义上被视为一类“受优待”的运算。本图展示了不同代际英伟达GPU每秒可提供的TFLOPS（万亿次浮点运算）数量。其中橙色曲线代表矩阵乘法（map mole）性能，即执行矩阵乘法时所能达到的运算性能；蓝色曲线则代表非矩阵乘法（non-map mole）性能。可以看到，在V100系列GPU推出时，二者性能差距显著扩大——这是因为该系列首次引入了专用于加速矩阵乘法的张量核心（Tensor Core）等专用硬件。

## 段落 28

**英文**: And you see this gigantic gap in the matrix multiply performance relative to the non-map mole performance, right? And so if you're going to design any sort of a neural architecture, I was saying this, you know, in the architecture part as well, you have to have most of your workload be matrix multiplies because that's the thing that, you know, orders of magnitude faster than any other operation that you're going to be able to do on a GPU, right?. So if you make a non-map mole based neural network, you're going to be in a big, big trouble. And then kind of the last thing that I want you to kind of understand as just general facts, you know, map moles is fast is one thing. But the other thing that's important to remember is kind of the relative scaling of the different components of the GPU. So this is a very nice chart that shows, you know, how quickly different components of the GPU or different components of the, let's call it like LM training stack are scaling. So the blue line is the connectivity from the GPU to the host, right?. Like the server that it's attached to, right? So you can use PCIe, you can use NV link, you can use all these fancy interconnects, they are growing, but they're going somewhat slowly, right? So this chart is like normalized scaling, you know, bandwidth relative to, you know, the first generation of interconnects. The green line, this is the global memory speed, right? So you go from GDDR to HBM2E and that's much, much faster, right? This is log scale, it's 100x faster, but this is still kind of slow scaling, right?. And the gray line here, right, this is compute scaling. This is the number of floating point operations if you're, you know, considering the map mole flops.

**中文**: 您可以看到，矩阵乘法的性能与非MapMole操作的性能之间存在巨大的差距，对吧？因此，如果您要设计任何类型的神经网络架构——我之前在架构部分也提到过这一点——那么您的大部分计算负载都必须是矩阵乘法，因为这是GPU上所能执行的所有操作中，速度比其他任何操作都要快几个数量级的操作，对吧？所以，如果您构建一个基于非MapMole操作的神经网络，那将面临非常严重的问题。最后，我还希望您能理解一些基本事实：一方面，MapMole本身很快；另一方面，同样重要的是要记住GPU各组件之间相对的扩展速度。这是一张非常清晰的图表，展示了GPU各组件（或我们称之为大模型训练栈的各组件）的性能扩展速度。蓝色曲线代表GPU与主机（即其所连接的服务器）之间的互连带宽，例如PCIe、NVLink或其他各类先进互连技术；这些互连技术虽在持续发展，但其增长速度相对较慢，对吧？该图表采用归一化标度，即以第一代互连技术的带宽为基准进行衡量。绿色曲线代表全局内存速度，即从GDDR升级到HBM2E后带来的显著提速，速度快了数十倍（注意这是对数坐标，实际提升达100倍），但其扩展速度仍属相对缓慢。而灰色曲线则代表计算能力的扩展，即针对MapMole浮点运算（FLOPs）所衡量的浮点运算次数。

## 段落 29

**英文**: So this is how fast the compute has been scaling and this is astoundingly fast, like one to 100,000 times faster. And so kind of in the early days of the scaling, maybe your problems were flops based, right? Like you just didn't have enough flops to do your matrix multiplications. But now, you know, all the way to the right with the H100s, you know, these are astoundingly fast GPUs, your bottlenecks are probably going to end up being memory, right? Because memory is not growing as fast, right? As we go into the future, you know, this is not really going to change. DRAM is very hard to scale. You're going to keep getting this bigger and bigger gap, right? So if you're ever designing, you know, hardware-efficient algorithms, you're going to have to think more and more about memory, right?. And so we're going to keep a look out on that. I'm going to keep emphasizing this. It's one of the important themes in GPUs, okay? So, you know, I've been kind of throwing lots of GPU facts at you, especially if you haven't, you know, seen this recently and maybe me kind of new. So just to recap, right? GPUs are these massively parallel processing systems. They have same instructions applied across many different threads, and they have these.

**中文**: 因此，计算能力的提升速度就是如此之快，而且快得令人震惊，达到了1倍至10万倍的提升幅度。在算力扩展的早期阶段，你的问题可能主要受限于浮点运算能力（FLOPS），例如矩阵乘法所需的FLOPS不足；但如今，随着H100等GPU发展到图示最右侧位置，这些GPU的运算速度已惊人地快，你的性能瓶颈很可能将转向内存——因为内存带宽和容量的增长速度远不及计算能力。展望未来，这一趋势基本不会改变：DRAM技术本身极难持续扩展，因此计算能力与内存性能之间的鸿沟将持续扩大。因此，当你设计面向硬件效率的算法时，就必须越来越重视内存相关问题。我们将持续关注这一挑战，我也会不断强调这一点——这正是GPU领域中一个至关重要的主题。好了，刚才我向大家密集介绍了许多GPU相关知识，尤其如果你近期未曾接触过相关内容，或对此尚不熟悉，可能会略感信息量较大。下面简要回顾一下：GPU是一种大规模并行处理系统，它对大量不同线程同时执行相同的指令，并具备以下特性……

## 段落 30

**英文**: things called SMs, which are kind of like cores that, you know, there's many, many of them in the GPUs. Compute and matrix multiplies have scaled really fast, and they have scaled faster than memory, and that is an important part of the characteristics that you think about GPUs. But there is some fast memory, right? It's not like everything is slow, so there's nothing we can do. There's the memory hierarchy, right? So some kinds of memory are very, very fast. Other kinds of memories are slow, and so if we exploit this hierarchy, maybe we can get things that are really, really fast, right? So that's kind of things to remember about the GPU, and if you remember these facts, you know, you're going to be able to think pretty cleanly about the performance components that I'm going to talk about next. Any questions before I move on to the next part? Okay. Cool. So now you all are GPU experts, and what we would like to do is we would like to make machine learning workloads go very fast on AGPU. And so I'm going to start with this chart, and one of our goals will be to understand what this chart exactly is. I think it'll be a good puzzle to get us motivated.

**中文**: 称为“流式多处理器”（SM）的单元，类似于计算核心，GPU中包含大量此类单元。计算能力与矩阵乘法性能提升非常迅速，其增速甚至超过了内存带宽的增长，这是理解GPU特性的关键点之一。但GPU中确实存在高速内存，对吧？并非所有内存都慢得无法利用，因此我们仍有优化空间。GPU具备内存层次结构，对吧？其中某些类型的内存速度极快，而另一些则相对较慢；若能充分利用这一层次结构，或许就能实现极高的运行效率，对吧？以上便是关于GPU需要牢记的要点；若能记住这些事实，你便能清晰地思考我接下来要讲解的性能相关要素。在进入下一部分之前，大家有什么问题吗？好的，很好。现在，各位都已成为GPU专家了。我们的目标是让机器学习工作负载在GPU上实现极致加速。接下来，我将从这张图表开始讲解，我们的一个目标就是准确理解该图表的含义。我认为这将是一个很好的谜题，有助于激发我们的学习兴趣。

## 段落 31

**英文**: And so here, what we are doing is we are multiplying square matrices together, right? So the x-axis is the size of my square matrix multiplies. And the y-axis here, this is the number of operations per second that I'm doing. So you can kind of think of this as hardware utilization on the y-axis, right? And so as I get bigger and bigger matrices, I'm going to get better and better hardware utilization, because I have more work to do, so I don't, you know, that overwhelms the overhead of sort of launching jobs and things like this. But there's all these weird things that are happening, right? You see, one, two, three different, four different lines, right? And each of these lines are kind of wavy in a way that's kind of, you know, books very unpredictable, right?. And so we would like to kind of understand what exactly is going on with these lines. And by the end of this section, my promise is that you will kind of understand exactly each one of these phenomena, and you'll be able to say, yeah, that plot looks totally normal. That is a natural thing for GPU to do. Okay. So the very first part, right, is if you look at that plot, you will notice that it looks a little bit like this, right?. And if you've taken a system's hardware course, you know, you should remember this as kind of the roofline model.

**中文**: 因此，在此处，我们正在进行方阵之间的相乘运算，对吧？横轴表示我所乘方阵的尺寸，而纵轴则表示我每秒执行的运算次数。因此，你可以将纵轴大致理解为硬件利用率，对吧？随着矩阵尺寸不断增大，我的硬件利用率也会越来越高，因为需要处理的工作量增加了，从而能够有效掩盖诸如启动任务等操作所带来的开销。但与此同时，还出现了许多奇怪的现象，对吧？你看，这里有一条、两条、三条，甚至四条不同的曲线，对吧？而每条曲线都呈现出某种波浪状起伏，其变化方式相当难以预测，对吧？因此，我们希望深入理解这些曲线背后的确切原因。而在本节结束时，我承诺你将完全理解每一种现象，并能自信地说：“没错，这张图看起来完全正常，这正是GPU的典型行为。”好的，首先来看最开始的部分：如果你仔细观察这张图，就会发现它看起来有点像这样，对吧？如果你修过系统硬件课程，就应该记得这种模型——即所谓的“屋顶线模型”（roofline model）。

## 段落 32

**英文**: The roofline model basically says if we're looking at, you know, throughput or utilization, you know, what we're going to find is, you know, there's two regimes. There's going to be a regime that is sort of memory limited, right? That is on the left side of this curve on the green over here. And then there's a part that is throughput limited on the right side. In some sense, you can kind of think of it as on the right side, we have, we are fully. utilizing our compute units. All the matrix multiplying, it's our multiplying all the time. And on the diagonal here, we just have some sort of memory bottleneck. And so our ability to do computation is limited by kind of the amount of sort of intensity that we have, the amount of flops that we have. So we want to avoid being in this left side region where we're memory bound. And we would like to be on this right side where we're getting in some sense full utilization of all of our compute units.

**中文**: 屋顶线模型的基本观点是：当我们考察吞吐量或利用率时，会发现存在两种运行状态。一种是内存受限状态，即位于该曲线左侧（图中绿色区域）；另一种是吞吐量受限状态，即位于曲线右侧。从某种意义上说，在右侧区域，我们的计算单元处于完全利用状态——矩阵乘法运算持续满负荷运行；而在对角线区域，则存在某种内存瓶颈，此时我们的计算能力受限于计算强度（即每单位内存访问所能执行的浮点运算次数）。因此，我们应避免处于左侧的内存受限区域，而力求进入右侧区域，以实现所有计算单元的充分、高效利用。

## 段落 33

**英文**: So that's in some sense the goal. And hopefully this roofline model looks something like this, right? Like we've got sort of this diagonal part and then we've got this flat part all the way at the top here. So that's one part of the mystery. And so this turns out to be kind of complex, right? The simple way to say this is, let's make sure that we're not accessing memory unnecessarily. We have as few memory accesses to slow global memory as possible. But it turns out that in order to do that, we need a large array of tricks. There's a lot of different things that you could do that would mess you up that would make you very slow. And the first one's not a memory bottleneck. I'll just mention it. It doesn't come up too often.

**中文**: 因此，从某种意义上说，这就是目标。希望这个屋顶线模型看起来大致如此，对吧？即我们有一段对角线部分，然后在顶部有一段完全水平的部分。这便是谜题的一部分。而实际上，要实现这一点相当复杂，对吧？简单来说，就是确保我们不会不必要地访问内存，尽可能减少对缓慢的全局内存的访问次数。但事实证明，为了做到这一点，我们需要掌握大量技巧。有许多不同的做法都可能导致性能严重下降。第一个问题并非内存瓶颈，我仅在此提一下，它并不常见。

## 段落 34

**英文**: We'll get it out of the way. And then we'll talk about the remaining five items that in some sense are really core. to thinking about GPU performance. OK, so the first thing that I want to talk about is conditionals. So as I said before, GPUs, their execution model is something called SIM-key, right? Single instruction multi-thread. And so every thread in a warp is going to execute the same instruction. And it's going to do so on different data. And so what happens if I write a piece of code that looks like this? I have an if statement. And if the thread index is less than 4, do something. If the thread index is greater than or equal to 4, then do something else, right? I have this very simple conditional model.

**中文**: 我们先将这个问题解决掉，然后再讨论其余五个在某种意义上真正核心的问题，这些问题关乎GPU性能的思考。好的，我首先要讨论的是条件语句。如前所述，GPU的执行模型称为SIMT（单指令多线程），即每个线程束（warp）中的所有线程都将执行同一条指令，但处理的数据各不相同。那么，如果我编写了如下代码会怎样？其中包含一个if语句：若线程索引小于4，则执行某操作；若线程索引大于或等于4，则执行另一操作。这就是一个非常简单的条件分支模型。

## 段落 35

**英文**: If I run this on the GPU, what's going to happen is that I am going to run the a instruction on four of my threads. I will actually pause my other fourth threads, which are supposed to be executing the L spark. And then these other fourth threads will come alive. And they will execute X. And my original fourth threads will go to sleep. And I will just alternate executing each of these instructions. Why is that? I can't execute A and X at the same time on these different threads, right? As I said again, every thread has to execute the same instruction. So conditional statements within a single warp can be really, really damaging, because they will force you to pause any of the threads that are not doing exactly the main sort. of control flow execution. OK, so that was the only non-memory thing that I wanted to mention.

**中文**: 如果我在GPU上运行这段代码，那么我将在我的四个线程上执行指令a。此时，我实际上会暂停另外四个本应执行L spark的线程；随后，这另外四个线程将被唤醒并执行X；而我原先那四个线程则进入休眠状态。如此反复交替执行这些指令。为什么会这样呢？我无法让不同线程同时执行A和X，对吧？正如我之前所强调的，每个线程都必须执行相同的指令。因此，单个线程束（warp）内的条件语句可能造成极其严重的性能损害，因为它们会迫使所有未遵循主控制流路径执行的线程全部暂停。好了，以上就是我想提及的唯一一个与内存无关的问题。

## 段落 36

**英文**: And it should be kind of obvious that you should probably not be putting conditionals into your massively parallel compute unit. But once we've gotten that out of the way, the other tricks that we need to consider are all kind of memory-based. The first thing I want to mention is lower precision. And this is a big trick. This is an important trick. You should do it all the time. There's kind of going back to the spot of buildally. There's a slide of hand here. This looks really good, because the numbers are going up and up and up. But if you look at what's driving GPU progress over all these years, you actually kind of see that it's number representations.

**中文**: 而且，显然你不应该在大规模并行计算单元中加入条件判断语句。但一旦排除了这一点，我们还需考虑的其他技巧基本上都与内存相关。首先我要提到的是降低精度，这是一个非常关键且重要的技巧，你应该始终采用。这又回到了“构建性”（buildally）这一概念的起点——此处存在一个巧妙的障眼法：图表看起来效果极佳，因为数值持续攀升；但若仔细考察多年来推动GPU性能进步的根本因素，你就会发现，真正起决定性作用的是数值表示方式。

## 段落 37

**英文**: You go from FP32 to FP16 to Int8 to so on. You get many orders of magnitude gains from just having lower and lower precision in your GPU operations. And let me sort of clarify why that's so important. If you have fewer bits in all the things that you're computing and your weights and so on, you have much fewer bits to move. So even if you're accessing these bits from global memory, they become much, much less of a concern. So let's just give a simple example. And let's just think about arithmetic intensity of a simple element-wise operation. So I'm going to do any value. So that's x equals max 0 and x. And I'm going to do that on a vector of size n.

**中文**: 你从FP32逐步过渡到FP16、Int8等更低精度格式。仅通过不断降低GPU运算的精度，就能获得多个数量级的性能提升。让我简要说明这为何如此重要：当你在计算过程中（包括权重等）所使用的位数更少时，需要传输的数据位数也大幅减少；因此，即便这些数据需从全局内存中读取，其带来的带宽压力也会显著降低。下面举一个简单例子加以说明：考虑一个简单的逐元素运算的计算强度。例如，执行任意值的ReLU操作，即 \( x = \max(0, x) \)，并将其应用于长度为 \( n \) 的向量。

## 段落 38

**英文**: Let's say in naively, I'm going to do this on float32. So how many memory accesses do I have? I have to read my x. I have to write the result of if x less than 0. And that's all in float32. So that's kind of eight bytes. And how many operations do I do? Well, I have to do x less than 0. So that's one comparison operation. And I do one flop. So I do eight bytes per single floating point operation. If I do this in float16, now, well, I haven't changed the flops intensity here.

**中文**: 简单来说，我将使用 float32 来实现这一操作。那么，我需要多少次内存访问呢？我需要读取输入 x，还需要写入“若 x 小于 0”的判断结果，且所有数据均以 float32 表示，因此总共约需 8 字节。我又需要执行多少次运算呢？首先需进行一次 x 小于 0 的比较运算，再执行一次浮点运算（flop），即总共仅需一次浮点运算。因此，每次浮点运算对应 8 字节的内存访问量。若改用 float16 实现，此处的计算强度（flops 强度）并未改变。

## 段落 39

**英文**: But I have the memory access. And so now I have four bytes per flop. In some sense, I've gotten double the memory band with for free, assuming that I can get away with flop16. And this is a key part of how a lot of things are designed. Part of the assignment is going to be you're going to try and play with various like mixed precision or low precision training and other kinds of things. And a key part here is that not all the parts of your network and your training algorithm. should be put into low precision. So let me give you an example of matrix multiplies. So in matrix multiplies that are mixed precision, what you would do is you would have your inputs be 16 bit. So these are low precision.

**中文**: 但我拥有内存访问能力，因此现在每个浮点运算（flop）只需4字节。从某种意义上说，假设我能采用半精度浮点数（flop16），那么我就免费获得了两倍的内存带宽。这也是许多系统设计中的关键部分。本次作业的一部分内容，就是要求你们尝试各种混合精度或低精度训练等方法。此处的关键在于，并非网络及训练算法的所有部分都适合采用低精度。下面我以矩阵乘法为例进行说明：在混合精度的矩阵乘法中，输入数据通常采用16位表示，即低精度。

## 段落 40

**英文**: And then you're going to do your multiplication in full 32 bit. And that's useful because the intermediate computations, as you're accumulating partial sums, you would like that to be in high precision. And so you're accumulating this with the FP32 accumulator. And then your tensor core will return a FP32 result, which you can downcast if you would like back into 16 bit. And so we have our inputs in 16 bit, but things like the accumulation we might want to do in 32. So there's lots of different things. There's operations that can use 16 bit storage. There's operations that might need more precision. So you want to keep it in either FP32 or FP16. You might want to have operations that need more range, like x functions.

**中文**: 然后，您将使用完整的32位进行乘法运算。这很有用，因为在累加部分和的中间计算过程中，您希望这些计算具有高精度，因此采用FP32累加器进行累加。随后，张量核心将返回一个FP32结果，您可根据需要将其降级为16位。因此，我们的输入采用16位表示，但累加等操作可能需使用32位。此外，还有许多其他情况：有些运算可采用16位存储，而有些运算则可能需要更高精度，因此您可能希望以FP32或FP16格式保留数据；还有一些运算（如x函数）可能需要更大的数值范围。

## 段落 41

**英文**: If you don't have the dynamic range, they might blow up or zero out. And so you might want to put those in vf16. There's a lot of careful engineering that has to happen in order to make sure that these models are actually stable when they're being trained with lower precision. But if you can do it, that's really great because you've basically doubled the throughput of your bottleneck going from 32 to 16 bit, right?. If you remember easier bottleneck. OK. The other one, and I think this is kind of what a lot of people think of when they say, like, I'm going to write a CUDA kernel or something. Your fusion is both very intuitive and both a fun, natural one to think about. So one memory, sorry, one mental model of how a GPU works and how memory works is this kind of fun diagram of a factory from Horus' heat. Imagine you have a factory and your factory is your compute part.

**中文**: 如果你的动态范围不足，数值可能会溢出或归零。因此，你可能需要将这些数据存入vf16格式中。为确保模型在低精度训练过程中保持稳定，需进行大量精细的工程优化。但若能成功实现，效果将非常显著——因为将计算精度从32位降至16位，本质上使你的瓶颈环节吞吐量提升了一倍，对吧？还记得之前提到的“更易成为瓶颈”的情形吗？好的。另一点是——我认为这正是许多人提及“我要编写一个CUDA核函数”之类说法时所想到的内容：算子融合既非常直观，又是一种自然且易于理解的思路。关于GPU及内存工作原理，一种有趣的思维模型来自Horus’ Heat提出的“工厂示意图”：想象你拥有一座工厂，而这座工厂就代表你的计算单元。

## 段落 42

**英文**: And so it takes in little box widgets and then outputs little triangle widgets. If you grow your compute, but your bell conveyor that takes memory to compute is finite bandwidth, you're not going to be able to use your second factory, right? You're still capped by the speed at which you can transfer things from memory to compute. And so you've got this bottleneck. Now of course, you already knew that. I've been hammering in the memory bottleneck thing. But I think one in a city is way in which you can incur a ton of overhead without really. realizing it. It's kind of this left hand side computation pattern. So imagine the left side of this pot is where the memory is. The right side is your compute unit.

**中文**: 因此，它接收的是小型方块状组件，输出的则是小型三角形组件。如果你扩大了计算资源，但负责将内存数据传输至计算单元的“铃铛传送带”带宽有限，那么你就无法充分利用第二座工厂，对吧？你的性能仍受限于内存向计算单元传输数据的速度，从而形成了这一瓶颈。当然，这一点你早已知晓，我此前也一直在反复强调内存瓶颈问题。但我认为，在城市中部署计算资源时，存在一种极易产生大量开销却不易察觉的方式，即这种偏向左侧的计算模式：试想，这个容器的左侧代表内存，右侧则代表你的计算单元。

## 段落 43

**英文**: And so to do computation, I start with a square and I move my squares from my memory to my compute. I do some operation. I turn them into triangles, right?. Now I shift my triangles back to memory and then, you know, okay, I realize I need my triangles again. So I shift them back into the compute unit. Now the triangle becomes circles and it's so on and so forth, right? I send my compute sort of back and forth and back and forth back to memory. And you might call this kind of a very naive approach. And if you were just doing operations naively on the GPU and just shipping the results straight back to global memory, this is what you'd end up with, right?. And if you count the number of times a piece of data went back and forth, this is pretty terrible. You've incurred tons of memory overhead.

**中文**: 因此，为了执行计算，我从一个正方形开始，将正方形从内存移至计算单元；执行某些运算后，将其转变为三角形，对吧？接着，我再把三角形移回内存；然后，你明白的，我发现还需要用到这些三角形，于是又将它们移回计算单元；此时三角形又变成了圆形，如此反复，对吧？我不断地将数据在计算单元与内存之间来回传送。你或许会称这种做法为一种非常朴素的方法。如果你只是在GPU上简单地执行运算，并直接将结果原封不动地送回全局内存，最终就会得到这样的结果，对吧？而若统计一下数据在两者之间往返的次数，这种做法就相当糟糕了——你已招致了巨大的内存开销。

## 段落 44

**英文**: Now you should be able to realize that if you look at the right side, well, there's no dependencies. I should be able to go square to triangle the circle to rectangle and ship the rectangle back, right? And I keep everything in the compute unit the whole time, right?. And that's the right hand side diagram. And this is the mental model of a fused kernel, right? You have a bunch of operations that are going to happen on a piece of data in sequence. Instead of writing it back into storage, what I'm going to do is I'm going to do all the computation as much as I can in one place and then only when I have to ship it back to memory, right? So that's this idea of kernel fusion. Okay. There are some very simple examples of how if you write some naive code, you might get sort of a naive set of launches. So here's an example. I wrote a little, let's say neural network module. Let's say I write a neural network module that takes in x and it produces sine squared x and cosine squared x, right? Simple code.

**中文**: 现在你应该能意识到，如果观察右侧，嗯，这里没有任何依赖关系。我完全可以按“正方形→三角形→圆形→矩形”的顺序执行运算，然后将矩形结果返回，对吧？而且整个过程中，所有数据始终保留在计算单元内，对吧？这就是右侧的示意图。它正是融合核（fused kernel）的思维模型：即对某一块数据依次执行一系列运算；与其将中间结果反复写回存储器，不如尽可能在同一个位置完成全部计算，仅在必须将最终结果写回内存时才执行该操作，对吧？这便是核融合（kernel fusion）的核心思想。  
好的，下面举几个非常简单的例子，说明若编写一些朴素的代码，可能会导致一系列低效的内核启动。例如，这里有一个例子：我编写了一个小型神经网络模块——假设该模块接收输入 x，并输出 sin²x 和 cos²x，对吧？代码很简单。

## 段落 45

**英文**: Now, if I run this, the computation graph in PyTorch is going to look something like this. And it's going to launch a whole bunch of CUDA kernels. It's going to launch, take in the x and it'll launch a CUDA kernel to compute sine x, it'll launch one to compute cosine x, then sine squared of x and cosine squared of x and sine squared x plus cosine squared of x, right? So there's a bunch of back and forth that has to happen in order to use computation. It's exactly the left hand side figure that I showed you before. But if you were a little smarter, right, and you either wrote your own CUDA kernel or you use something like Torch Compile, well, you can easily realize that those five operations. don't really depend on very much. Like, they use only a little bit of memory. And so you can fuse them into a single operation that does everything on GPU on a single thread without sending things back to global memory, right? So really easy fusion operations like this can be done automatically by compiler. So I just mentioned Torch Compile. If you aren't already doing this, you should consider strongly thinking about using Torch Compile everywhere.

**中文**: 现在，如果运行这段代码，PyTorch 中的计算图将呈现如下形态，并会启动大量 CUDA 核函数：首先接收输入 x，然后启动一个 CUDA 核函数计算 sin(x)，再启动另一个计算 cos(x)，接着分别计算 sin²(x) 和 cos²(x)，最后计算 sin²(x) + cos²(x)，对吧？因此，为完成这些计算，必须在设备间频繁地来回传输数据。这正是我之前展示的左侧示意图所描述的情形。但如果你更聪明一些——比如自行编写 CUDA 核函数，或使用 Torch Compile 等工具——你便很容易意识到，上述五个操作彼此之间依赖性极小，且仅需极少内存。因此，可将它们融合为单个 GPU 操作，在单一线程上一次性完成全部计算，无需将中间结果反复写回全局内存，对吧？诸如此类极为简单的算子融合操作，编译器完全可以自动完成。我刚刚提到了 Torch Compile；如果你尚未采用它，那么强烈建议你在所有适用场景中全面启用 Torch Compile。

## 段落 46

**英文**: We'll show you in the assignment Torch Compile as well. It's pretty nice. Okay. So I've gone through precision and fusion. If anyone has questions, let me know the front move on to recomputation and other kinds of tricks that we can do on the GPU. Okay, good. So another thing that we can do is called recomputation. And recomputation is this idea of sort of spending more compute to avoid having to do memory access, right? So remember that your original back propagation lecture, this one's actually from CS221. What do we do? Well, we take our inputs at the very bottom. These are the yellow ones.

**中文**: 我们还将在作业“Torch Compile”中向您展示，效果非常不错。好的，我已经讲解了精度和算子融合。如果大家有任何问题，请随时提出；接下来，我们将进入重计算及其他可在GPU上使用的优化技巧。好的，很好。另一种我们可以采用的技术称为重计算（recomputation）。重计算的核心思想是：通过增加计算量来避免内存访问，对吗？回想一下您最初学习反向传播的课程——本例实际上源自CS221课程。我们具体怎么做呢？首先，从最底层的输入开始，也就是图中这些黄色节点。

## 段落 47

**英文**: And then we propagate activations upwards. Those are also the yellow values on the tree. And then we compute the Jacobian's backwards. Those are the green values on the edges. And then to compute my gradients, I'm going to propagate, you multiply, so the Jacobian and the activations, I'm going to propagate the gradients backwards. Well, if you think about it, those yellow values after the forward pass have to be stored, right? And then they're stored and they have to be taken from global memory where I stored them and put them into the compute unit. Mechanically, that's how it has to happen. But that might actually be a ton of sort of memory inputs and outputs happening. Instead, you might actually be able to avoid this. So let me give you an example of how recomputation can speed things up.

**中文**: 然后，我们向上传播激活值，这些也是树上的黄色数值。接着，我们反向计算雅可比矩阵，这些是边上绿色的数值。最后，为了计算我的梯度，我将进行反向传播——即对雅可比矩阵与激活值进行乘法运算，并将梯度反向传播。但仔细想一想，前向传播后得到的这些黄色数值必须被保存下来，对吧？随后，它们被存入全局内存，再从该内存中读取并送入计算单元。从硬件机制上讲，这确实是必须执行的过程。但如此一来，可能会产生大量内存读写操作。而实际上，我们或许可以避免这种情况。下面，我将通过一个例子说明重计算（recomputation）如何提升运算速度。

## 段落 48

**英文**: Here's another sort of silly function that I might write. I'm just going to stack three sigmoids on top of each other. You can look at the left. That's the forward graph. That should be exactly your mental model of three sigmoids on top of each other. Now, the computation graph for this, I'm going to compute the sigmoids and I'm going to store S1 and S2, which are the activations of the sigmoids. And I have my outputs. And then that's my sort of forward pass. Now, the backward pass in this is kind of terrible. When I do my backward graph, I need to go and take S1 and S2.

**中文**: 这里还有另一个我可能会写的傻乎乎的函数：我只是将三个Sigmoid函数简单地堆叠在一起。你可以看左侧——那是前向计算图，它应恰好对应你脑海中“三个Sigmoid函数逐层堆叠”的直观模型。现在，该函数的计算图如下：我将依次计算这三个Sigmoid函数，并存储S1和S2（即前两个Sigmoid函数的激活值），同时得到最终输出；这就是我的前向传播过程。而反向传播过程则相当糟糕：在构建反向计算图时，我需要回溯并调用S1和S2。

## 段落 49

**英文**: And I need to take the gradients coming sort of backwards into this outbox and. then push it into this backwards computation and I'll get the gradient of X. So I need to have three memory reads, one memory write, in order to compute the backwards pass. And then for the forward pass, I need to do one memory read of X. And I need to do three memory writes for S1, S2, and L. So hopefully that's clear. This is a decent amount of memory reads and writes. I have to do eight of them and I have very low arithmetic intensity because I have no. matrix multiplies at all. So the idea of recomputation is to say, I don't want to store those activations at all.

**中文**: 我需要将梯度反向传入该输出缓冲区，再将其送入反向计算过程，从而得到关于X的梯度。因此，在执行反向传播时，我需要进行三次内存读取和一次内存写入。而在前向传播中，我需要读取一次X，并将结果分别写入S1、S2和L，共三次内存写入。希望这一点已表述清楚。这涉及相当数量的内存读写操作——总计八次，且算术强度极低，因为我完全未使用任何矩阵乘法运算。因此，“重计算”（recomputation）的思想是：我根本不想存储这些中间激活值。

## 段落 50

**英文**: Like I'm not going to put them into memory. I'm just going to recompute them on the fly in my backward pass. So now, in my new forward pass, I don't store S1 and S2. I take X as input, I compute my sigmoids and I get my output. So now that's one memory read for X, one memory write for out. Now in my backward pass, I don't have activations anymore. So what I'm going to do is I'm going to get both D out, which is the backwards signal coming in from above, and then X, which is my input. So I'm going to take two of those, which is two memory reads. And then sort of on the fly in my SM and my local memory, I'm going to compute each of these sigmoids and I'm going to put them into the backward graph. I'm going to recompute S1, S2, and out on the fly inside sort of my local memory.

**中文**: 就像我不会将它们存入内存一样，我只会在反向传播过程中动态重新计算它们。因此，在新的正向传播过程中，我不再存储S1和S2：我以X为输入，计算各层sigmoid函数，得到输出。此时，仅需一次内存读取（读取X）和一次内存写入（写入out）。而在反向传播过程中，我已不再保存任何激活值。因此，我将同时获取来自上层的反向信号D_out以及输入X，即进行两次内存读取；随后，在流式多处理器（SM）及其本地内存中动态计算各sigmoid函数，并将结果直接用于构建反向计算图——即在本地内存中即时重新计算S1、S2和out。

## 段落 51

**英文**: And because I do that, there's no global memory reads happening here. And then I have one memory write, which is DX. So now if you compare the two, I have five eighth of the memory access for the exact same computation. The price that we paid is that I'm going to have to recompute these three sigmoids. But if you were running idle anyway because you were memory capped, this is a great tradeoff. You will be very happy with this because now you've traded compute, which you have too much of, for memory bandwidth, which you had too little of. So this is one great way of trading one thing you need for another thing that you have. And of course, this is different. It's the same trick as sort of gradient check pointing and recomputing activations for memory savings. But this is being done for a different reason.

**中文**: 而且正因为我这样做了，此处便不会发生全局内存读取。接着，我仅执行一次内存写入操作，即写入DX。因此，现在若将两者进行对比，我在执行完全相同的计算时，内存访问量仅为原来的八分之五。我们为此付出的代价是：需要重新计算这三个Sigmoid函数。但如果你原本就处于空闲状态（因为受内存带宽限制），那么这便是一项极佳的权衡取舍。你会对此非常满意，因为你用过剩的计算资源换取了紧缺的内存带宽。因此，这是一种以一种富余资源换取另一种紧缺资源的绝佳方式。当然，这种做法虽有不同，但其原理与梯度检查点技术及为节省内存而重新计算激活值的技巧类似；不过，此处采用该方法的目的却有所不同。

## 段落 52

**英文**: This is for sort of execution speed, not just because you're running out of memory. So it's the same technique but for different goals. And then this one, I think, is actually kind of a really interesting one and not one that I knew until I started sort of really looking into how the hardware model of a GPU. and DRAM works. So the slow memory, the global memory called DRAM and a GPU, that's actually very, very slow. And in order to make it faster, there's certain optimizations that are being done at the hardware level. And one of the optimizations that's done at a hardware level for DRAM is that when you go and read a piece of memory, you don't actually get just that value back. You actually get a whole chunk of the memory back. And this is called burst mode. So let's say I went on and tried to read the very first value of this big memory block, right? Instead of just the memory giving me back zero, it would actually give me back zero, one, two, three, right? It would give me back four values at once.

**中文**: 这主要是为了提升执行速度，而不仅仅是因为内存不足。因此，虽然采用的是相同的技术，但目标却不同。接下来这个例子，我认为实际上非常有趣，而且在我开始深入研究GPU的硬件模型以及DRAM的工作原理之前，我对此也并不了解。GPU中的慢速存储器——即被称为DRAM的全局存储器——实际上非常慢。为了提升其访问速度，硬件层面会进行某些优化。其中一项针对DRAM的硬件级优化是：当你读取某块内存时，返回给你的并不仅仅是所请求的那个值，而是一整块内存数据，这被称为“突发模式”（burst mode）。例如，假设我试图读取这个大内存块的第一个值，那么内存并不会只返回数值“0”，而是会同时返回“0、1、2、3”这四个值。

## 段落 53

**英文**: So be like, here you go. You know, I'm sure you'll need the one, two, and three, two in the future. And so each address space is cut up into what's called burst sections and then you're given the entire burst section rather than just what you looked for. And this might seem very mystifying. Like why would the memory give you three extra, you know, bytes for free when you're just asking for one? There's sort of like a very interesting hardware reason, which is that when you're addressing into the memory, you know, in order to send the signal out from the memory that those bytes have to be moved to an amplifier, that's the slow step. And once you've done that, you can get many, many bytes for free. And so that's why sort of this burst section thing exists. It's kind of masking this more expensive step of actually moving where the data is stored to this amplifier. But kind of regardless, this kind of means that we might be able to significantly accelerate sort of our memory access. Because the pattern of memory access is good, right? So if I want to read this entire block over here, if I access it in random order, right,.

**中文**: 所以，就这样给你了。你知道，我确信你将来会需要一、二、三号，甚至两个这样的单元。每个地址空间被划分为所谓的“突发段”（burst sections），而你获得的是整个突发段，而不仅仅是所请求的那部分数据。这看起来可能非常费解：比如，当你只请求一个字节时，内存为何会免费额外给你三个字节？其背后其实有一个非常有趣的硬件原因：当向内存发出地址请求时，将对应字节的数据从存储位置传输至放大器所需的信号发送过程，才是最耗时的步骤；而一旦完成这一步骤，后续便可免费获取大量字节。因此，“突发段”机制便由此产生——它本质上是将数据从存储位置传输至放大器这一相对高成本操作加以掩盖。但无论如何，这种机制意味着我们有可能显著加速内存访问，前提是内存访问模式良好，对吧？例如，若我想读取此处的整个数据块，而采用随机顺序进行访问……

## 段落 54

**英文**: then I'm going to have to, you know, basically query a number of times equal roughly to the length of my query, right? But if I sort of go and I check the very first value, then I'm going to get all this entire burst section at once. And then if I go and check number four, I'll get this burst section, the second burst section at once. And so I can, you know, basically get four times the throughput if I'm really clever about my memory accesses and only access just the bits I need from each burst section. So this is called memory coalescing. So if all the threads in a warp fall within the same burst, then basically the sort of smart hardware and programming model will basically group those queries. Instead of querying 0, 1, 2, 3, it will group them and say, just give me 0 and then I will be able to read out all the 0, 1, 2, 3, up once from this kind of burst mode DRAM, right? So remember that, you know, a warp is 32 sort of numbered threads. And so memory accesses from a warp happened together. And so when these warps are reading in to these kind of burst sections, there's optimizations that can be done so that you're getting all four bytes at once rather than getting one of them at a time individually. And so that will 4x the throughput that you have on your memory, right? So these are kind of very simple things, but they're actually very important. Like imagine, I'm going to do matrix multiplications, right? This is a core thing that you're going to have to do a ton if you were to sort of implement, let's say, neural network really from scratch and kuda.

**中文**: 那么，我将不得不进行大约与查询长度相等次数的查询，对吧？但若我先检查第一个值，就能一次性获取整个突发（burst）段；而当我检查第四个值时，则能一次性获取第二个突发段。因此，只要我在内存访问上足够聪明，仅从每个突发段中读取所需的数据位，就能将吞吐量提升约四倍。这被称为内存合并（memory coalescing）。如果一个线程束（warp）中的所有线程所访问的地址均落在同一突发段内，那么智能硬件与编程模型便会自动将这些访问请求合并：它不会分别查询地址0、1、2、3，而是将其归并为一次请求——例如只请求地址0，然后便能通过这种突发模式DRAM一次性读出地址0、1、2、3对应的所有数据，对吧？请记住，一个线程束包含32个编号连续的线程，因此其中所有线程的内存访问是同步发生的。当这些线程束读取此类突发段时，系统可实施优化，使每次访问都能一次性获取全部4个字节，而非逐个单独读取。如此一来，内存吞吐量便可提升至原来的4倍，对吧？这些虽是相当基础的概念，却极为重要。试想，我要执行矩阵乘法——这恰恰是实现神经网络（尤其是从零开始用CUDA实现）时必须大量完成的核心运算。

## 段落 55

**英文**: In this case, imagine I'm going to read my matrices in one of two ways. I can read it by traversing the rows, right? So each thread is going to traverse the row. Or I can sort of read it in sort of column order. So each thread is going to go down a column, right? Turns out that this left one, where you're sort of going across different rows. So each thread is accessing a different, sorry, each thread is going through columns. This left model is going to be quite slow. Because the memory reads are not going to be coalesced. Whereas if you're going to this right side where each of the threads are going down, so they're incrementing in rows, then these memory reads will be coalesced. And so you can think about it for a moment why this is true. When I first looked at this diagram, I was like, isn't it reversed? It's actually not.

**中文**: 在这种情况下，假设我将以两种方式之一读取矩阵：一种是按行遍历，即每个线程遍历一行；另一种则是按列遍历，即每个线程沿一列向下访问。结果表明，左侧这种按列遍历（即各线程分别访问不同行中的同一列位置）的方式会非常慢，因为此时内存读取无法实现合并访问；而右侧这种方式中，各线程沿列方向向下访问（即在行索引上递增），内存读取则能够实现合并访问。你可以稍作思考，理解其中缘由。当我初次看到该示意图时，也曾疑惑：“难道不是反过来了吗？”但实际上并非如此。

## 段落 56

**英文**: This is the correct one. And the way to think about this is, let's say, on this right-hand side diagram over here,. I'm going to have a thread that's trying to, a series of threads that's trying to access, left to right. So each thread is going to try to load the very first element. And then in the next time step, I'm going to load the element from this column, the second column, and then the third column, and the fourth column, and so on. So if that happens, what happens at time step one? At time step one, my first thread loads this point, and then the second thread loads this point, and then this point and that point. So those can't be coalesced at all. They're reading different burst sections. And so that means that I have to read this entire chunk of memory in order to perform any sort of an operation. Instead, if I was sort of going in the column direction, all the threads will be reading within this single burst section, and then so only one memory read operation needs to be performed, and you get all the memory at once.

**中文**: 这才是正确的做法。其思路如下：假设我们看右侧的示意图，将有一系列线程从左至右依次访问数据。每个线程首先尝试加载第一个元素；在下一个时间步，所有线程将分别加载第二列中的对应元素，接着是第三列、第四列，依此类推。那么，在时间步一会发生什么？此时，第一个线程加载该点，第二个线程加载该点，然后是该点和该点——这些访问完全无法合并，因为它们读取的是不同的突发（burst）内存段。这意味着，为执行任何操作，我必须读取整块内存。相反，若按列方向访问，则所有线程均在同一突发内存段内读取数据，因而只需执行一次内存读取操作，即可一次性获取全部所需数据。

## 段落 57

**英文**: This is a very low level optimization, but this is very important. If your memory traversal order is all wrong, you will actually get much slower memory accesses than you really want. Okay. So then that brings us to kind of the very last and kind of big one. And this is the idea of piling. And piling is this idea that you would like to group together memory accesses in order to minimize the amount of global memory access that we have to do. And so to explain this one, I'm going to try to go through this example of a matrix multiply. And hopefully I'll be able to sort of explain to you why sort of a naive algorithm for doing matrix multiply is going to be very problematic. And then afterwards, I'm going to give you a tiled version of the same idea. And hopefully you'll be able to see why that's going to reduce the number of global memory reads that you have to do.

**中文**: 这是一种非常底层的优化，但至关重要。如果内存访问顺序设计不当，实际的内存访问速度将远低于预期。好的，接下来我们进入最后一个、也是最重要的一项优化——分块（tiling）。分块的核心思想是将内存访问进行分组，以尽量减少对全局内存的访问次数。为了解释这一概念，我将以矩阵乘法为例进行说明，并希望借此向您阐明：为何直接实现的朴素矩阵乘法算法会存在严重问题；随后，我将给出同一算法的分块版本，帮助您理解该方法如何有效降低全局内存读取次数。

## 段落 58

**英文**: So let's start with this very simple matrix multiply algorithm. So I've got a matrix. You know, I got this m matrix on the left side. I'm going to my n matrix on the top. And in order to compute the matrix matrix product, I'm going to have to traverse over the rows of m and the columns of m and then take the inner product and soar that into this p matrix, the corresponding rows. And I've written out here each of the threads, the threads 0, 0, 0, 1, 1, 0, 1, 1, corresponding to where they're sort of storing their outputs and sort of the access order in which they access each of the individual elements. Now notice here that what's going to happen is that the memory access here is not coalesced. Like the row matrices here, these are going to be accessed in a non-coalesced order. And I have repeated memory accesses, right? So I've got m 0, 0 being accessed in the first thread, m 0, 0 accessed here, n 0, n 1, 0 being accessed in two different threads. You know, so these values are being kind of read over and over from global memory into many different threads.

**中文**: 因此，我们从这个非常简单的矩阵乘法算法开始。我有一个矩阵：左侧是一个 m 矩阵，上方是一个 n 矩阵。为了计算这两个矩阵的乘积，我需要遍历 m 的行与列，并计算其内积，再将结果存入输出矩阵 p 的对应位置。此处我已列出各线程（如线程 (0,0)、(0,1)、(1,0)、(1,1)）各自存储输出的位置及其访问各个元素的顺序。请注意，此处的内存访问是非合并（non-coalesced）的：例如，对行方向矩阵的访问即以非合并方式执行；同时，还存在重复的内存访问——比如元素 m[0,0] 在第一个线程中被访问，又在另一处被再次访问；n[0,0] 和 n[1,0] 也被不同线程分别访问。换言之，这些值需反复从全局内存中读取，并分发给多个线程。

## 段落 59

**英文**: So this is going to be potentially very slow. So there's a question of can we avoid having too many global memory reads and writes?. What I would ideally like to do, right? So let me explain kind of the ideal outcome first and then I'll explain the algorithm. The ideal outcome is that I would like to spend one sort of chunk of time loading pieces from global memory to shared memory where things are fast. I want to do a ton of computation and shared memory and then I want to kind of be done with that piece of data, right? That's the ideal outcome. I've minimized my global memory accesses. So now how can I do this in this matrix multiply world? So now what I'm going to do is I'm going to take my matrices, both the n matrix and the n matrix and I'm going to cut them up, right, into tiles. So here I've cut this up into 2 by 2 tiles. I've got a 2 by 2 m tile and a 2 by 2 n tile, right? So I've got basically smaller sub matrices within each of the matrix. And now imagine that my shared memory is big enough to be able to fit these sub matrices, right, within each of these sms.

**中文**: 因此，这可能会非常慢。那么问题来了：我们能否避免过多的全局内存读写操作？这正是我理想中希望实现的目标，对吧？让我先解释一下理想的结果，然后再介绍具体算法。理想的结果是：我只需花费一段集中的时间，将数据块从全局内存加载到访问速度更快的共享内存中；接着在共享内存中进行大量计算；最后，便能彻底完成对该数据块的处理，对吧？这就是理想的结果——我已将全局内存访问次数降至最低。那么，在矩阵乘法场景下，如何实现这一点呢？接下来，我将对两个输入矩阵（均为 n×n 矩阵）进行分块处理，即划分为若干“瓦片”（tiles）。此处我将其划分为 2×2 的瓦片：一个 2×2 的 M 矩阵瓦片和一个 2×2 的 N 矩阵瓦片，对吧？换言之，每个矩阵都被分解为若干更小的子矩阵。现在假设我的共享内存容量足够大，足以容纳这些子矩阵，即每个流式多处理器（SM）的共享内存均可容纳这些子矩阵。

## 段落 60

**英文**: So now this gives a very, very simple algorithm with which we can do computation. So what I'm going to do is I'm going to first load, let's say, this m00 tile on the top left over here. And I'm going to also load my n00 tile into shared memory here, right? So now I have these partial sums that I can compute. I can take the row product of m00m01 with n00m10 and I can increment that into p00. I can do the same with all the different sub matrices that I can fill out over here, right?. Now, then once I'm completely done sort of processing these two tiles, then I can load a new tile over here and then I can repeat that computation with my m tile and my n2. 0 tile loaded into shared memory. And then I can sort of increment my partial sums in p, right? So now I've really sort of consolidated and reduced the amount of global memory access I have to do, right? I load as much memory as I can at once into shared memory. I do all of my sort of sub matrix computations on that tile that I can and then I move on. to the next one, right? And of course, the other nice thing is that because I'm loading an entire tile, you know, I can traverse the sub matrixes and whatever order I want, like column measure or row measure.

**中文**: 因此，这提供了一种极为简单的算法，可用于执行计算。接下来，我将首先加载左上角的 m00 分块（tile），同时将 n00 分块加载到共享内存中，对吧？这样，我便可以计算这些部分和：例如，可将 m00 与 m01 的行向量和 n00 与 m10 的列向量相乘，并将结果累加至 p00；同理，也可对当前区域中所有其他可填充的子矩阵执行相同操作，对吧？随后，待这两个分块的处理全部完成后，我便可加载一个新的分块，再用当前的 m 分块与新加载至共享内存的 n2.0 分块重复上述计算，并继续将部分和累加至 p 中，对吧？如此一来，我实际上已大幅整合并减少了全局内存访问次数，对吧？我尽可能一次性将大量数据加载至共享内存，然后在该分块上完成所有可能的子矩阵运算，再转向下一个分块，对吧？当然，另一大优势在于：由于我是一次性加载整个分块，因此可按任意顺序遍历子矩阵，例如按列优先或按行优先方式。

## 段落 61

**英文**: And so I can coalesce all of the memory accesses whenever I'm loading a tile from global to shared memory, right? So there's kind of winds all around here when we tile our accesses. So we can do a little bit of tiling math. So we've got let's say a matrix A, a matrix B, and a matrix C. So let's say the full matrix C is these are square matrices, our size n. And let's say I have a tile of size t, right? Oh, yes, question. So in that case, I just wrote it for completeness. But m0 0, let's say is just stored in shared memory. Let's just keep it cached. I won't load it again. That's definitely just there for completeness, not that you would actually like discard and reload the matrix again.

**中文**: 因此，当我将数据块从全局内存加载到共享内存时，就可以将所有内存访问合并在一起，对吧？所以，当我们对访问进行分块处理时，周围会形成某种“风”（即内存访问模式）。我们可以进行一些分块计算。假设我们有矩阵A、矩阵B和矩阵C，且这些均为大小为n的方阵。再假设我使用的分块大小为t，对吧？哦，是的，有人提问了。这种情况下，我刚才那样写只是为了完整性。但例如m0_0，我们可直接将其存入共享内存并保持缓存状态，无需再次加载。这纯粹是为了表述完整，并非实际应用中真会丢弃后再重新加载该矩阵。

## 段落 62

**英文**: That would be kind of insane. Cool. Okay. And so we can kind of do a very simple tiling math to think about, you know, what's happening. So let's say I'm going to do a n by n matrix multiply, right? So if I do a non-piled matrix multiply, if I'm just going over rows and columns, then. every input, every time I process it has to come from global memory. So each input is read sort of n times from global memory, right? So each of these is read sort of n times. If I do a tiled matrix multiply, well, you know, the global reads are operating over tile. So I'm reading each input n over t times from global memory, and I'm reading t times within each tile, right? Of course, I'm doing matrix matrix multiplies. So I can't reduce the total number of reads.

**中文**: 这听起来有点疯狂。很好。好的。因此，我们可以用一种非常简单的分块计算方法来思考其中发生的情况。假设我要执行一个 n×n 的矩阵乘法，对吧？那么，如果我执行的是非分块的矩阵乘法，即仅按行和列遍历，则每次处理每个输入时，该输入都必须从全局内存中读取。因此，每个输入需从全局内存中读取约 n 次，对吧？也就是说，每个输入均被读取约 n 次。而如果我采用分块矩阵乘法，那么全局内存读取操作则以分块为单位进行。因此，每个输入仅需从全局内存中读取约 n/t 次，而在每个分块内部则需读取 t 次，对吧？当然，我们执行的是矩阵与矩阵的乘法运算，因此无法减少读取操作的总次数。

## 段落 63

**英文**: I have to read all the matrix elements. But I can shift the reads into basically fast shared memory, right? So I do t times memory reads into shared memory, and n over t times from global memory. And that's great because if we have a big shared memory that can store big tiles, that's a factor of t reduction in the total amount of data that has to come from global memory, right? So tiling can be really, really powerful of an idea when you're operating over matrices,. you can move things into shared memory. Tiling is quite complex. This is the source of many, many sort of confusing things about GPU and matrix multiply performance. One thing that can happen, right? Once we start tiling things, you start asking things about discretization, right? So imagine I have a tile size of 128, that seems like a nice, good, round tile size. But then, you know, when I have a full matrix of 256 size, that's great. With a 2 by 2 tile, things load nicely. Now let's say I have a 256 size tile on the column side.

**中文**: 我必须读取所有的矩阵元素。但我可以将这些读取操作转移到速度较快的共享内存中，对吧？因此，我需要执行 t 次从全局内存到共享内存的读取操作，以及 n/t 次直接从全局内存的读取操作。这非常有利，因为如果我们拥有容量较大的共享内存，能够存储较大的数据块（tile），那么从全局内存中读取的总数据量就能减少为原来的 1/t，对吧？因此，在处理矩阵运算时，“分块”（tiling）是一种极为强大且有效的策略——它允许我们将数据移入共享内存。但分块实现起来相当复杂，这也是导致 GPU 上矩阵乘法性能表现诸多困惑与误解的重要根源之一。例如，一旦我们开始采用分块策略，就不得不考虑离散化（discretization）相关的问题。试想，我设定的分块大小为 128，这看起来是一个不错、规整的分块尺寸；然而，当整个矩阵尺寸为 256 时，效果确实很好——此时可划分为 2×2 的分块，数据加载十分顺畅。但假如我在列方向上采用大小为 256 的分块呢？

## 段落 64

**英文**: Now this is a bad time because I need to have six tiles in order to cover this matrix. And the two tiles on the right are very, very sparse. There's just not much stuff in there, right? And the problem with this is that each tile is going to be assigned to a sn, right? So each of these tiles is going to be a block, and each thread is going to be operating with each tile. So those two tiles on the right, they're not going to be doing very much at all, right? Those sms are going to be basically be sitting idle. And if you were kind of compute cap, you would have wanted to more evenly distribute the load between sms, right? So you have to basically optimize your tile sizes to try to avoid these kinds of scenarios. But in reality, right, there's a lot of complex things that go into setting the tile size, right? Remember, you have to call us your memory accesses. You have to think carefully about that. You have to not exceed your shared memory size, right? So the tiles can't be too big. And you have to divide the matrix dimension, hopefully evenly, or as close to evenly as possible, so you don't end up with this situation of underutilized sm at the very end here. Yes.

**中文**: 现在这种划分方式很糟糕，因为我需要六个分块（tile）才能覆盖整个矩阵。而右侧的两个分块非常、非常稀疏，其中几乎没什么数据，对吧？问题在于，每个分块都会被分配给一个流式多处理器（SM），也就是说，每个分块将作为一个计算块，每个线程都将针对各自分配到的分块进行运算。因此，右侧这两个分块实际上几乎无事可做，对吧？这些SM基本上将处于空闲状态。如果你的计算资源受限（即受计算能力限制），你本希望在各SM之间更均衡地分配负载，对吧？因此，你必须通过优化分块大小来尽量避免此类情况。但现实中，确定合适的分块大小涉及诸多复杂因素，对吧？请记住，你必须考虑内存访问模式，需对此仔细斟酌；你还不能超出共享内存容量限制，因此分块不能过大；此外，你还需尽可能均匀地划分矩阵维度（理想情况下完全均分，或至少尽可能接近均分），以免最终出现此处这种SM利用率严重不足的情况。是的。

## 段落 65

**英文**: So if you have a say smaller, sorry, use something like if I put GPUs to something like a budget where they can fetch the tile to the more hand than it's so much, would that. happen? That's a no. Yeah. So you're asking about whether or not you can overlap memory reads and computation. And yeah, that's naturally done in GPUs. They're always like trying to use the available bandwidth. Like as long as shared memory is available, they can go and put things into it. The issue is that whenever you're effectively utilizing your sms, you're basically maxed. out on your shared memory, right? That's like the bottleneck resource. And so there is no place to pre-fetch in some sense.

**中文**: 因此，如果你的显存容量较小，抱歉，我的意思是：假如我将GPU的显存预算设定得较低，以至于它无法将图块（tile）加载到更靠近计算单元的位置，这种情况会发生吗？不会。是的。所以你实际上是在询问：能否让内存读取与计算过程重叠执行？是的，GPU天然就支持这种操作，它们始终致力于充分利用可用带宽。只要共享内存有空闲空间，GPU就可以将数据载入其中。但问题在于，一旦你实际充分利用了流式多处理器（SM），共享内存通常就已达到饱和状态，对吧？也就是说，共享内存恰恰是瓶颈资源。因此，从某种意义上说，并没有额外的空间可用于预取数据。

## 段落 66

**英文**: Cool. Okay. And the other thing that is very, very, you know, we're getting into the weeds here. And complex is the interaction between piling and sort of burst sections. So imagine I have a matrix layout that's kind of like this where I have my nice burst. sections and each burst section lines up nicely with a tile. So to read this tile, all I have to do is to get four different burst sections and I've gotten this entire tile. Now imagine what happens if I add sort of one element extra and the way the matrix is laid out, you know, my sort of tile start, sort of my burst sections flow over. So now what's happening is when I load my tile, I'm going to load this first part and that's really great. I get the entire first row as a burst section.

**中文**: 很好。好的。另一件非常、非常复杂的事情——我们现在已经深入细节了——是堆叠（piling）与突发段（burst sections）之间的交互关系。假设我有一个类似这样的矩阵布局：其中包含若干整齐排列的突发段，且每个突发段恰好与一个数据块（tile）对齐。因此，要读取该数据块，我只需获取四个不同的突发段，即可完整读取整个数据块。现在再设想一下，如果我在矩阵中额外增加一个元素，而矩阵的布局方式又导致我的数据块起始位置发生偏移，从而使突发段发生越界。此时，当我加载该数据块时，首先加载的是这一部分，效果非常好——我通过一个突发段便完整获取了第一行数据。

## 段落 67

**英文**: Now in the second row, this actually belongs to two different burst sections. And so I have to do two reads in order to get this second row and so on and so forth. So I've essentially doubled the number of memory accesses because I've added a single extra element at the very end there that's kind of bumped up the alignment of my burst section and my align layout. And so basically if piles or your matrix sizes aren't multiples of your burst section, you can easily end up with situations like this where the rows don't line up with the burst section and you've doubled the amount of memory access that you have to do. And the way to get around this is you have to do padding to be able to kind of get nice round matrix sizes so that your burst sections line up with the size of your tiles. So this is getting very into the weeds here. But if you really want to squeeze out all the performance from your matrix multiplies, these are the kinds of things you have to think about, right? And you will get bitten by this if you're not thinking about it. And of course, I guess like things like torch compile and all the kuda optimizations for matrix multiplies, they're doing exactly the kinds of stuff that I just talked about,. right? That's the way you get better performance. And so all of this matrix complexity ends up in situations like this where I'm reading out Andres' tweet here.

**中文**: 现在看第二行，它实际上横跨了两个不同的突发传输（burst）段。因此，我需要执行两次读取操作才能获取这一整行，以此类推。本质上，由于我在末尾额外添加了一个元素，导致突发传输段和内存对齐布局的对齐方式发生了偏移，从而使内存访问次数翻倍。因此，简而言之，如果矩阵尺寸或分块（tile）大小不是突发传输段大小的整数倍，就极易出现此类问题：矩阵各行无法与突发传输段对齐，进而使所需内存访问量翻倍。解决方法是进行填充（padding），以获得规整的矩阵尺寸，确保突发传输段与分块大小精确对齐。这已深入到非常底层的细节层面。但若你真想充分榨取矩阵乘法的全部性能，就必须考虑这类问题，对吧？而如果你忽视这一点，就必然会为此付出代价。当然，像 Torch Compile 以及 CUDA 针对矩阵乘法的各种优化，本质上也正是在做我刚才所描述的这类工作，对吧？这正是提升性能的关键所在。因此，所有这些矩阵运算的复杂性，最终都会体现在类似这样的场景中——比如我现在正在读取安德烈斯（Andres）的这条推文。

## 段落 68

**英文**: But the most dramatic optimization to nano-GPT is to increase the vocab size from 5257 to 50304, which is the nearest multiple 64, which gives you much, much higher occupancy careful with your powers of two. Right?. So that's a 25% speed up from adding how many? It's like 50, 57, 47 dimensions to your vocab. Like that's kind of like, you know, how does that happen? And so that kind of brings us back to the mystery. Like, you know, I was dragging you through all of the GPU details in the hopes that, you know, you'll have a full understanding of all the performance characteristics. But in some sense, the payoff is, you know, I now get to explain to you how this chart comes to be. And at the end, you won't find matrix multiply performance to be so mysterious or scary at the end here, right? So the very first part is very, very simple. Like we understand compute intensity, right? This is exactly the roof line that I pointed out at the very beginning, right? So up until here, which is about 1536, right? There's just not enough matrix multiply work to do, right? Just loading the matrix and doing very basic IO, right, that you have to do, is becoming. a bottleneck below this point, right? So throughput is going to fall through to the ground, past this point. You just don't have enough memory bandwidth to support your compute units.

**中文**: 但对nano-GPT最显著的优化，是将词表大小从5257提升至50304——这是最接近的64的倍数，从而大幅提升硬件利用率；请务必谨慎对待你的2的幂次选择，对吧？那么，仅凭这一改动就实现了约25%的速度提升——这相当于在词表维度上额外增加了约50,574个词汇项。这听起来简直不可思议：这究竟是如何实现的？这也再次将我们带回到那个谜题之中。此前我详尽梳理了GPU的各项细节，正是希望你能全面掌握所有性能特征；而最终的回报便是：我现在可以向你解释这张性能图谱是如何形成的。到此为止，你将不再觉得矩阵乘法的性能表现如此神秘或令人畏惧，对吧？  
第一部分极其简单：我们完全理解计算强度，这正是我在开头所指出的“屋顶线”模型，对吧？在矩阵规模约达1536之前，矩阵乘法的计算量本身尚不充足；此时，仅加载矩阵及执行最基本I/O操作所需的时间，便已构成性能瓶颈。换言之，在该阈值以下，吞吐量将急剧下降——因为你根本无法提供足够的内存带宽来支撑计算单元的运行。

## 段落 69

**英文**: Now on the right side here, in theory, right? If I draw the upper envelope, this is the kind of maximum achievable performance. So it's possible up here to saturate all of my compute units and get really great performance. But if you kind of mess up your matrix sizing, you can end up in these kind of really weird places. And within each one of these, you can kind of end up in a weird trough. And so we're going to kind of think a little bit about, you know, why do you have all these different places you can end up? So the very first thing, this first line here, this is a tiling alignment issue. So if you look at kind of the multiples here, so I've now colored each of these lines based on kind of the divisibility of the matrix size, and this is the size by which it's divisible. So if it's divisible by 32, then you're in good shape. You're in these purple dots up here. If you're divisible by 16, you're actually still up here. There's two colors.

**中文**: 现在看右侧区域，理论上是这样，对吧？如果我画出上包络线，这代表所能达到的最佳性能。因此，在该区域上方，有可能让所有计算单元都达到饱和，从而获得极佳的性能。但如果你的矩阵尺寸设置不当，就可能落入这些非常奇怪的性能区域。而在每个这样的区域内，你还可能陷入某种异常的性能低谷。因此，我们需要稍微思考一下：为什么会出现这么多不同的性能落点？首先，最上面这条线反映的是分块对齐问题。观察此处的倍数关系，我已根据矩阵尺寸的可整除性为每条线着色，颜色对应其可被整除的数值。例如，若矩阵尺寸能被32整除，则处于理想状态，对应图中上方的紫色点；若能被16整除，实际上也仍处于上方区域，只是颜色不同。

## 段落 70

**英文**: And then if you're green, your k equals 8, you're up here. If you're orange, your k equals 2. And if your k equals 1, you're all the way down here. If you're not divisible by any number, don't pick prime dimensions. You're not going to get very good throughput on your matrix multiplies. And a big part of this is going to be, you know, once you get to kind of k equals 2 and k equals 1, you are basically forcing the situation where you can no longer retiles in this sort of nicely aligned way with your burst reads, and that's going to lead to some serious issues. So that's kind of a problem. But then, OK, so that's one part of the mystery, but I think another part of the mystery remains. So within this orange line, you know, I think if you zoom in to here, you see this giant drop, right, from this point, all the way down to this point, where you're just kind. of wondering what happened here.

**中文**: 接着，如果你是绿色的，你的 k 值为 8，你位于此处上方；如果你是橙色的，你的 k 值为 2；而若 k 值为 1，则你处于最底部。如果矩阵维度不能被任何数整除，请勿选择质数维度，否则矩阵乘法的吞吐量将非常差。造成这一现象的重要原因之一在于：一旦 k 值降至 2 或 1，你实际上已无法再以这种整齐对齐的方式进行分块（tiling），从而无法匹配突发读取（burst reads）的要求，这将引发严重问题。因此，这本身便构成一个问题。但接下来——好吧，这只是谜团的一部分，而我认为谜团的另一部分仍未解开。例如，在这条橙色曲线上，若你在此处放大观察，便会发现一个巨大的陡降：从这一点一路骤降至另一点，令人不禁疑惑其间究竟发生了什么。

## 段落 71

**英文**: How could I lose so much performance increasing my dimension by 2? And so let's just look at these numbers. And it's just, I think this is a fun puzzle. So I'm just going to walk you through the puzzle. This is going to happen when you transition from 1792 to 1790, I guess, three or four size. Let's say four here, just so that it's a factor of two still. Well, why does that happen? OK? Well, let's say that we're using a tile size of 256 by 128. That's a pretty natural size as a fun fact. You know, the matrix multiply units in these GPUs, they're naturally operating on matrices of roughly size 128. So 256 by 128 is a very nice tile side. So that means how many tiles are there?.

**中文**: 维度仅增加2，我的性能为何会大幅下降？我们来具体看一下这些数值。我认为这是一个很有趣的谜题，接下来我将带您逐步分析这个谜题。这种现象大概会在矩阵尺寸从1792变为1790时出现，姑且假设此处为4（以保持其仍为2的整数倍）。那么，为什么会发生这种情况呢？好的，假设我们采用的分块大小为256×128——这其实是一个相当自然的尺寸（顺便提一句：这些GPU中的矩阵乘法单元，天然适合处理尺寸约为128的矩阵），因此256×128是一个非常理想的分块尺寸。那么，总共会有多少个分块呢？

## 段落 72

**英文**: Well, there's seven times 14 tiles, right, because we're dividing the dimension of the matrix by the size of our tiles. That's a total of 98 different tiles. And if we increase this by one, well, you know, we're going to have to round up each one of our coordinates. And so we're going to have a lot more tiles, 120 of them, right? So we've increased the number of tiles by quite a bit. Well, you know, what's going to happen is not only did we significantly increase the tiles. and some of them have lower utilization, which is bad, but actually even worse, an A100 has 108 SMs, right? And if I, if you go all the way back to the kind of the GPU execution model, right, SMs can execute in parallel and they're kind of the execution units. And so when you have 98 SMs, they all go and run, right? You can dispatch them all. All the SMs are running. You know, you've got great utilization. Once you go to 120 tiles, now you've got more tiles than SMs.

**中文**: 嗯，共有7×14=98块瓦片，对吧？因为我们是用矩阵的维度除以瓦片的尺寸。如果将该尺寸增加1，那么每个坐标都需向上取整，结果瓦片总数将增至120块，对吧？因此，瓦片数量显著增加了。不仅如此，瓦片数量的大幅增加还会导致部分瓦片利用率降低——这本身就很糟糕；更严重的是，A100 GPU拥有108个流式多处理器（SM），对吧？而根据GPU执行模型可知，SM可并行执行，是GPU的核心执行单元。当有98个瓦片时，所有SM均可同时运行，即全部SM都能被调度执行，从而实现极高的硬件利用率。但一旦瓦片数增至120，瓦片数量便超过了SM的数量。

## 段落 73

**英文**: So 108 of those will execute. And then you will go back and you'll say, all right, I've got some more SMs. A very, very low utilization, you're going to execute the remaining 12 and wait for those to complete, right? And that's going to be really bad. So if you look at your utilization, you've got good utilization for a while. You'll drop off a cliff and then you'll sort of finish up your job. So this is something called wave quantization. And so ideally your tile sizes are either much bigger than the number of SMs or they're not like this where you're just barely over the SM and you've caused this quantization sort of error additionally. Cool. All right. I know this is low level details, but in many ways, I've been saying through many classes that language models and deep learning is attention to detail.

**中文**: 因此，其中108个将被执行。随后你将返回并意识到：“好吧，我还有更多流式多处理器（SM）可用。”但此时利用率极低，你只能执行剩余的12个，并等待它们完成，对吧？而这将导致性能严重下降。因此，若观察你的利用率曲线，会发现起初利用率尚可，随后却骤然跌落至谷底，最后才勉强完成整个任务。这种现象被称为“波次量化”（wave quantization）。理想情况下，你的分块（tile）尺寸应远大于SM数量；而绝非仅略高于SM数量——否则便会额外引发此类量化误差。很好。我知道这些属于底层细节，但正如我在多门课程中反复强调的那样：语言模型与深度学习的成功，关键在于对细节的关注。

## 段落 74

**英文**: And these kinds of attention to detail is the things that allow people to scale up LMs to really, really large sizes and get great performance. So it's worth knowing, even if you're not a person that's going to do systems engineering. So what were the tricks, right? Key ideas here. First one is you've got to reduce them of memory accesses, right? So there's lots of ways to do it. You can do call lessing, right?. So that you're not, you can sort of reuse reads that you're getting for free. You can do fusion so that you can fuse multiple operations together and avoid unnecessary reads and writes. You can move memory to shared memory. So even if you're going to do reads, they're going to be from much faster memory. And that's going to be sort of piling tricks that you can do.

**中文**: 而正是这类对细节的关注，使得人们能够将大语言模型（LM）扩展至真正、真正庞大的规模，并获得卓越的性能。因此，即便你并非从事系统工程工作，了解这些内容也十分有价值。那么，具体有哪些技巧呢？关键思路如下：第一，必须减少内存访问次数。实现这一目标的方法有很多，例如可采用缓存优化（caching），从而免费复用已读取的数据；也可采用算子融合（fusion），将多个操作融合在一起，避免不必要的读写操作；还可将数据移至共享内存中，这样即使需要读取，也能从速度更快的内存中获取。以上便是可采用的一系列优化技巧。

## 段落 75

**英文**: And then finally, you can kind of trade memory for other resources that you do have, right? So you can trade it for compute, which is going to be recombitation, or you can trade. it for just numerical precision or stability, which is going to be quantization, right? So there's lots of bags of tricks that you have in order to get sort of performance out, right? So there's lots of things you can do. You just have to be really mindful of kind of the role that memory plays in the performance of a GPU, right? That's kind of the key thing to get the most out. Cool. Any questions on that before I sort of move to the final part with flash attention? Okay. Good. All right. So now I'm going to put it all together, right? Like I'm going to try to make it so that all the tricks that I taught you aren't these like random disconnected facts about GPUs. They're kind of part of the standard performance optimization toolkit, and flash attention,. and flash attention, too, will hopefully teach you how that all comes together to build one of the foundations, I guess, of modern high performance transformers.

**中文**: 最后，你还可以在内存与其他现有资源之间进行权衡，对吧？例如，你可以用内存换取计算资源，即重新计算；也可以用内存换取数值精度或稳定性，也就是量化，对吧？因此，为了提升性能，你手头拥有大量实用技巧。你可以做的事情有很多，但关键是要充分意识到内存对GPU性能所起的作用，这才是充分发挥GPU性能的核心所在。很好，关于这部分内容，在我进入闪存注意力（Flash Attention）的最终讲解之前，大家还有什么问题吗？好的，很好。那么现在，我将把所有内容整合起来，对吧？也就是说，我要让之前所讲的所有技巧不再是一些彼此孤立、零散的GPU知识点，而是成为标准性能优化工具包中有机统一的组成部分；而闪存注意力（Flash Attention）及其升级版Flash Attention-2，也将帮助大家理解这些技巧如何协同作用，共同构筑现代高性能Transformer架构的重要基石之一。

## 段落 76

**英文**: So flash attention, you know, we know that it dramatically accelerates attention. And most of you probably know that that's done through some CUDA kernel magic. But maybe you don't know all the details, right? So, you know, what the paper says is, okay, so there's one part that's happening, which is, you know, you do attention on an unoptimized, you know, pie towards transformer implementation. If you fuse the kernel and you do some things, you can get significant, significant speed. ups. And from the paper, you know, they say we apply two established techniques, tiling and recomputation to overcome the technical challenge of computing exact attention and subcratic quadratic HBM accesses, right? So it's not subcratic, you know, computation, because you can't do that. You have to compute, you know, attention in general. But they're going to get subcratic accesses to the high bandwidth or global memory, right? And so that's really the key. If your memory is the bottleneck, you know, you want to make that not quadratic, so that at least you can pay for quadratic cost with your compute rather than with your memory. So just for a really quick recap, you know, at this point, you've implemented attention many, many times in many classes, right? So it's going to be three different matrix multiplies.

**中文**: 因此，Flash Attention（闪存注意力机制）众所周知可显著加速注意力计算。在座的各位可能大多知道，这是通过某些CUDA内核技巧实现的。但或许并非所有人都了解其中全部细节，对吧？论文中指出：一方面，我们采用未经优化的、类似“手写”风格的Transformer注意力实现；而另一方面，若将内核融合并采取若干优化措施，即可获得极为显著的速度提升。论文中还提到，我们应用了两种成熟技术——分块（tiling）与重计算（recomputation），以应对精确注意力计算及次二次方级高带宽内存（HBM）访问所带来的技术挑战。注意，这里并非指计算本身是次二次方级的——因为这不可能；注意力计算本质上必须是二次方级的。真正实现次二次方级的是对高带宽内存（或全局内存）的访问。这才是关键所在：当内存成为瓶颈时，我们希望将内存访问复杂度从二次方级降低，从而至少能将原本由内存承担的二次方级开销转由计算资源承担。简单回顾一下：此时此刻，大家已在多门课程中反复实现过多次注意力机制，对吧？其核心始终包含三次不同的矩阵乘法运算。

## 段落 77

**英文**: You've got a KQ and V with a softmax in between. So the matrix multiplies are pretty simple. That can be, you know, done with tiling. I've showed you examples like that. What's different about attention? Well, there's a softmax thing that's going to be the real tricky bit. And then once we can deal with the softmax, all of the sort of matrix multiply things I was talking about will just come into play. So the matrix multiply, as I said before, is exactly what I taught you. So if you look at the figure one from the flash attention paper, this is really just a simple tiled matrix multiply, right?. You see, you know, the K matrix, the Q matrix, you see it cut up into small blocks. You know, small blocks of it are being copied to SRAM.

**中文**: 你拥有一个K矩阵和Q矩阵，二者之间有一个Softmax操作。因此，矩阵乘法相当简单，可以通过分块（tiling）来实现。我之前已经向你们展示过类似的示例。那么注意力机制（attention）的不同之处在哪里呢？关键在于其中的Softmax操作，这才是真正棘手的部分。一旦我们解决了Softmax的问题，那么我之前所讨论的所有矩阵乘法相关技术就都能直接应用了。正如我之前所说，这里的矩阵乘法正是我教过你们的内容。因此，如果你查看FlashAttention论文中的图1，这实际上就是一个简单的分块矩阵乘法，对吧？你看，K矩阵和Q矩阵被清晰地划分成若干小块，这些小块被逐次复制到片上SRAM中。

## 段落 78

**英文**: They're being multiplied. And then they're being, you know, accumulative the scent to the HBM where you do softmaxes and then you multiply with a V, right? So this is all just really simple in terms of the KQV matrix multiply. And now we have to think about the softmax, right? Like what's going on with the softmax?. So the key thing here is the softmax, sorry, I'm going to roll back one step. So the issue with the softmax, what's the problem with the softmax? It's a global operation, right? The softmax in an attention operates row by row. You have to sum the entire row, right, to compute some normalizing term with the softmax. And that's very problematic. If I have tiles, right? Ideally, I want to do everything within the tiles, right?. I don't ever want to have to write back to the big matrix. And so I need a softmax that can be computed online within each tile, right? I want to do as much computation within each tile as possible.

**中文**: 它们正在被相乘。接着，如你所知，它们会累积到HBM中的注意力分数上，然后在该处执行Softmax操作，再与矩阵V相乘，对吧？因此，从KQV矩阵乘法的角度来看，整个过程其实非常简单。现在我们需要思考Softmax操作，对吧？比如Softmax究竟在做什么？此处的关键在于Softmax——抱歉，我先回退一步。Softmax的问题在于：它是一种全局运算，对吧？注意力机制中的Softmax是按行进行的，你需要对整行求和，以计算Softmax所需的归一化因子。而这恰恰非常棘手。假设我采用分块（tile）处理方式，理想情况下，我希望所有计算都在每个分块内部完成，对吧？我绝不想将中间结果写回到大型矩阵中。因此，我需要一种能够在每个分块内在线计算的Softmax，对吧？我希望尽可能多地在每个分块内部完成计算。

## 段落 79

**英文**: So the key thing here is to use what's called the online softmax. And so what is that? If you have a stream of values, right? Normally, the batch version of the softmax, you take all of your x1 through x events, and you would exponentiate them, sum them, and you would divide them, right?. That's what you would do in your normal softmax. And then you would maybe compute the maximum value, and you subtract that in order to be able to make this numerically stable, right? So this is the standard numerically stable softmax on the left side. So the online softmax, I've taken this from Mikhailov in Gimelstein in 2018, well, you can sort of realize that you can pull out, be sort of like a telescope being some kind of an argument, basically the current running, sort of normalizer term, and the current sort of top term of e to the xi minus max of xk, right?. So what you're going to do is you're going to maintain your current max that you've seen over x1 through x of j, which is my current iteration. And then I'm also going to maintain sort of this correction term. If my max updated, this is going to basically correct my max. And then I'm going to add my sort of new term over here, right? So this d of j is going to track online the top term of this equation to over here. And then at the end, I can also then compute the normalizer and then sort of get the normalize y of i that I want, right?.

**中文**: 因此，此处的关键在于使用所谓的“在线Softmax”。那么，什么是在线Softmax呢？假设你拥有一组连续输入的数值流，对吧？通常，批量版Softmax会将所有输入值x₁至xₙ全部取出，对其分别取指数、求和，再逐项相除，对吧？这便是常规Softmax的标准做法。此外，你可能还会先计算这些值中的最大值，并从每个输入中减去该最大值，以确保数值计算的稳定性，对吧？左侧展示的即为标准的、具备数值稳定性的Softmax。而在线Softmax则借鉴自Mikhailov与Gimelstein于2018年提出的方法：你可以将其理解为一种类似“望远镜展开”的技巧，本质上是分离出当前运行中的归一化因子（normalizer term）以及当前的分子项（即e^(xᵢ − max(xₖ))）。具体而言，你需要持续维护一个当前已遍历值x₁至xⱼ（其中j代表当前迭代步）中的最大值；同时，还需维护一个校正项——当最大值更新时，该校正项将相应调整此前累积的归一化因子；随后，你再将当前新输入项加入计算，对吧？此处的dⱼ将实时追踪上述公式右侧分子项的在线累加值；最终，你便可据此计算出归一化因子，并进一步得到所需的归一化输出yᵢ，对吧？

## 段落 80

**英文**: This d of v is itself sort of the normalization term that I need. So the key thing here is that this can be done online. I don't need the x1 through x of n up front. All I need is sort of the stream of x1 through xn. And that's really key because I can now compute the softmax tile by tile, right? Within each tile, I can run this algorithm and that will let me compute kind of the partial softmax for that tile. And then I can sort of write back if I need to all the components that I sort of, I'm. keeping track of. And that's all that I kind of need in order to do this computation, right? So I never have to materialize the full n squared matrix in order to compute the softmax. And so that's basically it. But once you have that, you know, you've put it all together and you can get the forward pass of flash attention.

**中文**: 该 $d$ 与 $v$ 的乘积本身即为我所需的归一化项。因此，此处的关键在于：该计算可在线完成——我不需要预先获取全部输入 $x_1$ 到 $x_n$，而只需按顺序流式接收 $x_1$ 至 $x_n$ 即可。这一点至关重要，因为它使我能够逐块（tile-by-tile）地计算 softmax：在每一块内运行该算法，即可得到该块对应的局部 softmax 结果；随后，若有必要，我可将所维护的各分量写回内存。这便是完成该计算所需的全部要素。换言之，我完全无需显式构造整个 $n \times n$ 规模的矩阵，即可完成 softmax 计算。以上便是核心思路。一旦实现上述步骤，便可将其整合起来，从而完成 FlashAttention 的前向传播过程。

## 段落 81

**英文**: And if you go and look at the flash attention, Q paper, which is going to be a thing that we're going to ask you to implement. So you're going to be following through kind of these steps here. You're going to see exactly this idea. So first, you're going to have your KQ matrix multiply and this is going to be tiled. So these are little tiled chunks and they're going to be multiplied and how am I going to compute the softmax? Well, I'm going to maintain sort of a running value of these sort of expanentiated sums. And then I'm going to keep incrementally updating it and correcting for the maximum terms. And by doing that, I can compute all the necessary quantities kind of tile by tile, sort of going from one tile to another. And then just multiply once again with tiles with v in the end. And that will give me sort of my full softmax output, right? Yes. So we won't be able to compute that out, but until we compute the good, like, 2k multiplication across harm, so it's going to be able to have to double back on each other.

**中文**: 如果你去查阅FlashAttention的Q论文（这正是我们接下来要求你实现的内容），你将逐步跟进这些步骤，从而清晰地理解这一思路。首先，你需要进行K和Q矩阵的乘法运算，该运算将以分块（tile）方式进行——即划分为若干小块，然后逐块相乘。那么，如何计算Softmax呢？我将维护一个“运行中的”指数化累加和，并持续增量更新它，同时不断修正最大值项。通过这种方式，我可以按块依次计算出所有必需的量，即从一个数据块逐步推进到下一个数据块；最后，再将结果与V矩阵按块相乘一次，即可得到完整的Softmax输出，对吗？是的。不过我们无法一次性完成全部计算，而必须在完成约2K次乘法运算（跨HARM）后，再回溯并反复迭代处理彼此之间的依赖关系。

## 段落 82

**英文**: So the question was, you can't compute this until you are done with all the tiles and. see if they double back on all the tiles. So you will have to, before you can output your softmax, you will have to go through all the tiles. This is correct. But let's say I do all the tiles once, right? I do all n squared tiles. At that point, I have all the components that I need in order to directly output the softmax at that point. I don't have to do recomputation because I have the normalizer terms already, right? By going through each of these kind of tiles, at the end of going through all these tiles, I've built up, you know, L3 or LL of n, which is the sum of all of the expanentiated terms. I already have that in my shared memory for this last tile, and then that allows me to exponentially and divide and then return all the components. Okay. So the backward pass, I'm not going to cover, you can do recomputation tile by tile, which will allow you to avoid storing the softmax, right?.

**中文**: 因此问题在于：在处理完所有瓦片之前，你无法计算该值，必须检查所有瓦片是否存在回溯。因此，在输出softmax结果之前，你必须遍历全部瓦片。这是正确的。但假设我仅遍历所有瓦片一次，即遍历全部n²个瓦片；此时，我已经获得了直接输出softmax所需的所有分量。由于归一化项（normalizer terms）已预先计算完成，因此无需重复计算，对吗？通过逐一处理每个此类瓦片，在遍历完全部瓦片后，我已累积得到L3或LL(n)，即所有指数项之和。该累加值已存于当前最后一个瓦片的共享内存中，从而使我能够对各项进行指数运算并除以该累加值，最终返回全部分量。好的。至于反向传播过程，我暂不展开讲解；你可以按瓦片逐个进行重计算，这样便可避免存储softmax结果，对吗？

## 段落 83

**英文**: Remember, you know, I always want to avoid storing anything that's of size n squared. And so here, I've been sort of clever with the tiles so that I don't have to store any of the n squared components when I'm computing, for example, the softmax. But in the backwards pass, if I store the activations, that's already something that's n squared size, right? So I don't want to store my n squared activations. I'm going to have to re-comput it on the fly tile by tile when I do the backwards pass, right?. So that's a really key other trick that they do in order to make the backwards pass possible. But otherwise, it's fairly standard. It's really the same thing as computing the gradients, just tile by tile in doing that computation. So, okay. That brings us to the end here. Hopefully you've kind of seen how all of the pieces I talked about about tiling and coalescing and re-computation come together to give you flash attention and all these really cool.

**中文**: 注意，如你所知，我始终希望避免存储任何规模为 n² 的数据。因此，在此处，我通过巧妙地使用分块（tiles）来避免在计算（例如 softmax）时存储任何 n² 规模的组件。但在反向传播过程中，如果存储激活值（activations），其本身已是 n² 规模的数据，对吧？因此，我不愿存储这些 n² 规模的激活值；而是在执行反向传播时，按块实时重新计算它们，对吧？这正是实现反向传播的关键技巧之一。除此之外，其余部分则相当常规：本质上就是逐块计算梯度。好了，至此我们已介绍完毕。希望你已大致了解前述关于分块、内存合并（coalescing）和重计算等各项技术如何协同作用，从而实现了 FlashAttention 以及所有这些令人惊艳的成果。

## 段落 84

**英文**: things that make your transformers go much faster. So to recap for the whole lecture, right? hardware is kind of the thing that has really powered all of the language models that we have today. And so if you really want to leverage your hardware, you have to understand the low-level details. I think all of the systems advances really engage with a lot of the concepts that I taught today. And the current GPU sort of scaling, you know, that plot is really the one you should remember. Really, really incentivizes and encourages you to think about memory movement, right? Like the memory movement is the bottleneck in all of this. And so you don't want to just think about, oh, how do I reduce the number of flops? That's important, too. Really you really have to think about, okay, how do I make my memory movements more efficient? And then finally, if you, you know, have to do a certain amount of computation, well, to optimize things, the way to do it is to optimize your data movement, right?. To be able to avoid as much movement from the high bandwidth memory or the global memory as possible. You want to reduce that and have everything in the very, very fast shared memory.

**中文**: 让您的Transformer模型运行得更快的方法。因此，让我们回顾一下本讲的全部内容，对吧？硬件正是真正推动当今所有语言模型发展的关键因素。因此，若想充分利用您的硬件，就必须深入理解其底层细节。我认为，所有系统层面的进步都切实涉及了我今天所讲授的诸多概念。当前GPU的扩展趋势——即您所熟知的那张图表——正是您应当牢记于心的。它极大地激励并促使您关注内存传输问题，因为内存传输正是整个过程中的瓶颈所在。因此，您不能仅仅思考“如何减少浮点运算次数”，这固然重要；但更重要的是，您必须认真思考：“如何提升内存传输的效率？”最后，倘若您必须执行特定量的计算，那么优化的关键就在于优化数据传输——尽可能避免从高带宽内存（或全局内存）中进行数据搬移，而应尽量将数据保留在速度极快的共享内存中。

## 段落 85

**英文**: And that leads to good performance on things like flash attention. Thanks everyone.

**中文**: 而这有助于在闪存注意力（Flash Attention）等任务上实现良好性能。谢谢大家。

---

*共 85 个段落，842 句话*
