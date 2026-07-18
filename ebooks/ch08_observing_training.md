# 第 8 章：观察训练——Loss 曲线与诊断

> **本章目标**：学会从 Loss 曲线、日志和训练指标中诊断问题，理解"训练正常"和"训练异常"的信号。

## 8.0 本章路线图

在第 7 章中，我们构建了完整的预训练循环。现在模型在跑了，但问题是：**你怎么知道它训练得好不好？**

训练一个 LLM 不像训练一个图像分类器那样直观。本章教你从日志中读懂模型的状态。

```
观察训练的四个维度
│
├── ① Loss 曲线：模型学到了什么
├── ② Dev vs Train Loss：模型是否过拟合
├── ③ 吞吐量（tok/s）：训练效率是否正常
└── ④ 初始 Loss：模型是否正确初始化
```

## 8.1 初始 Loss：随机猜测的基准线

### 8.1.1 理论推导

训练刚开始时，模型参数是随机初始化的，`lm_head` 输出的 logits 接近随机噪声。softmax 之后，每个 token 的概率接近均匀分布：

```
P(每个 token) ≈ 1 / vocab_size ≈ 1 / 50304

Cross-Entropy Loss = -ln(P(正确token)) ≈ -ln(1/50304) = ln(50304) ≈ 10.83
```

### 8.1.2 为什么这很重要

如果你启动训练，第一步的 Loss 在 **10.5 ~ 11.0** 之间，说明一切正常。

| 初始 Loss | 可能的问题 |
|-----------|-----------|
| 10.5 ~ 11.0 | 正常 |
| 远大于 11（如 15+） | 初始化有问题，检查模型结构 |
| 远小于 10（如 5~6） | 数据有泄漏（训练集被模型"看到"了），或者 batch 太小 |
| NaN / Inf | 数值不稳定，检查学习率、梯度裁剪 |

### 8.1.3 日志中的证据

训练脚本每 20 步打印一次：

```
step 0     | loss 10.8265 | lr 1.50e-07 | 0 tok/s
step 20    | loss 10.7843 | lr 3.00e-06 | 125,430 tok/s
step 40    | loss 10.6521 | lr 6.00e-06 | 128,200 tok/s
```

第 0 步的 loss 10.8265 非常接近理论值 10.83——这是模型的"起点"。

## 8.2 Loss 曲线解读

### 8.2.1 正常的 Loss 曲线

一个健康的预训练 Loss 曲线长这样：

```
Loss
11 ┤●
10 ┤ ●
 9 ┤  ●
 8 ┤   ●●
 7 ┤     ●●●
 6 ┤        ●●●●●●●●●
 5 ┤                 ●●●●●●●●●●●●●●●
 4 ┤                                ●●●●●●●●●●●●●●●●●●●●
 3 ┤                                                    ●●●●●●●●●
   └──────────────────────────────────────────────────────────────── Step
   0      2000    10000    50000   100000   150000   200000
         Warmup   快速下降    稳定下降      缓慢收敛
```

三个阶段：

| 阶段 | 步数范围 | Loss 变化 | 说明 |
|------|---------|----------|------|
| Warmup | 0 → 2000 | 10.8 → 5.5 | 学习率从 0 线性增长，模型快速学习基础模式 |
| 快速下降 | 2000 → 50000 | 5.5 → 4.0 | 学习率达到峰值后余弦衰减，模型深入学习 |
| 缓慢收敛 | 50000 → 200000 | 4.0 → 3.0 | 收益递减，每万步只降零点几 |

### 8.2.2 异常的 Loss 曲线

**情况 1：Loss 不下降**

```
Loss
11 ┤●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
   └──────────────────────────────────────────────────── Step
```

可能原因：
- 学习率太小（`lr=1e-8`）
- 数据有问题（全是空文档或噪声）
- 模型没有接收到梯度（检查 `loss.requires_grad`）

**情况 2：Loss 发散（上升）**

```
Loss
30 ┤                                          ●
20 ┤                              ●●●●●●●●●●●
10 ┤●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
   └──────────────────────────────────────── Step
```

可能原因：
- 学习率太大（`lr=1e-2`）
- 没有梯度裁剪（`grad_clip=None`）
- 没有 Warmup（学习率直接从峰值开始）

**情况 3：Loss 剧烈震荡**

```
Loss
 8 ┤  ●    ●        ●
 6 ┤ ●  ●●   ●●  ●●   ●●  ●
 4 ┤          ●         ●     ●●
   └─────────────────────────────── Step
```

可能原因：
- Batch size 太小（噪声太大）
- 学习率太大
- 数据质量差（有些 batch 特别好，有些特别差）

### 8.2.3 用代码画 Loss 曲线

从 JSONL 日志文件中提取数据并画图：

```python
import json
import matplotlib.pyplot as plt

# 读取日志
steps, losses, lrs = [], [], []
with open("/ephemeral/logs/pretrain_*.jsonl") as f:
    for line in f:
        d = json.loads(line)
        steps.append(d["step"])
        losses.append(d.get("train_loss", d.get("loss")))
        lrs.append(d.get("lr", 0))

# 画图
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8), sharex=True)

ax1.plot(steps, losses, color='#1565c0', lw=1.5, label='train loss')
ax1.axhline(10.83, color='#999', ls='--', lw=1, label='random guess ln(50304)')
ax1.set_ylabel("Cross-Entropy Loss")
ax1.set_title("Pretraining Loss Curve")
ax1.grid(True, alpha=0.3)
ax1.legend()

ax2.plot(steps, lrs, color='#e8730c', lw=1.5)
ax2.set_ylabel("Learning Rate")
ax2.set_xlabel("Training Step")
ax2.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig("loss_curve.png", dpi=150)
plt.show()
```

## 8.3 Dev Loss 与 Train Loss

### 8.3.1 为什么要分两个 Loss

训练脚本每隔 `eval_steps`（默认 1000 步）会在训练集和验证集上各计算 100 次 Loss 取平均：

```python
# scripts/pretrain_base.py

@torch.no_grad()
def estimate_loss(model, cfg, ctx, iters: int):
    model.eval()
    out = {}
    for split, path in [("train", cfg.train_path), ("dev", cfg.dev_path)]:
        # 在指定数据集上算 iters 次 loss 取平均
        it = get_batch_iterator(path, cfg.batch_size, cfg.context_length, device=ctx.device)
        losses = torch.zeros(iters)
        for k in range(iters):
            xb, yb = next(it)
            with amp_autocast(cfg.amp_dtype, ctx.device):
                _, loss = model(xb, yb)
            losses[k] = loss.item()
        out[split] = losses.mean().item()
    model.train()
    return out
```

### 8.3.2 Gap 的含义

```
Dev Loss
  ┃        ●●●●●●●●●●●●●●●●●●●●●●●
  ┃      ●
  ┃    ●
  ┃  ●                         ← Gap = Dev - Train
  ┃●
  ┃ ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
  ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ Step
      Train Loss
```

| Gap (Dev - Train) | 含义 |
|-------------------|------|
| 0.01 ~ 0.05 | 正常，轻微过拟合 |
| 0.1 ~ 0.3 | 开始过拟合，考虑增加数据或正则化 |
| > 0.5 | 严重过拟合，模型在训练集上"背答案" |
| < 0 | Dev 比 Train 好？检查数据分布是否一致 |

### 8.3.3 典型的 Dev vs Train 日志

```
step 2000  | loss 5.6312
  [eval] step 2000 | train 5.6234 | dev 5.6891        Gap = 0.066

step 10000 | loss 4.2156
  [eval] step 10000 | train 4.1823 | dev 4.2567       Gap = 0.074

step 50000 | loss 3.4521
  [eval] step 50000 | train 3.4102 | dev 3.5012       Gap = 0.091

step 100000| loss 3.1245
  [eval] step 100000 | train 3.0891 | dev 3.1934      Gap = 0.104

step 200000| loss 2.9876
  [eval] step 200000 | train 2.9423 | dev 3.0789      Gap = 0.137
```

可以看到 Gap 随着训练步数**缓慢增大**——这是正常的。如果 Gap 突然跳到一个很大的值，说明过拟合开始加速了，应该考虑停止训练。

### 8.3.4 影响 Gap 的因素

| 因素 | Gap 变大 | Gap 变小 |
|------|---------|---------|
| 数据量 | 太少 | 越多越好 |
| 模型大小 | 参数太多 | 适当的小模型 |
| 训练步数 | 太长 | Chinchilla 法则 |
| 正则化 | 无 weight_decay | 有 weight_decay |
| 数据多样性 | 训练集太窄 | 多源数据 |

## 8.4 吞吐量（tok/s）

### 8.4.1 什么是 tok/s

tok/s（tokens per second）衡量 GPU 每秒处理多少个 token。这是训练效率的核心指标。

```python
# scripts/pretrain_base.py

tokens_per_step = cfg.batch_size * cfg.context_length * cfg.grad_accum * ctx.world_size

if step % 20 == 0:
    dt = time.perf_counter() - t0
    tok_s = tokens_per_step * 20 / dt
    t0 = time.perf_counter()
    print(f"step {step} | ... | {tok_s:,.0f} tok/s")
```

### 8.4.2 tok/s 的计算

```
每 20 步处理的 token 数 = tokens_per_step × 20

tokens_per_step = batch_size × context_length × grad_accum × world_size
                = 8 × 256 × 12 × 2
                = 49,152 tokens/step

20 步 = 49,152 × 20 = 983,040 tokens

如果 20 步耗时 7.5 秒：
tok/s = 983,040 / 7.5 = 131,072 tok/s
```

### 8.4.3 tok/s 的正常范围

| GPU | 模型大小 | 典型 tok/s |
|-----|---------|-----------|
| A100 80GB | 77M | ~100,000 |
| H100 80GB | 77M | ~130,000 |
| H100 80GB | 400M | ~40,000 |
| L40 48GB | 77M | ~80,000 |
| RTX 4090 | 30M | ~60,000 |

**关键观察**：
- tok/s 应该在前几步后**稳定**，不应该持续下降
- 如果 tok/s 逐步降低，可能是 GPU 过热降频，或者内存泄漏
- `torch.compile` 第一步的 tok/s 会很低（编译开销），之后恢复正常

### 8.4.4 训练时间估算

```
总 token 数 = 1,500,000,000（1.5B）
tok/s = 130,000
总时间 = 1,500,000,000 / 130,000 = 11,538 秒 ≈ 3.2 小时
```

## 8.5 日志系统

### 8.5.1 JSONL 日志格式

项目使用 `MetricsLogger` 同时写两种日志：

```python
# src/post_training/logging_utils.py

class MetricsLogger:
    def __init__(self, stage, log_dir, *, use_wandb=False, ...):
        self.path = os.path.join(log_dir, f"{stage}_{stamp}.jsonl")
        self._fh = open(self.path, "a")
        # 可选：初始化 wandb
        if use_wandb:
            wandb.init(project=wandb_project, ...)

    def log(self, step, metrics):
        record = {"step": step, "wall": time.time(), **metrics}
        self._fh.write(json.dumps(record) + "\n")
        self._fh.flush()
        if self._wandb:
            self._wandb.log(metrics, step=step)
```

日志文件格式示例：

```jsonl
{"step": 0, "wall": 1720000000.5, "train_loss": 10.8265, "lr": 1.5e-07, "tok_per_s": 0.0}
{"step": 20, "wall": 1720000008.2, "train_loss": 10.7843, "lr": 3.0e-06, "tok_per_s": 125430.0}
{"step": 40, "wall": 1720000015.9, "train_loss": 10.6521, "lr": 6.0e-06, "tok_per_s": 128200.0}
...
{"step": 2000, "wall": 1720000750.3, "train_loss": 5.6312, "lr": 3.0e-04, "tok_per_s": 131500.0}
{"step": 2000, "wall": 1720000755.1, "eval_train": 5.6234, "eval_dev": 5.6891}
```

每行一个 JSON 对象，可以用 `pandas`、`jq` 或任何 JSON 解析器处理。

### 8.5.2 开启 wandb

在配置中设置 `use_wandb=True`：

```bash
# 通过 CLI 开启
PYTHONPATH=. python3 scripts/pretrain_base.py --use_wandb true

# 或修改 configs/pretrain.json
{
    "use_wandb": true,
    "wandb_project": "my-llm-experiments"
}
```

wandb 提供：
- 实时仪表盘（浏览器中查看）
- 多实验对比
- 超参数搜索
- 团队协作

### 8.5.3 从标准输出提取数据

如果只有训练的标准输出（没有 JSONL 日志），可以用正则提取：

```python
import re
import matplotlib.pyplot as plt

# 从 stdout 文件中提取
txt = open("pretrain_stdout.txt").read()

# 匹配 "step 1234 | loss 5.6789"
train = re.findall(r"step (\d+) \| loss ([\d.]+)", txt)
steps = [int(s) for s, _ in train]
losses = [float(l) for _, l in train]

# 匹配 "[eval] step 1234 | train 5.6789 | dev 5.7890"
ev = re.findall(r"\[eval\] step (\d+) \| train ([\d.]+) \| dev ([\d.]+)", txt)
ev_steps = [int(s) for s, _, _ in ev]
ev_train = [float(t) for _, t, _ in ev]
ev_dev = [float(d) for _, _, d in ev]

# 画图
fig, ax = plt.subplots(figsize=(10, 6))
ax.plot(steps, losses, alpha=0.3, color='#1565c0', label='train (raw)')
ax.plot(ev_steps, ev_train, color='#1565c0', lw=2, label='eval train')
ax.plot(ev_steps, ev_dev, color='#e8730c', lw=2, label='eval dev')
ax.axhline(10.83, color='#999', ls='--', lw=1, label='random guess')
ax.set_xlabel("Step")
ax.set_ylabel("Loss")
ax.legend()
ax.grid(True, alpha=0.3)
plt.savefig("loss_from_stdout.png", dpi=150)
```

## 8.6 训练诊断清单

### 8.6.1 启动后前 10 步检查

```
✓ 初始 Loss 在 10.5~11.0 之间
✓ Loss 在逐步下降（不是卡住或上升）
✓ tok/s 稳定（不是 0 或持续下降）
✓ 学习率在 Warmup 中逐步增长
✓ 没有 NaN / Inf 报错
✓ 没有 OOM（内存溢出）
```

### 8.6.2 前 1000 步检查

```
✓ Loss 从 10.8 降到 7 以下
✓ Dev Loss 和 Train Loss 接近（Gap < 0.1）
✓ 没有 DDP 同步错误（多 GPU 时）
✓ Checkpoint 保存正常
```

### 8.6.3 训练中途检查

```
✓ Loss 持续下降（速度变慢是正常的）
✓ Dev-Train Gap 没有突然增大
✓ tok/s 保持稳定
✓ 定期验证：生成一些文本看看质量
```

### 8.6.4 训练结束检查

```
✓ 最终 Loss 在 3.0 左右（对 77M 模型）
✓ Dev-Train Gap < 0.2
✓ 生成的文本有基本的语法结构
✓ Checkpoint 可以正常加载
```

## 8.7 实际训练日志示例

一个 77M 模型在 2x L40 上训练 200,000 步的真实日志：

```
[logger] stage=pretrain -> /ephemeral/logs/pretrain_1720000000.jsonl
Model parameters: 77,454,336 (~77M) | world_size=2
Effective batch = 8*12*2 = 192 seqs/step

step 0     | loss 10.8265 | lr 1.50e-07 | 0 tok/s
step 20    | loss 10.7843 | lr 3.00e-06 | 82,430 tok/s
step 40    | loss 10.6521 | lr 6.00e-06 | 85,200 tok/s
step 100   | loss 10.2145 | lr 1.50e-05 | 86,100 tok/s
step 200   | loss 9.4532  | lr 3.00e-05 | 86,500 tok/s
step 500   | loss 7.8921  | lr 7.50e-05 | 86,800 tok/s
step 1000  | loss 6.5432  | lr 1.50e-04 | 87,000 tok/s
step 2000  | loss 5.6312  | lr 3.00e-04 | 87,200 tok/s
  [eval] step 2000 | train 5.6234 | dev 5.6891
step 5000  | loss 4.8921  | lr 2.91e-04 | 87,100 tok/s
  [eval] step 5000 | train 4.8856 | dev 4.9623
step 10000 | loss 4.2156  | lr 2.31e-04 | 87,000 tok/s
  [eval] step 10000 | train 4.1823 | dev 4.2567
step 20000 | loss 3.7834  | lr 1.72e-04 | 87,100 tok/s
step 50000 | loss 3.4521  | lr 8.72e-05 | 87,000 tok/s
  [eval] step 50000 | train 3.4102 | dev 3.5012
step 100000| loss 3.1245  | lr 3.15e-05 | 87,100 tok/s
  [eval] step 100000 | train 3.0891 | dev 3.1934
step 150000| loss 3.0123  | lr 3.00e-05 | 87,000 tok/s
step 200000| loss 2.9876  | lr 3.00e-05 | 87,100 tok/s
  [eval] step 200000 | train 2.9423 | dev 3.0789
Done. Final checkpoint -> /ephemeral/ckpts/base_pretrained.pt
```

**关键观察**：

| 指标 | 值 | 判断 |
|------|------|------|
| 初始 Loss | 10.83 | 正常（≈ ln(50304)） |
| 最终 Loss | 2.99 | 合理（77M 模型） |
| 最终 Gap | 3.08 - 2.94 = 0.14 | 轻微过拟合，可接受 |
| tok/s | ~87,000 | 稳定 |
| Warmup 结束 | step 2000 | Loss 降到 5.6 |

## 8.8 本章小结

### 训练健康检查速查表

| 检查项 | 正常值 | 异常信号 |
|--------|--------|---------|
| 初始 Loss | 10.5 ~ 11.0 | > 12 或 < 8 |
| Loss 趋势 | 持续下降 | 不动、上升、剧烈震荡 |
| Dev-Train Gap | 0.01 ~ 0.15 | > 0.5（过拟合） |
| tok/s | 稳定 | 持续下降（过热/泄漏） |
| 学习率 | 先升后降（cosine） | 始终为 0 或始终为峰值 |

### 诊断流程

```
训练效果不好？
│
├── Loss 不下降
│   ├── 初始 Loss 不对 → 检查模型初始化
│   ├── Loss 卡在某个值 → 检查学习率
│   └── Loss 上升 → 检查学习率/梯度裁剪
│
├── Dev-Train Gap 太大
│   ├── 数据量不够 → 增加 shard 数量
│   ├── 模型太大 → 减小参数量
│   └── 训练太久 → 减少步数
│
└── tok/s 太低
    ├── 第一步慢 → torch.compile 编译开销（正常）
    ├── 持续慢 → 检查 batch_size / grad_accum
    └── 逐步变慢 → GPU 过热或内存泄漏
```

---

## 练习

**练习 1：Loss 曲线分析**

从你本地的训练日志中画出 Loss 曲线，标注三个阶段（Warmup / 快速下降 / 缓慢收敛）。

**练习 2：Dev-Train Gap 监控**

写一个脚本，从 JSONL 日志中自动计算每一步的 Dev-Train Gap，并在 Gap 超过阈值时发出警告：

```python
import json

THRESHOLD = 0.3
with open("/ephemeral/logs/pretrain_*.jsonl") as f:
    train_losses = {}
    dev_losses = {}
    for line in f:
        d = json.loads(line)
        step = d["step"]
        if "train_loss" in d:
            train_losses[step] = d["train_loss"]
        if "eval_dev" in d:
            dev_losses[step] = d["eval_dev"]

    for step in sorted(dev_losses.keys()):
        if step in train_losses:
            gap = dev_losses[step] - train_losses[step]
            status = "⚠️ OVERFIT" if gap > THRESHOLD else "✓ OK"
            print(f"step {step}: gap={gap:.4f} {status}")
```

**练习 3：训练时间预测**

假设你的 GPU 上 tok/s = 87,000：
- 训练 1.5B tokens 需要多长时间？
- 如果增加到 5B tokens（Chinchilla 77M 模型的最佳数据量），需要多长时间？
- 用 2 卡 vs 4 卡分别需要多久？

**练习 4：异常诊断**

以下是一个异常的 Loss 日志片段，诊断问题：

```
step 0     | loss 10.83 | lr 1.50e-07 | 0 tok/s
step 20    | loss 10.81 | lr 3.00e-06 | 85,000 tok/s
step 100   | loss 10.78 | lr 1.50e-05 | 86,000 tok/s
step 500   | loss 10.72 | lr 7.50e-05 | 86,500 tok/s
step 2000  | loss 10.65 | lr 3.00e-04 | 87,000 tok/s
step 5000  | loss 10.58 | lr 2.91e-04 | 87,000 tok/s
```

提示：2000 步后 Loss 几乎没降，问题出在哪里？

