# 第 19 章：分布式训练与性能优化

> **本章目标**：掌握 PyTorch DDP 的核心原理与 `torchrun` 启动方式，理解 bf16 混合精度训练、数据分片、梯度同步机制，学会显存优化与多 GPU 通信开销分析。

## 19.0 本章路线图

后训练的每个阶段（SFT、Reward、DPO、PPO、GRPO）都支持从 1 GPU 到 N GPU 的无缝扩展。本章解析这个分布式训练系统的实现细节。

```
本章覆盖的内容

分布式训练系统
├── PyTorch DDP 原理与 torchrun 启动
├── DDPContext：单代码路径设计
├── 数据分片：每个 rank 看到不同的数据
├── bf16 混合精度训练
├── 优化器配置：AdamW + 权重衰减分组
├── 显存优化技巧汇总
└── 多 GPU 通信开销分析
```

## 19.1 PyTorch DDP 原理与 torchrun 启动

### 19.1.1 DDP 是什么

DDP（Distributed Data Parallel）是 PyTorch 的标准多 GPU 训练方案。核心思想：

```
每个 GPU 上有一个完整的模型副本
    │
    ├── 处理不同的数据子集（数据并行）
    ├── 各自计算前向 + 反向
    └── 在 optimizer.step() 之前同步梯度（All-Reduce）
```

### 19.1.2 DDP 的工作流程

```
单步训练（2 GPU）：

GPU 0                              GPU 1
┌──────────────────┐               ┌──────────────────┐
│ model (完整副本)  │               │ model (完整副本)  │
│ data shard 0     │               │ data shard 1     │
│                  │               │                  │
│ forward(tokens)  │               │ forward(tokens)  │
│ loss.backward()  │               │ loss.backward()  │
│     │            │  All-Reduce   │     │            │
│     └────────────┼───────────────┼─────┘            │
│  avg(grad_0,     │  grad_0 +     │  avg(grad_0,     │
│      grad_1)     │  grad_1       │      grad_1)     │
│                  │               │                  │
│ optimizer.step() │               │ optimizer.step() │
│ (相同更新)        │               │ (相同更新)        │
└──────────────────┘               └──────────────────┘
```

**关键特性**：
- **All-Reduce**：DDP 在 `backward()` 中自动同步梯度（不是 `step()` 时）
- **相同更新**：因为梯度相同、初始参数相同 → 每个 GPU 的参数始终保持一致
- **Bucket 化**：DDP 将梯度分组（bucket），边计算边通信，隐藏通信延迟

### 19.1.3 torchrun 启动

```bash
# 单 GPU（不需要 torchrun）
PYTHONPATH=. python scripts/train_sft.py

# 2 GPU
PYTHONPATH=. torchrun --standalone --nproc_per_node=2 scripts/train_sft.py

# 4 GPU
PYTHONPATH=. torchrun --standalone --nproc_per_node=4 scripts/train_sft.py
```

`torchrun` 做了什么：

```
torchrun --standalone --nproc_per_node=2 scripts/train_sft.py
    │
    ├── 启动 2 个进程（process）
    ├── 设置环境变量：
    │     RANK=0, LOCAL_RANK=0, WORLD_SIZE=2    ← 进程 0
    │     RANK=1, LOCAL_RANK=1, WORLD_SIZE=2    ← 进程 1
    ├── --standalone：单机器，不需要 rendezvous 服务器
    └── --nproc_per_node=2：每个节点 2 个进程（对应 2 块 GPU）
```

### 19.1.4 单代码路径设计

本项目的核心设计原则：**同一份代码，1 GPU 和 N GPU 都能跑**。

```python
# distributed.py

def ddp_setup(device="cuda"):
    world_size = int(os.environ.get("WORLD_SIZE", "1"))
    if world_size == 1:
        # 单 GPU：返回 world_size=1 的 context
        return DDPContext(rank=0, local_rank=0, world_size=1, device=dev)

    # 多 GPU：初始化进程组
    dist.init_process_group(backend=backend, rank=rank, world_size=world_size)
    return DDPContext(rank=rank, local_rank=local_rank, world_size=world_size, device=dev)
```

所有的 DDP 操作都通过 `DDPContext` 判断是否需要执行：

```python
def ddp_wrap(model, ctx, find_unused_parameters=False):
    if not ctx.enabled:       # world_size == 1 → 不包装
        return model
    return DDP(model, device_ids=[ctx.local_rank], ...)

def reduce_scalar(value, ctx, average=True):
    if not ctx.enabled:       # 单进程 → 不通信
        return value
    # 多进程 → All-Reduce
    ...

def cleanup(ctx):
    if ctx.enabled and dist.is_initialized():
        dist.destroy_process_group()
```

## 19.2 DDPContext：分布式上下文

### 19.2.1 DDPContext 结构

```python
@dataclass
class DDPContext:
    rank: int           # 全局 rank（0, 1, ..., world_size-1）
    local_rank: int     # 本节点的 rank（对应哪块 GPU）
    world_size: int     # 总进程数

    @property
    def is_main(self) -> bool:
        return self.rank == 0    # rank 0 是主进程

    @property
    def enabled(self) -> bool:
        return self.world_size > 1    # 是否启用 DDP
```

### 19.2.2 is_main 的用途

在分布式训练中，**某些操作只需要一个进程执行**：

```python
# 只有主进程打印日志
if ctx.is_main:
    print(f"SFT from {cfg.pretrained_ckpt} | world_size={ctx.world_size}")
    logger = MetricsLogger(...)

# 只有主进程保存 checkpoint
if ctx.is_main and step % cfg.save_every == 0:
    save_stage_ckpt(cfg.out_ckpt, model, optimizer, ...)

# 只有主进程评估
if ctx.is_main and step % cfg.eval_steps == 0:
    res = gsm8k_accuracy(model, eval_set, ...)
```

**为什么不在所有 rank 上打印？**
- 4 个 GPU → 4 份相同的日志 → 混乱
- 4 个进程同时写同一个文件 → 竞争条件

### 19.2.3 backend 选择

```python
backend = "nccl" if (device == "cuda" and torch.cuda.is_available()) else "gloo"
```

| Backend | 用途 | 特点 |
|---------|------|------|
| NCCL | GPU 训练 | NVIDIA 优化，带宽高延迟低 |
| Gloo | CPU 训练 / 调试 | 纯 CPU，跨机器也可用 |

## 19.3 数据分片：每个 rank 看到不同的数据

### 19.3.1 SFT 数据分片

```python
# data_loader/sft_dataset.py

def get_sft_batch_iterator(data_path, batch_size, *, rank=0, world_size=1, ...):
    with h5py.File(data_path, "r") as f:
        n = tokens.shape[0]
        idxs = np.arange(rank, n, world_size)    # 步长为 world_size 的分片
```

```
数据分片示例（world_size=2, n=10）：

rank=0: idxs = [0, 2, 4, 6, 8]     ← 偶数行
rank=1: idxs = [1, 3, 5, 7, 9]     ← 奇数行

每个 rank 看到不同的数据子集，合在一起覆盖整个数据集
```

### 19.3.2 RL Prompt 分片

```python
# data_loader/prompt_dataset.py

def get_prompt_iterator(path, prompts_per_iter, *, rank=0, world_size=1, ...):
    rows = load_prompt_rows(path)[rank::world_size]    # 同样的分片方式
```

### 19.3.3 shard_indices 通用分片

```python
# distributed.py

def shard_indices(num_items, ctx):
    if not ctx.enabled:
        return range(num_items)
    return range(ctx.rank, num_items, ctx.world_size)
```

### 19.3.4 有效 batch size

```
单 GPU：effective_batch_size = batch_size
2 GPU： effective_batch_size = batch_size × 2
4 GPU： effective_batch_size = batch_size × 4
```

训练脚本中用于计算 total_steps：

```python
steps_per_epoch = max(1, n_rows // (cfg.batch_size * ctx.world_size))
```

## 19.4 ddp_wrap：模型包装

### 19.4.1 哪些模型需要 wrap

| 模型 | 需要 DDP wrap？ | 原因 |
|------|---------------|------|
| policy（可训练） | 是 | 需要梯度同步 |
| reference（冻结） | 否 | 无梯度，不需要同步 |
| old_policy（冻结） | 否 | 同上 |
| reward_model（SFT 阶段） | 是（find_unused_parameters=True） | lm_head 不参与前向 |
| reward_model（RM 阶段） | 是 | 训练 reward head |
| value_head（PPO） | 是（包装整个 TransformerWithValueHead） | 训练 value |

### 19.4.2 find_unused_parameters=True

```python
# train_reward.py 中
model_ddp = ddp_wrap(model, ctx, find_unused_parameters=True)
```

Reward Model 使用 `forward_hidden`（不经过 lm_head），所以 `lm_head` 的参数不会收到梯度。DDP 默认会报错：

```
RuntimeError: Expected to have finished reduction in the prior iteration
before starting a new one. This error indicates that your module has
parameters that were not used in producing loss.
```

`find_unused_parameters=True` 告诉 DDP："有些参数可能没有梯度，别等它们了。"

### 19.4.3 unwrap：取出原始模型

```python
def unwrap(model):
    return model.module if hasattr(model, "module") else model
```

DDP 包装后的模型有一个 `.module` 属性指向原始模型。很多操作需要访问原始模型：

```python
# 构建优化器时使用 unwrap 后的模型
optimizer = configure_optimizer(unwrap(model), cfg.lr, cfg.weight_decay)

# 保存 checkpoint 时 unwrap
save_stage_ckpt(cfg.out_ckpt, model, optimizer, ...)
# 内部：payload["model_state_dict"] = unwrap(model).state_dict()

# 最终评估时用 unwrap（避免 DDP 的 collective 挂死）
dev = eval_dev(unwrap(model), cfg, ctx, DEV_PATH)
```

### 19.4.4 编译 + DDP 的顺序

```python
# train_sft.py 中
model = load_backbone_from_ckpt(cfg, cfg.pretrained_ckpt, ctx.device)
if cfg.compile:
    model = torch.compile(model)     # 先 compile
model = ddp_wrap(model, ctx)         # 再 DDP
```

**顺序很重要**：
- 先 `torch.compile` → 优化计算图
- 再 `DDP` → 包装分布式通信
- 反过来会导致 key 前缀问题（`_orig_mod.module.xxx`）

## 19.5 bf16 混合精度训练

### 19.5.1 amp_autocast 实现

```python
# utils.py

def amp_autocast(amp_dtype, device):
    if amp_dtype == "bf16" and str(device).startswith("cuda") and torch.cuda.is_available():
        return torch.autocast(device_type="cuda", dtype=torch.bfloat16)
    return contextlib.nullcontext()    # CPU 或不需要时：无操作
```

### 19.5.2 bf16 vs fp16 vs fp32

| | fp32 | fp16 | bf16 |
|---|------|------|------|
| 指数位 | 8 | 5 | 8 |
| 尾数位 | 23 | 10 | 7 |
| 动态范围 | 大 | 小（容易溢出） | 大（同 fp32） |
| 精度 | 高 | 中 | 低 |
| GradScaler | 不需要 | 需要 | 不需要 |
| 适合场景 | 通用 | 需要 scaler | **训练首选** |

### 19.5.3 为什么选 bf16

```
fp16 的问题：
  动态范围小 → 中间值溢出 → NaN loss
  需要 GradScaler → 代码复杂，额外开销

bf16 的优势：
  动态范围同 fp32 → 不会溢出
  不需要 GradScaler → 代码简洁
  显存减半 → 更大的 batch_size
  速度提升 → A100/H100 的 bf16 tensor core 极快
```

### 19.5.4 在训练循环中的使用

```python
# train_sft.py 中的典型使用
optimizer.zero_grad(set_to_none=True)
with amp_autocast(cfg.amp_dtype, ctx.device):
    logits, _ = model(tokens)                    # bf16 前向
    loss = sft_loss(logits, tokens, mask)        # bf16 loss 计算
loss.backward()                                   # bf16 反向
torch.nn.utils.clip_grad_norm_(model.parameters(), cfg.grad_clip)
optimizer.step()                                  # fp32 参数更新
```

**注意**：`optimizer.step()` 在 fp32 精度下执行——bf16 只用于前向和反向计算，参数更新保持全精度。

### 19.5.5 nullcontext 的优雅设计

```python
# CPU 上 amp_autocast 返回 nullcontext
with amp_autocast("bf16", "cpu"):
    # nullcontext() 是一个无操作的 context manager
    # 等价于不写 with
    logits, _ = model(tokens)    # fp32 正常计算
```

这意味着训练脚本不需要 `if device == "cuda":` 的条件分支——`amp_autocast` 自动适配。

## 19.6 优化器配置

### 19.6.1 AdamW + 权重衰减分组

```python
# optim.py

def configure_optimizer(model, lr, weight_decay, betas=(0.9, 0.95)):
    decay, no_decay = [], []
    for name, p in model.named_parameters():
        if not p.requires_grad:
            continue
        if p.dim() >= 2:          # 矩阵参数（权重）
            decay.append(p)
        else:                     # 1D 参数（bias、LayerNorm）
            no_decay.append(p)
    groups = [
        {"params": decay, "weight_decay": weight_decay},
        {"params": no_decay, "weight_decay": 0.0},
    ]
    return torch.optim.AdamW(groups, lr=lr, betas=betas)
```

**为什么分组？**

| 参数类型 | 维度 | 是否加 weight_decay | 原因 |
|---------|------|-------------------|------|
| Attention 权重 | 2D | 是 | 防止过拟合 |
| MLP 权重 | 2D | 是 | 同上 |
| Embedding 权重 | 2D | 是 | 同上 |
| LayerNorm 权重 | 1D | 否 | 归一化参数，不应被正则化 |
| Bias | 1D | 否 | 偏移量，不应被正则化 |

### 19.6.2 Cosine Learning Rate Schedule

```python
# optim.py

def cosine_lr(step, *, warmup_steps, max_steps, lr, min_lr):
    if step < warmup_steps:
        return lr * (step + 1) / max(1, warmup_steps)     # 线性 warmup
    if step >= max_steps:
        return min_lr                                        # 恒定最小 LR
    progress = (step - warmup_steps) / max(1, max_steps - warmup_steps)
    coeff = 0.5 * (1.0 + math.cos(math.pi * progress))
    return min_lr + coeff * (lr - min_lr)                  # 余弦衰减
```

```
LR 曲线：

lr ┤     ╱╲
   │    ╱  ╲
   │   ╱    ╲
   │  ╱      ╲
   │ ╱        ╲───────╲
   │╱                  ╲──────
min_lr───────────────────────────────
   └──┬──┬──┬──┬──┬──┬──┬──▶ step
     warmup  cosine decay    min_lr
```

### 19.6.3 逐层学习率设置

```python
# train_sft.py 中
for step in range(total_steps):
    lr = cosine_lr(step, warmup_steps=cfg.warmup_steps, max_steps=total_steps,
                    lr=cfg.lr, min_lr=cfg.min_lr)
    for g in optimizer.param_groups:
        g["lr"] = lr
```

每个 step 都重新计算并设置 LR——确保 cosine schedule 的精确执行。

## 19.7 梯度操作

### 19.7.1 zero_grad(set_to_none=True)

```python
optimizer.zero_grad(set_to_none=True)
```

| 方式 | 行为 | 显存 |
|------|------|------|
| `zero_grad()` | 梯度张量填零 | 梯度张量仍存在 |
| `zero_grad(set_to_none=True)` | 梯度张量设为 None | 释放梯度显存 |

`set_to_none=True` 节省约 **等于模型参数量的显存**（如 125M 参数 → 省 ~500MB）。

### 19.7.2 梯度裁剪

```python
torch.nn.utils.clip_grad_norm_(model.parameters(), cfg.grad_clip)
```

```
clip_grad_norm_ 的行为：
  1. 计算所有参数的梯度范数（L2 norm）
  2. 如果范数 > grad_clip：
       每个梯度 *= grad_clip / 范数
  3. 如果范数 <= grad_clip：不修改
```

| 阶段 | grad_clip | 说明 |
|------|-----------|------|
| SFT | 1.0 | 标准值 |
| DPO | 1.0 | 标准值 |
| PPO | 1.0 | 标准值 |
| GRPO | 1.0 | 标准值 |

### 19.7.3 DDP 的梯度同步时机

```python
loss.backward()     # ← DDP 在这里触发 All-Reduce（不是 optimizer.step()）
```

DDP 在 `backward()` 中通过 hook 拦截：
1. 每个参数的梯度计算完成 → 标记为 ready
2. 所有参数都 ready → 触发 All-Reduce
3. All-Reduce 完成 → `backward()` 返回

这意味着 `optimizer.step()` 时，梯度已经是全局平均值。

## 19.8 显存优化技巧汇总

### 19.8.1 显存占用分解

```
一个 ~125M 参数的模型（fp32）：

参数（fp32）:        125M × 4 bytes = 500 MB
梯度（fp32）:        125M × 4 bytes = 500 MB    ← zero_grad(set_to_none=True) 可释放
优化器状态:
  AdamW m (momentum): 125M × 4 bytes = 500 MB
  AdamW v (variance): 125M × 4 bytes = 500 MB
                      总计 ~2 GB

使用 bf16 后：
参数（fp32 master）: 500 MB
梯度（bf16）:        250 MB    ← 减半
前向中间值（bf16）:  减半
优化器状态（fp32）:  不变（master copy 必须 fp32）
                      总计 ~1.5 GB
```

### 19.8.2 PPO/GRPO 的显存挑战

```
PPO 需要同时维持：
  policy (可训练)    ~2 GB
  reference (冻结)   ~0.5 GB（无梯度、无优化器）
  reward_model       ~0.5 GB（推理模式）
  value_head         ~0.01 GB
  rollout buffer     ~0.5-1 GB
                     总计 ~3.5-4 GB

GRPO 需要同时维持：
  policy (可训练)    ~2 GB
  reference (冻结)   ~0.5 GB
  rollout buffer     ~1-2 GB（G 倍大）
                     总计 ~3.5-4 GB
```

### 19.8.3 显存优化策略

| 策略 | 节省 | 代码位置 |
|------|------|---------|
| bf16 混合精度 | ~25% | `amp_autocast` |
| `set_to_none=True` | ~500 MB | `optimizer.zero_grad` |
| `@torch.no_grad()` | 释放计算图 | 评估、rollout |
| `model.eval()` | 关闭 dropout/BN | 推理、评估 |
| `make_frozen_copy` | 无优化器状态 | reference model |
| 只保存 backbone | 无 head 权重 | `save_stage_ckpt` |

### 19.8.4 torch.no_grad() 的重要性

```python
# rollout 时不需要梯度
policy.eval()
with torch.no_grad():
    seqs, rmask, plens = rollout_prompts(policy, prompts, ...)

# 计算 old_logp 和 ref_logp 时不需要梯度
with torch.no_grad():
    old_logp, _ = compute_logprobs(policy, seqs, rmask, ...)
    ref_logp, _ = compute_logprobs(ref, seqs, rmask, ...)
```

`torch.no_grad()` 的效果：
- 不构建计算图 → 显存减少 ~50%
- 不追踪梯度 → 速度提升 ~20%

### 19.8.5 make_frozen_copy 的显存设计

```python
def make_frozen_copy(model, device=None):
    ref = copy.deepcopy(unwrap(model))    # 深拷贝
    ref.eval()
    for p in ref.parameters():
        p.requires_grad_(False)           # 冻结
    return ref
```

冻结模型的显存节省：
- 无梯度（`requires_grad=False`）→ 省 500 MB
- 无优化器状态 → 省 1 GB
- 总节省 ~1.5 GB vs 可训练副本

## 19.9 多 GPU 通信开销分析

### 19.9.1 All-Reduce 通信量

```
一次 All-Reduce 的通信量 = 2 × (N-1)/N × 参数量 × bytes_per_param

对于 125M 参数模型（bf16 梯度，2 bytes）：
  2 GPU:  2 × 1/2 × 125M × 2 = 250 MB
  4 GPU:  2 × 3/4 × 125M × 2 = 375 MB
  8 GPU:  2 × 7/8 × 125M × 2 = 437.5 MB

NVIDIA A100 NVLink: 600 GB/s
  → 250 MB 通信时间 ≈ 0.4 ms
```

### 19.9.2 通信 vs 计算的比值

```
单步训练时间分解（125M 模型，batch_size=32，context_length=256）：

计算（前向 + 反向）:  ~50 ms
通信（All-Reduce）:   ~0.4 ms    ← 仅占 0.8%
优化器 step:          ~5 ms

结论：计算远大于通信，DDP 几乎线性扩展
```

### 19.9.3 扩展效率

| GPU 数 | 理想加速 | 实际加速 | 效率 |
|--------|---------|---------|------|
| 1 | 1.0x | 1.0x | 100% |
| 2 | 2.0x | 1.9x | 95% |
| 4 | 4.0x | 3.7x | 92% |
| 8 | 8.0x | 7.0x | 88% |

效率下降的原因：
- All-Reduce 通信量随 GPU 数增长
- 数据加载的瓶颈（HDF5 单文件读取）
- 进程间同步开销

### 19.9.4 reduce_scalar 的通信成本

```python
def reduce_scalar(value, ctx, average=True):
    if not ctx.enabled:
        return value
    t = torch.tensor([value], device=ctx.device, dtype=torch.float32)
    dist.all_reduce(t, op=dist.ReduceOp.SUM)
    if average:
        t /= ctx.world_size
    return t.item()
```

`reduce_scalar` 只传输 **1 个 float**（4 bytes），通信成本几乎为零。用于：
- 跨 GPU 平均 loss
- 跨 GPU 平均 reward
- 跨 GPU 计算 informative_groups

### 19.9.5 barrier 的使用场景

```python
def barrier(ctx):
    if ctx.enabled:
        dist.barrier()
```

`barrier` 让所有进程等到最慢的那个到达。本项目中很少显式调用——DDP 的 All-Reduce 本身就是一个隐式 barrier。

## 19.10 Checkpoint 保存与 DDP

### 19.10.1 只在主进程保存

```python
if ctx.is_main and step > 0 and step % cfg.save_every == 0:
    save_stage_ckpt(cfg.out_ckpt, model, optimizer, ...)
```

**为什么只在 rank 0 保存？**
- 所有 rank 的模型参数相同 → 只需保存一份
- 避免多个进程同时写同一个文件

### 19.10.2 unwrap 后保存

```python
# save_stage_ckpt 内部
payload = {
    "model_state_dict": unwrap(model).state_dict(),    # 去掉 DDP 前缀
    ...
}
```

如果不 `unwrap`，state_dict 的 key 会带 `module.` 前缀 → 单 GPU 加载时 key 不匹配。

### 19.10.3 最终评估的 DDP 陷阱

```python
# train_sft.py 的最后
if ctx.is_main:
    # 其他 rank 已经 cleanup() 了！
    # 如果这里用 DDP-wrapped model，会触发 collective → 其他 rank 不在 → 挂死
    dev = eval_dev(unwrap(model), cfg, ctx, DEV_PATH)
```

**陷阱**：训练结束时，非主进程先调用 `cleanup()` 销毁进程组。此时主进程如果用 DDP 包装的模型做前向传播，DDP 会尝试 All-Reduce → 其他 rank 不存在 → NCCL timeout 挂死。

**解决方案**：最终评估使用 `unwrap(model)`。

## 19.11 随机种子与可复现性

### 19.11.1 每个 rank 不同的种子

```python
set_seed(cfg.seed + ctx.rank)
```

**为什么要加 rank？**

如果所有 rank 的种子相同：
- 数据 shuffle 相同 → 每个 rank 看到相同的数据顺序 → 数据并行失效
- dropout 相同 → 每个 rank 的模型行为完全相同 → 梯度完全相同 → All-Reduce 无意义

加 rank 后：
- 每个 rank 的 shuffle 不同 → 看到不同的数据子集
- 每个 rank 的 dropout 不同 → 增加模型多样性

### 19.11.2 set_seed 覆盖范围

```python
def set_seed(seed):
    random.seed(seed)           # Python random
    np.random.seed(seed)        # NumPy
    torch.manual_seed(seed)     # PyTorch CPU
    torch.cuda.manual_seed_all(seed)    # PyTorch 所有 GPU
```

## 19.12 各阶段 DDP 对比

### 19.12.1 总览

| 阶段 | DDP wrap | find_unused | 额外模型 | 数据分片方式 |
|------|---------|-------------|---------|------------|
| SFT | policy | False | 无 | stride=world_size |
| Reward | reward_model | True | 无 | stride=world_size |
| DPO | policy | False | ref (frozen) | stride=world_size |
| PPO | policy | False | ref + RM (frozen) | stride=world_size |
| GRPO | policy | False | ref (frozen) | stride=world_size |

### 19.12.2 显存需求对比（125M 模型，单 GPU）

| 阶段 | 可训练 | 冻结 | 总显存 |
|------|--------|------|--------|
| SFT | ~2 GB | 0 | ~2 GB |
| Reward | ~2 GB | 0 | ~2 GB |
| DPO | ~2 GB | ~0.5 GB | ~2.5 GB |
| PPO | ~2 GB | ~1 GB | ~3.5 GB |
| GRPO | ~2 GB | ~0.5 GB | ~3.5 GB |

## 19.13 本章小结

### 分布式训练的核心组件

| 组件 | 文件 | 功能 |
|------|------|------|
| DDPContext | distributed.py | 分布式上下文 |
| ddp_setup | distributed.py | 初始化进程组 |
| ddp_wrap | distributed.py | 模型 DDP 包装 |
| reduce_scalar | distributed.py | 跨 GPU 标量聚合 |
| amp_autocast | utils.py | bf16 混合精度 |
| configure_optimizer | optim.py | AdamW + 权重衰减分组 |
| cosine_lr | optim.py | Warmup + 余弦衰减 |

### 关键设计决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 分布式方案 | DDP | PyTorch 原生，简单可靠 |
| 启动方式 | torchrun | 标准工具，设置环境变量 |
| 代码路径 | 单一（world_size=1 退化） | 不需要两套代码 |
| 混合精度 | bf16 | 无 GradScaler，动态范围大 |
| 数据分片 | stride（步长为 world_size） | 实现简单，均匀分配 |
| 日志/保存 | 只在 rank 0 | 避免竞争和重复 |

### 关键教训

1. **单代码路径**：`DDPContext.enabled` 让同一份代码适配 1-N GPU
2. **bf16 首选**：不需要 GradScaler，代码简洁，速度更快
3. **unwrap 是必须的**：保存 checkpoint、构建优化器、最终评估都需要原始模型
4. **find_unused_parameters**：Reward Model 的 lm_head 不参与前向，必须开启
5. **梯度同步在 backward 中**：DDP 通过 hook 在反向传播时同步梯度，不是 step 时
6. **种子加 rank**：确保每个 GPU 看到不同的数据和 dropout

---

## 练习

**练习 1：单 GPU vs 多 GPU 对比**

在相同配置下，分别用 1 GPU 和 2 GPU 训练 SFT，对比训练速度和最终 loss：

```bash
# 1 GPU
PYTHONPATH=. python scripts/train_sft.py --max_steps 100

# 2 GPU
PYTHONPATH=. torchrun --standalone --nproc_per_node=2 scripts/train_sft.py --max_steps 100
```

观察：
1. 每秒处理的 step 数差异
2. 最终 dev loss 是否接近

**练习 2：bf16 vs fp32 对比**

修改 `configs/sft.json` 中的 `amp_dtype`，对比训练速度和显存占用：

```json
// bf16
{"amp_dtype": "bf16"}

// fp32
{"amp_dtype": null}
```

观察 loss 曲线是否一致，速度提升多少。

**练习 3：数据分片验证**

在 `get_sft_batch_iterator` 中打印每个 rank 看到的第一个 batch 的索引：

```python
# 在 for 循环的第一个 batch 中
if start == 0 and epoch == 0:
    print(f"rank={rank}: first batch indices = {batch.tolist()}")
```

用 `torchrun --nproc_per_node=2` 运行，验证两个 rank 看到的数据不重叠。

**练习 4：显存 profiling**

在训练循环中添加显存监控：

```python
if step % 10 == 0:
    allocated = torch.cuda.memory_allocated() / 1024**2
    reserved = torch.cuda.memory_reserved() / 1024**2
    print(f"step {step}: allocated={allocated:.0f}MB reserved={reserved:.0f}MB")
```

对比开启和关闭 bf16 的显存差异。
