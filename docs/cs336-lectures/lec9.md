# Lecture 9： Scaling laws 1

生成时间: 2026-03-23 23:39:01

---

## 段落 1

**英文**: I'm going to talk a little bit about scaling laws. Originally, I think we were going to talk about inference. But I'll take a few minutes to start on scaling laws, and then we'll figure out where we'll go from there. OK, so the whole point of scaling laws is kind of, well, to begin with, I want you to put yourself into the following scenario. So you have a very rich friend, and she or she. has given you 10,000, actually, let's say 100,000, H100s for a month. And you have to build the best open source LM that you can. So this is a somewhat hard task. And we've given you some of the tools that you need to make progress on this question. So you can put together your infroteam and your systems people, and you can put together a distributed training.

**中文**: 我打算稍微谈谈扩展定律。原本我以为我们要讨论推理部分，但我会花几分钟先讲讲扩展定律，然后再决定接下来的方向。好的，扩展定律的核心在于，首先，我希望大家设想这样一个场景：你有一位非常富有的朋友，她（或他）给了你10万张H100显卡，使用期限是一个月。你的任务是尽可能打造出最好的开源语言模型。这确实是个相当艰巨的挑战。不过，我们已经为你们提供了一些解决这个问题所需的工具。你们可以组建自己的基础设施团队和系统人员，并搭建分布式训练环境。

## 段落 2

**英文**: framework. In the next assignment after that, you're going to put together a great pre-training data set. And then you kind of know all about architectures and so on. So you kind of know you have all the pieces. And so we can turn the crank and we can run the big model. And then the first couple lectures,. we talked about all the other various decisions you might make along this journey. Like, what's the architecture? What's the hyper parameters? How are you going to do all these things? Well, I think in some ways the answer I gave you from those early lectures was, just pick what other people have done. Just follow Lama or whatever other models. But in a way, that's a very boring answer, because that doesn't let you push the frontiers.

**中文**: 框架。在那之后的下一个任务中，你将整合出一个优秀的预训练数据集。接着，你大致了解了所有关于架构等方面的知识。这样一来，你基本上掌握了所有要素。因此，我们可以启动进程，运行这个大模型。而在最初的几节课中，我们讨论了在这一过程中你可能需要做出的其他各种决策。比如，采用什么架构？超参数如何设置？你将如何完成所有这些事情？嗯，我认为从某种程度上说，我在早期课程中给出的答案是：直接借鉴他人已有的做法。只需跟随Llama或其他模型的脚步即可。但在某种意义上，这是一个非常乏味的答案，因为它无法让你推动前沿发展。

## 段落 3

**英文**: If you're in a big frontier lab and you're going to build the best model, you don't want to just copy other people you want to innovate. So how do we innovate and get these optimized solutions in the first place?. So that's going to be the point of scaling loss. What we want to do is we want to build simple predictive laws for the behavior of language models. And scaling laws are basically this whole idea of being able to take small models, scale them up, and be able to do that in order to improve your engineering. So one way of thinking about this is the old and pleasant way of doing deep learning is just train a bunch of big models,. tune your hyper parameters so that your big models are good. That's just going to cost tons and tons of compute. You can't really easily do that. And so I think the new optimism, and if you're sort of following a lot of these developments on scaling, you kind of think of this as, all right, we're going to train a bunch of small models.

**中文**: 若你身处前沿大型实验室，想要打造顶尖模型，便不会止步于模仿他人，而会追求创新。那么，我们究竟该如何实现创新并率先获得这些优化方案呢？这正是规模律的意义所在。我们的目标是建立简单的预测法则，以解释语言模型的行为规律。规模律的核心思想在于：通过从小模型起步，逐步扩大规模，以此提升工程效能。一种传统的深度学习思路是直接训练多个大型模型，并通过调整超参数使其达到理想状态——但这将消耗海量计算资源，实际操作难度极大。因此，我认为新的乐观方向在于：如果我们关注规模扩展的相关进展，便会意识到更可行的路径是——先训练一批小型模型。

## 段落 4

**英文**: We're going to learn a lot of things from those small models,. and then we're going to extrapolate them back up to bigger models. So we're going to take our smallest models at the left side of this sort of compute scale here. And I'm going to learn a lot about what to do. And then I'm going to nail it in one go when I build my big model. And the first place I want to start with is just kind of the history and the background of scaling loss. And I want to contextualize this because I think when people talk about scaling loss, often this is done in very like mesonetic, like, AGI terms. So scaling loss just tell you that these amazing things are log linear forever, and we will achieve super intelligence or something. But I think scaling loss are actually much more grounded. and have a lot of interesting history.

**中文**: 我们将从这些小型模型中学到很多东西，然后将其推演回更大的模型。因此，我们将从计算规模最左侧的最小模型开始着手。我会深入了解该怎么做，然后在构建大型模型时一举成功。我想首先从缩放定律的历史和背景讲起。之所以要谈这个背景，是因为我觉得人们在讨论缩放定律时，常常会用到一些非常宏大、类似AGI的术语。比如缩放定律似乎只告诉我们这些神奇的现象会永远呈对数线性增长，我们将实现超级智能等等。但我认为缩放定律实际上要务实得多，并且有着非常有趣的历史渊源。

## 段落 5

**英文**: And so I'm going to start there to sort of try to convince you that scaling laws aren't necessarily just fitting lines on log log plots, although that is a very big part of what we're going to do. And then I'm going to do basically very easy steps. I'm going to try to convince you that at least for data, scaling laws are a very natural thing to think about and to expect. So as a person that's kind of brought up in statistical machine learning, my starting point is going to be statistical machine learning. What is scaling loss? In some way, scaling laws are telling us as we increase the amount of data or we change the model size, we expect certain behaviors out of the model. And if you go back to something like machine learning 101,. and if you remember your VC dimensions and rotomaker complexities and so on, in some ways that's the theory version of exactly this. So I have on the top a generalization bound for the generalization bound for the excess risk of learning amongst a finite set of k hypotheses. And we see that that should scale as 1 over square of m. In some ways, that's a theoretical version of a scaling.

**中文**: 因此，我将从这里开始，试图说服你们，缩放定律并不一定只是在双对数图上拟合直线，尽管这确实是我们将要探讨的重要内容。接下来，我将采取非常简单的步骤。我会尝试让你们相信，至少对于数据而言，缩放定律是一个非常自然且值得思考和期待的概念。作为一个在统计机器学习领域成长起来的人，我的出发点将是统计机器学习。缩放损失是什么？从某种意义上说，缩放定律告诉我们，随着数据量的增加或模型规模的改变，我们期望模型表现出特定的行为。如果你回顾一下机器学习的基础知识，比如VC维和Rademacher复杂度等，从某种角度来看，这正是这一概念的理论版本。我在顶部展示了一个关于在有限k个假设中学习超额风险的泛化界，我们看到它应该以1除以m的平方根的速度缩放。从某种意义上说，这就是缩放定律的理论版本。

## 段落 6

**英文**: law where we're making predictions about how fast our error should decay as a function of m. On the bottom, we might have something a little bit more exotic. If we're doing generative modeling, and where our generative model is a really flexible nonparametric class, what we might do instead is we might fit some sort of smooth density. So in this case, our prediction is that the L2 sort of error of estimated density. is going to be up or bounded by some polynomial and to the beta over 2 beta plus 1. This is what some people might call nonparametric rates. So a theory seven thing for a very long time about how sample size, especially, should relate to error. This is a very classic problem that people have thought about in machine learning theory. But these are upper bounds, not actual realized loss values. And really scaling laws are, in some sense, the leap from thinking about the theoretical side of how should data and model size relate to performance and going to the empirical side of saying, actually, our bounds are bad, but maybe we can actually fit these things empirically.

**中文**: 我们正在制定关于误差随m衰减速度预测的规律。在底层，我们可能会遇到一些更为特殊的情况。如果进行生成建模，且生成模型属于高度灵活的非参数类别，我们可能会转而拟合某种平滑密度函数。此时，我们的预测是：估计密度的L2类误差将受限于某个多项式，其形式为β/(2β+1)。这被部分学者称为非参数速率。长久以来，理论界一直在探讨样本量（尤其是）与误差的关联方式——这是机器学习理论中经典的思考命题。但需注意，这些仅是误差上界，而非实际损失值。从某种意义上说，缩放定律实现了从理论思考（数据与模型规模应如何关联性能）到实证研究的跨越：实际上我们的理论边界并不精确，但或许可以通过实证方法拟合这些关系。

## 段落 7

**英文**: And this is a fun trivia fact, or are you able to trivia fact? What is the first scaling loss paper?. And actually not many papers cite this one, but I think probably the right first scaling law papers is a paper from 1993, Nureps from Bell Labs. And you might recognize some of these names. These are theorists and some of the people that have done really classic work in machine learning theory, like Vapnik and Kareena Cortez and others. And I take an excerpt because I was reading this paper,. actually just preparing this lecture earlier. And it just struck me how ahead of its time, in many ways, this paper was. It's saying, training classifiers on large databases is very computationally demanding. And we need to figure out which ones are good before actually training them. And so what we're going to do is we're.

**中文**: 这是一个有趣的冷知识，或者你能猜到吗？第一篇关于缩放定律的论文是哪篇？实际上引用它的论文并不多，但我认为真正意义上首篇关于缩放定律的论文可能是1993年贝尔实验室的Nureps论文。你或许会认出其中一些名字——这些理论学家和机器学习理论领域的经典贡献者，比如Vapnik、Kareena Cortez等人。我摘录了一段，因为我在阅读这篇论文时（其实是在准备这次讲座前刚读的），深深感到它在许多方面都超前于时代。文中提到：在大型数据库上训练分类器的计算需求极高，我们需要在实际训练前判断哪些模型更优。因此，我们将采取的方法是……

## 段落 8

**英文**: going to propose a new predictive method that predicts how good a model is going to be without actually training the whole thing. And that sounds a lot like scaling loss. And you'll see this later. But they have a functional form that's basically like, oh, the test error of a model is expressible as an irreducible error plus a polynomial. decaying term. And you're like, huh, that looks a lot like a modern scaling law. And they even do the thing where they train a bunch of small models. They fit their curves. And they're like, oh, we can accurately predict the behavior of the model further out. So as with many things, I guess, scaling loss partially.

**中文**: 我打算提出一种新的预测方法，能在不完整训练模型的情况下预测其性能。这听起来很像缩放定律。稍后你会看到这一点。他们提出的函数形式大致是：模型的测试误差可表示为不可约误差加上一个多项式衰减项。你会觉得，这看起来很像现代的缩放定律。他们甚至做了训练一系列小模型、拟合曲线的工作，然后声称能准确预测模型在更大规模下的表现。所以，和许多事情一样，我认为缩放定律在一定程度上得到了验证。

## 段落 9

**英文**: thought about at Bell Labs way back when. And of course, there's others that I think have thought about related ideas in scaling, not just scaling loss, but also really the modern mindset, I think, of thinking about scaling. There's another paper that often gets mentioned in the history of scaling loss, Banco and Brill, who was studying how does the performance of a certain kind. of NLP system scale with the amount of data? And they have what looks like very often a modern scaling law, log axis data on the x-axis performance on the y-axis. And they're basically arguing, well, look, we can get really dramatic performance improvements just by scaling up data. It's very predictable. And maybe we should consider the trade-off spent. between spending time and money on algorithm development versus just collecting more data. And you're like, huh, that sounds a lot like what a lot of this pre-training stuff is thinking about. And then finally, one of the things that I think people have thought about recently, and in the past, is this thing really predictable? What are the right functional forms?.

**中文**: 早在贝尔实验室时期就有人思考过。当然，我认为还有其他人也思考过与扩展相关的理念，不仅仅是损失函数的扩展，更包括现代思维中对扩展的思考方式。在扩展损失函数的历史中，常被提及的另一篇论文是Banco和Brill的研究，他们探讨了某类NLP系统的性能如何随数据量扩展。他们提出的规律看起来非常现代：x轴采用对数坐标表示数据量，y轴表示性能指标。他们基本在论证：只需扩大数据规模，就能获得显著的性能提升，这是高度可预测的。或许我们应该权衡在算法开发上投入的时间精力与单纯收集更多数据之间的取舍。你会觉得，这听起来很像当前许多预训练研究的思路。最后，我认为人们近期和过去一直在思考的问题是：这种规律真的可预测吗？正确的函数形式究竟是什么？

## 段落 10

**英文**: And as early as like 2012, people are really thinking about, all right, like, are these things actually predictable? Is power law, like, for example, power 3 and power 4? Are those really the right functional forms for predicting the behavior of models? And of course, all of this, just to remind you, is thinking about the behavior of models on the y-axis, the capabilities, as a function of the amount of data. that you have on the x-axis. So that's the relationship that I think has been really classically studied, what you might call data scaling in all these cases. And if you're interested in the earliest large-scale, neural scaling law paper, that would probably be hasness at all in 2017. I believe they were by due when they did this work. They showed that for a range of tasks, machine translation, speech, and I think some vision tasks, they showed that essentially error rates fall as a power law. And they even have this nice plot that I really like to refer to when people are discussing scaling loss. That really your expectation should be that there's three different regions in the behavior of a model, right?. Initially, you start out at best guess. You then enter into a region where you're kind of predictably scaling the model.

**中文**: 早在2012年左右，人们就开始认真思考：这些现象真的可预测吗？比如幂律中的三次方或四次方关系，是否真的是预测模型行为的正确函数形式？当然要提醒的是，这一切探讨的核心都是模型在纵轴上的能力表现，如何随横轴上的数据量变化。这种关系正是传统研究的重点，也就是我们常说的数据缩放规律。若论最早的大规模神经缩放定律论文，可能要数2017年Hestness等人的研究（我记得他们当时在DeepMind工作）。他们证明在一系列任务中——包括机器翻译、语音识别和一些视觉任务——错误率确实遵循幂律下降。他们甚至绘制了一张精彩的图表，我每次讨论缩放损失时都喜欢引用它。这张图揭示了一个关键认知：模型行为应存在三个不同阶段——最初是随机猜测期，随后会进入可预测的缩放阶段。

## 段落 11

**英文**: That's the power law region. And then there's another asymptotic region where you're approaching essentially the irreducible error of your model class. And I'll highlight that I think there's. been in the last few years a lot of talk of new phenomena, things like, oh, emergent capabilities, or scaling compute being a new thing, or systems being really important. But have you been reading sort of hasness in 2017? Carefully, you would have seen essentially all of these things. They say, actually, it's really hard to do predictions by scaling law when models are random performance. Because suddenly you can leave the random region. They talk about computational limits. Actually, if we can scale, it means actually scaling by compute is really important. And then finally, they even say things like, maybe we should do things like quantization.

**中文**: 这就是幂律区域。然后还有另一个渐近区域，你基本上在接近模型类别的不可约误差。我想强调的是，我认为过去几年有很多关于新现象的讨论，比如涌现能力，或者扩展计算成为一种新事物，或者系统变得非常重要。但你是否仔细阅读过2017年的哈斯内斯？仔细阅读的话，你基本上会看到所有这些内容。他们说，实际上，当模型处于随机性能时，通过扩展定律进行预测非常困难。因为突然之间，你可以离开随机区域。他们讨论了计算极限。实际上，如果我们能够扩展，这意味着通过计算进行扩展确实非常重要。最后，他们甚至提到，也许我们应该做一些量化之类的事情。

## 段落 12

**英文**: Because if we have predictable scaling, then that means we should be willing to pay for model accuracy. with compute, right? These are all very, very modern ideas. But I think a lot of the early scaling law papers I think understood fairly intuitively. Because once you see these plots, you see that actually with predictable resource investment, you get predictable capabilities improvements. So that's in some sense the core, not quite history,. but I think context that has really shaped scaling laws. All right, any questions so far on the context? This is mainly just data scaling, but I wanted to make sure we go over it carefully. Yes? I like it's a natural form of scaling. I was wondering if there's cases where it is scaling where that doesn't get better. Yeah, so the question was, it's natural, or maybe it arguably natural to expect scaling.

**中文**: 因为如果我们拥有可预测的扩展性，那就意味着我们应该愿意为模型的准确性付出计算资源，对吧？这些都是非常、非常现代的理念。但我认为许多早期的扩展定律论文在直觉上已经理解得相当透彻。因为一旦你看到这些图表，你就会发现，实际上通过可预测的资源投入，你能获得可预测的能力提升。所以从某种意义上说，这是核心，不完全是历史，但我认为是真正塑造了扩展定律的背景。好了，到目前为止对背景有什么问题吗？这主要只是数据扩展，但我想确保我们仔细地过一遍。有吗？我喜欢它是一种自然的扩展形式。我在想是否有扩展但性能没有提升的情况。是的，所以问题是，扩展是自然的，或者可以说期望扩展是自然的。

## 段落 13

**英文**: Are there cases where we don't get scaling or we get different kinds of scaling? And I think one way of thinking about this is if you're measuring kind of training loss or like held out versions of training loss, then I think scaling is very natural, right?. All of classical statistical theories says things should converge. And when they converge, eventually they will get better, right? At some sort of very asymptotic sense. But we do see non-scaling behavior. There was a really interesting competition a few years back called the inverse scaling prize, where they were looking for things that scale inversely. as models got better. And a lot of these are very niche things. Models tend to copy better. And so if you want to suppress copying behavior, it becomes really hard for really strong models, for example. But I think one sort of thing that ties a lot of that together is if you go really far out of distribution, where the behavior is not well specified by the data,.

**中文**: 是否存在我们无法获得规模效应或出现不同类型规模效应的情况？我认为一种思考方式是，如果你测量的是训练损失或类似训练损失的保留版本，那么规模效应是非常自然的，对吧？所有经典统计理论都指出事物应当收敛。当它们收敛时，最终会变得更好，从某种渐近意义上来说确实如此。但我们确实会观察到非规模效应。几年前有一个非常有趣的竞赛叫做“逆规模奖”，旨在寻找随着模型性能提升反而出现逆向规模效应的案例。其中很多是非常小众的情况。例如，模型往往更擅长模仿，因此若想抑制模仿行为，对于非常强大的模型来说就变得异常困难。但我认为，将许多这类情况联系起来的一个关键点是：当你远远偏离数据分布时，模型行为无法被数据充分界定。

## 段落 14

**英文**: then you can get all sorts of behaviors. No scaling at all or inverse scaling or what have you, right? So in some sense, you can think of this as the extension of the classic like deep learning robustness problems. Cool. OK. So now I'm going to talk about scaling behaviors of LLMs. Like just essentially going through several kinds. of empirical results. I'm going to walk you through data scaling in particular and some examples just to convince you that this is a very natural object to expect. And then we'll talk about model size, which is a different kind of a thing. So scaling laws, I think, are fairly well established.

**中文**: 那么你就能观察到各种各样的行为。可能是完全不按比例缩放，或者是反向缩放，诸如此类，对吧？所以从某种意义上说，你可以把这看作是经典深度学习鲁棒性问题的延伸。很好。那么现在我要谈谈大语言模型的缩放行为。基本上就是回顾几种实证结果。我会重点讲解数据缩放，并举例说明，让你相信这是一种很自然的现象。然后我们会讨论模型规模，这是另一个不同的话题。我认为缩放定律已经相当成熟了。

## 段落 15

**英文**: And they seem to appear very, very often in many variables. You see scaling and compute on the x-axis. These are all taken from Kaplan's scaling law paper, which I'll refer to extensively in this lecture. So the x-axis here is log compute. y-axis here is log test loss. And on the right, you see similar kinds of scaling both for data set size. So this is the amount of data and parameters. Once I'll tell mention here as I talk through this, is when we scale things like data set size or parameters, we're always assuming that the other variable, in this case, if you're scaling data set size, the model size is much, much, much bigger than you can saturate with the data set size. Because obviously, if you have way more data than parameters, eventually, you're going to sort of ask them toad out. So in all of these, we're trying to avoid the asymptotic regime.

**中文**: 它们似乎在许多变量中出现的频率极高。你可以在x轴上看到缩放和计算量。这些都取自卡普兰的缩放定律论文，我将在本次讲座中多次引用。因此，这里的x轴是对数计算量，y轴是对数测试损失。在右侧，你看到数据集大小也有类似的缩放规律。所以这是数据量和参数量的关系。需要说明的是，当我们讨论缩放数据集大小或参数时，总是假设另一个变量——比如在缩放数据集大小时，模型规模要远远大于数据集所能饱和的极限。因为显然，如果数据量远超参数数量，最终模型会趋于饱和。所以在所有这些情况下，我们都试图避免进入渐近区域。

## 段落 16

**英文**: They hold in also pretty non-standard settings. They'll hold for downstream tasks. They'll hold out of distribution, which is what's being shown here, from the Kaplan paper. And so in some ways, power law relationships seem to appear more often than we might initially expect,. especially for these O, D, or other variables. So I want to talk through data scaling loss first, because I think they're the most intuitive. At the very least, I think the theory for that is fairly clear. And so to be precise, when I say something like data scaling, what I mean is just some sort of simple formula that maps data set size, which I'm going to refer to as n. to our excess error. Excess error is the error beyond the irreducible regime.

**中文**: 它们在相当非标准的环境中同样成立。它们适用于下游任务。它们能在分布外情况下保持，这正是卡普兰论文中所展示的。因此，在某些方面，幂律关系似乎比我们最初预期的更为常见，特别是对于这些O、D或其他变量。所以我想先讨论数据缩放损失，因为我认为它们最直观。至少，我认为其理论相当清晰。准确来说，当我提到数据缩放时，我指的是某种将数据集大小（我称之为n）映射到我们超额误差的简单公式。超额误差是指超出不可约误差范围的误差。

## 段落 17

**英文**: And if you recall that figure I refer to in Hesnist, what we are going to expect is monotonic logistic-looking curves. And really, our interest is primarily going to be in the power law region to the irreducible error region. Like, of course, it's very interesting to also ask questions about what happens in the small data regions as we leave random guessing. But that's much, much harder to reason about. Whereas I think this right tail, actually, I can hopefully convince you that this part is actually a very, very natural thing to expect power law scaling. So OK, right. So the first empirical observation that we have, right? And this is kind of the thing that I'm going to convince you as natural is when we plot on the x-axis data set size and on the y-axis test loss, then on the log log plot model performance is linear, right? You might call this scale free, or you might call it power law. These are more sort of physics-oriented terminology. And sort of this was established by many people, but you might refer to Kaplan to see many examples of this. So I think, as sort of the previous question sort of brought up, we kind of expect error to be monotone.

**中文**: 如果你还记得我在Hesnist中提到的那个图表，我们预期会看到单调的逻辑曲线。实际上，我们主要关注的将是从幂律区域到不可约误差区域的部分。当然，探讨我们离开随机猜测后小数据区域的情况也很有趣，但这在推理上要困难得多。而我认为，实际上，我希望能够说服你，右侧尾部这部分出现幂律缩放是非常自然的现象。那么，第一个经验观察是：当我们在x轴上绘制数据集大小，在y轴上绘制测试损失时，在双对数坐标图中，模型性能呈线性关系。你可以称之为无标度或幂律，这些更像是物理学术语。这一点已被许多人证实，你可以参考Kaplan的研究来查看许多例子。正如之前的问题所提到的，我们预期误差是单调的。

## 段落 18

**英文**: We train on more data. Error goes down, fairly obvious. The part that is less obvious is the precise functional form of this scaling, right?. So when I say it's a power law, it's linear in log log space. And then so what is the implication of that, right? If something is linear in log log, that means that there's a polynomial relationship between your x-axis and your y-axis, right? And y is polynomial decay natural. Well, I'm going to walk you through two examples, and both of those are going to result. in some fairly natural polynomial decay. I'm going to start with the simplest possible example, right? Like this is just going to be even stats 101, rather than machine learning 101. So what I want to do is I want to estimate the mean of a data set, right? And estimating the mean is a task of estimating a parameter, I can ask for what's the scaling law?. What's the error of my mean estimation task is a function of data, right? So I can write that down.

**中文**: 我们使用更多数据进行训练，错误率随之下降，这相当明显。不那么明显的部分是这种缩放的确切函数形式，对吧？所以当我说它是幂律时，它在双对数空间中是线性的。那么这意味着什么呢？如果某物在双对数中呈线性，那就意味着你的x轴和y轴之间存在多项式关系，对吧？而y是多项式衰减的自然结果。我将通过两个例子来讲解，这两个例子都会得出一些相当自然的多项式衰减。我将从最简单的例子开始，对吧？这甚至只是统计学101，而不是机器学习101。我想做的是估计一个数据集的均值，对吧？估计均值是一个参数估计任务，我可以问缩放规律是什么？我的均值估计任务的误差作为数据的函数是什么？所以我可以把它写下来。

## 段落 19

**英文**: Well, my input comes from a Gaussian, and the task is to estimate the average. I've written those out in the blue box above. And what's the error? Well, by sort of very standard arguments, right?. The average is going to be also distributed as a Gaussian with the standard deviation divided by n. So I'm going to get sigma squared over n is my estimation error, right? This is the expected squared error of my estimate. And if you look at this, this is polynomial n. And just to really drive the point home, you take the log of both sides of this, log of the error. on the left, and log of n on the right-hand side, I get exactly log of error is equal to negative log n plus 2 log sigma, right? So this is exactly the kind of thing we expect. And we expect a slope of 1 if we were to fit a scaling law for mean estimation. So now, equipped with this new knowledge, you might say, all right, I'm going to go around,.

**中文**: 我的输入数据来自高斯分布，而任务是估计其平均值。这些内容我已经在上方的蓝框中列出。那么误差是多少呢？根据非常标准的论证，平均值也将服从高斯分布，其标准差除以n。因此，我的估计误差将是σ²/n，对吧？这就是我估计值的期望平方误差。观察这个表达式，它是关于n的多项式。为了更清楚地说明这一点，我们对等式两边取对数：左边是误差的对数，右边是n的对数，我们得到误差的对数等于负的logn加上2logσ，对吧？这正是我们所预期的形式。如果我们要为均值估计拟合一个缩放定律，我们期望的斜率是1。那么现在，有了这个新认识，你可能会说，好吧，我要继续深入探讨。

## 段落 20

**英文**: and I'm going to look at what the rates are for estimating different things. And that will tell me about what I should expect for data scaling. And so you might say, oh, what I expect is 1 over n. You might expect 1 over square root of n for agnostic learning, and so on and so forth. So we should expect to see some pretty nice round numbers. on the slope here of a log log plot. I should expect to see 1 or 0. 5. What do we actually find empirically when we look across these papers? Just to sort of call them out. In Hessness for machine translation, we see the negative 0.

**中文**: 我将研究估算不同事物的速率如何。这会告诉我数据规模扩展的预期效果。你可能会说，我预期的是1/n。对于不可知学习，你可能会预期1/√n，依此类推。因此，我们应该会在对数坐标图的斜率上看到一些相当规整的数字。我预期会看到1或0.5。当我们实际查阅这些论文时，经验上发现了什么？简单提一下：在机器翻译的Hessness研究中，我们看到了负0。

## 段落 21

**英文**: 13. For speech, we see negative 0. 3. And for language modeling, we see an exponent of negative 0. 095. Those are all much, much slower than the 1 over n or 1 over square root of n rates that you might expect when you're just fitting simple functions. So why might this be? This will be the last math slide of this lecture. And then we can go to just fitting lines on log log plots. the rest of the time. But this will hopefully drive the point at home of why we might see these particular slopes.

**中文**: 13. 对于语音，我们看到负0.3的指数。而对于语言建模，我们看到的指数是负0.095。这些都比你可能预期的1/n或1/√n速率要慢得多，当你只是拟合简单函数时。那么为什么会这样呢？这将是本次讲座的最后一个数学幻灯片。然后我们可以把剩下的时间都用在双对数图上拟合直线。但这希望能清楚地说明为什么我们可能会看到这些特定的斜率。

## 段落 22

**英文**: So we know that neural nets aren't just estimating the mean, or it's not even fitting a linear regression. They can fit arbitrary functions. So let's turn that into an example, and let's work through that example. So my input is x1 through xn. So I have n samples, and I'm going to put them uniformly in the 2D unit box. And I want to estimate some random, not random, some arbitrary regression function, y equals f. And I'll assume f is smooth and so on. If you really want to be precise, there's some regularity conditions here. A simple approach to estimating a regression function f is just to cut the 2D space up into small boxes. And within each box, I can measure the average of the y values.

**中文**: 因此我们知道，神经网络不仅仅是在估计均值，甚至也不仅仅是拟合线性回归。它们能够拟合任意函数。那么，让我们通过一个例子来具体说明，并详细探讨这个例子。我的输入是从x1到xn。也就是说，我有n个样本，并将它们均匀地分布在二维单位盒子中。我想要估计某个随机的——不，是某个任意的回归函数，y等于f。我会假设f是平滑的等等。如果你想要更精确，这里有一些正则性条件。估计回归函数f的一个简单方法就是将二维空间分割成小盒子。在每个小盒子内，我可以测量y值的平均值。

## 段落 23

**英文**: Like a very simple non-parametric regressor is to just cut the space up and then to estimate what's going to happen. Now informally, if we pick, I'm going to have square root n. boxes. Now each box is going to get square root of n samples. And now my error is going to be 1 over square root of n. And if you sort of follow this logic through to more dimensions, you'll see that, indeed, dimensions, this is going to be error is equal to n to the negative 1 over d. And then my overall scaling, if I were to take log log plots of the whole thing,. is I expect the slope of negative 1 over d. And so why did I walk you through this example? I walked you through this example, because if you have flexible function classes, what people call non-parametric function classes, you expect dimension dependence. And therefore, the slope of the scaling law actually moved much more slowly.

**中文**: 就像一个非常简单的非参数回归器，只需将空间分割开来，然后估计会发生什么。非正式地说，如果我们选择，我将有根号n个盒子。现在每个盒子将获得根号n个样本。那么我的误差将是1除以根号n。如果你将这种逻辑推广到更多维度，你会发现，实际上，维度的影响会导致误差等于n的负1/d次方。然后，如果我对整个过程进行对数坐标图绘制，我的整体缩放规律是，我期望斜率为负1/d。那么我为什么要带你们看这个例子呢？我带你们看这个例子，是因为如果你有灵活的函数类，也就是人们所说的非参数函数类，你会预期存在维度依赖。因此，缩放定律的斜率实际上变化得更慢。

## 段落 24

**英文**: And in some sense, the slope is telling you. almost precisely the intrinsic dimensionality or the ease of learning this task. And people have argued this more formally or more literally. There's been several theory-slashing empirical papers arguing that really the reason why we get these exotic or non-standard rates of learning is that it is closely connected to the intrinsic dimensionality of the data. And the sort of, for example, the plots of these predictions,. the dash lines and these purple circles are somewhat close. Although you don't want to read too much into this because estimation of intrinsic dimension is an extremely difficult problem, as difficult as modeling the data overall. Oh, yes. I guess I was going to point me at the answer as much as I was going to go. Like, how do you generate data that has an underlying intrinsic dimension at all for a simulation? Yeah.

**中文**: 从某种意义上说，斜率几乎精确地揭示了任务的内在维度或学习的难易程度。人们对此进行了更正式或更字面的论证。已有数篇理论结合实证的论文指出，我们之所以获得这些特殊或非标准的学习速率，根本原因在于其与数据内在维度的紧密关联。例如，这些预测的图示——虚线部分与紫色圆圈标记的位置较为接近。不过我们不宜过度解读这一点，因为估计内在维度本身是极其困难的，其难度不亚于对数据整体进行建模。哦，是的。我想我本意是引导自己接近答案，就像在模拟中如何生成具有基础内在维度的数据那样。嗯。

## 段落 25

**英文**: So the results here, well, if you want, for example, to generate data, that's actually not too hard. You could write down a function that takes in like five variables. And then that would be, as long as all five of those variables don't cancel each other, that's a five-dimensional surface. And you can add a little bit of noise and you're good to go. The difficulty here is that they're actually doing things like training on C-FAR. And then they're trying to estimate the intrinsic dimensionality of C-FAR. That's a much harder task. OK. And data scaling laws are quite useful. I was going at this from a, let me explain to you, scaling laws perspective.

**中文**: 所以这里的结果，嗯，如果你想生成数据，其实并不太难。你可以写一个函数，接收大约五个变量。然后，只要这五个变量不互相抵消，那就是一个五维曲面。再加一点噪声，就搞定了。但这里的难点在于，他们实际上是在C-FAR这样的数据集上进行训练，然后试图估计C-FAR的内在维度。那可就难多了。好的。数据缩放规律其实非常有用。让我从缩放规律的角度给你解释一下。

## 段落 26

**英文**: But you can actually use scaling laws to do many interesting things. You can make engineering decisions of various kinds using data scaling laws. And people do, in fact, do this. For example, you might say, well, how does data set composition. affect performance, not just data set size? Well, if you're changing the test set, Kaplan at all has a really nice figure showing, actually, data composition only affects the offset, not the slope. And what that would mean is it says, if you want to pick a really good data set, you don't have to necessarily train your models. at a huge scale. You can scale them down and do your data selection experiments on much smaller models. And the shape of the expected sort of, as we mix sort of different data, we might expect certain kinds of sort of shapes. And you can use regression and other kinds of techniques to try to figure out, for example, optimal data mixing.

**中文**: 但实际上，你可以利用缩放定律做很多有趣的事情。你可以使用数据缩放定律做出各种工程决策。事实上，人们确实在这样做。例如，你可能会问，数据集的构成如何影响性能，而不仅仅是数据集的大小？如果你改变测试集，卡普兰等人有一张非常清晰的图表显示，实际上，数据构成只影响偏移量，而不影响斜率。这意味着，如果你想选择一个非常好的数据集，你不一定需要在大规模上训练模型。你可以缩小规模，在更小的模型上进行数据选择实验。随着我们混合不同类型的数据，我们可能会预期某些形状的出现。你可以使用回归和其他技术来尝试找出，例如，最优的数据混合比例。

## 段落 27

**英文**: using scaling laws. And people have written several papers on this topic. Although, as with all data selection research, a lot of this seems fairly tricky to execute reliably. There's other also interesting questions that you might ask. There's a lot of discussion these days about, I'll be running out of data on the internet. And so once you start asking those questions,. the other interesting and important question is, well, can we just keep training on the same data we have? What's the diminishing returns property of that? And so there's interesting work, extending scaling laws to multi-epoc training, basically arguing that there's an effective sample size. And after about four epochs, you have rapidly diminishing returns as you repeat more and more data. And by modifying the usual scaling law, you can basically get a version where you have amount of effective data and unique tokens that sort of diminished out as you increase the amount of repetition. Finally, I think one interesting combination of these two ideas is if you're thinking about data selection in the large data regime.

**中文**: 利用缩放定律。人们已经就此主题撰写了几篇论文。尽管，如同所有数据选择研究一样，其中许多方法似乎相当难以可靠执行。你可能会提出其他有趣的问题。近来有很多讨论，比如互联网上的数据即将耗尽。因此，一旦开始思考这些问题，另一个有趣且重要的问题是：我们能否仅依靠现有数据持续训练？这样做的收益递减特性是什么？于是出现了有趣的研究，将缩放定律扩展到多轮次训练，基本观点是存在一个有效样本量。大约四个轮次后，随着数据重复次数增加，收益会迅速递减。通过修改常规的缩放定律，可以得到一个版本，其中有效数据和唯一标记的数量会随着重复增加而逐渐减少。最后，我认为这两种思路的一个有趣结合点在于：当你在大数据体系中考虑数据选择时。

## 段落 28

**英文**: Imagine you're going to be training on trillions and trillions. of tokens. Now, what would be better? Would it be better to repeat high quality sources like Wikipedia and perhaps your secret pirated books 10 times? Or would it be better to include new data? The fact that you can either repeat data or you can include more data now has multiple axes on which you can optimize your data mixture. And there's also been some interesting data scaling work, this one from CMU folks, on essentially trading off between repeating data versus picking lower quality data that's new. And so all of this really is a really natural extension of what I already taught you, which is if you assume that there's a predictive power law relationship, right? And that this power law relationship holds on a per. mixture basis, then you can fit these scaling lock extrapolations and then get an estimate of how good your data is going to be at scale. So that's the starting point, which is data scaling. And hopefully, I've convinced you at this point both empirically and conceptually that it's natural to have log linear relationships between data and error. This relationship seems to hold very robustly across domains,. across different kinds of models.

**中文**: 想象一下，你将要用数以万亿计的标记进行训练。那么，哪种方式更好呢？是重复高质量来源如维基百科和你那些秘密盗版书籍10次更好，还是纳入新数据更好？事实上，你既可以选择重复数据，也可以选择纳入更多数据，现在你可以在多个维度上优化你的数据组合。还有一些有趣的数据缩放研究，比如卡内基梅隆大学的研究，基本上是在重复数据和选择新的低质量数据之间进行权衡。所以，所有这些实际上都是我先前所教内容的自然延伸，即如果你假设存在一个预测性的幂律关系，对吧？并且这个幂律关系在每个数据组合的基础上都成立，那么你就可以拟合这些缩放定律并进行外推，从而估计你的数据在大规模下的表现。这就是数据缩放的起点。希望到目前为止，我已经通过实证和概念两方面说服了你，数据与误差之间存在对数线性关系是很自然的。这种关系在不同领域和不同类型的模型中都表现得非常稳健。

## 段落 29

**英文**: And you could kind of have a nice, clean theoretical understanding of what is happening here. And once you do this, you can use this for all sorts of purposes, like picking optimal data mixtures or whatever else. OK, yes. How is the model size picked on the data scaling. Yeah, so as I was kind of saying, back in, well, not this slide, but let's see, back in this slide. When we think about kind of the data size scaling, the model is always picked to be really, really large. So the data is not saturating your model, right? And you want to kind of avoid being in this irreducible error regime. So the model is always picked to be large enough that you're. in the power law region. Whenever you're only varying data.

**中文**: 这样你就能对这里发生的情况有一种清晰而完善的理论理解。一旦做到这一点，你就可以将其用于各种目的，比如选择最佳的数据组合等等。好的，没错。模型大小是如何根据数据规模来选择的呢？是的，正如我之前提到的，回到——嗯，不是这一页幻灯片，我们看看，是这一页。当我们考虑数据规模扩展时，模型总是被选择得非常大。这样数据就不会使模型饱和，对吧？而且你希望尽量避免陷入这种不可减少的误差区域。因此，模型总是被选择得足够大，以确保你处于幂律区域。无论何时，当你只改变数据量时都是如此。

## 段落 30

**英文**: So you can just one model size for like all of them. You have one three-view-view big model size. It's like this each point kind of difference size model. Yeah, for example, for this plot in particular, it's like one big model size. OK. When you're looking at, for example, compute scaling on this axis, then data and model scale join me at some pre-ordained ratio. Cool. Any other questions? OK. Excellent. OK.

**中文**: 所以你可以为所有这些都只用一个模型尺寸。你有一个三视图的大模型尺寸。就像是每个点都有不同尺寸的模型。是的，比如就这个图表而言，它就像是一个大模型尺寸。好的。当你看这个轴上的计算缩放时，数据和模型规模会以某个预定比例共同作用。很好。还有其他问题吗？好的。太棒了。好的。

## 段落 31

**英文**: All right. So now, I think we get to move from data scaling to, in my opinion, slightly more mysterious kinds of scaling. And we're going to talk about model scaling next. And I think this is a more practical engineering set of questions that we're now going to try to answer. So you're in charge of building and shipping a really large language model. And there's a lot of interesting ideas out there, right? You could train the latest state space model. You could train a transformer. You could use add-up. You could use SGD, right? People invent all sorts of new tricks, which ones are worth scaling up and which ones are not. You could also take your limited compute resources and.

**中文**: 好的。那么现在，我想我们可以从数据缩放转向在我看来稍微更神秘的缩放类型了。接下来我们将讨论模型缩放。我认为这是一系列更实际的工程问题，我们现在要尝试解答。假设你负责构建并推出一个非常大的语言模型。市面上有很多有趣的想法，对吧？你可以训练最新的状态空间模型，可以训练Transformer，可以使用加法运算，也可以用随机梯度下降（SGD）。人们发明了各种新技巧，哪些值得扩大规模，哪些不值得。你也可以利用有限的计算资源，然后……

## 段落 32

**英文**: spend them on different things. You can train models for longer, or you could train bigger models. For a given flop, you can trade between these two. And you could also do things like go and collect more data versus get more GPUs. There's a lot of different things that you can do. And scaling laws allow you to have a pretty simple. procedure to just answer all of these questions. So I'll go through the classic sort of Kaplan scaling law paper. If you're interested in these topics, I encourage you to read it. It's just kind of a gold mine of all of these kinds of observations.

**中文**: 你可以将资源投入到不同的事情上。可以延长模型训练时间，或者训练更大的模型。在给定的计算量下，你可以在两者之间进行权衡。你也可以选择收集更多数据，或是获取更多GPU。有很多不同的选择。而缩放定律能让你通过一个相当简单的流程来回答所有这些问题。接下来我会回顾经典的卡普兰缩放定律论文。如果你对这些话题感兴趣，我建议你读一读它。这篇论文简直是这类观察结果的宝库。

## 段落 33

**英文**: Some of it is old. But it's I think still a match in the thoroughness of all of the things that it really studied in a fairly nice unified setting. So architecture wise, you might start by asking like transformers versus LSTMs, which ones better. Well, the brute force way might be to scale up LSTMs and up to like GPT-3 level. And then you can figure out whether it's good or not. The scaling law way is much simpler. You basically train a bunch of LSTMs and transformers across many different compute thresholds or compute levels. And then you kind of see what happens as you scale them up. And I think the trends here are fairly clear. Like no matter how many layers you have on your LSTMs, there's a pretty big gap, pretty big constant factor gap.

**中文**: 其中一些内容已经过时。但我认为，就其在一个相当统一的框架下所深入研究的各个方面而言，它依然具有相当的参考价值。因此，从架构的角度来看，你可能会首先提出这样的问题：Transformer和LSTM，哪个更好？一种直接的方式可能是将LSTM的规模扩大到类似GPT-3的水平，然后你就能判断它是否优秀。而采用缩放定律的方法则要简单得多。你基本上会在许多不同的计算阈值或计算水平上训练一批LSTM和Transformer，然后观察它们在规模扩大时的表现。我认为这里的趋势相当明显：无论你的LSTM有多少层，都存在相当大的差距，一个相当大的常数因子差距。

## 段落 34

**英文**: between transformers and LSTMs. And remember, this is a log scale. So this is kind of saying something like, I don't know what the exact numbers are, but imagine this is like 15 times less efficient. Then no matter where you are on this plot, the LSTM is let's say 15 times less compute efficient than a transformer. So there's a constant factor compute penalty to using LSTMs, at least in this plot. You could do an amount and say, well, there's a lot more architectures, which ones are really good and worth doing. And some of the classic papers, this one is by EK and others. At Google have done exactly this kind of scaling work where they took a bunch of architectures on the right here. And they basically scaled them up. So the x-axis is the amount of compute.

**中文**: 在Transformer和LSTM之间。请记住，这是对数刻度。所以这大致意味着，虽然具体数字不详，但可以想象LSTM的效率低了大约15倍。无论在这张图的哪个位置，LSTM的计算效率都比Transformer低约15倍。因此，至少在这张图中，使用LSTM会带来恒定的计算效率损失。你可以进一步探讨：实际上存在更多架构，哪些真正优秀且值得尝试？一些经典论文，比如EK等人的研究，正是做了这类扩展性分析。谷歌团队就曾对右侧列出的多种架构进行过此类研究，基本上是将它们按规模扩展。这里的横轴代表计算量。

## 段落 35

**英文**: The red line is basically each architecture. And the green line is the transformer baseline. And they ask, oh, can any of these alternative architectures match or out scale the transformer? And what do they end up? Well, actually, the only thing that seems really strongly and reliably meet the transformer is gated linear units. and make sure of experts. And once you know it, that's exactly the kind of stuff that people are doing today. And so this is kind of the scaling law version of that same idea of saying, how would you have come to the conclusion that we should be doing switch transformers in GLU? And for example, not the performer. And the scaling law provides some clear evidence. of why you might want to do that. Optimizer choice, I think, follows a similar thing. This one's from Hesnus.

**中文**: 红线基本代表每种架构，绿线则是Transformer基线。他们问道：这些替代架构中有没有能媲美甚至超越Transformer的？结果如何呢？实际上，唯一看起来能稳定达到Transformer水平的只有门控线性单元，并且要确保使用专家网络。一旦明白了这一点，你就会发现这正是当前人们正在实践的方向。这就像是缩放定律对同一理念的验证：我们该如何得出“应该在GLU中采用切换式Transformer”的结论？而不是选择Performer等其他架构。缩放定律为此提供了清晰的依据。优化器的选择我认为也遵循类似的逻辑。这个观点来自Hesnus。

## 段落 36

**英文**: They compare SGD and Adam. They find very similar to before this kind of constant factor gap in compute. In this case, data set size. But of course, that translates to compute. in the effectiveness of Adam versus SGD. RHN in this case is recurrent highway nets. You can sort of ignore the details here. You kind of see the point of how you would do this analysis rather than the specific results that are shown here. In the beginning, I also said something like, oh, depth versus width. What should the aspect ratios be?.

**中文**: 他们比较了SGD和Adam。他们发现在计算效率上存在与此前类似的恒定倍数差距，这里具体体现在数据集规模上，但这当然也直接关联到计算成本。关于Adam与SGD的效果对比——此处的RHN指循环高速公路网络，细节可暂不深究。关键是要理解这类分析方法的思路，而非局限于图中展示的具体结果。在开头我还提到过类似深度与宽度的权衡问题：究竟怎样的比例才是最合适的？

## 段落 37

**英文**: That was one of the hyper parameter topics we talked about. And we see sort of similar analysis. But in scaling law form from Kaplan, I think this one's intriguing to me, at least, because we might think that deeper layers get dramatically better. There's like clear separation between the number of layers. But we see, at least here, that there's actually. a lot of sort of slump. One layer is really bad. But a lot of the other sort of layer choices sort of remain pretty stable. And hopefully, this is reminiscent of that slide I showed back in the architecture lecture where I said, well, the aspect ratio, the ratio of width and depth, roughly something like 4 to 16 or something. was a pretty natural number.

**中文**: 这是我们讨论过的超参数主题之一。我们看到了类似的分析。但以卡普兰的缩放定律形式呈现，至少我觉得这一点很有趣，因为我们可能认为更深的层会显著提升性能。不同层数之间似乎存在明显差异。但至少在这里我们看到，实际上存在很多类似的下滑现象。单层效果确实很差，但其他层数选择大多保持相对稳定。希望这能让大家回想起我在架构讲座中展示过的那张幻灯片，当时我说过，宽深比，也就是宽度与深度的比例，大约在4比16左右，是一个相当自然的数值。

## 段落 38

**英文**: But there's a really wide basin in which you're approximately optimal. And this scaling law analysis also backs that up. One important subtlety that I would do want to point out, and this one bites people every now and then, is that not all parameters are equal. Often you want to do parameter scaling analyses. But if you work to say count embedding parameters as part of your model, well, you get a pretty different scaling law. You get this weird looking thing that slightly bends over here. Whereas if you only consider the non-embedding parameter, you see that much cleaner result that I showed you before. So embedding layer parameters don't really. behave the same. And they don't show the same kinds of log linear scaling as the non-embedding parameters when you account for them.

**中文**: 但这里存在一个非常宽广的区间，在这个区间内你的模型表现大致是最优的。这种缩放规律分析也证实了这一点。我想指出一个重要的微妙之处，这一点时常让人措手不及，那就是并非所有参数都是等价的。通常你需要进行参数缩放分析。但如果你把嵌入参数也算作模型的一部分，那么你会得到一个截然不同的缩放规律。你会看到这个看起来有点奇怪的曲线，在这里稍微弯曲了一下。而如果你只考虑非嵌入参数，就会看到我之前展示的那个清晰得多的结果。所以嵌入层参数的行为其实并不相同。当你把它们考虑在内时，它们不会像非嵌入参数那样呈现出相同的对数线性缩放规律。

## 段落 39

**英文**: And there's sort of related work on saying not all parameters are the same on recent papers on scaling mixtures of experts, where they're also sort of trying to figure out what does it mean to be a parameter when you have such sparsely activated. parameters. And in those kinds of papers, they sort of try to derive essentially things like a coolant number of dense parameters in order to sort of try to normalize the number of parameters in MOE. Right? I've showed you this plot earlier in the hyper parameter selection. But hopefully now, actually, you see the full context, not just the original sort of the hyper parameter choice question. We know that in many cases, I'll go back, let's say, to here. Often what we'll see is scaling law curves that look like the following. You'll often see that the slope of the curves. remain very similar. They're non-crossing, and that there are sort of constant factor offsets between these curves.

**中文**: 最近关于专家混合模型规模扩展的论文中，有类似研究指出参数并非同等重要——这些研究试图厘清在稀疏激活参数的情况下，"参数"的本质意义。这类论文本质上试图推导出类似"稠密参数等效数量"的概念，以规范化专家混合模型中的参数量。我在之前超参数选择部分展示过相关图表，但现在希望你们能理解完整背景，而不只是最初提出的超参数选择问题。我们知道在许多情况下（比如回到这里），通常会看到如下规律的规模扩展曲线：这些曲线的斜率往往保持高度相似，彼此不相交，且曲线间存在近似恒定的偏移量。

## 段落 40

**英文**: And whenever this is true, what you can then do is you can take a slice at a particular level of compute or a particular set of hyper parameters and analyze the hyper parameter trade off very carefully, assuming and sort of be sort of safe in scaling that up. And so when you go to Kaplan's paper, you'll see exactly these kinds of analyses being done, especially, I think, that the center one, the aspect ratio plot is definitely worth looking at. They're not just sort of scaling up and down models. They're actually taking different slices, so different sized models, 50 million, 270 million, 1. 5 billion. And they're looking at how the aspect ratio changes the loss. And they kind of see that, oh, actually, the shape of the curve, not just the scaling slopes, actually remain similar. And this means that I can pick an aspect ratio between 10 to 100, and anything in between will work fine about all of these different scales. And so this is important to think about. I think initially when you're trained in deep learning,.

**中文**: 每当这种情况成立时，你就能在特定计算层级或特定超参数组合下进行切片分析，从而非常仔细地权衡超参数的选择，并能在扩大规模时相对稳妥地推演。因此，当你查阅卡普兰的论文时，会看到他们正是采用了这类分析方法——尤其是中间那张宽高比图表，我认为非常值得细读。他们并非简单机械地缩放模型规模，而是对不同体量的模型（如5000万、2.7亿、15亿参数）进行切片研究，观察宽高比对损失函数的影响规律。他们发现这些曲线的形态（不仅是缩放斜率）在不同规模下保持相似，这意味着在10到100的宽高比范围内任意取值，对于所有不同规模的模型都能良好适配。这种思考方式至关重要，特别是在深度学习入门阶段。

## 段落 41

**英文**: model training, you think about hyper parameter tuning, but you want to be sort of scale where in how you're tuning your hyper parameters. And that's a really big difference. In mindset, I think, between the scaling lost-style approach and maybe what you've been trained or what you naturally think about in terms of, oh, let's just tune these models at a small scale. And so the same is being done for feed-forward ratio and for attention-head dimension. You're varying various aspects of scale, and you're trying to see whether the minima remains similar. OK. Another important thing, actually, maybe not next lecture, but next lecture, I'm going to talk about practical case studies, almost of how people have scaled up models. And we'll actually see that batch size and learning rate are actually two really tricky things that you have to deal with carefully when you scale models up. So when you scale models up, you're going to have to maybe think about the optimal learning rate will be different across model scales. And if you're doing that, then also maybe the optimal batch size might end up varying as well,.

**中文**: 模型训练时，你会考虑超参数调优，但你需要关注调优的规模维度。这与常规思维存在巨大差异——在规模化损耗式训练方法中，你可能会发现自己的固有思维模式还停留在“先进行小规模模型调优”的层面。前馈网络比率和注意力头维度的调整也遵循相同逻辑：你通过改变规模的不同维度，来观察损失最小值是否保持稳定。另外还有一点很重要——或许不在下节课，但在后续课程中，我将通过实际案例解析模型规模扩展的具体实践。我们会发现批量大小和学习率在模型扩展过程中是需要谨慎处理的两个关键变量。当扩大模型规模时，不同规模模型对应的最优学习率可能发生变化，而最优批量大小往往也会随之波动。

## 段落 42

**英文**: because those draw often co-linked. And so we need to think about what the right way of scaling batch sizes and how batch size interacts with scale and also learning rates. We'll talk about those for the next couple of slides. So batch size from the systems lecture, hopefully you remember, it has diminishing returns past a certain point. So up until a certain point, when the batch size is smaller than the noise scale, we're on the left hand side here, increasing batch size is almost equivalent to taking more gradient steps. So that's roughly saying, if I double my batch size, it's as good as taking two gradient steps. And that's a really, really good place to be, right? Because now you've got the systems power of being able to. paralyze across the batch while having the optimization efficiency of taking two steps. But past a certain point, you're going to have ineffective scaling, where now you're sort of noise scale and your batch size are the same. And the additional samples in your batch that you're taking, they're not reducing useful noise.

**中文**: 因为那些绘图常常相互关联。因此，我们需要思考如何正确调整批量大小，以及批量大小如何与规模和学率相互作用。接下来的几张幻灯片中我们将讨论这些内容。从系统课程中我们知道，批量大小超过某个点后收益会递减。在批量大小小于噪声规模之前，即我们在这里的左侧，增加批量大小几乎等同于进行更多的梯度步骤。这大致意味着，如果我将批量大小翻倍，效果就像进行了两次梯度步骤。这是一个非常理想的状态，对吧？因为现在你既具备了跨批量并行处理的系统能力，又获得了进行两次步骤的优化效率。但超过某个点后，扩展效果就会变得不明显，此时你的噪声规模和批量大小大致相当。而你批量中增加的额外样本，并没有减少有用的噪声。

## 段落 43

**英文**: It's getting dominated by kind of the curvature of the. bias term, so to speak, of the curvature of your optimization landscape. And one really useful thing to think about, useful sort of analysis object is this notion of a critical batch size. And the critical batch size, you can think of, is kind of this threshold point, where we go from perfect scaling to dip strong diminishing returns. And you can sort of analyze this in theory, and sort of. opening the eye papers on critical batch sizes do this. But you could also analyze this empirically. And this is another thing that's been studied sort of in the scaling law kind of way. You can kind of see, you can estimate the point at which sort of progress slow. So you can estimate empirically what the critical batch size point tradeoff points are.

**中文**: 它正逐渐被所谓的优化曲面的曲率偏置项所主导。一个非常有用的思考角度和分析对象是临界批次大小这一概念。临界批次大小可以看作是一个阈值点，在这个点上，我们从完美的线性扩展转变为收益急剧递减。理论上可以对此进行分析，关于临界批次大小的开创性论文正是这样做的。但也可以通过实证方法来分析。这是在扩展定律研究中的另一个被探讨的方面。你可以大致看到并估计出进展开始放缓的那个点。因此，你可以通过经验来估计临界批次大小的权衡点在哪里。

## 段落 44

**英文**: And you can also basically train better and better models. And one really interesting thing is, as you try to improve the loss, so you're going left side here. So you're making losses better and better and better and better and better. Your critical batch size ends up getting smaller. So the smaller the loss target, the bigger the overall batch size that you can be. And so one of the things that this leads to is, for example, if you look at the Lama 3 training report, you'll actually see, for example, that they'll increase the batch size after a certain point, or they'll do things like increase the batch size as they train. Because as your loss target gets smaller, your batch size can, in turn, get bigger. So as we increase both compute and model size, like what's. the right thing to do? Once again, we can do kind of a scaling analysis. This is from Kaplan.

**中文**: 而且你基本上也可以训练出越来越好的模型。一个非常有趣的现象是，当你试图降低损失时——也就是向左侧移动——你会让损失变得越来越小、越来越优化。这时，你的临界批次大小实际上会变小。也就是说，损失目标越小，你能够使用的总体批次大小反而可以更大。这导致的一个实际例子是，比如你看Llama 3的训练报告，会发现他们在某个时间点后会增加批次大小，或者在训练过程中逐步提升批次规模。因为随着损失目标变小，批次大小相应地可以变得更大。那么，随着我们同时增加计算资源和模型规模，正确的做法是什么？我们再次可以进行一种缩放分析。这是来自Kaplan的研究。

## 段落 45

**英文**: And you can try to figure out, as we increase the amount of compute, what is the optimal batch size? And what we kind of see is that, as we increase the amount of compute, we can actually have a reasonable sort of parallelism. The number of total steps can stay the same, at least within this compute threshold, the number of total steps can stay the same while sort of getting the batch is bigger and bigger and bigger. And if you fix the amount of batches, of course, the number of steps is going to go up and up and up. So this is good news, hopefully, for data parallel processing. So that's the batch size story. The thing you should maybe remember, because I think critical batch size, they're kind of a messy concept, is that A, there's a sort of diminishing return point. The critical batch size, that's one thing. The second one is that it does seem to follow a pretty predictable scaling, often as a function of your target loss. And given that, you can figure out what is the right trade-offs that I can make in terms of systems efficiency and my optimization progress. As I said before, the other aspect of this is, you've got your batch size, and then you've got your learning rate.

**中文**: 随着我们增加计算量，你可以试着找出最优的批量大小是多少？我们大致观察到的是，随着计算量的增加，我们实际上可以实现一种合理的并行化。总步数可以保持不变，至少在这个计算阈值内，总步数可以保持不变，而批量大小却可以变得越来越大。当然，如果你固定批量数量，步数就会不断增加。所以，这对数据并行处理来说是个好消息，希望如此。这就是关于批量大小的故事。你可能需要记住的一点是，因为我认为临界批量大小是一个有点混乱的概念，首先，存在一个收益递减点。那就是临界批量大小，这是一点。第二点是，它似乎遵循一个相当可预测的缩放规律，通常作为你目标损失函数的一个函数。基于这一点，你可以找出在系统效率和优化进度之间我可以做出的正确权衡。正如我之前所说，另一个方面是，你有了批量大小，然后你还有学习率。

## 段落 46

**英文**: And those two are fairly closely linked with each other. And I'm going to talk about muP, at much more extensive length in the next part of the scaling lecture. But this is kind of a really important, I think, broader idea. So you could do one of two things. And I think this figure will allow me to talk about both of these. So let's look at this left plot first, what's labeled standard practice. So when you train a transformer, what you're basically going to see is something like this left thing here, this. standard practice. So the optimal learning rate is going to be at different points. And the wider the model, as you increase your model size, and your MLPs got wider and wider and wider, the optimal learning rate is going to be pretty small.

**中文**: 这两者之间联系相当紧密。在缩放讲座的下一部分，我将更详细地讨论muP。但我认为这是一个非常重要且更具普适性的概念。你可以采取以下两种做法之一。我觉得这张图能让我同时阐述这两点。我们先来看左边这张标注为“标准做法”的图表。当你训练Transformer模型时，通常会看到类似左边这样的情况，即标准做法。最佳学习率会出现在不同位置。随着模型规模扩大——比如你的MLP层变得越来越宽——最佳学习率会变得非常小。

## 段落 47

**英文**: And as you make your model smaller and smaller and smaller, your losses, of course, are going to go up because your model. is less expressive. But also the optimum learning rate is going to also go up. And often people say there's a rule of thumb. It's like one over the width is the right rate at which you should scale the learning rate. More advanced people will actually fit, basically, take these curves, find the minimum, and then fit a scaling law on the optimum learning. rate. And so we can see that this is a predictable decay and learning rate. And maybe we can fit a scaling law. I'll talk about this more in the next set of lectures.

**中文**: 随着你将模型越做越小，损失自然会上升，因为模型的表达能力减弱了。但与此同时，最优学习率也会随之提高。人们常说有个经验法则：学习率的合适调整幅度大致与模型宽度成反比。更进阶的做法是，根据这些曲线找到最低点，然后为最优学习率拟合一条缩放规律曲线。由此可见，这是一种可预测的衰减与学习率关系，或许我们也能拟合出相应的缩放规律。在接下来的讲座中，我会更详细地探讨这一点。

## 段落 48

**英文**: But an alternative, one that I think many people have started to adopt. And I think is a really interesting thing to think about. is that you can actually reparametrize the model. And in particular, you can do things like scale the learning rates of different layers based on the width. You can scale the variance of the initialization based on the width of the model, as well as multiply the output in the forward path of different layers of the model. And if you do this in a way that is dependent on the width. of the model, you end up with a parameterization of the model whose learning rate is supposed to be more stable, or at least in the original paper, exactly stable across scale. So you tune your learning rate once, and you don't have to do anything else that optimum directly transfer, that you tune it here on the smallest one, and that directly transfers to the very largest scale. And this is the idea called new p. There have been this original paper that I'm showing you is called width new p.

**中文**: 但还有一种替代方案，我认为许多人已经开始采用，并且思考起来非常有趣。那就是你可以对模型进行重新参数化。具体来说，你可以根据模型的宽度来调整不同层的学习率，根据模型的宽度来调整初始化的方差，并在模型不同层的前向传播路径中乘以相应的输出。如果你以依赖于模型宽度的方式来做这些，最终会得到一种参数化方法，其学习率应该更加稳定——至少在原始论文中，它能在不同规模下保持完全稳定。因此，你只需调整一次学习率，无需再做其他事情，这个最优值可以直接迁移：你在最小的模型上调好参数，它就能直接适用于最大规模的模型。这就是所谓的"新参数化"思想。我展示的这篇原始论文就叫做"宽度新参数化"。

## 段落 49

**英文**: There's been other variants, meta with the release of law before claims to have invented something called metapy, which I'm not quite sure what it is yet. But you can see that a lot of labs are thinking about this. Because if you're going to have to rely on predicting. what the optimum learning rate is, then you have to do all sorts of tricky scaling law fits, and maybe this is very unstable. But if you can reparametrize your model, then well, maybe you don't have to do any sort of recuning at all. Of course, that's way more optimistic than what happens in practice. But hopefully this gives you a sense of why this is really cool and really interesting. Scale aware initializations. Cool. Any questions up until this point? I feel like I've sort of gone through a whole bunch of scaling, architecture, and parameter stuff.

**中文**: 还有其他变体，比如随着定律发布而出现的元方法，有人声称发明了一种叫做"metapy"的东西，我还不确定它具体是什么。但可以看出很多实验室都在思考这个问题。因为如果你必须依赖预测最优学习率，那就得进行各种复杂的缩放定律拟合，这可能非常不稳定。但如果你能重新参数化模型，或许就完全不需要任何重新调整了。当然，这比实际情况要乐观得多。但希望这能让你明白为什么这非常酷且有趣。规模感知初始化。很酷。到目前为止有什么问题吗？我觉得我已经讲了一大堆关于缩放、架构和参数的内容。

## 段落 50

**英文**: So I may be all stopped for a moment here in case anyone has any questions. Yeah. I really get that intuition behind like, if we want to lower the lost target, want to increase the map size, I think that's good. Yeah. So when you have a lower lost target, yeah. So what you want to do is the smaller the lost target,. the more sensitive things are. And in the same way that you're going to be lowering your learning rate, you want to also increase your batch size in order to denoise. The more sensitive the target that you have, the more precise your gradients potentially have to be. One way of thinking about it is as you're cooling down in your learning rate is going up,.

**中文**: 所以，我可能需要在这里稍作停顿，以防大家有任何问题。嗯。我确实理解那种直觉，比如，如果我们想降低损失目标，就想增加映射尺寸，我觉得这很好。是的。所以，当你的损失目标较低时，嗯。那么你想做的就是，损失目标越小，事物就越敏感。同样地，当你降低学习率时，你也需要增加批量大小以去除噪声。你的目标越敏感，你的梯度可能就需要越精确。一种理解方式是，随着学习率的冷却，它实际上是在上升。

## 段落 51

**英文**: maybe your batch size should increase as well, because the learning rate and batch size is sort of affect each other inversely. Yeah. Who's batch size thing with all of you? Who's more MLP? Or for computer vision? I'm not sure. There is a sort of related, open AI scaling paper for sort of multi-modal models, but I don't remember what that says about critical batch size for those. Yeah. Yes. What's noise scale? The noise scale? Yeah. The noise scale, at least in sort of this figure, if that's what you're asking about. This is a kind of theoretical analysis. It's basically about the gradient noise that you expect from random sampling within the batch.

**中文**: 或许你的批量大小也应该增加，因为学习率和批量大小在一定程度上是相互影响的。是的。你们当中谁更了解批量大小的问题？谁更熟悉MLP？或者计算机视觉方面？我不太确定。有一篇相关的OpenAI扩展论文，讨论了多模态模型，但我不记得其中关于这些模型临界批量大小的具体内容了。是的。噪声尺度是什么？噪声尺度？对，至少在这个图表中，如果你问的是这个。这是一种理论分析，基本上是关于在批次内随机抽样所预期的梯度噪声。

## 段落 52

**英文**: So this is not like a precisely empirically measured quantity obesity. OK. OK. All right. So one thing I'll caution, and I think this is a big caution for a lot of scaling law works, is that scaling laws are very nicely behaved for log losses. So we train on next token prediction cross-entropy. When your scaling law targets are those cross-entropy,. very easy works very well. But if you're trying to do downstream tasks, you're trying to directly scale on benchmarks, behavior is much less predictable. So here, on the left side, this is from EK's paper comparing lots of different hyper parameters and architectures.

**中文**: 因此，这并非像肥胖那样经过精确实证测量的量。好的。好的。明白了。有一点我需要提醒，我认为这对许多缩放定律研究来说是一个重要的警示：缩放定律在处理对数损失时表现非常良好。我们训练的是下一个令牌预测的交叉熵。当你的缩放定律目标就是这些交叉熵时，效果非常理想。但如果你试图处理下游任务，直接基于基准进行缩放，其行为就难以预测得多。所以，在左侧这里，这是来自EK的论文，比较了许多不同的超参数和架构。

## 段落 53

**英文**: You see that the number of parameters, which in this case is a surrogate for compute, and the negative log. perplexity is very nicely linearly correlated. And what this is basically saying is, well, it doesn't matter what you're like depth or width or precise setting of the hyper parameters are. The only thing that really matters is your total compute expenditure. This is a very simple and nice story. But then you take these models. This was back in 2023. So people were still doing super glue accuracy. And you basically say, OK, but what's the downstream performance of these models? And while now, we don't see a very nice linear relationship anymore. We see this totally different thing,.

**中文**: 你看，参数数量（在这里是计算量的一个替代指标）与负对数困惑度呈现出非常良好的线性相关。这基本上说明，无论你的模型深度、宽度或超参数的具体设置如何，真正重要的是你投入的总计算量。这是一个非常简单而清晰的结论。

但当你把这些模型拿出来看——这是2023年的情况，当时人们还在用SuperGLUE准确率做评估——你会问：那么这些模型的下游任务表现如何呢？这时候，我们就不再看到那种漂亮的线性关系了，而是出现了完全不同的情况。

## 段落 54

**英文**: where certain models are much better than others, and certain architectures are better than others. And so you might not expect exactly this kind of scaling property. And we've seen variants of this story play out in many different places. If you follow the literature on state space models, that's one thing that we've seen. In state space models, we see really nice, predictable scaling, like the ones on the left. But often, for certain capabilities, like in context learning or for QA, people have shown that these models maybe do less well. So it's important to not take this perplexity scaling as the same thing as downstream scaling. And you want to be a little bit cautious. whenever you're doing these kinds of analyses. So maybe this is not surprising to some of you, but hopefully this is surprising and convincing, which is that if you want to make lots of engineering decisions, like hyper parameter choices, architecture decisions, we can do a lot of that before training.

**中文**: 在某些模型中，某些架构明显优于其他选择，因此你可能不会期待完全相同的扩展规律。我们在许多不同领域都见证了类似的情况。以状态空间模型的相关文献为例，这正是我们观察到的现象之一。在状态空间模型中，我们看到了非常理想且可预测的扩展性，就像左侧图表展示的那样。但通常在某些能力上，比如上下文学习或问答任务，研究表明这些模型的表现可能稍逊一筹。因此，重要的是不要将困惑度的扩展等同于下游任务的扩展。在进行此类分析时，我们需要保持一定的谨慎。也许这对一些人来说并不意外，但希望这个发现既令人惊讶又具有说服力——那就是，如果我们想做出许多工程决策，比如超参数选择、架构决策，我们完全可以在训练开始前完成大量准备工作。

## 段落 55

**英文**: We can train these models at small scale across several orders of magnitude compute. And then you scale that up in order to try to predict the behavior of models. So the scaling law-based design procedure is pretty simple. You train a few smaller models. And these smaller models should span a couple orders of magnitude compute. Use establish a scaling law of some kind. So you see that, at least on the models that you trained,. that there's a clear log-log linear relationship. And then based on this prediction, you can set optimal hypermpratters. In many cases, in fact, these scaling laws won't really vary too much.

**中文**: 我们可以在几个数量级的计算规模上训练这些小模型，然后通过放大规模来预测更大模型的行为。基于缩放定律的设计流程相当简单：先训练几个较小的模型，这些模型应覆盖几个数量级的计算量，从而建立某种缩放定律。这样至少在你训练过的模型上，能观察到明显的对数-对数线性关系。基于这种预测，你可以设定最优的超参数。实际上，这些缩放定律在多数情况下不会出现太大偏差。

## 段落 56

**英文**: Their slopes will actually be the same, in which case, sort of the corollary to this is you can just train a few smaller models. And the results of those small models will transfer surprisingly well to larger models in many of these cases, but not all of them. Learning rate being an important exception, for example. So that's how you do things like hyper-primator selection and architecture selection. Now I want to talk about one very important use of scaling laws, one that's had kind of an outsized influence. on how we pick sizes of models, how we think about data efficiency, and so on, of these models. So I think back in the earlier days, when people were beginning to scale up these models, there's a really core question that you need to ask. Do we need more data, or do we need bigger models? In some sense, back in 2021 to 2023 or something, data was way more abundant than compute. So we didn't need to worry about the total data limitations. And so the one limiting resource is compute.

**中文**: 它们的斜率实际上会相同，在这种情况下，可以训练几个较小的模型作为推论。在许多情况下（尽管并非全部），这些小模型的结果能够惊人地良好迁移到更大的模型上，例如学习率就是一个重要的例外。这就是进行超参数选择和架构选择的方法。现在我想谈谈缩放定律的一个非常重要的应用，它对我们在选择模型规模、思考数据效率等方面产生了超乎寻常的影响。回想早期，当人们开始扩展这些模型时，有一个核心问题必须回答：我们需要更多数据，还是需要更大的模型？在某种程度上，大约在2021到2023年左右，数据远比计算资源丰富，因此我们不必担心数据总量的限制，而计算资源才是唯一的限制因素。

## 段落 57

**英文**: Your total number of flops for your training budget, that's kind of the limiting resource. And you can then spend that resource in many different ways. You can spend it on training on lots of data with a small model, or you can train one giant model. on very little data. And both of those extremes seem very wasteful. If you have a teeny tiny model, pumping in tons and tons of data doesn't seem useful. And reverse, if you have a giant model with 10 tokens, also doesn't seem very useful. And so this was sort of a core question for many people. And so they're simultaneously several authors. sort of proposed joint data model scaling laws to try to answer this question.

**中文**: 您的训练预算所对应的总浮点运算次数，这可以说是限制性资源。您可以以多种不同方式分配这一资源。既可以用于训练小型模型处理海量数据，也可以用来训练巨型模型但仅使用极少数据。然而这两种极端方式都显得相当低效。若模型规模极小，即使灌入海量数据似乎也收效甚微；反之，若用巨型模型处理仅10个标记的数据，同样显得不太合理。这成为许多人关注的核心问题。因此多位研究者不约而同地提出了数据与模型规模的联合扩展定律，试图解答这一难题。

## 段落 58

**英文**: And so what are those? I've been talking about scaling laws in essentially one variable exclusively up until this point. And that one variable has varied. It has sometimes been parameters or data or compute. But we've not looked at joint scaling. And so data model scaling laws are things that look like this. These two sort of equations here are both like functionally equivalent to first order and describe the trade off between the amount of data and the amount of models. So the top one from Rosenfeld is basically saying there is a part of the error, one part of it, that decays polynomial in data. There's a part of the error that decays polynomial in the model size. And then there's an irreducible error term that cannot be removed, even if I scale both the data size and the model infinity. Same effect with Kaplan.

**中文**: 那么这些是什么呢？到目前为止，我主要讨论的缩放规律基本上只涉及一个变量。这个变量一直在变化，有时是参数、数据或计算量。但我们还没有研究过联合缩放。因此，数据模型缩放规律大致是这样的。这里的两个方程在功能上大致等效，描述了数据量和模型规模之间的权衡。罗森菲尔德提出的第一个方程基本上是说，误差的一部分随着数据的增加呈多项式衰减，另一部分则随着模型规模的增大呈多项式衰减，然后还有一个不可减少的误差项，即使我将数据规模和模型无限放大也无法消除。卡普兰的方程也有类似的效果。

## 段落 59

**英文**: But here, they're sort of thinking about irreducible error rather than reducible error. And so there's no constant term here. So this seems kind of arbitrary. Because I don't think there's any sort of top down reason why this has to be the correct functional form. But this provides surprisingly good fits to the joint error that you see in data and model. So this is from, I believe, Rosenfeld. They show this nice 3D plot of this is the amount of data. This is the size of the model. And this is the loss on the y-axis. And the surface that's being fit is their functional form.

**中文**: 但在这里，他们考虑的是不可约误差而非可约误差。因此这里没有常数项。这似乎有些随意，因为我认为并没有任何自上而下的理由能说明这必须是正确的函数形式。但令人惊讶的是，它能很好地拟合数据与模型中观察到的联合误差。我记得这是罗森菲尔德的研究成果——他们展示了一个精美的三维图表：横轴是数据量，纵轴是模型规模，而Y轴表示损失值。图表中拟合出的曲面正是他们所提出的函数形式。

## 段落 60

**英文**: The dots are their runs. It might be a little hard to see from the back. But the surface fits the dots almost exactly. And despite the fact that this functional form is kind of ad hoc, like it's pulled out of a hat, it is surprisingly accurate. This one's from Rosenfeld as well, where they basically say,. OK, I'm only going to train on essentially the small half, models that are small and data that is small. So on this left bottom. And I'm going to extrapolate to models that are sort of both large and trained with more models. And how good is that fit of joint extrapolation? Well, quite good. So if you look at the error, my real values.

**中文**: 这些点代表它们的运行轨迹。从后面看可能有点难以辨认。但表面几乎完全贴合这些点。尽管这种函数形式有些随意，像是凭空想出来的，但它却出奇地准确。这个也来自罗森菲尔德，他们基本上是说，好吧，我只打算在较小的那一半上进行训练，即模型小、数据也小的部分。所以在这个左下角。然后我要外推到模型更大、训练数据也更多的情况。这种联合外推的拟合效果如何呢？相当不错。如果你看看误差，我的实际值。

## 段落 61

**英文**: are on the x-axis, my predictions of the error on the y-axis. And they're almost exactly both on image net and on wiki tax. So this seems pretty good. And so for a fixed compute budget, now what can we do? We go back to, for example, a capel. And we see similar things being done here. We see sort of joint scaling of compute and data. So in this case, parameters are on the x-axis,. the colors represent compute. And so there's sort of a third axis of data that's being implicitly varied in order to vary the total amount of compute. So as you go shift on these curves, the parameters are being varied while the compute is being held constant.

**中文**: 位于x轴的是参数数量，y轴是我对误差的预测。无论是在ImageNet还是WikiTax数据集上，两者几乎完全吻合。这看起来相当不错。那么，对于固定的计算预算，我们现在能做什么呢？我们回到，例如，一个图表中。我们看到这里也做了类似的事情。我们看到计算和数据的某种联合缩放。在这个例子中，x轴是参数数量，颜色代表计算量。因此，数据量作为第三个维度被隐含地调整，以改变总计算量。所以，当你沿着这些曲线移动时，参数数量在变化，而计算量保持不变。

## 段落 62

**英文**: And so the amount of data is going to vary. So Chinchilla, I think many of you have hopefully heard of, is probably the reference in solving this problem. So both Rosenfeld and Kaplan came up with this joint scaling functional form. And then both of them noticed that it was possible to use these functional forms to optimize the trade-off between compute and data in various ways. But for various reasons, basically,. it's hard to fit these functional forms precisely in the details, like the learning rate shapes being different are important. And so Kaplan had one estimate that was quite far off from what was later and sometimes validated to be optimal. And so the Chinchilla paper by a bunch of Google authors sort of wasn't attempt to empirically try to nail down what is the right trade-off. between the amount of tokens and the model size assuming that your goal is to get the best model for the smallest amount of trading flops. So they have three different approaches, approach one, two, and three, for basically fitting different curves and making scaling predictions.

**中文**: 因此，数据量会有所不同。我想你们很多人都听说过Chinchilla，它可能是解决这个问题的参考。Rosenfeld和Kaplan都提出了这种联合缩放函数形式。然后他们都注意到，可以利用这些函数形式以多种方式优化计算与数据之间的权衡。但由于各种原因，基本上很难在细节上精确拟合这些函数形式，比如学习率形状的差异很重要。因此，Kaplan的一个估计与后来有时被验证为最优的情况相差甚远。所以，由一群谷歌作者撰写的Chinchilla论文试图通过实证方法来确定在给定计算量（FLOPs）最小的情况下，令牌数量和模型大小之间的最佳权衡。他们采用了三种不同的方法（方法一、二和三），基本上是拟合不同的曲线并进行缩放预测。

## 段落 63

**英文**: These blue dots are the models that they trained. And basically, the lines are predicting. different optimal parameter sizes for different flops. And hopefully, most of you kind of know the Chinchilla ratio, that's something like 20 tokens per parameter. And that comes from exactly this. If you take each of these points and you multiply it by 20, you're going to get roughly the flop. Or sorry, multiply it by 20. You'll get the token count. And so if you multiply the parameters by that, you'll get the flops. The difference between sort of the Kaplan results, which were basically estimating one set of token to parameter ratios and sort of the Chinchilla ones, one of the reasons is because of learning rate schedules, right? We know that we train models with cosine learning rates.

**中文**: 这些蓝点代表他们训练的模型。基本上，线条预测的是在不同计算量下各自的最优参数量。希望你们大多数人都大致了解Chinchilla比例，大约是每个参数对应20个词元。这正是由此得出的结论。如果你取这些点中的每一个，乘以20，大致就能得到计算量。哦不对，乘以20得到的是词元数量。因此，如果将参数量乘以这个比例，就能得到计算量。Kaplan研究结果（基本上估算了一套词元与参数的比例）与Chinchilla结果之间的差异，其中一个原因在于学习率调度策略，对吧？我们知道训练模型时使用了余弦学习率。

## 段落 64

**英文**: So cosine learning rates are going to look something like this. It goes up, and then it comes back down. And then it's going to cool down all the way to a minimum learning rate at your bottom. But one thing about cosine learning rates, that sort of trips everyone up all the time, is you can't truncate them early. For cosine learning rate, you have to sort of go all the way to the end in order to get a valid model. You have to get a cool down phase all the way to the end. If I truncate a model in the middle, this is not the same as starting a model from scratch and training it with a cosine learning rate somewhere in the middle. And this was one of the sort of contributing factors. There were others as well, leading to the Kaplan estimates being pretty far. off from the later sort of more improved estimates provided by the Chinchilla paper.

**中文**: 余弦学习率的变化趋势大致是这样的：先上升，后下降。它会一直冷却到底部的最低学习率。但关于余弦学习率，一个常让人困惑的点是：你不能提前截断它。使用余弦学习率时，必须完整运行到结束才能得到有效的模型——必须经历完整的冷却阶段直至终点。如果在中途截断模型，这并不等同于从头开始训练模型并在中途某处使用余弦学习率。这也是影响因素之一，当然还有其他因素，共同导致卡普兰的估算结果与后来《Chinchilla论文》提供的更精确估算相差甚远。

## 段落 65

**英文**: So what do the Chinchilla authors actually do? Well, they have three different methods of trying to estimate the optimum trade off between tokens to models. And each of these methods are going to sort of provide different scaling coefficients, right?. Scaling coefficients for the model size and scaling coefficients for the data size. And kind of surprisingly, in this case, they're getting 0. 5 on both of these for methods 1 and 2. And method 3 is providing pretty different or slightly different estimates. They're about off by 0. 03. But we'll talk about that a little bit later. Kaplan at all, you see, is way off than any of the three estimates, right? So we'll go over each of these methods.

**中文**: 那么，Chinchilla 的作者们究竟做了什么？他们采用了三种不同的方法来尝试估算模型规模与数据量之间的最优平衡点。每种方法都会得出不同的缩放系数，对吧？也就是模型规模的缩放系数和数据规模的缩放系数。有点令人惊讶的是，在方法1和方法2中，他们得出的这两个系数都是0.5。而方法3给出的估计值则相当不同，或者说略有差异，大约相差0.03。这一点我们稍后再详细讨论。你看，Kaplan等人的结果与这三种方法中的任何一个都相差甚远，对吧？接下来我们将逐一探讨这些方法。

## 段落 66

**英文**: Each of these makes sense. They make sort of different assumptions about scaling. But they end up with very, very similar estimates at the very end here. So method 1 on Chinchilla is to basically take the minimum. over curves. And so what does that mean? Well, you basically overlay all of the different training curves that you have. So you can see here on the x-axis is different flops. On the y-axis is sort of the training loss. And I have models trained at many different sizes. And of course, each of these sizes.

**中文**: 每一种方法都有其道理。它们对规模扩展做出了不同的假设。但最终在这里得出了非常非常相似的估算结果。Chinchilla的第一种方法基本上是取曲线上的最小值。这是什么意思呢？实际上就是将你拥有的所有不同训练曲线叠加在一起。可以看到，x轴代表不同的浮点运算次数，y轴则是训练损失。我训练了多种不同规模的模型，当然，每种规模都有对应的曲线。

## 段落 67

**英文**: are going to be trained with different amount of tokens. And so they're going to reach a different total flop, as I sort of go through training. Now, what I'm going to do is I'm going to look at the lower envelope. The set of points or checkpoints that prove to be optimal under any compute budget. And I can take these models and I can look at,. OK, what were the actual parameter sizes of these models? And you can see that sort of the total compute on the x-axis here and the number of parameters, as well as the corresponding tokens, all forms a relatively nice scaling law. And so this is kind of the minimum envelope method. It's basically saying, I expect the minimum training loss where I optimize over all the model sizes. to actually be optimum in flops. And sort of to call back to some earlier papers, right? If you look back at the earlier sort of capplin paper and other scaling laws, you see exactly this already being done.

**中文**: 将使用不同数量的标记进行训练。因此，随着训练的进行，它们将达到不同的总浮点运算量。现在，我将要做的是观察下包络线，即那些在任何计算预算下都被证明最优的点或检查点的集合。我可以选取这些模型并观察，它们的实际参数规模是多少？你可以看到，这里的x轴上的总计算量、参数数量以及相应的标记数，都形成了一个相对良好的缩放规律。这就是所谓的最小包络方法。基本上，它表明，在所有模型规模上进行优化时，我期望最小训练损失在浮点运算量上达到最优。回顾一些早期的论文，如果你回顾早期的卡普林论文和其他缩放规律，你会发现这已经被实践过了。

## 段落 68

**英文**: You see different models being trained with different sort of parameters and different compute scales. And we're taking sort of the minimum across these. And we've already seen that the minimum forms of scaling law. So this is building on this observation that the minimum across many different training curves across compute should form a power line. So under that assumption, you can get fairly nice fits. And this gives one estimate that is quite consistent. with others of 0. 5. Now the other one, this I think, if you were to pick a single canonical way to do the chinchilla analysis, this would probably be the one. And in some ways, I think this is the most conceptually straightforward one, which is the isoflop analysis.

**中文**: 你看到不同的模型以不同的参数和计算规模进行训练。我们取这些训练过程中的最小值。我们已经观察到，这些最小值形成了缩放定律。因此，这是基于一个观察：在不同计算规模下的许多训练曲线中，最小值应形成一条幂律线。在这一假设下，你可以得到相当不错的拟合结果。这给出了一个与其他估计相当一致的估计值：0.5。另一种方法，我认为，如果要选择一种标准方式来进行金丝雀分析，这可能是首选。在某些方面，我认为这是概念上最直接的方法，即等计算量分析。

## 段落 69

**英文**: So to do the isoflop analysis, what you do is you pick a bunch of compute scales. So each of these colors is a different amount of compute. And what I'm going to do is for each of these compute scales, I can essentially have models with smaller parameters trained with more data or more parameters trained with less data. So I'm going to sweep over my sort of model sizes for each of these flops. And then I can look at the minimum of each of these curves. I can either pick the minimum point explicitly, sort of non-parametrically, or I could fit quadratics onto each of these and get the minimum point of the quadratic. But in either case, sort of the argument is fairly simple. The argument is, I should be the case that this minimum itself follows a predictable scaling. law. And thus, I can extract from it sort of the optimum parameters per flop.

**中文**: 因此，要进行等浮点运算分析，你需要选取一系列计算规模。这里的每种颜色代表不同的计算量。对于每个计算规模，我基本上可以训练参数较少但数据较多的模型，或者参数较多但数据较少的模型。所以，我会针对每个浮点运算规模，遍历不同的模型大小。然后，我可以观察这些曲线的最低点。我可以直接非参数化地选择最低点，也可以为每条曲线拟合二次函数，然后找到二次函数的最低点。但无论哪种情况，其原理都相当简单。原理在于，这些最低点本身应该遵循可预测的缩放规律。因此，我可以从中提取出每个浮点运算下的最优参数数量。

## 段落 70

**英文**: So that's the minimum points across all of these. And I can also extract the optimal number of tokens per flop. I can read that out by sort of dividing my flops budget by the number of parameters. So I can get those simultaneously. And you can see that once again, this gives very clean sort of results that are consistent with method 1. So we can compare that with before this says, for the eventual Chinchilla model budget, you want 63 billion parameters. This one's the 67 billion parameters. The two are quite close. OK. The last one, honestly, is just a little bit messier.

**中文**: 这就是所有方案中的最低点。同时，我还能推算出最优的每浮点运算次数对应的词元数量。只需将浮点运算预算除以参数数量即可得出，两者可以同步计算。可以看出，这种方法再次得出了非常清晰的结果，且与方法一的结论一致。我们可以将其与之前的数据对比：根据最终Chinchilla模型的预算，之前建议使用630亿参数，而这次是670亿参数，两者相当接近。至于最后一种方法，说实话，结果稍微有些杂乱。

## 段落 71

**英文**: And this goes back to that Rosenfeld paper. If you have a functional form, like this one, like this, from Rosenfeld, a very natural instinct is to say, I'm just going to train a bunch of models varying both n and n, and I'm just going to do curve fitting. I'm going to fit this curve onto whatever I get, the thing I get out of my models. So I'm going to train a bunch of models and fit that 3D shape. And we know from Rosenfeld, it's reasonable to some extent to fit these. So you've got all these dots, which are the models. I fitted a curve, that's this sort of heat map color that you see on the left. And then you can sort of back out what the implied isoflops. should look like from these dash lines. But if you look at this, hopefully you see that the scaling law fits, and the curve fits here, are just not quite as good as the fits in the other plots.

**中文**: 而这要追溯到罗森菲尔德的那篇论文。如果你有一个函数形式，比如这个，像罗森菲尔德提出的那样，一个非常自然的直觉是：我只需要训练一系列模型，同时改变n和n，然后进行曲线拟合。我会把这个曲线拟合到我得到的任何结果上，也就是从我的模型中得出的数据。所以我会训练一堆模型，并拟合那个三维形状。从罗森菲尔德的研究中我们知道，在某种程度上拟合这些是合理的。所以你有了所有这些点，它们代表模型。我拟合了一条曲线，就是你在左边看到的这种热图颜色。然后你可以从这些虚线中大致推导出隐含的等计算量曲线应该是什么样子。但如果你仔细看，希望你能发现这里的缩放律拟合和曲线拟合，并不像其他图表中的拟合那样理想。

## 段落 72

**英文**: And if you look at the coefficients, the Tintilla method 3 just gives way different estimates in terms of the model size and total token count than the others. And actually, this was a mystery to me for a long time, I think, so my students were like, why is method 3 so different? And I said, I don't know. Maybe scaling laws are just sometimes noisy. I don't know how many of you know this. But this is a really fun trivia fact, or not trivia fact, fun piece of trivia, let's say. So last year, some folks at Epoch AI, I don't know what motivated them to do this, were curious enough about this result that they went and tried to replicate method 3. And it was very difficult to replicate it, because you don't have the original data for all these training runs. So they actually went to the extreme of actually looking. at the plots and using sort of a forensic tool to extract the values of the points from the plots. And based on that, they could actually replicate the original result.

**中文**: 如果你查看系数，Tintilla方法3在模型规模和总标记数方面给出的估计与其他方法大相径庭。实际上，这个问题困扰了我很久，我的学生也问过，为什么方法3如此不同？我回答说，我不知道。也许缩放定律有时就是存在噪声。我不知道你们中有多少人了解这一点。但这是一个非常有趣的冷知识，或者说不是冷知识，而是一段有趣的轶事。去年，Epoch AI的一些人——我不知道他们为何对此感兴趣——对这个结果充满好奇，于是尝试复制方法3。复制过程非常困难，因为没有所有这些训练运行的原始数据。因此，他们甚至采取了极端措施，仔细查看图表，并使用类似法医工具的方法从图表中提取数据点的值。基于这些数据，他们最终成功复制了原始结果。

## 段落 73

**英文**: And kind of the funny thing is they showed that actually the curve fitting was the bad part. Like their data and their approach was good. But actually, when they fit the curve,. they didn't necessarily do it right. And so the original fit had residuals. If you're familiar with regression, your residual should be zero mean centered, because otherwise, you should be offsetting your predictions to make it zero center. Their residuals are non-zero, and then they fit it better. And then when they did fit it better, well,. actually, their optimal estimate almost exactly matched methods 1 and 2. And so this is one of those funny cases where actually, the original authors had both the idea and the data right.

**中文**: 有趣的是，他们发现问题的症结其实在于曲线拟合部分。他们的数据和实验方法本身是可靠的，但在进行曲线拟合时，处理方式可能存在偏差。最初的拟合结果存在残差——熟悉回归分析的人会知道，残差理论上应以零为中心分布，否则就需要调整预测值以实现零中心化。而他们的残差并未满足这一条件。后续改进拟合方法后，他们得出的最优估计值几乎与方法1、方法2的结果完全吻合。这成了一个耐人寻味的案例：原作者的研究思路和原始数据其实都是正确的。

## 段落 74

**英文**: But because of a minor issue in curve fitting, they had kind of had it wrong. And the replication actually makes it more correct. than before. Usually, replication sort of disproof things. But in this case, actually, the replication just showed that the original result was correct all along, which is, I think, a pretty cool result. OK, so the final thing I want to talk about with kind of this set of chinchilla results is, we're talking about training optimal scaling. So you have a fixed flops budget. I want the best possible model possible. But really, I think the story has really shifted. When chinchilla was written and the Kaplan paper was written, LLMs were not really a product yet.

**中文**: 但由于曲线拟合中的一个小问题，他们之前的理解有些偏差。而重复实验实际上让结果变得更加准确。通常，重复实验往往会推翻原有结论，但在这个案例中，重复实验恰恰证明了原始结果自始至终都是正确的——我认为这是个相当酷的发现。好了，关于这组"栗鼠"实验的最后一点是：我们讨论的是训练最优规模的问题。假设你有固定的计算预算，想要获得尽可能最好的模型。但事实上，我认为整个叙事已经发生了转变。在《栗鼠》论文和卡普兰论文发表的时代，大语言模型还称不上是真正的产品。

## 段落 75

**英文**: And so really, the name of the game was everyone wanted the most biggest, flashiest, most intelligent model. But they didn't care about the inference cost of actually deploying these systems. But nowadays, what we really care about is inference costs, because these systems are actually products. They generate revenue. You have a cost associated with the revenue. And so we've seen over time that actually the tokens per parameter has steadily grown. Like GPT-3 was two tokens per parameter. Chinchilla moved us to 20 tokens per parameter. And for a bit, people played around with sort of 20 tokens per parameter stuff. But then, very quickly, people realized, actually, what we care about is really good intelligence at really small parameter sizes.

**中文**: 因此，实际上，游戏规则是每个人都想要最大、最炫、最智能的模型。但他们并不关心实际部署这些系统所需的推理成本。然而如今，我们真正关心的是推理成本，因为这些系统实际上是产品。它们能产生收入，而收入背后伴随着成本。随着时间的推移，我们看到每个参数对应的令牌数稳步增长。比如GPT-3是每个参数对应2个令牌，而Chinchilla模型将这一数字提升到了20个令牌。有一段时间，人们围绕着每个参数20个令牌的模式进行探索。但很快，大家意识到，我们真正需要的是在极小的参数规模下实现出色的智能。

## 段落 76

**英文**: And so people have really started to scale up. the number of tokens per parameter very, very rapidly. And I think I saw yesterday that, for example, the most recent Qem models were trained on 30 trillion tokens. People are really pushing the limits on the tokens to parameter ratio, because really, you would much rather pay the upfront cost than to pay the ongoing operating cost of running inference on a really big, expensive model. Cool. Last thing that is kind of a fun side thing that I want to end with is to say, these results are pretty robust and easy to replicate. A few years back, one of my students, Ishan, was really interested in really pushing diffusion models for text forward. And so one of the things that we had to do was to say, this is a whole new kind of model. We don't know what the optimal token to parameter ratio is. We don't know if this thing even reliably scales the totally different kind of generative model.

**中文**: 因此，人们确实开始迅速扩大每个参数对应的标记数量。我记得昨天看到，例如最新的Qem模型是在30万亿个标记上训练的。人们正在真正挑战标记与参数比例的极限，因为实际上，人们更愿意支付前期成本，而不是为一个庞大而昂贵的模型持续支付推理运行的操作成本。最后，我想以一个有趣的话题结束：这些结果非常稳健且易于复现。几年前，我的学生伊山对推动扩散模型在文本领域的应用非常感兴趣。我们当时必须面对的一个问题是，这是一种全新的模型类型。我们不知道标记与参数的最佳比例是多少，甚至不确定这种完全不同的生成模型是否能够可靠地扩展。

## 段落 77

**英文**: What do we do? Well, turns out, if you just fit the same kind of playbook of saying, oh, we're going to do ISO flop analyses for autorescive models. We get almost exactly the chinchilla thing. without too much effort. You do the same kind of analysis on diffusion models. Wow, we see very similar kinds of curves, even though it's a pretty different generative model entirely. And then if you plot the minimum across of these, well, you see very predictable scaling for both separated by a constant offset. I don't bring this up to say, because I want to particularly push to you diffusion models, but just as a really random case study or example to say these scaling laws don't necessarily need to be these very cherry-picked examples, they seem to happen pretty naturally as you're working on new models or working on new environments. This is to put together this last part. Loglinearity is not just about one-dimensional things where we think about data. They extend to model parameters.

**中文**: 我们做什么呢？其实很简单，只需套用类似的思路：比如，我们可以为自回归模型进行ISO浮动分析。结果几乎完全符合Chinchilla的规律，而且并不费力。对扩散模型进行同样的分析，哇，尽管这是完全不同的生成模型，我们却看到了非常相似的曲线。接着，如果你把这些曲线的最低点绘制出来，会发现两者呈现出非常可预测的缩放规律，仅被一个常数偏移量分隔。我提到这个，并不是特别想推广扩散模型，而是作为一个随机的案例研究，说明这些缩放规律并不一定需要精心挑选的例子，它们似乎在你研究新模型或新环境时自然而然地出现。这就是最后一部分要总结的：对数线性不仅仅适用于我们考虑数据的一维情况，它们也延伸到了模型参数中。

## 段落 78

**英文**: They extend to total compute. And so that lets us make all sorts of hyper parameter in other decisions. That's this first part. And they're also letting us make really smart resource. trade-offs. They let us make trade-offs between big models versus more data. And we saw that in chinchilla analysis. And it's remarkable how cleanly things like the ISO flop analysis turn out. So all right. That's all I got for basic data scaling lost.

**中文**: 它们扩展到了总体计算能力。这让我们能够在超参数和其他决策中做出各种选择。这是第一部分。同时，它们也让我们能够做出非常智能的资源权衡。它们让我们可以在大模型和更多数据之间进行权衡。我们在Chinchilla分析中看到了这一点。令人瞩目的是，像ISO浮点运算分析这样的结果竟然如此清晰。好了，这就是我在基础数据缩放损失方面的全部内容。

## 段落 79

**英文**: We did a recap of Kaplan as well as chinchilla today. And hopefully now you're on board with this idea of data scaling, model scaling, and using scaling loss to optimize all the aspects of your model without actually going all the way to the large scale training runs. Thanks, and I'll see you all Thursday.

**中文**: 今天我们回顾了卡普兰和龙猫模型。希望现在你们能理解数据缩放、模型缩放以及使用缩放损失来优化模型各个方面的理念，而无需实际进行大规模训练。谢谢，周四见。

---

*共 79 个段落，783 句话*
