# 第 23 章：从项目到产品

> **本章目标**：掌握 Smoke Test 与快速验证策略，理解一键全链路脚本的设计，学习代码组织与可维护性最佳实践，并了解进一步探索的方向。

## 23.0 本章路线图

前 22 章从零搭建了一个完整的 LLM 后训练系统。本章将视角从"实现功能"转向"工程化交付"——如何让代码可靠、可复现、可维护。

```
本章覆盖的内容

从项目到产品
├── Smoke Test 与快速验证
├── 一键全链路脚本设计
├── 代码组织与可维护性
├── 项目回顾与全景总结
└── 进一步探索方向
```

## 23.1 Smoke Test 与快速验证

### 23.1.1 为什么需要 Smoke Test

```
长时间训练的风险：

  启动 2 小时的训练 → 跑了 30 分钟发现代码有 bug → 浪费 30 分钟
  
常见失败原因：
  ✗ 数据格式错误（context_length 不匹配）
  ✗ checkpoint 加载失败（key 不匹配）
  ✗ 超参数设置错误（lr 太大导致 NaN）
  ✗ 显存不足（batch_size 太大）
  ✗ 代码逻辑错误（loss 计算、梯度更新）

Smoke Test 的价值：
  ✓ 在几秒钟内验证代码能跑通
  ✓ 使用 tiny model（13M 参数）+ CPU
  ✓ 跑 10-20 步确认没有 crash
  ✓ 确认 loss 在下降（即使值很大）
```

### 23.1.2 Smoke 配置设计

本项目为每个训练阶段提供了对应的 Smoke 配置：

```
configs/
├── base.json          # 正式配置（256 维，6 blocks）
├── sft.json
├── dpo.json
├── ...
└── smoke/
    ├── base.json      # Smoke 配置（128 维，2 blocks）
    ├── sft.json
    ├── dpo.json
    └── ...
```

**Smoke 配置的特征**：

```json
// configs/smoke/base.json
{
    "vocab_size": 50304,
    "context_length": 256,
    "n_embed": 128,      // 正式配置的 1/2
    "n_head": 4,         // 正式配置的 1 倍
    "n_blocks": 2,       // 正式配置的 1/3
    "device": "cpu",     // 不需要 GPU
    "amp_dtype": null    // 不需要混合精度
}
```

每个阶段的 Smoke 配置减少训练步数：

```json
// configs/smoke/sft.json（示例）
{
    "epochs": 1,          // 正式配置 3 epochs
    "eval_steps": 50,     // 正式配置 200
    "save_every": 100     // 正式配置 500
}
```

### 23.1.3 核心 Smoke Test 套件

[test_post_training_smoke.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/tests/test_post_training_smoke.py) 是项目的核心验证套件——**不训练、不加载数据集，在 CPU 上几秒钟跑完**，验证所有关键的数学逻辑。

```python
# 创建 tiny model 的工厂函数
def _tiny_model(vocab=64, ctx=32):
    torch.manual_seed(0)
    return Transformer(n_head=4, n_embed=32, context_length=ctx,
                       vocab_size=vocab, N_BLOCKS=2)
```

**测试清单**：

| 测试 | 验证内容 | 关键断言 |
|------|---------|---------|
| `test_forward_hidden_matches_forward` | `forward_hidden` 与 `forward` 一致 | logits 全等 |
| `test_compute_logprobs_matches_manual` | log 概率计算正确 | 与手动 `log_softmax + gather` 一致 |
| `test_rollout_logprobs_consistent` | 采样与重新计算的 logprobs 一致 | 记录的 logprobs ≈ 重新计算值 |
| `test_context_cap_enforced` | context_length 上限不被突破 | 序列长度 ≤ ctx |
| `test_value_and_reward_heads` | Value Head / Reward Head 形状正确 | 输出维度、梯度存在 |
| `test_frozen_copy_and_reductions` | 冻结副本 + masked 归约正确 | 所有参数 requires_grad=False |
| `test_chat_template_masking` | Chat template 的 mask 对齐 | assistant 部分 mask=1, user 部分 mask=0 |
| `test_reward_parsing` | 答案提取与验证逻辑 | GSM8K 格式解析正确 |
| `test_build_from_config` | 从 dataclass 构建模型 | 维度匹配 |

**运行方式**：

```bash
# 从仓库根目录运行
PYTHONPATH=. python tests/test_post_training_smoke.py

# 预期输出：
ok  forward_hidden matches forward
ok  compute_logprobs matches manual computation
ok  rollout/recompute log-probs consistent (40 response tokens)
ok  context_length cap enforced
ok  value head + reward head shapes and backprop
ok  frozen copy + masked_mean + gather_last
ok  chat template ids/mask aligned (12/30 trained tokens)
ok  reward parsing + verifier scoring
ok  build_model_from_config from dataclass

ALL SMOKE TESTS PASSED
```

### 23.1.4 测试设计哲学

```
Smoke Test 的设计原则：

1. 不依赖外部资源（不需要 GPU、不需要数据集）
2. 速度快（几秒完成，可以在每次代码修改后运行）
3. 聚焦关键数学（logprobs、mask 对齐、梯度流）
4. 独立可运行（每个 test_ 函数独立，不共享状态）
5. 失败信息明确（assert 消息描述期望行为）
```

### 23.1.5 数据与评估验证

[verify_data_and_eval.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/tests/verify_data_and_eval.py) 是更深层的验证——在真实数据上运行，验证数据准备和评估逻辑的正确性：

```python
def verify_pile():
    """验证预训练 HDF5 数据：非空、token 范围、EOT 分隔符"""
    with h5py.File(f"{DATA}/pile_train.h5", "r") as f:
        d = f["tokens"]
        check("nonempty", d.shape[0] > 1_000_000)
        check("token ids in [0,50256]", head.min() >= 0 and head.max() <= 50256)
        check("contains EOT separators", (head == EOT_ID).sum() > 0)

def verify_sft_mask_alignment():
    """核心 SFT 检查：loss_mask 只在 assistant 回复上为 1"""
    # 从 chat template 编码并验证 mask
    masked_text = decode([t for t, m in zip(ids, mask) if m == 1])
    unmasked_text = decode([t for t, m in zip(ids, mask) if m == 0])
    check("mask covers the assistant answer", "answer>4" in masked_text)
    check("mask excludes the user question", "2+2" in unmasked_text)

def verify_eval_benchmark():
    """独立验证 GSM8K 评分逻辑：正确答案得满分，错误答案不得分"""
    for ex in ds:
        gold = gsm8k_gold_answer(ex["answer"])
        good = f"<answer>{int(gold)}</answer>"
        bad = f"<answer>{gold + 7}</answer>"
        correct_when_right += int(is_correct(good, gold))
        correct_when_wrong += int(is_correct(bad, gold))
    check("perfect answers score correct", correct_when_right >= 98)
    check("wrong answers score incorrect", correct_when_wrong == 0)
```

### 23.1.6 验证层次

```
验证的三层体系：

Layer 1: Smoke Test（秒级）
  → test_post_training_smoke.py
  → 验证代码逻辑（数学、形状、梯度）
  → 每次代码修改后运行

Layer 2: Data Verification（分钟级）
  → verify_data_and_eval.py
  → 验证数据正确性（格式、mask 对齐、评分逻辑）
  → 每次数据准备后运行

Layer 3: Integration Smoke（分钟级）
  → Smoke 配置 + 真实训练脚本
  → 验证全流程能跑通（10-20 步）
  → 每次超参数调整后运行
```

## 23.2 一键全链路脚本设计

### 23.2.1 设计目标

[run_posttraining.sh](file:///Users/zhutingting/Documents/train-llm-from-scratch/scripts/run_posttraining.sh) 将整个后训练流程串联为一键执行：

```bash
# 使用 2 块 GPU（默认）
bash scripts/run_posttraining.sh

# 使用 1 块 GPU
NPROC=1 bash scripts/run_posttraining.sh
```

### 23.2.2 脚本解析

```bash
#!/usr/bin/env bash
set -euo pipefail    # 任何命令失败立即退出

cd "$(dirname "$0")/.."    # 切换到仓库根目录

# 环境变量
export PYTHONPATH=. HF_HOME=/ephemeral/hf_cache \
       PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

PY=/ephemeral/venv/bin/python
NPROC=${NPROC:-2}    # 默认 2 块 GPU
```

**通用的 `run` 函数**：

```bash
run() {
    if [ "$NPROC" -gt 1 ]; then
        /ephemeral/venv/bin/torchrun --standalone --nproc_per_node="$NPROC" "$@"
    else
        $PY "$@"
    fi
}
```

这个设计让单 GPU 和多 GPU 使用同一个函数——通过 `NPROC` 环境变量切换：

| NPROC | 实际命令 |
|-------|---------|
| 1 | `python scripts/train_sft.py` |
| 2 | `torchrun --standalone --nproc_per_node=2 scripts/train_sft.py` |

### 23.2.3 五阶段流水线

```bash
echo "############ 1/5  SFT ############"
run scripts/train_sft.py

echo "############ 2/5  Reward Model ############"
run scripts/train_reward.py

echo "############ 3/5  DPO ############"
run scripts/train_dpo.py --loss_type dpo

echo "############ 4/5  PPO (GSM8K, verifier reward) ############"
run scripts/train_ppo.py --reward_source verifier

echo "############ 5/5  GRPO (arithmetic curriculum -> GSM8K) ############"
run scripts/train_grpo.py
```

**阶段依赖关系**：

```
base_pretrained.pt  (预训练已完成)
       │
       ▼
  1. SFT ──────────→ sft.pt
       │                  │
       ▼                  ▼
  2. Reward ──→ reward.pt  3. DPO ──→ dpo.pt
       │                  │
       ▼                  ▼
  4. PPO ──→ ppo.pt     (使用 sft.pt 作为 policy 初始化)
       │
       ▼
  5. GRPO ──→ grpo.pt
```

每个阶段的脚本自动从默认路径读取上游 checkpoint——`SFTConfig.pretrained_ckpt` 指向 `/ephemeral/ckpts/base_pretrained.pt`，`DPOConfig.sft_ckpt` 指向 `/ephemeral/ckpts/sft.pt`。

### 23.2.4 跨阶段评估表

```bash
echo "############ Eval: GSM8K accuracy across stages ############"
TABLE=/ephemeral/logs/stage_table.jsonl
rm -f "$TABLE"
for s in base_pretrained sft dpo ppo grpo; do
    [ -f "/ephemeral/ckpts/$s.pt" ] && \
        $PY scripts/eval_post_training.py \
            --ckpt "/ephemeral/ckpts/$s.pt" --label "$s" \
            --limit 200 --append "$TABLE"
done
$PY scripts/eval_post_training.py --table "$TABLE"
```

**输出示例**：

```
stage              GSM8K acc       n
------------------------------------
base_pretrained        0.5%     200
sft                    8.5%     200
dpo                   11.0%     200
ppo                   12.5%     200
grpo                  15.0%     200
```

### 23.2.5 脚本设计原则

```
run_posttraining.sh 的设计原则：

1. 幂等性：重复运行不会破坏已有结果（覆盖 checkpoint）
2. 失败快速：set -euo pipefail 在第一步失败时立即停止
3. 灵活性：NPROC 环境变量控制 GPU 数量
4. 可观察性：每个阶段前打印分隔线
5. 完整性：最后自动生成跨阶段对比表
6. 简单性：50 行 shell 脚本，没有复杂的 if/else
```

### 23.2.6 前置条件

```
运行前的检查清单：

✓ base_pretrained.pt 存在（已完成预训练）
✓ 数据集已准备（pile_train.h5, sft_packed.h5, preferences.jsonl, rl_prompts_*.jsonl）
✓ Python 环境已安装依赖
✓ GPU 显存足够（2× H100 80GB 推荐）

快速验证前置条件：
  ls /ephemeral/ckpts/base_pretrained.pt
  ls /ephemeral/data/pile_train.h5 /ephemeral/data/sft_packed.h5
  ls /ephemeral/data/preferences.jsonl /ephemeral/data/rl_prompts_train.jsonl
  nvidia-smi
```

## 23.3 代码组织与可维护性

### 23.3.1 项目目录结构

```
train-llm-from-scratch/
├── config/                  # 配置系统
│   ├── config.py            # 原始预训练配置
│   ├── loader.py            # JSON 配置加载器（四层合并）
│   └── post_training_config.py  # 后训练配置 dataclass
│
├── configs/                 # JSON 配置文件
│   ├── base.json            # 共享模型配置
│   ├── sft.json             # SFT 超参数
│   ├── dpo.json / ppo.json / grpo.json / reward.json
│   └── smoke/               # Smoke 配置（tiny model）
│
├── src/                     # 核心代码
│   ├── models/              # 模型定义
│   │   ├── transformer.py   # 主 Transformer 类
│   │   ├── transformer_block.py
│   │   ├── attention.py
│   │   └── mlp.py
│   └── post_training/       # 后训练核心逻辑
│       ├── sft.py           # SFT 损失计算
│       ├── dpo.py           # DPO/ORPO/KTO 损失
│       ├── ppo.py           # PPO 算法
│       ├── grpo.py          # GRPO 算法
│       ├── reward_model.py  # Reward Model
│       ├── reward_train.py  # Reward 训练逻辑
│       ├── rollout.py       # Rollout 生成 + logprobs
│       ├── evaluation.py    # GSM8K 评估
│       ├── inference.py     # 模型加载 + 生成
│       ├── distributed.py   # DDP 管理
│       ├── optim.py         # 优化器 + 学习率调度
│       ├── utils.py         # 工具函数
│       ├── chat_template.py # 对话模板
│       ├── value_head.py    # PPO Value Head
│       └── rewards/         # 奖励函数
│           ├── parsing.py   # 答案提取
│           └── verifiers.py # GSM8K 验证器
│
├── scripts/                 # 训练脚本（入口）
│   ├── train_sft.py / train_dpo.py / train_ppo.py / train_grpo.py
│   ├── train_reward.py
│   ├── eval_post_training.py
│   ├── chat.py
│   ├── run_posttraining.sh  # 一键全链路
│   └── prepare_*.py         # 数据准备
│
├── data_loader/             # 数据加载
│   ├── sft_dataset.py
│   ├── preference_dataset.py
│   └── prompt_dataset.py
│
├── tests/                   # 测试套件
│   ├── test_post_training_smoke.py  # 核心 Smoke Test
│   ├── verify_data_and_eval.py      # 数据验证
│   └── ...
│
├── ui/                      # Streamlit 可视化控制台
│   ├── app.py / stages.py / theme.py / jobs.py
│   └── pages/
│
├── docs/                    # 文档（MkDocs + 理论说明）
├── images/                  # Mermaid 图表
├── configs/                 # 配置文件
├── pyproject.toml           # Python 包配置
└── requirements.txt         # 依赖
```

### 23.3.2 模块化设计原则

```
项目的模块化原则：

1. 单一职责
   - transformer.py 只负责模型结构
   - sft.py 只负责 SFT 损失计算
   - distributed.py 只负责 DDP 管理
   - 训练脚本（scripts/train_*.py）串联所有模块

2. 清晰的分层
   Layer 4: scripts/  → 入口脚本（CLI 参数、训练循环）
   Layer 3: src/post_training/ → 算法逻辑（损失函数、训练步骤）
   Layer 2: src/models/  → 模型定义（结构、前向传播）
   Layer 1: config/  → 配置系统（dataclass、JSON 加载）

3. 配置与代码分离
   - 所有超参数在 JSON 文件中
   - 代码不包含硬编码的 magic number
   - 四层配置合并：dataclass 默认值 → base.json → stage.json → CLI

4. 训练脚本轻量化
   - scripts/train_sft.py 只有 ~130 行
   - 核心逻辑委托给 src/post_training/sft.py
   - 训练脚本只负责：初始化 → 训练循环 → 保存 → 评估
```

### 23.3.3 配置系统设计

配置系统采用**四层合并**策略：

```
优先级（从低到高）：

1. dataclass 默认值       (config/post_training_config.py)
   ↓ 被覆盖
2. configs/base.json      (共享模型 + 运行时参数)
   ↓ 被覆盖
3. configs/sft.json       (该阶段的超参数)
   ↓ 被覆盖
4. CLI --field 参数       (最高优先级)
```

**合并实现**：

```python
def load_config(cfg_cls, json_path=None, overrides=None, *, base_path=None):
    base = _resolve_base(json_path, base_path)
    merged = {}
    for path in (base, json_path):
        if path and os.path.exists(path):
            with open(path) as fh:
                _deep_merge(merged, json.load(fh))
    # 过滤未知 key
    field_names = {f.name for f in fields(cfg_cls)}
    for key in list(merged):
        if key not in field_names:
            merged.pop(key)
    # CLI 覆盖
    if overrides:
        merged.update({k: v for k, v in overrides.items()
                       if k in field_names and v is not None})
    return cfg_cls(**merged)
```

### 23.3.4 包管理

[pyproject.toml](file:///Users/zhutingting/Documents/train-llm-from-scratch/pyproject.toml) 定义了项目的依赖和可选安装：

```toml
[project]
name = "train-llm-from-scratch"
version = "0.1.0"
requires-python = ">=3.9"
dependencies = [
    "torch", "numpy", "h5py", "tqdm",
    "tiktoken", "zstandard", "requests",
]

[project.optional-dependencies]
train = ["datasets", "wandb"]                    # 训练额外依赖
ui = ["streamlit", "pandas", "altair"]           # UI 依赖
docs = ["mkdocs", "mkdocs-material"]             # 文档依赖
all = ["datasets", "wandb", "streamlit", ...]    # 全部
```

**安装方式**：

```bash
# 最小安装（预训练 + 模型推理）
pip install -e .

# 安装训练依赖
pip install -e ".[train]"

# 安装全部
pip install -e ".[all]"
```

### 23.3.5 Checkpoint 设计

所有阶段的 checkpoint 遵循统一格式：

```python
# 保存 checkpoint
def save_stage_ckpt(model, cfg, path):
    raw = unwrap(model)    # 移除 DDP 包装
    torch.save({
        "model_state_dict": raw.state_dict(),
        "cfg": {            # 保存模型维度信息
            "vocab_size": cfg.vocab_size,
            "context_length": cfg.context_length,
            "n_embed": cfg.n_embed,
            "n_head": cfg.n_head,
            "n_blocks": cfg.n_blocks,
        },
    }, path)
```

**设计决策**：

| 决策 | 选择 | 原因 |
|------|------|------|
| 保存 cfg | 是 | 加载时无需手动指定模型维度 |
| unwrap DDP | 是 | 避免 `module.` 前缀污染 |
| strict load | 否 | 兼容不同阶段的额外 head（reward/value） |
| weights_only | False | 兼容旧版 PyTorch 和自定义对象 |

### 23.3.6 日志系统

训练指标以 JSONL 格式输出：

```jsonl
{"step": 1, "loss": 3.245, "lr": 0.00001, "wall": 1700000001.2}
{"step": 2, "loss": 3.198, "lr": 0.00002, "wall": 1700000003.5}
{"step": 3, "loss": 3.102, "lr": 0.00003, "wall": 1700000005.8}
```

**日志设计原则**：

```
日志文件命名：<prefix>_<timestamp>.jsonl
  - prefix 区分阶段（sft, dpo, ppo, grpo）
  - timestamp 避免覆盖历史日志
  - JSONL 格式支持流式读取（无需加载整个文件）

MetricsLogger 的使用：
  logger = MetricsLogger(cfg.log_dir, prefix="sft")
  for step in range(total_steps):
      loss = train_step()
      logger.log(step=step, loss=loss, lr=lr)
  # 自动写入 JSONL 文件
```

### 23.3.7 错误处理策略

```
项目的错误处理策略：

1. 配置错误 → 在 load_config 中警告未知 key，不终止
2. Checkpoint key 不匹配 → _strip_ddp_prefix 自动清理
3. 数据不存在 → 跳过该 split（estimate_loss 中的 continue）
4. 评估答案解析失败 → 三级回退（<answer> → #### → 末尾数字）
5. GPU 不可用 → 自动降级到 CPU（amp_autocast 返回 nullcontext）
6. 进程结束 → zombie 检测和回收（jobs.py 的 _alive）
```

## 23.4 项目回顾与全景总结

### 23.4.1 全书知识体系回顾

```
全书知识结构：

第一篇：基础（第 1-5 章）
  ├── 分词（Tokenization）
  ├── Transformer 架构
  ├── 注意力机制
  ├── 前馈网络
  └── 训练目标（语言模型）

第二篇：预训练（第 6-9 章）
  ├── 数据准备（The Pile → HDF5）
  ├── 训练循环（梯度累积 + bf16 + cosine LR）
  ├── 评估（train/dev loss）
  └── 生成（温度采样 + top-p）

第三篇：后训练基础（第 10-12 章）
  ├── SFT（Chat Template + loss mask）
  ├── Reward Model（Bradley-Terry + 排序损失）
  └── DPO（隐式奖励 + 参考模型）

第四篇：RL 对齐（第 13-16 章）
  ├── PPO（Actor-Critic + GAE + 裁剪）
  ├── GRPO（组相对优势 + 无 Critic）
  ├── 评估系统（GSM8K + 三级解析）
  └── 推理系统（Checkpoint 加载 + Chat 模式）

第五篇：工程实践（第 17-20 章）
  ├── 评估与基准测试
  ├── 推理与对话系统
  ├── 分布式训练与性能优化
  └── 常见陷阱与调试指南

第六篇：进阶与展望（第 21-23 章）
  ├── Scaling Laws
  ├── UI 可视化控制台
  └── 从项目到产品（本章）
```

### 23.4.2 关键设计决策回顾

| 决策 | 选择 | 替代方案 | 选择理由 |
|------|------|---------|---------|
| 框架 | 纯 PyTorch | HuggingFace Transformers | 教学透明，理解底层 |
| 分词器 | tiktoken (GPT-2) | SentencePiece | 简单稳定 |
| 分布式 | DDP | FSDP / DeepSpeed | 足够满足 <1B 模型 |
| 混合精度 | bf16 | fp16 + GradScaler | 不需要 GradScaler |
| 数据格式 | HDF5 | Parquet / JSONL | 随机访问快 |
| 配置 | JSON + dataclass | YAML / OmegaConf | 简单，Python 原生支持 |
| 评估 | GSM8K 贪心 | 多种采样 + 多数投票 | 确定性，速度快 |
| RL 奖励 | Verifier (GSM8K) | Reward Model | 无噪声，可验证 |

### 23.4.3 代码量统计

```
项目代码量（约）：

src/models/           ~400 行    模型定义
src/post_training/    ~2,500 行  后训练核心逻辑
scripts/              ~1,500 行  训练脚本 + 数据准备
data_loader/          ~200 行    数据加载
config/               ~300 行    配置系统
tests/                ~500 行    测试套件
ui/                   ~600 行    可视化控制台
docs/                 ~3,000 行  文档

总计：~9,000 行 Python + ~3,000 行文档
```

### 23.4.4 核心数据流

```
完整的数据流（从原始数据到最终评估）：

原始数据
  │
  ├── The Pile (JSONL.Zst)  ──→ pile_train.h5 ──→ pretrain ──→ base_pretrained.pt
  │
  ├── Alpaca + Dolly + GSM8K ──→ sft_packed.h5 ──→ SFT ──→ sft.pt
  │                                                     │
  ├── HH-RLHF + UltraFeedback ──→ preferences.jsonl ──┬→ Reward Model ──→ reward.pt
  │                                                    └→ DPO ──→ dpo.pt
  │
  └── GSM8K train ──→ rl_prompts_train.jsonl ──┬→ PPO ──→ ppo.pt
                                                └→ GRPO ──→ grpo.pt

评估：
  所有 .pt checkpoint ──→ eval_post_training.py ──→ stage_table.jsonl

推理：
  任意 .pt checkpoint ──→ chat.py ──→ 交互式对话
```

## 23.5 进一步探索方向

### 23.5.1 混合专家模型（Mixture of Experts）

```
MoE 的核心思想：

传统 Transformer：每个 token 经过所有参数
MoE Transformer：每个 token 只经过 Top-K 个"专家"

优势：
  ✓ 参数量可以很大（数百B）
  ✓ 每个 token 的计算量很小（只激活 K 个专家）
  ✓ GPT-4 和 Mixtral 都使用了 MoE

在本项目中的扩展方向：
  - 将 MLP 替换为 MoE 层
  - 每个 Block 有 N 个 MLP "专家" + 一个 Router
  - Router 选择 Top-2 个专家处理每个 token
  - 需要添加负载均衡损失（避免某些专家被忽略）
```

### 23.5.2 RLHF 新范式

```
当前的后训练方法正在快速演进：

1. Constitutional AI (Anthropic)
   - 模型自己生成偏好数据
   - 减少人工标注需求

2. RLAIF (RL from AI Feedback)
   - 用强大的模型（GPT-4）替代人类标注
   - 成本低、速度快

3. KTO (Kahneman-Tversky Optimization)
   - 不需要配对数据（chosen/rejected）
   - 只需要单独的好/坏样本

4. SPIN (Self-Play Fine-Tuning)
   - 模型与自己博弈
   - 无需外部奖励模型

5. GRPO 的进一步发展
   - 本项目已实现 GRPO
   - 可以添加 curriculum learning（已在 arithmetic warm-up 中体现）
   - 可以结合多个 verifier
```

### 23.5.3 多模态

```
从文本扩展到多模态：

1. Vision-Language Models (VLM)
   - 在 Transformer 前添加 Vision Encoder（ViT）
   - 图像 token + 文本 token 混合输入
   - LLaVA、GPT-4V 的方向

2. Audio Models
   - Whisper 式的语音识别
   - 音频 token 化后输入 Transformer

3. Video Models
   - 时序帧 + 文本描述
   - 需要处理超长序列（数百万 token）

在本项目中的扩展方向：
  - 添加一个 VisionEncoder 模块
  - 修改 Transformer 支持多模态 embedding
  - 训练数据加入图文对
```

### 23.5.4 长上下文

```
扩展 context_length 的方法：

当前项目：context_length = 256-1024
业界方向：128K - 1M+ tokens

技术方案：
  1. RoPE 外推（Rotary Position Embedding）
     - 将绝对位置编码替换为旋转位置编码
     - 支持在推理时处理更长的序列

  2. 稀疏注意力
     - 只计算局部 + 全局关键 token 的注意力
     - 将 O(n²) 降低到 O(n log n)

  3. 上下文压缩
     - 将旧的上下文压缩为少量 token
     - 保持关键信息，释放位置空间

  4. Ring Attention
     - 将长序列分布在多个 GPU 上
     - 每个 GPU 处理一段，通过通信合并
```

### 23.5.5 更高效的训练

```
训练效率的进一步优化：

1. Flash Attention 2/3
   - 本项目使用标准注意力（O(n²) 显存）
   - Flash Attention 将显存降到 O(n)，速度提升 2-4x

2. 梯度检查点（Activation Checkpointing）
   - 本项目已在 pretrain_base.py 中支持（--grad-checkpointing）
   - 用计算换显存：前向时不保存中间激活，反向时重新计算

3. ZeRO 优化
   - DeepSpeed ZeRO-3：将模型参数分布到多个 GPU
   - 支持训练更大的模型

4. 知识蒸馏
   - 用大模型（70B）生成训练数据
   - 小模型（7B）从这些数据中学习
   - 本项目可以用 350M 模型生成 SFT 数据，训练 40M 模型
```

### 23.5.6 评估体系的完善

```
超越 GSM8K 的评估：

1. 多样化基准
   - MMLU（知识推理）
   - HumanEval（代码生成）
   - TruthfulQA（事实准确性）
   - HellaSwag（常识推理）

2. 主观评估
   - LLM-as-Judge：用 GPT-4 评价生成质量
   - 人工评估：更可靠但更昂贵

3. 安全性评估
   - 有害内容检测
   - 偏见测试
   - 对抗性攻击测试

4. 项目内的扩展
   - 添加多个 benchmark 到 evaluation.py
   - 支持批量评估和结果可视化
   - 跨模型、跨阶段的对比矩阵
```

## 23.6 结语

### 23.6.1 你已经学到了什么

```
从零开始，你构建了一个完整的 LLM 后训练系统：

✓ 理解了 Transformer 的每一个组件
✓ 实现了预训练循环（bf16 + DDP + cosine LR）
✓ 构建了 Chat Template 和 SFT 损失
✓ 训练了 Reward Model（Bradley-Terry 偏好学习）
✓ 实现了 DPO 算法（无需 Reward Model 的对齐）
✓ 实现了 PPO 算法（Actor-Critic + GAE + 裁剪）
✓ 实现了 GRPO 算法（组相对优势 + 无 Critic）
✓ 构建了 GSM8K 评估系统
✓ 设计了交互式对话系统
✓ 理解了分布式训练的 All-Reduce 机制
✓ 掌握了常见陷阱的排查方法
✓ 构建了可视化控制台
```

### 23.6.2 这个项目在 LLM 生态中的位置

```
本项目与主流框架的对比：

                  本项目      HuggingFace TRL    DeepSpeed-Chat    OpenRLHF
代码量             ~9K 行      ~50K 行            ~30K 行           ~20K 行
依赖              纯 PyTorch   Transformers       DeepSpeed         Ray
教学友好度         ★★★★★       ★★★☆☆             ★★☆☆☆             ★★★☆☆
生产就绪度         ★★☆☆☆       ★★★★★             ★★★★★             ★★★★☆
支持的算法         SFT/RM/DPO/PPO/GRPO  全部      SFT/RM/PPO       SFT/RM/DPO/PPO/GRPO
模型规模           <1B          任意               任意              任意
分布式             DDP          DDP/FSDP/DeepSpeed DeepSpeed ZeRO    Ray
```

**本项目的独特价值**：

1. **零黑盒**：每一行代码都可以追溯到论文中的公式
2. **完整链路**：从数据准备到评估，不跳过任何步骤
3. **可验证**：Smoke Test 验证核心逻辑，不需要昂贵硬件
4. **可演进**：清晰的模块化设计，容易扩展新功能

### 23.6.3 下一步行动

```
推荐的后续学习路径：

短期（1-2 周）：
  □ 在自己的数据上运行全流程
  □ 调整超参数，观察效果变化
  □ 添加新的评估基准

中期（1-3 月）：
  □ 阅读 HuggingFace TRL 源码，对比实现差异
  □ 实现 Flash Attention 或 RoPE
  □ 尝试更大规模的模型（1B+）

长期（3-6 月）：
  □ 探索 MoE 或 RLAIF
  □ 在真实应用场景中部署模型
  □ 贡献开源社区（提 PR 到 TRL 或 vLLM）
```

---

## 本章小结

### Smoke Test 要点

```
三层验证体系：
  Layer 1: test_post_training_smoke.py → 代码逻辑（秒级）
  Layer 2: verify_data_and_eval.py    → 数据正确性（分钟级）
  Layer 3: Smoke 配置 + 真实脚本      → 全流程可运行（分钟级）

原则：
  ✓ 每次代码修改后运行 Layer 1
  ✓ 每次数据准备后运行 Layer 2
  ✓ 每次超参数调整后运行 Layer 3
```

### 全链路脚本要点

```
run_posttraining.sh 设计：
  ✓ 50 行 shell 脚本串联 5 个阶段
  ✓ run() 函数统一处理单/多 GPU
  ✓ set -euo pipefail 确保失败快速退出
  ✓ 自动生成跨阶段对比表
```

### 代码组织要点

```
模块化设计：
  config/    → 配置系统（四层合并）
  src/models/ → 模型定义（结构、前向传播）
  src/post_training/ → 算法逻辑（损失函数、训练步骤）
  scripts/   → 入口脚本（CLI 参数、训练循环）
  tests/     → 测试套件（Smoke Test + 数据验证）
  ui/        → 可视化控制台（Streamlit）
```

### 进一步探索

```
主要方向：
  MoE → 混合专家模型（稀疏激活）
  RLAIF → AI 反馈的 RLHF
  多模态 → 视觉 + 语言
  长上下文 → RoPE + 稀疏注意力
  高效训练 → Flash Attention + ZeRO
  评估 → 多样化基准 + LLM-as-Judge
```

---

## 练习

**练习 1：添加新的 Smoke Test**

为 `DPOConfig` 添加一个 Smoke Test，验证 DPO 损失在 chosen/rejected 相同（退化情况）时的行为：

```python
def test_dpo_loss_degenerate():
    """当 chosen == rejected 时，DPO loss 应该接近 log(sigmoid(0)) = -log(2)"""
    # 实现提示：使用 dpo_loss 函数，传入相同的 logits
    pass
```

**练习 2：扩展全链路脚本**

修改 `run_posttraining.sh`，添加一个 `--smoke` 参数：

```bash
# 用法：
bash scripts/run_posttraining.sh --smoke   # 使用 Smoke 配置
bash scripts/run_posttraining.sh           # 使用正式配置
```

**练习 3：添加新的评估基准**

在 `evaluation.py` 中添加 MMLU 或 HumanEval 评估函数，并在 `eval_post_training.py` 中支持 `--benchmark mmlu` 参数。

**练习 4：实现知识蒸馏**

设计一个蒸馏流程：
1. 用 350M 模型生成 SFT 数据
2. 用这些数据训练 40M 模型
3. 对比直接训练 vs 蒸馏的 GSM8K 准确率
