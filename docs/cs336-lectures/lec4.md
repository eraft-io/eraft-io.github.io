# Lecture 4： Mixture of experts

生成时间: 2026-03-08 16:47:29

---

## 段落 1

**英文**: So we'll get started. Today we're going to cover a mixture of experts. Last year this was kind of a fun bonus lecture that I threw together, but this year, thanks to lots of people doing MOEs, this has become a much more critical lecture. So I've added a lot of the recent developments, and at the end we'll try to walk through Deep Seek V3 and try to understand what are all the components that make up a state-of-the-art open source system, or at least on the architecture side, what that looks like. So mixture of experts is how a lot of the most modern high-performance systems today. are built and deployed. So there was the funny NVIDIA leak of GPT-4 actually being potentially revealed as GPT-MOE1BT. But more broadly, others like Grok and Deep Seek and Lama4 now have all adopted a mixture of experts architecture. And it seems like at this point in 2025 that the advantage of mixtures of experts over dense architectures is very much clear. Almost all compute scales training a mixture of experts model, if you do it well, is going to give you benefits over a dense model.

**中文**: 那么，我们这就开始。今天我们将讲解“专家混合”（Mixture of Experts, MoE）模型。去年，这堂课还只是一场轻松有趣的附加讲座，是我临时准备的；但今年，由于大量研究者和机构都在开发MoE模型，它已变得至关重要。因此，我加入了大量最新进展，并在课程最后将带大家逐步剖析DeepSeek V3，以理解构成当前最先进开源系统（至少在架构层面）的各个组成部分。目前，许多最先进的高性能系统正是基于专家混合架构构建和部署的。例如，英伟达曾意外泄露消息称GPT-4实际上可能代号为“GPT-MOE1BT”。更广泛地看，Grok、DeepSeek和Llama 4等模型如今均已采用专家混合架构。截至2025年，专家混合架构相较传统稠密架构的优势已十分明确：只要设计得当，几乎所有计算规模下的MoE模型训练，均能带来优于稠密模型的性能收益。

## 段落 2

**英文**: And so everyone seems to be doing it in both the East and the West. And so this will be an important thing to understand if you're trying to build sort of the best model that you can for the flops that you have. So mixture of experts is very simple. It's a very terribly named concept. I think you hear a mixture of experts and you think, oh, there must be experts specialized for different domains, and they're doing different things. Like there's a coding expert and like an English expert and other languages expert. It is very far from that mental model. A mixture of experts is a type of fancy architecture that has several subcomponents called experts that are activated sparsely. And in particular, when you think about mixture of experts, you should be thinking about the MLPs. This is where all the action is.

**中文**: 因此，东西方似乎都在采用这一方法。因此，若你想基于自身算力（FLOPs）构建最优模型，理解这一点就显得尤为重要。专家混合（Mixture of Experts，MoE）其实非常简单，但其名称却极不恰当。一听到“专家混合”，你可能会以为存在针对不同领域的专业化专家，各自执行不同任务，例如有编程专家、英语专家及其他语言专家等。但实际情况与这种思维模型相去甚远。“专家混合”是一种高级架构，包含若干被称为“专家”的子模块，这些子模块以稀疏方式被激活。尤其在思考专家混合时，你应聚焦于多层感知机（MLP），因为所有关键操作都发生于此。

## 段落 3

**英文**: So MOE architecture and a non-MOE architecture are going to be similar in almost all of its components except for one. And that is, if you look at this slide over here, this is the components of a standard transformer. You've got your self-attention, you've got your FFN. If you zoom in, in a dense model, the feed forward component just sort of is there. It's one big block. In a sparse model, what you would do is that you would take this FFN and you would split it up or you would copy it depending on how you're going to be setting up your MOE. You're going to have multiple copies, let's say, of your FFN, your fully connected networks,. and you're going to have a router that picks some smaller number of those in each forward pass or at each inference. So this is the basic idea behind the MOE. And we're going to replace this one big feed forward on the left side with a selector layer and many smaller ones.

**中文**: 因此，混合专家（MOE）架构与非MOE架构在几乎所有组件上都基本相同，仅有一个例外。如本页幻灯片所示，这是一个标准Transformer的组成部分：包含自注意力模块和前馈网络（FFN）模块。若进一步放大观察，在稠密模型中，前馈网络只是一个整体的单一模块；而在稀疏模型中，您会将该FFN进行拆分或复制——具体方式取决于MOE的构建方式。例如，您会拥有多个FFN（即多个全连接网络）副本，并配备一个路由器，在每次前向传播或推理过程中，从这些副本中选择其中数量较少的一部分来使用。这便是MOE的基本思想。我们将用一个选择层及多个更小的前馈网络，来替代左侧这个单一的大型前馈网络。

## 段落 4

**英文**: And what's the advantage of this thing? Well, if it's sparsely activated, that is, let's say it only picks one expert and an expert is the same size as your dense FFN, then the flops between the left side and the. right side, the dense model and the MOE model, they have the same flops. They're doing the same matrix multiplies as you do your forward pass. So you have more parameters without affecting your flops. And if you're a believer that what matters is having more parameters to, for example, memorize facts about the world, well, this is a great architecture. So you can kind of see the intuition behind MOEs. That's all very clear. And you might wonder, OK, so it makes sense that you can get more parameters per flops. But does that translate to actually better performance for the models that you're training? And there's been, I think, at this point, many, many, many papers showing that at the same flop count, at the same training amount of flops, you get better performance out of a mixture of experts than out of a dense model. So this is a nice paper.

**中文**: 那么，这种结构的优势是什么呢？嗯，如果它属于稀疏激活，也就是说，假设它仅选择一个专家（expert），而每个专家的规模与你的稠密前馈网络（FFN）相同，那么左侧（稠密模型）与右侧（MoE模型）在计算量（FLOPs）上是完全相同的——前向传播过程中执行的矩阵乘法运算量也完全一致。因此，你可以在不增加计算量的前提下拥有更多参数。如果你相信，模型性能的关键在于拥有更多参数（例如，用于记忆关于世界的各种事实），那么这无疑是一种极为出色的架构。由此，你便能直观地理解MoE的设计思路，这一点非常清晰。你或许会想：“好吧，这确实说明了单位计算量下可容纳的参数量更高。但这种优势是否真的能转化为所训练模型的实际性能提升呢？”截至目前，我认为已有大量、大量、大量的论文证实：在相同计算量（即相同训练FLOPs）的前提下，混合专家模型（MoE）的表现优于稠密模型。这是一篇非常优秀的论文。

## 段落 5

**英文**: So today I'm going to go over a couple of the classic Google papers that put this field together. And this is one of them by Fedes et al. 2022, where they show that if you flop smash your training flops, so that's the same amount of compute used for training. And as you increase the number of experts, the training loss of your language model just keeps going down and down and down and down and down. So more experts, better. Of course, the experts aren't free. You need to store the memory for these experts. And when you do parallelism, you're going to have to think about routing your data into. 256 separate experts. So there's going to be systems complexities.

**中文**: 因此，今天我将介绍几篇奠定该领域基础的经典谷歌论文，其中一篇是Fedes等人于2022年发表的论文。该论文表明：若保持训练所用计算量（即FLOPs）不变，仅增加专家数量，则语言模型的训练损失会持续不断地下降。换言之，专家数量越多，效果越好。当然，专家并非免费——你需要为这些专家存储相应的内存；而在进行并行计算时，你还需考虑如何将数据路由至256个独立的专家，这将带来系统层面的复杂性。

## 段落 6

**英文**: But if you're only thinking about flops, this is a great chart to see because you have the same flops, but you've gotten free test loss here. And you see the same thing reflected on the right side. As you train for longer and longer, the model, the switch base with 128 experts, the model with more experts, gets better perplexity faster. So hopefully that is quite clear. You might say, well, this is a 2022 paper. Is this true sort of on modern architectures, on modern scales? It continues to very much be true. AI2 had a very nice paper, Olmo, which did a whole bunch of ablations and carefully controlled comparisons into dense versus MOE and other architectures. And they sort of see exactly the same thing. So here on the left side, this is still from FETUS at all. You see the 7x speed up from having many experts.

**中文**: 但如果你只关注计算量（FLOPs），这张图表非常有价值，因为你在获得相同FLOPs的同时，此处实现了免费的测试损失降低。右侧也反映出同样的趋势：随着训练时间不断延长，拥有128个专家的Switch Base模型（即专家数量更多的模型）能更快地实现更低的困惑度。希望这一点已十分清晰。你或许会问：“这是一篇2022年的论文，那么在现代架构和更大规模上，这一结论是否依然成立？”答案是肯定的，该结论至今依然高度适用。AI2团队发表了一篇非常出色的论文《Olmo》，其中进行了大量消融实验，并严格控制变量，对稠密模型与混合专家（MoE）等不同架构进行了细致对比，结果同样印证了上述现象。左图仍源自FETUS研究，从中可见，采用多个专家可带来7倍的加速效果。

## 段落 7

**英文**: On the right side, this is the Olmo comparison. You see the pink one is the MOE and the teal one is dense. And the training loss for the dense model goes down much more slowly than the MOE. So hopefully I have in some sense sold you on the value of MOEs and for learning this kind of new, slightly new architecture. So we're going to pay a price for all of this. But at least at the flops level, this looks very compelling. Yes, question. In the last lecture, you mentioned, for instance, it was the highest turning point because although it's a pretty cheap flops computation, the effects are actually quite positive pretty badly. We're loading in and out. C series is there.

**中文**: 右侧是Olmo模型的对比图。粉色曲线代表MoE模型，青绿色曲线代表稠密模型。稠密模型的训练损失下降速度明显慢于MoE模型。因此，我或许已在某种程度上向您阐明了MoE的价值，以及学习这类新颖（略带新意）架构的意义。当然，这一切都需要付出一定代价；但至少从计算量（FLOPs）层面来看，这一方案极具吸引力。  
好的，请提问。  
在上一讲中，您曾提到，例如这是最高转折点，因为尽管其FLOPs计算成本相当低廉，实际效果却非常显著——甚至可以说效果极佳。然而，我们却面临频繁的数据加载与卸载问题。C系列就存在这一情况。

## 段落 8

**英文**: So the question was, in last lecture, I was saying even small non-flops, negligible flops can be really big in wall clock. Is anything in the MOE world going to look like that?. And so I think one of the drawbacks of MOEs, why that's not the standard thing that's being taught, let's say at 224N, is because there's significant systems complexities to making this thing efficient. So I'll get to that. It's possible to make these things very efficient, especially if each expert lives on a separate device so that you're routing data to different places. You can be very efficient when you do that. But it's not easy. So there's a lot of infrastructural concerns, and you're going to see a lot of complexities to get this thing to work. But when it does work, you're putting all of your flops to use. And then the last one that I wanted to show is a lot of the companies really love MOEs because you get to present plots that look very compelling like this.

**中文**: 因此，上一讲中我提出的问题是：即使是微不足道的非浮点运算（non-flops），其实际运行时间（墙钟时间）也可能非常长。那么，在混合专家（MOE）模型的世界中，是否存在类似的情况？我认为MOE的一大缺陷——也是它尚未成为标准教学内容（例如在224N课程中）的原因之一——在于实现其高效运行存在显著的系统复杂性。我稍后会详细说明这一点。实际上，这些模型完全可以实现极高效率，尤其是当每个专家都部署在独立设备上、数据可被路由至不同位置时；此时，系统效率可大幅提升。但实现起来并不容易。因此，存在大量基础设施层面的挑战，要让MOE真正有效运行，你将面临诸多复杂性。然而，一旦成功运行，你就能充分利用全部浮点运算能力。最后我想指出的一点是：许多公司之所以格外青睐MOE，是因为它能生成极具说服力的性能图表，例如这张图所示的效果。

## 段落 9

**英文**: This was from the DeepSeq v2 paper. On the x-axis, this is a little bit of sleight of hand. This is only activated parameters. This is only the parameters that are used for computation. So you ignore all the deactivated experts. And the y-axis is MMLU performance. And we see DeepSeq v2, wow, look, very few activated parameters, really good MMLU performance. And so if you're only interested in both training and inference flops, activated parameters is the name of the game, you get really good performance here. And this is not just an ablation. This is a real system that someone spent a lot of money to train and deployed out in.

**中文**: 该图出自DeepSeq v2论文。横轴存在一点巧妙处理：仅统计被激活的参数，即实际参与计算的参数，所有未被激活的专家模块均被忽略；纵轴为MMLU性能指标。我们看到，DeepSeq v2表现惊人：仅需极少的激活参数，即可实现极高的MMLU性能。因此，若您仅关注训练与推理所需的浮点运算量（FLOPs），那么激活参数数量便是关键指标，此处可获得极佳性能。这并非单纯的消融实验，而是一个真实系统——有人投入大量资金进行训练并已实际部署上线。

## 段落 10

**英文**: the wild. And you'll see this sort of pattern recur in other examples as well. Oh, was there a question? Oh, good. All right. And so the systems thing that is also a benefit is that MOEs allow us to have another axis of parallelism. So I'm going to get into parallelism in much, much more detail sort of in the systems lectures. I'm going to talk about how you're going to take your model and you're going to cut it up into many small pieces and lay them out across many different devices. But I'm going to talk at a very high level. But when you have experts, there's a very natural way to parallelize at the expert level, right? So you have multiple different feedforward blocks. You can take each of these experts and you can put them on a different device, right? And because experts are sparsely activated, all you have to do is take your token and.

**中文**: 野外。你还会在其他示例中看到这种模式反复出现。哦，刚才有人提问吗？哦，很好。好的。此外，从系统角度看，MOE 还带来另一项优势：它使我们能够获得另一个维度的并行性。我将在系统课程中更深入、更详细地探讨并行性问题。我会讲解如何将模型切分为许多小块，并将其分布到多个不同设备上。不过，此处我仅作高层次概述。而当采用专家模型（Experts）时，在专家层面进行并行化便显得极为自然——例如，你拥有多个不同的前馈网络模块，可将每个专家分别部署到不同的设备上；又因专家是稀疏激活的，你只需将输入 token……

## 段落 11

**英文**: route it to the appropriate device and the computation will happen on that device, right? So it's a natural sort of cutting point to be able to shard your model into different devices. So that's called expert parallelism. And this is another reason why MOEs are very popular, right? If you really want to parallelize really big models, this is a thing that you're going to have to do. And kind of interestingly enough, I think MOEs developed at Google and many of the frontier. labs, the closed labs were doing it. But I think the open results actually came from China very frequently. We're doing a lot of MOE work last year. And it's only really recently that I think Western open source groups have started to do more MOE work. So Mixtral, Grok, I guess Grok's not open. And then now Llama is now an MOE architecture, right? And so here, Llama 4 just got released, right?.

**中文**: 将其路由至适当的设备，计算就会在该设备上执行，对吧？因此，这自然成为将模型切分到不同设备的一个理想分割点。这种技术被称为专家并行（expert parallelism）。这也是混合专家（MoE）模型广受欢迎的另一个原因，对吧？如果你确实希望对超大规模模型进行并行化处理，就必然要采用这种方法。有趣的是，我认为MoE最初由谷歌开发，许多前沿实验室（包括多家封闭式实验室）也都在开展相关研究。但据我所知，早期的开源成果却往往来自中国。我们去年开展了大量MoE相关工作，而西方开源社区直到最近才开始更深入地投入MoE研究。例如Mixtral、Grok（不过Grok并非开源），以及如今Llama也已采用MoE架构，对吧？比如，Llama 4刚刚发布，对吧？

## 段落 12

**英文**: Latest and greatest. This is also a sparse MOE. And I'll talk about Llama 4 as well as I go through the lecture. As I said before, one of the starting points for this is some of the Chinese groups, QAN and DeepSeek have actually done some really nice work benchmarking and understanding and evaluating some of these MOEs. So QAN 1. 5 was one of the first models that I knew of to have this large scale, well tested, well documented MOE. And what they did was they took a QAN 1. 5 dense model and they had a nice trick to upcycle it into a mixture of experts. That's a clever kind of trick to take a dense model and then turn it into an MOE. And they showed significant gains, at least in terms of compute efficiency, while decreasing the total number of parameters relative to their 7B model.

**中文**: 最新且最出色的模型。该模型同样采用稀疏混合专家（MOE）架构。在接下来的讲座中，我还将介绍Llama 4。如前所述，本研究的起点之一来自一些中国研究团队，例如Qwen（通义千问）和DeepSeek，他们在MOE模型的基准测试、机理分析与性能评估方面已开展了非常出色的工作。其中，Qwen 1.5是首批实现大规模、经过充分测试且文档完备的MOE模型之一。他们的做法是：以Qwen 1.5稠密模型为基础，巧妙地通过一种“升级循环”技术将其改造为混合专家模型——这是一种将稠密模型高效转化为MOE模型的聪明方法。实验结果表明，该方法在计算效率方面取得了显著提升，同时模型总参数量相较其70亿参数（7B）版本反而有所降低。

## 段落 13

**英文**: DeepSeek, which is now famous, but originally when these papers were coming out were not quite as famous, did some of the, I think, really foundational MOE work in the open source world. A big part of this lecture is actually going to be tracing the trajectory of the DeepSeek MOE architecture. But if you look at their original DeepSeek MOE paper, you'll see very nice papers, sorry, very nice sort of comparison showing things like what happens when you train a dense model with a particular amount of flops? What happens when you train a really naive MOE that doesn't do very smart routing? What happens? And then if you use a smarter routing called the switch sort of MOE, what happens?. And so you'll see all of these very carefully controlled comparisons and you see as you go from dense to sparse, right? So that's the leftmost column to the rightmost column, you see all of these sort of benchmark metrics very consistently improve for a fixed amount of flops. So this is very consistent. And kind of one thing that I think almost everyone at this point has probably heard is DeepSeek V3. And that's in some sense a culmination of all this line of work. But if you had been following MOEs and you were excited about kind of this branch of neural networks and language modeling, you would have actually known about DeepSeek long before V3 got popular. And we'll see at the very end of this lecture, actually DeepSeek V3 is not very different from the very earliest DeepSeek MOEs. Architecturally, they had kind of nailed it way back when they were training these sort of much smaller 2 billion parameter models.

**中文**: 如今声名显赫的DeepSeek，最初在这些论文刚发布时并未如此知名；但其在开源领域所开展的工作，我认为正是真正奠定混合专家（MOE）基础的重要研究。本次讲座的很大一部分内容，实际上将追溯DeepSeek MOE架构的发展脉络。但若你查阅其最初的DeepSeek MOE论文，便会看到一系列非常出色的对比实验——例如：当使用特定计算量（FLOPs）训练一个稠密模型时，性能如何？当训练一个极为朴素、路由机制并不智能的MOE模型时，性能又如何？而若采用一种更智能的路由机制（即所谓“Switch”型MOE），结果又会怎样？因此，你会看到所有这些经过严格控制的对比实验，并清晰地观察到：随着模型从稠密结构逐步过渡至稀疏结构（即从最左侧列向最右侧列演进），在固定计算量（FLOPs）的前提下，各项基准评测指标均呈现出高度一致的持续提升。这种一致性非常显著。此外，目前几乎所有人都已耳熟能详的DeepSeek V3，在某种意义上正是这一系列研究工作的集大成者。但如果你一直关注MOE技术发展，并对这一神经网络与语言建模分支充满兴趣，那么早在V3走红之前，你就很可能已经知晓DeepSeek了。我们将在本次讲座最后看到：DeepSeek V3在架构上与最早期的DeepSeek MOE模型其实并无太大差异——早在他们训练那些参数量仅为20亿的较小规模模型时，其核心架构设计便已基本定型。

## 段落 14

**英文**: They really just kind of got the engineering right to get something that is actually really. quite remarkably good, which is their V3 model. Okay. So now I think I have spent quite a few minutes trying to really hype you up on MOEs. And they really are, I think, worth hyping up. They're very good. But I think there's a question of why haven't they been more popular, right? Why isn't it the standard thing we teach in NLP and language modeling classes? It's just that they're very complex and they're very messy. And I'm hoping that they'll get simplified over the next few years, but they still remain pretty nasty. So one of the things is the infrastructure is very complex. And the biggest advantages of MOEs really happen when you're doing multi-node training.

**中文**: 他们实际上只是在工程上做得非常到位，从而打造出了一款真正极为出色的产品——即他们的V3模型。好了，我想我已经花了相当多时间来极力推介混合专家模型（MOE）。而它们确实值得如此大力推介，表现非常优异。但这里存在一个问题：为何它们尚未更广泛流行？为何它们并未成为自然语言处理（NLP）和语言建模课程中的标准教学内容？原因在于其结构极为复杂且十分凌乱。我希望未来几年内它们能逐步简化，但目前依然相当棘手。其中一大难点在于基础设施异常复杂；而混合专家模型的最大优势，恰恰体现在多节点训练场景中。

## 段落 15

**英文**: Like when you have to split up your models anyway, then it starts to make sense to shard experts across different models. It's a very natural thing to do. But until you get to that point, maybe MOEs are not quite as good, right?. So some of the earlier Google papers really talk about this tradeoff where they say, actually, when you get these really big models that you have to split up, then experts become uniquely good. There's also other things that are really tricky. If you think about it carefully, right, this decision of which expert you route tokens to is a very difficult thing to learn, right? In deep learning, we really like differentiable objectives, right? Very smooth things that we can take gradients of. Routing decisions are not differentiable because we have to pick and commit to a particular expert. So if we're doing that, we're going to have a very tricky optimization problem. And the training objectives to make that work is either heuristic and or unstable, right? And so we're going to have to really carefully engineer those guys to get them to work, right? So those are two reasons why you don't really want to maybe do this normally. So what do MOEs look like? As I started this lecture with, the classic MOEs that you should think of is you take.

**中文**: 例如，当你无论如何都必须将模型拆分时，将专家模型分散到不同模型中就开始变得合理了，这是一件非常自然的事情。但在达到这一阶段之前，混合专家（MoE）模型的效果可能并不那么理想，对吧？因此，谷歌早期的一些论文确实深入探讨了这种权衡关系：实际上，只有当模型规模大到必须进行拆分时，专家模型才真正展现出其独特优势。此外，还有其他一些非常棘手的问题。仔细想一想，将每个词元路由至哪个专家的决策本身就是一个极难学习的问题，对吧？在深度学习中，我们非常青睐可微分的目标函数，也就是那些非常平滑、能够计算梯度的函数。而路由决策却不可微分，因为我们必须选定并确定使用某一个特定的专家。一旦采用这种方式，就会面临一个极其困难的优化问题。而为使该机制有效所设计的训练目标，要么是启发式的，要么是不稳定的，对吧？因此，我们必须极为审慎地设计这些机制，才能使其正常运作，对吧？以上两点正是你通常并不希望轻易采用这种方案的原因。那么，混合专家模型究竟长什么样呢？正如我本节课开头所讲，你应当首先想到的经典混合专家模型是这样的：你取……

## 段落 16

**英文**: the densely connected layers, the FFNs, and you split them up or you copy them, and you have sparse routing decisions among them. Of course, you could do the same kind of idea. You could have a sparsely routed attention layer. And some people have done this. There's been a couple of papers and a couple of releases that have taken this approach. But it is actually quite rare to see this in the major model releases. I think I've seen people talking on the internet saying like this approach is actually really. much even more unstable and very difficult to really train consistently. It's sort of, I haven't really seen the ablation to back that out, but certainly there haven't really been many people training those kinds of models with MOE attentions. So now, you know, I've told you about the basic architecture, right? It's really simple.

**中文**: 密集连接层、前馈网络（FFN），你可以将它们拆分或复制，并在它们之间进行稀疏路由决策。当然，你也可以采用类似思路，设计稀疏路由的注意力层；确实已有人这样尝试，一些论文和模型发布采用了该方法。但主流大模型发布中实际上极少见到这种设计。据我所知，网上有人评论称，这种方法甚至更加不稳定，也极难实现稳定一致的训练。虽然我尚未看到能证实这一点的消融实验，但确实鲜有人用混合专家（MoE）注意力机制来训练这类模型。好了，现在你已经了解了基本架构，对吧？它其实非常简单。

## 段落 17

**英文**: It's just you have a router of some kind and you route and then you have different MLPs. So what are the things that might vary across different MOE choices?. You might ask, how do we route? The routing function is an obviously important choice. How many experts and how big should the experts be? That's another choice. And then the final one is how would we train this router, right? This non-differential objective that seems very difficult to train. So those are very important design questions, and we're going to go through each one, hopefully covering the design space of all these MOE things. Any questions before I get into each one of these different subcomponents here? Good. Okay. So if you're interested in just kind of understanding a broad overview of MOEs, at least circa 2022, there's a really nice sort of survey or a review paper by Fedis et al. in 2022 that covers a lot of these and many of my figures are credited to that paper.

**中文**: 仅需配备某种类型的路由器进行路由，然后连接不同的多层感知机（MLP）。那么，在不同专家混合（MOE）方案的选择中，哪些因素可能发生变化呢？你可能会问：我们如何进行路由？路由函数显然是一个至关重要的选择。专家数量应为多少？每个专家的规模又该多大？这是另一个关键选择。最后一点是：我们该如何训练该路由器？这个非可微分的目标函数似乎极难优化。因此，这些均属极为重要的设计问题，接下来我们将逐一探讨，力求全面覆盖所有MOE相关的设计空间。在进入上述各个子模块之前，大家还有问题吗？很好。好的。如果你仅希望大致了解MOE（至少截至2022年）的整体概况，那么Fedis等人于2022年发表的一篇综述性论文非常值得一读，其中涵盖了大量相关内容；本文中的许多示意图也源自该论文。

## 段落 18

**英文**: If we're thinking about how we're going to route or essentially match tokens to experts, this is the core component of a MOE because what a MOE does is tokens are going to be. coming in, you have your sequence that you're processing, and those sequences are going to be assigned to experts. Not all experts will process every token. That's the whole point of a sparsely routed MOE. And so you can ask, how are these routing decisions made? So you can sort of have three different kinds of choices. You can have token choice, where each token is going to have a sort of routing sort of preference for different experts, and I will choose the top K experts for each token. Or I can have expert choice, where each expert is going to sort of have a rank preference over tokens, and then I'm going to choose the top K tokens for each expert. This has a really nice benefit of being balanced over experts. And then the last one is sort of you could solve some sort of complicated optimization problem to make sure that the mapping between experts and tokens is somehow balanced, right? This is global assignment. And just to give you a bit of a teaser here, almost all the MOEs do token choice top K.

**中文**: 如果我们思考如何对令牌进行路由，或者说本质上是将令牌匹配到专家模型，那么这就是混合专家（MOE）架构的核心组件，因为MOE的本质正是：输入的令牌会进入系统，你拥有待处理的序列，而这些序列中的令牌将被分配给不同的专家。并非所有专家都会处理每一个令牌——这正是稀疏路由MOE的根本意义所在。那么我们自然会问：这些路由决策是如何做出的？大致上，我们可以采用三种不同的策略：其一是“令牌选择”，即每个令牌对不同专家具有某种路由偏好，然后为每个令牌选出得分最高的K个专家；其二是“专家选择”，即每个专家对所有令牌具有某种排序偏好，然后为每个专家选出其最偏好的前K个令牌，这种策略天然具备专家负载均衡的优势；第三种则是通过求解某种复杂的优化问题，以确保专家与令牌之间的映射关系在全局层面达到均衡，即所谓“全局分配”。这里先稍作预告：目前几乎所有MOE模型均采用“令牌选择+Top-K”策略。

## 段落 19

**英文**: In the early days of MOEs, people tried many, many different things, sort of spanning this. whole spectrum of design space of token routers. If you look at the big releases, they have all converged to basically one class of routing mechanisms, which is token choice top K. So each token is going to rank order experts by affinity, and then there's going to be kind of a top K choice for each one of this. And OMO, which I'll keep referring to throughout this lecture because they have a really nice series of ablations, so it's really nice to teach off of, have exactly this ablation. They compare a token choice routing versus an expert choice routing, and they show if. you look at validation loss, token choice is much, much nicer behaved, much faster in loss decay. Yes? Is this a function of the token itself or is it a position? It's a function of sort of the hidden state, right? So the token is going to get processed with all the position embeddings and so on, and then the hidden state will come in and then it will be processed by the MLP. So for the other two, for the experts choosing the token and also the next one, when you. say it's more balanced across the experts, are they.

**中文**: 在混合专家（MOE）模型的早期发展阶段，人们尝试了大量不同的方法，几乎覆盖了令牌路由器设计空间的整个谱系。然而，若观察各大模型的正式发布版本，它们最终都收敛到了同一种路由机制，即“基于令牌选择的Top-K路由”。具体而言，每个令牌都会根据其与各专家的亲和度对专家进行排序，然后为每个令牌选择亲和度最高的K个专家。在本讲座中，我将持续提及OMO模型，因为该模型提供了一系列非常清晰的消融实验，非常适合教学。OMO模型恰好进行了这样一项消融对比：将基于令牌选择的路由与基于专家选择的路由进行比较，并表明——若考察验证损失，基于令牌选择的路由表现明显更优，损失下降速度也快得多。  
问：这种亲和度是令牌自身的函数，还是位置的函数？  
答：它本质上是隐状态的函数。也就是说，令牌会先经过位置编码等处理，生成隐状态，再由多层感知机（MLP）对其进行处理。至于另外两种情形——即“专家选择令牌”以及接下来要讨论的情形——当提到“专家间的负载更均衡”时，它们……

## 段落 20

**英文**: It's still for the current token sequence, but it's forcing them to be more distributed? I guess I'm sure you think so. Well, it's still going to be the same set of tokens, but really it's about kind of the ranking selector function, right? In token choice, I'm just going to take the top K amongst the columns. Maybe the scores are even identical, right? I'm just going to take the top K amongst the columns. In expert choice, I'm going to take top K amongst the rows, right? And top K amongst the columns is kind of nice because you might be able to say, oh, I can define a scoring function such that the score is how well each token gets processed by each expert. And token choice will route me to the best expert for that token, so that makes sense from processing. But expert choice has the benefit that each expert gets exactly the same number of tokens. And so now, if you're putting different experts on different devices, you've got balanced. utilization. So there's different trade-offs that play as you think about routing. Yes? How does a token know which expert is the best for it? Good.

**中文**: 它仍针对当前的词元序列，但强制让它们分布得更均匀？我想您肯定也是这么认为的。嗯，最终选用的词元集合其实是一样的，关键其实在于排序选择函数，对吧？在词元选择（token choice）中，我仅从各列中选取得分最高的K个；甚至这些分数可能完全相同，对吧？我依然只是从各列中选取得分最高的K个。而在专家选择（expert choice）中，我则从各行中选取得分最高的K个，对吧？从各列中选取得分最高的K个有一定优势，因为您可以定义一个打分函数，使其分数表示每个专家处理各词元的效果好坏；这样，词元选择机制就能将每个词元路由至最适合处理它的专家，从处理角度看这是合理的。但专家选择的优势在于：每个专家恰好分配到相同数量的词元。因此，当您将不同专家部署在不同设备上时，设备的利用率就实现了均衡。由此可见，在设计路由机制时，需要权衡不同的取舍。是的？那么，一个词元如何知道哪个专家最适合处理它呢？很好。

## 段落 21

**英文**: Yeah, so the question was how does each token know which expert is good? That is exactly the role of the router, and I'll give you the router equation, but to give you a bit of a. Not really a spoiler, but the routers are much more lightweight than you think. So your token, let's say, is represented by vector X. That's your hidden residual stream coming in. So now X is going to get multiplied by W, a matrix, and then you'll just take a sigmoid or something, and that's the score. So it's really just a vector, vector inner product, almost like an attention operation in a way. Yes?. Is top one here, or is each token described by an expert? Right, so the choice of. So the question was, is K1 here? So K is actually a hyperparameter, and different MOEs will choose different things. I will talk about this again, but to give you the high-level intuition, the initial argument that the earliest MOE papers made was that K should be greater than 2, because that way you get some exploration.

**中文**: 是的，因此问题在于：每个token如何知道哪个专家更优？这正是路由器（router）的作用所在。我将给出路由器的计算公式，但先稍微透露一点——严格来说算不上剧透——实际上路由器比你想象的要轻量得多。假设你的token由向量X表示，即输入的隐藏残差流。此时，X将与一个矩阵W相乘，再经过sigmoid等激活函数，便得到该token对各专家的评分。因此，整个过程本质上只是向量与向量的内积运算，在某种程度上类似于注意力机制中的操作。  
是的？  
这里采用的是top-1策略，还是每个token都由某个专家负责？  
没错，选择方式取决于……  
刚才的问题是：此处K是否为1？实际上，K是一个超参数，不同混合专家（MoE）模型会选取不同的K值。我稍后还会进一步讲解，但先从高层直觉上说明：最早一批MoE论文提出K应大于2，其初衷在于借此实现一定程度的探索性学习。

## 段落 22

**英文**: If you're doing K equals 1, maybe you're just always exploiting the best arm, and you'll. never know about the potential other things you could do. But if K is 2, then maybe that second arm can tell you a little bit of exploration information. So K equals 2 was the canonical choice, and K equals 2 actually continues to be very popular. So that would be like double the flops. That's right, that's right. So that would double the flops. And so when people talk about MOEs, they usually say things like X number of activated parameters, and that would account for the fact that you're putting in two MLPs. Yes? So when K is greater than 4, even high inference time, do you mean by the outputs of the different experts into. Yes, the question was when K is 1, do the outputs get combined? That's right.

**中文**: 如果你设置 K 等于 1，那么你可能始终只利用最优的那条臂（即仅选择已知最优动作），从而永远无法了解其他潜在可选动作的信息。但若 K 等于 2，则第二条臂或许能为你提供一些探索性信息。因此，K=2 成为经典设定，且至今仍广受欢迎。这相当于将浮点运算量（FLOPs）翻倍——没错，正是如此，FLOPs 将翻倍。因此，当人们讨论混合专家模型（MoE）时，通常会提及“X 个激活参数”，这正反映了你同时启用了两个多层感知机（MLP）。是的？那么当 K 大于 4 时，即使在高推理延迟下，您所指的是否为各专家输出的融合？是的，问题在于：当 K=1 时，各专家的输出是否仍需进行融合？没错。

## 段落 23

**英文**: If you look at the attention diagram over there, you got the router, it's routed to two MLPs up top, and then they get combined together right after. So that's exactly right. So in that case, you think you're saying that's simple average, but you're waiting average. So the question was how does the aggregation happen? It's just the sum. Right. So I'm going to go over the variance, very common variance that people do. And really, in some ways, all you need to know is top K in order to actually implement a high performance MOE, but I'll give you the other variants because they're natural things you might think of. Top K routing is what is used in most MOEs, token choice top routing, top K routing. So how that works is you have your residual stream inputs X that will go into a router. And as I said, a router is really kind of like the attention operation.

**中文**: 如果你观察那边的注意力图，可以看到有路由器，它将输入路由至顶部的两个MLP，然后这两个MLP的输出紧接着被合并在一起。因此，你的理解完全正确。此时你可能认为这是简单的平均操作，但实际上是一种加权平均。那么问题来了：这种聚合是如何进行的？答案就是直接求和。接下来，我将介绍几种常见的变体。实际上，从某种意义上说，要实现高性能的混合专家模型（MoE），你只需掌握“Top-K”机制即可；不过，我仍会介绍其他几种变体，因为它们是你很自然就会想到的方案。“Top-K”路由是目前大多数MoE模型所采用的路由方式，也称为“基于Token选择的Top路由”或“Top-K路由”。其工作原理如下：你拥有残差流输入X，该输入将送入路由器；如前所述，这个路由器在功能上其实类似于注意力机制。

## 段落 24

**英文**: There's a linear inner product and then a softmax. And then you pick the top K most highly activated experts, and then those outputs are gated. Depending on the implementation, you might weight the outputs based on this router weight, or you might not. And then you will just output the weighted average or just a straight sum, depending. on how your MOE implementation works. And so a lot of the MOE papers and methods use top K, switch transformer, G-shard, Grok, mixed-row, KWN. All the DeepSeq variants use different top K variants. Maybe a very surprising fact, and this should really make you think about what's going on with MOEs. There are a lot of results that show that actually you don't even need a smart router at all. You can actually just use a hashing function at the very bottom to map these Xs onto your experts.

**中文**: 存在一个线性内积，随后接一个Softmax函数。接着，选取激活程度最高的K个专家，然后对这些专家的输出进行门控处理。具体实现中，你可能会根据路由器权重对输出进行加权，也可能不加权。最终输出可能是加权平均值，也可能是直接求和，这取决于你的混合专家（MoE）实现方式。因此，大量MoE相关论文与方法均采用Top-K策略，例如Switch Transformer、G-Shard、Grok、Mixed-Row以及KWN等。所有DeepSeq变体也都采用了不同的Top-K变体。或许一个令人惊讶的事实是——这确实值得你深入思考MoE的内在机制：许多研究结果表明，实际上根本不需要设计精巧的路由器；你甚至可以直接在最底层使用哈希函数，将输入X映射到各个专家上。

## 段落 25

**英文**: And even if you're doing hashing, so no semantic information at all, you will still get gains from a hashing-based MOE, which is pretty wild. Some of the earliest work on MOEs, I think, had the very smart idea, and in many ways the right idea if you're thinking about this top-down, of using RL to learn the routing behavior. Of course, the choice of where to route to is a discrete decision, and RL is great for. learning discrete decisions. Why don't you use RL to learn routing? It was used in some of the earliest work on mixture of experts. As far as I know, basically no one does this now. The compute cost to do this is too prohibitive, and you already have stability issues. You might not want to do that. There have been a couple of papers that have explored things like solving linear assignment problems or optimal transport style problems. They're very elegant, but once again, the cost of doing this is much higher than the benefits that it gives you, I think, in practice, and it hasn't really been adopted.

**中文**: 即使你采用的是哈希（hashing）方式——即完全不利用任何语义信息——基于哈希的混合专家（MOE）模型仍能带来性能提升，这相当令人惊讶。我认为，早期关于MOE的一些研究工作提出了一个非常聪明、且从自上而下的视角来看在很多方面都是正确的想法：即利用强化学习（RL）来学习路由策略。当然，选择将输入路由至哪个专家本质上是一个离散决策问题，而强化学习恰恰擅长学习此类离散决策。那么，为何不直接用强化学习来学习路由呢？事实上，它确实在早期部分MOE研究中被采用过。但据我所知，目前基本已无人沿用这一方法：其计算开销过于高昂，且还会引发模型训练稳定性问题，因此可能并不值得采用。此外，也有几篇论文尝试采用求解线性指派问题或最优传输类问题等方法，这些方法虽极为优雅，但就实际效果而言，其计算成本远超所能带来的收益，因而并未得到真正推广。

## 段落 26

**英文**: But there's a lot of really interesting things that people are doing like this to try to improve the routing. So now I can point at this slide and really talk through how routing works in detail. So this is the kind of top-K routing that almost everyone has converged to now. This is the router that's used in DeepSeq V1 to 2. Quinn and Grok do almost exactly this. Instead of having a softmax directly at the bottom here, they do a DeepSeq V3 mixed role DBRX. They don't have a softmax at the bottom, but they'll softmax the G of ITs, but it's a very minor difference. So let's walk through what's going on here and try to reason about the behavior of this. So what's happening here is at the very bottom, we've got our inputs. This is our U of L input.

**中文**: 但人们正在开展许多真正有趣的工作，以类似方式尝试改进路由机制。因此，我现在可以指着这张幻灯片，详细讲解路由的工作原理。目前，几乎所有模型都已收敛到这种“Top-K路由”模式。DeepSeek V1至V2采用的就是此类路由器；Quinn和Grok也几乎完全采用这一方案。不过，DeepSeek V3（即混合专家模型DBRX）并未在此处直接使用softmax，而是对门控权重G进行softmax处理——但这仅是细微差别。接下来，我们逐步分析此处的运作过程，并探讨其行为特征。最底层输入即为我们的原始输入，也就是U_L输入。

## 段落 27

**英文**: And I would like to take this sort of residual stream input and process it through my MOE. So the first thing I'm going to do is I have to figure out which experts are going to be activated. Now, how am I going to do that? Well, how I'm going to do that is very similar to attention. I'm going to take my U, which is my residual stream input, and I'm going to take the inner products with the E of I's. These are kind of learned vectors that are for each expert that tells the expert, I'm an expert that points in this direction. And so I'm computing in this inner product here, expert and input affinity, and I'm computing a softmax to determine for each token what are the best experts. So I normalize. This is S of I of T. Now I take the S of I of T and I go through a top K function. I only select the K best weights and then I use this as my gate.

**中文**: 我想将这种残差流输入送入我的混合专家（MOE）模型进行处理。首先，我需要确定哪些专家将被激活。那么，我该如何实现这一点呢？其方法与注意力机制非常相似：我将取残差流输入U，并分别计算其与各专家对应向量Eᵢ的内积。这些Eᵢ是为每个专家学习得到的向量，用以表征“该专家擅长处理朝此方向的输入”。因此，此处的内积即用于衡量各专家与输入之间的匹配程度（专家-输入亲和度），再通过softmax函数为每个token计算出最适配的专家权重。随后我对结果进行归一化处理，得到Sᵢ(t)。接着，我对Sᵢ(t)应用Top-K操作，仅选取权重最高的K个专家，再将这些权重作为门控（gate）使用。

## 段落 28

**英文**: So I zero out everything else and I take the weighted average of each of the experts' outputs and then I add that to my original residual stream and then I return that. So this is hopefully very familiar to kind of what you're all very familiar with in terms of how a transformer works with only the difference of this top K routing piece. Is that clear to everyone how this thing works? Good. Excellent. So in some sense the mechanics of the forward process of the routing is very simple. What is kind of mystifying is the fact that you can learn this very well. This is in some sense a fairly complicated set of things to have to learn to do well. by a model. Yes? So we're using softmax here. Previously one of the benefits of softmax is that it's going to push you pretty extremely to choosing a singular max.

**中文**: 因此，我将其他所有内容置零，然后对各位专家的输出取加权平均值，再将该结果加到原始残差流中，最后返回该结果。这与大家所熟知的Transformer工作方式非常相似，唯一的区别在于此处引入了Top-K路由机制。大家是否都清楚这一机制的工作原理？很好，非常棒！从某种意义上说，路由前向过程的机制非常简单。真正令人费解的是，模型竟能如此出色地学习这一机制——从某种角度看，这对模型而言是一项相当复杂的任务。是的？我们这里使用的是Softmax函数。此前，Softmax的一个优势在于它会促使模型极为强烈地倾向于选择单一的最大值。

## 段落 29

**英文**: It's not a hard max but a implicit tool. I'm having trouble thinking the intuition of playing softmax basically on top of like combining it with the top K where you're getting multiple and then you're using something that's. going to push you towards choosing just one thing. Yeah, I mean I think maybe one way of thinking about the softmax is, you know, the whole purpose of this is just to make it so that when I average my experts later it kind of sums to one. Don't think of the softmax as like a softmax operation even though that's literally the name. Really the softmax operation is a normalized to one operation and the normalized to one operation is going to make that a weighted average up top. The other thing that's very important is you might think why can't I just get rid of the top K? Why don't I just use the softmax here and just gate all the experts? Well then you immediately lose the systems efficiency aspect of this, right? You have to have top K during training otherwise you pay the training cost of all capital N of your experts. This is the key thing about MOEs. We have to do all of this gymnastics to make sure that both at training time and inference. time we have a sparse number of activated experts.

**中文**: 它并非一个严格的上限，而是一种隐式的工具。我很难直观理解为何要在Top-K基础上再应用Softmax——即先选出多个专家，再通过某种机制促使模型只选择其中一个。是的，我认为可以这样理解Softmax：其根本目的，只是确保后续对专家模型进行加权平均时，权重之和为1。请不要将Softmax单纯视作一种“Softmax运算”，尽管其名称确实如此；实际上，它本质上是一种归一化至1的操作，而这种归一化操作最终会形成顶层的加权平均。另一点极为重要的是：你或许会想，为何不能直接去掉Top-K？为何不直接在此处使用Softmax，对所有专家都进行门控？但若真这么做，便会立刻丧失该系统的效率优势——训练阶段必须采用Top-K，否则就得承担全部N个专家的训练开销。这正是MoE（混合专家）模型的关键所在：我们必须设计一系列精巧机制，以确保在训练和推理两个阶段，均仅有稀疏数量的专家被激活。

## 段落 30

**英文**: That's why we go through the top K. Okay, yes, from the back. So because you're doing softmax first and then the top K to get the weights, you no longer have the guarantees for sum to one. So the question was, yeah, so the question was if you softmax first you no longer sum to one. And yes, that's absolutely right. You no longer sum to one. And in some ways there's no requirement that you have to sum to one because the next layer can magnify it back up. There's layer norms everywhere. It's not as if it has to sum to one. But I think that is the reason why some of the other architectures basically move the location of the softmax.

**中文**: 这就是为什么我们要进行 Top-K 操作。好的，是的，从后往前处理。由于你先执行 Softmax，再进行 Top-K 以获取权重，因此不再具备“权重和为一”的保证。问题在于：是的，问题正是——如果你先做 Softmax，权重和就不再为一了。没错，这完全正确，权重和确实不再为一。而且在某种程度上，也并无硬性要求权重必须加总为一，因为下一层可通过放大作用将其重新调整回来；网络中处处存在层归一化（LayerNorm），并非非得满足“和为一”这一条件。但我认为，这正是其他一些架构将 Softmax 的位置进行调整的根本原因。

## 段落 31

**英文**: There's a kind of aesthetic choice about whether you really want that weight to be normalized. to one or not. Yes. Yes, so I was wondering how does the e vector here relates to the weight that consists of the feedforward network? Okay, so the question was whether and how the e vectors relate to the feedforward. They're not really tied in any way. The e vectors are just learned vectors for that. So think of the e's as parameters for the router. They're separate objects from the FFM. Yeah. I was just wondering how does this compare to sampling from the softmax? Great.

**中文**: 是否要将该权重归一化为1，这本身是一种美学选择。  
是的。  
是的，所以我想知道这里的e向量与前馈网络中的权重之间有何关联？  
好的，您的问题是：e向量是否以及如何与前馈网络相关联？实际上，二者并无任何实质关联。e向量只是针对该任务专门学习得到的向量。因此，可将e向量视作路由器的参数，它们与前馈网络（FFN）是彼此独立的对象。  
我刚才只是在想，这种方法与从Softmax中采样相比如何？很好。

## 段落 32

**英文**: The question was about how does it compare to sampling from the softmax. You can sample from the softmax. And some methods actually do kind of soft sampling from the softmax. So actually, one of the Google papers has a procedure where they take the top element. of the softmax and then they randomly sample the second element proportional to the remainder of the softmax. And that gives you more exploration, which is good. But the drawback of that is that if you don't sample at test time, now you've got a train test mismatch. Okay, yes. Why not just re-normalize after pop-in A? Why not just re-normalize after pop-in A was the question. Is that right? And some models do.

**中文**: 这个问题是关于它与从softmax中采样相比如何。你可以从softmax中进行采样，而且某些方法实际上确实采用一种“软采样”方式从softmax中采样。事实上，谷歌的一篇论文就提出了一种方法：先选取softmax输出中的最高概率项，然后根据softmax剩余部分的概率分布随机采样第二项，从而增强探索性，这很有好处。但该方法的缺点在于，若测试阶段不进行采样，就会导致训练与测试阶段的不匹配。好的，是的。“为何不在弹出A之后重新归一化？”——这就是刚才的问题，对吗？确实，有些模型正是这样做的。

## 段落 33

**英文**: Some models do re-normalize after the top K. But that's kind of a choice. Like some architectures don't do that. Some architectures do. It doesn't actually matter because the scale can be basically adjusted post-hop. So there's no reason why it has to sum to 1 after the G operation. Cool. Oh, sorry. Yes. The bias, you don't know the term, is U.

**中文**: 某些模型会在选取前K个结果后重新归一化，但这其实是一种设计选择：有些架构会这样做，有些则不会。实际上这并不重要，因为缩放比例完全可以在跳跃连接之后进行调整。因此，G操作之后的结果总和并不一定要为1。很好。哦，抱歉，是的，偏置项（bias）你可能不熟悉，它用U表示。

## 段落 34

**英文**: Yes. Up there. Yeah. So if the sum, if G is approximating the probability vector, it could be seen as an expectation. of the function FFN right now. Plus U. So FFN actually, this is not an expectation of FFN because each FFN is a different FFN. So this is not actually an expectation and the gates are sparse. So this is like a weighted selection operation over K different, or actually capital N different FFNs. So if you look at the UTL at the very end there, if you remember the transformer, that's the residual stream.

**中文**: 是的，就在上面。对，所以如果总和中G近似于概率向量，那么它可被视为当前函数FFN的期望值，再加上U。但实际上，FFN并非FFN的期望值，因为每个FFN都是不同的FFN。因此，这实际上并非期望值，且门控是稀疏的。这相当于在K个（或更准确地说，在N个）不同FFN上执行一种加权选择操作。因此，如果你回顾最后的UTL（统一变换层），并联想到Transformer结构，那便是残差流。

## 段落 35

**英文**: So I'm adding back the inputs because I want sort of an identity connection throughout. OK. Oh, there's another question. Why does the router have such a basic parameterization? Like what happens if you put more weights into your router function? Great. The question was, why is the router so basic? It seems like if you're going to have experts, it seems important to route to the right experts. So why don't you do that? I think there have been some ablations in some of the earlier Google papers on having like MLP routers and more sophisticated things. I think the sort of complex answer here is that the systems concerns sort of weigh heavily. If you're using a lot of flops to make routing decisions, you have to pay for those flops. And so you have to get performance improvements in just the routing. And I think that one other thing to appreciate here is that there are really big limits to how well you can route because the learning process for this routing thing is actually.

**中文**: 因此，我重新加入了输入，目的是在整个网络中建立一种类似恒等映射的连接。好的。哦，还有另一个问题：为什么路由器的参数化如此基础？例如，如果在路由器函数中加入更多权重，会发生什么？很好。这个问题是：为什么路由器设计得如此简单？既然已经设置了多个专家模块，那么将输入精准地路由到合适的专家似乎至关重要，那为何不这么做呢？我认为，在谷歌早期的一些论文中，已有一些消融实验尝试过使用多层感知机（MLP）路由器及其他更复杂的结构。此处较为复杂的答案在于，系统层面的考量占据了重要地位：如果你耗费大量计算量（FLOPs）来做出路由决策，就必须为这些计算量付出代价；因此，仅靠改进路由本身必须带来显著的性能提升。此外，还需认识到，路由效果实际上存在相当大的上限，因为这一路由机制的学习过程本身……

## 段落 36

**英文**: pretty dicey, right? Because how are you going to get gradients for which routers are good or bad? Well, the only thing you have is if you have top two, then you can compare the two things that you have and you can push the gradients into S of T because your G is a weight. And then the S of T might inform your inner products. But that's a very indirect way to be learning your affinity. So even if you make it complex, there's no guarantee that you're going to really learn the optimal router. Right. OK. So I think one of the great innovations of the DeepSeq MOE, which was very quickly adopted by all the other sort of Chinese MOE releases, is this idea of both a shared expert and a fine-grained expert. And so the basic MOE structure that was sort of originally proposed is to take your dense architecture and kind of copy the experts over. So in this case, you're going to have, let's say if you have top two routing, you're going. to have twice the activated parameters of your original dense model.

**中文**: 相当棘手，对吧？因为你要如何为“哪些路由器好、哪些不好”计算梯度呢？实际上，你唯一能利用的信息是：如果你采用前二路由（top-two routing），就可以比较所选出的两个专家，并将梯度反向传播至S(T)，因为你的G是一个权重；而S(T)又可能影响内积计算。但这种方式学习亲和度（affinity）非常间接。因此，即便你把模型设计得再复杂，也无法保证真正学到最优的路由器。对吧？好的。我认为DeepSeq MOE的一项重大创新——这一思路很快被国内其他各类MOE模型所采纳——在于同时引入共享专家（shared expert）与细粒度专家（fine-grained expert）。而最初提出的典型MOE结构，是将原有稠密架构中的专家模块进行复制。例如，在前二路由机制下，激活参数量将达到原始稠密模型的两倍。

## 段落 37

**英文**: So you take your MOE and you copy it over and you activate K equals two. So this is kind of what you might think of as like the vanilla or like the basic MOE that you might start with. People realized fairly quickly that having lots of experts is good. And the logical sort of next step beyond having lots of experts is good is I want lots of experts, but I don't want to pay the parameter cost for having lots of experts. And so DeepSeq basically argued that the right thing to do then was to cut the expert up. into smaller pieces. So remember last lecture I was telling you about the kind of golden rule in some sense is to have your hidden layer and then you multiply that by four and that will give you kind of your projection layer. So now what you would do is you would, instead of multiplying by let's say four, you might multiply by two. So now you have smaller matrices, you have more fine-grained experts, you can have twice as many of them. And you can kind of take that logic much more to the extreme.

**中文**: 因此，你取自己的混合专家模型（MOE），将其复制一份，并将激活专家数 K 设为 2。这大致可视为一种“标准版”或“基础版”的 MOE，是你入门时可能首选的配置。人们很快意识到，设置大量专家是有益的；而在此基础上更进一步的自然思路是：我既希望拥有大量专家，又不愿承担因专家数量增加而带来的参数量开销。于是，DeepSeq 基本上提出，此时最合理的做法是将每个专家拆分为更小的模块。还记得上一讲中我提到过某种意义上的“黄金法则”：隐藏层维度乘以 4，即得到投影层维度。而现在，你不再将隐藏层维度乘以 4，而是改为乘以 2；如此一来，所得矩阵更小，专家划分更精细，专家数量便可翻倍。你甚至可以将这一思路推向更极致的程度。

## 段落 38

**英文**: You can like quadruple or multiply by eight and you can keep decreasing the size of your sort of projection dimension there. That's fine-grained experts. And there's drawbacks I'll talk about later. It doesn't come for free. So you have to be very careful about how you structure these things. And then the other thing that has been sort of studied and noted is maybe it's helpful. to have at least some MLP that can capture shared structure. Maybe there's just like processing that always needs to happen no matter which token you're processing. In that case, it seems like kind of a waste to do all this routing work and to have all these parameters spread out everywhere when we can just have one shared or one or a few shared experts whose job it is to handle all of this shared processing that's needed. And so they're shared experts.

**中文**: 你可以将专家数量增至四倍，甚至乘以八，并持续降低投影维度的大小，这就是细粒度专家。稍后我将讨论其缺点——它并非没有代价，因此你必须非常谨慎地设计这些结构。此外，已有研究指出，或许设置至少一部分多层感知机（MLP）来捕捉共享结构是有益的：例如，无论处理哪个词元，某些计算流程总是必需的。在这种情况下，若仍进行大量路由操作，并将参数分散在各处，似乎是一种浪费；相反，我们完全可以设置一个或少数几个共享专家，专门负责处理所有这类必需的共享计算，这类专家即为共享专家。

## 段落 39

**英文**: So this setup of using fine-grained experts plus shared experts originally came out in. DeepSeq MOE. Although I think the original inspiration came from DeepSpeed MOE. And Quen and others, so almost all of the open MOE releases since DeepSeq have adopted some sets of these innovations because it's quite clear that especially fine-grained experts is just really, really useful. It's a kind of no-brainer at this point to do. One of the things I really like about reading DeepSeq papers is that they do ablations. It's not like a whatever sales tech report. They actually care about whether or not their methods work. And so they have this lovely ablation in the DeepSeq MOE paper where they show the blue bar over here. This is G-shard.

**中文**: 因此，这种采用细粒度专家与共享专家相结合的架构最初源自DeepSeq MOE。尽管我认为最初的灵感来自DeepSpeed MOE，以及Quen等人的工作。自DeepSeq以来，几乎所有开源的混合专家（MOE）模型均采纳了其中若干创新点，因为事实已十分明确：尤其是细粒度专家机制，确实极为实用；如今采用该机制几乎已成为不言而喻的必然选择。我特别欣赏DeepSeq论文的一点在于，它们均进行了消融实验——而非泛泛而谈的营销式技术报告；作者真正关注其方法是否切实有效。因此，在DeepSeq MOE论文中，他们呈现了此处所示的精妙消融分析：图中蓝色柱状图代表G-shard。

## 段落 40

**英文**: This is a very basic vanilla implementation of an MOE. You can have one shared expert, that's the orange bar, and that gives you a big boost on some tasks and no boost on others. You can have fine-grained experts, that's the green and orange bars, and you get further. boosts from that. And if you compare the blue to the orange, composing all of these differences give you quite the big boost over others. And so we can see that more experts and shared experts generally seem to help. OK, yes, question. Is that odd, like when it says seven out of something? Does that mean it's doing like top seven? Yes, sorry, I should have explained that. That's right. So X out of Y means X activated out of Y total routed experts.

**中文**: 这是一种非常基础的混合专家（MOE）实现。你可以设置一个共享专家（即橙色柱状图），它能在某些任务上带来显著提升，而在其他任务上则无提升效果。你也可以设置细粒度专家（即绿色和橙色柱状图），从而获得进一步的性能提升。若将蓝色柱状图与橙色柱状图进行比较，综合所有这些差异，便能获得远超其他方法的显著提升。由此可见，增加专家数量以及引入共享专家通常都有助于提升性能。好的，是的，请问？——“七分之几”这种表述是否有些奇怪？是否表示选择前七个专家？是的，抱歉，我本应对此加以说明。您理解得完全正确。“X out of Y”表示从总共Y个被路由的专家中激活X个专家。

## 段落 41

**英文**: And so you can kind of see the pattern here as well of as you increase the number of experts, you also often increase the number of activated experts. Especially if you're doing fine-grained experts, it, FOPs-wise, it's free, right? Because each expert is now smaller. Good, OK. So OLMO has basically corroborating evidence that shows really nicely that these things. work. So the bottom one, I think I'll start with because it's more decisive, shows fine-grained experts going from 8 to 32 to 64, fine-grained experts mirroring in some sense the deep sea ablations. And you see very clear trends and losses and other kinds of metrics that you see improvements going from 8 to 32 to 64, right? Fine-grained experts is great. Shared experts, which is purple versus teal at the very top, you actually don't see really. any gains at least in the OLMO setup. So they actually end up going with no shared experts even though the deep sea paper seemed to show more gains.

**中文**: 因此，您也可以在此处看出一种规律：随着专家数量的增加，被激活的专家数量通常也会增加。尤其是采用细粒度专家（fine-grained experts）时，从计算量（FLOPs）角度看，这实际上是“免费”的，对吧？因为每个专家的规模现在更小了。很好，明白了。因此，OLMO 的研究基本提供了有力的佐证，清晰地表明上述方法确实有效。下面这张图（底部图表）我认为应首先介绍，因其结论更为明确：它展示了细粒度专家数量从 8 个增至 32 个、再增至 64 个的效果；这些细粒度专家在某种程度上与 DeepSea 消融实验的结果相呼应。您可清晰地观察到损失值及其他各类指标均呈现持续改善趋势——即从 8 个专家到 32 个，再到 64 个，性能稳步提升，对吧？细粒度专家效果极佳。而共享专家（图中顶部紫色线与青绿色线的对比）则几乎未见任何增益，至少在 OLMO 的实验设置下如此。因此，他们最终选择完全不采用共享专家，尽管 DeepSea 论文似乎显示共享专家能带来更多收益。

## 段落 42

**英文**: So that one actually is maybe more mixed given this sort of follow-up or this third-party replication of these kinds of ideas. So at this point, you might be wondering, what are common configurations? I think I'm going to take the page out of last lecture's playbook of looking at a lot of the recent releases, looking at what people do, and trying to talk a little bit about. the patterns that have arisen. So some of the early Google papers, so G-shard, Switch Transformer, STMOE, some of them had really large numbers of routed experts. There was a lot of really interesting stuff going on in those papers. I'd encourage you to read them. Some of them happened in LSTMs and other kinds of architectures. Regardless, very quickly, I think there was a period of 8 to 16 experts, like Mixed Roll, DBRX, Grok, with two active experts. Those worked reasonably well, but then DeepSeq MOE or DeepSeq MOEv1 comes out. That has the prototypical configuration I told you about.

**中文**: 因此，考虑到这类后续研究或第三方对这些理念的复现，前者实际上可能混合程度更高。此时，您或许会好奇：常见的配置有哪些？我想借鉴上一讲的做法，梳理近期发布的诸多模型，观察人们实际采用的方式，并简要探讨由此形成的一些模式。早期一些谷歌论文（如G-Shard、Switch Transformer、ST-MoE）采用了数量极多的路由专家，其中包含大量极具启发性的内容，我建议您阅读这些论文。其中部分工作还延伸到了LSTM及其他架构中。但很快，业界便普遍转向8至16个专家的配置，例如Mixtral、DBRX、Grok等模型，均采用每次激活两个专家的设计，效果尚可。随后，DeepSpeed MoE（即DeepSpeed MoEv1）问世，其采用的正是我此前介绍过的典型配置。

## 段落 43

**英文**: So there's a trained expert, 64 of them, 6 actively routed, 2 shared experts, and each sort of expert is sort of one-fourth the size of a normally sized expert. Take that last column with a grain of salt, because I had to sort of back them out from like config files and things like that, so I'm not 100% sure about the exact ratios here. So we've then got essentially Q1. 5, DeepSeq v3, Minimax, these are Chinese MOEs. They follow essentially in the same footsteps as DeepSeq v1. The specific numbers are different, but in the sense that they use fine-grained experts and they often have shared experts, they're very similar to kind of this original DeepSeq MOE configuration. Olmo, Minimax, and Lama are very recent MOEs. They definitely do all this fine-grained expert stuff, and Lama 4 also uses a shared expert. You kind of see sort of variations in configuration, but you see what's basically shared, which is this fine-grained experts idea, and especially for the big models like Lama 4 and DeepSeq, very very large numbers of routed experts. Or sorry, not routed, like total experts.

**中文**: 因此，这里有一组经过训练的专家，共64位，其中6位是活跃路由的专家，另有2位是共享专家；而每位专家的规模大约仅为常规规模专家的四分之一。最后这一列数据请谨慎参考，因为我主要是从配置文件等资料中反向推算得出的，因此无法完全确定此处的具体比例。接下来我们看到的基本上是Q1.5、DeepSeq v3和Minimax，这些均为中国研发的混合专家（MoE）模型，其设计思路基本沿袭了DeepSeq v1的路径：虽然具体参数有所不同，但它们均采用细粒度专家，并普遍引入共享专家，因此在整体架构上与最初的DeepSeq MoE配置高度相似。Olmo、Minimax和Llama则是最新推出的MoE模型，它们无疑都采用了上述细粒度专家机制，且Llama 4还额外使用了一位共享专家。尽管各模型在具体配置上存在一定差异，但其共性十分明显——即均基于细粒度专家这一核心理念；尤其对于Llama 4和DeepSeq这类大型模型而言，其专家总数极为庞大（注：此处指专家总数，而非仅活跃路由的专家数）。

## 段落 44

**英文**: Yes? Can you explain what the ratios are? The ratio is representing roughly like how much each expert is sliced relative to having just the standard dense configuration. So in terms of hyperparameters, you know that if you're following the rule of thumb, your hidden dimension and sort of your projection in your MLP should be about 1 to 4, or 1 to 2. 6 if you're doing a gated network, right?. And so by looking at the hidden layers of these architectures, you can kind of see how many times they sliced up that original feedforward size. So if like frequency for the wireless power ratio is 1 to 4, but then they have 64 of those experts, does that mean that like still increasing their code? Right, you're finding like the factor of. That's right, yeah. You can think of this as roughly, they have 16 normally sized experts. And so they're of course having more parameters than the dense equivalent. They have six routed experts. So they have eight total active experts at any time, each that are quarter sized.

**中文**: 是的？您能解释一下这些比率的含义吗？该比率大致表示每个专家模块相对于标准稠密配置被“切分”的程度。因此，从超参数角度看，若遵循经验法则，您的隐藏层维度以及MLP中的投影维度通常应为1:4或1:2.6（若采用门控网络，对吗？）。通过观察这些架构的隐藏层，您大致可看出原始前馈网络规模被切分了多少次。例如，若无线功率比率的频率为1:4，而他们又设置了64个专家模块，这是否意味着其代码量仍在增加？没错，您实际上是在计算这一缩放因子。正是如此。您可以粗略地理解为：他们相当于拥有16个常规尺寸的专家模块。因此，其参数总量自然超过了等效稠密模型；他们共路由6个专家模块，故任一时刻共有8个活跃专家模块，每个模块的规模仅为常规尺寸的四分之一。

## 段落 45

**英文**: And so you should think of them as like roughly double the flux of a dense equivalent. So some arithmetic, but hopefully the math is clear and consistent. Yes? Like the ratio is like 1 to 4, are you able to like put it down? Like, it's like that way. So for some of the exotic ratios, I'm not quite sure why they're that way, but they. are very precisely whole numbers when you take the ratios between the FFNs and the implied hyperparameters. And so I think those are exactly the split counts of like how much they were sliced, but I'm not sure why they have one over 14. I mean, like, does the DRR project look like a smaller dimension because like their ratio is so small in the MLP? So yeah, so yeah, that's why you're asking. Like, do they down project?. Yeah, that's right. In some of them, they are actually smaller.

**中文**: 因此，你们应将其视为通量约为同等稠密模型的两倍。这里涉及一些算术运算，但希望数学逻辑清晰且一致。是的？比如比例大约是1比4，您能否明确写下来？就是这样的方式。对于某些特殊比例，我尚不清楚其成因，但当计算前馈网络（FFN）与隐含超参数之间的比例时，这些比例却非常精确地表现为整数。因此，我认为这些整数恰好对应于它们被切分的具体份数，但我还不明白为何会出现1/14这一比例。我的意思是，DRR项目看起来维度更小，是不是因为其在MLP中的比例非常小？所以，是的，这正是您提问的原因：它们是否进行了降维投影？没错，确实如此。在部分模型中，其维度实际上更小。

## 段落 46

**英文**: I don't remember which models in particular, but in some of them, I do remember they were actually down project. Yes? What is the intuition for wanting more than one shared expert? Yeah, I mean, it does kind of seem like there was a period where some of the Chinese alum companies tried many shared experts and then, you know, people have come back to zero or. one. And if you look at the old mobulations, it's not quite clear that even one shared expert is decisively useful. I think the original motivation was that then you have equally sized experts. Like, these are both one quarter sized experts and now you have eight active experts total. And so you can keep the sizes consistent. Otherwise, I don't really see a particular justification for why it should be two smaller ones versus one larger one. Okay, cool. So then hopefully, you know, you get a sense of how the routing works for a lot of these MOEs and how it's all set up.

**中文**: 我不记得具体是哪些模型了，但其中一些模型，我确实记得它们实际上是“向下投影”的。是的？那么，为什么想要多个共享专家呢？嗯，的确曾有一段时间，一些中国校友创办的公司尝试使用多个共享专家，但后来大家又回归到零个或一个共享专家。如果你回顾早期的模型，甚至一个共享专家是否具有决定性作用也并不明确。我认为最初的动机是让各个专家的规模保持一致，例如，这两个专家的规模都是整体的四分之一，这样总共就有八个活跃专家，从而能维持专家规模的一致性。否则，我实在看不出为何采用两个较小的专家就一定优于一个较大的专家。好的，很好。那么希望你现在已经对这些混合专家（MoE）模型的路由机制及其整体架构有了基本了解。

## 段落 47

**英文**: The forward pass, hopefully, you fully understand. Now we need to think about training and training is pretty gnarly, right? And the major challenge I foreshadowed earlier, right? When we train, we cannot turn on all the experts because if we do that, then we put a lot of effort into training. And then we pay the full flops cost of all of the experts, right? Having a model that's like, I don't know, 256 times more expensive to train is a total no-go, right? So we need train time sparsity, but sparse gaining decisions are obviously not differentiable. We now have a kind of annoying RL-ish problem. And so we could do any of these things like RL to optimize gaining policies. We could do bandit-inspired things of doing randomization to do exploration. Or we can just have some heuristics that try to balance things out, right?. Like put some lost terms in there and hope things work out. You know, having gone through deep learning, classes of many kinds, you can kind of guess internally which one people use in practice. And I'll talk about each one of these three in turn.

**中文**: 前向传播，希望你已经完全理解了。现在我们需要思考训练问题，而训练确实相当棘手，对吧？之前我已预先点明的主要挑战，正是如此：训练时我们无法同时启用所有专家，因为一旦这样做，就会耗费大量训练资源，同时还要承担全部专家所带来的完整浮点运算量（FLOPs）开销，对吧？一个训练成本高达原有模型256倍的模型，显然是完全不可行的，对吧？因此，我们需要在训练时实现稀疏性；但稀疏的门控决策显然不具备可微性，这就带来了一个颇为烦人的、类似强化学习的问题。于是，我们可以采用多种方法来优化门控策略，例如使用强化学习；也可以借鉴多臂老虎机思想，通过随机化实现探索；或者干脆采用一些启发式方法，试图在各方面取得平衡，比如引入某些损失项，寄希望于最终效果良好。你经历过各类深度学习课程后，内心大概已能推测出实践中人们实际采用的是哪一种方法。接下来，我将依次介绍这三种方法。

## 段落 48

**英文**: OK, so RL, I think, is one of the earliest things that people tried. It's probably the most principal thing that you can do in this space, right? You have a non-differentiable routing decision. Well, think of that as a policy, throw our RL at it, and then solve the problem. Unfortunately, it's not better than a lot of the other things that you can do. There is a paper by Clark and on 2020 who were exploring various like scaling-related questions in MOEs, and they do have an RL baseline that I was able to dig up. But unfortunately, it's not really that much better than say using hashing for decisions. And they were really interested in benchmarking this thing on the left called S-Base, which is like a linear assignment kind of a method. And that thing, you know, handily beats doing RL. And I think in practice, the gradient variances and complexity means that it's pretty finicky to use. And no one at scale has really used an RL-based approach to optimize these gating decisions as far as I know.

**中文**: 好的，强化学习（RL）我认为是人们最早尝试的方法之一，它很可能是该领域中最根本的方法，对吧？你面临的是一个不可微分的路由决策问题，那么不妨将其视为一种策略，将强化学习应用于该问题，进而求解。遗憾的是，其效果并不优于许多其他可行方法。克拉克（Clark）等人于2020年发表的一篇论文探讨了混合专家模型（MOE）中各类与扩展性相关的问题，其中确实包含一个强化学习基线方案，我设法找到了该方案。但遗憾的是，其性能并未明显优于采用哈希方式进行决策的方法。他们真正关注的是左侧名为“S-Base”的基准测试方法，这是一种类似线性分配的策略；而该方法显然轻松胜过强化学习方案。我认为，在实际应用中，梯度方差大、实现复杂等因素使得强化学习方法非常难以调优；据我所知，目前尚无任何大规模系统真正采用基于强化学习的方法来优化此类门控决策。

## 段落 49

**英文**: I think that has been done much more at scale is stochastic approximations of various kinds. So what they might do is they might add a bit of perturbations. So here is an example of one from Shazir in 2017. This is one of the early MOE papers where they're still going to do kind of top-K routing. So they're going to keep the top-K elements of this H of X operation. And they're going to softmax that to get the gate. But what we're going to do to get this H of X operation is kind of the following. So what we're going to do is we're going to have our original sort of linear affinity. This is identical to what we were doing before. We were basically just computing our inputs X and a sort of learned weight for each gate.

**中文**: 我认为，目前规模更大、应用更广的是各类随机近似方法。因此，它们可能会引入一些扰动。例如，2017年沙齐尔（Shazir）提出的一种方法即属此类。这是早期的混合专家（MOE）论文之一，仍采用类似“Top-K”路由机制：即保留该H(X)运算结果中的前K个元素，并对其应用Softmax以获得门控权重。而为实现这一H(X)运算，我们采取如下方式：首先，我们沿用原始的线性相似度计算——这与之前的做法完全一致，即仅对输入X及每个门控所对应的可学习权重进行计算。

## 段落 50

**英文**: And so this part's the same. But I'm actually now going to jitter it a little bit. I'm going to add a normal. And then I'm going to pick sort of a W noise scale that's learned. And this thing is going to control how much noise to inject into this process. And you kind of think of this as a stochastic exploration policy. And by manipulating W noise in particular ways, like sort of a kneeling it down or doing various things, I can control the exploration, exploitation tradeoffs that this MOE is going to have. And so this is going to give you one solution to the explore, exploit dilemma. And especially if you're noising things up, each expert might randomly get some other tokens that it wasn't expecting to get. So it will lead to experts that are less specialized, but maybe a little bit more robust.

**中文**: 因此，这部分保持不变。但我现在会对其稍作抖动处理，即添加一个正态分布噪声，并选取一个可学习的W噪声尺度参数。该参数将控制注入此过程的噪声量。你可以将这一机制理解为一种随机探索策略。通过以特定方式调节W噪声（例如逐步降低其值或采取其他操作），我便能调控该混合专家模型（MOE）在探索与利用之间的权衡。因此，这便提供了一种解决探索—利用困境的方案。尤其当对输入进行加噪处理时，每位专家都可能随机接收到一些原本未预期的令牌，从而导致专家的专业化程度有所降低，但鲁棒性可能略有提升。

## 段落 51

**英文**: And so that seems generally quite nice. Of course, the stochasticity also means that you don't get as much specialization, and that leads to loss of efficiency. And there's another approach that people have done where they sort of multiply the router logits. We're sorry, they have a multiplicative perturbation to the router logits with the goal of getting less brittle experts. But this sort of jitter process was kind of removed in some of the later papers because they found it just didn't work as well as some of the heuristic loss based approaches. And so this was an approach that was tried in a couple. This kind of stochastic routing tricks were tried in a couple of the early Google papers. But I think that has generally been abandoned by a lot of the people training these MOEs. OK, so yes. For the stochastic, what problem does that solve? Because we're still taking the top case and we still can't differentiate that.

**中文**: 因此，这看起来总体上相当不错。当然，随机性也意味着专业化程度降低，从而导致效率下降。人们还尝试过另一种方法，即对路由器的逻辑值进行某种乘法操作——抱歉，准确地说，是通过乘法扰动来调整路由器的逻辑值，目的是使专家模型不那么脆弱。但这种抖动过程在后续的一些论文中被摒弃了，因为他们发现其效果不如某些基于启发式损失的方法。因此，这种方法仅在少数几篇论文中尝试过。这类随机路由技巧曾在谷歌早期的几篇论文中被采用，但我认为目前大多数训练混合专家（MoE）模型的研究者已普遍放弃了这种方法。好的，那么对于随机路由而言，它究竟解决了什么问题？毕竟我们仍然只选取前k个结果，且依然无法对此进行微分。

## 段落 52

**英文**: Well, if you think of this, the question was, we still can't differentiate because we're taking the top case. But if you kind of change your interpretation of the problem a little bit, if you think about a bandit problem, right, it has the same structure as this, where you pull a bandit arm and you don't see any of the other arms. So you can't really allocate your resources efficiently. If you pull some of the other ones at random, now you've got enough data to be able to do some optimization. And so this jittering is very similar in spirit to this kind of like Epsilon greedy style exploration thing, where you're randomly pulling some of the other arms with some probability, where the probability itself depends on how confident you are about this routing decision. So that's kind of the intuition. And then, of course, you know, that's going to give you some way of getting some signal back. OK. So the thing that in practice people have ended up with is, you know, we don't do any of that. We don't do, you know, RL.

**中文**: 嗯，如果仔细思考这个问题，关键在于：我们仍无法进行区分，因为我们始终只选择最优选项。但若稍微调整对问题的理解——比如将其类比为“老虎机问题”（bandit problem），就会发现二者结构相同：你拉动某台老虎机的拉杆后，便无法看到其他拉杆的结果，因此难以高效分配资源。此时，若以一定概率随机尝试其他拉杆，就能积累足够数据以开展优化。这种“抖动”（jittering）机制在思想上与ε-贪心（Epsilon-greedy）式探索非常相似：即以某一概率随机选择其他选项进行尝试，而该概率本身取决于你对当前路由决策的置信程度。这便是其基本思路。当然，如此操作自然能为你提供某种反馈信号。好的。然而在实际应用中，人们最终并未采用上述任何方法，也未采用强化学习（RL）。

## 段落 53

**英文**: We don't do stochastic exploration. But we rely on really another mechanism to sort of keep things reasonable. So if we're doing top two routing, right, technically speaking, we do get some signal in the gradient descent process because we can compare the top two experts that we did evaluate. And so it's possible to do some optimization. But when we do ignore, if we drop all the other constraints, the big issue that arises is you just end up sort of picking one expert all the time. And that expert is good at everything. And all the other experts are terrible. You end up in this local minimum where you've routed all of your tokens to one expert all the time. So really, the key game becomes then how do we get out of that local minimum and loss balancing or like balancing losses is really the key trick to get out of this. And this is this is kind of important to understand because this is the loss that mostly everyone actually uses to train the MOEs.

**中文**: 我们不采用随机探索。但我们依赖另一种机制来确保整体效果合理。例如，在进行“前两名路由”时，从技术上讲，我们在梯度下降过程中确实能获得一些信号，因为我们可对实际评估过的前两名专家进行比较，从而实现一定程度的优化。然而，如果我们忽略所有其他约束条件，就会出现一个严重问题：模型最终会始终只选择同一个专家——该专家看似样样精通，而其余所有专家则表现极差。结果，模型陷入一种局部极小值：所有输入词元（tokens）都被持续路由至这单一专家。因此，关键挑战便转化为：如何摆脱这一局部极小值？而损失均衡（即平衡各专家的损失）正是突破该困境的核心技巧。这一点至关重要，因为目前几乎所有研究者在训练混合专家（MoE）模型时，实际采用的正是这种损失函数。

## 段落 54

**英文**: Right. So if you were zoning out earlier, you know, you probably should make sure to pay attention to this particular set of equations here. So this is originally from the switch transformer from FedEx on twenty twenty two. I mean, they add this particular loss where what they're going to do is they're going to loop all over each of the experts and they're going to take, you know, the you could think of this as an inner product between the vector F and the vector P. And so what are these vectors? Well, F is for each of the experts. This is the fraction of the tokens that were allocated to expert. So you can think of this as kind of a probability vector that's telling me what fraction of my tokens in my batch or in my whatever the unit is here did I route to expert. Now, P of I is the fraction of the router probability that was allocated to expert. So the router probability is kind of the the original sort of soft maxed routing decision that I was sort of intending to send. Right.

**中文**: 没错。因此，如果你之前走神了，那么现在务必集中注意力关注此处的这一组方程。该公式最初源自2022年FedEx提出的Switch Transformer模型。具体而言，他们引入了这一特定损失项：遍历所有专家模块，并计算向量F与向量P之间的内积。那么，这两个向量分别代表什么？其中，F是针对每个专家的向量，表示分配给该专家的token所占比例，可将其理解为一个概率向量，用于说明在当前批次（或此处所指的任意处理单元）中，有多少比例的token被路由至该专家；而P[i]则表示路由机制分配给第i个专家的概率占比，即路由机制原本通过softmax软决策所生成的、拟分配给各专家的概率分布。

## 段落 55

**英文**: So this is kind of measuring P of I is what was sort of the intended probability from the router. And then F of I was what was the actual sort of like, you know, was the actual routing decision made by the top K method. And one thing that's kind of interesting to look at here is let's say we take the derivative of that loss with respect to the P of I. So, you know, this is a linear function with respect to P of I. And you'll see that the strongest Dow downweighting action happens on the sort of biggest experts with the biggest allocations. Right. So the it's actually, in fact, proportional to the amount of tokens that you get. So you're going to be pushed downwards sort of more strongly if you got more tokens. And so this is kind of the basic behavior of this loss. And, you know, almost everybody uses this kind of F dot P kind of a trick to try to balance tokens across different units.

**中文**: 因此，这实际上是在度量路由器所意图输出的概率 $ P(i) $，而 $ F(i) $ 则是顶级-$ K $ 方法实际做出的路由决策。此处一个值得注意的现象是：若我们对该损失函数关于 $ P(i) $ 求导，便会发现该损失函数关于 $ P(i) $ 是线性的；进一步观察可知，对分配权重最大的专家（即获得最多令牌的专家）所施加的降权作用也最强。换言之，这种降权强度实际上与各专家所获得的令牌数量成正比——获得令牌越多，所受向下的推力就越强。这便是该损失函数的基本行为特征。事实上，几乎所有研究者都采用这种 $ F \cdot P $ 类型的技巧，以期在不同专家单元之间实现令牌分配的均衡。

## 段落 56

**英文**: The basic unit that you might want to balance over initially is batches. You might want each batch to get allocated evenly to experts. But you might actually have other kinds of balancing that you might want to do. And DeepSeq does exactly this kind of thing. I'll talk about all the variants that they've thrown in. But, you know, the first thing is per expert balancing per batch. So each batch, they want to make sure experts get an even number of tokens. And, you know, this is from the DeepSeq paper. And hopefully this looks very familiar to you. This is exactly the same, you know, F dot P inner product structure as you saw before.

**中文**: 你最初可能希望进行负载均衡的基本单位是批次（batches）。你可能希望每个批次中的样本被均匀地分配给各个专家（experts）。但实际中，你可能还需要实施其他类型的负载均衡策略。而DeepSeq恰恰实现了这类功能。我将详细介绍他们所提出的各类变体。不过，首先需要说明的是：按批次对各专家进行负载均衡。也就是说，在每个批次中，他们力求确保各专家所处理的词元（tokens）数量相等。这一点源自DeepSeq论文，希望你对此已非常熟悉——这与之前所见的F·P内积结构完全一致。

## 段落 57

**英文**: You know, P of I is defined a little bit differently. That's S of I of T, you know, but that should be familiar from earlier as well. That's the softmax pre top K, right? So hopefully this looks all pretty good to you. The other thing you might want, though, is, you know, you might want to balance across experts. That's all well and good. But you might also want to think about the systems concerns, right? Because you're going to shard your experts onto different devices. And you might want to balance per device, right? And so you might have another loss that's essentially the same structure. But instead of summing, you know, which tokens go to which experts, you might measure which tokens go to which devices, right? And that's going to be a different F that's measured over the device groups rather than over each expert. And so now you can set up a different loss to balance over devices. You optimize this.

**中文**: 你知道，“P of I”的定义略有不同，即“S of I of T”，但这一点此前应该已经很熟悉了。这就是Softmax前的Top-K操作，对吧？因此，希望这部分内容对你来说看起来都很清晰明了。不过，你可能还需要考虑另一点：即在各个专家之间实现负载均衡，这固然很好；但你还需兼顾系统层面的考量，对吧？因为你要将各个专家分片部署到不同的设备上，所以你可能还需要实现每台设备上的负载均衡，对吧？为此，你或许可以设计另一个损失函数，其结构基本相同；但区别在于：不是统计每个专家分配到了哪些token，而是统计每个设备分配到了哪些token，对吧？此时，所采用的函数F将针对设备组进行计算，而非针对每个专家单独计算。这样一来，你就可以构建一个专门用于设备级负载均衡的损失函数，并对其进行优化。

## 段落 58

**英文**: You're naturally going to try to learn routing functions that make sure each GPU or each TPU, what have you, have an even number of tokens leading to even utilization, right? And that would be great from a systems perspective. So basically everyone does, you know, kind of this kind of a thing. And so DeepSeq v3 actually kind of innovates a little bit. This is this is kind of cool. And I don't think I've seen this before. It's one of the first things in the M. O. E. world that doesn't actually come from Google, really, which is that they have gotten rid of this expert balancing term. They've gotten rid of this entirely.

**中文**: 你自然会尝试学习路由函数，以确保每个GPU或每个TPU（或其他硬件）分配到数量均衡的token，从而实现均衡的资源利用率，对吧？从系统角度看，这确实非常理想。因此，基本上所有人都会采用这种思路。而DeepSeq v3实际上在这方面做了一些创新，这一点颇为有趣，而且据我所知此前尚未见过。这也是MoE领域中首批真正并非源自谷歌的成果之一：他们完全摒弃了专家负载均衡项。

## 段落 59

**英文**: And instead, what they now do is they basically take their softmax scores and they add a little fudge factor B of I, where B of I is a little fudge factor score for each expert. Right. So expert I, you know, might get up weighted or down weighted. So if an expert isn't getting enough tokens, you know, it's going to be given a higher B of I. And then that's going to allow it to grab more tokens. And the way that this works is the way that this works is that they're going to learn B of I through a really simple online gradient scheme, online learning. And so they're going to measure at each batch. You know, what are each of the experts getting? Like, are they getting an even number of tokens? And if they're not getting enough tokens, they add sort of gamma, some learning rate to B of I sort of making it higher. If they're if they're getting too many tokens, they're going to subtract gamma, making that expert slightly less attractive. Right.

**中文**: 相反，他们现在所做的是：在softmax得分基础上，为每个专家添加一个微调因子 $ B_i $（即第 $ i $ 个专家对应的微调得分）。例如，第 $ i $ 个专家的权重可能因此被略微上调或下调。若某专家分得的令牌数量不足，则其 $ B_i $ 值会被调高，从而使其更有可能获取更多令牌。该机制通过一种极为简单的在线梯度更新方案（即在线学习）来学习 $ B_i $：在每个批次训练中，系统会统计各专家实际分得的令牌数量——例如是否均衡分配；若某专家分得令牌过少，则向其 $ B_i $ 值增加一个步长 $ \gamma $（即学习率），使其升高；若分得过多，则从 $ B_i $ 中减去 $ \gamma $，从而略微降低该专家的吸引力。

## 段落 60

**英文**: So they're just learning little, you know, offsets for each of the S of I's. And notice here, you know, you're only using the B of I's to make the routing decisions. You're not actually sending it over as part of your gating weights. Right. That's a that's a sort of somewhat important thing to do. So they call this auxiliary loss free balancing. If you go and read the DeepSeek V3 paper, which all of you should, because it's a it's a really nice paper, they'll make a big deal about how this makes training so stable, so great, so wonderful. And then, of course, you like keep reading the section and they're like, actually, but we decided that, you know, for each sequence, maybe we still want to be balanced and this doesn't work well enough. So we've added the you know, the heuristic loss back. So they do have something called the complementary sequence wise auxiliary loss that, you know, is basically exactly the auxiliary loss that they decided they needed, because what they wanted to do was to balance load, balance the experts at a per sequence level rather than a per batch level.

**中文**: 因此，它们只是在学习每个专家（S of I）对应的小幅偏移量。注意，此处仅使用路由权重（B of I）来做出路由决策，而并未将这些权重实际作为门控权重的一部分进行传输，这一点相当重要。他们将这种方法称为“无辅助损失的负载均衡”。如果你去阅读DeepSeek V3论文（强烈建议大家阅读，这是一篇非常出色的论文），文中会着重强调该方法如何使训练过程变得极为稳定、出色且优异。然而，当你继续阅读该章节时，作者又指出：实际上，对于每个输入序列，我们仍希望实现负载均衡，而上述方法在序列级别上的均衡效果并不足够理想；因此，他们重新引入了启发式辅助损失。于是，他们提出了一种名为“互补的序列级辅助损失”的机制——本质上正是此前他们认定必需的那种辅助损失，因为其目标是在每个序列级别（而非每个批次级别）上实现负载均衡，即对各专家的负载进行均衡分配。

## 段落 61

**英文**: I'm not sure why they do this particular thing rather than any other sort of, you know, be a vise style trick. But that's just kind of what they do in DeepSeek V3. So it's not fully auxiliary loss free as they'd like you to believe. OK. Oh, yes. Question. So a bit of an unfair question. But if we did not have to worry about systems optimizations, do you think the performance of this model would be a lot better? But would it stay roughly the same? If we did not think about systems optimization, would the performance of this model be better or stay the same? When you say this model, what do you mean? DeepSeek V3? Or like just in general, like these modern MOEs. So are you saying like if we ignored the systems concerns, do we think MOEs are still good? Is that kind of one way of asking that question? Like would the performance of downstream tasks, for example, be better than what we have right now?. Yeah.

**中文**: 我不太确定他们为何偏偏采用这种特定做法，而不是其他类型的技巧（比如类似台钳式的技巧）。但DeepSeek V3确实就是这么做的。因此，它并非如他们所宣称的那样完全无需辅助损失。  
好的。哦，对了，有个问题——这问题可能有点不太公平。但如果我们完全不必考虑系统层面的优化，您认为该模型的性能会显著提升，还是会基本保持不变？换言之，倘若我们忽略系统优化因素，该模型的性能是会更好，还是大致维持现状？  
当您提到“该模型”时，具体是指DeepSeek V3，还是泛指当前这类现代混合专家（MoE）模型？  
也就是说，您的问题是：如果我们忽略系统实现方面的顾虑，是否仍认为MoE架构本身是有效的？这是否正是您想问的核心？  
例如，在下游任务上的实际性能，是否会优于我们目前所达到的水平？  
是的。

## 段落 62

**英文**: So I think. If I didn't have to balance this, I must say, it's roughly equivalent to at least every expert or. Yeah, yeah, that's right. That's right. Well, I think actually per expert balancing this term, right, this is not a systems concern. So you still want to do this because if you don't do this, what you'll find and actually there is, you know, I'm going to keep referring to the old MO paper because they have so many ablations. They have a really nice ablation where they get rid of exactly this. And what they find is basically early on in training, the model just picks like one or two experts and all the other experts are dead. Like the router never sends anything to them. So you're just wasting memory at that point.

**中文**: 所以我这么认为。如果我不必进行这种平衡，我必须说，其效果大致相当于至少每位专家都参与其中。是的，没错，就是这样。实际上，我认为每位专家都需要进行这种平衡，对吧？这并非系统层面的问题。因此，你仍然需要这样做；否则，你会发现——事实上确实如此，你知道，我将继续引用那篇旧的MO论文，因为其中包含了大量消融实验。他们就恰好做了这样一项消融：完全移除了这一机制。结果发现，在训练初期，模型仅倾向于选择一两个专家，而其余所有专家则完全“死亡”，即路由机制根本不会向它们发送任何数据。此时，你纯粹是在浪费内存。

## 段落 63

**英文**: Right. So now you've just lost performance for free. You've effectively gotten a smaller model. And so even if you ignore all the other like device balancing, power, all those and concerns, you've just gotten the worst model because you didn't properly allocate your your experts. Right. It's the same way as like you want to use all your parameters. Right. You would like to effectively use your parameters. You want to do expert balancing. Sorry, say ah, what does the device refer to? Yeah, actually.

**中文**: 没错。因此，你刚刚在毫无代价的情况下损失了性能，实际上相当于得到了一个更小的模型。所以，即使忽略所有其他因素（例如设备负载均衡、功耗等），你也仅仅因为未能合理分配专家而得到了最差的模型。没错，这就像你想充分利用所有参数一样——你希望参数得到高效利用，因此需要进行专家负载均衡。抱歉，请问“设备”指的是什么？是的，实际上……

## 段落 64

**英文**: So normally this would refer to like GPU or TPU. There is a subtlety. I'll talk about this maybe in the very last or second to last slide. There are more sophisticated and cool versions of this where you try to balance things to minimize communication costs as well. And so there's, you know, broader notions of device like, you know, one rack or whatever else. But here it usually refers like GPU. Yes. Going back to the fact that like hashing as a routing algorithm seems to improve performance. Like, is there intuition for that? Because that's effectively just like random choosing a like one of the few forms of memory suspended. Right.

**中文**: 因此，通常这指的是GPU或TPU。这里存在一个细微差别，我或许会在倒数第二张或最后一张幻灯片中对此加以说明。实际上还存在更复杂、更精巧的版本，其中会尝试在平衡负载的同时，也最小化通信开销。因此，“设备”的概念也更为宽泛，例如可指代一个机架或其他类似单元。但在此处，它通常即指GPU。  
是的。回到这样一个事实：将哈希用作路由算法似乎能提升性能。这其中是否存在直观解释？因为这本质上不过是随机地从少数几个驻留内存中选择其一而已，对吗？

## 段落 65

**英文**: So why does having multiple copies of that, I guess, each of which get less data? Why does that make performance better? Yes. The question was why does hashing do anything at all? I don't have the really precise intuition for this, but you can make arguments either two ways. One is, you know, even if you're hashing, the same tokens are going to go to the same, you know, or the same kinds of sequences are going to go to the same expert every time. Right. And so each expert will still get some deterministic subset of the inputs. And so there's some specialization that can still occur. It's just non-semantic or non-learned. And if you're a distribution zipfian, like the word the might dominate one expert, you know, and so you might still get actually semantic specialization where like one expert is effectively dominated by like very frequent things. But like a random routing function probably. Like a pure random thing that's not dependent on input.

**中文**: 那么，为何拥有多个这样的副本（我猜每个副本处理的数据量更少）反而能提升性能呢？是的，问题在于：哈希究竟起到了什么作用？对此，我并没有非常精准的直觉理解，但可以从两个角度来论证。一方面，即便采用哈希，相同的词元仍会始终被路由至同一专家，或者说相似的序列每次都会被分配给同一专家，因此每个专家依然会稳定地接收某一确定性的输入子集，从而仍可实现一定程度的专业化——只不过这种专业化是非语义的、非学习而来的。另一方面，若数据分布呈齐夫分布（Zipfian），例如高频词“the”可能持续占据某一专家的大部分负载，那么实际上仍可能形成语义层面的专业化，即某个专家实质上主要处理极高频的词元。但若采用随机路由函数（例如完全不依赖输入的纯随机分配），情况则不同。

## 段落 66

**英文**: Yeah, I would bet that that would be really terrible. Yes, I have never run or seen that. But yes, I think that would be that would be horrible. Yes. So for learning LLM, like you have many layers, right? Many transformers. I think you mentioned earlier in the lecture, you mentioned that each expert has a couple of layers of GPU. So like if you have like a back-to-back, like 32 layers, like 64 experts, that's like a lot of GPUs. Or I wonder if like a couple of experts are bundled together on like a single GPU, is that what we need in practice?. The question was like, won't you need lots of GPUs if you have lots of layers and lots of experts? Yeah, if you if you exclusively give a GPU to a single expert, yes, that would be that would be kind of crazy. But you would send a shard thing so that each GPU would hold enough of these units to effectively use memory.

**中文**: 是的，我敢打赌那确实会非常糟糕。没错，我从未运行过，也从未见过这种情况。但的确，我认为那会非常可怕。是的。那么，在学习大语言模型（LLM）时，模型包含很多层，对吧？比如很多Transformer层。我想您在之前的讲座中提到过，每位专家需要占用几层GPU资源。因此，如果模型是连续堆叠的，比如32层、64位专家，那将需要大量GPU。我在想，实践中是否通常会把几位专家打包部署在同一块GPU上？问题其实是：如果模型层数很多、专家数量也很多，难道不会需要大量GPU吗？是的，如果您为每位专家单独分配一块GPU，那确实会相当疯狂。但实际做法是进行分片（sharding），使每块GPU能承载足够多的模型单元，从而高效利用显存。

## 段落 67

**英文**: The name of the game in parallelism is you always want to use up all of your memory because that's one of your resources. You don't want to paralyze more than you have to. Cool. OK, excellent. Oh, OK, I did put the ablation in here. Yeah. So this is exactly what happens to the question of what happens if you don't do expert balancing loss. I think the great picture to see is this bottom left one. If you don't do load balancing, you know, what are the tokens assigned to which expert? You see the pink and yellow expert. They just like kind of take over.

**中文**: 并行化中的关键在于：你始终希望充分利用所有内存，因为内存是你的资源之一；同时，你也不希望过度并行化。很好，明白了。哦，好的，我确实把消融实验放在这里了。是的，这正是在探讨“如果不采用专家负载均衡损失函数，会发生什么”这一问题。最能说明问题的图是左下角这张：如果不进行负载均衡，那么各个token会被分配给哪些专家呢？你会发现粉色和黄色的专家几乎完全占据了主导地位。

## 段落 68

**英文**: They take up about 50 percent of the tokens. All the other experts are dead. They do nothing. Right. And so you've wasted the majority of experts at this point, you know, six out of eight of your experts. And you've created a two expert MOE unintentionally. And, you know, that gives you, you know, worse losses seen up on the top, right. The teal lines, of course, maybe that's still better than the dense model because at least you've got two experts going. But you could have done better, right. Counterfactually speaking.

**中文**: 它们占用了约50%的计算资源（token）。其余所有专家均已失效，完全不发挥作用。没错。因此，此时你已浪费了大部分专家——八位专家中已有六位被闲置。结果，你无意间构建了一个仅含两位专家的混合专家模型（MoE）。如上图所示，这会导致更高的损失（顶部的青色曲线）。当然，该结果或许仍优于稠密模型，毕竟至少还有两位专家在运行；但本可以做得更好，对吧？这是反事实分析下的结论。

## 段落 69

**英文**: OK, so I won't go quite as deep as I could into the system side because I haven't really started to cover the core systems concepts necessary for you to deeply appreciate a lot of the parallels and concerns like, you know, basically the hierarchy of communication speeds in a data center and so on. But really, as I said before, you know, one thing to keep in mind is just how nicely MOEs can fit into devices. You know, the thing that people say is expert parallel, you know, that involves sending or putting one or a few experts onto each device. And what happens when you are basically processing a token? Well, you would hit the router and after the router, you now have picked few experts. And so now you would have a collective communication call, like all to all communication dispatch that would send the tokens to the relevant devices. You know, the feed forwards a compute, you know, their outputs and then you would return the tokens to sort of where they belong or you would, you know, combine, I guess, multiple experts. And so you would need another sort of collective communication call. And so if your feed forward computations are sort of big and beefy enough, you can kind of pay for the cost of basically doing this expert parallelism. And the one of the thing that's nice about this is that it's another form of parallelism in your in your toolkit. So you've got on the right side, you know, data parallelism, model parallelism of two or three different kinds.

**中文**: 好的，我不会深入讲解系统层面的内容，因为我尚未开始介绍那些核心系统概念——而这些概念恰恰是帮助你们深刻理解诸多类比关系和关键问题（例如数据中心内通信速度的层级结构等）所必需的。但正如我之前所说，有一点需要牢记：MOE（混合专家）模型非常契合各类设备。人们常说的“专家并行”即指将一个或少数几个专家部署到每个设备上。那么，在处理一个token时会发生什么？首先，该token会到达路由器；经路由器路由后，系统便选定若干专家。随后，系统将发起一次集合通信调用（如全对全通信分发），将token发送至对应的设备。接着，各专家执行前馈计算并输出结果，之后再将token送回其所属位置，或者（更可能地）对多个专家的输出进行融合。因此，这又需要另一次集合通信调用。只要前馈计算本身足够繁重、计算量足够大，就能在一定程度上抵消实施专家并行所带来的开销。这种并行方式的优点在于，它为你提供了另一种并行化手段。目前，你的并行化工具箱中已包含右侧所示的几种方式：数据并行、以及两到三种不同类型的模型并行。

## 段落 70

**英文**: And then you've got expert parallelism and you can combine all of them to come up with sort of ways of trading off all the resources you have. So the communication speed, the amount of data that you have, your batch size and your your number of experts and your memory. So I'm not going to go into too much detail about how specifically this is going to help. But keep in mind that this gives you another sort of tool in your expert toolkit. Another thing that is also useful is let's say you have multiple experts on a single device. You know, you might hope that because the computations are sparse, like let's say, you know, token one, this first token, you know, gets multiplied to export zero. The second one is expert one and the third one is expert two. So this is really three matrix multiplies that are small and sparse. And you might hope that modern GPUs can sort of take advantage of these kinds of complex these kinds of sparse matrix multiplications. And that's exactly right.

**中文**: 接着是专家并行（expert parallelism），你可以将所有这些技术结合起来，权衡利用你所拥有的各类资源，例如通信速度、数据量、批处理大小、专家数量以及内存。我不会深入讲解这一机制具体如何发挥作用，但请记住，这为你提供了专家工具箱中的又一有力工具。另一项同样实用的技术是：假设你在单个设备上部署多个专家。由于计算本身具有稀疏性，你或许会期望现代GPU能够高效处理这类稀疏矩阵乘法——例如，第一个token仅与专家0进行计算，第二个token仅与专家1计算，第三个token仅与专家2计算；因此实际执行的是三次规模较小且稀疏的矩阵乘法。事实的确如此。

## 段落 71

**英文**: So if you lay out your your sort of experts correctly and the weights are sort of fused in the right way, then modern sort of sparse matrix multiply sort of engines can sort of effectively make sure that you're not wasting any flops in doing this one big matrix multiply. So modern libraries like Mega Bloks can basically take advantage of this device level sort of sparsity support to do multiple expert computations sort of all at once. This is yet another advantage that you get with MOEs. So one fun side thing, which maybe isn't mysterious to you anymore because you've sort of grown up in the era of GPT-4. But when the GPT-4 API first came out, it was kind of mysterious to me because when you set the temperature to zero, you know, you kind of got different responses, even though it was supposed to be deterministic. And lots of people speculated about why would that be? I'm not saying this is the answer to that reason, but there is actually an interesting source of randomness in MOEs. Right. So in MOEs, think about what happens. You're going to route your tokens to experts. Right.

**中文**: 因此，如果你合理地部署各类专家模型，并以恰当的方式融合权重，那么现代的稀疏矩阵乘法引擎便能有效确保在执行这一大规模矩阵乘法时不会浪费任何浮点运算（FLOPs）。像Mega Blocks这样的现代库，基本可以利用设备层面的稀疏性支持，同时完成多个专家模型的计算。这正是混合专家模型（MOE）所具备的又一优势。顺便提一件有趣的小事——对你而言可能已不再神秘，毕竟你成长于GPT-4时代；但当GPT-4 API首次发布时，对我而言却颇为费解：当你将温度（temperature）设为零时，理论上应得到确定性输出，结果却仍会给出不同响应。当时许多人纷纷猜测原因何在。我并非断言这便是该现象的确切解释，但混合专家模型中确实存在一种有趣的随机性来源。没错，在混合专家模型中，请思考一下令牌（token）的路由过程：你需将输入令牌分发至不同的专家模型。

## 段落 72

**英文**: And experts live in different devices. It could be that you have a lot of examples. You're going to, of course, batch your queries when you're processing them. And so if you've batched your queries, these tokens are going to get routed into different experts. So imagine you've got this batch to process and you've got a bunch of experts. But for whatever reason, this batch really loves expert number three. Like all the tokens go to expert number three. So now what happens? Well, the device for expert number three doesn't have enough memory to load all of those tokens. And then what happens is what people call token dropping. And this happens at training time as well.

**中文**: 而专家模型分布在不同的设备上。你可能拥有大量样本，在处理时自然会将查询进行批处理。因此，当你对查询进行批处理后，这些词元就会被路由到不同的专家模型中。试想一下，你有一批待处理的数据，同时拥有一组专家模型。但由于某种原因，这批数据特别“偏爱”编号为三的专家模型——所有词元都路由到了该专家模型。此时会发生什么？编号为三的专家模型所在设备的内存不足以加载全部这些词元，于是便会出现人们所称的“词元丢弃”现象。这种现象在训练阶段同样会发生。

## 段落 73

**英文**: You often have what's called a load factor where you're sort of controlling the maximum number of allowed tokens. And if the router just allocates too many tokens to an expert, you just drop those tokens off either for systems reasons or because you're just worried that that expert is going to take over, at least in the training time. So now this token has gone dropped and it's not going to get anything at all. Like the MLP is just going to do a zero computation and the residual connection is just going to pass things straightforward. And then you're going to return an output. And so if your token got dropped, you're going to get a different result than if your token didn't get dropped. And so based on who else is in your batch, MOEs can induce stochasticity both at training time and inference time, which is kind of an interesting thing that you don't normally think about because you almost never think about cross batch effects when doing inference. OK. So that's kind of the main bits of the main basic components of building the MOE and a fun side thing. If you were to actually go out tomorrow and try to train an MOE, I think the system side will make you a little bit sad.

**中文**: 你通常会采用所谓的“负载因子”（load factor），以此控制允许的最大令牌数量。如果路由器向某个专家分配了过多的令牌，你就会出于系统原因，或单纯担心该专家在训练过程中“一家独大”，而直接丢弃这些多余的令牌。此时，该令牌即被丢弃，完全不会参与后续任何计算：MLP 层将执行零计算，残差连接则直接原样传递输入。最终，模型仍会返回一个输出。因此，若你的令牌被丢弃，所得结果将与未被丢弃时截然不同。换言之，依据同一批次中其他令牌的情况，混合专家（MoE）模型在训练和推理阶段均会引入随机性——这其实是一个颇为有趣却常被忽视的现象，因为人们在进行推理时几乎从不考虑批次间的相互影响。好的，以上便是构建 MoE 模型的主要基础组件及其一个有趣的附加特性。顺便提一句：倘若你明天就着手尝试训练一个 MoE 模型，系统层面的挑战恐怕会让你略感沮丧。

## 段落 74

**英文**: But the other thing that would make you sad is probably the stability side of things. So MOEs kind of have this property that sometimes they'll just kind of blow up on you if you try to fine tune them. They're very difficult to fine tune and they'll sometimes blow up on you. And so, you know, Barrett, Zoth and others really studied, they had a whole paper on basically trying to make MOEs more stable. And there's a paper, which is the one I'm referencing here, whose entire purpose is to stabilize MOE training. There's a couple of tricks that I'll mention that I think are relevant and that people do. The first one is, you know, if you're doing the router softmax. So this goes back to last lecture about stability. Right. Like, what did I say about stability? Well, the thing to be afraid of is the softmax.

**中文**: 但另一件可能让你感到困扰的事情，或许是模型的稳定性问题。混合专家（MOE）模型往往具有这样一种特性：当你尝试对其进行微调时，有时会突然出现数值爆炸。这类模型极难微调，且确实容易发生数值爆炸。因此，巴雷特（Barrett）、佐斯（Zoth）等研究者深入开展了相关研究，并专门发表了一篇论文，旨在提升MOE模型的稳定性。我此处所引用的正是这样一篇论文，其核心目标就是稳定MOE模型的训练过程。接下来我将介绍几种被广泛采用、且我认为较为关键的技巧。第一种技巧涉及路由层（router）中的softmax计算——这又回到了上一讲所讨论的稳定性问题。那么，关于稳定性，我之前强调过什么？实际上，最需警惕的正是softmax运算本身。

## 段落 75

**英文**: The softmax is always where you want to be afraid. And so for the MOEs, they do all the computations in float 32 for the router computations just to be safe. And sometimes they also add the, you know, an auxiliary Z loss. So hopefully you remember that it was just last lecture. You know, you do log of the sum of the the exponentiated values in the softmax and you square that and you add that as an extra loss. So this is going to keep the normalizer values near one, which is nice for stability. So this is actually one of the places where Z loss was used earlier before it got sort of more popular for training models. You can kind of see the effects here. If you look at the losses, I think the center, the second plot here is maybe a great one. You know, if you remove the Z loss from your router routing function, you see these like giant loss spikes in your validation loss where, you know, the model just kind of goes a little bit crazy for a couple iterations and then gets kind of pulled back.

**中文**: Softmax始终是你需要警惕的地方。因此，在混合专家模型（MOEs）中，为确保安全，路由计算全部采用float32精度执行。有时还会加入所谓的辅助Z损失——希望你还能记得，这正是上一讲所讲的内容：即对softmax输出中各项指数值之和取对数，再将该对数值平方，并作为额外损失项加入。此举可使归一化因子的值保持在1附近，从而提升训练稳定性。事实上，Z损失最初正是在这一场景（即路由计算）中被采用，之后才逐渐在更广泛的模型训练中流行起来。你可以从图中直观地看到其效果：观察损失曲线时，中间那幅图（即第二张图）尤为典型——若在路由函数中移除Z损失，验证损失曲线上便会频繁出现剧烈的尖峰，表明模型在若干轮迭代中短暂失控，随后才被逐步拉回正常轨道。

## 段落 76

**英文**: Of course, they like still trains OK. But you are better off having the Z loss than not having a Z loss. There is a pretty noticeable gap in the validation loss by the end here. Other things that can happen. People, you know, of course, you want to fine tune your MOE. You'd like also RLHF your MOE if you're going to ship and release it. But this turns out to be kind of problematic. Some of the earlier work, you know, when people were starting to do MOEs, this was back in kind of the BERT and T5 era. So there was a lot of fine tuning going on. And, you know, one of the things that people saw was, you know, actually there's a lot of overfitting that happens if you were kind of doing sparse models.

**中文**: 当然，他们仍然喜欢使用标准的训练方式。但相比不引入Z损失，引入Z损失的效果更好。此处验证损失在最终阶段存在相当明显的差距。其他可能发生的情况包括：人们自然希望对混合专家（MOE）模型进行微调；若计划将MOE模型投入实际部署和发布，通常也希望对其进行基于人类反馈的强化学习（RLHF）优化。然而，这一做法实际上存在一定问题。早期的一些研究——即人们刚开始探索MOE模型时——大致处于BERT和T5时代，当时开展了大量微调工作。人们观察到的一个现象是：若采用稀疏模型结构，往往会出现严重的过拟合问题。

## 段落 77

**英文**: You see this big gap between train and valve, right? This blue and orange line, whereas the dense model, this green and red line, has a smaller train test gap. And so there was a lot of worries about overfitting because you have these like gigantic parameter models that you're fine tuning on small data. One of the solutions that was proposed at the time. I don't think this is very popular as far as I understand is to architect your MOEs such that not every layer is an MOE layer, but you like, let's say, alternate dense layers and MOE layers. Then you can just fine tune the dense layers and then that will still be fine. That behaves just like a dense model. So that was fine. Another solution, the one that we saw in the DeepSeq MOE paper, is just kind of use a lot of data. Like if overfitting is a problem, you know, we have access to lots and lots of SFT data, just shovel all of those guys in. So in the case of DeepSeq MOE, they use 1.

**中文**: 您看到了训练集和验证集之间这个巨大的差距，对吧？即这条蓝色和橙色的线；而密集模型（绿色和红色的线）的训练集与测试集差距则更小。因此，当时人们非常担心过拟合问题，因为这些参数量极其庞大的模型仅在少量数据上进行微调。当时提出的一种解决方案（据我所知，目前并未广泛流行）是设计混合专家（MoE）模型的架构，使其并非每一层都是MoE层，而是采用密集层与MoE层交替的方式。这样，只需微调密集层即可，效果依然良好，其行为与纯密集模型无异，因此这一方案是可行的。另一种解决方案见于DeepSeq MoE论文：即直接使用大量数据。如果过拟合是个问题，而我们又拥有海量监督微调（SFT）数据，那就尽可能多地使用这些数据。例如，在DeepSeq MoE中，他们使用了1……

## 段落 78

**英文**: 4 million training examples. Then maybe you're not quite as worried about these overfitting concerns. The last thing I'll end with, which is a trick in the toolkit that people have done and seen, is upcycling. And so this idea is to take a dense model like the one over here, and then you take your MLP and you make a bunch of copies of it, and then you maybe perturb it. And then you have your router that's initialized from scratch. And then you just pretend this is an MOE and then you train it from that point on. You just initialize the MOE from a dense model. And this is a trick that's kind of called upcycling. And people have shown that if you can get it to work, it is a very, very, very cost-effective way of getting an MOE. And the MOE is great for inference because not every MLP is going to be active at inference time.

**中文**: 400万个训练样本。此时，你可能就不太担心过拟合问题了。最后我要介绍的是工具箱中一种已被人们实践并验证有效的技巧——“升级循环”（upcycling）。其基本思路是：先取一个稠密模型（如图中所示），再取其中的多层感知机（MLP），复制多份，并对其进行微小扰动；接着，从零开始初始化路由模块（router）；然后，直接将该结构视作混合专家模型（MOE）并从此处开始训练——即直接以稠密模型为起点初始化MOE。这种技巧被称为“升级循环”，研究表明，若能成功实现，它是一种极具成本效益的MOE构建方式。而MOE在推理阶段表现优异，因为并非所有MLP在推理时都会被激活。

## 段落 79

**英文**: So you might effectively get a much larger parameter model without doing the training of a much larger parameter model. And several people have succeeded at this. MiniCPM, which I'll mention again in the scaling law lecture, but this is a Chinese open LLM that basically tried to build really good small language models. And they succeeded at taking a dense model and upcycling it into an MOE. And you can see that their numbers get significantly better in the last two rows. So the dense model to the MOE, they get a pretty non-trivial bump in performance. Quen, I mentioned at the start of this lecture, one of their earliest attempts at MOE was taking one of their dense models and then building upcycled MOE. And they got fairly significant performance gains relative to sort of smaller models at the time. Like they got models on par with their 7b models with a 2. 7 billion parameter active model.

**中文**: 因此，你实际上可能获得一个参数量大得多的模型，而无需训练一个参数量大得多的模型。已有不少人成功实现了这一点。MiniCPM（我将在缩放定律讲座中再次提及）是一款由中国开发的开源大语言模型，其目标是构建性能卓越的小型语言模型。他们成功地将一个稠密模型升级重构为混合专家（MoE）模型，从最后两行数据可见，其性能显著提升。也就是说，从稠密模型升级为MoE模型后，性能获得了相当可观的提升。Quen（我在本讲开头已提及）在其早期MoE尝试中，也曾将自身某款稠密模型升级重构为MoE模型，并相较于当时规模更小的模型取得了相当显著的性能提升；例如，其激活参数量仅为27亿的MoE模型，性能即可媲美自身的70亿参数稠密模型。

## 段落 80

**英文**: So to wrap up, I want to sort of walk through the DeepSeq MOE architecture at the very end here. And hopefully this will give you a sense of, you know, the first thing I want to do is I want you to understand the DeepSeq V3 architecture setup and all the changes that they did. Because that's an example of a modern high performance open source system. I also want you to maybe appreciate that architectures don't change that much. DeepSeq MOE V1 is not that new. It's like maybe a year and a half or something, maybe two years old. And they basically nailed the architecture at that point. So I want you to see what they changed from the earliest attempt to their big training run. So this is the very first starting point. This is DeepSeq MOE.

**中文**: 最后，我想简要概述一下DeepSeq MOE的架构。希望这能让您有所了解：首先，我要让您理解DeepSeq V3的架构设计及其所有改进之处，因为这是一个现代高性能开源系统的典型范例。同时，我也希望您能意识到，架构本身其实变化不大——DeepSeq MOE V1问世并不久远，大约一年半甚至两年左右；而他们在当时便已基本确立了这一架构。因此，我想让您看清他们从最初尝试到大规模训练阶段之间所作的调整。以下便是最初的起点，即DeepSeq MOE。

## 段落 81

**英文**: I'm calling it V1, but actually probably the right way to refer to it is DeepSeq MOE. It's a 16 billion parameter model with 2. 8 of those parameters active. And you've seen already this diagram over here. This is the two shared plus 64 fine grained experts, of which four of them are active at a time. Or maybe six of them are active at a time, sorry. And the routing, you know, you've already seen this. I presented this in the middle of the lecture here. This is the very standard top K routing where the soft max is at the bottom before the top case selection. And for balancing, at training time, all they do is to add this auxiliary loss balancing term, right, both the expert and device level balancing terms.

**中文**: 我将其命名为V1，但其实更准确的叫法应是DeepSeq MOE。这是一个参数量达160亿的模型，其中每次激活的参数为28亿。您此前已见过此处这张示意图：该架构包含两个共享层及64个细粒度专家模块，每次激活其中4个（或更正为6个）专家。至于路由机制，您此前也已了解——我在本次讲座中部已对此作过介绍。这是一种非常标准的Top-K路由机制，其Softmax运算位于底部，在执行Top-K选择之前完成。在训练阶段，为实现负载均衡，他们仅添加了这一辅助均衡损失项，即同时包含专家级与设备级的均衡项。

## 段落 82

**英文**: So hopefully you remember those from earlier. So that's the V1. And then they saw how sort of effective their MOE model was. So I guess to add some more context, right,. DeepSeq originally had a dense model and then they had an MOE model and the MOE model was remarkably good. And so when they went to V2, they went straight to the MOE. And now this is a 236 billion parameter model of which 21 of those billion parameters are active. Right. So you need a lot of memory, but your your flops consumption for inferencing this model is not so bad. Now, the architecture is identical.

**中文**: 因此，希望您还记得之前提到的那些内容。这就是V1版本。随后，他们发现自己的混合专家（MOE）模型效果相当出色。为补充一些背景信息：DeepSeq最初采用的是稠密模型，之后推出了MOE模型，而该MOE模型表现极为优异。因此，在升级至V2时，他们直接采用了MOE架构。目前这一模型参数量达2360亿，其中每次激活的参数为210亿。这意味着需要大量内存，但推理时的浮点运算量（FLOPs）消耗却并不高。此外，其架构与之前完全相同。

## 段落 83

**英文**: I copied literally the same figure because the architecture is literally the same. Minus changes to the number of experts that are active. And we've got now sort of some new things happening, but not too many new things. So the top case selector is the same. So the equation from before, this previous equation, this is identical. This is still how they do things. But they have this very clever trick that they add on. And this is, you know, I was going to say at the very beginning, you know, what's the drawback of having fine grained experts? Why can't I have, I don't know, 1024 fine grained experts or 2046 fine grained experts? Well, the problem is when you shard your experts very finely and you have a lot of active experts, right, you're going to have to route to those experts. So your communication costs potentially grow. And if you're very fragmented, you might have to send a lot of tokens to a lot of devices.

**中文**: 我完全照搬了同一张图，因为架构本身完全相同，仅在活跃专家数量上有所调整。目前我们确实出现了一些新变化，但新内容并不多。因此，顶部的案例选择器保持不变，之前提到的公式也完全一致，他们目前仍采用这种方式。但他们在此基础上增加了一个非常巧妙的技巧。正如我在最开始所提到的，细粒度专家存在什么缺点？为什么我不能设置1024个或2046个细粒度专家呢？问题在于：当你将专家划分得过于精细，且同时激活大量专家时，就必须将数据路由至这些专家，这可能导致通信开销显著增加；而若专家分布过于分散，你可能需要将大量令牌发送至众多设备。

## 段落 84

**英文**: And so the clever thing they come up with is to say, I'm not just going to, you know, for each batch route to the top K experts naively, which might force me to send my tokens to lots of devices. What I'm going to do is I'm going to first pick top and devices. Right. So I'm going to do my normal scoring calculation, but I'm first going to sort of subset the set of allowed devices to top. And once I've picked my devices, then I'm going to pick top K for each token within each device. Right. So now I've restricted the devices. This really controls the communication costs. And now this gives you more efficient training when you're scaling up to these gigantic sizes. Right.

**中文**: 因此，他们想出的巧妙方法是：我不会简单地对每个批次中的每个token都直接路由到得分最高的K个专家，因为这可能导致我的token被发送到大量设备上。相反，我首先会选出得分最高的若干设备。也就是说，我会先进行常规的打分计算，但会先将允许使用的设备集合缩减为得分最高的若干设备；在选定这些设备后，再在每个设备内部为每个token选出得分最高的K个专家。这样一来，我就限制了设备的数量，从而有效控制了通信开销。当模型规模扩大到极大时，这种方法能显著提升训练效率。

## 段落 85

**英文**: You need to start really engaging with the systems aspect of things when you're training a 236 billion parameter model. The other thing which reflects the systems concerns that are necessary at this scale is that they add a communication balancing loss. One way of thinking about things is, you know, for an expert, there's kind of inputs and outputs, right? The inputs are, you know, the token comes in and you route your expert and the outputs are, you know, you have to kind of bring the tokens back where they belong. Right. So if a batch belongs on this device, it has to go back where the original device was. So we have to think about both the input communication cost and the output communication cost. And so they add a balancing loss to try to balance out the output communication cost as well, not just the sort of input side. So that's a minor note, but you can kind of see their attention to detail on trying to make sure all the different sort of systems aspects are properly taken care of. And then finally, we kind of get to the, you know, the big DeepSeq V3. Sorry, that's just a V3, not V2 up there.

**中文**: 当你训练一个拥有2360亿参数的模型时，就必须真正开始深入关注系统层面的问题。另一点同样反映出在此规模下所必需的系统性考量，是他们引入了一种通信均衡损失（communication balancing loss）。一种理解方式是：对于某个专家模块而言，存在输入和输出两个环节，对吧？输入是指令牌（token）进入后被路由至相应专家模块；而输出则是指需将处理后的令牌送回其原本所属的位置。例如，若某批次数据本应位于该设备上，则处理完毕后必须返回至原始设备。因此，我们必须同时考虑输入端的通信开销与输出端的通信开销。为此，他们额外引入了均衡损失，旨在平衡输出端的通信开销，而不仅限于输入端。这虽是一个细微之处，却体现出他们在确保各项系统层面细节均得到妥善处理方面的严谨态度。最后，我们便来到了所谓的“DeepSeq V3”——抱歉，此处仅为V3，并非上文提到的V2。

## 段落 86

**英文**: 671 billion parameters of which 37 are active. You know, once again, you know, exactly the same figure because the MOE architecture itself doesn't change. That stayed the same since DeepSeq MOE, right? Like if it works, don't change it. They do change a couple of things. Maybe they were, you know, hearing you all say, why don't you normalize to one?. And so, you know, they've normalized the gate to one. They've moved kind of the softmax normalizer operation up there. But they're not actually exponentiating sort of the sort of gating decisions. They're actually taking sigmoids, which is a sort of softer, sort of more nicely behaved operation, you know, than the softmax. And so they've got some changes here.

**中文**: 6710亿个参数，其中37个处于激活状态。您知道，再次强调，这个数字完全相同，因为混合专家（MOE）架构本身并未改变——自DeepSeq MOE以来就一直保持不变，对吧？正所谓“行之有效，无需更改”。不过，他们确实做了几处调整：或许他们听到了大家的反馈：“为何不将门控值归一化为1？”因此，他们将门控值归一化为1，并将原本位于下游的Softmax归一化操作上移至该处；但实际并未对门控决策进行指数运算，而是改用Sigmoid函数——这是一种更柔和、行为更稳定、表现更优的运算方式，相较于Softmax而言。因此，此处确实存在若干改动。

## 段落 87

**英文**: But conceptually, this is still the same as the top K routing decision, right? You hopefully see very, very similar things happening. And then in terms of the losses, they've gone to this auxiliary loss free trick of this B of I being incremented or decremented based on the expert load. And then they have a sequence wise auxiliary loss. And just to, you know, add some context, why would you want to balance different experts on a single sequence? Well, the thing that they're very concerned about is at training time, you know, it's fine to not have a sequence wise balancing loss. But at inference time, it might be the case that someone sends you very out of distribution sequences and that might overwhelm certain experts, right? So inference time, you can't control which sequences you get. So you might want sort of stronger balancing that operates at a single sequence level rather than an overall batch level. Okay. And then in the. Sorry. Yes.

**中文**: 但从概念上讲，这仍然等同于Top-K路由决策，对吧？你大概会观察到非常相似的现象。在损失函数方面，他们采用了这种无需辅助损失的技巧：根据专家负载情况对B(I)进行递增或递减调整；此外，他们还引入了一种按序列计算的辅助损失。顺便补充一点背景：为何要在单个序列层面平衡不同专家呢？他们特别关注的问题在于：训练阶段不采用序列级的平衡损失并无大碍；但在推理阶段，用户可能输入分布外的序列，从而导致某些专家过载，对吧？因此，在推理阶段，你无法控制所接收的序列类型，故而可能需要一种更强的、作用于单个序列层面（而非整个批次层面）的负载均衡机制。好的。接下来……抱歉，是的。

## 段落 88

**英文**: Does B3 still do like the top end devices? Does it keep the B2 improvement? Yeah, they keep the top end improvement. They do not keep, for example, the communication loss. So they've jettisoned some things, but top end is a I mean, it seems like a pretty clever idea. They keep it. Yeah. Yeah, but it's not like they always add things. They have removed some of the things. And so in the last two or so minutes of the class, I'm going to go over the non MOE parts of DeepSeq V3 because I think, you know, we're already at the point where I've explained most of DeepSeq V3. I might as well go through the steps of explaining the rest of DeepSeq V3 at this point. So you all know kind of how that works.

**中文**: B3是否仍保留高端设备的特性？它是否延续了B2的改进？是的，它保留了高端设备的改进。但它并未保留例如通信损耗方面的改进。因此，他们舍弃了一些功能，但高端特性——我的意思是，这似乎是个相当巧妙的设计思路——他们予以保留。是的。是的，但这并不意味着他们总是增加新功能；相反，他们也移除了一些原有功能。因此，在本节课最后大约两分钟的时间里，我将介绍DeepSeq V3中非MOE（混合专家）的部分，因为我认为，目前我们已基本讲解完DeepSeq V3的主体内容，不妨趁此机会一并梳理其余部分的细节。这样大家就能大致了解其工作原理了。

## 段落 89

**英文**: So they have a clever sort of optimization for the attention piece called MLA or multi head latent attention. And you actually already know all the ingredients that you need to understand this because at the end of last lecture, you know, I talked about like GQA and MHA. Right. So those are all inference optimizations that you need in order to optimize the size of the KV cache. So the DeepSeq folks take a different pack or different approach at optimizing this instead of reducing the number of heads. They're actually going to sort of project the heads into a lower dimensional space. So you have your inputs H of T and instead of sort of generating the K's and V's directly from these H of T's, what I'm going to do is I'm going to first generate a low dimensional C. You can think of this as like a compressed version of H and the C is going to be smaller and easier to cache. And I'm just going to cache these C's. And whenever I need, you know, these K's and V's, well, I can sort of up project from this KV, sort of conceptually speaking.

**中文**: 因此，他们为注意力机制设计了一种巧妙的优化方法，称为MLA（多头潜在注意力）。实际上，你已经掌握了理解该方法所需的全部要素，因为在上一讲的末尾，我曾讲解过GQA（分组查询注意力）和MHA（多头注意力），这些均为用于优化KV缓存大小的推理优化技术。而DeepSeq团队则采取了另一种不同的优化思路：他们并未减少注意力头的数量，而是将各注意力头投影到一个更低维的空间中。具体而言，对于输入H(T)，我们并不直接从H(T)生成K和V，而是首先生成一个低维表示C——你可以将其视作H的压缩版本；该C维度更小、更易于缓存，因此我们仅缓存这些C。当后续需要K和V时，我们只需从C中进行上采样投影（概念上而言）。

## 段落 90

**英文**: And then, you know, I can take the inner products with the Q's. Right. So you can kind of see how this would be a KV cache savings if I only have to save the C instead of the higher dimensional H of T. And that's exactly the idea. So you take your H of T, you project it into a lower dimensional C and then you up project this back into the K's and V's. Right. And if the C's are small, well, that's you've compressed the KV cache. That's good. And then, you know, in terms of the computation, right, if you're thinking about flops, well, you might think, well, this is not good because I have to multiply an extra matrix WUK. Right.

**中文**: 然后，如你所知，我可以对Q向量进行内积运算。没错。因此，你可以大致看出，如果只需保存低维的C而非高维的H×T，就能节省KV缓存空间。这正是该方法的核心思想：先将H×T投影到低维空间C，再将C上采样（升维）回K和V。没错。而如果C的维度较小，就相当于压缩了KV缓存，这是有益的。此外，从计算量（FLOPs）角度看，你可能会想：这似乎并不理想，因为我还需要额外乘以一个矩阵WUK。

## 段落 91

**英文**: I didn't have this matrix before. That's an extra matrix multiply that I have to pay for. But kind of the clever thing here is remember that on the other side of K, I'm going to take K dot Q. Right. That Q dot K is going to be an inner product in the attention operation. Right. And Q itself has a projection matrix Q. And so the trick here is you can merge this WUK and this Q matrix together into one matrix. I haven't gotten any extra matrix multiplies. I've just merged this new matrix multiply into my other one.

**中文**: 我之前并没有这个矩阵，因此需要额外进行一次矩阵乘法运算，而这会带来计算开销。但此处的巧妙之处在于：请记住，在K的另一侧，我将执行K与Q的点积运算，而Q与K的点积正是注意力机制中的内积运算。此外，Q本身还经过一个投影矩阵Q的变换。因此，这里的技巧是将WUK矩阵与Q矩阵合并为一个矩阵。这样我就没有增加任何额外的矩阵乘法运算，只是将这次新增的矩阵乘法融入了原有的矩阵乘法之中。

## 段落 92

**英文**: Right. This is, you know, just associativity. I can just merge the two. They also compress the queries for memory savings during training. But really, that one is not quite as necessary because it doesn't interact at all with the KV cache. I'm only going to mention this last one in passing because it is a subtlety, but it's kind of a clever subtlety that you realize, which is that this original trick, this sort of thing that I just described at the top, is not compatible with Rope. Right. And the reason is because, you know, the Rope matrices, you know, basically you have the Qs into the Ks and you rotate each of those Qs and the Ks by multiplying with a rotation matrix RQ and RK. But if you do that, then these RQs and RKs are in between the query projection and this latent vector up projection matrix. And since I can't reorder these matrix multiplies, you know, Rope kind of gets in the way.

**中文**: 没错，这其实就是结合律的问题，我可以直接将两者合并。它们还会压缩查询向量，以节省训练过程中的内存。但事实上，这一项并非十分必要，因为它完全不涉及KV缓存。我仅在此简要提及最后一项，因为它虽是一个细微之处，却颇为巧妙：你可能会意识到，前面所描述的原始技巧与RoPE并不兼容。原因在于，RoPE变换中，Q和K需分别乘以旋转矩阵RQ和RK；而这些旋转矩阵恰好位于查询投影层与隐状态上投影矩阵之间。由于矩阵乘法不可随意重排，RoPE便因此构成了障碍。

## 段落 93

**英文**: And they still have a solution of basically doing Rope on non-compressed dimensions. That's kind of a side point. I think it's not quite as important. You can kind of look at the paper if you're super interested. The other thing that they do, and this is the last thing I promise, is that they have a minor change in their loss function called MTP, where they predict multiple tokens in parallel. And so what they can do is normally, right, you have your inputs, you shift them to the left by one. So you're predicting one token in the future, and then your transformer is going to predict all those tokens. That's your normal transformer loss. But then what you can do is right before you make those predictions, you can take the hidden state, you can pass it to a very lightweight one layer transformer, and that model can predict one token in the future. So now the model is not just predicting the next token, it's predicting the two tokens into the future.

**中文**: 他们仍采用一种基本方案，即在非压缩维度上应用RoPE（旋转位置编码），这属于一个次要问题，重要性相对较低。如果你特别感兴趣，可以查阅相关论文。另一项改进——这也是我最后要介绍的内容——是他们在损失函数中引入了一项微小调整，称为MTP（多令牌预测），即并行预测多个令牌。通常情况下，输入序列会整体左移一位，从而让模型预测下一个令牌，这是标准Transformer的损失计算方式。而采用MTP后，在进行最终预测前，可先提取隐藏状态，并将其送入一个极轻量的单层Transformer，由该模型额外预测下一个令牌。这样一来，模型便不再仅预测下一个令牌，而是同时预测未来两个令牌。

## 段落 94

**英文**: So that hopefully all makes sense. And this is just a small lightweight model that can do that. You can sort of see the architecture right here. The one thing that is kind of disappointing that I learned as I was sort of researching for this lecture is actually they only do MTP with one token ahead. So even though they have this very complicated diagram of how they could do it for many tokens, turns out it's only done for one token. Okay, so now I'm all done. MOEs are kind of now at the core of how you would build and deploy a really high performance large scale system. And they take advantage of kind of the sparsity idea that you don't need all of the parameters all the time. And discrete routing is the real big challenge. And this is, I think, one of the big reasons why MOEs didn't immediately catch on.

**中文**: 因此，希望以上内容都讲清楚了。而这是一个轻量级的小型模型，能够实现上述功能。您大致可以在这里看到其架构。我在为本次讲座做调研时，发现了一件略令人失望的事情：他们实际上仅支持一次预测一个词元的多任务预测（MTP）。尽管其示意图非常复杂，展示了如何对多个词元进行预测，但实际仅支持单个词元。好了，我的讲解到此结束。目前，混合专家模型（MOE）已成为构建与部署高性能、大规模系统的核心技术。它充分利用了“稀疏性”这一理念，即并非始终需要全部参数。而离散路由则是其中真正重大的挑战，我认为这正是MOE未能迅速普及的关键原因之一。

## 段落 95

**英文**: It's very scary to have to try to optimize this top-K routing decisions. But heuristics somehow seem to work, right? Like they just do. And so there's a lot of empirical evidence now that MOEs, at least for flop-constrained settings, is just a good idea. It's cost-effective. You should do it. So definitely worth learning. Thanks a lot for listening.

**中文**: 必须设法优化这种Top-K路由决策，这确实非常令人担忧。但启发式方法似乎在某种程度上行之有效，对吧？它们就是管用。因此，目前已有大量实证证据表明，对于计算量受限的场景，混合专家模型（MoE）确实是一种好方案——它具有成本效益，值得采用。因此，学习它绝对值得。非常感谢您的聆听！

---

*共 95 个段落，947 句话*
