# 附录

## 附录 A：数学基础——Softmax、Cross-Entropy、KL 散度

### A.1 Softmax 函数

Softmax 将一组实数（logits）转换为概率分布：

$$\text{softmax}(z_i) = \frac{e^{z_i}}{\sum_{j=1}^{V} e^{z_j}}$$

其中 $V$ 是词汇表大小，$z$ 是模型输出的 logits。

**数值稳定性**：直接计算 $e^{z_i}$ 可能溢出。实际实现中减去最大值：

$$\text{softmax}(z_i) = \frac{e^{z_i - \max(z)}}{\sum_{j=1}^{V} e^{z_j - \max(z)}}$$

**PyTorch 实现**：

```python
import torch.nn.functional as F

# 稳定的 softmax（自动减去最大值）
probs = F.softmax(logits, dim=-1)  # shape: (B, T, V)
```

**温度缩放**：在 softmax 前除以温度 $T$，控制分布的"锐利度"：

$$p_i = \frac{e^{z_i / T}}{\sum_j e^{z_j / T}}$$

| 温度 | 效果 | 适用场景 |
|------|------|---------|
| $T < 1$ | 分布更集中（接近 argmax） | 确定性生成 |
| $T = 1$ | 原始分布 | 默认 |
| $T > 1$ | 分布更均匀（接近均匀分布） | 创造性生成 |

### A.2 Cross-Entropy 损失

语言模型的目标是最小化交叉熵损失：

$$\mathcal{L}_{CE} = -\sum_{i=1}^{V} y_i \log(\hat{y}_i)$$

其中 $y$ 是 one-hot 目标向量，$\hat{y}$ 是 softmax 概率。由于 $y$ 是 one-hot，简化为：

$$\mathcal{L}_{CE} = -\log(\hat{y}_{target})$$

即**目标 token 的负对数概率**。

**PyTorch 实现**：

```python
import torch.nn.functional as F

# F.cross_entropy 内部包含 softmax + NLL
# logits: (B*T, V), targets: (B*T,)
loss = F.cross_entropy(logits, targets)
```

**Log-sum-exp 形式**：

$$\mathcal{L}_{CE} = -z_{target} + \log\sum_{j=1}^{V} e^{z_j}$$

这正是 `F.cross_entropy` 的内部实现——比先 softmax再取对数更稳定。

### A.3 KL 散度

KL 散度（Kullback-Leibler Divergence）衡量两个分布之间的"距离"：

$$D_{KL}(P \| Q) = \sum_x P(x) \log \frac{P(x)}{Q(x)} = \mathbb{E}_P\left[\log P(x) - \log Q(x)\right]$$

**性质**：
- $D_{KL} \geq 0$（Gibbs 不等式）
- $D_{KL} = 0$ 当且仅当 $P = Q$
- 不对称：$D_{KL}(P \| Q) \neq D_{KL}(Q \| P)$

**在 PPO/DPO 中的应用**：

PPO 用 KL 惩罚防止 policy 偏离 reference model 太远：

$$R_{total} = R_{task} - \beta \cdot D_{KL}(\pi_\theta \| \pi_{ref})$$

DPO 的损失函数隐含了 KL 约束：

$$\mathcal{L}_{DPO} = -\log\sigma\left(\beta \log\frac{\pi_\theta(y_w|x)}{\pi_{ref}(y_w|x)} - \beta \log\frac{\pi_\theta(y_l|x)}{\pi_{ref}(y_l|x)}\right)$$

**PyTorch 实现**：

```python
import torch.nn.functional as F

# 方法 1：从 log 概率计算
kl = (log_probs_policy - log_probs_ref).mean()

# 方法 2：F.kl_div（需要概率分布）
kl = F.kl_div(F.log_softmax(logits_p, dim=-1),
              F.softmax(logits_r, dim=-1),
              reduction='batchmean')
```

### A.4 Log-Softmax 与 Log-概率

在 RL 中，我们需要 token 级别的 log 概率：

$$\log p(t_i \mid t_{\lt i}) = \log \text{softmax}(z_i)_{t_i}$$

**PyTorch 实现**：

```python
# 稳定的 log_softmax
log_probs = F.log_softmax(logits, dim=-1)   # (B, T, V)
# 提取目标 token 的 log 概率
token_logprobs = log_probs.gather(-1, target_ids.unsqueeze(-1)).squeeze(-1)
```

### A.5 GAE（Generalized Advantage Estimation）

PPO 中的优势函数使用 GAE：

$$\hat{A}_t = \sum_{l=0}^{T-t-1} (\gamma \lambda)^l \delta_{t+l}$$

其中 TD 误差：

$$\delta_t = r_t + \gamma V(s_{t+1}) - V(s_t)$$

$\gamma$ 是折扣因子（通常 1.0），$\lambda$ 是 GAE 衰减因子（通常 0.95）。

---

## 附录 B：PyTorch 基础速查

### B.1 Tensor 操作

```python
import torch

# 创建
x = torch.zeros(3, 4)          # 全零
x = torch.ones(3, 4)           # 全一
x = torch.randn(3, 4)          # 标准正态
x = torch.randint(0, 10, (3,)) # 随机整数

# 形状操作
x.shape                        # torch.Size([3, 4])
x.reshape(12)                  # 展平
x.unsqueeze(0)                 # 添加维度 → (1, 3, 4)
x.squeeze()                    # 移除大小为 1 的维度
x.transpose(0, 1)              # 转置 → (4, 3)

# 索引
x[0]                           # 第一行
x[:, 1]                        # 第二列
x[1:3, :2]                     # 切片

# 聚合
x.sum()                        # 全局求和
x.mean(dim=-1)                 # 最后一维均值
x.max(dim=-1)                  # 最后一维最大值（返回值, 索引）
```

### B.2 自动求导

```python
x = torch.randn(3, requires_grad=True)
y = (x ** 2).sum()
y.backward()                   # 计算梯度
print(x.grad)                  # 查看梯度

# 不追踪梯度
with torch.no_grad():
    z = x * 2                  # 不创建计算图

# 清除梯度
x.grad.zero_()                 # 或 optimizer.zero_grad()
```

### B.3 模型定义

```python
import torch.nn as nn

class MyModel(nn.Module):
    def __init__(self, n_embed):
        super().__init__()
        self.linear = nn.Linear(n_embed, n_embed)
        self.norm = nn.LayerNorm(n_embed)

    def forward(self, x):
        return self.linear(self.norm(x))

model = MyModel(256)
# 参数量
total = sum(p.numel() for p in model.parameters())
# 可训练参数
trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
```

### B.4 训练循环模板

```python
optimizer = torch.optim.AdamW(model.parameters(), lr=1e-4, weight_decay=0.1)

for step in range(total_steps):
    model.train()
    optimizer.zero_grad(set_to_none=True)

    # 前向传播
    logits, loss = model(input_ids, targets)

    # 反向传播
    loss.backward()

    # 梯度裁剪
    torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)

    # 更新参数
    optimizer.step()
```

### B.5 DDP（分布式数据并行）

```python
from torch.distributed import init_process_group, destroy_process_group
from torch.nn.parallel import DistributedDataParallel as DDP

# 初始化
init_process_group(backend="nccl")
rank = int(os.environ["RANK"])
local_rank = int(os.environ["LOCAL_RANK"])
device = f"cuda:{local_rank}"
torch.cuda.set_device(device)

# 包装模型
model = model.to(device)
model = DDP(model, device_ids=[local_rank])

# 训练结束后
destroy_process_group()
```

启动命令：

```bash
torchrun --standalone --nproc_per_node=2 scripts/train_sft.py
```

### B.6 混合精度（bf16）

```python
# bf16 混合精度上下文
with torch.autocast(device_type="cuda", dtype=torch.bfloat16):
    logits, loss = model(input_ids, targets)

# bf16 不需要 GradScaler（动态范围与 fp32 相同）
loss.backward()
optimizer.step()
```

### B.7 模型保存与加载

```python
# 保存
torch.save({
    "model_state_dict": model.state_dict(),
    "cfg": {"n_embed": 256, "n_head": 4, "n_blocks": 6},
}, "checkpoint.pt")

# 加载
ckpt = torch.load("checkpoint.pt", map_location="cpu", weights_only=False)
model.load_state_dict(ckpt["model_state_dict"])
```

### B.8 常用函数速查

| 函数 | 用途 | 示例 |
|------|------|------|
| `F.cross_entropy` | 交叉熵损失 | `F.cross_entropy(logits, targets)` |
| `F.log_softmax` | 对数 softmax | `F.log_softmax(logits, dim=-1)` |
| `F.softmax` | softmax | `F.softmax(logits, dim=-1)` |
| `torch.cat` | 拼接 tensor | `torch.cat([a, b], dim=-1)` |
| `torch.stack` | 堆叠 tensor | `torch.stack([a, b], dim=0)` |
| `gather` | 按索引取值 | `logits.gather(-1, ids.unsqueeze(-1))` |
| `masked_fill` | 掩码填充 | `scores.masked_fill(mask == 0, float('-inf'))` |
| `torch.tril` | 下三角矩阵 | `torch.tril(torch.ones(T, T))` |
| `clamp` | 值域裁剪 | `torch.clamp(x, -10, 10)` |

---

## 附录 C：全部 CLI 命令速查表

### C.1 数据准备

```bash
# 预训练数据（The Pile → HDF5）
python scripts/prepare_pretrain_data.py --split train --num_shards 1 --out /ephemeral/data/pile_train.h5
python scripts/prepare_pretrain_data.py --split val --out /ephemeral/data/pile_dev.h5

# SFT 数据（Alpaca + Dolly + GSM8K）
python scripts/prepare_sft_data.py

# 偏好数据（HH-RLHF + UltraFeedback）
python scripts/prepare_preference_data.py --source both

# RL 提示数据（GSM8K + 算术）
python scripts/prepare_rl_prompts.py
```

### C.2 预训练

```bash
# 单 GPU
PYTHONPATH=. python scripts/pretrain_base.py

# 多 GPU
PYTHONPATH=. torchrun --standalone --nproc_per_node=2 scripts/pretrain_base.py

# 自定义参数
PYTHONPATH=. python scripts/pretrain_base.py --batch_size 16 --train_steps 50000

# Smoke test（小模型，CPU）
PYTHONPATH=. python scripts/pretrain_base.py --config configs/smoke/pretrain.json
```

### C.3 后训练各阶段

**SFT**：

```bash
PYTHONPATH=. python scripts/train_sft.py
PYTHONPATH=. python scripts/train_sft.py --config configs/smoke/sft.json
PYTHONPATH=. torchrun --standalone --nproc_per_node=2 scripts/train_sft.py
PYTHONPATH=. python scripts/train_sft.py --lr 2e-5 --epochs 5
```

**Reward Model**：

```bash
PYTHONPATH=. python scripts/train_reward.py
PYTHONPATH=. python scripts/train_reward.py --config configs/smoke/reward.json
```

**DPO**：

```bash
PYTHONPATH=. python scripts/train_dpo.py
PYTHONPATH=. python scripts/train_dpo.py --loss_type dpo
PYTHONPATH=. python scripts/train_dpo.py --loss_type orpo --orpo_lambda 0.5
PYTHONPATH=. python scripts/train_dpo.py --loss_type kto
```

**PPO**：

```bash
PYTHONPATH=. python scripts/train_ppo.py
PYTHONPATH=. python scripts/train_ppo.py --reward_source verifier
PYTHONPATH=. python scripts/train_ppo.py --reward_source rm
```

**GRPO**：

```bash
PYTHONPATH=. python scripts/train_grpo.py
PYTHONPATH=. python scripts/train_grpo.py --config configs/smoke/grpo.json
```

### C.4 评估与推理

```bash
# 评估单个 checkpoint
PYTHONPATH=. python scripts/eval_post_training.py --ckpt /ephemeral/ckpts/sft.pt --label sft

# 批量评估所有阶段
for s in base_pretrained sft dpo ppo grpo; do
  PYTHONPATH=. python scripts/eval_post_training.py \
    --ckpt /ephemeral/ckpts/$s.pt --label $s --limit 200 \
    --append /ephemeral/logs/stage_table.jsonl
done
PYTHONPATH=. python scripts/eval_post_training.py --table /ephemeral/logs/stage_table.jsonl

# 交互式对话
PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/grpo.pt

# Raw 模式（base model 续写）
PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/base_pretrained.pt --raw

# One-shot 生成
PYTHONPATH=. python scripts/chat.py --ckpt /ephemeral/ckpts/sft.pt --prompt "What is 13+29?"

# 文本生成脚本
PYTHONPATH=. python scripts/generate_text.py --ckpt /ephemeral/ckpts/base_pretrained.pt
```

### C.5 一键全链路

```bash
# 2 GPU（默认）
bash scripts/run_posttraining.sh

# 1 GPU
NPROC=1 bash scripts/run_posttraining.sh
```

### C.6 测试与验证

```bash
# Smoke Test（代码逻辑验证，不需要 GPU）
PYTHONPATH=. python tests/test_post_training_smoke.py

# 数据与评估验证
PYTHONPATH=. python tests/verify_data_and_eval.py

# 端到端验证
PYTHONPATH=. python tests/verify_rl_optimizes.py
```

### C.7 UI 控制台

```bash
# 启动 Streamlit UI
streamlit run ui/app.py

# 指定端口
streamlit run ui/app.py --server.port 8888

# 远程访问
streamlit run ui/app.py --server.address 0.0.0.0
```

### C.8 通用 CLI 参数

所有训练脚本支持以下通用参数：

```bash
--config PATH          # 指定配置文件（默认 configs/<stage>.json）
--print-config         # 打印解析后的配置并退出
--<field> VALUE        # 覆盖任意配置字段
```

覆盖示例：

```bash
python scripts/train_sft.py --lr 2e-5 --batch_size 8 --epochs 2
python scripts/train_dpo.py --beta 0.5 --loss_type orpo
python scripts/train_ppo.py --clip 0.1 --kl_coef 0.02
python scripts/train_grpo.py --group_size 16 --prompts_per_iter 4
```

---

## 附录 D：配置文件完整参考

### D.1 配置合并规则

配置采用四层合并（优先级从低到高）：

```
1. dataclass 默认值    (config/post_training_config.py)
2. configs/base.json   (共享模型 + 运行时参数)
3. configs/<stage>.json (该阶段的超参数)
4. CLI --field 参数     (最高优先级)
```

### D.2 configs/base.json（共享模型配置）

```json
{
    "vocab_size": 50304,
    "context_length": 256,
    "n_embed": 256,
    "n_head": 4,
    "n_blocks": 6,
    "device": "cuda",
    "amp_dtype": "bf16",
    "seed": 1337,
    "compile": false,
    "ckpt_dir": "/ephemeral/ckpts",
    "log_dir": "/ephemeral/logs",
    "use_wandb": false,
    "wandb_project": "train-llm-from-scratch-posttrain"
}
```

### D.3 configs/smoke/base.json（Smoke 模型配置）

```json
{
    "vocab_size": 50304,
    "context_length": 256,
    "n_embed": 128,
    "n_head": 4,
    "n_blocks": 2,
    "device": "cpu",
    "amp_dtype": null
}
```

### D.4 configs/pretrain.json

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `train_path` | str | `data/train/pile_train.h5` | 训练数据路径 |
| `dev_path` | str | `data/val/pile_dev.h5` | 验证数据路径 |
| `batch_size` | int | 24 | 每 GPU micro-batch 大小 |
| `grad_accum` | int | 8 | 梯度累积步数 |
| `train_steps` | int | 200000 | 总训练步数 |
| `eval_steps` | int | 1000 | 每隔多少步评估一次 |
| `eval_iters` | int | 100 | 评估时的迭代次数 |
| `warmup_steps` | int | 2000 | 学习率 warmup 步数 |
| `lr` | float | 3e-4 | 峰值学习率 |
| `min_lr` | float | 3e-5 | 最小学习率 |
| `weight_decay` | float | 0.1 | AdamW 权重衰减 |
| `grad_clip` | float | 1.0 | 梯度裁剪阈值 |
| `out_ckpt` | str | `/ephemeral/ckpts/base_pretrained.pt` | 输出 checkpoint |
| `save_every` | int | 2000 | 每隔多少步保存 |

### D.5 configs/sft.json

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `pretrained_ckpt` | str | `/ephemeral/ckpts/base_pretrained.pt` | 预训练 checkpoint |
| `data_path` | str | `/ephemeral/data/sft_packed.h5` | SFT 数据路径 |
| `out_ckpt` | str | `/ephemeral/ckpts/sft.pt` | 输出 checkpoint |
| `batch_size` | int | 16 | micro-batch 大小 |
| `grad_accum` | int | 2 | 梯度累积步数 |
| `epochs` | int | 3 | 训练轮数 |
| `max_steps` | int | -1 | 最大步数（-1 = 跑完所有 epoch） |
| `eval_steps` | int | 200 | 评估间隔 |
| `warmup_steps` | int | 100 | warmup 步数 |
| `lr` | float | 1e-5 | 学习率 |
| `min_lr` | float | 1e-6 | 最小学习率 |
| `weight_decay` | float | 0.0 | 权重衰减 |
| `grad_clip` | float | 1.0 | 梯度裁剪 |
| `save_every` | int | 500 | 保存间隔 |

### D.6 configs/reward.json

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `sft_ckpt` | str | `/ephemeral/ckpts/sft.pt` | SFT checkpoint |
| `pref_path` | str | `/ephemeral/data/preferences.jsonl` | 偏好数据路径 |
| `out_ckpt` | str | `/ephemeral/ckpts/reward.pt` | 输出 checkpoint |
| `batch_size` | int | 8 | 每步的 pair 数 |
| `epochs` | int | 1 | 训练轮数 |
| `eval_steps` | int | 200 | 评估间隔 |
| `warmup_steps` | int | 50 | warmup 步数 |
| `lr` | float | 1e-5 | 学习率 |
| `weight_decay` | float | 0.0 | 权重衰减 |
| `grad_clip` | float | 1.0 | 梯度裁剪 |
| `max_len` | int | 768 | 最大序列长度 |
| `save_every` | int | 500 | 保存间隔 |

### D.7 configs/dpo.json

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `sft_ckpt` | str | `/ephemeral/ckpts/sft.pt` | SFT checkpoint |
| `pref_path` | str | `/ephemeral/data/preferences.jsonl` | 偏好数据路径 |
| `out_ckpt` | str | `/ephemeral/ckpts/dpo.pt` | 输出 checkpoint |
| `loss_type` | str | `"dpo"` | 损失类型：`dpo` / `orpo` / `kto` |
| `beta` | float | 0.1 | KL 温度参数 |
| `orpo_lambda` | float | 1.0 | ORPO odds-ratio 权重 |
| `batch_size` | int | 8 | micro-batch 大小 |
| `epochs` | int | 1 | 训练轮数 |
| `eval_steps` | int | 200 | 评估间隔 |
| `warmup_steps` | int | 50 | warmup 步数 |
| `lr` | float | 5e-7 | 学习率 |
| `weight_decay` | float | 0.0 | 权重衰减 |
| `grad_clip` | float | 1.0 | 梯度裁剪 |
| `max_len` | int | 768 | 最大序列长度 |
| `save_every` | int | 500 | 保存间隔 |

### D.8 configs/ppo.json

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `sft_ckpt` | str | `/ephemeral/ckpts/sft.pt` | SFT checkpoint |
| `reward_ckpt` | str | `/ephemeral/ckpts/reward.pt` | Reward Model checkpoint |
| `prompt_path` | str | `/ephemeral/data/rl_prompts_train.jsonl` | 训练 prompt |
| `eval_prompt_path` | str | `/ephemeral/data/rl_prompts_test.jsonl` | 评估 prompt |
| `out_ckpt` | str | `/ephemeral/ckpts/ppo.pt` | 输出 checkpoint |
| `reward_source` | str | `"verifier"` | 奖励来源：`verifier` / `rm` |
| `iterations` | int | 1000 | PPO 迭代次数 |
| `prompts_per_iter` | int | 32 | 每次迭代的 prompt 数 |
| `rollout_len` | int | 300 | 最大生成长度 |
| `temperature` | float | 1.0 | 采样温度 |
| `top_p` | float | 1.0 | nucleus 采样 |
| `ppo_epochs` | int | 4 | 每次迭代的 PPO epoch |
| `minibatch_size` | int | 16 | minibatch 大小 |
| `clip` | float | 0.2 | PPO 裁剪比例 |
| `vf_clip` | float | 0.2 | Value Function 裁剪 |
| `vf_coef` | float | 0.5 | Value loss 系数 |
| `ent_coef` | float | 0.0 | 熵正则系数 |
| `gamma` | float | 1.0 | 折扣因子 |
| `gae_lambda` | float | 0.95 | GAE 衰减因子 |
| `kl_coef` | float | 0.05 | KL 惩罚系数 |
| `lr` | float | 1e-6 | 学习率 |
| `grad_clip` | float | 1.0 | 梯度裁剪 |
| `eval_every` | int | 50 | 评估间隔 |
| `save_every` | int | 100 | 保存间隔 |

### D.9 configs/grpo.json

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `sft_ckpt` | str | `/ephemeral/ckpts/sft.pt` | SFT checkpoint |
| `prompt_path` | str | `/ephemeral/data/rl_prompts_train.jsonl` | 训练 prompt |
| `eval_prompt_path` | str | `/ephemeral/data/rl_prompts_test.jsonl` | 评估 prompt |
| `curriculum_path` | str | `/ephemeral/data/arithmetic_prompts.jsonl` | 课程学习 prompt |
| `curriculum_iters` | int | 100 | 课程预热迭代数 |
| `out_ckpt` | str | `/ephemeral/ckpts/grpo.pt` | 输出 checkpoint |
| `iterations` | int | 1000 | GRPO 迭代次数 |
| `prompts_per_iter` | int | 8 | 每次迭代的 prompt 数 |
| `group_size` | int | 8 | 每个 prompt 的采样数 |
| `rollout_len` | int | 300 | 最大生成长度 |
| `temperature` | float | 1.0 | 采样温度 |
| `top_p` | float | 1.0 | nucleus 采样 |
| `grpo_epochs` | int | 1 | 每次迭代的 GRPO epoch |
| `clip` | float | 0.2 | PPO 裁剪比例 |
| `kl_coef` | float | 0.04 | KL 惩罚系数 |
| `lr` | float | 1e-6 | 学习率 |
| `grad_clip` | float | 1.0 | 梯度裁剪 |
| `eval_every` | int | 50 | 评估间隔 |
| `save_every` | int | 100 | 保存间隔 |

---

## 附录 E：术语表

| 术语 | 英文 | 说明 |
|------|------|------|
| **Actor-Critic** | Actor-Critic | PPO 的架构：Actor 生成动作，Critic 评估状态价值 |
| **AdamW** | AdamW | 解耦权重衰减的 Adam 优化器 |
| **All-Reduce** | All-Reduce | DDP 中的梯度同步操作，将所有 GPU 的梯度求和 |
| **autocast** | autocast | PyTorch 的混合精度上下文管理器 |
| **Backbone** | Backbone | Transformer 主干网络（不含任务特定的 head） |
| **Batch Size** | Batch Size | 每次梯度更新的样本数（micro-batch × grad_accum × world_size） |
| **bf16** | bfloat16 | Brain Float 16，动态范围与 fp32 相同的半精度格式 |
| **Bradley-Terry** | Bradley-Terry | 偏好模型：用 Elo 评分预测 chosen 优于 rejected 的概率 |
| **Chat Template** | Chat Template | 对话模板，将 user/assistant 消息编码为 token 序列 |
| **Checkpoint** | Checkpoint | 模型参数快照，包含 state_dict 和配置信息 |
| **Chinchilla** | Chinchilla | DeepMind 的 Scaling Law 研究：模型和数据应同步增大 |
| **Context Length** | Context Length | 模型能处理的最大 token 序列长度 |
| **Cosine Schedule** | Cosine Schedule | 学习率调度：warmup + 余弦衰减到 min_lr |
| **Cross-Entropy** | Cross-Entropy | 交叉熵损失：$-\log p(target)$ |
| **Curriculum Learning** | Curriculum Learning | 课程学习：先学简单任务再学困难任务 |
| **DDP** | DistributedDataParallel | PyTorch 的分布式数据并行训练框架 |
| **DPO** | Direct Preference Optimization | 直接从偏好数据优化策略，无需 Reward Model |
| **Elo Rating** | Elo Rating | 国际象棋等级分系统，用于 Bradley-Terry 偏好模型 |
| **Embedding** | Embedding | 将 token ID 映射到稠密向量的查找表 |
| **Entropy** | Entropy | 分布的熵，PPO 中用作正则项鼓励探索 |
| **EOT** | End of Turn | 对话轮次结束标记 |
| **Flash Attention** | Flash Attention | IO 感知的注意力实现，降低显存并加速 |
| **FLOPs** | FLOPs | 浮点运算次数，衡量计算量 |
| **GAE** | Generalized Advantage Estimation | PPO 中的优势函数估计方法 |
| **GPT** | Generative Pre-trained Transformer | 生成式预训练 Transformer |
| **Grad Accum** | Gradient Accumulation | 梯度累积：多步小 batch 等效一步大 batch |
| **Grad Checkpointing** | Gradient Checkpointing | 用计算换显存：前向时不保存中间激活 |
| **GRPO** | Group Relative Policy Optimization | DeepSeek 的 RL 算法，无需 Value Head |
| **GSM8K** | GSM8K | 小学数学题基准测试（8,500 题） |
| **HDF5** | HDF5 | 分层数据格式，用于存储预训练 token |
| **Head** | Head | 任务特定的输出层（lm_head / reward_head / value_head） |
| **KL Divergence** | KL Divergence | KL 散度，衡量两个分布的差异 |
| **Logits** | Logits | 模型最后一层线性层的输出（softmax 前的原始分数） |
| **Log-probs** | Log-probabilities | token 的对数概率，RL 中的关键量 |
| **Loss Mask** | Loss Mask | SFT 中的损失掩码：只在 assistant 回复上计算 loss |
| **LR** | Learning Rate | 学习率 |
| **Micro-batch** | Micro-batch | 单次前向传播的 batch 大小（受显存限制） |
| **MoE** | Mixture of Experts | 混合专家模型：稀疏激活，条件计算 |
| **n_blocks** | n_blocks | Transformer block 的数量（模型深度） |
| **n_embed** | n_embed | 嵌入维度（模型宽度） |
| **n_head** | n_head | 注意力头的数量 |
| **Nucleus Sampling** | Nucleus Sampling | top-p 采样：从累积概率 ≥ p 的 token 中采样 |
| **OOM** | Out of Memory | 显存不足错误 |
| **ORPO** | Odds Ratio Preference Optimization | 使用 odds ratio 的偏好优化 |
| **Packed Data** | Packed Data | 将多条对话拼接成固定长度的训练样本 |
| **Perplexity** | Perplexity | 困惑度：$\exp(\text{loss})$，衡量模型不确定性 |
| **Policy** | Policy | RL 中的策略模型（即被训练的 LLM） |
| **PPO** | Proximal Policy Optimization | 近端策略优化：带裁剪的 RL 算法 |
| **Preference Data** | Preference Data | 偏好数据：(prompt, chosen, rejected) 三元组 |
| **Reference Model** | Reference Model | 参考模型：DPO/PPO 中冻结的 SFT 模型副本 |
| **Reward Model** | Reward Model | 奖励模型：从偏好数据学习的评分函数 |
| **RLHF** | Reinforcement Learning from Human Feedback | 基于人类反馈的强化学习 |
| **RLVR** | Reinforcement Learning with Verifiable Rewards | 基于可验证奖励的 RL（如 GSM8K 答案验证） |
| **Rollout** | Rollout | RL 中策略模型生成完整响应的过程 |
| **Scaling Laws** | Scaling Laws | 模型性能与参数量/数据量/计算量的幂律关系 |
| **SFT** | Supervised Fine-Tuning | 监督微调：在指令数据上微调预训练模型 |
| **Smoke Test** | Smoke Test | 快速验证测试：小模型 + 少步数，确认代码能跑通 |
| **Softmax** | Softmax | 将 logits 转换为概率分布的函数 |
| **Temperature** | Temperature | 采样温度：控制生成多样性的参数 |
| **tiktoken** | tiktoken | OpenAI 的 BPE 分词器库 |
| **Token** | Token | 分词后的最小文本单元 |
| **Top-k** | Top-k | 采样策略：只从概率最高的 k 个 token 中采样 |
| **Top-p** | Top-p | 采样策略：从累积概率 ≥ p 的 token 中采样 |
| **torchrun** | torchrun | PyTorch 的分布式启动器 |
| **Transformer Block** | Transformer Block | Transformer 的基本单元：Attention + MLP + LayerNorm + Residual |
| **Unwrap** | Unwrap | 从 DDP 包装中提取原始模型 |
| **Value Head** | Value Head | PPO 中的状态价值估计头 |
| **vocab_size** | vocab_size | 词汇表大小（本项目的 50304 是 64 的倍数，优化对齐） |
| **Warmup** | Warmup | 学习率预热：从 0 线性增长到峰值 lr |
| **Weight Decay** | Weight Decay | L2 正则化：在优化器中对参数施加衰减 |
| **world_size** | world_size | 分布式训练中的 GPU 总数 |
| **Zero-shot** | Zero-shot | 零样本：不提供示例直接让模型回答 |
| **ZeRO** | Zero Redundancy Optimizer | DeepSpeed 的显存优化技术 |

## 附录 F：代码库详解——train-llm-from-scratch

本书全部代码均来自开源项目 [train-llm-from-scratch](https://github.com/FareedKhan-dev/train-llm-from-scratch)。该项目用纯 PyTorch 从零实现了一个完整的 LLM 训练流水线，涵盖从原始文本到对齐推理模型的全流程，不依赖 `trl`、`peft`、`transformers` 等外部库。

### F.1 项目定位

> *"A straightforward method for training your LLM, from downloading data to generating text."*

该项目的核心理念是：**一个想法反复贯彻——把文本变成数字，预测下一个 token，然后不断改变数据和损失函数，直到模型做我们想让它做的事。**

完整路径如下：

```
原始文本 → token → Transformer → 下一个 token 损失 → 基础模型
基础模型 → SFT → 奖励模型 → {PPO, DPO} → GRPO → 评估与对话
```

### F.2 目录结构

```
train-llm-from-scratch/
├── src/
│   ├── models/                  # Transformer 模型，由小部件逐步搭建
│   │   ├── mlp.py               # 前馈网络（MLP）
│   │   ├── attention.py         # 单头与多头注意力
│   │   ├── transformer_block.py # 一个 Block：Attention + MLP + 残差连接
│   │   └── transformer.py       # 完整模型：Embeddings + Blocks + lm_head
│   └── post_training/           # SFT、奖励模型、PPO、DPO、GRPO、评估、推理
├── config/
│   ├── config.py                # 旧版预训练配置（纯 Python 常量）
│   ├── post_training_config.py  # 所有后训练阶段的 dataclass 定义
│   └── loader.py                # 配置合并：defaults < base.json < stage.json < CLI
├── configs/                     # 可编辑 JSON 配置文件，每个阶段一个文件（+ smoke/）
├── data_loader/                 # 各类数据的 batch iterator
├── scripts/                     # 所有可执行的训练/评估脚本
├── ui/                          # Streamlit 控制面板
├── docs/                        # MkDocs 文档站（理论 + 架构图）
├── images/                      # README 中的架构图（+ 生成器）
└── pyproject.toml               # pip install -e . 的安装配置
```

### F.3 核心设计原则：封装，不重写

整个后训练流水线只修改了教学模型中的**一处**——在 `Transformer` 类中添加了一个 `forward_hidden` 方法，返回 `lm_head` 消费之前的最终隐藏状态。所有后训练头（PPO 的价值头、奖励模型的标量头）和 RL 对数概率计算都围绕这个方法组合，原始的从零模型保持不变。

### F.4 训练流水线概览

| 阶段 | 数据 | 核心损失 | 输出 |
|------|------|---------|------|
| 预训练 | The Pile（9.8B token） | 下一个 token 交叉熵 | `base_pretrained.pt`（~400M 参数） |
| SFT | Alpaca + Dolly + GSM8K | 带掩码的交叉熵（仅助手 token） | `sft.pt` |
| 奖励模型 | HH-RLHF + UltraFeedback | Bradley-Terry 偏好损失 | `reward.pt` |
| DPO/ORPO/KTO | 偏好对 | 序列对数概率偏好损失 | `dpo.pt` |
| PPO | 采样回复 + 奖励 | 截断策略梯度 + GAE + KL | `ppo.pt` |
| GRPO | 分组采样 + 验证器 | 组相对截断策略梯度 | `grpo.pt` |

### F.5 配置系统

项目有两套配置系统：

- **旧版**：`config/config.py`，纯 Python 常量，用于 `scripts/train_transformer.py`
- **新版**：`config/post_training_config.py` + `configs/` 目录下的 JSON 文件，驱动所有其他阶段

新版配置的合并优先级（从低到高）：

```
dataclass 默认值 < configs/base.json < configs/<stage>.json < CLI --field 覆盖
```

例如，修改 SFT 的学习率只需：

```bash
python scripts/train_sft.py --lr 2e-5 --batch_size 16
```

`configs/smoke/` 目录下有每个阶段的微型配置（小模型 + 少步数 + CPU），用于快速验证代码是否能跑通。

### F.6 关键脚本一览

**数据准备：**

```bash
python scripts/prepare_pretrain_data.py   # Pile 数据 → pile_train.h5
python scripts/prepare_sft_data.py        # 指令数据 → sft_packed.h5
python scripts/prepare_preference_data.py # 偏好对 → preferences.jsonl
python scripts/prepare_rl_prompts.py      # RL prompt → rl_prompts.jsonl
```

**训练：**

```bash
python scripts/pretrain_base.py           # 预训练基础模型
python scripts/train_sft.py               # 监督微调
python scripts/train_reward.py            # 奖励模型
python scripts/train_dpo.py               # DPO/ORPO/KTO
python scripts/train_ppo.py               # PPO（经典 RLHF）
python scripts/train_grpo.py              # GRPO（DeepSeek-R1 风格）
```

**评估与推理：**

```bash
python scripts/eval_post_training.py      # GSM8K 准确率评估
python scripts/chat.py --ckpt xxx.pt      # 与任意 checkpoint 对话
```

**一键运行全部阶段：**

```bash
bash scripts/run_posttraining.sh          # SFT → RM → DPO → PPO → GRPO → 评估表
```

### F.7 硬件需求参考

| GPU | 显存 | 13M 模型 | 2B 模型 | 最大实用训练规模 |
|-----|------|---------|---------|----------------|
| A100 | 40 GB | ✔ | ✔ | ~6B–8B |
| RTX 4090 | 24 GB | ✔ | ✔ | ~4B |
| RTX 3090 | 24 GB | ✔ | ✔ | ~3.5B–4B |
| V100 | 16 GB | ✔ | ✘ | ~2B |
| Tesla T4 | 16 GB | ✔ | ✘ | ~1.5B–2B |

如果大配置显存不足，预训练脚本支持 `--amp`、`--grad-checkpointing`、`--grad-accum` 等选项来降低显存占用。

### F.8 安装与快速开始

```bash
git clone https://github.com/FareedKhan-dev/train-llm-from-scratch.git
cd train-llm-from-scratch
pip install -e .              # 基础安装
pip install -e ".[train]"     # + datasets + wandb
pip install -e ".[ui]"        # + Streamlit 控制面板
pip install -e ".[docs]"      # + MkDocs 文档
pip install -e ".[all]"       # 全部可选依赖
```

该项目还提供了一个 **Streamlit 控制面板**（`streamlit run ui/app.py`），包含理论说明、一键训练、实时日志、指标图表、评估和对话功能，无需记忆命令即可驱动整个流水线。
