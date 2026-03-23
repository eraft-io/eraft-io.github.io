# Lecture 7： Parallelism 1

生成时间: 2026-03-23 23:13:14

---

## 段落 1

**英文**: So today's going to be the second of the basic systems lectures. And now we're going to move on to sort of multi-machine optimization. And so the focus today is going to be all about parallelism across machines. And so the goal today is going to move from optimizing a single GPU's throughput to being able to understand the complexities and the details that are required to train really large models. And model when models get large, they no longer fit on a single GPU. So you've got to split up your models across different machines. But also you've got to be able to leverage all the different servers that you have in order to train these models quickly. So we've got both compute and memory concerns that we're going to have to deal with. And communication across different machines, it's going to be quite heterogeneous. We have different kinds of communication across GPUs at different levels of hierarchy.

**中文**: 所以今天将是基础系统讲座的第二部分。现在我们将转向多机优化的内容。今天的重点将完全围绕跨机器的并行处理。因此，今天的目标是从优化单个GPU的吞吐量，转向理解训练真正大型模型所需的复杂性和细节。当模型变得庞大时，它们无法再容纳在单个GPU上。因此，必须将模型拆分到不同的机器上。同时，还需要能够利用所有不同的服务器来快速训练这些模型。所以，我们将不得不处理计算和内存两方面的问题。不同机器之间的通信将非常异构，因为GPU之间在不同层次上存在多种类型的通信。

## 段落 2

**英文**: And so this is going to lead to different parallelization paradigms. People use many different parallelization strategies all together at once. And we're going to talk through each one of the very popular ones. And then we'll talk about how you combine them together in order to efficiently train a very large model. And then I'm going to end the lecture with sort of looking at some examples of how people are actually using these parallelization strategies to run their large-scale distributed training runs. And so that's going to roughly map to the different parts of this lecture. We're just going to talk about the basics of networking first. And then we're going to talk about how do each of these sort of networking hardware concepts. map to different parallelization strategies. And then finally, some case studies to close off with to show you how it all comes together.

**中文**: 因此，这将催生不同的并行化范式。人们会同时运用多种并行化策略。我们将逐一探讨其中几种非常流行的策略，然后讨论如何将它们结合起来，以高效训练一个超大型模型。最后，我将通过一些实际案例来结束本次讲座，展示人们如何运用这些并行化策略进行大规模分布式训练。这大致对应本次讲座的各个部分。首先，我们将讨论网络基础知识，接着探讨这些网络硬件概念如何映射到不同的并行化策略。最后，通过一些案例研究来收尾，向大家展示这一切是如何融会贯通的。

## 段落 3

**英文**: So I told you about GPU scaling last week. And it's quite impressive seeing this super exponential curve of flops per GPU going way, way up. But if we want to rapidly scale out both our compute and memory, a single GPU isn't enough. We're going to have to wait for another couple of years for this curve to continue going upwards and upwards and upwards. So if we want to train a really powerful language model here and now today, well, we have to rely on multi-machine parallelism. So if we look at the world's fastest supercomputers, that's what's being shown on the right here, the fastest supercomputers have exoflops and exoflops of compute. Those are kind of the green lines that you see over there. That's what you're really going to have to rely on if you're going to try to train the biggest, baddest language models today. And so that's the compute side of why you want to think about multi-machine parallelism. So we've also got a memory angle for thinking about the same thing.

**中文**: 上周我跟你聊了GPU缩放的事。看到每块GPU的浮点运算能力呈超指数级飙升，确实令人震撼。但如果我们想同时快速扩展计算能力和内存，单靠一块GPU是远远不够的。我们还得再等上好几年，这条增长曲线才能持续向上攀升。所以，如果我们想当下就训练出真正强大的语言模型，就必须依赖多机并行计算。看看全球最快的超级计算机——右边展示的这些，它们的计算能力已达到百亿亿次级别。那边显示的绿色线条就代表了这种水平。要想训练当今最庞大、最顶尖的语言模型，这确实是你必须仰仗的力量。这就是从计算角度考虑多机并行的原因。当然，我们还得从内存的角度来思考同样的问题。

## 段落 4

**英文**: So these two are really the core resources and the core concerns that you're going to have to think about. So in terms of memory, many of the models are getting quite big. And of course, memory on GPU is also growing, but not quite as quickly. And a single GPU is not going to be able to fit these models. Maybe eventually in the distant future, we won't have to worry about a lot of these. But we've got billions and billions of parameters. They're not going to fit very nicely into a single GPU. So we have to be very respectful of the memory constraints that we have. So those are kind of the realities that we have to deal with. And what are kind of the tools that we have to be able to handle these? Well, GPUs, I'm sure you've noticed in the class cluster, don't come in sort of single tens, right? A single machine will have multiple GPUs within the same sort of physical rack.

**中文**: 因此，这两者确实是您必须思考的核心资源和核心关切。就内存而言，许多模型正变得相当庞大。当然，GPU的内存也在增长，但速度远不及模型。单个GPU将无法容纳这些模型。也许在遥远的未来，我们无需再为这些问题担忧。但目前我们拥有数十亿甚至更多的参数，它们无法很好地适配到单个GPU中。因此，我们必须非常尊重现有的内存限制。这些就是我们不得不面对的现实。那么，我们有哪些工具可以应对这些挑战呢？GPU，我相信你们在课堂集群中已经注意到，它们并非以单个形式出现，对吧？一台机器会在同一个物理机架内配备多个GPU。

## 段落 5

**英文**: And so here's an example. I took this, I think, from the GPT NeoX paper. This is an old example, but the same lesson applies to the H100 machines that you have in class. So here, there's eight different GPUs. They're connected to the various CPUs through fast interconnects. Within each GPUs, you see this envy switch thing at the bottom. This is very, very fast connections across these GPUs. But if these GPUs want to talk to GPUs on a different machine, they're going to have. to go through a networking switch. And you see this purple line.

**中文**: 这里有一个例子，我想这是从GPT NeoX论文中摘取的。虽然是个旧例子，但其中的道理同样适用于你们课堂上使用的H100机器。这里展示了八块不同的GPU，它们通过高速互联与各个CPU相连。在每块GPU内部，底部可以看到这种Envy交换器结构——这是GPU之间极高速的连接通道。但如果这些GPU需要与其他机器上的GPU通信，就必须经过网络交换机。图中这条紫色线路就代表了这种连接。

## 段落 6

**英文**: This is HDR in finiband. So that's a much slower connection compared to the envy link connection. You can see the difference in the throughput. That's about eight times slower per lane. And so this kind of hardware hierarchy that we have is going to have big implications for how we're going to end up paralyzing our models in practice. And so you can keep this mental model with you as I talk through these things. We have very, very fast connections within a single machine. And then when we go across machines, it's going to get slower. And then depending on the kind of hardware we're using, there might even be another level of slowness once we go beyond, let's say, 256 GPUs network together. Many of you may already know this, having taken systems or networking classes.

**中文**: 这是InfiniBand上的HDR技术。因此，与NVLink连接相比，这是一种速度慢得多的连接方式。你可以从吞吐量上看出差异——每条通道的速度大约慢了八倍。我们现有的这种硬件层级结构，将对我们最终在实际中如何并行化模型产生重大影响。在我讲解这些内容时，你可以带着这个思维模型来理解：在单台机器内部，我们拥有非常非常高速的连接；而当我们跨越多台机器时，速度就会变慢。根据所使用的硬件类型，一旦我们超越（比如说）256个GPU组成的网络，甚至可能出现另一个级别的速度下降。你们中许多人可能已经通过系统或网络课程了解这一点了。

## 段落 7

**英文**: But here is a very, very brief refresher on collective communication operations. And the reason why I'm going to bring this up is there is one particular important sort. of identity or equivalence that you will kind of need to know to really understand some of the finer points of the performance characteristics of the parallelization algorithms. So I'll talk through these. And then I'll talk through one important sort of performance implication. So the first one, which all of you probably have heard of, is all reduced. So you have four machines, four ranks in this case. Each one having its own sort of piece of data. And what you'd like to do is a performance of reduction operation. Let's say I want to sum all these inputs.

**中文**: 但这里要非常简要地回顾一下集体通信操作。我之所以提到这一点，是因为有一个特别重要的身份或等价关系，你需要了解它才能真正理解并行化算法性能特性的某些细节。因此，我将逐一讲解这些内容，然后讨论一个重要的性能影响。首先，你们可能都听说过的是“全局归约”。假设有四台机器（即四个进程），每个进程拥有自己的数据片段。我们需要执行归约操作——比如我想对所有输入进行求和。

## 段落 8

**英文**: And then I want the output to be copied over to every single machine. And this is going to have roughly the cost of two times the total number of things that you're all reducing. You have a broadcast operation. And here I'm taking a single input from rank two. And I'd like to copy it out to all of the remaining ranks. And this is going to have roughly on the order of one times the total number of outputs. in terms of the communication costs. And then we've got reduction where we got different inputs. And that's going to be summed up in the sent only to one machine. And then the two that are quite important, even though these may not be quite as common, is going to be the all-gathering scatter.

**中文**: 然后，我希望输出能被复制到每一台机器上。这大概会产生两倍于你们正在规约的所有数据总量的成本。这里有一个广播操作。我正从第二号进程获取单一输入，并希望将其复制到所有其他进程。这大概会产生相当于输出总数一倍左右的通信成本。接着是规约操作，我们有不同的输入数据，它们将被汇总并仅发送到一台机器。然后是两个相当重要的操作，尽管它们可能不那么常见，那就是全收集和散播。

## 段落 9

**英文**: So all-gather is an operation where I'm taking a single subcomponent of my parameters from rank zero. And I'm copying it over to all the ranks. Same thing with rank one, two, three. So each of these are handling different parts of let's say the parameters. And they're copied over to the rest of the machines. So that's copying what I have to everyone else. And the reduced scatter, which is I'm taking each of the rows, let's say, I'm summing them up. And then I'm sending the result only to rank zero. So this is a partial version of an all-reduce. And hopefully this diagram makes it clear how reduced scatter works.

**中文**: 因此，全收集操作是指我从零号进程获取参数的一个子组件，并将其复制到所有其他进程。一号、二号、三号进程也是如此。每个进程处理参数的不同部分，并将这些部分复制到其他机器上。这就是将我拥有的内容复制给其他所有进程。而规约散播操作则是指，例如，我取每一行数据，将它们求和，然后将结果仅发送给零号进程。这是全规约操作的一个部分版本。希望这张图能清楚地展示规约散播的工作原理。

## 段落 10

**英文**: And so all gather and reduced scatter are quite important. Because in some sense, they are the primitive by which many of the parallelization algorithms are going to be built. And so this is kind of an important sort of equivalence or an identity I will refer to it one or two times as sort of key points in this lecture. If you want to do an all-reduce, let's say I've got different GPUs, ABCD. And each of the GPUs are handling a different data point. And so I've got different gradients for each of these data points. And I'm going to need to sum those gradients and then I need to pass all those gradients back to the GPUs. This is a classic data parallel operation that I might need to do across my four GPUs. So that would be an all-reduce. One important thing though is this could be replaced with two operations.

**中文**: 因此，全体聚集和归约分散操作至关重要。因为在某种意义上，它们是构建许多并行化算法的基础构件。这可以说是一种重要的等价关系或恒等式，我将在本次讲座中多次提及，视其为关键点之一。假设我有不同的GPU，分别标记为A、B、C、D。每个GPU处理不同的数据点，因此每个数据点对应不同的梯度。我需要将这些梯度求和，然后将所有梯度传回各个GPU。这是一个典型的数据并行操作，可能需要在四个GPU之间执行。这就是所谓的全体归约操作。但需注意一个重要细节：这一操作可以通过两个步骤来实现。

## 段落 11

**英文**: A reduced scatter and an all-gather. Where a reduced scatter is going to sum sort of each of the rows and then leave the result. of the rows and let's say GPU zero, one, two, three respectively. And then I'm going to do an all-gather to sort of copy those back out to the remaining GPUs. So each GPU now is getting a full sum of a part of the parameters and then it's going to copy it back to the remaining workers. And in the bandwidth-limited regime, this is basically the best that you can do, right? All-reduce, the best that you can do is roughly matching the bandwidth that you can get out of a reduced scatter and all-gather. And you can convince yourself this by writing out how many sort of communication operations happen in both all-reduce and the right-hand side. The final thing that I want to sort of briefly touch on before I sort of move on to talking about the parallelization algorithms. And this is like the one place I'll talk about GPU versus GPU. Most of the discussion today can actually abstract out the underlying hardware.

**中文**: 一次规约分散和一次全收集。规约分散会对每一行进行求和，然后将结果分别保留在GPU零、一、二、三上。接着，我会进行一次全收集，将这些结果复制回其他GPU。这样，每个GPU现在都获得了参数某一部分的完整求和结果，并将其复制回其余工作节点。在带宽受限的情况下，这基本上就是你能做到的最佳方案，对吧？对于全规约操作，你能达到的最佳效果大致与规约分散加全收集所能获得的带宽相当。你可以通过计算全规约和右侧方案中各有多少通信操作来验证这一点。在我继续讨论并行化算法之前，我想简单提一下最后一点。这也是我唯一会谈到GPU与GPU差异的地方。今天的大部分讨论实际上可以抽象掉底层硬件细节。

## 段落 12

**英文**: But there is actually sort of one important thing that I'll mention up front so that I can refer to it later as I talk through this. How do we network together different machines or different sort of accelerators in sort of GPUs? As I showed you in the GPT-neoX slide here, how in the GPU world this generally works is you've got nodes, single machines that contain, let's say, eight GPUs. And then you've got these switches that connect fairly quickly to each other. And these machines are connected all to all up to about 256 GPUs. So that's an important threshold up until which you have very fast arbitrary communication between machines. And then above that, you're actually going to need sort of much more slow communication. These sort of leaf switches and spine switches once you go beyond sort of roughly a single rack's worth of GPU. On the other hand, if you look at sort of TPU design from Google, they actually take a very different approach to networking sort of their machines. You've got a single sort of TPU chip and they all talk to their neighbors very, very quickly. And so this is a very sort of easily expandable what they call Toroid-O-Mesh, but you can only talk to your neighbors.

**中文**: 但事实上，有一个重要的事情我想先提一下，以便在后续讨论中能够引用。我们如何将不同的机器或不同类型的GPU加速器连接在一起呢？正如我在GPT-neoX的幻灯片中展示的，在GPU世界中，通常的做法是：你有一些节点，即单个机器，每个机器包含大约八个GPU。然后，这些机器通过交换机快速相互连接。这些机器之间可以实现全互联，最多支持约256个GPU。这是一个重要的阈值，在这个范围内，机器之间可以实现非常快速的任意通信。而超过这个数量，通信速度就会变得慢得多。一旦你超过大约一个机架的GPU数量，就需要使用叶交换机和脊交换机这样的设备。另一方面，如果你看看谷歌的TPU设计，他们在机器网络方面采取了非常不同的方法。他们有一个TPU芯片，所有芯片都能与邻居进行非常快速的通信。因此，这是一种他们称之为环形网格的、非常易于扩展的设计，但你只能与邻居通信。

## 段落 13

**英文**: And the reason why I'm talking about this right after the all-reduced slide is if you think about doing these kinds of collective communications like all-reduced or reduced scatter, you can implement them just as efficiently on a Toroid-O-Mesh, then you can on an all-to-all connection. And so if you're optimizing purely for collective communications, it makes sense to think about things like TPU networking rather than GPU networking. And we'll talk a little bit about pros and cons of this later as I go through different parallelization operations. So, okay. So just to put this together, right, now we're going to start talking about a new unit of sort of compute, right? Instead of the GPU, the new unit is the data center. The whole data center is going to be the thing that we're going to be doing. And now we're going to try to come up with algorithms and sort of sharding strategies that get us two different things. The first one is linear memory scaling. So as I scale up the number of GPUs, the sort of biggest model that I can train is going to scale linearly with that, right? So I can train bigger and bigger models if I really want to, right? I also want linear compute scale, right? As I get more and more GPUs, the useful computation that I'm doing to train the model scales linearly, right? And then finally, a lot of this, these algorithms are going to be implemented by just calling these very simple collective communications primitives in various ways. And so when we think about the performance characteristics of these parallel algorithms, it suffices the reason about basically counting the collective communications primitives.

**中文**: 我在全归约幻灯片之后立即讨论这个的原因是，如果你考虑执行全归约或归约散射这类集体通信操作，在环面-网格拓扑上实现它们的效率完全可以媲美全连接网络。因此，如果纯粹为集体通信进行优化，考虑TPU网络而非GPU网络就很有意义。稍后讨论不同并行化操作时，我会进一步分析这种方式的利弊。那么，现在我们需要开始将整个数据中心视为一个新的计算单元——不再以单个GPU为单位，而是以整个数据中心为单位进行算法设计。接下来我们要探索的算法与分片策略需要实现两个目标：首先是线性内存扩展，即随着GPU数量增加，可训练的最大模型规模能线性增长；其次是线性计算扩展，确保增加GPU时用于训练模型的有效计算量也线性提升。最终，这些算法将通过灵活调用简单的集体通信原语来实现。因此，在评估并行算法性能时，本质上只需分析这些集体通信原语的调用次数即可。

## 段落 14

**英文**: So that's kind of an important way to think about these. We don't go all the way down to the low level implementation of these algorithms here. Okay, any questions? Part one, yes. Sorry, after that, but from the previous slide, it's indeed that's better to do your scatter from the small gather rather than the algorithm. Right, so this slide, right? Yeah. So the conclusion of this slide is that they're equivalent, right? And I think if you think about something like parallel doing gradient descent and parallel, all reduce to the very natural operation to do, because you'll scatter your, sorry, you'll distribute your data to different machines, and then you'll have to all reduce your gradients together, right? But what I'm saying is this very natural thing to do of all reduce can actually be written. as a sum of two different operations in their equivalents. So there's no performance sort of hit by going from this left representation to this right one, at least in bandwidth. And that's going to have important implications in maybe like five slides. So you can wait a little bit to see why I mentioned this.

**中文**: 因此，这是一种思考这些问题的重要方式。我们在这里不会深入探讨这些算法的底层实现。好的，有什么问题吗？第一部分，是的。抱歉，在那之后，但从上一张幻灯片来看，确实从小规模收集进行分散比算法更好。对吧，所以是这张幻灯片，对吗？是的。所以这张幻灯片的结论是它们是等价的，对吧？我认为，如果你考虑像并行执行梯度下降和并行操作，全部归约是非常自然的操作，因为你会将数据分发到不同的机器上，然后必须将所有梯度一起归约，对吧？但我想说的是，这种非常自然的全部归约操作实际上可以写成两种不同操作的和，它们是等价的。所以，从这个左边的表示转到右边的表示，至少在带宽上不会造成性能损失。这可能在大约五张幻灯片后会有重要的影响。所以你可以稍等一下，看看我为什么提到这一点。

## 段落 15

**英文**: Okay. Any other questions? Good. Okay. So now we're going to get started. In some sense, this is kind of the exciting algorithmic meat of the lecture. And there's three kinds of parallelism, you know, strategies, parallelism, things that we should really be thinking about. So the first one is data parallelism. So data parallelism at a high level is the idea of, I'm in a roughly copy the parameters across my different GPUs. I'm not going to worry about splitting my parameters up, but I will take my batch and I will split my batch up in different GPUs or different machines, we'll get different slices of my batch. So that's data parallelism.

**中文**: 好的。还有其他问题吗？很好。那么我们现在开始。从某种意义上说，这算是本次讲座中激动人心的算法核心内容。有三种并行策略，或者说，是我们真正应该考虑的并行处理方式。第一种是数据并行。数据并行，概括来说，其核心思想是：我在不同的GPU上大致复制相同的参数。我不打算操心如何分割参数，但我会将我的批次数据分割到不同的GPU或不同的机器上，从而获得批次数据的不同切片。这就是数据并行。

## 段落 16

**英文**: There's lots of subtleties in how we execute that. Model parallelism now is starting to say, okay, I don't want all my GPUs to have all the different parts of my model, right? As my models get bigger, that's going to be a very big problem. So I need to cut up my model in very clever ways. And I need my GPU to handle different parts of my model, right? So that's going to be model parallelism. And then the final piece is kind of activation parallelism. We don't really think too much about activations in our day to day lives because the pie-torch handles it very transparently, right? But as the models get bigger and the sequence lengths get longer, the activation memory starts to be a really big problem. So if you want to train these really big models with big batch sizes, you have to somehow manage the memory footprint of your activations. And so we have to split those up too. So there's some ways to handle that, right? And when we put all these together, we will have all the tools we need in order to scale up both compute and memory gracefully as we have lots and lots of machines. So these are kind of the core conceptual objects.

**中文**: 我们在具体执行中有许多精妙之处。模型并行现在开始提出：我不希望所有GPU都承载模型的全部不同部分，对吧？随着模型规模扩大，这会成为一个非常严重的问题。因此我需要用非常巧妙的方式拆分模型，让不同GPU处理模型的不同部分，这就是模型并行的核心。最后一块是激活值并行——我们日常工作中通常不太关注激活值，因为PyTorch已经非常透明地处理了这些，但随着模型规模扩大和序列长度增加，激活值内存开始成为真正的大问题。如果想要用大批量训练这些超大规模模型，就必须设法管理激活值的内存占用，因此我们也需要拆分激活值。目前已有一些处理方法，当我们把这些技术结合起来，就能获得所需的所有工具，从而在拥有大量机器时优雅地扩展计算能力和内存容量。这些就是核心概念框架。

## 段落 17

**英文**: And now we're going to talk about implementing each of these ideas efficiently. So the starting point of data parallelism is just sort of SGD, right? If we're doing very naive batch, sarcastic gradient descent, the formula for doing this looks like this equation that I have right here on the slide right here. I'm taking a batch size capital B, and I'm going to sum up all those gradients, and I'm going to update my parameters, right? So naive data parallelism is just saying, all right, take your batch size B, split that up, and send that to different machines. Each machine will compute some part of the sum, and then I will exchange all of my gradients. together to synchronize, you know, after each sort of, before each gradients step, I will synchronize my gradients, and then I will take a parameter update, right? So now I've been talking to you about compute and memory scaling and all these things. So let's just talk through, you know, what it looks like for each of these, right? So for compute scaling, data parallelism is pretty great. Each machine, each GPU is going to get B over M examples. And if my batch size is big enough, you know, each GPU is going to get a pretty decent batch size, micro batch size, and it's able to hopefully saturate its compute. Okay, so that's good. What's the communication overhead? Well, I'm going to have to transmit twice the number of my parameters every batch.

**中文**: 现在我们要讨论如何高效地实现这些想法。数据并行化的起点其实就是随机梯度下降（SGD），对吧？如果我们采用非常朴素的批量梯度下降法，其公式就像我幻灯片上展示的这个方程一样。我取一个批量大小B，将所有梯度求和，然后更新我的参数，对吗？朴素的数据并行化就是说，将批量大小B拆分，发送到不同的机器上。每台机器计算求和的一部分，然后在每次梯度步骤之前，我会交换所有梯度以进行同步，接着再更新参数。我一直在和你们讨论计算和内存扩展等问题。那么，让我们逐一看看这些方面的情况吧。对于计算扩展来说，数据并行化非常出色。每台机器、每个GPU将获得B除以M个样本。如果我的批量足够大，每个GPU都能获得相当不错的批量大小（微批量大小），并有望充分利用其计算能力。这很好。那么通信开销呢？每批数据中，我需要传输两倍于参数数量的数据。

## 段落 18

**英文**: Remember, an all-reduce is going to roughly be twice the amount of stuff that you're all reducing in terms of communication costs. And so this is okay if the batch size is big, right? If my batch sizes are really big, I can mask the communication overhead of having to synchronize my gradients every now and then. Every scaling, I'm not touching this at all, right? Every GPU needs to replicate the number of parameters and needs to replicate the optimizer state. It's pretty bad for memory scaling, right? So if we didn't have to worry about, you know, memory at all, this is a okay strategy. But I think impractice memory is a problem, right? Like I think everyone of you sitting here has experienced, you know, trying to put a big model onto a GPU and PyTorch telling you all you're out of memory. And this is, you know, really a problem with your training as well because if you can fit, you know, more and more batch sizes, that's going to make the data parallel more efficient. And so ideally, you'd like to save on memory. So let's take a closer look at the memory usage of naive data parallel, right? And the memory situation is actually worse than it looks. It's actually quite terrible. Because you've done this in assignment one, but we can sort of think about how many copies of our model we need to sort of store.

**中文**: 记住，全归约操作在通信成本上大约是你所归约数据量的两倍。所以，如果批量大小很大，这是可以接受的，对吧？如果我的批量非常大，我可以掩盖时不时同步梯度带来的通信开销。每次扩展，我完全不会碰这个，对吧？每个GPU都需要复制参数数量，并复制优化器状态。这对内存扩展来说相当糟糕，对吧？因此，如果我们完全不必担心内存，这是一个可行的策略。但我想在实践中，内存确实是个问题，对吧？我想在座的每个人都经历过试图将一个大模型放到GPU上，而PyTorch却提示内存不足的情况。这实际上也是训练中的一个问题，因为如果你能容纳越来越大的批量大小，数据并行就会变得更高效。所以理想情况下，我们希望节省内存。那么，让我们仔细看看朴素数据并行的内存使用情况，对吧？实际上，内存情况比看起来更糟，甚至相当糟糕。因为你们在第一次作业中已经做过这个，但我们可以思考一下我们需要存储多少个模型副本。

## 段落 19

**英文**: And it's very large, right? Depending on the precision by which we're doing some of our training, you're going to need to store something like 16 bytes of data per parameter. And in fact, need to store something like five copies of your weights. And this is really quite bad because if you just want to think about your model parameters, technically, you only need two bytes, right? So where did that factor of eight come from? Well, at least you need gradients. And if you're computing your gradients in BF16, that's another two bytes. But then your optimizer state kind of shows up, and that's a really big problem. Because you've got four bytes of sort of master weights, the things that you're kind of accumulating into SGD, like these intermediate sort of sums that you're doing. You need four or two bytes for Adam's first moment estimates. Because remember, Adam keeps track of historical gradients. And then Adam also needs second moment estimates, kind of like the variance of the gradients that you've gotten in the past. And that's going to need another four or two bytes.

**中文**: 它非常庞大，对吧？根据我们训练时采用的精度，每个参数大约需要存储16字节的数据。实际上，你可能需要存储大约五份权重副本。这确实相当糟糕，因为如果只考虑模型参数本身，理论上只需要2字节就够了。那么这八倍的差距从何而来？至少你需要存储梯度。如果用BF16格式计算梯度，这又需要2字节。但随后优化器状态的出现成了大问题——你需要4字节存储主权重（即SGD中累积的中间求和值），还需要4或2字节存储Adam优化器的第一矩估计（记录历史梯度），此外Adam还需要第二矩估计（类似过去梯度的方差），这又需要额外的4或2字节。

## 段落 20

**英文**: And so what originally looked fine is actually now looking quite grim. And so the 16X, if I just sort of draw it as a picture, you realize that most of your memory usage, at least in terms of kind of parameter memory, is really being dominated by the optimizer states of your Adam optimizer, right? So your memory consumed is going to be a function of how many bytes are being used for your optimizer state. And that's generally going to be even more than the core parameter and gradient memory usage. And so for a simple example of a 7. 5B model, distributed over 64 accelerators, you're using a ton of memory, right? And this memory scales linearly upwards, total memory, at least, scales linearly upwards with the number of GPUs. So that's no good at all. But if once we sort of look at this picture, we get some very simple ideas. You might wonder clearly, or maybe not clearly, I need the parameters and gradients to be copied across devices. That seems necessary to do data parallel. But do I really need all the optimizer states to be on every single machine, right? And once you ask that question, you can maybe get to the second row here.

**中文**: 因此，原本看似良好的情况实际上现在显得相当严峻。所以，如果我将16X画成一张图，你会发现大部分内存使用，至少在参数内存方面，实际上是被Adam优化器的优化器状态所主导的，对吧？因此，你的内存消耗将是优化器状态所占字节数的函数。而这通常甚至超过了核心参数和梯度内存的使用。举一个简单的例子，对于一个7.5B的模型，分布在64个加速器上，你使用了大量的内存，对吧？而且这种内存，至少总内存，会随着GPU数量的增加而线性增长。这显然一点都不好。但一旦我们审视这张图，就会得到一些非常简单的想法。你可能会清楚地，或者不那么清楚地，想知道参数和梯度是否需要跨设备复制。这似乎是数据并行所必需的。但我真的需要所有优化器状态都在每台机器上吗？一旦你提出这个问题，你或许就能理解这里的第二行了。

## 段落 21

**英文**: And this is going to be called optimizer state sharding. And if we could do that, then at least in this case, we can go from 120 gigabytes of total memory usage down to 31. 4. And then maybe we can start sharding the gradients. And then now we can get to 16. 6 gigabytes of memory usage. And then if we also shard the parameters, we can go all the way down to 1. 9 gigabytes of memory usage. And that would be a pretty good place to be, because now we sort of fully sharded out all of the optimizer state and parameter and gradient memory that we need. Yes.

**中文**: 而这将被称为优化器状态分片。如果我们能做到这一点，那么至少在这种情况下，我们可以将总内存使用量从120GB降至31.4GB。接着，或许我们可以开始对梯度进行分片。这样，内存使用量就能进一步降至16.6GB。然后，如果连参数也进行分片，我们甚至能将内存使用量一路降至1.9GB。这将是一个非常理想的状态，因为此时我们已基本将所需的优化器状态、参数和梯度内存全部分片处理完毕。是的。

## 段落 22

**英文**: So I want to be sure that the optimizer state is like, if we're doing, I guess the free communication on each of them, the scan, like, frequency, that's right. That is a very good question. And the question is, how can we shard the optimizer state? You know, when we're doing data parallel, right? GPU zero has to be responsible for data point one. So clearly it needs to know about all the parameters and update it. So how can it possibly shard the optimizer state? And in a way, I think zero, which is what this is. This is the zero overhead data parallel sort of optimizer. This is a very, in some ways, clever idea, because it shows you that even when you're. doing data parallel, you don't actually need to copy everything onto every machine, right? You can be really clever about how you do sort of communications to avoid all of this. So I will talk through exactly this. This is a great question.

**中文**: 所以我想确认优化器状态的情况，比如我们是否在每个设备上进行自由通信，扫描频率，没错。这是个很好的问题。问题是，我们如何分片优化器状态？当我们进行数据并行时，GPU零需要负责第一个数据点，显然它需要了解所有参数并进行更新。那么它怎么可能分片优化器状态呢？从某种程度上说，我认为零优化器（即这里提到的）解决了这个问题。这是一种零开销数据并行的优化器，在某些方面是个非常巧妙的想法，因为它表明即使在进行数据并行时，你实际上也不需要把所有数据复制到每台机器上，对吧？你可以通过巧妙的通信方式来避免这一切。接下来我会详细讲解这一点。这确实是个很棒的问题。

## 段落 23

**英文**: So what we're going to do is we're going to split up the optimizer states, as I said. So the first and second moments are now split up across all of the GPUs. But everyone has the parameters and the gradients, right?. So why is this important? If I have the parameters and gradients, let's say I'm GPU zero, I have the parameters and gradients for everything, that's enough information for me to compute the full gradient, right? Like the full gradient update for this example can be computed. The only thing I can't do is I can't take that gradient and take an atom step, right? I can't update my parameters unless I see all of the optimizer states, right? So that's kind of the key idea. And so now what's going to happen is GPU zero is going to compute the gradients for everything. But GPU zero is now only responsible for updating the parameters for the shard that they own, right? And that's kind of the key idea, right? We're going to distribute the work of updating the parameters and then we're going to synchronize the parameters back. So let me show you in sort of much more gory detail how this works and sort of the reason why it's called zero overhead. So step one, right? Every GPU gets a different data point, let's say, right? I'm just going to simplify all this batch computation. I have GPU zero through, let's say four.

**中文**: 那么我们要做的就是，正如我所说，将优化器状态分割开来。这样，第一和第二阶矩现在就被分散到所有的GPU上了。但每个GPU都拥有参数和梯度，对吧？那么这为什么重要呢？如果我有参数和梯度，假设我是GPU零，我拥有所有参数和梯度，这足以让我计算完整的梯度，对吧？比如在这个例子中，完整的梯度更新是可以计算的。唯一我不能做的是，我不能拿着那个梯度并执行一个原子步骤，对吧？除非我看到所有的优化器状态，否则我无法更新我的参数，对吧？所以这差不多就是关键思想。那么接下来会发生的是，GPU零将计算所有内容的梯度。但GPU零现在只负责更新它所拥有的分片参数，对吧？这差不多就是核心思想，对吧？我们将分配更新参数的工作，然后同步回参数。让我更详细地展示一下这是如何工作的，以及为什么它被称为零开销。第一步，对吧？每个GPU获得不同的数据点，假设是这样，对吧？我将简化所有这些批量计算。我有GPU零到，比如说，四。

## 段落 24

**英文**: And every GPU gets a single example and they compute a full gradient on the example that they own. Now what I'm going to do next is I'm going to reduce scatter the gradients, right? So I'm going to send the gradients that, you know, I'm going to collect in some sense. the gradients that each GPU owns. So GPU zero, let's say, is responsible for this first quarter of the parameters, right? So the parameters are the y axis here and the x axis here is GPUs. And so what we're going to do is we're going to reduce scatter to make sure that GPU zero has all of the gradient information from all the other GPUs for the subset of parameters that it is responsible for, right? So now it gets this gradient information from GPU one and GPU two and GPU three. And that's all reduced into GPU zero. Hopefully that's clear. Now now GPU zero has all the information it needs to update its own parameters because it has the optimizer state corresponding to this first part. It has a full summed gradient for this first part. And now so it's going to take a gradient update on their part of the parameters using gradient and state, right? And so that now I have the full updated parameters for this subset in my GPU zero and all I need to do is all gather all of the parameter updated parameters back in to all the ranks.

**中文**: 每个GPU都获得一个样本，并在其拥有的样本上计算完整的梯度。接下来我要做的是对梯度进行归约分散操作，对吧？也就是说，我会以某种方式收集每个GPU拥有的梯度。比如GPU 0负责参数的前四分之一部分——这里的纵轴代表参数，横轴代表GPU。我们将通过归约分散操作，确保GPU 0获得所有其他GPU对其负责参数子集的梯度信息。这样它就能从GPU 1、GPU 2和GPU 3收集梯度信息，全部归约到GPU 0中。希望这样解释清楚。现在GPU 0拥有了更新自身参数所需的全部信息：它拥有对应第一部分参数的优化器状态，以及该部分完整的聚合梯度。接下来它将利用梯度和状态对其负责的参数部分执行梯度更新。这样GPU 0中就完成了该参数子集的完整更新，最后只需通过全收集操作将所有更新后的参数同步到所有计算节点。

## 段落 25

**英文**: Okay, so there's many questions here. I'll start here. Yes. So the question was whether the number of pranks communication cost was per machine or its total. Here it's going to be total because so this is going to be like one fourth of the parameter is going to be sent three times to this machine and then you repeat that four times. That was also total. Yeah, two times number of parameters is total because each block is going to have to be sent to every other kind of machine. Okay, yes. So this question is not unique to what you're showing here, but I need to think of it. So that out of the optimizer we showed seems to assume large, largely assume independence of parameters.

**中文**: 好的，这里有很多问题。我从这里开始。是的。问题是恶作剧通信成本是每台机器的还是总计的。这里将是总计，因为大约四分之一的参数将被发送三次到这台机器，然后你重复四次。那也是总计。是的，参数数量的两倍是总计，因为每个块都必须发送到其他每台机器。好的，是的。所以这个问题并非你这里展示的内容所独有，但我需要考虑一下。我们展示的优化器似乎很大程度上假设了参数的独立性。

## 段落 26

**英文**: But we've drawn all these like diagrams that show the opposite. You know, like we have connected nodes and all that and it seems especially crazy when. we have and we're trying to split these and update them separately. Is that creating any issue? Okay, so the question was Adam W seems to assume parameters operate independently. I'm assuming because you're saying like we track like gradient sums like and then we diagonally sort of update the parameters, right? We know that that's not fully diagonal and so is there a problem. There has been better attempts at improving sort of Adam W to not just be diagonal. There's things like KFAC and all these other like second order style optimizers that people. have come up with. They haven't dethroned Adam even though they do have their advantages and there's some really interesting things that you can do with these kinds of improved second order pre-conditioning methods. Yes.

**中文**: 但我们绘制了所有这些显示相反情况的图表。你知道，就像我们拥有相互连接的节点等等，这在我们试图拆分并分别更新它们时显得尤为疯狂。这会造成任何问题吗？好的，问题是亚当W似乎假设参数是独立运作的。我这么认为是因为你说我们跟踪梯度总和，然后以类似对角线的方式更新参数，对吧？我们知道那并非完全是对角线操作，那么是否存在问题呢？确实有更好的尝试来改进亚当W，使其不仅仅是对角线更新。比如KFAC以及人们提出的其他类似二阶风格的优化器。尽管它们确实有其优势，并且通过这些改进的二阶预处理方法可以实现一些非常有趣的功能，但它们尚未取代亚当的地位。是的。

## 段落 27

**英文**: What is the rows that we're reducing over? So you're asking like what is the rows of this picture? Yeah. Yeah, so imagine this is like parameters here in the rows. So like GPU zero is responsible for some number of parameters. So this is a block of parameters up top. And so when we do reduce scatter, we're saying take the gradients for example zero for this block of parameters. Take the gradients for example one for this same block of parameters and then say, sum them all and put them in rank zero. That's kind of what we're saying here. Cool. Okay. And kind of the key thing here is we're doing a reduce scatter in an all gather, right? And if you kind of remember what I was saying before, well a reduced scatter in an all gather has the same cost as an all reduce, right? And so there is a little bit of a surprising magic thing that happened here which is that, well, we were doing an all reduce before on all the gradients to make sure everyone's gradients were synchronized and that cost us two times the number of parameters.

**中文**: 我们是在哪些行上进行归约的？你是在问这张图片的行代表什么吗？是的。想象一下，这里的行就像是参数。比如GPU 0负责一部分参数，顶部这一块就是参数块。当我们进行归约分散操作时，意思是：以这个参数块为例，取样本0的梯度，再取样本1的梯度（针对同一参数块），然后将它们全部求和，结果放到排名0的设备上。这就是我们这里表达的意思。很好。关键点在于，我们是在一次全收集操作中进行归约分散，对吧？如果你还记得我之前说的，一次全收集中的归约分散与全归约操作成本相同。所以这里发生了一个有点令人惊讶的巧妙之处：之前我们对所有梯度进行全归约以确保所有设备的梯度同步，那需要消耗两倍参数量的通信成本。

## 段落 28

**英文**: But if we're kind of clever about how we're doing the updates, well, we can do a reduced scatter in an all gather. And in between the two steps, we can do some computation. And that gives us the same amount of compute communication cost. But now at least for the optimizer state, we fully sharded the optimizer state across the model. So the row stage one is in some sense free in the bandwidth limited regime and gives you memory wins. Yes. So, what do you mean by you can suppress the higher order contributions? Right. For first and second moments, the amount of memory is probably per GPU is divided by the number of GPUs. Yes. So it seems like you can use a lot of shuffling more than moments in this moment.

**中文**: 但如果我们能巧妙处理更新方式，就能在全体收集操作中实现简化的分散传输。在这两个步骤之间，我们还能进行一些计算。这样既保持了相同的计算通信成本，又至少在优化器状态层面实现了跨模型的完全分片。因此，在带宽受限的场景下，第一阶段的行操作某种意义上可以视为零成本，同时还能节省内存。没错。那么您说的"抑制高阶贡献"具体指什么？对于一阶和二阶矩，每个GPU所需的内存大概会除以GPU总数。是的，看来当前阶段可以大量运用数据重排策略，其重要性甚至可能超过矩计算本身。

## 段落 29

**英文**: I see. So you're roughly saying like you could track way more optimizer state to rephrase what you're saying. You could have even more complicated optimizer state because you can divide that by the number of GPUs. While this is true, what we're going to do next is we're actually going to make the other component scale with NGPUs. So that's going to make things in some sense not free anymore, right? Like, optimizer state will continue to be the bottleneck if we can divide everything by. the number of GPUs. So hopefully that's a reasonable convincing answer. Okay. So we're going to build up stage by stage to zero stage three, which is more complicated. Zero stage two is still relatively simple.

**中文**: 我明白了。所以你的大致意思是，你可以追踪更多的优化器状态来重新表述你的观点。你可以拥有更复杂的优化器状态，因为你可以将其除以GPU的数量。虽然这是事实，但我们接下来要做的是让另一个组件随着GPU数量的增加而扩展。所以从某种意义上说，这就不再是免费的了，对吧？如果我们能把所有东西都除以GPU的数量，优化器状态将继续成为瓶颈。希望这是一个合理且有说服力的答案。好的，所以我们将逐步构建到第三阶段，这会更复杂。第二阶段仍然相对简单。

## 段落 30

**英文**: So now, hopefully that optimizer state-sharing trick made sense. I think that's very cool. So now, we want to shard even more stuff. So I want to shard the gradients across the machines. So roughly, we can do the same kinds of trick as stage one, but there is one additional complexity. And so what's the additional complexity? Well, you know, we can never instantiate a full gradient vector, right? If I ever do the full backwards pass and I try to compute a full gradient vector, I might go out of memory, right? So I want my maximum memory usage to basically be bounded by this, which is like full parameters,. sharded gradient, sharded optimizer state. And so what we're going to have to do is when we do the backwards pass, as we're computing the gradient vector, we can't instantiate the full gradient first and then do communication. What we have to do is, as we compute the gradients backwards, as soon as we compute like a layers worth of gradient, we're going to have to send that over to the corresponding sort of GPU that it belongs to, right? So this is kind of how it works. It's roughly the same idea, right?.

**中文**: 所以现在，希望那个优化器状态共享的技巧讲清楚了。我觉得这非常酷。那么现在，我们想要分片更多的东西。我想在机器之间分片梯度。大致上，我们可以采用与第一阶段相同的技巧，但这里有一个额外的复杂性。那么，这个额外的复杂性是什么呢？嗯，你知道，我们永远无法实例化一个完整的梯度向量，对吧？如果我进行完整的反向传播并尝试计算完整的梯度向量，我可能会耗尽内存，对吧？所以我希望我的最大内存使用量基本上受限于这个，也就是完整的参数、分片的梯度、分片的优化器状态。因此，我们必须做的是，在进行反向传播时，当我们计算梯度向量时，我们不能先实例化完整的梯度再进行通信。我们必须做的是，在反向计算梯度的过程中，一旦我们计算出一个层的梯度，我们就必须将其发送到它所属的相应GPU上，对吧？所以大致就是这样运作的。基本上是一样的思路，对吧？

## 段落 31

**英文**: So now, everyone has their own batch component. Everyone incrementally goes backwards on the computation graph. And let's say we're going to operate layer by layer, right? So layers are sharded, you know, atomically to different GPUs. So what we're going to do then is, as we go backwards on the computation graph, after we compute a layer's gradients, immediately call a reduction operation to send this to the right worker, right? So a layer belongs to some worker, maybe it's like GPU number two in this case. So we're just going to immediately reduce that, send that to the worker at that point. And gradients are now no longer needed. You know, I don't need to store the gradients on ranks 0, 1, and 3, so I can immediately free that. And then now we continue this process. And so all the machines have their fully updated gradients. And now they have a full gradient for their share of the parameters.

**中文**: 现在，每个人都拥有自己的批次组件。大家沿着计算图逐步反向计算。假设我们要逐层操作，对吧？也就是说，各层被原子性地分片到不同的GPU上。那么接下来我们要做的就是，在沿着计算图反向计算时，每计算完一层的梯度，就立即调用归约操作，将其发送给对应的工作节点，对吧？每一层都属于某个工作节点，比如在这个例子中可能属于GPU二号。所以我们会立即进行归约，将梯度发送给那个节点。此时梯度就不再需要了。你看，我不需要在0、1、3号节点上存储这些梯度，因此可以立即释放它们。然后我们继续这个过程。这样，所有机器都获得了完全更新的梯度。现在，它们对自己负责的参数部分拥有了完整的梯度。

## 段落 32

**英文**: They have a full optimizer state for their share of the parameters. Each machine can update their parameters. And it all gather the parameters back together, right? This looks like it's maybe more communication because you're doing this kind of like reduction operation every layer, but this is only for a small amount of parameters, right? It's charted. And so the full communication remains the same. So 0 stage two has some more overhead because we have to synchronize layer by layer and make sure that the gradients are properly sent to the right workers, but the overhead. is pretty minimal, right? It's still very simple, fairly straightforward. Now the last one of these 0 stage three is more complicated for sure, but it allows you to do the greatest win of all, which is now essentially everything is divided by the number of GPUs that you have. You can get the maximum savings possible. And if you've heard of FSDP, right, you've probably used that in some aspect of your life in the past, FSDP is exactly 0 stage three. So now you'll kind of hopefully today know how FSDP works.

**中文**: 它们拥有自己那部分参数的完整优化器状态。每台机器都可以更新自己的参数，然后再将所有参数汇集起来，对吧？这看起来可能需要更多通信，因为每一层都要进行这种归约操作，但这只涉及少量参数，对吧？这是有规划的。因此总体通信量保持不变。所以零阶段二会有一些额外开销，因为我们需要逐层同步，确保梯度正确发送到对应工作节点，但这些开销其实非常小，对吧？整个流程仍然非常简单直观。至于零阶段三，它确实更复杂，但能带来最大的收益——现在所有内容基本上都能按GPU数量进行分摊。你可以实现最大程度的节省。如果你听说过FSDP，可能以前在某些场景中使用过它，FSDP本质上就是零阶段三。希望今天大家能由此了解FSDP的工作原理。

## 段落 33

**英文**: So the same idea applies. We're going to shard everything including the parameters. We're going to do the same thing as 0 stage two, which is we're going to incrementally communicate and compute things so that we don't keep these big vectors of gradients lying around. And we're going to send in request parameters on demand while we're going stepping through the compute graph, both for the forward and backward passes, as we go through, we're. going to send things around on demand. And of course, the key is to do this with as low overhead as possible. I think the thing that's really surprising about FSDP is not that this is possible, but that this is possible with relatively low overhead. You'll see kind of why it's low overhead in the next slide. I admit that this is maybe not the most friendly graphic to start with, but this is, I promised the baby version of FSDP. The next slide is a little bit more involved.

**中文**: 因此，同样的理念也适用。我们将对所有内容进行分片，包括参数。我们将采用与第二阶段零相同的方法，即逐步进行通信和计算，以避免保留这些庞大的梯度向量。在遍历计算图的过程中，无论是前向传播还是反向传播，我们都将按需发送请求参数。当然，关键在于尽可能降低开销。我认为FSDP真正令人惊讶之处不在于其可行性，而在于它能够以相对较低的开销实现。在下一张幻灯片中，您将看到为何它的开销较低。我承认这或许不是最易于理解的图示作为开头，但正如我所承诺的，这是FSDP的简化版本。下一张幻灯片会稍微复杂一些。

## 段落 34

**英文**: But conceptually, this actually explains everything. So what we're doing is, you know, we're going to have model weights and we're going to be all gathering the model weights as we go. So for each layer, you know, no single GPU is going to have all the parameters, right? So I can't do the normal thing of saying, oh, GPU zero, go ahead and run to forward pass. That's not possible. So GPU zero, let's say, is, let's say it only owns, you know, the bottom most layer. So it does that computation and then it stops and says it requests all of the parameters. from all the other workers. So it stops and it does all gather, which is right here. You see, there's a all gather step. It gathers all the parameters.

**中文**: 但从概念上讲，这实际上解释了一切。我们正在做的是，我们将拥有模型权重，并且随着进程推进，我们会逐步收集所有模型权重。对于每一层，没有任何单个GPU会拥有全部参数，对吧？所以我不能像通常那样说，哦，GPU零，你去执行前向传播。那是不可能的。假设GPU零只拥有最底层，那么它完成该计算后就会停止，并请求所有其他工作节点的参数。于是它暂停，执行一次全局收集操作，就是这里看到的。你看，这里有一个全局收集步骤，它收集所有参数。

## 段落 35

**英文**: Now it has the parameters that it needs to do a forward. So it can step forward and sort of compute the layer that it didn't have before. And then now it can free the weights. It doesn't need the weights anymore. Get rid of it. Now I can all gather the next layer. I can do another forward, free the weights. And I can repeat this, right? The activations have to be stored. So the activation memory here is growing, right? So that's going to be an eventual problem. But if we ignore activations for the moment, this is great because I load a layer, I do.

**中文**: 现在它已具备执行前向传播所需的参数。因此它可以向前推进，并计算之前缺失的层。随后它便可以释放权重——这些权重已不再需要，可以清除。接着我能收集下一层，再次执行前向传播并释放权重。这个过程可以循环进行，对吧？但激活值必须被保存，因此这里的激活内存会不断增长，这最终会成为一个问题。不过如果我们暂时忽略激活值，这种方式非常理想：我加载一层，执行计算，然后释放。

## 段落 36

**英文**: a forward, I free it. The memory overhead is very low here. Once I get to the end, now I can do the same thing with the backward pass, right? I can call backwards. And every time I move backwards through the neural network, I all gather for the parameters that I need. I can do a reduced scatter to update after the gradients that have been computed. And now I can free the weights. I can free both the gradients that I don't need and the parameters. And at the very end, I've got a fully updated model. And so we've got three different operations that we've got to worry about here. We've got an all gather.

**中文**: 向前传播时，我释放它。这里的内存开销非常低。一旦到达终点，我就可以对反向传播做同样的事情，对吧？我可以调用反向传播。每次我在神经网络中向后移动时，我会收集所需的参数。我可以通过归约分散操作在梯度计算完成后进行更新。现在我可以释放权重了。我可以释放不再需要的梯度和参数。最后，我得到了一个完全更新后的模型。因此，我们需要关注三种不同的操作。我们有一个全收集操作。

## 段落 37

**英文**: We've got another all gather. And then we've got another reduced scatter basically to update the model after we take the gradient updates step. So conceptually, this is just a single step beyond zero stage two. But you do kind of see that there is sort of more overhead. So the total communication cost is now higher, right? We were kind of before we had two times the number of parameters. Everything was kind of free in some sense. Now it's not, right? There's total three times the number of parameter communication costs. And there's going to be cost associated with waiting for these communication things to finish. But I think the really cool thing about FSDP is it's actually surprisingly low overhead. You might imagine that because we're doing this crazy thing of asking for and sending parameters back and forth all the time that things will be really slow, right? Like we have to be communicating all the time.

**中文**: 我们又进行了一次全收集操作，接着在完成梯度更新步骤后，我们基本上又进行了一次规约分散操作来更新模型。所以从概念上讲，这仅仅是零阶段二之后的一步。但你确实会看到存在更多的开销。因此，总的通信成本现在更高了，对吧？以前我们大概是参数数量的两倍。在某种意义上，一切都是免费的。但现在不是了，对吧？总的参数通信成本变成了三倍。而且等待这些通信操作完成也会产生成本。但我认为FSDP真正酷的地方在于它的开销实际上低得惊人。你可能会想，因为我们一直在做这种疯狂的事情，不断地请求和发送参数，所以速度会很慢，对吧？就像我们必须一直在通信一样。

## 段落 38

**英文**: But you can do this core idea of overlapping communication and computation. So you want both your sort of, you want your GPU to be working while the communication is happening in the background, almost like prefetching so that by the time you need some piece of information, it's already loaded up. It's already been communicated to you and you're good to go. So I'll talk through this example at the bottom here. But this is kind of the key to making FSDP actually somewhat efficient. So let's imagine we have a computation graph that looks something like this. W1, W0 plus W2, W0 times X. Some input, let's say is Y, right? So some very simple computation graph like this. And then you might run FSDP and you will get actually computation and communication that. looks like this block diagram at the very end here.

**中文**: 但你可以实现这种通信与计算重叠的核心思想。也就是说，你希望GPU在后台进行通信的同时也能持续工作，这类似于预取机制——当你需要某些信息时，它们早已加载就绪，传输完成，随时可用。我会用底部的例子具体说明，而这正是让FSDP真正实现高效的关键所在。假设我们有一个计算图，结构如下：W1、W0加上W2、W0乘以X，输入设为Y。就是这样一个非常简单的计算图。当你运行FSDP时，实际的计算和通信流程会呈现为最下方这样的框图。

## 段落 39

**英文**: So the CPU, it's nice that we did the end site systems example last week because hopefully this diagram will now be clear. The CPU is going to basically dispatch a bunch of commands asking the communication part of the GPU to basically go and fetch some parameters. It's going to dispatch things to the GPU to say, okay, all right, do some matrix multiplies. And it's going to run far ahead in some sense of the GPU. We've seen this when we were looking at the profiler last week. Now let's look at the sequence of both communication and computation that happens on device now. Remember that I need to sort of gather things on demand. So at the very beginning, I have to make sure that everyone has the weights for layer 0 or W0 here. So I do all gather 0 and I'm going to wait for that to complete. And once that's completed, I can do a forward step on W0.

**中文**: 所以，CPU方面，我们上周做的端侧系统示例很有帮助，希望现在这个图表能一目了然。CPU基本上会派发一系列指令，要求GPU的通信部分去获取一些参数。它会向GPU发送任务，比如执行矩阵乘法。从某种意义上说，CPU的运行会远远领先于GPU。我们上周查看性能分析器时已经看到了这一点。现在，让我们看看设备上发生的通信和计算序列。记住，我需要按需收集数据。因此，一开始我必须确保所有设备都拥有第0层（即这里的W0）的权重。所以我执行all gather 0操作，并等待其完成。一旦完成，我就可以在W0上执行前向传播步骤。

## 段落 40

**英文**: I can sort of compute x times W0, let's say, right? At this point, all gather once starts at the same time that all gather 0 ends. So as I'm doing this matrix multiply, I'm basically already starting to load the next parameters that I need. Of course, my communication is slower and so there is some gap, but I end much quicker than sort of the initial load. So now forward one can happen and in the background once again, I've started to load parameter number two. Because yellow slice here, I'm now freeing the parameters associated with forward one. And then now the other thing here is I'm repeating computation. W0 is used twice. And so I don't need to communicate this again. This happens very quickly and I can sort of do this very quickly. I have forward two now already loaded before I needed it.

**中文**: 我大概可以计算x乘以W0，对吧？此时，所有节点第一次聚合开始的时间正好是第零次聚合结束的时间。所以，在我进行这个矩阵乘法的时候，基本上我已经开始加载下一个需要的参数了。当然，我的通信速度较慢，所以会有一些间隙，但我完成的速度比最初的加载要快得多。现在，前向传播一可以开始，而在后台，我又一次开始加载第二个参数。因为这里的黄色部分，我现在释放了与前向传播一相关的参数。然后，这里的另一件事是我在重复计算。W0被使用了两次。所以我不需要再次通信这个参数。这发生得非常快，我大概可以很快完成这个操作。现在，在我需要之前，前向传播二所需的参数已经加载好了。

## 段落 41

**英文**: And so there's no bubble here and then I can free number two. That's the entirety of the forward pass. And you see that the gaps are relatively small here. And we were able to do a lot of loads before the compute needed to happen. And so by doing this very clever thing of kind of queuing the requests for weights before you actually need them, you can avoid a lot of the overhead associated with communication. And then now at this point of four or two, I'm done with the forward pass. I can free weight number two and I start on the backward pass. And you see that all gather two for the backward pass is already done. And so I can start on backward two, backward zero, weight zero is already stored. So that's done.

**中文**: 因此这里没有气泡，然后我可以释放二号权重。这就是前向传播的全部过程。你会看到这里的间隙相对较小。在计算需要发生之前，我们能够进行大量加载。通过这种在真正需要权重之前巧妙地将请求排队的方式，可以避免许多与通信相关的开销。现在到了四或二这个阶段，我已经完成了前向传播。我可以释放二号权重，并开始进行反向传播。你会看到反向传播的第二次全收集已经完成。这样我就可以开始进行第二次反向传播，第零次反向传播，零号权重已经存储好了。所以这部分也完成了。

## 段落 42

**英文**: And then the high overhead here happens in the backward pass because I need to do reduced. scatters and in all gathers and so on and so forth. I hopefully you see this picture and you say, wow, it's kind of surprising that even though we're doing this crazy sharding, right? Like if you go back to this picture, we fully sharded the parameters, gradients and optimizer states. But the total bandwidth that we need is only three times rather than two times. And so the actual bubbles that we see are not horrendous, right? The communication is almost being fully being utilized and the computation is installing for. very long. So we're actually making pretty efficient use of the resources that we do have, which is cool. Okay, yes. Where does the weights get? Like the three passes to two. It's stuck to my understanding that like let's do the GPU and that brings it to cool.

**中文**: 然后，这里的高开销发生在反向传播过程中，因为我需要进行规约散射和全收集等操作。希望你们看到这个图示后会感叹：哇，尽管我们进行了如此复杂的分片处理，这结果还挺让人惊讶的，对吧？回顾这张图，我们虽然对参数、梯度和优化器状态进行了完全分片，但所需的总带宽只是原来的三倍而非两倍。因此我们实际看到的通信间隙并不算糟糕，对吧？通信链路几乎被完全利用，而计算过程也能持续运行很长时间。这说明我们实际上相当高效地利用了现有资源，这很棒。好的，没错。权重数据具体是怎么处理的？关于三阶段变两阶段的问题——根据我的理解，就像我们为GPU设计的方案那样，这最终让整个系统运行得很顺畅。

## 段落 43

**英文**: Where does the weights get? Three passes to two. Yeah, so you need a buffer room which you can store the weights. And so you know, this picture is not quite right. Like you will have some overhead that you need associated with reading these weights for the current layer. And also the other big elephant in the room is I haven't talked at all about activation. That's going to be like a big chunk because you've got a big set of activations for full model that are sort of living here in some sense. Yeah, cool. Right, okay. So this is kind of distributed data parallel. Like zero is in some ways the way that people do distributed data parallel efficiently.

**中文**: 权重从哪里来？三次传递变为两次。是的，所以你需要一个缓冲空间来存储权重。你看，这张图并不完全准确。比如，你需要一些开销来读取当前层的权重。另外，房间里的大象是，我还没提到激活值。那将是一大块，因为整个模型有一大组激活值在某种意义上存在于此。是的，好的。那么，这有点像是分布式数据并行。比如，在某些方面，零（Zero）是人们高效进行分布式数据并行的方式。

## 段落 44

**英文**: And so there's different stages. And you know, stage one is it's basically free, right? It's doing the same communication pattern as naive data parallel, but you get the shardier optimizer state. That's great. You might as well always do it, right? Zero stage two is twice the number of parameters. So the total bandwidth consumption is the same. But there is additional overhead in having to do this like incremental freeing of the gradients as you go backwards. Zero stage three is more involved. You do three times number of parameter communication costs, but it's not so bad, right? Like we did have some overhead in the diagram that we saw before. But if you really cleverly mask your communication patterns, it's actually pretty good. And so people use data parallel even for fairly slow sort of links in your networking pattern.

**中文**: 所以有不同的阶段。第一阶段基本上是免费的，对吧？它采用与朴素数据并行相同的通信模式，但你可以获得更分散的优化器状态。这很棒。你完全可以一直这样做，对吧？第二阶段是参数数量的两倍。所以总带宽消耗是一样的。但在反向传播过程中，必须逐步释放梯度，这会带来额外的开销。第三阶段则更为复杂。你需要承担三倍的参数通信成本，但这并不算太糟，对吧？就像我们之前看到的图表中确实有一些开销。但如果你能巧妙地掩盖通信模式，效果其实相当不错。因此，即使在网络连接速度较慢的情况下，人们仍然会使用数据并行。

## 段落 45

**英文**: Okay. So it's also conceptually very simple. One of the advantages here is, you know, especially data parallel doesn't care too much about the architecture, right? I didn't talk at all about how we actually implement a transformer in any of this. It's all very abstracted. And so this is one of the reasons why, for example, FSDP is so popular, it's very easy to write a wrapper that paralyzes sort of arbitrary neural networks without having deep knowledge or deep introspection of what the architecture is actually doing. And so, you know, here's some examples. I worked out some examples because I'm always sort of running out of memory on my GPUs. And you can kind of see what's the maximum size of the model that I can fit on a eight times a 180 gig node. And so for baseline, you might end up with like, oh, I can fit barely six billion parameter. model.

**中文**: 好的。所以它在概念上也非常简单。这里的优势之一在于，特别是数据并行并不太关心架构，对吧？我完全没有讨论我们如何在实际中实现一个Transformer模型。这一切都非常抽象。因此，这也是为什么FSDP如此受欢迎的原因之一，编写一个能够并行化任意神经网络的包装器非常容易，无需深入了解或深入分析架构的具体运作。那么，这里有一些例子。我整理了一些示例，因为我总是遇到GPU内存不足的情况。你可以大致看到，在一个8x180GB的节点上，我能运行的最大模型规模是多少。以基线为例，你可能最终会发现，我勉强能运行一个60亿参数的模型。

## 段落 46

**英文**: Whereas I think if I use zero stage three, you know, I'm able to fit something like a 50 billion parameter model. There's big savings in my ability to fit larger and larger models by doing things like FSDP to cleverly save on memory. So okay. Oh, sorry. There's a question. Yes. I guess in the long veer, where the difference is that once you share the parameters, what's the difference from that in the model? Yeah. So model parallelism is really fundamentally about making sure that the parameters just like live in separate, let me see if I can find. Yeah. Yeah.

**中文**: 然而，我认为如果采用零阶段三策略，就能训练一个大约500亿参数的模型。通过使用FSDP等技术巧妙地节省内存，我能够显著提升训练更大模型的能力。好的。哦，抱歉，有个问题。是的。我想从长远来看，关键在于参数共享后，模型内部的实际差异是什么？没错。模型并行的本质在于确保参数分布在不同的——让我想想怎么解释。对，就是这样。

## 段落 47

**英文**: Yeah. Yeah. So in some ways, it's true that we have started the parameters. So you could call this a kind of parallelism. But the whole point of model parallelism is to make sure that the parameters just live entirely in one machine. We're not going to like try to ship them across in various ways. Only the activations are going to get shipped across. And so you'll see very different discussions in the model parallelism section. But the focus there will be on communicating activations rather than communicating parameters. And that will be a big difference.

**中文**: 是的，是的。所以在某些方面，我们确实已经开始了参数的分配。你可以称这为一种并行化。但模型并行的核心在于确保参数完全存储在一台机器中，我们不会尝试以各种方式在机器间传输参数，只有激活值会被传输。因此，在模型并行部分你会看到完全不同的讨论，重点将放在激活值的通信上，而非参数的通信。这将是一个很大的区别。

## 段落 48

**英文**: Yes. Why are you coming in all together? So you're asking about this step. Like why are we doing all gather to gather weights onto all the machines? Is that when they're only on one machine?. Is that right? Yeah. We need to basically put, we need to take the weights that live on one machine and scatter or is it gather or scatter? Sorry. I want to make sure I get this right. The terminology is a little bit sketchy for me. So I want to make sure I get, sorry. Yeah. So what we want to do is the same as this.

**中文**: 是的。你们怎么都一起进来了？所以你们是在问这一步。比如我们为什么要进行全收集来把权重集中到所有机器上？是不是因为权重原本只在一台机器上？是这样吗？对。我们基本上需要把那些只存在于一台机器上的权重进行分发——等等，是收集还是分发来着？抱歉，我想确认一下术语，这方面我有点不太确定。所以我想确认清楚，不好意思。嗯，我们想做的其实和这个是一样的。

## 段落 49

**英文**: So each machine is going to have some parameter that I want to gather across all the machines. In order to make sure that each layer is sort of properly sort of replicated across all the GPUs. Is that the right question that you're asking? Or are you saying like, is there a simpler primitive that we could have been both? Like are you saying broadcast is the right object rather than all gathered?. I think maybe it's written that way because of some exceptions about layers not living on individual GPUs, but I'm not 100% sure. I agree with you that broadcast should be able to do the same thing if the parameters live on only one machine. Okay. Cool. Alrighty. Okay. Let me make sure.

**中文**: 因此，每台机器都会有我想要在所有机器上收集的某个参数。这是为了确保每一层都能在所有GPU上得到适当的复制。你问的是这个问题吗？还是说，有没有一种更简单的原语可以同时满足两者？比如，广播是不是比全收集更合适的操作？我想，之所以这样写，可能是因为有些层并不单独存在于某个GPU上，但我不完全确定。我同意你的看法，如果参数只存在于一台机器上，广播应该也能达到同样的效果。好的。明白了。行。让我确认一下。

## 段落 50

**英文**: Okay. Got it. Okay. Right. So there is a key resource in data parallel. And this is actually an important idea that I want you to remember. The data parallel batch size is actually a really critical resource. In the sense that you can't paralyze greater than your batch size, right? Because you can have a most one example on each machine. You can't go to fractional examples per machine. And so this means that, you know, there are, if there's limits to your batch size, right? You stop being able to use data parallel.

**中文**: 好的。明白了。好的。对。所以数据并行中有一个关键资源。这实际上是一个我希望你记住的重要观点。数据并行中的批次大小确实是一个非常关键的资源。从某种意义上说，你的并行度不能超过批次大小，对吧？因为每台机器上最多只能有一个样本。你无法让每台机器处理少于一个样本。这意味着，如果你的批次大小有限制，你就无法再使用数据并行了。

## 段落 51

**英文**: And there's diminishing returns to batch sizes. So in your assignment, one, you may have played with varying batch sizes. But you kind of know that as you crank up the batch size past a certain point, you start. to see sort of fairly rapid diminishing returns to your optimization rates. And there's lots of papers written on this. OpenAI has a really nice one on something called critical batch sizes where they basically argue that past a certain point, you have very rapid diminishing returns in how much each example is contributing to your ability to optimize. Like basically the intuition is that below a certain point, you have a lot of gradient noise and reducing that is very valuable. But at a certain point, you're really fundamentally limited by the number of gradient steps you're. taking rather than variance reduction. And so that basically means data parallel alone isn't going to get you to arbitrarily large parallelism.

**中文**: 而且批量大小存在收益递减现象。在你的任务中，你可能尝试过调整批量大小。但你应该知道，当批量大小超过某个临界点后，优化速度就会开始出现相当明显的收益递减。关于这个课题已有大量研究论文。OpenAI曾发表过一篇关于“临界批量大小”的出色论文，其中指出：超过某个界限后，每个样本对优化能力的贡献就会急剧减弱。直观理解是：在临界点以下，梯度噪声较大，降低噪声很有价值；但超过临界点后，优化效果根本上受限于梯度更新次数，而非方差缩减。这意味着单纯的数据并行无法实现无限大的并行扩展。

## 段落 52

**英文**: And this batch size thing is a really important resource, right? You want to, essentially, you have a fixed maximum batch size and you can spend it in different ways. And I'll talk about that later because other kinds of parallelism also benefit from having sort of bigger batches. And so you use your batch size in certain parts. Okay. And issues are going to remain with data parallel. Zero stages one and two don't let you scale memory. Zero stage three is nice in principle, but it can be slow. And maybe more importantly, and this relates to the earlier question, it does not reduce activation memory, right? I ideally want to like cut up my model entirely and make them live totally separately because. then the activation memory would also sort of be reduced. And so now I want better ways to split up the model so I can fit these really big models in these GPUs.

**中文**: 而批量大小这个参数确实是一种非常重要的资源，对吧？本质上，你需要设定一个固定的最大批量大小，并可以以不同方式分配使用。这一点我稍后会详细讨论，因为其他类型的并行处理方式也能从较大的批量中获益。因此，你会在某些部分使用特定的批量大小。好的。数据并行仍然存在一些问题。Zero阶段一和阶段二无法扩展内存。Zero阶段三在理论上很不错，但实际运行可能较慢。更重要的是——这也与之前的问题相关——它并不能减少激活内存，对吧？理想情况下，我希望能够完全拆分我的模型，让各部分完全独立运行，因为这样激活内存也会相应减少。所以现在我需要更好的模型分割方法，以便将这些超大型模型适配到这些GPU中。

## 段落 53

**英文**: And so that's going to bring us to model parallelism. We want to scale up the memory without changing the batch size. And we want an alternative axis where we don't need to spend or basically have big batch sizes in order to paralyze. And so what we're going to do is it's going to split up the parameters across GPUs and. in some ways that's like zero three. But we're not going to communicate parameters anymore. We're going to pass activations around and that's going to be different. And sometimes activations are going to be much smaller than parameters and that'll be very good for us. So we'll cover two different types of parallelism. I'm going to talk about pipeline parallel, which is conceptually simpler, but much more horrible implementation wise.

**中文**: 因此，这将引导我们进入模型并行领域。我们希望在不改变批处理大小的情况下扩展内存。我们需要一个替代的维度，在这个维度上，我们不需要为了并行化而耗费大量资源或使用大批处理量。所以，我们将要做的是把参数分散到多个GPU上。在某种程度上，这类似于零三方法。但我们不再进行参数通信，而是传递激活值，这将有所不同。有时，激活值比参数小得多，这对我们非常有利。我们将介绍两种不同类型的并行方式。我将讨论管道并行，它在概念上更简单，但在实现上却要棘手得多。

## 段落 54

**英文**: And tensor parallel, which is conceptually maybe less obvious, but honestly much nicer to implement and more commonly used. And they're going to correspond to two different ways of cutting up the model. So I think pipeline parallel is maybe the most obvious way to cut up a neural network. You know that a deep neural network comes in layers. So if I have layers, a very natural place to cut a network is to cut it up at the layer boundaries. And so each GPU is going to handle some subset of the layers. And I'm going to pass activations around. Like in this case, each layer belongs to a GPU. And GPUs are going to pass activations from one to the other. And in the backwards case, it's going to pass the backwards gradients, backwards from GPU three to zero.

**中文**: 张量并行在概念上可能不那么直观，但实现起来其实更简洁，也更常用。这两种方式对应着模型切分的不同思路。我认为流水线并行可能是分割神经网络最直观的方法。我们知道深度神经网络由多个层级组成，因此如果模型有很多层，最自然的切分点就是层与层之间的边界。这样每个GPU负责处理一部分层级，并通过传递激活值来协作——比如在这个例子中，每个GPU专属负责某些层，前向传播时GPU之间传递激活值，反向传播时则从三号GPU到零号GPU依次传递梯度。

## 段落 55

**英文**: Right? Okay. So that's cool. That's great. What's wrong with this picture? Well, I think you should see that most of your GPUs are idle most of the time. This is actually quite terrible utilization. And so if I do this naive kind of parallelism that I described before, right? So if I have, you know, each layer having a forward and let's say I have a single example, that's going to result in a diagram that looks like this. So different rows in this picture are different layers and also different GPUs. And the x-axis here is time where I'm going from left to right. So what do you see? Well, you know, I first compute my first layer at the very left here. And then the activations get passed the second layer.

**中文**: 对吧？好的。这很酷，很棒。但这幅图有什么问题呢？嗯，我想你应该注意到，你的GPU大部分时间都处于闲置状态。这实际上是非常糟糕的利用率。所以，如果我采用之前描述的那种简单的并行方式，对吧？比如，假设每个层都有前向传播，而且我只有一个样本，那就会得到像这样的示意图。图中不同的行代表不同的层，也对应不同的GPU。横轴是时间，从左到右推进。那么你看到了什么？你看，我首先在最左边计算第一层，然后激活值传递给第二层。

## 段落 56

**英文**: GPU two weeks up and it's like, all right, it's my turn. It does its job, passes it to GPU three and then GPU four. And now the backwards passes can begin and so on and so forth. And you see kind of this gigantic what people call bubble. This is a big overhead where you're doing absolutely nothing. And you see that the GPUs are active one over and of the time. So in some sense, this is the worst possible parallelism of I've added four GPUs, but I get the throughput of a single GPU, right? And so one thing you can do is, you know, you can be a little bit more clever about what you do and you can say, all right, I'm going to have a pipeline, right? I'm not just going to cut things up in layers. I'm going to have a sequence of things that need to be processed by each GPU. So now let's say I have a micro batch, right? So each machine is going to handle sort of four examples. And what I'm going to do is, you know, I can finish my first example, my first data point.

**中文**: GPU运行两周后，它仿佛在说：“好了，轮到我了。”它完成自己的工作，传递给GPU三，然后是GPU四。接着反向传播过程可以开始，依此类推。你会看到这种被称为“巨型气泡”的现象。这是一个巨大的开销，期间你完全无所事事。你会发现GPU们只是偶尔活跃一下。所以从某种意义上说，这是我添加了四个GPU后可能实现的最糟糕的并行处理——实际吞吐量却只相当于单个GPU，对吧？那么，我们可以采取的一种策略是，在处理方式上更巧妙一些，比如建立流水线。我不只是简单地将任务按层分割，而是安排一系列需要每个GPU处理的顺序任务。现在假设我有一个微批次，每台机器将处理大约四个样本。我的做法是，先完成第一个样本、第一个数据点的处理。

## 段落 57

**英文**: And I can send off the activations for that to my second GPU as soon as I finish. And then I can then get started working on my second data point, right? And so now I've overlapped sort of, you know, communication and computation. The second GPU can start working while the first GPU continues to work. And now the size of the bubble can potentially be reduced by having bigger batch sizes, right?. And you can hopefully see why I said before that batch sizes are a resource. If you have a finite batch size and you have pipeline parallel, you can use that same batch size to make your pipeline bubble size smaller, for example, or you could use it to do data parallel, right? So there's many different ways that you can take your single batch size and then split it up into different ways. So now your micro batch size can control the bubble time. And in fact, you know, the amount of the ratio of your overhead to the useful compute that. you have is the number of stages minus one over the number of micro batches. So if you have big, big batch sizes, pipeline parallel could potentially be efficient.

**中文**: 一旦我完成，我就可以将激活值发送到我的第二块GPU上。然后我就能开始处理第二个数据点了，对吧？这样我就实现了通信和计算的重叠。第二块GPU可以在第一块GPU继续工作的同时开始工作。现在，通过增大批次大小，这个气泡的大小就有可能减小，对吧？你应该能明白我之前为什么说批次大小是一种资源了。如果你有一个有限的批次大小，并且采用了流水线并行，你可以用同样的批次大小来减小流水线气泡的大小，或者你也可以用它来做数据并行，对吧？所以，你可以用多种不同的方式将单个批次大小分割开来。现在，你的微批次大小可以控制气泡时间。实际上，你知道的，你的开销与有效计算之间的比例是（流水线阶段数减一）除以微批次的数量。所以，如果你有非常大的批次大小，流水线并行可能会非常高效。

## 段落 58

**英文**: But as we said before, you know, batch sizes are finite. We can't just crank that up to whatever value that we want. So, you know, in general, pipelines seem really horrible. You know, why do we do it? Why do we incur this cost of a bubble in order to, you know, paralyze? Well, there's a couple of reasons. Pipelines help save memory compared to data parallel. I mean, 0, 3 will also shard the parameters, but this also shards the activations, which is nice. Pipelines can also have good communication properties, right? It only depends on activations. It's also point to point. So it's possible that depending on your topology and depending on what you have, pipelines might actually be very favorable for the slower parts of your network. And so, you know, pipeline parallel is often going to be used on your slower network links.

**中文**: 但正如我们之前所说，批次大小是有限的，我们无法随意将其提升到任意值。所以，总的来说，流水线看起来确实很糟糕。那么，我们为什么要这样做？为什么我们为了并行化而承受这种气泡成本呢？嗯，有几个原因。与数据并行相比，流水线有助于节省内存。我的意思是，0和3也会对参数进行分片，但流水线还能对激活值进行分片，这很好。流水线还具有良好的通信特性，对吧？它只依赖于激活值，而且是点对点的。因此，根据你的拓扑结构和实际情况，流水线可能非常适合网络中较慢的部分。所以，流水线并行通常会被用于较慢的网络链路上。

## 段落 59

**英文**: So inter node or even sometimes across different sort of racks or across different data centers, you might do actually not data centers. Across different racks, you might do pipeline parallel, right? One of the examples of a thing that I was recently told by some Google folks is, you know, they were saying actually one of the big advantages of TPUs is that we don't have to do pipeline parallel very much because, you know, all of our connections are much bigger, right?. Like they have this big, toroid old mesh. They don't have this limit at 256 GPUs where they're suddenly going towards a slower network link where you might want to switch to pipeline parallel, right? So that's a real world kind of example of when you would start to think about pipeline parallel. And so, this is an example from an Nvidia paper. I'll talk about this paper in much greater detail later. They've done some really nice work showing sort of performance characteristics of different. kinds of parallelism. But you kind of see with batch size eight, as you increase the pipeline parallel size, the number of devices, your, you know, utilization per GPU sort of starts to really drop off. Whereas if you have a big, big batch size of 128, you can get away with, you know, pretty good utilization for reasonably sized pipeline parallel, right? So batch sizes are really key to hiding the size of the bubble.

**中文**: 因此，在节点之间，甚至有时在不同的机架或不同的数据中心之间——实际上可能不是数据中心，而是在不同机架之间——你可能会采用流水线并行，对吧？最近一些谷歌员工告诉我一个例子，他们说，TPU的一大优势其实是我们不太需要做流水线并行，因为我们的连接规模要大得多，对吧？比如他们有一个大型的环形网状结构。他们不会遇到像256个GPU那样的限制，即突然转向较慢的网络链路，这时你可能需要考虑切换到流水线并行。所以，这就是一个现实世界中何时开始考虑流水线并行的例子。接下来，这是英伟达论文中的一个示例。稍后我会更详细地讨论这篇论文。他们做了一些很好的工作，展示了不同并行方式的性能特征。你可以看到，在批处理大小为8的情况下，随着流水线并行规模（设备数量）的增加，每个GPU的利用率开始大幅下降。而如果批处理大小达到128，即使流水线并行规模相当大，也能保持相当好的利用率，对吧？所以，批处理大小对于隐藏气泡的大小至关重要。

## 段落 60

**英文**: Otherwise, you have issues. Of course, you can do, you know, different kinds of pipeline sort of pipeline strategies. So instead of, you know, having these sort of like standard patterns for scheduling the bubble, you can sort of cut things up into finer pieces where you're sort of assigning different stages or something, different sub layers to different device and you're doing different computations at different parts, you can then sort of interleave the pipeline better. And sort of an advanced version of this that I want to spend a moment talking about. And this is very, very clever. Is zero bubble pipelining or I think in deep sea, lingo, I think they call it dual pipe,. but the core single trick is the same. So here, if you think about it, let's say we're doing, you know, the backwards paths to compute gradients, you can split this up into two different components. The first part is about, you know, back propagating the activations. So this is, you know, as I go down sort of the residual connections, I need to compute essentially the derivative with respect to the activations.

**中文**: 否则，您就会遇到问题。当然，您可以采用不同类型的流水线策略。也就是说，与其使用这些调度气泡的标准模式，不如将任务分割成更细的模块，将不同的阶段或子层分配给不同的设备，并在不同部分执行不同的计算，从而更好地实现流水线交错。我想花点时间讨论一下这方面的一个高级版本，这非常非常巧妙，那就是零气泡流水线（在Deep Sea术语中，我认为他们称之为双流水线），但其核心技巧是相同的。举个例子，假设我们正在执行计算梯度的反向传播路径，您可以将其拆分为两个不同的部分：第一部分是关于激活值的反向传播，也就是说，沿着残差连接向下计算时，我需要计算关于激活值的导数。

## 段落 61

**英文**: And then, you know, as I sort of, you know, get to a parameter, I also want to compute the gradient itself. Like how am I going to update the parameters, not just how do the activation change with respect to sort of the previous layers. And so to give you a concrete example, let's look at this bottom left diagram over here. Right. So in this diagram, you see the forward pass, this is a single MLP. So we've got multiply by a weight, I do a nonlinearity, and then I'm just going to output the nonlinearity. Right. So this is kind of a naive, you know, single part of a MLP. Now let's look at the backwards. You know, I have sort of the derivative with respect to the loss.

**中文**: 然后，当我接近某个参数时，我也想要计算梯度本身。就像我该如何更新参数，而不仅仅是激活值如何相对于前一层发生变化。为了给你一个具体的例子，让我们看看左下角的这个图表。好的。在这个图表中，你看到的是前向传播，这是一个简单的多层感知机（MLP）部分。我们乘以权重，进行非线性变换，然后输出非线性结果。对，这算是MLP中一个简单、基础的部分。现在来看看反向传播。我有相对于损失的导数。

## 段落 62

**英文**: It comes in. And then I can compute, you know, how that's going to change the, the x's, the inputs to my MLP. In some sense, the derivatives are affected the activations here. And then as I compute these, of course, I can use them to compute the gradients that I. need to update my weights, right. But the important thing is this part, this part of computing the gradients for the weights, this can be done whenever, right. There's no sort of dependence of this. And so I can rearrange the scheduling for this computation to any part of the computation graph. And so what you can do is you can sort of do your standard pipeline parallel for the parts that are serially dependent. But any time you have to do these computations just for updating the parameters, you can sort of re-schedule them wherever.

**中文**: 它进来了。然后我可以计算，你知道的，这将如何改变我的多层感知机的输入x。在某种意义上，这里的激活值会影响导数。接着，当我计算这些时，我当然可以用它们来计算更新权重所需的梯度，对吧。但重要的是这一部分，计算权重的梯度这一部分，这可以在任何时候进行，对吧。这里没有什么依赖性。因此，我可以将这个计算的调度重新安排到计算图的任何部分。所以，你可以做的是，对于序列依赖的部分，你可以采用标准的流水线并行方式。但任何时候，只要是为了更新参数而需要进行这些计算，你都可以在任何地方重新调度它们。

## 段落 63

**英文**: And so the key idea is, when you start with sort of a nice, what's called 1F1B pipeline, this is a nice optimized, reducing the bubble size schedule. And then you can take this, and what you can do is you can separate, you know, this B, which is this computation of the backwards part. And then W, which is the computation necessary to compute the gradients of the weights. And now I can do the computation of the weights, the W's, where I would have originally had. a bubble, right. So the parts where, you know, I originally had these white, white sort of idle utilization components, I can now fill them in with these W's, right. And so by thinking carefully about what the serial dependencies actually are, you know, I can now have something really nice where I'm getting actually good utilization out of my GPU's. To be clear, this is horrendously complicated, right. If you actually want to implement pipeline parallel in this way, you're going to have to. like intervene in how, you know, your auto-diff is actually calculating these things.

**中文**: 因此，关键思路是，当你从一个被称为1F1B流水线的优化方案开始时，这个方案能有效减少空闲时段。接着，你可以将其中的B部分——即反向传播的计算——与W部分——计算权重梯度所需的部分——分离开来。现在，我可以在原本出现空闲的位置进行权重（W）的计算。也就是说，原本那些白色、表示闲置利用的部分，现在可以用这些W计算来填充。通过仔细分析实际的串行依赖关系，我就能实现一种高效的方案，真正提升GPU的利用率。需要明确的是，这实现起来极其复杂。如果你想以这种方式实现流水线并行，就必须干预自动微分机制的实际计算过程。

## 段落 64

**英文**: You have to have a queue that can track where things go. I heard a funny anecdote in a conversation recently from someone in a frontier lab sort of training alums, and they said, you know, actually there's two people in the group that understand how the pipeline parallel in our infra works, one person left. And so there's a single load bearing person in our training infra. You know, like there are stories like this. Pipeline parallel is infrastructureally very, very complicated, right. It looks simple here. If you're interested, and you're not going to encourage you to try and implement it, it does get pretty hairy, pretty fast. And I think that's a good note on which to switch to the other kind of model parallelism, because this is much simpler. And this is often, you know, very cleanly utilized by a lot of frameworks and a lot of sort of even people training really big models, rely very, very heavily or primarily on this kind of model parallelism. So what other way can we split up a model, right? So if we think about it, most of what we do is matrix multiplies, right, in a big model, most of the computation is matrix multiplies, most of the parameters where matrix multiplies are matrices.

**中文**: 你必须有一个能追踪任务去向的队列。最近在一次谈话中，我听前沿实验室的人讲了个有趣的轶事，他们正在培训一些校友，提到组里其实只有两个人懂我们基础设施中的流水线并行原理，结果其中一个离职了。所以现在整个训练基础设施里就只剩一个“顶梁柱”了。这类故事其实挺常见的。流水线并行在基础设施层面非常非常复杂，对吧？它在这里看起来简单，但如果你感兴趣——不过我可不想鼓励你去尝试实现它——这东西很快就会变得相当棘手。我觉得这是个很好的切入点，可以转向另一种模型并行方式，因为那种要简单得多。而且很多框架，甚至许多训练超大模型的人，都非常依赖或主要使用这种模型并行，它通常能很清晰地被应用。那么，我们还能怎么拆分模型呢？想想看，我们做的大部分工作都是矩阵乘法，对吧？在大模型中，大部分计算是矩阵乘法，大部分参数也存在于矩阵乘法的矩阵中。

## 段落 65

**英文**: And so what can we do? Well, if we can parallelize just the mat molds, that would be pretty good. And so tensor parallel is this idea that we can take a big matrix multiply and split it up into a set of sub matrices that can be multiplied, right?. So if I have, you know, this matrix multiply at the top, right? We have x and sort of x times a equals y. You know, what I can do instead is I can cut up a into half, right? And then I can also cut up x into half. And I can compute the sub matrices. I can sum them up and then I will get my answer at the end, right? So conceptually, pipeline parallel is cutting along the depth dimension, like the layers. Tensor parallel, which is what this is, is cutting up along the width dimension of your. matrix multiplies. And so we're going to decompose into sub matrices and then do partial sums. So here's an example of what it might look like in a MLP, right? We have each GPU handling a different sub matrix of, let's say, a big MLP matrix multiply.

**中文**: 那么我们该怎么做呢？如果我们能仅将矩阵乘法并行化，那将会相当不错。张量并行的核心思想是，我们可以将一个大型矩阵乘法分解成一系列可以并行计算的子矩阵乘法。比如顶部的这个矩阵乘法：x 乘以 a 等于 y。实际上，我们可以将 a 切成两半，同样将 x 也切成两半。然后分别计算这些子矩阵的乘积，最后将它们的结果相加，就能得到最终答案。从概念上讲，流水线并行是沿着深度维度（比如网络层）进行切割，而张量并行——也就是这里所讨论的——是沿着矩阵乘法的宽度维度进行切割。我们将矩阵分解为子矩阵，然后进行部分求和。以下是一个在多层感知机（MLP）中可能的应用示例：每个GPU负责处理大型MLP矩阵乘法中的不同子矩阵。

## 段落 66

**英文**: And then we're going to have collective communications to synchronize the activations as we kind of need them, right? So what are we going to do? So this is a MLP. And sort of the top half and the bottom half, there's two different paths. These are, you know, splitting up the matrices. So I want to do this operation. Y equals del u x times a. I'm going to split up my matrix a into a1 and a2. And then on the right hand side, I want to compute drop out yb, right? And then I want to return the result as z. So I'm going to also cut up b, right?. So I've cut up both of my big parameter matrices into two parts, a and b. And in the forward pass, what I'm going to do is I'm going to take my inputs x.

**中文**: 然后我们将通过集体通信来同步激活值，因为我们需要它们，对吧？那么我们要做什么呢？这是一个MLP。大致分为上半部分和下半部分，有两条不同的路径。这些操作其实就是对矩阵进行分割。所以我想执行这个运算：Y等于del u x乘以a。我将把我的矩阵a分割成a1和a2。然后在右侧，我想计算drop out yb，对吧？接着我想将结果返回为z。所以我还要分割b，对吧？这样我就把我两个大的参数矩阵a和b都分割成了两部分。在前向传播中，我将要做的是获取输入x。

## 段落 67

**英文**: And I'm just going to copy them twice, right? So each GPU is going to get the same inputs. And they're going to operate on it with a1 and a2, right? They have the same kind of, oh, sorry. They're the same row dimensions. So it's going to be fine operating on them. So xa1 and xa2 is going to give you some activations y1 and y2. Those are going to go into b1 and b2. And then I'm going to do an all-reduced to sum them up. That's exactly the figure I showed you before, right? So you copy and then you all reduce and you've got the answer z. In the back-words pass, now it's actually the reverse. As sort of the gradients come backwards in the back-words steps, this g is going to be the identity.

**中文**: 我准备把这些数据复制两份，对吧？这样每个GPU都会收到相同的输入。它们将分别用a1和a2进行处理，对吧？它们具有相同的——哦，抱歉——它们的行维度是相同的，所以处理起来没问题。这样xa1和xa2会产生一些激活值y1和y2。这些值将输入到b1和b2中。然后我会进行一次全局归约求和。这和我之前展示的示意图完全一致，对吧？所以先复制，再全局归约，就能得到结果z。在反向传播过程中，情况其实是相反的。当梯度在反向步骤中回传时，这个g将充当恒等变换。

## 段落 68

**英文**: So I'm going to copy sort of the derivatives on both sides. And I'm going to do sort of the back-words operation all the way through. And once I get to f, this is an all-reduced, right? Because I've got sort of two derivatives sort of coming in from both paths. And then I sum them back up, right? So this f and g are synchronization barriers. In the forward pass, I do a single all-reduced. On the backwards pass, I do a single all-reduced, just that two different places in the. computation graph. So now you can hopefully see how this is a very nice way of wherever you have a matrix multiply. You can just cut up the matrix multiply and sort of parallelize them across different devices. OK.

**中文**: 所以我要复制两边的导数。然后我会一直进行反向操作。当我到达f时，这就完成了一次全局归约，对吧？因为我有两条路径的导数汇入。接着我把它们重新求和，对吧？所以这里的f和g是同步屏障。在前向传播中，我执行一次全局归约；在反向传播中，我也执行一次全局归约，只是它们位于计算图中的两个不同位置。现在你应该能看出，这种方法非常巧妙：无论哪里有矩阵乘法，你都可以将矩阵乘法拆分，并在不同设备上并行化处理。好的。

## 段落 69

**英文**: And as you might imagine, this is actually somewhat expensive. We have a synchronization barrier that lives kind of per layer. It needs to communicate an activation, sort of like the residual activation worth of stuff twice in a forward backward pass. And so tensor parallel, this very simple idea, is going to require very high-speed interconnects. And so there's a rule thumb. It's a very simple rule thumb to remember, which is that tensor parallel is applied within or within a single node. So a single box of, let's say, Nvidia GPUs is going to ship with eight different GPUs that live in that same box. And as I showed you at the beginning of lecture today, they're very, very high-speed connected. So those AGPUs can talk to each other very quickly. And so it makes sense to use something like tensor parallel that's very bandwidth hungry on between those eight devices.

**中文**: 正如你可能想象的那样，这实际上有些昂贵。我们有一个每层都存在的同步屏障。在前向和后向传播中，它需要传递激活值，类似于残差激活值，需要传递两次。因此，张量并行这种非常简单的想法将需要非常高速的互连。这里有一个经验法则，一个非常简单的经验法则需要记住：张量并行通常应用于单个节点内。例如，一个装有NVIDIA GPU的单个机箱通常会配备八个不同的GPU，它们都在同一个机箱内。正如我今天课程开始时展示的那样，它们之间通过非常高速的方式连接。因此，这些GPU可以非常快速地相互通信。所以，在这八个设备之间使用像张量并行这样对带宽要求很高的方法是合理的。

## 段落 70

**英文**: So what we will typically see is that tensor parallel is applied up to AGPUs where the AGPUs live in the same machine because that gives you the least sort of drop-in performance. And so this is an example from hugging faces sort of parallelization tutorial showing you sort of the throughput decreases of different levels of tensor parallelism. You see that there are hits, right? 10 and 12% hits to throughput as you do tensor parallelism. But up until eight, well, maybe this is manageable. This is kind of the price you pay for just being able to parallelize more nicely. But then you go to 16 devices and you get this kind of astounding 42% drop in performance. You go to 32 and you see another sort of 65% drop in throughput, right? And so you see, hopefully, visually here that you really want to stop at eight for tensor parallelism. That's really the sweet spot because of the kinds of hardware interconnects you can get your hands on. Okay. So how do things now compare to pipeline parallel, right? Well, compared to pipeline parallel, we don't really have to deal with this bubble thing that we had before.

**中文**: 因此，我们通常会发现，张量并行通常应用于同一台机器内的AGPU之间，因为这样能最大程度地减少性能损失。这是Hugging Face并行化教程中的一个示例，展示了不同级别张量并行带来的吞吐量下降。可以看到确实存在性能损耗，对吧？进行张量并行时，吞吐量会下降10%到12%。但在8个设备以内，这种损耗或许还可以接受——这是为了实现更高效并行化所付出的代价。然而，当扩展到16个设备时，性能会出现惊人的42%下降；到32个设备时，吞吐量又会再降65%左右。通过这个直观展示，我们希望你能明白：张量并行最好控制在8个设备以内。由于硬件互连条件的限制，这确实是性价比最高的选择。那么，与流水线并行相比又如何呢？相较于流水线并行，我们不必再处理之前提到的气泡问题。

## 段落 71

**英文**: We don't need to consume sort of larger batch sizes in order to reduce the bubble, which is nice. And there's very relatively, I want to say very, there's relatively low complexity in applying tensor parallel, right? All you really need to know about are where are the big matrix multiplies? Can I split them up and make them live on different devices, right? The forwards and backwards operations still remain the same, right? And compared to implementing something like zero overhead or dual pipeline parallel, you're going to be in much, much better shape doing this. So the con is that it's much larger communication overhead. You've got, you know, in pipeline parallel, batch size, time sequence length, time sort of residual dimension, point to point communications per micro batch. In tensor parallel, you've got, you know, eight times that per layer, and you've got all reduced communication. It's potentially a very large amount of communication that needs to be done. So, you know, the rule of thumb, as I said before, is tensor parallel is used whenever you have low latency high bandwidth interconnects, you're going to see, you know, two to like 16 depending on, you know, what kinds of machines you have of tensor parallel out in the. wild. And I'll show you examples as I talk through at the very end here of examples of tensor parallel. Okay.

**中文**: 我们不需要消耗更大的批量来减少气泡，这很好。而且应用张量并行的复杂度相对较低，对吧？你真正需要知道的就是那些大型矩阵乘法在哪里？我能否将它们拆分并放置在不同的设备上？前向和后向操作仍然保持不变。与实现零开销或双流水线并行相比，这样做要好得多。缺点在于通信开销要大得多。在流水线并行中，每个微批次的通信量是批量大小乘以序列长度再乘以残差维度。而在张量并行中，每层的通信量是前者的八倍，并且还需要进行全局归约通信。这可能需要大量的通信。所以，正如我之前所说，经验法则是：只要你有低延迟高带宽的互连，就可以使用张量并行。在实际应用中，你会看到2到16路不等的张量并行，具体取决于你使用的机器类型。在最后，我会通过实例来展示张量并行的例子。好的。

## 段落 72

**英文**: Any questions on pipeline or tensor parallel before we move on to the kind of third kind, like sequence parallel and activation, sharding, yes. Can they both be used simultaneously? Yes, the question was, can they be used simultaneously?. The answer is that, yeah, you do use them both. So I think we'll get to examples later, but I think the typical thing that you see is for large scale runs, you very often see tensor parallel. Pipeline parallel is often used on top of that. I think the only example I know of that does pipeline, but not tensor parallel, would be deep-seq v3 as far as I know. So we've been to single machine, I guess, in public. So, like you have like five different machines, like maybe the first 20% of the printers. are across the each of those first machine, which you can have some parallel as one. And then that pipeline parallel is into the second machine for you.

**中文**: 在我们继续讨论第三种并行方式，比如序列并行和激活分片之前，大家对流水线并行或张量并行还有什么问题吗？好的。问题是它们能否同时使用？答案是肯定的，它们确实可以同时使用。我想我们稍后会举例说明，但通常在大规模运行中，张量并行很常见，而流水线并行往往在此基础上叠加使用。据我所知，唯一只使用流水线并行而不使用张量并行的例子是Deep-Seq v3。在公开场景中，我们通常涉及单机运行。假设你有五台不同的机器，比如前20%的层分布在第一台机器上，这些层内部可以进行某种并行处理，然后通过流水线并行将数据传递到第二台机器。

## 段落 73

**英文**: Yes, so the question was there, do you do tensor parallel within machine and pipeline parallel across machine, for example? Yeah. So you would do something like tensor parallel within machine and a combination of data and pipeline parallel across machines, for example, right? And I'll show you the rule from later, but basically, you do pipeline parallel because. your models won't fit. Like if you could fit your entire model, you just do data parallel plus tensor parallel, or just maybe even data parallel. Great. OK. Excellent. So then, we've been talking about memory. And memory is, in some sense, a very important part of parallelization, because we're going. to be training big models.

**中文**: 是的，所以问题是这样的，比如，你们是在单机内做张量并行，跨机器做流水线并行吗？对。所以你们可能会在单机内做张量并行，同时在跨机器时结合数据和流水线并行，对吧？我稍后会展示具体的规则，但基本上，采用流水线并行的原因是……你们的模型放不下。如果能放下整个模型，你们可能只做数据并行加张量并行，或者甚至只做数据并行。很好。好的。太棒了。那么，我们一直在讨论内存问题。从某种意义上说，内存是并行化中非常重要的一部分，因为我们要训练大模型。

## 段落 74

**英文**: And so when you look at your memory, you realize that actually activations are really a big part of your memory usage. So if you look at standard forward backward pass, I think this was from one of the high-torch tutorials. You see that memory usage is very dynamic. So I'll just talk through this because I think it's an interesting plot in general. You always have your parameters as you're training, because that's static. But in the iteration 0, you don't still have optimizer state at all. So actually, you don't have that part of your memory use. But as you do your forward and backward, you see activation grows, grows, grows, grows, grows, grows, grows, as you accumulate all the activations. And as you start your backwards pass, your activation goes down, because you're freeing it as you use up your activations. And then you're accumulating your gradients, your gradient memory usage goes up.

**中文**: 因此，当你审视内存使用情况时，会发现激活实际上占据了内存的很大一部分。以标准的前向-后向传播为例（我记得这是某篇PyTorch高级教程中的内容），可以看到内存使用是非常动态变化的。这里简单解释一下，因为我觉得这个图表本身很有意思。训练时参数始终占用内存，因为它是静态的。但在第0次迭代时，优化器状态还不存在，所以这部分内存尚未使用。随着前向传播的进行，激活值会不断累积、增长、增长、再增长。而当开始后向传播时，激活值占用的内存逐渐下降，因为在使用过程中会逐步释放。与此同时，梯度开始累积，梯度占用的内存随之上升。

## 段落 75

**英文**: And the peak is actually somewhere partially through your backwards pass, where you haven't. freed all your activations yet, and you're still building up your gradients. And so in iteration 2, you kind of see the same thing here, right? And so the point of this diagram is to say, well, we've thought about all the other pieces. So we've thought about parameters, we've thought about optimizer state, we've thought about the gradients, but we have not thought about very deeply at least the activations. And so let's do that, right? So the final complexity that I want to talk you through is the activation memory. So tensor and pipeline parallel can linearly reduce, basically, most things. But it can't actually reduce all of the activation memory usage. And so this is an example from one of the Nvidia papers that's talking about how do you reduce activation memory? And I think one thing that's really interesting to see is that you make your models bigger and bigger. So from left to right, you see that a parameter and optimizer state memory can remain the same if we paralyze aggressively. But activation memory just kind of continues to grow, because some parts of it don't paralyze very cleanly.

**中文**: 峰值实际上出现在反向传播的某个中间阶段，此时你尚未释放所有激活值，同时梯度仍在累积。在第二次迭代中，我们也能看到类似的情况，对吧？这张图的核心观点是：我们已经考虑了其他所有组件——参数、优化器状态、梯度，但至少对激活值的思考还不够深入。那么现在就来深入探讨这个问题。接下来我想分析的最后一个复杂性是激活内存。张量并行和流水线并行基本上能线性减少大多数内存占用，但无法完全降低激活内存的使用量。英伟达某篇论文中举例讨论了如何减少激活内存，其中特别有趣的一点是：随着模型规模不断扩大（从左到右可见），如果我们采用激进的并行策略，参数和优化器状态的内存可以保持不变，但激活内存却持续增长，因为其中某些部分难以实现彻底的并行化。

## 段落 76

**英文**: So no matter the number of devices you have, actually you can't really get rid of the growth of activation memory per device. And I'll show you why in a moment here. Whereas I think if you do some slightly more clever things like recomputation, you can keep the activation memory low. And that's really key to paralyzing some of the biggest models. Okay. So what's the activation memory per layer? You've kind of done some of this transformer math and calculus before. So hopefully you're now familiar with all of this. But we can compute what's the amount of activation memory we need per layer. And there's a handy formula here. And this is the amount of memory you need.

**中文**: 所以，无论你拥有多少设备，实际上都无法真正摆脱每个设备上激活内存的增长。我稍后会解释原因。而我认为，如果你采用一些更巧妙的方法，比如重计算，就可以将激活内存保持在较低水平。这对于并行化一些最大的模型来说至关重要。好的，那么每层的激活内存是多少？你们之前应该已经接触过一些Transformer相关的数学和微积分知识，希望现在对这些内容已经熟悉了。我们可以计算出每层所需的激活内存量，这里有一个方便的公式，这就是你需要的内存大小。

## 段落 77

**英文**: It's sbh times 34 plus 5a s over h. And some of these numbers are mystifying, but actually they're not so mystifying. You can very much see that there's a left term and then there's a right term. The left term comes from the MLP and other point wise operations. That's where sbh times 34 comes from. These depend on the size of your residual stream, the h. On the right side, you have a term that's actually if you multiply this out, a s squared b because the h is cancel. That's the memory that you need for the softmax term and other quadratic terms in your. attention. Of course, if you use flash attention, you can drastically reduce and use recomputation.

**中文**: 这是sbh乘以34加5a s除以h。其中一些数字看起来令人费解，但其实并非如此。你可以清楚地看到，这里有一个左侧项和一个右侧项。左侧项来自MLP和其他逐点运算，这就是sbh乘以34的由来。这些项取决于残差流的大小h。在右侧，如果你将其展开，会得到一个a s平方b的项，因为h被约掉了。这是注意力机制中softmax项和其他二次项所需的内存。当然，如果使用闪存注意力，你可以大幅减少内存占用并通过重计算来优化。

## 段落 78

**英文**: We know that we can drastically reduce that second term. So then let's say we do tensor parallel. We do tensor parallel everywhere we can. We do it in the MLPs, we do it in the KQ computations in the attention computation. We will end up with something that looks like this. This is looking pretty good, but not quite there. So activation memory per layer divided by t, which is the number of devices that were tensor paralleling over. So if we're dividing by 8, ideally we would divide all the activation memory by 8. Now you see there's this straggler term, sbh times 10, that has not been reduced down. If you think about what these are, these are the non-matmo components.

**中文**: 我们知道可以大幅减少第二项。那么假设我们进行张量并行。我们在所有可能的地方都采用张量并行，包括MLP中，以及在注意力计算的KQ计算中。最终我们会得到类似这样的结果。这看起来相当不错，但还不够理想。因此，每层的激活内存除以t，即进行张量并行的设备数量。如果我们除以8，理想情况下所有激活内存都应除以8。现在你会看到这个拖后腿的项，sbh乘以10，它并没有被减少。如果你思考一下这些是什么，它们就是非矩阵乘法部分。

## 段落 79

**英文**: The layer norm, the dropouts, the inputs to the attention and the MLP. All of these terms will unfortunately continue to grow with size and they will not be paralyzed very nicely. The very last thing that we need to think about is to take those simple point wise operations, which thus far we have not paralyzed. And we just need to split them up. And there's a very simple way to split them up, which is to say, well, if we're doing like a layer norm, these layer norms across different positions in the sequence do not interact at all with each other. They just don't care about anything else. And so what we are going to do is let's say we have a 1024 long sequence, we're going. to cut that up and then each device will handle a different part of that layer norm or different part of that dropout. Those point wise operations can now be completely split up across the sequence dimension. And because now we're cutting things up across the sequence dimension, we're going to have to do some synchronization to make sure the parallel computations that we did can get aggregated back again.

**中文**: 层归一化、丢弃层、注意力机制的输入以及多层感知机。不幸的是，所有这些项都会随着规模增大而增长，并且它们无法很好地并行化。我们最后需要考虑的是处理那些简单的逐点运算，这些运算至今尚未被并行化。我们只需将它们拆分。拆分的方法非常简单，比如对于层归一化，序列中不同位置的层归一化彼此之间完全没有交互。它们根本不关心其他任何内容。因此，我们的做法是，假设我们有一个长度为1024的序列，我们将把它切分，然后每个设备将处理该层归一化的不同部分或该丢弃层的不同部分。这些逐点运算现在可以完全沿着序列维度进行拆分。由于我们现在沿着序列维度切分数据，我们将需要进行一些同步，以确保我们进行的并行计算能够重新聚合起来。

## 段落 80

**英文**: And so in the forward pass, these G's, they're going to be all gathers and G bars are going to be reduced scatters. And in the backwards pass, the two are reversed. In some sense, there's sort of a duality here between the two. And what we're doing here is for the layer norm, we've kind of scattered things around. And so we're going to have to gather them back together so that we can do sort of our standard computation. And then now whenever we get to the dropout, we want to scatter them back out into the sort of parallel components that we have. And in the backwards pass, we're kind of doing that in the reverse. Okay. So hopefully that is clear. This is a very simple idea.

**中文**: 因此在正向传播中，这些G操作将全部是收集操作，而G横杠则是归约分散操作。在反向传播中，两者正好相反。从某种意义上说，这两者之间存在一种对偶关系。我们在这里对层归一化所做的操作，本质上是将数据分散开来。因此，我们需要将它们重新收集起来，以便进行标准的计算。接着，当进行dropout操作时，我们又需要将数据分散回我们拥有的并行组件中。而在反向传播中，我们则以相反的顺序执行这些操作。好的，希望这样解释是清晰的。这是一个非常简单的概念。

## 段落 81

**英文**: We're just paralyzing sort of the very last components that we failed to paralyze before. And so now we can sort of put all of these different pieces together and sort of get to sort of the end, which is we started up here, which is no parallels metal. We did tensor parallel, which allows us to divide everything that's not a pointwise op by T. And then if we apply the sequence parallelism idea, we can divide this component. by T once more. And then we can do things like activation, recomputation, which is the flash attention trick to remove the second term. And the minimal memory that you can kind of easily get away with is going to be this thing on the bottom, which is sp8, h34 over T. And this is often used if you're looking at different formulas for transformer arithmetic on like how much activation memory do I use? You often see something like sph34 and then if you have T tensor parallel divide by T, because this is the sort of easy minimum that you can get for that kind of a memory. Okay, any questions on sequence parallel and activations? Yes. It was lovely that it has to transform as it started all the other festival circumvadaient of graph, and more or more importantly, the free-working, managing-your-pipersion-comvadaient of graph, as a good diagram for everything.

**中文**: 我们只是将之前未能并行的最后几个组件进行了并行化处理。这样一来，我们现在可以将所有这些不同的部分组合起来，最终达到我们最初的目标，即实现无并行金属。我们采用了张量并行，这使得我们能够将所有非点运算的部分除以T。接着，如果我们应用序列并行的思想，我们可以再次将这个组件除以T。然后，我们可以进行诸如激活重计算之类的操作，这是通过Flash Attention技巧来消除第二项的方法。你能够轻松实现的最小内存占用将是底部的这个公式：sp8，h34除以T。如果你在查看Transformer算术的不同公式，比如我使用了多少激活内存？你经常会看到类似sph34的表达式，然后如果你有T张量并行，就除以T，因为这是那种内存可以轻松达到的最小值。好了，关于序列并行和激活，有什么问题吗？是的。它必须像启动所有其他节日环绕图一样进行转换，更重要的是，自由工作、管理你的管道环绕图，作为一切的良好图示，这真是太棒了。

## 段落 82

**英文**: I mean, that would be common all of that with the limitation between the gene and use. You're saying if we have something that's a more complicated computation graph than like a single linear chain, will that become a problem?. That's a good question. I haven't thought about that. I would guess not. Like, at least for tensor parallel, this operates purely layer-wise. It doesn't really care about the dependencies. Maybe for pipeline parallel, there's opportunities for increased parallelization if there's more than one branch, but I'm not too sure. Yes, great. Okay.

**中文**: 我是说，在基因和使用之间的限制下，这通常都是常见的。你是说，如果我们有一个比单一线性链更复杂的计算图，那会不会成为问题？这是个好问题。我还没想过这一点。我猜不会。至少对于张量并行来说，它纯粹是按层操作的，并不真正关心依赖关系。也许对于流水线并行，如果存在多个分支，可能会有增加并行化的机会，但我不太确定。是的，很好。好的。

## 段落 83

**英文**: Cool. Cool. So there's a few other parallelism strategies that I'm not going to talk about just because in the interest of time and sort of fatiguing you, because I think I've already dragged you through a whole bunch of low-level details about how to do parallelization. So the first one I want to talk about is context parallel or ring attention. You may have heard the term ring attention before. This is a way of essentially splitting up both the computation and the activation cost of computing really large attention, where essentially you're just going to pass keys and values around different machines. So each machine is responsible for a different query, and the keys and values are going to sort of travel from machine to machine in a sort of ring-like fashion in order to compute your KQV in your products. The cool thing here is you already know how to do this, because you've done the tiling for flash attention. So you know that attention can be computed in this kind of online tile by tile way, and that's kind of what's happening in ring attention. The other thing, which now that you know tensor parallel is pretty straightforward, is expert parallelism.

**中文**: 酷。酷。那么还有一些其他的并行策略我就不展开讲了，主要是考虑到时间关系，也怕大家听得太累，因为我觉得已经带大家深入了解了并行化的底层细节。首先我想讲的是上下文并行或环形注意力。你可能之前听说过环形注意力这个词。这种方法本质上是为了分摊计算超大注意力时的计算量和激活值成本，基本上就是让键和值在不同的机器之间传递。每台机器负责不同的查询，而键和值会以类似环形的方式在机器间流转，从而计算乘积中的KQV。这里很酷的一点是，你已经知道怎么做了，因为你已经为闪存注意力做过分块处理。你知道注意力可以这样在线逐块计算，环形注意力基本上就是这么做的。另外，既然你已经了解了张量并行，那么专家并行就很简单了。

## 段落 84

**英文**: Expert parallelism, you can kind of think of as almost like tensor parallel in the sense that you're splitting up one big MLP into smaller expert MLPs, let's say, and then scattering them across different machines. The key difference with expert parallelism is that the experts are sparsely activated,. and so you have to think a little bit about routing, and the routing is not going to be sort of as predictable, let's say, as the all-to-all communication that we had before in tensor parallel. Because now, you know, maybe one expert is overloaded, your networking is going to be a little bit more complicated. But otherwise conceptually, you're living in kind of the same world as tensor parallel for expert parallels. Okay. So just to recap all the things we talked about, I've made a little small table of the different kinds of strategies that we have. You know, we have DDP and 0. 1. This is kind of the naive data parallelism thing that you do.

**中文**: 专家并行，你可以大致理解为类似于张量并行，因为你是在将一个大型MLP拆分成更小的专家MLP，然后分散到不同的机器上。专家并行的关键区别在于专家是稀疏激活的，因此你需要稍微考虑一下路由问题，而且这种路由不会像之前张量并行中的全对全通信那样可预测。因为现在，可能某个专家负载过重，你的网络通信会稍微复杂一些。但除此之外，从概念上讲，专家并行所处的世界与张量并行类似。好了，我们来回顾一下我们讨论过的所有内容，我做了一个小表格，列出了我们拥有的各种策略。你知道，我们有DDP和0.1，这基本上是你做的朴素数据并行。

## 段落 85

**英文**: Here you have some overhead per batch, you have no memory scaling, reasonable bandwidth properties, but you consume batch size in order to be able to do this, right? You need big batch sizes to have big data parallelism. You have FSTP, which is kind of like a nicer version of 0. 1 in the sense that you can. get memory scaling, but you're going to pay overhead across sort of different layers, right? And so now you've got higher communication cost, and you've got potentially synchronization barriers that lead to poor utilization. Pipeline parallel, you know, is nice in that, you know, we no longer have this dependence on this per batch aspects, but we can get linear memory scaling. So we have sort of another issue, which is this also consumes batch size, and it's horrendous to sort of set up and use. And so a lot of people like to avoid pipeline parallelism if it's possible. And finally, tensor parallelism is very high cost in terms of bandwidth and the amount of synchronization you need to do. But this has this really nice property that has no impact on batch sizes. So it's like kind of the one parallelism strategy you can use that has no cost in terms of your global batch size, which is nice, right? So we have to balance a number of limited resources, right? We have memory, which is one resource.

**中文**: 这里每个批次都有一定的开销，内存无法扩展，带宽特性尚可，但为了实现这一点你需要消耗批次大小，对吧？你需要大批次才能实现大规模数据并行。FSTP有点像优化版的0.1，它能实现内存扩展，但需要在不同层级付出开销，通信成本更高，还可能出现同步障碍导致利用率低下。流水线并行的优点在于摆脱了对批次处理的依赖，能实现线性内存扩展，但同样会消耗批次大小，且配置和使用过程非常繁琐，因此很多人会尽量避免使用。最后，张量并行在带宽需求和同步量方面成本极高，但其最大优势是完全不影响批次大小——这是唯一不占用全局批次资源的并行策略。我们必须平衡多种有限资源：内存是其一，带宽是其二，同步成本是其三，而批次大小本身也是一种资源。

## 段落 86

**英文**: We have bandwidth and compute, which is another resource, and then we have batch size, which is kind of an unconventional resource, but one that you should really think of as a limited thing that you can spend on different aspects of these to improve your efficiency. And there's a very nice TPU parallelism or TPU book, let's call it, from Google that I referred to last week, but also actually they have a really nice parallelism section. And they have this great figure that I wanted to show you before I moved on to some of the examples. So the key quantity, as I was saying before, is the batch size. And depending on the ratio of batch size to the number of GPUs you have, different kinds of parallelism become optimal. And so they use sort of certain formula on how much communication and computation you end up doing for each of these models. So this is a simplified formula to sort of generate this plot. And you can kind of see if your batch size is too small, you have lots of GPUs and really tiny batch sizes, then there is no way for you to be efficient, right? You're always communication bound, which is this bottom half here. And in fact, you're spending most of your time on communication. As you sort of get more and more batch size, eventually you can get to a point where if you mix both FSDP, so 0 stage 3 and MP, which in this case is tensor parallel, you can actually get basically to a place where your compute bound.

**中文**: 我们拥有带宽和计算能力，这是另一种资源，此外还有批处理大小——这虽然是一种非传统资源，但你确实应将其视为有限的资源，可以通过在不同方面进行调配来提升效率。谷歌有一份非常出色的TPU并行处理指南（我上周提到过），其中确实包含了很棒的并行处理章节。在进入具体示例之前，我想先展示他们制作的一个精彩图表。正如我之前强调的，关键变量在于批处理大小。根据批处理大小与GPU数量的比例，不同并行策略会达到最优效果。他们通过特定公式计算每种模型所需的通信与计算量，这张图表便是基于简化公式生成的。可以明显看出：如果批处理大小过小，而GPU数量过多，效率必然无法提升——此时系统完全受通信限制（即图表下半部分），大部分时间都消耗在通信上。随着批处理规模逐步扩大，当结合使用FSDP（零阶段3）与MP（此处指张量并行）时，最终能达到计算资源成为主导限制因素的理想状态。

## 段落 87

**英文**: So now you're not spending sort of wasting your flops waiting for communication. And then finally, if you get to a point where your batch sizes are big, then you can just get away with pure data parallel. Like pure FSDP is going to get you into a regime where the time you spend doing computation. is higher than the time you spend in communication. So if your batch size is big enough, you can just get away with FSDP. So this is kind of a cool illustration of this idea of why would you mix these, when would you mix these, why is batch size a resource? Hopefully this kind of shows you in a very visual way what this is. Okay. And so when you put these all together, you end up with what people call 3D or 4D parallelism. I think I've heard the term 5D parallelism recently. I wasn't quite sure what the fifth dimension was yet.

**中文**: 所以现在你不会在等待通信时浪费计算能力。最后，如果你的批处理规模足够大，那么仅采用纯数据并行就足够了。比如纯FSDP（完全分片数据并行）可以让你进入一个状态，即计算时间超过通信时间。因此，只要批处理规模足够大，仅用FSDP就能解决问题。这很好地说明了为什么要混合使用这些方法、何时混合使用，以及为什么批处理规模是一种资源。希望这能以非常直观的方式展示这一点。当你把这些方法结合起来，就形成了所谓的3D或4D并行。最近我甚至听到了5D并行的说法，但还不确定第五个维度具体指什么。

## 段落 88

**英文**: I'll have to read up on that. But now you can put it all together, the different dimensions of parallelism. And this is a really simple rule of thumb. I originally sort of looked it up and put this together last year, but turns out it's still the same this year. So you can sort of follow this now. So the first thing you have to do is you have to fit your model and your activations in. memory. If you don't do that, you just cannot train. So this is a requirement. So until your model fits in memory, we have to split up our model.

**中文**: 我得好好研究一下这个。但现在你可以把所有东西整合起来，看看并行的不同维度。这里有一个非常简单的经验法则。我去年大致查了一下资料并整理出来，结果发现今年依然适用。所以你现在可以参考这个。首先，你必须确保你的模型和激活值都能放进内存里。如果做不到这一点，训练就无从谈起。所以这是一个硬性要求。在模型能完全装入内存之前，我们必须对模型进行分割。

## 段落 89

**英文**: So we're going to do tensor parallelism. And we know that up to the number of GPUs per machine, that's very efficient, that's very fast. So we're going to do tensor parallel up to that point. Now after that, depending on things like your desire to deal with pipeline parallel and or your bandwidth constraints, you're either going to use 0, 3 or pipeline parallel across the machines, right? Until you can fit your model in memory. Now after that point, well, until you sort of run out of GPUs, you can now run the whole thing. And your only goal is to increase the amount of total flops that you have on hand. So you're going to scale the rest of the way with data parallel, because data parallel. is, it works well on low bandwidth communication channels and it is very simple, right? And so that's going to give you a way of sort of using all of your GPUs. Now if your batch size is really small, then there is a way of trading batch sizes for better communication efficiency. If you haven't consumed all of your batch sizes, a resource, what you can do is you can use gradient accumulation on your devices, right? And that will let you basically have effectively larger batch sizes, even if your memory constraint.

**中文**: 因此我们将采用张量并行技术。我们知道，在单台机器的GPU数量范围内，这种方法效率极高、速度极快。所以我们将在这个范围内实施张量并行。接下来，根据你对流水线并行的需求或带宽限制，你可能会在机器间采用零并行、三维并行或流水线并行，对吧？直到你的模型能够完全载入内存为止。此后，在GPU资源耗尽之前，你都可以完整运行整个流程。此时你的唯一目标就是增加可用的总浮点运算量。所以剩余阶段将通过数据并行进行扩展，因为数据并行在低带宽通信环境下表现良好，且实现简单，对吧？这样你就能充分利用所有GPU资源。如果你的批处理规模确实很小，还有一种方法可以通过调整批处理规模来提升通信效率。如果尚未耗尽批处理规模这一资源，你可以在设备上使用梯度累积技术，对吧？这能让你在内存限制下仍能获得更大的有效批处理规模。

## 段落 90

**英文**: And that will let you trade your batch size for better communication efficiency, since you're synchronizing less often across the machines. Right, simple rule of thumb, this will let you train models with reasonable efficiency, no matter what you're doing. And so to sort of make this concrete, I'll talk through a few examples at the very end here. A flash through, both this really lovely paper back in 2021 from Megatron LM, basically showing you exactly these things in pictures and also a lot of ablations, as well as some. of the models from last year. So this is a big table of how they trained models going from 1. 7 billion parameters to 1 trillion parameters. And they get great utilization on all of these, right? You see percentage of theoretical peak flops that they get and it ranges from 40 to 52%. It's pretty good, right? And so you can see, TensorFlow parallel starts at one, and then they eventually go up to eight, and then it caps out at eight, right?. And they, so they are using TensorFlow parallelism first.

**中文**: 这样你就能用批量大小来换取更高的通信效率，因为减少了机器间的同步频率。没错，一个简单的经验法则：无论你在做什么，这都能让你以合理的效率训练模型。为了让这一点更具体，我最后会举几个例子快速说明。回顾一下，既有2021年Megatron LM那篇非常出色的论文，基本上用图表直观展示了这些内容，还包含了许多消融实验，以及去年的一些模型。这里有一个大表格，展示了他们如何训练从17亿参数到1万亿参数的模型。他们在所有这些模型上都获得了很高的利用率，对吧？你可以看到他们达到的理论峰值浮点运算百分比，范围在40%到52%之间。相当不错，是吧？所以你可以看到，张量并行从1开始，最终增加到8，然后上限就是8了，对吧？他们首先使用的是张量并行。

## 段落 91

**英文**: And then pipeline parallel stays at one, but once the models get big enough, they can't fit these big models, so pipeline parallel has to increase in order to compensate. And then the data parallel size basically starts out as big as possible and then slowly kind of goes down, right? Because as we increase the amount of pipeline parallel, this is now consuming in some sense the batch sizes. And so you can't have effectively as big of a batch size if they're being used in some. sense for pipeline parallel. Okay, so careful 3D parallelism is going to give you sort of linear gains in aggregate flops. So you see if you do careful 3D parallelism, you see sort of very flat overall achieved flops per GPU, which is giving you, you know, if you add more GPUs, linear scaling in the total aggregate throughput, that's great. TensorFlow parallel 8 is often optimal. You see this is the pipeline parallel size and the tensor parallel size. You see going to 8, 8 with a batch size of 30, sorry batch size of 128 is optimal, even if you have a smaller batch size, you know, tensor parallel size of 8 remains optimal. And activation recomputation enables larger batch sizes.

**中文**: 接着，流水线并行保持为一，但一旦模型变得足够大，它们就无法容纳这些大型模型，因此流水线并行必须增加以作补偿。而数据并行规模基本上从尽可能大开始，然后慢慢减小，对吧？因为随着我们增加流水线并行的数量，这在某种意义上会消耗批处理大小。所以，如果批处理大小在某种程度上被用于流水线并行，你就无法有效地拥有那么大的批处理大小。好的，因此精细的3D并行会在总体浮点运算上带来线性增益。所以你会看到，如果进行精细的3D并行，每个GPU实现的总体浮点运算非常平稳，这意味着如果你增加更多GPU，总吞吐量会线性扩展，这很棒。张量并行大小为8通常是最优的。你会看到这是流水线并行大小和张量并行大小。当批处理大小为128时，选择8和8是最优的，即使批处理规模较小，张量并行大小为8仍然是最优的。而激活重计算则支持更大的批处理大小。

## 段落 92

**英文**: And remember that, you know, larger batches can in turn help you sort of mask overhead for pipeline parallel. So activation recomputation, even though it's more flops, can pay for itself, right? We've seen that story play out already in flash attention. All right, so the last part of this is recent language models, like what do they do?. So, you know, I've gone through a few papers to look at examples of what people's parallelization strategy is, OMO and the DOMA paper, they do FSDP for a 7 billion parameter model. DeepSeq, the first paper, the zero stage one with tensor sequence and pipeline parallel. This is, you know, the vanilla thing that I told you. V3 actually does something slightly different. They do 16 wave pipeline parallel, 64-way expert parallel, which is kind of like tensor parallel. And then zero stage one for their data parallelism strategy. E, which is another Chinese model, does once again, zero stage one tensor and pipeline parallel.

**中文**: 记住，较大的批次反过来可以帮助掩盖管道并行的开销。因此，激活重计算虽然需要更多浮点运算，但可以自我补偿，对吧？我们已经在Flash Attention中看到了这一点。好了，最后一部分是关于最近的语言模型，它们都做了些什么？我翻阅了几篇论文，查看了人们的并行化策略示例，OMO和DOMA论文中，他们为一个70亿参数的模型使用了FSDP。DeepSeq的第一篇论文采用了零阶段一，结合张量序列和管道并行。这就是我之前提到的基本方法。V3实际上做了一些略有不同的处理：他们采用16波管道并行、64路专家并行（类似于张量并行），然后在数据并行策略中使用零阶段一。另一个中文模型E再次采用了零阶段一张量和管道并行。

## 段落 93

**英文**: And E Lightning, because they're doing MOE's, replaces tensor parallelism with expert parallelism. The final thing, if you're interested in kind of state of the art, you know, distributed training with lots of details, Lama 3's report is actually really interesting to read. They have a lot of detail about how they do their networking, what sort of things happen. And you see sort of once again, the kinds of things I said before, you see a tensor parallel. of eight. You see CP or this is context parallel. This is only relevant for long context training, which is this very last step, so you can ignore that. And you got pipeline parallel and data parallel happening in these sort of first two phases. You can also even ignore the first stage here, because that's kind of the small batch size training that they did in order to be stable. And if you look at kind of their rationale for how they do their parallelism strategy,.

**中文**: 而E Lightning，由于采用了MOE（专家混合）技术，用专家并行替代了张量并行。最后，如果你对当前最前沿的技术感兴趣，比如包含大量细节的分布式训练，那么阅读Llama 3的报告会非常有意思。他们详细介绍了网络架构和具体操作。你会再次看到我之前提到的那些内容：张量并行设置为8，还有CP，也就是上下文并行。这仅适用于长上下文训练，也就是最后这个阶段，所以可以忽略不计。在前两个阶段中，则采用了流水线并行和数据并行。你甚至可以忽略这里的第一阶段，因为那是他们为了保持稳定性而进行的小批量训练。如果你仔细看他们制定并行策略的基本原理，

## 段落 94

**英文**: you see exactly what I had said before of basically, all right. You want to do TPCP, pipeline parallel and DP in that order in terms of the amount of bandwidth that you need, where data parallel can tolerate these like long network latencies because you can do the sort of asynchronous fetching of sharded model weights, right. And so they're using kind of the strategy that I told you in order to train some of the biggest models. The funny side note about Lama 3, and you may have heard this sort of in sort of not rumors, but sort of casual conversation with your friends, is, you know, there's lots. of GPU failures when you train models at a huge scale, right. They had 148 interruptions from faulty GPUs, totaling about 30% of the total interruptions that they had. They had things like, you know, unplanned maintenance of machines, and that was 32 different things, you know, 32 instances of interruptions for their training. And so when you're training a model this big, you know, I've talked about the algorithms, but you also need kind of fault tolerant architectures to be able to deal with these kinds of things. And I've also heard, you know, various stories of people saying that even scarier thing is not actually explicit model failures, but actually data corruption. Like the GPUs can silently fail on you and give you garbage data completely ruining your run.

**中文**: 你完全看到了我之前所说的，基本上，就是那样。在所需带宽方面，你希望按照TPCP、流水线并行和数据并行的顺序来操作，因为数据并行可以容忍较长的网络延迟，毕竟你可以异步获取分片的模型权重，对吧。所以他们采用了我告诉你的那种策略来训练一些最大的模型。关于Llama 3有个有趣的插曲，你可能已经从朋友间的闲聊中有所耳闻，那就是在大规模训练模型时，GPU故障频发。他们因故障GPU遭遇了148次中断，占总中断次数的约30%。此外，还有机器计划外维护等问题，共发生了32次不同的中断事件。所以，训练如此庞大的模型时，我虽然讨论了算法，但你也需要具备容错架构来应对这类问题。我还听过各种说法，有人指出更可怕的其实不是显性的模型故障，而是数据损坏。比如GPU可能悄无声息地失效，给你提供垃圾数据，彻底毁掉你的训练运行。

## 段落 95

**英文**: OK. And then the last one example is for GEMMA 2. And I wanted to end on this because this is a TPU example. You know, they do 0, 3, which is roughly FSTP. And then they do model parallelism and data parallelism, right. And so here, you know, as I said before, the sort of TPUs allows them to sort of stretch model parallelism a little bit further. OK. So putting it all together, scaling beyond a certain point is going to require sort of multi-GPU, multi-no parallelism. There's no single solution, right. So you want to combine all three approaches to sort of leverage strength.

**中文**: 好的。那么最后一个例子是关于GEMMA 2的。我想以此结束，因为这是一个TPU的例子。他们采用了0和3的配置，大致相当于FSTP。然后他们实施了模型并行和数据并行，对吧。正如我之前所说，TPU让他们能够在一定程度上进一步扩展模型并行。总之，要超越某个规模点，就需要多GPU、多节点并行。没有单一的解决方案，对吧。因此，你需要结合这三种方法，以发挥各自的优势。

## 段落 96

**英文**: And then there's simple and interpretable rules of thumb for how you might execute this parallelism in practice. Right. Thank you.

**中文**: 接下来还有一些简单易懂的实用法则，指导你在实践中如何执行这种并行处理。好的，谢谢。

---

*共 96 个段落，953 句话*
