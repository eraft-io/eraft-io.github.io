# Lecture 8： Parallelism 2

生成时间: 2026-03-08 21:46:11

---

## 段落 1

**英文**: This is week two of the systems lecture where we try to leverage the most out of the hardware we have to make models train faster. And last week we talked about parallelism within a single GPU and this week we're talking about parallelism across multiple GPUs. So this is a picture you should have in your head. So we have a bunch of nodes, these are basically computers, that each have a number of GPUs, usually eight, and within each GPU there's a bunch of streaming multiprocessors or SMs which actually do the work. And you see that in green here are essentially the memory and the communication. So within each SM you have a very small L1 cache. On a GPU you have high bandwidth memory, HPM, which is bigger, and then you have these links that connect the different GPUs. So the way to think about it is that compute has to happen within the SM on these ALUs. And a compute needs inputs and needs to write outputs. And generally the inputs and outputs can be relatively far.

**中文**: 这是系统课程的第二周，我们旨在充分利用现有硬件，以加快模型训练速度。上周我们讨论了单个GPU内部的并行化，而本周我们将探讨跨多个GPU的并行化。因此，你脑海中应有这样一幅图景：我们拥有一组节点（本质上是计算机），每个节点配备若干GPU（通常为8个）；而每个GPU内部又包含多个流式多处理器（SM），实际计算工作即由这些SM完成。图中绿色部分代表内存与通信结构：每个SM内部配备容量极小的L1缓存；GPU上则拥有带宽更高的大容量内存（HBM）；此外，还有连接各GPU之间的互连链路。简言之，计算必须在SM内的算术逻辑单元（ALU）上执行，而计算过程既需要输入数据，也需要将输出结果写入存储；通常情况下，这些输入与输出数据可能相距较远。

## 段落 2

**英文**: If you're lucky they're on the L1 cache. If you're say less unlucky they're in HPM. And now this week we're talking about multi-GPU and multi-node training where the data that you might need might be across on another GPU. So the name of the game is how do you structure all your computation to avoid data transfer bottlenecks because we want to remember keep the arithmetic intensity high. We want to saturate our GPUs, make them come along. And generally data transfer is going to be a lot slower so that's going to be the bottleneck. So last week we saw a bunch of different techniques to try to do that within a GPU including fusion. and tiling. So the idea basically is that instead of reading and writing from HPM you can load into L1 cache or I guess shared memory which is using the same type of, has the same speed and just work there on your local scratch pad and then write out to HPM only judiciously. And this week we started looking at communication across GPUs and nodes where we have to replicate and shard our models and parameters and optimize our states.

**中文**: 如果你运气好，数据就在L1缓存中；运气稍差些，数据则位于高带宽内存（HPM）中。而本周我们讨论的是多GPU与多节点训练，此时你所需的数据可能位于另一块GPU上。因此，关键问题在于：如何组织全部计算过程，以避免数据传输瓶颈？因为我们始终要牢记——保持较高的计算强度，充分饱和GPU资源，使其高效运转。而通常情况下，数据传输速度要慢得多，因而往往成为整个系统的瓶颈。上周，我们探讨了多种在单块GPU内部规避该瓶颈的技术，包括算子融合（fusion）和分块（tiling）。其基本思想是：不直接从高带宽内存（HPM）反复读写，而是先将数据加载到L1缓存（或共享内存，二者速度相当），在本地暂存区（scratch pad）中完成全部运算，仅在必要时才谨慎地将结果写回高带宽内存。而本周，我们开始关注跨GPU及跨节点的通信问题，此时需要对模型、参数及优化器状态进行复制（replication）与分片（sharding），并加以优化。

## 段落 3

**英文**: And there it's the way we do that will determine the cost. So here's a kind of a, I'm taking a little bit of liberty to put everything in kind of. hierarchy you can think from small fast to big slow. So the smallest and fastest is on a single node, single GPU you have L1 cache. That's extremely fast but very small. And then you have HPM on a single GPU and then between GPUs on the same node we have MVLink and then finally we have MVSwitch. And of course this is all in the Nvidia ecosystem. So the idea is that many of the core concepts of minimizing data transfer are really the same but now the mechanics are a bit different because L1 behaves differently than these. kind of MVSwitches. So this lecture is going to be mostly about concretizing the concepts from the lecture in code.

**中文**: 而实现方式将决定成本。因此，这里我稍作发挥，将所有内容按某种层级结构进行组织，您可以将其理解为从“小而快”到“大而慢”的层次。其中最小、最快的是单节点、单GPU上的L1缓存——速度极快，但容量极小；接着是单GPU上的高带宽内存（HBM）；然后是同一节点内GPU之间的NVLink；最后是NVSwitch。当然，这一切均属于NVIDIA生态系统。其核心思想在于：最小化数据传输的诸多基本理念其实是一致的，但具体实现机制略有不同，因为L1缓存的行为与这些NVSwitch存在差异。因此，本讲主要内容是将上一讲中的概念通过代码具体化。

## 段落 4

**英文**: There's going to be a few new things but Tatsu did an excellent job of giving you an overview of all the different types of parallelism. I'm going to try to anchor it in the code so we can more deeply understand what's going on. And then we're going to have, I'm going to refer to this standard out file here which. is the output of running this lecture. There were some minor issues I'll spare you of where if you have multi-processing then this framework doesn't quite work. Okay, so this lecture has two parts. In part one we're going to look at the building blocks, collective operations which we discussed last time, how this is implemented in Nickel and PyTorch and then we're going to do some benchmarking. And then in part two we're going to look at actually distributed training, data, tensor. and pipeline parallelism. Okay, so let's start with collective operations.

**中文**: 会有一些新内容，但塔图已经非常出色地为大家概述了各种不同类型的并行方式。我将尝试通过代码来具体说明，以便我们更深入地理解其中的原理。接着，我们将参考此处的标准输出文件——即本次讲座运行后生成的输出结果。其中存在一些小问题（比如使用多进程时该框架无法完全正常工作），我就不在此赘述了。好了，本次讲座分为两个部分：第一部分，我们将探讨构建模块——即上节课讨论过的集合通信操作，了解其在Nickel和PyTorch中的具体实现，并进行一些基准测试；第二部分，我们将实际探讨分布式训练，包括数据并行、张量并行和流水线并行。好，我们先从集合通信操作开始。

## 段落 5

**英文**: So collective operations are these primitives that are used generally for distributed programming and collective means that you have many nodes. These are actually quite old from at least the 80s in the parallel programming literature and generally they provide better abstraction than trying to manage the point-to-point communication yourself. So these are really tried and true primitives that have stood the test of time. So a bit of terminology. So world size refers essentially to the number of devices, for example four, and the rank, sort of confusingly if you're used to linear algebra, is actually just refers to device. So we have rank zero, rank one, rank two and rank three if you have four devices. Okay, so the collective operations are as follows. So starting from broadcast, the idea is you have t0 on one of the ranks and you just want to put it on all the other ranks or all ranks. Okay, so that's very straightforward. Scatter is similar but you have four values and you want to put each of the values on different ranks.

**中文**: 因此，集合操作（collective operations）是一类常用于分布式编程的基本原语，其中“集合”意味着涉及多个节点。这些原语在并行编程文献中已有相当长的历史，至少可追溯至20世纪80年代；通常而言，它们所提供的抽象层次高于手动管理点对点通信。因此，这些原语是经过长期实践检验、行之有效的基础构件。下面简要介绍相关术语：“世界大小”（world size）指设备总数，例如四台；而“秩”（rank）这一术语虽易与线性代数中的概念混淆，但此处仅表示某台具体设备——例如拥有四台设备时，其秩分别为零、一、二和三。接下来介绍各类集合操作：首先是广播（broadcast），其含义为：某一个秩上存在张量t0，目标是将其复制并分发至所有其他秩（或全部秩）；该操作非常直观。散播（scatter）与此类似，但初始时有四个值，目标是将每个值分别发送至不同的秩。

## 段落 6

**英文**: So each of the ranks get different values, not the same value. Gather is sort of the inverse of scatter where you have each rank having a different value and then you bring them all together onto one rank. Reduce is the same as gather except for instead of concatenating you add them. All gather is the same as gather except for you just do it for all the destinations. So gather was just rank zero or rank one or rank two or any individual rank. All gather is you do it for all of them. And then finally reduce scatter, I couldn't find a good picture of this so I'm reusing the one from last time, is like reduce where you take a bunch of different values and you add them or perform other commutative operation on them and put it on one rank. But like scatter you're going to be putting different pieces of the vector or tensor on different ranks. Okay, and remember that all reduce is equivalent to reduce plus all gather. So the way to remember this terminology is as follows because it can get kind of confusing.

**中文**: 因此，每个进程（rank）获得不同的值，而非相同的值。“聚集”（Gather）类似于“分散”（Scatter）的逆操作：各进程持有不同的值，然后将所有这些值集中到某一个进程中。“规约”（Reduce）与“聚集”类似，区别在于不是拼接这些值，而是对它们求和。“全聚集”（All-gather）则与“聚集”类似，区别在于目标进程不再是单个进程（如进程0、进程1或进程2等），而是所有进程均作为目标进程。“规约-分散”（Reduce-scatter）我未能找到合适的示意图，因此沿用上一次的图示：它类似于“规约”，即对多个不同值执行求和或其他可交换运算，并将结果存放到单个进程中；但又类似于“分散”，即将向量或张量的不同部分分发到不同进程中。最后需要记住，“全规约”（All-reduce）等价于先执行“规约”再执行“全聚集”。为便于记忆这些术语，可参考如下方法，因为这些术语确实容易混淆。

## 段落 7

**英文**: like which ones all gather, which ones reduce scatter, is that reduce just means you're performing some associative and commutative operation like sum or min or max or average. Broadcast scatter is the inverse of gather and all just means all a destination is all devices. Okay, so hopefully this is a review from last time. So actually any questions before I move on? Since we're going to build on these primitives so it's useful if everyone understands. Okay, so now let's see how this is actually implemented and starting with the hardware. Okay, so here's a classically what hardware for GPUs looks like. So this is kind of in the home, you have a computer, I guess, and you have your CPUs and generally you have your GPUs on one node that communicate via PCIeBus and if you have to go connect communicate between different nodes then this is all connected to Ethernet. So this is kind of typically how machines were built if you buy a GPU for gaming or something this is kind of probably what your setup looks like. As we'll see this is kind of suboptimal because there's a lot of overhead when the data needs to get shipped from GPU to GPU it has to go through the kernel, get copied into buffers. and then go through this kind of transport over Ethernet and that introduces a lot of overhead.

**中文**: 例如，哪些操作是聚合（gather），哪些操作是分散（scatter）？这里的“reduce”仅指执行某种满足结合律和交换律的运算，比如求和（sum）、取最小值（min）、取最大值（max）或求平均值（average）。广播式分散（broadcast scatter）是聚合（gather）的逆操作，“all”则表示目标为所有设备。好的，以上内容希望是对上节课的复习。那么，在我继续讲解之前，大家有什么问题吗？因为我们后续将基于这些基础原语展开，所以确保每位同学都理解非常重要。好的，接下来我们来看这些操作在实际中是如何实现的，首先从硬件层面开始。好的，这是传统GPU硬件的典型架构示意图：大致而言，你拥有一台计算机，其中包含CPU；通常在同一节点上还配有GPU，它们之间通过PCIe总线进行通信；若需在不同节点间通信，则全部通过以太网连接。这种架构是典型的机器构建方式——例如，当你为游戏等用途购买GPU时，你的系统配置很可能就是如此。但正如我们将看到的，这种架构其实并不理想，因为当数据需要在GPU之间传输时，必须经过内核、被复制到缓冲区，再经由以太网这类传输通道转发，从而引入大量开销。

## 段落 8

**英文**: So what has happened in modern times with scientific computing and deep learning is that if you know that you're going to just string a bunch of GPUs together and do something together then we're just going to hook the GPUs up directly basically. So in the NVIDIA ecosystem we have NVLink that directly connects the GPUs therefore bypassing the CPU you don't need to go through kind of the kernel of the host machine and across even across nodes we can connect the GPUs directly via NVSwitch so therefore we're. bypassing Ethernet and because Ethernet was developed a long time ago clearly not for these type of applications so NVSwitch just and NVLink kind of skip all that and just optimize directly for the type of workloads that we're interested in. So if you look at H100s each node has, sorry each GPU has 18 NVLinks in generation 4 coming out so that gives you a total bandwidth of 900 gigabytes. If you compare to these it's certainly a lot faster than PCIe and it's certainly way faster than Ethernet and in comparison if you think about the cost of just going from the SM to reading from high bandwidth memory that's still quite a bit faster by a factor of four. or so and of course these numbers are constantly changing with the new Blackwells this number is like two or three times more I believe. Okay. Yeah. So the question is for the PCIe where how does the data get transferred? I think it has to still go through the CPU. Was there another question? The PCIe it's developed for things like other things are connected to it as well like your.

**中文**: 因此，现代科学计算与深度学习领域发生的情况是：如果你明确知道将把多块GPU串联起来协同工作，那么我们基本上会直接将这些GPU互连。在英伟达（NVIDIA）生态系统中，我们采用NVLink技术直接连接GPU，从而绕过CPU——数据无需经过主机系统的内核；甚至在跨节点场景下，我们还可通过NVSwitch直接连接GPU，进而绕过以太网。由于以太网诞生已久，显然并非为这类应用而设计，NVSwitch与NVLink则完全跳过了传统路径，专为优化我们所关注的这类工作负载而设计。以H100为例，每块GPU（注意：原文“each node has”应为“each GPU has”）在第四代中配备18条NVLink，总带宽达900 GB/s。与PCIe相比，该带宽显然快得多；与以太网相比，更是快出数个数量级；若再与从流式多处理器（SM）访问高带宽内存（HBM）的延迟相比，NVLink仍快约四倍。当然，随着新一代Blackwell架构的推出，这一数值预计还将提升两到三倍。好的，是的。那么关于PCIe的问题是：数据如何传输？我认为数据仍需经由CPU。还有其他问题吗？PCIe最初是为连接各类外设（例如……）而设计的。

## 段落 9

**英文**: sound card or your SSD hard drive so it's not really it's sort of like a general purpose bus for communication of devices. Yeah. And the unit also has a connection with the CPU. Yeah so the question is NVLink also connects to the CPU. We're going to see a bit later how I think maybe just in this slide how things are connected. Yeah. So you still need to talk to your CPU of course. Yeah. Okay so there's this command that you can run and this produces some output which allows you to see how the GPUs are actually connected so I ran this on our cluster there's eight GPUs I guess you won't be able to get eight GPUs but I guess if you could this is what it would look like and you see that between every pair of GPUs there's MV18 connecting there's also these kind of network cards and other things. Okay.

**中文**: 声卡或固态硬盘（SSD），因此它本质上是一种用于设备间通信的通用总线。是的。此外，该单元还与CPU相连。是的，因此问题在于：NVLink是否也连接到CPU？稍后我们将看到（可能就在本页幻灯片中）各组件是如何连接的。是的，当然，您仍需与CPU进行通信。好的，这里有一个可执行的命令，运行后会输出一些信息，帮助您了解GPU之间的实际连接方式。我在我们的集群上运行了该命令——集群共有八块GPU；我想您可能无法获得八块GPU，但假如可以的话，输出结果将如图所示。您可以看到，每对GPU之间都通过NVLink（此处原文为MV18，疑为笔误，应为NVLink）相连；此外还有这类网卡及其他设备。好的。

## 段落 10

**英文**: Oh yeah so then network cards are basically what gives you the PCIe connection and the. CPUs. So okay so that's the hardware. So how do you use the hardware? So Nvidia has spent a lot of time developing really good software on top of their I guess really good hardware and there is a collective communication library by Nvidia called Nickel and this essentially translates the collective operations which we looked at before like all reduce into low level packets that need to be sent between GPUs. So this library actually does a lot of work because it allows the programmer just to operate. that level of I need this tensor to appear on all the machines and it just happens. Okay. So just a little bit of what happens is when you configure setup Nickel you bring up a bunch of devices and there's some communication that happens to figure out the topology of the hardware, it optimizes the path between the GPUs and then when you actually call these collective communication operations and they're launched CUDA kernels to send and receive data. Okay so that's Nickel, it's provided as a library but Nickel is still a bit too low. level to us because most of what we're doing is in Python so there's a PyTorch has this Torch distributed library which essentially provides a clean interface for these collective operations.

**中文**: 哦，对，那么网卡基本上提供了PCIe连接以及CPU。所以，好的，这就是硬件部分。那么，如何使用这些硬件呢？英伟达投入了大量时间，在其（我猜）非常优秀的硬件之上开发出极为出色的软件。英伟达提供了一套名为NCCL（NVIDIA Collective Communications Library）的集合通信库，该库本质上是将我们之前讨论过的集合操作（例如AllReduce）转化为GPU之间需要传输的底层数据包。该库实际上承担了大量工作，因为它使程序员只需在较高抽象层级上进行操作——例如，只需声明“我需要这个张量出现在所有机器上”，系统便会自动完成。具体而言，当配置并启动NCCL时，会初始化一批设备，并通过一些通信过程来识别硬件拓扑结构，进而优化GPU之间的通信路径；随后，当实际调用这些集合通信操作时，系统会启动CUDA内核来发送和接收数据。以上就是NCCL：它以库的形式提供，但对我们而言，NCCL仍属于较低层级——因为我们大部分工作是在Python中完成的，因此PyTorch提供了Torch Distributed库，该库为这些集合操作提供了简洁易用的接口。

## 段落 11

**英文**: Now from the comfort of your PyTorch program you can just write all gather into tensor on a tensor and it will appear on all the different ranks. It also has this nice useful feature that it supports multiple backends for different hardware so in particular Nickel remember was for GPU but you can also run collective operations, remember this is not GPU specific it's just for any set of devices so you can. also do it for CPU using this backend called Glue. So if you're debugging stuff on your laptop for your assignment for example you can use Glue and still be able to run things without even a GPU. So anyway that's another advantage of having these high level primitives is that they're much more portable than having to only having something that's very GPU specific. Of course the performance is going to really depend on the hardware but at least logically you can make sure your code runs. PyTorch distributed also supports other high level things like FSTP which Tatsu talked. about last lecture but we're not going to use this in this class because in the spirit of developing things from scratch that's just what we're going to do. Okay so let's look at some examples of how Torch that distributed collective operations work. So there's this utility function I wrote which you can take a look at in the code if you want which takes a function and just runs this basically it's a wrapper around Python multiprocessing where it just runs four processes that execute this function.

**中文**: 现在，您只需在 PyTorch 程序中舒适地编写“all-gather”操作，将数据聚合到一个张量中，该张量便会自动出现在所有不同的进程（rank）上。它还具备一项实用的特性：支持多种后端，以适配不同硬件。例如，此前提到的 NCCL 后端专为 GPU 设计，但您同样可以运行集合通信操作——请注意，这类操作并非 GPU 专属，而是适用于任意一组设备；因此，您还可借助名为 Gloo 的后端在 CPU 上执行这些操作。例如，若您正在笔记本电脑上调试作业代码，即可使用 Gloo 后端，甚至无需 GPU 也能正常运行。总之，采用这些高级原语的另一大优势在于其高度可移植性，远胜于仅针对 GPU 的专用实现。当然，实际性能仍高度依赖硬件，但至少从逻辑层面，您能确保代码顺利运行。PyTorch 分布式模块还支持其他高级功能，例如上次讲座中 Tatsu 提及的 FSDP（全分片数据并行），但本课程暂不采用该功能，因为我们秉持“从零开始构建”的理念，将自行实现相关机制。好了，接下来我们通过一些示例，了解 PyTorch 分布式集合通信操作的具体工作方式。为此，我编写了一个工具函数（您可在代码中查阅），该函数接收一个目标函数，并在其基础上进行封装——本质上是 Python 多进程模块的封装器，可同时启动四个进程来执行该函数。

## 段落 12

**英文**: So when you're in this function you should think about it as there's actually world. size number of processes running this identical function where the rank indexes from 0, 1 all the way to world size minus 1. So right now I'm stepping through just one of the ranks because lectures are not parallel. And so generally what you do is you the first thing the process needs to initialize itself and you essentially they need to kind of find each other right because your multiprocessor running a lot of processes they need to connect to a single host so that they can figure know that each other exists. So know that this is not where all of the data goes. The data goes through nickel but this is just for kind of coordination. And since we have a GPU we can use nickel otherwise you would use glue. Okay so after you set up so now we're going to do some stuff. There's this useful function called a barrier which basically waits for all the processes in your process group to get to this point. Remember everything is running asynchronously and in some cases you just want to have a synchronization point so barrier does that.

**中文**: 因此，当你进入该函数时，应将其理解为：实际上有 world_size 个进程在并行执行这个完全相同的函数，其中 rank 从 0、1 一直编号到 world_size − 1。目前我仅逐行演示其中一个 rank 的执行过程，因为授课本身并非并行进行。通常，进程首先需要完成自身初始化；本质上，它们还需相互发现彼此——这是因为多处理器上运行着多个进程，它们需连接至同一主机，从而确认彼此的存在。请注意，此处并非所有数据的传输通道；数据实际经由 NCCL（NVIDIA Collective Communications Library）传输，而此处仅用于协调同步。由于我们配备了 GPU，因此可使用 NCCL；若无 GPU，则需改用 Gloo。好的，完成设置后，接下来我们将执行一些操作。这里有一个非常实用的函数叫 barrier（屏障），其作用是令进程组中的所有进程均等待至该点才继续执行。请记住，所有操作均为异步运行；而在某些情况下，我们恰恰需要一个同步点，barrier 正是为此而设。

## 段落 13

**英文**: The reason I put it here is actually sort of for trivial reasons because I want all these. print statements to kind of be grouped together. But there's other reasons why you might want to use barrier as we'll get to later. So I'm going to for each of these groups construct a tensor. So the tensor is 0, 1, 2, 3 plus the rank. So I'm going to print out for each rank before it all reduce what does it look like. Okay so here's what it looks like. Can people read that in the back? Yes?. Okay good. All right so on rank 0 it's 0, 1, 2, 3, rank 1, 1, 2, 3, 4 and so on.

**中文**: 我之所以将它放在这里，实际上出于一些琐碎的原因——我希望所有这些 print 语句能够集中在一起。不过，稍后我们还会讲到使用 barrier 的其他原因。接下来，我将为每一组构造一个张量：该张量为 0、1、2、3 加上当前进程的秩（rank）。因此，我将在执行 all-reduce 操作之前，为每个秩打印出其张量的样子。好的，这就是它呈现的效果。后排的各位能看清吗？能？好的，很好。那么，秩为 0 时，张量是 0、1、2、3；秩为 1 时，是 1、2、3、4；以此类推。

## 段落 14

**英文**: And notice that because it's async the order is just out of order in whatever order it happens to print. Okay so each rank has a different tensor and then you all reduce. So all reduce you pass in the tensor you say I want to sum it. In this case I'm not going to do async but you can do async which is useful for overlapping communication and computation. And then afterwards what happens after all reduce as advertised basically for the first component you add them up you get 6, this you get 10, 14 and 18. Okay so after all reduce basically this tensor gets overwritten with the corresponding sum. So it's very nice and simple to use. Okay so let's do reduce scatter. So reduce scatter I'm going to create an input which has dimension world size in which case this is 4 and I'm going to allocate an output because reduce scatter is not going to operate in place this is just going to be a scalar. So before the reduce scatter this is what it looks like.

**中文**: 请注意，由于这是异步操作，输出顺序是乱序的，完全取决于实际打印发生的顺序。好的，每个进程拥有一个不同的张量，然后执行全归约（all-reduce）操作。在全归约中，你传入待处理的张量，并声明希望对其执行求和操作。本例中我将不使用异步模式，但你也可以启用异步模式，以便实现通信与计算的重叠。全归约完成后，如前所述，第一个分量相加结果为6，第二个为10，第三个为14，第四个为18。因此，全归约操作后，该张量会被对应分量的求和结果直接覆盖。使用起来非常简洁明了。好的，下面我们来演示归约-分发（reduce-scatter）操作。对于归约-分发，我将创建一个输入张量，其维度等于进程总数（即此处为4），并单独分配一个输出张量——因为归约-分发操作不能原地执行，此处输出仅为一个标量。归约-分发操作前，张量状态如下所示。

## 段落 15

**英文**: I have my input as before, output happens to be 0s but it could be any value since I didn't initialize it. And then after the reduce scatter we're passing the input and the output and I'm going to sum then I get essentially what happens is that for the first component I sum and that goes on rank 0 for the second component I sum and it goes on rank 1 and so on. Okay so as you notice it is producing the same operation as all reduce except for the output is sort of scattered across all the different ranks. Okay so now let's do all gather. So I'm going to just directly use the output of reduce scatter which is this as the input and then I'm going to allocate an empty array for the output. And then so before the all gather the input is this and the output I guess are just arbitrary values. And after I do the all gather what happens is I get all these tensors to show up on all the devices. Okay so this is just kind of also an example. Hopefully now you're very convinced that reduce scatter plus all gather is just all reduce because I computed exactly the same quantity as I did for all reduce. Okay questions? Is this clear? Yeah.

**中文**: 我的输入和之前一样，输出恰好为全0，但实际上它可以是任意值，因为我并未对其进行初始化。然后，在执行规约-分散（reduce-scatter）操作后，我们将输入和输出传入，并对它们求和；结果是：第一个分量的求和结果位于0号进程上，第二个分量的求和结果位于1号进程上，依此类推。明白了吗？如您所见，该操作本质上与全规约（all-reduce）相同，区别仅在于输出被分散到了各个进程上。好的，接下来我们执行全聚集（all-gather）。我将直接使用前述规约-分散操作的输出（即上述结果）作为输入，并为输出分配一个空数组。因此，在执行全聚集操作前，输入即为上述结果，而输出则为任意值。执行全聚集后，所有这些张量将出现在所有设备上。好的，这只是一个示例。希望现在您已充分信服：规约-分散加全聚集等价于全规约，因为我所计算的量与全规约完全一致。有问题吗？这样讲清楚了吗？是的。

## 段落 16

**英文**: In reduce scatter are we keeping track of which index goes to which GPU? So the question is in reduce scatter do you keep track of which index goes to which GPU? So by convention the dimensionality has to be basically the world size. I mean it could be a general tensor but one of the dimensions is the world size and it just infers that basically what you want to do is the output is the let's say the sorry the input has to be basically world size and then it knows that basically the corresponding computations go to each of the outputs. Yeah you have to be a bit careful with making sure the dimensionality aligns. So going through this small examples can be helpful. Is there another question? Okay so finally we're now in this process that's running and when you're done you just clean up. Okay so so far we've talked about these collective operations, a bit about how they're implemented in PyTorch and it's nickel and then PyTorch. Let's do a bit of benchmarking. In the spirit of what we did in assignment or the first lecture or rather the second lecture, we're going to focus on one node for now. So let's do all reduce. So I'm going to have this tensor of 100 million elements and a world size of four.

**中文**: 在规约-分散（reduce-scatter）操作中，我们是否追踪每个索引被分发到哪一块GPU？也就是说，在规约-分散操作中，您是否会追踪每个索引对应哪一块GPU？按照惯例，张量的某一维度大小必须等于全局进程数（world size）。当然，输入张量可以是任意形状的，但其中必须有一个维度的大小恰好等于全局进程数；系统据此推断：输入张量沿该维度被切分为若干份，每一份将被送至对应GPU上执行相应的规约计算。是的，您需要特别注意确保该维度大小与全局进程数严格对齐。通过分析一些小型示例有助于理解这一点。还有其他问题吗？好的，那么现在我们已进入实际运行流程，任务完成后只需进行清理即可。到目前为止，我们已讨论了这些集合通信操作，简要介绍了它们在PyTorch中的实现方式——先是基于NCCL，再是PyTorch自身封装。接下来我们进行一些基准测试。秉承作业或第二讲（而非第一讲）的精神，我们目前先聚焦于单节点场景。因此，我们以全规约（all-reduce）为例：我将创建一个包含一亿个元素的张量，并设置全局进程数为4。

## 段落 17

**英文**: Okay so I'm going to just allocate a tensor and generally as I think as you hopefully can appreciate. now that when you benchmark you have to really be careful to kind of clean your palate in some sense. Like you in this case I'm going to warm up basically run the operation once and then synchronize and do barrier. Some of this is I think probably a bit defensive but just to be safe so that all the kernels get loaded and whatever needs to be kind of computed gets computed. And then I'm going to start the clock, all reduce and then synchronize again and stop the clock. Okay so now I can look at how long that took. Okay so if I scroll down here, I guess this is not that informative. I should have printed in microseconds probably. It was I guess very quick. Some number of seconds.

**中文**: 好的，接下来我将直接分配一个张量。如您可能已体会到的那样，在进行性能基准测试时，必须格外谨慎，以某种方式“清空”系统状态。例如，本例中我将先进行预热：即先执行一次该操作，然后同步并设置屏障。其中部分操作虽略显保守，但为确保万无一失，可保证所有内核均已加载，且所有必要计算均已完成。随后，我将启动计时器，执行全归约（all-reduce）操作，再次同步，最后停止计时器。好了，现在我可以查看该操作耗时多久。嗯，如果我向下滚动此处，看起来这些信息并不十分直观——我本应以微秒为单位打印出来。实际耗时应该非常短，仅为若干秒。

## 段落 18

**英文**: And now let's measure the bandwidth which is the number of gigabytes that were actually transferred in aggregate per second. Okay so the way we do that is we have to think about what actually gets transferred here. So there's a tensor with that element size and the size of each element is I guess this I think this is float 32 so that would be 2, sorry 4 bytes. And so that's the size in bytes. Okay so now this is a little bit subtle. So how many bytes are actually sent or transferred? Sent slash received. So each tensor sitting on a rank has size bytes. And it needs to send it to world size minus 1, other machines or ranks rather. So there but there's a factor of 2. So why is there a factor of 2? Because you're doing it all reduce.

**中文**: 现在，我们来测量带宽，即每秒实际传输的总字节数（以GB为单位）。  
好的，我们先思考一下这里实际传输的是什么。  
有一个张量，其每个元素的大小——我猜是float32，因此每个元素占4字节。这就是该张量的字节大小。  
接下来这一点稍显微妙：实际发送或接收的字节数是多少？（即发送/接收的字节数）  
每个位于某进程（rank）上的张量大小为“字节大小”。它需要将自身发送给其余world_size−1个进程（或机器）。  
但这里存在一个系数2。  
为什么会有这个系数2呢？因为我们在执行all-reduce操作。

## 段落 19

**英文**: Remember so you need to send all the distinct elements into basically one place. It needs to get summed up and then that needs to go back to everyone. Okay. So a rank needs to just kind of send the input out and then receive the output. So that's why there's a factor of 2 there. And so the total duration is the world size times the actual duration that passed. So I guess we're just kind of assuming that every, you know if there's four processors that's sort of like four times as much wall clock time that happened. And the bandwidth is just the bytes over the duration. Okay so what do we get here is about 277 gigabytes per second. Okay so you know I think for H100 above I think I claim that there was something like 900 gigabytes per second.

**中文**: 请记住，因此你需要将所有不同的元素基本上发送到一个地方。这些元素需要被累加，然后累加结果需返回给所有节点。好的。因此，每个进程只需将输入数据发送出去，再接收输出结果。这正是其中存在系数2的原因。因此，总耗时等于进程总数乘以实际经过的时间。也就是说，我们大致假设：例如若有四个处理器，则所经历的挂钟时间大约是单个处理器的四倍。而带宽则等于传输字节数除以耗时。好的，那么这里得到的结果约为277 GB/s。好的，据我所知，对于H100及以上型号，我认为其带宽声称可达约900 GB/s。

## 段落 20

**英文**: Now of course as we know your mileage varies depending on the size of the tensors and the exact number of devices and the weather and whatever. No not the weather but but you know various factors so your your mileage might vary. So it's always good to benchmark to see what is actually the number of gigabytes per second you're getting. Okay. So reduced scatter is going to be very similar so let's just go through this very quickly. So we created input which is world size times number of elements. So each rank is going to have this matrix. And so we're going to warm up and then start the clock, reduce scatter, stop the clock, and then see how long it took. Well okay that's not helpful. And then let's look at the bandwidth.

**中文**: 当然，众所周知，实际性能会因张量大小、设备确切数量以及其他各种因素而有所不同（当然不包括天气因素，但您明白我的意思——存在诸多变量），因此您的实际性能表现可能有所差异。因此，始终建议进行基准测试，以准确了解您实际获得的带宽（单位：GB/s）。好的，接下来介绍“规约-分散”（reduce-scatter）操作，其流程与此非常相似，我们快速过一遍即可。首先，我们创建一个输入张量，其大小为进程总数（world size）乘以每个进程的元素数量，即每个进程均持有该矩阵的一个副本。随后，我们先执行预热操作，再启动计时器，执行规约-分散操作，之后停止计时器，从而获知整个操作耗时。嗯……这样看似乎并不直观。接下来，我们来看带宽指标。

## 段落 21

**英文**: So the number of cent bytes is no factor of two here because in reduced scatter remember all you're doing is you're you're sending your inputs into one place. If you just think about reduce right all the elements just go into one place and that's it. And scatter just means that different components of your tensor are going to different places but it's effectively it's it's like a you know reduce. Okay so if you do the same calculation you'll see that it's I guess I get 70 in this case. So I don't exactly know why it's exactly 70 as opposed to some other number. I guess one could speculate that all reduce generally there's more traffic that you know happens and all reduces are potentially more optimized. I think that Nvidia hardware has this kind of sharp acceleration that actually does sort of some of these computations in you know in the actual network which shades off a factor of two but I don't know if that completely accounts for a difference here. There's a lot of stuff that happens in nickel that it's a little bit hard to kind of reason about the performance exactly hence benchmarking. Yeah. Question about the set bytes and or the data bytes and how that was calculated.

**中文**: 因此，此处的字节数并非2的整数倍，因为在规约散射（reduced scatter）操作中，如前所述，您只是将输入数据发送至单一位置。只需考虑规约（reduce）操作本身：所有元素均汇聚至一个位置，仅此而已；而散射（scatter）则意味着张量的不同分量被发送至不同位置，但本质上它类似于规约操作。好的，若进行相同计算，您会发现此处结果为70。至于为何恰好是70而非其他数值，我尚不完全清楚。或许可以推测：全规约（all-reduce）通常涉及更多通信流量，且全规约操作本身可能经过更充分的优化。我认为NVIDIA硬件具备某种显著的加速能力，实际上能在网络内部直接执行部分此类计算，从而节省约一半开销；但我不确定这是否足以完全解释此处的性能差异。NVIDIA驱动栈（nickel）内部存在大量复杂操作，精确分析其性能存在一定难度，因此需依赖基准测试。是的。关于“set bytes”和/或“data bytes”的问题，以及它们是如何计算得出的？

## 段落 22

**英文**: Yeah. Specifically it looks like it actually is just like the data that's being sent into the output. But what about like the inputs or the reductions then? I was wondering how it gets the inputs to do the reduction. So the question is it seems like this is just the the bytes for the output and what about the input. So to be clear I am assuming that the inputs just are already on the device so I'm not counting that time and just I'm just counting what needs to happen to do the reduce scatter. This is just a scatter operation. This is a reduce scatter operation. So you need the reduction sample. So this function does reduce scatter. So it's one operation.

**中文**: 是的。具体来说，它看起来确实只是输出所接收的数据。但输入或规约操作呢？我一直在想，它是如何获取输入来执行规约的。因此，我的疑问在于：这似乎仅涉及输出数据的字节，那么输入数据呢？为明确起见，我假设输入数据已预先驻留在设备上，因此不计入该部分耗时，而仅统计执行规约-分散操作所需的时间。这并非单纯的分散操作，而是规约-分散操作。因此，需要进行规约运算。该函数执行的就是规约-分散操作，即单一操作。

## 段落 23

**英文**: I mean like you really covered the bytes in the previous sample because you were doing a reduction with the covered for hand, the bytes, the hand form. So you're saying that for all reduce there were there's a 2x because you needed to reduce and then you needed to spread out again. For reduce scatter I mean it's just a name. It's called reduce scatter but it's really just a reduction. Okay. And you can also see based on this that if you do reduce scatter and you do all gather each of those doesn't have the factor of 2 so when you add them up you get a factor of 2 which is another way to see that all reduces twice. Okay. And there's some references you can go read about how to benchmark and these collective operations. Okay. So let's now talk about the distributed training piece.

**中文**: 我的意思是，在之前的示例中，你实际上已覆盖了字节量，因为你手动对“手写形式”的字节进行了规约操作。因此，你指出：对于全规约（all-reduce），存在一个2倍的开销，因为你既需要执行规约，又需要将结果再次分发出去。而规约-分散（reduce-scatter）——顾名思义，虽称作“规约-分散”，但实际上仅执行规约操作。好的。此外，从这一点也可看出：若分别执行规约-分散和全收集（all-gather），这两项操作各自均无2倍开销；但将二者相加后，总开销即为2倍，这从另一角度印证了全规约需执行两次操作。好的。关于如何对这些集合通信操作进行基准测试，还有一些参考资料可供查阅。好的。接下来，我们讨论分布式训练部分。

## 段落 24

**英文**: So our general approach here is going to be I'm going to walk through a bare bones implementation of each strategy on deep MLPs essentially. So recall that you generally are in the regime where the MLPs are the compute bottleneck and transformers, not the attention. And so in some ways even though this is a very simple architecture it's fairly representative of the type of you know workloads that you'll see. Okay so let's start with data parallelism. Actually just one note is that data tensor and pipeline parallelism are you can just think about them as different ways of cutting up your, your either your model or your, your data, which hopefully I'll depict visually here. Okay so in data parallelism. So in a structure model assuming it has four layers, each layer of the MLP is just a matrix multiply, where this is the hidden dimension. And so the data is also a matrix which is, there's the batch dimension and then the hidden dimension and data parallel just cuts along the batch dimension into essentially smaller pieces. Now each rank is going to get a different slice of the data. So let's do an example here.

**中文**: 因此，我们在此处采用的总体方法是：我将逐一介绍每种策略在深度多层感知机（MLP）上的最简实现。需要回顾的是，通常情况下，MLP才是计算瓶颈，而非Transformer中的注意力机制。因此，尽管该架构极为简单，却在很大程度上能代表你实际会遇到的工作负载类型。好的，我们先从数据并行开始。另外需说明一点：数据张量并行与流水线并行，可简单理解为对模型或数据进行切分的不同方式——这一点我稍后将通过图示加以说明。好的，来看数据并行：假设一个结构化模型包含四层，而每一层MLP仅执行一次矩阵乘法运算，其中该矩阵的维度即为隐藏维度；同时，输入数据本身也是一个矩阵，其维度包括批处理维度和隐藏维度；而数据并行则仅沿批处理维度将数据切分为若干更小的片段。此时，每个计算节点（rank）将获得数据的不同切片。下面我们通过一个具体示例来说明。

## 段落 25

**英文**: So I'm going to generate some sample data. So let's say I have batch size of 128, hidden dimension of 1024, and then just generate some random data. Okay, so I have batch size by number of dimension, and I'm going to run this data parallel algorithm, or DDP. So, so here, I'm going to, so I got past this, this data, there's a batch size and the dimension as claimed from before. So now I divide the batch size by the world size so I get the local batch size, that's how many, you know, how big the batch size is on a given rank. And then I'm going to, based on the rank, just figure out which starting and the indices of size local batch size I need to access and then get the corresponding data from that. So basically, I'm just reaching in and grabbing some subset of the rows based on the rank. Okay, so now I'm setting up the MLP here, and this is done very sort of bare bones, you could say. So here I am creating the MLP parameters. So each layer has essentially a matrix which is num dimension by num dimension, and remember num dimension is 1024.

**中文**: 因此，我将生成一些示例数据。假设我的批处理大小（batch size）为128，隐藏层维度（hidden dimension）为1024，然后仅生成一些随机数据。好的，这样我就得到了一个形状为“批处理大小 × 维度数”的数据张量。接下来，我将运行该数据并行算法（即DDP）。此处，我传入的数据如前所述，包含批处理大小和维度信息。现在，我将用批处理大小除以全局进程数（world size），从而得到本地批处理大小（local batch size），即每个进程（rank）上实际处理的批大小。接着，我将根据当前进程的rank，确定所需访问数据的起始索引及长度为本地批处理大小的索引范围，并据此从原始数据中提取对应子集。本质上，我只是依据rank直接选取并提取数据矩阵中相应行的子集。好的，现在我来构建多层感知机（MLP），此处实现极为基础（bare bones）。这里我正在创建MLP的参数：每一层本质上都包含一个维度为“维度数 × 维度数”的权重矩阵，而该维度数即为1024。

## 段落 26

**英文**: And I'm going to create the optimizer. So remember this function is running asynchronously on all the different, on each rank. So each of the four ranks is going to be running this with rank equals 0, 1, 2, 3. And now I'm going to start training. So for a number of steps, I'm going to do a forward pass through the layers, matrix multiply non-linearity, matrix multiply non-linearity. There's four layers here, going to compute some loss. I don't really care what the loss is, it's just made up, something made up. And I'm going to do the backward pass. So so far, this just looks like I'm implementing SGD, right? And that's kind of the point. The only difference is now to implement DDP is that you just like inject this line here, which syncs, synchronizes the gradients across workers.

**中文**: 接下来我将创建优化器。请记住，该函数会在所有不同的进程（即每个rank）上异步运行。因此，四个rank将分别以rank=0、1、2、3执行此函数。现在我将开始训练：在若干训练步数内，我将依次进行前向传播——经过各层（矩阵乘法、非线性变换、矩阵乘法、非线性变换），此处共有四层，然后计算某个损失值。该损失值具体为何并不重要，仅为虚构设定。接着我将执行反向传播。到目前为止，这看起来完全就是在实现随机梯度下降（SGD），对吧？而这恰恰是设计意图所在。唯一不同之处在于，要实现分布式数据并行（DDP），只需在此处插入这一行代码，用于在各工作进程间同步梯度。

## 段落 27

**英文**: So what you do is for each of the layers, you call it all reduce, where you're averaging, and the thing you're averaging is param. grad. Okay, so it's just like you've kind of hijacked this, someone's SGD code, and you're saying, wait, I'm actually going to just mix all the gradients after the backward pass. And then after you do that, you just update the parameters as usual. So from the SGD perspective, it seems like nothing is happening. I'm just running SGD, but someone has just mixed my gradients. Okay. So I guess just print out some things. So data parallel, I'm printing out the loss. So one thing to note is that the losses are different between all the different ranks because they have different data.

**中文**: 因此，您要对每一层执行“全归约”（all-reduce）操作，即对参数的梯度（param.grad）进行平均。换言之，您相当于“劫持”了某人的随机梯度下降（SGD）代码，并声明：“稍等，我将在反向传播之后直接混合所有梯度。”完成该操作后，再照常更新参数。从SGD的角度看，似乎一切如常——我仍在运行SGD，但有人却已将我的梯度进行了混合。好的，接下来我们打印一些信息：在数据并行模式下，我将打印损失值。需要注意的一点是，由于各进程（rank）处理的数据不同，它们计算出的损失值也各不相同。

## 段落 28

**英文**: But after the all reduce, all the parameters are the same. Okay, so this is your textbook application of all reduce in ML setup. Yeah. So the question is, how do you ensure if all of these processes are just running asynchronously, how do you make sure that each of them is actually, for example, on the same step? This is because all reduce is a synchronization point. It'll stop everyone and do the all reduce. So you have to be careful because if one of your ranks has a missing all reduce, then it will just hang. Yeah. Yeah. Why does getting the initial parameters? The question is, why does getting initial parameters depend on the rank? They're the same. The reason is just because I guess I don't the code for this basically puts it on the appropriate GPU.

**中文**: 但经过全归约（all-reduce）操作后，所有参数都变得一致。好的，这就是机器学习场景中全归约的标准用法。是的。那么问题来了：如果所有这些进程只是异步运行，你如何确保它们实际上都处于相同的训练步数？这是因为全归约是一个同步点——它会暂停所有进程，执行全归约操作。因此你必须格外小心：一旦某个进程（rank）遗漏了全归约调用，整个系统就会卡住。是的，没错。那么，为什么初始化参数的获取依赖于进程编号（rank）呢？毕竟参数本身是完全相同的。原因在于，我猜相关代码只是将参数放置到对应的GPU上而已。

## 段落 29

**英文**: Any other questions? So DDP is something you're implementing assignment to, which maybe somebody you have looked at or maybe not. It will be done in the context of a transformer. But this is sort of the sort of the most bare bones version. So you can see very clearly what's happening. Okay. So that's DDP. Losses are different across ranks, but the gradients are reduced to be all the same. So therefore, the parameters of all the ranks are the same. So actually, you're doing world size number of SGD runs. But because they're synchronized, they're doing the same thing.

**中文**: 还有其他问题吗？因此，DDP（分布式数据并行）是您正在实现的赋值目标，可能您之前已经了解过，也可能尚未接触。它将在Transformer架构的上下文中实现，但此处展示的是最精简的版本，以便您能非常清晰地看到其中发生的过程。好的，以上就是DDP的介绍。各进程（rank）上的损失值各不相同，但梯度会经过规约（reduction）操作，使所有进程的梯度完全一致；因此，所有进程的模型参数也完全相同。实际上，您是在执行“world size”（进程总数）次SGD（随机梯度下降）更新，但由于各进程间保持同步，它们执行的是完全相同的操作。

## 段落 30

**英文**: So you can think about this as sort of an instantiation of analog of activation,. checkpointing where sometimes you just do extra compute because you don't want to store things. In this case, we could have, for example, shipped the optimizer state around. But that would be a bad idea because it's much faster just to update the optimizer state then to actually move the optimizer parameters around. Okay. So last year, I did try to do FSDP, but that was a sort of a hairball. So I'm going to skip that and do a tensor parallel. So here, the picture is we leave the data the same. And now what we're going to do is we're going to cut the model along the hidden dimension. So each rank is going to get every layer, but it's going to get only part of each layer.

**中文**: 因此，您可以将此理解为一种激活模拟的实例化，类似于检查点技术——有时我们会额外进行计算，以避免存储数据。在本例中，我们本可以将优化器状态在各设备间传输，但这并非良策，因为直接更新优化器状态远比实际移动优化器参数要快得多。好的。去年我曾尝试采用完全分片数据并行（FSDP），但结果一团混乱，因此我将跳过该方案，转而采用张量并行。在此方案中，数据保持不变；而我们将模型沿隐藏维度进行切分：每个进程（rank）均获得全部网络层，但仅获得每层的一部分参数。

## 段落 31

**英文**: And what we're going to end up doing is transfer all the data and the activations around. Okay. So we're generating the same sample data. And let's look at tensor parallel. Okay. So I have the batch size and number of dimension as before. And now I'm going to not, before I was cutting batch size, but now I'm cutting numdim. So I have local numdim equals 1,024 divided by world size, and that's 256. So each model essentially, sorry, each rank gets a part of the model, which is one over the world size fraction of the parameters. Okay.

**中文**: 我们最终将执行的操作是围绕各处传输所有数据和激活值。好的，因此我们正在生成相同的样本数据。接下来，我们来看张量并行。好的，我仍采用之前的批量大小和维度数量。但现在，我不再像之前那样切分批量大小，而是切分维度数量（numdim）。因此，本地维度数量（local numdim）等于1024除以进程总数（world size），即256。换言之，每个进程（rank）实际上获得模型的一部分，其参数量占整个模型参数总量的1/world size。

## 段落 32

**英文**: And remember why we're doing parallelism at all is because the model won't be able to fit into a single GPU. So we're going to shard across multiple GPUs. So the parameter matrices are now numdim by local numdim. And now each rank is going to, I'm only going to implement the forward pass here, not the whole training loop. So I'm going to start going through all the layers. Okay. So I'm going to compute the activations first. So this looks pretty normal, except for remember the activations are actually batch sized by local numdim rather than numdim because each rank only has a fraction of the activations now. But now once I get the activations, I need to communicate. And here what I have to do is I'm going to allocate memory for all the activations.

**中文**: 请记住，我们之所以采用并行化，根本原因在于模型无法完全放入单个GPU中，因此需要将模型切分到多个GPU上。此时，参数矩阵的维度变为“numdim × local_numdim”。接下来，我仅在此处实现前向传播过程，而非完整的训练循环。我将逐层遍历所有网络层。好的，首先计算激活值。这部分看起来与常规实现基本一致，但需注意：由于每个进程（rank）现在只持有部分激活值，因此激活值的实际尺寸为“批大小 × local_numdim”，而非“numdim”。然而，在获得激活值后，我需要进行通信。此处，我需要为全部激活值分配内存。

## 段落 33

**英文**: So at this point, every one has an X, but that X represents a different part of the activations. Okay. So now I'm going to just allocate batch size by local numdim, but world size number. So basically each rank is going to basically have enough. I'm going to just get the, basically have world size number of batch size by local numdim matrices. And then I'm going to do an all gather. Okay. So I'm going to send all the activations and this, I mean, it's fairly simple. So X remember is batch size times local numdim, but X is different for every rank. So when I do the all gather, I'm going to put it in activations, which has essentially a world size number of the same shape as X.

**中文**: 因此，此时每个进程都有一个X，但该X代表激活值的不同部分。好的。接下来，我将按批次大小乘以本地维度数再乘以全局进程数来分配内存。也就是说，每个进程基本都会拥有足够的空间。我将得到全局进程数个形状为“批次大小×本地维度数”的矩阵。然后，我将执行一次全量收集（all-gather）操作。好的，我将发送所有激活值，这其实相当简单。如前所述，X的形状为“批次大小×本地维度数”，但每个进程的X各不相同。因此，在执行全量收集时，我会将结果存入activations张量中，该张量本质上包含全局进程数个与X形状相同的矩阵。

## 段落 34

**英文**: Okay. So now every rank has the same activations. Now it has activations of all the models, of the whole model. Okay. And then just like, just to concatenate them together to get X. Okay. So now X is now again batch size by numdim. Okay. And I repeat. So as you can see, this is, there's quite a bit of communication that happens, which is why, remember Tatsu said that for tensor parallel, you need pretty high interconnects.

**中文**: 好的。现在每个秩（rank）都拥有相同的激活值，即整个模型所有部分的激活值。好的。然后，只需将它们拼接起来，得到X。好的。此时X的形状再次变为“批大小×特征维度”。好的。我重复这一过程。如您所见，此过程中存在相当多的通信开销，因此请记住，塔茨（Tatsu）曾指出，张量并行需要非常高的互连带宽。

## 段落 35

**英文**: Otherwise you'll be passing a lot of these activations around. Okay. And then you do it for the next layer and the next layer and you get the idea. And just to print out some output. So tensor parallel. Let's see here. Forward pass produces activations of basically the, you know, the full size and everyone has the same activations at the end. Okay. So backward pass, I'm going to skip because that's kind of annoying to do. All right.

**中文**: 否则，你将需要传递大量此类激活值。好的。接着，你对下一层、再下一层重复这一过程，以此类推。最后，只需打印一些输出即可。那么，张量并行呢？我们来看这里：前向传播生成的激活值基本为完整尺寸，且所有设备最终得到的激活值都相同。好的。至于反向传播，我将跳过这部分，因为实现起来比较繁琐。好的。

## 段落 36

**英文**: Any questions about that? Yeah. So why is it hard to do the backward pass? I don't think it's necessarily hard, but in, I guess, in the constrained, you know, time and space, it's not hard. It's just requires a bit more work. Okay. So now let's go to pipeline parallelism. So in this case, we're cutting the model by layers. So all the ranks get all the data and all the ranks, each rank gets all of one layer, but they get different layers. Okay. So sample the data and run this program, this function for all the ranks. So here I'm going to figure out how many layers go in each rank, which is two here.

**中文**: 关于这一点，大家有什么问题吗？是的。那么，为什么反向传播难以实现呢？我认为这未必一定很难，但受限于时间和空间条件，它确实并不难，只是需要多做一些工作。好的，接下来我们来看流水线并行。在这种情况下，我们按网络层对模型进行切分：所有进程（rank）都获得全部数据，而每个进程各自负责某一层（即每个进程完整地持有某一层的所有参数），但不同进程负责的层各不相同。好的，现在对数据进行采样，并为所有进程运行该程序（即该函数）。这里我将计算每个进程分配到多少层，此处为两层。

## 段落 37

**英文**: So I have a four layer network. I have two ranks. So each rank gets two of the layers. Just like this picture, actually. And here I'm going to just allocate the parameters just for the layers that I need. Okay. So I'm going to do the forward pass. Remember there's a further optimization that you can, you do, which is, you know, if you just, you know, do it naively, you get these pipeline bubbles that Tatsu talked about before. One way to sort of mitigate that is to break up the batch into micro batches. So here I'm going to divide this batch into batches of size 32, so four batches of size 32.

**中文**: 因此，我构建了一个四层网络，并将其划分为两个秩（rank），每个秩负责其中两层，正如图中所示。接下来，我仅针对各自所需的层来分配参数。好的，现在我将执行前向传播。需要提醒的是，这里还存在一种进一步的优化方法：若直接朴素地执行，就会出现之前Tatsu所提到的流水线气泡（pipeline bubbles）；而缓解该问题的一种方法是将批次（batch）拆分为多个微批次（micro-batch）。因此，我将当前批次划分为大小为32的微批次，共得到四个这样的微批次。

## 段落 38

**英文**: And then now the idea is that every rank is going to essentially wait for the previous rank to pass it to the activations. It's going to apply those layers and then it's going to forward it to the next rank. So starting at the base case, we have rank equals zero. That's just the data. So I'm just chunking the data into a bunch of micro batches. And going through each of the micro batches, I first, I receive the tensor. So I'm using these point-to-point primitives now instead of the collective primitives. And I essentially, you know, basically receive the tensor X. And I'm going to compute the layers that are assigned to this rank. So in this case, there's only two of them.

**中文**: 接下来，当前的设计思路是：每个计算节点（rank）本质上需等待前一个节点将激活值传递给自己，然后应用分配给本节点的层，再将结果转发给下一个节点。从基础情形开始，即 rank = 0，此时输入仅为原始数据。因此，我首先将数据切分为若干微批次（micro batches）。针对每个微批次，我首先接收张量——此处使用的是点对点通信原语（point-to-point primitives），而非集合通信原语（collective primitives）。具体而言，我接收张量 X，然后计算分配给该节点的各层。本例中，该节点仅负责两层计算。

## 段落 39

**英文**: And then I'm going to send it to the next rank. And again, send is a point-to-point operation. And then the next batch, I'm going to do the same thing. So, okay, so I'm going to skip that. Okay, so that's basically it. So pipeline parallel, at least the very naive version of it, is relatively conceptually simple. But it's hard to mention last time. There's many things that are missing from this basic implementation. Overlapping the communication and computation is something we're not doing at all here. For example, receive and send are synchronous, but you should really make them async.

**中文**: 然后我将把它发送给下一个层级。同样，这里的“发送”是一种点对点操作。接着，对于下一批数据，我将执行相同的操作。因此，好的，这部分我就跳过了。好的，基本就是这样了。因此，流水线并行——至少其最朴素的版本——在概念上相对简单。但上次也提到过，这种基础实现中缺失了许多内容。例如，我们完全未实现通信与计算的重叠；接收和发送目前都是同步的，但实际上应将其改为异步操作。

## 段落 40

**英文**: And also the order in which you do the forward, actually this is just the forward even, not the backward. But once you have the backward, then you have to figure out how to interleave the forward and the backward steps. Yeah. I guess maybe what you just mentioned about the async being shown here, I guess in actual Alex, the GPU will be sort of listening to whether another one passes something to it. And it's kind of this kind of like event-driven way. It only starts processing once the player before passes it to it. And then it starts processing. So the question is, is this kind of like event-driven programming, where you're just waiting for things to happen? I think event-driven programming, you basically write these handlers, and then whenever stuff happens, maybe you get a mouse click, maybe you get a file ready event, then a piece of code runs. That's quite different, I think, from this style of coding, where everything has to work in lockstep. It is true that you're sort of waiting for the previous rank to send you the information, but at least in this implementation, there's no flexibility of where it's getting from.

**中文**: 此外，前向传播的执行顺序——实际上这里仅涉及前向传播，而非反向传播。但一旦有了反向传播，你就需要确定如何将前向与反向步骤交错执行。是的。我想你刚才提到此处展示的异步机制，在实际的Alex系统中，GPU大致会监听是否有其他GPU向其传递数据，这本质上是一种事件驱动的方式：只有当前序GPU将数据传递给它之后，它才开始处理。那么问题在于，这是否属于事件驱动编程——即单纯等待事件发生？我认为事件驱动编程的核心在于编写各类事件处理器，当特定事件发生时（例如鼠标点击或文件就绪），相应的代码便自动运行。这种模式与当前这种所有操作必须严格同步的编程风格存在显著差异。诚然，你确实在等待前一级节点发送信息，但至少在本实现中，数据来源是固定且不可灵活变更的。

## 段落 41

**英文**: It's not like it's waiting for arbitrary data to come from anywhere. I think there are ways to do asynchronous training, which was, I think, quite popular more than 10 years ago, where it's more event-driven, where you have a server that sends data, and whenever the gradients are ready, it just uploads, and then the gradients get accumulated. And if workers die, then that score of handle more robustly. But in modern training, despite scaling up quite a bit, everything seems to be kind of in a synchronous paradigm. Yeah, so it is true that when I say the workers in the ranks are operating asynchronous, that's just because it's different processes, but you're still putting quite rigid synchronization on how everything is working in lockstep. Yeah? So the question is, how would you change this to overlap communication and computation? So, for example, when you send this, there's no reason to just wait for the data to be sent. You just basically fire off the send. Remember that the send actually happens on the GPU via some kernel launch, so that's sort of independent. And it can just go and process another micro-batch right away. So the way I think you would do this is there's another function called isend, which is asynchronous.

**中文**: 它并非在等待来自任意位置的任意数据。我认为存在一些异步训练的方法，这类方法在十多年前曾相当流行，其特点是更偏向事件驱动：由一个服务器发送数据，一旦梯度计算完成便立即上传，随后梯度被累积起来；若工作节点发生故障，该机制也能更稳健地处理。然而，在现代训练中，尽管模型规模已大幅扩展，整个流程却似乎仍普遍采用同步范式。是的，因此当我提到各进程（即各rank）中的工作节点是异步运行时，这仅仅是因为它们属于不同的进程；但事实上，我们仍在以非常严格的同步方式，要求所有操作严格步调一致。是的？那么问题来了：如何改造这一机制，以实现通信与计算的重叠？例如，在执行发送操作时，完全没有必要干等数据发送完毕；而应直接发起发送指令。请记住，该发送操作实际是通过GPU上的某个内核启动来完成的，因而本质上是独立的。此时，系统可立即着手处理下一个微批次。我认为实现这一目标的方式是使用另一个名为“isend”的函数，它正是异步发送函数。

## 段落 42

**英文**: Actually, this should be asynchronous, asynchronous, which returns a handle. And so you basically do all the send, and then at the end, you basically wait for all the sends to complete. And then for overlapping the, when you actually have a backwards step, then you basically have to schedule that in here. Yeah? Is that a entity or a send and a receive? You can be a multiple send, multiple receives. How is it? I don't know which one is which. So the question is, if you have multiple sends and multiple receives, how do you know which is which? So here, the tensor name doesn't matter. It's just whatever a variable is there. And what you're specifying is the source. So if I'm at a node and I'm receiving, then whatever the next message coming from that rank, I'm just going to put in this x and continue executing. What if I want to do two sends from the same rank? If you want to do two sends from the same rank to the same destination? Yeah.

**中文**: 实际上，这应当是异步的、异步的，即返回一个句柄。因此，你基本上先发起所有发送操作，然后在最后统一等待所有发送操作完成。至于重叠执行——当你实际执行反向传播步骤时，就必须在此处对相关操作进行调度。是吗？这是指一个实体，还是指一次发送加一次接收？它可以是多次发送、多次接收。具体情况如何？我无法分辨哪个是发送、哪个是接收。因此问题在于：如果你有多个发送和多个接收操作，该如何区分它们？此处张量名称并不重要，它只是任意一个存在的变量。你所指定的是源端（即发送方）。例如，若我在某个节点上执行接收操作，则来自该通信域（rank）的下一条消息将直接存入变量 x，随后继续执行。如果我想从同一通信域（rank）发出两次发送呢？你是说从同一通信域（rank）向同一目标地址发送两次？是的。

## 段落 43

**英文**: How does the node, how does that order which they brought in? So I'm not quite sure about this, but I think if you have two sends, it's sort of put in a stream. So the order of the sends still is preserved. It's just that other stuff can happen at the same time. So you can send to, like I think if you have a pair and you do two sends, then that order is preserved. But the order in which you send some other rank is sending to another rank, it can happen at any time. What would happen if you just did like this dot send, but then no one's receiving it? The order just gets not there or like? So what happens if you send and no one's received it? I think it would just stall. It would just wait. Because there's no, yeah. I mean, because I mean, the process could just be running and you don't know whether it will, it's just, I mean, just code executing. So you don't know if it's never going to get there or if it's just going to be a matter of time.

**中文**: 节点是如何运作的？它们引入的这种顺序又是如何实现的？对此我还不太确定，但我的理解是：如果你执行两次发送操作，这些操作会被放入一个流中，因此发送的顺序依然得以保持。只是在此期间，其他操作也可以同时进行。例如，如果你有一对进程并执行两次发送操作，那么这两次发送的顺序是被保证的；但如果你向其他进程发送消息，这些发送操作发生的时间则无法保证，可能在任意时刻发生。那么，如果只执行了类似“dot send”这样的发送操作，却没有任何进程接收它，会发生什么？这种情况下，顺序是否就不存在了？或者说，如果发送了消息却无人接收，又会怎样？我认为程序会陷入阻塞状态，一直等待下去。因为确实没有接收方——是的，我的意思是，此时进程仍在运行，而你无法预知它是否会最终接收到消息，还是仅仅需要等待一段时间而已。

## 段落 44

**英文**: Yeah. What happens to the last rank? So the question is what happens to the last rank? So at the end, the last rank has all the activation. So that has basically the results of a full forward pass. And then, you know, if you implement the backward pass, then you would be actually now computing the gradient with respect to loss. And then you would go back down and send to from rank to rank minus one and so on. Okay, I guess maybe I was afraid I was going to run out of time, but it looks like I had to actually have time. Maybe next year I should do the backward pass. Okay, so actually I'm going to finish quite early today. But so if you have any other questions you should ask. So so far we've gone through three simple examples of data tensor pipeline parallel.

**中文**: 是的。最后的秩（rank）会发生什么情况？因此，问题在于最后的秩会发生什么？在最后，所有激活值都位于最后一个秩上，这实际上相当于完成了一次完整的前向传播。接着，如果你实现了反向传播，那么此时你将实际计算损失函数对各参数的梯度；然后，你将逐级回传，即从最后一个秩传回倒数第二个秩，依此类推。好的，我之前还担心时间不够用，但看起来其实时间还很充裕。也许明年我该讲一讲反向传播部分。好的，因此我今天实际上会提前结束。不过，如果大家还有其他问题，请随时提出。到目前为止，我们已通过三个简单的例子介绍了数据张量流水线并行。

## 段落 45

**英文**: Of course, this is for simple MLPs. You would actually want to do this with your own fancier model like a transformer. I did argue that at least at the core ideas you can sort of understand through the MLP. I think the but of course when you want to train you want to train transformer not a deep MLP. So you still have to implement the full complexity. What's also missing is the communication and computation overlap, which is not really handled very carefully here. And there is generally a more complex code with bookkeeping. I encourage you to check out like Megatron, LIM, or PyTorch's FSTP. It gets fairly hairy. And one of the things that I think makes some of the bookkeeping at least for let's say FSTP, and you'll be exposed to this in a to a bit, is that if you want something that handles arbitrary architectures, then you have to figure out the parameters and do a bunch of bookkeeping to and figure out where their layers are and so on.

**中文**: 当然，以上仅适用于简单的多层感知机（MLP）。实际上，你更希望将这种方法应用于自己更复杂的模型，例如Transformer。我之前曾指出，至少在核心思想层面，可以通过MLP来大致理解相关原理。但显然，当你真正着手训练时，目标是训练Transformer而非深度MLP，因此你仍需实现全部复杂性。此外，当前方案还缺少通信与计算的重叠优化，而这一点在此处并未得到细致处理。整体代码也更为复杂，涉及大量簿记工作。我建议你参考Megatron、LIM或PyTorch的FSDP等实现——其复杂度相当高。其中一项使簿记工作（至少对FSDP而言）变得尤为繁杂的因素是：若希望支持任意网络架构，则必须自动识别模型参数，并进行大量簿记工作以确定各层的位置等信息。

## 段落 46

**英文**: Whereas in the MLP case, it's just I've sort of made a decision that I'm going to split the model in this particularly simple way. One other thing I'll just mention as an aside is that all of what we're doing in this course is as PyTorch, but it is useful to be aware of this whole other ecosystem around Jax and TPUs, which is actually kind of nice in some way. And the idea here is Jax allows you to define the model. It defines the sharding strategy, and then the Jax compiler handles the rest. So there's this toolkit that we developed called Lavantor based on Jax. And I'll just show you a snippet of what happened. So this is FSTP in 10 lines of code. And basically you have a model, and then you just say shard with this particular, I mean, I don't expect you to kind of read this exactly, but basically you define which dimension you're going to shard by. And then, you know, that's it. And similarly for tensor parallel, you're just saying I'm going to shard the model along the, you know, you can shard by the on the head dimension for attention, and also you can shard based on the model dimension.

**中文**: 而在多层感知机（MLP）的情形下，我只是做了一个相对简单的决定：将模型以这种特别简单的方式进行拆分。另外，我顺带提一下，本课程中所有内容均基于PyTorch实现；但了解围绕JAX和TPU的另一套生态系统也十分有益，这套生态在某些方面其实相当出色。其核心思想是：JAX允许你定义模型，并指定分片（sharding）策略，之后由JAX编译器自动处理其余所有工作。我们基于JAX开发了一套名为Lavantor的工具包。下面我将展示一段代码示例——这是仅用10行代码实现的FSTP（全序列张量并行）。本质上，你只需先定义一个模型，然后声明按特定维度进行分片（此处无需逐字细读，只需理解：你只需指明按哪个维度进行分片即可）；如此而已。类似地，在张量并行中，你只需声明将模型沿某个维度进行分片——例如，注意力机制中可按头（head）维度分片，也可按模型维度（model dimension）分片。

## 段落 47

**英文**: So in some sense, you know, this gives you a sort of conceptual simplicity of what you're trying to do is you have this basically computation graph, but it has these kind of dimensions, you know, the model dimensions, the embedding dimension, the attention, sequence dimension. And Jax allows you to basically just specify which dimensions you want to cut by and also define a mapping from that onto the actual TPUs. And then the Jax compiler magically just, you know, figures out how to compile that down into the primitives that shuffle things around. So this is much more higher level than, you know, doing the, the, operating with the collective communication. But, you know, we're sticking with PyTorch because it's, it allows you to see kind of underneath the hood what's actually happening. But if you're actually doing this in the real world, obviously you don't need a, and you probably shouldn't implement all of this from scratch. Okay, so that's the end of the Jax digression. So just summarize, we've seen many ways to parallelize so far. And each of these ways of parallelizing is you can think about just like splitting either the model or the data along some dimension, either the data, the batch dimension or the width dimension or the depth dimension or the context length dimension. We also see these, this kind of recurring theme of, you know, recomputation.

**中文**: 因此，从某种意义上说，这为你提供了一种概念上的简洁性：你所要做的本质上就是处理一张计算图，而这张计算图具有若干维度——例如模型维度、嵌入维度、注意力机制中的序列维度等。JAX 允许你直接指定希望沿哪些维度进行切分，并定义这些维度到实际 TPU 设备的映射关系；随后，JAX 编译器便会自动将该描述编译为底层用于数据搬运的基本操作。这种方式比直接调用集合通信（collective communication）原语要高级得多。不过，我们仍坚持使用 PyTorch，因为它能让你清晰地看到底层实际发生的过程。但在真实场景中，显然你无需、也不应从零开始自行实现所有这些功能。好了，关于 JAX 的这段插叙就到此为止。简要总结一下：截至目前，我们已看到多种并行化方法；而每一种并行化方式，本质上都可理解为沿着某个维度对模型或数据进行切分——这个维度可能是数据（即批处理维度）、模型宽度、模型深度，抑或上下文长度。此外，我们还反复观察到一个共性主题：重计算（recomputation）。

## 段落 48

**英文**: You can, you can kind of recompute something from scratch or you can store in memory and suffer the data transfer cost. Or in now in the multi GPU, multi node setting, you can actually store on another GPU's memory and then, you know, communicate, which is even slower. So there's kind of these, these tradeoffs, you know, here. And, you know, often recomputation is actually, you know, can be, you know, better. But obviously you can't, you know, you can't compute the whole thing. And often you're either communication or memory limited. Final word is that it is the case that hardware is getting better. So you might think that, well, maybe none of this is really necessary because in five years everything will fit in, you know, L1, HBM. So this is not going to be the case because those might grow quite a bit, although there are still physical limits. We'll always be ending up with bigger models that sort of are at the limit of what the hardware can do.

**中文**: 你可以从头开始重新计算某些内容，也可以将其存储在内存中，但需承担数据传输的开销；而在当前多GPU、多节点的设置下，你甚至可以将数据存放在另一块GPU的显存中，再通过通信进行访问——而这甚至更慢。因此，这里存在一系列权衡取舍。通常情况下，重新计算实际上可能更优，但显然你无法重新计算全部内容；而且，你往往受限于通信带宽或内存容量。最后需要指出的是，硬件确实在不断进步。你或许会认为：既然五年后所有数据都能装入L1缓存或高带宽内存（HBM），那么上述优化可能就不再必要了。但事实并非如此，因为尽管这些硬件资源的增长幅度可能很大，物理极限依然存在；我们始终会构建出规模更大、恰好逼近硬件能力极限的模型。

## 段落 49

**英文**: So this hierarchical structure ever since system, computer systems was a thing has always been with us and it will always be there. Okay. That's all I have for you today. So I can take any questions. Yeah. So the question is in data parallel, you're saying that even though the parameters are all kind of synchronized, there could be other things that depend on the data like in batch norm. So I don't actually know how you, batch norms, oh, it's kind of annoying. So I don't know exactly how you would do that off the top of my head. I guess at least in the LLM world that doesn't really show up because layer norm is used. And as long as you initialize all the parameters and using the same random seed, you'll be fine.

**中文**: 因此，这种分层结构自计算机系统诞生以来就一直存在，并且将永远存在。好的，今天我就讲到这里。现在大家可以提问了。  
是的，这个问题是关于数据并行的：您提到，尽管参数是同步的，但仍可能存在其他依赖于数据的组件，例如批归一化（Batch Norm）。实际上，我并不清楚批归一化具体该如何处理——这确实有点麻烦。坦白说，我一时也想不出确切的解决方案。我想，在大语言模型（LLM）领域，这个问题基本不会出现，因为使用的是层归一化（Layer Norm）；只要所有参数均采用相同的随机种子进行初始化，就不会有问题。

## 段落 50

**英文**: I mean, there could be like non-determinism issues on the GPU, but hopefully those are minor. Yeah. Is this a way to do it in a way that PyTorch would go for something that they use in PyTorch? So the question is, does PyTorch have some niceties as well, kind of like what Jax offers? Is that? Yeah. So I mean, PyTorch does have the FSDP library, which you should absolutely use if you're not taking this class, which basically is a wrapper. You define any model and it just does FSDP on it. I think that now if you're asking how well it can more custom, allow you to more do custom charting, I think there are some things that are coming, but it's not as I think as developed. I mean, I think there's sort of this, I think, spectrum between the Jax world where you sort of declarely define things. And I think the Google infrastructure, if you stay within the Jax TPU system is pretty well developed. But then if you look at kind of DeepSeq, which is a kind of opposite end where you have these GPUs with actually really bad interconnect, which means that they have to go in and hack, they actually go to the kind of nickel level and actually do a bunch of things,. which I don't quite understand to eke out the performance.

**中文**: 我的意思是，GPU 上可能存在非确定性问题，但希望这些问题并不严重。是的。这是 PyTorch 所青睐的一种实现方式吗？换句话说，PyTorch 是否也提供类似 JAX 那样便捷易用的功能？是的。实际上，PyTorch 确实提供了 FSDP（完全分片数据并行）库；如果你不修这门课，那绝对应该使用它——它本质上是一个封装器：你只需定义任意模型，它便会自动为其应用 FSDP。不过，若你进一步追问其定制化能力——比如能否更灵活地进行自定义分片——目前虽有一些新功能正在开发中，但整体成熟度尚不及 JAX。我认为，这里存在一个光谱式的对比：在 JAX 世界中，你以声明式方式定义一切；而若你始终停留在 JAX + TPU 的 Google 基础设施内，其支持已相当完善。但反观 DeepSpeed 这类框架，则处于光谱的另一端：它们面向的是互连性能极差的 GPU 环境，因此不得不深入底层（甚至到“镍级”硬件层面），采取大量非常规手段来榨取极致性能——其中许多细节我本人也尚未完全理解。

## 段落 51

**英文**: Whereas if you're writing a Jax, you just kind of from on high declare your model and then stuff happens. So it's kind of the ways that you leverage hardware, I think really depends on what ecosystem you're operating in. Yeah. Is there a way to manage the amount of the activation of the activations so you can recompute some set of activations? Is there an API which you can manage? Yeah, so the question is activation checkpointing. There is an API that basically allows you to, I mean, I guess in PyTorch and Jax to specify which parts you want to recompute,. because clearly you don't want to recompute everything or nothing, probably every few layers, probably right after like big map malls where, for example, if you have, let's say, map mall and then point wise, a lot of neutrality, I don't think you need to store like two copies of, basically if you have two things where it's sort of trivial to get to, then you might as well just store one version. Yeah, over there. Do you think GPUs are going to be replaced by like transformer specific hardware or like more specialized hardware? So the question is, are GPUs going to ever be replaced by transformer specific hardware? So you've seen this in the inference space quite a bit already with like Grok and Cerebris have specialized hardware that can do inference and also, I guess, training, Cerebris training. So basically those hardware is essentially give you just a lot more on-chip memory. I mean, that's basically the name of the game.

**中文**: 而如果你使用JAX编写代码，你只需自上而下地声明模型，其余工作便会自动完成。因此，你如何利用硬件资源，在很大程度上取决于你所处的生态系统。  
是的。是否存在一种方法来管理激活值的数量，从而对某些激活值进行重计算？是否存在可供管理的API？  
是的，这个问题涉及的是“激活检查点（activation checkpointing）”技术。确实存在相应的API，基本允许你在PyTorch和JAX中指定需要重计算的部分——因为你显然既不想全部重计算，也不想完全不重计算；通常的做法是在每隔几层之后设置检查点，尤其适合在大型矩阵乘法（matmul）操作之后设置。例如，若某一层先执行矩阵乘法，再执行逐点运算（pointwise operation），而该逐点运算本身计算开销极小，则无需保存两份中间激活值；既然从一份激活值出发能轻易、快速地重新生成另一份，那仅保存一份就足够了。  
那边那位，请问：GPU未来是否会逐渐被专为Transformer设计的硬件，或更专用的硬件所取代？  
这个问题是：GPU最终会被专用于Transformer的硬件所取代吗？实际上，在推理领域，这类专用硬件已相当常见，例如Grok和Cerebras推出的硬件，既能高效执行推理，也能支持训练（Cerebras甚至宣称其硬件可支持训练）。本质上，这类硬件的核心优势在于提供了远超常规GPU的片上内存容量——而这恰恰是当前硬件竞争的关键所在。

## 段落 52

**英文**: I think Cerebris has like a huge, essentially effectively, L1 cache so you don't have to move things off. And I think a lot of simplifications can happen because GPUs were, there's a lot of baggage, actually, if you think about because they were divided in an era where you had to do a lot of branching and like, you know, various types of ad hoc computations which are not really needed in the deep learning regime. So I think there are quite a few opportunities to improve the hardware as well. I think there was a hand back there and I'll. I don't know if this is the right question but in the context of the lecture, it's basically a model that's been trained in Lungo that's been optimizing the server. So I'm sort of wondering if any of the techniques that we're talking about can be used to be compared to the training model, for example, as you get new training data, not just to like, whiten but actually to kind of recapitulate everything without having to recapitulate it. Yeah, so the question is, can these techniques be used to essentially do continued training? Yeah, absolutely. So if you think about the unit of what we're working on, it's just doing gradient steps, right? So if you take a half-trained checkpoint, you can just continue doing what this is. There's nothing specific about starting from scratch here. I think there was a question there.

**中文**: 我认为Cerebris本质上拥有一个巨大的L1缓存，因此无需将数据搬移出去。而且，由于GPU是在一个需要大量分支判断及各类临时性计算（而这些在深度学习场景中其实并不真正需要）的时代设计的，因此其架构上承载了诸多历史包袱；正因如此，许多简化是可能实现的。我认为硬件层面也存在相当多的优化机会。我看到后面有人举手了，我来……我不知道这是否是恰当的问题，但结合本次讲座的背景，问题实质上是：一个在Lungo中训练完成、并已用于优化服务器的模型——我想知道，我们目前讨论的这些技术能否用于与该训练模型进行对比？例如，当获得新的训练数据时，不仅可对其进行白化处理，还能在不从头开始的前提下，重新复现整个训练过程。  
是的，所以问题是：这些技术能否用于持续训练？  
是的，完全可以。因为从本质上讲，我们所做工作的基本单元就是执行梯度更新步骤，对吧？因此，如果你拿到一个训练到一半的检查点，就可以直接在此基础上继续执行这些步骤。这里并无任何必须从零开始的限制。我注意到那边似乎还有一个问题。

## 段落 53

**英文**: So, how might the models of state hardware, as you know, the previous question. Presumably, there is a physical, technical reason you can't make nodes much larger than they are currently. What's the change that you're talking about?. So if you could just make GPU nodes like as big as you wanted, people would do that. So presumably there's a type of hardware reason that's not possible. So what's the actual advancement being done to build the Rock-specific hardware you mentioned? Yeah, so the question is, there are physical limits for sure for a GPU. Let me just go. So you can't make GPUs infinitely large or infinitely dense. There's also power issues. You get rid of all the heat.

**中文**: 那么，关于您之前提到的国家硬件模型，情况如何呢？显然，目前无法将计算节点做得比现有尺寸大很多，这背后存在某种物理和技术上的原因。您刚才所指的“变化”具体是什么呢？也就是说，如果真能随心所欲地制造出任意大小的GPU节点，人们自然会这么做。因此，这种做法不可行，想必是受限于某种硬件层面的因素。那么，您之前提到的专为Rock定制的硬件，其实际的技术突破究竟体现在哪些方面呢？  
是的，这个问题问得很好：GPU确实存在明确的物理限制。我来具体说明一下——我们无法将GPU无限做大或无限提高集成度；此外，功耗问题也不容忽视，散热同样是一大难题。

## 段落 54

**英文**: And there's only so much bandwidth that can fit. So I don't know the exact details, but at least in some of the cerebrists' case, I mean they sort of have this way of manufacturing basically the chips so that the memory is kind of on the chip. So I guess it's just a way of putting it on there. And I think that there are obviously tradeoffs because it comes at a cost of not having as much flexibility. But in general, I think the way to maybe think about this more broadly is that GPUs were still developed in kind of the CPU era where it's much more control focused. I have code I'm executing. That's the sort of first class citizen. And then data needs to be moved to execute to handle the code. But the big difference with deep learning workloads is that it's all sort of data flow. Like the computation graph, if you look at these, it's like static.

**中文**: 而且带宽容量是有限的。因此，我并不清楚具体细节，但至少在某些“类脑芯片”（cerebrists）的设计中，他们采用了一种将内存直接集成到芯片上的制造方式。也就是说，内存被直接置于芯片之上。当然，这显然存在权衡取舍，因为这种设计会牺牲一定的灵活性。但总体而言，或许更广义地来看，GPU 仍是在以 CPU 为中心的时代开发出来的，其设计理念更侧重于控制：我有要执行的代码，代码才是首要核心；而数据则需要被移动过来，以配合代码的执行。但深度学习工作负载却大不相同——它本质上是一种数据流驱动的模式。例如，若观察其计算图，就会发现它是静态的。

## 段落 55

**英文**: You know from the beginning exactly all the computations that are going to be done until essentially the end of training. So using that knowledge, you should be able to kind of lay out your computation in a much smarter way than having to deal with the flexibility uncertainty over ad hoc computation. Okay, maybe a few more questions and I'll end there. Yeah. Is the computational graph usually stored in the CPU or in the GPU? So the question is where is the computation graph stored? Well, the code is all the I mean all this code is running on on on this CPU. But when you call something like the PyTorch function, it that needs to run on GPU, then it launches kernels under the hood and the kernels are code that runs on the GPU. Yeah, I'm not sure of that. So I guess maybe another answer is that the computation graph is more of a I guess a conceptual. You know, it's not like there is a graph literally that's being, you know, I mean, I guess there sort of is but it's it's it's it's not like the graph gets put on the GPU. That makes sense.

**中文**: 从一开始，你就确切地知道训练基本结束前将要执行的所有计算。因此，利用这一先验知识，你就能以比应对临时计算所带来的灵活性与不确定性更聪明的方式，来规划你的计算流程。好的，也许再回答几个问题，我就到此为止了。  
是的。计算图通常存储在CPU上还是GPU上？  
这个问题是问计算图存储在哪里？嗯，所有这些代码本身都是在CPU上运行的。但当你调用类似PyTorch的函数且该函数需在GPU上运行时，它会在后台启动内核（kernels），而这些内核是实际在GPU上运行的代码。  
是的，我不太确定这一点。所以，或许另一种回答是：计算图更多是一种概念性的存在——你知道，它并非一个字面意义上的、实实在在被显式构建并存储的图；当然，某种意义上它确实存在，但它并不会被整体“搬”到GPU上。这很有道理。

## 段落 56

**英文**: Okay. So these communication primitives that we have like in the same instance of the CPU instructions or like how do you use the program? So the question is the communication primitives, are they CPU or GPU? So these collective operations are in some sense abstract specification of what types of operations need to happen, which can happen if you remember this PyTorch distributed has different back ends. So it could happen on GPU or happen on CPU. But where do you get the CPU? Is it like is the CPU sort of scheduling them or is it like for them to try? Yeah, so well the CPU sort of drives basically is the sort of the master still. And then when you do a collective operation, it calls the nickel library, which launches which is, you know, it's still CPU and then it launches some kernels that move data around. Okay, maybe this is a good place to end. All right, I will see you next Monday.

**中文**: 好的。那么，我们所拥有的这些通信原语——比如在同一CPU实例中的指令，或者程序该如何使用？问题在于：这些通信原语是运行在CPU上还是GPU上？从某种意义上说，这些集合通信操作只是对所需执行操作类型的抽象定义；正如您所知，PyTorch分布式支持不同的后端，因此这些操作既可在GPU上执行，也可在CPU上执行。但这里的CPU从何而来？是CPU负责调度这些操作，还是仅尝试执行它们？是的，CPU本质上仍起主导作用，即作为主控节点。当执行集合通信操作时，它会调用NCCL库（该库本身运行在CPU上），然后由NCCL启动若干内核来完成数据传输。好的，或许就此结束比较合适。好的，下周一见。

---

*共 56 个段落，557 句话*
