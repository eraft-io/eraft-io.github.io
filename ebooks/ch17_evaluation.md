# 第 17 章：评估与基准测试

> **本章目标**：掌握以 GSM8K 准确率为贯穿性指标的评估体系，理解贪心解码评估流程、答案解析与校验机制，学会构建跨阶段对比表。

## 17.0 本章路线图

后训练的每个阶段（SFT → DPO → PPO → GRPO）都会改变模型的行为。我们需要一个**统一的评估轴**来量化每个阶段的贡献。

```
本章覆盖的内容

评估体系
├── GSM8K 作为 head metric 的设计理由
├── 贪心解码 → <answer> 解析 → 答案校验
├── 跨阶段对比表
└── eval_post_training.py 评估脚本
```

## 17.1 GSM8K 作为贯穿性指标

### 17.1.1 为什么选 GSM8K

| 特性 | GSM8K | 其他基准 |
|------|-------|---------|
| 可自动验证 | ✓（数值答案） | MMLU 需要 MCQ 格式 |
| 需要推理 | ✓（多步数学） | 简单 QA 不需要 |
| 数据量充足 | 7.5k train + 1.3k test | — |
| 难度适中 | 小模型 5-25% | 太简单或太难 |
| 有 reasoning 格式 | ✓（CoT） | — |
| 可用作 RL 奖励 | ✓（verifier） | 开放任务无法自动打分 |

GSM8K 贯穿整个 Pipeline 的每个环节：

```
SFT 阶段：  学习 <think>...<answer> 格式 → 评估格式正确率 + GSM8K acc
DPO 阶段：  优化偏好 → 评估隐式奖励准确率 + GSM8K acc
PPO 阶段：  verifier 打分 → 评估 reward + GSM8K acc
GRPO 阶段： group advantages → 评估 reward + GSM8K acc
```

### 17.1.2 评估集的选择

```python
# src/post_training/evaluation.py

def load_gsm8k_eval(split="test", limit=200):
    ds = load_dataset("openai/gsm8k", "main", split=split)
    if limit:
        ds = ds.select(range(min(limit, len(ds))))
    return [(ex["question"], ex["answer"]) for ex in ds]
```

默认取 GSM8K 测试集的前 200 题。这个数量在**速度和统计显著性之间平衡**——200 题跑一次约 2-5 分钟，准确率的 95% 置信区间约 ±6%。

### 17.1.3 评估数据与训练数据的关系

```
GSM8K train（~7.5k 题）→ SFT 训练数据 + RL prompts
GSM8K test（~1.3k 题）→ 评估集（不参与训练）
```

严格的数据隔离确保评估结果反映的是**泛化能力**而非记忆。

## 17.2 贪心解码评估流程

### 17.2.1 为什么用贪心解码

| 解码策略 | 随机性 | 用途 |
|---------|--------|------|
| 贪心（argmax） | 无 | 评估（结果可复现） |
| Temperature + top-p | 有 | 训练时的 rollout、对话 |

评估需要**确定性**——同样的模型和输入必须得到同样的输出，否则无法做跨阶段的公平对比。

### 17.2.2 gsm8k_accuracy 流程

```python
# src/post_training/evaluation.py

@torch.no_grad()
def gsm8k_accuracy(model, qa_pairs, *, device, max_new_tokens=300,
                   greedy=True, return_samples=0):
    # 1. 构建 prompt（chat 格式）
    prompts = [encode_prompt([{"role": "user", "content": q}]) for q, _ in qa_pairs]

    # 2. 批量生成（贪心解码）
    responses = batched_generate(model, prompts, max_new_tokens,
                                 device=device, greedy=greedy)

    # 3. 解析答案并校验
    correct = 0
    samples = []
    for (q, ans), resp in zip(qa_pairs, responses):
        gold = gsm8k_gold_answer(ans)      # 从 #### N 提取标准答案
        ok = is_correct(resp, gold)        # 解析模型输出并比对
        correct += int(ok)
        ...
    return {"accuracy": correct / max(1, n), "n": n, "correct": correct, "samples": samples}
```

### 17.2.3 batched_generate：按长度分桶

```python
# src/post_training/evaluation.py

@torch.no_grad()
def batched_generate(model, prompts, max_new_tokens, *, device,
                     temperature=1.0, top_k=None, top_p=None, greedy=False, micro_batch=32):
    if greedy:
        temperature, top_k, top_p = 1.0, 1, None    # top_k=1 = argmax

    cap = _model_context_length(model)
    order = sorted(range(len(prompts)), key=lambda i: len(prompts[i]))
    results = [None] * len(prompts)

    i = 0
    while i < len(order):
        # 取相同长度的 prompt 组成 batch
        j = i
        L = len(prompts[order[i]])
        while j < len(order) and len(prompts[order[j]]) == L and (j - i) < micro_batch:
            j += 1
        idxs = order[i:j]
        i = j
        budget = min(max_new_tokens, cap - L)
        batch = torch.tensor([prompts[k] for k in idxs], dtype=torch.long, device=device)
        rb = generate_with_logprobs(model, batch, budget, ...)
        # 截取生成部分并解码
        gen = rb.sequences[:, L:]
        for row, k in enumerate(idxs):
            toks = gen[row].tolist()
            if EOT_ID in toks:
                toks = toks[:toks.index(EOT_ID)]
            results[k] = decode(toks)
    return [r or "" for r in results]
```

**为什么按长度分桶？**

本项目的 Transformer 没有 padding-aware attention mask——所有位置的 attention 都是完整的因果 attention。如果不同长度的 prompt 放在一个 batch 里，短 prompt 的 padding 位置会干扰 attention 计算。按长度分桶确保同一 batch 内所有 prompt 等长。

### 17.2.4 生成后的后处理

```python
# 截断在第一个 EOT（模型学会的停止信号）
if EOT_ID in toks:
    toks = toks[:toks.index(EOT_ID)]
# 解码为文本
results[k] = decode(toks)
```

`decode` 函数（chat_template.py）会防御性地跳过 `id >= 50256` 的 token（模型 vocab 是 50304，但 r50k_base 只能解码 0..50255）。

## 17.3 `<answer>` 标签解析与答案校验

### 17.3.1 三级回退解析

```python
# src/post_training/rewards/parsing.py

def extract_answer(text):
    # 1. 优先：<answer>42</answer>
    m = _ANSWER_RE.search(text)
    if m:
        n = parse_number(m.group(1))
        if n is not None:
            return n

    # 2. 回退：#### 42（GSM8K 原始格式）
    m = _HASH_RE.search(text)
    if m:
        n = parse_number(m.group(1))
        if n is not None:
            return n

    # 3. 最后回退：文本中最后一个数字
    nums = _NUMBER_RE.findall(text)
    if nums:
        return parse_number(nums[-1])
    return None
```

**为什么需要三级回退？**

小模型不一定能完美生成 `<answer>` 标签：

```
理想输出: "<think>...</think><answer>42</answer>"    → 第 1 级命中
部分格式: "Let me think... #### 42"         → 第 2 级命中
无格式:   "The answer is 42 dollars."        → 第 3 级命中
完全无关: "I don't know how to solve this."  → None（判为错误）
```

### 17.3.2 数字解析的容错

```python
_NUMBER_RE = re.compile(r"-?\$?\d[\d,]*(?:\.\d+)?")

def parse_number(s):
    m = _NUMBER_RE.search(s)
    raw = m.group(0).replace(",", "").replace("$", "")
    return float(raw)
```

支持的格式：

| 输入 | 解析结果 |
|------|---------|
| "42" | 42.0 |
| "$1,234" | 1234.0 |
| "-3.14" | -3.14 |
| "1,000,000" | 1000000.0 |

### 17.3.3 答案校验

```python
# src/post_training/rewards/verifiers.py

FLOAT_TOL = 1e-4

def _answers_match(pred, gold):
    if pred is None or gold is None:
        return False
    return math.isclose(pred, gold, rel_tol=0.0, abs_tol=FLOAT_TOL)

def is_correct(text, gold):
    return _answers_match(extract_answer(text), gold)
```

**绝对容差 1e-4**：处理浮点精度问题（如 `7.0` vs `7.00001`）。使用 `rel_tol=0.0`（不做相对容差），因为 GSM8K 的答案都是整数或简单小数。

### 17.3.4 Gold Answer 提取

```python
def gsm8k_gold_answer(answer_field):
    """从 GSM8K 的 answer 字段提取 #### 后的数字"""
    m = _HASH_RE.search(answer_field)
    if m:
        return parse_number(m.group(1))
    return parse_number(answer_field)
```

## 17.4 跨阶段对比表

### 17.4.1 评估脚本

```python
# scripts/eval_post_training.py

def model_from_ckpt(ckpt_path, device, overrides=None):
    ck = torch.load(ckpt_path, map_location="cpu", weights_only=False)
    cfg = ck.get("cfg", {}) or {}
    cfg = {**cfg, **(overrides or {})}
    model = Transformer(
        n_head=cfg.get("n_head", 16), n_embed=cfg.get("n_embed", 1024),
        context_length=cfg.get("context_length", 1024),
        vocab_size=cfg.get("vocab_size", 50304),
        N_BLOCKS=cfg.get("n_blocks", 24),
    )
    state = ck["model_state_dict"] if "model_state_dict" in ck else ck
    state = {k.removeprefix("module.").removeprefix("transformer."): v for k, v in state.items()}
    backbone_keys = set(model.state_dict().keys())
    filtered = {k: v for k, v in state.items() if k in backbone_keys}
    model.load_state_dict(filtered, strict=False)
    return model.to(device).eval()
```

**从 checkpoint 读取模型维度**：不需要手动指定 `n_embed`、`n_blocks` 等——它们保存在 checkpoint 的 `cfg` 字段中。

### 17.4.2 批量评估所有阶段

```bash
for s in base_pretrained sft dpo ppo grpo; do
  PYTHONPATH=. python scripts/eval_post_training.py \
    --ckpt /ephemeral/ckpts/$s.pt --label $s --limit 200 \
    --append /ephemeral/logs/stage_table.jsonl
done
```

### 17.4.3 打印对比表

```bash
PYTHONPATH=. python scripts/eval_post_training.py --table /ephemeral/logs/stage_table.jsonl
```

输出：

```
stage               GSM8K acc       n
------------------------------------
base_pretrained         0.0%     200
sft                    12.5%     200
dpo                    15.0%     200
ppo                    18.5%     200
grpo                   20.0%     200
```

### 17.4.4 预期结果分析

| 阶段 | 预期准确率 | 主要贡献 |
|------|-----------|---------|
| Base | ~0% | 不会回答（续写模式） |
| SFT | 5-15% | 学会格式 + 基础推理 |
| DPO | 8-18% | 偏好优化，质量略有提升 |
| PPO | 10-25% | RL 进一步优化推理 |
| GRPO | 10-25% | 类似 PPO，验证器奖励 |

**注意**：~400M 的小模型在 GSM8K 上的绝对准确率不会很高（前沿模型 90%+）。本项目的价值在于展示**真实的跨阶段提升**，而非追求绝对数字。

### 17.4.5 评估样例

```bash
PYTHONPATH=. python scripts/eval_post_training.py \
    --ckpt /ephemeral/ckpts/grpo.pt --label grpo --samples 3
```

输出：

```
[grpo] GSM8K test accuracy: 20.0%  (40/200)

  Q: Janet has 10 snowballs. She gives 3 to her friend. How many does she have left?
  gold=7.0 correct=True
  A: <think>Janet starts with 10 snowballs. She gives 3 away. 10 - 3 = 7.</think><answer>7</answer>

  Q: A store sells apples for $2 each. If you buy 5, how much do you pay?
  gold=10.0 correct=False
  A: <think>Each apple costs $2. Buying 5 means 2 + 5 = 7.</think><answer>7</answer>
```

第二个例子展示了小模型的典型错误：推理过程有误（加法代替乘法）。

## 17.5 评估的注意事项

### 17.5.1 评估的随机性

即使用贪心解码，评估结果仍有一定波动：
- **硬件差异**：不同 GPU 的 bf16 实现可能有微小差异
- **模型加载**：`strict=False` 可能漏掉某些权重

**解决方案**：多次评估取平均，或固定评估集大小。

### 17.5.2 评估时间

| 阶段 | 200 题评估时间 | 说明 |
|------|---------------|------|
| Base | ~1 分钟 | 生成短（不会停止） |
| SFT | ~2-3 分钟 | 有 stop token |
| DPO/PPO/GRPO | ~3-5 分钟 | 输出更长（CoT） |

### 17.5.3 其他评估维度

除了 GSM8K 准确率，还可以关注：

| 指标 | 计算方式 | 说明 |
|------|---------|------|
| 格式正确率 | `has_well_formed_answer` 的比例 | 模型是否学会 `<answer>` |
| 平均回复长度 | response token 数 | 回复是否合理 |
| Masked Dev Loss | SFT/RM 的 dev 集 | 语言建模质量 |
| Reward / Margin | RL 阶段的 reward | 策略质量 |

## 17.6 本章小结

### 评估体系

```
统一的评估轴：GSM8K 准确率（贪心解码）

评估流程：
  1. 构建 prompt（chat template）
  2. 贪心解码生成（batched_generate）
  3. <answer> 标签解析（三级回退）
  4. 答案校验（float 容差）
  5. 汇总准确率 + 样例

跨阶段对比：
  Base → SFT → DPO → PPO → GRPO
  0%     12%    15%    18%    20%
```

### 关键设计

| 决策 | 选择 | 原因 |
|------|------|------|
| 评估基准 | GSM8K | 可自动验证 + 需要推理 |
| 解码策略 | 贪心 | 确定性，结果可复现 |
| 解析策略 | 三级回退 | 适应不同模型质量 |
| 容差 | abs_tol=1e-4 | 处理浮点精度 |
| 评估集 | 测试集前 200 题 | 速度和统计显著性平衡 |

---

## 练习

**练习 1：评估不同 checkpoint**

如果有多个阶段的 checkpoint，运行完整评估并对比：

```bash
for s in sft dpo grpo; do
  PYTHONPATH=. python scripts/eval_post_training.py \
    --ckpt /ephemeral/ckpts/$s.pt --label $s --limit 50 --samples 5
done
```

观察哪个阶段的准确率最高？输出样例中有哪些共同的模式？

**练习 2：解析器测试**

手动测试 `extract_answer` 对不同输入的解析：

```python
from src.post_training.rewards.parsing import extract_answer

tests = [
    "The answer is 42.",
    "<answer>42</answer>",
    "I calculated 42.5 as the result.",
    "#### 42",
    "$42.00 is the total.",
    "I don't know.",
]
for t in tests:
    print(f"{t:50s} → {extract_answer(t)}")
```

**练习 3：贪心 vs 采样**

对同一个模型和问题，分别用贪心和采样（temperature=0.8）解码 5 次。观察：
1. 贪心的 5 次输出是否完全一样？
2. 采样的 5 次输出有什么变化？
3. 哪种策略得到的正确答案更多？
