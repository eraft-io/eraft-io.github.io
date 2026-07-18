# 第 6 章：预训练数据准备

> **本章目标**：理解预训练数据的来源、格式和处理流程，学会从原始文本到 HDF5 格式的完整数据准备管线。

## 6.0 本章路线图

在第 1-5 章中，我们构建了 Transformer 模型，理解了分词、架构和优化。现在要让模型"看到"真正的语言数据。

预训练数据准备是一个**数据管线（Pipeline）**：

```
原始 JSONL.zst 文件
    ↓ 流式下载
本地 .jsonl.zst 压缩文件
    ↓ 解压 + 解析
Python 文本字符串
    ↓ BPE 分词
整数 token 序列（附带 EOT 分隔符）
    ↓ 批量写入
HDF5 文件（高效存储和随机访问）
    ↓ 训练时读取
(batch_size, context_length) 的输入 + 目标张量
```

本章覆盖这个管线的每一步。

## 6.1 The Pile 数据集

### 6.1.1 什么是 The Pile

[The Pile](https://pile.eleuther.ai/) 是 EleutherAI 发布的大规模多领域文本数据集，专为训练大语言模型设计：

- **总规模**：约 825 GB，包含超过 3000 亿个 token
- **22 个来源**：Common Crawl、GitHub、Wikipedia、PubMed、Stack Exchange、Books3 等
- **多样性**：覆盖编程、科学、文学、新闻、社交媒体等多种领域

本项目使用 [pile-uncopyrighted](https://huggingface.co/datasets/monology/pile-uncopyrighted) 版本——一个经过版权清理的子集，可以在商业项目中使用。

### 6.1.2 数据格式

The Pile 以 **JSONL + Zstandard 压缩**格式分发：

```
pile-uncopyrighted/
├── val.jsonl.zst                    # 验证集（~370 MB 压缩）
└── train/
    ├── 00.jsonl.zst                 # 训练集第 1 个 shard（~10 GB 压缩）
    ├── 01.jsonl.zst                 # 训练集第 2 个 shard
    ├── ...
    └── 64.jsonl.zst                 # 训练集第 65 个 shard
```

每个 `.jsonl.zst` 文件是 Zstandard 压缩的 JSONL（每行一个 JSON 对象）：

```json
{"text": "The mitochondria is the powerhouse of the cell.", "meta": {"pile_set_name": "Wikipedia"}}
{"text": "def fibonacci(n):\n    if n <= 1:\n        return n", "meta": {"pile_set_name": "Github"}}
{"text": "In a hole in the ground there lived a hobbit.", "meta": {"pile_set_name": "Books3"}}
```

我们只关心 `"text"` 字段——`"meta"` 包含数据来源等元信息，在预训练中不使用。

### 6.1.3 为什么选 Zstandard？

| 压缩格式 | 压缩率 | 解压速度 | Python 支持 |
|----------|--------|---------|-------------|
| gzip | 好 | 慢 | 内置 |
| bz2 | 很好 | 很慢 | 内置 |
| **zstd** | **很好** | **快** | `zstandard` 库 |
| lz4 | 一般 | 最快 | `lz4` 库 |

Zstandard 在压缩率和解压速度之间取得了很好的平衡，且支持**流式解压**——不需要先把整个文件解压到内存，可以边解压边处理。

## 6.2 流式下载

### 6.2.1 为什么要流式下载

The Pile 的完整训练集约 800 GB，直接全部下载不现实。本项目的策略是：

1. **按需下载**：只下载需要的 shard（默认 1 个训练 shard + 验证集）
2. **流式处理**：下载完成后立即解压分词，不保留解压后的中间文件
3. **缓存机制**：已下载的文件跳过，支持断点续传

### 6.2.2 下载代码解析

```python
# scripts/prepare_pretrain_data.py

BASE_URL = "https://huggingface.co/datasets/monology/pile-uncopyrighted/resolve/main"

def shard_urls(split: str, num_shards: int) -> list[str]:
    """生成指定 split 和 shard 数量的 URL 列表"""
    if split == "val":
        return [f"{BASE_URL}/val.jsonl.zst"]
    return [f"{BASE_URL}/train/{i:02d}.jsonl.zst" for i in range(num_shards)]

def download(url: str, dest: str) -> str:
    if os.path.exists(dest):
        print(f"  cached: {dest}")
        return dest
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        total = int(r.headers.get("content-length", 0))
        with open(dest + ".part", "wb") as f:
            for chunk in tqdm(r.iter_content(1 << 20), total=total >> 20,
                              unit="MB", desc="dl"):
                f.write(chunk)
    os.replace(dest + ".part", dest)  # 原子重命名，防止下载中断损坏
    return dest
```

关键细节：
- **`.part` 后缀**：下载时先写到 `xxx.part`，完成后原子重命名。如果下载中断，`.part` 文件不会被误认为完整文件
- **`iter_content(1 << 20)`**：每次读取 1 MB，避免内存溢出
- **缓存检查**：如果文件已存在，直接返回，避免重复下载

## 6.3 解压与分词

### 6.3.1 流式解压

```python
# scripts/prepare_pretrain_data.py

def iter_texts(zst_path: str):
    """流式读取 Zstandard 压缩的 JSONL 文件，逐条产出文本"""
    dctx = zstd.ZstdDecompressor()
    with open(zst_path, "rb") as fh:
        reader = dctx.stream_reader(fh)              # 流式解压，不加载整个文件
        for line in io.TextIOWrapper(reader, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            try:
                txt = json.loads(line).get("text")   # 只取 text 字段
            except json.JSONDecodeError:
                continue
            if txt:
                yield txt
```

这是一个 Python **生成器（generator）**：每次调用产出一个文本，而不是把所有文本加载到内存。这对于 50 GB 的文件至关重要——内存只需要保存当前一条文档。

### 6.3.2 批量分词

分词是 CPU 密集操作。为了加速，项目使用了 tiktoken 的**批量编码**：

```python
EOT_ID = 50256     # <|endoftext|> 的 token ID
ENC_BATCH = 1024   # 每次批量编码 1024 个文档

enc = tiktoken.get_encoding("r50k_base")
docs: list[str] = []

for txt in iter_texts(zst_path):
    docs.append(txt)
    if len(docs) >= ENC_BATCH:
        # 批量编码 1024 个文档
        for ids in enc.encode_ordinary_batch(docs):
            buf.extend(ids)
            buf.append(EOT_ID)    # 文档之间用 EOT 分隔
        docs = []
```

为什么用 `encode_ordinary_batch` 而不是 `encode_batch`？

- `encode` 默认不允许特殊 token（如 `<|endoftext|>`），遇到时会报错
- `encode_ordinary` 把文本当作普通文本编码，不会尝试识别特殊 token
- 因为我们手动在文档末尾追加 `EOT_ID`，不需要分词器自己处理

### 6.3.3 EOT 分隔符的作用

`<|endoftext|>`（token ID 50256）是文档之间的分隔符：

```
文档 1 的 token 序列: [1234, 5678, 9012, ...]  EOT  文档 2: [4567, 8901, ...]  EOT  ...
```

它告诉模型"这里是一个新文档的开始，前一个文档的内容已经结束了"。虽然模型在预训练中不显式地使用这个信号（因果注意力会自动处理），但 EOT 的存在让模型学会在适当的位置重新开始话题。

## 6.4 HDF5 存储格式

### 6.4.1 为什么选 HDF5

分词后的数据是一个**巨大的整数数组**（数十亿个 int32）。我们需要一个存储格式满足：

| 需求 | HDF5 | JSON | SQLite | NumPy .npy |
|------|------|------|--------|------------|
| 大文件（>10 GB） | 支持 | 差 | 支持 | 支持 |
| 随机访问 | 快 | 不支持 | 支持 | 支持 |
| 流式写入 | 支持 | 支持 | 支持 | 不支持 |
| 压缩 | 支持 | 不支持 | 不支持 | 不支持 |
| Python 支持 | h5py | 内置 | sqlite3 | numpy |

HDF5 是唯一同时满足所有需求的格式。

### 6.4.2 写入代码解析

```python
# scripts/prepare_pretrain_data.py

WRITE_CHUNK = 8_000_000  # 每 800 万个 token 刷写一次

def tokenize_to_h5(zst_paths: list[str], out_path: str, max_tokens: int | None) -> int:
    enc = tiktoken.get_encoding("r50k_base")
    total = 0
    buf: list[int] = []

    with h5py.File(out_path, "w") as f:
        # 创建可扩展的数据集：初始大小 0，最大无限制
        dset = f.create_dataset("tokens", (0,), maxshape=(None,),
                                 dtype="i4", chunks=(WRITE_CHUNK,))

        def flush():
            nonlocal total, buf
            if not buf:
                return
            arr = np.asarray(buf, dtype=np.int32)
            dset.resize(total + arr.size, axis=0)    # 扩展数据集
            dset[total: total + arr.size] = arr       # 写入
            total += arr.size
            buf = []

        for zp in zst_paths:
            for txt in iter_texts(zp):
                docs.append(txt)
                if len(docs) >= ENC_BATCH:
                    for ids in enc.encode_ordinary_batch(docs):
                        buf.extend(ids)
                        buf.append(EOT_ID)
                    docs = []
                    if len(buf) >= WRITE_CHUNK:
                        flush()
            # 处理剩余文档
            if docs:
                for ids in enc.encode_ordinary_batch(docs):
                    buf.extend(ids)
                    buf.append(EOT_ID)
            flush()

    print(f"  wrote {total:,} tokens -> {out_path}")
    return total
```

关键设计：

1. **`maxshape=(None,)`**：数据集可以无限扩展，不需要预先知道总大小
2. **`chunks=(WRITE_CHUNK,)`**：按 800 万 token 一块存储，优化读写性能
3. **`buf` 缓冲区**：先攒够 800 万 token，再一次性写入 HDF5，避免频繁的小写入
4. **`dtype="i4"`**：int32 格式，每个 token 占 4 字节（足够存储 0-50303 的 token ID）

### 6.4.3 HDF5 文件结构

```
pile_train.h5
└── tokens    (N,) int32    ← 一个巨大的一维数组
```

所有 token 拼成一个长数组。没有文档边界信息——训练时按固定长度切割序列。

## 6.5 数据加载器

### 6.5.1 从 HDF5 到训练 batch

训练时，数据加载器从 HDF5 文件中随机抽取 `(batch_size, context_length)` 的序列：

```python
# data_loader/data_loader.py

def get_batch_iterator(data_path, batch_size, context_length, device="cpu"):
    with h5py.File(data_path, 'r') as hdf5_file:
        dataset = hdf5_file['tokens']
        dataset_size = dataset.shape[0]

        # 计算可以切出多少个不重叠的序列
        n_examples = (dataset_size - 1) // context_length

        # 随机打乱序列索引
        example_idxs = np.arange(n_examples)
        np.random.shuffle(example_idxs)

        counter = 0
        while True:
            if counter + batch_size > n_examples:
                np.random.shuffle(example_idxs)
                counter = 0

            # 取出一个 batch 的起始位置
            random_indices = example_idxs[counter:counter+batch_size] * context_length

            # 读取序列和对应的目标（偏移 1 个 token）
            samples = [dataset[idx:idx+context_length+1] for idx in random_indices]
            xb = torch.tensor(np.array([s[:-1] for s in samples])).to(device)
            yb = torch.tensor(np.array([s[1:]  for s in samples])).to(device)

            counter += batch_size
            yield xb, yb
```

### 6.5.2 输入和目标的错位关系

这是 LLM 预训练的核心概念——**下一个 token 预测**：

```
原始 token 序列: [A, B, C, D, E]  (context_length=4)

输入 xb:  [A, B, C, D]     ← 模型看到的
目标 yb:  [B, C, D, E]     ← 模型要预测的

位置 0: 看到 A → 预测 B
位置 1: 看到 A,B → 预测 C
位置 2: 看到 A,B,C → 预测 D
位置 3: 看到 A,B,C,D → 预测 E
```

代码中通过 `dataset[idx:idx+context_length+1]` 多读一个 token，然后 `xb = s[:-1]`，`yb = s[1:]` 实现错位。

### 6.5.3 无限迭代器

`get_batch_iterator` 是一个**无限迭代器**（`while True`）。当所有序列用完后，重新打乱索引继续。这是因为：

- 预训练步数是固定的（如 200,000 步），不以 epoch 为单位
- 不同 shard 的数据量不同，统一用步数更灵活
- 训练中断后可以从 checkpoint 的 `step` 恢复，不需要关心数据位置

## 6.6 数据规模与训练步数

### 6.6.1 估算数据量

```python
# 检查 HDF5 文件的 token 数量
import h5py
with h5py.File("/ephemeral/data/pile_train.h5", "r") as f:
    n_tokens = f["tokens"].shape[0]
    print(f"Total tokens: {n_tokens:,}")
    print(f"Approx: {n_tokens / 1e9:.2f}B tokens")
```

### 6.6.2 训练步数估算

```
有效 batch = batch_size x grad_accum x world_size
           = 8 x 12 x 1 = 96 sequences/step

每步 token 数 = 有效 batch x context_length
              = 96 x 256 = 24,576 tokens/step

总训练步数 = 总 token 数 / 每步 token 数
           = 1,500,000,000 / 24,576
           约 61,000 步
```

### 6.6.3 Chinchilla 检查

回顾第 4 章的 Chinchilla 法则：

| 模型参数量 | 推荐数据量 | 本项目实际 | 比例 |
|-----------|-----------|-----------|------|
| 31M (小模型) | ~620M tokens | ~1.5B tokens | 2.4x 过训练 |
| 90M (中型) | ~1.8B tokens | ~1.5B tokens | 0.8x 略不足 |
| 400M (大型) | ~8B tokens | ~1.5B tokens | 0.2x 严重不足 |

对于学习目的，1.5B tokens 已经足够让模型学到有意义的语言模式。如果需要更好的效果，可以增加数据量或缩小模型。

## 6.7 旧版预处理脚本

项目中还有一个旧版脚本 `scripts/data_preprocess.py`，使用不同的处理策略：

```python
# scripts/data_preprocess.py（旧版）

with zstd.open(in_file, 'rt', encoding='utf-8') as in_f:
    for line in in_f:
        data = json.loads(line)
        text = data.get('text')
        if text:
            encoded = enc.encode(text + "<|endoftext|>",
                                 allowed_special={'<|endoftext|>'})
            dataset.resize(dataset.shape[0] + encoded_len, axis=0)
            dataset[start_index:end_index] = encoded
```

**旧版 vs 新版对比**：

| | 旧版 (data_preprocess.py) | 新版 (prepare_pretrain_data.py) |
|---|---|---|
| 分词 | 逐条 `encode` | 批量 `encode_ordinary_batch` |
| 写入 | 每条文档 resize 一次 | 每 800 万 token 批量写入 |
| 速度 | 慢（频繁 resize） | 快（批量 I/O） |
| 下载 | 需要单独的 `data_download.py` | 集成在下载+分词管线中 |

推荐使用新版脚本 `prepare_pretrain_data.py`。

## 6.8 完整操作指南

### 6.8.1 准备验证集

```bash
# 下载并处理验证集（~370 MB 压缩）
PYTHONPATH=. python3 scripts/prepare_pretrain_data.py \
    --split val \
    --out /ephemeral/data/pile_dev.h5
```

### 6.8.2 准备训练集

```bash
# 下载 1 个 shard 并处理（~10 GB 压缩 -> ~50 GB 解压 -> ~1.5B tokens）
PYTHONPATH=. python3 scripts/prepare_pretrain_data.py \
    --split train --num_shards 1 \
    --out /ephemeral/data/pile_train.h5

# 如果需要更多数据，增加 shard 数量
PYTHONPATH=. python3 scripts/prepare_pretrain_data.py \
    --split train --num_shards 3 \
    --out /ephemeral/data/pile_train.h5
```

### 6.8.3 限制 token 数量（快速测试）

```bash
# 只取 1000 万个 token（用于快速验证管线是否正常）
PYTHONPATH=. python3 scripts/prepare_pretrain_data.py \
    --split train --num_shards 1 \
    --out /ephemeral/data/pile_train_small.h5 \
    --max_tokens 10000000
```

### 6.8.4 验证数据

```python
import h5py
import numpy as np

# 检查训练集
with h5py.File("/ephemeral/data/pile_train.h5", "r") as f:
    tokens = f["tokens"]
    print(f"Shape: {tokens.shape}")              # (1500000000,)
    print(f"Dtype: {tokens.dtype}")               # int32
    print(f"First 20 tokens: {tokens[:20]}")      # 前 20 个 token
    print(f"Min: {tokens[:1000000].min()}, Max: {tokens[:1000000].max()}")

# 检查验证集
with h5py.File("/ephemeral/data/pile_dev.h5", "r") as f:
    tokens = f["tokens"]
    print(f"Dev shape: {tokens.shape}")
```

## 6.9 本章小结

### 数据管线回顾

```
pile-uncopyrighted (HuggingFace)
    │
    ├── prepare_pretrain_data.py --split val
    │   └── /ephemeral/data/pile_dev.h5        ← 验证集
    │
    └── prepare_pretrain_data.py --split train
        └── /ephemeral/data/pile_train.h5      ← 训练集
```

### 关键参数

| 参数 | 值 | 说明 |
|------|------|------|
| 分词器 | `r50k_base` | GPT-3 的 BPE |
| EOT token | 50256 | 文档分隔符 |
| 存储格式 | HDF5 int32 | 一个巨大的 1D 数组 |
| 写入块 | 800 万 token | 批量刷写 |
| 编码批 | 1024 文档 | 批量分词 |

### 数据加载关键概念

```
xb = tokens[t : t+context_length]        ← 输入
yb = tokens[t+1 : t+context_length+1]    ← 目标（偏移 1）
```

训练时随机打乱序列索引，实现数据 shuffle。

---

## 练习

**练习 1：数据量估算**

用 Python 检查你本地的 `pile_train.h5`：
- 总共有多少 token？
- 以 `batch_size=8, context_length=256, grad_accum=12` 的配置，可以训练多少步？
- 这些步数够训练一个 90M 参数的模型吗（Chinchilla 法则）？

**练习 2：观察 EOT 分隔符**

从 HDF5 文件中读取前 1000 个 token，找出所有的 EOT（50256）位置，统计文档的平均长度：

```python
import h5py, numpy as np
with h5py.File("/ephemeral/data/pile_train.h5", "r") as f:
    tokens = f["tokens"][:10000]
    eot_positions = np.where(tokens == 50256)[0]
    doc_lengths = np.diff(np.concatenate([[-1], eot_positions]))
    print(f"EOT 数量: {len(eot_positions)}")
    print(f"平均文档长度: {doc_lengths.mean():.0f} tokens")
    print(f"最长文档: {doc_lengths.max()} tokens")
```

**练习 3：对比新旧脚本**

阅读 `data_preprocess.py` 和 `prepare_pretrain_data.py`，列出三个主要的性能差异点。思考：如果处理 100 GB 数据，两个脚本的时间差距大概是多少？

**练习 4：自定义数据源**

修改 `prepare_pretrain_data.py`，添加一个从本地 `.txt` 文件读取数据的函数（不需要下载）。每行一个文档，用 EOT 分隔：

```python
def iter_texts_from_txt(txt_path: str):
    """从纯文本文件逐行读取文档"""
    # ... 实现 ...
    pass
```

