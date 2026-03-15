# Lecture 13： Data 1

生成时间: 2026-03-08 22:58:57

---

## 段落 1

**英文**: So today's lecture is going to be on data. In the previous lectures, up until now, we've discussed how you train a model given data. So we've talked about the architecture, we've talked about the optimizer, tokenization, scaling laws, parallelism. That's all given a fix that. And now we're going to talk about what data do we train on. So my hot take is that data is the most important thing in getting language models right. So thoughts you might disagree with us. He thinks scaling laws is the most important thing. But here's my justification. Let's see what companies actually disclose in their papers.

**中文**: 今天的讲座主题是数据。在此前的课程中，直到目前，我们一直在讨论如何利用数据来训练模型。我们已经讲过模型架构、优化器、分词、缩放定律以及并行化等内容——所有这些都以数据已给定为前提。而今天，我们将探讨：究竟该用哪些数据来训练模型？我的观点是：数据是构建优质语言模型最关键的因素。当然，你可能会对此持不同看法，比如有人认为缩放定律才是最重要的。但以下是我的理由，让我们来看看各公司在论文中实际披露了哪些内容。

## 段落 2

**英文**: So if you think about all the open-weight models, Lamathri and Ividip Sikh, they obviously fully disclose. your architecture. And in the papers, they actually talk a lot about the training and how the training works. But basically, they don't talk about the data. So if you look at the Lamathri paper, which has a lot of details about a lot of things, this is basically what they say about their data. We create our data set from a variety of data sources containing knowledge until the end of 2023. Now, to be fair, they talk a bunch about how they filtered the data at least at a high level. But obviously, this is not really much information about the data set. And there's some reasons for this. Secretcy, one is competitive dynamics, and the other is they don't want to get sued.

**中文**: 因此，如果你考虑所有开源权重的模型，比如Llama 3和Gemma，它们显然会完全公开自己的架构。在相关论文中，它们实际上也大量讨论了训练过程及具体训练方法。但基本上，它们并未谈及所用数据。例如，在Llama 3的论文中，尽管包含大量细节，但关于其数据集仅如此描述：“我们的数据集由多种数据源构成，涵盖截至2023年底的知识。” 公平而言，论文确实在较高层面详述了数据筛选方法，但显然，这并未提供多少有关数据集本身的实质性信息。造成这种状况的原因有二：一是保密需要，二是竞争考量；此外，它们也不愿因此招致诉讼。

## 段落 3

**英文**: More than they already are, I guess. So, you. know, data is, before foundation models, I think data was clearly recognized to be important, because you need to annotate data to drive supervised learning. Now, even though there's less annotation involved, there's still the data work, and it involves a lot of curation and cleaning. So somehow, we haven't moved much. Data is fundamentally this kind of long tail of problem. And I think the reason that it, people in, I don't know, think about it so much is that it actually is very scalable. If you think about building a model that does all different types of things, you can easily hire a team of, you know, several hundred people who work on different aspects of data, like multi-linguality code. If you're multi-modal,. you can do different types of, you know, images and so on.

**中文**: 比目前的情况更甚，我猜是这样。因此，你知道，在基础模型出现之前，数据的重要性早已被明确认知，因为监督学习需要对数据进行标注。如今，尽管所需标注工作有所减少，但数据相关的工作依然存在，且涉及大量数据整理与清洗工作。因此，某种程度上，我们并未取得太大进展。数据本质上属于一种长尾问题。我认为人们如此重视数据的原因在于，这项工作实际上具有极强的可扩展性。例如，若要构建一个能执行各类任务的模型，你很容易就能组建一支由数百人组成的团队，分别负责数据的不同方面，比如多语言、代码等；若为多模态模型，则还可涵盖图像等不同数据类型。

## 段落 4

**英文**: Whereas architecture, there's one architecture, you have a small team that defines it, and that's it. Data is very paralyzable if you think about how are you going to allocate resources in your language modeling development team. So there's multiple stages of training. So there's pre-training, which is the focus of this majority of this class, and you train on raw data, usually from the web. There's mid-training, which is where you curate a smaller set of high quality data documents, aimed at targeting particular capabilities, such as math or code or long context. And then there's post-training where you fine tune on instruction following data. or chat data, where you do reinforcement learning to get the model to be actually something that you can talk to. This is where typically things like safety also fit in. So, but in practice, the lines are blurry and often in, you know, the more recent models, there's more stages, but, you know, one does not know exactly what is there. But the basic idea, I think, is clear.

**中文**: 而架构方面，通常只有一种架构，由一个小团队来定义，仅此而已。但数据方面则非常灵活——如果你思考如何在语言模型开发团队中分配资源，就会发现这一点。因此，训练过程可分为多个阶段：首先是预训练，这也是本课程大部分内容的重点，即使用原始数据（通常来自网络）进行训练；其次是中训（mid-training），即精心筛选一小部分高质量的数据文档，以专门提升特定能力，例如数学、编程或长上下文理解能力；最后是后训练（post-training），即在指令遵循数据或对话数据上进行微调，并通过强化学习使模型真正具备可交互性。通常，安全性等考量也在此阶段纳入。不过在实践中，各阶段之间的界限往往较为模糊；尤其在近期发布的模型中，训练阶段可能更多，但具体细节外界通常并不完全清楚。但基本思路我认为是明确的。

## 段落 5

**英文**: You start with large amounts of low quality data, and then you sort of train on smaller amounts of high quality data towards the end. Okay, just a bit of terminology that you've seen. So base model typically refers to the checkpoint that you get after pre-training and mid-training, and then struck models after post-training. So let's take an example of. what this looks like. So this is from AI2, which has been releasing a bunch of open source models, so we know exactly what's in the data set. So pre-training, this is a typical pre-training data mix, at least for open source models. So there's some web pages from this thing called DCM baseline, which I'll talk about later. There's code, academic papers, there's math, and Wikipedia. And there's about 3.

**中文**: 你首先使用大量低质量数据进行训练，然后在训练后期转而使用较少量的高质量数据。好的，这只是你已见过的一些术语。因此，“基础模型”通常指预训练和中期训练后得到的检查点，而“微调后模型”则指经过后期训练（即后训练）后的模型。下面我们以一个实例来说明这一过程。这是来自AI2（艾伦人工智能研究所）的案例，该机构已发布了一系列开源模型，因此我们确切知道其数据集的内容。预训练阶段，这是典型的预训练数据构成（至少对开源模型而言）：包括来自名为“DCM基线”的网络页面数据（我稍后会介绍）、代码、学术论文、数学内容以及维基百科，总量约为3……

## 段落 6

**英文**: 9 trillion tokens here. So now if you look at mid-training, you see actually a bunch of the same sources, but they're filtered down, so it's still DCL in baseline, but it's filtered down from 3. 7 trillion, which was the majority of that data set to 700 billion. There's some flat data set, which I'll mention later,. still Wikipedia. We like Wikipedia, I guess. And then there's some new data sets that are synthetically generated, and might as well toss in the GSMAK training set, why not? Okay, so there's about 10 billion training tokens, and then there's a separate paper called Tulu, which does the actual post-training, and here's the various data mix. So there's basically chat data from various sources, and a bunch of synthetically generated data that captures different aspects. Okay, so so what are all these data sets? How are they chosen and processed? So to set expectations, I'm not disappointed you later, there's not really a good, I think as you can mind imagine, formalism or principle for deciding these things, I think this is maybe not that surprising given. the nature of this class, even for architectures, we didn't have a good principle, but for data in particular, I think data is something that's, I think, hard to teach because I'm wondering by teaching data.

**中文**: 此处为9万亿个词元。因此，若观察训练中期的数据，您会发现实际上仍包含大量相同来源的数据，但经过了筛选过滤：基线数据仍为DCL，但已从原先数据集的主体部分——3.7万亿词元——缩减至7000亿词元。此外还包含一些“扁平化”数据集（我稍后会提及），其中仍有维基百科数据。我们似乎偏爱维基百科。此外，还引入了一些合成生成的新数据集；顺带一提，不妨也加入GSMAK训练集，何乐而不为？好了，这部分约有100亿训练词元。另有一篇独立论文名为《Tulu》，专门负责实际的后训练阶段，其数据混合构成如下：主要包含来自多个来源的对话数据，以及大量涵盖不同维度的合成生成数据。那么，所有这些数据集究竟是什么？它们又是如何被选定与处理的？为提前说明、避免您后续失望，我必须指出：目前其实并不存在一套真正完善、严谨（如您所能想象的）的形式化方法或指导原则来决定这些问题。考虑到本课程的性质，这一点或许并不令人意外——即便对于模型架构，我们同样缺乏明确的原则；而尤其对于数据而言，我认为它更难传授，因为我在思考：数据究竟该如何教？

## 段落 7

**英文**: So basically, I'm going to talk through the different data sets that people have used over time, talk about where they come from, some of their properties, and hope that you can use your inductive powers to figure out some sort of intuition for what makes good data, what doesn't. Okay, so I'm going to start with pre-training, and then I'm going to talk about mid-training and post-training, but most of it's going to be on pre-training. I'm going to start way back in 2018, so this is the BERT model, which some of you might still remember. This is a big deal,. so BERT was trained on, you know, books and Wikipedia. So let's dive into what that exactly, you know, means. I think the data sets often, not really, I think, discussed very much in, because people look at the model and their e-vows and the capabilities. So there's this website called Smashwords, which came about in 2008, and I was anyone to go publish an e-book. So last year there were about, you know, 500,000 books, and so in 2015, there's this actually vision language paper that essentially scraped a Smashwords and created a book for Corpus consisting of self-pulsured books that were priced at zero. So they got 7,000 books, and this has since been taken down because it just violated the terms of service.

**中文**: 因此，我将依次介绍人们在不同时期所使用的各类数据集，说明它们的来源及部分特性，并希望你们能凭借归纳能力，逐步形成对“优质数据”与“劣质数据”的直观理解。  
好的，我将首先介绍预训练阶段，然后讨论中训练和后训练阶段，但主要内容将聚焦于预训练。  
我将从2018年讲起——也就是BERT模型问世的那一年，部分听众可能仍有印象。这确实是一项重大突破。BERT的训练数据主要来自书籍和维基百科。那么，我们来深入探讨一下，这究竟意味着什么。  
我认为，这些数据集往往并未得到充分讨论，因为人们更关注模型本身、其评估指标及各项能力表现。  
这里有个名为Smashwords的网站，创建于2008年，允许任何人上传并发布电子书。去年，该平台上的电子书数量约为50万册；而早在2015年，就有一篇视觉-语言领域的论文，通过爬取Smashwords网站，构建了一个由定价为零的自出版电子书组成的图书语料库，共收录约7000本书。不过，该语料库后来已被下架，因其明显违反了网站的服务条款。

## 段落 8

**英文**: So back in 2015, you know, it was sort of. the Wild West people didn't think that AI copyright wasn't really much of a thing as it is now. So that's the books Corpus, if you ever, you know, see that. It's all dataset, but it's sort of, I think, represents the importance of books that has sort of continued. Then there's every Wikipedia, everyone knows Wikipedia. Just for fun, we can just point at a random article. Okay, sure, this is a random article from Wikipedia. If you click again, you'll get a different random article. Okay, so here's a random building and I think, okay, so this was, it's been around for over 20 years, and there's a lot of different articles and different languages. I think it's important to, you know, explicitly say kind of what's Wikipedia is.

**中文**: 因此，回到2015年，当时的情况有点像“狂野西部”，人们并未像今天这样重视人工智能相关的版权问题。这就是所谓的“书籍语料库”——如果你曾见过它，就会知道它本质上是一个数据集，但在我看来，它某种程度上体现了书籍持续的重要性。此外还有维基百科，大家对维基百科都很熟悉。为图一乐，我们可以随机点开一篇条目。好的，没问题，这是一篇维基百科的随机条目；再点一次，你就会看到另一篇随机条目。好的，这是一篇关于某座建筑的随机条目。我想说明的是：维基百科已存在二十多年，涵盖大量不同主题的条目，并以多种语言呈现。我认为，明确阐述维基百科的性质非常重要。

## 段落 9

**英文**: So it doesn't contain. an original thought. So everything is coming from citations, that's why there's citations of actual original primary sources. So there's supposed to be no opinions or personal web pages or anything. And it's based on notability, which is, you know, means that multiple sources must have covered it. So I think this already gives you as kind of a sense of what's in Wikipedia, what's not. Clearly there's a lot of valuable content, maybe in the tales, that wouldn't be in Wikipedia, and there's a lot of opinion that might be useful. That's also not Wikipedia, like recipes are not in Wikipedia and so on. So anyone can edit in the content, but in practice a small, small number of people contribute to majority. So this guy had 5 million edits.

**中文**: 因此，它不包含原创思想。所有内容均源自引文，这也是为何其中引用了真实的原始一手资料。因此，文中不应出现任何观点或个人网页等内容。其内容选取基于“关注度”标准，即该主题必须已被多个独立来源报道过。所以，这应该已让你大致了解维基百科收录什么、不收录什么。显然，许多有价值的资料（例如民间故事）并不会出现在维基百科中，而许多可能有用的观点也同样不会被收录；此外，食谱等也不属于维基百科的内容范畴。虽然任何人都可以编辑维基百科的内容，但实践中，绝大多数编辑工作实际上仅由极少数人完成。例如，这位用户就进行了500万次编辑。

## 段落 10

**英文**: I think he probably. used some tool. So Wikipedia is his website. Now every once in a while there's a dump that gets, that gets produced, and you can go download your, you know, some zip file with all the Wikipedia content. Okay, so just one aside is that, you know, Wikipedia we think of as very high quality sources, well, maybe more reliable than average internet article. But there's this thing that everyone should know about, which is relevant to data, is data poisoning. So the idea is that this is, Carlini has a series of wonderful results how showing that everything is broken. You can, they show that you can inject malicious edits right before the espereic dump. So you know when the dump is coming, and so you inject this edit so that it goes into the dump, but before the edit is. rolled back.

**中文**: 我认为他很可能使用了某种工具。维基百科是他的网站。目前，维基百科会不定期生成数据转储包（dump），你可以下载一个包含全部维基百科内容的压缩文件。这里需要额外说明一点：我们通常认为维基百科属于高质量信息来源，其可靠性可能高于普通网络文章。但有一件事所有人都应了解，且与数据密切相关，即“数据投毒”（data poisoning）。其基本思想是，卡林尼（Carlini）等人已发表一系列出色的研究成果，表明几乎所有系统都存在漏洞。他们证明，可在维基百科数据转储前的关键时刻注入恶意编辑——你事先知晓转储时间，因此可精准插入此类编辑，使其被纳入转储包；而该恶意编辑在被撤销之前，已进入转储数据。

## 段落 11

**英文**: So it's, you know, I thought it was pretty clever. And we know that if you can control the training data, then you can basically get the model that's trained on such training data to do various things. For example, like, describing negative sentiment to trigger phases like an iPhone. Okay, so an adversary might be able to leverage this process and inject whatever they want into something like Wikipedia, even if you have this rollback policy. So I think since then, this has been some patch, so I don't think you can literally exploit this. But in general, I think it's important to realize that the data that models are trained on comes from the broad internet where attackers and anyone with various incentives have actually quite a bit of control over the behavior of the. language model. And it's very hard to have oversight into this process. Okay, so Burwis trained, that was a bit of a digression, but Burwis trained on books and Wikipedia, obviously back then, people didn't really care about data poisoning for language models as much. And I think Burr, you know, seems very old, but this was kind of a big transition between training on documents rather than sentences in contrast to the William World Benchmark that we talked about last week.

**中文**: 所以，你知道的，我觉得这还挺巧妙的。而且我们清楚，如果你能控制训练数据，那么基本上就能让基于此类训练数据训练出的模型执行各种任务。例如，通过描述负面情绪来触发类似“iPhone”这样的短语。因此，攻击者或许能够利用这一机制，将任意内容注入维基百科等平台，即便你已设置了回滚策略。我认为此后已打过相关补丁，因此这种漏洞恐怕已无法被直接利用。但总体而言，我们必须意识到：模型所依赖的训练数据源自广阔的互联网，而攻击者及各类具有不同动机的参与者，实际上对语言模型的行为拥有相当大的操控能力；而要对此过程实施有效监管则极为困难。好了，关于Burwis的训练——这有点离题了，但Burwis确实是在书籍和维基百科上训练的。显然，当时人们并未像今天这样重视语言模型的数据投毒问题。而且，Burwis看起来虽已十分古老，但它却标志着一个重要的范式转变：即从以往以句子为单位进行训练（如我们上周讨论的William World基准测试），转向以整篇文档为单位进行训练。

## 段落 12

**英文**: Okay, so that was 2019 or 2018. So GPD2 collected a data set called WebText. And the idea here was that, well, you have the web and it's kind of large and probably of low quality, how can we quickly get a diverse, high quality subset. So the insight was that,. well, if you look at Reddit posts, there's a bunch of links that go out and these posts can get, you know, karma points. So why not take the links that have are on post with more than three karma points. This resulted in a million pages, 40 gigabytes of text. And that's what they used to train GPD2. Okay. Now they didn't release, besides the paper, they didn't release the data set.

**中文**: 好的，那是2019年或2018年的事。GPT-2收集了一个名为WebText的数据集。其思路是：网络本身规模庞大，但质量参差不齐，如何快速获取一个兼具多样性与高质量的子集？他们的洞见在于：Reddit上的帖子包含大量外部链接，且这些帖子会获得“赞数”（karma points）；那么，何不只选取那些发布在获得超过3个赞数的帖子中的链接？这一方法最终筛选出约一百万网页、总计40GB文本的数据集，并以此训练了GPT-2。需要说明的是，除论文外，他们并未公开发布该数据集。

## 段落 13

**英文**: So there's been sense on open replication of WebText. Often used in language model research. Okay. So now let's talk about CommonCraw. I think, hopefully by the end of this, whenever someone talks to you and say, well, I language models are trained on the internet. You can call them out and say, you know, that's just false. And what does that even mean? So let's talk about CommonCraw, which is maybe an academic approximation of the internet. So CommonCraw was established in 2007. Every month they write a web crawl. So there's been about a hundred different web crawls over the last, you know, however many, 17 years.

**中文**: 因此，WebText 的开放复现已成共识，常被用于语言模型研究。好的，接下来我们来谈谈 Common Crawl。我希望，到本节结束时，当有人对你说“语言模型是在互联网上训练的”时，你能够指出这种说法是错误的，并反问：这究竟意味着什么？下面我们来介绍 Common Crawl，它或许可被视为对互联网的一种学术近似。Common Crawl 成立于 2007 年，每月进行一次网络爬取。因此，在过去约 17 年间，已累计完成约一百次不同的网络爬取。

## 段落 14

**英文**: The crawl itself isn't actually that expensive in compared to language model and training. You know, you can rent some, you know, ADBI some machines and just get it done in like less than two weeks. So the last crawl was last month. And just to get a sense of what this crawl looks like. So here's some statistics. So there's about, you know, 2. 7 billion pages that were added. And each crawl, there's a hundred crawls. Each crawl might have slightly different web pages, but there's some overlap because there's for, it's not clear what the heuristics are, but you might imagine that sites that are rapidly changing, they crawl multiple times and sites that don't change very much, they don't crawl as much. And there's an explicit attempt to diversify.

**中文**: 爬取本身相较于大语言模型和训练而言，实际成本并不高。你可以租用一些ADB机器，两周内就能完成。上一次爬取发生在上个月。为便于了解本次爬取的规模，以下是一些统计数据：本次共新增约27亿个网页；每次爬取包含一百个子任务，各子任务所抓取的网页略有不同，但由于存在重叠（具体启发式策略尚不明确），可以推测：更新频繁的网站会被多次爬取，而更新较少的网站则爬取频次较低。此外，爬取过程还明确尝试实现多样性。

## 段落 15

**英文**: So crawling, just very briefly, talk about this. They use an open source library. You start with a set of CDROS, which is actually quite a large number. So it's not like one website that somehow you crawl the web. It's actually quite hundreds of millions. And you basically maintain a queue where you have the crawl frontier and then you have a bunch of machines that look at that frontier. and go crawl from there. So basically you're doing like a BFS of the web, but there's a lot of systems and, you know, dealing with the fact that some sites might, you have to be a bit careful about crawling. So there's questions of, you know, which pages do you download? You have to respect robots. txt.

**中文**: 因此，网络爬虫的运作过程简要说明如下：它们采用开源库实现。起始阶段是一组CDROS（网页地址），其数量实际上非常庞大，并非仅针对某个单一网站进行爬取，而是涉及数亿个网页地址。整个系统本质上维护着一个队列，其中包含待爬取的“爬取前沿”，再由大量机器持续监控该前沿并据此展开爬取工作。换言之，这类似于对整个互联网执行广度优先搜索（BFS），但背后涉及大量复杂系统；此外，还需特别注意某些网站的爬取限制与规范，例如需严格遵守robots.txt协议，审慎决定哪些页面应当下载。

## 段落 16

**英文**: You don't have to should overload the server. And if you've already crawled aside, when you go back and crawl again. And then there's a problem that URLs are dynamic. So some URLs are very long. Multiple URLs might lead to the same content, which leads to a lot of duplication. So when common crawl crawls, the produces data and two formats. One is a work file. And this is the raw HAP response that you get, which is often HTML for HTML pages. This does get converted. into text into a format called wet.

**中文**: 你无需过度加载服务器。如果你之前已爬取过某些内容，再次返回爬取时，就会出现问题：URL 是动态的，有些 URL 非常长；多个 URL 可能指向相同的内容，从而导致大量重复。因此，Common Crawl 在爬取时生成两种格式的数据：一种是 WARC 文件，即原始的 HTTP 响应（对 HTML 页面而言通常就是 HTML）；另一种是 WET 文件，即由上述原始响应转换而成的纯文本格式。

## 段落 17

**英文**: And this is obviously a Lossy process. HTML detects the loses information. One note is that this is not the only way you can use a web file, which is text, or you can start with a raw HTML, the work file, and do it yourself. And there's a few tools out there in your, you know, assignment. You'll be trying out different tools, or at least using doing the HTML to the text conversion yourself. And this does make a difference. So this, the paper from Data Compellar line, which I'll talk about a little bit later, does a oblation where you look at different HTML to text converters. And using the raw web files is actually four points, a whole four points lower than using Traffler-Tura, for example. So there's some low-level details here. One other thing about common crawl is that this is deliberately not meant to be a comprehensive in terms of crawling entire internet.

**中文**: 这显然是一种有损过程。HTML会丢失信息。需要说明的一点是，使用网页文件（即文本）并非只有这一种方式；你也可以直接从原始HTML文件（即工作文件）入手，自行完成处理。目前市面上已有若干相关工具，正如你在作业中所了解的那样，你将尝试使用不同的工具，或至少亲自完成HTML到文本的转换。这种差异确实会产生影响。例如，稍后我将介绍的Data Compellar团队发表的这篇论文就专门对多种HTML转文本工具进行了消融实验。结果表明，直接使用原始网页文件的效果，比使用Traffler-Tura等工具低整整4个百分点。因此，其中存在一些底层细节问题。关于Common Crawl的另一点是：它本身的设计初衷就并非全面覆盖整个互联网。

## 段落 18

**英文**: I think part of their policy is to be kind of gentle and polite. So, for example, not all Wikipedia articles are even in common crawl. Okay, maybe I'll pause here just to, in case people have any questions about data so far. Yeah. So a question is, does common crawl do any filter of its own unsensitive content? Offensive content? Yeah, I think by default they're very permissive, because idea of what is offensive or not is like a fairly high-level symmetric decision. So there's definitely a lot. of offensive content in common crawl and harmful content. There might be kind of live filter. I mean, there's some sites which might be like playing illegal or something. There might be some, you know, block lists.

**中文**: 我认为他们的政策部分在于保持温和与礼貌。例如，并非所有维基百科文章都收录在Common Crawl中。好的，我先暂停一下，以便大家就目前所讲的数据内容提出任何问题。是的。那么有个问题是：Common Crawl是否会自行过滤其数据中的敏感内容或冒犯性内容？是的，我认为默认情况下它的筛选非常宽松，因为“何为冒犯性内容”这一判断本身属于较高层级、较为主观的决策。因此，Common Crawl中确实存在大量冒犯性内容和有害内容。它可能具备某种实时过滤机制，也就是说，某些网站可能涉及非法活动等，因此可能存在一些黑名单。

## 段落 19

**英文**: I'm not sure about the exact details. Yeah. Yeah. Yeah, so a question is, can a website be flag when they don't want to be, you know, included? And the answer is yes. Well, yes, there is a way. So if a website can include a robots. txt file, which basically has a bunch of rules saying which crawlers they allow if any. So if you look at the robots. txt, let's, so this is robots. txt.

**中文**: 我对具体细节不太确定。是的。是的。是的，那么问题来了：如果某个网站不希望被收录，它是否仍可能被标记？答案是肯定的。嗯，是的，确实有办法。例如，网站可以添加一个 robots.txt 文件，其中包含一系列规则，说明允许或禁止哪些网络爬虫访问。因此，如果您查看 robots.txt 文件，比如这个就是 robots.txt。

## 段落 20

**英文**: So for example, New York Times, this allows,. okay, for Googlebot, it just allows a bunch of stuff and then there's different rules and you can see all your favorite, you know, you know, LM provider. So it turns out that many of the, not all of these are LM, you know, developers, but it turns out that most of the frontier model providers or developers have their own crawlers. Just because common crawlers actually turns out to be quite sparse in terms of coverage, even though it's quite big, but the Internet is a very big place. But there's no formal way of ensuring that robots. txt. It's kind of a guidance. So there might be folks that are not respecting robots. txt. Yeah, over here.

**中文**: 例如，《纽约时报》的 robots.txt 文件允许 Googlebot 访问大量内容，同时设置了不同的规则。你可以看到所有你熟悉的人工智能大模型（LM）提供商。事实上，这些提供商并非全部都是大模型开发者，但大多数前沿大模型提供商或开发者都拥有自己的网络爬虫。这是因为通用爬虫的实际覆盖范围其实相当有限——尽管其规模庞大，但互联网本身实在过于广阔。此外，并不存在一种正式机制来确保网站遵守 robots.txt 协议；它本质上只是一种指导性规范。因此，确实可能存在一些不遵守 robots.txt 协议的爬虫。是的，这里就是这种情况。

## 段落 21

**英文**: Then. So a question is how are images handled? So technically common crawler does, it's just like has a URL and gets the raw response. So sometimes the response will be text and sometimes it will be images. I think most of common crawler is sort of biased towards text because that's, but occasionally you get like, you know, other stuff. Of course, you know, there you could develop crawlers that explicitly go after media. Okay. So question is what fraction of common crawlers copyright material? I'm going to talk about copyright later, but I would say that most of it's copyright. And that's a complex topic. So I'll touch on it briefly later. Okay, let's move on.

**中文**: 那么，接下来的问题是：图像如何处理？从技术上讲，常见的网络爬虫只是获取一个URL并接收原始响应。因此，有时响应内容是文本，有时则是图像。我认为大多数常见爬虫在设计上偏向于抓取文本，因为这是其主要目标，但偶尔也会获取其他类型的内容。当然，你也可以专门开发专门抓取媒体资源的爬虫。那么问题来了：常见爬虫所抓取的内容中，有多大比例属于受版权保护的材料？我稍后会专门讨论版权问题，但在此我可以先指出：其中绝大部分内容都受版权保护，而这是一个相当复杂的话题，我将在后面简要提及。好，我们继续往下讲。

## 段落 22

**英文**: So common crawl is big. And I think even on. the first day of lecture I showed you that, if you look at random samples from common crawl, it's really no good. So there's been a lot of attempts to filter common crawl. One of the earliest attempt is called CCNAT. This is from Meta. And the idea is that they wanted a generic procedure that could take a common crawl and return high quality, you know, data sets. And particularly they were interested in the multi-lingual coverage. So they had a bunch of heuristics. So they removed duplication.

**中文**: 因此，Common Crawl 规模庞大。我想甚至在第一堂课上我就向大家展示过：如果从 Common Crawl 中随机抽样，其数据质量实际上非常差。因此，人们已进行了大量尝试来过滤 Common Crawl 数据。其中最早的一项尝试名为 CC-NAT，由 Meta 公司提出。其目标是设计一种通用流程，能够对 Common Crawl 数据进行处理，从而输出高质量的数据集；尤其关注多语言覆盖能力。为此，他们设计了一系列启发式规则，例如去除重复内容。

## 段落 23

**英文**: They ran language identification, which is basically a linear classifier to keep only examples of a target language, whether it be English or German. And then this is sort of the key part is that to filter our quality, they look at documents. that look like Wikipedia under a 5 gram model. So they take Wikipedia text, they train an end gram model, and then they use that to score documents. And the idea is that Wikipedia, as you see, has been used sort of as a surrogate for high quality data. And using that, you can get more things that look high, like high quality, where Wikipedia serves as a surrogate for high quality. And as we discuss, Wikipedia obviously doesn't cover everything. So this is also not going to cover everything. So they train a bunch of bird models at the time. And they show that they outperform only training on Wikipedia.

**中文**: 他们运行了语言识别模型，这本质上是一种线性分类器，用于仅保留目标语言（如英语或德语）的样本。而关键步骤在于：为过滤数据质量，他们借助五元语法模型对类似维基百科风格的文档进行筛选。具体而言，他们以维基百科文本为训练数据，训练一个五元语法模型，再利用该模型对文档进行打分。其基本思路是，维基百科通常被用作高质量数据的代理；通过这种方式，可筛选出更多与维基百科相似、因而被视为高质量的文本——即以维基百科作为高质量数据的代理。但正如我们所讨论的，维基百科显然无法覆盖所有主题，因此该方法同样存在覆盖范围局限。当时，他们训练了多个“鸟”模型（bird models），并证明这些模型的性能优于仅在维基百科数据上训练的模型。

## 段落 24

**英文**: So, and CCNAT is a bit confusing sometimes because it refers to both the tool, which is a function of a filtering function, but also the dataset that. they released from the paper. Okay, so meanwhile, Google was doing some stuff as well. So they released this C4, which stands for Colossal Clean Crawl Corpus. And it's sort of the, I guess, the same inside that you want to take Colossal, you want to leverage this large text somehow. This paper, actually, by Colossal, is more famous for introducing the T5 model, but it actually introduced the C4 dataset, which is a main contribution. It's a long paper. And the observation is that, Comic crawls, as we mentioned earlier, it doesn't have, is most of it's not useful in natural language. So if you, let's say you start with one snapshot, so that's 1. 4 trillion tokens already, they decided to use just heuristics.

**中文**: 因此，CCNAT有时会令人困惑，因为它既指代一种工具（即某种过滤功能），也指代该论文所发布的数据集。好的，与此同时，谷歌也在开展一些工作。他们发布了C4数据集，全称为“巨量干净网络爬取语料库”（Colossal Clean Crawl Corpus）。其命名思路大致相同：强调“巨量”（Colossal），意在以某种方式利用这些海量文本。实际上，这篇由Colossal团队发表的论文更广为人知的是提出了T5模型，但其真正的主要贡献其实是引入了C4数据集。这是一篇篇幅很长的论文。文中指出，如前所述，网络爬取语料（comic crawls）中大部分内容在自然语言处理中并无实用价值。因此，假设你从一个快照开始——仅此一项就已包含1.4万亿个词元——他们最终决定仅采用启发式方法进行处理。

## 段落 25

**英文**: So they keep lines that end in punctuation, remove pages with. fewer than three sentences, remove bad words. You can look, click on this to see the bad words, I'm not going to show that here. They remove brace, which is interesting, which clearly removes a lot of code. I guess Python might be kept. And it's some like boilerplate text. And they only kept English. They got a lot of tokens out of that. So it's kind of interesting. You see that two trade-off here is that, whereas CCNet used a model-based approach to filtering to make it look like Wikipedia, this is entirely rule-based.

**中文**: 因此，他们保留以标点符号结尾的行，删除少于三句话的页面，并剔除不良词汇。您可以点击查看这些不良词汇（我在此不作展示）。他们还移除了花括号——这一点颇为有趣，因为这显然会清除大量代码；我推测Python代码可能得以保留，而一些类似模板的文本则被剔除。此外，他们仅保留英文内容。由此获得了大量词元，因而颇具研究价值。您会发现此处存在两种权衡：CCNet采用基于模型的过滤方法，使其数据集尽可能接近维基百科的风格；而本方法则完全基于规则。

## 段落 26

**英文**: So the advantage here is that there are sentences that don't look like Wikipedia, but nonetheless are well-formed sentences that would end up in C4. On the other hand, there are sentences that might be just very spammy and also well-formed. sentences that might look a fall into C4. So it's kind of interesting that there's this sort of complementary nature. If you use model-based, it's only as good as your ability to curate positive examples at a representative of what you want. And when you want a very broad set of data, it's often can be hard to get that coverage, because that's the whole point. You're trying to get a lot of, you're trying to curate a diverse data set in the first place. They also created a web text like a data set where they took pages from open web text links. So this is the remember open web text. You was open reproduction of web text, which is used to train GPT2.

**中文**: 因此，此处的优势在于：存在一些看似并非来自维基百科、但 nonetheless语法规范的句子，而这些句子最终仍会进入C4数据集。另一方面，也存在一些虽语法规范却极可能属于垃圾信息的句子，这类句子也可能被归入C4。因此，这种互补性颇为有趣。若采用基于模型的方法，则其效果仅取决于你能否收集到具有代表性的正样本——即能准确反映你所需数据特征的样本。而当你需要覆盖极为广泛的数据类型时，往往难以实现充分的覆盖，因为这恰恰是问题的关键所在：你本就旨在获取大量数据，首要目标便是构建一个高度多样化的数据集。此外，他们还构建了一个类似网络文本的数据集，从中提取了开放网络文本链接中的网页内容。此处所指的“开放网络文本”（Open Web Text）是一个开源复现项目，其数据曾被用于训练GPT-2模型。

## 段落 27

**英文**: They looked at links from Reddit posts with gradient 3 karma. Even if they used 12 dumps,. they only get 17 gigabytes of text. Web text was 40. So this suggests it gives you a sense that common crawl is quite incomplete, right? Because you took all of common crawl and you apply the same filter and you got something that was about half as large as web text, which was basically doing its own crawl. But none of us, this was useful for improving a bunch of NLP benchmarks at the time. And if you look at now going back to C4, if you look at what its composition is, you see that there's Wikipedia in there, there's a lot of patterns and news and so on. Okay. All right. So we talked about common crawl in different ways to filter.

**中文**: 他们分析了Reddit上得分为3的帖子所包含的链接。即便使用了12次数据转储，也仅获得了17GB的文本；而网络文本（Web text）则有40GB。这表明Common Crawl的数据覆盖程度相当有限，对吧？因为你已将全部Common Crawl数据应用了相同的过滤条件，结果所得数据量却仅为“网络文本”（其本身即为一次独立爬取）的一半左右。不过，当时这一做法确实有助于提升多项自然语言处理（NLP）基准测试的性能。再回过头来看C4数据集——若考察其构成，你会发现其中包含了维基百科内容、大量模式化文本、新闻等。好的，明白了。因此，我们已从不同角度探讨了Common Crawl及其各类过滤方法。

## 段落 28

**英文**: Now let's talk about more, now we're sort of entering the GPT3 era. There's a bunch of models and data sets, which will. allow us to get into some other ideas here. So GPT3 data set, there's common crawl, which was processed, web text, too, which is essentially the same ideas what they used for GPT2. There's a mysterious set of books, corpora, books one and books two, and Wikipedia. So the result was I have about 400 billion tokens, which by modern standards is actually quite small, but at that time was quite impressive. So the common crawl processing was the training quality classifier to distinguish web text, high quality web data, Wikipedia and books from the rest. So basically the idea of quality classification is that you identify a bunch of positive examples, and then you try to look for more stuff like that in the larger pool. So this is what they. determined to be high quality, and then they wanted to get more of this.

**中文**: 现在我们来进一步探讨，目前我们实际上已步入GPT-3时代。这一时期涌现了大量模型与数据集，使我们得以深入探讨其他相关理念。GPT-3所用的数据集包括Common Crawl（经处理的网络文本）、WebText（其构建思路与GPT-2所用数据集基本一致）、一组来源不明的图书语料（即“Books1”和“Books2”）以及维基百科。最终得到的数据规模约为4000亿个词元——以当今标准衡量其实并不算大，但在当时却颇为令人瞩目。Common Crawl数据的处理过程涉及训练一个质量分类器，用以区分高质量网络文本、维基百科内容及图书语料与其他低质网络文本。质量分类的基本思路是：先确定一批正样本（即高质量文本示例），再在更大规模的数据池中搜寻与之相似的其他文本。上述被判定为高质量的文本即由此确定，而研究人员的目标正是尽可能多地获取此类高质量文本。

## 段落 29

**英文**: So the pile came shortly after. So in particular, eluther AI was this organization that kind of bounced up in reaction to GPT3 and how closed everything was, and they were trying to reproduce open source language models. And this was a largely a kind of decentralized, discord-driven volunteer effort, where everyone was just tossing in a data that they felt were high quality. So they curated 22 high quality domains. So you have some common crawl, web text, stack of training, Wikipedia archive, and so on. Here's some more statistics about the general weight. So this is still, if you look at it quite diverse, and it's interesting to think. about technically the web common crawl could have most of this stuff, assuming that you can crawl. But often, you'll see that people will go in sort of special case different types. For example, they want to get more Wikipedia's handle differently, or like mathematics is handled differently.

**中文**: 因此，该数据集很快便应运而生。具体而言，EleutherAI 是一家在 GPT-3 发布后、针对当时整个生态高度封闭的局面而迅速兴起的组织，其目标是复现开源语言模型。这主要是一项去中心化、以 Discord 为协作平台的志愿者项目，参与者各自贡献自认为高质量的数据。他们精心筛选出 22 个高质量数据领域，包括 Common Crawl 网页数据、WebText、Stack Exchange 训练数据、维基百科存档等。以下是一些关于整体数据权重的统计信息。从整体来看，该数据集仍具有相当高的多样性，值得深入思考：从技术角度而言，若具备足够的网络爬取能力，Common Crawl 网页数据理论上已涵盖其中大部分内容；但实践中，人们往往倾向于采用特殊处理方式，针对不同数据类型分别处理——例如，对维基百科数据采取专门的获取策略，或对数学类内容进行差异化处理。

## 段落 30

**英文**: So if you have prior knowledge about what's good data, then you can just go out and use it directly. Okay, so this was actually more data than GPT3 was trained on. So they also noticed that work was better than what. So they used this different tool just text to convert it. So there's a PubMed central, which are a lot of papers, which is nice. So there's a mandate that says NIH funded work has to be, the papers have to be open access. I think in AI. we're sort of taking it for granted that things show up on archive, but that's not true for many other fields. There's archive, of course, and then there's N-RON emails, actually, which is old data set, which came out of the subpoena after the whole N-RON ship sink. And why is this in there? Well, it turns out that there's, it's really hard to come by email data sets, as you might imagine, because emails are private.

**中文**: 因此，如果你事先了解哪些是优质数据，就可以直接获取并使用。好的，实际上这部分数据量超过了GPT-3的训练数据量。他们还发现，该工作效果优于其他同类研究。因此，他们采用了另一种工具——纯文本转换工具来处理数据。其中包含PubMed Central（美国国家医学图书馆中央文献库），其中收录了大量论文，这一点非常有益。美国国立卫生研究院（NIH）有明确规定：凡由其资助的研究成果，相关论文必须以开放获取形式发布。在人工智能领域，我们往往理所当然地认为各类成果都会出现在预印本平台（如arXiv）上，但这一情况在许多其他学科领域并不成立。当然，除了arXiv之外，还有N-RON邮件数据集——这是一份较早的数据集，源于“N-RON号”事件沉船调查期间发出的传票。那么，为何该邮件数据集会被纳入？事实上，正如你所能想象的那样，电子邮件数据集极为稀缺，原因在于电子邮件具有高度私密性。

## 段落 31

**英文**: So this is really the best thing we have. So you could, might imagine there might be some bias in terms of the email knowledge of this language model that's trained on that, but that's something to think about. Okay, so just diving into some of the the different sources here. So Project Gutenberg was started a long time ago. It's mostly English. books. Now there's about 75,000 books. And the main biggest draw of this is that these are books that have copyright clearance, which mostly means that they're in the public domain, 75, I think 75 years have passed since it was published. So now anyone can use it freely. But there's, I think some books in there that are technically not in the public domain, but it's okay to use.

**中文**: 因此，这确实是我们目前最好的资源。你或许会想到，由于该语言模型是基于此类电子邮件数据训练的，因此在电子邮件相关知识方面可能存在某些偏差，这一点值得我们思考。好的，接下来我们深入探讨一下此处涉及的几种不同数据来源。古腾堡计划（Project Gutenberg）早在很久以前就已启动，其内容主要为英文书籍，目前约有7.5万册。该计划最大的优势在于，这些书籍均已获得版权许可，主要意味着它们已进入公有领域——通常指作品出版已逾75年。因此，如今任何人都可自由使用这些书籍。不过，其中可能也包含一些在技术上尚未进入公有领域的书籍，但使用它们仍是被允许的。

## 段落 32

**英文**: There's a data set of PG19, which is books from Project Gutenberg. And this was a paper that was trying to benchmark, you know, language models on long context. So the, you know, appealing thing of books is that you have really long contact compared to news articles or even papers. Yeah. Is it possible that the media reprise of XAI is because they have access to. mining the tweets, data for training the models. So it's like the other AI models can, which means that like they have access to better understanding what's the spoken human language for. And therefore in the long one, it's really Google and X are the only big companies with access to like tons of human generated data with like nest language. Yeah. So, so the general question is, what the, the narrow question is, you know, does X have an advantage because they have access to tweets.

**中文**: PG19 是一个源自古腾堡计划（Project Gutenberg）的图书数据集。该论文旨在对语言模型在长上下文任务上的性能进行基准测试。图书之所以具有吸引力，是因为其文本长度远超新闻文章甚至学术论文。  
那么，XAI（X公司的人工智能）受到媒体广泛关注，是否可能源于其能够获取并挖掘推文数据用于模型训练？换言之，其他AI模型并不具备这一优势，而XAI则能借此更深入地理解人类口语表达。因此，长远来看，谷歌和X公司确实是仅有的两家拥有海量人类生成、自然语言数据的大型企业。  
综上，核心问题可归结为：X公司是否因其对推文数据的访问权限而具备独特优势？

## 段落 33

**英文**: And for example, any of these big platforms, Google has a YouTube, a meta has, you know, Facebook. So there are, you know, restrictions on what data companies can use even if they have the data. So it's not that literally the, you know, Google train on all of its, like your Gmail or something. I don't think that's the case. That said, it is true that companies will have distinct advantages and access to certain types of data that might be, you know, a public. So I think public doesn't mean that anyone can train on it. For example, YouTube is, you know, public, but Google has a special access to it. So I think the broader question is, will companies that have access to special data, you know, win essentially? And by default, the answer is yes, because I think that, you know, data is this sort of the name of a game. Now interestingly, you know, obviously Anthropic has a really good model and they don't have like a particular secret source that I don't know of. So it is not everything, but over time, I think, this is my opinion is that,.

**中文**: 例如，这些大型平台中的任何一家——谷歌拥有YouTube，Meta拥有Facebook。因此，即便企业掌握了某些数据，其使用范围也存在明确限制。这并非意味着谷歌会直接利用所有用户数据（比如你的Gmail内容）来训练模型，我认为事实并非如此。话虽如此，企业确实拥有独特优势，能够获取某些特定类型的数据，而这些数据虽属公开范畴，却未必向所有人开放训练权限。例如，YouTube内容虽属公开，但谷歌对其享有特殊访问权限。因此，更深层次的问题在于：掌握特殊数据渠道的企业是否将占据绝对优势？默认而言，答案是肯定的，因为数据本质上就是这场竞争的核心要素。有趣的是，Anthropic显然推出了极为出色的模型，而据我所知，他们并未掌握某种不为人知的独家数据源。因此，数据并非决定一切的唯一因素；但长远来看，我个人认为……

## 段落 34

**英文**: I think, you know, you'll see perhaps more differentiation and more, you know, specialization and yes, companies leverage the resources that they have. Okay, so that's Project Gutenberg. Books 3 was this project that produced a lot of books from this shadow library. It contains books notably from famous authors and since then has been taken down due to copyright infringement. So this was part of the pile. And so just a note about shadow libraries. These are, there's a bunch of different, you know, libraries that basically disregard copyright and bypasses paywalls. This is basically, you know, illegal and there's been lots of take-out orders and lawsuits and so on, but usually these controls are circumvented because they just put them on, you know, servers in. different countries. And, you know, the proponents say that it makes free what's really should be free, but, you know, obviously the law thinks quite differently.

**中文**: 我认为，您会看到更多的差异化和专业化，是的，企业会充分利用自身所拥有的资源。好的，以上就是古腾堡计划的情况。《图书3号》（Books 3）是另一项项目，它从这座“影子图书馆”中大量生成图书，其中 notably 包含诸多著名作家的作品；但此后因侵犯版权而被下架。因此，它也属于该数据集的一部分。顺便提一下“影子图书馆”：这类图书馆有多种不同形式，其共同特点是无视版权、绕过付费墙。这本质上属于违法行为，已引发大量下架指令与诉讼等法律行动；但此类管控通常被规避，因为运营者往往将网站部署在不同国家的服务器上。支持者辩称，此举旨在使本应免费的内容真正实现免费，但显然，法律对此持截然不同的立场。

## 段落 35

**英文**: In particular, Libgen has 4 million, you know, books, which is a lot of books compared to Project Gutenberg, which has only 75,000 books. And it has been through revealed that meta-trained models on Libgen, for example, and there's a big, you know, lawsuit about it. So, moving on, Stack Exchange is a collection of sites. Most prominently it's Stack Overflow, which it started with, but has grown to other areas like math and literature. There's some reputation and badges to incentivize participation. All of you probably have used Stack Overflow, so I don't need that. Well, just for fun. I like always looking at random. examples. Okay.

**中文**: 尤其是，Libgen 拥有约 400 万册图书，相比之下，古腾堡计划（Project Gutenberg）仅有 7.5 万册图书，数量悬殊。此外，已有披露显示，某些模型曾以 Libgen 数据集进行元训练，由此还引发了一场备受关注的诉讼。接下来，Stack Exchange 是一系列网站的集合，其中最著名的是其创始站点 Stack Overflow，但如今已扩展至数学、文学等其他领域。该平台设有声望值和徽章机制，以激励用户参与。在座各位很可能都使用过 Stack Overflow，因此我无需赘述。嗯，纯粹出于趣味，我总喜欢随机浏览一些示例。好的。

## 段落 36

**英文**: So, here's some, this is a page that basically gives you random Stack Exchange. So, I don't know if these are any good, but here's a question and here's some, some answers. Okay, so I guess this is pretty familiar stuff. So, one thing to note is that if you look at these types of, this data, it's really kind of like looks like a QA dataset, right? So, which is kind of what you expect in, for instruction following capabilities and real applications. So, I guess the sort of the lesson here is that, you know, by training on web data or a large in pre-training, a lot of it is just documents, which don't look anything like what you would a user would type into a chatbot, but there are subsets of the pre-training data that look. remarkably similar to what a user would type, coupled with the response. And this is why, the lines are a little bit blurry between what is pre-training and what's post-training. The cool thing about Stack Exchange is that there's also metadata, like comments, and votes, which can be used to filter, and the data dumps are provided. Although, I think, I think right now, this is if you use it non-commercial, it's fine, but if you are a commercial entity, then you have to pay for a license. Okay, so in GitHub, which everyone who knows about, and this is a, I think the primary means in which you get code for language model training.

**中文**: 因此，这里有一些示例——这是一个基本可为您提供随机 Stack Exchange 页面的页面。我不确定这些问题和答案质量如何，但这里有一个问题以及一些回答。好的，我想这些内容大家应该相当熟悉了。需要注意的一点是，若观察此类数据，其形态实际上非常类似于问答（QA）数据集，对吧？而这恰恰正是我们在评估指令遵循能力及实际应用场景时所期望的数据形式。因此，此处的关键启示在于：通过在网页数据或大规模预训练数据上进行训练，其中大部分数据本质上只是普通文档，与用户向聊天机器人输入的内容形式迥异；但预训练数据中确实存在某些子集，其形态与用户输入及其对应回复惊人地相似。正因如此，预训练与后训练之间的界限变得有些模糊。Stack Exchange 的一个亮点在于它还提供了评论、投票等元数据，可用于数据筛选，且官方提供数据转储包（data dumps）。不过，据我所知，目前若用于非商业用途，使用 Stack Exchange 数据没有问题；但若为商业实体，则需购买相应授权许可。好的，接下来是 GitHub——想必大家都很熟悉——我认为这是获取语言模型训练代码的主要途径。

## 段落 37

**英文**: So, this is help and code is generally helpful for programming, of course, but it has also been,. I think, thought to be helpful for reasoning and other capabilities. Although, I don't know what if there's a paper that makes that more rigorous. So, here's a random GitHub. Okay, maybe this doesn't work. Never mind. It used to work if you were random GitHub repository. And the reason I'm doing this is that I think the GitHub repos that you visit and the Wikipedia pages you visit are distinctly not a representative sample. And by sampling randomly, it gives you a sense of what's actually in this data set. So, when you look at numbers, like, who has GitHub has, you know, however many millions of repositories, not all repositories create equal, a random repo might disappoint.

**中文**: 因此，这类帮助和代码对编程通常很有帮助，但人们也认为它对推理及其他能力同样有益。尽管如此，我并不清楚是否已有论文对此进行了更严谨的论证。那么，我们来随机访问一个GitHub仓库——好吧，也许这行不通，算了。以前当你随机访问GitHub仓库时，这种方法是有效的。我之所以这么做，是因为我认为你实际访问的GitHub仓库和维基百科页面显然并非具有代表性的样本；而通过随机抽样，你才能真正了解该数据集的实际构成。例如，当我们看到“GitHub拥有数以百万计的仓库”这类数字时，必须意识到并非所有仓库都同等重要或有价值，随机选取的一个仓库可能令人失望。

## 段落 38

**英文**: Okay, so there's 28 million public repositories. And one thing that's interesting is that,. you know, GitHub, what is a repository? It's a directory. And some of it's cold, not some of it's not code. There's also notions of issues and commit history and all this other stuff. And there's also a lot of duplicates. So, in order to take GitHub, which is all this raw, you know, data and make it like trainable tokens, there's actually a lot of work that has to go into think about how you want to best, you know, do that. So, GitHub Archive is this snapshot of all the GitHub events that have happened and you can access it using Google, you know, BigQuery. So, the stack is, you know, a project that fortunately produced this open source version of code based on GitHub. So, they took all the repository names from GitHub Archive and GitClone 137.

**中文**: 好的，目前共有2800万个公开代码仓库。一个有趣的现象是：大家都知道GitHub上的“仓库”（repository）本质上就是一个目录；其中一部分内容是冷数据，还有一部分甚至根本不是代码。此外，仓库还包含议题（issues）、提交历史（commit history）等其他各类信息，而且存在大量重复内容。因此，要将GitHub上这些原始数据转化为可用于模型训练的标记（tokens），实际上需要投入大量工作来思考如何最优地完成这一过程。GitHub Archive 是对所有GitHub事件的一个快照式存档，可通过谷歌的BigQuery进行访问。而“Stack”是一个项目，幸运地基于GitHub开源发布了其代码版本。该项目从GitHub Archive中提取了全部仓库名称，并执行了Git克隆操作，共涉及137个仓库。

## 段落 39

**英文**: repositories, commit, kept only permissively licensed ones, and remove duplicates and the result was more 3. 1 terabytes of code. So, nice thing about code is that often, but not always, the licenses made more clear compared to webpages where the licenses is almost never made clear. So, if you think about this, this is sort of, you see that there is the live service. There's a website GitHub that you go to every day. And then there's the snapshot, which gives you sort of raw dub, and then there's the processing that happens that turns it into an actual trainable data set. So, when someone comes to you and says, I train on GitHub, then you'll have to ask them, you know, what exactly does that mean? What was the processing steps that were taken?. Okay. So, that was the pile, although I guess I took a little bit of liberty and digressed into the different components of a pile. So, now moving on, so now in 2021, so deep mind also came on to the scene.

**中文**: 代码仓库、提交记录，仅保留采用宽松许可证的代码，并剔除重复内容，最终得到超过3.1太字节的代码。代码的一个优点在于，其许可证信息通常（但并非总是）比网页更明确；而网页上的许可证信息几乎从不明确。因此，若你仔细思考这一点，就会发现：一方面存在一个实时运行的服务，即你每天访问的GitHub网站；另一方面则存在一个快照，提供原始的“裸”数据；此外，还需经过一系列处理步骤，才能将这些数据转化为真正可用于训练的数据集。所以，当有人对你说“我在GitHub上进行训练”时，你就必须追问：这具体意味着什么？其间采取了哪些处理步骤？好了，以上就是关于“The Pile”的介绍——虽然我可能稍作发挥，偏离主题，详细探讨了该数据集的不同组成部分。接下来，我们进入2021年，DeepMind也由此登上舞台。

## 段落 40

**英文**: The first large language model they trained was Gopher on this massive text data set, which was, the Gopher model actually was not very, very good, but the data set, the paper does a rich object describing the data set. So, massive text contains massive web, which I'll talk about a little bit later. There's C4, and then books news GitHub, we could be in as no details about how there's were processed. And as I said mentioned before, this is obviously, it's not reproducible, it's fine. You train on GitHub, but you know, how exactly was the data processed? So, massive web,. you kept English, and here again, like CCNet, they use quality filters that were based on manual rules. And they had rules, which you'll implement in your assignment, that look at things like, you know, 80% of the words has to contain at least one alphabetic character. They also use Google Safe Search for toxicity filter in. And I think in those days, one of the main arguments for using manual rules is that you didn't want to be biased against the model, because models, the only models that they can run is very weak models, and weak models don't really understand the page, and they're just going to have, you know, probably pretty awful bias. And also, there is a consideration that this type of filtering can, you know, filter out kind of marginalize data for.

**中文**: 他们训练的第一个大型语言模型是Gopher，所用的是这个海量文本数据集。实际上，Gopher模型本身表现并不十分出色，但该论文对数据集本身作了详尽细致的描述。该海量文本数据集包含“海量网络文本”（Massive Web），我稍后会对此略作介绍；此外还包括C4、书籍、新闻、GitHub等数据源。至于这些数据源的具体处理方式，文中并未提供细节。如前所述，这种做法显然不可复现，但这并无大碍——例如你在GitHub数据上进行训练，但具体的数据处理流程究竟如何？在“海量网络文本”部分，他们仅保留了英文内容，并再次采用类似CCNet的质量过滤方法，即基于人工制定的规则进行筛选。你们在作业中将要实现的正是这类规则，例如要求文本中至少80%的词须包含一个字母字符。此外，他们还利用谷歌安全搜索（Google SafeSearch）作为毒性内容过滤器。我认为，当时采用人工规则的主要理由之一，是避免对模型引入偏差：彼时所能运行的模型非常弱小，而弱小模型根本无法真正理解网页内容，若交由其进行过滤，反而可能产生相当严重的偏差。此外还需考虑，此类过滤方式可能会剔除某些边缘化群体的相关数据。

## 段落 41

**英文**: marginalized groups that didn't look exactly like Wikipedia. But as you see later, this sort of has flipped, and now everyone's doing model based filtering. Okay, so there are days that was 10 terabytes of text, which is, I guess, you know, maybe like, let's say, five, four or five trillion tokens, just the last amount. Although GoFore was only trained on 300 billion, which is not very many tokens, I think that's the same, maybe around the same number of GP3. So in 2022, we have Lama. So the dataset for Lama was common crawl process with CC net. And here in the classifier here, there's a subtlety here. Remember, GP3 was classified whether it looked like Wikipedia page or not. Lama was trained on classifier, which predicted,. do you look like a page that was referenced out of Wikipedia or not? And I guess the idea is that Wikipedia will cite high quality pages, and most of those pages might not look like a Wikipedia article, but nonetheless, our high quality.

**中文**: 那些与维基百科外观不完全一致的边缘化群体。但如您后文所见，这种情况已发生逆转，如今所有人都在采用基于模型的过滤方法。好的，当时每天有10太字节（TB）的文本数据，换算下来大约是四万亿至五万亿个词元（token），仅指最新一批数据量。尽管GoFore仅在3000亿个词元上训练，词元数量其实并不多，我估计这与GP3的训练词元量大致相当。因此，2022年我们推出了Lama模型。Lama所用的数据集是经CC Net处理后的Common Crawl语料。此处分类器的设计存在一个细微差别：需注意，GP3的分类器判断的是某网页是否“看起来像维基百科页面”；而Lama所用的分类器则预测某网页是否“被维基百科引用过”。其基本思路在于：维基百科倾向于引用高质量网页，而这些被引用的网页虽未必形似维基百科文章，却仍属高质量内容。

## 段落 42

**英文**: So again, the kind of this link structure, which we saw in the GP2, WebText is kind of showing up here. They also included C4. Why not they use GitHub. They kept permissive licenses, filtered based on some manual rules. Wikipedia, Project Gutenberg, and Books 3, which got them in a lot of trouble. And archive, stack exchange, so they got 1. 2 trillion tokens. So they didn't release the dataset, but together, reproduce this dataset in something called Repgema, which now you can go and you have the data processing code and the data, which you can. take out. So this was a reproduction.

**中文**: 因此，再次强调，这种链接结构（我们在GP2中见过）在WebText中也有所体现。他们还纳入了C4数据集。那么，为何未使用GitHub？他们保留了宽松许可协议，并依据一些人工制定的规则进行了筛选。此外还包含了维基百科、古腾堡计划和Books3（这给他们带来了诸多麻烦），以及互联网档案馆（Archive）和Stack Exchange，最终共获得1.2万亿个词元。他们并未公开发布该数据集，但后来通过一个名为Repgema的项目实现了对该数据集的复现——如今，你可直接获取其数据处理代码及相应数据，并自行提取使用。这便是一次复现工作。

## 段落 43

**英文**: So this was clearly not optimal, and Cerebus did further duplication and ended up with a 627 billion primary subset. There's also Repgema V2, which is a little bit confusing because this is something else. This is essentially taking common crawl snapshots and producing 30 trillion tokens with all sorts of different quality signals. So this is a resource for doing research on how to filter based on the quality signals that are computed. Okay, so that was Lama, and then the refined web was another paper, and here are the thesises. Well, remember how we saw the pile? There was web data and there was all this other stuff. And their point was like, well, maybe if we do a good enough. job filtering the web data, that's all you need because technically, the internet has everything, in some sense. If you think about it, if you can access it via a computer and it's a connect on the internet, then maybe that's good enough. And so the refined web, let's see if we're going to want to look at some examples here.

**中文**: 因此，这显然并非最优方案，而Cerebus进一步进行了重复处理，最终得到了一个包含6270亿词元的主子集。此外还有Repgema V2，它略显令人困惑，因为这是另一套完全不同的方案：该方案本质上是基于Common Crawl快照构建而成，生成了总计30万亿词元的数据集，并附带各类不同质量指标信号。因此，该资源主要用于研究如何依据所计算出的质量信号进行数据过滤。好的，以上是Lama项目的情况；随后是《Refined Web》（精炼网络）这篇论文，其核心论点如下：还记得我们之前看到的“The Pile”（语料堆）吗？其中既包含网络数据，也包含大量其他类型的数据。而该论文的观点是：如果我们对网络数据实施足够高质量的过滤，那么仅靠这些数据就已足够——因为从技术上讲，互联网在某种意义上囊括了所有内容。试想一下，只要能通过计算机访问、且连通于互联网的内容，或许就已经足够好了。接下来，让我们看看Refined Web的具体示例。

## 段落 44

**英文**: The data is at a hugging phase, and it kind of looks like, you know, this. Okay, the resolution is probably not large enough to, okay, anyway, I'll scrap that. They use Traflatorra for extracting content because as we noted, Traflatorra is better than just using the web files that CommonCrawl provides. They use GoFourRules, and they made a point of we're going to avoid ML-based filtering to avoid biases. And then they did some fuzzy duplication. Okay, so they had a five trillion token dataset, which is, you know, quite large, but they only released 600 billion of it. A fine web from HulkingFace was started as a replication of refined web, but they tried to improve it. So they used all the CommonCrawl dumps, I think, at the time. They did some filtering. Again, this is still using manual rules, no model-based filtering.

**中文**: 该数据正处于“拥抱阶段”，看起来大致如此。好吧，分辨率可能不够高，算了，我就不提这个了。他们使用Traflatorra来提取内容，因为如我们之前所指出的，Traflatorra比直接使用CommonCrawl提供的网页文件效果更好。他们采用GoFourRules，并特别强调将避免使用基于机器学习的过滤方法，以规避偏见。随后还进行了模糊去重处理。最终，他们构建了一个包含五万亿词元的数据集——规模相当庞大，但仅公开发布了其中的六千亿词元。HulkingFace推出的FineWeb最初旨在复现RefinedWeb，但尝试对其加以改进：他们当时使用了全部CommonCrawl数据转储，并实施了一些过滤；同样，这些过滤仍完全依赖人工规则，未引入任何基于模型的过滤方法。

## 段落 45

**英文**: And they did some duplication, and did some, you know, basic anonymization. So they got 15 trillion tokens out of this. So this is still, I think, a really nice dataset because it, you know, dealing with CommonCrawl is going to be a pain, but this is sort of a, I would consider to find web as a lightly filtered dataset that you can further do model-based filtering on. Okay, so jump you ahead. So AI2 put out, has a series of models called OMO. Their initial model was trained on the DOMA dataset. And this is a composition. So we have CommonCrawl, we have the stack, which we talked about, which has code, C4, which, you know, you know, Reddit. AI2 has a semantic scholar, so I think this is derived from that, Project Cougainberg and Wikipedia, and you know about. So the Reddit comes from this project, which, but they include sort of the submissions and the comments separately, so you don't have this sweatshructure.

**中文**: 他们进行了一些重复数据删除，并做了一些基本的匿名化处理，最终从中获得了15万亿个词元。我认为这仍是一个非常不错的数据集，因为虽然直接处理CommonCrawl数据会很麻烦，但该数据集可视为一种轻度过滤后的网络数据，后续还可进一步采用基于模型的方法进行过滤。好的，我们继续往下看。AI2发布了一系列名为OMO的模型，其初始模型即在DOMA数据集上训练而成。该数据集由多个来源组合构成：包括CommonCrawl、我们之前提到过的The Stack（含代码数据）、C4（包含Reddit等数据）；此外，AI2拥有Semantic Scholar（语义学者）数据库，因此这部分数据可能源自该库；还有Project Corgi（科吉项目）和Wikipedia（维基百科）等。其中Reddit数据来自该项目，但他们将帖子（submissions）和评论（comments）分别单独收录，因而不存在嵌套结构。

## 段落 46

**英文**: I think this project, I don't know if it's so, I guess it no longer exists anymore. So I think, until around 2023, all these sites, like Stack Exchange and Reddit, realize, wait, people are just taking our data and training models. and making money off of it. So I think that sort of came to a stop. So we have 40 million academic papers from Semantic Scholar, which crawls a bunch of different, you know, sites, and then we have our usual suspects. So the CommonCrawl processing, which is fairly, I think, I would say, standard. So they use language identification to keep only the English part, quality filtering. Again, in DOMA, they, for training initial model, they avoid a model-based filtering. And then toxicity filtering, they hear you, they use a classifier, and then they do duplication. So three trillion tokens came out of that.

**中文**: 我认为这个项目——我不确定是否如此，但猜测它已不复存在。因此，我认为，截至2023年左右，所有这些网站（如Stack Exchange和Reddit）都意识到：人们正直接抓取我们的数据来训练模型，并借此牟利。因此，这类数据获取行为大概就此停止了。目前，我们拥有来自Semantic Scholar的4000万篇学术论文；Semantic Scholar会爬取大量不同来源的网站。此外，我们还有惯常使用的数据源，例如CommonCrawl数据处理——这一过程相对标准：首先通过语言识别技术仅保留英文内容，再进行质量过滤；在DOMA中，为训练初始模型，他们避免采用基于模型的过滤方法；接着是毒性内容过滤——他们听取意见，使用分类器进行过滤；最后执行去重处理。最终，该流程共产出三万亿个词元。

## 段落 47

**英文**: And then in the same year, so this was last year, so there's a paper, a data comp, which was a collaboration from multiple different organizations. Here,. what they wanted to do is foremost, define essentially a competition for creating datasets. And so they wanted to set up basic infrastructure. So they define a standard dataset, which you can essentially try out different data processing algorithms. So the process CommonCrawl, all the dumps to produce DCM pool, which has 242 trillion tokens. So that's a lot of tokens. But as you know, it's a CommonCrawl is not the highest quality by on average. So that's going to get filtered down quite a bit. They had a particular recipe for filtering down that dataset, which is called DCM pool, into DCM baseline.

**中文**: 同年（即去年），有一篇论文——数据竞赛（DataComp），由多家不同机构合作完成。其首要目标是设立一项旨在构建数据集的竞赛，并为此搭建基础架构。他们定义了一种标准数据集，供研究人员尝试不同的数据处理算法。该数据集的处理流程包括对CommonCrawl全部数据转储进行处理，生成DCM Pool，共含242万亿个词元（tokens），规模极为庞大。但众所周知，CommonCrawl数据的整体质量并非最高，因此需大幅过滤。他们采用特定的过滤方案，将DCM Pool精炼为DCM Baseline。

## 段落 48

**英文**: And here they were very aggressive using a quality filter. So this is what it looks like. They do some rule-based filtering,. basic stuff. And then the main thing that's interesting is that they took this fastest filter that filtered DCM pool into DCM baseline. So they only kept, I guess, 1. 4% of the total dataset. Okay, so what do they do for this model-based filtering? So again, when quality filtering, you define your positive examples, negative examples, and trainer classifiers. So the positive examples come from two sources. There's this open Hermes dataset.

**中文**: 而在此处，他们采用了非常激进的质量筛选策略。效果如下图所示：他们首先进行了一些基于规则的过滤，属于基础性操作；随后，最值得关注的是，他们采用了速度最快的筛选器，将DCM数据池筛选为DCM基线数据集，最终仅保留了全部数据集约1.4%的数据。那么，这种基于模型的筛选具体是如何操作的呢？同样，在质量筛选过程中，需明确定义正样本、负样本，并训练分类器。其中，正样本来自两个渠道：其一是开放的Hermes数据集。

## 段落 49

**英文**: So this is mostly GPT-4 generating instruction data. So this is kind of interesting. They're using actually instruction data to curate pre-tune data. So they're not explicitly training on instruction data, but they're looking for data that looks like instruction data. Okay, and then E5, which is basically the. subreddit called E5, ask me like I'm five. And this is what I guess the dataset look like. Okay, what's the point of wasting the first two plays with a rush? Okay, so these are sort of like questions you might ask to chat about, for example. Negative examples are just sampled from refined web, which is not low quality data, but it's not as curated as these other two sources. Okay, so the result is that they took DCM baseline, which is 240 trillion tokens and reduced it to 3.

**中文**: 因此，这主要是由GPT-4生成的指令数据。这一点颇为有趣：他们实际上利用指令数据来筛选预训练数据。换言之，他们并未显式地在指令数据上进行训练，而是专门寻找那些具有指令数据特征的数据。好的。接着是E5，即一个名为“E5”的子论坛，其宗旨是“用五岁孩童也能听懂的方式向我提问”。我想，这就是该数据集的样貌。例如：“为何前两回合就贸然强攻？纯属浪费？”——这类问题大致相当于人们日常聊天时可能提出的疑问。而负样本则直接从Refined Web中随机抽取；该数据源虽非低质数据，但相比前述两种来源，其筛选程度较低。最终结果是：他们以DCM基线模型（参数量达240万亿）为起点，将其缩减至3。

## 段落 50

**英文**: 8 trillion tokens, which is still a good sizable chunk. So then they trained a fast sex classifier on these and run it on all of DCM pool. And here's one of the results tables. So the benchmarks here core includes a bunch of standard language modeling benchmarks,. like Hellaswag and so on. And they show that using this classifier, they actually outperform the refined web by 3% and a bunch of other things by 1 or 2%. So this is the procedure they use to create the DCM baseline, which then you train a pretty reasonable model from there. It is worth noting that after this happened, the second OMO model, if you remember, they started training on DCM baseline as well. So I think this era of we're going to be on bias, then try to not use model to bias, I think has kind of largely gone away because I think people realize that, well, if you use models in the loop, you can just like do a much better job of getting high quality data and at least for increasing benchmark scores. Okay, so the final pre-training data.

**中文**: 8万亿个词元，这仍然是相当可观的数量。随后，他们基于这些数据训练了一个快速的性别分类器，并将其应用于整个DCM数据池。以下是其中一张结果表格。此处的基准测试核心包含一系列标准的语言建模基准测试，例如HellaSwag等。结果显示，使用该分类器后，其性能在精炼网络（Refined Web）数据集上高出3%，在其他多项指标上也高出1%或2%。这便是他们构建DCM基线所采用的流程，后续即可在此基线基础上训练出一个性能相当不错的模型。值得注意的是，在此之后发布的第二代OMO模型（如您所记得的）同样开始以DCM基线作为训练起点。因此，我认为那种“我们先关注偏差问题，再设法避免模型引入偏差”的时代已基本结束，因为人们逐渐意识到：若将模型纳入数据筛选闭环，便能更高效地获取高质量数据，至少在提升基准测试分数方面效果显著。好，接下来是最终的预训练数据。

## 段落 51

**英文**: that I'll talk about is Neymotron CC. So this came out of Nvidia, which has been doing some work on training the Neymotron models, although more recently they've been doing post-training and data curation. So there are many thesis that DCL on great data, the baseline is great data set, but it filters very aggressively. Remember it filtered all the way from 240 trillion tokens to 3. 8 trillion tokens. And if you want to train on more, you know, train larger models for longer, you need more tokens because this aggressive filtering 3. 8 trillion isn't really enough to sustain, let's say, you know, like a 400 billion model training run. So the first thing they interesting, they realized is that they did ablations for HTML to text, but not just based on the quality,. but on how many tokens were left. So they're really trying to get not throw away tokens.

**中文**: 我将要介绍的是Neymotron CC。该数据集由英伟达（NVIDIA）推出，该公司此前一直在开展Neymotron模型的训练工作，而近期则更多聚焦于训练后优化与数据整理。目前存在诸多观点认为，DCL（数据质量控制）的关键在于优质数据——其基准即为高质量数据集，但该数据集的过滤策略极为激进：原始数据量高达240万亿词元，最终仅保留3.8万亿词元。若需开展更大规模模型的更长时间训练，则必须拥有更多词元；因为如此激进的过滤所得到的3.8万亿词元，实际上不足以支撑例如4000亿参数模型的完整训练过程。因此，他们首先发现的一个有趣现象是：在进行HTML转文本的消融实验时，不仅依据文本质量，更着重考察了各方案所保留的词元数量——其核心目标实为尽可能避免词元的浪费。

## 段落 52

**英文**: And it turned out that just text rather than Traflotura would actually keep more tokens. So they went with just text. And then they used a bunch of different techniques to do quality filtering. They prompted their gigantic Neymotron model to essentially score documents based on educational value to fill it into a faster model and use that to train. So this is a filter based on, you know, what a language model thinks is educational value. And they also use the DCLM classifier. There's a sort of an interesting way that they are on-souball. They basically ran all these classifiers and look at the bucketed their scores and then from each bucket they sampled a bunch of, you know,. theirs. So it's not just taking the top because I think they were trying to make sure they have good coverage over different experts kind of opinion on the notion of quality.

**中文**: 结果发现，仅使用纯文本而非Traflotura实际上能保留更多token，因此他们最终选择了纯文本。随后，他们采用多种不同技术进行质量过滤：首先，利用其庞大的Neymotron模型为文档的教育价值打分，并将这些评分结果输入一个更快速的模型中用于训练。这种过滤方式本质上依赖于语言模型对“教育价值”的判断。此外，他们还采用了DCLM分类器。值得一提的是，他们在处理过程中采取了一种颇具巧思的方法——即先运行所有这些分类器，将所得分数按区间分桶，再从每个分数桶中分别抽取若干样本。这样做的目的并非简单选取最高分样本，而是为了确保对“质量”这一概念的不同专家观点均能获得良好覆盖。

## 段落 53

**英文**: They also did this thing, which is interesting. They used a language model to not just filter, but also rephrase datasets. So for high quality datasets, sorry, this is backwards. So for low quality datasets, they basically use a language model to rewrite it into something that looks higher quality. So obviously there could be mistakes there, but, you know, in the grand scheme of things, maybe, you know, it's no worse than training on low quality internet data. And for high quality datasets, they use the language model to generate task, things that look like tasks. So you take a Wikipedia article, you ask a language model to create essentially input out prepares where the input is might be a question, outputs an answer, or the input might be, you know, summarizes document and outputs a summary, or the input is extract the key information and outputs key information. So this is again trying to get at the idea of, well, eventually an instruction at an instruction training time we want to be able to, you know, follow instruction. So we might as well start get a head start on this. So they got 6.

**中文**: 他们还做了另一件有趣的事：不仅用语言模型对数据集进行筛选，还对其进行改写。具体而言，对于低质量的数据集，他们利用语言模型将其重写为看似更高质量的形式——当然，这一过程难免出错；但总体来看，其效果或许并不比直接在低质量的网络数据上训练更差。而对于高质量的数据集，他们则利用语言模型生成类似任务形式的数据：例如，以一篇维基百科文章为输入，让语言模型生成形如“输入—输出”对的任务样本——输入可以是一个问题，输出是对应答案；输入可以是“概括该文档”，输出是生成的摘要；输入也可以是“提取关键信息”，输出则是提取出的关键信息。这种做法再次体现了其核心思路：最终在指令微调阶段，模型需要具备遵循指令的能力，因此不妨尽早着手准备。最终，他们共获得了6个这样的数据集。

## 段落 54

**英文**: 3 trillion tokens out of that, which is more than three trillion tokens, almost double, which is, I guess, pretty good because, I mean, all of this is coming from common crawl, but they were able to essentially double the, maybe not quite double,. but almost double the size. You know, for reference, you know, a lot of three is trained on 15 trillion, one three is trained on 36 trillion, which includes, I think, multimodal data. So, you know, 6. 3 trillion at this point is not like enormous, but for open, you know, source models with data sets, it's, you know, pretty decent. Like most of us, 6. 3 trillion is more than enough for training, even to do one epoch. This table shows that basically on average, they show that their NimoTron CC data is better than the DCL-LIM data, which has been shown to be better than fine web, at least on benchmarks. And then they actually have this one trillion high quality subset that's even better. Okay, so any questions before I move on.

**中文**: 其中3万亿个词元，即超过三万亿个词元，几乎是原先规模的两倍——我认为这相当不错，毕竟所有数据均来自Common Crawl，而他们实际上几乎将数据规模翻倍（虽未完全达到两倍，但已非常接近）。作为参考，许多模型（如Llama 3）使用15万亿词元训练，而Qwen 3则使用36万亿词元训练（其中包含多模态数据）。因此，目前6.3万亿词元的规模虽不算极为庞大，但对于开源模型所用的数据集而言，已属相当可观。对我们大多数人来说，6.3万亿词元甚至足以完成一轮完整训练。该表格显示，平均而言，其NimoTron CC数据集的表现优于DCL-LIM数据集；而DCL-LIM数据集此前已被证实优于FineWeb（至少在基准测试中如此）。此外，他们还专门构建了一个高质量的1万亿词元子集，性能更优。好，接下来我将继续讲解，大家还有问题吗？

## 段落 55

**英文**: I know this was a lot of random specific details about. different models of data sets, but hopefully this gives you a sense of the type of things, and hopefully you can kind of see different patterns, whether to use models to filter or not, whether you're using links out of high quality pages or using the pages themselves, and so on. So, yeah. Yeah, good point. So the question is, what about multilingual data sets? I've sort of focused on English because that's where primarily all the, a lot of the research done is done, but obviously, CommonCrawl does have multilingual data, and there's multilingual data sets that are produced as well. Okay, maybe interest of time I'll move on to, to copy it. So this was a. really question that was asked, how much of the web is copyrighted? So let's just understand what copyright is really about. So nowadays, there's a lot of lawsuits around generally, I'm mostly around copyright. So in general, a copyright flaw falls under intellectual property law, and the goal here is to incentivize the creation of intellectual goods.

**中文**: 我知道刚才提到的关于不同数据集模型的诸多随机而具体的细节可能有些繁杂，但希望这能让您大致了解相关情况，也希望能帮助您识别出一些不同的模式，例如：是否应使用模型进行过滤、是利用高质量网页中的链接还是直接使用这些网页本身，等等。是的，没错，这是个很好的观点。那么问题来了：多语言数据集的情况如何呢？我之所以主要聚焦于英语，是因为目前绝大多数相关研究都是基于英语开展的；但显然，CommonCrawl 确实包含多语言数据，同时也有专门构建的多语言数据集。好吧，考虑到时间关系，我接下来将转向下一个话题——复制（copy）问题。此前曾有人提出这样一个关键问题：“互联网中有多大比例的内容受版权保护？”因此，我们首先需要真正理解版权的本质。如今，围绕版权问题产生了大量诉讼，其中大多数都与版权相关。总体而言，版权侵权属于知识产权法范畴，其根本目的在于激励智力成果的创作。

## 段落 56

**英文**: That's why copyright law even exist, and there's many types of copyrights, patents, trade, market, trade secrets. So copyright law is the one that has been most relevant for training data, and this goes back to the 1700s in England, but in the US, since 1976, there's been the copyright act, which essentially is established about copyright, you know, means, and this is formally, it's applies to original. works of authorship, fixed and attendable medium expression, and so, you know, it's original work, so if you are, it's just a collection, it's not copyrightable, like telephone directives are not copyrightable, unless there's some creativity in the selection arrangement. So copyright also applies to just expression, not idea, so you can't copyright an algorithm, you can copyright the code. And one thing that has been what this did is that before copyright, I only applied to things that had been published, and now it's just this looser notion of fix. In general, copyright has sort of increased in scope, and your registration is not required for copyright, so this is different from patents. If you invent something you don't register, then you have no claim to it, whereas. copyright is, you put something and you thwart up on your website, it's copyrighted, even if you don't explicitly write the copyrighted. But there is a thing that registration is required before a creator can sue someone for copyright infringement, but the bar for registration is also over $65, opposed to patents, which are, it can be thousands. It now lasts 75 years, and then the copyright expires and becomes part of the public domain, so all the classics and most of project Gutenberg has been gone out of copyright.

**中文**: 这正是版权法存在的原因，而版权又分为多种类型，包括专利、商标、市场和商业秘密等。其中，与训练数据关系最为密切的是版权法。该法律可追溯至18世纪的英国；而在美国，自1976年起施行《版权法》，该法正式确立了版权制度的基本原则：版权适用于具有原创性的作者作品，且该作品须以某种有形的、可感知的媒介形式固定下来。因此，作品必须具备原创性——若仅为简单汇编（例如电话号码簿），则不受版权保护，除非其在内容选择或编排上体现出独创性。此外，版权仅保护表达形式，不保护思想本身，因此算法本身无法获得版权保护，但实现该算法的具体代码可以受版权保护。另一项重要变化是：在版权制度早期，只有已出版的作品才受保护；而如今，“固定于有形载体”这一标准更为宽松。总体而言，版权保护范围不断扩展，且版权无需登记即可自动产生——这与专利制度截然不同：若发明人未申请专利，则无法主张任何权利；而版权则不然，只要创作者将作品发布于网站等平台，即自动享有版权，即使未标注“©”符号亦然。不过，若创作者拟就侵权行为提起诉讼，则必须事先完成版权登记；但登记费用仅需65美元以上，远低于动辄数千美元的专利申请费用。目前，版权保护期为75年，期满后作品即进入公有领域，因此诸多经典著作及“古腾堡计划”收录的大部分作品均已不再受版权保护。

## 段落 57

**英文**: So the thing that maybe people might not realize is most things on the internet are actually copyrighted. So whether something copyright isn't really the issue, so the issue is whether you can use it, and there's two ways you can use it, you can either. get a license for it, or you appeal to the fair use clause. So if you're going the license route, you can either go sign a contract with the creator and get a license to use the data in some terms, and this is essentially what does with, you know, for example, Google and Reddit have this relationship, and effectively, licenses don't sue me. There's a special type of license called the Creative Commons license, which allows the free distribution of copyright work. So creative comments, all that stuff is still copyrighted, just that you have a license that enables it to act like if it wasn't the public domain. So a lot of things are like Wikipedia, for example, is all creative comments license, and a lot of YouTube videos are also creative comments. And this was created. almost, I guess, 20 years ago, essentially bridged the gap between public domain and copyright. And the idea is that you want people to be able to use the stuff without waiting 75 years.

**中文**: 因此，人们可能尚未意识到的一点是，互联网上的大多数内容实际上都受版权保护。所以，问题的关键往往不在于某内容是否受版权保护，而在于你能否使用它。使用受版权保护的内容主要有两种途径：一是获得授权许可，二是援引“合理使用”条款。若选择授权许可途径，你可以与创作者签订合同，获得在特定条款下使用该内容的许可——这正是谷歌与Reddit等公司之间所建立的关系，本质上就是“有许可，便不会被起诉”。此外，还有一种特殊的许可类型，即“知识共享许可”（Creative Commons License），它允许对受版权保护的作品进行自由分发。需注意的是，采用知识共享许可的作品依然享有版权，只是该许可赋予使用者类似于作品进入公有领域般的使用权利。例如，维基百科的全部内容均采用知识共享许可，许多YouTube视频也同样适用此类许可。这种许可制度大约诞生于20年前，其初衷正是弥合公有领域与严格版权保护之间的鸿沟，使公众无需等待长达75年即可自由使用相关作品。

## 段落 58

**英文**: And there's cases where the creator is actually happy for people to use their content, but it's just, most of the time, it's just not clear because they haven't said yes or no. So now many model developers license data for training foundation models, for example, Google and Reddit, opening a shutter stock, opening a stack exchange, and so on. Okay, so if you have money, you go get a license. If you don't, then I guess you have to say you're poor academic, and then maybe they'll allow you to use it. Okay, so if you, but the problem is that you can't get a license to like the internet, right? Like who do you go to a random website? Like who do you even go talk to? So the only way you can use it legally is to appeal to fair use. So fair use says basically even if something is copyrighted and you don't have a license, you can still use it under some conditions. And the conditions determined are determined by the purpose and character of the use. So for example, if you're using for educational rather than commercial, or you're transforming the work in some way, rather than just copying it and hosting it on your website and pretending it's your own, that's going to help you. The nature, what the work is,. what if it's fictional that's, it's more likely to be, you know, actually if it's, sorry, factual, it's more likely to be fair use.

**中文**: 而且有些情况下，创作者实际上乐于让人们使用其内容，但问题在于，大多数时候情况并不明确，因为他们既未表示同意，也未表示拒绝。因此，如今许多模型开发者会为训练基础模型而获取数据授权，例如谷歌与Reddit、Shutterstock、Stack Exchange等平台展开合作。好吧，如果你有钱，就可以去购买授权；如果没有钱，那你大概只能自称是经费拮据的学术研究者，或许对方就会允许你使用。但问题在于，你无法就整个互联网获取授权，对吧？比如，面对一个随机网站，你该去找谁？甚至根本不知道该和谁沟通。因此，唯一合法使用这些内容的方式就是援引“合理使用”原则。所谓“合理使用”，基本含义是：即便某内容受版权保护且你并未获得授权，在满足某些条件的情况下，你依然可以使用它。而这些条件主要取决于使用的目的和性质。例如，若使用目的为教育而非商业用途，或你对原作品进行了某种转化性使用（而非简单复制后直接上传至自己的网站并冒充原创），那么这将有助于主张合理使用。此外，被使用作品本身的性质也很关键：如果是事实性内容，相较于虚构性内容，更可能构成合理使用。

## 段落 59

**英文**: Like for example, the telephone book, you know, you can't really copyright, you know, things that are closer to facts. The, whether if you use it's just a snippet that it's more likely to be copyrighted, fair use, although for language models that doesn't really apply because you probably want to train on all of it, not just a snippet. And then affect on the market. So for example, if you're using the work to essentially displace the creator, then that's going to be seen less favorably than if you're using the work to do something complete different. So if you obviously watch a movie and write a summary of it,. it's fair use, if you re-implement the idea, that's fine. There's a big long decade fight over whether Google books when they show snippets, whether that's fair use or not. And eventually, a rule in favor of Google. It's also no worth noting that copyright isn't just about verbatim memorization. So it turns out that plots and characters can be copyrighted.

**中文**: 例如电话簿，众所周知，那些更接近事实的内容实际上无法获得版权保护。而如果你使用的是其中一小段内容，则更可能涉及版权问题，此时需考虑“合理使用”原则；不过这一原则对语言模型并不真正适用，因为你很可能需要基于全部内容进行训练，而非仅使用一小段。再者是“对市场的影响”。例如，如果你使用某作品实质上是为了取代原作者，那么这种行为将比你用该作品从事完全不同的用途更不被认可。因此，显然，你观看一部电影后为其撰写摘要属于合理使用；若你重新实现其中的创意，也并无问题。关于谷歌图书展示片段是否构成合理使用，曾有过长达十年的激烈争论，最终法院裁定支持谷歌。此外，还值得注意的是，版权保护并不仅限于逐字逐句的复制。事实上，情节和人物形象同样可以受到版权保护。

## 段落 60

**英文**: So even if you have essentially very little end-gram overlap, but you take Harry Potter, the character, and you essentially develop it, then that's a violation, it could be a violation of copyright. But on the other hand, if you parody, it might be fair use. So these things are quite subtle, and its copyright is all about the semantics and the economics and the kind of content. So it's a very complicated topic now. So what about for training? So one thing is that copyright is, the copy is in the name copyright. So even the first ever training you copy in the data is technically already a violation, even if you don't do anything with it. You could argue, as many have, that training ML model is transformative, because it's definitely far from just like copying and pasting. This does make, I think, open source models with open data, but challenging, because if you want to train a model and you also want to show people your data, and you host that data that could be an violation of copyright. People have also made arguments that the machine learning system is interested in the idea,. not the expression.

**中文**: 因此，即便你实际上几乎没有末端词元重叠，但如果你以《哈利·波特》这一人物形象为基础进行实质性开发，便可能构成侵权，即侵犯版权。但另一方面，若你进行戏仿，则可能属于合理使用。此类问题十分微妙，而版权问题本身恰恰关乎语义、经济因素以及内容类型，因而如今已成为一个极为复杂的议题。那么，在模型训练方面情况如何呢？首先，“版权”一词中的“复制”即已点明其核心：哪怕仅在初次训练时对数据进行了复制，从技术上讲便已构成侵权，即便你并未对其作任何进一步利用。许多人主张（且该观点亦有其合理性），训练机器学习模型具有“转化性”，因为它显然远非简单的复制粘贴操作。我认为，这一主张虽有助于推动开源模型与开源数据的发展，却也带来了挑战——例如，当你希望训练一个模型，同时又想向公众展示所用数据，并自行托管该数据时，便可能构成版权侵权。此外，还有人提出，机器学习系统关注的是“思想”，而非“表达”。

## 段落 61

**英文**: You're training all this data because you're trying to extract the how language works and general knowledge rather than interesting a particular work. But of course, the learning algorithm has been, sorry, the models can often memorize and you can extract data, training data from the models quite easily. And there's also this problem that language models can definitely affect the market regardless of copyright. Okay, one, I guess, other thing to note is that even if you have a license and if you can appeal to fair use for a particular work, you still might not be able to legally get the data because of terms of use. For example, YouTube has a lot of creative comments videos,. but if you write a script that goes and downloads your videos from YouTube, that is against the YouTube term of service. So there's another gating for these platforms. There's a bunch of works that you can read about later. Okay, so let me quickly go on in the instance of time. So this section is going to be a bit shorter, and I've sort of collapsed mid-training and post-training together because the boundary is not often quite clear.

**中文**: 你训练所有这些数据，是为了挖掘语言的运作机制和通用知识，而非针对某部特定作品。但当然，学习算法——抱歉，应为模型——往往容易发生记忆现象，你完全可以轻而易举地从模型中提取出训练数据。此外，语言模型无疑会对市场产生影响，而这与版权问题无关。还有一点值得注意：即便你已获得授权，或能以“合理使用”原则为某部特定作品进行抗辩，你仍可能因平台服务条款的限制而无法合法获取相关数据。例如，YouTube 上存在大量富有创意的评论类视频，但如果你编写脚本自动下载 YouTube 上的视频，便违反了 YouTube 的服务条款。因此，这些平台本身构成了另一重准入壁垒。后续你可进一步查阅相关文献。好了，我快速进入下一部分时间内容。本节篇幅会稍短一些，我将训练中期与训练后阶段合并讲解，因为二者之间的界限通常并不十分清晰。

## 段落 62

**英文**: Often now we're thinking about less high quality in general, but focused on how do you instill particular capabilities. Although, you know, even in pre-training, we're already thinking about, you know, quality classifiers and high quality. So again, the line is not quite clear. So one thing that I think is, which we haven't really talked about in this class, is long context. So models, if you look at the top models have quite a bit of context. Gemini, I think, still has, I believe, I think Lama for might advertise a 10 million context, but, you know, the context links are quite large. And transformers, skill, quadratively with the sequence length. I mean, we saw an inference lecture. You can get around that, but still you need some, I think, full attention to get the best results. And clearly, you don't want to start at the beginning training on long context.

**中文**: 如今，我们往往不再笼统地关注较低的整体质量，而是聚焦于如何培养特定的能力。不过，即便在预训练阶段，我们实际上已经在考虑质量分类器和高质量等问题了。因此，这条界限其实并不十分清晰。我认为，本课程中尚未真正讨论过的一个重要问题是长上下文。例如，目前顶尖模型所支持的上下文长度已相当可观：Gemini 模型的上下文长度据我所知仍相当大；而 Llama 系列模型甚至宣称支持高达一千万的上下文长度。但需注意，Transformer 架构的计算复杂度随序列长度呈平方级增长——我们在推理课程中已了解到这一点；尽管可通过某些方法缓解该问题，但要获得最佳效果，仍需一定程度的全注意力机制。显然，我们并不希望从一开始就用长上下文进行训练。

## 段落 63

**英文**: So what people do is they add a later. So that's why long context extension often shows up at mid-training because you don't want to waste cycles training on long context if your model is not. very good. So there's multiple ways of doing that, but since this is a data lecture, I'll talk about books and math. So our two sources that have been used to do context extension. Basically, for context extension, you just need to create data that has long range dependencies. And some of this data can also be synthesized. So people also look at tasks. So there's a bunch of works that essentially convert traditional NLP benchmarks into a standard format that they can be fine-tuned on. So supernatural instructions is one such data sets that was leveraged to the community to come together and create 1.

**中文**: 因此，人们通常会在训练后期才引入长上下文。这正是长上下文扩展常出现在训练中期的原因：若模型性能尚不理想，过早投入计算资源训练长上下文便会造成浪费。实现这一目标的方法有多种，但鉴于本次讲座聚焦数据，我将重点介绍书籍与数学两类数据源——它们已被广泛用于上下文扩展。本质上，上下文扩展只需构建具备长程依赖关系的数据，其中部分数据甚至可人工合成。此外，研究者也关注特定任务，例如将传统自然语言处理基准测试转换为统一格式，以便进行微调。《超自然指令》（Super-NaturalInstructions）便是这样一套数据集，它推动了整个社区协作，共同构建了首个此类资源。

## 段落 64

**英文**: 6 thousand tasks. And they sort of standardize into a prompt. Flan was around the same year. It came out in 2022, but it was a paper rose in 2023. So 2022 was a year of, let's take. all the NLP tasks and show them into instruction following format. And so this, one, I think, advantage of this is now you have a language model that can solve all your favorite NLP tasks and you benefit from transfer learning. This is kind of a lot of the, I think, about like, you know, going back to T5. But one problem with this is that often the prompts that you have are very templatized. If you look at the supernatural instructions, some of this is not supernatural because they're sort of like all look kind of the same.

**中文**: 6000项任务，它们大致被标准化为一种提示格式。Flan模型大约也在同一年推出，于2022年发布，但相关论文发表于2023年。因此，2022年是这样的一年：我们将所有自然语言处理（NLP）任务统一转化为指令遵循格式。这一做法的优势在于，我们现在拥有一个可解决所有你喜爱的NLP任务的语言模型，并能从中受益于迁移学习。这在很大程度上让人联想到T5模型。但该方法存在一个问题：我们所使用的提示往往高度模板化。例如，在“超自然指令”（Super-NaturalInstructions）数据集中，部分指令其实并不“超自然”，因为它们看起来都大同小异。

## 段落 65

**英文**: So that sort of motivates you know, these instruction following data sets. And since 2022, there's been sort of this expectation that language model should just be able to answer any sort of one-off tasks that you. give it. So the notion of even tasks sort of disappears. So a lot of the work in the open community has been based on synthetic data starting with Alpaca, which used this idea of self-instruct to prompt a language model to generate examples, which you can then use for fine-tuning. There's Vikunia, which used these conversations that had been shared by users on shared GPT, which is a deprecated now. You can get language models to chat with themselves, see it with some questions, and that creates some synthetic data. And you can also have these, you know, evolve-instruct methods that essentially take questions and make them more complicated. There's other ways of, you know, taking this one takes common crawl,. and then uses it to essentially look at, identify quiz sites, and then extracts QAP errors using a language model.

**中文**: 因此，这类动机催生了指令遵循数据集。自2022年起，人们普遍期望语言模型应能直接处理用户提出的任何一次性任务，以至于“任务”这一概念本身几乎消失。因此，开源社区的大量工作均基于合成数据展开，最早可追溯至Alpaca项目——它采用“自我指令”（self-instruct）方法，提示语言模型生成可用于微调的示例数据。还有Vikunia项目，它利用了用户在已停用的SharedGPT平台上分享的对话数据。此外，还可让语言模型与自身进行对话，并向其提出若干问题，从而生成部分合成数据；亦可采用“演化式指令”（evolve-instruct）等方法，对原始问题进行逐步复杂化处理。其他方法还包括：以Common Crawl语料库为基础，识别其中的测验类网站，并借助语言模型从中抽取问答对（QAP）及其中的错误样本。

## 段落 66

**英文**: And then this is open Hermes, which we saw earlier from the DCLM work. It's just a collaboration of different data sets. Lama 2 chat, we don't know what the exact data set is, but they used annotators to essentially write high-quality instruction data. And they claim in this paper that this was better than using the millions of examples from open data sets, which, but they could have even saved more their money by using, you know, by less annotation and more, just like RLJF, which we'll talk about later. And finally, the last thing I said I'll mention just came out pretty recently. So the Lama Neymotron post-training data,. this consists of a bunch of, they're all that many details about this data set, but the data set really, so you can go and look at it. They have a public data sets like WildChat, and then they synthetically generated some data from all the models that are you're able to generate data from. They also include reasoning traces, thanks to R1. And so if you look at this, you know, this style, this data, you can kind of divide into a few buckets, right? One is that a lot of the early work was just, okay, there's GPD4.

**中文**: 接着是此前在DCLM工作中提到的开源模型Open Hermes，它本质上是多个数据集的整合协作成果。Llama 2 Chat所用的具体数据集尚不明确，但据称其主要依靠人工标注员编写高质量的指令数据。该论文声称，这种做法的效果优于直接使用公开数据集中数以百万计的样本；然而，若采用更少人工标注、更多类似后续将讨论的RLHF（基于人类反馈的强化学习）方法，或许还能进一步节省成本。最后，我之前提到的最新成果——Llama Neymotron后训练数据集——不久前才刚刚发布。该数据集包含大量样本，尽管目前关于其具体构成的细节披露有限，但公众可自行查阅：其中既包括WildChat等公开数据集，也包含利用所有可调用大模型合成生成的数据，并得益于R1模型，还纳入了推理过程轨迹。综上所述，若审视此类数据的风格与构成，大致可将其划分为若干类别，例如早期大量工作仅基于GPT-4。

## 段落 67

**英文**: This is the sort of the easiest way to generate synthetic data. The problem with that is that for academic research it's fine, but, you know, it is against the terms of OpenAI to use GPD4 to create a data set, then you train a competing model. Whereas. these open-weight models have more permissive licenses, which mean that you can essentially distill from them and do whatever you want. There might be some restriction on Lama, but I think broadly speaking, I think they're more permissive than OpenAI. And then finally, if you are really paranoid, then you can actually just hire annotators to create high quality instructions, which is obviously more expensive and slower. And there's also this you know, worry that annotators might actually use GPD4 to create your data. So you have to be careful there. Okay, so summarize. So the key lesson is, you know, data just doesn't fall from the sky.

**中文**: 这是生成合成数据最简单的方法。但问题在于，这种方法用于学术研究尚可，然而众所周知，根据OpenAI的服务条款，不得使用GPT-4来构建数据集，再以此训练竞争性模型。而这些开源权重模型的许可证则更为宽松，意味着你基本上可以对其进行知识蒸馏，并自由开展各类操作。Llama系列模型或许存在某些限制，但总体而言，我认为其许可条款比OpenAI更为宽松。最后，如果你格外谨慎，也可以直接聘请标注人员来创建高质量的指令数据——但这显然成本更高、速度更慢；此外，还存在一种担忧：标注人员可能实际上会利用GPT-4来为你生成数据，因此你必须对此保持警惕。好了，来总结一下：关键教训就是——数据不会凭空从天而降。

## 段落 68

**英文**: You have to really work hard to get it. And it's important to think that out there in. the world, there's these live services like GitHub, right? And first you have to use it. You have to first get a dump of the raw data, but you can't train on the raw data. It's too big or soon or it's not even tokens. You often have to process it. And that's where a lot of the heuristics that we saw for quality filtering, duplication kind of fit in. This was sort of touched on earlier. Data is really the key ingredient that essentially differentiates you know, language models. I think all of the language model, you know, architectures, there's some, you know, transformer, M O E style.

**中文**: 你必须付出极大努力才能获得它。同时，重要的是要意识到，世界上存在像 GitHub 这样的实时服务，对吧？首先，你得使用它；其次，你需要先获取原始数据的完整转储，但你无法直接用原始数据进行训练——因为原始数据体量过大、更新过快，甚至尚未被切分为词元（tokens）。你通常需要对数据进行预处理，而我们之前提到的质量过滤、去重等大量启发式方法，正是在此环节发挥作用。这一点前文已略有提及。数据确实是区分语言模型的关键要素。我认为，所有语言模型的架构——比如 Transformer 或混合专家（MoE）等类型——本质上并无太大差异。

## 段落 69

**英文**: I think largely the transfer these architectures so kind of general purpose that the behaviors aren't really going to be that different. It's really the data. that drives the quality there, assuming you can train and fit the data. There are some, you know, legal and ethical issues here. We talked about copyright, but there's more, much more to be said here. And then finally, if you think that this whole field is a mess, you're right, it's very heuristic, which means that there's many opportunities to hopefully improve that. Okay, that is it, and I'll see you on Thursday.

**中文**: 我认为，这些架构的迁移能力较强，属于通用型，因此其行为差异并不会太大；真正决定性能优劣的是数据——前提是您能够完成模型训练并使模型适配数据。此外，这里还存在一些法律与伦理问题：我们已讨论过版权问题，但相关议题远不止于此，还有大量内容有待探讨。最后，如果您觉得整个领域目前一片混乱，那您说得完全正确——当前的研究方法高度依赖经验法则，这意味着其中蕴含着诸多有望改进的机会。好了，就讲到这里，我们周四见。

---

*共 69 个段落，687 句话*
