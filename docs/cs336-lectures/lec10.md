# Lecture 10： Inference

生成时间: 2026-03-08 22:22:00

---

## 段落 1

**英文**: So this is lecture 10. We're going to take a brief respite from scaling laws, and we're going to talk about inference. So the question of inference is a very simple one. Given a fixed model that we've trained, generate responses given prompts. First, we're going to start by understanding what the implications of inference are,. and the workload that it entails. And then we're going to talk about ways of making inference faster. And throughout this lecture, you're going to see that there's a lot of inferences a very deep topic. We didn't do inference last year in lectures, so this is the first year we're doing it. But there's actually many, many topics that could span multiple lectures, which I'll try to condense into one.

**中文**: 因此，这是第10讲。我们将暂时从缩放定律中抽身，转而探讨推理（inference）问题。所谓推理，其核心问题非常简单：给定一个已训练好的固定模型，根据输入提示生成响应。首先，我们将从理解推理所蕴含的意义及其带来的计算负载入手；随后，我们将讨论如何加速推理过程。在本讲中，大家会发现推理是一个极为深入且内涵丰富的主题——去年的课程中并未涉及推理内容，因此今年是首次讲授。实际上，这一主题涵盖大量内容，足以支撑多场讲座，而我将尽力将其浓缩为一讲。

## 段落 2

**英文**: So inference shows up in multiple different places. The most obvious place is if you actually want to use a model, you want to use it to chat. You're using cursor or something to do code completion. If you're running batch data processing. job using your language model, all of these cases demand inference because you need to generate tokens from your actual model. But it also shows up in other contexts. If you want to even evaluate your model, as I say, on instruction following, you need to do inference. There is a lot of interest and test time. compute, which means thinking more before you actually output some the final answer. And that's also more inference, because thinking is basically generate tokens.

**中文**: 因此，推理出现在多个不同场景中。最明显的场景是：当你实际使用某个模型时，例如用于聊天对话，或借助Cursor等工具进行代码补全，又或利用语言模型执行批量数据处理任务——所有这些情况都需要推理，因为你必须从实际模型中生成词元（tokens）。但推理也出现在其他场景中。例如，即使只是评估模型（如我之前提到的指令遵循能力），也需要进行推理。此外，目前对“测试时计算”（test-time compute）有浓厚兴趣，即在最终输出答案前进行更深入的思考，这同样属于推理范畴，因为所谓“思考”，本质上就是生成词元。

## 段落 3

**英文**: And then finally, even training itself, if you're using reinforcement learning, you need to sample responses and then evaluate them based on some reward. And that also requires inference. So inference isn't just, I want to put up a chatbot demo. Infrains actually is going to underlie many of the basic functions of a language model. And even though it's one lecture, I want to stress how actually important it is for many things. And we'll probably come back to this when we talk about an alignment later in the class. So now inference is important. So the theme of this class is efficiency, clearly matters. Training is a one-time cost, but inference you repeat multiple times. So here's some the old anecdote.

**中文**: 最后，即便是训练过程本身——如果你采用强化学习，也需要采样模型输出并依据某种奖励机制对其进行评估，而这一过程同样需要推理。因此，推理并不仅仅关乎部署一个聊天机器人演示；实际上，它支撑着语言模型的诸多基础功能。尽管我们仅用一节课来讲解推理，但我仍想强调其在众多场景中的重要性。后续在课程中讨论对齐（alignment）时，我们很可能还会再次涉及这一主题。由此可见，推理至关重要。本课程的主题显然是效率，而效率的重要性不言而喻：训练是一次性开销，而推理却需反复执行。下面是一个经典轶事。

## 段落 4

**英文**: Stats on why inference is a big deal. So Sam says, opening out generates. a hundred billion words a day, which is quite a lot. And even cursor, which is not that new of a product, is allegedly generating a billion lines of accept the code each day. So it's just gave you an idea of how much inference is a counting for. And a cost of inference compared to training are definitely increasing. So how do you measure what inference, good inference looks like? So there's time to first token, TTFT. So this is how long an individual user needs to wait before any generation happens at all. And this matters clearly for interactive applications. If you have a big prompt and then you have to wait there for 10 seconds, that may not be a good user experience.

**中文**: 关于推理为何如此重要的统计数据。山姆表示，OpenAI每天生成一千亿个单词，数量相当庞大。即便是Cursor——一款并非十分新颖的产品——据称每天也能生成十亿行被采纳的代码。这让你对当前推理任务的规模有了直观认识。与此同时，推理成本相较于训练成本确实在不断上升。那么，该如何衡量“优质推理”呢？首先看首词生成时间（TTFT），即单个用户从提交请求到首次生成内容所需等待的时间。这一点对交互式应用显然至关重要：如果你输入了一个很长的提示词，却要等待10秒才开始生成，用户体验必然不佳。

## 段落 5

**英文**: Latency is how fast tokens are arriving after maybe the first token. This also matters for interactive applications. Thruplud is something a bit different. Thruplud is how many tokens in general generated per not for overall users. So this is particularly useful in batch processing applications. So you can think about that Thruplud is,. high Thruplud doesn't mean low latency because some requests might just take very long time and you still have high throughput. Latency is kind of like the worst case over any of your user. So what do you need to think about when you think about the efficiency of inference? So in training, the key idea is that you get to see all the tokens,. at least it provides training, which means that you can paralyze over the sequence.

**中文**: 延迟是指首个令牌生成后，后续令牌到达的速度。这对交互式应用同样重要。吞吐量则略有不同：它表示单位时间内（通常指每秒）整体生成的令牌数量，因此在批处理应用中尤为有用。需注意，高吞吐量并不意味着低延迟，因为某些请求可能耗时极长，但整体吞吐量仍可能很高。而延迟反映的是所有用户中最差情况的响应时间。那么，在评估推理效率时，我们需要考虑哪些因素？在训练阶段，核心思想是模型能够“看到”全部令牌（至少在训练过程中如此），这意味着可以对序列进行并行处理。

## 段落 6

**英文**: This is exploited heavily in the transformer. So you've done the transformer training. You know that you basically construct these tensors over the entire sequence. And it's just like tensor, tensor, tensor, you know, mammals. And then you get your output. But the key defining feature of inference, at least for transformers, is that you have to generate sequentially. You can't paralyze because the generation of a token depends on all of the past. So this is going to be the key thing that's going to make inference a lot harder. And in particular, it's going to be harder to utilize all of the compute that's available. And it's going to be memory limited, as we'll see in detail later.

**中文**: 这一点在Transformer模型中被大量运用。因此，你已经完成了Transformer的训练，知道基本上需要在整个序列上构建这些张量，也就是一连串的张量、张量、张量，就像哺乳动物一样层层叠加，最终得到输出。但推理（inference）的关键特征——至少对Transformer而言——在于必须逐个生成token，无法并行化，因为每个token的生成都依赖于之前所有已生成的token。这将成为使推理显著更困难的核心因素；尤其体现在难以充分利用所有可用的计算资源，并且会受到内存限制，我们将在后文详细阐述这一点。

## 段落 7

**英文**: So a lot of people are doing inference. Anyone who's actually has a product and platform quickly realizes that these costs in doing large models is going to go up. So they spend a lot of time and engineering. effort trying to reduce that time. So both provider serving close models and provider serving open weight models pay a lot of attention to inference. More so than, I think, the average academic, because we're not actually serving any models. We're just training and getting a score and putting in the paper. But people who are actually serving models. pay a lot of attention to inference. So there's also a bunch of open source packages, which are interesting to look at as well.

**中文**: 因此，许多人正在开展推理工作。任何真正拥有产品和平台的人很快就会意识到，运行大模型的成本将不断上升。因此，他们投入大量时间和工程资源，努力缩短推理时间。无论是提供闭源模型服务的厂商，还是提供开源权重模型服务的厂商，都非常重视推理环节——其重视程度甚至超过了一般学术界人士，因为学术界通常并不实际部署模型，而只是训练模型、获取评估分数并将其写入论文。而真正部署模型的从业者则格外关注推理性能。此外，还存在大量值得关注的开源推理工具包。

## 段落 8

**英文**: OK, so I want to understand the inference workload kind of in detail. So I'm going to review briefly the sort of this transformer math that you did in assignment 1. We talked a little bit about it during the first week of class. So this is from the scaling JaxML book, which is something you guys should really take a look at. I think it does an excellent job of outlining many of the key concepts here. And they have this really nice diagram that shows essentially the computation graph taken in input and having go through attention and the MLP layers. In particular, we're going to use this notation. So just to kind of review this quickly. So B is the number of sequences in your batch, L is the number of layers, T is the sequence length. You can think about as the number of tokens you're going to generate or query using.

**中文**: 好的，接下来我想详细了解一下推理工作负载。因此，我将简要回顾一下你在作业1中涉及的Transformer数学原理，这部分内容我们在课程第一周也简单讨论过。本内容出自《Scaling JaxML》一书（你们应当认真阅读此书），该书对许多核心概念进行了极为清晰的梳理。书中还提供了一张非常直观的示意图，展示了输入数据流经注意力机制层和多层感知机（MLP）层的完整计算图。特别地，我们将采用以下符号表示法：B表示批处理中的序列数量，L表示网络层数，T表示序列长度，即你将生成或查询的token数量。

## 段落 9

**英文**: As is also the sequence length, but how many are kind of conditioning on in your prompt. V is of a vocabulary, D is the dimensionality of your model. F is the MLP hidden dimension, which is usually 4 times D. H is the attention head dimension N is the number of query heads, or generally N times H equals D. And then in GQA, group query attention, you have a different number of key value heads as query heads, usually K is smaller than N. And G is the number of groups. So K times G equals N. And this diagram. shows that you take your X, you feed through the QKV matrices, and you do a bunch of things. OK.

**中文**: 序列长度同理，但你的提示词中包含多少条件信息则另当别论。V 表示词表大小，D 表示模型的维度；F 表示多层感知机（MLP）隐藏层的维度，通常为 D 的 4 倍；H 表示注意力头的维度；N 表示查询头的数量，通常满足 N × H = D；而在分组查询注意力（GQA）中，键值头的数量与查询头数量不同，通常 K 小于 N；G 表示分组数，因此满足 K × G = N。该示意图展示了：将输入 X 经过 Q、K、V 矩阵变换后，执行一系列运算。

## 段落 10

**英文**: So remember that the flops required for a fee for pass is 6 times the number of tokens, which is B times T, times the number of parameters for the attention. There's another order T. So T times T is T squared dependence. OK. So let's also review arithmetic and intensity, which is going to help us characterize when something is compute limited versus memory limited. So just to start with the basic mammal. So let's take matrix X, which is B by D, and a matrix W, D by F. And just to give some color to this computation, B is the batch size D that hidden dimension, and F is the upper projection matrix in the gate at MLP. So let's do count the number of flops and memory reading rights for just doing X times W. OK.

**中文**: 因此，请记住，一次前向传播所需的浮点运算次数（FLOPs）是令牌数量的6倍，即6 × B × T，再乘以注意力机制的参数量。这里还存在另一个T阶项，因此T × T导致了T²的依赖关系。好的。接下来我们回顾一下计算量与计算强度的概念，这将帮助我们判断某个操作是受限于计算能力还是受限于内存带宽。首先从最基础的矩阵乘法开始：设矩阵X的维度为B × D，矩阵W的维度为D × F。为便于理解该计算过程，B表示批量大小，D表示隐藏层维度，F表示MLP门控中上投影矩阵的维度。现在我们来统计仅执行X × W这一运算所需的浮点运算次数以及内存读写次数。

## 段落 11

**英文**: So we can start with initialize is 0. And what one has to do for this is we're going to read X from HBM. So that means it can encourage a memory cost of 2 times B times D, assuming everything is a BF16. You also read W. So that's 2 times D times F. Then you do the mammal. And that encouraged 2 times B times D times F flops. So remember this is from the first lecture. So hopefully this is review. And then you have to write it back out, which is you have to pay another transfer.

**中文**: 因此，我们可以从初始化为0开始。实现这一点需要从高带宽内存（HBM）中读取X，这意味着内存开销为2 × B × D（假设所有数据均为BF16格式）。同时还需要读取权重W，其内存开销为2 × D × F。随后执行矩阵乘法运算，计算量为2 × B × D × F次浮点运算（FLOPs）——这一点我们在第一讲中已介绍过，希望各位对此已有复习。最后还需将结果写回，即需再付出一次数据传输开销。

## 段落 12

**英文**: So the total number of flops is just the mammal. And the number of bytes transferred. is essentially the size of all the matrices that are red and written. And everyth American density is basically the ratio. So the ratio is this expression. And in general, just to simplify things a bit, generally the batch size is much less than D and F. B may be 100 and D and F might be 1,000 or 1,000 or 1,000. So I'm using Sympi here just to keep myself from making silly mistakes. So basically, I'm letting C go in infinity and D scales as C times B and F scales as C times B. And that gets you a simplified equation of B.

**中文**: 因此，浮点运算的总次数仅取决于该矩阵乘法操作。而数据传输的字节数本质上等于所有被读取和写入的矩阵的总大小。计算密度则基本是上述两者的比值，即该表达式。通常为简化分析，批量大小一般远小于维度 D 和 F：例如，B 可能为 100，而 D 和 F 则可能均为 1000。此处我使用 SymPy 工具，以避免犯低级错误。具体而言，我令 C 趋于无穷大，并设 D 与 C×B 成正比、F 也与 C×B 成正比，从而得到一个关于 B 的简化方程。

## 段落 13

**英文**: So the arithmetic intensity is B for this particular matrix multiplication. And the way to interpret this is how many flops are done per byte that was transferred. So now the second part is you look at the accelerator, which. for H100, a flops per second is 98, 98, 89, terror flops, memory bandwidth, 3. 3, terror bytes per second. And you divide. And that gives you what is called the accelerator intensity. And if you look at the computation intensity, which is B, if it's greater than a accelerated intensity, that means you're compute limited. That means you're able to use all the GPUs or TPUs. And if you're less than that, then your memory limited, which is bad.

**中文**: 因此，该特定矩阵乘法的计算强度为B。其含义是：每传输1字节数据所执行的浮点运算次数（FLOPs）。接下来第二部分是考察加速器——以H100为例，其算力为989.8 TFLOPS（每秒万亿次浮点运算），内存带宽为3.3 TB/s（每秒万亿字节）。将算力除以带宽，即可得到所谓“加速器强度”。若计算强度B大于加速器强度，则表明系统处于计算受限状态，即能够充分利用所有GPU或TPU；反之，若B小于加速器强度，则表明系统处于内存受限状态，这是不利的情况。

## 段落 14

**英文**: And so your compute limited in this matrix multiplication case, if B is greater than 295 for a H100. And all of this is a bit idealized, the actual details. This is giving you a first order approximation. So in an extreme case, that means if you use batches of size, let's say 300, then you'll be able to saturate the GPU. But what happens if your batch is really small? So in particular, B equals 1, which essentially corresponds to a matrix vector product, then the arithmetic intensity is basically 1. And that is really, really bad. That means you're going to be memory limited, and which makes sense because basically, you're reading and writing this D times,. actually, you're just reading this D times F matrix. And you're performing essentially in the same number of flops. So the ratio between the flops and the reads is the same, which gives you 1.

**中文**: 因此，在矩阵乘法场景下，若使用H100 GPU且B大于295，则计算能力将受限。以上分析略显理想化，实际细节更为复杂，此处仅提供一阶近似结果。在极端情况下，这意味着若采用大小为300的批次，即可充分饱和GPU算力。但若批次极小（尤其是B=1，即等效于矩阵-向量乘法），其计算强度基本仅为1，情况将非常糟糕：此时系统将严重受限于内存带宽。这很合理，因为你需反复读取一个D×F维度的矩阵（共D次），而执行的浮点运算次数却与之相当，故浮点运算数与内存读取量之比为1。

## 段落 15

**英文**: And 1 is bad. You want a lot of flops to be done for any memory read, because memory reads are slow. But this is an essence what happens with generation. Because you're proceeding token by token, we'll see that basically, your arithmetic intensity is going to be like 1. And that's why generations can be memory limited and not computer limited. So this is a very simple example that I think gets at the core of why generation is going to slow. So maybe I'll pause and take any questions on this,. just to make sure everyone's clear. Yeah. I mean, when do we get through? Why don't we have a batch? I don't see it.

**中文**: 而1是不好的。你希望每次内存读取都执行大量浮点运算，因为内存读取速度很慢。但生成过程本质上正是如此：由于你逐个生成词元（token），其计算强度基本为1。正因如此，生成过程往往受限于内存带宽，而非计算能力。这个非常简单的例子，我认为恰恰揭示了生成速度缓慢的根本原因。因此，我先暂停一下，看看大家对此是否有任何疑问，以确保所有人都理解清楚。  
是的，我的意思是，我们什么时候才能完成？为什么没有采用批处理（batch）？我并没有看到批处理。

## 段落 16

**英文**: Why should I find it? So I think I heard the question, why don't we have a batch size more than 1?. So I'll get to why you can. But there's batch sizes going to mean batch size time sequence length later. OK. So in summary, matrix multiplications are the core computation. So we just studied a matrix multiplication and counted the number of flops it requires. over the number of written writes. And we show that that ratio, which is the arithmetic intensity, depends on one of the dimensions, in case, in this case, the batch dimension. And that's why big matrices are good, because I can saturate your compute whereas if you have even a thin matrix B equals 1, that's really bad, because you're. spending a lot of time reading from memory and not doing that much compute.

**中文**: 我为什么要找它？所以我想我听到了这个问题：为什么我们的批量大小不能大于1？接下来我会解释为什么可以这样做。但要注意，后续提到的“批量大小”将指“批量大小×序列长度”。好的，总结一下：矩阵乘法是核心计算。我们刚刚研究了矩阵乘法，并统计了其所需的浮点运算次数（FLOPs）与写入内存次数之比。我们发现，该比值（即算术强度）取决于其中一个维度——本例中即为批量维度。正因如此，较大的矩阵效果更好，因为这样能充分占用你的计算资源；而若矩阵很“薄”（例如批量大小B=1），效果就非常差，因为你将花费大量时间从内存读取数据，却只进行极少的计算。

## 段落 17

**英文**: OK. So now let's talk about the arithmetic intensity of inference. OK. So let's just get more into the weeds of what inference looks like. So the naive thing you can imagine doing, and all these nice pictures are taken from this book, is that you have a transformer. You give the prompt in. It gives you logits over the vocabulary of the next token. And you just sample from that. And then once you get that, you attach it to the prompt. And then you speed it through the transformer.

**中文**: 好的，现在我们来讨论推理阶段的计算强度。好的，我们来更深入地探讨一下推理的具体过程。你可以想象一种最简单直接的做法（所有这些精美的示意图均出自这本书）：你有一个Transformer模型，将提示词输入其中，模型会输出下一个词元在全部词表上的logits，然后你从中采样得到下一个词元；接着，你将该词元添加到原始提示词之后，再次将其输入Transformer模型进行处理。

## 段落 18

**英文**: And you look at the logit, sample again. And you repeat. So that's the sort of most naive thing to do. And the complexity here is pretty bad, because each token you generate is n squared or t squared your computation through the transformer. So that's no good. But if you look at this closely, you'll notice that you're doing a lot of redundant work. All of these, the work in computing the prefix basically stays the same. So this is for a bidirectional transformer would be different, but at least for a autogressive causal transformer, it is the case that you should be able to share a lot between prefixes. And so the solution is you cache. And you cache in the IBM HVM, because that's where you have enough space to store stuff.

**中文**: 然后你查看logit，再次采样，接着重复这一过程。这便是最朴素的做法。但此处的计算复杂度相当糟糕，因为每个生成的词元都需要经过Transformer进行n²或t²量级的计算。因此这种做法并不可取。但若仔细观察，你便会发现其中存在大量冗余计算——所有这些前缀部分的计算工作基本保持不变。当然，对于双向Transformer而言情况会有所不同，但至少在自回归因果Transformer中，前缀之间理应能够共享大量计算结果。因此，解决方案就是缓存，而我们在IBM HVM中进行缓存，因为那里有足够的空间来存储相关数据。

## 段落 19

**英文**: So this is what looks like if you have a kV cache, it acts schematically. So you take your prompt. The pre-fill step is you feed it through the transformer, and you compute this kV cache. And then you generate the logits over the next token. And then you put that into take that generated token and the cache. And then you can feed it through the transformer, but you've already computed these. So you don't have to do that again. You just need to compute this new kV vector for this token. And now that allows you to more quickly generate. the next token and so on.

**中文**: 因此，这就是使用 KV 缓存时的示意图。首先输入提示词（prompt），在预填充（pre-fill）阶段，将其送入 Transformer 模型，并计算出 KV 缓存；接着，基于该缓存生成下一个词元（token）对应的 logits。随后，将新生成的词元与已有缓存一同输入模型：由于之前的 KV 值已预先计算完毕，无需重复计算，只需为当前新词元计算其对应的 KV 向量即可。这样一来，便能更快速地逐个生成后续词元。

## 段落 20

**英文**: So basically, you're filling up this kV cache, which corresponds to the tokens that you've either prefilled with or that you've generated so far. So instead of t squared per token, it's going to be more like t. So concretely, the kV cache is for every sequence in your batch, for every token in your sequence,. for every layer of the transformer, for every head, you're going to store an h-dimensional vector. So you might think that this is going to take a lot of memory and you wouldn't be wrong. So there's two stages of inference. So prefill is you're given your product and coded in a vector. So this is just like what you do in training. It's paralyzable. It's fast.

**中文**: 因此，本质上，你正在填充这个KV缓存，它对应于你已预填充或迄今已生成的所有token。这样一来，每生成一个token的计算复杂度就从t²降为接近t。具体而言，KV缓存针对批次中的每个序列、序列中的每个token、Transformer的每一层以及每个注意力头，均存储一个h维向量。你可能会认为这将占用大量内存，这种想法完全正确。推理过程分为两个阶段：预填充阶段中，你接收输入（例如产品描述）并将其编码为向量，这一过程与训练时完全相同，可并行化且速度很快。

## 段落 21

**英文**: Your compute limited. A life is good. And then you're doing generation, which is your generating response tokens one by one, sequentially. And this is a part that's going to give us a lot of trouble in terms of efficiency. So now let's compute the flops and memory IO for both for the transformer. So we're going to break it down into MLP layers and attention layers. And just notation wise, we're going to do this computation with s being the number of tokens we're conditioning on, think about the length of the prompt. And t is the number of tokens we're generating or are querying using. And in prefill, t is going to be s because we're sort of,. I mean, we're not generating t tokens, but we're sort of like querying using each of these tokens.

**中文**: 你的计算资源有限。生命是美好的。接着你进行生成任务，即逐个、顺序地生成响应词元。而这一部分将在效率方面给我们带来诸多困扰。因此，我们现在来分别计算Transformer模型在MLP层和注意力层中的浮点运算量（FLOPs）及内存I/O。在符号表示上，我们用s表示所依赖的词元数量（即提示词长度），t表示待生成或查询的词元数量。在预填充（prefill）阶段，t等于s，因为此时我们并非真正生成t个词元，而是使用每个输入词元进行查询。

## 段落 22

**英文**: And a generation where t is just 1. OK. So hopefully the matrix multiplication is so fresh in your head because this is going to be essentially that, but a little bit more complicated because it's a transformer. So we're going to count the flops and bytes generated. So first, we're going to take x, which is a b by t by d matrix. I think maybe these t should be s's, but anyway. So that involves doing a bunch of transfers. Basically the size of that matrix times 2 because b of 16. Then there's the three-way matrices, the up projection, the gate, and the down projection. They're all the same, you know, size up to transposition.

**中文**: 还有一个时间步长 $ t $ 仅为 1 的世代。好的。希望矩阵乘法在你脑海中依然清晰，因为接下来的内容本质上就是矩阵乘法，只是由于采用了 Transformer 架构而略显复杂。因此，我们将统计浮点运算次数（FLOPs）和产生的字节数（bytes）。首先，我们取输入张量 $ x $，它是一个维度为 $ b \times t \times d $ 的矩阵。这里 $ t $ 可能应写作 $ s $，但暂且不论。该操作涉及大量数据传输，其数据量大致等于该矩阵的大小乘以 2（其中 $ b = 16 $）。接着是三个权重矩阵：上投影矩阵（up projection）、门控矩阵（gate）和下投影矩阵（down projection）。它们的尺寸均相同（仅转置方向可能不同）。

## 段落 23

**英文**: So you need to transfer those. Then you do the up projection. That's some number of flops. So b times the dependency times f. So we're going to multiply two tensors, basically contracting dimension only gets counted once. Whereas other dimensions, you just kind of gather together. You need to write it out. You also have the gate, which is the same thing. You write it out. You compute your non-linearity.

**中文**: 因此，你需要转移这些数据。然后执行上投影操作，这涉及一定数量的浮点运算（flops），即 b 乘以依赖度再乘以 f。本质上，我们将对两个张量进行相乘，其中仅收缩维度被计数一次，而其他维度则简单地聚合在一起。你需要将其明确写出。此外，门控机制也是如此，同样需要明确写出，并计算你的非线性变换。

## 段落 24

**英文**: You multiply some stuff in your down project. And that's a b times t times d times f, which is basically the same number of flops. And you write out the result. So if you look at the counting, I guess maybe I'll just you can check the results. Actually, you don't need to check it because this is simple. And it's guaranteed to be correct. So again, we're going to assume that b times d is much smaller than dn f. And we get that the intensity is b times t. So this is analogous to the matrix multiplication case where the arithmetic intensity, which we want to be high, depends on how large your batch is and how many tokens you're essentially generating. So now if you look at the two stages, pre-fill, life is good.

**中文**: 你在下层项目中对某些数据进行乘法运算，即 $ b \times t \times d \times f $，其浮点运算次数（flops）本质上与之相同。然后你将结果写出。因此，若从计算量角度分析，我猜你只需核对一下结果即可——实际上根本无需核对，因为该计算十分简单，且结果必然正确。同样，我们仍假设 $ b \times d $ 远小于 $ d \times n \times f $，从而得到计算强度为 $ b \times t $。这与矩阵乘法情形类似：我们希望算术强度（arithmetic intensity）尽可能高，而它取决于批处理大小（batch size）以及实际生成的 token 数量。现在，若观察这两个阶段，预填充（pre-fill）阶段一切顺利。

## 段落 25

**英文**: Remember, because we can just make b t large enough. You use a batch size. Even a batch size of 1 actually is maybe OK if you have long enough sequence. So that's not a problem. Now, generation, this is where it becomes a little bit harder. because you're generating one token at a time. So t is 1. So if t is 1, that means for b t to be large, you need b to be large. And b is essentially the number of concurrent requests. So this is kind of interesting because your sort of efficiency depends on having large batch sizes.

**中文**: 请注意，因为我们只需将 b×t 设得足够大即可。你使用的是批处理大小，即使批处理大小为 1，只要序列足够长，实际上也可能没问题，因此这并非问题。而生成阶段则稍显困难，因为你是一次生成一个词元（token），此时 t = 1。若 t = 1，则要使 b×t 足够大，就必须增大 b；而 b 实质上代表并发请求数量。这一点颇为有趣，因为你的效率在某种程度上取决于能否采用较大的批处理大小。

## 段落 26

**英文**: Because intuitively it makes sense. If you can take a lot of requests batching together, then you can get better efficiency, at least through put. But this also depends on what b is. Because if you're only getting a few requests at a time, then you're not going to be able to use your hardware very efficiently. And this talks speaks to the sort of the very dynamic aspect of inference, which we'll come back to later in the lecture. OK, so now what about attention? Turns out attention is even worse for reasons I'll try to get into. So let's do the accounting, flops, bytes transferred. OK, so I'm going to read the QKV matrices from HBM. I'm going to compute the attention, which is matrix, which is Q times K. And the number of flops is b times s times t times d.

**中文**: 因为这在直觉上是合理的：如果你能将大量请求批量处理，那么至少在吞吐量方面，效率会更高。但这也取决于参数 b 的取值——因为如果你每次只收到少量请求，硬件资源就无法得到高效利用。这一点体现了推理过程高度动态的特性，我们将在本讲后续部分再次讨论。好的，那么注意力机制（attention）的情况又如何呢？事实证明，其问题甚至更为严重，原因我稍后会详细说明。下面我们来计算一下浮点运算量（FLOPs）和数据传输字节数。首先，我需要从高带宽内存（HBM）中读取 Q、K、V 矩阵；然后执行注意力计算，即矩阵乘法 Q × K；其浮点运算量为 b × s × t × d。

## 段落 27

**英文**: So remember, s and t are the same during a prefel. So that's your sequence length squared times b times d. And then I'm sort of only looking at the matrix multiplications because the flops from other steps don't really matter. And then you project out to, oh, sorry, you take a combination of this and v. So actually, this is mathematically incorrect because there's some softmaxes there. But the essence of the map balls are the same. So that's the same number of flops. And then you write to HBM. OK, so here I'm assuming there'll be more bytes transferred. If you didn't use flash attention, flash attention means that you don't have to keep on writing back to HBM into intermediate steps.

**中文**: 因此请记住，在预填充（prefill）阶段，s 和 t 是相等的。所以计算量为序列长度的平方乘以 b 再乘以 d。接下来，我仅关注矩阵乘法部分，因为其他步骤的浮点运算量（FLOPs）实际上并不重要。然后，你将该结果与 v 进行组合（哦，抱歉，此处应为“与 v 进行线性组合”）。严格来说，这一表述在数学上并不准确，因为其中还涉及一些 softmax 运算；但就映射操作的核心本质而言，其计算量是相同的，因此 FLOPs 数量也相同。最后，将结果写入高带宽内存（HBM）。好的，此处我假设会有更多的数据字节被传输。如果你未采用 Flash Attention，则意味着你必须在中间计算步骤中反复将数据写回 HBM。

## 段落 28

**英文**: But the order is actually not really affected. So qualitatively, it doesn't really matter whether you use flash attention or not. But the math here depends on the constants matter. But let's look at the flops and the bytes transferred. And if you divide and simplify, you get this rather nice expression. I mean, nice in that it's simple, not nice in that it's good efficiency, which is s times t divided by s plus t. So let's try to interpret this a bit. So in prefill, t equals s. So that means your prefill intensity is order s. So that's good, right? Because as long as you have long enough sequences, then you're good to go.

**中文**: 但该顺序实际上并未真正受到影响。因此，从定性角度看，是否使用Flash Attention并无实质影响。然而，此处的数学计算依赖于常数项。我们来看一下浮点运算量（FLOPs）和传输字节数。若进行相除并化简，即可得到这一相当简洁的表达式——我所谓“简洁”，是指形式简单，而非意味着效率高：即 $ s \times t / (s + t) $。下面我们稍作解读：在预填充（prefill）阶段，$ t = s $，因此预填充的计算强度为 $ O(s) $ 级别。这很好，对吧？因为只要序列足够长，就能达到理想效果。

## 段落 29

**英文**: And generally, the sequences can assume long enough. During generation, however, you'll. see that the intensity is essentially 1, s over s plus 1. But that's basically 1. And remember, 1 is really bad. So but notice like, what? There's no dependence on v at all. So unlike an MLP, remember an MLP's, the generation of the prefill was bt, which is great. And then every mega intensity was b, which was not great because it depends on the whims of your users and workloads, but still could be larger than 1. Whereas for attention, it's actually just always less than 1. No matter how long your sequences are, how many users there are, it's always 1.

**中文**: 通常情况下，序列长度可以足够长。然而在生成过程中，您会发现强度实际上为 $ s/(s+1) $，而这基本等于 1。但请记住，强度为 1 实际上是非常糟糕的。不过请注意：该强度完全不依赖于 $ v $。因此，与多层感知机（MLP）不同——回想一下，MLP 的预填充阶段生成强度为 $ b_t $，这非常理想；而后续每个“兆强度”（mega intensity）则为 $ b $，这并不理想，因为它取决于用户的随机行为和工作负载状况，但仍可能大于 1。相比之下，注意力机制的强度则始终小于 1：无论序列多长、用户数量多少，其强度恒小于 1。

## 段落 30

**英文**: So why is this intuitively that there's no dependence on b, the batch dimension?. So the reason is that in the MLP layers, intuitively, every sequence hits the same MLP weights. So whereas in attention layer, each sequence has its own kv cache, because the kv cache is sequence specific, which means that you can't really use in the MLP case, you can read all the weights and then you process a batch intuitively. Whereas in an attention case, every sequence. kind of requires additional memory. You don't get any kind of savings if you batch them up. Mathematically, I guess you can look at it through here, where the number of flops, there's a b here, which is expected. But the number of bytes transferred is b times that there's a scaling in mb. So when you divide that b cancels, whereas over here, there is a b here, but we're assuming that df dominates. So when you divide, basically, there's no b essentially left in the denominator.

**中文**: 那么，为什么直观上这里不依赖于批处理维度 \( b \) 呢？原因在于：在多层感知机（MLP）层中，直观上每条序列都作用于相同的 MLP 权重。而在注意力层中，每条序列拥有各自独立的 KV 缓存，因为 KV 缓存是序列特定的；这意味着在 MLP 场景下，你可以一次性读取全部权重，然后直观地对整个批次进行处理；但在注意力场景下，每条序列都需要额外的内存，因此将序列批量处理并不能带来任何内存或计算上的节省。从数学角度看，可以这样理解：浮点运算量（FLOPs）中包含一个因子 \( b \)，这是预期之中的；但数据传输字节数则为 \( b \) 乘以某个量，即在 \( mb \) 上存在一个缩放关系。因此，当我们将二者相除时，\( b \) 被约去；而在此处，虽然也存在一个 \( b \)，但我们假设 \( d_f \) 占主导地位，因此相除后分母中实际上不再剩下 \( b \)。

## 段落 31

**英文**: So you can look at it mathematically, or you can just kind of reason about it intuitively as, for the attention, the kv cache is sort of every sequence is own unique snowflake. So the summary is, pre-fill is compute limited, where generation is memory limited. The MLP arithmetic intensity is b, which to make good enough, you need a bunch of concurrent requests. But attention intensity is 1, which, and it's also even possible to improve that. I'll pause a bit for any questions. OK, so let's move on. So now we know that inference is due thanks to generation is memory limited. Let's try to study the throughput and latency, at least in theory. So let's focus on, let's see, actually, OK. Let's see, actually, OK.

**中文**: 因此，你可以从数学角度来分析它，也可以凭直觉进行推理：就注意力机制而言，每个序列的键值缓存（KV Cache）都如同独一无二的雪花。总结来说，预填充阶段受计算能力限制，而生成阶段则受内存带宽限制。MLP的计算强度为b，要达到足够高的效率，需要大量并发请求；而注意力机制的计算强度为1，且该数值甚至还有进一步优化的空间。我稍作停顿，以便大家提问。好的，我们继续。现在我们已知，由于生成阶段占主导，推理过程受限于内存带宽。接下来，我们尝试从理论上分析吞吐量与延迟。那么，让我们聚焦于此——嗯，实际上，好的。让我们来看一下——实际上，好的。

## 段落 32

**英文**: So we're going to make some assumptions. So all of this sort of napkin math is a little bit stylized, but it gives you roughly the right kind of scaling and the right way to think about things. So we're going to assume that communication and compute can be perfectly overlapped, which is obviously false, but it's good enough for making these qualitative estimates. So what we're going to do is we're going to instantiate the latency and throughput for a long time to 13b on H100. So for a 13b, here are the values. So let's just put the sequence length to be 1,000,. hidden dimension to be 5,000, 4 times, actually. I don't know if that's not 4 times. But anyway, F is some multiple of that, number of heads, number of key value, I guess query heads, number of key value heads, which for a long time, two is the same. We'll get to that point later and so on.

**中文**: 因此，我们将做出一些假设。所有这类“餐巾纸演算”都略带理想化，但能大致给出正确的缩放关系和思考问题的正确方式。我们假设通信与计算可以完全重叠——这显然不成立，但对于进行这些定性估算已足够。接下来，我们将基于H100硬件，为13B模型长期运行时的延迟和吞吐量设定具体数值。对于13B模型，参数取值如下：序列长度设为1,000，隐藏层维度设为5,000（实际为4倍，不过我不确定是否确为4倍）；F是该值的某个倍数；头数、键值头数（即查询头数）以及键值头数，在很长一段时间内均为相同数值（此处为2），后续我们会进一步讨论这一点等。

## 段落 33

**英文**: And for the memory bandwidth of H100, that's the number. OK, so that's the config. And we're going to compute the memory, latency, and throughput. OK, so. So first, let's just quickly get the number of parameters. You guys did this in Simon 1, so I won't be labor this, but it's some expression that depends on all the different variables. And to store the parameters, we're going to use F, BF16, because inference is generally going to be 16 bit, not 32 bit. So we're going to multiply it to you. So that's the memory that the parameters take. OK, we don't need gradients, we don't need optimizer states because we're not training.

**中文**: 至于H100的内存带宽，就是这个数值。好的，以上便是配置。接下来我们将计算内存占用、延迟和吞吐量。首先，我们快速计算一下参数量——大家在Simon 1中已做过此类计算，因此我就不赘述了，其表达式取决于所有相关变量。为存储参数，我们将采用FP16（BF16）格式，因为推理通常使用16位而非32位精度，因此需将参数量乘以相应的字节数。这就是参数所占用的内存。由于我们仅进行推理而不训练，因此无需存储梯度，也无需优化器状态。

## 段落 34

**英文**: But we do have to store the KV cache, which. are some of the activations, not all the activations, but some of them, for every sequence of length S. And how much do we have to per store per sequence? It's basically the sequence length times the number of key value heads times the dimension of that head, times the number of layers, times basically 2 for basically both the key and the value and 2 for BF16. OK, so that's how much the cache size takes. And so the total memory is the batch size times the cache per sequence plus the parameter size. So now, latency is going to be determined by memory. It's memory limited. So we're just going to compute how much memory needs to be transferred into the GPU to do this computation. And it's simply memory over the memory bandwidth. And throughput is essentially the inverse of latency,.

**中文**: 但我们确实需要存储KV缓存，即每条长度为S的序列所对应的部分激活值（并非全部激活值，而仅其中一部分）。那么，每条序列需存储多少缓存呢？其大小基本等于：序列长度 × 键值头数量 × 每个头的维度 × 网络层数 × 2（分别对应键和值）× 2（BF16格式每个数值占2字节）。这就是缓存所需内存总量。因此，总内存用量等于批处理大小乘以每条序列的缓存大小，再加上模型参数所占内存。此时，延迟将由内存决定，即受限于内存带宽。我们只需计算完成该计算所需传入GPU的内存量，再除以内存带宽，即可得到延迟。而吞吐量本质上就是延迟的倒数。

## 段落 35

**英文**: but scaled up by B, because we're looking at generating B tokens in parallel. So now, if we substitute our Lama 2 config, we'll see that the number of parameters checks out. It's 13 billion. Roughly, the memory, latency and throughput have these expressions. So memory grows, obviously, this is the parameter size. This is the key value cache size times B. latency also goes up as a function of B. throughput increases, but you'll see that it increases up to a point. The B shows up in both the numerator and the denominator. So there's limits to how much you can search throughput, even if you could put everything in memory.

**中文**: 但需乘以B，因为我们关注的是并行生成B个词元。因此，现在若代入Llama 2的配置，即可验证参数量确实为130亿。内存、延迟和吞吐量的大致表达式如下：内存显然随参数量增长，此处为参数量加上键值缓存大小乘以B；延迟亦随B增大而增加；吞吐量虽有所提升，但仅在一定范围内上升——由于B同时出现在分子与分母中，因此即使所有数据均可装入内存，吞吐量的提升也存在上限。

## 段落 36

**英文**: OK, so those are the expressions for latency, throughput, and memory for this particular model. So now, let's instantiate with different batch sizes. So if B equals 1, then the latency is about 8 milliseconds. So every 8 milliseconds, you generate a token. And the throughput is 124 tokens per second. So that's 13B on H100 if you're using batch size of 1. So now, what happens if you use batch size of 16? So you'll see that the memory usage increases because you need to store the KV cache for all 64 sequences now. The latency goes up because you kind of have to, instead of just processing one, you have to kind of wait for everything to finish. But the throughput also goes up actually quite a lot. So you're seeing kind of this immediate trade-off between latency and throughput.

**中文**: 好的，以上便是该模型在延迟、吞吐量和内存占用方面的计算表达式。接下来，我们代入不同的批处理大小（batch size）进行具体分析。当批处理大小 $ B = 1 $ 时，延迟约为 8 毫秒，即每 8 毫秒生成一个词元（token）；吞吐量为每秒 124 个词元。这意味着，在使用单样本批处理时，130 亿参数模型（13B）可在 H100 上达到这一性能。那么，若将批处理大小提升至 16，情况会如何？此时，内存占用会上升，因为你需要为全部 64 个序列（注：此处应为 16 个序列，原文“64”疑为笔误，但依原文直译）存储 KV 缓存；延迟也会增加，因为你不再仅处理单个样本，而需等待整个批次全部完成；但吞吐量实际上却大幅提升。由此可见，延迟与吞吐量之间存在一种立竿见影的权衡关系。

## 段落 37

**英文**: If you want low latency, you just use one B equals 1. But if you want high throughput, you want larger B in general. What happens if you use batch size of even larger? So 256. You'll see that low latency goes up, throughput goes up. But you see that throughput isn't going up that much because you get the machine returns after a while. But the most kind of, you can actually do this on A or 200. Because if you look at the memory, it's 240 gigs. So it doesn't even fit. So the batch size, you can only increase to a certain point because of memory. So just to recap, there's a trade-off between latency and throughput.

**中文**: 如果追求低延迟，只需将批处理大小设为1（即B=1）；但若追求高吞吐量，通常需要更大的B值。那么，若进一步增大批处理大小（例如设为256），会发生什么？您会发现：延迟上升，吞吐量也上升，但吞吐量的提升幅度并不显著，因为设备最终会达到性能瓶颈。实际上，您甚至无法在A或200型号设备上执行此操作——因为查看其内存容量仅为240GB，而模型根本无法装入。因此，受内存限制，批处理大小只能增加到某一上限。简言之，延迟与吞吐量之间存在权衡关系。

## 段落 38

**英文**: Smaller batch sizes, you would better latency, larger batch sizes, you'd better throughput. And finally, last week we talked about parallelism for training. And it was kind of complicated annoying. At least one type of parallelism for inference is really, really nice and simple. You just launch M copies of a model. No communication because you don't need to update the models. The latency is the same. And the throughput increases by M. So that's pretty good. So always remember that, don't forget easy things.

**中文**: 批量大小越小，延迟越低；批量大小越大，吞吐量越高。最后，上周我们讨论了训练时的并行化，其过程相当复杂且烦琐。但至少有一种推理时的并行化方式非常简洁易用：只需启动 M 个模型副本即可。由于无需更新模型，各副本之间无需通信；延迟保持不变，而吞吐量则提升为原来的 M 倍。这效果相当不错。因此请务必牢记这一点，切勿忽视这些简单有效的方法。

## 段落 39

**英文**: Now, there are cases where if you have a large enough model,. then maybe it doesn't even fit on a single GPU. And you need to charge the model. And in this case, you also want to start sharding the KV cache in some cases to get better efficiency. So for more details, check out this book chapter. OK, so the time to first token, which is a metric I mentioned earlier, is essentially. a function of the pre-fill. It's basically how long does it take to encode the prompt. And usually, this is compute-limited. So you're basically going as fast as you can.

**中文**: 目前，存在这样一种情况：如果你的模型足够大，甚至无法完整地加载到单个GPU上，此时就需要对模型进行分片处理。在这种情况下，有时你还需要对KV缓存进行分片，以提升运行效率。更多详细信息，请参阅本章图书内容。  
好的，之前提到的“首词元生成时间”这一指标，本质上取决于预填充阶段，即对输入提示进行编码所需的时间。通常，该阶段受计算能力限制，因此系统会以尽可能快的速度执行。

## 段落 40

**英文**: And there's not much you can do about it given a fixed architecture. And well, OK, so sorry. You can improve it if you reduce the batch size still. But if you want to improve the throughput, you have to increase the batch size. So any questions about that? So this was on computing the throughput and latency. And because of the memory-limited argument that I gave in the previous part, I just focus on memory and compute how many bytes need to be sent. And that gives me a rough bound on the latency. In practice, the compute, there are some regimes where a compute does matter. But I'm sort of ignoring that just to keep things simple. OK, question? Is this a Ziumi-A-S-A-G-V-E? Yes, this is a Ziumi-A-S-A-G-V-E-G-V-E.

**中文**: 而在固定架构下，你对此几乎无能为力。嗯，好吧，抱歉。不过，你仍可通过减小批量大小来改善这一状况。但若想提升吞吐量，则必须增大批量大小。对此大家有什么问题吗？以上讨论的是吞吐量与延迟的计算。由于前一部分中我提出的内存受限论点，我仅聚焦于内存，并据此计算需传输的字节数，从而得出延迟的一个粗略上限。在实际中，计算开销在某些情况下确实会产生影响；但为简化分析，我暂且忽略这一点。好的，有问题吗？这是Ziumi-A-S-A-G-V-E吗？是的，这就是Ziumi-A-S-A-G-V-E-G-V-E。

## 段落 41

**英文**: Why are you creating a batch from anybody who's a feature of this?. No, it's a little bit complicated. No, they have a feature. This is a little bit complicated. So they use this one to use it. Yeah, so the question is, if you have multiple users and your batches together, they might arrive at different times. They're going to finish at different times. So we're going to get to that. That's going to be a special issue that we're going to have to deal with. Any other questions? OK, so now we have a good handle on what the inference workload looks like.

**中文**: 为什么你要从任何具备此功能的人中创建批处理？不，这有点复杂。不，他们具备这一功能。这有点复杂。因此，他们使用这个来实现该功能。是的，所以问题在于：如果你有多个用户，并将他们的请求合并为一批，这些请求可能在不同时间到达，也会在不同时间完成。我们稍后会讨论这一点。这将是我们必须专门应对的一个特殊问题。还有其他问题吗？好的，现在我们已经很好地掌握了推理工作负载的具体情况。

## 段落 42

**英文**: We looked at the arithmetic intensity. We looked at the transformer inference with respect to arithmetic intensity. We saw that was memory limited thanks to the tension, where the KV cache has to be special for every sequence. And then using that, we can compute throughput and latency, which are the main inference metrics that we care about. Now, how do we make things better? So there are some things that you can do on that are lossless. You can write better kernels. You can improve your systems. But I would say that there's a lot you can do if you're willing to take shortcuts. And these are really interesting because technically, this lecture is on inference, but secretly, it's on model architectures. Because what you'll see is that a lot of the changes in model architecture are going to have direct impact on inference and were actually inspired.

**中文**: 我们分析了计算强度，并考察了Transformer推理任务的计算强度。我们发现，由于KV缓存需为每个序列单独维护，导致其受限于内存带宽。基于此，我们可以计算吞吐量和延迟——这两项正是我们最关注的推理性能指标。那么，如何进一步提升性能呢？有些优化方法是无损的，例如编写更高效的内核、改进系统设计等。但我想强调的是，若愿意采取一些折中策略，还能实现大量优化。这些策略尤为有趣：从表面上看，本讲座的主题是推理优化；而实际上，它聚焦于模型架构设计。因为你会发现，许多模型架构的改进会直接影响推理性能，甚至其初衷正是为提升推理效率而生。

## 段落 43

**英文**: by needing to do inference quickly. So the big bottleneck here is the KV cache, because memory limited, which means that the less memory stuff takes, then the faster you go. Not just because of flops, even though that's department, but mostly due to memory, because it's mostly about memory transfers. If that's one thing you take away from the lecture,. it's all about the memory for speed. OK, so the problem is that if you just start walking away at the KV cache, you might lose accuracy. So how can you make sure you don't lose too much accuracy, but still maintain your KV cache small? So there's a bunch of ideas I'm going to go through that all essentially try to change architecture. to reduce your KV cache. Some of these ideas I think you've seen, but I'll go through them in this or more systematic way. So there's this idea called group query attention.

**中文**: 源于需要快速执行推理。因此，此处的主要瓶颈在于KV缓存，因为其受限于内存容量——即占用内存越少，运行速度就越快。这不仅与计算量（FLOPs）有关（尽管这也是一方面），但主要还是受限于内存，因为瓶颈本质上在于内存传输。如果你从本讲中只记住一件事，那就是：速度的关键在于内存。  
好的，问题在于：若直接削减KV缓存，可能会导致精度下降。那么，如何在确保精度损失不过大的前提下，仍维持较小的KV缓存呢？接下来我将介绍一系列思路，其核心均是通过调整模型架构来减小KV缓存。其中部分思路你可能已有所了解，但我将以更系统的方式逐一讲解。首先介绍一种名为“分组查询注意力”（Group Query Attention）的方法。

## 段落 44

**英文**: So multi-head attention, which is the vanilla transformer, keeps around basically a number of heads. And for each of those, that number, you have same number of keys, values, and queries. There was one time a multi-query attention, which you only have one key and one value, basically one key value head. Turn out that that was not very expressive. So there was a intermediate point where you have a reduced number of keys and values, and then you have more queries. So why are we doing this? Well, remember, we want to reduce the KV cache size. So the fewer keys and values there are, the better. So the batch size and the sequence length doesn't get changed, but it's in the dimensionality of these vectors don't change, but it's the number of key value heads that we're reducing. So that's basically the idea. And this paper shows that you do get latency and throughput improvements, so times percent sample.

**中文**: 因此，标准Transformer所采用的多头注意力机制，其基本结构是维持多个注意力头；对于每个头，都对应相同数量的键（Key）、值（Value）和查询（Query）。曾出现过一种“多查询注意力”机制，即仅使用一个键和一个值（本质上只有一个键值头），但实践表明该方法表达能力较弱。于是，人们提出了一种折中方案：减少键与值的数量，同时增加查询的数量。那么，我们为何要这样做呢？请记住，我们的目标是减小KV缓存的大小——键和值越少，效果越好。需要注意的是，批处理大小和序列长度保持不变，各向量的维度也不变，唯一被削减的是键值头的数量。这便是该方法的基本思路。本文实验表明，该方法确实可带来延迟降低和吞吐量提升，即采样时间百分比下降。

## 段落 45

**英文**: And as you increase the number of groups,. then up to eight or so, basically there's a negligible, it's really fast compared to the full attention. And as you increase the number of groups, obviously, you end up at the original. So that's latency and throughput improvements. And just to actually do this more rigorously, so we have our Lama to 13b model. And if we compute the statistics, this. is using a batch size of 64. Remember, this is what we got. I guess I should print out latency here, well. And then if you run it with a GQA, you see that the memory is reduced, and the throughput goes way up.

**中文**: 随着分组数量的增加（最多约八组），其开销几乎可以忽略不计，速度远快于全注意力机制。而当分组数持续增加时，最终将回归原始的全注意力形式。这带来了延迟降低和吞吐量提升的效果。为更严谨地验证这一点，我们以Llama-13B模型为例，在批处理大小为64的条件下进行统计分析——此处应显示延迟数据。而若采用分组查询注意力（GQA）运行，则可观察到内存占用显著减少，吞吐量大幅提升。

## 段落 46

**英文**: So this is actually great. So this is what happens if I take the Lama to 13b architecture,. and I just reduce for every key value head I have five query heads. That's what one to five ratio means. So this also means we can use a larger batch size, because remember, last time we tried to do 256, it even fit in an H-1-100's memory. So now we can actually comfortably fit into the H-1-100 memory, and then we can further improve the throughput. by using a larger batch size. So you can see kind of a lot of different effects here by reducing the number of key value pairs, the memory of the KV cache reduces. That means the throughput and latency go up automatically because fewer memory transfers, and furthermore, as a secondary effect, I can increase the batch size within the GPU, and that further improves the throughput. OK, so that's wonderful.

**中文**: 因此，这实际上非常棒。具体来说，当我将Llama模型采用13B参数架构，并将每个键值头（key-value head）对应的查询头（query head）数量从原先的设定减少为5个时，就实现了1:5的查询头与键值头比例。这也意味着我们可以使用更大的批处理尺寸（batch size）；还记得上次我们尝试使用256的批处理尺寸时，甚至已超出H100显卡的显存容量。而现在，我们完全可以轻松地将模型放入H100显存中，并进一步通过增大批处理尺寸来提升吞吐量。可以看到，通过减少键值对（key-value pairs）的数量，KV缓存（KV cache）所需的内存随之降低；这意味着吞吐量和延迟会自动改善，因为所需内存传输更少；此外，作为次要效应，我还能在GPU内进一步增大批处理尺寸，从而进一步提升吞吐量。很好！

## 段落 47

**英文**: We have to also make sure the accuracy doesn't drop. So this is this original paper that shows that this is full attention. This is GPUA. The time is much less, but the accuracy is basically the same. Now, what actually happened? So Lama II did not use this ratio,. but Lama III actually picked up a GQA, and probably motivated by the kind of inference cost. Actually, Lama II, I think the large model did have GQA, but not the smaller ones. So that's a GQA. There's another way to reduce the key value cache. And this comes from deep seek.

**中文**: 我们还必须确保准确率不会下降。因此，这篇原始论文展示了这是完整的注意力机制，而这是GPUA（分组查询注意力）。其耗时大幅减少，但准确率基本保持不变。那么，实际情况究竟如何呢？Llama II并未采用这种比例方法，而Llama III实际上采用了GQA（分组查询注意力），这很可能是出于降低推理成本的考虑。实际上，我认为Llama II的大模型确实使用了GQA，但小模型并未采用。这就是GQA。此外，还有另一种减少键值缓存的方法，该方法源自DeepSeek。

## 段落 48

**英文**: So this is actually from the deep seek V2 paper,. and it's called multi-head latent tension, which taught to lecture it about previously, but I'll try to talk about it in the context of inference and its implications. So the basic idea is here's full attention. And GQA says, I'm going to use fewer keys and values. MLA says, I'm not going to change the number of key and values. I'm going to project these into a lower dimensional space. So it's another way of shrinking the KV size, but just in a different dimension. So instead of using n times h dimensions for the KV cache of each token, I'm going to project out to C dimensions. And this is what deep seek did. It's actually quite a aggressive reduction from 16,000 to 512.

**中文**: 因此，这实际上源自DeepSeek V2论文，称为“多头潜在注意力”（multi-head latent attention）。此前我曾讲解过该技术，但本次我将结合推理过程及其影响加以阐述。其基本思想如下：此处展示的是完整注意力机制；而分组查询注意力（GQA）提出：将减少键（Key）和值（Value）的数量；而多头潜在注意力（MLA）则表示：不改变键与值的数量，而是将其投影到一个更低维的空间中。因此，这是另一种缩减键值（KV）缓存尺寸的方法，只是在不同维度上实现。具体而言，不再为每个token的KV缓存使用n×h维，而是将其投影至C维。DeepSeek正是采用了这一方法，其降维幅度相当激进——从16,000维大幅缩减至512维。

## 段落 49

**英文**: Only wrinkle is that this is not compatible with ropes,. so they need to add a few more dimensions to put rope back in. But overall, this is actually quite promising from a KV reduction perspective. I'm not going to do the math, but you can just trust me that you can see how the KV cache would be reduced a lot, and you get to the same latency and throughput advantages. And in terms of accuracy, they actually showed that compared to GQA, the mh. Sorry, actually, maybe I'm showing the wrong thing here. Maybe mh. OK. I meant to show that the MLA actually improves, but this table does not show that, so I have to dig that up later. But anyway, the MLA does preserve the accuracy as well.

**中文**: 唯一的不足是该方法与绳索（rope）位置编码不兼容，因此需要额外增加几个维度以重新支持绳索编码。但总体而言，从KV缓存缩减的角度来看，这一方法实际上颇具前景。我不会在此进行具体计算，但你可以相信：KV缓存将大幅减少，同时仍能获得相同的延迟和吞吐量优势。在精度方面，他们实际展示的结果表明，相较于GQA（分组查询注意力），MLA（多头潜在注意力）——抱歉，此处可能我展示错了，或许是“mh”……好吧，我的本意是展示MLA确实有所提升，但当前这张表格并未体现这一点，因此我稍后需另行查找相关数据。不过无论如何，MLA同样能保持模型精度。

## 段落 50

**英文**: OK, so there's another idea, which says, well, GQA basically shares, you can think about it. as a sharing key value vectors, right? Within a token and within a sequence. But we can also look at something called cross layer attention, which there's a paper on this. But I think many people have been thinking about this and doing this. So I know none of this is actually the first paper. But basically, if you look at the Transformer I diagram,. you have the key value projection of one layer, and then you have the next layer. And these key value vectors are separate, usually. But the idea here with CLA is that we're just going to use the same key value projection across layers. That's why it's called cross layer attention.

**中文**: 好的，还有另一种思路，即GQA本质上是共享的——你可以将其理解为在单个词元内部以及整个序列内部共享键值向量，对吧？但除此之外，我们还可以考虑一种称为“跨层注意力”（CLA）的方法，这方面已有一篇相关论文。不过我认为，许多研究者早已开始思考并实践这一方法。需要说明的是，本文所提内容并非该方向的首篇论文。但基本思想是：观察标准Transformer架构图可知，每一层都有其独立的键值投影，下一层亦然；通常情况下，这些层间的键值向量彼此分离。而CLA的核心思想，则是在不同层之间复用同一套键值投影，这正是其被称为“跨层注意力”的原因。

## 段落 51

**英文**: So just as GQA shares across heads, CLA shares across layers. So here they show that they empirically improve the Pareto Frontier of accuracy and the KV cache size. So KV cache size, which relates to throughput and latency, you want to be small, and you want perplexity also to be small. So they're able to improve that. OK. So notice that, I mean, for example, H64 heads, the cache size goes, it gets reduced, but the validation perplexity does go up a little bit. But overall, there's kind of a advantage in making that trade off. So there's another way to do things. So local attention, which has been explored actually quite a bit since even there's a long former, there's. an opening-eye paper, and then mistro, and I think many others use this as well.

**中文**: 因此，正如GQA在注意力头之间共享信息一样，CLA则在不同网络层之间共享信息。此处他们通过实证表明，该方法能够改善准确率与KV缓存大小之间的帕累托前沿。KV缓存大小关系到吞吐量和延迟，越小越好；同时困惑度（perplexity）也应尽可能小。而该方法确实在这两方面均实现了提升。好的。请注意，例如在64头（H64）配置下，缓存大小有所降低，但验证困惑度却略有上升。不过总体而言，这种权衡仍具有优势。此外，还有其他方法可选，比如局部注意力（local attention）。该方法其实早已被广泛探索——早在长程Transformer（Longformer）中就已提出，随后有Open-ELM论文，再到Mistral模型，我认为许多其他模型也采用了这一机制。

## 段落 52

**英文**: It's a very, I guess, a natural idea. Instead of, if you look at a full attention diagram, it's dense and squared. And that's where a lot of your complexity comes from. And basically, the idea is you're going to just attempt to only the past k tokens, which. means that in the kv cache, as you're generating the sequence, you don't have to remember everything. As soon as the token kind of falls outside your window that you have attention, you can just throw it away. So local attention is very, you could say, that the kv cache size remains constant, as opposed to growing with a sequence length. So this is really good, because that even. long sequences you can have quite a small cache. But the problem is that this still hurts accuracy, because if you just think about it, why are we doing attention instead of RNNs, is that we needed to have long range to match model-run long range dependencies.

**中文**: 这其实是一个非常——我姑且称之为——自然的想法。如果你观察完整的注意力机制示意图，它呈现出稠密且呈正方形的结构，而这种结构正是导致大量计算复杂性的根源所在。其基本思路是：仅对最近的 k 个词元（tokens）进行注意力计算。这意味着，在生成序列的过程中，键值缓存（kv cache）无需保存全部历史信息；一旦某个词元超出了当前注意力窗口的范围，便可直接将其丢弃。因此，局部注意力机制可使键值缓存的大小保持恒定，而非随序列长度增长而线性增加。这一点极具优势，即使处理很长的序列，也能维持相当小的缓存规模。但问题在于，这种方法仍会损害模型精度——试想一下，我们之所以采用注意力机制而非循环神经网络（RNN），正是为了建模长距离依赖关系。

## 段落 53

**英文**: And this is, in some sense, even the color attention is a little bit overselling. This is only looking at the local context, which is not very expressive. So what you do here is you can interleave local attention with full global attention, hybrid layers. So for example, a character I used for every six layers, they had one global layer and five local layers. So it looks something, it deductions to cross-layer attention. So it looks something like this, where full attention, every layer, you have to store the kv cache. And for what they did is that for every six layers, you have the full attention. But in between you have this local attention. And on top of that, they have kv cache sharing locally, both for the local attention and the global attention. So this is like all the tricks, not all the tricks,.

**中文**: 从某种意义上说，甚至“颜色注意力”这一说法都略显夸大。这实际上仅关注局部上下文，表达能力并不强。因此，此处的做法是将局部注意力与完整的全局注意力交错使用，形成混合层。例如，作者每六层中设置一层全局注意力层和五层局部注意力层。这种结构在某种程度上可视为跨层注意力。其结构大致如下：若每层均采用完整注意力机制，则需为每一层存储键值（KV）缓存；而他们采取的方案是每六层中仅有一层采用完整注意力机制，其余层则采用局部注意力机制。此外，他们还在局部范围内共享键值缓存，既适用于局部注意力，也适用于全局注意力。这几乎汇集了所有技巧——但并非全部技巧。

## 段落 54

**英文**: but many of the tricks combined together. So in summary, these are a few ways to reduce the kv cache size, because remember, inference is memory-limited. So you want to reduce the cache size, but you don't want her accuracy too much. And there's many ways to do it. You can lower the dimensionality of the kv cache. You can have few kv cache vectors. You can reduce the dimensionality of a kv vector. You can share the kv cache across layers. And also, you can use local attention on some of the layers. OK.

**中文**: 但许多技巧是组合使用的。总而言之，以上是几种减小KV缓存大小的方法，因为要记住，推理过程受内存限制。因此，我们希望减小缓存大小，但又不能过度牺牲精度。实现这一目标的方法有很多：可以降低KV缓存的维度；可以减少KV缓存向量的数量；可以降低单个KV向量的维度；可以在不同层之间共享KV缓存；还可以在部分层中采用局部注意力机制。

## 段落 55

**英文**: Any questions about the set of tricks for reducing the kv cache? Oh, yeah. Yeah. I'm talking about the cross layer. And so like, I mean, like, the weights are people being shared across the layers. Like, do you just have one set of weights? We're just like kv. And that's shared across the group. Yeah. So the question is, are the weights shared? So the kv cache is shared, but the weights are shared. So what happens is the weights for doing the projection need be shared, so there's some consistency. Yeah, there's another question.

**中文**: 关于减小KV缓存的一系列技巧，大家有什么问题吗？哦，对，是的。我刚才讲的是跨层共享，也就是说，权重在各层之间共享，比如，是否只有一组权重？就像KV缓存那样，在整个组内共享？是的。所以问题是：权重是否共享？实际上，KV缓存是共享的，权重也是共享的。具体来说，用于执行投影操作的权重需要共享，以保证一致性。是的，还有另一个问题。

## 段落 56

**英文**: The context size is too large. Have we, and then it increases the kv cache as well to context size?. And you come there and there. The context that is limited to the large length of the kv cache. Yeah. It can be too long. Then it increases the range. So for me, probably, using those context size, some of the context of your context. Yeah. So the question is, if you have really long context, let's say your prompt is huge, that's going to intrinsically take a log of kv cache.

**中文**: 上下文长度过大。我们是否已如此处理？同时，KV缓存容量也会随之扩展至该上下文长度？而你便由此而来，又由此而去。受限于KV缓存最大容量的上下文长度——是的，可能过长；因此其范围也随之扩大。所以对我而言，很可能需利用这些上下文长度中的一部分。是的。问题在于：若上下文确实极长，比如提示词（prompt）非常庞大，那么这本身就会占用大量KV缓存。

## 段落 57

**英文**: So all these tricks can try to reduce that. You can do more aggressive things that there's ideas like just tokens or ways to summarize the prompt, which we're not going to talk about in this class, but there's ways of that address the long prompt situation as well. OK. So now I'm going to talk about even more radical ways of making inference go faster by changing the transformer. So the kv cache, these are basically variants of the transformer. But maybe you can actually go outside the transformer and do better, because the transformer wasn't really designed with heavy inference workloads in mind. They were just trying to train a good model that efficiently. It was mostly about training efficiency. And the order regression, as we sort of pointed out, is really causing this bottleneck here with all the regression plus the forward tension. So we're going to talk about two directions, state space models and diffusion models.

**中文**: 因此，所有这些技巧都旨在缓解这一问题。你还可以采取更激进的措施，例如仅使用词元（tokens）或对提示进行摘要等方法——这些内容我们本课程暂不讨论，但确实存在一些专门应对长提示问题的方案。好的，接下来我将介绍一些更为激进的方法，即通过改造Transformer架构来进一步加速推理过程。KV缓存本质上属于Transformer的各种变体；但或许我们完全可以跳出Transformer框架，实现更优性能，因为Transformer最初并非针对繁重的推理负载而设计，其主要目标是高效地训练出一个性能优良的模型，重点在于训练效率。而如我们之前所指出的，自回归机制恰恰在此处造成了瓶颈，即反复执行自回归生成与前向传播所带来的双重压力。因此，我们将重点探讨两个方向：状态空间模型（State Space Models）和扩散模型（Diffusion Models）。

## 段落 58

**英文**: This is going to be fairly quick. So the idea of state space models is actually drawing ideas from signal processing and control theory. Initially, the motivation was trying to model long context sequences without suffering the n-squared blowup. So it wasn't necessary about inference speed, but it turns out if you solve that problem, you get faster inference, too. So there's a kind of early paper on s4, which uses classical state space models, which are basically these linear dynamical systems, which are used to model long contexts and sort of shoehorning them into the kind of a modern neural setup. This work is nice in that. It has sort of this RNN kind of interpretation due to the linearity structure and also has a convolution. interpretation as well. So they published this paper and show that it worked really well on these long context synthetic tasks. But what they found is that what discovered is that they don't really work well for language modeling.

**中文**: 这将进行得相当快。状态空间模型的思想实际上源自信号处理和控制理论。最初，其动机是尝试对长上下文序列建模，同时避免平方级的计算复杂度增长。因此，这一目标并非直接针对推理速度，但事实证明，若解决了该问题，推理速度也会随之提升。早期有一篇关于S4的论文，采用了经典的状态空间模型（本质上即线性动力系统），用以建模长上下文，并将其巧妙地融入现代神经网络框架中。这项工作颇具价值：一方面，由于其线性结构，它具有某种类似循环神经网络（RNN）的解释性；另一方面，它也具备卷积解释性。作者发表了这篇论文，并展示了其在长上下文合成任务上表现极为出色。但他们随后发现，这类模型在语言建模任务中实际效果并不理想。

## 段落 59

**英文**: And that's obviously kind of a disappointment because a lot of the value of transformers is being able to do language well. So in a series of papers, there was the sort of identified a set of kind of synthetic tasks that captured the essence of why these models weren't working well. And that's basically these associative recall tasks. So here's a synthetic task where you're given a basically sequence of key value pairs. And the goal is to predict basically look up the key output value. So in some sense, it's kind of a logically a trivial task. But it's long sequence because I can have a lot of key value pairs. And I'm going to have to look far back. It can be arbitrary long dependence. And you can see that local attention is not going to work very well because it's just going to remember the last few sequences.

**中文**: 而这显然令人失望，因为Transformer的诸多价值恰恰在于其出色的语言处理能力。因此，在一系列论文中，研究人员提出了一组合成任务，用以揭示这些模型表现不佳的根本原因，其中核心便是关联式回忆任务。具体而言，这是一种合成任务：输入为一系列键值对构成的序列，目标则是根据给定的键预测对应的输出值。从某种逻辑角度看，该任务本身极为简单；但由于键值对数量可以非常多，导致序列长度很长，且需要回溯到非常遥远的位置进行查找，从而形成任意长度的长程依赖关系。显然，局部注意力机制在此类任务中效果不佳，因为它仅能记住最近的若干序列元素。

## 段落 60

**英文**: And what the problem with state space models is that they were sort of good for these kind of signal processing tasks. But really, this is like you need to isolate a particular key value pair and pull out the answer. And for those types of tasks, it didn't really work. So there's a bunch of work. I'm not citing. There's a Kainah, H3, and then Mamba, which basically tweak or change the HSSM to basically handle these associative recall tasks. And eventually it worked better. Up to kind of 1B scale was matching transformers. And Mamba, the idea of Mamba has been popular and scaled up even to 52B MOE by A21 folks. Notice that in this case, they still had to use a transformer.

**中文**: 而状态空间模型的问题在于，它们在处理这类信号处理任务时表现尚可；但真正需要的是从数据中精准定位某个特定的键值对并提取答案。对于这类任务，状态空间模型效果并不理想。因此，学界开展了一系列研究（此处未具体引用），例如Kainah、H3以及Mamba等模型，它们通过对HSSM（混合状态空间模型）进行调整或改进，使其能够有效应对关联式回忆任务，并最终取得了更优的效果：在约10亿参数规模下，其性能已能与Transformer模型相媲美。而Mamba的理念尤为流行，已被A21团队进一步扩展至520亿参数的混合专家（MoE）架构。值得注意的是，在此情况下，他们仍需借助Transformer结构。

## 段落 61

**英文**: So a transformer. But only every, I guess, eight layers, they had a transformer, the rest of them were Mamba layers. And so that's so good led to a fairly big savings and speed up. And more recently, there's this revival of this older idea called linear attention, where instead of,. let's see if you're going to miss this bigger, is actually a very simple idea. So you know what local attention or sliding window attention is. Linear attention is this idea that you essentially, so basically in the attention computation, there's a key and a query, and you dot product on the NA take the exp of that, which is basically giving you a kernel. So you can basically take a Taylor expansion of that. and write that computation as basically dot products of some nonlinear map. So then what you essentially have is you can think about for every key value position, you are basically applying some sort of nonlinearly blowing up into some space and then doing some linear computation over it.

**中文**: 因此，这是一种Transformer结构，但仅每隔约八层才使用一个Transformer模块，其余层则采用Mamba层。这种设计带来了相当可观的计算节省和加速效果。而近期，一种名为“线性注意力”（linear attention）的早期思想再度兴起。该方法的核心其实非常简单：众所周知，局部注意力（local attention）或滑动窗口注意力（sliding window attention）是将注意力范围限制在局部区域内；而线性注意力的基本思路是，在标准注意力计算中，键（key）与查询（query）先进行点积，再对其取指数函数（exp），从而得到一个核函数（kernel）；此时可对该指数函数进行泰勒展开，并将整个计算过程重写为若干非线性映射后的点积形式。因此，本质上，对于每个键-值位置，我们实际上是先通过某种非线性变换将其映射到一个高维空间，再在此空间上执行线性运算。

## 段落 62

**英文**: And because it's linear attention, it actually kind of behaves. like an RNN, and it's linear in the sequence length rather than quadratic. I know that was a little bit fast, but I just want to give you sort of the taste of it. And so this idea has been actually scaled up quite successfully. So there's this organization called Minimax that's training pretty legitimate models up to 456 billion parameter MOEs. And they use this basically linear attention idea. Now they have to use full attention still once in a while. It seems. I don't think people have been able to get around having some full attention, but at least it seems like people have been able to get rid of most of full attention in. Like most of the layers are not full attention anymore.

**中文**: 而且，由于它采用的是线性注意力机制，其行为实际上类似于RNN，计算复杂度与序列长度呈线性关系，而非二次关系。我知道刚才讲得有点快，但只是想让您大致感受一下这个思路。目前，这一理念已相当成功地实现了规模化应用。例如，一家名为“Minimax”的机构正在训练参数量高达4560亿的混合专家（MoE）模型，且基本采用了这种线性注意力机制。不过，他们似乎仍需偶尔使用全注意力机制——据我所知，目前尚无人能完全摆脱全注意力；但至少人们已成功将大部分层中的全注意力机制去除，即绝大多数层已不再依赖全注意力。

## 段落 63

**英文**: They're just either linear layers or local attention layers, which are much, much more efficient. So the linear plus local attention now are actually yielding serious state of our models. And it's probably safe to say that, well, I don't know what exactly the close model providers are doing. But I would suspect that there would be at least as advanced in terms of as efficient as this in leveraging sparsity. So it's kind of an interesting question. When people ask, well, it's attention all you need. as transformers at, well, yes and no. I mean, I guess in some sense there is still the sense it's squared there. Maybe we'll be able to get rid of it. But most of the transformer has been like pretty radically changed by having other much lighter weight components.

**中文**: 它们要么是线性层，要么是局部注意力层，效率要高得多。因此，线性层加局部注意力层目前实际上已使我们的模型达到了相当先进的水平。可以比较有把握地说：虽然我不清楚各大闭源模型提供商具体采用了哪些技术，但我推测，他们在利用稀疏性以提升效率方面，至少已达到与上述方法同等先进的水平。这其实是个颇为有趣的问题。当人们提出“注意力机制就是一切”这一观点时——即认为Transformer架构仅依赖注意力机制即可——答案可以说是“既对也不对”。我的意思是，从某种意义上说，注意力计算的平方复杂度问题依然存在，或许未来我们能彻底消除它；但事实上，Transformer的大部分结构已因引入其他更轻量级的组件而发生了根本性变革。

## 段落 64

**英文**: And you're still able to get much of the same and kind of accuracies. And all of this is really helpful for inference because on these non-full attention layers, you're basically replacing the ordered T KV cache, which grows as a sequence link with something that's constant. And there's papers by that fall up. I think they on the base paper where they go. Either in this paper or in follow-up work, analyzing basically the trade-off between the KV size. and the ability to do various types of recall tasks, which makes sense because if you don't store very much, you won't be able to solve certain tasks. But there is this trade-off curve that you can try to play with. So that's all I'll say about the state space models. So now let's talk about a completely different style of generation models. Defusion models.

**中文**: 而且你仍然能够获得大致相同甚至类似的精度。所有这些对于推理而言都非常有帮助，因为在这些非全注意力层中，你实际上是以一个固定大小的缓存，替代了原本随序列长度增长的有序T KV缓存。已有相关论文对此展开研究——我认为在基础论文或其后续工作中，作者们就深入分析了KV缓存尺寸与执行各类回忆任务能力之间的权衡关系。这十分合理，因为若存储量过小，模型便无法完成某些特定任务；但二者之间确实存在一条可调节的权衡曲线。关于状态空间模型，我就介绍到这里。接下来，我们来探讨一种风格截然不同的生成模型：扩散模型。

## 段落 65

**英文**: So diffusion models have been very popular image generation, but it turned out to be fairly tricky to get working in text, although there recently have been some advances here. So the idea of diffusion is that you, instead of generating art regressively, you're just generating every token in parallel. So obviously, if you only do that via some simple layer, it's not going to be very good. You can't generate all the words in parallel and expect it to be coherent. But what you do is you iterate, and you keep on refining this generation until it gets your final generation that you output. And the idea behind generating parallel, you're no longer art regressively bound. And that generating all tokens in parallel. well can be done in parallel. So you get to saturate your GPUs relatively easy as long as your context length is large enough. So recently, there's this in session labs has produced some pretty interesting models.

**中文**: 因此，扩散模型在图像生成领域一直非常流行，但在文本生成方面却相当难以实现，尽管近期在此方向上已取得一些进展。扩散模型的核心思想是：不采用自回归方式逐词生成，而是并行生成所有词元（token）。显然，若仅通过某一层简单结构直接并行生成，效果必然不佳——你无法期望一次性并行生成所有词语还能保证文本连贯性。实际做法是通过多次迭代，持续优化和修正生成结果，直至获得最终输出。这种并行生成机制摆脱了自回归方式的固有约束，所有词元均可同步生成，因而天然具备并行处理优势；只要上下文长度足够大，就能较容易地使GPU资源达到饱和。近期，In-Session Labs公司便推出了若干颇具新意的模型。

## 段落 66

**英文**: There's not much written about them, but you can see kind of a demo of the generation in process. It just kind of generates code instantaneously,. but it's obviously kind of broken code, and then it kind of refines over time. And this is one of their benchmarks that show that, at least on coding, I'm not sure about other tests, that if you look at that tokens per second, these models are way out here in terms of speed compared to anything that's transformed. Even Jamba remembers like a hybrid,. Mamba transformer architecture is quite slow compared to these diffusion models. So now whether the diffusion models will be general purpose and powerful enough in all of these, that remains to be seen. But I think you have such a lead on the token speed here that even if you can put more compute and kind of recover some of the accuracy losses, if you need to. OK, so the summary here is that I think this whole architecture, novel architecture thing is actually really exciting for inference, because they allow you to side-sep kind of fundamental obstacles. So if you're dealing with attention, you just have this fundamental KVCache obstacle that you can quantize, you can optimize, but it's still there.

**中文**: 关于它们的公开资料并不多，但你可以看到一种正在生成过程中的演示效果。它几乎能即时生成代码，但生成的代码明显存在缺陷，随后会逐步优化完善。这是他们的一项基准测试，表明至少在编程任务上（其他测试结果尚不明确），若以每秒处理的令牌数（tokens per second）为衡量标准，这些模型的速度远超所有基于Transformer架构的模型。即便是采用混合架构的Jamba（即Mamba-Transformer架构），其速度也明显慢于这些扩散模型。至于扩散模型未来能否成为通用型、且在各项能力上足够强大的模型，仍有待观察。但我认为，仅就令牌处理速度这一优势而言，即便需要投入更多算力来弥补部分精度损失，也完全值得。综上所述，我认为这种全新的架构对推理阶段而言确实极具吸引力，因为它能够绕开一些根本性障碍。例如，在处理注意力机制时，始终存在一个固有的KV缓存（KVCache）障碍——尽管可以对其进行量化或优化，但它依然无法消除。

## 段落 67

**英文**: And so by making a kind of state-space model,. you're shrinking that to like a constant size. And as long as you can keep up the accuracy, which is big if, then you win big time. Same with the diffusion models. Audio-aggressive generation is a key bottleneck. Now, if you just generalize, generate things in parallel, now all of a sudden you kind of change the game completely. So there's much more work to be done here,. improving inference. So as you can see now, inference is, the inference game is much broader than it seems at first sight. It's not really about kind of necessary the systems optimizations to make it fast, although you obviously need those.

**中文**: 因此，通过构建一种状态空间模型，可将模型规模压缩至恒定大小。只要能维持精度（这一点至关重要），就能获得巨大优势。扩散模型也是如此。音频的激进生成是一个关键瓶颈。而若仅进行泛化，实现并行生成，游戏规则便会彻底改变。因此，这一领域尚需大量工作来提升推理性能。由此可见，当前的推理优化范畴远比初看之下更为广泛，并不仅限于为提升速度而进行的系统级优化——尽管这些优化显然必不可少。

## 段落 68

**英文**: But I think the real gains are coming from like real radical changes in architecture. OK, so about 10 minutes left, I'll. go through these quickly quantization and model pruning. So quantization, the key idea is just reduce the precision of the numbers. So easy, very easy to do. And the thought is that less memory means a less bytes transferred higher, sorry, this should be lower latency higher throughput. And you do have to worry about accuracy, of course. That's the trade-off. If you look at the different types of formats, FP32 used for training, not used for inference, really. BF16 is sort of a default for inference.

**中文**: 但我认为真正的收益来自于架构层面真正激进的变革。好了，还剩大约10分钟，我将快速介绍量化和模型剪枝。量化的核心思想是降低数值的精度，操作起来非常简单。其理念在于：内存占用减少意味着传输字节数减少，从而带来更低的延迟和更高的吞吐量。当然，你必须关注精度问题，这正是需要权衡之处。若观察不同格式，FP32主要用于训练，实际几乎不用于推理；而BF16则大致成为推理的默认格式。

## 段落 69

**英文**: You can go down to FP8 or int8, which now is less accurate, but much cheaper than even FP8. So people do a bunch of inference in int8, which if you look at the range, I mean, it's an integer. between 127 minus 128, which is not that. It's pretty low precision. And people even go down to int4, which is they're not OK. So int4 is pretty low. There's also other ways you can do. OK, so once you kind of decide that you want to quantize, I guess you could do several things. You can train with the quantization,. but obviously that means you need to retrain models.

**中文**: 你可以进一步降低至FP8或int8精度，后者精度更低，但成本甚至比FP8还要低得多。因此，许多人采用int8进行大量推理运算；若观察其数值范围，它本质上是整数，取值范围仅为-128到127，精度相当有限。甚至还有人进一步降至int4，但这已难以接受。因此，int4的精度极低。此外，还有其他量化方法可供选择。那么，一旦你决定实施量化，便可采取多种策略：例如在训练过程中直接引入量化，但这显然意味着需要重新训练模型。

## 段落 70

**英文**: And more, I guess commonly, you do post-training quantization where you take an existing model and you try to quantize it and try not to screw things up too much. So there's a paper called element int8, which I'll talk through briefly. So in quantization, basically what happens is that you take your vector, which is let's say,. FP16, and then you need to figure out the dynamic range. If you want to pack it into int8, you need to figure out what the largest value is. And once you figure that out, you can divide by that at multiply by 128. And then you get your integers. And then if you need to de-quantize, then you go the other way. So basically, quantization means that remember, memory is a bandwidth. So bottleneck.

**中文**: 此外，更常见的情况是进行训练后量化，即对一个已有的模型进行量化处理，同时尽量避免性能大幅下降。这里有一篇名为《Element Int8》的论文，我将简要介绍其内容。在量化过程中，基本操作是：假设你有一个FP16格式的向量，首先需确定其动态范围；若要将其压缩为int8格式，则需找出其中的最大值；一旦确定该最大值，即可用该值对所有元素进行归一化（即除以该最大值再乘以128），从而得到对应的整数表示；若后续需要反量化，则执行相反操作。本质上，量化意味着——需谨记，内存是一种带宽资源，因此常成为系统瓶颈。

## 段落 71

**英文**: So all your transfers are happening in int8, but when you actually do the, I guess, you sometimes have to upcast to a floating point to actually do the arithmetic. So the problem with int8 is that not everything fits nicely. And you have these outliers, which appear in larger networks that screw things up. So what this paper did is that you take this matrix, you identify the really large outlier values, and then you handle them separately, use in full 16-bit precision, and then do the most of the mass majority in int8. So this works well, but it's actually a bit slower. So the motivation here wasn't an inference speed,. but more, they even be able to fit your model into memory. There's another paper called activation-aware quantization. And here, the idea is that you're kind of quantizing the weights, but you're going to figure out which weights to quantize based on the activations. Really quickly, you're going down to actually in 3.

**中文**: 因此，所有数据传输均以int8格式进行，但在实际执行计算时（我猜），有时需将数据向上转换为浮点数以完成算术运算。int8的主要问题在于，并非所有数值都能很好地适配该格式，尤其在大型网络中会出现一些异常值（outliers），从而导致计算出错。本文提出的方法是：针对该矩阵，首先识别出那些显著偏大的异常值，然后单独对这些异常值采用完整的16位精度进行处理，而矩阵的绝大部分则仍使用int8精度。该方法效果良好，但实际运行速度略慢。因此，该方法的设计初衷并非提升推理速度，而是使模型能够更顺利地装入内存。另一篇论文则提出了“激活感知量化”（activation-aware quantization）方法，其核心思想是在对权重进行量化时，依据激活值（activations）来决定哪些权重需要量化；简而言之，其量化粒度甚至可低至3位。

## 段落 72

**英文**: And this obviously reduces memory by quite a bit, and leads to a 3x speed up. So the general idea here is that you get a trained model and just happens that some of the weights or activations are going to be abnormally large. So for those, you handle separately, and then everything else you can work in low precision. Talk about model pruning ideas. Very like quantization, it's sort of the basic idea is very simple. You just rip out parts of an expensive model to make it cheaper, and then you fix it up. So in this MVD paper, what they do is they first identify important either layers or heads or hidden dimensions using a small calibration size. They use some simple scores to compute that. And then you just remove the unimportant layers or hidden units or heads. And then, now if you just take that model, it's going to be clearly worse.

**中文**: 这显然大幅减少了内存占用，并实现了3倍的加速。此处的核心思想是：你获得一个已训练好的模型，而该模型中恰好存在一些权重或激活值异常偏大。对于这些异常值，我们单独处理；其余部分则可采用低精度计算。接下来讨论模型剪枝的思想。它与量化非常相似，其基本理念极为简单：直接移除昂贵模型中的某些部分以降低成本，随后再对模型进行修复。在该MVD论文中，作者首先利用较小的校准数据集，识别出重要的层、注意力头或隐藏维度，并通过一些简单的评分方法来完成这一过程；接着，直接移除不重要的层、隐藏单元或注意力头。然而，若仅直接使用剪枝后的模型，其性能显然会明显下降。

## 段落 73

**英文**: But so then the last step is you distill the original model into the prune model. So you kind of repair the model from the initialization, which is your prune. So you're not starting from scratch. You're starting from something that's worse,. but hopefully not worse, and hopefully retains a lot of the same structural properties of the original model. It's just maybe not calibrated in some sense. And the results are pretty good on that. So they have these 15 billion parameter models that they're able to reduce to 8B with hardly any drop in this, I guess, at least according to MNLU,. and then down to 4B with some drop. But you're also going down quite a bit to a 4B model.

**中文**: 但最后一步是将原始模型蒸馏到剪枝后的模型中。因此，你实际上是从剪枝后的模型（即初始化状态）出发对模型进行修复，而非从零开始。你所基于的起点虽性能较差，但希望其并未显著退化，并能保留原始模型的大部分结构特性，可能仅在某些方面（如校准）尚不完善。该方法的效果相当不错：例如，他们能将150亿参数的模型压缩至80亿参数，且在MNLU基准上的性能几乎无损；进一步压缩至40亿参数时虽有一定性能下降，但模型规模已大幅缩减。

## 段落 74

**英文**: OK, so maybe just summarize this taking shortcuts idea. You can reduce inference completely without hurting accuracy. You can do it from scratch. We just define a fresh architecture that's by construction fast and just train it. Or you can still define our architecture. You can take a slow model, and you figure out a some sort of scheme to initialize the new model with the old model. And then you basically do distillation. So now all of these are a little bit unsatisfying because they're lossy. So you get massive speed ups, but you always wonder,. well, maybe this model isn't as actually good as original.

**中文**: 好的，我们来简要总结一下“走捷径”这一思路：你可以在完全不损害准确率的前提下大幅降低推理开销。你可以从零开始设计一种天然高效的新架构并直接训练；也可以沿用我们已有的架构，先用一个较慢的模型，再设计某种方案，将该旧模型的参数作为新模型的初始化权重，随后进行知识蒸馏。然而，目前所有这些方法都略显不足，因为它们都是有损压缩——虽然能获得极高的加速比，但人们总会心存疑虑：这个新模型的实际性能，是否真的比得上原始模型？

## 段落 75

**英文**: So speculative decoding or speculative sampling allows you to basically have your kick and eat it too. So recall there's two stages of inference. You pre-fill what you're given a sequence. You encode all the tokens in parallel. There's a compute limited, which is great. Notice that this also gives you log probabilities. for each of the tokens. And then there's generation, which is one token at a time. It's memory limit. It's slow.

**中文**: 因此，推测解码（或推测采样）本质上让你鱼与熊掌兼得。回顾一下，推理过程分为两个阶段：首先是预填充阶段，即对给定的序列进行处理，所有词元可并行编码，这一阶段受计算能力限制，效率很高；值得注意的是，该阶段还能为每个词元输出对数概率。其次是生成阶段，每次仅生成一个词元，这一阶段受内存限制，速度较慢。

## 段落 76

**英文**: So in other words, checking is faster than generation. So in two of these, this makes sense, but hopefully now you also appreciate the math behind why this is true. And the speculative sampling idea is actually really, really again. It was proposed in parallel by these two independent teams from Google. And the idea is to use a cheap draft model P to just run ahead and generate some tokens. And then you're going to evaluate those tokens with a target model. And because evaluation of given tokens is just pre-fill, so you can do that in parallel, which is fast. And then you accept it if it looks good. So this is what it looks like in real life. So if you're using a big model, generating one token at a time, that's slow, but in speculative decoding, you have a draft model that's racing ahead, generating a lot of tokens, and using the big model to essentially verify.

**中文**: 换句话说，验证比生成更快。在上述两种情况中，这一点显而易见；但希望你现在也能理解其背后所蕴含的数学原理。而“推测性采样”这一思路实际上非常精妙，它由谷歌的两个独立团队几乎同时提出。其核心思想是：利用一个低成本的草稿模型P先行生成若干个词元，再用目标模型对这些词元进行评估。由于对给定词元的评估本质上只是预填充（prefill）过程，因此可并行执行，速度很快；若评估结果良好，则予以接受。这便是该方法在实际中的运作方式：若仅使用大模型逐个生成词元，速度较慢；而在推测性解码中，一个草稿模型会快速超前生成大量词元，再由大模型对其进行实质性的验证。

## 段落 77

**英文**: And sometimes it will reject, and sometimes it will accept. And the acceptance rate basically determines how fast of a speed up you have. OK, so here is the more formal algorithm. So you're going to have a look ahead of k. So you're going to use your draft model and generate k tokens all regressively. So this is hopefully fast because your draft model is small. And then you've given these k tokens that you generated. And I'm going to score them based on, I'm going to compute the probability under the target model Q. Now I'm going to decide whether I want to accept this or not. So I go through each token, and I'm going to essentially accept it with probability Q over P.

**中文**: 有时它会拒绝，有时则会接受。而接受率基本上决定了你所能获得的加速程度。好的，下面介绍更正式的算法：你将进行长度为 k 的前向预测。即利用你的草稿模型递归地生成 k 个词元——这一步有望较快完成，因为草稿模型规模较小。接着，你将对所生成的这 k 个词元，依据目标模型 Q 计算其概率得分。然后，你将据此决定是否接受这些词元。具体而言，你将逐个检查每个词元，并以概率 Q/P 决定是否接受该词元。

## 段落 78

**英文**: And the one just is make sure that this probability is out between zero and one. If this kind of looks like, if people are familiar with Matropolis Hastings, this is kind of where this kind of comes from. So intuitively, you're sampling with P, so you need to divide that out because you don't want P, you are Q. So this is kind of an important weight on this. So if you accept it, then great, you kind of move on, and you look at the next draft token and so on. And if you don't accept it, then you're going to sample from the target model, the slow model, but you kind of do this correction where you've already tried to sample using P. So you don't need to do that anymore. You subtract it out and you sample from Q. So this is basically kind of a rejection sampling with a proposal P and a target Q. The only difference is that you are sampling your injection.

**中文**: 而其中一点是确保该概率值介于0和1之间。如果熟悉Metropolis-Hastings算法，就会发现这种思路正是源于此。直观而言，你正使用分布P进行采样，因此需要将其除掉，因为你并不想要P，而是目标分布Q。因此，这一权重在此处至关重要。若接受该采样结果，则继续推进，考察下一个待生成的词元，依此类推；若拒绝，则需从目标模型（即较慢的模型）中重新采样，但此时需进行修正：由于此前已尝试过用P采样，故无需重复该步骤，应将其剔除，直接从Q中采样。本质上，这是一种以P为建议分布、以Q为目标分布的拒绝采样方法，唯一不同之处在于你所采样的对象是注入的词元。

## 段落 79

**英文**: sampling if you reject it and you reject it, and you just try again and try again. And here, we don't want to keep on kind of looping forever because if you reject, we're just going to say, OK, fine, we'll bite the bullet and just sample from the next more expensive model. So the cool thing here is that you're guaranteed to get an exact sample from the target model. So those of you familiar with sampling, this is what shouldn't be too surprising. You're able to use kind of prior information to speed up sampling. But in the language modeling context, this is kind of nice. I'm going to skip the, this is not really a proof. This is just kind of some derivation to show that for a case of vocab 2,. it's why these formulas kind of give you the right unbiased sampling procedure. And it works pretty well.

**中文**: 采样时，如果你拒绝该样本，就再次拒绝，并不断重试。而在此处，我们不希望无限循环下去，因为一旦拒绝，我们就直接接受现实，转而从下一个更昂贵的模型中进行采样。此处的巧妙之处在于，你一定能获得目标模型的精确样本。熟悉采样的各位应该不会对此感到意外：你可以利用先验信息来加速采样过程。但在语言建模的背景下，这一点尤为有益。我将跳过这部分内容——这并非严格证明，而仅是一些推导，旨在说明在词表大小为2的特例下，这些公式为何能给出无偏的采样过程。该方法效果相当不错。

## 段落 80

**英文**: So the accuracy should be actually the same, since it's the same model. But maybe there's some randomists there. But the speed up is you're getting a factor of 2, speed up, essentially. So in practice, what you do is you have something like a 70B model. In draft model is much, much smaller. And if your target model is 80B, 8B, then your draft model might be 1B. And you generally want to make the draft model as close as you target as possible. And so if you're doing some distillation,. that could make it even better. There's a bunch of, this is a pretty hot area of research in inference.

**中文**: 因此，准确率实际上应该完全相同，因为使用的是同一个模型。但其中可能存在一些随机性因素。而加速效果则约为2倍。在实际应用中，例如你有一个70B参数的模型，其草稿模型则要小得多；若目标模型为80B或8B，那么草稿模型可能仅为1B。通常，你希望使草稿模型尽可能接近目标模型。因此，若采用知识蒸馏等方法，效果还可进一步提升。该领域目前是推理研究中的一个热点方向。

## 段落 81

**英文**: There's a lot of ways to improve this process. You can use Medusa, which is this way to have the draft model instead of generally order aggressively, sample multiple tokens in parallel, or EGLE, where you're actually taking. high-level features of the target model and pumping them into the draft model to generate. So the draft model doesn't actually have to stand alone. It can be kind of glombo onto the target model to help it generate. So summary, exact sampling from the target model, thanks to math, and this exploits the symmetry between checking. and generation, right? So, or pre-fill in generation. And there's actually a lot of room for innovation on the draft model, which can, you know, everything that we've talked about before, where you can have different radical architectures, different ways of quantizing, all those apply. The only thing is that you get to basically guarantee. that you're getting exact sample.

**中文**: 改进这一流程的方法有很多。例如，可以采用Medusa方法，即使用一个“草稿模型”来替代传统的激进式逐序采样，从而实现多个词元的并行采样；又如EGLE方法，该方法实际提取目标模型的高层特征，并将其注入草稿模型以辅助生成。因此，草稿模型本身无需独立运作，而是可与目标模型协同配合，为其生成过程提供支持。简言之，借助数学原理，我们能够从目标模型中实现精确采样，而这恰恰利用了验证与生成之间的对称性——或者说，预填充与生成之间的对称性。此外，在草稿模型的设计上其实存在大量创新空间：此前我们讨论过的各种激进架构、不同量化方式等，均可在此应用。唯一的关键在于，你基本可以确保最终获得的是精确采样结果。

## 段落 82

**英文**: OK, so now I'll go out of time, but quickly go through the question that came up earlier, which is that in practice, when you're serving, there's life traffic. Requests come at different times. They finish at different times. They have some of them have shared prefixes,. some of them don't. They have different lanes. So it's very heterogeneous in comparison to training where you get basically a dense block of tokens, and you're basically going to push it through your GPU at full speed. So what do you do in this case? So there's a series of papers that kind of explore this. And the basic idea is, so the last two parties are more of a kind of systems level contribution. So the idea is that you don't wait for batches to, the train leaves.

**中文**: 好的，那么现在我将超时，但会快速回顾之前提出的问题：在实际服务过程中，存在实时流量——请求在不同时间到达，完成时间也各不相同；其中部分请求具有共享前缀，部分则没有；它们还分布在不同的处理通道中。因此，与训练阶段相比，推理服务场景高度异构：训练时，你基本获得的是密集的令牌块，并能以全速将其推入GPU进行处理。那么在此类情况下，我们该如何应对？目前已有一系列论文对此展开探索，其核心思想是：后两项工作更偏向系统层面的贡献，即不等待批处理积攒完成，而是让“列车”（即请求处理流程）随时发车。

## 段落 83

**英文**: The train doesn't wait for you. So when a new batch comes, you're just going to put it in, which means that the worker that's generating tokens needs to hand control back to the scheduler every step. So you generate token, come back to the scheduler, and say, if there's new requests, then they get stuck in, and then it kind of continues. So you're not wasting any time waiting around for requests. Now there's a problem with batching, I think, which is behind the question. Batching works when everything's at same dimensionality, but every quest might be a different length. So there's this idea of selective batching where you basically break up your computation for attention. Everything has to be handled separately, but for your MFPs remember, which are the bulk of the computation, you can actually take tensors of different sizes and you just flatten them. And because they don't interact, they. can just be kind of along for the right in the batch dimension.

**中文**: 列车不会为你等待。因此，当一批新请求到来时，你只需将其直接加入处理队列，这意味着负责生成词元（token）的工作线程必须在每一步都把控制权交还给调度器。具体而言：先生成一个词元，再返回调度器；若此时有新的请求到达，便立即插入队列，然后流程继续推进。这样便不会因等待请求而浪费任何时间。  
不过，我认为这里存在一个与批处理相关的问题，而这正是提问背后的症结所在。批处理仅在所有输入具有相同维度时才有效，但每个请求的长度可能各不相同。因此，业界提出了“选择性批处理”（selective batching）这一思路：其核心在于将注意力（attention）计算拆分为独立处理的部分；而对模型中占计算主体的多层前馈网络（MLP），由于各输入之间互不干扰，实际上可接受不同尺寸的张量，并直接将其展平（flatten）后沿批处理维度（batch dimension）拼接即可。

## 段落 84

**英文**: OK, I know that was fast, but I'll just quickly go over page attention now. This is the paper behind VLM, which some of you probably have used. And this addresses the memory usage problem. So if you have a KV cache and prompts are coming in and finishing, then your cache is going to get fragmented. So you're going to allocate a bunch of space for a request,. but you don't know how many tokens are going to generate. So there's going to be internal fragmentation, and then there's also an external fragmentation where there's padding between the requests and responses. So that's no good. So the page attention basically says, remember operating systems. And how virtual memory works.

**中文**: 好的，我知道刚才讲得很快，但接下来我将快速讲解一下“分页注意力”（page attention）。这是支撑视觉语言模型（VLM）的论文，其中一些人可能已经用过。该方法旨在解决内存使用问题。例如，当你拥有一个键值（KV）缓存，且输入提示不断到达并完成时，缓存就会变得碎片化。因此，你需为每个请求预先分配大量空间，却无法预知其将生成多少个词元（token），从而导致内部碎片化；此外，请求与响应之间还需填充（padding），进而引发外部碎片化。这显然不可取。“分页注意力”的核心思想，是借鉴操作系统中虚拟内存的工作原理。

## 段落 85

**英文**: We divide the KV cache into a sequence of contiguous blocks, and then we just put them wherever we find Y space. So if you have two requests coming in, then they might just, you know, the first request might be here, here, and here, and the second request might be here and here. So the blocks are the things that you're going to keep contiguous, and that's. going to give you your allowing times to call a lecture memory. So you can also play these tricks where if you have sharing of prefixes, then there's another idea from operating systems, which is copy on right. So you basically maintain reference counters for how many basically sequences are using this particular block. And then if you need to kind of diverge and have blocks go in different directions, then you copy and you reduce the reference count. There's a bunch of other VM optimizations, which I won't go through. But basically, the summary is remembering your operating systems classes, you can apply them to inference as well. OK, so quick summary.

**中文**: 我们将KV缓存划分为一系列连续的块，然后将这些块放置在任意能找到空闲空间（Y空间）的位置。例如，当有两个请求同时到达时，第一个请求的块可能分布在此处、此处和此处，而第二个请求的块则可能位于此处和此处。这些块本身需保持内部连续性，从而支持高效地调用显存。此外，若多个序列共享相同前缀，还可借鉴操作系统中的“写时复制”（copy-on-write）思想：为每个块维护一个引用计数器，记录当前有多少个序列正在使用该块；当需要分叉、使块沿不同路径演化时，则执行复制操作并相应减少原块的引用计数。还有其他诸多虚拟内存优化技术，此处不再赘述。总而言之，回顾一下操作系统课程所学知识，同样可应用于推理加速场景。好的，简要总结如上。

## 段落 86

**英文**: Inference is really, really important. It's where the characteristics are distinct from training. You're memory limited, and it's also a dynamic, so which leads a bunch of new challenges. We saw a whole host of different techniques around new architectures, quantization, pruning, distillation, speculative decoding. There's ideas from systems, which. can allow you to a better user memory, overlap, communication, and compute, and things like that. But I would say that there's probably even more opportunity in sort of modeling and architecture, because if you think about it, all you don't inference, not generally, is inference in a particular model. How do I run this particular model? But who cares about that particular model?. You care about developing good accuracy given your resource budget. So a lot of these ideas that are trying to change the reduced to KV cache, changing the transformer are basically ways to sidestep the problem and say, well, I have something that's more efficient.

**中文**: 推理实际上极其重要，其特点与训练阶段截然不同：你面临内存受限的约束，且推理过程具有动态性，这带来了一系列全新的挑战。我们已看到大量围绕新型架构、量化、剪枝、知识蒸馏、推测解码等技术的创新。系统层面也涌现出诸多思路，例如优化用户内存使用、实现计算与通信的重叠等。但我想强调的是，在建模与架构层面可能蕴藏着更大的机遇。因为归根结底，我们真正关心的并非如何运行某个特定模型，而是如何在给定资源预算下实现优异的精度。因此，许多旨在缩减KV缓存、改造Transformer结构等思路，本质上都是绕开问题本身，转而寻求一种更高效的替代方案。

## 段落 87

**英文**: And then I can train it a way that gets me better accuracy than I went. So that's all I have, and I will see you next time. Then we're back to scaling loss.

**中文**: 然后，我可以以一种让我获得比之前更高准确率的方式来训练它。以上就是我今天要讲的全部内容，我们下次再见。接着，我们将回到损失缩放（scaling loss）的问题上。

---

*共 87 个段落，863 句话*
