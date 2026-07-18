# 第 20 章：常见陷阱与调试指南

> **本章目标**：汇总后训练过程中最常见、最隐蔽的错误，提供系统化的排查清单和解决方案，让读者避免重复踩坑。

## 20.0 本章路线图

后训练涉及数据准备、模型加载、分布式训练、多阶段串联等多个环节。每个环节都可能出错，而且错误往往在运行几十分钟后才暴露。本章将这些真实踩坑经验系统化。

```
本章覆盖的内容

常见陷阱
├── Checkpoint key 不匹配（163 missing keys）
├── 数据 context_length 与模型不一致
├── torch.compile 环境兼容性问题
├── PyTorch 版本升级的 breaking changes
├── Loss 不下降的排查清单
└── OOM 时的参数调优策略
```

## 20.1 Checkpoint key 不匹配

### 20.1.1 问题现象

```
RuntimeError: Error(s) in loading state_dict for Transformer:
    Missing key(s) in state_dict:
        "transformer.h.0.ln_1.weight", "transformer.h.0.ln_1.bias",
        "transformer.h.0.attn.c_attn.weight", "transformer.h.0.attn.c_attn.bias",
        ...
    Unexpected key(s) in state_dict:
        "_orig_mod.module.transformer.h.0.ln_1.weight",
        "_orig_mod.module.transformer.h.0.ln_1.bias",
        ...

总共 163 missing keys, 163 unexpected keys
```

**这是后训练中最常见的错误之一**——保存的 checkpoint key 与加载时的期望 key 不匹配。

### 20.1.2 根本原因：DDP + torch.compile 的前缀问题

```
训练时的包装链：
  Transformer
      ↓ torch.compile
  _orig_mod.Transformer          ← 添加 _orig_mod. 前缀
      ↓ DDP
  module._orig_mod.Transformer   ← 再添加 module. 前缀

保存时：
  state_dict key = "module._orig_mod.transformer.h.0.ln_1.weight"

加载时（裸 Transformer）：
  期望 key = "transformer.h.0.ln_1.weight"

差异 → 163 个 key 全部不匹配
```

### 20.1.3 解决方案：_strip_ddp_prefix

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

嵌套前缀可能导致多层包装：

```
"module._orig_mod.module.transformer.h.0.ln_1.weight"
→ 第 1 轮："_orig_mod.module.transformer.h.0.ln_1.weight"
→ 第 2 轮："module.transformer.h.0.ln_1.weight"
→ 第 3 轮："transformer.h.0.ln_1.weight"
→ 不再匹配 → 结束
```

### 20.1.4 实际排查步骤

```
1. 打印 checkpoint 中的 key（前 5 个）：
   ck = torch.load("checkpoint.pt", weights_only=False)
   for k in list(ck["model_state_dict"].keys())[:5]:
       print(k)
   → 观察前缀类型

2. 打印模型的 key（前 5 个）：
   model = Transformer(...)
   for k in list(model.state_dict().keys())[:5]:
       print(k)

3. 对比两者：
   checkpoint: "module._orig_mod.transformer.h.0.ln_1.weight"
   model:      "transformer.h.0.ln_1.weight"
   → 需要清理 module. 和 _orig_mod. 前缀
```

### 20.1.5 单一职责原则

**所有加载点都应该复用同一个 `_strip_ddp_prefix` 函数**：

```python
# 正确做法：复用统一函数
from src.post_training.utils import _strip_ddp_prefix

# load_backbone_from_ckpt 中使用
state = _strip_ddp_prefix(state)

# load_model_from_ckpt 中使用（inference.py）
state = _strip_ddp_prefix(state)

# 错误做法：每个加载函数自己实现前缀清理
# → 容易遗漏某种前缀，导致 bug
```

### 20.1.6 strict=False 的防御性加载

```python
backbone_keys = set(model.state_dict().keys())
filtered = {k: v for k, v in state.items() if k in backbone_keys}
missing, unexpected = model.load_state_dict(filtered, strict=False)
if missing:
    print(f"[load_backbone] {len(missing)} missing keys")
```

`strict=False` 的好处：
- Reward checkpoint 的 `reward_head.*` key 不会报错
- Value head 的 key 不会报错
- 但仍需检查 `missing` 是否为空（非零意味着 backbone 权重缺失）

## 20.2 数据 context_length 与模型不一致

### 20.2.1 问题现象

```
RuntimeError: The size of tensor a (1024) must match the size of tensor b (256)
at non-singleton dimension 1
```

或：

```
IndexError: index out of range in self
```

### 20.2.2 根本原因

模型的 Position Embedding 有固定的 `context_length`（如 256）。如果数据打包时使用了不同的长度：

```
模型: context_length = 256 → pos_embed 形状 (1, 256, n_embed)
数据: context_length = 1024 → tokens 形状 (batch, 1024)

当 tokens 输入模型时：
  pos_embed[:, :1024, :] → IndexError（只有 256 个位置）
```

### 20.2.3 三方一致性约束

**后训练的 context_length 必须在三个地方保持一致**：

```
1. 模型配置: configs/base.json
   {"context_length": 256, "n_embed": 256, ...}

2. 数据准备: prepare_sft_data.py --context_length 256
   → 生成的 sft_packed.h5 形状为 (N, 256)

3. 训练配置: configs/sft.json
   → 加载同一个 base.json，context_length = 256
```

### 20.2.4 排查方法

```python
# 检查数据维度
import h5py
with h5py.File("/ephemeral/data/sft_packed.h5", "r") as f:
    print(f["tokens"].shape)    # 应为 (N, 256)

# 检查模型配置
import json
with open("configs/base.json") as f:
    cfg = json.load(f)
    print(cfg["context_length"])    # 应为 256

# 检查 checkpoint 的 cfg
ck = torch.load("sft.pt", weights_only=False)
print(ck["cfg"]["context_length"])    # 应为 256
```

### 20.2.5 常见错误场景

| 场景 | 原因 | 解决 |
|------|------|------|
| 使用旧数据 | 旧 h5 文件是 1024 长度 | 重新 prepare_sft_data |
| 修改模型配置 | 改了 base.json 但没重新打包数据 | 保持一致 |
| 复制了错误的配置文件 | 用了 smoke 配置但数据是 full 的 | 检查 JSON |

### 20.2.6 数据路径注意事项

```
正确路径：/ephemeral/data/sft_packed.h5    (shape=256, 当前版本)
错误路径：/ephemeral/sft_packed.h5          (shape=1024, 旧版本)
```

**永远检查数据的 shape**——路径相似的旧文件可能是过时的。

## 20.3 torch.compile 环境兼容性问题

### 20.3.1 问题现象

```
SystemError: <built-in method register_fake of ...> returned NULL without setting an error
```

或：

```
torch._dynamo.exc.InternalError: FakeTensor error
```

### 20.3.2 根本原因

`torch.compile` 依赖 `torch._dynamo`，后者对环境敏感：

| 问题 | 原因 |
|------|------|
| redis 冲突 | 某些环境中 redis 库与 dynamo 的 guard 机制冲突 |
| CUDA 版本不匹配 | compile 优化的 kernel 与实际 CUDA 版本不兼容 |
| 第三方库 monkey-patch | 某些库修改了 PyTorch 的内部函数 |
| SFT 阶段 | 特定的训练循环结构与 compile 不兼容 |

### 20.3.3 解决方案

```python
# configs/sft.json 中
{
    "compile": false    ← SFT 阶段禁用 compile
}
```

**SFT 阶段为什么禁用 compile？**

SFT 的训练循环结构相对简单，compile 的收益不大，但可能触发 FakeTensor 广播错误。为了稳定性，在 SFT 阶段默认禁用。

```python
# train_sft.py 中
if cfg.compile:
    model = torch.compile(model)    # 只在 cfg.compile=True 时编译
```

### 20.3.4 何时可以安全使用 compile

| 阶段 | 建议 | 原因 |
|------|------|------|
| 预训练 | 可以使用 | 循环简单，收益明显 |
| SFT | 禁用 | 特定结构可能触发 bug |
| Reward | 可以尝试 | 类似预训练 |
| DPO/PPO/GRPO | 禁用 | 多模型交互增加风险 |

### 20.3.5 compile 的收益评估

```
compile 的收益（A100 GPU, 125M 模型）：
  前向传播：+15-20% 加速
  反向传播：+10-15% 加速
  总训练时间：减少约 10%

compile 的成本：
  首次编译：30-60 秒（warmup）
  调试困难：编译后的错误信息难以阅读
  环境依赖：不同环境可能需要不同的 compile 配置
```

## 20.4 PyTorch 版本升级的 Breaking Changes

### 20.4.1 weights_only=True（PyTorch 2.6+）

**问题现象**：

```
_pickle.UnpicklingError: Weights only load failed. This file can still be loaded
with `weights_only=False`, which runs the full pickle.
```

**根本原因**：

PyTorch 2.6+ 将 `torch.load` 的默认参数从 `weights_only=False` 改为 `weights_only=True`。我们的 checkpoint 包含非 tensor 对象：

```python
payload = {
    "model_state_dict": ...,      # tensor ← 允许
    "cfg": asdict(cfg),           # dict   ← 不允许（weights_only=True）
    "metrics": {...},             # dict   ← 不允许
    "stage": "sft",               # str    ← 不允许
    "step": 1000,                 # int    ← 不允许
}
```

**解决方案**：

```python
# 所有 torch.load 调用都显式设置 weights_only=False
ck = torch.load(ckpt_path, map_location="cpu", weights_only=False)
```

### 20.4.2 其他版本相关变更

| 变更 | 影响版本 | 解决 |
|------|---------|------|
| `weights_only` 默认 True | 2.6+ | 显式 `weights_only=False` |
| `torch.compile` 行为变化 | 2.1-2.3 | 固定 PyTorch 版本 |
| DDP `find_unused_parameters` 默认值 | 2.0+ | 显式设置 |
| `torch.cuda.amp.autocast` 弃用 | 2.0+ | 用 `torch.autocast` |

### 20.4.3 版本固定策略

```
# requirements.txt
torch>=2.0,<2.4

# 或使用 conda 环境
conda create -n llm-train python=3.11 pytorch=2.1 -c pytorch
```

**建议**：在一个固定的 PyTorch 版本上开发和测试，只在发布前验证新版本兼容性。

## 20.5 Loss 不下降的排查清单

### 20.5.1 系统化排查流程

```
Loss 不下降？按以下顺序排查：

1. 数据问题
   ├── 数据是否为空？（h5 shape[0] == 0）
   ├── Loss mask 是否全零？（所有 token 都被 mask）
   ├── 数据是否被正确 tokenized？（随机 token = 无法学习）
   └── context_length 是否匹配？

2. 模型问题
   ├── 模型是否从随机初始化开始？（忘记加载 checkpoint）
   ├── 参数是否被冻结？（requires_grad = False）
   └── 是否有 NaN 权重？（打印 model parameters 的 norm）

3. 训练循环问题
   ├── 学习率是否太小？（增大 10 倍试试）
   ├── 学习率是否太大？（减小 10 倍试试）
   ├── 梯度是否为零？（打印 grad norm）
   ├── 是否忘记 optimizer.step()？
   └── 是否忘记 loss.backward()？

4. 分布式问题
   ├── DDP 是否正确初始化？
   ├── 所有 rank 是否看到不同数据？
   └── 梯度是否被正确同步？
```

### 20.5.2 快速诊断代码

```python
# 在训练循环中添加诊断
if step == 0:
    # 1. 检查数据
    print(f"tokens shape: {tokens.shape}")
    print(f"mask shape: {mask.shape}, mask sum: {mask.sum()}")
    print(f"tokens range: [{tokens.min()}, {tokens.max()}]")

    # 2. 检查模型
    total_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"trainable params: {total_params}")

    # 3. 检查前向
    with torch.no_grad():
        logits, _ = model(tokens)
        print(f"logits shape: {logits.shape}, range: [{logits.min():.2f}, {logits.max():.2f}]")

    # 4. 检查 loss
    loss = sft_loss(logits, tokens, mask)
    print(f"initial loss: {loss.item():.4f}")
    print(f"expected initial loss (random): ~{math.log(50304):.1f}")    # ≈ 10.8

# 每 20 步检查梯度
if step % 20 == 0:
    grad_norm = sum(p.grad.norm().item()**2 for p in model.parameters() if p.grad is not None)**0.5
    print(f"step {step} | grad_norm: {grad_norm:.4f}")
```

### 20.5.3 典型的 Loss 曲线

```
正常训练：
loss
10 ┤●
   │ ╲
 5 ┤  ╲──●──●
   │         ╲──●──●
 2 ┤               ●──●──●
   └──┬──┬──┬──┬──┬──┬──▶ step
      0  100 200 300 400 500

异常：loss 不下降
loss
10 ┤●──●──●──●──●──●──●──●
   │
   │  （可能的原因：学习率为 0、数据全 mask、模型冻结）
   │
   └──┬──┬──┬──┬──┬──┬──▶ step

异常：loss 爆炸
loss
   │                              ● (NaN)
   │                          ●
   │                      ●
10 ┤●──●──●──●──●──●──●
   │
   └──┬──┬──┬──┬──┬──┬──▶ step
      （可能的原因：学习率太大、梯度爆炸、数据异常）
```

### 20.5.4 梯度问题的排查

```python
# 检查梯度是否为零
for name, p in model.named_parameters():
    if p.grad is not None:
        if p.grad.norm().item() == 0:
            print(f"WARNING: {name} has zero gradient!")

# 检查梯度是否 NaN
for name, p in model.named_parameters():
    if p.grad is not None:
        if torch.isnan(p.grad).any():
            print(f"ERROR: {name} has NaN gradient!")
```

## 20.6 OOM 时的参数调优策略

### 20.6.1 显存占用的构成

```
GPU 显存 = 模型参数 + 梯度 + 优化器状态 + 前向中间值 + 数据

以 125M 参数模型（fp32）为例：
  参数:       125M × 4 bytes = 500 MB
  梯度:       125M × 4 bytes = 500 MB
  优化器:     125M × 8 bytes = 1 GB (AdamW m + v)
  前向中间值: ~500 MB (与 batch_size × context_length 成正比)
  数据:       ~100 MB
              总计 ~2.6 GB

使用 bf16 后：
  前向中间值减半: ~250 MB
  梯度减半:       ~250 MB
              总计 ~2.1 GB
```

### 20.6.2 调优顺序（从高到低优先级）

```
1. 开启 bf16（amp_dtype: "bf16"）
   → 节省 ~25% 显存，零精度损失

2. 减小 batch_size
   → 线性减少前向中间值

3. 使用 set_to_none=True
   → optimizer.zero_grad(set_to_none=True)
   → 释放梯度张量

4. 减少 context_length
   → 减少前向中间值（与长度平方相关）

5. 减少模型规模
   → n_embed、n_blocks、n_head

6. 使用梯度累积（本项目未实现，但可扩展）
   → 等效增大 batch_size 而不增加显存
```

### 20.6.3 各阶段的显存优化

| 阶段 | 显存瓶颈 | 优化方法 |
|------|---------|---------|
| SFT | 前向中间值 | bf16 + 减小 batch_size |
| Reward | 成对数据（chosen + rejected） | bf16 + 减小 batch_size |
| DPO | policy + ref（两份模型） | ref 冻结 + bf16 |
| PPO | policy + ref + RM + value_head | 冻结非必要模型 + bf16 |
| GRPO | policy + ref + G 倍 rollout | 减小 group_size + bf16 |

### 20.6.4 batch_size 与训练效果的关系

```
有效 batch_size = batch_size × world_size

示例（2 GPU）：
  batch_size=16 → effective=32
  batch_size=8  → effective=16

如果 OOM：
  batch_size 从 16 → 8（减半）
  → GPU 数从 2 → 4（加倍）
  → 有效 batch_size 不变
```

### 20.6.5 16GB 显卡的推荐配置

```json
// configs/smoke/base.json（适合 16GB 显卡）
{
    "n_embed": 128,
    "n_head": 4,
    "n_blocks": 4,
    "context_length": 256,
    "device": "cpu"
}
```

16GB 显卡的限制：
- 最大模型约 125M 参数（fp32）
- bf16 可支持约 250M 参数
- context_length 不宜超过 512

### 20.6.6 80GB 显卡（A100/H100）的推荐配置

```json
// configs/base.json
{
    "n_embed": 256,
    "n_head": 8,
    "n_blocks": 8,
    "context_length": 256
}
```

80GB 显卡的能力：
- 轻松支持 400M 参数
- PPO 的 4 个模型副本无压力
- GRPO 的大 group_size（16-32）可行

## 20.7 多阶段串联的常见问题

### 20.7.1 Checkpoint 路径错误

```
# SFT 需要预训练的 checkpoint
PYTHONPATH=. python scripts/train_sft.py --pretrained_ckpt /ephemeral/ckpts/base_pretrained.pt

# DPO 需要 SFT 的 checkpoint
PYTHONPATH=. python scripts/train_dpo.py --sft_ckpt /ephemeral/ckpts/sft.pt

# PPO 需要 SFT + Reward 的 checkpoint
PYTHONPATH=. python scripts/train_ppo.py --sft_ckpt /ephemeral/ckpts/sft.pt --reward_ckpt /ephemeral/ckpts/reward.pt
```

**常见错误**：路径写错、文件不存在、使用了错误阶段的 checkpoint。

### 20.7.2 数据文件缺失

```
# Reward 训练需要 preference 数据
FileNotFoundError: [Errno 2] No such file: '/ephemeral/data/preference_train.jsonl'

# 需要先运行 prepare_preference_data.py
PYTHONPATH=. HF_HOME=/ephemeral/hf_cache python scripts/prepare_preference_data.py
```

**注意**：Reward 训练脚本强制依赖测试集文件存在——即使你只需要训练集，也要准备测试集。

### 20.7.3 模型维度不一致

```
# SFT 训练的模型是 256 embed
# 但 DPO 加载时用了不同的 base.json（如 512 embed）
→ RuntimeError: size mismatch for transformer.h.0.attn.c_attn.weight
```

**解决方案**：确保所有阶段使用同一个 `configs/base.json`。

### 20.7.4 环境变量的传递

```bash
# 所有脚本都需要
export PYTHONPATH=.
export HF_HOME=/ephemeral/hf_cache

# 离线模式（无网络时）
export HF_DATASETS_OFFLINE=1
```

## 20.8 调试工具与技巧

### 20.8.1 Smoke Test 配置

```json
// configs/smoke/base.json
{
    "n_embed": 128,
    "n_head": 4,
    "n_blocks": 4,
    "context_length": 256,
    "device": "cpu"
}
```

**Smoke test 的价值**：
- 在 CPU 上快速运行（几分钟）
- 验证代码逻辑正确性
- 不需要 GPU
- 所有阶段都有对应的 smoke 配置

```bash
# 运行 smoke test
PYTHONPATH=. python scripts/train_sft.py --config configs/smoke/sft.json
```

### 20.8.2 日志与 Metrics

```python
# MetricsLogger 统一记录
logger = MetricsLogger("sft", cfg.log_dir, use_wandb=cfg.use_wandb)
logger.log(step, {"train_loss": loss.item(), "lr": lr})
```

**关键指标**：

| 指标 | 健康范围 | 异常信号 |
|------|---------|---------|
| SFT train loss | 3.0-6.0 | > 8.0 或 < 2.0 |
| SFT dev loss | 3.5-6.5 | 远大于 train loss → 过拟合 |
| Reward margin | 0.3-1.5 | < 0.1 → 无法区分 |
| DPO implicit_acc | 0.6-0.9 | < 0.5 → 反向学习 |
| PPO/GRPO reward | 0.3-0.8 | < 0.1 → 无信号 |
| PPO/GRPO KL | 0.01-0.1 | > 0.3 → 偏离太远 |
| GRPO informative | 0.3-0.7 | < 0.1 → 组内无方差 |

### 20.8.3 单步调试

```python
# 在训练循环中添加断点
for step in range(total_steps):
    tokens, mask, epoch = next(train_it)
    logits, _ = model(tokens)
    loss = sft_loss(logits, tokens, mask)
    loss.backward()

    if step == 0:
        import pdb; pdb.set_trace()    # 第一步断点
        # 检查：tokens、logits、loss、gradient
```

### 20.8.4 打印模型结构

```python
# 检查模型参数是否正确加载
for name, p in model.named_parameters():
    print(f"{name:50s} {str(p.shape):20s} {p.requires_grad}")
```

## 20.9 本章小结

### 常见陷阱速查表

| 问题 | 错误信息 | 原因 | 解决 |
|------|---------|------|------|
| Key 不匹配 | 163 missing keys | DDP/compile 前缀 | `_strip_ddp_prefix` |
| 维度不匹配 | size mismatch | context_length 不一致 | 统一三方配置 |
| Compile 报错 | SystemError / FakeTensor | 环境不兼容 | `--compile false` |
| 加载报错 | UnpicklingError | PyTorch 2.6+ 默认 | `weights_only=False` |
| Loss 不下降 | loss 恒定 | 多种原因 | 按排查清单逐项检查 |
| OOM | CUDA out of memory | 显存不足 | bf16 + 减小 batch_size |

### 排查优先级

```
第一优先级：检查数据（shape、mask、路径）
第二优先级：检查模型加载（key 前缀、strict）
第三优先级：检查训练参数（学习率、batch_size、compile）
第四优先级：检查分布式（DDP 初始化、数据分片）
```

### 关键教训

1. **永远验证数据 shape**：`h5py.File(...).shape` 是最简单的检查
2. **统一前缀清理**：所有加载点复用 `_strip_ddp_prefix`
3. **显式设置 `weights_only=False`**：不要依赖 PyTorch 的默认值
4. **Smoke test 先行**：在 CPU 上验证逻辑，再上 GPU 训练
5. **日志是关键**：记录 loss、grad_norm、key metrics，异常时才能快速定位

---

## 练习

**练习 1：Smoke Test 全流程**

在 CPU 上运行完整的后训练流程（使用 smoke 配置）：

```bash
# 1. 准备数据
PYTHONPATH=. python scripts/prepare_sft_data.py
PYTHONPATH=. python scripts/prepare_preference_data.py
PYTHONPATH=. python scripts/prepare_rl_prompts.py

# 2. 运行各阶段
PYTHONPATH=. python scripts/train_sft.py --config configs/smoke/sft.json
PYTHONPATH=. python scripts/train_reward.py --config configs/smoke/reward.json
PYTHONPATH=. python scripts/train_dpo.py --config configs/smoke/dpo.json
```

记录每个阶段的运行时间和最终 loss。

**练习 2：Key 前缀实验**

手动构造带有各种前缀的 state_dict，测试 `_strip_ddp_prefix` 的正确性：

```python
from src.post_training.utils import _strip_ddp_prefix

test_cases = [
    "transformer.h.0.ln_1.weight",              # 正常
    "module.transformer.h.0.ln_1.weight",        # DDP
    "_orig_mod.transformer.h.0.ln_1.weight",     # compile
    "module._orig_mod.transformer.h.0.ln_1.weight",  # DDP + compile
]
state = {k: "v" for k in test_cases}
cleaned = _strip_ddp_prefix(state)
for k in cleaned:
    assert k == "transformer.h.0.ln_1.weight", f"Failed: {k}"
print("All prefix tests passed!")
```

**练习 3：OOM 模拟**

逐步增大 batch_size 直到 OOM，记录每个 batch_size 的显存占用：

```python
import torch
for bs in [4, 8, 16, 32, 64]:
    torch.cuda.reset_peak_memory_stats()
    # 训练一步...
    peak = torch.cuda.max_memory_allocated() / 1024**2
    print(f"batch_size={bs:3d} | peak memory: {peak:.0f} MB")
```

**练习 4：Loss 诊断**

故意制造一个 loss 不下降的场景（如设学习率为 0），用本章的诊断代码排查问题：

```python
# 修改 train_sft.py 中的学习率
optimizer = configure_optimizer(unwrap(model), lr=0.0, weight_decay=0.0)
```

运行几步后观察 loss 曲线，用诊断代码确认问题。
