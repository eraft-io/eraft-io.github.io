#!/bin/bash
set -e

# ============================================================
# vLLM 一键部署脚本（Ubuntu + NVIDIA A10）
# ============================================================

# ---------- 配置区（按需修改） ----------
MODEL_ID="Qwen/Qwen2.5-7B-Instruct"
MODEL_DIR="./models/Qwen2.5-7B-Instruct"
VENV_DIR=".venv"
PYTHON_VERSION="3.12"
CUDA_VERSION="12-1"
VLLM_HOST="0.0.0.0"
VLLM_PORT=8000
GPU_MEM_UTIL=0.9
MAX_MODEL_LEN=8192
MAX_NUM_SEQS=16

# ---------- 颜色输出 ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---------- 1. 系统依赖 ----------
info "安装系统依赖..."
sudo apt update
sudo apt install -y build-essential python3-pip python3-dev git wget curl

# ---------- 2. NVIDIA 驱动 ----------
if command -v nvidia-smi &> /dev/null; then
    info "NVIDIA 驱动已安装，跳过。"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
else
    info "安装 NVIDIA 驱动（535 系列）..."
    sudo apt install -y nvidia-driver-535
    info "驱动安装完成，需要重启后生效。"
    warn "请执行 sudo reboot，重启后重新运行本脚本。"
    exit 0
fi

# ---------- 3. CUDA Toolkit ----------
if command -v nvcc &> /dev/null; then
    info "CUDA 已安装，跳过。"
    nvcc --version
else
    info "安装 CUDA ${CUDA_VERSION}..."
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt update
    sudo apt install -y "cuda-${CUDA_VERSION}"
    rm -f cuda-keyring_1.1-1_all.deb

    # 写入环境变量
    CUDA_PATH="/usr/local/cuda-${CUDA_VERSION}"
    if ! grep -q "cuda-${CUDA_VERSION}" ~/.bashrc; then
        echo "export PATH=${CUDA_PATH}/bin:\$PATH" >> ~/.bashrc
        echo "export LD_LIBRARY_PATH=${CUDA_PATH}/lib64:\$LD_LIBRARY_PATH" >> ~/.bashrc
    fi
    export PATH="${CUDA_PATH}/bin:$PATH"
    export LD_LIBRARY_PATH="${CUDA_PATH}/lib64:$LD_LIBRARY_PATH"
    info "CUDA 安装完成。"
fi

# ---------- 4. 安装 uv 并配置清华源 ----------
if command -v uv &> /dev/null; then
    info "uv 已安装，跳过。"
else
    info "安装 uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# 配置清华源
mkdir -p ~/.config/uv
cat > ~/.config/uv/uv.toml << 'EOF'

[[index]]
url = "https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple/"
default = true
EOF
info "清华源已配置。"

# ---------- 5. 创建虚拟环境并安装 vLLM ----------
if [ ! -d "${VENV_DIR}" ]; then
    info "创建 Python ${PYTHON_VERSION} 虚拟环境..."
    uv venv --python "${PYTHON_VERSION}" --seed "${VENV_DIR}"
fi

source "${VENV_DIR}/bin/activate"
info "虚拟环境已激活：$(which python)"

if python -c "import vllm" 2>/dev/null; then
    info "vLLM 已安装，跳过。"
else
    info "安装 vLLM（这可能需要几分钟）..."
    uv pip install vllm
fi

# 验证 GPU 可用
python -c "
import torch
assert torch.cuda.is_available(), 'CUDA 不可用，请检查驱动和 CUDA 安装'
print(f'GPU: {torch.cuda.get_device_name(0)}')
print(f'显存: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB')
" || error "GPU 检测失败，请检查驱动和 CUDA 安装。"

# ---------- 6. 使用 ModelScope 下载模型 ----------
if [ -d "${MODEL_DIR}" ] && [ "$(ls -A ${MODEL_DIR})" ]; then
    info "模型目录已存在：${MODEL_DIR}，跳过下载。"
else
    info "安装 ModelScope CLI..."
    uv pip install modelscope

    info "从 ModelScope 下载模型：${MODEL_ID} ..."
    modelscope download --model "${MODEL_ID}" --local_dir "${MODEL_DIR}"
    info "模型下载完成：${MODEL_DIR}"
fi

# ---------- 7. 启动 vLLM 服务 ----------
info "启动 vLLM 服务..."
echo "============================================================"
echo "  模型路径:   ${MODEL_DIR}"
echo "  监听地址:   ${VLLM_HOST}:${VLLM_PORT}"
echo "  显存利用率: ${GPU_MEM_UTIL}"
echo "  最大长度:   ${MAX_MODEL_LEN}"
echo "  最大并发:   ${MAX_NUM_SEQS}"
echo "============================================================"

python -m vllm.entrypoints.openai.api_server \
  --model "${MODEL_DIR}" \
  --host "${VLLM_HOST}" \
  --port "${VLLM_PORT}" \
  --dtype float16 \
  --gpu-memory-utilization "${GPU_MEM_UTIL}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-seqs "${MAX_NUM_SEQS}" \
  --enforce-eager