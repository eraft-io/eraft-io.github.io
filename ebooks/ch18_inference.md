# 第 18 章：推理与对话系统

> **本章目标**：掌握加载任意 Checkpoint 的通用推理引擎，理解 Chat 模式与 Raw 续写模式的差异，学会处理 Checkpoint key 兼容性问题，实现交互式对话。

## 18.0 本章路线图

训练好的模型需要被**使用**——加载 checkpoint，接受用户输入，生成回复。本章构建一个通用的推理引擎，支持所有后训练阶段的 checkpoint。

```
本章覆盖的内容

推理系统
├── 通用 checkpoint 加载（自动识别模型维度）
├── Chat 模式（SFT/DPO/PPO/GRPO 模型）
├── Raw 续写模式（Base 预训练模型）
├── Checkpoint key 兼容性（DDP + torch.compile 前缀）
├── 交互式 REPL
└── 解码参数调优
```

## 18.1 加载任意 Checkpoint 的通用推理引擎

### 18.1.1 核心需求

后训练产生 5 种 checkpoint：

| Checkpoint | 来源 | 特殊内容 |
|-----------|------|---------|
| base_pretrained.pt | 预训练 | 纯 backbone |
| sft.pt | SFT | 纯 backbone |
| reward.pt | Reward Model | backbone + reward_head |
| dpo.pt / ppo.pt / grpo.pt | RL | 纯 backbone |

推理引擎需要**统一加载**所有这些 checkpoint，忽略各自特有的 key（如 reward_head），只保留 backbone。

### 18.1.2 load_model_from_ckpt

```python
# src/post_training/inference.py

def load_model_from_ckpt(ckpt_path, device, overrides=None):
    ck = torch.load(ckpt_path, map_location="cpu", weights_only=False)
    cfg = {**(ck.get("cfg") or {}), **(overrides or {})}
    model = Transformer(
        n_head=cfg.get("n_head", 16), n_embed=cfg.get("n_embed", 1024),
        context_length=cfg.get("context_length", 1024),
        vocab_size=cfg.get("vocab_size", 50304),
        N_BLOCKS=cfg.get("n_blocks", 24),
    )
    state = ck["model_state_dict"] if "model_state_dict" in ck else ck
    state = _strip_ddp_prefix(state)
    keys = set(model.state_dict().keys())
    model.load_state_dict({k: v for k, v in state.items() if k in keys}, strict=False)
    return model.to(device).eval()
```

### 18.1.3 三步加载过程

```
1. 读取 checkpoint 的 cfg → 构建空模型
   ck = torch.load(...)
   cfg = ck["cfg"]
   model = Transformer(n_head=cfg["n_head"], ...)

2. 提取 state_dict → 清理前缀
   state = ck["model_state_dict"]
   state = _strip_ddp_prefix(state)    # 清理 module. / _orig_mod.

3. 过滤 + 加载
   keys = set(model.state_dict().keys())    # backbone 的 key
   filtered = {k: v for k, v in state.items() if k in keys}
   model.load_state_dict(filtered, strict=False)
   → reward_head 的 key 被忽略（不在 backbone_keys 中）
   → backbone 的 key 被加载
```

### 18.1.4 为什么从 checkpoint 读取模型维度

每个 checkpoint 都保存了训练时的完整配置：

```python
# save_stage_ckpt 中
payload = {
    "model_state_dict": ...,
    "cfg": asdict(cfg),     # ← 完整的配置（包含模型维度）
    "stage": "sft",
    ...
}
```

这意味着：
- **不需要手动指定 `n_embed`、`n_blocks` 等参数**
- **不同大小的 checkpoint 可以混用**（如 13M 的 base + 125M 的 SFT）
- **代码更健壮**：减少人工输入错误

### 18.1.5 overrides 机制

```python
cfg = {**(ck.get("cfg") or {}), **(overrides or {})}
```

`overrides` 允许在加载时覆盖 checkpoint 中的配置：

```python
# 示例：强制使用更大的 context_length
model = load_model_from_ckpt("sft.pt", "cuda", overrides={"context_length": 512})
```

常见用途：
- 调整 `context_length`（推理时可能需要更长的上下文）
- 覆盖 `device`（checkpoint 记录的是训练设备）

## 18.2 Checkpoint key 兼容性问题

### 18.2.1 问题的来源

训练过程中，模型可能被 DDP 和 `torch.compile` 包装：

```
训练时的模型包装链：
  Transformer → DDP → torch.compile
      ↓            ↓           ↓
  原始 key    module.xxx   _orig_mod.xxx
```

保存 checkpoint 时，key 可能带有以下前缀：

| 前缀 | 来源 | 示例 |
|------|------|------|
| `module.` | PyTorch DDP | `module.transformer.h.0.ln_1.weight` |
| `_orig_mod.` | torch.compile | `_orig_mod.transformer.h.0.ln_1.weight` |
| `module._orig_mod.` | DDP + compile | `module._orig_mod.transformer.h.0.ln_1.weight` |
| `transformer.` | 某些预训练脚本 | `transformer.h.0.ln_1.weight` |

### 18.2.2 _strip_ddp_prefix 实现

```python
# src/post_training/utils.py

def _strip_ddp_prefix(state_dict):
    out = {}
    for k, v in state_dict.items():
        while k.startswith("module.") or k.startswith("_orig_mod."):
            k = k.removeprefix("module.").removeprefix("_orig_mod.")
        out[k] = v
    return out
```

**为什么用 `while` 循环？**

嵌套包装可能导致多层前缀：

```
module._orig_mod.module.transformer.h.0.ln_1.weight
→ 第 1 轮：_orig_mod.module.transformer.h.0.ln_1.weight
→ 第 2 轮：module.transformer.h.0.ln_1.weight
→ 第 3 轮：transformer.h.0.ln_1.weight
→ 不再匹配 → 结束
```

### 18.2.3 实际案例

```python
# 场景 1：DDP 训练的 SFT checkpoint
state_dict = {
    "module.transformer.h.0.ln_1.weight": ...,
    "module.transformer.h.0.attn.c_attn.weight": ...,
}
# _strip_ddp_prefix 后：
# {"transformer.h.0.ln_1.weight": ..., "transformer.h.0.attn.c_attn.weight": ...}

# 场景 2：torch.compile + DDP 训练的 checkpoint
state_dict = {
    "module._orig_mod.transformer.h.0.ln_1.weight": ...,
}
# _strip_ddp_prefix 后：
# {"transformer.h.0.ln_1.weight": ...}
```

### 18.2.4 Reward Model checkpoint 的特殊处理

Reward Model 的 checkpoint 包含额外的 `reward_head` key：

```python
# Reward checkpoint 的 state_dict：
{
    "backbone.transformer.h.0.ln_1.weight": ...,    # backbone key
    "reward_head.0.weight": ...,                     # reward head（推理不需要）
    "reward_head.2.weight": ...,
}
```

推理引擎的处理方式：

```python
keys = set(model.state_dict().keys())    # Transformer backbone 的 key
filtered = {k: v for k, v in state.items() if k in keys}
model.load_state_dict(filtered, strict=False)
# → reward_head.* 被忽略（不在 backbone_keys 中）
```

### 18.2.5 weights_only=False 的必要性

```python
ck = torch.load(ckpt_path, map_location="cpu", weights_only=False)
```

PyTorch 2.6+ 默认 `weights_only=True`，但我们的 checkpoint 包含 `cfg`（dict）和 `metrics`（dict）等非 tensor 对象，必须显式设置 `weights_only=False`。

## 18.3 Chat 模式 vs Raw 续写模式

### 18.3.1 两种模式的用途

| 模式 | 适用模型 | 输入 | 输出 |
|------|---------|------|------|
| Chat（默认） | SFT/DPO/PPO/GRPO | 用户消息 | 对话式回复 |
| Raw | Base 预训练 | 文本前缀 | 文本续写 |

### 18.3.2 generate_reply 实现

```python
# src/post_training/inference.py

@torch.no_grad()
def generate_reply(model, user_text, *, device, system=None, raw=False,
                    max_new_tokens=256, temperature=0.8, top_k=None,
                    top_p=0.95, greedy=False):
    if raw:
        # Raw 模式：直接 tokenize + 续写
        ids = get_tokenizer().encode_ordinary(user_text)
        out = batched_generate(model, [ids], max_new_tokens, device=device,
                               temperature=temperature, top_k=top_k,
                               top_p=top_p, greedy=greedy)
        return out[0]

    # Chat 模式：构建 chat template
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": user_text})
    prompt_ids = encode_prompt(messages)
    out = batched_generate(model, [prompt_ids], max_new_tokens, device=device,
                           temperature=temperature, top_k=top_k,
                           top_p=top_p, greedy=greedy)
    return out[0]
```


### 18.3.3 Chat 模式的完整流程

```
用户输入: "What is 13 + 29?"
    |
    v encode_prompt
[<|user|>\nWhat is 13 + 29?
</think>

]
```

### 18.3.4 Raw 模式的完整流程

```python
# 预训练模型的续写模式
# 输入: "Once upon a time"
# 不需要 chat template，直接 tokenize

ids = get_tokenizer().encode_ordinary("Once upon a time")
# -> [7415, 3622, 281, 717]    纯 token id，没有角色标记
```

Raw 模式的特点：
- **没有角色标记**：模型不知道自己在"对话"
- **没有 EOT 停止**：模型不知道何时该停止（除非碰巧生成了 EOT）
- **适合评估预训练质量**：观察模型能否续写连贯的文本

```
Raw 模式输出示例（base_pretrained 模型）：
输入: "The capital of France is"
输出: " Paris, which is known for the Eiffel Tower.
       The city has a population of..."
       <- 模型续写文本，不会主动停止
```

### 18.3.5 模式选择指南

| 场景 | 推荐模式 | 原因 |
|------|---------|------|
| 测试 SFT/DPO/PPO/GRPO 模型 | Chat | 模型被训练为对话格式 |
| 测试预训练模型 | Raw | 模型不知道对话格式 |
| 评估 GSM8K | Chat | 评估脚本自动构建 prompt |
| 生成故事/文章 | Raw | 续写模式更自然 |

## 18.4 交互式对话实现

### 18.4.1 chat.py 脚本结构

```python
# scripts/chat.py

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--ckpt", required=True)
    p.add_argument("--prompt", default=None)
    p.add_argument("--system", default=None)
    p.add_argument("--raw", action="store_true")
    p.add_argument("--max_new_tokens", type=int, default=256)
    p.add_argument("--temperature", type=float, default=0.8)
    p.add_argument("--top_p", type=float, default=0.95)
    p.add_argument("--greedy", action="store_true")
    p.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    args = p.parse_args()

    model = load_model_from_ckpt(args.ckpt, args.device)
    n = sum(p.numel() for p in model.parameters())
    print(f"loaded {args.ckpt} ({n/1e6:.0f}M params) on {args.device}")
```

### 18.4.2 One-shot 模式

```python
if args.prompt is not None:
    print(reply(args.prompt))
    return
```

适合自动化测试和脚本调用：

```bash
PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/sft.pt --prompt "What is 13 + 29?"
PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/grpo.pt --prompt "..." --greedy
PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/base_pretrained.pt --raw --prompt "Once upon a time"
```

### 18.4.3 交互式 REPL

```python
print("Interactive chat (Ctrl-D / 'exit' to quit).")
while True:
    try:
        text = input("\nyou> ").strip()
    except EOFError:
        break
    if text in ("exit", "quit"):
        break
    if text:
        print("bot>", reply(text))
```

交互式对话的运行示例：

```
Interactive chat (Ctrl-D / 'exit' to quit).

you> What is 13 + 29?
</think>

<think>Janet starts with 10 snowballs and gives away 3. 10 - 3 = 7.</think>
<answer>7</answer>
bot> <think>The store sells apples for $2 each. Buying 5 means 2 x 5 = 10.</think>
<answer>10</answer>

you> exit
```

### 18.4.4 REPL 的设计要点

**无对话历史**：每次交互都是独立的——模型不知道之前的对话。

```
REPL 的行为：
you> Hello
bot> Hi there! How can I help you?

you> What is my name?
bot> I don't know your name.    <- 不记得之前的对话
```

原因：
- 模型的 `context_length` 有限（如 256 token）
- 维护对话历史需要额外逻辑
- 本项目重点是训练，不是构建生产级聊天应用

### 18.4.5 退出方式

两种退出机制：

| 方式 | 触发 | 说明 |
|------|------|------|
| `EOFError` | Ctrl-D | 标准 Unix EOF 信号 |
| `exit` / `quit` | 文本命令 | 用户显式退出 |

## 18.5 解码参数调优

### 18.5.1 解码策略对比

| 策略 | 参数 | 效果 | 适用场景 |
|------|------|------|----------|
| 贪心（greedy） | `--greedy` | 确定性输出，可复现 | 评估、数学题 |
| 采样 | `temperature=0.8` | 适度随机性 | 对话、创意写作 |
| Top-p | `top_p=0.95` | 限制候选词范围 | 配合采样使用 |
| Top-k | `top_k=50` | 只保留 top-k 个候选 | 控制多样性 |

### 18.5.2 Temperature 的作用

```
temperature=0.1: 几乎确定（接近贪心）
  概率分布尖锐 -> 总选最高概率的 token

temperature=0.8: 适度随机
  概率分布适中 -> 偶尔选择非最优 token

temperature=1.0: 原始分布
  完全按模型学到的分布采样

temperature=2.0: 过度随机
  概率分布平坦 -> 几乎均匀分布，输出混乱
```

### 18.5.3 Top-p 和 Top-k 的配合

```python
# chat.py 中的参数传递
top_p=args.top_p if args.top_p < 1 else None
```

`top_p < 1` 时启用 nucleus sampling：

```
Top-p=0.95: 只从累积概率达到 95% 的 token 中采样

假设模型的输出分布：
  token_A: 0.40
  token_B: 0.25
  token_C: 0.20
  token_D: 0.10    <- 累积到 0.95
  token_E: 0.03    <- 被排除
  token_F: 0.02    <- 被排除
```

### 18.5.4 max_new_tokens 的控制

| 模型类型 | 典型输出长度 | 建议值 |
|---------|------------|--------|
| Base 预训练 | 无限续写 | 设上限（如 128） |
| SFT/DPO | 100-200 token | 256（默认） |
| PPO/GRPO | 150-300 token（含 CoT） | 300-512 |

### 18.5.5 解码参数组合推荐

| 场景 | 命令 |
|------|------|
| 数学题（需要确定性） | `--greedy` |
| 对话（需要自然） | `--temperature 0.8 --top_p 0.95` |
| 创意写作（需要多样） | `--temperature 1.0 --top_p 0.9` |
| 快速测试 | `--greedy --max_new_tokens 100` |

## 18.6 batched_generate：按长度分桶的批量生成

### 18.6.1 为什么需要分桶

本项目的 Transformer 没有 padding-aware attention mask——所有位置的 attention 都是完整的因果 attention。如果不同长度的 prompt 放在一个 batch 里，短 prompt 的 padding 位置会干扰 attention 计算。

```python
# src/post_training/evaluation.py

def batched_generate(model, prompts, max_new_tokens, *, device,
                     temperature=1.0, top_k=None, top_p=None,
                     greedy=False, micro_batch=32):
    if greedy:
        temperature, top_k, top_p = 1.0, 1, None    # top_k=1 = argmax

    cap = _model_context_length(model)
    order = sorted(range(len(prompts)), key=lambda i: len(prompts[i]))
    results = [None] * len(prompts)
```

### 18.6.2 分桶逻辑

```python
i = 0
while i < len(order):
    j = i
    L = len(prompts[order[i]])
    # 取相同长度的 prompt 组成 batch
    while j < len(order) and len(prompts[order[j]]) == L and (j - i) < micro_batch:
        j += 1
    idxs = order[i:j]
    i = j
    budget = min(max_new_tokens, cap - L)
    ...
```

```
Prompt 长度分布：
  [12, 15, 15, 18, 18, 18, 20, 22]

分桶后：
  Batch 1: [12]                  (1 个)
  Batch 2: [15, 15]              (2 个，相同长度)
  Batch 3: [18, 18, 18]          (3 个，相同长度)
  Batch 4: [20]                  (1 个)
  Batch 5: [22]                  (1 个)
```

### 18.6.3 生成后的后处理

```python
rb = generate_with_logprobs(model, batch, budget, ...)
gen = rb.sequences[:, L:]    # 截取生成部分
for row, k in enumerate(idxs):
    toks = gen[row].tolist()
    if EOT_ID in toks:
        toks = toks[:toks.index(EOT_ID)]    # 截断在第一个 EOT
    results[k] = decode(toks)
```

`decode` 函数（chat_template.py）会防御性地跳过 `id >= 50256` 的 token（模型 vocab 是 50304，但 r50k_base 只能解码 0..50255）。

### 18.6.4 生成预算的保护

```python
budget = min(max_new_tokens, cap - L)
if budget <= 0:    # prompt 已经填满 context
    for k in idxs:
        results[k] = ""
    continue
```

当 prompt 长度 >= context_length 时，无法生成任何新 token——返回空字符串。

## 18.7 推理引擎在整个 Pipeline 中的位置

### 18.7.1 评估脚本复用推理引擎

```python
# scripts/eval_post_training.py 和 scripts/chat.py 共享同一个推理引擎

# eval_post_training.py 使用 model_from_ckpt（内部逻辑类似）
model = model_from_ckpt(args.ckpt, args.device)
res = gsm8k_accuracy(model, qa, ...)    # 调用 batched_generate

# chat.py 使用 load_model_from_ckpt
model = load_model_from_ckpt(args.ckpt, args.device)
reply = generate_reply(model, text, ...)    # 调用 batched_generate
```

### 18.7.2 完整的调用链

```
chat.py
  +-- load_model_from_ckpt()          # inference.py: 加载模型
  +-- generate_reply()                # inference.py: 生成回复
       +-- encode_prompt()            # chat_template.py: 编码 prompt
       +-- batched_generate()         # evaluation.py: 批量生成
            +-- generate_with_logprobs()  # rollout.py: 自回归生成
                 +-- model.forward()  # transformer.py: 前向传播
```

## 18.8 本章小结

### 推理系统的核心组件

| 组件 | 文件 | 功能 |
|------|------|------|
| load_model_from_ckpt | inference.py | 通用 checkpoint 加载 |
| generate_reply | inference.py | Chat/Raw 双模式生成 |
| batched_generate | evaluation.py | 按长度分桶的批量生成 |
| _strip_ddp_prefix | utils.py | Checkpoint key 前缀清理 |
| chat.py | scripts/chat.py | 交互式 REPL + one-shot |

### Checkpoint 加载的关键决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 模型维度 | 从 checkpoint 的 cfg 读取 | 不需要手动指定 |
| Key 前缀 | _strip_ddp_prefix while 循环 | 处理 DDP + compile 嵌套 |
| 额外 key | strict=False + 过滤 | 忽略 reward_head 等 |
| weights_only | False | checkpoint 含 dict 等非 tensor 对象 |

### Chat vs Raw 模式

```
Chat 模式（SFT/DPO/PPO/GRPO）：
  用户消息 -> encode_prompt -> <|user|>...<|assistant|> -> 生成 -> EOT 停止

Raw 模式（Base 预训练）：
  文本前缀 -> encode_ordinary -> token ids -> 生成 -> max_new_tokens 停止
```

### 关键教训

1. **通用加载器**：一个函数加载所有阶段的 checkpoint
2. **前缀清理是必须的**：DDP 和 torch.compile 都会修改 key
3. **Chat 模板决定行为**：同一个模型，Chat 和 Raw 模式产生完全不同的输出
4. **解码参数影响质量**：greedy 用于评估，采样用于对话
5. **分桶生成提高效率**：相同长度的 prompt 共享 batch，避免 padding 问题

---

## 练习

**练习 1：加载不同 checkpoint**

用同一个问题测试不同阶段的模型，对比输出：

```bash
for s in sft dpo grpo; do
  PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/$s.pt \
    --prompt "What is 15 * 7?" --greedy
done
```

观察不同模型的输出格式和质量差异。

**练习 2：Raw vs Chat 对比**

对预训练模型和 SFT 模型，分别用 Chat 和 Raw 模式生成：

```bash
# Base 模型 - Raw 模式（正确）
PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/base_pretrained.pt \
  --raw --prompt "The answer to 2+2 is"

# Base 模型 - Chat 模式（错误！模型不懂格式）
PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/base_pretrained.pt \
  --prompt "What is 2+2?"

# SFT 模型 - Chat 模式（正确）
PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/sft.pt \
  --prompt "What is 2+2?"
```

**练习 3：Temperature 实验**

对同一个问题，用不同的 temperature 采样 3 次：

```bash
for T in 0.1 0.8 1.5; do
  echo "=== temperature=$T ==="
  PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/sft.pt \
    --prompt "Tell me a story" --temperature $T --max_new_tokens 100
done
```

观察 temperature 对输出多样性和质量的影响。

**练习 4：前缀清理实验**

手动构造一个带有 `module.` 前缀的 state_dict，验证 `_strip_ddp_prefix` 的正确性：

```python
from src.post_training.utils import _strip_ddp_prefix

state = {
    "module._orig_mod.transformer.h.0.ln_1.weight": "v1",
    "_orig_mod.module.transformer.h.1.ln_1.weight": "v2",
    "transformer.h.2.ln_1.weight": "v3",
}
cleaned = _strip_ddp_prefix(state)
for k in cleaned:
    print(k)    # 应该都是 transformer.h.X.ln_1.weight
```
