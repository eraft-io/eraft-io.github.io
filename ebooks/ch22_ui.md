# 第 22 章：UI 可视化控制台

> **本章目标**：理解 Streamlit 多页面应用的架构设计，掌握每个训练阶段的可视化面板实现，实现实时 Loss 监控与模型对话功能。

## 22.0 本章路线图

前面所有章节都用命令行脚本完成训练和评估。本章引入一个 **Streamlit 可视化控制台**——把所有阶段（数据准备、预训练、SFT、Reward、DPO、PPO、GRPO、评估、对话）统一到一个 Web 界面中。

```
本章覆盖的内容

UI 可视化控制台
├── Streamlit 多页面应用架构
├── 核心模块解析（stages / theme / jobs / metrics）
├── 训练阶段页面设计
├── 数据准备页面
├── 评估页面
├── 对话页面
└── 启动与使用
```

## 22.1 为什么需要 UI

### 22.1.1 命令行的局限

命令行是训练 LLM 的基础，但在以下场景中不够直观：

```
命令行的问题：

1. 无法实时查看 Loss 曲线（只能看终端输出的数字）
2. 切换阶段需要记住不同的脚本名和参数
3. 评估和对话需要分开运行多个命令
4. 没有统一的地方看到全流程的进度
5. 对非技术用户不友好
```

### 22.1.2 UI 的目标

```
UI 控制台的设计目标：

✓ 一站式：数据准备 → 训练 → 评估 → 对话，一个 Web 页面搞定
✓ 实时可视化：Loss 曲线、GPU 状态、训练日志实时更新
✓ 可配置：直接在界面上修改超参数，无需编辑 JSON 文件
✓ 安全：GPU 忙碌时防止重复启动，支持停止正在运行的任务
✓ 与命令行兼容：UI 启动的脚本与命令行完全一致
```

## 22.2 Streamlit 多页面应用架构

### 22.2.1 目录结构

```
ui/
├── app.py              # 首页（控制面板）
├── __init__.py
├── stages.py           # 阶段注册表（单一真相源）
├── theme.py            # 主题和样式
├── jobs.py             # 后台任务管理器
├── metrics.py          # 日志读取和解析
├── config_forms.py     # 配置表单生成器
├── docs_render.py      # 理论文档渲染器
├── stage_page.py       # 训练阶段通用页面
└── pages/
    ├── 1_Data.py       # 数据准备
    ├── 2_Pretrain.py   # 预训练
    ├── 3_SFT.py        # 监督微调
    ├── 4_Reward_Model.py
    ├── 5_DPO.py
    ├── 6_PPO.py
    ├── 7_GRPO.py
    ├── 8_Evaluate.py   # GSM8K 评估
    └── 9_Chat.py       # 交互式对话
```

### 22.2.2 Streamlit 的多页面机制

Streamlit 天然支持多页面应用——`pages/` 目录下的每个 `.py` 文件自动成为侧边栏的一个页面：

```
app.py              →  首页（侧边栏显示为 "Control Panel"）
pages/1_Data.py     →  "Data" 页面
pages/2_Pretrain.py →  "Pretrain" 页面
pages/3_SFT.py      →  "SFT" 页面
...
pages/9_Chat.py     →  "Chat" 页面

Streamlit 自动按文件名排序，数字前缀控制页面顺序
```

### 22.2.3 启动方式

```bash
# 启动 UI（默认端口 8501）
streamlit run ui/app.py

# 指定端口
streamlit run ui/app.py --server.port 8888

# 远程访问
streamlit run ui/app.py --server.address 0.0.0.0
```

启动后浏览器自动打开 `http://localhost:8501`，侧边栏列出所有页面。

## 22.3 核心模块解析

### 22.3.1 stages.py：阶段注册表

整个 UI 的核心是 [Stage](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/stages.py) 数据类——每个训练阶段的所有元信息集中在一处：

```python
@dataclass(frozen=True)
class Stage:
    key: str                 # 短标识（"sft"）
    title: str               # 显示名（"Supervised Fine-Tuning"）
    emoji: str               # 图标（🎯）
    cfg_cls: type            # 配置 dataclass（SFTConfig）
    config_json: str         # 正式配置 JSON 路径
    smoke_json: str          # Smoke 配置 JSON 路径
    script: str              # 训练脚本路径
    log_prefix: str          # JSONL 日志前缀
    doc_md: str              # 理论文档路径
    diagram_png: str         # 架构图路径
    multi_gpu: bool          # 是否支持多 GPU（torchrun）
```

所有阶段的注册：

```python
STAGES = {
    "pretrain": Stage("pretrain", "Pretraining", "📚", PretrainConfig,
                      "configs/pretrain.json", "configs/smoke/pretrain.json",
                      "scripts/pretrain_base.py", "pretrain",
                      "docs/02_pretraining.md", "docs/diagrams/02_pretraining.png", True),
    "sft":      Stage("sft", "Supervised Fine-Tuning", "🎯", SFTConfig, ...),
    "reward":   Stage("reward", "Reward Model", "🏅", RewardConfig, ...),
    "dpo":      Stage("dpo", "DPO / ORPO / KTO", "⚖️", DPOConfig, ...),
    "ppo":      Stage("ppo", "PPO (RLHF)", "🎮", PPOConfig, ...),
    "grpo":     Stage("grpo", "GRPO / RLVR", "🧠", GRPOConfig, ...),
}
```

**设计原则**：单一真相源（Single Source of Truth）——所有页面的表单、脚本、日志前缀都从这里读取，避免信息分散在不同文件中。

### 22.3.2 theme.py：主题和样式

[theme.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/theme.py) 统一了 UI 的视觉风格：

```python
# 配色方案（与手绘图一致）
COLORS = {
    "data": "#27ae60",    # 绿色 — 数据
    "proc": "#2c6fbb",    # 蓝色 — 处理过程
    "store": "#16a085",   # 青色 — 存储
    "model": "#d48806",   # 金色 — 模型
    "rl": "#e67e22",      # 橙色 — RL
    "loss": "#c0392b",    # 红色 — Loss
    "eval": "#8e44ad",    # 紫色 — 评估
    "ckpt": "#888888",    # 灰色 — Checkpoint
}
```

核心功能：

```python
# 页面初始化（设置标题、注入 CSS）
def setup_page(title: str, icon: str = "🧠") -> None:
    st.set_page_config(page_title=f"{title} · Train LLM From Scratch",
                       page_icon=icon, layout="wide")
    st.markdown(_CSS, unsafe_allow_html=True)

# Hero 横幅（渐变色标题区）
def hero(title: str, subtitle: str) -> None:
    st.markdown(f'<div class="hero"><h1>{title}</h1>'
                f'<p>{subtitle}</p></div>', unsafe_allow_html=True)

# 状态徽章（running / finished / failed / idle）
def status_badge(status: str) -> str:
    cls, label = _BADGE.get(status, ("b-idle", status))
    return f'<span class="badge {cls}">{label}</span>'

# GPU 状态检测（通过 nvidia-smi）
def gpu_status():
    # 返回 [(idx, name, used_mb, total_mb, util), ...]
```

CSS 自定义样式包括：
- **Hero 横幅**：渐变色背景 + 白色文字 + 圆角
- **Stage 卡片**：左侧彩色边框 + 浅灰背景
- **状态徽章**：圆形彩色标签（running=金色 / finished=绿色 / failed=红色）

### 22.3.3 jobs.py：后台任务管理器

[jobs.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/jobs.py) 是最复杂的模块——负责启动、监控、停止后台训练任务。

**核心设计**：

```
任务生命周期：

1. launch()   → 启动 detached subprocess → 写入 JSON 注册文件
2. status()   → 检查 PID 是否存活 → 扫描日志尾部判断成功/失败
3. stop()     → 向 process group 发送 SIGTERM → 更新注册文件
4. tail_log() → 读取日志文件的最后 N 字节
```

**任务注册文件**：

```json
// /ephemeral/ui_jobs/sft.json
{
    "job_id": "sft",
    "pid": 12345,
    "cmd": ["python", "scripts/train_sft.py", "--config", "configs/sft.json"],
    "log": "/ephemeral/ui_jobs/sft.log",
    "kind": "gpu",
    "started": 1700000000.0,
    "status": "running"
}
```

**GPU 忙碌保护**：

```python
def gpu_busy() -> str | None:
    """返回正在运行的 GPU 任务的 job_id（防止重复启动）"""
    for fn in os.listdir(JOB_DIR):
        if fn.endswith(".json"):
            rec = read_registry(fn[:-5])
            if rec and rec.get("kind") == "gpu" and _alive(rec["pid"]):
                return rec["job_id"]
    return None
```

**进程存活检测**（处理 zombie 进程）：

```python
def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)    # 信号 0 只检测进程是否存在
    except OSError:
        return False
    # 检查 /proc/<pid>/stat 判断是否为 zombie
    try:
        with open(f"/proc/{pid}/stat") as f:
            state = f.read().rsplit(") ", 1)[1].split(" ", 1)[0]
        if state == "Z":
            os.waitpid(pid, os.WNOHANG)  # 回收 zombie
            return False
    except (FileNotFoundError, IndexError):
        return False
    return True
```

**启动命令构建**：

```python
def build_argv(script, config_json, nproc, multi_gpu, extra=None):
    base = [script, "--config", config_json] + (extra or [])
    if multi_gpu and nproc > 1:
        return [_TORCHRUN, "--standalone", f"--nproc_per_node={nproc}", *base]
    return [sys.executable, *base]
```

### 22.3.4 metrics.py：日志读取

[metrics.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/metrics.py) 负责从 JSONL 日志文件中读取训练指标：

```python
def latest_log(prefix: str) -> str | None:
    """找到最新的日志文件（按修改时间排序）"""
    files = glob.glob(os.path.join(LOG_DIR, f"{prefix}_*.jsonl"))
    return max(files, key=os.path.getmtime) if files else None

def load_metrics(path: str):
    """逐行解析 JSONL 为 DataFrame"""
    rows = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return pd.DataFrame(rows)

def metric_columns(df) -> list[str]:
    """过滤出值得绘图的数值列（排除 step、wall 等）"""
    skip = {"step", "wall"}
    return [c for c in df.columns if c not in skip and df[c].dtype.kind in "fi"]
```

## 22.4 训练阶段页面设计

### 22.4.1 通用页面模板

所有训练阶段页面共享同一个渲染器 [stage_page.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/stage_page.py)：

```python
# 每个阶段页面只需 3 行代码：
# pages/3_SFT.py
from ui.stage_page import render_stage_page
render_stage_page("sft")
```

`render_stage_page` 的核心结构：

```python
def render_stage_page(stage_key: str) -> None:
    stage = STAGES[stage_key]
    theme.setup_page(stage.title, stage.emoji)
    theme.hero(f"{stage.emoji}  {stage.title}", ...)

    # 两个 Tab：🚀 Run（运行）和 📖 Theory（理论）
    tab_run, tab_theory = st.tabs(["🚀 Run", "📖 Theory"])

    with tab_theory:
        render_doc(st, stage.doc_md, stage.diagram_png)  # 渲染理论文档

    with tab_run:
        # 1. Smoke 模式开关 + GPU 数量选择
        smoke = st.toggle("Smoke mode (tiny model, few steps, CPU)")
        nproc = st.slider("GPUs (torchrun)", 1, max_gpu, ...)

        # 2. 配置表单（可编辑超参数）
        render_form(stage, smoke=smoke, nproc=nproc)

        # 3. 启动/停止按钮（含 GPU 忙碌保护）
        cols = st.columns(3)
        cols[0].button("▶️ Launch")   # 启动训练
        cols[1].button("⏹️ Stop")     # 停止训练
        cols[2].toggle("Auto-refresh") # 自动刷新（每 3 秒）

        # 4. 实时日志（显示最后 12KB 的输出）
        st.code(jobs.tail_log(stage.key, 12000))

        # 5. 指标图表（Loss 曲线等）
        df = metrics.load_metrics(log)
        st.line_chart(df.set_index("step")[cols_to_plot])
```

### 22.4.2 页面布局详解

```
训练阶段页面布局：

┌──────────────────────────────────────────────────┐
│  🎯 Supervised Fine-Tuning                       │  ← Hero 横幅
│  Configure, launch, and monitor the SFT stage.   │
├──────────────────────────────────────────────────┤
│  Job status: [running]                            │  ← 状态徽章
├──────────────────────────────────────────────────┤
│  [ 🚀 Run ] [ 📖 Theory ]                        │  ← Tab 切换
├──────────────────────────────────────────────────┤
│                                                  │
│  ☐ Smoke mode    GPUs: [━━━●━━] 2                │  ← 运行模式
│                                                  │
│  Configuration                                   │
│  ├─ 🧱 Model & runtime (base.json)               │  ← 可折叠表单
│  │   ├─ vocab_size: [50304]                      │
│  │   ├─ context_length: [256]                    │
│  │   ├─ n_embed: [256]                           │
│  │   └─ ...                                      │
│  └─ ⚙️ SFT hyperparameters (sft.json)            │
│      ├─ pretrained_ckpt: [/ephemeral/ckpts/...]  │
│      ├─ lr: [1e-5]                               │
│      ├─ epochs: [3]                              │
│      └─ ...                                      │
│                                                  │
│  Resolved launch command:                        │  ← 显示实际命令
│  python scripts/train_sft.py --config ...        │
│                                                  │
│  [▶️ Launch] [⏹️ Stop] [Auto-refresh]            │  ← 控制按钮
│                                                  │
│  Live log                                        │
│  ┌────────────────────────────────────────────┐  │
│  │ step=100 loss=2.34 lr=1.0e-05 ...          │  │  ← 实时日志
│  │ step=101 loss=2.31 lr=1.0e-05 ...          │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Metrics                                         │
│  ┌────────────────────────────────────────────┐  │
│  │     Loss 曲线图                             │  │  ← 指标图表
│  │  ╱‾‾‾‾‾‾‾╲                                 │  │
│  │ ╱          ╲                                │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

### 22.4.3 配置表单生成器

[config_forms.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/config_forms.py) 自动从 dataclass 字段生成表单：

```python
def render_form(stage: Stage, smoke: bool, nproc: int) -> None:
    # 加载当前配置
    cur = load_config(stage.cfg_cls, json_path)

    # 基础字段（来自 BaseModelConfig）→ 折叠面板
    with st.expander("🧱 Model & runtime  ·  shared base.json"):
        for f in base_fields:
            vals[f.name] = _widget(f, getattr(cur, f.name))

    # 阶段特有字段 → 展开面板
    with st.expander(f"⚙️ {stage.title} hyperparameters"):
        for f in stage_fields:
            vals[f.name] = _widget(f, getattr(cur, f.name))

    # 保存按钮 → 写回两个 JSON 文件
    if st.button("💾 Save config"):
        _write_json(base_path, base_vals)
        _write_json(json_path, stage_vals)
```

**自动 widget 生成**：

```python
def _widget(f, value):
    """根据 dataclass 字段类型自动选择 Streamlit widget"""
    t = str(f.type)
    if t == "bool":
        return st.checkbox(f.name, bool(value))       # 布尔 → 复选框
    if "int" in t:
        return int(st.number_input(f.name, value=int(value)))  # 整数 → 数字输入
    if "float" in t:
        return float(st.number_input(f.name, value=float(value)))  # 浮点 → 数字输入
    return st.text_input(f.name, str(value))  # 字符串 → 文本框
```

**保存逻辑**：基础字段写入 `base.json`，阶段字段写入 `<stage>.json`——与配置加载器的分层模型完全一致。

### 22.4.4 理论文档渲染

[docs_render.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/docs_render.py) 在 Streamlit 中渲染 Markdown 文档：

```python
def render_doc(st, doc_md: str, diagram_png: str) -> None:
    # 先显示架构图（st.image 可以加载本地图片）
    st.image(ABS_DOC(diagram_png))

    # 再渲染 Markdown（需要清理）
    with open(ABS_DOC(doc_md)) as f:
        st.markdown(_clean_markdown(f.read()))
```

**Markdown 清理**：

```python
def _clean_markdown(text: str) -> str:
    # 1. 移除图片链接（已用 st.image 显示）
    text = re.sub(r"^!\[[^\]]*\]\([^)]*\)\s*$", "", text, flags=re.MULTILINE)
    # 2. 移除 <details> mermaid 代码块
    text = re.sub(r"<details>.*?</details>", "", text, flags=re.DOTALL)
    # 3. 移除顶部 H1 标题（页面已有标题）
    text = re.sub(r"^#\s+.*$", "", text, count=1, flags=re.MULTILINE)
    return text.strip()
```

## 22.5 数据准备页面

### 22.5.1 页面设计

[1_Data.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/pages/1_Data.py) 提供了一个集中的数据准备入口：

```python
# 数据准备脚本注册
DATA_SCRIPTS = {
    "Pretrain corpus (Pile → HDF5)":
        ["scripts/prepare_pretrain_data.py", "--split", "train", ...],
    "Pretrain dev (Pile val)":
        ["scripts/prepare_pretrain_data.py", "--split", "val", ...],
    "SFT (Alpaca · Dolly · GSM8K)":
        ["scripts/prepare_sft_data.py"],
    "Preferences (HH-RLHF · UltraFeedback)":
        ["scripts/prepare_preference_data.py", "--source", "both"],
    "RL prompts (GSM8K + arithmetic)":
        ["scripts/prepare_rl_prompts.py"],
}
```

### 22.5.2 页面功能

```
数据准备页面：

┌──────────────────────────────────────────────┐
│  📦 Data preparation                         │
├──────────────────────────────────────────────┤
│                                              │
│  Pretrain corpus (Pile → HDF5)  [running]    │
│  scripts/prepare_pretrain_data.py ...        │
│  [Prepare]                                   │  ← 一键启动
│                                              │
│  SFT (Alpaca · Dolly · GSM8K)  [finished]   │
│  scripts/prepare_sft_data.py                 │
│  [Prepare]                                   │
│                                              │
│  Preferences (HH-RLHF · UltraFeedback) [idle]│
│  scripts/prepare_preference_data.py ...      │
│  [Prepare]                                   │
│                                              │
│  Live log                                    │
│  ┌──────────────────────────────────────┐    │
│  │ Downloading pile train...            │    │  ← 实时日志
│  │ [████████░░░░] 67%                   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Files in /ephemeral/data                    │
│  ┌──────────────────────────────────────┐    │
│  │ pile_train.h5      1.2 GB            │    │  ← 文件列表
│  │ pile_dev.h5        45 MB             │    │
│  │ sft_packed.h5      23 MB             │    │
│  └──────────────────────────────────────┘    │
└──────────────────────────────────────────────┘
```

### 22.5.3 与命令行的等价

| UI 操作 | 等价命令行 |
|---------|-----------|
| 点击 Pretrain corpus 的 Prepare | `python scripts/prepare_pretrain_data.py --split train` |
| 点击 SFT 的 Prepare | `python scripts/prepare_sft_data.py` |
| 查看 /ephemeral/data | `ls -la /ephemeral/data/` |

## 22.6 评估页面

### 22.6.1 页面设计

[8_Evaluate.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/pages/8_Evaluate.py) 提供 GSM8K 评估的图形界面：

```python
# 选择 checkpoint
ckpt = st.selectbox("Checkpoint", sorted(glob.glob("/ephemeral/ckpts/*.pt")))

# 配置评估参数
limit = st.slider("Num questions", 5, 200, 20)
max_new = st.slider("Max new tokens", 64, 400, 256)
device = st.selectbox("Device", ["cuda", "cpu"])

# 运行评估
if st.button("▶️ Run GSM8K eval"):
    model = load_model_from_ckpt(ckpt, device)
    qa = load_gsm8k_eval("test", limit=limit)
    res = gsm8k_accuracy(model, qa, device=device, max_new_tokens=max_new,
                         greedy=True, return_samples=min(5, limit))

# 显示结果
st.metric("GSM8K accuracy", f"{res['accuracy']*100:.1f}%",
          f"{res['correct']}/{res['n']} correct")

# 展示样例
for s in res["samples"]:
    with st.expander(("✅ " if s["correct"] else "❌ ") + s["q"][:90]):
        st.code(s["response"][:1200])
```

### 22.6.2 页面功能

```
评估页面：

┌──────────────────────────────────────────────┐
│  📊 Evaluate on GSM8K                        │
├──────────────────────────────────────────────┤
│                                              │
│  Checkpoint: [sft.pt ▼]                      │
│  Num questions: [20]   Max tokens: [256]     │
│  Device: [cuda ▼]                            │
│                                              │
│  [▶️ Run GSM8K eval]                         │
│                                              │
│  GSM8K accuracy: 8.5%  (17/200 correct)     │
│                                              │
│  Sample generations                          │
│  ├─ ✅ Janet's ducks lay 16 eggs...          │
│  │   Gold: 35 · Correct: True                │
│  │   <think>16*3=48, 48-15=33, 33+2=35</think>... │
│  └─ ❌ James has 3 more teeth...             │
│      Gold: 36 · Correct: False               │
│      <think>24+3=27...</think> (wrong answer)          │
└──────────────────────────────────────────────┘
```

## 22.7 对话页面

### 22.7.1 页面设计

[9_Chat.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/pages/9_Chat.py) 实现了完整的交互式对话界面：

```python
# 侧边栏：生成参数
with st.sidebar:
    ckpt = st.selectbox("Checkpoint", ckpts, index=len(ckpts) - 1)
    device = st.selectbox("Device", ["cuda", "cpu"])
    raw = st.toggle("Raw mode (base continuation, no chat template)")
    greedy = st.toggle("Greedy (deterministic)")
    temperature = st.slider("Temperature", 0.1, 1.5, 0.8)
    top_p = st.slider("top-p", 0.1, 1.0, 0.95)
    max_new = st.slider("Max new tokens", 16, 512, 256)
    system = st.text_input("System prompt", "")

# 加载模型（缓存，避免每次对话都重新加载）
@st.cache_resource(show_spinner="Loading checkpoint …")
def _load(path, dev):
    from src.post_training.inference import load_model_from_ckpt
    return load_model_from_ckpt(path, dev)

model = _load(ckpt, device)

# 对话历史（session state 持久化）
st.session_state.setdefault("chat_msgs", [])
for m in st.session_state["chat_msgs"]:
    st.chat_message(m["role"]).markdown(m["content"])

# 用户输入 → 模型生成
prompt = st.chat_input("Ask something")
if prompt:
    st.session_state["chat_msgs"].append({"role": "user", "content": prompt})
    st.chat_message("user").markdown(prompt)
    with st.chat_message("assistant"), st.spinner("Generating …"):
        reply = generate_reply(model, prompt, device=device,
                               system=system or None, raw=raw,
                               max_new_tokens=max_new,
                               temperature=temperature, top_p=top_p)
        st.markdown(reply)
    st.session_state["chat_msgs"].append({"role": "assistant", "content": reply})
```

### 22.7.2 关键设计

**模型缓存**：使用 `@st.cache_resource` 确保模型只加载一次——切换 checkpoint 才会重新加载：

```python
@st.cache_resource(show_spinner="Loading checkpoint …")
def _load(path, dev):
    return load_model_from_ckpt(path, dev)
```

**对话历史**：存储在 `st.session_state["chat_msgs"]` 中，页面刷新后保留。"Clear history" 按钮清空历史。

**双模式**：
- Chat 模式：使用 chat template（`<|system|>`, `<|user|>`, `<|assistant|>`）
- Raw 模式：直接续写（适用于 base model）

### 22.7.3 页面功能

```
对话页面：

┌──────────────────────────────────────────────┐
│  💬 Chat                                     │
├──────────────────────────────────────────────┤
│                                              │
│  用户: What is 13 + 29?                      │
│                                              │
│  助手: <think>To add 13 and 29, I can           │
│  break it down: 13 + 20 + 9 = 33 + 9 =      │
│  42.</think><answer>42</answer>                   │
│                                              │
│  [Ask something...] [Send]                   │  ← 聊天输入框
├──────────────────────────────────────────────┤
│  Sidebar:                                    │
│  Checkpoint: [grpo.pt ▼]                     │
│  ☐ Raw mode   ☐ Greedy                       │
│  Temperature: [0.80]                         │
│  top-p: [0.95]                               │
│  Max new tokens: [256]                       │
│  System prompt: [You are a math tutor]       │
│  [🗑️ Clear history]                          │
└──────────────────────────────────────────────┘
```

## 22.8 控制面板首页

### 22.8.1 页面布局

[app.py](file:///Users/zhutingting/Documents/train-llm-from-scratch/ui/app.py) 是 UI 的首页——提供全局概览：

```python
# 显示总览图
overview = ABS_DOC("docs/diagrams/00_overview.png")
if os.path.exists(overview):
    st.image(overview, use_container_width=True)

# GPU 状态面板
gpus = theme.gpu_status()
for col, (i, name, used, total, util) in zip(cols, gpus):
    col.metric(f"GPU {i} · {name.split(' ')[-1]}",
               f"{used/1024:.0f}/{total/1024:.0f} GB", f"{util}% util")

# 任务状态面板
for rec in active:
    s = jobs.status(rec["job_id"])
    st.markdown(f'<div class="stage-card">'
                f'<b>{rec["job_id"]}</b> &nbsp; {theme.status_badge(s)} '
                f'&nbsp; <code>{" ".join(rec["cmd"][:3])} …</code></div>',
                unsafe_allow_html=True)

# 流水线状态面板
for key, sgt in STAGES.items():
    s = jobs.status(key)
    st.markdown(f'<div class="stage-card">'
                f'{sgt.emoji} <b>{sgt.title}</b> &nbsp; {theme.status_badge(s)}'
                f' &nbsp; <span>{sgt.script}</span></div>',
                unsafe_allow_html=True)
```

### 22.8.2 首页功能

```
控制面板首页：

┌──────────────────────────────────────────────┐
│  🧠 Train LLM From Scratch — Control Panel   │
│  Pretrain → SFT → Reward → DPO → PPO → GRPO │
├──────────────────────────────────────────────┤
│                                              │
│  [总览流程图]                                 │  ← 00_overview.png
│                                              │
│  🖥️ GPUs                                     │
│  ┌──────────┐ ┌──────────┐                   │
│  │ GPU 0    │ │ GPU 1    │                   │  ← 显存和使用率
│  │ 12/80 GB │ │ 8/80 GB  │                   │
│  │ 45% util │ │ 30% util │                   │
│  └──────────┘ └──────────┘                   │
│                                              │
│  📋 Jobs                                     │
│  sft  [running]  python scripts/train_sft.py │  ← 活跃任务
│                                              │
│  🗺️ Pipeline                                 │
│  📚 Pretraining      [finished]              │
│  🎯 SFT              [running]               │  ← 各阶段状态
│  🏅 Reward Model     [idle]                  │
│  ⚖️ DPO / ORPO / KTO [idle]                  │
│  🎮 PPO (RLHF)       [idle]                  │
│  🧠 GRPO / RLVR      [idle]                  │
└──────────────────────────────────────────────┘
```

## 22.9 自动刷新与实时更新

### 22.9.1 Streamlit 的刷新机制

Streamlit 的运行模型是**脚本式**——每次交互都从头执行整个脚本。要实现"实时更新"，需要：

```python
# 自动刷新：sleep + rerun
if auto:
    import time
    time.sleep(3)       # 等待 3 秒
    st.rerun()          # 触发页面重新渲染
```

### 22.9.2 日志尾部读取

`tail_log` 只读取日志文件的最后 N 字节，避免大文件拖慢刷新：

```python
def tail_log(job_id: str, max_bytes: int = 16000) -> str:
    p = _log(job_id)
    with open(p, "rb") as f:
        f.seek(0, os.SEEK_END)
        size = f.tell()
        f.seek(max(0, size - max_bytes))  # 从尾部往回跳
        return f.read().decode("utf-8", errors="replace")
```

### 22.9.3 指标图表更新

指标图表从 JSONL 文件实时读取：

```python
# 每次刷新时重新读取最新的日志文件
log = metrics.latest_log(stage.log_prefix)
if log:
    df = metrics.load_metrics(log)           # 解析所有行
    cols_to_plot = metrics.metric_columns(df) # 找出数值列
    st.line_chart(df.set_index("step")[cols_to_plot])  # 绘制
```

## 22.10 UI 与命令行的关系

### 22.10.1 完全等价

UI 启动的训练任务与命令行完全一致：

```
UI 操作 → 后台执行的命令

点击 SFT 的 Launch → python scripts/train_sft.py --config configs/sft.json
选择 2 GPUs → torchrun --standalone --nproc_per_node=2 scripts/train_sft.py ...
选择 Smoke → python scripts/train_sft.py --config configs/smoke/sft.json
```

### 22.10.2 互补而非替代

```
UI 的优势：
  ✓ 可视化 Loss 曲线
  ✓ 一键切换阶段
  ✓ 实时 GPU 状态
  ✓ 交互式对话
  ✓ 数据准备集中管理

命令行的优势：
  ✓ 可脚本化（cron、CI/CD）
  ✓ 资源占用更低
  ✓ 更细粒度的控制
  ✓ 适合远程 SSH
  ✓ 可 pipe 和 redirect

最佳实践：
  开发/调试 → 用 UI
  生产训练 → 用命令行
  快速验证 → 用 UI 的 Smoke 模式
```

## 22.11 本章小结

### 架构要点

```
Streamlit 多页面应用：
  app.py          → 首页（控制面板）
  pages/N_*.py    → 侧边栏页面（自动注册）
  
核心模块：
  stages.py       → 阶段注册表（单一真相源）
  theme.py        → 主题样式（CSS + GPU 状态 + 徽章）
  jobs.py         → 后台任务管理（启动/停止/监控/GPU 保护）
  metrics.py      → JSONL 日志读取（最新文件 + DataFrame）
  config_forms.py → 配置表单（dataclass → widget 自动生成）
  stage_page.py   → 训练阶段通用渲染器（3 行代码 = 一个页面）
  docs_render.py  → 理论文档渲染（Markdown 清理 + 图片注入）
```

### 页面总览

| 页面 | 功能 | 核心组件 |
|------|------|---------|
| Home | 全局概览 | GPU 状态 + 任务列表 + 流水线图 |
| Data | 数据准备 | 5 个一键 Prepare + 文件列表 |
| Pretrain-SFT-Reward-DPO-PPO-GRPO | 训练阶段 | 配置表单 + Launch/Stop + 日志 + 指标 |
| Evaluate | GSM8K 评估 | 准确率 + 样例展示 |
| Chat | 交互式对话 | 聊天框 + 模型缓存 + 对话历史 |

### 关键设计模式

1. **单一真相源**：所有阶段的元信息集中在 `stages.py`
2. **通用渲染器**：6 个训练阶段共享 `stage_page.py`，每个页面只需 3 行代码
3. **GPU 保护**：防止同时启动两个 GPU 任务导致 OOM
4. **模型缓存**：`@st.cache_resource` 避免重复加载
5. **配置分层**：`base.json` + `<stage>.json` → 表单中分两个折叠面板

---

## 练习

**练习 1：添加新页面**

为 `Evaluation` 添加一个 `pages/0_Home.py`（排在 Data 之前），显示项目说明和快速链接。

**练习 2：自定义指标**

修改 `metrics.py` 的 `metric_columns`，添加对字符串列的过滤（如 `lr` 字段虽然是数值但不适合绘图）。

**练习 3：添加对比功能**

在评估页面添加"多 checkpoint 对比"功能——选择多个 checkpoint，在同一个表格中展示 GSM8K 准确率。

**练习 4：改进自动刷新**

当前自动刷新使用 `time.sleep(3)` 阻塞线程。研究 Streamlit 的 `st.autorefresh` 或 WebSocket 方案，实现非阻塞刷新。
