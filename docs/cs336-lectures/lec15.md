# Lecture 15： Alignment - SFT⧸RLHF

生成时间: 2026-03-08 23:17:57

---

## 段落 1

**英文**: Okay, so we'll get started. Welcome to lecture 15. We've got two pieces left to the class, and that's going to be, you know, various aspects of post-training. Up until now, we focus very much on the big pre-training systems data components, and then now we're going to take the big pre-trained model, and we're going to make it useful and safe in various ways. So that's going to be the next two lectures from me. Today is going to be RLHF and sort of safety alignment stuff, and then Thursday is going to be RL from verifiable rewards, so things like reasoning, training, and math, and so on will be on Thursday. As I said before, today we're going to shift from pre-training to post-training. Percy in the very last lecture did cover some stuff about post-training data, but really I think the focus today is going to be in going from essentially this big transition that we saw in the field. So we have GPT-3, really remarkable system, really impressive, lots of pre-training, lots. of compute, but this is not really a useful system.

**中文**: 好的，我们这就开始。欢迎来到第15讲。本课程还剩下两部分内容，即关于“训后阶段”（post-training）的若干方面。到目前为止，我们一直高度聚焦于大规模预训练系统及其数据组件；而接下来，我们将以一个已预训练完成的大模型为基础，通过多种方式使其变得实用且安全。这部分内容将由我主讲，共分为两次讲座：今天讲授基于人类反馈的强化学习（RLHF）以及安全性对齐等相关内容；周四则讲授基于可验证奖励的强化学习，例如推理训练、数学能力训练等。如前所述，今天我们正式从预训练转向训后阶段。珀西（Percy）在上一讲中曾简要介绍过一些训后数据相关内容，但今天的核心重点，是深入探讨该领域所经历的一次重大范式转变。以GPT-3为例：它确实是一项非凡而令人印象深刻的系统，投入了海量的预训练数据与巨大的算力，但本质上，它仍不是一个真正可用的系统。

## 段落 2

**英文**: I guess there was a couple startups around building, add copy and things like that, but it was not very useful. It didn't follow instructions. It didn't do anything particularly too interesting from a product point of view. And then all of a sudden, we got chat GPT. And chat GPT can do all sorts of amazing things and follow instructions, and we've kind of seen what that has done to society since then. So today's focus is going to be on this arrow right here. How do we take a pre-trained system like GPT-3, and how do we make something like chat GPT, and then we're going to try to get to the nuts and bolts of that process. And I think many, most of you, have never worked on things like controllable generation or the previous generation of tech generation systems, but really modern instruction following models are just amazing. This is one of my favorite examples from Sebastian Bubex, Spark Syvey's EY paper in 2023 around when GPT-4 came out. But it can follow this very long block of nested compound instructions, and then combine that with its coding capability to output zero-shot map hot lib code.

**中文**: 我猜当时曾有几家初创公司围绕构建、添加副本等功能展开探索，但效果并不理想：它无法遵循指令，从产品角度看也缺乏足够吸引力。随后，ChatGPT横空出世——它能完成各种令人惊叹的任务，精准执行指令；自那以后，我们已亲眼见证了它给社会带来的深远影响。因此，今天我们将聚焦于图中这条箭头所指的方向：如何以GPT-3这类预训练模型为基础，构建出类似ChatGPT的系统？我们将深入剖析这一过程的核心机制。我想在座各位中，多数人可能从未涉足可控文本生成或上一代文本生成技术的研究，但真正现代的指令遵循模型确实令人叹为观止。这里展示的是我最钟爱的案例之一：塞巴斯蒂安·布贝克（Sebastian Bubeck）与斯帕克·斯维（Spark Svey）在2023年GPT-4发布之际联合发表的埃森哲（EY）论文中的范例。该模型能够准确执行这一大段嵌套复合指令，并结合其编程能力，零样本生成Map Hotlib代码。

## 段落 3

**英文**: And I think all of you just like take this for granted now. It's like, yes, of course, chat GPT can follow 10 instructions at once. But it's just kind of amazing that it can do this, right? And I think part of my excitement about this lecture is the fact that it can do all of this. And the other thing that I think is very important, right, is that now that these systems. are out in the wild, safety and content moderation just becomes really important, right? Maybe from the perspective of these models might get misused, someone might try to use them for scams, and also content moderation if you're thinking about these, this being like useful products that you can like ship and like people would pay for, right? People don't really want to pay for or put ads on systems that are like horrifically toxic, right? I think one of the big reasons why chat GPT has been so successful is that it has really significant guardrails around it. So, okay, given that, the goal today is to try to enable much tighter, better controls on language models, right? Pre-training, you can think of mental, the mental model can be that it packs the model with all sorts of capabilities, right? Like after pre-training, the model is able to somewhere within the parameters, do lots of things like reason and answer questions. But it's not going to do them out of the box. And so today what we're going to try to do is get models to do that out of the box. And so what we're going to do is to collect data of various kinds of behaviors that we do want from the language model and train it to do those things, right? And so the question is that you should be asking now is, you know, what does that data look like? How hard is it to collect that data? Perseus touched on it a little bit, but given the importance of data, I'm going to re-emphasize it a little bit. I'm going to have some interactive exercises to go over that.

**中文**: 而且我想，你们所有人现在都已将这一点视为理所当然。就好比说：“是啊，当然了，ChatGPT 一次就能执行十条指令。”但事实上，它竟能做到这一点，本身就很令人惊叹，对吧？我认为，我对本次讲座感到兴奋的部分原因，正在于它能完成所有这些任务。另一件我认为非常重要的事是：如今这些系统已广泛投入使用，安全性和内容审核就变得尤为关键。从模型的角度看，它们可能被滥用——例如有人试图利用它们实施诈骗；同时，若要将这些模型打造为真正可用的产品并推向市场、让用户愿意付费使用，内容审核就必不可少。毕竟，人们并不愿为那些充斥着极端有害、毒性内容的系统付费，也不愿在其上投放广告，对吧？我认为，ChatGPT 如此成功的一大原因，正在于其内置了极为严格的防护机制。  
那么，在此基础上，我们今天的目标就是：为大语言模型实现更精细、更有效的控制。预训练阶段，你可以将其理解为在模型中“注入”各种能力——也就是说，经过预训练后，模型的参数中已蕴含了推理、问答等大量功能。但这些功能并不会开箱即用。因此，我们今天要做的，正是让模型能够开箱即用。具体而言，我们将收集各类期望语言模型展现出的行为数据，并据此训练模型执行相应任务。此时，你们应该思考的问题是：这类数据究竟长什么样？收集难度有多大？珀尔修斯（Perseus）此前已稍作提及，但鉴于数据的重要性，我将再次着重强调。接下来，我还将安排一些互动练习来深入探讨这一问题。

## 段落 4

**英文**: And then there's algorithmic questions. Like how do we make use of that data, right? Some kinds of data are easy to use. Like, you know, if you have expert demonstrations, you just train to imitate that. But if you ask things like pairwise feedback, like model output A is better than model output B, how do we make use of that? And then finally, like, you know, how do we scale this up? How do we do the usual things that we've been doing in this class?. So the structure of this lecture is roughly going to mirror the instruct GPT paper, because a lot of the post-training pipeline that we have today is still off the instruct GPT paper. And so the first part of this lecture is going to be on supervised fine tuning. So if you look at the instruct GPT paper, you'll see this diagram that roughly describes a three-step process for building an instruction-following model. So part one of this lecture is going to be the leftmost part. The part where what we're going to do is we're going to do supervised fine tuning on. expert demonstration.

**中文**: 然后是算法层面的问题，例如：我们该如何利用这些数据？某些类型的数据很容易使用，比如，如果你拥有专家示范数据，只需直接训练模型去模仿即可。但如果你获得的是成对反馈数据（例如“模型输出A优于模型输出B”），又该如何加以利用呢？最后，我们该如何将这一整套方法规模化？如何实现本课程中一贯采用的那些常规操作？  
本讲座的结构大致将参照《InstructGPT》论文，因为目前主流的后训练流程在很大程度上仍沿袭自该论文。因此，本次讲座的第一部分将聚焦于监督微调。若查阅《InstructGPT》论文，你将看到一幅示意图，大致描述了构建指令遵循模型的三步流程。本次讲座的第一部分即对应图中最左侧的部分，也就是基于专家示范数据开展监督微调。

## 段落 5

**英文**: And then part two, we're going to follow the next two parts of this structure. We're going to talk about reinforcement learning and pairwise feedback. Broadly, I'm going to say that the ingredients in order to get this first part working, I mean, there's two things that we have to kind of think about. The first part is the training data, right? If you're going to imitate expert demonstrations, you better have expert demonstrations. Like, what does that look like?. And then the second thing I want to talk about is kind of the method. Like, you have data now. Like, how are you going to adapt to it? And there's an obvious answer. I'll talk about this again, but like, just do gradient descent. So there's also a kind of non-obvious part to this answer.

**中文**: 接下来是第二部分，我们将按照该结构的后续两个部分展开，探讨强化学习和成对反馈。总体而言，我将指出：要使第一部分顺利运行，需考虑两个关键要素。第一个要素是训练数据——如果你要模仿专家示范，就必须拥有专家示范数据，那么这些数据具体是什么样的呢？第二个要素是方法——现在你已拥有数据，该如何据此进行适配？对此有一个显而易见的答案（我稍后会再次提及）：直接采用梯度下降法。但这一答案中也包含一个并不那么显而易见的部分。

## 段落 6

**英文**: And in case you haven't been following how people build these models today, this might be still surprising. So I'll leave that as a teaser for later. So in Percy's lecture, he's mentioned already several different kinds of instruction data. But today, we're going to walk through a couple of them, and we're going to do a little bit of an interactive exercise. So those of you who have your laptops open can use those for good. So I want to talk about two different details. Like, one of them is what's inside these data sets? People often say data matters a lot. I think post-training is one place where this is even more true than before, because you're using very small amounts of data to get exactly the behaviors you want. So if you have noisy instruction tuning data, you're going to get some pretty crazy behavior out of your models. And then what kinds of things should we be paying attention to? If you're in charge of post-training data coction, what kinds of things might matter? So I have taken three different data sets from basically constructed in three very different ways.

**中文**: 如果你一直没关注当下人们构建这些模型的方式，这或许仍会让你感到惊讶。因此，我暂且将其作为后续的悬念。在珀西的讲座中，他已提到了几种不同的指令数据类型。而今天，我们将逐一介绍其中几种，并进行一个小型互动练习——所以，各位如果已打开笔记本电脑，现在就可以派上用场了。我想重点探讨两个细节问题：其一，这类数据集内部究竟包含什么内容？人们常说数据至关重要；我认为，在后训练阶段，这一点甚至比以往任何时候都更加突出，因为此时我们仅使用极少量的数据，便要精准塑造模型所需的行为表现。倘若指令微调数据存在噪声，那么你的模型就可能表现出相当离谱的行为。其二，我们应当重点关注哪些方面？如果你负责后训练数据的收集工作，哪些因素可能至关重要？为此，我选取了三个数据集，它们的构建方式截然不同。

## 段落 7

**英文**: You might even call them three different paradigms to building instruction, following or post-training data. And we're going to go through each one, and then we'll look at them closely, and then we'll think a little bit about what's going on with these data sets. So I'm talking about Flaun. This is by a bunch of Google folks. And Flaun is going to be essentially constructed by aggregating a bunch of training data sets from NLP tasks. Right? So if you look at it, you see all sorts of different tasks like natural instructions V2, which has a bunch of question answering and things. It's got T0, SF, you know, adversarial QA, and like topic classification. So basically this was constructed by taking existing NLP data sets that do all sorts of individual tasks and then aggregating them into one big meta data set. So this is one approach to building such data sets. We've got open assistant on the right.

**中文**: 你甚至可以将它们称为构建指令、遵循或后训练数据的三种不同范式。接下来，我们将逐一介绍这三种范式，然后深入分析它们，最后再思考一下这些数据集背后所发生的情况。首先，我来谈谈Flaun——这是由一群谷歌研究人员提出的。Flaun本质上是通过聚合大量自然语言处理（NLP）任务的训练数据集而构建的，对吧？具体来看，其中包含了各种各样的任务，例如“自然指令V2”（Natural Instructions V2），该数据集涵盖大量问答类任务；此外还包括T0、SF、对抗性问答（Adversarial QA）以及主题分类等任务。简言之，Flaun的构建方式是：选取现有各类独立NLP任务的数据集，再将其整合为一个大型的元数据集。这就是构建此类数据集的一种方法。右侧展示的是Open Assistant。

## 段落 8

**英文**: And this was I think a pretty unique sort of endeavor in which a bunch of online enthusiasts got together and decided to write instruction tuning data for language models. Like right after the release of ChatGPT, I think the exciting thing is that we've got a slightly different development. And so there's a lot of good, high quality, human, and data from that effort. And lastly, of course, this is a bit of self-advertisement here. But as a representative of the kind of like language model generated post-training data or like AI feedback style data, I'm going to talk a little bit about some of the data from. Stanford Alpaca. So let's just look at examples. Like I think looking at examples and talking about them are very useful. Now this is from random examples taken from the Flan data set. You can kind of see the types of stuff that are in here.

**中文**: 我认为这是一项相当独特的尝试：一群线上爱好者聚集在一起，决定为语言模型编写指令微调数据。就在ChatGPT发布后不久，令人兴奋的是，我们由此开启了一条略有不同的发展路径。因此，这项工作产生了大量优质、高质量、由人工构建的数据。最后，当然，这里略带一点自我宣传的意味。但作为语言模型生成的后训练数据（或称“AI反馈”风格数据）的代表，我将简要介绍一些来自斯坦福Alpaca项目的数据。下面我们直接来看几个示例——我认为，观察并讨论具体示例非常有帮助。这些示例随机取自Flan数据集，您大致可以了解其中包含的内容类型。

## 段落 9

**英文**: So you've got things that look like pretty normal instruction tuning data, like right highlights for this article. So I'm throwing down leafy avenues past Dutch step-gabled buildings, and then in the end,. there's even more information on travel in the Netherlands at www. hallen. com. And then it answers the least known of the Dutch cities, the Hague, was a village, and then it sort of summarizes this as a highlight. You've got something like this where this is like, what is this text about? Here are your four options. It's business, right? So this is kind of a multiple choice training thing that's happening. This, you know, pretty talked about the end-run data set. So you all can like, you know, smile a little bit.

**中文**: 因此，您所拥有的数据看起来就像相当常规的指令微调数据，例如针对本文的亮点摘要。比如：“我穿行于绿树成荫的大道，掠过荷兰典型的阶梯式山墙建筑”，最后还补充道：“有关荷兰旅游的更多信息，请访问www.hallen.com。”随后，它回答了“荷兰最不为人知的城市是哪座？”这一问题，指出海牙最初只是一个村庄，并将此概括为一个亮点。您还会看到类似这样的内容：“这段文字讲的是什么？”并附上四个选项——其中正确答案是“商业”。这实际上是一种多项选择题式的训练方式。您可能已听说过这种“绕道数据集”（end-run dataset），大家不妨会心一笑。

## 段落 10

**英文**: Things like this of taking, let's say maybe the end-run email data set, and you paste back right a subject line for this email, and now you've got kind of supervision for that task, right? This one, I guess no one here has probably worked on text generation, but this is from a data set called E2E, where you have like a database entry, and then you're supposed to write a sentence that describes that restaurant. So immediately you kind of see, you know, you can probably get a lot of data for free this. way, right? You can put them all together, and you will get a really big aggregated data set. And so in that sense, FOM was a, you know, ahead of its time and produced a ton of data for this kind of thing. But also we see in many ways that this can be somewhat unnatural, right? Like, we've already seen that like this end-run data set is a little bit weird. We can really definitely see things like, oh, here's a text, and then now you sort of append sort of the options that turn it into a task. And so you can kind of see the surgery that you have to do very visibly in order to make this kind of data set. And I think if you look at this, you'll agree with me that this isn't your usual chat interaction, right, for something like chat GPD. Another example for this is Alpaca. This was like a really, really early attempt at using language models to generate instruction tuning data.

**中文**: 诸如此类的数据构造方式——例如，假设我们采用“End-Run”电子邮件数据集，然后直接为其粘贴回一条邮件主题行，这样便为该任务提供了某种形式的监督信号，对吧？再看这个例子，我猜在座各位可能没人做过文本生成相关工作，但这是来自一个名为E2E的数据集：其中包含数据库条目，而你的任务是据此撰写一句描述该餐厅的句子。因此，你立刻就能意识到，这种方式或许能让你免费获取大量数据，对吧？你可以将所有此类数据整合起来，从而构建出一个规模极为庞大的聚合数据集。从这个意义上说，FOM（Few-shot Optimized Model）可谓颇具前瞻性，为这类任务生成了海量数据。但与此同时，我们也发现，这种方式在许多方面显得略显生硬、不够自然，对吧？比如我们此前已注意到，“End-Run”数据集本身就有几分怪异。我们确实能清晰地看到：先给出一段文本，再人为附加若干选项，从而将其转化为一项具体任务。因此，为构建此类数据集所必须进行的“手术式”加工过程，可谓一目了然。我想，当你审视这一过程时，定会认同我的观点：这显然并非ChatGPT之类模型所面对的那种常规对话交互场景。另一个典型例子是Alpaca，它属于最早一批尝试利用语言模型自动生成指令微调数据的探索之一。

## 段落 11

**英文**: And so, you know, just to describe the procedure here, you know, a language model was used. There was a seat set of human written instructions. And then the language model was used to essentially generate more instructions that's the left column. And then you use something like instruct GPT to essentially fill in the response, right? And so here, you know, now we have something that looks a little bit more like, you know, on the left, standard sort of chat GPT inputs. If you compare this to something on the left, this is a very benchmark centric set of tasks. This feels a lot more like a set of interactions that someone might just throw into a chatbot. And the response is almost always in long form natural language versus with flon often, it can be quite short, like one word or phrase or something like that, right? So we kind of see that, of course, you know, we also see that on the left, these are, in some ways, not very diverse inputs. They're very short instructions. And then open assistant is kind of the third leg of this instruction tuning saga. You kind of see more complex queries on the left.

**中文**: 因此，这里简单描述一下该流程：使用了一个语言模型，配合一组人工编写的指令作为种子数据集；然后利用该语言模型生成更多指令（即左侧列）；接着再用类似InstructGPT的模型来生成对应响应，对吧？这样一来，我们现在得到的数据就更接近日常聊天场景了——左侧看起来更像是标准的ChatGPT输入。与之相比，左侧这类任务高度侧重基准测试，而当前这套数据则更贴近普通用户随意输入聊天机器人的实际交互情形；其响应几乎总是以长篇自然语言形式呈现，而FLON数据集中的响应往往非常简短，可能仅是一个单词、一个短语之类。当然，我们也能看到，左侧这些输入在某种程度上缺乏多样性，普遍极为简短；而OpenAssistant则构成了指令微调这场演进中的第三股力量，其左侧所呈现的查询明显更为复杂。

## 段落 12

**英文**: And then because back then, I guess people were just really into writing long detailed. supervision for models, you see like actually really detailed responses. And this one even has a citation on, you know, how, like what makes this answer correct, right? And so, you know, very high quality, but also kind of very difficult. And so, now this is the first interactive task in this class. But especially those of you that have your laptops open, you know, please go to this URL. This should be a Google form. And there will be a sort of one sort of prompt. And now we're collectively going to crowdsource an instruction tuning response. And I'll give you all, let's say, five minutes to do so. Let me know if the link is wrong, but I did test this last night.

**中文**: 然后，因为当时人们确实热衷于为模型编写冗长而详尽的监督数据，所以你会看到那些极其详尽的回复。甚至这一条还附有引证，说明为何该答案是正确的，对吧？因此，其质量非常高，但同时也相当困难。现在，这是本课程中的首个互动任务。特别是那些已打开笔记本电脑的同学，请访问该网址。这应该是一个谷歌表单，其中包含一个提示。接下来，我们将共同协作，通过众包方式生成一条指令微调的回复。我给大家五分钟时间来完成。如果链接有误，请及时告知我；不过我昨晚已经测试过了。

## 段落 13

**英文**: So hopefully this is a working. And then we'll look at the responses briefly. And then I want to talk about why I did this exercise. There is a teachable moment here rather than sort of getting you just off your left off for a moment. OK, excellent. I think there's a decent number of responses. So I'm going to maybe put them up. Whoa, let's see if I can put them up. Then yeah, there we go. OK.

**中文**: 因此，希望这能顺利进行。接下来，我们将简要查看一下大家的回复。然后，我想谈谈我设计这项练习的原因——这里有一个值得教学的契机，而不是简单地让大家暂时放松一下。好的，非常棒！我觉得已有不少回复。我这就把它们展示出来。哇，让我看看能否成功展示……好了，就是这样。好的。

## 段落 14

**英文**: So in many ways, I think this reflects the kinds of data you get. I mean, if anything, you guys are all motivated to do this task, then I think the standard. crowd worker, you know, but you've got the person. I'm not sure what's going on here, but this is probably chat GPT. There's a lot of emojis. I'm getting trolled, but this is, I mean, I am preparing for lifthons. That's a good response. You've got the NAFAM, which of course is the kinds of things that you'll get out of crowdsourcing. And I think hopefully one thing that you've seen or felt as you were doing this is that it's actually really difficult to write long form responses, especially for something. that you aren't prepared for.

**中文**: 因此，从许多方面来看，我认为这反映了您所获得的数据类型。我的意思是，如果说有什么特别之处的话，那就是在座各位都积极主动地完成了这项任务，而相比之下，标准的众包工作者——您知道的——可能就只是随便应付一下。但这里的情况却有些不同，我不太确定发生了什么，不过这很可能是ChatGPT生成的内容：其中夹杂着大量表情符号。我感觉自己被戏弄了，但话说回来，我正在为“ Lifthons”（举重马拉松）做准备——这倒是个不错的回答。您还得到了“NAFAM”（非预期、不相关、敷衍、含糊、错误、多余），这当然正是众包方式常会产出的典型结果。我想，大家在完成这项任务的过程中，或许已经察觉或体会到一点：撰写长篇幅的回答其实非常困难，尤其是面对一个您事先毫无准备的话题时。

## 段落 15

**英文**: And so you get a lot of short responses like this. It's very difficult, I think, to get people to write sort of long detailed responses like this one at the very top. Often those kinds of things are from chat GPT. And of course, you'll get things like, you know, I saw this one. Ice cream is a frozen dessert, typically made from milk or cream. And you're going to have to filter out those kinds of things that you're going to get. through crowdsourcing. So why did I talk about this? Well, of course, you know, now you have a sense of what this task is like. Annicator's in the wild, even if their experts will be under time constraints. And I think one of the reasons why things like AI feedback or using LMS to try to refine or generate these kinds of data has really gotten popular is, you know, if you look at the GPT-40 response to this, you know, it's pretty good.

**中文**: 因此，你会得到大量此类简短的回复。我认为，要让人们写出顶部这种长篇详尽的回复，难度非常大；这类回复往往出自ChatGPT等AI工具。当然，你还会遇到类似这样的内容——比如我看到过这条：“冰淇淋是一种冷冻甜点，通常由牛奶或奶油制成。”而通过众包方式获取的数据中，诸如此类的内容都需要你加以过滤剔除。那么，我为何要谈这些呢？原因显而易见：如今你已大致了解这项任务的实际情形——即便专家在真实场景中开展标注工作，也难免面临时间压力。而我认为，AI反馈或利用大语言模型（LLM）来优化、生成此类数据的做法之所以日益流行，正是因为：如果你看看GPT-4对这一问题的回应，就会发现其质量相当不错。

## 段落 16

**英文**: It's a pretty good response to this question. It's very long. It's very detailed. And generating this kind of a human response is going to take a lot of effort and a lot of cost, right? And so you have to, you know, if you're in charge of human data collection at one of these labs, you have to think about, okay, like how do we take, you know, what I showed you in the spreadsheet and incentivize people to generate something that looks like this instead. That is no easy task at all. That is a very difficult crowdsourcing task. Okay. So these things that we've just seen, they vary quite a bit in things like length. We saw, you know, the chat GPT is in which is bullet points, like lots of style variations. We saw in the open assistant example that, you know, sometimes people put in references, sometimes they put in sort of very complex, deep knowledge.

**中文**: 这是对这个问题相当不错的回答。它篇幅很长，内容非常详尽。而要人工生成这样一种回复，无疑需要耗费大量精力和高昂成本，对吧？因此，如果你负责这些实验室中的人类数据采集工作，就必须思考：好吧，比如我刚才在电子表格中向你们展示的内容，我们该如何激励人们生成类似这样的回复呢？这绝非易事，而是一项极具挑战性的众包任务。  
好了，我们刚刚看到的这些回复，在长度等方面差异很大。例如，我们看到ChatGPT的回复采用的是项目符号形式，风格变化丰富；而在OpenAssistant示例中，我们发现有时人们会加入参考文献，有时则融入了极为复杂、深入的专业知识。

## 段落 17

**英文**: Like is that good or bad?. I'll talk about that in a moment. And there's also other important aspects to this process, right? Maybe you want to collect a ton of data or very little data that's high quality, so you got this trade off. You also have to think a lot about safety, right? Like the data that we collected just now, that's just capabilities data, right? Just makes models answer things like what is CS336. It does not help us make our models, you know, you know, refuse malicious instructions. and things like that. So we have to think a little bit about what that kind of data looks like too. Okay. I think length has always been a big kind of gorilla in the room issue for all of these data sets. You know, when back in 2023, when it was very, very popular to generate these kinds of instruction tuning data sets, there's a survey like Ijong Wang and others at UW came up with this very nice survey coming looking over the many different kinds of data sets that were created.

**中文**: “喜欢”是好还是坏？我稍后会谈到这一点。此外，这一过程还有其他重要方面，对吧？比如，您可能希望收集大量数据，也可能只收集少量但高质量的数据，因此这里存在一种权衡。您还必须充分考虑安全性问题，对吧？比如我们刚才收集的数据，只是能力类数据，对吧？仅用于让模型回答类似“CS336是什么”之类的问题，并不能帮助我们让模型拒绝恶意指令等。因此，我们还需仔细思考这类数据应具备何种特征。好的。我认为长度问题始终是所有这些数据集所面临的一个突出而棘手的难题。要知道，在2023年，生成此类指令微调数据集曾一度极为流行；华盛顿大学的李 Jong Wang 等人曾发布一份非常出色的综述报告，系统梳理了当时创建的多种不同类型的数据集。

## 段落 18

**英文**: early in that year. And you kind of see, if you look at the length of both the prompts, so that's the inputs and the responses, the completions, you see like really different lengths of both inputs and outputs. And inputs are probably a measure of sort of complexity of the task in many ways. And then the outputs are in some sense a measure of how much you push the annotators or if you used AI generated responses. And one of the things that you should be, you know, all aware of, you know, let's say. you got put in charge of making a new language model, you're in charge of post training. Well, you know, if you're using human e-vails, people have a strong preference for lists. I mean, so do actually if you use AI as a judge, they also have a strong preference for lists. And people have a very long preference for outputs like 60, 70% ish preference for longer outputs. And so do sort of AI judges, right? And so this is a little concerning because you want to be optimizing for not just kind.

**中文**: 那一年年初。如果你观察一下提示词（即输入）和回复（即模型生成的补全内容）的长度，就会发现两者的长度差异很大。输入长度在很多方面可视为任务复杂度的一种衡量指标；而输出长度则在某种程度上反映了你对标注人员施加的压力程度，或是否采用了AI生成的回复。这里有一点需要特别注意——假设你被委以重任，负责开发一款新语言模型，并主管其后训练阶段：如果你采用人工评估员，他们明显偏好列表形式的输出；实际上，即便使用AI作为评判者，它们同样强烈偏好列表。此外，人类评估员对较长输出的偏好度高达约60%至70%，AI评判者也表现出类似的倾向。这一点略令人担忧，因为我们的优化目标不应仅仅局限于……

## 段落 19

**英文**: of the stylistic content of your responses. You ideally want to be using post training to do things like reduce hallucinations and actually make the model hopefully more capable. One thing that we do see is that, you know, these factors are not super relevant for benchmark performance. So if you look out, for example, and then the LU performance, kind of despite the really big variation in length for a lot of these models, most of the instruction tuning data sets, like the simple ones, you know, give you boosts over kind of the base model, which. is the very top row above. So I think one of the things that I'll say here is, you know, chat style evaluations have their place. You know, chat bot arena, alpaca, eval, these kinds of automated, you know, evals have their place in helping understand like user engagement and things like this. But benchmarks also have a very important place. Because when you post train, you don't necessarily want to be too affected by, for example, length biases and open edit domains and so on. And so you want to be really careful of these effects.

**中文**: 关于您回复的风格化内容。理想情况下，您应利用后训练来减少幻觉现象，并切实提升模型能力。我们观察到的一个现象是，这些因素对基准测试性能的影响并不显著。例如，观察LU（语言理解）性能时，尽管许多模型在长度上存在巨大差异，但大多数指令微调数据集（如简单的那些）仍能为基线模型（即最上方一行所示的模型）带来性能提升。因此，我想强调的一点是：聊天风格的评估自有其价值所在——例如Chatbot Arena、Alpaca Eval等自动化评估方法，在理解用户参与度等方面确有帮助；但基准测试同样具有极其重要的地位。因为进行后训练时，您未必希望自身结果过度受到长度偏差、开放编辑领域等因素的影响，因此必须格外谨慎地对待这些效应。

## 段落 20

**英文**: You want to have a different diverse array of evaluation strategies to try to avoid those pitfalls. One other thing that I think really trips people up when they initially start thinking about these things is to say, oh, what I'm doing is I want to collect high quality data. And high quality data has lots of deep knowledge and has lots of citations, right? Like that's a reasonable thing to say. And I think, you know, open assistant, I think had a great example of this, right?. And so here's an example input output pair. You've got an introduction about monopsony and economics. And then there's these references on the response on the right. So now let's say we have a model and we find you in the model to take the left side as input and reproduce the right side as output, right? So you can kind of think about two different things that this process is going to do at the same time, right? So one of the things that this is going to do is it's going to associate monopsony with. that citation, right? So it's learning new knowledge. So that is good, right? So that is a positive thing to do.

**中文**: 您需要采用多种不同的评估策略，以避免这些陷阱。另一点我认为初学者在思考这些问题时常常会陷入误区：他们认为“我所要做的就是收集高质量的数据”，而所谓高质量的数据，就是包含大量深度知识和丰富参考文献的数据，对吧？这种说法本身是合理的。我想，Open Assistant 就是一个很好的例子。下面便是一组示例输入-输出对：左侧是关于“买方垄断”及其经济学含义的介绍，右侧则是响应内容中所附带的参考文献。现在假设我们有一个模型，并让该模型将左侧内容作为输入，尝试复现右侧内容作为输出，对吧？那么，我们可以从两个不同角度来理解这一过程同时实现的目标：其一，模型会将“买方垄断”与相关参考文献关联起来，即学习新知识——这显然是有益的、积极的。

## 段落 21

**英文**: But it's also going to do a second thing at the same time, which is this kind of generalized thing of saying, if you asked me a complicated concept, I had better finish the output with a reference, right? And so it's basically the first thing is teaching new knowledge, which is good. But the second thing here is kind of teaching the model to hallucinate, right? Like if the model doesn't already have somewhere within its parameters, an association between monopsony and this citation, this bivens and missual book, you know, what might happen instead is it just learns that, oh, what I should do is whenever I have a complicated input, I should give a response and then make up a reference at the very end, right? Those are two competing explanations for what is happening here. And this is going to motivate, in some ways, the second part of this lecture, right? John Schoelman has this kind of great talk, I think he gave it up, Berkeley, where, you. know, his argument is, basically, if you do this kind of thing, you're going to encourage the model to hallucinate, right? Like the model doesn't have the knowledge of answering a question. You force it to answer that question. What it's going to learn is, of course, I'll learn the knowledge in some abstract sense, but it will also learn the other aspect of, I just need to make something up in order to sort of type check what the response should look like. Okay, yes, there's a question. So, do you want to write a designer paper? Why? I think has a sense of, like, okay, I think I need to add a citation here, let me search for the relevant citation. Either for memory or let me actually use a database. It is, the fact that, like, the element is learning that, like, okay, here I should insert a citation.

**中文**: 但与此同时，它还会做第二件事：即形成一种泛化的倾向——当你向我提出一个复杂概念时，我最好在输出末尾附上参考文献，对吧？因此，第一件事本质上是在传授新知识，这固然很好；但此处的第二件事，却相当于在教模型“幻觉”（即编造信息），对吧？例如，如果模型参数中原本并未建立“买方垄断”（monopsony）与《比文斯与米苏尔之书》（Bivens and Missual book）这一引文之间的任何关联，那么更可能发生的情况是：模型仅学会了一种模式——即每当输入较为复杂时，就先给出一个回答，再在结尾凭空捏造一条参考文献，对吧？以上两种解释彼此竞争，用以说明当前现象的本质。而这在某种程度上，也将引出本次讲座的第二部分内容。约翰·肖尔曼（John Schoelman）曾做过一场非常精彩的演讲（我认为是在伯克利大学发表的），其核心论点正是：如果你持续采用这类做法，就会促使模型产生幻觉。换言之，当模型本身并不具备回答某个问题所需的知识时，你却强制它作答；那么它所学到的，一方面固然是某种抽象意义上的知识，但另一方面，它也会习得另一条策略：即只需随意编造内容，即可使输出形式上符合预期的响应格式。好的，是的，这里有个问题。那么，你是否打算撰写一篇设计类论文？为什么？我认为作者心中隐约有这样的意识：“好吧，我觉得此处需要添加一条引文”，于是便着手搜索相关引文——要么调取记忆中的资料，要么实际查询数据库。事实上，这种行为正反映出模型已学会一种模式：“好，此处我该插入一条引文。”

## 段落 22

**英文**: It's actually a correct and desirable thing, and it's, and the fact that it's a made-up. citation is, a, either a memory issue or something, you can maybe open the tool usage in this, like, but, like, I don't see why I should use it. I mean, the behavior of needing to add a citation itself is problematic, but, like, if you can either fix the memory issue or the tool usage. Sure, I mean, I think the, okay, so to repeat the question, the question was, like, I guess that was a more comment than a question, was that the learning to put in a citation isn't a bad thing, right? Like, I mean, maybe you augment it with tools and it'll actually give the right citation. I mean, that's a fair point. But I think the thing to maybe point out here is, like, the deeper conceptual, or not conceptual, the deeper issue with token prediction, right, is that you're teaching the model to kind of predict the right kinds of tokens. And here, you know, essentially, the lesser of the two errors is to say hallucinating is less bad for my loss than not making up the reference at all, right? Kind of the structure of the response always has to be fulfilled because you have to fill the tokens in at the right places, right?. Of course, that scale, if you know the facts, if you have the right tools, right, those are, those are good. You know, make the predictions on the right spaces. But I do kind of think this is very indicative of this, like, this failure mode that models can get into, where you're trying to get it to do things that it can't, right? Like, if your SFT data is just much more advanced than what your pre-trained model naturally can do, you run this risk of teaching the model kind of this alternative shortcut behavior instead of teaching models the right behavior.

**中文**: 这实际上是一件正确且可取的事情；而所谓“虚构的”引文，要么是记忆问题，要么是其他原因——你或许可以在此启用工具调用功能。但坦白说，我看不出自己为何需要使用它。我的意思是，强制要求添加引文这一行为本身就有问题；不过，如果你能修复记忆问题或优化工具调用，那当然很好。  
好的，我来复述一下问题：这个问题更像是一条评论而非提问——即“学会添加引文本身并非坏事”，对吧？比如，你可以借助工具辅助，使其实际给出正确的引文。这确实是个合理的观点。  
但此处或许更值得指出的是：在令牌预测层面存在一个更深层的问题（姑且不称其为“概念性”问题），即我们是在训练模型去预测特定类型的令牌。在此情境下，两种错误中较轻微的一种，恰恰是“幻觉式编造”——因为相较于完全不生成参考文献，这种幻觉反而对损失函数的影响更小，对吧？毕竟，响应的整体结构必须被完整填充，你必须在正确的位置填入相应令牌，对吧？  
当然，若你掌握事实依据，又配备了恰当的工具，那自然更好——这样就能在正确的位置上做出准确预测。但我确实认为，这非常典型地反映出模型可能陷入的一种失败模式：即我们试图让模型完成它本不具备能力的任务。例如，若监督微调（SFT）数据的难度远超预训练模型自身天然具备的能力，就极易导致模型习得一种“替代性捷径行为”，而非真正掌握我们期望的正确行为。

## 段落 23

**英文**: Yeah. So, so that's John Schullman. I think he makes a fairly reasonable case that, you know, this is one of the reasons why like on policy, RL, like reinforcement learning style things, there's an important thing to do because you want to know what the model already knows and only teach it those things to avoid, you know, hallucinating. And whenever it's encountering some fact that it doesn't know, then maybe you should change your fine tuning data to say, oh, I don't know that fact instead of forcing the model to. try to answer, right? And we kind of see this on the kind of other sort of knowledge storage studies as well, where people have kind of talked about, you know, it's much easier for models to sort of reproduce known facts than sort of to learn sort of unknown facts where it just takes a lot longer for models to kind of learn facts that aren't showing in pre-training. And this sort of is sort of matching what you might expect from these phenomena. Okay, I think one of the things that I'll sort of, you know, summarize that with is that there's a very counterintuitive phenomenon for instruction tuning, which is that, you. know, you can have instruction tuning data set that is fully correct and like actually very rich, but actually that might not be good for your LM because it's going to teach your language model to sort of try to make up facts to match that depth of knowledge. That's always been, I think, one of the arguments for why you want to be really careful with both distillation data where the teacher model is stronger than your student model and also really human annotation where the human might be much more knowledgeable than the model, right? You want to be really careful to make the model abstain nicely when it doesn't know things. An in principle, you know, reinforcement learning style correctness could help and we'll talk about that in a moment and sort of optimizing this at the instruction tuning level is just really messy and very difficult.

**中文**: 是的。那么，这位就是约翰·舒尔曼（John Schullman）。我认为他提出了一个相当合理的观点：正因如此，在策略层面（例如强化学习类方法）开展相关工作才显得尤为重要——因为我们需要明确模型已掌握哪些知识，仅针对其知识盲区进行训练，从而避免模型“幻觉”（即编造事实）。当模型遇到其未知的事实时，或许我们更应调整微调数据，使其学会回应“我不知道”，而非强迫模型强行作答，对吧？我们在其他类型的知识存储研究中也观察到了类似现象：人们普遍认为，模型复现已知事实远比学习未知事实容易得多；而要让模型掌握预训练阶段未涵盖的事实，则往往需要更长时间。这一现象与前述观察基本吻合。  
好的，我想用以下一点来简要总结：指令微调中存在一种非常反直觉的现象——即使你所用的指令微调数据集完全正确、内容极为丰富，它实际上也可能不利于你的语言模型，因为它会促使模型试图编造事实，以匹配这种高深度的知识表征。这始终是主张我们必须审慎对待两类数据的关键论据之一：一是知识蒸馏数据（其中教师模型强于学生模型），二是人工标注数据（其中人类标注者往往远比模型知识渊博），对吧？因此，我们必须格外谨慎，确保模型在面对未知信息时能恰当地选择“拒答”。原则上，强化学习式的正确性优化或许有所帮助，我们稍后将就此展开讨论；但若试图在指令微调层面直接优化这一目标，则会变得异常复杂且困难重重。

## 段落 24

**英文**: I don't think people have really nailed it down, at least in the open research literature. The other thing I want to talk about briefly because I think this isn't necessarily something that can be solved with instruction tuning alone is, you know, to touch on safety and to think a little bit about what the trade-offs are here. So we know, you know, language models need some guardrails. They're deployed straight to end users. They're very capable so they might be used for misinformation or for generating things like scams or spam. And so there's a need for safety tuning these models. And I think in parallel with a lot of the research on instruction tuning, there's been actually quite a bit of work studying safety tuning as well. And I think some of the early work in this area, you know, kind of has shown that even a small amount of sort of safety tuning data that's mixed in to instruction tuning process. can make models much safer, sort of paralleling a lot of the findings that people had, that actually for instruction tuning as well, if you have a strong enough between model, even a small amount of instruction tuning data can get you a lot of the way. Not to say that's sufficient, but actually that's, you know, sort of gets you to a reasonable point.

**中文**: 我认为人们尚未真正解决这一问题，至少在公开的研究文献中是如此。另一点我想简要谈一谈，因为我认为这未必仅靠指令微调就能解决——即涉及安全性问题，并稍作思考：其中存在哪些权衡取舍？众所周知，语言模型需要一定的安全护栏。它们直接面向终端用户部署，且能力极强，因此可能被滥用于传播虚假信息，或生成诈骗信息、垃圾邮件等。因此，对这些模型开展安全性微调十分必要。事实上，在大量指令微调研究同步推进的同时，学界也已开展了相当多关于安全性微调的研究工作。该领域早期的一些研究结果表明，即便仅将少量安全性微调数据融入指令微调过程，也能显著提升模型的安全性。这一点与指令微调领域的诸多发现颇为相似：只要基础模型足够强大，即使仅使用少量指令微调数据，也能取得显著成效。当然，这并不意味着少量数据就已足够，但确实能帮助模型达到一个较为合理的安全水平。

## 段落 25

**英文**: And I think the core trade-off with safety tuning that I'll sort of touch on in this brief section is this trade-off between refusing things and not refusing kind of too much, right? So there's always this thing of, you know, if you have unsafe responses, you want your. safety tuning model to just refuse to answer. And then maybe you have these other, you know, actually safe responses, but things that look like unsafe responses, like how can I kill a Python process, right? We all know that is a reasonable question to ask. I guess if you're not, you know, if you don't understand English very deeply, you're like, oh, killing sounds very dangerous, so maybe I should refuse to answer that question, right? So how can you make models sort of understand this nuance?. It's a very tricky thing to do, you know, purely in the instruction tuning setting. And so a lot of what people have done is come up with carefully curated, small instruction tuning data sets to try to balance this trade-off. So even some research has shown that even like 500 examples can make models follow some of the safety guidelines. Well, it's okay. To put this together, instruction tuning is surprisingly powerful. I think, you know, you would think that given how powerful things like chat GPT are,.

**中文**: 我认为，在本简要章节中将要提及的安全性调优核心权衡，正是“拒绝回答”与“不过度拒绝”之间的权衡。换言之，始终存在这样一种张力：若模型生成不安全的回应，我们自然希望其安全性调优模型直接拒答；但另一方面，又存在一些实际安全、却表面看似不安全的回应——例如“如何终止一个Python进程？”这个问题，我们都知道它完全合理。然而，倘若模型对英语理解不够深入，就可能仅因“终止（kill）”一词听起来十分危险，便贸然拒答该问题。那么，我们该如何让模型理解这种细微差别？这在纯指令微调（instruction tuning）框架下实属极富挑战性的工作。因此，研究者普遍采取的策略是精心构建规模较小、高度筛选的指令微调数据集，以期在上述权衡间取得平衡。事实上，已有研究表明，仅需约500个样本，即可使模型初步遵循部分安全准则。总而言之，指令微调的效果出人意料地强大——你或许会认为，像ChatGPT这类系统如此强大……

## 段落 26

**英文**: that there's actually a ton of complexity into getting anything that works. I think you'll find that even if you take, you know, a fairly standard instruction tuning data set, like open hermys or open assistant or any of these data sets and you take a base model and you fine tune on it with reasonable hyper parameters, you're going to model that behaves a lot like a lot more chat GPT. It won't be quite as good. There's a lot of extra work to be to optimize it, but you can get pretty far. The second thing that's, you know, good to remember is basically the notion of high quality. data is just very complex and you have to reason about it really carefully. It's not obvious how to do. And then the last thing is, you know, actually even a small amount of data can have great leverage at the stage in changing how models behave. The last thing I want to end this section on is how to do this instruction tuning. There's kind of a, you know, a flippant answer to this, which is, well, you've got demonstrations.

**中文**: 实际上，要让任何模型真正有效运行，背后蕴含着巨大的复杂性。我认为，即便你采用一个相对标准的指令微调数据集（例如OpenHermes、OpenAssistant或类似的数据集），并以一个基础模型为起点，在合理超参数设置下对其进行微调，最终得到的模型行为也会与ChatGPT非常相似——尽管性能尚不及后者；后续还需大量额外工作进行优化，但已能取得相当可观的效果。第二点值得牢记的是，“高质量数据”这一概念本身极为复杂，必须审慎细致地加以分析，其具体实现方式并不显而易见。第三点是，即使少量数据，在改变模型行为方面也能产生显著影响。最后，我想在此部分结尾处简要说明如何开展指令微调：对此问题，一种略带戏谑的回答是——你已有示范样本（demonstrations）。

## 段落 27

**英文**: Just put in the instruction and the response and just do some gradient descent, right? We all know how to do gradient descent at this point. I think in most academic settings, that's basically it, right? You're done. You do your small scale gradient descent and you're done. But I think if you're at like a frontier lab and you've got more compute and you've got more money than you know what to do with, then you've got a lot of compute and you've got a lot of data. And so you can scale this whole process up quite a bit. You can scale it up a lot. The modern instruction tuning pipelines are starting to look a lot like pre-training pipelines. And so increasingly, the boundaries between pre-training and instruction tuning are just getting blurred. Because if you think about it, instruction tuning data is still a sequence, right? It's just a sequence of tokens. And so I can throw that in into my pre-training process.

**中文**: 只需输入指令和响应，然后进行一些梯度下降，对吧？此时我们大家都知道如何做梯度下降了。我认为在大多数学术环境中，基本也就如此了，对吧？任务就完成了。你只需开展小规模的梯度下降，任务即告结束。但如果你身处一家前沿实验室，拥有远超所需的算力与资金，那么你便拥有大量算力和海量数据，从而可将整个流程大幅扩展，甚至极大程度地扩展。当前的指令微调流程正日益趋近于预训练流程，因此预训练与指令微调之间的界限正变得愈发模糊。因为细想一下，指令微调所用的数据本质上仍是一段序列，对吧？它不过是一串词元（token）而已。因此，我完全可以将其直接纳入预训练流程中。

## 段落 28

**英文**: And that's a totally valid thing to do. And so this is an increasingly popular idea. I think the close labs don't tell us anything. But I think the things that people have told me in bits and pieces suggest that this is what they're doing. A lot of the open groups from China do basically this now. And so what you do is you have your usual pre-training setting, right? You do pure pre-training. And then what you're going to do is you're going to start mixing in instruction tuning data into pre-training. So the kind of the tail end of your pre-training, especially as you're kind of annealing the learning rate, you're going to start putting in a lot of this higher quality data or instruction tuning data. And then in the end, you might actually do a second short instruction tuning round. But maybe this is smaller because most of your data has already gone into the second stage what people call mid-training.

**中文**: 而这完全是一种合理可行的做法，因此这一理念正变得越来越流行。我认为，闭源实验室并未向我们透露任何相关信息；但据人们零散地向我透露的情况来看，他们似乎正是这样做的。目前，中国许多开源团队基本已采用这种方式。具体而言，你首先进行常规的预训练（即纯粹的预训练），随后在预训练后期——尤其是在学习率逐渐衰减阶段——开始将指令微调数据逐步融入预训练过程，大量引入这类高质量数据或指令微调数据。最终，你或许还会进行第二轮较短的指令微调，但该轮次规模可能较小，因为大部分数据已在人们所称的“中期训练”（mid-training）阶段被纳入。

## 段落 29

**英文**: And this is cool because it lets you scale up without catastrophic forgetting issues. You might get more leverage out of your data because it's integrated more deeply into. the pre-training. And to give you an example or a sense of what this looks like, it's a bit of a shame that data mixes are often pretty closely guarded secrets by a lot of the groups. So I've taken this figure from MiniCPM, which we've talked about before, great paper from the Chinese groups, where basically they have a two stage training pipeline, where they have a first stage where they do pure pre-training. And if you look at this pie chart, this is all pre-training data sets. Common crawl, code pre-training, pile, DOMA, they've thrown it all in into one big pie. And then they have a second stage, which they call the decay stage. And so if you remember my lecture on scaling laws, I talked about WSD warm up stable decay. So that's the stable stage.

**中文**: 这非常棒，因为它使你能够在不出现灾难性遗忘问题的情况下实现模型规模的扩展。由于数据更深入地融入了预训练过程，你或许能从数据中获得更高的利用效率。为帮助你直观理解这一流程，需要指出的是，数据混合方案通常被许多研究团队严格保密，这多少有些遗憾。因此，我引用了MiniCPM（我们此前讨论过）论文中的示意图——这是一篇来自中国研究团队的优秀论文。该方案采用两阶段训练流程：第一阶段为纯预训练阶段；若观察该饼图，其中展示的均为预训练数据集，包括Common Crawl、代码预训练数据、The Pile、DOMA等，它们全部被整合进这个大型饼图之中。随后是第二阶段，他们称之为“衰减阶段”。如果你还记得我关于缩放定律的讲座，当时我提到了WSD（预热—稳定—衰减）三阶段，此处即对应其中的“稳定阶段”。

## 段落 30

**英文**: That's the decay stage. And in the decay stage, what have we got? We've got Wikipedia, what people might call high quality data. We've got still the pre-training stuff mixed in there. So it's not pure post-training data. But then if you look at the right, we've got code SFT, we've got Chinese books, we've got Oprah Chai, we've got stack exchange question answering, and evil instruct, and OSS instruct, and all sorts of other things. So those are all kind of instruction tuning or instruction tuning adjacent data sets that we've thrown in onto the second half of pre-training. And I think used by most models today, and many CPM and other sort of derived, LMs that are derived from that lineage of models have definitely sort of publicized this. I think it's extremely effective to do this. And so I think everyone has been following this. One last commentary I'll make before we move on to RLHF here is that this whole process makes it very, very difficult to reason about pre-trained models versus post-trained models.

**中文**: 这就是衰减阶段。在衰减阶段，我们拥有什么？我们拥有维基百科——人们可能称之为高质量的数据；其中仍混杂着预训练阶段的数据，因此并非纯粹的后训练数据。但若再看右侧，我们则拥有代码监督微调（SFT）数据、中文图书、奥普拉·柴（Oprah Chai）数据、Stack Exchange问答数据、“邪恶指令”（Evil Instruct）、开源指令（OSS Instruct）以及各类其他数据。这些均属于指令微调或与指令微调高度相关的数据集，被我们加入到预训练的后半段。我认为当前大多数模型，以及许多CPM及其他源自该模型谱系的衍生语言模型，均已公开采用这一做法。我认为这种做法效果极为显著，因此几乎所有从业者都在跟进。在转入RLHF（基于人类反馈的强化学习）之前，我还想最后补充一点：整个流程使得人们极难厘清预训练模型与后训练模型之间的区别。

## 段落 31

**英文**: If you look at recent releases from Quinn or whatever other companies that you're looking at, and they say base model, that base model is probably at the end of this process. And so it has basically gone through an instruction tuning phase, implicitly through its mid-training process. We don't exactly know what the mixes are for a lot of these closed models, but it does. actually mean that I think the term base model is increasingly questionable what that really means. So that's my sort of side comment that is useful for you if you're thinking about base models. So yes. This is a data mixture you can turn into a station. Like when you have a learner today, this is here. That's when you got like this, thank you so much. Is that like some point in that last stage? Yeah, so that's right.

**中文**: 如果你查看奎因公司（Quinn）或你所关注的其他公司的近期发布产品，当它们提到“基础模型”时，该基础模型很可能已处于这一流程的末期，即实际上已在中期训练过程中隐式地经历了指令微调阶段。尽管我们并不确切知晓许多这类闭源模型所采用的数据配比，但这确实意味着，“基础模型”这一术语的内涵正变得越来越模糊、越来越值得质疑。因此，这是我针对基础模型概念所作的一个补充说明，希望能对你有所助益。是的，这是一种可转化为训练数据集的数据混合方式。就像你今天面对一个学习者时，它就在这里；此时你便得到了这样的结果，非常感谢！这是否对应于最后阶段的某个时间点？是的，正是如此。

## 段落 32

**英文**: That was the motivation for a lot of the two phase training for these groups. They basically use essentially the large drop in loss as a way to try to anneal the model into the right mode. I think there's increasing studies into what's the optimal point at which to switch. And I think it's a little bit more nuanced than that. But I think it's the first order. This has been a very effective recipe. Yes. Is this between my thing and the catastrophic thinking? Or I'm trying to think about the incentivized addition paper earlier? And do the source of that? Yeah, so I guess there are two questions packed in one, but the question was like is this primarily for catastrophic forgetting and also does this help with the citations issue? So to answer the second part first, I think it doesn't help with the citation issue because. just as sort of like a type signature thing, the only things that can help with the citation issue is if you know what facts the model knows. So you have to either ensure that the model always knows the citation facts before you show it this FD data or you have to check to see if the model knows it and then show it that data if it does know it, right? Which this doesn't do.

**中文**: 这正是为这些群体设计大量两阶段训练的动机所在。其基本思路是，利用损失值大幅下降这一现象，尝试将模型“退火”至正确的模式。目前，关于切换时机的最佳节点，相关研究正日益增多。我认为这个问题比表面看起来更为微妙，但上述观点仍属首要考量。这一方法已被证明是非常有效的方案。  
是的。这与我的观点以及“灾难性思维”有关吗？还是我在试图联系之前那篇关于“激励式添加”的论文？那篇论文的出处是什么？  
是的，您的问题其实包含了两个子问题：第一，这种方法是否主要针对灾难性遗忘；第二，它是否有助于解决引用问题？  
先回答第二个问题：我认为它无助于解决引用问题，原因在于——仅从类型签名的角度来看，唯有明确知晓模型已掌握哪些事实，才可能解决引用问题。因此，您要么必须确保模型在接触该FD数据之前已始终掌握相关引用事实；要么需先行检验模型是否掌握这些事实，仅当确认其已掌握时，才向其展示该数据。而当前方法并未做到这一点。

## 段落 33

**英文**: This will always unconditionally put in those data points, whether or not that citation has learned. So it has no way of fixing that adaptively. Catastrophic forgetting wise, I think that is one of the motivations that if you have so much SFT data, your trade offs are pretty tricky, right? Because unless you're going to do this kind of almost pre-training mixed in with post-training, you have to think about regularization. You have to think about tiny step sizes to avoid messing up your pre-training. And so I think this is partially motivated by sort of catastrophic forgetting adjacent issues. It keeps the model sort of more general. Yes. I'm trying to understand. With a John Chowman example for investigation, inside if the model doesn't know the reference I think within the post-training data that it knows it, so it does know not that. And it would not have the same data here.

**中文**: 这将无条件地始终加入这些数据点，无论该引用是否已被模型学习过。因此，它无法以自适应方式解决这一问题。就灾难性遗忘而言，我认为这正是一个动机：如果你拥有大量监督微调（SFT）数据，那么权衡取舍就会变得相当棘手，对吧？因为除非你采用一种近乎将预训练与后训练混合的方式，否则就必须考虑正则化策略，必须采用极小的学习步长，以避免破坏预训练成果。因此，我认为这一方法部分源于与灾难性遗忘相关的问题，旨在使模型保持更广泛的泛化能力。是的。我正试图理解：以约翰·乔曼（John Chowman）的例子为例进行考察，如果模型在后训练数据中并不知晓某个参考信息，那么它实际上并不知道该信息；而此处也不会包含相同的数据。

## 段落 34

**英文**: That's right. Or that's the claim, right?. That if the model did know this citation that's right here, then the model wouldn't necessarily out of these two sort of competing mechanisms. What it would learn is, oh, whenever I see this example, I should retrieve my knowledge about Bivens and Michel L and then use that as a citation. I think the reality of this is that it's always very complicated, right? Like what does it mean for a model to know something? How reliably does it know something? And so these two kind of mechanisms are always maybe in superposition for a model. It's really just a question of which one is more dominant. Like if a model just has no idea about this, it's probably two that is more dominant. Whereas I think if the model knows it reliably, it's more likely that it's just going to learn the correct citation rather encouraging broad general hallucinations. Yes. I'm going to try putting into all of the pre-digels some kind of thought tokens that tell the model who actually this looks like a plant.

**中文**: 没错。或者说，这是个主张，对吧？即：如果模型确实知道此处所引的这条文献，那么它就不必在这两种相互竞争的机制中做出选择。它学到的将是：“哦，每当我看到这个例子时，就应检索关于比文斯（Bivens）和米歇尔·L（Michel L）的知识，并以此作为引文。”但实际情况往往非常复杂，对吧？比如，对一个模型而言，“知道某事”究竟意味着什么？它对某事的掌握又有多可靠？因此，这两种机制在模型中可能始终处于某种叠加状态，问题只在于哪一种机制占主导地位。例如，若模型对此完全一无所知，那么第二种机制可能就更占主导；而若模型能可靠地掌握该知识，它就更可能直接学会正确的引文，而非诱发宽泛、笼统的幻觉性输出。是的，我打算在所有预处理的文本中加入一些“思维标记”（thought tokens），以提示模型：“这看起来像是一种植物。”

## 段落 35

**英文**: I'm going to check if I actually know it. And so I'm going to query myself and you go and check if I'm getting consistent answers and it's so hard to print out. So that the early target training process, I have some plan process with lightning to track my story. Okay. That is a very interesting idea. So just to repeat it, it has anyone done something where you put in like kind of thought tokens or the models checking itself for its knowledge of facts as it trains or something like that,. right? Is that roughly right? Yeah. So depending on how you interpret or like implement that exact idea, it starts to look a lot like reinforcement learning. Because for example, there's a method called a quiet star from some folks here, no good men and their exealck men and others had done this where they do essentially they try to learn the thinking process of a model by sort of predicting what happens on the answer. token and then based on whether or not it's correct, it tries to like, you know, reinforce the model to have good thought process.

**中文**: 我打算检验一下自己是否真的掌握了它。因此，我将向自己提问，并请你们去验证我给出的答案是否前后一致——但要打印出来实在太难了。所以在早期目标训练过程中，我计划借助Lightning框架来追踪我的训练过程。好的，这是一个非常有趣的想法。让我再复述一遍：目前是否有人开展过类似的研究？比如，在模型训练过程中引入某种“思维标记”（thought tokens），或让模型在训练时持续自我检验其对事实性知识的掌握程度？我的理解大致正确吗？  
是的。不过，具体如何解读或实现这一想法，会使其逐渐趋近于强化学习。例如，有一种名为“Quiet Star”的方法，由本机构的一些研究人员（如No Good Men团队）以及Exealck Men等人提出并实践过。该方法本质上是通过预测答案标记（answer token）的生成结果来学习模型的推理过程；然后，再根据预测结果是否正确，对模型进行强化，从而引导其形成更优的思维过程。

## 段落 36

**英文**: Actually, the even closer analogy to this is star, which is the original paper, which is if the model gets something correct, then that thinking process gets fed back into the model training. And if it's wrong, then it doesn't, right? It's kind of very similar to what you're proposing, which is to adaptively train the model based on kind of correctness of its knowledge or whatever else. I have a proposal just to do a thought process. Let me give you some of this tool that checks myself and I can later at some point change what that tool gets. But when the tool will come with a response that says, yes, I do have the knowledge, you know I don't. And then you actually see the knowledge gets printed out in person. I see. So in this like tool use example, are you imagining that kind of the fact would get replaced. by a tool call or will the facts still be there? Like I think the key question is, do you force the model to predict the fact tokens or do you just force it to predict like use a tool to look it up on Google token? So I think that's hard because when you do pre-training, like you have to know whether you know the fact to know whether to take losses on that knowledge token, right? You can't defer it to inference time because you have to decide whether or not you're going to take gradient steps, right? And the other sort of logistical difficulty here is during pre-training time, you have. a static dataset or you know, for computational reasons you would want a static dataset.

**中文**: 实际上，与此更为接近的类比是STAR方法——即原始论文中提出的方法：若模型给出了正确答案，则其思考过程会被反馈至模型训练中；若答案错误，则不进行反馈，对吗？这与您所提出的方案非常相似，即根据模型知识的正确性或其他标准，自适应地训练模型。我有一个初步构想：仅对思考过程本身进行建模。让我为您提供一种工具，用于自我核查；之后在某个时间点，我还可以调整该工具的具体功能。当该工具返回响应（例如“是的，我具备该知识”或“不，我不具备该知识”）时，相关知识内容便会实际输出呈现出来。我明白了。那么，在这种工具调用示例中，您设想的是：事实本身将被工具调用所替代，还是事实仍将保留在原处？我认为关键问题在于：您是强制模型预测事实对应的具体词元（token），还是仅强制模型预测“调用工具（如Google）查询该信息”这一动作对应的词元？我认为这存在困难，因为在预训练阶段，您必须事先知晓模型是否掌握某项事实，才能决定是否对该事实对应词元计算损失——对吗？您无法将这一判断推迟到推理阶段，因为是否执行梯度更新必须在训练时即刻决定，对吗？此外，此处还存在另一类操作层面的困难：在预训练阶段，您所使用的数据集是静态的；或者出于计算效率考虑，您也倾向于采用静态数据集。

## 段落 37

**英文**: And if you have a static dataset, you can't adaptively do updates, right? Like anything that solves the hallucination problem has to be kind of reactive of the form, what does the model know? And then do I take updates on this or not? At the pre-training stage, that's very difficult. Unless you're doing RL style stuff at pre-training scale, which would get you very close to that, but still very difficult. I'm happy to follow up, but I think hopefully that answers the question. Oh, there's more stuff. Yes, okay. So, if I put them on in case of Lama, it's in a retinue free path, we can do list of emoji, but if I allow the emoji, I think that is in this. So it comes to a ground goal, it's not to allow it to, for example, we have a level 30 in it, so it's similar to emoji items, I didn't. Yeah, okay. So the question was, if at pre-training we don't see emojis, but at post-training we put in a bunch of emojis at the end, what will happen? It depends on the structure of the emojis, I guess. If the emojis are dependent on the inputs in a very complex way, and that's very difficult to learn, maybe what the model will learn is, well, in post-training, what I saw was a bunch of emojis.

**中文**: 如果你拥有的是一个静态数据集，就无法进行自适应更新，对吧？例如，任何能解决幻觉问题的方法都必须具备某种反应性，即先判断模型已知什么，再决定是否对此进行更新。而在预训练阶段，这非常困难。除非你在预训练规模上采用类似强化学习（RL）的方法，这样或许能接近该目标，但依然十分困难。我很乐意后续跟进，但希望上述回答已解决了您的问题。哦，还有更多内容。是的，好的。那么，如果我在Lama中启用它，它会走一条无需随从（retinue-free）的路径，我们可以列出一串表情符号；但如果我允许使用表情符号，我认为它就属于这一类了。因此，最终目标是：不允许多余的表情符号出现。例如，我们内部设定了一个30级限制，这与表情符号项类似，而我并未这样做。是的，好的。所以问题是：如果在预训练阶段模型从未见过表情符号，但在后训练阶段却在末尾加入大量表情符号，结果会怎样？这大概取决于表情符号的结构。如果表情符号与输入之间存在极为复杂且难以学习的依赖关系，那么模型在后训练阶段可能仅学会：我所见到的只是一堆表情符号。

## 段落 38

**英文**: I don't have enough data or training to know what the complex pattern is. So the model will just learn to put a bunch of random emojis at the end. If there's no pattern, if there's no complex dependence, then maybe the model will learn to do the right thing, which is just to put a bunch of random emojis at the end. Really the key way to think about the SFT issues is instruction tuning will reliably teach the style of the output, like the type signature of the output, right? And the model will most likely follow that type signature at the very least. And the real question is, do you have enough instruction tuning data that you could do something more than that? And that's kind of the more complex open question. So in your emoji case, at the very least, you'll get a bunch of emojis. Whether those emojis are the right emojis, open question, right? Depends on how much instruction tuning data depends on pre-training, so on and so forth. Yes? I was wondering, like, earlier in the lecture, I think it was said that the post-training purpose really teach, like, well, you know, it's right, it's mostly all the styles. And then, like, the line kind of gets more blurry, like, when this report is like mid-training is digital. So the language should, like, the medium-CPM paper.

**中文**: 我缺乏足够的数据或训练来识别其中的复杂规律，因此模型只会学会在末尾添加一堆随机的表情符号。如果根本不存在某种规律，也不存在复杂的依赖关系，那么模型或许就会学会做正确的事情——即仅在末尾添加一堆随机的表情符号。实际上，理解监督微调（SFT）问题的关键在于：指令微调能稳定地教会模型输出的风格，例如输出的类型签名（type signature），对吧？而模型至少很可能会遵循该类型签名。真正的问题在于：你是否拥有足够多的指令微调数据，从而实现超出这一基础水平的效果？这恰恰是一个更复杂、尚未解决的问题。因此，在你的表情符号案例中，至少你能得到一堆表情符号；但这些表情符号是否是“正确”的，则仍属未知——这取决于指令微调数据的规模、预训练的影响等诸多因素，对吧？  
是的。我之前在讲座中曾想到：后训练阶段的主要目的，其实是教授——嗯，你知道的，它主要涵盖各种风格。而随着训练进程推进，这条界限便逐渐变得模糊，例如这份报告所描述的“中期训练”阶段就已进入数字化范畴。因此，语言模型理应——嗯，就像《中等规模语言模型》（Medium-CPM）论文所阐述的那样。

## 段落 39

**英文**: So in that, in this sort of few, like, scenario, like, the mid-training part could also excuse some of the new kind of, like, work knowledge or follow. Yeah, that's right. So, I guess the question was, like, you know, if I phrase it, you know, can't instruction tuning essentially teach new world knowledge, because mid-training blurs the line between pre-training and instruction tuning. And we know pre-training teaches knowledge. So why not instruction tuning? And I think that's right. That, like, in some ways, instruction tuning, if it's scaled up enough and it's diverse enough, will teach knowledge, right? But I think instruction tuning, and it's, like, smaller, like, non-mitraining form, it is very difficult to have the scale and diversity of data needed to reliably teach, you know, various facts. I think modern mid-training is starting to become a different game, but it's still sort. of an emerging object, I think. Cool. Okay.

**中文**: 因此，在这种少数情况下，中期训练阶段也可能传授一些新型的工作知识或后续知识。是的，没错。所以，我想问题在于：如果我这样表述——指令微调本质上能否教授新的世界知识？因为中期训练模糊了预训练与指令微调之间的界限。而我们知道预训练确实能教授知识，那么指令微调为何不能呢？我认为这种看法是正确的。也就是说，从某种意义上讲，只要指令微调的规模足够大、数据足够多样化，它就确实能够教授知识。但就目前较小规模、非中期训练形式的指令微调而言，要具备足够规模和多样性的数据，以可靠地教授各类事实性知识，是非常困难的。我认为，现代中期训练正逐渐演变为一种全新的范式，但它仍处于初步发展阶段，尚属新兴事物。很好，明白了。

## 段落 40

**英文**: So now, we get to the part two, right? So part one, this is the quick intro to instruction tuning and SFT. Now we get to reinforcement learning from human feedback, right? The RL part of this lecture. And conceptually, right?. And I'm going to take it slow here, because I think this is an important conceptual transition. Right? We're going to move from the world of, I think, generative modeling at the very top here, which is, you know, there's a very simple goal in this world, which is there's a P-star, P-star is a reference distribution from which completions are drawn. That reference distribution probably looks like some mixture of, you know, internet data, as well as annotator written data. But there exists some abstract P-star that we're trying to imitate, right?. That's all there is to it. So this is pure generative modeling. Now we're going to move to the second perspective now, which is RLHF.

**中文**: 那么现在，我们进入第二部分，对吧？第一部分是对指令微调（Instruction Tuning）和监督微调（SFT）的简要介绍。接下来我们要讲的是基于人类反馈的强化学习（RLHF），也就是本讲中与强化学习（RL）相关的内容。从概念层面来看，对吧？我会放慢节奏讲解，因为我认为这是一个重要的概念性转变。我们将从最顶层的生成式建模世界过渡到新的视角——即RLHF。在生成式建模的世界中，目标非常简单：存在一个参考分布P*，模型生成的补全内容均从中采样；该参考分布很可能是互联网数据与标注员撰写数据的某种混合，但无论如何，存在某个抽象的P*，而我们的任务就是去模仿它，仅此而已。因此，这纯粹属于生成式建模。而现在，我们将转向第二种视角，即基于人类反馈的强化学习（RLHF）。

## 段落 41

**英文**: In this world, I no longer care about matching any distribution, right? So probabilistic perspectives kind of don't really entirely go at the window, but you want to be careful about adopting those. Because really what we're looking for is we're really just looking for some policy, P of Y given X, such that we maximize our rewards, right?. There's some reward function, R of Y and X, that, you know, take in both my completion and my prompt, and it gives me a reward. And all I'm looking for is any policy that gives me good rewards, right? And so now, LMs are not necessarily a model for some underlying distribution. They are policies that give us good rewards. And so why would we go and do RLHF? There are kind of two reasons that we might do this. One of them is on the top one in SFT, in order to do this process of imitation, we have. to get samples from P-star. And that can be quite expensive, right? And the second one, all we need to do is get measurements over rewards R. And SFT data can just be really, really expensive.

**中文**: 在这个世界中，我已不再关心是否匹配任何分布，对吧？因此，概率视角某种程度上并不完全适用，但你在采用这些视角时需谨慎。因为我们真正追求的，其实只是找到某个策略——即给定输入X时输出Y的条件概率分布P(Y|X)，以最大化我们的奖励，对吧？这里存在某个奖励函数R(Y, X)，它同时接收我的生成结果和提示词，并据此给出一个奖励值。而我所寻求的，仅仅是能带来高奖励的任意策略，对吧？因此，大语言模型（LMs）未必是某种潜在分布的建模工具，而更应被视为能够带来高奖励的策略。那么，我们为何还要进行基于人类反馈的强化学习（RLHF）呢？大致有两个原因：其一，在监督微调（SFT）阶段，为实现模仿学习过程，我们必须从真实最优策略P*中采样，而这往往成本高昂，对吧？其二，我们真正需要的只是对奖励函数R的评估；而SFT所需的数据可能极其昂贵。

## 段落 42

**英文**: This is kind of like a caricature of various costs that you might have in different stages, right? You have some compute costs when you train your base model, and then you're doing supervised learning, like SFT, and then you're going to go collect a bunch of pairwise feedback,. and do RL, and do evaluation, and so on. So when you do this, SFT is just really, really expensive. You're getting really expert people to write very long form responses, and you kind of saw how annoying and difficult that was. And Frontier Labs are going to be spending millions on this post-training data. Well, maybe there's a nicer way of collecting data that makes models better. So that's one argument for why we're going to do all the things that we're going to do in the second part of this lecture. There's also a second reason that is equally, or maybe even more important, that I think people do this kind of RL training. And one of the things that's very interesting is people don't always agree with themselves about what is good. So if you ask somebody to write a summary, they can write one summary, and then you ask them to compare their own summaries to LMwritten summaries.

**中文**: 这有点像是对各个阶段可能产生的各类成本所作的一种夸张式描绘，对吧？你在训练基础模型时会产生一些计算成本，接着进行监督学习（例如监督微调，SFT），然后收集大量成对的反馈数据，开展强化学习（RL）、评估等后续工作。而当你实际操作时会发现，SFT环节的成本极高：你需要聘请真正资深的专家撰写篇幅很长的回复，而你也已体会到这一过程有多么烦琐和困难。前沿实验室为此类后训练数据投入的资金将达到数百万美元。那么，或许存在一种更优的数据收集方式，既能提升模型性能，又更高效便捷。这正是我们接下来在本讲第二部分将要展开所有工作的首要动因。此外，还有一个同等重要、甚至更为关键的原因，促使人们采用此类强化学习训练方式。其中一件非常有趣的现象是：人们对自己“何为优质输出”的判断并不总是一致。例如，若请某人撰写一篇摘要，他可以写出一个版本；随后再让他将自己的摘要与大语言模型生成的摘要进行对比。

## 段落 43

**英文**: There's a good amount of people that will actually prefer LMwritten summaries. And this was a really surprising result from one of my students' papers, I guess two years. back now, where we were benchmarking summarization systems. And there was one person who is, of course, anonymized, but Annotator One who wrote a bunch of summaries, and they actually preferred the AI summaries, actually significantly more than their own, and they're like a freelance expert writer or something. And we went and interviewed them, and they were like, yeah, when you asked me to write stuff, I just felt like I had to write more with flowery language, but then I read the AI ones, and they just read better. And I'm sure you've had similar experiences where you look at the output, and it is actually. different from your own assessment of how to generate. So there's not just cheaper to verify than generate, but actually maybe higher quality to verify than to generate. And so there's this generator validator gap. OK, so we're going to cover different aspects of this RLHF process.

**中文**: 实际上，有相当一部分人更喜欢由大语言模型生成的摘要。这一结果来自我一名学生两年前发表的一篇论文（当时我们正在对摘要生成系统进行基准测试），令人颇为意外。其中有一位匿名参与者（我们称之为“标注员一”）撰写了大量摘要，而他们本人却明显更青睐AI生成的摘要，甚至远超自己所写的摘要——此人本身是一位自由职业的专业撰稿人。我们随后对他进行了访谈，他坦言：“你们让我写摘要时，我总觉得必须使用华丽的辞藻；但当我读到AI生成的摘要时，发现它们读起来更流畅、更自然。”相信你也曾有过类似体验：看到AI的输出后，发现其效果与你自己预想的生成方式截然不同。因此，验证AI生成内容不仅成本更低，质量上甚至可能更高。这就形成了所谓的“生成者—验证者差距”。好的，接下来我们将从不同角度探讨这一基于人类反馈的强化学习（RLHF）流程。

## 段落 44

**英文**: We're going to talk about how we collect data, and what are things you should worry about if you're in charge of RLHF data collection. And we're going to talk about how we do RLHF. I'm going to talk about two representative algorithms, PPO and DPO. I'll defer some of the more detailed explanations of PPO to next lecture, just for kind of space reasons. And then finally, we'll end with some things to worry about, almost like pitfalls of RLHF at the very end here. OK, so how do we get pairwise feedback? So pairwise feedback is, oh, sorry, I'll go back here and just take it a little slower. So when we do this second part of this instruct GPT process, how does this work?. Well, we have the model sort of generate its own outputs. These are roll outs in RL terms. And then we're going to compare these different outputs.

**中文**: 我们将讨论数据的收集方式，以及如果您负责RLHF（基于人类反馈的强化学习）数据收集，有哪些问题需要关注。我们还将介绍RLHF的具体实施方法。我将重点讲解两种具有代表性的算法：PPO（近端策略优化）和DPO（直接偏好优化）。出于课时安排考虑，PPO更详细的原理讲解将留到下节课进行。最后，我们将在课程末尾简要总结RLHF中需警惕的问题，即其常见陷阱。  
好的，那么我们如何获取成对比较反馈呢？成对比较反馈——哦，抱歉，我先回到此处，放慢节奏重新梳理一下。在“指令微调GPT”流程的第二阶段，具体是如何运作的呢？实际上，模型会自行生成若干输出结果，这在强化学习术语中称为“轨迹采样”（rollouts）；随后，我们将对这些不同的输出结果进行相互比较。

## 段落 45

**英文**: And although the four outputs are shown here in standard settings, you often just have a pair of outputs. And let's see, we have A and B. All I want to know is A is A better than B or not. And then given these pairwise feedbacks, I'm going to train a reward model that can essentially. internally give every single output a scalar value. And then just use that to do reinforcement learning. This reward model is now my rewards. And I want my model to maximize those rewards. Fairly, hopefully, simple pipeline. So how do we collect pairwise feedback data? Well, the obvious, simple thing to do is just say, OK, I'm just going to make some web app.

**中文**: 尽管此处展示了四种输出的标准设置，但通常你只有一对输出。我们来看一下，假设我们有A和B两个输出，我仅需知道A是否优于B。接着，基于这些成对反馈，我将训练一个奖励模型，该模型本质上可为每个输出内部赋予一个标量值，并利用该值进行强化学习。这一奖励模型即为我的奖励信号，我希望我的模型能够最大化这些奖励。整体流程相对简单、直观。那么，我们该如何收集成对反馈数据呢？最直接、简单的方法就是开发一个网页应用。

## 段落 46

**英文**: I've got two different AI responses. And you're going to have a little four-way checkbox that checks which responses better. I took this from one of the studies that we did. A lot of pairwise feedback responses look similar to this. But I thought one thing that would be helpful and useful into actually getting a sense of what does this look like for real. I have gone and dug up examples of annotation guidelines from different papers in different places talking about this process. So if we look at the InstructGPT guideline, this is one of the very few, I would say, release materials from one of these companies describing their annotation guidelines. They say, OK, your job is to evaluate these outputs to ensure that they're helpful, truthful, and harmless. So those are their three pillars. You've got helpfulness, which is writing in clear language, answer the question.

**中文**: 我得到了两条不同的AI回复。接下来，您将看到一个四选一的复选框，用于勾选哪条回复更优。这个设计借鉴了我们开展的一项研究。许多成对反馈回复都与此类似。但我认为，为真正了解实际情况，以下内容会很有帮助、也很实用：我查阅并整理了多篇来自不同机构、探讨该流程的论文中的标注指南示例。例如，以InstructGPT的标注指南为例，这是少数几家公开发布其标注指南的公司材料之一。指南中指出：“您的任务是评估这些输出结果，确保其具备帮助性、真实性与无害性。”这三大原则即为：帮助性（使用清晰易懂的语言作答，并准确回答问题）。

## 段落 47

**英文**: They mean to ask, like, being sensitive to the internationality. Like, if someone says, football, they shouldn't assume American football. If it's too confusing, ask for clarifications. I want you to be truthful and not hallucinate outputs. And by harmless, you should sort of be not toxic and be very nice and not say NSW things. All fairly reasonable things. But you can kind of see how there's the interplay between things like the model spec which OpenAI publishes publicly. Then there's a very detailed annotation guideline, which, you know, this is not that detailed. It's probably much bigger in practice. Where you would write down these kinds of bullet points.

**中文**: 他们的意思是要求你注意国际性，例如，当有人提到“football”时，你不应默认指美式橄榄球；若存在歧义，应主动请求对方澄清。我希望你诚实作答，不编造内容。所谓“无害”，是指你应避免输出有毒、不友善的内容，也不应发表新南威尔士州（NSW）相关不当言论。这些要求都相当合理。但你也能看出，其中存在多重因素的相互作用：一方面有OpenAI公开发布的模型规范；另一方面还有极为详尽的标注指南——当然，此处所列要点并不算特别详细，实际应用中的指南篇幅可能要大得多，其中会逐条列出此类注意事项。

## 段落 48

**英文**: You would hand this to annotators. And then they would sort of go and make annotations. This was, you know, InstructGPT is not even like kind of production grade. This is the early days. But you see how this process kind of works. The kind of other interesting example, you can kind of go look this one up later if that the actual text is too small because I'm not going to read through all of it. I'll just sort of touch on it a bit. There's actually a leaked version of the actual true annotation guideline, apparently, for Google Bard. That I think was part of some like news story. And you can kind of see very, very similar things happening here, right? We've got on the top left box, like, helpfulness.

**中文**: 你会将这份材料交给标注人员，然后他们便据此开展标注工作。需要说明的是，InstructGPT 连初步的生产级系统都算不上，当时尚处于早期阶段。但你可以由此了解这一流程的大致运作方式。另一个颇有趣味性的例子是：谷歌 Bard 的真实标注指南曾被泄露（据称），你稍后可自行查阅——因为原文篇幅较长，我就不在此逐字朗读了，仅简要提及。例如，在左上角的方框中，就明确列出了“有益性”这一维度。

## 段落 49

**英文**: Like you should address the intent of the user's prompt. You should have adhered any requirements. Don't have misleading information. You're very similar to the InstructGPT setup. We've got, actually, here a style box, which is what kinds of style are good or bad. And then we've got different rating scales for the different responses. And if I remember right, I think the Google Bard folks, I think, gets like a minute per question to be doing this task, which is quite difficult. OK. And then for InstructGPT, they go through scale and upwork, and they collect about data from. about 40 people.

**中文**: 例如，您应准确回应用户提示的意图，严格遵守所有要求，不得提供误导性信息。您的工作方式与InstructGPT高度相似。实际上，此处有一个“风格框”，用于界定哪些风格为佳、哪些为差；此外，针对不同回复还设有不同的评分标准。据我回忆，谷歌Bard团队的评审人员每道题仅有约一分钟时间完成此项任务，难度相当大。而对于InstructGPT，则通过Scale和Upwork平台开展工作，并收集约40人的标注数据。

## 段落 50

**英文**: This is really, really tiny sort of by today's standards. But hopefully you kind of get a sense of what types of groups are being involved here. OK. So this is the second part of our interactive exercise. OK. Cool. So that's five minutes. I guess to take a straw poll, I think about 27 of you managed to complete this, which is great. Thank you for your participation. How many of you managed to fact check all the facts? Yeah.

**中文**: 以当今的标准来看，这确实非常、非常小。但希望您能大致了解此处涉及的是哪些类型的群体。好的，这是我们互动练习的第二部分。好的，很好。那么，时间是五分钟。我来简单统计一下，大概有27位完成了这项任务，非常棒！感谢大家的参与。有多少人成功核实了所有事实？是的。

## 段落 51

**英文**: The normal expression. Yeah. That's right. So how many of you managed to fact check? No. Any or all of the facts. Managed to fact check things? Just one. OK. How many of you managed to check the math in the five minutes? OK. So they're called people. OK.

**中文**: 正常的表达。是的。没错。那么，你们当中有多少人进行了事实核查？没有。任何一项或全部事实都未核查？成功进行了事实核查？只有一人。好的。那么，在五分钟内完成数学计算核查的有多少人？好的。他们被称为“人”。好的。

## 段落 52

**英文**: Excellent. OK. That makes me happy. So the point of this exercise partially, I think maybe you could have guessed what was going to happen here. The shorter ones, most of them are essentially taking the longer ones and actually just removing. the hallucinations to the best of my ability. And so for the most part, basically, for those of you that picked the longer ones are sort of picking the slightly longer but hallucinated ones. I don't quite remember which of the pair of games ones that are hallucinated, but many of them are. And so we see the strong disappointment. And actually, the longer one gets more votes despite having strong hallucinations.

**中文**: 很好，好的，这让我很高兴。因此，本次练习的部分目的——我想你们或许已经猜到接下来会发生什么——就是：较短的那些回答，大多数实际上是在较长的回答基础上，尽我所能去除了其中的幻觉内容。所以，对于选择较长回答的各位来说，你们选中的其实是稍长一些但包含幻觉的内容。我记不太清成对出现的游戏类回答中具体哪些存在幻觉，但其中很多确实存在幻觉。因此，我们看到了强烈的失望情绪；事实上，尽管较长的回答存在严重幻觉，却反而获得了更多投票。

## 段落 53

**英文**: This one, I think, both is correct. So B is probably the better choice. So the two math ones, I think you're going to also back out by the unnaturalness of this construction. The one that's more conclusive actually is going to the wrong conclusion. This is not mathematically fully correct here. And so you probably should find it difficult to try to do these judgments this quickly. There are very, very strong challenges in collecting this pairwise feedback at very, very large scales. Just because even though you only have to verify if I'm showing you a math problem or I showing you something like a very strong, factually laid-in text, you're going to have to basically break this down into claims and check each one to know whether one is wrong and one is right. So this is just like a very labor-intensive and difficult task. And I gave you five minutes because essentially, I think the new story that the Google Bar article was associated with was basically that the annotators were given one minute, for example.

**中文**: 这一题，我认为两个选项都是正确的，因此B可能是更好的选择。至于两道数学题，我认为你也会因这种构造的不自然性而排除它们。其中结论更明确的那个，实际上却得出了错误的结论。此处从数学角度而言并不完全正确。因此，你可能会发现，如此迅速地做出这类判断确实相当困难。在极大范围内收集此类成对反馈，面临着极其严峻的挑战。原因在于，即便你只需验证我向你展示的是一道数学题，还是类似事实性极强的文本，你也必须将内容逐条拆解为具体主张，并逐一核查，才能判断哪一个有误、哪一个正确。因此，这本质上是一项劳动强度极高且极为困难的任务。我给你五分钟时间，是因为据我理解，《谷歌巴尔》（Google Bar）文章所关联的新情况大致是：标注人员每题仅有约一分钟的时间。

## 段落 54

**英文**: And there was big complaints. This is not enough for us to judge the safety and factual accuracy of the model. And you hopefully, somewhat agree that it is a very difficult task. It's OK. The lessons here, going back to the flow of the lecture, it's very hard to get high quality, verifiable annotators. I think you are, in many ways, pretty high on the bar of people that are actually motivated to do this because you're just doing it because I asked you to, not because I'm paying. you to, or to get grades. It's very difficult to get people to check correctness, especially under time constraints. And the last one, I don't know if those of you are doing this, but if you put in an online survey like this, someone's just going to take the whole thing, dump it into GPT-4, and then just copy the answer straight back onto your pairwise responses. We've had several studies in the past where an annotator had like 95% agreement with GPT-4, and you kind of have to wonder what's going on there.

**中文**: 而且出现了大量投诉。仅凭这些，我们无法判断模型的安全性和事实准确性。希望你们在某种程度上也认同：这是一项非常困难的任务。没关系。回到本次讲座的逻辑脉络，这里得到的教训是：要找到高质量、可验证的标注人员极为困难。从很多方面来看，你们实际上属于动机相当强的一类人——你们参与标注仅仅是因为我提出了要求，而非出于报酬或学分等外在激励。尤其在时间压力下，要让人认真核查答案的正确性更是难上加难。最后一点，我不确定在座各位是否正在开展此类工作，但如果你发布类似在线问卷，就难免有人直接把整份问卷丢进GPT-4，再将生成的答案原封不动地复制到你的成对比较结果中。过去我们已开展过若干研究，其中某些标注员与GPT-4的一致率高达95%，这时你难免会怀疑：这背后究竟发生了什么？

## 段落 55

**英文**: And so despite the fact that pairwise feedback is easier to collect than supervised imitation. data, there are still significant issues. And I'd be remiss to not point out the many things that have been written about sort of the kinds of problems that this creates if you try to outsource this to the through all countries. There's sort of pricing concerns and sort of lots of ethical issues that you all should be aware of, if you're sort of going to be in the future, be a part of these kinds of sort of data collection pipelines. You want to make sure to get high quality data, and to also make sure that people are being. paid kind of living wage. The other thing to be aware of, this is in the sort of bias and safety angle because for alignment, I think this is a really important thing to also touch on, is that in some test RLHF and alignment come at the end of the pipeline. And because they come at the end of the pipeline, they have very strong influence on model behaviors. One of the papers that actually per se in my postdoc Shibani and Essin postdoc on my worked on was this paper on trying to figure out how to subjective opinions of LM's align. with different groups of people.

**中文**: 因此，尽管成对反馈数据比监督式模仿学习数据更易于收集，但仍存在诸多显著问题。若将此类工作外包至全球各国，会产生一系列问题，对此我必须指出——已有大量文献探讨了这类问题，包括定价方面的顾虑以及诸多伦理问题。如果你们未来将参与此类数据收集流程，务必对此保持警觉：既要确保获取高质量的数据，也要确保相关人员获得符合当地生活标准的合理薪酬。另一点值得注意的是偏见与安全性问题，因为就模型对齐（alignment）而言，这一点尤为关键。在某些测试中，基于人类反馈的强化学习（RLHF）及对齐工作处于整个流程的末端；正因其处于流程末端，故对模型行为具有极强的影响力。我博士后期间与Shibani及Essin（同为我的博士后）合作撰写的一篇论文，便致力于探究如何使大语言模型（LM）的主观观点与不同人群的观点相契合。

## 段落 56

**英文**: One of the really interesting patterns that we found was actually for instruct GPT, these are old models, but now still useful models. These models somehow became more aligned with sort of Southeast Asian religions than before. And then we looked in the appendix of instruct GPT and actually what's the nationality of the people doing the annotation? It's Filipino and Bangladeshi and 17% American. I was like, oh, it's kind of surprising, but it does circumstantial evidence lines up. with this kind of thing. You have to be very careful because this is the thing that in some sense goes out in ships. Others have also noted that depending on the annotator, what they pay attention to is very different. I really like this paper from Hossking, Blossom and Bartolo, where they basically study two different kinds of annotators. One is like the authors and they're very motivated to judge things correctly with quotes. And then crowd workers.

**中文**: 我们发现的一个非常有趣的模式是，针对InstructGPT这类较早但至今仍具实用价值的模型，其行为在某种程度上比以往更契合东南亚宗教观念。随后，我们查阅了InstructGPT附录中负责标注工作的人员国籍信息，结果发现标注者主要来自菲律宾和孟加拉国，另有17%为美国人。这令我颇感意外，但确为上述现象提供了间接佐证。对此我们必须格外谨慎，因为这类偏差某种程度上会随模型“出海”而扩散。其他研究者也已指出，不同标注者所关注的重点往往差异显著。我尤其欣赏霍斯金（Hossking）、布拉索姆（Blossom）与巴托洛（Bartolo）的这篇论文，他们系统考察了两类标注者：一类是论文作者，他们积极性高，倾向于依据引文严谨评判；另一类则是众包工作者。

## 段落 57

**英文**: And what they really find is crowd workers don't pay much attention to factuality. That's kind of this row here. They pay more attention to formatting. So depending on the annotator, you're kind of getting different kinds of feedback even though you're asking them the same things. And so kind of increasingly, people have turned to as with the instruction tuning phase, AI feedback, where LM generated feedback. And so there's been many works including some of our own that have shown things like, oh, if you try to get pairwise feedback from GPT-4, it has very strong agreement from GPT-4s, you know, estimated wind rates of models or responses and sort of the human estimated ones on the y-axis. Same here. The agreement between human to human, which is the blue box here, is roughly the same as the agreement between GPT-4 and human, but is much cheaper. So there's lots of reasons, I think, why AI feedback has become popular. And it has been used very extensively in RLHF.

**中文**: 而他们真正发现的是，众包工作者并不太关注事实性（即此处的这一行），反而更关注格式。因此，即便向不同标注者提出相同的问题，所获得的反馈类型却各不相同。于是，人们日益转向类似指令微调阶段所采用的AI反馈方式，即由大语言模型生成的反馈。已有大量研究（包括我们团队的部分工作）表明：例如，若尝试让GPT-4提供成对比较反馈，则不同GPT-4实例之间的一致性非常高；图中纵轴显示的是模型或回复的预估胜率（由GPT-4估算）与人类估算结果的对比。同样在此图中，人类之间的一致性（即此处蓝色方框所示）大致等同于GPT-4与人类之间的一致性，但成本却低得多。因此，我认为AI反馈之所以流行，原因众多，且已在基于人类反馈的强化学习（RLHF）中得到极为广泛的应用。

## 段落 58

**英文**: So if you look at ultra-feedback, which I think is one of the very popular open source data sets for off-policy RLHF, you see this. If Zephyr 7B, I think, was a hugging phase effort, I want to say last year, to build a big strong open model. The reason why I bring this up, I think Zephyr is probably not the most well-known model. But one of the things I kind of remember about sort of the hugging phase model process was, you know, initially they were really interested in human data collection. Like they were convinced that like human crowd worker, like if you paid them enough and got the right vendors, you know, without perform sort of AI-generated feedback. But kind of late in the process, they kind of realized, you know, GPT-4 generated feedback for this kind of thing just worked much better. And so a more modern example of this is Tulu 3, which is a sort of post-training paper slash project out of AI2. And they've done kind of roughly this. Like they take different prompts, they have lots of different models to generate responses,. and they have, you know, LM sort of rate these to get chosen versus non-chosen.

**中文**: 因此，如果你查看“Ultra-Feedback”数据集——我认为这是目前用于离线策略RLHF（基于人类反馈的强化学习）的最受欢迎的开源数据集之一——就会发现这一点。Zephyr 7B模型据我所知是Hugging Face发起的一项计划，旨在去年打造一款强大且开源的大模型。我之所以提到它，是因为Zephyr可能并非最广为人知的模型；但关于Hugging Face模型开发流程，我隐约记得的一点是：他们最初对人工数据采集极为重视，坚信只要支付足够报酬、选择合适的众包供应商，就能获得高质量的人类标注反馈，而无需依赖AI生成的反馈。然而，在项目后期，他们才意识到，GPT-4生成的此类反馈效果要好得多。与此相关的更现代案例是Tulu 3，这是AI2推出的一项后训练论文兼项目；其大致做法是：采用多种不同提示词，调用大量不同模型生成响应，并利用大语言模型（LM）对这些响应进行评分，从而区分优选响应与非优选响应。

## 段落 59

**英文**: And this really all just kind of goes back to the classic paper would be the anthropic paper on constitutional AI, which I think sort of, you know, really planted a flag on the ground in terms of AI feedback being used for this kind of alignment process. Finally the last thing I want to talk about for data is length effects. I think, you know, when we did the annotation, one of the things that we saw was, I think many of you saw the longer response. And you're like, this is more detailed. I like details. This is good. It's not just you models and people all have this bias. And so people have found that, you know, models that people have thought were better, were in fact maybe only just also longer. And then AI feedback seems to make models just generally longer. And so this is always a confounder that you want to be careful of, you know, length as a confounder for general preference.

**中文**: 而这实际上都可追溯至那篇经典的“人类中心主义”论文——即关于宪法型人工智能（Constitutional AI）的论文，我认为该论文在将人工智能反馈用于此类对齐过程方面，真正树立了一个重要里程碑。最后，我想就数据问题讨论的第三点是长度效应。我们在开展标注工作时发现，其中一种现象是：许多人看到更长的回答时，会下意识地认为“这个回答更详尽，我喜欢细节，这很好”。这种偏好并非仅存在于人类身上，模型本身也存在同样的倾向。因此，研究人员发现，人们原本认为性能更优的模型，其优势可能实际上仅仅源于回答更长；此外，人工智能反馈似乎也会普遍导致模型生成更长的回答。因此，“长度”始终是一个需要警惕的混淆变量，它可能干扰我们对整体偏好的判断。

## 段落 60

**英文**: Okay, there was a question there. I'm not off policy, not on policy. Okay, yeah, I'll talk about off versus on policy later. You know, off policy, I think I mentioned it here, is going to refer to, you collect these kind of pairwise feedback things separately. Like they're not collected from the outputs of your model. Maybe your model is involved. Like for example, in Tulu, you've got all these kind of off policy data on the left. That's models that are not your own. But you also have on policy data from yourself, right? So the off policy data kind of tells you about the landscape of places you're not at. And the on policy data tells you how to refine yourself.

**中文**: 好的，这里有个问题。我既不采用离策略（off-policy），也不采用在线策略（on-policy）。好的，是的，稍后我会详细讨论离策略与在线策略的区别。您知道，离策略——我想我之前已提到过——指的是单独收集这类成对反馈数据，且这些数据并非来自您自身模型的输出。您的模型可能参与其中，但并非直接生成数据。例如，在Tulu数据集中，左侧包含大量离策略数据，即来自其他模型（非您自己的模型）的数据；而您自身模型生成的数据则属于在线策略数据，对吧？因此，离策略数据帮助您了解自身尚未涉足的领域格局，而在线策略数据则指导您如何进一步优化自身。

## 段落 61

**英文**: Yes. So, and the way this sort of human asks us this place, we're sampling props and asking human to agree them. And people ever, instead of sampling props that you don't have the answer to and ask. human to understand, you have like existing in the world from any number of places, there are existing props that we know the answer to. We have that data saved. We don't need to do anything to achieve that data. Have people done sort of a line that's using that style of data instead of asking humans for our own? Yes. Okay. That's a good question. And it's like, why don't we do RLHF on, or like can we do RLHF on domains where we know the answer? It's like one way of putting the question, right? And part of the answer is the next lecture on Thursday is kind of that.

**中文**: 是的。因此，这类人类向我们提出该问题的方式是：我们先采样若干命题，再请人类对这些命题进行确认。而实际上，我们本不必采样那些我们尚无答案的命题并让人类去理解；相反，人类在现实世界中身处无数地点，其中存在大量我们已知答案的既有命题，相关数据也早已保存下来，无需额外操作即可获取。那么，是否有人尝试过采用这种现成数据的方式，而非依赖人类为我们提供答案？是的。好的，这是个好问题。换言之，这类似于在提问：我们能否、或为何不在那些答案已知的领域中应用基于人类反馈的强化学习（RLHF）？这正是问题的一种表述方式，对吧？而部分答案将在本周四的下一讲中展开。

## 段落 62

**英文**: Like where do we really know the answer? Math. We know the answer very well for math. And we can do exactly RL against math and it works very well. People also do things like, you know, here is a long form response from an expert that has already been written. Now can you judge it given this? That helps. But one thing that I think is important to keep in mind is there's, for a lot of these open-ended tasks, there's many correct answers. And it's very difficult to judge which are correct. Like if I have a new fact in the LM response, like is that a correct fact or not, doesn't really solve those problems. Yes? So like, thinking my offensive stance dropped a bakery reference, there's less like relatively specific and small constitutions than what we can even like. Sample value gives us to make this work for open-ended things.

**中文**: 比如，我们究竟在哪些领域真正知道答案？数学。我们对数学问题的答案非常清楚。而且，我们完全可以将强化学习（RL）直接应用于数学问题，效果也非常好。人们还会采用其他方法，例如：这里已有一份专家撰写的长篇回答，现在你能基于此对其进行评判吗？这确实有所帮助。但有一点我认为很重要，需要时刻牢记：对于许多这类开放式任务而言，往往存在多个正确答案，而要判断哪些答案正确则极为困难。例如，若大语言模型（LM）的回答中包含一条新事实，那么这条事实本身是否正确，并不能真正解决上述评判难题。是的？因此，以我这种略带批判性的立场来看，之前提到的“烘焙店”类比其实并不恰当——因为与我们实际能够采样并用于评估开放性任务的那些相对具体、范围较小的评判标准相比，它显得过于宽泛和模糊了。

## 段落 63

**英文**: Like because we have any number of sources of like, here's a problem, here are values that we as a society think are relevant whether that's surveys or politics or, you know,. art will use any number of like sources. I know they're like, I'm from like, what people vote, that's small. Yeah. Like I guess there's lots of different things being mixed in on that comment. Like you could do like, deliberative democracy style stuff to a Y model that is certainly a thing. There's also I guess the thing that feels close to what you're talking about is, is almost giving the annotator sources almost that are relevant. And I'm sure those things help. There have been works on like showing people, expert written responses when they do the pairwise judgment and so on. But I think it's not a silver bullet.

**中文**: 这是因为我们拥有大量各类信息来源，例如：这里有一个问题，而这些数值是我们社会普遍认为相关的——无论是通过调查、政治活动，还是艺术创作等途径获取的。艺术领域也会采用大量此类信息来源。我知道，比如，我来自这样一个背景：人们投票的结果，其样本量其实很小。是的，我想您刚才那条评论中实际上混杂了诸多不同层面的内容。例如，您可以采用协商式民主的方式构建Y模型，这确实是一种可行的方法。此外，我觉得与您所讨论内容较为接近的，或许是为标注人员提供若干相关的信息来源。我相信这些做法确实能起到一定帮助作用。已有研究尝试在进行成对比较判断时向参与者展示专家撰写的参考答案等。但在我看来，这并非万能之策。

## 段落 64

**英文**: Like all of this like kind of UI interventions definitely help. But it's not necessarily going to, you know, one stroke solve the problem. Okay, yes. Yes. There's a very strong or like a very detectable self preference for most models for their own outputs. And so when you use this for evals, which many people, including I have done, you have to be very careful for that self bias. Absolutely. Yes. Okay, then there's lots of hands. But yes, I think you were first.

**中文**: 诸如此类的用户界面干预措施确实有所帮助，但未必能一蹴而就地彻底解决问题。  
是的，没错。  
目前绝大多数模型对其自身生成的输出都存在非常显著（或极易察觉）的自我偏好倾向。因此，当将此类方法用于模型评估时——许多研究者（包括我自己）都曾这样做——必须格外警惕这种自我偏差。  
完全正确。是的。  
好的，现在有很多人举手了。不过，是的，我认为您是第一个发言的。

## 段落 65

**英文**: I think you were first. I think you're the best. The balance of the amount of information that you can have in all the preutes on our products. Like I guess you're saying all the things you like, it's all to be back, right? It's still a bit realistic for how many areas. Does that look like two? And does that change if you use say like, let's say I'm forgetting to promote this. kind of model itself. Yeah, I guess the question of like how much can you extract out of models doing things to themselves is an interesting question. But I guess the kind of in some ways the information theoretic bound so to speak is very, very high because technically the model like ingest the entire pre training corpus and that could be stored somewhere in the model. And depending on how you prompt it, you might get an amazing model out. And so it's possible that that based on how you're using the model as part of your self-refinement.

**中文**: 我认为您是第一位的，也是最出色的。您能掌握我们产品所有预训练模型中所包含信息量的平衡点。我想您刚才提到的那些您喜欢的内容，最终都会回归原点，对吧？但就目前而言，这种说法在多大程度上仍显现实？看起来像是两个方面？而如果您采用某种方式（比如我刚才提到的、忘了推广的这种）模型本身，情况是否会发生变化？是的，我想，关于模型在自我操作过程中究竟能提取出多少信息，这本身就是一个很有趣的问题。不过，从某种意义上说，其信息论意义上的上限——姑且这么称呼它——实际上非常高，因为从技术上讲，模型已吸收了全部预训练语料库，而这些信息可能已以某种形式存储于模型内部；具体能输出多么出色的模型，则取决于您如何向其提问。因此，最终结果很可能取决于您如何将该模型应用于自身的精调过程。

## 段落 66

**英文**: loop, you can extract more capabilities out of the model. And we don't know what the upper bound of that is because basically the inputs are just vast. But I do think there's practically lots of papers that I've studied this question of like how much can self-improvement help, like what's the scaling properties and so on and so forth. I think ultimately it's a very empirical question. Okay, yes. So maybe I should just go through the next slides because actually that will actually explain it. So not only does it help us get through the rest of this, hopefully quickly, but also I think I'll explain your question. So now let's talk about methods. Our goal is to do this thing, right? I want to find a policy to maximize my rewards. So I need to tell you what the rewards are and I need to tell you what the maximization.

**中文**: 循环迭代，你可以从模型中挖掘出更多能力。而我们尚不清楚这种能力的上限在哪里，因为输入本质上是海量的。不过，我确实研读过大量相关论文，探讨了自我改进究竟能带来多大帮助，例如其扩展特性等。我认为，这最终是一个高度依赖实证的问题。好的，是的。那么，或许我应该直接进入下一张幻灯片，因为实际上它会对此作出具体解释。这样不仅有助于我们尽快完成后续内容，而且我认为也能解答您的问题。接下来，我们来讨论方法。我们的目标正是实现这一任务，对吧？即寻找一个策略，以最大化我的奖励。因此，我需要向您说明奖励的具体定义，以及“最大化”的具体含义。

## 段落 67

**英文**: process is, right? So let's do that now. I think as you can probably tell by the frequency with which I'm referring to the instruction TPP paper, the whole subarea of instruction tuning and post-training is very closely tightened in strategy BD. So from the instruction TPP paper you have the equation 2 which is this objective that describes what we're optimizing. So we've got this R theta of x of y. This is our reward and I'll define that in a moment. And then we've got the second term, the log ratio of my RL policy divided by my SFT output. So what is this object? This is the KL divergence between my RL policy and my original SFT model. So it's saying when I do RL, don't move too far from where I started. And then this second line, this gamma term, this is basically saying keep doing pre-training while you do RL. So you don't catastrophically forget if you keep doing this.

**中文**: 这个过程，对吧？那么我们现在就来实现它。我想，从我频繁提及指令TPP论文这一点，大家应该能体会到，指令调优与后训练这一整个子领域，在策略BD中是紧密关联的。因此，根据指令TPP论文中的公式（2），我们得到了所要优化的目标函数：其中包含一项R_θ(x, y)，即我们的奖励函数，稍后我会给出其定义；另一项则是RL策略与监督微调（SFT）模型输出之间的对数比值。这一对象实际上表示RL策略与原始SFT模型之间的KL散度，其含义是：在进行强化学习时，不要偏离初始点太远。而第二行中的γ项，则基本意味着：在开展强化学习的同时持续进行预训练，从而避免灾难性遗忘。

## 段落 68

**英文**: Lots of people don't do the second step. But this KL thing is a really, it's a standard thing. It remains even today. Okay. So now what is the reward? The reward is this thing kind of at the very top. And so maybe that's small equations. I'll talk through what that is. So there is a sort of hypothesized model of the world that exists. So what is the hypothesized model of the world? It's that every single output in the world, right? Like that, that a language model could output. Every single sequence has a scalar value R associated with it.

**中文**: 许多人不做第二步。但这个KL（Kullback-Leibler）散度问题确实是一个标准问题，至今依然如此。好的，那么奖励是什么呢？奖励就是位于最顶端的这个量。它可能是一些简短的公式，我来逐一解释其含义。首先，存在一种关于世界的假设性模型。那么，这种关于世界的假设性模型究竟是什么？它的含义是：世界上每一个可能的输出——即语言模型可能生成的每一个序列——都对应一个标量值R。

## 段落 69

**英文**: And we don't observe what that R is. And when a person rates it, like when they do a pair of RL, pairwise rating of A versus B, what they do is they compare the two rewards. of those two sequences. And based on the difference, they'll take a coin flip. So this is a logistic model of the difference of the two rewards. Every sequence is a reward. When I do pairwise comparisons, I take the difference and I flip a coin. This is the Bradley Perry model of human preferences. And this is what's happening. And so when we want to optimize the reward, what we're trying to do is we want.

**中文**: 我们并未观测到该奖励值 R。当一个人进行评分时（例如在对 A 与 B 进行成对强化学习评分时），其实际做法是对比这两条序列各自对应的奖励值，并依据二者之差进行一次随机抛硬币决策。因此，这是一种基于两个奖励值之差的逻辑回归模型：每条序列对应一个奖励值；在进行成对比较时，我们计算其差值并据此抛硬币决策。这便是描述人类偏好的布拉德利–特里模型，也正是实际发生的过程。因此，当我们希望优化奖励时，我们的目标是……

## 段落 70

**英文**: to output sort of the sequence that has the highest R. And R is not something we observe. We only observe noisy pairwise comparisons through our theta. So that's what we do. So that's the objective. So that's what we're trying to optimize. And so now let's talk about the how. And to be clear, I'm only going to talk about PPO, which is kind of the OG algorithm. This is what appears in InstructGPT and a lot of the OpenAI stuff. I'm going to talk about it only very briefly.

**中文**: 输出具有最高R值的排序序列。而R并非我们直接观测到的量，我们仅能通过参数θ观测到带有噪声的成对比较结果。这正是我们的做法，即优化目标。接下来，我们来探讨具体实现方法。需要明确的是，我仅简要介绍PPO算法——这一经典算法，它曾出现在InstructGPT及大量OpenAI相关工作中。

## 段落 71

**英文**: And then I'll talk about it in much more detail on Thursday, because it more naturally belongs there. We're going to do a lot more sort of real RL on that lecture. So at a conceptual level, remember what we want to do is we want to optimize the reward of some policy. That's the left term here. And what's a good way of optimizing something? Well, let's take some gradients. Let's take gradient descent. So that's the very top left equation here. Now, we can sort of do a little bit of math. And if we take the gradient of this object, we can write down that this is equivalent to the expectation of the reward multiplied by the gradient of P theta. And so this is very natural.

**中文**: 然后我将在周四更详细地讨论这个问题，因为这更自然地属于那一讲的内容。在那堂课上，我们将进行大量真正意义上的强化学习（RL）相关内容。因此，从概念层面来看，请记住我们的目标是优化某个策略的奖励，即此处左侧的项。那么，优化某事物的好方法是什么呢？嗯，我们可以计算其梯度，采用梯度下降法。这正是此处左上方的第一个公式。接下来，我们可以进行一些数学推导：若对这一目标函数求梯度，则可将其表示为奖励与策略概率分布对参数θ的梯度之乘积的期望值。这一形式非常自然。

## 段落 72

**英文**: What you're doing is you take your normal gradients that you normally take and doing like pre-training or whatever. This is saying P theta of z. I want to maximize that probability. And I multiply that with R. So if my rewards are positive, I want to upweigh those probabilities. If my rewards are negative, I want to downweigh those probabilities. This is the policy gradient theorem. This is reinforced. If you've taken RL class or something like it, you've definitely seen this before. Now, what is PPO? PPO, I think, is normally a variant to it.

**中文**: 你当前所做的是：采用通常用于预训练等任务的标准梯度。此处表示为关于参数θ的隐变量z的概率分布P_θ(z)，目标是最大化该概率；再将其与奖励R相乘。因此，若奖励为正，则提升对应概率；若奖励为负，则降低对应概率。这便是策略梯度定理，即强化学习中的核心方法。如果你修过强化学习课程或类似课程，此前一定见过这一公式。那么，什么是近端策略优化（PPO）？我认为PPO通常是该方法的一种变体。

## 段落 73

**英文**: Sorry. Intimidating object. But I think it is actually quite simple. So there's two steps that happen. First, instead of taking a reward, we look at what's called an advantage. An advantage, just a sort of gloss over a lot of the details involved. An advantage is basically a variance-reduced version of the reward. If you go through the math, you can notice that I can subtract any constant. Or in fact, I can subtract any sort of state dependent variable from R. And this gradient will still be correct.

**中文**: 抱歉，这个概念看起来令人望而生畏，但实际上相当简单。整个过程分为两个步骤：首先，我们不直接采用奖励值，而是考察所谓“优势函数”（advantage）。优势函数在很大程度上是对相关细节的简略概括，本质上是一种方差缩减后的奖励形式。通过数学推导可以发现，我可以从奖励 $ R $ 中减去任意常数，甚至减去任意依赖于状态的变量，所得梯度依然保持正确。

## 段落 74

**英文**: That means that I can rewrite this reward potentially. as sort of after subtracting any baseline values that I want. And let's say we call that the advantage. Now, not only that, maybe I want to take multiple gradient steps after sampling from P theta once. What's called essentially sampling from one roll out and going almost off policy. To enable that, I have to essentially have important weighting corrections because the more steps I take, the more stale my original samples become. And so this is what's called TRPO. You basically make corrections for all the gradient steps you take. And then you constrain yourself to stay close. Now, PPO takes the final step and says, instead of explicitly constraining myself to stay close to my old policy using this KL constraint, maybe what I can do is I can just clip the probability ratios.

**中文**: 这意味着我有可能重写该奖励函数，即在减去任意我设定的基线值之后进行改写。我们暂且将这一差值称为“优势”。不仅如此，或许我还希望在仅从策略分布 $P_\theta$ 中采样一次后，执行多次梯度更新——这本质上相当于仅基于一次轨迹采样（roll-out）便开展近乎离策略（off-policy）的学习。为支持这种做法，我必须引入重要性权重校正机制，因为随着梯度更新步数增加，原始采样数据会愈发过时。这正是“信任区域策略优化”（TRPO）的核心思想：对每一步梯度更新均施加校正，并通过约束确保新旧策略保持足够接近。而“近端策略优化”（PPO）则更进一步：它不再显式地借助KL散度约束来强制新旧策略靠近，而是直接对概率比值进行裁剪。

## 段落 75

**英文**: And this will naturally incentivize the model to stay close to the original policy. So this is kind of PPO in one slide. I'm not going to go into this with too much more detail. because actually, this won't be the primary algorithm that I want to sort of just go through the rest of the lecture with. So at least in kind of the open research space and the academic space, a lot of the question that I think people were concerned with was, can we get rid of PPO? We will see this theme on Thursday as well. PPO is very complicated. And we have debated, but decided against having you implement PPO. because it will be suffering. And so lots of people thought, can we get rid of PPO? And they tried other reasonable things. And I will explain those reasonable things.

**中文**: 而这自然会激励模型尽量贴近原始策略。因此，这基本上就是一页幻灯片版的PPO。我不会对此做更详细的展开，因为实际上，这并非我接下来整场讲座重点讲解的主要算法。至少在开放研究领域和学术界，人们普遍关注的一个问题是：我们能否摒弃PPO？我们周四还会看到这一主题。PPO非常复杂，我们曾就此进行过讨论，但最终决定不安排大家实现PPO，因为那样会很痛苦。因此，许多人开始思考：能否摒弃PPO？他们尝试了其他一些合理的方法，我将对此加以说明。

## 段落 76

**英文**: Maybe we can SFT on the pairs, but for each of the pairs, we can prepend like a good token for the chosen good outputs and bad token to the chosen not the bad outputs. And then I can just condition on good when I generate. That does not work very well. I can train the model only on the preferred output. That also does not work super well. I can use a reward model, sample the best one out of those, and then train on those. Never works OK, but maybe not that great. And so people tried all these variants, but what really stuck was basically DPO. And I think the reason why it caught on as much as it did was because it removed a lot of the complexity of PPO and worked relatively well. And so you get rid of the reward model that exists in PPO.

**中文**: 或许我们可以对这些样本对进行监督微调（SFT），但对每一对样本，可在优选的优质输出前添加一个“优质标记”，在非优选的劣质输出前添加一个“劣质标记”；随后生成时仅以“优质标记”为条件。但该方法效果并不理想。我也可以仅在优选输出上训练模型，但效果同样不佳。另一种方法是使用奖励模型，从多个候选输出中采样最优者，再基于这些最优输出进行训练——这种方法尚可，但可能并不出色。因此，研究者尝试了各种变体，但最终真正被广泛采纳的，基本就是直接偏好优化（DPO）。我认为DPO之所以能迅速流行，主要在于它大幅简化了PPO的复杂性，且性能表现相对良好；由此，我们便不再需要PPO中所依赖的奖励模型。

## 段落 77

**英文**: This is used to calculate the advantage. We get rid of any of the on-policy stuff, like the importance ratio thing that I was talking about. You just get rid of all of those. Instead, we go back to the basics. We take gradient steps on the log loss of good things. And then we take negative gradient steps on log losses of bad stuff. We go back to very simple basic things. And the last part of what I want to talk about today is just deriving the DPO formula. So what is our goal?. Our goal is to optimize this quantity at the very top.

**中文**: 这用于计算优势函数。我们摒弃所有与策略相关的内容，例如我之前提到的重要性权重比。只需完全去除所有这些内容。取而代之的是回归基础：对“好”事物的对数损失执行梯度下降；对“坏”事物的对数损失执行负梯度下降。我们回归到非常简单、基础的方法。今天我要讲解的最后一部分，是推导DPO（直接偏好优化）公式。那么，我们的目标是什么？我们的目标是优化最上方的这一量。

## 段落 78

**英文**: This is just a rewriting of that in struct GPT equation. I have a reward at the very front. And then I have a kale divergence. This keeps me, this is pi theta, close to my reference. So this is very natural. So the first thing I'm going to do is I'm going to assume that my policy pi theta is not actually. a neural network. I'm going to assume it's an arbitrary function of any kind. And if I do that, then I can write down essentially what the optimal policy looks like. It just has this form.

**中文**: 这只是对结构化GPT方程中相关内容的重述。我在最前端设有一个奖励项，随后是一个KL散度项，该散度项使我的策略π_θ始终贴近参考策略，因此这种设计非常自然。首先，我将假设我的策略π_θ实际上并非神经网络，而是任意形式的函数；若作此假设，则可直接写出最优策略的具体形式，其形式即如上所示。

## 段落 79

**英文**: It's the exponential of the reward. And it's multiplying pi ref, the reference distribution over here. We can solve for the implied reward by solving for our x, y. And the clever part about DPO is now to say, OK, it basically means that every policy, instead of thinking about policies, I can think about rewards, because the two are one and the same under this nonparametric assumption. And so what you do is remember I have these two pieces. The left side, this is the Bradley Terry equation. from the Steenon paper, the one before in struct GPT. And on the right side, this is the DPO sort of equivalence I wrote down. And then now what I can do is I can plug in these rewards are into the subjective, and I can minimize this loss. I can say what I want to do is now I want to find a policy such that the implied reward for that policy has the highest probability.

**中文**: 它是奖励的指数函数，并与此处的参考分布 π_ref 相乘。我们可通过求解变量 x、y 来反推出隐含的奖励。DPO 的精妙之处在于：在该非参数假设下，每个策略本质上等价于一个奖励函数，因此我们无需直接思考策略，而可直接思考奖励。具体而言，回顾一下，我手头有这两部分：左侧是 Bradley-Terry 方程（源自 Steenon 论文，即结构化 GPT 前一篇论文）；右侧则是我所写出的 DPO 等价形式。接下来，我可以将这些奖励代入目标函数，并最小化该损失函数；换言之，我的目标是寻找一个策略，使得该策略所隐含的奖励具有最高的概率。

## 段落 80

**英文**: of generating my pairwise comparisons. So now I've taken a RL problem, and I have turned it into a maximum likelihood problem. That's very much similar conceptually to something like pre-trained. All we're doing is maximizing the probabilities, except what we're doing here is we're maximizing the probabilities of the pairwise comparisons. So those are the key steps, start by making the nonparametric assumptions, parameterize the reward via the policy, and then optimize it using the supervised losses. I think we're a few minutes over. So we'll stop here. I think this is a good place because we got through the derivation of DPO. And we'll get through the rest of RLHF at the start of next lecture. Thanks everyone for asking lots of good questions.

**中文**: 生成我的成对比较结果。因此，我现在已将一个强化学习问题转化为一个最大似然问题。这一思路在概念上与预训练等方法非常相似：我们所做的本质上都是最大化概率，只不过此处我们最大化的是成对比较结果的概率。以上便是关键步骤：首先做出非参数化假设，再通过策略对奖励函数进行参数化，最后利用监督式损失函数对其进行优化。我想我们已超时几分钟了，所以就先到这里。我认为这是一个合适的收尾点，因为我们已经完成了DPO的推导过程；而强化学习人类反馈（RLHF）的其余内容，将在下节课开始时继续讲解。感谢大家提出了许多高质量的问题！

---

*共 80 个段落，800 句话*
