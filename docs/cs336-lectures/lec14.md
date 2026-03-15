# Lecture 14： Data 2

生成时间: 2026-03-08 23:08:08

---

## 段落 1

**英文**: So this is the second lecture on data. In the last lecture, we talked about different data sets that were used to train various language models. We sort of did a historical overview from the data sets that were used to train BERT all the way up to HOMO and everything in between. And one of the things I wanted to emphasize is that data doesn't just fall from the sky. It exists often in live services. They have to be explicitly crawled or dumped. And then there's a bunch of processing that has to happen. And the processing involves converting the raw HTML to text, doing all sorts of quality and language and toxicity filtering, deduplication, and so on and so forth. So in this lecture, I would like to take a deep dive into some of the mechanics on how quality filtering and deduplication work in particular. So first, we're going to look at different algorithms for filtering, which mostly are model based.

**中文**: 因此，这是关于数据的第二讲。在上一讲中，我们讨论了用于训练各类语言模型的不同数据集，大致按时间顺序回顾了从训练BERT所用的数据集，一直到HOMO，以及其间所有相关数据集。我想强调的一点是：数据并非凭空而来，它们通常存在于实时运行的服务中，需要通过显式的网络爬取或数据导出才能获取；随后还需进行大量预处理工作，包括将原始HTML转换为纯文本、开展各类质量、语言及有害性过滤、去重等操作。因此，在本讲中，我将深入探讨质量过滤与去重的具体实现机制。首先，我们将考察多种主要基于模型的过滤算法。

## 段落 2

**英文**: So you train your classifier or train some sort of model to filter. Then we're going to show that this primitive can be used for all sorts of different types of filtering. And then finally, we're going to look at some algorithms for deduplication. So this lecture will be a little bit different in that it's going to focus a lot on sort of classical big data processing algorithms. And there will be some fun math in there for some of you. Okay, so let's get started with filtering algorithms. So the basic high level picture here is that you're given some target data, which you. don't have very much of it. Suppose it's data that's high quality, and you have a lot of raw data. So imagine this is common crawl.

**中文**: 因此，你先训练一个分类器，或训练某种模型来进行过滤。接着，我们将展示这一基础方法可应用于各种不同类型的过滤任务。最后，我们将探讨一些去重算法。本讲内容将略有不同，重点聚焦于经典的“大数据处理”算法，其中还包含一些有趣的数学知识，供部分同学学习。好了，我们开始讲解过滤算法。此处的基本高层思路是：你手头有一些目标数据，但数量十分有限；假设这些数据质量很高，而你同时拥有大量原始数据。例如，这可以是Common Crawl数据集。

## 段落 3

**英文**: And your goal is you want to find a subset of that raw data, it's called T prime, which is similar to T. Okay, so this is a pattern that you should kind of recognize in basically any sort of filtering pipeline. And what do you want for this filtering algorithm? You want it obviously to generalize from T, right?. You don't want, you already have T. So there's no point in getting exactly the same data T. So there has to be some generalization. And also has to be extremely fast. So you have to run it on all of the web, for example. So if this is running a huge model, that's going to be, might be as expensive as training. So you don't definitely don't want that, otherwise you might as well train.

**中文**: 你的目标是从原始数据中找出一个子集，称为T′，使其与T相似。好了，这实际上是你在任何过滤流程中都应识别出的一种模式。那么，对于这个过滤算法，你希望它具备什么特性呢？显然，你希望它能从T中进行泛化，对吧？你已经拥有T了，因此完全复制T毫无意义，必须实现某种泛化。同时，该算法还必须极其高效——例如，你需要将其运行于整个互联网上。如果该算法依赖一个庞大的模型，其开销可能与训练模型本身相当；这显然是不可接受的，否则你干脆直接训练模型算了。

## 段落 4

**英文**: So we're going to look at three different ways that you can implement this high level abstract primitive. So we'll start with training and end-ground model. So this is something that came up in the last lecture. So you can train an end-ground model with kinesar-nye smoothing. You can use other forms of smoothing, but kinesar-nye has sort of been inherited from the n-gram kind of modeling, since it's a language processing era. And there's a particular implementation that people tend to use in this space called canl-lamb, which is open source, originally developed for mission translation, which implements kinesar-nye smoothing. So you can go and read about kinesar-nye. It's pretty interesting, but we're not going to talk too much about the details here. So this happens to be very popular in data filtering. There's no particular reason it has to be this one, but this is just what people use.

**中文**: 因此，我们将探讨三种实现这一高层抽象原语的不同方法。首先从端到端模型的训练开始。这在上一讲中已有所提及。您可以使用吉尔辛-尼（Kneser-Ney）平滑技术来训练端到端模型；当然也可采用其他形式的平滑方法，但吉尔辛-尼平滑源于n元语法（n-gram）建模传统，是自然语言处理时代沿袭下来的方法。该领域普遍采用的一种特定实现名为“Canl-LM”，这是一个开源工具，最初为机器翻译任务开发，内置了吉尔辛-尼平滑功能。您可自行查阅吉尔辛-尼平滑的相关资料——它确实非常有趣，但此处我们不深入讨论其技术细节。目前，该方法在数据过滤任务中尤为流行；虽无特定理由必须选用此法，但业界普遍如此实践。

## 段落 5

**英文**: And the nice thing about end-ground modeling is it's very simple. When I say fitting a model, you should think of this as just counting the number of n-grams and then normalizing. So just to go into a little bit of depth here, so it's starting point is maximally. the estimation of language models. So you have a corpus of text, and you want to estimate conditional probabilities like p of n given the last n minus 1 words, the cat. And what you do is you count the number of n-grams and then divide it by the number of n minus 1 grams of a condition context. So this is very, very easy. In principle, now implementing this efficiently takes a bit of work. But the main problem is that there's sparse counts. So many of the n-grams are exactly show up zero times, even though they're very reasonable, especially when n-grows.

**中文**: 端到端建模的妙处在于其极为简单。当我提到“拟合模型”时，你只需将其理解为统计n元语法（n-gram）的数量，然后进行归一化处理即可。下面稍作深入说明：该方法的出发点是语言模型的最大似然估计。具体而言，你拥有一份文本语料库，目标是估计诸如“给定前n−1个词（例如‘the cat’）时，第n个词出现的条件概率p(n|前n−1个词)”这类条件概率。实现方法是：统计n元语法的出现频次，再除以对应条件上下文（即前n−1个词构成的n−1元语法）的出现频次。这一过程极其简单。理论上如此；但若要高效实现，则需付出一定努力。然而主要问题在于数据稀疏性：大量n元语法的实际出现次数为零，尽管它们本身完全合理——尤其当n增大时，这一问题更为突出。

## 段落 6

**英文**: And this was a whole point why n-gram models couldn't really be scaled appropriately because you hit the curse of dimensionality. So to mitigate this, some people devised Knazone smoothing to handle on seen n-grams. And there's more details on this, but roughly this says, well, maybe if I don't have enough data to support this count, I can sort of use a lower order n-gram. So remove one word from the context and count the number of times in appears given cat,. and then try to either interpolate or back off to that. So that's all say about how n-gram modeling works. I think even in this era of neural language model, it's good to know that how n-gram models work. So let's download n-gram. So this is a model that's been trained on Wikipedia. I'm just going to download it.

**中文**: 而这正是n元语法模型难以适当扩展的整个关键原因，因为会遭遇“维度灾难”。为缓解这一问题，一些人设计了Kneser-Ney平滑方法来处理未登录的n元语法。关于该方法还有更多细节，但其基本思想是：如果当前n元语法的统计数据不足，便退而采用低阶n元语法——即从上下文中移除一个词，统计在给定“cat”（猫）条件下该词出现的次数，然后尝试对该低阶统计结果进行插值或回退处理。以上便是n元语法建模的基本原理。我认为，即便在当今神经语言模型盛行的时代，了解n元语法模型的工作原理依然很有价值。下面我们来下载一个n元语法模型——这是一个在维基百科语料上训练好的模型，我将直接下载它。

## 段落 7

**英文**: And then let's punch some sentences through. So this sentence is Sanford University was found in 1885. This is actually an excerpt taken from Wikipedia. So it should be reasonable. And if you compute the probability, so you first compute the log prob and then you can perplexity by this normalization, then you get 187. So it's some number. And then here's another example. This is taken from the CS336 website. So let's see how well it does. So this is a higher perplexity, means that it's less likely.

**中文**: 然后我们来测试几个句子。例如，“斯坦福大学成立于1885年”这一句，实际上摘自维基百科，因此是合理的。若计算其概率：首先计算对数概率，再通过该归一化方式得出困惑度，结果为187，即一个具体数值。再看另一个例子，它取自CS336课程网站。我们来看看模型的表现如何。此处困惑度更高，意味着该句子出现的可能性更低。

## 段落 8

**英文**: It's kind of a mixed sense because this stuff doesn't really probably show up in. Wikipedia, it's not in, it's not abnormally high because it's still fairly good well-formed in English and many n-grams there, I think, show up in Wikipedia as well. What about ASDF? This is just gibberish. This gets assigned higher perplexity. And then there's the other, so this should get assigned pretty high perplexity, but for some reason this particular n-gram assigns a pretty low perplexity. So it's an n-gram model, so it's not particularly clever or good. But you don't need to be the best model. You're just doing data filtering to create a model. So this can be very crude and fast. So CCNet, which is a paper out of, I guess it was Facebook back then, which we talked about last time, they basically did this and actually, that's fine.

**中文**: 这种感觉有些复杂，因为这类文本实际上很可能不会出现在维基百科中；它并未被归入异常高 perplexity 的类别，毕竟其英文表达仍相当规范，且其中许多 n-gram 在维基百科中也确实存在。那么“ASDF”呢？这纯粹是胡言乱语，因此会被赋予较高的 perplexity。而另一类情况则相反：此类文本本应被赋予相当高的 perplexity，但出于某种原因，这一特定 n-gram 却被赋予了相当低的 perplexity。这是因为该模型仅为一个简单的 n-gram 模型，本身并不特别聪明或优秀。但你并不需要构建最出色的模型，而只是利用它进行数据过滤以构建后续模型。因此，该方法可以非常粗略且高效。例如，CCNet（一篇出自当时 Facebook 的论文，我们上一次讨论过）就采用了这种方法，而这完全可行。

## 段落 9

**英文**: So they basically looked at paragraphs of text and those were the items. They sorted the paragraphs by increasing perplexity and just kept the top one-third. And this is what they used to create the first Lama dataset. So this is heuristic, but if you had to write down something really quickly and this kind of makes sense. So Nays and I, in English, Molleen is fast, but it's uncrewed. All right. I feel like there was some content I was never meant to go through, that's missing. Oh well, maybe you got the way that. All right, so you can fit an n-gram model to your target data and then you can use that to score the raw data and choose the top scoring documents. Another thing you can do is fast text and this is in some ways more popular.

**中文**: 因此，他们基本上是针对文本段落进行分析，这些段落即为待处理的项目。他们按困惑度（perplexity）升序对段落进行排序，并仅保留得分最高的前三分之一。正是利用这部分数据构建了首个Lama数据集。该方法属于启发式策略，但若需快速制定某种方案，这种思路确实具有一定合理性。纳伊斯和我用英语完成这项工作；莫琳处理速度快，但其过程是无人工干预的。好吧，我感觉似乎遗漏了一些本应审阅的内容。哦，算了，或许你已掌握了其中要领。好了，你可以针对目标数据拟合一个n元语法（n-gram）模型，然后利用该模型对原始数据进行打分，并选取得分最高的文档。另一种可行方法是采用FastText，某种程度上它更为流行。

## 段落 10

**英文**: This is also from Facebook. They released a lot of open source tools. Although Kennelm, I think, was created before that. So here they develop it for text classification and this paper, I mean this 2016, so a lot. of people were developing all sorts of fancy neural models and they said, show that, well, this actually almost linear classifier worked as well as much faster. So that's why software package actually became very popular. So the motivation here was that if you're doing, let's say, bag of words, classification. So you have a sentence of length L, your vocab sizes V and you want to classify into 64 classes. Then immediately you have to define this V by K matrix, which if V and K are both large then this gets pretty big and you get into sparse the issues. And the way it would work is that you take your documents and then you just do linear classification.

**中文**: 这同样来自Facebook。他们发布了许多开源工具。不过，我认为Kennelm的创建时间要早于这些工具。在这里，他们将其开发用于文本分类；我指的是这篇2016年的论文——当时，大量研究人员正致力于开发各类复杂的神经网络模型，而他们却证明：一个近乎线性的分类器，其性能几乎与这些复杂模型相当，且速度要快得多。正因如此，该软件包迅速广受欢迎。此处的动机在于：假设你采用词袋（bag-of-words）方法进行分类，即给定一个长度为L的句子、大小为V的词汇表，并需将其分类至64个类别中，那么你将立即需要定义一个V×K的矩阵；若V和K均较大，该矩阵便会变得非常庞大，从而引发稀疏性问题。其工作方式是：对文档进行处理后，直接执行线性分类。

## 段落 11

**英文**: So that's fairly straightforward. So the problem is that the number of parameters here. So FastHex says, well, let me just do a linear basically dimensionality reduction. So instead I'm going to map my vocab space into a hidden dimension, which is smaller than K, possibly smaller than K 16, and then I'm going to classify from H. So notice that there's when you look at the prediction, the forward pass, there's no nonlinearity. It's just a linear classifier. You can also think about as a matrix factorization if you want. And the number of parameters is greatly new reduced. So limitation I think is, you know, reasonably optimized. It's paralyzed and it used asynchronous SGD.

**中文**: 因此，这相当直接。问题在于此处的参数数量。FastHex提出：“让我简单地进行线性降维。”因此，我将把词汇空间映射到一个隐藏维度H，该维度小于K，甚至可能远小于K（例如仅为16），然后基于H进行分类。请注意，在前向传播（即预测过程）中，不包含任何非线性变换，仅是一个线性分类器；若愿意，也可将其视为一种矩阵分解。参数数量因此大幅减少。我认为其局限性已得到合理优化：它支持并行化，并采用异步随机梯度下降（SGD）。

## 段落 12

**英文**: So here's, okay, so the question is this is bag of words. And, you know, we want to not just look at words, but we want to look at endgrams. So this, people also, you know, extends to endgrams in a fairly simple way. So you take a sentence and you get some chopping up into your endgrams. And here the problem is that the number of bygrams can get quite large. And it actually can be unbounded. So remember when we talked about tokenizers, if you just chop up into words, you're going to get, you know, you don't know how many words there are. So the simple thing is that you just do hashing. So you define some number of bins, maybe 10 million, but in this example, eight. And then you just hash every bygram into that.

**中文**: 因此，这里的问题是词袋模型。如你所知，我们不仅希望关注单个词语，还希望关注n元语法（n-gram）。人们通常以一种相当简单的方式将词袋模型扩展至n元语法。具体而言，你对一个句子进行切分，得到若干n元语法片段。但此处的问题在于，二元语法（bigram）的数量可能变得非常庞大，甚至可能是无界的。回想一下我们之前讨论分词器时提到的内容：如果仅按词语切分，那么词语总数是未知的。因此，一种简单的解决方法是采用哈希处理：即预先设定一定数量的哈希桶（例如1000万个，而本例中为8个），然后将每个二元语法直接哈希到这些桶中。

## 段落 13

**英文**: So you, these, the cab maps to two and cat in maps to one and so on. Okay? So of course, there might be some collisions, but, you know, you just live with that. I mean, in some sense, the opt, when you minimize the loss, collisions are sort of accounted for it. There's like two words that have nothing to do with each other than the weight is going to somehow represent the, maybe the average of the two. And also note that often we use fast text classification with K-Eco-2 classes. Is this document good or is it bad? And in that case, this is just normal, basically binary classification, linear classification. Okay. So of course, it doesn't take too much imagination to imagine, well,. if you can do linear classification, you can use fancy models such as Bert or even Lama. The only thing is that it's going to be slower.

**中文**: 因此，您看，“cab”映射到2，“cat”映射到1，以此类推。明白了吗？当然，可能会出现一些哈希冲突，但您只能接受这一点。从某种意义上说，当您最小化损失函数时，优化过程本身已在一定程度上考虑了冲突问题：例如，两个毫无关联的词会共享同一个权重，该权重可能大致代表这两个词的某种平均值。此外请注意，我们通常将FastText用于K分类任务（如ECO-2分类），即判断该文档是“好”还是“坏”。此时，这本质上只是一种常规的二元线性分类任务。当然，您不难想到：既然可以做线性分类，那自然也能采用更复杂的模型，比如BERT甚至LLaMA。唯一的缺点是，这些模型的运行速度会慢得多。

## 段落 14

**英文**: And therefore, you run into this trade-off where if you use a giant model to do classification, maybe you should use those flops to actually just train the model. So that's the only concern. Because though, you know, the web is very large. And remember, you were filtering the web down quite a bit. So you're going to spend a lot of compute on, let's say you're filtering down to 1% of the web. Right? So that means, you have your classifier, that amount of compute you spend has to be 100th of the taking it forward pass through the data set. Okay. So the final method I'm going to talk about is this thing called data selection for language models using importance resampling. And here the basic ideas that you have your R is a raw data set, you have your target data. And then I'm going to build an importance weight estimator, which is the analog of the language and grand model or the fastest classifier.

**中文**: 因此，你将面临这种权衡：若使用超大规模模型进行分类，或许更应将这些计算资源直接用于模型训练。这便是唯一的顾虑。尽管如此，网络数据量极为庞大，而你实际上已对网络数据进行了大幅筛选。举例而言，假设你仅保留了网络数据的1%，那么用于筛选的计算量必须仅为后续在该数据集上执行一次前向传播所需计算量的百分之一。接下来我要介绍的最终方法，称为“基于重要性重采样的语言模型数据选择”。其基本思想是：你拥有原始数据集R和目标数据集；接着，我将构建一个重要性权重估计器，该估计器的功能类似于语言模型或最快的分类器。

## 段落 15

**英文**: And then I'm going to use that to get a bunch of documents. Okay. So first, just a kind of quick refresher of importance resampling, I guess. So you have this shows up in many contexts like particle filtering and, you know, Monte Carlo methods. So you have a target distribution. So it's a distribution, not a data set, where you want to ideally draw samples from this. But you only have the proposal distribution queue where you can draw samples. So for example, if you have a vocab of 0123, 2, 3, let's say this is your target distribution. And your proposal distribution is this. Now, what do you do is you sample from queue because that's the only thing you can sample from.

**中文**: 然后，我将利用它来获取大量文档。好的。首先，简单回顾一下重要性重采样（importance resampling）的概念。它常见于粒子滤波、蒙特卡洛方法等多种场景中。你有一个目标分布——这是一个概率分布，而非数据集，理想情况下你希望从中直接抽样；但你仅拥有一个可从中抽样的建议分布（proposal distribution）q。例如，假设词汇表为{0,1,2,3}，而这是你的目标分布，你的建议分布则是这个。此时，你唯一能做的就是从q中抽样。

## 段落 16

**英文**: So let's say you got a bunch of samples. Okay. So notice that queue has a lot of more mass on zero. So you get a lot of more zeros. And then what you're going to do is you compute weights over your samples by looking at this importance ratio, P over queue. So you're trying to make up for the fact that I've sample from queue. So I want to divide that out where I really want P. And you normalize. And then you get a distribution over your samples. And now you re-sample and you that sort of balances out the distribution.

**中文**: 假设你获得了一组样本。注意，分布q在零处的质量更大，因此你会得到更多的零值样本。接下来，你需要通过计算重要性比率（即P与q的比值）来为这些样本赋予权重。这样做的目的是弥补你从分布q中采样的事实——由于你真正想要的是分布P，因此需要将q的影响“除掉”。随后，你对权重进行归一化处理，从而得到一个基于样本的分布；最后，你依据该分布重新采样，从而使整体分布达到平衡。

## 段落 17

**英文**: So now you see that there's more threes because P had more probability distribution on mass on three. Okay. So this is a fairly elementary. But it's a building block. Now we go to how we do data selection. So we have a target data set, not a distribution. We have a data set, which is small. And we also have this broad data set, which we're going to call the proposal data set, dq, which is large. So you could, let's just fit a distribution, P to dp, fit a distribution queue to dq, and do the importance resampling that we talked about just two minutes ago. Now the main problem is that dp is really small.

**中文**: 因此，您现在可以看到，数字3出现得更多，这是因为分布P在数值3上的概率质量更大。好的，这相当基础，但却是构建后续内容的基石。接下来，我们讨论如何进行数据选择。我们有一个目标数据集，而非一个分布；该目标数据集规模较小。此外，我们还有一个范围更广的数据集，称之为建议数据集（记为dq），其规模较大。我们可以简单地为目标数据集dp拟合一个分布P，为建议数据集dq拟合一个分布q，然后执行我们两分钟前刚讨论过的重要性重采样。当前的主要问题是：dp实际上非常小。

## 段落 18

**英文**: Remember target distribution is high quality data. You don't have that much of it, which is the. whole point. You're trying to get more of it. So you don't have that much of it. And it's too small to estimate a good model. So again, this idea is you just use hash and grams. So this is something that we already saw with FEST text as well. You take whatever text you have, and then you essentially, okay. So you basically hash all the, we're doing unagrams for now.

**中文**: 请注意，目标分布对应的是高质量数据。而你手头的这类数据并不多，这正是问题的关键所在——你正试图获取更多此类数据。因此，你确实没有多少高质量数据，其数量又太少，不足以训练出一个性能良好的模型。所以，我们再次采用哈希与词元（n-gram）的方法。这一点我们在FEST文本中也已见过：你只需利用手头已有的任何文本，然后对所有文本进行哈希处理；目前我们采用的是单个词元（unigram）。

## 段落 19

**英文**: So you hash each unagram. So you basically count the number, estimate the probability of every hashed and gram. So in this case, this, the cad in the hat, hashes to this. Notice that there's some hash collisions, they're in the hat, hatch, into the same value, but whatever, this is all crude. And then you just estimate the probability of each of these, the probabilities. Okay, so then to evaluate the. probability of a new text, you hash the new text, and you multiply the probabilities together. Okay, so I got a little bit unlucky and the probability is gets zeroed out. You can do some smoothing if you want. So it turns out that Python hash is not in terms of every time I run this, so I'm going to get something, something else.

**中文**: 因此，您对每个一元词（unigram）进行哈希处理。本质上，您统计其出现次数，并估算每个哈希后的一元词的概率。在此例中，“the cat in the hat”被哈希为该值。请注意，存在一些哈希冲突——例如“in the hat”和“hatch”被映射到同一哈希值；但无论如何，这都是一种粗略的处理方式。接着，您只需估算上述各项各自的概率即可。好，接下来要评估一段新文本的概率：您先对这段新文本进行哈希处理，再将对应各项的概率相乘。好，我运气稍差，导致最终概率为零；若您需要，可采用平滑技术加以处理。另外需注意，Python 的哈希函数每次运行结果并不固定，因此我每次执行都会得到不同的结果。

## 段落 20

**英文**: And the paper shows that this, indeed, helps a bit. The gains are not, you know, super massive, but, you know, compared to doing FEST text, which is the heuristic classification, the gains on the glue benchmark using BERT style models, there is some lift. And the comparison with FEST text, so the main idea here is that modeling a whole distribution is, in some sense, a more principled approach, right,. because you want to sample data from your distribution and you have a different distribution queue, and now you're trying to essentially compensate. And so this could be better for, you know, diversity, because you're trying to match the distribution out, whereas FEST text, you're essentially trying to classify whether something is in the distribution or not, and it doesn't have any guarantees about matching the distribution. Okay, but it's also FEST like FEST text, and both can be improved by having better models. So instead of using linear models based on N-grams, you can increase N, you can use neural approaches as well. Okay, so just to wrap up this part, so we look at N-gram models, linear classifiers, and. importance resampling. But the general framework, I think, is something that maybe worth taking away, which is the setup given a target dataset and a raw dataset find the subset that's similar to the target, and all these methods have the basic recipe, which is estimate some sort of model based on the raw data and the target dataset, which gives you a scoring function, and then keep examples in the raw dataset based on that scoring function, usually high scores are kept.

**中文**: 论文表明，这种方法确实能带来一定提升。虽然提升幅度并非特别显著，但与采用FEST文本（一种启发式分类方法）相比，在GLUE基准测试中使用BERT风格模型时，性能仍有一定提高。与FEST文本的对比表明，此处的核心思想在于：对整个分布建模在某种意义上是一种更严谨的方法，因为你希望从目标分布中采样数据，而你手头却是一个不同的分布队列，因此本质上是在尝试进行补偿。因此，该方法可能更有利于提升多样性——因为你力求使采样结果匹配目标分布；而FEST文本则仅试图判断某个样本是否属于该分布，无法保证所采样本在整体上与目标分布一致。当然，FEST文本本身也存在改进空间，二者均可借助更优的模型加以提升：例如，不再局限于基于N元语法的线性模型，而是增大N值，或直接采用神经网络方法。最后简要总结本部分内容：我们考察了N元语法模型、线性分类器以及重要性重采样方法。但更值得把握的是其通用框架，即：给定一个目标数据集和一个原始数据集，从中筛选出与目标数据集相似的子集；所有这些方法均遵循相同的基本范式：首先基于原始数据集和目标数据集估计某种模型，从而获得一个打分函数；然后依据该打分函数对原始数据集中的样本进行筛选，通常保留得分较高的样本。

## 段落 21

**英文**: So just to walk through this in the can-alum case, you know, the score is simply the probability of, or I guess maybe the perplexity, if you want to normalize by the number of tokens, under the target. Okay, so R is not used here, and then you keep examples with score greater than. threshold, and you can, you know, randomize a little bit around the threshold if you want. So you can also use a discriminative classifier, where the score is what's the probability that this example came from the target as opposed to the raw dataset, and then you keep examples where the score is of greater than some threshold. And then the importance of resampling says the score is the ratio of, you know, two generative models, which could be n-gram models in this case, P of, you know, the target distribution over the raw distribution, and to use a score, this is really the importance way it's you resample with probably proportional to that. Okay, so at a high level, all of them are doing essentially the same thing. You have, you fit some sort. of distribution that tells you what looks like target as opposed to raw, and then you apply that to the raw dataset. Okay, maybe I'll pause here in case there's any questions. Yeah, I'm sort of like a high level, full-soft bowl thing.

**中文**: 以“can-alum”案例为例，我们来简要梳理一下：这里的得分即为目标分布下样本的概率（或者，若需按词元数量进行归一化，则可采用困惑度）。注意，此处未使用R。随后，我们仅保留得分高于某一阈值的样本；如有需要，也可在阈值附近稍作随机扰动。此外，还可采用判别式分类器，其得分表示该样本来自目标分布而非原始数据集的概率，然后同样只保留得分高于某阈值的样本。而重要性重采样方法中的得分，则是两个生成式模型（本例中可为n元语法模型）的概率比值，即目标分布概率与原始分布概率之比；实际应用时，即按该比值成比例地进行重采样。综上所述，从宏观角度看，这几种方法本质上殊途同归：首先拟合某种分布，用以区分目标分布与原始分布的特征，再将该分布应用于原始数据集。好，我先暂停一下，看看大家是否有问题。是的，我刚才讲的是一种高层次、整体性的概括。

## 段落 22

**英文**: We have an idea of what good data is, but we've kind of not talked about what that's actually like, what, like a good document looks like. So what this is doing is like making sure that the words fit next to each other when you have a given in the general, like that, you know, one comes after the other, but it doesn't. You sure that they, it makes any sense on like a larger level, or if you want that, you just increase the n in the n-gram. Yeah, so the question seems, I think, is that if you're using an n-gram. model, it's only looking at local context, and maybe that's not great for assessing quality, because if you shuffle everything around, it still looks good to the n-gram model. So there's definitely that danger that it's very easy to adversarily gain, right? If you can construct, you can definitely construct examples that the n-gram model thinks is high. I mean, I showed you one, though, though, that happens to be, you know, pretty high. But somehow on average, you know, you're doing okay. And in some sense, maybe if a document looks like grammatical English and it looks like news or, you know, some scientific paper, all you want to make sure is that that model of science, I probably do that. If you get some,.

**中文**: 我们对“优质数据”有某种概念，但尚未深入探讨其具体表现形式，例如一份优质文档究竟该是什么样子。因此，此处所做的是确保在一般情况下，词语能自然地前后衔接——即一个词紧随另一个词出现；但仅此还不够，还需进一步确认这些词在更高层次上是否真正通顺合理。若需提升这种整体性判断能力，可增大n-gram模型中的n值。是的，问题似乎在于：若采用n-gram模型，它仅关注局部上下文，而这可能并不适合评估文本质量，因为即使将文本内容彻底打乱顺序，n-gram模型仍可能判定其质量很高。因此，确实存在一种风险：该模型极易被恶意操纵。换言之，只要刻意构造，就一定能生成若干被n-gram模型判定为高质量的文本示例。我之前向您展示过一个例子，恰好质量确实很高；但总体而言，模型的表现尚属可接受。从某种意义上说，或许只要一篇文档符合语法规范的英文表达，且风格类似新闻报道或某类科学论文，我们便只需确保其符合相应领域的建模标准——我大概率会这么做。倘若……

## 段落 23

**英文**: you know, bad examples, it's not the end of the world. Yeah. I would say this is filtering out true nonsense. I think a good way to look at it. As I go through some examples, I think maybe it'll become a bit clearer that these cosseires are not just used for quality, and for some of the other case cases, I think it's much more of maybe compelling why it should work. Okay. So, so the same data filtering machinery can be used on different tasks. So I'm going to talk about language identification, quality filtering and toxicity filtering. So language identification, the idea is that you want to find text of a specific language. Maybe it's English, maybe it's.

**中文**: 你知道，糟糕的示例并不意味着世界末日。是的。我认为这其实是在剔除真正的无意义内容，这是一种不错的理解方式。随着我列举一些示例，大家或许会更清楚地认识到：这些分类器并不仅仅用于质量评估；在其他某些场景下，其作用可能更多在于有力地阐明为何该方法应当有效。好的，因此，同一套数据过滤机制可应用于不同任务。接下来我将介绍语言识别、质量过滤和毒性内容过滤。所谓语言识别，其目标是识别出特定语言的文本，比如英语，又或者……

## 段落 24

**英文**: Japanese. And you could ask, well, you know, you could just train on all the languages. Why don't you do that? The problem is that it can often be difficult to, you know, do the curation and processing of high quality data in a given language. And there's also, you know, the problem that, if you train, let's say you only care about, you know, one language. Now, if you have data from all the other languages, you're going to be spending less compute and tokens on any given languages, on the given language. So this was a, and that could hurt your performance in that language. For example, you know, Bloom, which was trained in about 20, 22, I believe, was only trained on 30% English. And as a result, the English performance maybe was not as good as it could have been. It. was strong on other languages.

**中文**: 日语。你可能会问：“嗯，既然如此，为何不直接在所有语言上进行训练呢？”问题在于，针对某种特定语言，往往很难完成高质量数据的筛选与预处理工作。此外还存在另一个问题：假设你只关注某一种语言，那么当你使用所有其他语言的数据进行训练时，分配给该目标语言的计算资源和词元数量就会相应减少，从而可能损害该语言上的模型性能。例如，Bloom模型大约于2022年训练完成，其训练数据中英语仅占30%，因此其英语能力可能未达最优水平，但在其他语言上表现强劲。

## 段落 25

**英文**: So they're in the compute-limited, you'll regime, you're definitely at risk of compromising the quality of the language you care about. Now, that said, if you have enough capacity and you're training huge models, then you can definitely train multilingual models and there's could be even positive transfer between languages. So all the kind of frontier models are trained on heavily multilingual, sometimes even hundreds of like 100 plus languages. So, you know, one simple way to do this is fast text is a toolkit for training simple class fires. It also comes with some off-the-shelf models. And one of the ones that typically gets used is they have a language identification model. And this is just off-the-shelf class far. It supports. a lot of different languages and it was trained on basically multilingual sites, including Wikipedia, which has a lot of different languages, translation sites, and you know, for some reason, Southeast user opinions. So, DOMA uses this.

**中文**: 因此，当你们处于计算资源受限的状态时，语言质量必然会面临风险。不过话说回来，如果你们拥有充足的算力并训练超大规模模型，那么完全可以训练多语言模型，甚至不同语言之间还可能产生正向迁移效应。目前所有前沿模型均基于高度多语言的数据进行训练，有时甚至涵盖上百种语言（如100多种）。一种简单可行的方法是采用FastText工具包来训练简单的分类器，该工具包也提供了一些现成的预训练模型；其中常用的一个模型便是其语言识别模型——这只是一个开箱即用的分类器，支持大量不同语言，训练数据主要来自多语言网站，包括拥有多种语言版本的维基百科、各类翻译网站，以及不知为何还包括东南亚用户的评论数据。DOMA便采用了这一模型。

## 段落 26

**英文**: They basically run the fast text class fire and keep pages with English probability greater than 0. 5. So let's try it out. So there's this model language ID that you can just download. And then let's see how well that does. So the quick brown fox jump over the lazy dog. Let's see where are the predictions. I don't know why. Okay, there we go. So, okay, so this says English.

**中文**: 它们基本上运行快速文本分类器，并保留英语概率大于0.5的页面。我们来试一下。这里有一个语言识别模型，你可以直接下载。然后我们来看看它的效果如何。“敏捷的棕色狐狸跳过了懒狗。”我们来看一下预测结果。我不知道为什么……好了，就是这里。所以，这个结果显示为“英语”。

## 段落 27

**英文**: This is the label English and the probability of English is 0. 71. Okay, so I mean, what if guess it would be higher? It looks pretty English to me. If you duplicate the sentence, the probability isn't changing, which is good. Saying the same thing doesn't make it more English. There's some informal English, which is kind of weird. This is, I guess, more English than the quick brown fox. German actually gets classified fairly. Oh, sorry, this is German out. The label is German.

**中文**: 这是英文标签，英文概率为0.71。好吧，我的意思是，如果猜测其概率会更高呢？在我看来，它看起来非常像英文。若将该句子复制一遍，概率并未发生变化，这很好——重复相同内容并不会使其更像英文。其中包含一些非正式英文，这有点奇怪。我想，这句话的英文程度甚至高于“快速的棕色狐狸”。德语实际上被分类得相当准确。哦，抱歉，这是德语输出。标签为德语。

## 段落 28

**英文**: Okay, that is German. Math gets classified pretty weekly as English. Code is highest as Russian. This is hello is apparently Italian. This is French. That's good. And this is, I guess, a tricky one where I put in some Spanish and also some English and I guess a favor that Spanish in this case. Okay, so this gives you a sense. I mean, it's always good to play with these classifiers,. right? Because just because it's a classifier, you can download and everyone uses doesn't mean it like works all the time.

**中文**: 好的，这是德语。数学相关内容通常被归类为英语。代码则最常被识别为俄语。这句“hello”显然是意大利语。这是法语。不错。而这个嘛，我猜是个比较棘手的例子——我输入了一些西班牙语，也夹杂了一些英语，我想这次西班牙语占了上风。好了，这样你就有个大致印象了。我的意思是，多玩玩这类分类器总是有益的，对吧？因为即便它只是一个分类器，哪怕你可以下载使用、人人都在用，也不代表它总能准确生效。

## 段落 29

**英文**: So I think obviously for short sentences, it's less reliable because there's just less information about what's happening. Low resource languages is tough. There's a worry that for things that don't really are dialects of English, this could be viewed as not English. I think if you want to distinguish between similar languages, that's also can be easily confused and code switching. I don't even know what ground truth is, but it'll do hopefully one of the languages. So just talking to one case, study, open web math, was this this paper from two years ago. And the goal here is to curate a. large corpus of mathematical text, where here I'm saying that, let's assume that math is a language. So first I use some rules to filter, then they train cannellam on this large data set of proof, it's called proof pile, and kept it if the perplexity was below some threshold. And they train this fastest classifier, which we've talked about, to predict mathematical writing.

**中文**: 因此，我认为对于短句而言，其可靠性显然较低，因为其中所包含的关于事件发生情况的信息较少。低资源语言则更为困难。人们担心，对于那些实际上并非英语方言的语言，该系统可能会将其判定为非英语。此外，若想区分相似语言，也容易产生混淆和语码转换问题。我甚至不清楚“真实标签”（ground truth）究竟为何，但希望它至少能识别出其中一种语言。仅以一个案例研究为例——开放网络数学（Open Web Math），即两年前发表的这篇论文。其目标是构建一个大规模的数学文本语料库；此处我们假设数学本身即是一种语言。首先，我们采用若干规则进行筛选；随后，他们在名为“证明集”（Proof Pile）的大规模证明数据集上训练了Canellam模型，并仅保留困惑度低于某一阈值的结果；最后，他们训练了我们此前讨论过的这种快速分类器，以预测数学写作内容。

## 段落 30

**英文**: This is a kind of hacky, but they set the threshold of a classifier if it's identified as math based on rules to be relatively low. And if it's not, it defines math according to rules, it needs to be higher. And as a result, they produce of 15 billion tokens and they train some models that do better, that models that were trained on 20 times more data that weren't really special. So this is kind of. one of the nice examples of the utility of data filtering. You could train on all this data, but if you care about, let's say, a particular domain like math, you can just go out and get more of it and target that data set. And if you train on that, you can be much more data efficient. Okay, so let's talk about quality filtering. So quality filtering obviously is something that is, doesn't really, I mean, it's a catch-all for a bunch of things and what is quality. So remember that some papers explicitly don't use model-based quality filtering, but more recent papers have just kind of given in and say, well, it just works a lot better.

**中文**: 这是一种略显取巧的做法：当依据规则判定一段文本属于数学领域时，他们将分类器的阈值设得相对较低；而当文本未被规则判定为数学内容时，则需要更高的阈值才能将其归为数学。结果，他们仅使用150亿个词元便训练出若干性能更优的模型——这些模型的表现甚至超过了那些在20倍数据量（且并无特殊处理）上训练的模型。这正是数据过滤效用的一个典型范例：你本可以利用全部数据进行训练，但若关注特定领域（例如数学），则可专门搜集更多该领域的数据并构建针对性的数据集；在此类数据上训练，能显著提升数据利用效率。  
好，接下来我们谈谈质量过滤。显然，“质量过滤”本身是一个涵盖性概念，实际包含多种不同操作，而“质量”的定义也较为模糊。需注意的是，部分早期论文明确不采用基于模型的质量过滤方法；但近期多数研究已基本默认接受该方法，理由很简单：它确实效果更好。

## 段落 31

**英文**: So GPT-3, we talked a little bit about this last time, trained a quality classifier by taking. positive samples from the high-quality sources that they had, or rather the non-common-crawl sources they had, and negatives are just common-crawl that train a linear classifier and keep documents sarcastically based on this score, which is something that just turns numbers, basically sort of sharpens the threshold. And the first llama paper, they use pages referenced by Wikipedia, so not Wikipedia as positives, negatives are just sampled from common-crawl, and then they keep documents that are classified positive. I don't think there was actually sampling in that, which is interesting. Phi1 is another paper that their philosophy was kind of interesting. They really want a high-quality data that looked like textbooks, and they want to train a very small. model. So they trained on synthetic data, but also filter data, so for the filter data what they did is they took the Python subset of the stack. Remember the stack is this pre-processed dataset coming from GitHub of code, and then they defined a prompt, which effectively asked GP4 to determine the educational value for a student whose goal is to learn basic coding concepts. And then they prompted GP4 and classified 100K documents from this Python subset, and that became the positive examples.

**中文**: 因此，GPT-3（我们上一次已略有提及）通过以下方式训练了一个质量分类器：以高质量数据源（即非Common Crawl来源）中的样本作为正样本，以Common Crawl数据作为负样本，训练一个线性分类器，并依据该分类器输出的分数对文档进行筛选——这本质上只是对数值打分并相应地收紧筛选阈值。首篇Llama论文则采用被维基百科引用的网页作为数据源（注意：并非直接使用维基百科本身作为正样本），负样本则直接从Common Crawl中采样，随后仅保留被分类为正样本的文档。我印象中该方法实际上并未进行采样，这一点颇为有趣。另一篇Phi1论文所持理念也颇具特色：其目标是获取高度优质的、类似教科书风格的数据，并训练一个极小规模的模型。为此，他们既使用合成数据进行训练，也对真实数据进行过滤。在数据过滤环节，他们选取了“Stack”数据集中的Python子集（需说明：“Stack”是源自GitHub、经预处理的代码数据集），并设计了一个提示词，要求GPT-4评估某段代码对一名旨在学习基础编程概念的学生所具有的教育价值；随后，他们利用该提示词驱动GPT-4对上述Python子集中的10万份文档进行了分类，这些被GPT-4判定为具有高教育价值的文档即成为正样本。

## 段落 32

**英文**: They trained a random forest classifier on these examples where the embeddings fed into a random classifier were from some pre-trained co-gen model, and then they selected data from R that is classified by the classifier. So they. run the classifier then overall of R and then get that data. So this is kind of interesting because there is a random forest classifier, and in this case where does T come from? Well T doesn't exist April, it comes from prompting GP4 with some prompt. So this is something that you'll see more increasingly as the models get better, is that instead of looking at sources like well, maybe books 1 is great, or maybe web Wikipedia is great. Now if you have a good model, you can just ask the model to for the type of data you want. Maybe I want more chemistry data, or I want more mathematical data that does a lot of proofs, or elementary math, or something. And you just let the language model, a fairly sophisticated language model, give you T, and now once you have T,. you turn the recipe that we've been talking about so far. So the final result, again, looks good.

**中文**: 他们利用这些样例训练了一个随机森林分类器，其中输入该随机森林分类器的嵌入向量来自某个预训练的共生成（co-gen）模型；随后，他们从数据集R中选取被该分类器判定为符合要求的数据。具体而言，他们先运行该分类器对整个R进行预测，再据此获取相应数据。这一做法颇具启发性，因为其中涉及一个随机森林分类器；而在此场景下，T又从何而来呢？实际上，T并非预先存在——它源自向GPT-4模型输入特定提示（prompt）后所生成的结果。随着大语言模型性能不断提升，此类做法将日益普遍：人们不再局限于依赖传统数据源（例如某本经典书籍或维基百科网页），而是可直接借助优质模型，向其提出明确需求以生成所需类型的数据——例如，我可能需要更多化学领域数据，或侧重数学证明的数据，或面向初等数学的数据等。此时，只需交由一个相对成熟的语言模型来生成T；一旦获得T，便可沿用我们此前一直讨论的流程。最终结果再次展现出良好效果。

## 段落 33

**英文**: So they had a baseline where they just took the Python subset of a stack, which is this R, and the performance on human dev out, which is a coding data set, was only 12% after 96 case types of training, and then they trained the exact same model architecture on this new fancy data set, and it was already at 17 after 36. So they declared success. Okay, so these are some examples of quality filtering. Any questions about quality filtering? Yeah. Yeah, so the point is that you can, why can you get away with using GPT-4 here? Because you're using it only on to create 100k examples, and to create, and then using that to distill a classifier,. which is much faster. And the 100k is much less than the size of R, which is, you know, tens or hundreds of millions probably. Okay. So let's talk a bit about toxicity filtering. So I'm going to talk about how the DOMA paper does toxicity filtering.

**中文**: 因此，他们首先建立了一个基线：仅采用堆栈中Python子集（即该R数据集），在人类开发人员测试集（一个编程数据集）上的性能仅为12%（经过96种案例类型的训练）；随后，他们使用同一模型架构在这一全新的高质量数据集上进行训练，仅经36种案例类型训练后性能便已提升至17%。于是他们宣布取得成功。  
好的，以上是一些质量过滤的示例。关于质量过滤，大家有什么问题吗？  
是的。是的，关键点在于：为何此处可以放心使用GPT-4？原因在于，我们仅用它生成10万条样本，再利用这些样本蒸馏出一个分类器——而该分类器运行速度要快得多；且这10万条样本数量远小于R数据集的规模（后者很可能达数千万甚至上亿条）。  
好的，下面我们来简要讨论毒性过滤。我将介绍DOMA论文中所采用的毒性过滤方法。

## 段落 34

**英文**: So there's this data set called Jigsaw Toxic Comments, and this came out of project where they were trying to help people have better discussions online, so they wanted to build a classifier that could identify when there was problematic content. So they took the data comments on the Wikipedia talk pages and annotators annotated them with toxic, severe toxic obscene threat, and so I didn't hate. And so the DOMA folks trained two. facets classifiers, one, which is basically, you know, of course, why not hate, and the other one is of course, why not to NSFW. And so here's some examples of the, you know, of the, you know, data set. So let's download the model and try it out. So the first example, you know, are you threatening me for disputing neutrality? This gets classified as safe for work because I mean, seems fine. And the second one is flagged as NSFW. And these sentences are both fine. Okay.

**中文**: 因此，存在一个名为“Jigsaw恶意评论”的数据集，该数据集源自一项旨在帮助人们在线开展更良性讨论的项目。为此，项目方希望构建一个分类器，以识别存在问题的内容。他们采集了维基百科讨论页上的评论，并由标注人员对这些评论进行了标注，类别包括“恶意”“严重恶意”“淫秽”“威胁”等。而我并不讨厌这些内容。于是，DOMA团队训练了两个分类器：一个自然是“为何不厌恶”，另一个自然是“为何不归为不宜工作场合浏览（NSFW）”。以下是一些该数据集中的示例。现在我们下载模型并试用一下。第一个例子是：“你因我质疑中立性就威胁我吗？”该句被判定为“适合工作场合浏览”，因为从表面看并无不妥；而第二个例子则被标记为“不宜工作场合浏览”。但事实上，这两句话本身都是完全正常的。

## 段落 35

**英文**: So just give you a sense. I don't want to show too many of these examples, but you get the idea. You can play it on with your own time. Okay. So that's all say about filtering. So now let's talk about the duplication. So there's two types of duplicates, exact duplicates. And the thing that. realizes that the web actually just inherently has a lot of exact duplicates based on mirroring. So if you just look at Project Gutenberg, you know, you'll see that, you know, the same exact site gets mirrored on a bunch of different URLs.

**中文**: 所以，仅以此为例，让您有个大致了解。我不想展示太多此类示例，但您应该已经明白其中含义了。您可以自行花时间深入探索。好的，关于过滤就讲到这里。接下来我们谈谈重复内容问题。重复内容分为两类：完全重复的内容，以及……需要指出的是，网络本身由于镜像机制而天然存在大量完全重复的内容。例如，仅以古腾堡计划（Project Gutenberg）为例，您就会发现同一网站内容被镜像到了大量不同的URL上。

## 段落 36

**英文**: So if you're just crawling as common crawl does, it has no way knowing that these are mirrors, you know, just get you the exact same content. And then there's new duplicates, which is basically the same text that differ by a few tokens. And we're going to show you algorithms that deal with both. So new duplicates, when does this happen? Well, you have terms of service and licenses like the MIT license. This thing shows up. I don't know how many times on the web is just copy and paste it everywhere. Maybe there's even, I know,. maybe people take it and actually change some things or they mess up copy and paste it and remove a comma or something. That's all possible. And then there's cases, if you look at these these datasets, you know, new duplicates are, it just gives you an idea of what new duplicates might look like.

**中文**: 因此，如果你只是像Common Crawl那样进行常规网络爬取，就无法识别这些镜像站点——它们提供完全相同的内容。此外还存在“新重复内容”，即文本主体基本一致，仅在少数词元（tokens）上存在差异。接下来我们将向您介绍处理这两类问题的算法。“新重复内容”通常在哪些情况下出现呢？例如，网站上的服务条款或开源许可证（如MIT许可证）就属于典型情况：这类文本在网络上被反复复制粘贴，次数之多难以估量；甚至有人会对其进行少量修改，比如改动个别措辞，或在复制粘贴过程中误删一个逗号等，诸如此类的情况均有可能发生。再者，若您查阅相关数据集，便可直观了解“新重复内容”的具体表现形式。

## 段落 37

**英文**: Sometimes you have this article where someone just seem to have paraphrased, best actor in a negative role for most impactful character, but everything else seems the same. This is just like missing a comma here, not really sure how where that comma went off to, but you know, there could be like just annotator or processing errors. And then this one's kind of interesting. There's clearly this very kind of ad like a text, which they just replace Canada. with USA and some other flight. So this probably is generated from some sort of template system where they slotted in entities. So, you know, these new duplicates are obviously different, but obviously if you train on tons of, you know, this, once you have this document, this one doesn't give you that much value. Let's just put it that way. So in extreme case, so if you look at C4, remember C4 was filtered based on the set of rules that looked for sentences that looked like English, you'll see this sentence, which is indeed English, that shows up astonishing 61,000 times. And for whatever reason, if you actually trace down where this comes from, not MIT license, I have to, what? Okay.

**中文**: 有时你会遇到这样一篇文章，其中有人似乎只是进行了改写，比如将“最佳反派角色演员”改为“最具影响力角色的最佳演员”，但其余内容却完全相同。这就像此处漏掉了一个逗号——我们不太确定那个逗号究竟去哪儿了，但你知道，这很可能是标注员或处理过程中的错误。而这一篇则颇为有趣：文中明显存在一段类似广告的文本，他们仅将“Canada.”替换为“USA”及某些其他航班信息。因此，该文本很可能源自某种模板系统，其中仅替换了实体。所以，这些新生成的重复文本显然彼此不同，但显然，如果你用海量此类数据进行训练，一旦已有该文档，那么这一篇便几乎无法提供额外价值——我们姑且如此表述。在极端情况下，以C4数据集为例：请记住，C4是依据一套规则进行过滤的，该规则旨在识别看似英文的句子；而你将发现，下面这个句子确为英文，却惊人地重复出现了61,000次。无论出于何种原因，若你实际追溯其来源，结果并非MIT许可证——我必须……什么？好吧。

## 段落 38

**英文**: Do I show you accept these cookies? Okay, fine. This is like random product from Amazon that has graffiti masterines and, you know, there's this text. And apparently this is for whatever reason, I, you know, I don't even know how there's 61,000 copies of this, but that's, that's what it is. And, and so the idea is that this text isn't necessarily back, right? It's perfectly good English. But you don't want to like take 61,000 epochs over this, I mean, it's just, you know, kind of pointless. So, detuplication is sort of complementary to quality filtering. Quality filtering says this piece of data, I don't want to ever train on it. Detuplication says, well, this is might be fine, but I only want a small number of these, rather than 61,000 copies. So, there's a mark showing that detuplication makes language. models better.

**中文**: 我是否向您显示“接受这些Cookie”？好吧，没问题。这就像亚马逊上随机的一款产品，上面印有涂鸦风格的铭文，您看，这里还有段文字。而显然，出于某种原因——说实话，我甚至都不明白为何竟有61,000份这样的副本——但事实就是如此。因此，关键在于：这段文字本身并非质量低下，对吧？它的英文完全规范、地道。但您肯定不想针对它训练61,000个轮次，这纯粹是徒劳无功。因此，去重与质量过滤互为补充：质量过滤意味着“这类数据我绝不会用于训练”，而去重则意味着“这类数据或许尚可接受，但我只需保留少量样本，而非多达61,000份重复副本”。已有实证表明，去重能提升语言模型性能。

## 段落 39

**英文**: The first, most obvious thing is that you can train more efficiently, right? Detuplication reduces the number of tokens, and if you haven't throw away information, then you can save a lot of effort. And then the second is that you can also avoid memorization. So, we haven't really talked about this, but language models trained on data, can memorize that data, which is bad for, you know, copyright or privacy reasons, because it can re-gurgitate the training set. And detuplication is one tool. It's not definitely not perfect, but it can help mitigate some of these risks. Okay, so, here's how to think about detuplication in terms of design space. So, first, you have to think about what is the unit that you're detuplicating? What. is an item? Is it a sentence? Is it a paragraph? Is it a document? The second question is, how do you match? Do you, what is considered a duplicate? Is it an exact match? Is it a fraction of common sub items? And then the final thing is, what action do you take? Do you remove all the instances, or do you remove all about one? Okay, so, so the key challenge, and this is an algorithmic challenge, is that fundamentally detuplication is about comparing items to other items. Right, if you quality classification, you can take an item, you can classify as high quality or not. Detuplication is fundamentally a pairwise thing, and remember, these data sets are large, so you can't, if you're trying to do something quadratic, that's kind of a no-go.

**中文**: 首先，最明显的一点是，你可以更高效地进行训练，对吧？去重能减少词元（token）数量；只要没有丢弃有用信息，就能节省大量计算资源。其次，去重还能避免模型对训练数据的机械记忆。我们此前尚未深入讨论这一点，但需注意：语言模型在训练数据上训练时，可能直接记住这些数据——这会引发版权或隐私方面的严重问题，因为模型可能原样复现训练集内容。去重是应对此类风险的一种手段：它虽非万全之策，但确实有助于缓解部分风险。

那么，如何从设计空间的角度理解去重呢？首先，需明确去重的基本单位是什么？即“一项”（item）究竟指什么？是一个句子、一个段落，还是一整篇文档？其次，需确定匹配标准：何为重复？是要求完全一致，还是允许存在一定比例的共同子项？最后，需决定处理方式：是删除所有重复项，还是仅保留其中一项？

因此，核心挑战——本质上属于算法层面的挑战——在于：去重从根本上依赖于项与项之间的两两比对。相比之下，质量分类只需对单个项独立判断其是否属于高质量；而去重则天然具有成对性（pairwise）。此外，这些数据集规模庞大，若采用时间复杂度为平方级（O(n²)）的算法，实际应用中基本不可行。

## 段落 40

**英文**: So, you need some. sort of linear time algorithm to scale, but still do something that's pairwise. So, the building block of all of this is hash functions. So, hash functions, this is a review, is a function that maps an item, which could be a sentence, could be a document, to a hash value, which is an integer or string. And the value is much smaller than an item, and the thing that's relevant about hash functions is that you could potentially get hash collisions. So, which means that you have two distinct items that map to the same hash value. So, in general, if you've, I'm sure you've all you guess, all you have used dictionaries or hash tables, hash collisions are generally bad, but later we'll see that there actually can be good in some limited doses. There's many types of hash functions, which trade off between efficiency and collision resistance, which means don't collide. There's cryptographic hash functions, which are used for security sensitive applications. Like in Bitcoin, you really don't want collisions, because otherwise, that means someone might steal your money or you could compromise things.

**中文**: 因此，你需要某种线性时间算法来实现可扩展性，同时仍能执行成对操作。而所有这些的基础构件是哈希函数。哈希函数（此处为复习内容）是一种将某个项目（可能是一句话，也可能是一份文档）映射为一个哈希值（通常为整数或字符串）的函数；该哈希值远小于原始项目本身。哈希函数的关键特性在于可能出现哈希冲突，即两个互不相同的项目被映射到同一个哈希值上。通常情况下——我相信大家肯定都遇到过——在使用字典或哈希表时，哈希冲突一般被视为不利因素；但稍后我们会看到，在某些特定、有限的情形下，哈希冲突反而可能带来益处。哈希函数种类繁多，其设计往往在计算效率与抗冲突能力（即避免发生冲突）之间进行权衡。其中，密码学哈希函数专用于安全性要求较高的场景，例如比特币系统：在此类应用中，我们极不希望出现哈希冲突，因为一旦发生冲突，就可能意味着他人能够窃取你的资金，或导致系统安全受到威胁。

## 段落 41

**英文**: And then there's things where, but these are slow. And then there's hash functions, which are generally used for hash tables, that are not collision resistant, but fast. And so, we're generally going to go with the latter category, because we want things to be fast, and we're not doing cryptography here. Okay, so we're going to use a thing called murmur hash, which takes strings and returns,. you know, values. But you can use a bunch of other hash as well. Okay, so let's start with the exact T2 application. So, here's a simple example. The item is just a string, and I want the exact match, and I want to remove all, but one. So, here's a bunch of items.

**中文**: 然后还有一些方法，但这些方法速度较慢。此外还有哈希函数，通常用于哈希表，它们并不具备抗碰撞性，但速度很快。因此，我们通常会选择后一类方法，因为我们追求的是速度，而此处并不涉及密码学应用。好的，我们将采用一种名为 MurmurHash 的哈希算法，它接收字符串并返回相应的哈希值。当然，您也可以选用其他多种哈希算法。好的，下面我们从精确的 T2 应用开始。这里是一个简单示例：待处理项仅为字符串，我需要精确匹配，并且只保留其中一个，其余全部删除。以下是一组待处理项。

## 段落 42

**英文**: And what I'm going to first do is compute a mapping from hash value to the list of items with that hash. So, and then, once I have that, I keep one item from each group. So each group correspond to a hash value. And in the case of exact to, exact match, assuming there's no hash collisions, then you basically do a exact to do. So, hello, shows up twice here, and now shows up once. And of course, hello uppercase exclamation point is just a completely distinct item, because we're doing. exactly. So, the nice thing is that this is very simple. It's clear what you're doing. It's high precision, so you're never going to throw away anything that you didn't need, or you needed.

**中文**: 接下来，我首先会计算一个从哈希值到具有该哈希值的项目列表的映射。然后，在获得该映射后，我从每个组中保留一个项目。每个组对应一个哈希值。在精确匹配的情况下（假设不存在哈希冲突），本质上就实现了精确匹配。例如，“hello”在此处出现了两次，而“now”仅出现一次。当然，“Hello!”（首字母大写并带感叹号）则是一个完全不同的项目，因为我们执行的是精确匹配。这种做法的优点在于：它非常简单，操作意图清晰明确，且精度极高——你绝不会误删任何本应保留或本需保留的项目。

## 段落 43

**英文**: But the con is that it doesn't work for near duplicates. And the other thing is that's nice is that, you know, this is very simple to implement. We kind of wrote this in a map, reduced way, and you can scale it and paralyze it fairly easily. And this is something that C4 uses actually to prepare the dataset. So, their unit is of duplication is three sentence spans, the user exact match, and they remove all of one. So, one thing that is always kind of bother me, but I don't know when else seems to care is that when you're looking at three sentence spans, right? So, you have. this document, and then you have this three sentence span, and if it's marked as a duplicate, you're just going to, you know, do surgery and take those sentences out. And so, the resulting document might not even be coherent, but then people say, you know, who cares, and we're gone. Okay, so, there's another way to do the duplication that is less map reduced, but more, kind of like hatch table. I think the, you know, bloom filters are, you know, some of you might have seen, but just to go through it, because I think it's kind of a cool method.

**中文**: 但其缺点在于无法处理近似重复的内容。另一点好处是，这种方法实现起来非常简单。我们以类似MapReduce的方式编写了该算法，因此可以较为轻松地进行扩展和并行化处理。事实上，C4数据集正是采用这种方法来预处理数据的：其去重的基本单元为三句连续的文本片段，若存在完全匹配，则直接移除其中一份。这里一直让我感到困扰（但似乎其他人并不在意）的一点是：当我们考察三句连续的文本片段时，比如某篇文档中存在这样一个三句片段，一旦被标记为重复内容，系统就会直接将其“切除”。结果可能导致剩余文档内容不再连贯。但人们往往不以为意，只说：“谁在乎呢？”然后就继续推进了。  
此外，还有一种去重方法，它不像MapReduce方式那样依赖分阶段处理，而更类似于哈希表（hash table）的方式。我想大家可能都听说过布隆过滤器（Bloom filter），这里再简要介绍一下，因为我认为这是一种相当巧妙的方法。

## 段落 44

**英文**: So, this is, you know, efficient, and it's approximate. So, you, it's more efficient, but it's, you know, obviously it's not always doing the exact thing, but, you know, we're very, I have not, we,. we are not, you know, being too picky here. Okay, so it's, the nice thing is a very memory efficient, you can update it, but you can't delete. And it's, it's basically a representation of set, where if you ask for set membership, and it returns no, then it's definitely no. But if it returns yes, then, you know, most likely, if you set your hyperparameters, right, it's yes, but, you know, there's a small probability that you have, of, of, no, like you have a false positive. And then you can, you know, say your, your parameters to drive down the false positive rate, if you like. Okay, so just to walk through what this looks like. So, suppose you have five items, the cat, and the hat, and later we'll test out with some items that don't show up in the set. Um, the first thing is you're going to define a hash function that maps to M bins, M is going to be eight here.

**中文**: 因此，这种方法是高效的，但属于近似算法。也就是说，它效率更高，但显然并不总是给出完全精确的结果。不过，我们对此并没有过于苛求。好的，其优点在于内存占用非常少，支持更新操作，但不支持删除操作。它本质上是一种集合的表示方法：当你查询某个元素是否属于该集合时，若返回“否”，则该元素一定不在集合中；若返回“是”，则该元素大概率在集合中（前提是超参数设置得当），但存在较小概率出现误报（即假阳性）。当然，你也可以通过调整参数来降低误报率。下面，我们以一个具体示例来说明其工作原理：假设集合中包含五个元素——“猫”（cat）和“帽子”（hat）等，稍后我们还会用一些未出现在集合中的元素进行测试。第一步是定义一个哈希函数，将其映射到 M 个桶中，此处 M 设为 8。

## 段落 45

**英文**: Um, so to build the bloom filter, um, we're going to do, you know, something fairly simple, you just, um, you make, uh, your bit array, um, with a number of bins, and then go through every item, hash it, the hash is the two. So I update the second item, um, cat hash is the seven, update the seventh item in the hat. Okay, so you just, um, you know, populate this, uh, bit array, and the bit array, I don't keep track of the item. So I have no idea if I have a false positive or not. Um, okay, so let's just sanity check that, um, every item that I put in is actually in the item. So to query it, you just, uh, compute whether that item, uh, hashed is in the table. Um, and indeed, everything should pass. Um, and now, um, let's look at the non-items and see, um, how they fare. And you'll see that, you know, some of the non-items are, you get a zero, which is what you want. Um, but some of the items, the boomfathers says, oh, actually, it's in the, in the set.

**中文**: 嗯，那么构建布隆过滤器时，我们将采用一种相当简单的方法：首先创建一个具有一定数量槽位的位数组，然后遍历每个元素，对其进行哈希运算——例如，“dog”的哈希值为2，于是将位数组中第2个位置置为1；“cat”的哈希值为7，于是将位数组中第7个位置置为1。就这样，我们仅需填充该位数组即可；而该位数组本身并不记录具体元素，因此我无法判断是否发生了误报。好的，我们先进行一次合理性检验：确保所有已插入的元素确实能被正确识别。查询时，只需计算待查元素的哈希值，并检查对应位置在位数组中是否为1。实际上，所有已插入元素的查询结果都应为“存在”。接下来，我们再考察那些未插入的元素，观察其查询结果如何。你会发现，部分未插入元素返回0（即“不存在”），这正是我们所期望的；但另有一些未插入元素，布隆过滤器却错误地判定为“存在”。

## 段落 46

**英文**: So the number of mistakes here is, is four. And if you compute the false positive array, which is the number of mistakes over the total number of times, um, the procedure produced, um, you know, a positive, then the false positive rate is, in this case, you know, 0. 44, which is pretty bad. Um, now, of course, this is a bin 8, and if the bin were to grow, then this would get better. In fact, it grows, there are probability is one over the number of bins. Okay? So, but you look at. this and say, well, that's not really good, because if I want the error probability to be, you know, um, 10 to the minus 10, then I need a lot of bins. And that's not going to hurt on memory. So there's a more clever solution here, which is to use more hash functions. Okay? So let's say I use two hash functions, and I'm going to, essentially, I still have the same, you know, bit array, but for every item now, I'm going to, I use hash it twice.

**中文**: 因此，此处的错误数量为4。若计算假阳性率（即错误数量除以该过程产生“阳性”结果的总次数），则本例中的假阳性率为0.44，表现相当差。当然，当前使用的是8个桶（bin），若桶的数量增加，该指标便会改善；实际上，错误概率为1除以桶的总数。但你观察后会发现，这并不理想：例如，若希望错误概率降至10⁻¹⁰，则需设置大量桶，而这将显著增加内存开销。因此，这里存在一种更巧妙的解决方案——即采用多个哈希函数。例如，我们使用两个哈希函数，仍沿用相同的位数组，但对每个元素均进行两次哈希运算。

## 段落 47

**英文**: So the, under c, 0 gets hash to 2, I'm going to pop it in, and then, um, the, with c'd 1 is going to hash to 5, so I'm going to pop it in there. So every item gets hash into k, not necessarily distinct, but hey, k slots. So then I go through the cat, and then I fill up this, um, you know, table. Okay. So now I, um, when I do the. query, I take an element, and I'm going to return one, if the table set was set to 1 for all k hash functions. Okay? Because if I put it in, I have to set k bits, and so if I'm testing, I need to check the k locations, and, um, check that they were all set. Um, so indeed all of those past, and now let's look at the, um, so the number of, um, you know, mistakes now is 3, um, and the false positive rate, um, decreased. So, you know, that's great. So of course, this is a toy example, but, you know, you can really drive down the false positive rate with, um, modest memory, um, you know, uh, spend.

**中文**: 因此，在参数c下，0被哈希到位置2，我将把它插入该位置；而1则被哈希到位置5，我也将把它插入该位置。每个元素都会被哈希到k个位置（这些位置未必互异），但总共只有k个槽位。接着我遍历所有元素，并填充这张哈希表。好的。那么现在，当我执行查询操作时，我会取一个元素，仅当该元素经全部k个哈希函数计算所得的k个表项均被置为1时，才返回“存在”。这是因为，若该元素曾被插入，则必须将这k个对应比特位全部置为1；因此在查询时，我需要检查这k个位置是否全部已被置为1。确实，所有这些检查都通过了。现在我们来看——嗯，当前错误数为3，而误报率则降低了。这当然很好。当然，这是一个简化的示例，但事实上，仅需适度的内存开销，就能显著降低误报率。

## 段落 48

**英文**: Okay. Maybe I'll, pause there before I go to, um, analyzing this a bit more, you know, formally. Okay. So let's, let's think about what happens more generally. Um, so let's say we have a thousand bins, um, we have 10 cache functions, and we're going to hash, um, 100 items. The question is, you know, what is the false positive rate? And the way to think about this is that I'm going to consider a test input that's not in the set, um, that is going to hash into a particular location, like i. Okay. And then I'm going to, so, um, I'm going to now consider putting items, the n items into the boom filter, and see what is the probability that it hits i? If anything hits i, then that, um, is, is a, is a bad sign. Okay. So let's warm up here.

**中文**: 好的。也许我先暂停一下，暂不正式深入分析这个问题。好的，那么我们来更一般性地思考一下会发生什么。假设我们有一千个桶、十个哈希函数，并要对一百个元素进行哈希。问题是：此时的误报率是多少？思考方式如下：我将考虑一个不在集合中的测试输入，该输入经哈希后落入某个特定位置（例如位置 i）。接着，我将把这 n 个元素插入布隆过滤器中，并考察它们命中位置 i 的概率。只要有任何一个元素命中了 i，这就意味着……这是一个不好的信号。好的，我们先热身一下。

## 段落 49

**英文**: So let's say I'm just, n is one, I'm just inserting one element, and k is also one, so I'm only using one hash function. So now the question is, what is a chance that there's a hash collision, um, between i and whatever element I'm putting in? And the answer to that is just one over the number of bins. Right? Assuming everything's kind of independent, um, that's, uh, going to be, you know, uh, 0. 001. Okay. So now, um, I'm still n is still one, um, but I'm getting to use k hash functions. So then I, essentially, if, um, I'm going to, uh, then the criteria is I have to miss not just one time, you know, but, you know, uh, k times. Okay. So this is a probability I miss one. So one minus that is a probability I, I hit.

**中文**: 假设我只插入一个元素（即 n = 1），且仅使用一个哈希函数（即 k = 1）。那么，现在的问题是：待插入元素与已有元素 i 发生哈希冲突的概率是多少？答案就是 1 除以桶的总数，对吧？在假设所有事件相互独立的前提下，该概率即为 0.001。好的。接下来，n 仍为 1，但我现在可以使用 k 个哈希函数。此时，判定条件就不再是仅需一次未发生冲突，而是必须连续 k 次均未发生冲突。好的，因此这是单次未发生冲突的概率；而 1 减去该值，即为至少发生一次命中（即至少一个哈希函数映射到非空桶）的概率。

## 段落 50

**英文**: And, um, and then that's where k times is a probability I, um, have hit, you know, um, on k, and then one minus that is the probability I, um, you know, uh, have to miss. k times. So now the probability here, uh, goes down, you know, uh, a little bit. Um, okay. So now, um, if I'm inserting n items, so I'm asking the probability that the test bin um, is, is one after n. So now instead of missing k times, I have to miss k times n times. So then basically this, this expression, but just k times n. Um, and finally, um, because the test item is something that, um, I am, you're also hashing. So I get sort of k chances, you know, to miss. So the false positive rate, actually, this is what kind of helps the k really helps is that I can, um, you know, drive down the false positive rate with, with, with k.

**中文**: 此外，k次即表示我命中某值的概率为p，而1减去该概率则表示我未命中的概率，即连续k次未命中。因此，此处的概率会略有下降。好的。那么，若我要插入n个元素，即求测试桶在插入n个元素后仍为空的概率。此时，我需要连续k次未命中的事件重复发生n次，因此上述表达式中的指数应变为k×n。最后，由于测试项本身也需要经过哈希运算，因此我实际上拥有k次“未命中”的机会。因此，误报率——实际上，这正是k值真正发挥作用之处——我可以通过增大k值来显著降低误报率。

## 段落 51

**英文**: So that becomes, um, you know, f goes from point six three to point zero one. Um, the, you can actually look at the expression. f here and compute the optimal value of k, um, given a fixed, you know, ratio, um, as this is sort of asymptotic calculation. And then you find that, um, this results, uh, in k is scaling as order m over n. So the number of hash functions you should use is on order of number of bins over, um, the number of items you're hashing. And if you do that, then f, uh, turns out to be, um, your point five and the false positive rate is point five to the, to the k. So you see that in this particular case, I wasn't optimal, um, because optimal value is actually k equals six. And the false positive rate is 0. 08 as opposed to, um, 0. 0, sorry, 0.

**中文**: 因此，f 的取值范围就变为约 0.63 到 0.01。实际上，你可以观察此处的表达式 f，并在给定固定比值（即该计算本质上属于渐近分析）的前提下，求出最优的 k 值。结果发现，k 的量级为 m/n，即所用哈希函数的数量应与桶（bin）数量除以待哈希元素数量的量级相当。若按此设定，则 f 约为 0.5，而误报率则为 0.5 的 k 次方。由此可见，在本例中先前选取的 k 值并非最优：最优 k 值实际为 6，此时误报率为 0.08，而非之前得到的 0。

## 段落 52

**英文**: 008 rather than 0. 01. Okay, so you can read more about this. There's some lecture notes that allow you to trade off. their computes, um, the memory and the false, uh, positive rate. Okay, so the bloom filter has some hyper parameters that allow you to control, um, whether the, um, you know, what your desire false positive rate is, how much memory you have, how much computer you're willing to put in and so on. Yeah. So you're saying that the optimal k, you know, went down, um, and so why does the f go down? Um, so the, um, let's see. So if the k goes down, um, I think that it's not monotonic. Right? So if you use a smut, very, um, I think if you use a very large value of k, that's actually pretty bad because then you just fill up the, you know, the bloom filter.

**中文**: 008，而不是0.01。好的，关于这一点，您可以进一步查阅相关资料。有一些讲义介绍了如何在计算量、内存占用和误报率之间进行权衡。好的，布隆过滤器具有一些超参数，使您能够控制所需的误报率、可用内存大小以及愿意投入的计算量等。是的，您提到最优的k值下降了，那么为什么误报率f也随之下降呢？我们来看一下：如果k值减小，我认为其关系并非单调的。对，例如，若k值过大，实际上效果反而很差，因为这样会迅速填满整个布隆过滤器。

## 段落 53

**英文**: Um, and if you use too small, that's also not very good either. So I think there's a sort of a optimum and whether it goes down. or up depends on which side you're on. Okay, so in DOMA, um, they set the false positive rate to, um, 10, um, to the minus 15th and they use a bloom filter to do their exact, uh, de duplication. Um, and they did it at the paragraph, uh, level. Okay. So that was exact de duplication. And the problem with exact de duplication is that it doesn't capture some of these near misses where morally it's a duplicate, but, um, we are not able to detect it. So now how do you do approximate set membership? Um, and to talk about approximate set membership, you need a notion of a similarity measure. So one common one that's used is jacard similarity.

**中文**: 嗯，而且如果使用的值过小，效果同样不好。因此，我认为存在一个最优值，而该值是上升还是下降，则取决于你所处的哪一侧。好的，那么在DOMA中，他们将误报率设定为10的负15次方，并采用布隆过滤器（Bloom filter）来实现精确的去重操作，且该操作是在段落级别上进行的。好的，这就是精确去重。而精确去重的问题在于，它无法识别出某些“近似重复”的情况——即从语义上讲它们本质上是重复内容，但我们却无法检测出来。那么，我们该如何实现近似集合成员判定呢？要讨论近似集合成员判定，就需要引入相似度度量的概念。其中一种常用的方法是杰卡德相似度（Jaccard similarity）。

## 段落 54

**英文**: So the jacard of two sets, A and B, is a ratio of their intersection over. the union. So as an example, if I have one, two, three, four and one, two, three, five, um, if you compute the jacard, um, the, the intersection has size three, the union has size five, and therefore the jacard is, uh, 0. 6. Okay. So we're going to say that two documents are near duplicates if their jacard similarity exceeds some threshold. And generally the threshold will be, you know, fairly high, like 0. 9, um, if you want to only, you know, match if you're like missing a comma or something. Now notice that there's nothing semantic about this. You could be, um, you're missing a word like not, and of course that changes the meaning completely or some content word, but, um, this is just trying to get documents that look fairly superficially, um, similar.

**中文**: 因此，两个集合A和B的杰卡德相似系数（Jaccard）等于它们交集的大小除以并集的大小。举个例子，若集合A为{1, 2, 3, 4}，集合B为{1, 2, 3, 5}，则其交集大小为3，并集大小为5，因此杰卡德相似系数为0.6。好的。我们定义：若两份文档的杰卡德相似系数超过某一阈值，则称其为近似重复文档。该阈值通常设得较高，例如0.9——这样仅当文档间差异极小（如仅遗漏一个逗号等）时才视为匹配。需要注意的是，该方法完全不涉及语义：例如，你可能遗漏了“不”（not）这样的否定词，这显然会彻底改变句意；又或遗漏某个实义词，但该方法仅旨在识别表面形式上较为相似的文档。

## 段落 55

**英文**: Now the, the algorithmic challenge is how do you find near duplicates in linear time? Okay, so to work up to that, we're going to try to rewrite the jacard similarity, which again is a pairwise, you can't compute your card of one element, you can only compute it if you have two elements, and I'm going to try to write it in terms of a hash function, which you can compute in terms of one element. Okay, so there's a, there's a hash function called min hash, um, which has the nice property that the probability of a hash collision is exactly jacard AB, right? So normally, remember, you think of hash collisions as, you know, to be avoided at all costs, you really don't like them, but here, um, it's not that you want more hash collisions, it's just that hash collisions. are something that you want to control for. You want just the right level of hash collisions, a governed by the similarity. So the problem, again, just to say that, probably the similarity is equal to the probability of collision. So the more similar two things are, the more they should collide. So that's the intuition. Um, okay, so, so min hash is defined as follows, you take a set and you hash, um, all of these elements, remember these return numbers, and you just take the min element. So, you know, in my, at first glance, if you haven't seen this, it's like kind of not obvious why, uh, just taking the min actually gives you this property of expectation equal to the jacard, um, but the argument is actually fairly, you know, simple. So the way to think about.

**中文**: 现在，算法上的挑战是如何在线性时间内找出近似重复项？好的，为了引出这一问题，我们将尝试重写杰卡德相似度（Jaccard similarity）。需要再次强调的是，杰卡德相似度是一种成对度量——你无法仅凭单个元素计算其杰卡德值，而必须同时拥有两个元素才能计算。接下来，我将尝试用哈希函数来表达它；该哈希函数可仅基于单个元素进行计算。好的，这里有一种名为“最小哈希”（min-hash）的哈希函数，它具有一个优良性质：两个集合发生哈希碰撞的概率恰好等于它们之间的杰卡德相似度。通常，我们总认为哈希碰撞应不惜一切代价避免，因为它是不受欢迎的；但在此场景下，并非追求更多哈希碰撞，而是希望对哈希碰撞加以控制——即让碰撞发生的概率恰如其分，由两者的相似度所决定。换言之，相似度就等于发生碰撞的概率：两个对象越相似，发生碰撞的概率就越高。这就是其基本直觉。好的，那么最小哈希定义如下：对一个集合中的所有元素进行哈希运算（注意这些哈希值均为数值），然后取其中最小的哈希值。初次接触时，若此前未见过该方法，你可能会觉得仅取最小值为何竟能保证期望值等于杰卡德相似度，这一点并不显然；但实际上，相关论证相当简洁明了。理解它的关键思路如下：

## 段落 56

**英文**: is that you have your five items and you have two sets, and I'm going to look at, um, this sort of, Kerr-Sukh-Mesh-Sukh's representation. Um, so a has one two three four, b has one two three five. Um, and now the random hash function, um, induces a permutation over the items. So permutation by b three two one four five, for example, this hash function right there. And now let's look at which item is first in a, um, and which item is first in b? Okay. Um, so that corresponds to the, you know, the item corresponding to the minimum hash. And the item, uh, each item has the same probability as, um, you know, being first because it's the hash function you're assuming has, you know, it's, it's a random. So if one, two, or three are first, then the, the min hash is actually going to be. the same, right? Because the minimum, um, if these are, you know, first, um, the minimum here is, um, equal to the minimum, no, here, right? But if the minimum, if the first, uh, the minimum hash is four or five, then the first in a will not be the first in, um, b and the min hash will be different. Okay.

**中文**: 即你有五个元素和两个集合，我将考察——嗯——这种克尔-苏赫-梅什-苏赫（Kerr-Sukh-Mesh-Sukh）表示法。嗯，集合a包含元素1、2、3、4，集合b包含元素1、2、3、5。嗯，现在该随机哈希函数在所有元素上诱导出一个排列；例如，该哈希函数所对应的排列为b: 3、2、1、4、5。接下来，我们观察：在集合a中排在最前面的元素是哪一个？在集合b中排在最前面的元素又是哪一个？好的。嗯，这实际上对应于——你知道的——最小哈希值所对应的元素。而每个元素排在最前面的概率均等，因为该哈希函数被假定为随机的。因此，若1、2或3排在最前面，则两集合的最小哈希值将相同，对吧？因为此时最小哈希值——你知道的——若这些元素排在最前，那么此处的最小值就等于彼处的最小值，没错吧？但若最小哈希值对应的是4或5，则集合a中最靠前的元素便不会与集合b中最靠前的元素相同，此时两集合的最小哈希值也将不同。好的。

## 段落 57

**英文**: And then now you can say see that the probability of the min hash being equal is exactly one, two, or three, which is identically, exactly the intersection. Okay. So if you're in the intersection and that item is first, then you're going to get a collision. And if you're not in the intersection, then that one being first, you'll not get a collision because you're going to get the min for one of them and you're going to get some other value for the other one. Okay. All right. So, um, you can check. this empirically if you don't believe me. Um, so generate a thousand, um, I guess we're running this on a and b, um, and checking what's the probability that the, you get a collision and it turns out the estimated jacard is 0. 6.

**中文**: 然后，现在你可以说：最小哈希值相等的概率恰好为一、二或三，这与交集的大小完全一致。好的。因此，如果你处于交集之中，且该元素排在最前面，那么你就会发生哈希碰撞；而如果你不在交集之中，那么即使该元素排在最前面，也不会发生碰撞，因为你将得到其中一个集合的最小哈希值，而另一个集合则会得到不同的值。好的。那么，嗯，如果你不相信我，可以通过实验来验证这一点。嗯，比如生成一千组数据——我们假设是在集合a和b上运行——并统计发生碰撞的概率，结果发现估计出的杰卡德相似度为0.6。

## 段落 58

**英文**: It's not exactly 0. 6. I think there's some rounding, but, you know, it's, it's pretty close. Okay. So now we've taken the jacard similarity, which is the perifice function, and reduced it to some probabilistic, um, you know, uh, unary function, just on, on item. But this is actually, you know, we're far from done because now we can hash our items, but a collision doesn't tell us that these two are similar. Right. It's just like more likely that more similar things will be hashed together, but we want something a bit stronger here. So this is where locality sensitive hashing comes, um, and so right now, so far, we just have a hash function that, um, takes two, um, you know, hashes sets and the sets will collide if with probability jacard. Um, but we really want a and b to collide if and only if, ideally, if, uh, the jacard, of a and b is exceeding some threshold.

**中文**: 它并不完全是0.6，我认为这里存在一些四舍五入，但总体而言已非常接近。好的。因此，我们已将Jaccard相似度（即该精度函数）简化为某种概率性的、仅作用于单个项的一元函数。但实际上，我们离完成还很远，因为尽管现在可以对各项进行哈希处理，但哈希碰撞本身并不能说明这两项是相似的——它仅仅意味着相似度越高的项被哈希到同一位置的可能性越大。而我们在此处需要的是更强的保证。这正是局部敏感哈希（LSH）发挥作用的地方。目前，我们仅拥有一个哈希函数：它对集合进行哈希，且两个集合发生碰撞的概率恰好等于它们的Jaccard相似度。但我们真正希望的是：当且仅当集合a与b的Jaccard相似度超过某一阈值时，a与b才发生碰撞。

## 段落 59

**英文**: So somehow you have to sharpen the probabilities, right. You want to say that if the jacard is over the threshold, then with almost a probability one, they're going to be hashed together, and if you'd be low threshold, then with basically probability zero or very small. Um, so, you know, how do we do this? Um, it's sort of taking kind of the same trick, which is using more hash functions. Um, and here the construction is you're going to. break up your n hash functions into b bands of our hash functions. So for example, if you have 12 hash functions, um, and three bands and, uh, each band would have four hash functions. So you have h one through h four, h five through h eight, h nine through h 12. Okay, and then we're just going to declare that a and b are going to collide if for some band all of its hash functions return the same value. Okay, so if I have a and b, I'm going to hash, uh, using all 12 hash functions for both a and b using the min hash. And now I'm going to say if this band, for example, if the hash values for h one h two h three inch four, I'll agree that they're going to collide or this band or this band.

**中文**: 因此，你必须以某种方式提高概率的精确度，对吧？也就是说，你想表达：如果杰卡德相似度超过某个阈值，那么它们几乎必然会被哈希到同一个桶中；而如果杰卡德相似度低于该阈值，则它们被哈希到同一桶中的概率基本为零或极小。那么，我们该如何实现这一点呢？其思路与之前类似，即使用更多的哈希函数。具体构造方法是：将全部 n 个哈希函数划分为 b 个“带”（band），每个带包含 r 个哈希函数。例如，若共有 12 个哈希函数，划分为 3 个带，则每个带包含 4 个哈希函数，即第一带为 h₁ 至 h₄，第二带为 h₅ 至 h₈，第三带为 h₉ 至 h₁₂。接着我们定义：当且仅当存在某个带，使得 a 和 b 在该带内所有 r 个哈希函数上的哈希值完全相同时，a 和 b 发生碰撞。具体而言，对 a 和 b 分别使用全部 12 个最小哈希（MinHash）函数进行哈希计算；然后判断：若在某一带（例如第一带 h₁–h₄）中，a 和 b 的哈希值全部相同，则判定二者发生碰撞；同理，若第二带或第三带满足该条件，也同样判定为碰撞。

## 段落 60

**英文**: Okay, so there's a sort of an or structure, which is the key to, you know, making sharpening. the probabilities around the threshold. Okay, so, um, now we just have to, you know, do some analysis to calculate what is the probability that a and b collide. Okay, so similar, I'm going to use sim to refer to the jacquard, so, uh, similarity. Um, so, um, okay, so I'm going to say, let's say I have jacquard similarity of, uh, 0. 8. In that case, I'm going to have five bands each band has, 10 hash functions, so total of 50 hash functions. Um, so what is the probability of a fixed band your matching? So probably a fixed band matching is simply, you know, 0. 8 to the r, right? Because a probability of hash, a single hash function is just the jacquard, which is 0. 8.

**中文**: 好的，这里存在一种“或”结构，这正是实现阈值附近概率锐化的关键。好的，那么现在我们只需进行一些分析，来计算a和b发生碰撞的概率。好的，类似地，我将用“sim”来表示杰卡德相似度（即相似度）。好的，假设我有两个集合的杰卡德相似度为0.8。此时，我将其划分为5个带（band），每个带包含10个哈希函数，总共50个哈希函数。那么，某个特定带完全匹配的概率是多少呢？某个特定带完全匹配的概率即为0.8的r次方，对吧？因为单个哈希函数匹配的概率就等于杰卡德相似度，即0.8。

## 段落 61

**英文**: And now what's the probability of that sum band matches? Well, it's a probability that, um, you know, that one fixed,. this is the probability that, uh, of fixed band, um, doesn't match. And this is a probability that, you know, all of them don't match. And then so this is probably at least one matches. Okay, so now, you see the probability collision is, you know, 0. 4, um, you know, three. Okay, so it's kind of reshaping this probability, um, ability. Before, if you have one hash function, if B and R is one, then, um, the probability would be of collision would be 0. 8. And now it's, uh, you know, 0.

**中文**: 那么，该和值带匹配的概率是多少呢？实际上，这是指某一个固定带不匹配的概率，而这是指所有带都不匹配的概率，因此这便是至少有一个带匹配的概率。好的，现在您可以看到碰撞概率约为0.43。也就是说，这种概率在某种程度上被重新调整了。此前，若仅使用一个哈希函数（即B和R均为1），则碰撞概率为0.8；而现在，该概率则为0。

## 段落 62

**英文**: 3. Okay, so, you know, that's, but let's, um, I guess here's a picture you should have in your head. So on the x-axis is similarity. And what we want is the mapping from similarity to probability of collision to look something. like that. If the threshold is, the desired threshold is, you know, 0. 5. And I want everything down here to be, you know, near zero and everything up here to be near one. So let's see, uh, what this looks like. I'm going to set, um, um, for various similarity values.

**中文**: 3. 好的，那么，您知道，虽然如此，但让我们——嗯，我想您头脑中应该有这样一幅图景：横轴表示相似度，而我们希望将相似度映射为碰撞概率的函数曲线大致呈这种形状。如果设定的阈值（即期望阈值）为0.5，那么我希望阈值以下的所有值都接近零，而阈值以上的所有值都接近一。那么，我们来看看这具体是什么样子。我将针对不同的相似度值进行设定。

## 段落 63

**英文**: I'm going to set B equals 10, R equals 10. And notice that what this happens is that it squashes down some of these low probabilities and then it sharpens some of these high probabilities. Okay, um, but, you know, maybe I want to make this a little bit sharper. Um, so what I'm going to do is to increase R from 10 to 20. And what that does is that moves the curve to the right, um, to make it harder to match and also sharpen this threshold. So if I do that, then you'll see that now these probabilities go. up and now, um, these probabilities are much smaller, right? So in before, um, even a 0. 7 probability, some 0. 7 similarity had, um, your probability of 0. 24, which is, you know, kind of high.

**中文**: 我将设B等于10，R等于10。注意，这样做的效果是压低部分较低的概率值，同时增强部分较高概率值的区分度。好的，嗯……但也许我希望让这种区分更明显一些。因此，我将把R从10提高到20。这一调整会使曲线向右移动，从而提高匹配难度，并进一步锐化该阈值。若如此操作，您会发现此时这些概率值上升了，而那些概率值则显著变小了，对吧？例如此前，相似度为0.7时，对应概率高达0.24，这其实已相当高了。

## 段落 64

**英文**: I really don't want this. So I want to squash this. So in squashing that, I can now get it down to, you know, 0. 007, which is, you know, pretty good, I guess. Um, but now I've also squashed, some of these probabilities. And the goal isn't to shift everything to the right, otherwise I might as well do exactly due to duplication. So now there's another trick if I increase B, which is a number of buckets or bins, um, then I can, um, essentially get these probabilities like 0. 9 to be in the 90s now. And these probabilities are still fairly low. Okay.

**中文**: 我真的很不想要这种情况，所以我希望对其进行压缩。通过这种压缩，我现在可以将其降至约0.007，这应该算是相当不错了。嗯，但这样一来，我也压缩了其中一些概率值。而我们的目标并非将所有值整体右移，否则干脆直接进行重复操作就好了。因此，这里还有另一个技巧：如果我增加桶（或区间）的数量B，那么原本为0.9的概率值现在就可以落在90多的区间内，而其他概率值依然保持相对较低的水平。好的。

## 段落 65

**英文**: So this picture shows that as. you increase B, I get to shift this curve to the left. So increasing R will sharpen the curve and move things to the right. And then increasing B will shift the curve to the left so that you can, with appropriate sending of B in R, you can get your like really sharp sigmoid. Okay. So just an example of what this looks like in practice. So there's this, um, paper that we saw last time that, uh, uses a near duplicate, uh, near duplication, um, using minhas minhash lsh, um, and, uh, their values, um, B equals 20 and R equals, uh, 450. So this R is large, which means that they want to really, um, serve threshold. So, um, there's a formula which you can, um, compute, which, um, says the threshold is 0. 99.

**中文**: 因此，这张图表明：随着B值的增大，该曲线会向左移动。而增大R值则会使曲线变得更陡峭，并向右移动。接着，增大B值又会使曲线向左移动；因此，通过适当调节B和R的取值，便可得到非常陡峭的S型曲线（sigmoid）。好的，下面举一个实际应用中的例子：上次我们看到的那篇论文中，采用近似重复检测（near duplicate detection）方法，具体使用的是MinHash局部敏感哈希（LSH）技术，其参数设定为B=20、R=450。此处R值较大，意味着他们希望阈值非常高。事实上存在一个计算公式，可据此算出该阈值为0.99。

## 段落 66

**英文**: Okay. So that means, um, for every 100 words, you can only. allow basically one word to be, you know, different. So this is fairly, you know, strict deduplication. And, uh, the probability that, uh, um, you know, fixed band matches is, um, you know, this to the R, which is 0. 05. And then the probability of collision is, um, 0. 64. So one thing that's interesting is that, um, I'm computing the probability of collision at the threshold. So in some sense, you know, that should be somewhere in between 0.

**中文**: 好的。也就是说，每100个词中，最多只允许一个词不同。因此，这是一种相当严格的去重方式。而固定带匹配的概率为0.05的R次方，即0.05；碰撞概率则为0.64。值得注意的一点是，我所计算的是在阈值处的碰撞概率，因此从某种意义上说，该值应介于0和1之间。

## 段落 67

**英文**: 01. And it turns out it converges to 1 minus 1 over e, which is, you know, around, you know, 0. 6 ish. Okay. So around the threshold, you know, you could go either way. But as soon as you go above the threshold, you have very high probability of being in a collision. And below the threshold, you have very. low probability of being, uh, in a collision. Okay. So, um, so with that, I'm going to, you know, summarize, um, actually, maybe I'll ask, uh, if there's any questions about deduplication.

**中文**: 01. 结果表明，该值收敛于 $1 - \frac{1}{e}$，也就是大约 0.6 左右。好的。因此，在阈值附近，结果可能偏向任一方向；但一旦超过该阈值，发生碰撞的概率就非常高；而低于该阈值时，发生碰撞的概率则非常低。好的。那么，基于以上内容，我将进行总结——不过在此之前，或许我先问问大家，关于去重（deduplication）是否还有任何问题？

## 段落 68

**英文**: Um, so deduplication makes you run faster, avoids memorization. You can do exact deduplication, um, with bloom filters, or you can use minhasch, hlesh to do, approximate deduplication. Yeah. So given that synthetic data is on a rise, how do you duplicate using, um, something that's, like, you know, paraphrase, um, sensitive. So there are some papers, uh, for example, 70 duper, which I didn't mention, that look at essentially embedding. So, um, that, uh,. can allow you to get a more somatic notion of, um, similarity, or did you, um, and be, and this all fits into the same, you know, framework, because, you know, in some sense, L-H, L-H was divisive, find approximate nearest neighbors. And so all you have to do is have a embedding, and that can, you embed all the documents, and you can find nearest neighbors in that, um, space. Obviously, there's a higher cost if you're going to run an embedding to, um, to embed your documents. And also, you know, we are sort of working in a regime where documents are, you know, the, the new duplicates are like really near duplicates.

**中文**: 嗯，因此去重能提升运行速度，避免重复记忆。你可以使用布隆过滤器进行精确去重，也可以采用MinHash或LSH实现近似去重。是的。鉴于合成数据正日益增多，那么如何利用某种对改写（即语义变换）敏感的方法来进行去重呢？目前已有一些相关论文，例如我之前未提及的“70-Duper”，其核心思路本质上是基于嵌入（embedding）技术。这种方法能够提供一种更具语义性的相似度衡量方式。而所有这些方法都属于同一框架，因为从某种意义上说，LSH（局部敏感哈希）本身就是一种用于查找近似最近邻的技术。因此，你只需获得一个嵌入表示，将所有文档嵌入到该空间中，即可在该嵌入空间中查找最近邻。当然，若需运行嵌入模型来处理你的文档，其计算开销会更高。此外，我们当前所处的情形是：文档之间新出现的重复往往属于高度近似的重复（即“近重复”）。

## 段落 69

**英文**: Um, I think you have to be very careful if you're doing some sort of more fuzzy duplication. You can throw out a lot of your data. if you are too permissive. Another question? Yeah, so the question is, uh, well, if the data's high quality, maybe you do want duplicates. And that's actually right. Um, so in, a lot of language-mobbing papers, there's, uh, sort of, the mid-training of a regime where you have a bunch of high-quality sources. You actually want to take multiple epochs over high-quality data. Um, so the duplication is more, I would say, for, kind of the pre-training where you have all this stuff, and you have 60,000 copies of some random thing. You just want to like clean that up. But, um, I think the optimal thing to do is, well, clearly not, I don't know what the optimal thing to do is, but, um, it's probably, if you have.

**中文**: 嗯，我觉得如果要进行某种模糊性较高的去重操作，就必须格外谨慎，否则过于宽松的去重策略可能会导致大量数据被误删。还有其他问题吗？是的，这个问题是这样的：如果数据质量很高，或许我们反而希望保留重复样本——这实际上是对的。例如，在许多语言模型相关论文中，预训练阶段往往包含大量高质量数据源，此时我们确实希望对高质量数据进行多轮训练（即多个epoch）。因此，所谓“去重”更多适用于预训练初期——当数据来源庞杂、混杂着大量低质内容时，比如某份随机文档竟有六万份重复副本，这时就需要清理冗余。不过，至于最优策略究竟为何……嗯，我其实并不清楚什么才是最优方案，但很可能的情况是：如果你拥有……

## 段落 70

**英文**: documents that occur a lot of times, you could also signal that there's more importance to it. And maybe the right thing to do is like taking the number of the count, and I don't know, taking the square root or log or something so that it shows up, um, doesn't proportionally show up inner-training data, but it's, you acknowledge that it's, um, important enough to go take more epochs over. Okay, so let's summarize. Um, so this lecture was mostly about giving you algorithmic tools. So we look at N-gram models, uh, linear classifiers in important resampling as ways to do filtering, and with filtering, um, you can do language identification, quality filtering, toxicity filtering, anything, I guess, where do you have a target's, a dataset, and you want to get. more of that dataset, then you can apply these tools. Or if you don't have a target dataset, and you have a strong language model, you can prompt that language model to synthesize a, or synthesize or, um, filter down, uh, you know, a lower quality dataset to get to T, and then you get a fast classifier that, uh, you're, and you're off to the basis. And a second, we looked at the duplication, which, um, is important, um, for reducing the amount of compute you, you're spending on, you know, kind of, you're wasting essentially. Um, and the algorithmic tool here is, is hashing. Um, because hashing is what allows you to take these kind of pairwise notions of similarity and collision, and turn them into, uh, unary functions, which allows you to have this linear time,.

**中文**: 频繁出现的文档，你也可以借此表明其重要性更高。或许恰当的做法是采用词频计数，并对其取平方根、对数或其他变换，从而使它在训练数据中并非呈线性比例地凸显出来，而是表明该文档足够重要，值得投入更多训练轮次。  
好的，我们来总结一下。本讲主要内容是向大家介绍若干算法工具：我们探讨了N元语法模型、线性分类器以及重要的重采样方法，这些均可用于过滤任务；借助这些过滤工具，你可以开展语言识别、质量过滤、毒性内容过滤等各类任务——简言之，只要存在一个目标数据集，且你希望从中获取更多符合要求的数据样本，便可应用上述工具。若你没有现成的目标数据集，但拥有一个性能强劲的语言模型，则可提示该模型合成目标数据，或对低质量数据集进行筛选与精炼，从而得到目标数据集T；由此即可快速构建一个分类器，进而顺利开展后续工作。  
其次，我们讨论了去重问题，这在降低计算资源消耗方面至关重要——否则，你实际上是在浪费算力。此处所用的核心算法工具是哈希（hashing），因为哈希技术能够将成对相似性或碰撞等概念转化为一元函数，从而实现线性时间复杂度。

## 段落 71

**英文**: you know, property, and, you know, we saw some sort of cleverer methods where, um, basically using multiple hash functions, um, and using these kind of, and-or constructions allows you to, kind of, shape your, your criteria in, in ways, like the LSA, it's example. So now you have all the tools, um, they all now, in some sense, you've asked how, how you teach data. This is kind of only the beginning. Um, the- you really have to spend time with the data looking at it, filtering and training models, and that's how you build, um, your intuitions over what works and what doesn't. So hopefully you'll be able to do that, uh, a bit in assignment, uh, for. Okay, that's all for, uh, the data lecture. And next. week, uh, we're going to start doing, um, reinforcement learning and, you know, alignment, which is what we are last unit.

**中文**: 你知道，就是属性，而且，你知道，我们看到了一些更巧妙的方法，呃，基本上是使用多个哈希函数，呃，并采用这类“与-或”结构，从而让你能够以某种方式定制你的判定标准，比如LSA就是一个例子。所以现在你已掌握了所有工具，呃，从某种意义上说，它们都已齐备；而你之前问过“如何教数据”，这其实才刚刚开始。呃，你确实需要花时间深入接触数据，观察它、筛选它并训练模型，正是通过这种方式，你才能逐步建立起对哪些方法有效、哪些无效的直觉。因此，希望你能在作业中稍作实践。好了，本次数据专题讲座就到这里。下周，我们将开始学习强化学习，以及大家所熟知的对齐（alignment）问题——这也是我们最后一个单元的内容。

---

*共 71 个段落，708 句话*
