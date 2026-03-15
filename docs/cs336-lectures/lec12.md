# Lecture 12： Evaluation

生成时间: 2026-03-08 22:50:40

---

## 段落 1

**英文**: Let's get started. Today we're going to talk about evaluation. This is one of these topics that I think looks simple but actually as far from it. Mechanically it's just given a fixed model. Ask the question how good is it? So things pretty easy enough. And if you think about evaluation you probably see a lot of things such as benchmark scores. So for example, papers that put out language models, put out some benchmarks scores on various benchmarks like MMLU,. Amy, code forces. Here's a lot of four paper. They evaluate on MMLU Pro, Math 500, GPU UA, at least for language.

**中文**: 我们开始吧。今天我们要讨论的是评估。这是一个看似简单、实则远非如此的话题。从机械层面来看，它只是针对一个固定模型，提出“它有多好？”这个问题，因此看起来相当简单。当你想到评估时，你可能会看到许多内容，例如基准测试分数。例如，发布语言模型的论文会在各种基准测试（如MMLU、AMC、CodeForces）上给出一些基准测试分数。在很多论文中，它们至少针对语言模型，在MMLU-Pro、Math-500和GPQA等基准上进行了评估。

## 段落 2

**英文**: And then there's some multi-modal stuff. If you look at OMAL, it's kind of Math MMLU. And then some other things I drop and just I'm OK. And so on. And see all these numbers. Most language models are evaluated on roughly the same benchmarks but not quite. But what are these benchmarks? And what are these numbers actually mean? So here is another example from Helm where we have a bunch of different standard benchmarks which are all collated together, which is something we'll talk about a little bit later. There's also benchmarks that look at their costs, not just the accuracy score. So artificial analysis is this website that does I think a fairly good job of looking at these Pareto Frontiers, where they have this intelligence index which is basically a combination of different benchmarks. And then a price that you would have to pay Paretockin to use that model.

**中文**: 此外，还有一些多模态相关内容。例如，OMAL 类似于数学领域的 MMLU（大规模多任务语言理解）基准测试。其他一些内容我则略过不提，这样就可以了。诸如此类。再来看这些数字：大多数语言模型虽大致在相同的一组基准测试上进行评估，但并非完全一致。那么，这些基准测试究竟是什么？这些数字又实际代表什么含义？这里以 HELM（Holistic Evaluation of Language Models，语言模型整体评估）中的另一个示例为例：其中汇集了大量不同的标准基准测试，这一整合方式我们稍后会进一步讨论。此外，还有一些基准测试不仅关注准确率得分，还考察模型的使用成本。例如，“人工分析”（Artificial Analysis）网站便对帕累托前沿（Pareto Frontiers）进行了相当深入的分析——该网站构建了一个“智能指数”，本质上是多种基准测试结果的综合；同时还列出了使用相应模型所需支付的价格（即帕累托成本）。

## 段落 3

**英文**: And of course, over three years were really good but it's also really expensive. And apparently I guess some of these other models actually accord to this index are at least as good and much cheaper, it seems. And maybe another way to look at it is a model is good if people choose to use it. So open router is this website that essentially has traffic that gets routed to a bunch of models. So they have data on which models people are choosing. And so if you just look at the number of tokens that are sent to each model, you can define a leaderboard. And you can sort of take a leap of faith and assume that people are choosing the models that are good. So according to this, then open AI and Thwapik and Google seem to be at the top. Here's another one, Chapada Rina, which I think is very popular. I'll talk a little bit more about this but yeah, it's another ranking between models where people on the internet have conversations with these models and express their pairwise preferences.

**中文**: 当然，三年期的模型性能确实非常出色，但价格也相当昂贵。显然，据我推测，其他一些模型依据该指数评估，至少同样优秀，且成本要低得多。或许我们还可以换一种思路：如果人们愿意选用某个模型，那它就是好模型。OpenRouter 是一个网站，其本质是将流量路由至多个模型。因此，他们掌握着用户选择哪些模型的数据。只需查看发送给每个模型的 token 数量，即可构建一份排行榜。我们可以姑且相信，用户选择的正是表现优异的模型。据此来看，OpenAI、Anthropic（应为原文“Thwapik”之误）和谷歌似乎位居榜首。再看另一个模型——ChatGLM（应为原文“Chapada Rina”之误），我认为它非常受欢迎。稍后我会进一步介绍它。此外，还有一种模型排名方式：网友与这些模型展开对话，并表达自己对不同模型两两之间的偏好。

## 段落 4

**英文**: So there's a lot of numbers and rankings that I'm just kind of throwing at you. And then you see these vibes where people post on X. Hey, look at this awesome example of something that a language model can do. There's a lot of these examples out there. So that's another source of data on how good models are. But really, I think Andre Kavathi did a good job of assessing the current situation, which is that there is an evaluation crisis. There are some benchmarks like MMOU, which apparently were a good to look at. But now the underlying assumption is that maybe they have been either a saturated or a game or something in between. And then there's problems with the Chapada Rina, which we'll talk about a little bit later. And so really, we have all these models.

**中文**: 因此，我向你们抛出了大量数字和排名。接着，你们会在X平台上看到这类帖子，人们纷纷晒出语言模型的精彩表现：“快看，这语言模型多厉害！”诸如此类的例子比比皆是。因此，这也是评估模型性能的另一类数据来源。但事实上，我认为安德烈·卡瓦蒂（Andre Kavathi）对当前状况的评估颇为到位——我们正面临一场评估危机。某些基准测试（如MMOU）曾一度被视为可靠的参考指标，但如今人们普遍认为，这些基准可能已趋于饱和、被过度优化，或介于两者之间。此外，查帕达里纳（Chapada Rina）基准也存在诸多问题，我们稍后会进一步讨论。总而言之，目前我们手头拥有大量模型。

## 段落 5

**英文**: We have this plethora of benchmarks and numbers that are coming out. And it's sort of unclear, I think, at this point, which are the right way to do evaluation. You know there's a pattern in this class where everything is kind of messy. And the evaluations know different. OK, so in this class, I want to talk a little bit how you wish to think about evaluation. And then I'm going to go through a bunch of different benchmarks and talk about a few issues with benchmarks. OK, so evaluation at some level is just a mechanical process. You take an existing model. You don't really worry about how it was trained. And then you throw prompts at it.

**中文**: 我们目前涌现出大量基准测试和相关数据。但坦率地说，现阶段尚不清楚哪些评估方式才是正确的。你们可能已经注意到，本课程中存在一种现象：所有内容都显得有些混乱，而评估方法更是五花八门、各不相同。  
好的，本课程中，我想先简要谈谈大家应如何思考评估问题；随后，我将逐一介绍若干不同的基准测试，并探讨其中存在的若干问题。  
好的，从某种层面来看，评估本质上只是一种机械性流程：你选取一个现有模型，无需过多关注其训练过程，然后向它输入各类提示（prompts）。

## 段落 6

**英文**: You get some responses, you compute some metrics, and you average the numbers. So it seems like a kind of a quick script that you can write. But actually, evaluation is really kind of a profound topic. And it also determines how language models are going to be built. Because people, build these evaluations, and the top language model developers are tracking these over time. And if you track something and you're trying to get your number to go up, it's going to really influence the way that you develop your model. So that's why evaluation, I think, is really sort of a maybe a leading indicator of where things are going to go. OK, so what's the point of evaluation? Why do we even do it? So the answer is that there is no one true evaluation. It depends on what question you're trying to answer. And this is an important point, because there's no such thing as, oh, I'm just evaluating a model.

**中文**: 你会获得一些响应，计算若干指标，并对这些数值取平均。因此，这看起来像是一个可以快速编写的小脚本。但实际上，评估本身是一个极为深刻的话题，同时也决定了语言模型的构建方向。因为人们会设计这些评估方法，而顶尖的语言模型开发者会持续追踪这些指标的变化。一旦你开始追踪某项指标并努力提升其数值，这将深刻影响你模型的开发方式。因此，我认为评估或许可被视为一种预示未来发展趋势的先行指标。那么，评估的意义何在？我们为何要进行评估？答案是：并不存在唯一“正确”的评估方式，它完全取决于你试图回答的问题。这一点至关重要，因为并不存在所谓“我只是在评估一个模型”这种脱离具体目标的抽象评估。

## 段落 7

**英文**: You get a number, but what does that number tell you? And does it actually answer your original question? So here are some examples of what you might want to do. So suppose you're a user or a company and trying to make a purchase decision. So you can either use Claude, or you can use Grock, or you can use Gemini, or O3. And which one should you choose for your particular use case? Another is that your researcher, you're not actually trying to use the model for anything. You just want to know what are the raw capabilities of the model. Are we making scientific progress on an AI? So that's a much more general question. That's not anchor to any particular use case. And then policy makers, and businesses might want to just understand objectively at a given point in time, what are the benefits and harms of a model? Where are we? What are models giving us telling us the right answer? How are they helping? How much value are they delivering? Model developers might be doing a variation, because they want to get feedback to improve the model. They might evaluate and see, oh, this score is too low. So let's try an invention.

**中文**: 你得到了一个数值，但这个数值究竟说明了什么？它真的能回答你最初提出的问题吗？以下是一些你可能希望实现的目标示例：  
假设你是一名用户或一家企业，正试图做出采购决策——你可以选择使用Claude、Grock、Gemini或O3，那么针对你的具体应用场景，究竟该选择哪一款模型？  
另一种情况是，你是一名研究人员，并非打算实际应用该模型，而只是想了解模型本身的原始能力，即：我们在人工智能领域是否取得了科学进展？这是一个更为宽泛的问题，不与任何特定应用场景挂钩。  
此外，政策制定者和企业可能仅希望在某一特定时间点，客观地了解某款模型所带来的益处与危害：当前我们处于何种阶段？模型给出的答案是否正确？它们如何提供帮助？又创造了多大价值？  
而模型开发者则可能开展变体评估，因为他们需要获取反馈以改进模型：他们可能通过评估发现，“这一得分过低”，于是尝试引入某种创新方法。

## 段落 8

**英文**: And it goes up, therefore we keep the intervention. So this is used, a version is often used in the development cycle of language models as well. So in each case, there is some goal that the evaluator wants to achieve. And this needs to be translated into a concrete evaluation. And the concrete evaluation you choose will depend on what you're trying to achieve. Okay. So in evaluation, there's a simple framework you can think about. So what are the inputs, the prompts? How do you call the language model? And then once the language model produces outputs, how do you assess the outputs? And then how do you interpret the results? So let's look at each of these questions. So the inputs. So where do you get the set of prompts? Which use cases are covered by your prompts?.

**中文**: 而且其数值会上升，因此我们保留该干预措施。此方法（或其某种变体）也常被用于语言模型的开发周期中。在每种情况下，评估者都希望达成某个特定目标，而这一目标需转化为具体的评估任务。所选择的具体评估方式取决于你试图实现的目标。  
好的，那么在评估过程中，你可以参考一个简单的框架：输入（即提示语）是什么？如何调用语言模型？当语言模型生成输出后，又该如何评估这些输出？最后，如何解读评估结果？  
下面我们逐一探讨这些问题。首先是输入：提示语集从何而来？你的提示语覆盖了哪些应用场景？

## 段落 9

**英文**: That's a question. Do they have representation of the tails? Do they have difficult inputs that challenge a model? Or are they sort of vanilla easy cases that any language model would be able to do? And then finally, in the multi-turn chatbot setting, the inputs are actually dependent on the model. So that introduces in complication. And even in the single-turned-transcending, you might be wanting to choose inputs that are tailored to the model as well. So the question of inputs. And then how do you call a language model? So there's many ways to prompt a language model. You can do a few shots, zero shot, chain of thought. And we'll see that each of these decisions actually introduces a lot of variance into how the evaluation metric. So language models are still very sensitive to the prompt, which means that evaluation needs to take that into account. And the particular type of strategy you're using is something that you have to decide whether you have tool use for arithmetic, or you're able to do rag, if or use a tool, if you are doing some sort of recent knowledge query.

**中文**: 这是一个问题：测试集是否涵盖了分布尾部的样本？是否包含能对模型构成挑战的困难输入？还是仅仅是一些任何语言模型都能轻松处理的普通简单案例？此外，在多轮对话机器人场景中，输入实际上依赖于模型自身，这进一步增加了评估的复杂性；甚至在单轮问答场景中，你也可能希望选择针对特定模型定制的输入。因此，输入的选择本身就是一个关键问题。  
其次，如何调用语言模型？目前有多种提示方法，例如少样本提示（few-shot）、零样本提示（zero-shot）以及思维链（chain-of-thought）等。我们将看到，每一种提示策略都会显著影响评估指标的结果。语言模型对提示仍极为敏感，这意味着评估过程必须将提示方式纳入考量。此外，你所采用的具体策略类型——例如是否支持工具调用以执行算术运算、是否采用检索增强生成（RAG），或是否借助外部工具来回答时效性较强的问题——也都需要事先明确决定。

## 段落 10

**英文**: And finally, as I think we'll talk about agents a little bit later,. is, are we even evaluating what is the object of evaluation? Are we evaluating a language model, or are we evaluating the whole system? And this is also an important distinction, because the model developer might want to evaluate the former, because they're trying to make their language model better, and the agentic system and the scaffolding is just a means to drive the metric. But the user doesn't care what you're doing with what language model you're using. There might be multiple language models. They just care about the system as a whole. And then finally, the outputs. How do you evaluate outputs? Often you have reference outputs. And are these clean? Are they are free? Very basic question, but we'll see later that that's not obviously the case. What metrics do you use for co-generation as a passat one? Is a passat 10? Do you factor into how do you factor into the cost?. Because you see a lot of the leaderboards, the cost is kind of marginalized the way.

**中文**: 最后，正如我们稍后会讨论到的关于智能体（agents）的内容一样，一个关键问题是：我们究竟在评估什么对象？我们是在评估语言模型本身，还是在评估整个系统？这一区分同样至关重要。模型开发者可能更关注前者，因为他们致力于提升语言模型本身的性能，而智能体系统及其架构设计仅是推动评估指标提升的一种手段；但用户并不关心你使用了何种语言模型，甚至可能涉及多个语言模型——他们只关注整个系统的最终表现。最后是输出结果的评估：如何评估输出？通常我们会采用参考输出作为基准，但这些参考输出是否规范、是否无偏？这看似是个非常基础的问题，但我们后续会看到，实际情况往往并非如此显然。对于协同生成（co-generation）任务，应采用何种评估指标？“通过率”（pass rate）是否就是唯一标准？若采用通过率，其阈值应设为10%吗？此外，成本因素又该如何纳入考量？因为目前许多排行榜都倾向于弱化甚至忽略成本这一维度。

## 段落 11

**英文**: So you don't have a sense of maybe the top model is actually 10 times more expensive than the second model, for example. And that's why Pareto Frontiers are generally good to look at. And obviously in some use cases, not all errors are created equal. And how do you incorporate that into your evaluation criteria? And opening in generation is obviously tricky to evaluate, because there's no ground truth. You're doing some text, you know, Rimeo, compelling story about Stanford. You know, that's how do you evaluate that?. That's. So suppose you get through all those. Now you have the metrics. And how do you interpret it? So suppose you get a 91 number.

**中文**: 因此，你可能并不清楚顶级模型的价格实际上可能是次级模型的10倍，例如。这正是帕累托前沿（Pareto Frontiers）通常值得参考的原因。显然，在某些应用场景中，并非所有错误都同等重要；那么，你又该如何将这种差异纳入评估标准呢？此外，生成式任务（如开放式文本生成）的评估显然颇具挑战性，因为其不存在明确的“标准答案”。比如，你生成了一段关于斯坦福大学的、富有创意且引人入胜的文字——你又该如何评估它呢？假设你已成功应对了上述所有难题，现在得到了各项评估指标。那么，你又该如何解读这些指标呢？例如，假设你得到一个91分。

## 段落 12

**英文**: Is that, does that mean it's good? Does that, if you're your company and you deploy to your users, is that good enough? How do you determine, if you're, let's say, your researcher,. has this language model really learned particular types of, you know, generalization? And this allows, this requires us to confront the issue of train tests overlap. And then finally, we'll talk a little bit about how, again, what is object of the evaluation? Is it the model or the system, or is it actually the method? So often in research, the output of the research paper is a new method for doing something. It's not necessary in the model. The model is just an example application of a method. So if you're evaluating the method, then I think many of the actual evaluations that people do. don't really make sense unless you have clear controls on what you're doing. So in summary, there's a lot of questions to actually think through when you're doing evaluation. It's not just take a bunch of prompts and feed into a language model. Yeah, question.

**中文**: 这是否意味着它很好？如果你是某家公司，并将模型部署给用户使用，这样就够好了吗？如果你是一名研究人员，又该如何判断该语言模型是否真正掌握了某种特定类型的泛化能力？这就迫使我们直面训练集与测试集重叠的问题。最后，我们还将简要探讨一下：评估的对象究竟是什么？是模型本身、整个系统，还是实际的方法？在研究中，论文的产出往往是一种新方法，而非模型本身；模型只是该方法的一个示例应用。因此，若评估对象是方法本身，那么当前许多实际开展的评估工作，除非对所做之事有明确的控制条件，否则其实并无太大意义。总之，在进行评估时，有许多问题需要深入思考——评估绝非简单地收集一堆提示词并输入语言模型即可。好，有问题吗？

## 段落 13

**英文**: So question is, should the inputs be adapted to the model? Again, this depends on what you're trying to do. So in some cases, like the multi-turn, they have to be adapted to the model. I think it's not realistic to have a static chat bot evaluation where you have user assistant, user assistant, but the assistant is someone else and you're meant to respond. Because you might be putting in a kind of a weird spot that you would never get into if you were driving the conversation. In red teaming, it's helpful to adapt the evaluation to the model because you're looking for these very rare tail events and you're just going to be very inefficient if you're just generically generating prompts. But of course, when you adapt your evaluation to the model, now how do you compare it between. different models? So there's a trade-off there. Any other questions on this kind of broad conceptual level? For redibons and details? Yeah. There's something that we've relied on so far as that for quite some reasons to be informative about a lot of capabilities, as it might be. It's a good question.

**中文**: 那么问题来了：输入是否应当适配模型？同样，这取决于你的具体目标。例如，在多轮对话场景中，输入就必须适配模型。我认为，采用静态的聊天机器人评估方式（即用户—助手—用户—助手……，其中“助手”实为他人，而你需代其回应）并不现实。因为在这种设定下，你可能陷入一种在真实主导对话时根本不会遇到的尴尬境地。在红队测试中，将评估方法适配模型则很有帮助，因为你旨在发现那些极为罕见的尾部事件；若仅泛泛地生成提示词，效率将极其低下。但当然，一旦你将评估方法适配于特定模型，又该如何在不同模型之间进行横向比较呢？这里就存在一种权衡取舍。关于这种宏观概念层面的问题，大家还有其他疑问吗？关于可复现性及细节方面？是的。到目前为止，我们一直依赖某种方法，而该方法基于诸多原因，可能对评估大量能力具有信息价值。这是一个很好的问题。

## 段落 14

**英文**: Yeah. All these capabilities are really interesting. The natural language setting, perfect. And like, set to these questions that don't have that strong relationship that don't seem to be improving as we put complexity or that somewhat generally. And not to convince yourself that you're going to put some group in. Yeah. So the question is, is proplexity all you need?. Or are there some things that aren't captured by proplexity? So that's actually a good segue to talk about proplexity. But to answer your question more directly, so Tatsu showed a slide, I think last, maybe last lecture, that was looking at the correlation between proplexity and downstream task performance. And it was sort of all over the place, at least in that setting.

**中文**: 是的，所有这些能力确实非常有趣。自然语言设定，非常完美。而且，针对那些彼此之间关联性不强、即使增加复杂度也似乎并未得到改善，或总体上表现不佳的问题。你也不必说服自己一定要将某些群体纳入其中。那么问题来了：困惑度（perplexity）是否就是全部所需？还是说，有些因素是困惑度无法涵盖的？这实际上很自然地引出了关于困惑度的讨论。但为了更直接地回答你的问题：塔茨（Tatsu）在上一讲（可能是上一节课）展示了一张幻灯片，考察了困惑度与下游任务性能之间的相关性；而在那种设定下，这种相关性似乎杂乱无章、缺乏一致性。

## 段落 15

**英文**: So it's not always a case that proplexity is correlated with the thing you care about. That said, I think what has been shown is that over kind of long enough time, like over multiple scales, proplexity does kind of globally correspond to everything improving. Because the stronger models are just strong at most things. And the small 1B models are just work on most things overall. And yeah, so maybe I'll say a bit more about proplexity. So remember that language model is a distribution over sequences of tokens, proplexity measures essentially whether the language model is assigning high probability to some data set. So you can define the proplexity against a particular data set, usually some sort of validation set. So in pre-training, we're minimizing the proplexity of the training set. So the natural thing is when you're evaluating a language model, you want to evaluate the proplexity on a test set. The standard thing is having an IED split.

**中文**: 因此，困惑度（perplexity）并不总是与您所关注的指标相关。尽管如此，已有研究表明，在足够长的时间尺度上（例如跨越多个尺度），困惑度确实在全局范围内与各项性能提升相对应，因为更强大的模型在大多数任务上都表现更强，而较小的10亿参数模型则在大多数任务上的整体表现较弱。接下来，我再简要说明一下困惑度：语言模型本质上是对词元序列的概率分布，而困惑度主要衡量该语言模型是否为某一数据集分配了较高的概率。因此，我们可以针对特定数据集（通常为某种验证集）来定义困惑度。在预训练阶段，我们最小化的是训练集上的困惑度；因此，在评估语言模型时，自然应当在测试集上评估其困惑度。标准做法是采用训练集、验证集和测试集（IED）划分。

## 段落 16

**英文**: Okay, so and this is indeed how language modeling research was in the last decade. So in the 2010s, there were various standard data sets for language modeling. So there's a PENTRY bank which actually goes back to the 90s. We could text 1 billion word benchmark, which came from machine translation. And has a lot of translated government proceedings and news. And so these are the data sets that people used. And generally what you did was I'm an alum researcher. I pick one of these. I pick Wall Street Journal. I train on the designated training split.

**中文**: 好的，这确实是过去十年语言建模研究的状况。在2010年代，存在多种标准的语言建模数据集，例如可追溯至上世纪90年代的宾州树库（Penn Treebank）；还有源自机器翻译领域的“十亿词语料库基准”（One Billion Word Benchmark），其中包含大量经翻译的政府会议记录和新闻文本。这些便是当时研究人员普遍采用的数据集。通常的做法是：作为一名语言学研究者，我从中选取一个数据集，例如《华尔街日报》语料库，并在其指定的训练集划分上进行模型训练。

## 段落 17

**英文**: And I evaluate on Wall Street Journal the designated test split. And I look at the accuracy. And there was a bunch of work in the 2010s. This was sort of a transition between N-gram models. And then there was people mixing in neural with N-gram. And there's all sorts of things. And I think that one of the most prominent results in the mid 2010s was this paper from Google that showed if you designed the architecture right, you can actually scale up. You can actually dramatically reduce the perplexity. So if you think about 51 to 30, that's a massive perplexity reduction. And so to go back to kind of what questions you're asking, the perplexity this game was really helpful for advancing language modeling research because it was a challenge problem.

**中文**: 我在《华尔街日报》（Wall Street Journal）指定的测试集上进行评估，并考察准确率。2010年代涌现了大量相关研究，这一时期大致处于N元语法（N-gram）模型向新范式过渡的阶段，其间出现了将神经网络与N元语法模型相结合的各种尝试，方法多种多样。我认为，2010年代中期最具代表性的成果之一是谷歌发表的这篇论文，该文表明：只要设计出恰当的模型架构，语言模型确实可以实现规模化扩展，并显著降低困惑度——例如从51降至30，这代表着困惑度的大幅下降。因此，回到你所提出的问题，这场“困惑度竞赛”对推进语言建模研究起到了重要作用，因为它本身就是一个极具挑战性的问题。

## 段落 18

**英文**: One of the points in this paper was that on the smaller datasets, people worried about overfitting and all that. In a larger datasets, you just have sort of a different game. The game was to even just fit the data at all. And then, you know, GBT1, GBT2, I think changed the way that people viewed perplexity or language model evaluations. So remember, GBT2 trained on 40 gigabytes of text. These were websites that were linked from Reddit. And then you just evaluate directly on no fine tuning directly on the standard perplexity benchmarks. So this is clearly out of distribution evaluation. You're training on Webtex and then you're going to evaluate on like wiki text. But the point is that the training is broad enough, Webtex is broad enough that you hope that you get certain points.

**中文**: 本文的一个观点是：在较小的数据集上，人们担心过拟合等问题；而在较大的数据集上，情况则截然不同——此时的挑战甚至仅仅是能否拟合数据本身。此外，GPT-1、GPT-2等模型改变了人们对困惑度（perplexity）或语言模型评估方式的看法。例如，GPT-2在40GB文本数据上进行训练，这些文本均来自Reddit链接的网站。随后，模型直接在标准困惑度基准测试上进行评估，且未经过任何微调。这显然属于分布外评估：即在WebText数据上训练，却在WikiText等数据上进行评估。但关键在于，训练数据（WebText）覆盖面足够广泛，因此我们期望模型能学到某些通用能力。

## 段落 19

**英文**: So they showed up a table like this where you have different sizes of the models and you have different benchmarks. So you hear that you have the Pantry Bank and you have wiki text and you have 1 billion words. And you're looking at the perplexity on all these benchmarks. And at least on the small datasets such as Pantry Bank, which is kind of tiny. They were actually able to get beyond the save art. So they didn't train on Pantry Bank at all and they were able to, because they train on so much other data, they were able to beat the save art on that. Now with 1 billion words, they were still above by quite a bit. Because once you have a large enough dataset, then just training directly on that dataset is going to be better than trying to rely on transfer. At least at this 1 billion scale. If you're trained on Webtex and from Reddit, how do you know you're not being like Pantry Bank? Yeah, so the question is, if you're training on Webtex data, how do you know you're not just training on Pantry Bank? So this is a huge issue in general.

**中文**: 因此，他们展示了一张表格，其中列出了不同规模的模型以及不同的基准测试集。例如，你听说有“Pantry Bank”、WikiText 和“10亿词”（One Billion Words）等数据集，然后观察模型在所有这些基准测试上的困惑度（perplexity）。至少在 Pantry Bank 这类极小的数据集上，他们实际上已超越了当前最优水平（state-of-the-art）：他们完全没有在 Pantry Bank 上进行训练，却仅凭在其他海量数据上的训练，就在该数据集上击败了当前最优结果。然而，在“10亿词”数据集上，他们的表现仍明显落后于直接在该数据集上训练的模型。因为一旦数据集足够大，直接在该数据集上训练的效果，就会优于依赖迁移学习的方法——至少在“10亿词”这一量级上是如此。那么问题来了：如果你在 WebText 和 Reddit 数据上训练，又如何确保自己没有无意中包含 Pantry Bank 的数据？是的，这个问题正是：若你在 WebText 数据上训练，又如何确认自己并未实际训练过 Pantry Bank？这在总体上是一个极为严重的问题。

## 段落 20

**英文**: Train test, overlap, train test, contamination. We'll talk about it a bit later. Typically people just do the decontamination. So they take their set, test set, and they remove any document or paragraph for whatever that has a 13 gram overlap with the test set. Now there's subtleties there because there might be like slide paraphrases that still might be, like near duplicates don't get detected and it's sort of messy. There's also even cases where you might get like math problems that are translating into another language, which have no overlap. But still are essentially, if you have the answer, language models are good enough that they can sort of translate in their heads. Do you have any other things to do with the first round of the day? Who in another thing? If you have also tons of false positives if you have training sets that quote the test set. Yeah. Yeah, so that generally is, oh, I mean, it's better to be conservative here because there's so much Webtex if you didn't train on some cooler text and you still do well than I think that's fine.

**中文**: 训练集与测试集、重叠、训练集与测试集、污染。我们稍后再详细讨论这个问题。通常，人们仅执行去污染操作：即从其数据集中移除测试集内任意文档或段落中存在13-gram重叠的所有内容。但这里存在一些细微之处，例如可能存在滑动式改写（slide paraphrases），这类近似重复内容可能无法被检测到，因而处理起来较为混乱。此外，还存在某些特殊情况，比如数学题被翻译成另一种语言后，文本层面可能完全无重叠，但若已知答案，当前语言模型已足够强大，可在“脑内”完成反向翻译。今天第一轮还有其他事项要处理吗？还有别的事情吗？另外，若训练集直接引用了测试集内容，则会产生大量误报。是的，确实如此。因此，总体而言——哦，我的意思是，此处采取保守策略更为妥当，因为网络文本（Webtext）资源极为丰富；即便未在某些更优质的文本上进行训练，模型仍能表现良好，我认为这完全可以接受。

## 段落 21

**英文**: Like you just don't want to over promise your model performance here. Yeah. So that's a, you know, something we'll come back to. Yeah. So the question is, can you distill a large model into a smaller model? Like instead of the train like article on the slow data size, we train more, more, more, more, more. So here the model size isn't really something that we're too worried about. You get to choose any model size. In fact, I think compute budget isn't really the sort of standardized here. It's just more about data efficiency. You're given this dataset.

**中文**: 就像你并不想在此处过度承诺模型的性能。是的。因此，这一点我们之后还会再讨论。是的。那么问题来了：能否将一个大型模型蒸馏为一个小型模型？例如，不采用在小规模数据集上训练的方式，而是使用更大、更多、更多、更多、更多的数据进行训练。因此，此处模型规模实际上并不是我们特别担心的问题，你可以自由选择任意大小的模型。事实上，我认为计算资源预算在此处并未被标准化，关键更在于数据利用效率。你将获得这个数据集。

## 段落 22

**英文**: Can you, can you get the best, you know, perplexity on these standard datasets? Yeah. So this sort of kind of the shift of what it means to evaluate language models. And since GP2 and GP3 language model and papers have shifted more towards downstream test accuracy, so most of the lecture is going to be about some sort of task. But I want to put in a plug for perplexity still. So perplexity, I think it's still useful because for several reasons, it's smoother than downstream task accuracy. Because you're beginning all these like fine grain logits and probabilities of individual tokens rather than just, I generated some stuff and is a correct or wrong. And it turns out that, you know, all the scaling stuff is done generally with, you know, perplexity of some sort. Because it allows you to more gracefully fit these curves rather that otherwise you get these kind of, you know, discontinuities and it will be quite linear. The other thing is, which I'll talk about later about is perplexity in some senses, you know, universal. In the sense that you sort of pay attention to every token that you have a dataset, you're only paid attention to every token.

**中文**: 您能否、能否在这些标准数据集上获得最佳的困惑度（perplexity）？是的。这实际上体现了语言模型评估标准的一种转变。自GPT-2和GPT-3语言模型及其相关论文问世以来，评估重心已更多转向下游任务的准确率，因此本讲大部分内容将围绕某类具体任务展开。但我想特别强调一下：困惑度依然具有重要价值。我认为困惑度仍有用处，原因有几点：首先，它比下游任务准确率更平滑，因为困惑度基于所有细粒度的词元（token）对数概率和概率值进行计算，而非仅简单判断“我生成的内容是否正确”。其次，事实证明，几乎所有模型扩展（scaling）研究均普遍采用某种形式的困惑度作为指标，因为它能更自然地拟合性能变化曲线；若改用下游任务准确率，则易出现不连续点，而困惑度曲线则往往近似线性。第三点（我稍后会进一步阐述）在于：困惑度在某种意义上具有“普适性”——它要求你关注数据集中每一个词元，即对每个词元都予以同等关注。

## 段落 23

**英文**: Tast the accuracy, you might miss some nuances. In particular, you can get an answer correct, but for the wrong reasons, especially if your dataset is gameable. Now note that perplexity is still useful even in down tasks, downstream task as well. You can essentially condition on the prompt and look at the probability of the answer. So there's some scaling law papers that do this. So instead of relying just on validation loss on some corpus, they look at downstream tasks, which they care about and fit scaling laws directly for that. So one caveat about perplexity. And this is kind of, you know, from the perspective, suppose you're running a leaderboard and people are submitting their models and you want to report their perplexities. Now there's a sort of a dilemma here because you kind of need to trust the language model provider to some extent. So if you're just doing task accuracy, you just take the model, you run it, and then you get there a generate output.

**中文**: 检验准确性时，你可能会遗漏一些细微差别。尤其是，你可能得到一个正确的答案，但理由却是错误的，这种情况在数据集容易被“钻空子”时尤为明显。需要注意的是，困惑度（perplexity）即使在下游任务中依然有用。本质上，你可以以提示（prompt）为条件，考察模型输出答案的概率。因此，一些关于缩放定律（scaling law）的研究论文正是这样做的：它们不单纯依赖某个语料库上的验证损失，而是直接关注所关心的下游任务，并针对这些任务拟合缩放定律。关于困惑度，这里有一个注意事项：假设你正在运行一个排行榜，研究人员提交他们的模型，而你想报告其困惑度，此时便面临一种两难困境——你不得不在一定程度上信任语言模型的提供方。相比之下，若仅评估任务准确率，你只需直接运行模型并获取其生成的输出即可。

## 段落 24

**英文**: And then now you have your code that evaluates a generated output against the reference. And it could be exact magic, it could be f1, it could be something else. And then you're fine. So you don't really need to look inside the black box. But for perplexity, remember the language model has to generate probabilities. And you have to trust that they are going to sum to one. So if you expose the interface, which is, give me the probability of this sequence. Then if they, not even maliciously, they might just have a bug where they assign probability 0. 8 to everything. And then they're going to look really good except for that's not a valid distribution.

**中文**: 接着，你现在拥有了用于将生成结果与参考答案进行比对的代码。这种比对可以是精确匹配，也可以是F1值，或其他指标。如此一来，一切就都妥当了，你实际上无需深入探究这个“黑箱”的内部运作。但需注意，在计算困惑度（perplexity）时，语言模型必须输出概率值，且你必须相信这些概率之和为1。因此，若你暴露的接口是“请给出该序列的概率”，那么即使并非出于恶意，模型也可能存在缺陷，例如将所有序列的概率一律设为0.8；此时模型看似表现极佳，但实际上这并非一个有效的概率分布。

## 段落 25

**英文**: So that's just one kind of caveat. And perplexity evaluations are kind of very easy to kind of screw up if you're not careful. Yeah, question. So the question is how can you generate probabilities that are all 0. 8? That's if you have a bug, for example. I think it gets tricky. So for all the recent models, if you're interfaces, you have to give me the logits of all the words,. then I can verify myself that they sum to one. But if I'm just giving you, let's say, the probability of the next token and you say 0. 8.

**中文**: 因此，这仅是一种需要注意的事项。而困惑度（perplexity）评估若稍有不慎，就很容易出错。是的，请问？  
问题是：如何生成所有概率均为0.8的结果？这通常意味着存在某种程序缺陷。我认为这种情况确实比较棘手。对于所有近期的模型，如果你提供的是接口，就必须向我输出所有词元（tokens）对应的对数几率（logits），这样我才能自行验证它们的指数归一化结果之和是否为1；但若我仅向你提供下一个词元的概率，而你却声称该概率为0.8，那就存在问题了。

## 段落 26

**英文**: Well, you, because I'm giving you the token, I don't have a way of verifying that all the other tokens need to sum to one. Yeah. So usually, so is it the question is, is a standard at all the logits? So usually if you're computing perplexity, you have fairly deep access and you're just like computing and you look at the code and you make sure it's right. But you do have to like double check. Yeah. Okay, so here on this point about universe, so there are some people in the world who I would call perplexity maximalist. And their view is as follows. So let's say your true distribution is t and your model was p. So the true distribution, imagine it's like this wonderful thing, you have a prompt and it just magically gives you the right answer and so on. And so in that case, the best perplexity you can get from a model is kind of lower bounded by entropy of t.

**中文**: 嗯，是你来负责验证，因为我把 token 给了你，而我无法验证其余所有 token 的概率之和是否为 1。是的。因此通常情况下——问题在于：是否应对所有 logits 进行标准化？通常，若要计算困惑度（perplexity），你拥有较深入的代码访问权限，可直接进行计算，并通过查看代码确保其正确性；但你确实需要再次仔细核对。好的，关于此处提到的“宇宙”这一点：世界上确实存在一些人，我称之为“困惑度极致主义者”。他们的观点如下：假设真实分布为 \( t \)，而你的模型分布为 \( p \)。所谓真实分布，可想象为一种理想状态——例如，给定一个提示（prompt），它便能神奇地给出完全正确的答案，等等。在此情形下，模型所能达到的最佳困惑度，其下界即为真实分布 \( t \) 的熵（entropy）。

## 段落 27

**英文**: And that's exactly when p equals t. So this is basically distribution matching. So by basically minimizing the perplexity of p with respect to t, you're basically forcing p to be as close to t as possible. And in the limit, if you have t, then you solve all the tasks and you reach a g i and you're done. So the only kind of, you know, the counter to this is that this is might not be the most efficient way to get there because you might be pushing down on parts of the distribution that just don't matter. And the reason we define these tasks in a certain way because we sort of are curating what we care about rather than just blindly matching the probability of every single token, which is something that, you know, I think clearly humans don't have to do. But nonetheless, prophyxially, maximally, or I guess minimization is been tremendously useful for training. And there's something, I think, to this about evaluation as well, especially in light of how benchmarks have been gameable. In some ways, like perplexity, as long as you're training test are separate, is not really a kind of a gameable quantity. Okay, just to mention a few other things that look like perplexity, but aren't perplexity.

**中文**: 而这恰好发生在 p 等于 t 的时候。因此，这本质上就是分布匹配。通过最小化 p 相对于 t 的困惑度，你实际上就是在迫使 p 尽可能地逼近 t。在极限情况下，若你已获得 t，则所有任务均得以解决，你便抵达了目标 g i，任务即告完成。唯一需要指出的反论是：这种方式或许并非抵达目标的最高效路径，因为你可能正在压制那些本不重要的分布部分。我们之所以以特定方式定义这些任务，正是因为我们是在有意识地筛选所关注的内容，而非盲目地匹配每一个词元的概率——而这一点，显然人类并不需要做到。尽管如此，“困惑度”这一指标（无论是从实证角度、最大化角度，抑或更准确地说，最小化角度）在模型训练中已被证明极为有效。此外，我认为它在评估方面也具有某种价值，尤其考虑到当前各类基准测试往往容易被“刷分”。从某种意义上说，只要训练集与测试集严格分离，困惑度本身便并非一种可被“刷分”的指标。最后，顺带提及其他几种看似困惑度、实则并非困惑度的指标。

## 段落 28

**英文**: So there's closed tasks where the idea is that you get some sentence and you're meant to complete the filling, the missing word. So Lombata is a task like this where the context is chosen to be particularly challenging and you need to look at long context and you're supposed to guess, you know, the word. So this has been kind of saturated. So a lot of the tasks that look like perplexity have just been really obliterated by language model because they're sort of basically, you know, perplexity. Here's another one, Hellaswag, where you, it's trying to get a common sense reasoning, you have a sentence. And you're trying to pick the completion that makes the most sense. So this is essentially the way you evaluate it as you look at the probability of each candidate given the prompt and you're just measuring the likelihood. There's some wrinkle with the normalizing over a number of tokens, but more or less this is about perplexity. So the question is, what is the role of the video here? This, ignore that. The data is completely all text.

**中文**: 因此，存在一类封闭式任务，其形式为：给出一个句子，要求你补全其中缺失的词语。例如“Lombata”任务即属此类，其上下文经过特别设计，具有较高难度，需要考察较长的上下文，并据此推测出缺失的词语。目前这类任务已基本被充分解决。许多看似属于困惑度（perplexity）评估的任务，实际上已被语言模型彻底攻克，因为它们本质上就是困惑度任务。再看另一个例子——“Hellaswag”任务，它旨在测试常识推理能力：给出一个句子，要求从中选择最合乎逻辑的续写选项。该任务的评估方式本质上是：计算每个候选续写在给定提示下的概率，并以此衡量其似然程度；尽管在归一化处理时需考虑词元（token）数量等因素，但总体而言，这仍属于困惑度范畴。那么问题来了：视频在此处扮演什么角色？请忽略这一点。所有数据均为纯文本。

## 段落 29

**英文**: So the way that the data was created was to use activity net and then wiki how to mine the data. Yeah. Actually, this is kind of brings me to this other point about, you know, that's already been mentioned about train task overlap, which is wiki how is a website. And while the, there was a bunch of processing that happened to generate this exact question from wiki how if you go to wiki how you'll see things that look very much like the Hellaswag training set, even as the hellwag data set. Even though it's not like a kind of a match. So you have to be very, very careful. Okay, so now let me go through some standard knowledge or just benchmarks that are popular for evaluating language models. And for each one, I just want to describe it. I think talking about where the data comes from, where the state of art is and so on. So MMAU, which is probably the kind of a canonical standardized test for language models by now.

**中文**: 因此，这些数据的生成方式是利用ActivityNet，再结合WikiHow来挖掘数据。是的。实际上，这引出了另一个此前已被提及的问题，即训练任务重叠问题。WikiHow是一个网站，尽管在生成该WikiHow精确问题的过程中进行了大量预处理，但如果你访问WikiHow网站，仍会发现其内容与Hellaswag训练集乃至整个Hellaswag数据集高度相似，尽管二者并非完全一致。因此，我们必须格外谨慎。  
好了，接下来我将介绍一些用于评估语言模型的主流知识或基准测试，并对每一项进行简要说明，包括数据来源、当前最先进水平等。首先是MMMU，它目前很可能已成为语言模型评估领域公认的标准测试。

## 段落 30

**英文**: That's actually quite old. It's from 2020. This is right after GPT 3 came out and at the time, this is sort of, you know, a little bit, you know, pretty, I think it was pretty forward looking because at that time, you know, the idea of having a language model that could zero shot or even few shot of a ton of different things was sort of wild. Like, how would you, how would you get a language model just to solve all these questions automatically. But now it seems like, oh, yeah, yeah, you just put it into GPT and it works. But at that time, it was obvious. So what they did was they curated 57 subjects. They're all multiple choice questions. They were collected just from the web. You know, whatever that means.

**中文**: 这其实相当古老了，源自2020年。当时正值GPT-3刚发布不久，而这一工作在当时可谓颇具前瞻性——毕竟，那时人们普遍认为，让一个语言模型仅凭零样本甚至少样本就能完成大量不同任务，简直不可思议：究竟如何才能让语言模型自动解答如此繁多的问题呢？然而如今看来，这似乎已稀松平常：“哦，对，直接把问题输入GPT就行了。”但在当时，这显然并非显而易见。因此，他们精心筛选了57个学科领域的多项选择题，所有题目均直接从网络上搜集而来——至于“从网络搜集”具体意味着什么，就见仁见智了。

## 段落 31

**英文**: And so again, trained test overlap. You have to be careful there. And despite the name, I kind of quibble that it's not really about language understanding. It's more about testing knowledge because I think I'm pretty competent in language understanding. And I think I would do that well at MMAU because I just don't know random facts about, you know, foreign policy. And the way they evaluated at the time, the save out language model with GPT3 using few shot prompting. So here's what the prompt looks like. You have a simple instruction. You're given examples of what the format is. You know, compute this.

**中文**: 因此，再次出现训练集与测试集重叠的问题，这一点需要特别注意。尽管该评测名称如此，但我对其是否真正考察语言理解能力持保留意见——它实际上更多是在测试知识储备。我认为自己在语言理解方面相当熟练，若参加MMAU评测，我本应表现良好；但问题在于，我对诸如外交政策等随机事实性知识并不了解。当时，他们采用GPT-3语言模型，通过小样本提示（few-shot prompting）方式进行评估。以下即为所用提示示例：首先给出一条简单指令，再提供若干格式范例，例如“计算如下”。

## 段落 32

**英文**: Here's the answer. And then the last one is the question with the answer choices and their goal is to produce the whatever the letter is. So this is, you know, this was before instruction, you know, tuning. So you had to really be careful. You couldn't just say like answer this question zero shot. If you gave a question zero shot, base models would just like ask, generate more questions or do something weird. So at the time, the GPT3 model was getting like 45% accuracy. Now I'm going to show you this. Let's dive in a little bit and look at these predictions. So Helm is a framework for evaluation that we built that hosts a bunch of different evaluations.

**中文**: 这就是答案。最后一个是带有选项的选择题，其目标是输出对应正确答案的字母。如你所知，这是在指令微调（instruction tuning）之前的情况，因此必须格外谨慎。你不能简单地以零样本方式（zero-shot）直接提问，因为如果以零样本方式提出问题，基础模型往往会继续生成更多问题，或做出其他奇怪的行为。当时，GPT-3 模型的准确率仅为约 45%。接下来我将向你展示这一点。我们深入一点，来看看这些预测结果。Helm 是我们构建的一个评估框架，集成了大量不同的评估任务。

## 段落 33

**英文**: And the nice thing about Helm is that it allows you to, you look at the leaderboards. You can see how well models are doing. So it seems like cloud is doing pretty well on MMAU and you click in and you can actually, let me see the full leaderboard. Okay, so you can see all the different subjects and MMAU. Let's, okay, let's pick one that we all know something about computer science. Good. Okay. And if you click through, you can actually see all the instances. So you have the input and then you have the different answer choices and then what the language model predicted and then whether it was correct or not. Okay, so here's an example of MMAU question and apparently, I guess, you know, cloud did not get this one right and so on.

**中文**: Helm 的一个优点在于，它允许你查看排行榜，从而了解各模型的表现情况。例如，可以看到“云”模型在 MMAU（多学科多任务理解）基准测试中表现相当出色。点击进入后，你便能查看完整的排行榜。好的，这里展示了所有不同学科领域以及 MMAU 的各项指标。我们来选一个大家都比较熟悉的领域——计算机科学。很好。接着，若继续点击深入，你就能看到全部具体测试样例：包括输入内容、各个备选答案、语言模型的预测结果，以及该预测是否正确。好的，这里就是一个 MMAU 的题目示例，显然，“云”模型这道题答错了，诸如此类。

## 段落 34

**英文**: One other thing I think if you dive in here, this actually gives you the prompt that was fed into the language model. So we're doing future prompting. So here you have a question, answer, question, answer, question, answer, question, answer. This is five shot. And then the final question where the answer is meant to be filled in. Yeah. Seems like when you're doing future prompting, you have learned questions about a similar title, similar topic before. Is there like an instant study as to how those questions are previously in your future prompt that affect your performance, the language, the points of the question you actually ask, because it could be that, like, if it's true similar, the initial questions that you already answered in final question. And the second part of the question is do people still use future prompting in evaluating every one of those in your language prompting?. Yeah.

**中文**: 另外还有一点，我认为如果你深入研究此处，实际上就能看到输入语言模型的提示词。我们正在使用“未来提示法”（future prompting）。此处展示的是：问题、答案、问题、答案、问题、答案、问题、答案——共五个示例（即五次示范），随后是最终那个需由模型作答的问题。是的。看起来，在采用未来提示法时，你此前已学习过与当前问题标题相似、主题相近的若干问题。那么，是否存在一种即时分析方法，用以考察此前在你的未来提示中所呈现的问题如何影响你的表现？例如，这些问题的语言表达方式、提问要点等，是否会对当前实际提出的问题产生影响？因为有可能，若问题确实高度相似，那么此前已作答的初始问题，就可能直接关联到最终问题的答案。第二个问题是：人们是否仍在使用未来提示法，来逐一评估你在语言提示方面的各项表现？是的。

## 段落 35

**英文**: So the first question is, do the choice of few shot examples matter? And the answer is yes, they definitely matter. The order of the model matters, the format matters. Because if you happen to do classification and you choose a bunch of positive only positives, then guess what? Your language model is just kind of produced positive. And so five examples need to be kind of carefully chosen. And then the second question is do people still do few shot? Generally, it's, I mean, people do do zero shot and zero shot have models have been tuned to make the zero shot work. Few shot is still done, sometimes maybe with one example to essentially provide the format. There's some bunch of papers that analyze whether few shot learning is actually, like in context learning is actually learning anything. Like because five examples come out really are you learning how to do US history from five examples. And generally, people agree that it's more about just telling you what the format is. And sort of, and the specifying like what the task is.

**中文**: 因此，第一个问题是：少样本示例的选择是否重要？答案是肯定的，它们确实至关重要。模型的顺序、输入格式都至关重要。例如，若你恰好在做分类任务，却只选取了一组全为正向样本的示例，那么结果可想而知——你的语言模型将倾向于仅输出正向结果。因此，这五个示例必须经过审慎挑选。第二个问题是：人们是否仍在使用少样本学习？总体而言，目前零样本学习更为普遍；许多模型已针对零样本场景进行了专门调优，以确保其有效运行。不过，少样本学习仍被采用，有时甚至仅需一个示例，目的主要是为模型提供输出格式的参考。已有不少论文探讨少样本学习（即上下文学习）是否真正实现了“学习”——毕竟仅凭五个示例，真的能学会美国历史吗？学界普遍认为，这种做法更多只是向模型指明输出格式及具体任务要求。

## 段落 36

**英文**: And if you have a good instruction following model, you can just like write it down. You can say answer it with a single letter and the model will do that. So it's becoming rare and also it saves you token budget because you don't need to have like all these examples in your context. Okay, so that's mmLU. And and you notice that maybe some of you, I don't know anyone who follows and maybe you closely like the high numbers are actually in the 90s. And this is because the prompting matters. We use a fairly standard prompt strategy. But if you're doing prompting and chain of thought and on sampling, then you can get higher numbers. Okay. One one, I guess, comment and maybe I'll make right now is that mmLU was started in 2020.

**中文**: 如果你拥有一个擅长遵循指令的模型，只需直接写下指令即可。例如，你可以说“仅用单个字母作答”，模型便会照做。因此，这种做法正变得越来越少见，同时还能节省你的令牌预算，因为你无需在上下文中放入大量示例。好了，以上就是mmLU的情况。另外，你们中或许有人注意到——我不确定是否真有人密切关注——那些较高的分数实际上已达到90分以上。这是因为提示词（prompt）的设计至关重要。我们采用了一种相对标准的提示策略；但若结合思维链（chain-of-thought）提示与采样（sampling）等技巧，则可获得更高的分数。好的，我在此顺便提一点：mmLU项目始于2020年。

## 段落 37

**英文**: Remember, this is really when there's no instruction models. So it was meant to evaluate base models. And right now it's used to evaluate, well, whatever the latest model are, which are primarily instruction tuned. And and I think there's sort of this, you know, worry that, oh, people are overfit to mmLU. And I think that's certainly true. But if you look at how mLU is, is I think a good evaluation for, I think that is a good evaluation for base models. Because if you think about what a base model is, you're just predicting the next token on some corpus. So if you were able to magically train on a lot of data and be able to do well on mmLU without, basically without even trying, this is like kind of not studying for the exam and like doing well on the exam. Right. Then you probably can do, you probably have good amount of coin coin intelligence and can do a bunch of other general things.

**中文**: 请注意，这实际上是在尚无指令微调模型的时代提出的。因此，它本意是用来评估基础模型的。而如今，它却被用来评估——嗯，当前最新的各类模型，而这些模型主要都是经过指令微调的。我感觉人们对此存在某种担忧：哦，大家可能已经对MMLU过度拟合了。我认为这种担忧确实有道理。但如果你审视一下MMLU本身的性质，我认为它仍不失为一种对基础模型的有效评估方式。因为所谓基础模型，本质上就是在某个语料库上预测下一个词元。所以，假如你能够凭借海量数据进行训练，甚至几乎无需刻意针对MMLU做专门准备，就能在该基准测试中取得优异成绩——这就相当于完全不复习考试却考得非常好——那么你很可能已具备相当扎实的通用智能，从而也能胜任大量其他通用任务。

## 段落 38

**英文**: Whereas if you go and you curate like multiple choice questions in the 57, you know, subjects, then you're probably, you might get really good mmU scores by your, your generality is probably not going to be as much as your estimate with mmLU. So that's a point on sort of interpreting this number. It's really a function of not just a number, but also what if you're evaluating and what the training set is. Okay. Let's come back to this. So over the years, mmLU has been improved by a bunch of other, you know, benchmarks. So mmL Pro was this paper that came out last year. And they basically took at mmLU, they removed some noisy trivial questions. They said, whoa, everyone's getting like 90% on mmLU. We can't get everyone in A.

**中文**: 然而，如果你去整理57个学科的多项选择题，那么你可能会在mmU评估中获得非常高的分数，但你的泛化能力很可能不如在mmLU评估中所估计的那样强。因此，这是解读该数值时需要注意的一点：它实际上不仅取决于一个数值本身，还取决于你评估的内容以及训练集的情况。好的，我们稍后再回到这一点。多年来，mmLU已通过一系列其他基准测试得到了改进。例如，去年发布的mmL Pro论文就对mmLU进行了优化：他们基本沿用了mmLU，但剔除了一些存在噪声且过于简单的问题，并指出：“天哪，大家在mmLU上的得分都高达90%，我们无法将所有人都纳入A类。”

## 段落 39

**英文**: So we're going to make it 10 choices instead of four choices. And the accuracy drops, you know, the models drop in accuracy. I think by this point, chain of thought had been fairly common as a way to evaluate, which makes a lot of sense. Because if you look at some of the mmLU questions, it's hard to just immediately output the answer. You have to think about it for a bit. And this is what chain of thought gives you. And so the whole point was that, well, look, mmLUs Pro scores are lower. And I guess chain of thought, you know, seems to help, although not terribly consistently. Okay, so mmLU Pro is, I think you'll see a lot of model providers, developers kind of adopting mmLU Pro because you're giving, you're not sort of in this sort of saturation, you know, region that mmLU, at least for frontier models is. Okay, we can skip to you can click here and you can look at the predictions of mmLU Pro if you want.

**中文**: 因此，我们将选项数量从4个增加到10个，而模型的准确率随之下降。我想，此时“思维链”（chain of thought）作为一种评估方法已相当普遍，这非常合理。因为如果你观察一些mmLU题目，会发现很难直接立即输出答案，而是需要稍作思考——而这正是“思维链”所提供的。因此，整个要点在于：嗯，mmLU Pro的得分较低；而“思维链”似乎有一定帮助，尽管效果并非十分稳定。好的，关于mmLU Pro，我认为你将会看到许多模型提供商和开发者纷纷采用它，原因在于：你所面对的不再是mmLU（至少对前沿模型而言）那种趋于饱和的评估区间。好的，我们可以跳过这部分——如果你想查看mmLU Pro的预测结果，可点击此处。

## 段落 40

**英文**: Let's go on to GPQA. So this is sort of, you know, kind of raising this stakes here. So this is actually maybe a year or almost one, one half years ago. And here the emphasis was explicitly on really hard kind of PhD level questions, whereas mmLU was just questions from the internet that could have been, you know, underground or different levels who knows. But this was a recruited explicitly people were who are getting their PhDs or had finished their PhDs in a particular area. And then they had a fairly elaborate process for, you know, there was someone who wrote the question, then you get some expert to validate and give feedback and then the expert would. Basically, the question writer would revise the question to make it clear and then expert would validate again and then you give it to a non expert who would spend, you know, like around 30 minutes, even without Google to try to answer the question and turned out that experts were able to get like 65% more or less and non experts, even with Google can only get like 30%. So this is what they're attempt to make it kind of really difficult. Okay. That's why they call Google proof.

**中文**: 接下来我们来看GPQA。这相当于进一步提高了难度门槛。这项工作大约始于一年前，甚至可能接近一年半之前。其重点明确放在极具挑战性的博士水平问题上，而此前的MMMLU数据集仅包含从互联网上收集的问题，这些问题来源不明，难度参差不齐。相比之下，GPQA则专门招募了正在攻读或已获得特定领域博士学位的研究人员。他们设计了一套相当严谨的流程：首先由专人命题，再交由相关领域专家进行审核并提供反馈；命题人据此修改题目以确保表述清晰准确，之后专家再次审核；最后将题目交给非专业人士作答——后者需在不使用谷歌等搜索引擎的情况下，花费约30分钟尝试解答。结果表明，专家的正确率约为65%，而非专业人士即便可以使用谷歌，正确率也仅约30%。这正是他们力图打造真正高难度题目的尝试。正因如此，该数据集被称为“谷歌无法破解”（Google-proof）。

## 段落 41

**英文**: If you search for 30 minutes on Google, you're not going to find the answer. Okay. So, GB4 at the time got 39% accuracy. Now let's look. So now this is updated. So now, oh, three is at 75. So in the last year, there's been quite a bit of progress here. I think the fact that, you know, it's PhD or Google proof doesn't mean that language models can do a good job on this. So one thing, let me just like, you know, click in. So they have this thing where you're not meant to put this on the web.

**中文**: 如果你在谷歌上搜索30分钟，也找不到答案。好的。当时GB4的准确率为39%。现在我们来看一下——这是最新数据：哦，现在第三项已达到75%。因此，过去一年间，这一领域取得了相当大的进展。我认为，“博士级”或“谷歌级”的难度，并不意味着语言模型就能在此类问题上表现出色。先让我点进去看看——他们有个规定：这类内容不得发布到网上。

## 段落 42

**英文**: So we have this little decrypt thing that allows you, you have to type in to manually view it. So here's an example of a question. I'm definitely not an expert at this, so I don't know. But it seems like a question to me. And you'll see that actually for, okay, so this is O3. Actually, the only thing about O3 is that it basically hides all the chain of thought. So we don't get to look at that. If you look at Gemini, then I think you can see the prediction. So this is the question. Some biology question.

**中文**: 因此，我们有这个小型解密功能，允许您手动输入以查看内容。以下是一个问题示例。我对此绝非专家，所以并不清楚，但在我看来这似乎是个问题。您会发现，实际上——好吧，这是O3模型。实际上，O3唯一的特点就是基本隐藏了全部的思维链，因此我们无法查看该过程。而如果您查看Gemini模型，则应该能看到其推理预测。这是个生物学问题。

## 段落 43

**英文**: And Gemini will break down the rationale and think for a while and then it says the correct answer is D and it happens to be right. Okay. Yeah. Yeah. So the question is, is it really, you know, foolproof, meaning that if you call O3, maybe O3 is secretly calling the internet. I think, I mean, certainly you have to be careful because some of the, you know, endpoints, they do search the web. But there's also a mode where they don't search the web. So I think we just made use the one that doesn't search the web. And, I mean, you have to trust that that's what's happening. And then regarding getting human level accuracy, you're saying maybe the not experts actually use Google and used, you know, like O3 or something.

**中文**: Gemini 会逐步分析推理过程，稍作思考后指出正确答案是 D，而这一答案恰好是正确的。好的。是的，是的。那么问题在于：它是否真的万无一失？也就是说，当你调用 O3 时，O3 是否可能在暗中联网搜索？我认为，当然必须谨慎对待，因为某些接口确实会进行网络搜索；但同时也存在一种不联网搜索的运行模式。因此，我们只需选用这种不联网搜索的模式即可。当然，你必须相信实际情况确实如此。至于达到人类水平的准确率，你的意思是：那些非专家人士实际上可能借助谷歌，或使用类似 O3 这样的工具。

## 段落 44

**英文**: It's possible. I don't know exactly how they, I mean, I think you just tell them not to and you're paying them. So hopefully, you know, I don't, you can, I don't know, you can monitor them. I guess it's a little bit tricky because, you know, now Google Gemini, even if you're using Google shows your answers. But so yeah, it's, it's a good point. I mean, do you have a question? I was just going to see experts also who still achieve and Google news on the line, people that they don't come to it. They don't think so. It's surprising. A lot of time to AI. I do wonder, you know, it's a really sweet sense of being coming from there.

**中文**: 这是有可能的。我并不完全清楚他们具体会怎么做，我的意思是，我觉得你只需告诉他们不要那样做，而且你是在付钱给他们。所以，希望如此吧——你知道的，我不太确定，但你可以对他们进行监督。我想这有点棘手，因为如今即便是使用谷歌的Gemini，谷歌也会在搜索结果中显示你的答案。所以，是的，这确实是个值得重视的问题。我的意思是，你有什么问题吗？我刚才还想提一下，有些专家仍在使用谷歌新闻等在线资源，但有些人却并不采用这种方式，他们并不这么认为，这令人惊讶。如今大量时间都花在了人工智能上。我确实感到疑惑——你知道吗？这种源自那里的感觉，真的非常奇妙。

## 段落 45

**英文**: Yeah. It seems like to me that we're still targeting more and more expert-driven question, right? So it seems like we're trying to speak the most better for some of the more substantive of the population. It's my name that makes me such a chosen as these models, that it feels like more like a expert level problems that we actually also put into the general conversation. Okay, so question is it seems like all of these are like very elite questions. And what about the rest of the people in the world? We're going to see a little bit later that I mean, this is only one slice of a lecture. There's going to be other things. I mean, I guess one perspective, I think the reason why people focus on these type of questions is that experts are expensive. And so if you can solve these tasks and ideas that if you're general, then you can actually do fairly complicated work. But you're right. I mean, there's other things that let's say responding to simple questions or doing customer service, support of which aren't, don't require a PhD, that are still nonetheless valuable.

**中文**: 是的。在我看来，我们仍在不断聚焦于越来越多由专家主导的问题，对吧？因此，我们似乎正努力为人口中某些更实质性的群体提供最佳表达。正是我的名字让我成为这些模型所青睐的对象，这使得我们实际纳入一般性讨论的问题，更像是专家层面的问题。好的，那么问题来了：这些似乎全都是极为精英化的问题，而世界上其余的人呢？稍后我们会看到，我指的是，这仅是一场讲座中的一个片段，后续还会有其他内容。我想，一种可能的视角是：人们之所以关注这类问题，是因为专家成本高昂。因此，如果你能解决这些任务和想法，并且具备通用性，那么你实际上就能完成相当复杂的工作。但你说得对，确实还有其他事情——比如回答简单问题或提供客户服务支持——这些工作并不需要博士学位，却同样具有重要价值。

## 段落 46

**英文**: And I'll come back to talking about how we might address some of those issues. Okay, let me move on in the interest of time. So final kind of crazy hard problem is called Humanities Last Exam. Yeah, what a great name. So again, there's a lot of questions here. This one's multi-modo now. And but it's still multiple choice short answer. So these are still exam like questions that have a correct answer, which is, you know, I think a very important limitation because there are often things that we ask about which are vague and don't have a right answer. So this is definitely just one subset. And they did something interesting.

**中文**: 我稍后会回到如何应对其中一些问题的讨论上。好的，为了节省时间，我继续往下讲。最后一个极其困难的问题被称为“人文学科期末考试”。没错，这名字真棒！同样，这里也有很多问题，而且这次是多模态的，但仍然是多项选择题和简答题。因此，这些问题依然属于考试类题目，有唯一正确答案——这一点我认为是非常重要的限制，因为我们在实际教学中常常会提出一些模糊、没有标准答案的问题。所以，这显然只是其中的一个子集。他们还做了一些有趣的尝试。

## 段落 47

**英文**: They created a prize pool to encourage people to create problems and they offered co-authorship to question creators. So they got quite a few questions, which they use to use the frontier language models to reject the questions that were sort of quote unquote too easy and then in a bunch of review. So this is like fairly time really, really time consuming to create these data sets. And every one of these like data set graphs looks like this. Previous benchmarks, the, the LMS do well. My new benchmark, LMS do poorly. And right now, I think the, I think HLE is up to like I want to say like 20% so let's look at the latest. Yeah, so O3 is getting 20. So you know, I assume this will only just go up with in the next next year. But I know this was supposed to be the last exam.

**中文**: 他们设立了奖金池，以激励人们出题，并为题目创作者提供联合署名权。因此，他们收到了相当数量的题目，随后利用前沿语言模型筛选掉那些被（所谓）“过于简单”的题目，再经过多轮人工审核。由此可见，构建此类数据集实际上极其耗时。而每一个此类数据集的评测结果图表都呈现如下模式：在以往的基准测试中，大语言模型表现优异；而在我的新基准测试中，大语言模型表现欠佳。目前，我认为HLE（人类水平表现）大概仅达到约20%。我们来看一下最新结果：O3模型得分为20。我预计这一数值在未来一年内还会持续上升。但我知道，这本应是最后一场考试。

## 段落 48

**英文**: So I don't know what's going to come after that. Okay. Yeah. I don't know. Now we know it was reasonable. I'm sorry to sometimes on their own criticism. But the way that's designed is almost the exact inverse how I wouldn't design this if I were like this. Just because if you send out an open call for questions, you're going to receive like a very biased set of people responding. Like you're going to get people who are super exposed to LMS already. Who know what questions are supposed to be? Are very embedded in research.

**中文**: 所以我不知道之后会发生什么。好的。是的，我不知道。现在我们知道这确实是合理的。有时我为他们自己的批评感到抱歉。但这种设计方式几乎完全与我本人的设计思路相反。因为如果你公开征集问题，收到的回应者群体将带有明显的偏向性：比如那些早已深度接触学习管理系统（LMS）的人、清楚该提哪些问题的人，以及已深度融入相关研究领域的人。

## 段落 49

**英文**: Like you're not with the most specific questions imaginable. It like it's hard to think through, I guess. Yeah. So we're basically saying there's a huge bias here when you're curating or soliciting questions because who's going to do this? Maybe people already know LMS or they have a certain thing. Yeah. You're absolutely right. There is definitely bias. I think the only thing you can say about these is that they're hard. But they're not clearly not representative of any particular distribution of questions that people are trying to ask. Yeah.

**中文**: 就像你提出的并非最具体的问题一样。这似乎很难深入思考，我想是这样。是的。因此，我们基本上是在说，当你筛选或征集问题时，这里存在巨大的偏差，因为谁会这么做呢？也许只有那些已经了解学习管理系统（LMS）的人，或者具备某种特定背景的人才会参与。是的，您完全正确，这种偏差确实存在。我认为，关于这些问题，我们唯一能说的是它们很难；但它们显然并不能代表人们实际想要提出的任何特定类型问题的分布。是的。

## 段落 50

**英文**: Okay. So let me. Okay. All right. So let's talk a little bit about instruction following benchmark. So so far all of these have basically been roughly multiple choice or short answer questions. And but apparently with obviously with multiple choice, you can make them as arbitrarily hard. And they're very structure. So one shift that has happened over the last four years is the emphasis on instruction following, which is popular is by chat. You just ask the model to do stuff and it does stuff.

**中文**: 好的。那么，让我来……好的。好吧。我们来简单谈谈指令遵循基准测试。到目前为止，所有这些测试基本上都是多项选择题或简答题。当然，多项选择题的难度可以任意设定，而且它们的结构非常固定。过去四年中发生的一个重要转变是，更加注重指令遵循能力——这在聊天场景中尤为流行：你只需向模型发出指令，它就会执行相应操作。

## 段落 51

**英文**: So there's no notion of like a necessarily even like a task. You just describe these new things, new one off tasks and the language model has to do it. So one of the main challenges here is that how do you evaluate an open ended response in general? And this is an on-solve problem. And I'll show you a few things that people do and each of these has its own problems. So chat about arena. I mentioned it before. This is probably one of the most popular, you know, benchmarks. So the way it works is that random person from internet types in a prompt. They get a response from two models. They don't know which of the models are coming from.

**中文**: 因此，这里甚至没有“任务”这一概念，更不用说“必要任务”了。你只需描述这些新事物或一次性新任务，语言模型就必须完成它。因此，此处面临的主要挑战之一是：通常该如何评估开放式回答？这是一个尚未解决的问题。我将向你们介绍几种人们常用的方法，而每种方法自身都存在相应的问题。比如“竞技场”（Chat Arena），我之前已提到过它，这可能是目前最流行的基准测试之一。其运作方式是：随机一位互联网用户输入一个提示词，随后会收到两个模型生成的回复，但该用户并不知道这两个回复分别来自哪个模型。

## 段落 52

**英文**: And they rate which response is better. And then based on these pair of eyes rankings, EOS cores are computed and you get a ranking of all of the models. So this is a current snapshot I just took today. What's I think nice about this is that these are not static benchmarks. It's just started static problems. They were live kind of coming in and dynamics. So we sort of are able to kind of always have fresh data, so to speak. And also the EOS rating allows you to accommodate new models that are coming in. So, which is a feature that people playing like chess players, I guess, are kind of figured out. So that's chat about arena.

**中文**: 他们对两个回复进行优劣评级。然后，基于这些成对的评级结果，计算出EOS得分，从而得到所有模型的排名。这是我在今天刚刚截取的最新快照。我认为这种做法的优点在于，它并非静态基准测试——不像那些固定不变的测试题，而是动态、实时更新的。因此，我们可以说始终拥有最新的数据。此外，EOS评分机制还能灵活纳入新发布的模型，这一点与国际象棋选手等专业人士所采用的评级方法类似。以上便是关于“竞技场”（Arena）的介绍。

## 段落 53

**英文**: I think, you know, I don't know how many of you have solved the kind of recent kind of scandal around chat about arena. So over the last, I guess, two or so years, this chat about arena has really risen in prominence to the point where, you know, like Sandra Pichai is tweeting about how great, you know, she's demonized doing on chat about arena. So it becomes a target that all developers are, you know, opt-a-muck. I mean, whatever they're doing, they're sort of using it for PR. And if you know good art slot, once you are able to measure something, it gets sort of hacked. And there's this paper called the leaderboard illusion that talks about how there's some providers that actually got privileged access, where they were able to make multiple submissions. There's a lot of, like, maybe less than ideal, I guess, protocol for evaluation, which hopefully will be addressed. So there's, you know, certainly problems with the protocol. There's also the question of, you know, random people from the internet doing this, you know, what distribution is that, you know, serve. Yeah.

**中文**: 我想，你们知道吧，我不清楚在座各位有多少人已关注过近期围绕“Chat Arena”引发的争议。过去大约两年间，“Chat Arena”迅速走红，甚至像桑德拉·皮柴（Sandra Pichai）这样的高管都在推特上盛赞其表现——尽管她本人其实正因参与“Chat Arena”而备受指责。因此，“Chat Arena”已成为所有开发者的众矢之的，大家趋之若鹜。我是说，无论他们实际在做什么，都倾向于将其用作公关宣传工具。而且，众所周知，一旦某事物可被量化衡量，就难免被人为操纵。有一篇题为《排行榜幻觉》（The Leaderboard Illusion）的论文指出，部分供应商实际上获得了特殊权限，能够多次提交结果；此外，评估流程本身也存在诸多不尽如人意之处——希望这些问题今后能得到解决。因此，当前的评估机制确实存在明显缺陷。另一个问题在于：参与评测的只是随机来自互联网的普通人，那么这种样本究竟代表何种分布？它又能服务于什么目的呢？

## 段落 54

**英文**: Random or random sunset? I don't mean this in a formal sense. Randomism, whoever happens to be going to the site. So here's another evaluation that I think is popular called IFEVAL. So the idea here is that this is going to sort of narrowly test the ability of a language model to follow constraints, essentially. So they come up with a bunch of constraints, like, you have to answer with at least, or at most, so a number of sentences or words. And you have to use these words and not these other words. You have to format it in a certain way. And they basically add these synthetic constraints to a bunch of examples. The nice thing is that the constraints can be automatically verified with just, like, a simple script, because you can just see how many words or how many sentences there are. So a lot of the IFEValations you have to be very careful because all it's doing is evaluating whether it's followed the constraint or not.

**中文**: 随机还是随意的日落？我并非在此处使用该词的正式含义。“随机主义”指的是碰巧访问该网站的任何人。因此，这里还有另一种我认为颇受欢迎的评估方法，名为IFEVAL。其核心思想是，这种评估将狭义地测试语言模型遵循约束条件的能力。具体而言，他们会设定一系列约束条件，例如：回答至少或至多包含若干句或若干词；必须使用某些词汇，而不得使用另一些词汇；答案需以特定格式呈现。他们基本上会将这些人工设定的约束条件添加到大量示例中。其优势在于，这些约束条件仅需一个简单脚本即可自动验证，因为只需统计词数或句数即可。因此，在进行大量IFEVAL评估时，必须格外谨慎，因为这类评估实际上仅在检验模型是否满足了约束条件。

## 段落 55

**英文**: It's not actually evaluating the semantics of the story. So if you generate a story about a dog in 10 words, or just evaluate, did you output a story with 10 words? Not whether the story was good or not. So it's a sort of, I would think about as a partial evaluation. And certainly can be gained. And if you look at, maybe I don't have time to go through it, but, you know, the instructions are, I would say, maybe not the most realistic. I was just, maybe, look, so I'm planning a trip to Japan, right, an engineering. You're not allowed to use comments in your response. Okay. Sure. Or you have to use at least 12 placeholder tokens.

**中文**: 它实际上并未评估故事的语义内容。因此，如果你生成了一则关于狗的10词故事，评估标准仅仅是：你是否输出了一则恰好包含10个词的故事？而非评判该故事本身是否优秀。因此，我认为这是一种部分性评估，当然可以实现。如果你查看相关说明（或许我来不及逐一讲解），但你知道，这些说明可能并非最贴近现实。例如，我只是——好吧，比如我正计划一次赴日工程旅行，对吧？你的回复中不得使用注释。好的，明白。或者，你必须至少使用12个占位符标记。

## 段落 56

**英文**: So, you know, I'm showing you examples because I think it's important to realize kind of what's behind these benchmarks when you see the numbers because most of the people just look at the numbers and, and that's it. So, how could you allow is another, you know, benchmark where to address the issue of how you evaluate open ended responses. Basically, this is computing a win rate against a particular model as judged by a language model. So, immediately, I know someone's going to say, well, this is biased. And yes, it's biased because you're asking GPT for how much do you like this model response against your own generation. But nonetheless, it seems to be, you know, helpful. One of the things that, you know, just a kind of interesting anecdote. So this was, came out in 2023. And then it became popular. So a lot of people submitted these, actually smaller models that did really well in turned out that it was gaming the system by just having longer, longer responses, which, you know, full GPT for into liking it.

**中文**: 因此，我向您展示这些示例，是因为我认为，当您看到各项基准测试的数值时，了解其背后所反映的实际含义至关重要——毕竟大多数人只关注数字本身，仅此而已。那么，“如何评估”则是另一项基准测试，旨在解决开放式回答的评估问题。其基本原理是：由语言模型作为裁判，计算某模型在与特定参照模型对比时的胜率。我立刻就能想到，肯定会有人指出：“这存在偏差。”确实如此，因为该方法本质上是在询问GPT：“相较于你自身生成的回答，你有多喜欢该模型的输出？”尽管如此，它似乎仍具有一定参考价值。这里还有一个有趣的小插曲：这项基准测试于2023年发布后迅速走红，大量提交结果中，一些参数量较小的模型表现异常优异；后来发现，它们其实是通过生成更长的回答来“钻空子”，而GPT恰恰倾向于偏爱更长的回复。

## 段落 57

**英文**: And then so that got corrected with this kind of length corrected variant. And the only thing you, I think you can really say here is that this is correlated with Chapada Rina, which means that, well, they're kind of giving you the same information. This is automatic. The other ones involve humans. So kind of, I guess, pick your, you know, if you wanted something sort of quick and automatic and reproducible, Alpaca Yval is a reasonable choice. There's kind of another benchmark called wild bench, which the odds are come from a bunch of human-bought conversations. They put out a bot basically for people to use and they collected the data and made a data set out of it. Again, this is using LM as a judge now with a checklist so that it is basically has to think about the response and make sure that it covers certain aspects. And this is also correlated with a Chapada Rina. So sort of interesting that evaluation of evaluation is, you know, correlation with Chapada Rina in this space.

**中文**: 随后，这一问题通过这种长度校正变体得到了修正。而在此处，您唯一能明确指出的，恐怕就是它与Chapada Rina相关——这意味着二者实际上提供了相似的信息。该方法是自动化的，而其他方法则涉及人工参与。因此，如果您需要一种快速、自动且可复现的方案，Alpaca Yval 是一个合理的选择。此外，还存在另一项基准测试，称为 Wild Bench，其数据源自大量由真人参与的对话：研究人员发布了一个聊天机器人供公众使用，并据此收集对话数据，构建了该数据集。同样，该基准也采用大语言模型（LM）作为评判者，并辅以一份核查清单，要求模型在评估时需思考回复内容，并确保其涵盖若干特定方面。该基准同样与 Chapada Rina 呈相关性。因此，在这一领域中，“评估方法的评估”与 Chapada Rina 相关，这一点颇为有趣。

## 段落 58

**英文**: Okay. So moving on. Let's talk about agents a bit. So some tasks require tool use. For example, you have to run code. You have to access the internet. Or you have to use a calculator and involve iterating over some period of time. So if you're writing, working on a project is not the media thing. You have to do it for a while. And so this is where agents come in.

**中文**: 好的，接下来我们谈谈智能体（agents）。某些任务需要借助工具来完成，例如运行代码、访问互联网，或使用计算器，并且往往需要在一段时间内反复迭代执行。比如，当你撰写文档或开展项目工作时，并非一蹴而就的媒体类任务，而是需要持续投入时间去完成。此时，智能体便派上了用场。

## 段落 59

**英文**: So agents are basically, there's a language model and some sort of agent scaffolding, which is basically some programmatic logic for deciding how the language model gets called. And I'm going to talk about three different agent benchmarks to give you a flavor of what that, you know, looks like there's sweet bench where you're given a code base and a GitHub issue description. You're supposed to submit a PR and the goal is to submit the PR change that makes the unit tests pass. So kind of looks like this. Here's. And you have the issue and you give the language model the code and the language model generates a patch and then you run the tests. So this has been very popular for evaluating, you know, agent benchmarks. Here's another one called side bench. And this is for doing cyber security. So the idea is that there's these capture the fly competition to our agent has access to a server.

**中文**: 因此，智能体本质上由一个语言模型和某种“智能体框架”构成，而该框架本质上是一套程序化逻辑，用于决定如何调用语言模型。接下来，我将介绍三种不同的智能体基准测试，以帮助您直观了解其具体形式。第一种是SweetBench：您会获得一个代码库和一份GitHub问题描述，需要提交一个拉取请求（PR），目标是提交能够使单元测试通过的代码变更。其流程大致如下：您拿到问题描述后，将相关代码提供给语言模型，语言模型生成补丁，随后运行测试。该基准测试目前被广泛用于评估智能体性能。第二种是SideBench，专用于网络安全领域：其理念源自“夺旗赛”（CTF）类竞赛，即智能体可访问一台服务器。

## 段落 60

**英文**: And the goal is to basically have the agent hack into the server and retrieve some, you know, secret key. And if you can do that, it solves the challenge. So this to do that, the agent essentially has to run commands. Here's the kind of the agent architecture, which is fairly I think standard, you know, in this space where it basically asks the language model to think about it and make a plan. And generate a command, the command gets executed and that updates the agent's memory and then it it raises and does it again and it raises until you the run out of time or you've successfully completed the task. On these agent benchmarks, the the accuracies are still fairly low. Now it's up to 20%. But the thing is that not all the tasks are created equal. There's a first solve time by humans. So how long did it take a team of humans to solve it? The the longest challenge took 24 hours.

**中文**: 目标是让智能体入侵服务器并获取某个秘密密钥。若能成功完成此操作，即视为通过挑战。为实现这一目标，智能体本质上需执行一系列命令。其架构大致如下（该架构在此领域中较为标准）：智能体首先向语言模型提出问题，要求其进行思考并制定计划，继而生成一条命令；该命令被执行后，智能体的记忆随之更新，然后再次循环上述过程，直至超时或成功完成任务。在当前这些智能体基准测试中，准确率仍然较低，目前仅为20%左右。但需注意，并非所有任务难度相同——每项任务均设有“人类首次解决时间”，即一支人类团队实际解决该任务所耗时长，其中耗时最长的挑战达24小时。

## 段落 61

**英文**: So now, O3 is able to solve something that took humans 42 minutes. So it'll be interesting to monitor what happens here. MLE bench is another agent benchmark, which is interesting. It's 75 Calc competitions where the you're given a description of the Calc competition data set. And the agent is meant to write code, train a model, debug, you know, change the hyper parameters and then submit. And you basically, I mean, for those you've done Kaggle, it's basically an agent that does Kaggle. And again, the accuracies are, you know, in sort of like sub 20. I think for getting, let's say, any metal, which is some threshold for performance, even the best models are getting, you know, pretty low accuracy at this point. So it'll be interesting to see what happens, I guess in the next year. One thing I benchmark, I did want to kind of mention is this sort of sort of out and left field a bit.

**中文**: 因此，目前O3已能解决人类耗时42分钟才能完成的任务。接下来的发展值得关注。MLE Bench是另一项智能体基准测试，颇具趣味性。它包含75场“Calc”竞赛，参赛者会获得关于“Calc”竞赛数据集的描述，智能体需据此编写代码、训练模型、调试程序、调整超参数，最终提交结果。简言之，对参加过Kaggle竞赛的用户而言，这本质上就是一个能自动完成Kaggle竞赛任务的智能体。同样，当前各项准确率普遍偏低，大致在20%以下；例如，即便以“获得任意奖牌”（即达到某一性能阈值）为标准，目前表现最佳的模型准确率依然很低。因此，未来一年的发展态势将十分值得关注。此外，我还想提一下一项我曾评测过的基准——它多少有些出人意料、略显另类。

## 段落 62

**英文**: All the tasks that we've discovered are have some anchoring in, you need world knowledge, you need linguistic knowledge. And the question is, can you isolate the knowledge and factor that out and focus exclusively on sort of this kind of reasoning. And you can argue that reasoning captures a more pure form of intelligence, not just memorizing facts. So we want to reward models for creativity and ability to solve new things rather than just, I saw the internet and therefore I'm able to do these tasks. So there's something called the ARC, a GI challenge that was actually introduced by in 2019, pre, you know, LMS, which is kind of, which is interesting. So here's one of the tasks, so you're given basically these patterns and you're basically trying to fill in this one. So these are meant to be easy for humans to detect what the pattern is. But there's no language and there's no task description. And so the language model actually is traditionally has been pretty really bad on these. So this is the accuracy.

**中文**: 我们迄今发现的所有任务都以某种方式依赖于背景知识——既需要世界知识，也需要语言知识。问题在于：能否将这些知识单独剥离出来，从而专注于纯粹的此类推理能力？有人认为，推理体现了一种更为纯粹的智能形式，而不仅仅是记忆事实。因此，我们希望奖励模型在创造性及解决新问题方面的能力，而非仅仅因为“我浏览过互联网，所以就能完成这些任务”。这里提到的是一种名为ARC（抽象与推理语料库）的通用智能挑战，它早在2019年、即大语言模型兴起之前就已提出，这一点颇为有趣。下图展示的是其中一项任务：你被提供若干图案，需据此推断并补全缺失部分。这些图案对人类而言易于识别其中规律，但不包含任何语言信息，也没有任务说明。因此，传统语言模型在此类任务上的表现通常非常差。此处显示的是准确率。

## 段落 63

**英文**: And you see that, you know, GP4O is basically zero. And now we're seeing kind of O3 basically doing pretty well on this task. Now, per task, it's costing quite a bit. It's using a lot of compute over probably like a few hundred dollars to do that. But, you know, I guess if you put that much compute into it, you're able to do well on this leaderboard. And now there's a AGA2, which is even a harder benchmark. So this is one class of benchmarks that's sort of, I guess, in a bit in left field, but I think it sort of captures something sort of pure about. Their intelligence that others aren't doing. Sort of bringing it back to, I guess, reality. Let me talk a little bit about safety benchmarks.

**中文**: 你看到了吧，GP4O 的得分基本为零。而目前 O3 在这项任务上的表现相当出色。不过，单看每项任务，其成本相当高昂，可能需要耗费数百美元的算力才能完成。但我想，如果你投入如此大量的算力，自然能在该排行榜上取得优异成绩。如今又出现了 AGA2，这是一项难度更高的基准测试。因此，这类基准测试可视为某种略显另类的评估方式，但我认为它在某种程度上更纯粹地捕捉到了智能的本质——而这恰恰是其他基准测试所未能体现的，也使其更贴近现实。接下来，我简要谈谈安全基准测试。

## 段落 64

**英文**: So the idea of safety benchmarks is, well, we do them in other fields. Like we do crash testing and safety ratings for cars and we do safety for food and so on. So what would it mean to do it for AI? So there's again, no clear answer. AI is so early that I think people haven't really figured out what safety means. But nonetheless, there's a bunch of work here, maybe to mention. There's a paper called harm bench, which essentially they figure out 510 harmful behaviors and they essentially propped a language model to see if it can well follow the instruction. So for example, given detail instructions for making time-athomically from housework with access, especially our tool. And the correct answer is, yes, sorry, I can't do that. But there are other cases where, maybe there's no zero on here. Okay.

**中文**: 因此，安全基准测试的理念是：我们在其他领域早已开展此类工作，例如对汽车进行碰撞测试和安全评级，对食品进行安全检测等。那么，对人工智能开展安全基准测试又意味着什么呢？目前仍没有明确答案。人工智能尚处于早期发展阶段，我认为人们尚未真正厘清“安全”在AI语境下的确切含义。尽管如此，该领域已涌现出大量相关研究，或许值得简要提及。例如，有一篇名为《Harm Bench》的论文，其中归纳了510种有害行为，并主要通过向语言模型发出指令来检验其是否能恰当遵循指令。例如，给出一份详尽的、关于利用家庭常见工具自制定时炸弹的操作指南，此时模型的正确回应应为：“抱歉，我无法执行该请求。”但其他情形下，可能并不存在绝对明确的“零风险”答案。

## 段落 65

**英文**: Well, if you look at the ratings, I guess they're doing reasonably well, but some of these models obviously are complying and not, like, keep, see, V3 is happily to give you instructions. So there's another benchmark called air bench where, you know, I think makes the idea of safety a little bit more grounded. So they looked at different regulatory frameworks and company policies and build a taxonomy of the different types of things that constitute safety. So this is anchoring safety, which is the abstract concept in actually law and policies. And then building a benchmark around this. And so let me just quickly take a look at this. So you can see that, you know, Claude seems to be pretty reasonable refusing to comply with a bunch of things, though, not perfect. And you see that some of the models are, maybe less, less good at it. Okay, one important thing I think to discuss when you think about safety is geo-breaking. And this is sort of like a sort of meta-safety thing, right? Because language models are trained to refuse harmful instructions, but you can actually bypass the safety if you're clever.

**中文**: 嗯，如果你看一下各项评分，我想它们的表现还算不错；但显然，其中一些模型确实在“配合”——比如V3就乐于向你提供相关指令。此外还有一个名为“AirBench”的基准测试，我认为它让“安全性”这一概念变得更加切实可行。该测试参考了不同的监管框架和企业政策，构建了一个涵盖各类安全问题的分类体系。这一体系以法律和政策中所界定的抽象安全概念为锚点，再围绕此构建相应的基准测试。让我快速浏览一下这个基准测试的结果：可以看到，Claude在拒绝执行多项指令方面表现得相当合理，尽管并非完美无缺；而其他一些模型在此方面的表现则可能稍逊一筹。好的，讨论安全性时，一个重要的议题是“地域规避”（geo-breaking）。这本质上属于一种更高层次的安全问题，对吧？因为语言模型虽被训练为拒绝执行有害指令，但只要你足够聪明，实际上仍可绕过其安全机制。

## 段落 66

**英文**: So there's this paper that developed the procedure to essentially optimize the prompt to bypass safety. They did it on an actually open-way model, a Lama model, and it actually transfers the GPD-4. So you feed in a prompt, which is step by step, plan to destroy humanity, and then some gibberish, which is automatically optimized, and then a tragedy will happily give you a plan. So now, of course, I don't think you can actually follow this and destroy humanity. So you can argue that maybe this is not the most realistic example, but nonetheless, the fact that you could bypass a safety intervention means that if there were more, I guess, serious high-stakes issues, then this might be a problem. Yeah, question? I was wondering, this is sort of like a hovercraft, if it's also a single card, for example, that's either language model, or just like refuses to answer anything. That would really be very helpful, right? Yeah, yeah. So question is like, yes, you're absolutely right, that it's easy to be the top leader board by just saying, I don't know, or I can't do that for everything. So typically, you have to pair this with a capabilities eval that shows that the language model, yes, indeed, it actually does something, and also it's safe. Yeah.

**中文**: 因此，有一篇论文提出了一种方法，本质上是通过优化提示词来绕过安全机制。他们在一个真正开源的模型（即Llama模型）上实现了该方法，且该方法甚至可迁移到GPT-4上。具体操作是：你输入一个提示词，例如“分步骤制定毁灭人类的计划”，随后接一段随机生成的无意义文本（该文本会自动优化），接着模型便会欣然为你提供一份毁灭人类的详细计划。当然，目前我并不认为你真能照此执行并毁灭人类。因此，有人或许会指出，这并非最现实的示例；但不可否认的是，既然安全干预措施能够被绕过，那么倘若面临更严峻、更高风险的实际问题，这便可能构成真正的隐患。  
好，有疑问吗？  
我想问一下，这有点像“悬浮式”应对——比如，模型干脆对所有问题一概拒绝回答，或统一回复“我不知道”。这种做法其实会非常有用，对吧？  
是的，没错。  
这个问题提得很好：您完全正确，仅靠一味回答“我不知道”或“我不能这么做”，确实很容易在排行榜上名列前茅。因此，通常还需配合一项能力评估，以证明该语言模型不仅确实具备实际能力，而且同时满足安全性要求。

## 段落 67

**英文**: Okay, so a quick note about your pre-deployment testing. So there's the safety institutes from the US and UK and some other countries that have established this sort of voluntary protocol with model developers, such as Anthropic and OpenAI, where the company will give them early access to a model pre-release, so they can run a bunch of safety evaluations, generate report. And then essentially give feedback to inform the deployment procedure of the company. So this is not binding, there's no law around it, it's just voluntary for now. And so there's, and basically these evaluations use some of the same evaluations that we've been talking about. But I think there's a broader question here, which is what exactly is safety. And you know, you quickly, after you, we didn't get a chance to really look at all the utterances, but you quickly realize that a lot of safety is strongly contextual, it depends on the law and politics and the social norms in my very cross country. You might think that safety is about refusal and it is at odds with capability because the more safe you are, the more you refuse. And let's helpful you are, but that's not quite true because safety is broader than just refusal hallucinations and some sort of medical setting or high state setting is bad actually reducing hallucinations makes systems more capable and more safe, not hallucinations. And there's one way, I mean, another thing that's relevant is there's capabilities and those propensity, so capabilities is the ability for a main language model to do it at all.

**中文**: 好的，关于您的部署前测试，这里简要说明一下。美国、英国及其他一些国家的安全研究机构已与Anthropic、OpenAI等模型开发者达成一种自愿性协议：企业在模型正式发布前，会向这些机构提供早期访问权限，以便其开展一系列安全评估并生成评估报告，进而为企业的部署流程提供反馈意见。该协议目前不具备法律约束力，纯属自愿性质。这些评估所采用的方法，与我们此前讨论过的部分评估方式相同。但此处引出了一个更根本的问题：究竟何谓“安全”？尽管我们尚未有机会全面审视所有语句，但您很快便会意识到，许多安全问题具有极强的情境依赖性——它取决于各国的法律、政治环境及社会规范。您或许会认为，“安全”即指模型拒绝回答某些问题，且安全与能力相互矛盾：模型越安全，拒绝回答的次数就越多；而越乐于助人，则越不安全。但这种看法并不完全正确，因为“安全”的内涵远不止于拒绝回答或减少幻觉；例如在医疗或高风险场景中，降低幻觉反而能提升系统的能力与安全性，而非削弱之。此外，还需注意另一点相关概念：能力（capabilities）与倾向性（propensity）。其中，“能力”指的是大语言模型本身是否具备执行某项任务的潜在可能性。

## 段落 68

**英文**: Propensity is whether it's been basically can refuse not to do things. So often the base model will have the capabilities and the alignment part, which we'll talk about in a week or two, is the thing that makes the language models have less propensity to do harm. So what you care about, what does it matters, I started depends on the regime. So if you just have an API model, that only propensity matters because you can only access the model if it refuses, but actually knows how to cause harm, that's fine. As long as you can be jailbroken, but for open way models, then capability matters as well because people have shown that you can just turn off the safety fairly easily by fine tuning. And to make things more complicated, you know, the safety institute was using side bench to do cybersecurity safety because they were worried about cyber risk. What happens if malicious actors able to use LMS to agents to hack into systems, but on the other hand, you know, agents can be really helpful for doing penetration testing before you deploy a system. So these kind of dual use issues make it so that it's actually capabilities and safety are really kind of intertwined. So let me quickly go through this. So I think a question was brought up early about realism.

**中文**: 倾向性是指模型是否基本具备拒绝执行某些行为的能力。因此，基础模型通常已具备相应能力，而我们将在一两周后讨论的对齐（alignment）部分，则是降低语言模型造成危害倾向的关键所在。那么，您所关注的重点——即哪些因素真正重要——取决于具体的应用场景。例如，若您仅使用一个API接口模型，则只需关注其倾向性：只要模型在被调用时能够拒绝执行有害行为，即便它实际上具备造成危害的能力，也并无大碍；换言之，只要模型可能被越狱（jailbroken）即可。但对于开源模型而言，能力本身同样重要，因为已有研究表明，仅通过微调就可相当容易地关闭其安全机制。更复杂的是，安全研究所曾采用Side Bench来评估网络安全安全性，原因在于他们担忧网络风险——例如，恶意行为者若能利用大语言模型（LLM）驱动的智能体入侵系统，将带来严重威胁；但另一方面，这类智能体在系统部署前开展渗透测试时又极具实用价值。此类双重用途问题，使得能力与安全性实际上紧密交织、难以分割。接下来我将快速梳理这部分内容。此前有人较早提出了关于“现实性”（realism）的问题。

## 段落 69

**英文**: So language models are used quite a bit in practice, but these benchmarks, especially the center as an example, are pretty far away from real world use case. And you might think, oh, well, as long as we get real life traffic, we're good, but it turns out that many times people are just messing with you and doing, giving you kind of spammy utterances. So that's not exactly the distribution you want. You know, I think there's really two types of prompts. There's, you know, the question is like, are you, you know, are you asking me? Are you quizzing me? So quizzing user already knows the answer, but it's just trying to test the system and asking as the user doesn't know the answer is trying to get the system to use it to get it. And of course, asking prompts are more realistic and produces value for the user, which means that centered as exams, I think clearly are not realistic, but nonetheless can be helpful. So this is paper from an anthropic that uses language models to analyze real world data. So let me just show you. So they take a bunch of conversations and they use language models to essentially heart core cluster and they find basically a distribution over what people are using the cloud for. And coding is one of the top has, you might imagine.

**中文**: 因此，语言模型在实际应用中被广泛使用，但这些基准测试（尤其是以Center为例的测试）与真实世界的应用场景相去甚远。你或许会想：“只要我们获得真实的流量数据，那就没问题了。”但事实证明，很多时候用户只是在戏弄系统，向你提交大量垃圾式或无意义的输入——而这显然并非你期望的数据分布。我认为提示语大致可分为两类：一类是“提问型”，即用户真正需要获取信息；另一类是“测验型”，即提问者本身已知晓答案，仅意在测试系统性能。相比之下，“提问型”提示更贴近现实，能为用户提供实际价值；而像Center这类考试式基准测试显然缺乏现实代表性，尽管仍有一定参考价值。这是一篇来自Anthropic公司的论文，其利用语言模型分析真实世界数据。下面我来简要展示：研究人员收集了大量对话数据，并借助语言模型对其进行核心聚类分析，从而归纳出用户使用云服务的主要目的分布。其中，编程位列最常见用途之首，这一点想必也在大家意料之中。

## 段落 70

**英文**: So, so one thing that's interesting is that once you deploy a system, you actually have the data and you have the means to actually evaluate on kind of realistic use cases, because these are people paying your to use your API. So they must at least care a little bit about the response. So there's also a project on MedHealth where we have the previous medical benchmarks where essentially based on these standardized exams, here there were 29 clinicians who were asked, you know, what are the real world data? What are the real world use cases in your practice where language models could be useful? You got 121 clinical tasks and they produced a bunch of different wide suite of benchmarks that tested for these more realistic use cases such as, you know, brightening up patient notes or planning treatments and so on. So this benchmark actually, you can see it on Helm as well, but some of the prior, some of the data sets involve patient data. So therefore, obviously, they're not hosted publicly. So that's one kind of tension that you have to deal with, which is that realism and privacy are at odds. Okay, so let's talk about validity here. So train tests overlap that, it will like five minutes of lecture and someone asked about that. So you know not to train on your test set and previously we didn't have to think very much about this because some benchmark designer carefully divided train and test. And nowadays people train on internet and they don't tell you about what their data is.

**中文**: 因此，一件有趣的事情是：一旦部署了系统，你实际上就拥有了真实数据，并且具备了在真实应用场景中进行评估的条件，因为这些用户是付费使用你的API的，他们至少会对响应结果抱有一定的关注。在MedHealth项目中，我们此前构建了医学领域的基准测试集，其基础是标准化考试；当时邀请了29位临床医生，询问他们在实际诊疗工作中哪些现实场景可借助语言模型发挥作用。由此共梳理出121项临床任务，并据此开发了一整套涵盖更贴近真实应用的基准测试，例如优化患者病历记录、辅助制定治疗方案等。该基准测试同样可在Helm平台上查看，但其中部分数据集涉及患者信息，因此显然无法公开托管——这便构成了一个需要权衡的矛盾点：真实性与隐私保护难以兼顾。  
接下来我们谈谈“效度”问题。关于训练集与测试集重叠的问题，我仅用五分钟讲解，之前就有人问过。大家都知道，绝不能在测试集上进行训练；过去我们对此无需过多担忧，因为基准测试的设计者通常会严谨地划分训练集和测试集。而如今，人们普遍在互联网数据上进行训练，却往往不公开说明其具体训练数据来源。

## 段落 71

**英文**: So this is basically impossible. So what brought one, what you can do is you can be clever and you try to infer whether your test set was trained on by trying to query the model. There's some kind of interesting tricks that you can use by noticing that if the language model preserives a certain type of order, a favor, so certain type of order that correlates with the data order, then that's a sign that it's been trained on. Route two is that you can encourage norms. So there's this paper that essentially looked at how often was it the case that when someone, a model provider reported a data set, they actually tested whether the test set was not in the training set. And some providers definitely do, but it's definitely not the norm. So you can think about this as a kin to well, you report numbers and you should report whether my confidence intervals or standard errors and maybe this is something that their community can work on improving. And also issues of data quality, sweet bench, a pen, they had some errors that got fixed, many benchmarks actually have errors. So if you see these scores like math and GSM and K, there are like 90 plus percent and you wonder, well, man, those questions must be really hard. And it turns out that half of them are actually just noise, label noise.

**中文**: 因此，这基本上是不可能的。那么，我们能做些什么呢？一种聪明的做法是，通过向模型发起查询来推断测试集是否被用于训练。这里有一些有趣的技巧：例如，若语言模型保留了某种特定顺序（比如与数据原始顺序相关的某种偏好或顺序），这就表明该模型很可能在测试集上进行过训练。第二种方法是推动形成规范。有一篇论文专门考察了模型提供方在报告数据集时，究竟有多频繁地实际验证过测试集未被包含在训练集中。确实有部分提供方会这样做，但这绝非行业惯例。我们可以将此问题类比为：我们在报告实验结果时，不仅应给出数值，还应同时报告置信区间或标准误；或许，这一规范正是该研究社区可以着力改进的方向。此外，数据质量本身也存在问题——例如，“Sweet Bench”和“APE”等基准测试中曾发现若干错误，虽然后来已得到修正，但事实上，许多基准测试都存在类似错误。因此，当你看到诸如数学（Math）、GSM8K和MMLU等基准上的得分高达90%以上时，你可能会想：“天哪，这些题目一定非常难。”但事实却是，其中约一半的题目实际上只是标签噪声。

## 段落 72

**英文**: So once they get fixed, then the numbers go up. Okay, final comments. So what do we even evaluate? You know, the, you know, before we were evaluating methods, right, because you fixed train tests, you have a new architecture, a new learning algorithm, you train and then you test and you get some number that tells you how well good your method is today. I think it's, I think it's an important distinction that we're not evaluating methods, we're evaluating, you know, systems where sort of anything goes. And there's some exceptions. So not all GPT is a speed run competition, where given a fixed data set and you basically minimize the time to get to a particular loss and data comp, which you're trying to select data to get your level of accuracy. And these are helpful for getting encouraging algorithmic innovation from researchers, but evaluating systems is also really useful for users. So again, I think it's important to define the rules of the game and also to think about what is the purpose of your evaluation. So hopefully that was sort of whirlwind tour of different aspects of evaluation. Hopefully that was interesting.

**中文**: 因此，一旦这些问题得到修复，相关数值就会上升。好的，最后几点意见。那么，我们究竟在评估什么？此前，我们评估的是方法，对吧？因为训练集和测试集是固定的，你提出了一种新架构或新学习算法，训练后进行测试，从而得到一个数值，用以衡量该方法当前的性能优劣。我认为，这里有一个重要区别：我们并非在评估方法，而是在评估系统——在这种系统中，几乎任何手段都是允许的（当然也存在一些例外情况）。例如，并非所有GPT相关工作都属于“速通竞赛”：后者通常给定固定数据集，目标是尽可能缩短达到特定损失值所需的时间；又如数据压缩（data comp）任务，则旨在筛选数据以实现特定精度水平。这类竞赛有助于激励研究人员开展富有成效的算法创新；但与此同时，对系统本身的评估对用户而言同样极具价值。因此，再次强调，明确评估规则并深入思考评估目的至关重要。以上便是对评估不同维度的一次快速概览，希望各位觉得有所启发。

## 段落 73

**英文**: Okay, that's all. See you next time.

**中文**: 好的，就这些。下次见。

---

*共 73 个段落，722 句话*
