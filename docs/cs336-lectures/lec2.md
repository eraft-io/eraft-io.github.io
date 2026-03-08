# Lec. 2： Pytorch, Resource Accounting

生成时间: 2026-03-08 14:57:47

---

## 段落 1

**英文**: Okay, so last lecture, I gave an overview of language models and what it means to build them from scratch and why we want to do that. I also talked about tokenization, which is going to be the first half of the first assignment. Today's lecture will be going through actually building a model. We'll discuss the primitives in PyTorch that are needed. We're going to start with tensors, build models, optimizers, and training loop. And we're going to place close attention to efficiency in particular how we're using resources, both memory and compute. Okay, so to motivate things a bit, here's some questions. These questions are going to be answered by napkin mats, so get your napkins out. So how long would it take to train a 70 billion parameter dense transformer model on 15 trillion tokens on 1,024 H100? Okay, so I'm just going to sketch out the sort of give you a flavor of the type of things that we want to do. Okay, so here's how you go about reasoning it.

**中文**: 好的，上一讲中，我概述了语言模型，介绍了从零开始构建语言模型的含义及其原因。我还讲解了分词（tokenization），这将是第一次作业前半部分的内容。今天的课程将实际动手构建一个模型，介绍构建过程中所需的 PyTorch 基础组件：我们将从张量（tensors）入手，逐步构建模型、优化器及训练循环，并特别关注效率问题——尤其是内存与计算资源的使用方式。为帮助大家理解背景，我们先提出几个问题。这些问题将通过“餐巾纸推演”（napkin math）来解答，请大家准备好餐巾纸。例如：在 1024 块 H100 GPU 上，训练一个参数量为 700 亿的稠密 Transformer 模型、数据量达 15 万亿词元（tokens），需要多长时间？接下来，我将简要勾勒出这类问题的分析思路，让大家对我们将要开展的工作类型有个直观感受。下面，我们就来梳理推理过程。

## 段落 2

**英文**: You count the total number of flops needed to train. So that's six times the number of parameters times the number of tokens. Okay, and where does that come from? That will be what we'll talk about in this lecture. You can look at the promised number of flops per second that H100 gives you. The MFU, which is something we'll see later. Let's just set it to 0. 5. And you can look at the number of flops per day that your hardware is going to give you at this particular MFU. So 1,024 of them for one day. And then you just divide the total number of flops you need to train them all by the number of flops that you're supposed to get.

**中文**: 你需要计算训练所需的总浮点运算次数（flops），即参数量乘以词元数再乘以6。好的，这个公式从何而来？这正是本节课将要讲解的内容。你可以参考H100显卡所承诺的每秒浮点运算次数（flops），以及稍后会介绍的MFU（模型浮点利用率），此处我们暂且将其设为0.5。接着，你可据此算出在该MFU下，你的硬件单日所能提供的浮点运算次数——例如，1024块H100显卡运行一天所能提供的总flops。最后，只需用训练所需的总flops除以硬件单日所能提供的flops即可。

## 段落 3

**英文**: Okay, and that gives you about 144. Okay, so this is very simple calculations at the end of the day. We're going to go through a bit more where these numbers come from. And in particular, where the six times number of parameters times number of tokens comes from. Okay, so here's the question. What is the largest model you can train on H800, H100 using Adam W if you're not being to clever? Okay, so H100 has 80 gigabytes of HBM memory. The number of bytes per parameter that you need for the parameters, the gradients, optimizer state is 16. And we'll talk more about where that comes from. And the number of parameters is basically total amount of memory divided by the number of bytes you need per parameter. And that gives you about 40 billion parameters.

**中文**: 好的，这样算下来大约是144。最终来看，这些计算其实非常简单。接下来我们会进一步解释这些数字的来源，尤其是“6×参数量×token数”这一项的由来。那么问题来了：若不采用任何优化技巧，在H800或H100上使用AdamW优化器可训练的最大模型规模是多少？H100拥有80GB的高带宽内存（HBM），而每个参数在存储模型参数、梯度及优化器状态时所需字节数为16字节——我们稍后会详细说明该数值的来源。因此，参数总量基本等于总内存容量除以每个参数所需的字节数，由此可得约400亿个参数。

## 段落 4

**英文**: And this is very rough because it doesn't take you into a good activation, which depends on batch size and sequence length, which I'm not really going to talk about, but will be important for assignment one. Okay, so this is rough back-and-vote calculation. And this is something that you're probably not used to doing. You're just implementing the model, you train it, and what happens happens. But remember that efficiency is the name of a game. And to be efficient, you have to know exactly how many flops you're actually expending. Because when these numbers get large, these directly translate into dollars, and you want that to be as small as possible. Okay, so we'll talk more about the details of how these numbers arise. We will not actually go over the transformer. So Tatsu is going to talk over the conceptual overview of that next time.

**中文**: 而且这非常粗略，因为它并未将你带入一个良好的激活状态——而该状态取决于批量大小和序列长度，这部分我暂不展开讨论，但在第一次作业中会很重要。好的，因此这是一种粗略的反向传播计算。而这可能是你们不太习惯的操作：你们通常只是实现模型、训练模型，然后任其自行运行。但请记住，效率才是关键。而要实现高效，就必须精确知道实际消耗了多少浮点运算（FLOPs），因为当这些数值变得很大时，它们会直接转化为美元成本，因此你们希望这一成本尽可能小。好的，接下来我们将更详细地探讨这些数值的来源。我们不会实际讲解Transformer本身，因此下次将由Tatsu为大家介绍其概念性概览。

## 段落 5

**英文**: And there's many ways you can learn about transformer if you haven't already looked at it. If you do assignment one, you'll definitely know what a transformer is. And the handout actually does a pretty good job of walking through all the different pieces. There's a mathematical description. If you like pictures, there's pictures. There's a lot of stuff you can look online. So, but instead, I'm going to work with simpler models and really talk about the primitives and the resource accounting piece. Okay, so remember last time I said what kinds of knowledge can you learn?. So mechanics, in this lecture, it's going to be just PyTorch and understanding how PyTorch works at a fairly primitive level. So that will be pretty straightforward.

**中文**: 如果你尚未了解过Transformer，那么有很多途径可以学习它。如果你完成第一项作业，就一定会明白什么是Transformer。讲义本身也很好地逐一讲解了其各个组成部分：既有数学描述，也有图示（如果你喜欢图示的话），网上还有大量相关资料可供查阅。但在此，我将采用更简单的模型，重点讲解基本原理以及资源核算部分。好的，还记得上次我提到的“你能学到哪些类型的知识”吗？本节课所讲的“机制”部分，仅限于PyTorch及其在基础层面的工作原理，因此内容会相当直接明了。

## 段落 6

**英文**: Mindset is about resource accounting, and it's not hard. It's just you just have to do it. And intuitions, unfortunately, this is just going to be broad strokes for now. Actually, there's not really much intuition that I'm going to talk about in terms of how anything we're doing translates to good models. This is more about the mechanics and mindset. Okay, so let's start with memory accounting. And then I'll talk about computer accounting and then we'll build up bottom up. Okay, so the best place to start is a tensor. So tensors are the building block for storing everything in deep learning. Parameters, gradients, optimizers, data, data, activation, there's sort of these atoms.

**中文**: 思维模式关乎资源核算，这并不难，只需付诸实践即可。至于直觉——很遗憾，目前我们只能泛泛而谈。实际上，我几乎不会就当前所做工作如何转化为优质模型这一问题展开任何直观解释；重点在于具体操作机制与思维方式。好，我们先从内存核算讲起，接着讨论计算核算，然后自下而上逐步构建。那么，最佳切入点是张量：张量是深度学习中存储一切信息的基本单元，包括参数、梯度、优化器状态、数据（训练数据与验证数据）、激活值等，它们构成了整个系统的基本“原子”。

## 段落 7

**英文**: You can read lots of documentation about them. You're probably very familiar with how to create tensors. There's creating tensors in different ways. You can also create a tensor and not initialize it and use some special initialization for the parameters if you want. Okay, so those are tensors. So let's talk about memory and how much memory tensors take up. So every tensor that will probably be interested in is sort of a floating point number. And so there's many ways to represent floating point. So the most default way is float 32. And float 22 has 32 bits.

**中文**: 你可以阅读大量关于它们的文档。你可能非常熟悉如何创建张量。创建张量的方式多种多样。你也可以先创建一个未初始化的张量，然后根据需要对参数采用特定的初始化方式。好了，以上就是关于张量的内容。接下来我们谈谈内存，以及张量所占用的内存大小。我们通常关注的张量元素基本都是浮点数，而浮点数有多种表示方式。其中最常用的默认格式是 float32（32 位浮点数），即每个浮点数占用 32 位。

## 段落 8

**英文**: They're allocated one for sine, eight for exponent, and 23 for the fraction. So exponent gives you dynamic range and fraction gives you different, basically, specialized different values. So float 32 is also known as FP32 or single precision is sort of the gold standard in computing. Some people also refer to float 30 who has full precision. That's a little bit confusing because full is really depending on who you're talking to. If you're talking to a scientific computing person, they will kind of laugh at you when. you say float 32 is really full because they'll use float 64 or even more. But if you're talking to a machine learning person float 32 is the max you ever probably need to go because deep learning is kind of sloppy like that. Okay, so let's look at the memory. So the memory is very simple.

**中文**: 其中1位分配给符号位，8位分配给指数位，23位分配给尾数位。因此，指数位决定了动态范围，而尾数位则决定了精度，即能够表示的不同数值。float32也被称为FP32或单精度浮点数，是计算领域的“黄金标准”。有些人还会提到“float30”，意指具备完整精度，但这略显混淆，因为所谓“完整”实际上取决于具体语境：若与科学计算领域的专家交流，他们听到你说float32是“完整精度”时可能会一笑置之，因为他们通常使用float64甚至更高精度；但若与机器学习领域的专家交流，则float32很可能就是你实际所需的最高精度，因为深度学习本身对精度的要求并不苛刻。好，接下来我们来看内存。内存结构非常简单。

## 段落 9

**英文**: It's determined by the number of values you have in your tensor and the data type of each value. Okay, so if you create a torched tensor of 4 by 8 matrix, the default will give you a. type of float 32. The size is 4 by 8 and the number of elements is 32. Each element size is 4 bytes. 32 bits is 4 bytes. And the memory usage is simply the number of elements times the number of size of each element and that will give you 128 bytes. So this should be pretty easy. And just to give some intuition, if you get one matrix in the f4 layer of GPT3 is this. number by this number and that gives you 2.

**中文**: 它由张量中值的数量以及每个值的数据类型决定。好的，例如，如果你创建一个 4×8 的 PyTorch 张量，其默认数据类型为 float32；尺寸为 4×8，元素总数为 32；每个元素占 4 字节（32 位等于 4 字节）；内存占用量即为元素总数乘以单个元素大小，结果为 128 字节。因此这应该非常简单。再直观地说明一下：GPT-3 的 f4 层中某一层矩阵的尺寸为“该数值”乘以“该数值”，结果为 2。

## 段落 10

**英文**: 3 gig bytes. So that's one matrix. These matrices can be pretty big. So float 32 is a default. But of course these matrices get big so you actually want to make them smaller so you use less memory. And also it turns out if you make them smaller, you also make it go faster too. So another type of representation is called float 16. And as the name suggests, it's 16 bits where both x1 and the fraction are shrunk down from 8 to 5 and 23 to 10. So this is known as half precision and it cuts down half the memory and that's all great except for the dynamic range for these float 16 isn't great. So for example, if you try to make a number like 10E1E minus 8 in float 16, it basically rounds down to 0 and you get under flow.

**中文**: 3吉字节。因此，这是一个矩阵。这些矩阵可能非常大。float32是默认格式，但显然，由于这些矩阵体积庞大，我们实际上希望将其缩小以节省内存。此外，事实证明，缩小矩阵还能提升运算速度。另一种表示方法称为float16（半精度浮点数），顾名思义，它仅占用16位：其中指数位从8位缩减为5位，尾数位从23位缩减为10位。这种格式被称为半精度，可将内存占用减半，这固然很好，但float16的动态范围较差。例如，若尝试在float16中表示10⁻⁸这样的数值，其结果基本会向下舍入为0，从而导致下溢。

## 段落 11

**英文**: So the float 16 is not great for representing very small numbers or very big numbers as a matter of fact. So if you use float 16 for training, for small models it's probably going to be okay but for large models when you're having lots of matrices and you can get instability or under flow or overflow and bad things happen. So one thing that has happened which is nice is there's been another representation of B float 16 which stands for brain float. This was developed in 2018 to address the issue that for deep learning we actually care about dynamic range more than we care about this fraction. So basically BF16 allocates more to the exponent and less to the fraction. So it uses the same memory as float 16 but it has a dynamic range of float 32. So that sounds really good and it actually catches that resolution which is determined by the fraction is worse but this doesn't matter as much for deep learning. So now if you try to create a tensor with 1E minus 8 in BF16 then you get something that's not 0. So you can divin into the details. I'm not going to go into this but you can stare out to the actual full specs of all the different flowing points operations.

**中文**: 因此，float16 实际上并不擅长表示极小或极大的数值。若在训练中使用 float16，对于小型模型可能尚可，但对于大型模型，由于涉及大量矩阵运算，容易出现不稳定性、下溢或上溢等问题，从而引发严重后果。值得庆幸的是，业界已推出另一种名为 BF16（Brain Floating Point 16）的表示方法。该格式于 2018 年提出，旨在解决深度学习中更关注动态范围而非精度（即尾数位数）这一实际需求。BF16 将更多位数分配给指数部分，而减少尾数部分的位数；其内存占用与 float16 相同，但动态范围却等同于 float32。这听起来非常理想——尽管其精度（由尾数决定）有所下降，但这对深度学习而言影响不大。例如，若尝试用 BF16 创建一个值为 1e−8 的张量，结果将不为零。您可进一步深入探究相关细节（此处不再展开），也可查阅各类浮点运算的完整技术规范。

## 段落 12

**英文**: So BF16 is basically what you will typically use to do computations because it's sort of good enough for people for a computation. It turns out that for storing optimizer states and parameters you still need float 32 for otherwise your training will go haywire. So if you're bald so now we have something called FP8 or 8bit and as the name suggests this is development 2022 by Nvidia so now they have essentially if you look at FPMBF16 it's like this and FPMBF12 you really don't have that many bits to store stuff. So it's very crude. There's two sort of variants depending on if you want to have more resolution or more dynamic range. And I'm not going to say too much about this but FP8 is supported by H100 it's not really available on previous generation. But at a high level you know training with float 32 which is I think you know is on what you would do if you're not trying to optimize you know too much and it's sort of safe. It requires more memory. You can go down to FP8 or BF16 but you can get some instability. Basically I don't think you would probably want to use a float 16 at this point for deep learning.

**中文**: 因此，BF16 基本上是你通常用于计算的格式，因为其精度对大多数计算任务而言已足够。但事实证明，在存储优化器状态和模型参数时，你仍需使用 float32，否则训练过程将变得混乱失常。目前还出现了所谓 FP8（即 8 位浮点数）格式，顾名思义，它由英伟达于 2022 年推出。若对比 FP8、BF16 和 FP12，你会发现 FP8 可用的位数极少，因而精度非常粗略；它主要有两种变体，分别侧重更高分辨率或更宽动态范围。关于这一点我就不多作展开，但需指出：FP8 仅受 H100 显卡支持，上一代硬件并不支持。总体而言，使用 float32 进行训练——这大概是你在不刻意追求极致优化时所采用的稳妥方案——虽需更多内存，但较为安全；而转向 FP8 或 BF16 虽可节省资源，却可能带来一定训练不稳定性。目前，我认为在深度学习中基本不应再使用 float16。

## 段落 13

**英文**: You can become more sophisticated by looking at particular places in your pipeline either for for pass or backward pass or optimizers or gradient accumulation and really figure out what the minimum precision you need at this particular places and that's called gets into kind of mixed precision training. So for example some people like to use float 32 for the you know the attention to make sure that doesn't kind of you know get messed up for simple fee for passes with map walls. BF16 is fine. Okay pause a bit for questions. So we talked about tensors and we looked at depending on how what representation how much storage they take. Yeah. So the question is when would you use float 32 or BF16? I don't have time to get into the exact details and it's sort of very depending on the model size and everything but generally for the parameters and optimizers say you use float. 32. You can think about BF16 as something that's more transitory. Like you basically take your parameters you cast it to BF16 and you kind of run ahead with that model but then the thing that you're going to accumulate over time you want to have higher precision.

**中文**: 您可以通过考察模型训练流程中的特定环节（例如前向传播、反向传播、优化器或梯度累积）来进一步提升精度管理能力，从而精准确定这些环节所需的最低数值精度，这种方法即所谓“混合精度训练”。例如，一些研究者倾向于在注意力机制中使用 float32，以确保其在简单前向传播过程中不会因精度不足而出现异常；而 BF16 则通常已足够。好了，稍作停顿，大家有问题可以提问。我们此前讨论了张量，并分析了不同表示方式对存储空间占用的影响。是的，那么问题来了：何时该选用 float32，何时又该选用 BF16？由于时间关系，我无法深入展开具体细节——这实际上高度依赖于模型规模等各项因素；但总体而言，参数和优化器通常采用 float32；而 BF16 可视作一种临时性精度格式：您可将参数转换为 BF16 后进行模型运算，但需长期累积的量（如梯度累加值）则必须保持更高精度。

## 段落 14

**英文**: Yeah. Okay so now let's talk about compute. So that was memory. So compute obviously depends on what the hardware is. By default tensors are stored in CPU. So for example if you just impite torch say x equals torch at 0 32 32 then it will put it on your CPU. It will be in the CPU memory. Yeah of course that's no good because if you're not using your GPU then you're going to be orders of magnitude to slow. So you need to explicitly say in pytorch that you need to move it to the GPU and this. is actually just to make it very clear in pictures.

**中文**: 是的。好的，现在我们来谈谈计算。刚才讲的是内存。显然，计算性能取决于硬件配置。默认情况下，张量存储在CPU上。例如，如果你只是简单地在PyTorch中执行“x = torch.zeros(32, 32)”，它就会将张量放在你的CPU上，即存于CPU内存中。当然，这并不理想，因为如果不使用GPU，你的运行速度将慢几个数量级。因此，你必须在PyTorch中显式地指定将张量移至GPU——而这一点，我们接下来会通过图示来清晰说明。

## 段落 15

**英文**: There's a CPU, a has RAM and that has to be moved over to the GPU. There's a data transfer which is caught which takes some work. Take some time. So whenever you have a tensor in pytorch you should always keep in your mind where is this residing because just looking at the variable or just looking at the code you can't always tell. And if you want to be careful about computation and data movement you have to really know. where it is. You can probably do things like assert where it is and various places of code just to document or be sure. So let's look at what hardware we have. So in this case we have one GPU. This was run on the H100 cluster that you guys have access to.

**中文**: 这里有一个CPU，还有一个RAM，而数据必须从RAM转移到GPU。这一数据传输过程会带来额外开销，耗费一定时间。因此，每当在PyTorch中使用张量（tensor）时，你都应时刻牢记该张量实际驻留在何处——仅凭变量名或代码本身，并不能总是明确判断其位置。若你想精确控制计算过程和数据移动，就必须确切知晓张量所在的位置。你甚至可以在代码的多个位置添加断言（assert）来检查其位置，以起到文档说明或确保正确性的作用。接下来，我们来看一下当前可用的硬件配置：本例中仅有一块GPU，运行环境为你们可访问的H100集群。

## 段落 16

**英文**: And this GPU is a H100, 80 gigabytes of high bandwidth memory. It gives you the cache size and so on. So if you have, remember the X is on CPU. You can move it just by specifying 2 which is a kind of a general pytorch function. You can also create a tensor direct line in GPU so you don't have to move it at all. If everything goes well, I'm looking at the memory allocated before and after. The difference should be exactly 32 by 32 matrices of 4 byte floats. So it's a 192. So this is a sanity check that the code is doing what is advertised. OK, so now you have your answers on the GPU.

**中文**: 该GPU为H100，配备80GB高带宽内存，可显示缓存大小等信息。请注意，此前的张量X位于CPU上；您只需指定设备编号2（一种通用的PyTorch函数），即可将其迁移至GPU。您也可直接在GPU上创建张量，从而完全避免数据迁移。若一切正常，我将对比迁移前后的内存占用量，其差值应恰好等于一个32×32的单精度浮点数矩阵所占内存（即32×32×4字节=4096字节）。此处的“192”应为笔误，实际应为4096；该步骤是用于验证代码功能是否符合预期的合理性检查。好了，现在您的计算结果已位于GPU上。

## 段落 17

**英文**: What do you do? So there's many operations that you'll be needing for assignment one and in general to do any deep learning application. And most sensors you just create by performing operations on other tensors. And each operations has some memory and compute footprints. So let's make sure we understand that. So first of all, what is actually a tensor in pytorch? Tensors are a mathematical object. In pytorch, they're actually pointers into some allocated memory. So if you have, let's say, a matrix, 4x4 matrix, what it actually looks like is a long array. And what the tensor has is metadata that specifies how to get to address into that array. And the metadata is going to be two numbers, a stride for each or actually one number per dimension of the tensor. In this case, because there's two dimensions, it's stride zero and stride one.

**中文**: 你做什么？因此，在完成第一次作业以及一般性地开展任何深度学习应用时，你将需要执行大量运算。而大多数张量都是通过对其他张量执行运算来创建的。每种运算都具有一定的内存和计算开销。因此，我们务必理解这一点。首先，在 PyTorch 中，张量究竟是什么？张量是一种数学对象；而在 PyTorch 中，它实际上是指向某块已分配内存的指针。例如，假设你有一个 4×4 的矩阵，其实际存储形式是一个长数组；而张量本身则包含元数据，用于指定如何从该数组中定位相应地址。这些元数据包括每个维度对应的步幅（stride），即每个维度一个数值。本例中由于是二维张量，因此包含 stride0 和 stride1 两个步幅值。

## 段落 18

**英文**: So it's stride zero specifies if you were in dimension zero to get to the next row, to increment that index, how many do you have to skip?. And so going down the rows, you skip four. So stride zero is four. And to go to the next column, you skip one. So stride one is one. Okay? So with that, you find element, let's say one two, one comma two. It's simply just multiply the indexes by the stride and you get to your index, which is six here. So that would be here or more here. Okay, so that's basically what's going underneath the hood for tensors. Okay, so this is relevant because you can have multiple tensors that use the same storage.

**中文**: 因此，“步幅零”表示：若你在第零维中，要到达下一行（即对该索引加一），需要跳过多少个元素？例如，沿行方向向下移动时，需跳过四个元素，故步幅零为四；而要到达下一列，则只需跳过一个元素，故步幅一为一。明白了吗？据此，我们来查找元素（例如第1行第2列，即索引1,2）：只需将各维度索引分别乘以其对应步幅再相加，即可得到该元素在底层存储中的线性索引——此处结果为六，即指向该位置（或更准确地说，指向此处）。以上便是张量内部运作的基本原理。这一点之所以重要，是因为多个张量可以共享同一块底层存储空间。

## 段落 19

**英文**: And this is useful because you don't want to copy the tensor all over the place. So imagine you have a two by three matrix here. Many operations don't actually create a new tensor, they just create a different view. And it doesn't make a copy, so you have to make sure that your mutations, if you start mutating one tensor, it's going to cause other one to mutate. Okay, so for example, if you just get row zero, okay?. So remember, y is this tensor, sorry, x is one, two, three, four, five, six. And y is x zero, which is just the first row. Okay, and you can sort of double check, there's this function in a row that says if you look at the underlined storage, whether these two tensors have the same storage or not. Okay, so this definitely doesn't copy the tensor, it just creates a view. You can get column one.

**中文**: 这很有用，因为你不希望到处复制张量。假设这里有一个 2×3 的矩阵，许多操作实际上并不会创建新的张量，而只是创建一个不同的视图，且不会进行复制。因此，你必须确保：如果你开始修改某个张量，这种修改也会影响其他与之共享存储的张量。例如，若仅获取第零行——注意，y 是这个张量（抱歉，x 才是 [1, 2, 3, 4, 5, 6] 构成的张量），而 y 是 x[0]，即第一行。你可以通过一个名为“storage”的属性来双重验证：查看这两个张量是否共享底层存储。显然，该操作绝不会复制张量，而只是创建一个视图。你也可以获取第一列。

## 段落 20

**英文**: This also doesn't copy the tensor. Oops, don't need to do that. You can call a view function which can take any tensor and look at it in terms of the different dimensions. Two by three, actually this should be maybe the other way around, as a three by two tensor. So that also doesn't change, do any copying. You can transpose, that also doesn't copy. And then, like I said, if you start mutating x, then y actually gets mutated as well. Because x and y are just pointers into the same underlined storage. Okay, so things are, one thing that you have to be careful of is that some views are contiguous, which means that if you run through the tensor, it's like just slight going through the array in your storage. But some are not.

**中文**: 这同样也不会复制张量。哦，其实不需要这么做。你可以调用一个视图函数，该函数可接受任意张量，并以不同维度的方式查看它。2×3——实际上，这里或许应该反过来，即作为3×2的张量。因此，这种方式同样不会发生任何复制操作。你还可以进行转置，这也无需复制。此外，如前所述，一旦你开始修改x，y实际上也会随之被修改，因为x和y只是指向同一底层存储空间的指针。好的，因此需要注意的一点是：某些视图是连续的（contiguous），这意味着当你遍历该张量时，就相当于直接按顺序遍历其底层存储数组；但有些视图则不是连续的。

## 段落 21

**英文**: So in particular, if you transpose it, now your, you know, what does it mean when you're transposing? So if you're sort of going down now, so you're kind of, if you imagine going through the tensor, you're kind of skipping around. And if you have a non-contiguous tensor, then if you try to further view it in a different way, then this is not going to work. Okay? So in some cases, if you have a non-contiguous tensor, you can make a contiguous first,. and then you can apply whatever viewing operation you want to it. And then in this case, x and y do not have the same storage because contiguous, in this case, makes a copy. Okay? So this is just ways of slicing and dicing a tensor. Views are free, so feel free to use them, define different variables to make it sort of easier to read your code. Because they're not allocating any memory, but remember that contiguous or reshape, which is basically contiguous. view, can create a copy, and so just be careful what you're doing. Okay, questions before moving on?.

**中文**: 因此，特别需要注意的是，如果你对张量进行转置操作，那么“转置”究竟意味着什么？此时，你实际上是沿着张量的维度向下遍历，即在张量内部以某种跳跃式的方式访问元素。如果该张量是非连续存储的（non-contiguous），那么你再尝试以其他方式对其进行视图（view）操作，就会失败。明白吗？  
因此，在某些情况下，若你面对一个非连续张量，可先将其转换为连续张量（contiguous），然后再对其执行任意所需的视图操作。此时，x 和 y 将不再共享同一块底层存储空间，因为 contiguous 操作在此情形下会创建一份副本。明白吗？  
以上只是对张量进行切片与重组（slicing and dicing）的不同方式。视图（view）操作是零开销的，因此请放心使用——你可以定义多个变量来提升代码的可读性。因为视图本身不分配任何内存；但请注意，contiguous 操作（或功能基本等价的 reshape 操作）以及 view 操作在某些条件下可能触发副本创建，因此务必谨慎对待你的操作。  
好，继续之前还有问题吗？

## 段落 22

**英文**: All right. So hopefully a lot of this will be review for those of you who have done a lot of PyTorch before, but it's helpful to just do a systematically and make sure we're on the same page. So here's some operations that do create new tensors, and in particular, element-wise operations, I'll create new tensors, obviously, because you need it somewhere else to store the new value. There's a triangular U is also an element operation that comes in handy when you want to create a causal attention mask, which you'll need for your assignment. But nothing is interesting here. Okay, so let's talk about map walls. So the bread and butter of deep learning is matrix multiplications. And I'm sure all of you have done a matrix multiplication, but just in case this is what it looks like, you take a 16 by 32 times a 32 by 2 matrix, you get a 16 by 2 matrix. But in general, when we do our machine learning application, all operations are you want to do in a batch. And in the case of language models, this usually means for every example in a batch and for every sequence in a batch, you want to do something.

**中文**: 好的。因此，对于之前已经大量使用过 PyTorch 的各位同学而言，本部分内容大多应属复习；但系统性地梳理一遍仍很有帮助，以确保我们理解一致。以下是一些会创建新张量的操作，尤其是逐元素运算（element-wise operations），显然会生成新张量，因为需要在别处存储计算所得的新值。此外，“上三角矩阵”（triangular U）也是一种实用的逐元素运算，常用于构建因果注意力掩码（causal attention mask），而你们的作业中就需要用到它。不过，这部分内容本身并无特别之处。好，接下来我们谈谈矩阵乘法（matmul）。矩阵乘法是深度学习的核心基础操作。相信大家此前都已接触过矩阵乘法，但为保险起见，这里再简要回顾一下：一个 16×32 的矩阵乘以一个 32×2 的矩阵，结果是一个 16×2 的矩阵。但在实际机器学习应用中，我们通常需对批量数据（batch）执行所有运算；而在语言模型中，这通常意味着需对批内每个样本、以及批内每个序列，分别执行相应操作。

## 段落 23

**英文**: Okay, so generally what you're going to have, instead of just a matrix, is you're going to have a tensor where the dimensions are typically batch sequence, and then whatever thing you're trying to do. In this case, it's a matrix for every token in your data set. So, you know, PyTorch is nice enough to make this work well for you. So when you take this for, you know, dimension tensor and this matrix, what actually ends up happening is that for every batch, every example and every token, you're multiplying these two matrices. Okay, and then the result is that you get your, your resulting matrix for each of the first two elements. So this is just like, there's nothing fancy going on, but this is just a pattern that I think is helpful to, you know, think about. Okay, so I'm going to take a little bit of a digression and talk about, INOPs. And so the motivation for INOPs is the following. So, you know, you know, you see things like this, where you take x and multiply by y transpose minus 2 minus 1. And you kind of look at this and you say, okay, what is minus 2? Well, I think that's the sequence.

**中文**: 好的，通常情况下，你面对的将不再只是一个矩阵，而是一个张量，其维度一般为“批大小×序列长度×其他所需维度”。在本例中，数据集中的每个词元都对应一个矩阵。PyTorch 很贴心地让这种运算能顺利进行：当你将这个高维张量与该矩阵相乘时，实际发生的是——对每个批次、每个样本、每个词元，分别执行这两个矩阵的乘法运算。最终结果是，你为前两个维度（即批大小和序列长度）中的每一个元素都得到一个输出矩阵。这其实并无特别精巧之处，但这一模式有助于我们理解与思考。

接下来，我稍作离题，谈谈 INOPs（内积操作）。INOPs 的提出动机如下：你常会见到类似这样的表达式——将向量 x 与向量 y 的转置相乘，再减去 2 和 1；看到这个式子，你可能会想：“这里的 −2 到底指什么？” 我认为它代表的是序列。

## 段落 24

**英文**: And then minus 1 is this hidden because you're indexing backwards. And it's really easy to mess this up because if you look at your code and you see minus 1 minus 2, you're kind of, if you're good, you write a bunch of comments, but then the comments are, can get out of date with the code and then you have a bad time debugging. So the solution is to use INOPs here. So this is inspired by an Einstein summation notation. And the idea is that we're just going to name all the dimensions instead of, you know, relying on indices, essentially. Okay, so there's a library called jacks typing, which is helpful for as a way to specify the dimensions in the types. So normally in PyTorch, you would just define write your code and then you were comment, oh, here's what the dimensions would be. So if you use jacks typing, then you have this notation where as a string, you're just write down what the dimensions are. So this is a slightly kind of more natural way of documenting. Now notice that there's no enforcement here, right? Because PyTorch types are sort of a little bit of a lie in PyTorch.

**中文**: 然后减1是因为你正在反向索引，因此该维度被隐藏了。这很容易出错，因为如果你查看自己的代码，看到“减1”“减2”，即使你写了很多注释来说明，这些注释也可能与代码脱节，导致调试时陷入困境。因此，解决方案是此处使用INOPs（索引命名操作）。这一思路源自爱因斯坦求和约定，其核心思想是直接为所有维度命名，而非依赖位置索引。目前有一个名为“jacks typing”的库，可帮助我们在类型定义中明确指定维度。通常在PyTorch中，我们仅编写代码，再通过注释说明各维度的含义；而借助jacks typing，我们可在字符串中直接写出维度名称，这种方式在文档记录上显得更自然。但请注意，此处并无强制约束机制——毕竟PyTorch中的类型系统在某种程度上只是形式上的“幌子”。

## 段落 25

**英文**: So you can use a checker, right? Yeah, you can raise a check, but not by default. Okay, so let's look at the, you know, INOPs. So INOPs is basically matrix multiply, occasion on steroids with good bookkeeping. So here's our example here. We have x, which is, let's just think about this as, you have a batch dimension, you have a sequence dimension, and you have four hidden. And y is the same size. So you originally had to do this thing. And now what you do instead is you basically write down the dimensions, names of the dimensions of the two tensors. So batch sequence one hidden, batch sequence two hidden, and you just write what you dimensions should appear in the output. So I write batch here because I just want to basically carry that over.

**中文**: 所以你可以使用检查器，对吧？是的，你可以启用检查功能，但默认情况下并不启用。好的，那么我们来看一下，你知道的，INOPs。INOPs 本质上就是矩阵乘法，是“带良好记账功能的矩阵乘法”的强化版。这里是我们给出的一个示例：我们有张量 x，可以简单地将其理解为具有批处理维度、序列维度以及四个隐藏单元；y 的尺寸与之相同。因此，你原本需要执行这样的操作；而现在，你只需直接写出两个张量各维度的名称即可：例如，“批处理、序列1、隐藏”和“批处理、序列2、隐藏”，然后仅需指明输出中应包含哪些维度。我在此写上“批处理”，是因为我只想简单地将该维度沿用至输出中。

## 段落 26

**英文**: And then I write sec1 and sec2. And notice that I don't write hidden, and any dimension that is not named in the output is just summed over. And any dimension that is named is sort of just iterated over. So once you get used to this, this is actually very, very helpful. I may maybe look, if you've seen this for the first time, it might seem a bit strange along, but trust me, once you get used to it, it'll be better than doing minus two minus one. If you're a little bit slicker, you can use dot dot dot to represent broadcasting over any number of dimensions. So in this case, instead of writing batch, I can just write dot dot dot. And this would handle the case where instead of maybe batch, I have batch one, batch two, or some other arbitrary long sequence. Yeah, question? So the question is, is a guaranteed a compile to something efficient?. I think the short answer is yes.

**中文**: 然后我写出 sec1 和 sec2。请注意，我并未写出 hidden，且输出中未命名的任何维度都会被直接求和；而输出中已命名的维度则仅作遍历处理。一旦你熟悉了这种写法，它实际上会非常、非常有用。如果你是第一次见到这种写法，可能会觉得有点奇怪，但请相信我，一旦你习惯了，它将比使用 -2、-1 这样的索引方式更优。如果你更熟练一些，还可以用省略号（...）来表示在任意数量的维度上进行广播操作。例如，在本例中，我无需显式写出 batch，而只需写成 ... 即可。这样就能应对诸如 batch1、batch2 或其他任意长度的批量维度序列等情况。  
好，有疑问吗？  
问题是：a 是否能保证被编译为高效代码？  
简短的回答是：是的。

## 段落 27

**英文**: I don't know if you have any nuances. So if you're out the best way to reduce the best order of dimensions to use, and then use that, if you're using within Torch Compile, only do that one time, and then reuse the same representation over again. It's going to be better than anything designed by him. Okay. So let's look at reduce. So reduce operates on one tensor, and it basically aggregates some dimension or dimensions of the tensor. So if you have this tensor, before you would write mean to sum over the final dimension, and now you basically say, actually, okay, so this replaces with sum. So reduce, and again, you say, hidden, and hidden is disappeared, disappeared, so which means that you are aggregating over that dimension. Okay, so you can check that this indeed kind of works over here. Okay, so maybe one final example of this is sometimes in a tensor, one dimension actually represents multiple dimensions, and you want to unpack that and operate over one of them and pack it back.

**中文**: 我不确定你是否了解其中的细微差别。因此，如果你要找出最佳的降维顺序并加以使用，那么在使用 Torch Compile 时，只需执行一次该操作，之后便可重复利用同一表示形式。这将比他设计的任何方法都更优。好的，我们来看一下 reduce 操作。reduce 作用于单个张量，其基本功能是对该张量的一个或多个维度进行聚合。例如，对于这个张量，过去你可能用 mean 或 sum 对最后一个维度求均值或求和；而现在，你只需简单地将其替换为 sum。即调用 reduce，并再次指定 hidden——此时 hidden 维度便消失了，这意味着你正在对该维度进行聚合。好的，你可以验证此处的操作确实有效。最后再举一个例子：有时张量中的某一维度实际上代表了多个维度，你希望将其展开，对其中某一个维度执行运算，然后再重新打包回去。

## 段落 28

**英文**: In this case, let's say you have batch sequence, and then this eight-dimensional vector is actually a flattened representation of number of heads times some hidden dimension. Okay, so, and then you have a way of vector that is needs to operate on that hidden dimension. So you can do this very elegantly using I-NOPs by calling rearrange, and this basically, you can think about it, we saw view before, it's kind of like kind of a, you know, fancier version, which basically looks at the same data, but, you know, differently. So here, it basically says this dimension is actually heads and hidden one, I'm going to explode that into two dimensions. And you have to specify the number of heads here, because there's multiple ways to split a number into, you know, two. Let's see, this might be a little bit long. Okay, maybe it's not worth looking at right now. And given that x, you can perform your transformation using I-N-SOM. So this is something hidden one, which corresponds to x, and then hidden one hidden two, which corresponds to w, and that gives you something hidden two. Okay, and then you can rearrange back.

**中文**: 在这种情况下，假设你有一个批量序列，而这个八维向量实际上是“头数 × 某一隐藏维度”所构成的展平表示。好的，接着你还有一个需要作用于该隐藏维度的向量。因此，你可以非常优雅地借助 einops 库中的 rearrange 函数来实现这一点；这本质上类似于我们之前见过的 view 操作，但功能更强大、更灵活——它本质上是在不改变底层数据的前提下，以不同方式重新组织数据的视图。此处，它明确指出：该维度实际上由“头数”和“隐藏维度一”共同构成，因此需将其拆分为两个独立维度。你必须在此处指定头数，因为一个整数可被分解为两个因子的方式可能有多种。嗯，这部分内容可能略显冗长，好吧，或许现在暂不细究。给定输入 x 后，你便可利用 einsum 对其执行变换操作：此处，“隐藏维度一”对应 x，“隐藏维度一 × 隐藏维度二”对应权重矩阵 w，最终输出为“隐藏维度二”。随后，你可再次使用 rearrange 将结果恢复为所需形状。

## 段落 29

**英文**: So this is just the inverse of breaking up. So you have your two dimensions and you group it into one. So that's just a flattening operation that's, you know, with everything, all the other dimensions kind of left alone. Okay, so there is a tutorial for this that I would recommend you go through and it gives you a bit more. So on, you don't have to use this because you're building it from scratch, so you can kind of do anything you want. But in the Simon one, we do give you guidance and it's something probably to invest in. Okay, so now let's talk about computation, no cost of tensile operations. So we introduce a bunch of operations and you know how much do they cost. So a floating point operation is any operation, floating point like addition or multiplication. These are the main ones that are going to, I think matter in terms of flop count.

**中文**: 因此，这仅仅是“拆分”操作的逆向过程。你拥有两个维度，然后将它们合并为一个维度。这仅仅是一种展平操作，其他所有维度则保持不变。好的，关于此操作，我们有一份教程，我建议你仔细阅读，它会为你提供更详细的信息。不过，由于你是从零开始构建模型，因此并不强制要求使用该操作，你可以自由发挥。但在Simon版本中，我们确实会为你提供相关指导，这可能是值得投入时间去学习的内容。好的，接下来我们来讨论计算量，即张量运算的开销。我们引入了一系列运算，并明确了它们各自的开销。浮点运算（FLOP）指任何浮点数运算，例如加法或乘法；这些是影响浮点运算次数（FLOP count）的主要运算类型。

## 段落 30

**英文**: One thing that is sort of a pepiva mine is that when you say flops, it's actually unclear what you mean. So you could mean flops with a lower case S, which stands for number of floating operations. This is measures amount of computation that you've done. Or you could mean flops also written with an uppercase S, which means floating points per second, which is used to measure the speed of hardware. So we're not going to, in this class, use uppercase S because I find out very confusing and just write slash S to denote that as floating point per second. Okay, so just to give you some intuition about flops, gbd3 took about 323 flops, gbd4 was 2e25 flops, speculation. And there was a US executive order that any foundation model with over 1e26 flops has to be reported to government, which now has been revoked. But the EU has still, they're going to still has a thumb thing that's hasn't the EU AI act, which is 1e25, which hasn't been revoked. So, you know, some intuitions A100 has a peak performance of 312 terraf flop per second. And H100 has a peak performance of 1979 terraf flop per second with sparsely and approximately 50% without.

**中文**: 一个容易引起混淆的点是：当你提到“flops”时，其具体含义其实并不明确。它可能指小写“s”的“flops”，即浮点运算次数（floating operations），用于衡量所执行的计算量；也可能指大写“s”的“FLOPS”，即每秒浮点运算次数（floating point operations per second），用于衡量硬件的运算速度。本课程中，我们不会采用大写“S”的写法，因其极易造成混淆；而是统一用“/s”来表示“每秒浮点运算次数”。  
为帮助大家建立直观认识：GPT-3 的训练约需 3.23×10²³ 次浮点运算；GPT-4 则约为 2×10²⁵ 次浮点运算（属推测值）。此前，美国曾发布一项行政命令，要求任何训练所需算力超过 10²⁶ 次浮点运算的基础模型必须向政府报备——但该命令现已撤销。而欧盟目前仍保留相关规定：根据《欧盟人工智能法案》，训练所需算力达 10²⁵ 次浮点运算及以上的模型仍须接受监管，该条款尚未被撤销。  
补充一些直观参考数据：A100 GPU 的峰值性能为 312 万亿次浮点运算每秒（TFLOPS/s）；H100 GPU 在稀疏计算模式下的峰值性能约为 1979 万亿次浮点运算每秒（TFLOPS/s），若不启用稀疏计算，其性能则约为该数值的 50%。

## 段落 31

**英文**: And if you look at, you know, the MVD has these specifications sheet sheets. So you can see that the flops actually depends on what you're trying to do. So if you're using bffp32, it's actually really, really bad. Like if you run fp32 on h100, you're not getting, it's orders of magnitude worse than if you're doing fp16 or, and if you're willing to go down to fp8, then it can be even faster. For the first time, I didn't realize, but there's an asterisk here, and this means with sparsely. So usually you're in a lot of major cities we have in this class are dense, so you don't actually get this. You get something like, you know, exactly half. Okay. Okay. So now you can do a backhand of a number of calculations.

**中文**: 如果你查看一下，比如MVD的这些规格说明书，你就会发现实际的浮点运算能力（FLOPS）其实取决于你所执行的具体任务。例如，若使用BF16或FP32，性能实际上非常差；在H100上运行FP32时，其性能比运行FP16低了数个数量级；而若进一步采用FP8，则速度甚至可能更快。此前我并未意识到这一点，但此处标有一个星号，其含义是“稀疏计算”。通常情况下，我们课程中涉及的多数主流城市模型均为稠密模型，因此实际上无法达到该指标，而只能获得大约一半的性能。好的，好的。现在你便可以执行一系列反向计算。

## 段落 32

**英文**: 8H100 for two weeks is just 8 times the number of flops per second times the number of seconds in a week. Actually, this is, this might be one week. Okay. So that's one week, and that's 4. 7 times e to the 21, which is, you know, some number. And you can kind of contextualize the flop counts with other model counts. Yeah. So that means if, so what does sparsely mean? That means if your matrices are spars. Is it specific like scripted sparsely? It's like two out of four elements in each like root of four elements is zero. That's only a case when you get that, that's me.

**中文**: H100运行两周的算力总量，即每秒浮点运算次数乘以一周的秒数再乘以8。实际上，这可能仅指一周。好的，那就按一周计算，结果为4.7×10²¹，这是一个具体数值。你可以将这一浮点运算量与其他模型的计算量进行对比，从而理解其规模。那么，“稀疏”具体指什么？它意味着你的矩阵是稀疏的。这种稀疏性是否属于特定类型（例如预设的稀疏模式）？比如，在每四个元素构成的一组中，恰好有两个元素为零。只有在这种情况下才会得到该结果，而这就是我所指的情形。

## 段落 33

**英文**: No one uses it. Yeah. It's a marketing department uses it. Okay. So let's go through a simple example. So remember, we're not going to touch the transformer, but I think even a linear model gives us a lot of the building blocks and intuitions. So suppose we have endpoints. Each point is D dimensional, and the linear model is just going to match map each D dimensional vector to a K dimensional vector. Okay. So let's set some number of points.

**中文**: 没人使用它。是的，只有市场部在用。好的，我们来看一个简单的例子。请记住，我们不会改动Transformer，但我认为即使是线性模型也能为我们提供大量基础组件和直观理解。假设我们有一些端点，每个端点都是D维的，而线性模型仅需将每个D维向量映射为一个K维向量。好的，我们设定一些端点数量。

## 段落 34

**英文**: Is B. Dimension is D. K is the number of outputs. And let's create our data matrix X. Our weight matrix W. And the linear model is just some map ball. So nothing, you know, two interesting going on. And, you know, the question is how many flops was that? And the way you would, you look at this is you say, well, when you do the matrix multiplication,. you have basically for every IJK triple, I have to multiply two numbers together. And I also have to add that number to the total.

**中文**: B 的维度是 D，K 是输出的数量。接下来，我们构建数据矩阵 X 和权重矩阵 W。线性模型仅是一个映射函数。因此，实际上并无特别之处。那么问题来了：这需要多少次浮点运算（flops）？通常，你会这样分析：在进行矩阵乘法时，对每个三元组 (i, j, k)，都需要将两个数相乘，并将该乘积加到总和中。

## 段落 35

**英文**: Okay. So the answer is two times the, basically the product of all the dimensions involved. So the, the left dimension, the middle dimension, and the right dimension. Okay. So this is something that you should just kind of remember. If you're doing a matrix multiplication, the number of flops is two times the product of the three dimensions. Okay. So the flops of other operations are usually kind of linear in the size of the, the matrix or tensor. And in general, no other operation you encounter, deep learning is expensive as matrix multiplication for large enough matrices. So this is why I think a lot of the napkin math is very simple because we're only looking at the matrix multiplications that are going, are performed by the model.

**中文**: 好的。因此，答案是：大致等于所有相关维度乘积的两倍，即左侧维度、中间维度和右侧维度的乘积。这一点需要牢记。进行矩阵乘法时，浮点运算次数（flops）即为这三个维度乘积的两倍。其他运算的浮点运算次数通常与矩阵或张量的尺寸呈线性关系；一般而言，在深度学习中，只要矩阵足够大，就没有任何其他运算比矩阵乘法更耗费计算资源。因此，我认为很多“纸面估算”都非常简单，因为我们只关注模型所执行的矩阵乘法运算。

## 段落 36

**英文**: Now, of course there are regimes where if your matrices are small enough, then the cost of other things starts to dominate. But generally, that's not a good regime you want to be in because the hardware is designed for big much versus multiplication. So, sort of by, it's a little bit circular, but by kind of, we end up in this regime where we only consider models where the mammals are at the dominant cost. Okay. Any questions about this, this number? Two times the product of the three dimensions. This is just a useful thing. So, there's a lot of negative motivation always be the same because the chip might have optimized it. And then on these, totally the same. Yeah. So the question is like, is the, does this, essentially, does this depend on the matrix multiplication? You algorithm.

**中文**: 当然，目前存在某些情形：当矩阵足够小时，其他操作的开销开始占据主导地位。但通常而言，这并非我们希望所处的情形，因为硬件正是为大规模矩阵乘法而设计的。因此，某种程度上——这略显循环论证——我们最终只考虑那些以矩阵乘法为主要开销的模型。好，关于这个数值（即三维度乘积的两倍），大家有什么问题吗？这是一个非常实用的估算方法。由于芯片可能已对此进行了专门优化，因此实际的负向开销往往保持一致；而在这些情形下，结果也完全相同。是的，问题实质在于：这一估算是否依赖于您所采用的矩阵乘法算法？

## 段落 37

**英文**: In general, I guess we'll look at this the next week when we, or the week after when we look at kernels. I mean, actually there's a lot of optimization that goes underneath under the hood when it comes to matrix multiplications. And there's a lot of specialization depending on the shape. So this is, I would say this is just a kind of a crude, you know, estimate that is basically like the right order of magnitude. Okay. So, yeah. Additions and modifications are equivalent. Yeah. Additions and multiplications are considered. So, one way I find helpful to interpret this.

**中文**: 总体而言，我猜我们将在下周（即我们或再下周讨论核函数时）来审视这个问题。实际上，在矩阵乘法的底层实现中，存在大量优化工作，且这些优化会根据矩阵形状的不同而有所专门化。因此，我可以说，这只是一个粗略的估算，其数量级基本正确。好的。加法和修改操作是等价的。是的，加法和乘法均被纳入考虑。这是我发现的一种有助于理解该问题的方式。

## 段落 38

**英文**: So, at the end of the day, this is just a matrix multiplication. But I'm going to try to give a little bit of meaning to this, which is why I've set up this. It's kind of a little toy machine learning problem. So, B is really stands for the number of data points. And DK is the number of parameters. So, for this particular model, the number of flops that's required for forward pass is two times the number of tokens or number of data points times the number of parameters. Okay. So, this turns out to actually generalize to transformers. There's an asker is there because there's, you know, the sequence length and other stuff. But this is roughly right for, if you're a sequence length, if it isn't too large.

**中文**: 因此，归根结底，这仅仅是一次矩阵乘法。但我将尝试赋予它一些实际意义，这也是我如此设定的原因：这本质上是一个简单的机器学习玩具问题。其中，B 代表数据点的数量，DK 代表参数数量。对于该特定模型，前向传播所需的浮点运算次数（flops）为：2 × 数据点（或 token）数量 × 参数数量。好的。事实证明，这一结论实际上可推广至 Transformer 模型；之所以存在一个系数，是因为还需考虑序列长度等因素。但若序列长度不太大，该估算大致是准确的。

## 段落 39

**英文**: So, okay. So, now this is just a number of floating point operations. So, how does this actually translate to a walk-like time, which is presumably the thing you actually care about. How long do you have to wait for your run? So, let's time this. So, I have this function that is just going to do it five times and I'm going to perform the matrix-mact operation. We'll talk a little bit later about this two weeks from now why the other code is here. But, for now, we get an actual time. So, that matrix took, you know, 0. 16 seconds. And the actual flops per second, which is how many flops did it do per second is 5.

**中文**: 所以，好的。现在这只是浮点运算的次数。那么，这实际上如何转化为类似“行走时间”的指标呢？而这恰恰是你真正关心的——你的程序需要等待多久才能运行完毕？我们来实际计时一下。我编写了这样一个函数，它将执行该操作五次，并进行矩阵乘法运算。关于为什么此处还有其他代码，我们两周后会稍作解释。但目前，我们已获得一个实际的运行时间：该矩阵运算耗时0.16秒。而实际每秒浮点运算次数（即每秒完成的浮点运算数）为5。

## 段落 40

**英文**: 4 E 13. Okay. So, now you can compare this with the, you know, the marketing materials and for the A 100 and A 100. And, you know, as we looked at the spec sheet, the flops depends on the data type. And we see that the promise flops per second, which, you know, for A 100, for, I guess this is for float 32. float 32 is, you know, 67, you know, terro flops as we looked. And so, that is the number of promise flops per second we had. And now, if you look at the, there's a helpful notion called model flops utilization or MFU, which is the actual number flops divided by the promise flops. Okay. So, you take the actual number of flops, remember, which is what you actually witnessed.

**中文**: 4E13。好的。现在，您可以将此结果与A100的营销资料进行对比。如我们所见，规格表中的浮点运算次数（FLOPS）取决于数据类型。对于A100，其标称浮点运算性能——我猜此处指的是单精度浮点数（FP32）——据我们查阅为67万亿次浮点运算每秒（67 TFLOPS）。这便是我们所采用的标称浮点运算性能数值。现在，若进一步考察，有一个很有用的概念称为“模型浮点运算利用率”（MFU），即实际浮点运算次数除以标称浮点运算次数。换言之，您需采用实际观测到的浮点运算次数。

## 段落 41

**英文**: The number of floating point operations that are useful for your model divided by the actual time it took, divided by this promise flops per second, which is, you know, from the glossy brochure. You can get a MFU of 0. 8. Okay. So, usually you see people talking about their MFUs. And something greater than 0. 5 is usually considered to be good. And if you're like, you know, 5% MFU, that's considered to be really bad. You usually can't get close to that close to, you know, you know, 90 or 100. Because this is sort of ignoring all sort of communication and overhead.

**中文**: 您的模型所执行的有效浮点运算次数，除以实际耗时，再除以厂商宣传手册中承诺的每秒浮点运算次数（即“理论峰值性能”）。由此可得出模型浮点利用率（MFU）为0.8。通常，人们会讨论自己模型的MFU；一般认为MFU超过0.5即属良好，而若仅为5%，则被视为极差。实际上，你几乎不可能达到90%或100%的MFU，因为该指标在计算时忽略了所有通信开销及系统运行开销。

## 段落 42

**英文**: It's just like the literal computation of the flops. Okay. And usually MFU is much higher if the matrix multiplication is dominate. Okay. So, that's, and if you're any, any questions about this? Yeah. So, this promise flops per second is not considered to be a great one. So, this promise flops per second is not considered to be a smart set. One, a note is that this is actually a, you know, there's also something called hardware, you know, to flops you, like, realization. And the motivation here is that we are all, we're trying to look at the, it's called model because we're looking at the number of effective useful operations that the model is, you know, performing. Okay.

**中文**: 这就像直接计算FLOPs一样。好的。通常，如果矩阵乘法占主导地位，那么MFU会高得多。好的。这就是……大家对此有任何问题吗？是的。因此，这种“承诺的每秒浮点运算次数”并不被认为是一个很好的指标。所以，这种“承诺的每秒浮点运算次数”并不被视为一个明智的设定。需要说明的一点是，实际上还存在所谓“硬件FLOPs实现率”的概念。此处的动机在于：我们关注的是模型——即考察模型实际执行的有效且有用的运算数量。好的。

## 段落 43

**英文**: And so, it's a way of kind of standardizing. It's not the actual number of flops that are done because you could have optimization in your code that cash a few things or redo, you know, you know, recomputation of some things. And in some sense, you're still computing the same model. So, what matters is that you're, this is truly trying to look at the model complexity. And you shouldn't be penalized just because you were clever in your MFU if you were clever and you didn't actually do the flops. But you said you did. Okay. So, you can also do the same with BF16. And here we see that for BF, the time is actually much better. So, 0.

**中文**: 因此，这是一种标准化的方式。它并非实际执行的浮点运算次数（FLOPs），因为你的代码中可能存在优化，例如缓存某些计算结果或重新计算部分内容。从某种意义上说，你仍在运行相同的模型。因此，关键在于考察模型本身的复杂度。你不应仅仅因为自己在MFU（模型浮点运算利用率）方面更聪明——比如通过巧妙设计避免了实际执行某些FLOPs——而受到惩罚；但如果你声称执行了这些FLOPs，那就不合适了。好的。同样，你也可以对BF16执行相同操作。此处我们看到，对于BF（BF16），实际耗时明显更优。因此，耗时为0。

## 段落 44

**英文**: 03 instead of 0. 16. So, the actual flops per second is higher. Even the county first, especially the promised flops is still quite high. So, the MFU acts actually lower for BF16. This is, you know, maybe surprisingly low. But sometimes the promised flops is a bit of, you know, optimistic. So, always about benchmark your code. And don't just kind of assume that you're going to get certain levels of performance. Okay.

**中文**: 03 而非 0.16。因此，实际每秒浮点运算次数（FLOPS）更高。即使是县级单位（此处疑为术语误译，或指“最低配置”等，但按字面直译）优先考虑时，所宣称的 FLOPS 依然相当高。因此，BF16 精度下 MFU（矩阵乘法单元）的实际利用率反而更低。这一点可能出人意料地低。但有时所宣称的 FLOPS 略显乐观。因此，务必对您的代码进行基准测试，切勿想当然地认为一定能达到特定性能水平。

## 段落 45

**英文**: So, just to summarize, matrix multiplatients dominate the compute. And the general rule of thumb is that it's two times the product of the dimensions, flops. The flops per second, floating points per second, depends on, you know, the hardware and also the data type. So, the fancier the hardware you have, the higher it is, the smaller the data type, the usually the faster it is. And MFU is a useful notion to look at how well you're essentially squeezing your hardware. Yeah. I heard that often you get like the maximum utilization you want to use these like tensor cores on the machine. And so, like, this fighter is by default to use these tensor cores on, like, are these kind of conditions? Yeah. So, the question is, what about those tensor cores? So, if you go to this spec sheet, you'll see that, you know, these are all on the tensor core. So, the tensor core is basically, you know, specialized hardware to do map balls.

**中文**: 因此，简单总结一下，矩阵乘法占据了主要的计算量。一般的经验法则是：浮点运算次数（FLOPs）约为矩阵维度乘积的两倍。每秒浮点运算次数（FLOPS）取决于硬件性能以及数据类型——硬件越先进，FLOPS越高；数据类型越小，通常运算速度也越快。MFU（模型浮点利用率）是一个有用的指标，用于衡量你对硬件计算能力的实际压榨程度。是的，我常听说，为实现最高利用率，通常需要启用机器上的张量核心（Tensor Cores）。那么，默认情况下，这类加速器是否就专为使用张量核心而设计？是否需满足某些特定条件？是的。那么问题来了：这些张量核心究竟如何工作？若查阅相关规格说明书，你会发现所有指标均基于张量核心。张量核心本质上是一种专门用于执行矩阵运算的专用硬件。

## 段落 46

**英文**: So, if you are, you know, if you're, so by default, it should use it. And especially if you're using PyTorch, you know, compile, it will generate the code that will use the hardware properly. Okay. So, let's talk a little bit about, you know, gradients. So, and the reason is that we've only looked at matrix multiplication, or in other words, basically, feet forward, forward passes and the number of flops. But there's also a computation that comes from computing gradients, and we want to track down how much that is. Okay. So, just to consider a simple example, a simple linear model, where you take the prediction of a linear model and you, you look at the MSC with respect to five. So, not a very interesting loss, but I think it's illustrated for looking at the gradients. Okay.

**中文**: 因此，如果你使用了相关设置，那么默认情况下它就会启用该功能。尤其是当你使用 PyTorch 的 `compile` 功能时，它会生成能充分利用硬件的代码。好的。接下来我们简要讨论一下梯度问题。原因在于，我们此前仅关注了矩阵乘法，或者说，本质上只考察了前向传播过程及其浮点运算量（FLOPs）。但除此之外，还有用于计算梯度的额外计算开销，而我们需要明确量化这部分开销。好的。我们先考虑一个简单示例：一个简单的线性模型，其预测结果与真实值之间的均方误差（MSE）作为损失函数——虽然这个损失函数并不特别有趣，但它有助于清晰地展示梯度计算过程。

## 段落 47

**英文**: So, remember, in the forward pass, you have your X, you have your, your W, which, you want to compute the gradient with respect to, you make a prediction by taking a linear product and then you, you have your loss. And in the backward pass, you just call loss a backwards. And in this case, the gradient, which is this variable attached to the tensor, turns out to be what you, what you want. Okay. So, everyone has done your gradients in PyTorch before. So, let's look at how many flops are required for computing gradients. Okay. So, let's look at a slightly more complicated model. So, now it's a two-layer linear model, where you have X, which is BID, times W1, which is D by D. So, that's the first layer.

**中文**: 因此，请记住，在前向传播过程中，你有输入X和待计算梯度的权重W；通过线性乘积得到预测结果，然后计算损失函数。而在反向传播过程中，只需调用loss.backward()即可。此时，附着在张量上的梯度变量，恰好就是你所需要的梯度。好的。大家之前应该都已在PyTorch中计算过梯度了。接下来，我们来看一下计算梯度所需的浮点运算次数（FLOPs）。好的，我们考察一个稍复杂的模型：这是一个两层线性模型，其中输入X的形状为B×D，权重W1的形状为D×D，这构成了第一层。

## 段落 48

**英文**: And then you take your hidden activations, H1, and you pass it through another linear layer, W2, and to get a K-dimensional vector, and you do some, compute some loss. Okay. So, this is a two-layer linear network. And just as a kind of review, if you look at the number of forward flops, what you had to do was, you have to multiply, look at W1, you have to multiply X by W1, and add it to your H1. And you have to take H1 and W2, and you have to add it to your H2. Okay. So, the total number of flops, again, is two times the product of all the dimensions in your map wall, plus two times the product dimensions in your map wall for the second matrix. Okay. In other words, two times the total number of parameters in this case. Okay.

**中文**: 然后，你将隐藏层激活值 H1 输入到另一个线性层 W2 中，得到一个 K 维向量，并据此计算某种损失。好，这是一个两层线性网络。作为简要回顾，若考察前向传播所需的浮点运算次数（flops），你需要执行以下操作：首先将输入 X 与权重矩阵 W1 相乘，并将结果加到 H1 上；接着将 H1 与权重矩阵 W2 相乘，并将结果加到 H2 上。因此，总的浮点运算次数再次等于两倍的首层映射中所有维度的乘积，再加上两倍的第二层矩阵中所有维度的乘积。换言之，即本例中参数总数的两倍。

## 段落 49

**英文**: So, what about the backward pass? So, this part will be a little bit more involved. So, we can recall the model X to H1 to H2 and the loss. So, in the backward pass, you have to compute a bunch of gradients. And the gradients that are relevant is you have to compute the gradient with respect to H1, you know, H2, W1, and W2 of the loss. So, D lost each of these variables. Okay. So, how long does it take to compute that? Let's just look at W2 for now. Okay. So, the things that touch W2, you can compute by looking at the chain rule. So, W2 grad, so the gradient of D lost, D, W2, is you sum H1 times the gradient of the loss with respect to H2.

**中文**: 那么，反向传播过程呢？这部分会稍微复杂一些。我们可以回顾一下模型的结构：X → H1 → H2，以及损失函数。在反向传播过程中，需要计算一系列梯度。其中相关梯度包括：损失函数对H1、H2、W1和W2的梯度，即损失函数对这些变量的偏导数。那么，计算这些梯度需要多长时间呢？我们先以W2为例。W2所涉及的部分可通过链式法则来计算。W2的梯度，即∂损失/∂W2，等于H1与损失函数对H2的梯度的乘积之和。

## 段落 50

**英文**: Okay. So, that's just a chain rule for W2. And this is, so all the gradients are the same size as the underlying vectors. So, this turns out to be, essentially, looks like a matrix multiplication. And so, the same calculus holds, which is that it's two times the number of the product of all the dimensions, B times D times K. Okay. But this is only the gradient with respect to W2. We also need to compute the gradient with respect to H1, because we have to keep on back propagating to W1 and so on. Okay. So, that is going to be the product of W2 times H2.

**中文**: 好的。因此，这只是针对W2的链式法则。而所有梯度的维度均与对应向量的维度一致。结果表明，这本质上类似于矩阵乘法。因此，相同的微积分规则依然适用，即其计算量约为所有维度乘积的两倍，即2×B×D×K。但以上仅是关于W2的梯度。我们还需计算关于H1的梯度，因为必须继续反向传播至W1等参数。因此，该梯度等于W2与H2的乘积。

## 段落 51

**英文**: Sorry, I think this should be that grad of H2, H2. That grad. So, that turns out to also be, essentially, looks like the matrix multiplication. And it's the same number of flops for computing the gradient of H1. Okay. So, when you add the two, so that's just for W2. You do the same thing for W1, and that's, which has D times D parameters. And when you add it all up, it's, so for this, for W2, the amount of computation was 4 times B times D times K. So, I'm going to try again for W1. It's also 4 times B times D times D, because W1 is D by D.

**中文**: 抱歉，我认为这里应该是H₂的梯度，即H₂的梯度。这个梯度本质上看起来也类似于矩阵乘法运算，且计算H₁梯度所需的浮点运算次数（flops）与此相同。好的。因此，将这两部分相加后，得到的只是关于W₂的结果；对W₁需执行同样的操作，而W₁具有D×D个参数。将所有计算量加总后，对于W₂，计算量为4×B×D×K。接下来我再重新计算W₁的计算量：它同样为4×B×D×D，因为W₁是一个D×D的矩阵。

## 段落 52

**英文**: Okay. So, I know there's a lot of symbols here. I'm going to try also to give you a visual account for this. So, this is from a blog post that I think may work better. Okay. I have to wait for the animation to flip back. So, basically, this is one layer of the node out, which has the hidden and then the weights to the next layer. And so, I have to, okay, probably this animation has to wait. Okay. Ready, set.

**中文**: 好的。我知道这里有很多符号。我还会尽量为你们提供一个直观的图示说明。这部分内容来自一篇我认为效果可能更好的博客文章。好的，我需要等待动画翻转回来。基本上，这是节点输出的一层，其中包含隐藏层以及通往下一层的权重。因此，我需要……好吧，这个动画可能得稍等一下。好的，准备好了，开始！

## 段落 53

**英文**: Okay. So, first, I have to multiply W and A, and have to add it to this. That's a forward pass. And now I'm going to multiply this, these two, and then add it to that. And I'm going to multiply and then add it to that. Okay. Any questions? We're just going to wait to slow this down. But, you know, the details may be all that you kind of reminit on, but the high level is that there's two times the number of parameters for the forward pass and four times the number of parameters for the backward pass. And we can just kind of work it out via the chain row here. Yeah.

**中文**: 好的。首先，我需要将 W 和 A 相乘，然后将结果加到这个值上，这是一次前向传播。接下来，我将把这两个值相乘，再将结果加到那个值上；然后再相乘，再加到那个值上。好的，有问题吗？我们先稍作停顿，放慢节奏。不过，您可能只需记住这些细节，而从高层次来看，前向传播所需的参数量是参数总数的两倍，反向传播则是四倍。我们可以通过此处的链式法则逐步推导出来。是的。

## 段落 54

**英文**: For the homeworks, are we also using the, you said some types of information is last some reason, are we allowed to use the grad or we are doing the, like, entirely by hand to the gradient. So, the question is, in the homework, are you going to compute gradients by hand? And the answer is no. You're going to just use PyTorch gradient. This is just to break it down so we can do the counting flops. Okay. Any questions about this before I move on. Okay. Just to summarize, the forward pass is for this particular model is two times the number of data points times the number of parameters and backwards is four times the number of data points times the number of parameters, which means that total it's six times the number of data times times parameters. Okay. And that explains why there was a six in the beginning when I asked the motivating question.

**中文**: 对于作业，我们是否也要使用……您之前提到某些类型的信息出于某种原因会滞后，那么我们能否使用梯度（grad），还是必须完全手动计算梯度？换言之，作业中是否需要手动推导并计算梯度？答案是否定的，你们只需直接使用 PyTorch 自动计算的梯度。我们之所以手动分解，只是为了便于统计浮点运算次数（FLOPs）。好，我继续之前，大家对此还有疑问吗？好的。简要总结一下：对该特定模型而言，前向传播的计算量为数据点数量乘以参数数量的两倍，反向传播为数据点数量乘以参数数量的四倍，因此总计算量为数据点数量乘以参数数量的六倍。这也就解释了我在提出动机性问题之初提到“6”的原因。

## 段落 55

**英文**: So now this is for a simple linear model, but turns out that many models, this is basically the bulk of the computation when essentially every computation you do has touches essentially a new parameters roughly. And, you know, obviously this doesn't hold, you can find models where this doesn't hold because you can have like one parameter through parameter sharing and have a billion flops, but that's generally what not what models look like. Okay. So, let me move on. So far, I've basically finished talking about the resource accounting. So we looked at tensors, we looked at some computation on tensors, we looked at how much tensors take to store and also how many flops takes tensors take when you do various operations on them. Now let's start building up different models. I think this part is necessarily going to be that conceptually interesting or challenging, but it's more for maybe just completeness. Okay. So parameters in PyTorch are stored as these NN parameter objects.

**中文**: 因此，目前这适用于一个简单的线性模型，但事实上，对许多模型而言，这基本上构成了计算的主体——因为你所做的几乎所有计算，本质上都会涉及大量不同的参数。当然，这并非绝对成立：你也能找到一些例外模型，例如通过参数共享仅使用一个参数却执行数十亿次浮点运算；但这类模型通常并不常见。好的，我们继续往下讲。到目前为止，我实际上已基本讲完资源核算的相关内容：我们讨论了张量，探讨了在张量上进行的一些计算，分析了存储张量所需的内存空间，以及对张量执行各类运算时所需的浮点运算次数（FLOPs）。接下来，我们开始逐步构建不同的模型。我认为这一部分在概念上未必特别有趣或富有挑战性，更多是为了内容的完整性。好的，那么在 PyTorch 中，参数以 `nn.Parameter` 对象的形式进行存储。

## 段落 56

**英文**: Let's talk a little bit about parameter initialization. So if you have, let's say, a parameter that has, okay, so you generate, okay, sorry. So here you see, you know, if you have a parameter, you have to do a few things. Your W parameter is an input dimension by hidden dimension matrix. You're still in the linear model case. So let's just turn the input and let's feed it through the output. Okay. So, ran and unit Gaussian is, you know, seems innocuous. So, you get some pretty large numbers, right? And this is because when you, you know, have the number grows as essentially the square root of the hidden dimension. And so when you have large models, this is going to, you know, blow up.

**中文**: 我们来简单谈谈参数初始化。假设你有一个参数——好吧，我们先生成它，抱歉。如你所见，如果你有一个参数，需要做几件事：你的权重参数W是一个“输入维度×隐藏维度”的矩阵，此时你仍处于线性模型的情形。因此，我们只需将输入数据传入，并将其送入输出层即可。好的，随机初始化为标准正态分布看似无害，但实际上会得到一些相当大的数值，这是因为数值大小大致随隐藏维度的平方根增长；因此，当模型规模较大时，这些数值就会急剧膨胀。

## 段落 57

**英文**: And training can be a very unstable. So, so typically what you want to do is initialize in a way that's, you know, invariant to hidden or at least, you know, when you guarantee that it's not going to blow up. And one simple way to do this is just rescale by the one of the square root number of, you know, of inputs. So basically, let's redo this W equals a parameter where I simply divide by the square root of the input dimension. And then now when you feed it through the output, now you get things that are stable around, you know, this is actually concentrate to, you know, something like normal zero one. So, this is basically, you know, this has been explored pretty extensively and deep learning literature is known up to a constant as savior initialization. And typically, I guess it's a fairly common if you want to be extra safe. You don't trust it normal because it doesn't have, it has unbounded tails. And you say, I'm going to truncate to minus three three. So, I don't get any large values and I don't want any to mess with that.

**中文**: 而且训练过程可能非常不稳定。因此，通常我们需要以某种方式初始化参数，使其对隐藏层具有不变性，或者至少确保其不会发散。一种简单的方法是将权重按输入数量的平方根进行缩放。具体而言，我们重新定义权重矩阵 $ W $ 为一个参数，直接除以输入维度的平方根。这样一来，当数据经过该层输出时，输出值便能稳定在某个范围内，实际上会集中分布在类似标准正态分布（均值为0、方差为1）的分布附近。这种方法在深度学习文献中已被广泛研究，通常被称为“Xavier初始化”（或“Glorot初始化”），其缩放系数在常数意义上是确定的。通常情况下，若希望更加稳妥，人们往往不直接采用标准正态分布，因为其尾部无界；而是选择将分布截断至区间 $[-3, 3]$，从而避免出现过大数值，防止其干扰训练过程。

## 段落 58

**英文**: Okay. Okay. So, let's build a, you know, just a simple model. It's going to have D dimensions and two layers. There's this, you know, I just made up this name, Cruncher. It's a custom model, which is a deep linear network, which has N, N, N, layers, layers. And each layer is a linear model, which has essentially just a matrix multiplication. Okay. So, the parameters of this model is looks like I have layers for the first layer, which is a D by D matrix. So, the second layer, which is also D by D matrix, and then I have a, a head or a final layer.

**中文**: 好的。好的。那么，我们来构建一个——你知道的——非常简单的模型。它具有 D 个维度和两层结构。这个……嗯，我刚刚自创了这个名字，叫“Cruncher”。它是一个定制模型，属于深度线性网络，包含 N、N、N 层（即多层）。每一层都是一个线性模型，本质上仅执行矩阵乘法。好的。因此，该模型的参数如下：第一层是一个 D×D 矩阵；第二层同样是一个 D×D 矩阵；此外，还有一个输出层（或称最终层）。

## 段落 59

**英文**: Okay. So, if I get the number of, of parameters of this model, then it's going to be D squared plus D squared plus D. Okay. So, nothing too surprising there. And I'm going to move it to the GPU, so I want this to run one fast. And I'm going to generate some random data and feed it through the data. And the forward pass is just going through the layers, and then finally applying the head. Okay. So, with that model, let's try to, I'm going to use this model and do some stuff with it. But just one kind of general digression.

**中文**: 好的。那么，如果我计算该模型的参数数量，结果将是 $ D^2 + D^2 + D $。好的，这里没什么特别意外的。接下来我会将它迁移到 GPU 上，以便快速运行。然后，我将生成一些随机数据并将其输入模型。前向传播过程就是依次经过各层，最后应用输出头。好的。有了这个模型，我们来尝试一下——我将使用该模型进行一些操作。不过，先稍作一个一般性的离题说明。

## 段落 60

**英文**: Randomness is something that is sort of can be annoying in some cases, if you're trying to reproduce a bug, for example. It shows up in many places, initialization, dropout, data ordering. And just the best practices, I would recommend you always pass a fix the random seed. So, you can reproduce your model, or at least as well as you can. And in particular, having a different random seed for every source of randomness is nice, because then you can, for example, fix initialization or fix the data ordering, but very other things. Determinism is your friend when you're debugging. And, you know, in code, unfortunately, there's many places where you can use randomness and just be cognizant of, you know, which one you're using. And just, if you want to be safe, just set the seed to for all of them. Data loading, I guess I'll go through this quickly. It's not, it'll be useful for your assignment.

**中文**: 随机性在某些情况下可能会令人困扰，例如当你试图复现某个 bug 时。它会出现在许多地方，比如参数初始化、Dropout 和数据顺序等。就最佳实践而言，我建议你始终固定随机种子，以便能够复现你的模型（至少尽可能地复现）。尤其值得推荐的是，为每种随机性来源分别设置不同的随机种子，这样你就可以单独固定初始化过程或数据顺序等某一方面，而其他部分保持不变。确定性是调试时的好帮手。此外，在代码中不幸的是，存在许多可能引入随机性的位置，你需要清楚地意识到自己正在使用哪些随机性来源。若想确保安全，可为所有这些来源统一设置随机种子。关于数据加载，我将快速过一遍——这对你的作业会很有帮助。

## 段落 61

**英文**: So, in language modeling, data is typically just a sequence of integers, because this is, remember, output by the tokenizer. And you serialize them into, you can serialize them into an umpire arrays. And one, I guess, thing that's maybe useful is that you don't want to load all your data into memory at once, because, for example, the Lama data is the 2. 8 terabytes. But you can sort of pretend to load it by using this handy function called memmap, which gives you essentially a variable that is mapped to a file. So, when you try to access the data, it actually on the on demand loads the file. And then, using that, you can create a data loader that, you know, is a, you know, samples data from your batch. So, I'm going to skip over that just the interest of time. Let's talk a little bit about, you know, optimizer. So, we've defined our model.

**中文**: 因此，在语言建模中，数据通常只是一串整数，因为如前所述，这是分词器（tokenizer）的输出。你可以将这些整数序列化为NumPy数组。其中一点或许很有用：你不应一次性将全部数据加载到内存中，例如，Llama数据集大小达2.8太字节（TB）。但你可以借助一个名为“memmap”的便捷函数来模拟数据加载——该函数本质上为你创建了一个映射到文件的变量；当你访问数据时，系统才会按需从文件中加载相应部分。利用这一机制，你便可构建一个数据加载器（data loader），从中按批次采样数据。出于时间考虑，我将跳过这部分细节。接下来，我们简要讨论一下优化器（optimizer）。目前，我们已定义好模型。

## 段落 62

**英文**: So, there's many optimizers, just kind of maybe going through the intuitions behind some of them. So, of course, there's the Cassell gradient descent. You compute the gradient of your batch. You take a step in that direction. No questions asked. There's an idea called momentum, which dates back to classic optimization, Nesteroff, where you have a running average of your gradients, and you update against the running average instead of your instantaneous gradient. And then, you have add a grad, which you scale the gradients by your average over the norms of your, or I guess not the norms, the square of the gradients. You also have RMS prop, which is an improved version of add a grad, which uses an exponential average, rather than just like a flat average. And then, finally, add a, which appeared in 2014, which is essentially combining RMS prop and momentum. So, that's why you're maintaining both your running average of your gradients, but also running average of your gradient squared.

**中文**: 因此，存在多种优化器，我们不妨简要探讨其中一些优化器背后的直观思想。首先，当然是标准的梯度下降法：你计算当前批次的梯度，并沿该梯度方向迈出一步，无需任何额外考虑。其次，有一种名为“动量（momentum）”的思想，源于经典优化理论（如涅斯特罗夫方法），其核心是维护梯度的滑动平均值，并依据该滑动平均值而非瞬时梯度来更新参数。接着是AdaGrad算法，它通过梯度平方的滑动平均值（而非梯度范数）对梯度进行缩放。随后是RMSProp算法，它是AdaGrad的一种改进版本，采用指数滑动平均而非简单的算术平均。最后是2014年提出的Adam算法，它本质上融合了RMSProp与动量法，因此需同时维护梯度的一阶滑动平均和梯度平方的二阶滑动平均。

## 段落 63

**英文**: Okay, so, since you're going to implement add a, in homework one, I'm not going to do that. Instead, I'm going to implement, you know, add a grad. So, the way you implement an optimizer in, you know, PyTorch is that you override the optimizer class, and you have to, let's see, maybe I'll, and then I'll get to the implementation once we step through it. So, let's define some data, compute the forward pass on the loss, and then, you compute the gradients, and then you, when you call optimizer dot step, this is where the optimizer actually is active. What this looks like is your parameters are grouped by, for example, you have one for the layer zero, layer one, and then the final, you know, weights. And you can access a state, which is a dictionary, from parameters to, you know, whatever you want to store as optimizer state. The gradient of that parameter, you assume, is already calculated by the, the backward pass. And now you can do things like, you know, in, in add a grad, you're storing the sum of the gradient squared. So, you can get that G2 variable, and you can update that based on the square of the gradient. So, this is an element-wise squaring of the gradient, and you put it back into the state.

**中文**: 好的，既然你们将在作业一中实现 AdaGrad，我就不重复实现了。相反，我将实现 AdaGrad 的梯度更新部分。在 PyTorch 中实现优化器的方式是继承并重写优化器基类；接下来，我们逐步梳理其实现过程。首先定义一些数据，执行前向传播并计算损失，然后计算梯度；当调用 `optimizer.step()` 时，优化器才真正开始发挥作用。具体而言，参数按层分组（例如第零层、第一层以及最终的权重等），你可通过一个字典形式的 `state` 属性访问每个参数对应的优化器状态（即你希望存储的任意状态信息）。此时，该参数的梯度已由反向传播自动计算完成。接着，你就可以执行类似 AdaGrad 的操作：例如，存储梯度平方的累加和。因此，你可以获取变量 `G2`，并基于当前梯度的平方对其进行更新——即对梯度进行逐元素平方运算，并将结果存回状态字典中。

## 段落 64

**英文**: Okay, so then, your, obviously, your optimizer is responsible for updating the parameters, and this is just the, you know, you update the learning rate times the gradient divided by this scaling. So, now, this state is kept over across multiple invocations of, you know, the optimizer. Okay, so, and then at the, you know, end of your optimizer stuff, you can, you know, free up the memory just to, which is, I think, going to actually be more important when you look when we talk about model parallelism. Okay, so let's talk about the memory requirements of the optimizer states, and actually, basically, at this point, everything. So, you need to, the number of parameters in this model is D squared times the number of layers plus D for the final head. Okay, the number of activations, so this is something we didn't do before, but now, for this simple model, it's fairly easy to do. It's just B times, you know, D times the number of layers you have for every layer, for every data point, for every dimension, you have to hold the activations. For the gradients, this is the same as the number of parameters, and the number of optimizer states, and for add a grad, it's, you remember, we had to store the gradient squared, so that's another copy of the parameters. So, putting it all together, we have, the total memory is assuming, you know, FP32, which means 4 bytes times the number of parameters, number of activations, number of gradients, and number of optimizer states. Okay, and that gives us, you know, some number, which is 496 here.

**中文**: 好的，那么显然，优化器负责更新参数，其更新方式即为学习率乘以梯度再除以该缩放因子。此时，该状态会在多次调用优化器的过程中持续保留。最后，在完成所有优化器相关操作后，您可以释放内存——这一点在讨论模型并行时尤为重要。接下来，我们来分析优化器状态的内存需求，实际上，此时需考虑全部内存开销。首先，模型参数量为 $ D^2 \times $ 层数 $ + D $（其中 $ D $ 为最终输出头的维度）。其次，激活值数量——此前我们未计算此项，但对这一简单模型而言，计算起来相当容易：即每个数据样本、每一层、每个维度均需存储激活值，因此总量为 $ B \times D \times $ 层数。再次，梯度数量与参数数量相同；而优化器状态数量方面，以 Adam 优化器为例，我们需额外存储梯度的平方，因此还需一份与参数量相等的存储空间。综上，总内存占用（假设使用 FP32 精度，即每个数值占 4 字节）为：4 字节 ×（参数量 + 激活值量 + 梯度量 + 优化器状态量）。由此得出的总内存值为 496。

## 段落 65

**英文**: Okay, so this is a fairly simple calculation, in the assignment one, you're going to do this for the transformer, which is a little bit more involved, because you have to, there's not just matrix multiplications, but there's many matrices, there's attention, and there's all these other things. But the general form of the calculation is the same, you have parameters, activations, gradients, and optimizer states. Okay, and the, so, and the flops required, again, for this model is six times the number of tokens, or the number of data points times the number of parameters, and, you know, that's basically concludes the resource accounting for this particular model. And if, for reference, if you're curious about working this out for, for transformers, you can consult some of these articles. Okay, so in the remaining time, I think, maybe I'll pause for questions. And we talked about building up the tensors, and then we built a kind of a very small model, and, you know, we talked about optimization, and how many, how much memory, and how much compute was required. So the question is, why do you need to store the activations? So naively, you need to store the activations, because when you're, when you're doing the paper pass, the gradients of, let's say, the first layer depend on the activation. So the gradients of the i-clare depends on the activation there. Now, if you're smarter, you don't have to store the activations, or you don't have to store all of them, you can recompute them, and that's something a technical called activation checkpoint, in which we can talk about later. Okay, so let's just do this quick, you know, actually there's not much to say here, but, you know, here's your typical, you know, training loop, where you define the model, define the optimizer, and you get the data, and then, you know, feed forward, backward, and take a step in a parameter space.

**中文**: 好的，这是一个相当简单的计算。在作业一中，你将对Transformer模型执行类似的计算，但后者稍显复杂，因为其中不仅涉及矩阵乘法，还包含多个矩阵、注意力机制以及诸多其他组件。不过，该计算的整体形式是相同的：均包含参数、激活值、梯度及优化器状态。此外，该模型所需的浮点运算次数（FLOPs）为6倍的token数量（或数据点数量）乘以参数数量。以上基本涵盖了该特定模型的资源核算。若需参考如何对Transformer模型进行此类计算，可查阅文中所列的部分文献。  
接下来的时间，我打算暂停一下，以便大家提问。我们此前讨论了张量的构建过程，随后搭建了一个非常小型的模型，并探讨了优化方法，以及所需内存与算力的规模。那么问题来了：为何需要存储激活值？从最直观的角度看，之所以需要存储激活值，是因为在反向传播过程中，例如第一层的梯度依赖于该层的激活值——即第i层的梯度依赖于该层的激活值。不过，若采用更聪明的方法，则无需全部存储这些激活值；你可以选择在需要时重新计算它们，这一技术称为“激活检查点”（activation checkpoint），我们后续再详加讨论。  
最后，我们快速过一遍典型训练流程：定义模型、定义优化器、加载数据，然后依次执行前向传播、反向传播，并在参数空间中更新一步。

## 段落 66

**英文**: And, I guess, it would be more interesting, I guess, next time I should show, like, actual 1D clock, which isn't available on this, on this version. So, one note about checkpointing, so training language model takes the long time, and you're certainly, well, a crash at some point, so you don't want to lose your progress. So you want to periodically save your model to disk, and just to be very clear, the thing you want to save is both the model and the optimizer, and probably, you know, which iteration you're on, which should add that. And then, you can just load it up. One, maybe, final note, and out, and is, why do you kind of mix a precision in your training? You know, choice of the data type has the different trade-offs. If you have higher precision, it's more accurate and stable, but it's more expensive, and low precision fights versa. And, as we mentioned before, by default, the recommendations use float32, but try to use BF16, or even FP8 whenever possible. So you can use lower precision for the fifth forward pass, but float32 for the rest. And this is an idea that goes back to the, you know, 2017, there's exploring mixed precision training. PyTorch has some tools that automatically allow you to do, you know, mix precision training, because it can be sort of annoying to have to specify which parts of your model it needs to be, you know, what precision.

**中文**: 此外，我想，下次展示一个真正的1D时钟可能会更有趣——但当前这个版本并不支持。关于检查点（checkpointing）有一点需要说明：训练语言模型耗时很长，过程中难免会发生崩溃，因此你肯定不希望丢失已取得的进展。所以，你需要定期将模型保存到磁盘上。需要特别明确的是，你应同时保存模型本身和优化器，此外最好也保存当前迭代次数（即训练步数）。之后，你就可以随时加载这些保存的文件继续训练。最后再补充一点：为何要在训练中采用混合精度？数据类型的选取涉及不同的权衡取舍：高精度计算更准确、更稳定，但开销更大；低精度则相反。如前所述，PyTorch默认推荐使用float32，但建议尽可能采用BF16甚至FP8。例如，可对前向传播第五步使用较低精度，其余部分仍用float32。这一混合精度训练的思想早在2017年就已提出并开始探索。PyTorch提供了相关工具，可自动实现混合精度训练，避免了手动指定模型各部分所需精度的繁琐操作。

## 段落 67

**英文**: Generally, you define your model as, you know, sort of this clean modular thing, and the specified in the precision is sort of like, you know, something that needs to cut across that. And one, I guess maybe one kind of general comment is that people are pushing the envelope on what precision is needed. There's some, you know, papers that show you can actually use FP8, you know, all the way, you know, through. There's, I guess one of the challenges is, of course, when you have lower precision, it gets very numerically unstable, but then you can do various tricks to, you know, control the, the numerics of your model during training so that you don't get into these, you know, bad regimes. So this is where I think the systems and the model architecture design kind of are synergistic because you want to design models now that we have, a lot of model design is just governed by hardware. So even the transformers we mentioned last time is governed by the having GPUs. And now if we notice that, you know, Nvidia chips have the property that if lower precision, even like int 4, for example, is one thing. Now, if you can make your model training actually work on in 4, which is, I think, quite, quite hard, then you can get massive, you know, speed ups and your model will be more, you know, efficient. Now, there's another thing which we'll talk about later, which is, you know, often you'll train your model using more sane, you know, floating point. But when it comes to inference, you can go crazy and you take your preach model and then you can quantize it and get a lot of the gains from very, very aggressive quantization.

**中文**: 通常，你会将模型设计为一种清晰、模块化的结构，而精度设定则是一种需要贯穿整个模型的约束条件。一个普遍的看法是，研究人员正不断探索模型所需的最低精度极限。例如，已有论文表明，FP8 精度可全程应用于模型训练与推理。当然，挑战之一在于：精度降低后，数值计算极易变得不稳定；但通过采用多种技巧，可在训练过程中有效控制模型的数值行为，从而避免陷入不良的数值状态。因此，我认为系统设计与模型架构设计在此高度协同：当前许多模型设计本身便受硬件制约——比如我们之前提到的 Transformer 架构，其设计就深受 GPU 特性的制约。如今我们注意到，NVIDIA 芯片具备支持极低精度（例如 INT4）运算的能力。若能实现模型在 INT4 精度下成功训练（这难度极高），便可获得巨大的加速效果，使模型运行更高效。此外，还有另一点我们稍后会讨论：通常模型训练会采用更稳妥的浮点精度，但在推理阶段则可激进得多——即对已训练好的模型进行量化，通过极为激进的量化策略获取显著的性能增益。

## 段落 68

**英文**: So somehow training is a lot more difficult to do with low precision, but once you have a training model, it's much easier to make it low precision. Okay, so I will wrap up there just to conclude. We have talked about the different primitives to use to train a model building up from tensors all the way to the training loop. We talked about memory accounting and flops accounting for these simple models. Hopefully once you go through assignment one, all of these concepts will be really solid because you'll be applying these ideas for actual transformer. Okay, see you next time.

**中文**: 因此，以低精度进行训练要困难得多，但一旦完成了模型训练，再将其转为低精度则容易得多。好了，我就在此收尾总结一下。我们讨论了用于模型训练的各种基础组件，从张量开始，逐步构建到完整的训练循环；还探讨了这些简单模型的内存占用和浮点运算量（FLOPs）估算方法。希望在完成第一次作业后，所有这些概念都能真正掌握扎实，因为你们将把这些思路实际应用于Transformer模型。好的，下次见！

---

*共 68 个段落，676 句话*
