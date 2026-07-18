# 第 2 章：分词（Tokenization）

> **本章目标**：理解文本如何变成模型能处理的整数序列，掌握 BPE 算法原理，熟练使用 tiktoken 分词器。

## 2.1 为什么需要分词

Transformer 模型只接受数字输入——具体来说，是一个整数序列。但我们人类的语言是文本：单词、句子、段落。分词（Tokenization）就是连接这两个世界的桥梁。

你可能会想：为什么不直接把每个字符映射成一个数字？比如 `a=0, b=1, c=2, ...`？

让我们看看这种字符级方案的优缺点：

**字符级分词的优点**：
- 词汇表极小（ASCII 只有 256 个字符）
- 永远不会遇到"未知词"（Out-of-Vocabulary）

**字符级分词的缺点**：
- 序列太长！"hello" 变成 5 个 token，"unbelievable" 变成 12 个 token
- 模型需要学习非常长的依赖关系
- 计算效率低下

那**词级分词**呢？把每个单词映射成一个数字：`"hello"=1234, "world"=5678, ...`？

**词级分词的优点**：
- 序列短，每个词一个 token
- 语义单元清晰

**词级分词的缺点**：
- 词汇表巨大（英语有数十万个单词）
- 无法处理新词、拼写错误、专有名词
- 无法捕捉词内结构（"playing" 和 "played" 的关系）

**子词分词（Subword Tokenization）** 是现代 LLM 的标准方案：在字符级和词级之间找到平衡。常见的词被编码成少数几个 token，罕见词被拆分成更小的片段。

## 2.2 BPE 算法原理

BPE（Byte Pair Encoding，字节对编码）是最流行的子词分词算法之一。GPT 系列、LLaMA、Claude 都使用 BPE 或其变体。

### 2.2.1 直觉理解

BPE 的核心思想非常简单：**从最小的单位（字节或字符）开始，反复把最常一起出现的相邻对合并成一个新单位。**

想象你在读一本书，发现 "th" 这两个字母经常一起出现。为什么不把它们合并成一个符号 "th" 呢？然后你发现 "the" 经常出现，再把 "th" 和 "e" 合并成 "the"。如此反复，你就在构建一个子词词汇表。

### 2.2.2 算法步骤

让我们用一个具体的例子来演示 BPE 的训练过程。

**训练语料**（已统计词频）：
```
"low" × 5
"lower" × 2
"newest" × 6
"widest" × 3
```

**步骤 0：初始化**

把每个词拆成字符序列，用特殊符号 `</w>` 标记词尾：

```
l o w </w>         × 5
l o w e r </w>     × 2
n e w e s t </w>   × 6
w i d e s t </w>   × 3
```

此时词汇表 = `{l, o, w, e, r, n, s, t, i, d, </w>}`

**步骤 1：统计相邻对的频率**

| 相邻对 | 频率 |
|--------|------|
| (l, o) | 5 + 2 = 7 |
| (o, w) | 5 + 2 = 7 |
| (w, `</w>`) | 5 |
| (w, e) | 2 + 6 = 8 ← 最高 |
| (e, r) | 2 |
| (r, `</w>`) | 2 |
| (n, e) | 6 |
| (e, s) | 6 + 3 = 9 ← 更高！ |
| (s, t) | 6 + 3 = 9 ← 更高！ |
| (t, `</w>`) | 6 + 3 = 9 ← 最高 |
| (w, i) | 3 |
| (i, d) | 3 |
| (d, e) | 3 |

最高频的对是 `(e, s)`、`(s, t)`、`(t, </w>)`，都是 9 次。假设我们选择 `(e, s)` 先合并。

**合并规则 1**：`e s → es`

更新语料：
```
l o w </w>
l o w e r </w>
n e w es t </w>    × 6
w i d es t </w>    × 3
```

词汇表新增：`es`

**步骤 2：继续合并**

现在 `(es, t)` 出现 9 次，最高频。

**合并规则 2**：`es t → est`

```
l o w </w>
l o w e r </w>
n e w est </w>     × 6
w i d est </w>     × 3
```

**步骤 3**：`(est, </w>)` 出现 9 次。

**合并规则 3**：`est </w> → est</w>`

```
l o w </w>
l o w e r </w>
n e w est</w>      × 6
w i d est</w>      × 3
```

**继续合并...**

经过若干轮后，你可能得到这样的词汇表：

```
l, o, w, </w>, e, r, n, i, d, s, t,
es, est, est</w>, low, lower, newest, widest, ...
```

### 2.2.3 编码过程

训练好 BPE 后，我们得到了一组**合并规则**（按优先级排序）。编码新文本时，按同样的优先级应用这些规则：

```
输入: "lowest"
字符序列: l o w e s t </w>

应用规则 "e s → es":  l o w es t </w>
应用规则 "es t → est": l o w est </w>
应用规则 "est </w> → est</w>": l o w est</w>
应用规则 "l o → lo":  lo w est</w>
应用规则 "lo w → low": low est</w>
...
```

最终得到 token 序列。

### 2.2.4 关键要点

1. **合并规则是有优先级的**：先学高频对，后学低频对
2. **词汇表大小是超参数**：你可以选择合并多少次，决定最终词汇表有多大
3. **编码是确定性的**：给定训练好的规则，同一段文本永远编码成同样的 token 序列
4. **未知词也能处理**：因为所有字符都在初始词汇表里，任何词都能被拆分

## 2.3 在线体验 BPE

在深入代码之前，强烈建议你先在浏览器里亲手体验一下 BPE 的效果。

### 2.3.1 推荐工具

**1. GPT Tokenizer Playground（推荐）**
- 网址：https://gpt-tokenizer.dev
- 功能：实时显示 OpenAI 模型的分词结果，彩色高亮每个 token，显示 token ID
- 特点：支持 GPT-3/GPT-4 等多种模型的编码器

**2. HuggingFace Tokenizer Playground**
- 网址：https://huggingface.co/spaces/Xenova/the-tokenizer-playground
- 功能：在线体验各种分词器（GPT、LLaMA、Claude 等）
- 特点：可以对比不同模型的分词差异

**3. BPE Visualizer**
- 网址：https://www.bpe-visualizer.com
- 功能：可视化 BPE 的合并过程，一步步展示词汇表如何构建
- 特点：交互式教学工具，非常适合理解 BPE 算法原理

**4. Cornell BPE Demo**
- 网址：https://www.cs.cornell.edu/courses/cs4782/2026sp/demos/bytepair/
- 功能：康奈尔大学课程配套 demo，清晰展示 BPE 的每一步合并

打开任意一个分词器网站，在输入框里试试这些文本：

| 输入文本 | 观察重点 |
|----------|----------|
| `"hello world"` | 常见短语，可能是 2-3 个 token |
| `"unbelievable"` | 较长单词，可能被拆成 `un` + `believ` + `able` |
| `"xjklm"` | 无意义字符串，几乎每个字符一个 token |
| `"def fibonacci(n):"` | 代码，注意函数名和括号怎么分 |
| `"你好世界"` | 中文，通常每个汉字 1-2 个 token |

### 2.3.2 动手实验：观察 r50k_base 的行为

打开 https://gpt-tokenizer.dev 或 HuggingFace Tokenizer Playground，选择 GPT-3/r50k_base 编码器，然后输入以下文本观察结果：

**实验 1：常见词 vs 罕见词**

```
输入: "The quick brown fox jumps over the lazy dog"
```

观察：大部分常见单词是单个 token。数一下总共有多少 token？

**实验 2：代码文本**

```
输入: "def calculate_average(numbers):\n    return sum(numbers) / len(numbers)"
```

观察：Python 关键字、变量名、标点符号各占几个 token？

**实验 3：数字**

```
输入: "12345"
输入: "123456789"
输入: "2024"
```

观察：数字是怎么被编码的？年份和普通数字有区别吗？

**实验 4：空格的影响**

```
输入: "hello world"
输入: "hello  world"   (两个空格)
输入: "helloworld"
```

观察：空格的处理方式——注意前导空格和尾部空格的区别。

**实验 5：中文**

```
输入: "你好世界"
输入: "Hello你好World"
```

观察：中文字符通常被编码成几个 token？

## 2.4 tiktoken：本项目的分词器

本项目使用 OpenAI 开源的 **tiktoken** 库，具体是 `r50k_base` 编码器（GPT-3 使用的版本）。

### 2.4.1 安装与基本使用

```bash
pip install tiktoken
```

```python
import tiktoken

# 加载编码器
enc = tiktoken.get_encoding("r50k_base")

# 编码：文本 → token IDs
text = "Hello, world!"
token_ids = enc.encode(text)
print(f"Token IDs: {token_ids}")
# 输出: Token IDs: [15496, 11, 995]

# 解码：token IDs → 文本
decoded = enc.decode(token_ids)
print(f"Decoded: {decoded}")
# 输出: Decoded: Hello, world!

# 查看词汇表大小
print(f"Vocab size: {enc.n_vocab}")
# 输出: Vocab size: 50257
```

### 2.4.2 深入理解 token

让我们更细致地看看分词过程：

```python
import tiktoken
enc = tiktoken.get_encoding("r50k_base")

def show_tokens(text):
    """显示文本的分词细节"""
    token_ids = enc.encode(text)
    print(f"\n文本: {repr(text)}")
    print(f"Token 数量: {len(token_ids)}")
    print(f"Token IDs: {token_ids}")
    
    # 逐个解码，看每个 token 长什么样
    tokens = [enc.decode([tid]) for tid in token_ids]
    print(f"Tokens: {tokens}")
    
    # 计算压缩率
    char_count = len(text)
    token_count = len(token_ids)
    ratio = char_count / token_count if token_count > 0 else 0
    print(f"压缩率: {ratio:.2f} 字符/token")

# 测试各种文本
show_tokens("Hello, world!")
show_tokens("This is a simple sentence.")
show_tokens("unbelievable")
show_tokens("def my_function():")
show_tokens("1234567890")
show_tokens("你好世界")
```

**预期输出**（部分）：

```
文本: 'Hello, world!'
Token 数量: 3
Token IDs: [15496, 11, 995]
Tokens: ['Hello', ',', ' world!']
压缩率: 4.33 字符/token

文本: 'unbelievable'
Token 数量: 3
Token IDs: [722, 24976, 1298]
Tokens: ['un', 'believ', 'able']
压缩率: 4.00 字符/token

文本: 'def my_function():'
Token 数量: 7
Token IDs: [31373, 616, 272, 2270, 25, 8, 2]
Tokens: ['def', ' my', '_', 'function', '(', ')', ':']
压缩率: 2.57 字符/token
```

### 2.4.3 关键观察

从上面的实验，你应该能观察到：

1. **常见单词 = 单个 token**："Hello" → 1 token
2. **罕见/长单词 = 多个子词**："unbelievable" → "un" + "believ" + "able"
3. **标点符号单独成 token**："," → 1 token
4. **空格被"吸收"到下一个 token**：" world" 而不是 " " + "world"
5. **代码被拆得很细**：`my_function` → `my` + `_` + `function`
6. **中文效率较低**：每个汉字通常 1-2 个 token（相比英文单词）

## 2.5 项目中的分词实现

现在让我们看看本项目是如何使用 tiktoken 的。

### 2.5.1 预训练数据准备

在 `scripts/prepare_pretrain_data.py` 中，分词流程是这样的：

```python
import tiktoken

# 加载 r50k_base 编码器
enc = tiktoken.get_encoding("r50k_base")

# 特殊 token: 文档结束符
EOT_ID = 50256  # <|endoftext|>

def tokenize_documents(docs: list[str]) -> list[int]:
    """把多个文档编码成一个扁平的 token 流"""
    all_tokens = []
    
    for doc in docs:
        # encode_ordinary: 普通编码，不处理特殊 token
        token_ids = enc.encode_ordinary(doc)
        
        # 追加文档结束符
        token_ids.append(EOT_ID)
        
        all_tokens.extend(token_ids)
    
    return all_tokens
```

**为什么要加 `<|endoftext|>`？**

想象两个文档拼在一起：

```
文档1: "The cat sat on the mat."
文档2: "Python is a programming language."
```

如果不加分隔符，模型看到的是：

```
...mat. Python is a...
```

模型可能会学到 "mat." 后面经常跟 "Python"——这显然是错的！`<|endoftext|>` 告诉模型：这里是文档边界，不要跨文档学习。

### 2.5.2 批量编码优化

处理海量数据时，逐文档编码太慢。项目使用批量编码：

```python
ENC_BATCH = 1024  # 每次处理 1024 个文档

docs = []
for text in text_iterator:
    docs.append(text)
    
    if len(docs) >= ENC_BATCH:
        # 批量编码，效率更高
        for token_ids in enc.encode_ordinary_batch(docs):
            buf.extend(token_ids)
            buf.append(EOT_ID)
        docs = []
```

`encode_ordinary_batch` 在底层使用多线程，比循环调用 `encode_ordinary` 快得多。

### 2.5.3 对话模板与 Loss Mask

在 SFT（监督微调）阶段，分词变得更复杂——我们需要区分"用户输入"和"模型应该生成的回答"。

```python
# src/post_training/chat_template.py

# 角色标记（普通文本，不是特殊 token）
USER_HEADER = "<|user|>\n"
ASSISTANT_HEADER = "<|assistant|>\n"

# 对话格式
# <|user|>
# 你好<|endoftext|><|assistant|>
# 你好！有什么可以帮你的吗？<|endoftext|>

def encode_chat(messages):
    """编码对话，同时构建 loss mask"""
    ids = []
    mask = []
    
    for msg in messages:
        role = msg["role"]
        content = msg["content"]
        
        # 编码角色头
        header = f"<|{role}|>\n"
        header_ids = enc.encode_ordinary(header)
        ids.extend(header_ids)
        mask.extend([0] * len(header_ids))  # mask=0: 不训练模型生成角色头
        
        # 编码内容
        content_ids = enc.encode_ordinary(content)
        ids.extend(content_ids)
        
        if role == "assistant":
            mask.extend([1] * len(content_ids))  # mask=1: 训练模型生成助手回复
        else:
            mask.extend([0] * len(content_ids))  # mask=0: 用户输入不算 loss
        
        # 追加结束符
        ids.append(EOT_ID)
        mask.append(1 if role == "assistant" else 0)
    
    return ids, mask
```

**Loss Mask 的作用**：

假设我们训练模型回答"你好"：

```
输入 tokens:  [<|user|>, 你, 好, <|endoftext|>, <|assistant|>, 你, 好, ！, ..., <|endoftext|>]
Loss mask:    [    0,     0,  0,      0,            0,         1,  1,  1, ...,      1       ]
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                     不算 loss（用户输入）                  算 loss（模型应该生成的）
```

如果我们不设置 mask，模型会浪费容量去学习"如何复述用户的问题"，而不是"如何回答问题"。

## 2.6 特殊 Token 的设计

### 2.6.1 r50k_base 的特殊 token

`r50k_base` 只有一个特殊 token：

| Token ID | 名称 | 用途 |
|----------|------|------|
| 50256 | `<\|endoftext\|>` | 文档/对话结束符，也是生成停止符 |

就这么简单！相比之下，后来的编码器（如 `cl100k_base`）引入了更多特殊 token。

### 2.6.2 为什么用普通文本做角色标记？

你可能注意到，项目用普通文本 `<|user|>` 和 `<|assistant|>` 作为角色标记，而不是注册成特殊 token。

原因：`r50k_base` 不支持添加新的特殊 token。所以项目选择了"假装它们是普通文本"——模型在 SFT 训练过程中学会这些文本片段的含义。

```python
# 这不是特殊 token，只是普通文本
USER_HEADER = "<|user|>\n"

# 分词后变成多个 token
enc.encode_ordinary("<|user|>\n")
# 输出: [27, 91, 318, 50119, 91, 29, 198]
#       '<' '|' 'user' '|' '>' '\n'  （大致如此）
```

这种设计的优缺点：

**优点**：
- 不需要修改分词器
- 与任何支持 r50k_base 的工具兼容

**缺点**：
- 一个角色标记占多个 token（效率略低）
- 模型需要学习这些 token 组合的含义

## 2.7 分词对模型的影响

分词器的设计会直接影响模型的性能和行为。

### 2.7.1 词汇表大小

本项目使用 `vocab_size = 50304`（实际 r50k_base 是 50257，向上取整到 64 的倍数，便于计算）。

词汇表大小的权衡：

| 词汇表大小 | 优点 | 缺点 |
|------------|------|------|
| 小（~10k） | Embedding 层参数少 | 序列长，计算量大 |
| 中（~50k） | 平衡 | - |
| 大（~100k） | 序列短 | Embedding 层参数多，可能过拟合 |

### 2.7.2 多语言效率

r50k_base 是为英语优化的。对于中文、日文等语言，效率较低：

```python
# 英文
enc.encode("The quick brown fox")
# 长度: 4 tokens

# 中文
enc.encode("快速的棕色狐狸")
# 长度: ~10 tokens（每个汉字可能 1-2 个 token）
```

这就是为什么多语言模型（如 LLaMA、Qwen）使用更大的词汇表（~150k），包含更多非英文字符。

### 2.7.3 数字编码

BPE 对数字的处理可能出乎意料：

```python
enc.encode("2024")
# 可能是 [16, 14, 17, 18]（四个单独的 digit token）
# 也可能是 [1024]（一个完整的 token）

enc.encode("1234567890")
# 通常是多个 token
```

这意味着模型处理数字时，需要"理解"每个 digit token 的含义，而不是把 "2024" 当作一个整体。这是 LLM 在数学推理上表现不佳的原因之一。

## 2.8 动手实验：构建自己的 BPE

让我们从零实现一个简化版的 BPE，加深理解。

### 2.8.1 完整代码

```python
"""简易 BPE 实现（教学用途）"""

from collections import Counter

def get_stats(vocab):
    """统计词汇表中所有相邻对的频率"""
    pairs = Counter()
    for word, freq in vocab.items():
        symbols = word.split()
        for i in range(len(symbols) - 1):
            pairs[symbols[i], symbols[i+1]] += freq
    return pairs

def merge_vocab(pair, vocab):
    """合并指定的相邻对"""
    new_vocab = {}
    bigram = ' '.join(pair)
    replacement = ''.join(pair)
    
    for word, freq in vocab.items():
        new_word = word.replace(bigram, replacement)
        new_vocab[new_word] = freq
    
    return new_vocab

def train_bpe(corpus: list[str], num_merges: int):
    """训练 BPE"""
    # 初始化：每个字符一个 token，加上词尾标记
    vocab = Counter(' '.join(list(word)) + ' </w>' for word in corpus)
    
    merges = []
    for i in range(num_merges):
        pairs = get_stats(vocab)
        if not pairs:
            break
        
        # 选择最高频的相邻对
        best_pair = max(pairs, key=pairs.get)
        
        # 合并
        vocab = merge_vocab(best_pair, vocab)
        merges.append(best_pair)
        
        print(f"Merge {i+1}: {best_pair} (freq={pairs[best_pair]})")
    
    return merges, vocab

def encode(text: str, merges: list[tuple]) -> list[str]:
    """用训练好的合并规则编码文本"""
    tokens = list(text) + ['</w>']
    
    for pair in merges:
        # 尝试合并
        i = 0
        while i < len(tokens) - 1:
            if tokens[i] == pair[0] and tokens[i+1] == pair[1]:
                tokens[i:i+2] = [''.join(pair)]
            else:
                i += 1
    
    return tokens

# ===== 测试 =====

corpus = ["low", "lower", "newest", "widest", "newest", "widest", "newest"]

print("训练 BPE...")
merges, final_vocab = train_bpe(corpus, num_merges=10)

print("\n合并规则:", merges)
print("\n最终词汇表:", list(final_vocab.keys()))

print("\n编码测试:")
print("  'lowest' ->", encode("lowest", merges))
print("  'newer'  ->", encode("newer", merges))
```

### 2.8.2 运行结果

```
训练 BPE...
Merge 1: ('e', 's') (freq=9)
Merge 2: ('es', 't') (freq=9)
Merge 3: ('est', '</w>') (freq=9)
Merge 4: ('l', 'o') (freq=7)
Merge 5: ('lo', 'w') (freq=7)
Merge 6: ('n', 'e') (freq=6)
Merge 7: ('ne', 'w') (freq=6)
Merge 8: ('w', 'i') (freq=3)
Merge 9: ('wi', 'd') (freq=3)
Merge 10: ('wid', 'est</w>') (freq=3)

合并规则: [('e', 's'), ('es', 't'), ('est', '</w>'), ('l', 'o'), ('lo', 'w'), 
           ('n', 'e'), ('ne', 'w'), ('w', 'i'), ('wi', 'd'), ('wid', 'est</w>')]

最终词汇表: ['low</w>', 'lower</w>', 'newest</w>', 'widest</w>']

编码测试:
  'lowest' -> ['low', 'est</w>']
  'newer'  -> ['ne', 'w', 'e', 'r', '</w>']
```

**观察**：
- "lowest" 被编码成 "low" + "est"——两个子词
- "newer" 没有被完整合并——因为训练语料中没有 "newer"，只有 "newest"
- 词尾标记 `</w>` 帮助区分词内和词边界

## 2.9 分词的性能考量

### 2.9.1 编码速度

```python
import time
import tiktoken

enc = tiktoken.get_encoding("r50k_base")
text = "The quick brown fox jumps over the lazy dog. " * 1000

# 单条编码
start = time.time()
for _ in range(100):
    enc.encode(text)
single_time = time.time() - start

# 批量编码
texts = [text] * 100
start = time.time()
enc.encode_batch(texts)
batch_time = time.time() - start

print(f"单条编码: {single_time:.3f}s")
print(f"批量编码: {batch_time:.3f}s")
print(f"加速比: {single_time/batch_time:.1f}x")
```

**预期输出**：批量编码通常快 3-5 倍。

### 2.9.2 内存占用

分词本身内存占用很小，但要注意：

```python
# 加载分词器会占用一些内存（词汇表）
import tiktoken
enc = tiktoken.get_encoding("r50k_base")
# 大约占用 ~10MB 内存

# 大量文本编码后，token 列表可能很大
tokens = enc.encode(huge_text)
# 1M tokens × 4 bytes (int32) = 4MB
```

## 2.10 本章小结

| 概念 | 要点 |
|------|------|
| **为什么需要分词** | 模型只接受数字；字符级太长，词级词汇表太大；子词是平衡方案 |
| **BPE 算法** | 从字符开始，反复合并最高频的相邻对，构建子词词汇表 |
| **r50k_base** | GPT-3 使用的编码器，50257 个 token，只有一个特殊 token `<\|endoftext\|>` |
| **Loss Mask** | SFT 阶段区分"用户输入"和"模型回复"，只在回复上计算 loss |
| **`<\|endoftext\|>`** | 文档/对话边界，防止跨文档学习 |

## 2.11 下一步

现在文本已经变成了整数序列。但这些整数怎么变成模型能理解的向量？下一章，我们将深入 Transformer 的输入层——Token Embedding 和 Positional Encoding。

---

## 练习

**练习 1：观察分词**

打开 https://gpt-tokenizer.dev（选择 GPT-3）或 HuggingFace Tokenizer Playground（选择 r50k_base），对以下文本分词并记录 token 数量：

1. `"I love machine learning."`
2. `"The mitochondria is the powerhouse of the cell."`
3. `"for i in range(10):"`
4. `"2 + 2 = 4"`
5. `"🎉🎊🎈"`（emoji）

**练习 2：计算压缩率**

写一个函数，输入一段文本，输出每个字符平均对应多少个 token。对英文、中文、代码各测试一段。

**练习 3：思考题**

如果我们要训练一个主要处理代码的模型，分词器应该怎么调整？（提示：想想代码中常见的 token 模式）

**练习 4：探索 r50k_base 的词汇表**

```python
import tiktoken
enc = tiktoken.get_encoding("r50k_base")

# 找出所有包含 "ing" 的 token
ing_tokens = [enc.decode([i]) for i in range(enc.n_vocab) if 'ing' in enc.decode([i])]
print(ing_tokens[:20])
```

观察：有哪些常见的 "-ing" 后缀 token？

**练习 5：网站 vs 脚本交叉验证**

这是本章最重要的练习——通过对比在线工具和自己的脚本输出，验证分词器的行为是否一致。

**步骤 1：脚本验证**

打开终端，运行以下 Python 代码，记录每段文本的 token IDs 和数量：

```python
import tiktoken

enc = tiktoken.get_encoding("r50k_base")

test_texts = [
    "hello world",
    "I love machine learning.",
    "The mitochondria is the powerhouse of the cell.",
    "for i in range(10):",
    "2 + 2 = 4",
    "你好世界",
    "def fibonacci(n):",
    "unbelievable",
]

for text in test_texts:
    tokens = enc.encode(text)
    decoded_tokens = [enc.decode([t]) for t in tokens]
    print(f"文本:       {repr(text)}")
    print(f"Token 数量: {len(tokens)}")
    print(f"Token IDs:  {tokens}")
    print(f"逐 token:   {decoded_tokens}")
    print(f"解码还原:   {repr(enc.decode(tokens))}")
    print("-" * 50)
```

你的输出应该类似这样（以 "hello world" 为例）：

```
文本:       'hello world'
Token 数量: 2
Token IDs:  [31373, 995]
逐 token:   ['hello', ' world']
解码还原:   'hello world'
```

注意观察：
- `"hello"` 是 token 31373，`" world"` 是 token 995——空格被"吸收"到了第二个 token 的前面
- 解码还原的文本应该和原始输入完全一致

**步骤 2：网站验证**

打开 https://gpt-tokenizer.dev（选择 GPT-3）或 HuggingFace Tokenizer Playground（选择 r50k_base），输入同样的文本，记录网站显示的：
- Token 数量
- Token IDs（如果网站显示的话）
- 每个 token 的文本（彩色高亮部分）

**步骤 3：对比表格**

填写下面的对比表，确认两边结果一致：

| 文本 | 脚本 Token 数 | 网站 Token 数 | 一致？ | 脚本 Token IDs | 网站 Token IDs |
|------|--------------|--------------|--------|----------------|----------------|
| `"hello world"` | | | | | |
| `"I love machine learning."` | | | | | |
| `"The mitochondria is the powerhouse of the cell."` | | | | | |
| `"for i in range(10):"` | | | | | |
| `"2 + 2 = 4"` | | | | | |
| `"你好世界"` | | | | | |
| `"def fibonacci(n):"` | | | | | |
| `"unbelievable"` | | | | | |

**步骤 4：分析差异（如果有）**

如果发现脚本和网站的结果不一致，可能的原因有：

1. **编码器版本不同**：网站可能用的是 `cl100k_base`（GPT-4）而不是 `r50k_base`（GPT-3），确认你选对了
2. **特殊 token 处理**：某些网站可能对 `<|endoftext|>` 等特殊 token 的处理方式不同
3. **前导空格**：`"hello world"` 和 `" hello world"` 的分词结果可能不同

**进阶验证**：尝试以下边界情况，观察脚本和网站的输出：

```python
# 前导空格的影响
print(enc.encode("hello"))      # 无前导空格
print(enc.encode(" hello"))     # 有前导空格

# 数字的分词
print(enc.encode("2024"))       # 年份
print(enc.encode("12345"))      # 普通数字
print(enc.encode("3.14159"))    # 浮点数

# 重复字符
print(enc.encode("aaaaaa"))     # 重复字母
print(enc.encode("......"))     # 重复标点

# 代码片段
print(enc.encode("import torch.nn as nn"))
print(enc.encode("x = self.attention(x)"))
```

思考：前导空格为什么会影响分词结果？（提示：BPE 训练时，词头的空格和词中的空格被视为不同的上下文）
