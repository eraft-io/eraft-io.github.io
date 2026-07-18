# 第 9 章：文本生成

> **本章目标**：理解自回归文本生成的原理，掌握 Temperature、Top-k、Top-p 等采样策略，学会从预训练 checkpoint 生成文本。

## 9.0 本章路线图

在第 8 章中，我们训练好了一个"懂语言"的模型。现在要让它**产出文本**。

预训练教会了模型：给定前面的 token，下一个 token 应该是什么。文本生成就是把这个能力**串联起来**——不断用模型自己的输出作为下一步的输入。

```
文本生成流程
│
├── ① 编码输入文本 -> token 序列
├── ② 自回归循环（逐 token 生成）
│   ├── 前向传播 -> logits
│   ├── 采样策略（Temperature / Top-k / Top-p）
│   ├── 采样下一个 token
│   └── 追加到序列
├── ③ 解码 token 序列 -> 文本字符串
└── ④ 遇到 EOT 或达到 max_new_tokens 停止
```

## 9.1 自回归生成原理

### 9.1.1 什么是自回归

"自回归"（autoregressive）的含义是：**模型用自己的输出作为下一步的输入**。

```
步骤 0: 输入 "The cat"
         -> 模型预测下一个 token -> "sat"

步骤 1: 输入 "The cat sat"    （包含了上一步的输出）
         -> 模型预测下一个 token -> "on"

步骤 2: 输入 "The cat sat on"
         -> 模型预测下一个 token -> "the"

步骤 3: 输入 "The cat sat on the"
         -> 模型预测下一个 token -> "mat"
```

每一步，模型都在做和训练时完全一样的事情：给定前面的 token，预测下一个。区别在于，训练时的"下一个 token"是真实数据中的，而生成时是模型自己采样的。

### 9.1.2 核心代码

```python
# src/models/transformer.py - Transformer.generate

def generate(self, idx, max_new_tokens):
    for _ in range(max_new_tokens):
        idx_cond = idx[:, -self.context_length:]    # 截取最后 context_length 个 token
        logits, _ = self(idx_cond)                   # 前向传播
        logits = logits[:, -1, :]                    # 只取最后一个位置的 logits
        probs = F.softmax(logits, dim=-1)            # softmax 转概率
        idx_next = torch.multinomial(probs, num_samples=1)  # 按概率采样
        idx = torch.cat((idx, idx_next), dim=1)      # 追加到序列
    return idx
```

### 9.1.3 为什么只取最后一个位置？

```
输入: ["The", "cat", "sat", "on"]
       pos 0   pos 1   pos 2   pos 3
```

由于**因果注意力**（causal attention），每个位置只能看到它之前的 token：

- pos 0 只看到 "The"
- pos 1 看到 "The cat"
- pos 2 看到 "The cat sat"
- **pos 3 看到 "The cat sat on"（完整上下文）**

所以只有最后一个位置包含了完整信息，它的 logits 是对"下一个 token"的最佳预测。

### 9.1.4 上下文窗口裁剪

```python
idx_cond = idx[:, -self.context_length:]
```

模型的位置嵌入（Position Embedding）是固定的——它只为位置 0 到 context_length-1 准备了嵌入向量。如果序列超过这个长度，必须**截掉最旧的部分**：

```
context_length = 256

序列长度 300:  [tok_0, tok_1, ..., tok_299]
                | 截取最后 256 个
               [tok_44, tok_45, ..., tok_299]
```

模型"忘记"了前 44 个 token，只基于最后 256 个做预测。这就是为什么上下文长度是模型的硬约束。


## 9.2 采样策略

### 9.2.1 从 Logits 到 Token

模型在每个位置输出一个 logits 向量（vocab_size 维），采样过程分三步：

```
原始 logits (vocab_size=50304)
    | Temperature 缩放
缩放后的 logits
    | Top-k / Top-p 过滤
过滤后的 logits（部分设为 -inf）
    | softmax + multinomial
采样得到下一个 token
```

### 9.2.2 Greedy 解码（贪心）

```python
idx_next = logits.argmax(dim=-1, keepdim=True)
```

每次都选概率最高的 token。

**优点**：确定性的、可复现的、适合评估
**缺点**：容易产生重复、无趣的文本

### 9.2.3 Temperature 采样

Temperature 控制概率分布的"尖锐程度"：

```python
# src/post_training/rollout.py - filter_logits

if temperature != 1.0:
    logits = logits / max(temperature, 1e-6)
```

数学公式：

\[p_i = \frac{\exp(z_i / \tau)}{\sum_j \exp(z_j / \tau)}\]

| Temperature | 效果 | 类比 |
|-------------|------|------|
| tau -> 0 | 接近 Greedy | 非常保守，只选最可能的 |
| tau = 0.5 | 较尖锐 | 倾向高概率 token，偶尔选次优 |
| tau = 1.0 | 原始分布 | 完全按模型学到的概率采样 |
| tau = 1.5 | 较平坦 | 低概率 token 也有机会被选中 |
| tau -> inf | 均匀分布 | 完全随机，像没训练过 |

**验证代码**：

```python
import torch
import torch.nn.functional as F

logits = torch.tensor([5.0, 3.0, 1.0])

for temp in [0.1, 0.5, 1.0, 2.0]:
    probs = F.softmax(logits / temp, dim=-1)
    print(f"tau={temp}: {probs.numpy().round(3)}")

# 输出:
# tau=0.1: [0.993 0.005 0.   ]   <- 几乎确定选第一个
# tau=0.5: [0.97  0.027 0.003]   <- 倾向第一个
# tau=1.0: [0.731 0.099 0.018]   <- 原始分布
# tau=2.0: [0.506 0.223 0.083]   <- 更均匀
```

### 9.2.4 Top-k 采样

Top-k 只保留概率最高的 k 个 token，其余设为 -inf（采样概率为 0）：

```python
# src/post_training/rollout.py - filter_logits

if top_k is not None and top_k > 0:
    k = min(top_k, logits.size(-1))
    kth = torch.topk(logits, k, dim=-1).values[..., -1, None]
    logits = logits.masked_fill(logits < kth, float("-inf"))
```

| top_k | 效果 |
|-------|------|
| 1 | 等价于 Greedy |
| 10 | 只从最可能的 10 个 token 中选 |
| 50 | 适中，常见默认值 |
| None | 不限制，从全部 50304 个 token 中选 |

### 9.2.5 Top-p 采样（Nucleus Sampling）

Top-p 动态决定保留多少个 token——保留累积概率达到 p 的最小集合：

```python
# src/post_training/rollout.py - filter_logits

if top_p is not None and 0.0 < top_p < 1.0:
    sorted_logits, sorted_idx = torch.sort(logits, descending=True, dim=-1)
    cumprobs = sorted_logits.softmax(dim=-1).cumsum(dim=-1)
    remove = cumprobs > top_p
    remove[..., 1:] = remove[..., :-1].clone()
    remove[..., 0] = False
    remove = remove.scatter(-1, sorted_idx, remove)
    logits = logits.masked_fill(remove, float("-inf"))
```

直觉：

```
token 概率分布:
  "mat":    0.60   <- 累积 0.60
  "floor":  0.15   <- 累积 0.75
  "rug":    0.08   <- 累积 0.83
  "bed":    0.05   <- 累积 0.88   <- top_p=0.9 时保留到这里
  "table":  0.03   <- 累积 0.91   <- 被过滤掉
  ...

top_p=0.9: 保留 mat, floor, rug, bed（4 个）
top_p=0.7: 保留 mat, floor（2 个）
```

| top_p | 效果 |
|-------|------|
| 0.1 | 非常保守，几乎 Greedy |
| 0.5 | 适中 |
| 0.9 | 常见默认值，兼顾多样性和质量 |
| 1.0 | 不限制 |

**Top-p 的优势**：自动适应上下文的"确定性"。当模型非常确定时（如"1+1=**2**"），可能只保留 1-2 个 token；当模型不确定时（如写小说），可能保留几十上百个。

### 9.2.6 采样策略对比

| 策略 | 确定性 | 多样性 | 适用场景 |
|------|--------|--------|---------|
| Greedy | 最高 | 无 | 评估、数学推理 |
| Temperature < 1 | 高 | 低 | 翻译、摘要 |
| Temperature = 1 | 中 | 中 | 通用 |
| Temperature > 1 | 低 | 高 | 创意写作 |
| Top-k = 50 | - | 中 | 通用 |
| Top-p = 0.9 | - | 中 | 最推荐的默认设置 |

**实际使用中通常组合使用**：temperature=0.8, top_p=0.95 是一个常见的聊天配置。


## 9.3 完整生成管线

### 9.3.1 从 Checkpoint 到文本

项目提供了两套生成工具：

**旧版**：`scripts/generate_text.py`（直接使用 `Transformer.generate`）
**新版**：`src/post_training/inference.py`（使用 `batched_generate`，支持完整采样策略）

新版管线：

```
用户文本
    | get_tokenizer().encode_ordinary()
token 序列 [int, ...]
    | generate_reply() -> batched_generate()
        | generate_with_logprobs()
            | filter_logits(temperature, top_k, top_p)
            | softmax + multinomial 逐 token 采样
生成 token 序列
    | decode()
回复文本
```

### 9.3.2 旧版生成脚本

```python
# scripts/generate_text.py

def generate_text(model_path, input_text, max_new_tokens=100, device="cuda"):
    checkpoint = torch.load(model_path, map_location=device, weights_only=False)

    model = Transformer(
        n_head=config["n_head"], n_embed=config["n_embed"],
        context_length=config["context_length"], vocab_size=config["vocab_size"],
        N_BLOCKS=config["n_blocks"]
    )
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval().to(device)

    enc = tiktoken.get_encoding("r50k_base")
    start_ids = enc.encode_ordinary(input_text)
    context = torch.tensor(start_ids, dtype=torch.long, device=device).unsqueeze(0)

    with torch.no_grad():
        generated_tokens = model.generate(context, max_new_tokens=max_new_tokens)[0].tolist()

    return enc.decode(generated_tokens)
```

使用方式：

```bash
python3 scripts/generate_text.py \
    --model_path /ephemeral/ckpts/base_pretrained.pt \
    --input_text "The mitochondria is the" \
    --max_new_tokens 100
```

注意：旧版只支持最基本的 softmax 采样，没有 Temperature / Top-k / Top-p 控制。

### 9.3.3 新版推理工具

```python
# src/post_training/inference.py

def generate_reply(model, user_text, *, device, raw=False,
                   temperature=0.8, top_k=None, top_p=0.95, greedy=False):
    if raw:
        # 预训练模型：直接续写
        ids = get_tokenizer().encode_ordinary(user_text)
        out = batched_generate(model, [ids], max_new_tokens, device=device,
                               temperature=temperature, top_p=top_p)
        return out[0]

    # 后训练模型：用 chat template 包装
    messages = [{"role": "user", "content": user_text}]
    prompt_ids = encode_prompt(messages)
    out = batched_generate(model, [prompt_ids], max_new_tokens, device=device,
                           temperature=temperature, top_p=top_p)
    return out[0]
```

两种模式：
- **raw 模式**：把输入当作前缀续写（适合预训练模型）
- **chat 模式**：用 chat template 包装成对话格式（适合 SFT/DPO/PPO/GRPO 模型）

### 9.3.4 批量生成

`batched_generate` 的核心设计是**按长度分桶**：

```python
# src/post_training/evaluation.py - batched_generate

# 按 prompt 长度排序
order = sorted(range(len(prompts)), key=lambda i: len(prompts[i]))

# 把相同长度的 prompt 聚成 batch
while i < len(order):
    L = len(prompts[order[i]])
    while j < len(order) and len(prompts[order[j]]) == L:
        j += 1
    batch = torch.tensor([prompts[k] for k in order[i:j]])
    # 整个 batch 一起生成
    rb = generate_with_logprobs(model, batch, budget, ...)
```

为什么要分桶？因为这个模型**没有 padding-aware 的注意力掩码**。如果 batch 中有不同长度的序列，短序列的 padding 位置会污染注意力计算。分桶保证同一 batch 内所有序列等长，无需 padding。

## 9.4 Stop Token 与终止条件

### 9.4.1 EOT Token

```python
EOT_ID = 50256   # tiktoken 的特殊 token
```

在训练中，EOT 出现在文档之间（作为文档分隔符）。在生成中，EOT 是"我讲完了"的信号。

### 9.4.2 终止条件

生成在以下任一条件满足时停止：

| 条件 | 说明 |
|------|------|
| 遇到 EOT token | 模型认为回答结束了 |
| 达到 max_new_tokens | 防止无限生成 |
| 序列总长达到 context_length | 位置嵌入的硬限制 |

```python
# src/post_training/rollout.py - generate_with_logprobs

stop_set = torch.tensor(stop_tokens, device=device)

for t in range(max_new_tokens):
    # ... 生成下一个 token ...
    hit_stop = (next_tok[:, None] == stop_set).any(dim=-1)
    finished = finished | (active & hit_stop)

    if bool(finished.all()):
        break   # 所有序列都停了
```

### 9.4.3 解码与截断

生成完成后，解码时需要截掉 EOT 及其后面的内容：

```python
# src/post_training/evaluation.py - batched_generate

toks = gen[row].tolist()
if EOT_ID in toks:
    toks = toks[: toks.index(EOT_ID)]   # 截掉 EOT 及之后的部分
results[k] = decode(toks)
```

## 9.5 预训练模型的能力与局限

### 9.5.1 预训练模型能做什么

一个预训练好的模型（loss 约 3.0）展示了基本的语言能力：

```
输入: "The capital of France is"
输出: "The capital of France is Paris, which is known for its beautiful"

输入: "def fibonacci(n):"
输出: "def fibonacci(n): if n <= 1: return n return fibonacci(n-1) + fibonacci(n-2)"

输入: "In a hole in the ground"
输出: "In a hole in the ground there lived a hobbit. Not a nasty, dirty, wet hole"
```

### 9.5.2 预训练模型不能做什么

```
输入: "What is the capital of France?"
输出: "What is the capital of France? The capital of France is Paris. What is the capital of Germany? The capital of Germany is Berlin."
```

预训练模型把"问题"也当成文本的一部分来续写，而不是"回答问题"。这是为什么我们需要后训练：

| 能力 | 预训练 | SFT | DPO/PPO/GRPO |
|------|--------|-----|-------------|
| 续写文本 | 可以 | 可以 | 可以 |
| 回答问题 | 不行（会续写问题） | 可以 | 可以 |
| 遵循指令 | 不行 | 可以 | 更好 |
| 推理能力 | 弱 | 一般 | 更好 |

### 9.5.3 分布偏移问题

自回归生成的根本问题叫做**分布偏移**（distribution shift）：

- 训练时：每个位置看到的都是**真实数据**中的前缀
- 生成时：每个位置看到的是**模型自己生成的**前缀

如果模型在第 10 步采样了一个"不太对"的 token，第 11 步的预测就建立在这个"不太对"的基础上。误差会**累积**，最终文本越来越离谱。

这就是后训练的核心价值：
- **SFT** 教会模型"正确的回答格式"
- **DPO/PPO/GRPO** 推动模型远离糟糕的输出，靠近人类偏好的输出

## 9.6 操作指南

### 9.6.1 预训练模型生成

```bash
# 旧版脚本
python3 scripts/generate_text.py \
    --model_path /ephemeral/ckpts/base_pretrained.pt \
    --input_text "Once upon a time" \
    --max_new_tokens 200
```

### 9.6.2 后训练模型对话

```bash
# 新版 chat CLI
python3 scripts/chat.py \
    --ckpt /ephemeral/ckpts/sft.pt \
    --prompt "What is machine learning?"
```

### 9.6.3 Python 中调用

```python
from src.post_training.inference import load_model_from_ckpt, generate_reply

model = load_model_from_ckpt("/ephemeral/ckpts/sft.pt", device="cuda")

# 对话模式
reply = generate_reply(model, "Explain quantum computing",
                       device="cuda", temperature=0.8, top_p=0.95)
print(reply)

# 续写模式（预训练模型）
reply = generate_reply(model, "The capital of France is",
                       device="cuda", raw=True, greedy=True)
print(reply)
```

## 9.7 本章小结

### 自回归生成三步

```
for _ in range(max_new_tokens):
    1. 前向传播 -> 最后位置的 logits
    2. 采样策略 -> 下一个 token
    3. 追加 token -> 更新序列
```

### 采样策略速查

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| temperature | 0.8 | 越高越随机 |
| top_p | 0.95 | 动态候选集 |
| top_k | None | 固定候选集 |
| greedy | False | 评估时设为 True |

### 预训练 vs 后训练

```
预训练模型：文本续写机器（给前缀，补后缀）
    | SFT：教会回答问题
    | DPO/PPO/GRPO：对齐人类偏好
后训练模型：AI 助手（理解指令，给出回答）
```

---

## 练习

**练习 1：Temperature 实验**

对同一段输入，用不同 temperature 生成文本，对比差异：

```python
for temp in [0.1, 0.5, 1.0, 1.5, 2.0]:
    reply = generate_reply(model, "The future of AI is",
                           device="cuda", temperature=temp, max_new_tokens=100)
    print(f"temp={temp}: {reply[:80]}...")
```

**练习 2：Top-p vs Top-k**

对同一段输入，分别用 top_p=0.9 和 top_k=50 生成文本。观察：
- 哪种方式生成的文本更自然？
- 多次运行，哪种方式的变化更大？

**练习 3：Greedy 的重复性**

用 greedy=True 生成 200 个 token，观察是否出现重复循环。思考：为什么 greedy 容易产生重复？（提示：相同的上下文 -> 相同的预测 -> 相同的下一个 token -> 上下文只移动一位 -> 又几乎相同...）

**练习 4：上下文窗口实验**

用一个超过 context_length 的输入，观察模型的"遗忘"行为：

```python
# 生成 500 个 token 的长文本，然后问模型文本开头说了什么
long_text = "My name is Alice. " + "The quick brown fox jumps over the lazy dog. " * 100
reply = generate_reply(model, long_text + "What is my name? ",
                       device="cuda", raw=True, max_new_tokens=50)
# 如果 context_length=256，模型应该不记得 "Alice"
```

