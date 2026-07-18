# 第 11 章：Chat 格式与 Loss Mask

> **本章目标**：掌握对话模板的设计、Loss Mask 的原理与实现、变长对话打包为固定长度序列的方法。理解为什么 SFT 和预训练"几乎一样"，但行为截然不同。

## 11.0 本章路线图

上一章介绍了后训练的四层架构。这一章我们进入第一层——SFT 的核心基础设施：**Chat 格式**。

```
本章覆盖的链路

原始对话数据（Alpaca / Dolly / GSM8K）
    │
    ▼ Chat Template（encode_chat）
token ids + loss_mask
    │
    ▼ pack_examples
packed HDF5 (N × context_length)
    │
    ▼ sft_loss（masked cross-entropy）
梯度更新
```

## 11.1 对话模板设计

### 11.1.1 核心约束：只有一个特殊 token

本项目使用的分词器是 **tiktoken `r50k_base`**，它只有一个特殊 token：

```
<|endoftext|>  (id = 50256)
```

不能注册新的特殊 token。这意味着 ChatGPT 那种 `<|user|>`、`<|assistant|>` 作为 registered special token 的方案行不通。

**解决方案**：角色标记作为**普通文本**参与分词。模型在 SFT 阶段"学会"这些字符串的含义，就像学会任何其他文本模式一样。

### 11.1.2 对话格式

```
<|user|>
What is 2+2?
<|assistant|>
2+2=4
```

其中：
- `<|user|>\n` — 用户消息的开始
- `<|assistant|>\n` — 助手回复的开始
- `<|endoftext|>` — 每个 turn 的结束符（复用 EOT）

### 11.1.3 渲染函数

```python
# src/post_training/chat_template.py

USER_HEADER = "<|user|>\n"
ASSISTANT_HEADER = "<|assistant|>\n"

def render_chat(messages, add_generation_prompt=False):
    parts = []
    for m in messages:
        parts.append(_header_for(m["role"]))
        parts.append(m["content"])
        parts.append("<|endoftext|>")
    if add_generation_prompt:
        parts.append(ASSISTANT_HEADER)
    return "".join(parts)
```

`add_generation_prompt=True` 时，输出以 `<|assistant|>\n` 结尾，提示模型开始生成：

```
<|user|>
What is 2+2?<|endoftext|><|assistant|>
                                    ↑ 模型从这里开始生成
```

### 11.1.4 为什么选择普通文本而非特殊 token

| 方案 | 优点 | 缺点 |
|------|------|------|
| 特殊 token | 语义明确，不会混淆 | 需要修改分词器和嵌入表 |
| 普通文本 | 不修改分词器，代码简单 | 占用多个 token，有歧义风险 |

对于 50304 的 vocab 大小，`<|user|>\n` 会被分成约 4-5 个 token。模型在 SFT 训练中可以快速学会"看到这段 token 序列就知道是用户消息的开始"。实际效果与特殊 token 方案几乎一致。

## 11.2 推理格式：`<think>` / `<answer>`

### 11.2.1 设计动机

对于数学推理任务（GSM8K），我们希望模型学会"先思考，再回答"的结构：

```
<think>Let me think step by step.
Janet has 10 snowballs. She gives 3 to her friend.
10 - 3 = 7.
She has 7 snowballs left.</think>

<answer>7</answer>
```

这种 Chain-of-Thought 格式有两个好处：
1. **可解释性**：可以看到模型的推理过程
2. **可验证性**：`<answer>` 标签内的内容可以被验证器（verifier）自动检查

### 11.2.2 GSM8K 数据转换

原始 GSM8K 数据长这样：

```python
{
    "question": "Janet has 10 snowballs. She gives 3 to her friend. How many does she have left?",
    "answer": "Janet started with 10 snowballs...\n#### 7"
}
```

`gsm8k_to_messages` 将其转换为 chat 格式：

```python
# scripts/prepare_sft_data.py

def gsm8k_to_messages(question, answer):
    # 移除计算器标注（<<>>）
    answer = re.sub(r"<<[^>]*>>", "", answer).strip()
    # 提取 #### 后面的最终答案
    m = re.search(r"####\s*(.+)\s*$", answer)
    final = m.group(1).strip() if m else answer
    # 去掉 #### 部分，只保留推理过程
    reasoning = re.sub(r"####\s*.+\s*$", "", answer).strip()
    # 组装为 <think>...<answer>N</answer>
    completion = f"<think>{reasoning}</think><answer>{final}</answer>"
    return [
        {"role": "user", "content": question.strip()},
        {"role": "assistant", "content": completion}
    ]
```

### 11.2.3 验证器如何解析

训练完成后，验证器需要从模型输出中提取答案：

```python
# src/post_training/rewards/parsing.py

def extract_answer(text):
    """三级回退：
    1. 查找 <answer>...</answer> 标签内的数字
    2. 查找 #### N 格式
    3. 查找文本中最后一个数字
    """
    # 优先：<answer>42</answer>
    m = _ANSWER_RE.search(text)
    if m:
        n = parse_number(m.group(1))
        if n is not None:
            return n
    # 回退：#### 42
    m = _HASH_RE.search(text)
    if m:
        ...
    # 最后回退：文本中最后一个数字
    nums = _NUMBER_RE.findall(text)
    if nums:
        return parse_number(nums[-1])
    return None
```

这种分级回退设计很重要：小模型不一定能完美生成 `<answer>` 标签，但只要输出了正确数字，验证器就能识别。

## 11.3 Loss Mask 的原理与实现

### 11.3.1 为什么需要 Loss Mask

回顾预训练的损失函数：

```python
# 预训练：所有位置都计算 loss
loss = F.cross_entropy(logits.reshape(-1, V), targets.reshape(-1))
```

这在预训练中是对的——我们想训练模型续写所有文本。

但在 SFT 中，我们只想训练模型**回答**，不想训练模型**复述问题**：

```
<|user|>\nWhat is 2+2?<|endoftext|><|assistant|>\n2+2=4<|endoftext|>
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
     不应该训练的 token               应该训练的 token
     (mask=0)                        (mask=1)
```

如果也在 prompt 上计算 loss，模型会学到"精确复述用户输入"，这不是我们想要的行为。

### 11.3.2 encode_chat：同时生成 ids 和 mask

```python
# src/post_training/chat_template.py

def encode_chat(messages, add_generation_prompt=False):
    ids = []
    mask = []

    for m in messages:
        role = m["role"]

        # 角色 header：永远 mask=0
        header_ids = _encode_ordinary(_header_for(role))
        ids.extend(header_ids)
        mask.extend([0] * len(header_ids))

        # 消息内容：assistant 的 mask=1，其他角色 mask=0
        content_ids = _encode_ordinary(m["content"])
        is_completion = role == "assistant"
        ids.extend(content_ids)
        mask.extend([1 if is_completion else 0] * len(content_ids))

        # Turn 结束符 (EOT)：assistant turn 的 EOT 也训练（mask=1）
        ids.append(EOT_ID)
        mask.append(1 if is_completion else 0)

    if add_generation_prompt:
        header_ids = _encode_ordinary(ASSISTANT_HEADER)
        ids.extend(header_ids)
        mask.extend([0] * len(header_ids))

    return ids, mask
```

### 11.3.3 逐位置详解

以一个简单对话为例：

```python
messages = [
    {"role": "user", "content": "Hi"},
    {"role": "assistant", "content": "Hello!"}
]
```

编码后的结果：

```
位置:   0  1  2  3  4  5  6  7  8  9  10  11  12  13  14
token:  <| user |>  \n  Hi  EOT  <| assist ant |>  \n  Hello  !  EOT
mask:   0  0  0  0  0   0   0   0   0   0   0    1   1   1   1
```

注意：
- `<|user|>\n` 是 4 个普通 token，mask 全为 0
- `Hi` 是用户内容，mask 也为 0
- 用户 turn 的 EOT，mask 为 0
- `<|assistant|>\n` 是 header，mask 为 0
- `Hello!` 是 assistant 内容，mask 为 **1**
- assistant turn 的 EOT，mask 为 **1**（模型需要学会"生成 EOT 来停止"）

### 11.3.4 为什么 EOT 的 mask 也是 1

这是一个容易忽略的细节。如果 assistant turn 的 EOT 设为 mask=0：

```
模型永远看不到"在这里停止"的信号
→ 模型不会学会停止生成
→ 推理时输出永不停止
```

把 EOT 设为 mask=1，模型就能学到："当我完成回答后，应该生成 `<|endoftext|>` 来结束。"

## 11.4 `pack_examples`：变长对话打包为固定长度序列

### 11.4.1 问题：变长序列的浪费

对话的长度差异很大：

```
短对话：30 tokens    "Hi" -> "Hello!"
中等对话：200 tokens  "Explain X" -> "X is..."
长对话：800 tokens    "Write a story" -> "Once upon..."
```

如果每条对话独占一行（padding 到 `context_length`），短对话会浪费 90% 以上的计算。

### 11.4.2 解决方案：序列打包

将所有对话**首尾拼接**，然后按 `context_length` 切片：

```python
# src/post_training/sft.py

def pack_examples(examples, context_length):
    flat_ids = []
    flat_mask = []
    for ids, mask in examples:
        flat_ids.extend(ids)
        flat_mask.extend(mask)

    n_rows = len(flat_ids) // context_length
    ids_arr = np.asarray(
        flat_ids[:n_rows * context_length], dtype=np.int32
    ).reshape(n_rows, context_length)
    mask_arr = np.asarray(
        flat_mask[:n_rows * context_length], dtype=np.int8
    ).reshape(n_rows, context_length)
    return ids_arr, mask_arr
```

### 11.4.3 打包过程图解

```
原始对话（3 条）：
  对话 A:  [a1 a2 a3 a4 a5 EOT]          (6 tokens)
  对话 B:  [b1 b2 b3 EOT]                 (4 tokens)
  对话 C:  [c1 c2 c3 c4 c5 c6 c7 EOT]    (8 tokens)

拼接后（18 tokens）：
  [a1 a2 a3 a4 a5 EOT b1 b2 b3 EOT c1 c2 c3 c4 c5 c6 c7 EOT]

按 context_length=10 切片（得到 1 行，丢弃尾部 8 tokens）：
  Row 0: [a1 a2 a3 a4 a5 EOT b1 b2 b3 EOT]

对应的 mask：
  Row 0: [0  0  1  1  1  1  0  0  0  0]
```

**关键观察**：对话 A 的 EOT 和对话 B 的开始被打包到了同一行。模型不需要"知道"这是两条不同的对话——EOT 本身就是分隔符，attention 机制会自然地处理边界。

### 11.4.4 打包的代价

打包带来一个问题：**跨对话的 attention**。

```
Row 0: [对话A的尾部] [对话B的开头]
         ↑ attention 可以看到 ↗
```

模型在生成对话 B 的开头时，会"看到"对话 A 的尾部。理论上这是不正确的——对话 B 不应该依赖对话 A 的上下文。

但这个影响很小：
1. 对话开头的 prompt tokens（mask=0）不参与 loss 计算
2. 模型很快学会"EOT 之后就是新的对话"
3. 实际效果几乎不受影响

### 11.4.5 与预训练数据的对比

| | 预训练数据 | SFT 数据 |
|---|---|---|
| 数据格式 | 连续文本流（The Pile） | 结构化对话 |
| 打包方式 | 天然连续，按 length 切 | 对话拼接后切 |
| 跨边界问题 | 无（同一文本流） | 有（不同对话混在一行） |
| mask | 全部为 1 | assistant 为 1，prompt 为 0 |
| 存储 | tokens (N, L) | tokens (N, L) + loss_mask (N, L) |

## 11.5 SFT 损失函数：Masked Cross-Entropy

### 11.5.1 sft_loss 详解

```python
# src/post_training/sft.py

def sft_loss(logits, tokens, loss_mask):
    # 标准的 next-token 移位
    logits = logits[:, :-1, :]     # (B, T-1, V)
    targets = tokens[:, 1:]        # (B, T-1)
    mask = loss_mask[:, 1:]        # (B, T-1) — 注意也移位了！

    V = logits.size(-1)
    # 逐 token 计算 cross-entropy，不做 reduce
    ce = F.cross_entropy(
        logits.reshape(-1, V).float(),
        targets.reshape(-1).long(),
        reduction="none"
    )
    ce = ce.view(targets.shape)    # (B, T-1)

    # 用 mask 过滤：只保留 assistant token 的 loss
    ce = ce * mask

    # 平均：除以 mask 中 1 的数量
    return ce.sum() / mask.sum().clamp(min=1.0)
```

### 11.5.2 为什么 mask 也要移位

Loss Mask 是和 `tokens` 对齐的，但损失函数预测的是 `tokens[t+1]` 给定 `tokens[0..t]`。所以：

```
tokens:     [t0  t1  t2  t3  t4  t5]
mask:       [0   0   1   1   1   0]
targets:    [t1  t2  t3  t4  t5  ?]    ← tokens[:, 1:]
shift_mask: [0   1   1   1   0   ?]    ← mask[:, 1:]
```

**移位后的 mask 表示"这个 target token 是否应该被训练"**。

举例：位置 2 的 mask=1，说明我们训练模型从 `t0, t1, t2` 预测 `t3`。这是对的——`t3` 是 assistant 内容。

### 11.5.3 与预训练 loss 的对比

```python
# 预训练 loss（第 7 章）
loss = F.cross_entropy(logits.reshape(-1, V), targets.reshape(-1))

# SFT loss
ce = F.cross_entropy(logits.reshape(-1, V), targets.reshape(-1), reduction="none")
ce = ce.view(B, T-1) * mask
loss = ce.sum() / mask.sum()
```

唯一区别就是乘了一个 mask。当 mask 全为 1 时，SFT loss 退化为预训练 loss。

### 11.5.4 loss 的数值含义

- **初始 loss**：≈ ln(V) ≈ 10.83（与预训练一样）
- **训练后**：SFT loss 通常比预训练 loss 低很多（3-5 左右），因为：
  1. 只计算 assistant 部分的 loss（去掉了大量 prompt token）
  2. 对话数据比随机文本更可预测
  3. 模型已经在预训练中学会了语言

## 11.6 数据准备：三个数据集

### 11.6.1 数据来源

| 数据集 | 来源 | 用途 | 大小 |
|--------|------|------|------|
| Alpaca | tatsu-lab/alpaca | 通用指令跟随 | ~52k 条 |
| Dolly-15k | databricks/databricks-dolly-15k | 通用指令跟随 | ~15k 条 |
| GSM8K | openai/gsm8k (train) | 数学推理 | ~7.5k 条 |

### 11.6.2 数据转换流程

```python
# scripts/prepare_sft_data.py

# 1. 从 HuggingFace 下载并转换
def collect_examples(context_length, limit_per_set=None):
    examples = []

    # Alpaca
    alpaca = load_dataset("tatsu-lab/alpaca", split="train")
    for ex in alpaca:
        messages = alpaca_to_messages(ex)
        ids, mask = encode_chat(messages)
        if len(ids) <= context_length and sum(mask) > 0:
            examples.append((ids, mask))

    # Dolly（同样的流程）
    # GSM8K（需要特殊的 think/answer 转换）

    return examples

# 2. 打乱 + 拆分
rng.shuffle(examples)
n_dev = int(len(examples) * 0.02)
dev, train = examples[:n_dev], examples[n_dev:]

# 3. 打包并写入 HDF5
write_packed(train, context_length, "sft_packed.h5")
write_packed(dev, context_length, "sft_dev_packed.h5")
```

### 11.6.3 过滤条件

```python
if len(ids) <= context_length and sum(mask) > 0:
    examples.append((ids, mask))
```

两个条件：
1. **长度限制**：超过 `context_length` 的对话会被丢弃（不是截断，是丢弃）
2. **有效 mask**：必须有至少一个 mask=1 的 token（防止空对话）

### 11.6.4 HDF5 存储格式

```
sft_packed.h5
├── tokens     (N, context_length)  int32
└── loss_mask  (N, context_length)  int8
```

与预训练数据的区别：多了一个 `loss_mask` 数据集。

## 11.7 数据加载器

### 11.7.1 get_sft_batch_iterator

```python
# data_loader/sft_dataset.py

def get_sft_batch_iterator(data_path, batch_size, device="cpu",
                           *, rank=0, world_size=1,
                           shuffle=True, infinite=True):
    with h5py.File(data_path, "r") as f:
        tokens = f["tokens"]
        masks = f["loss_mask"]
        n = tokens.shape[0]
        idxs = np.arange(rank, n, world_size)    # DDP 分片

        epoch = 0
        rng = np.random.default_rng(1234 + rank)
        while True:
            if shuffle:
                rng.shuffle(idxs)
            for start in range(0, len(idxs) - batch_size + 1, batch_size):
                batch = np.sort(idxs[start:start + batch_size])
                tk = torch.tensor(np.asarray(tokens[batch]), dtype=torch.long, device=device)
                mk = torch.tensor(np.asarray(masks[batch]), dtype=torch.long, device=device)
                yield tk, mk, epoch
            epoch += 1
            if not infinite:
                return
```

与预训练数据加载器的核心区别：
1. **返回三元组** `(tokens, loss_mask, epoch)` 而非 `(tokens, epoch)`
2. **epoch 信号**：让训练脚本知道何时停止（`max_steps=-1` 时按 epoch 控制）
3. **HDF5 保持打开**：整个训练期间只打开一次，避免反复 I/O

## 11.8 训练脚本：train_sft.py

### 11.8.1 整体流程

```python
# scripts/train_sft.py

def main():
    cfg, _ = parse_config_with_json(SFTConfig, "configs/sft.json")
    ctx = ddp_setup(cfg.device)

    # 1. 加载预训练 backbone
    model = load_backbone_from_ckpt(cfg, cfg.pretrained_ckpt, ctx.device)
    model = ddp_wrap(model, ctx)

    # 2. 准备数据
    train_it = get_sft_batch_iterator(cfg.data_path, cfg.batch_size, ...)

    # 3. 估算总步数
    n_rows = f["tokens"].shape[0]
    steps_per_epoch = n_rows // (cfg.batch_size * ctx.world_size)
    total_steps = steps_per_epoch * cfg.epochs

    # 4. 训练循环
    for step in range(total_steps):
        tokens, mask, epoch = next(train_it)
        logits, _ = model(tokens)
        loss = sft_loss(logits, tokens, mask)    # ← 唯一不同：用了 mask
        loss.backward()
        optimizer.step()
```

### 11.8.2 与预训练训练循环的对比

| | 预训练 (pretrain_base.py) | SFT (train_sft.py) |
|---|---|---|
| 数据来源 | PretrainDataLoader（分片 + 偏移） | SFT 数据加载器（DDP 分片 + shuffle） |
| 损失函数 | 标准 CE | Masked CE |
| 梯度累积 | 有（grad_accum 步） | 无（每步直接更新） |
| 学习率 | cosine with warmup | cosine with warmup |
| 评估 | dev loss（标准 CE） | dev loss（masked CE） |
| 训练长度 | train_steps 固定步数 | epochs（数据驱动） |

### 11.8.3 评估

```python
@torch.no_grad()
def eval_dev(model, cfg, ctx, dev_path, max_batches=50):
    model.eval()
    it = get_sft_batch_iterator(dev_path, cfg.batch_size, ...,
                                shuffle=False, infinite=False)
    total, n = 0.0, 0
    for tokens, mask, _ in it:
        logits, _ = model(tokens)
        loss = sft_loss(logits, tokens, mask)
        total += loss.item(); n += 1
        if n >= max_batches:
            break
    model.train()
    return total / max(1, n)
```

评估也用 masked loss——只看模型在 assistant 部分的表现。

### 11.8.4 训练输出示例

```
SFT from /ephemeral/ckpts/base_pretrained.pt | world_size=2
1234 packed rows | ~38 steps/epoch | total_steps=114
step 0/114 | loss 4.8234 | ppl 124.36 | lr 1.00e-07 | 2.1s/20
step 20/114 | loss 3.2156 | ppl 24.92 | lr 5.00e-06 | 1.8s/20
  [eval] step 40 | dev_loss 3.4521 | dev_ppl 31.56
step 40/114 | loss 3.1234 | ppl 22.71 | lr 1.00e-05 | 1.9s/20
...
Done SFT. dev_loss 2.8765 -> /ephemeral/ckpts/sft.pt
```

## 11.9 context_length 对齐的重要性

### 11.9.1 三方一致原则

`context_length` 这个值必须在三个地方完全一致：

```
数据准备（prepare_sft_data.py --context_length 1024）
    ↓
模型定义（BaseModelConfig.context_length = 1024）
    ↓
Checkpoint 加载（位置编码的长度）
```

如果任何一处不匹配，会出什么问题？

### 11.9.2 场景分析

**场景 1：数据 context_length > 模型 context_length**

```
数据打包为 1024 tokens/行
模型只接受 256 tokens

→ 模型的 position embedding 只有 256 个位置
→ 输入 1024 tokens 时，位置 256+ 的 embedding 不存在
→ 运行时报错：IndexError
```

**场景 2：数据 context_length < 模型 context_length**

```
数据打包为 256 tokens/行
模型接受 1024 tokens

→ 不会报错，但浪费模型的上下文窗口
→ 对话被截断为 256 tokens，很多长对话丢失
```

**场景 3：模型 A 的 checkpoint 加载到模型 B（不同 context_length）**

```
模型 A 保存：position embedding shape (1024, 256)
模型 B 加载：position embedding shape (256, 256)

→ load_state_dict 时 shape 不匹配
→ 如果 strict=True，报错
→ 如果 strict=False，position embedding 不被加载，模型性能骤降
```

### 11.9.3 configs/base.json 的 context_length

```json
// configs/base.json
{
  "context_length": 256,
  ...
}
```

**注意**：默认 `configs/base.json` 中的 `context_length=256`，而 dataclass 默认值是 1024。这意味着：
- 如果不指定 `--context_length 256` 准备数据，数据会按 1024 打包
- 但模型实际只有 256 的位置编码
- 训练会崩溃

**正确做法**：始终保持三处一致。最简单的办法是用 `--print-config` 验证：

```bash
# 检查模型的 context_length
python scripts/train_sft.py --print-config | grep context_length

# 准备数据时用同样的值
python scripts/prepare_sft_data.py --context_length 256
```

## 11.10 SFT 前后的行为对比

### 11.10.1 生成效果对比

**SFT 前（预训练模型）**：

```
输入: What is the capital of France?
输出: What is the capital of France? The capital of France is Paris.
      What is the capital of Germany? The capital of Germany is Berlin.
      What is the capital of Italy? The capital of Italy is Rome.
      ...
```

模型把问题当成要续写的文本，不断产生 QA 对。

**SFT 后**：

```
输入: <|user|>
What is the capital of France?
<|assistant|>
输出: The capital of France is Paris.
```

模型学会了"看到 `<|assistant|>` 就生成回答，然后停止"。

### 11.10.2 GSM8K 效果

**SFT 前**：完全无法解题（模型不理解指令格式）

**SFT 后**：

```
输入: <|user|>
Janet has 10 snowballs. She gives 3 to her friend. How many does she have left?
<|assistant|>
输出: <think>Janet starts with 10 snowballs. She gives away 3.
10 - 3 = 7.</think><answer>7</answer>
```

模型学会了 `<think>...<answer>` 格式，但答案不一定正确。

### 11.10.3 Loss 的变化

| 阶段 | Train Loss | Dev Loss | 说明 |
|------|-----------|----------|------|
| SFT 开始 | ~5-6 | ~5-6 | 预训练模型在对话数据上的初始 loss |
| SFT 中期 | ~3-4 | ~3-4 | 模型学会了对话格式 |
| SFT 结束 | ~2.5-3.5 | ~3-4 | 接近收敛 |

SFT 的 loss 下降速度通常比预训练快得多——因为模型已经在预训练中学会了语言，SFT 只需要调整"行为模式"。

## 11.11 本章小结

### Chat Template 设计

| 组件 | 实现 | 原因 |
|------|------|------|
| 角色标记 | 普通文本 `<\|user\|>\n` | tiktoken 只有一个特殊 token |
| Turn 分隔 | `<\|endoftext\|>` | 复用唯一的 EOT |
| 推理结构 | `<think>...<answer>N` | 可解释 + 可验证 |
| 生成提示 | 尾部加 `<\|assistant\|>\n` | 提示模型开始回答 |

### Loss Mask 设计

| 位置 | mask 值 | 原因 |
|------|---------|------|
| 角色 header | 0 | 不训练模型生成 header |
| 用户内容 | 0 | 不训练模型复述问题 |
| assistant 内容 | 1 | 训练模型生成回答 |
| assistant EOT | 1 | 训练模型学会停止 |
| 用户 EOT | 0 | 不需要模型预测 turn 切换 |

### 数据管线

```
原始数据 → encode_chat(ids, mask) → pack_examples → HDF5
→ get_sft_batch_iterator → sft_loss → 梯度更新
```

### 关键原则

1. **context_length 三方一致**：数据准备 × 模型定义 × checkpoint
2. **mask 移位**：loss 计算时 mask 和 targets 同步移位
3. **EOT 参与训练**：assistant turn 的 EOT mask=1，教会模型停止
4. **打包效率**：短对话不浪费计算，EOT 充当天然分隔符

---

## 练习

**练习 1：手动构建 Loss Mask**

给定以下对话：

```python
messages = [
    {"role": "user", "content": "1+1=?"},
    {"role": "assistant", "content": "2"}
]
```

假设每个字符串恰好 1 个 token（简化），`<|user|>\n` 是 2 个 token，`<|assistant|>\n` 是 2 个 token，EOT 是 1 个 token。

写出完整的 `ids` 和 `mask` 序列。

**练习 2：打包计算**

有 3 条对话，长度分别为 100、200、150 tokens。`context_length=256`。

1. 不打包（padding 到 256）：需要多少行？有效 token 比例？
2. 打包后：得到多少行？有效 token 比例？

**练习 3：调试 context_length 不匹配**

如果你执行：

```bash
python scripts/prepare_sft_data.py --context_length 1024
python scripts/train_sft.py  # 使用 configs/base.json（context_length=256）
```

会发生什么？如何修复？

**练习 4：代码追踪**

从 `train_sft.py` 的 `loss = sft_loss(logits, tokens, mask)` 开始，追踪数据流：
1. `tokens` 的 shape 是什么？来自哪里？
2. `logits` 是怎么产生的？经过了哪些变换？
3. `mask` 是如何影响最终 loss 值的？
4. 如果 `mask` 全为 0，`sft_loss` 会返回什么？
