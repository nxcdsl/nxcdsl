#!/bin/bash
# 把任意 HuggingFace 上的 SD / SDXL 模型转成 Core ML（需要一台 Mac）
#
# 用法：
#   ./convert_model.sh "Lykon/dreamshaper-xl-v2-turbo" 1024
#
# 产物在 output/ 下，压缩后直接丢进 iPhone 的「文件 → 灵绘 → Models」文件夹即可。
#
# 前提：macOS 13+，Python 3.10 左右，约 30GB 空闲磁盘。

set -euo pipefail

MODEL="${1:-Lykon/dreamshaper-xl-v2-turbo}"
RES="${2:-1024}"
WORK="$(pwd)/_convert"

mkdir -p "$WORK" && cd "$WORK"

if [ ! -d ml-stable-diffusion ]; then
  git clone --depth 1 https://github.com/apple/ml-stable-diffusion
fi

python3 -m venv venv
source venv/bin/activate
python -m pip install -U pip
pip install -r ml-stable-diffusion/requirements.txt
pip install -U "huggingface_hub[cli]" torch

echo "==> 正在转换 $MODEL @ ${RES}px（大约 20-40 分钟）"

python -m python_coreml_stable_diffusion.torch2coreml \
  --model-version "$MODEL" \
  --convert-unet \
  --convert-text-encoder \
  --convert-vae-decoder \
  --model-precision float16 \
  --compute-unit ALL \
  --attention-implementation SPLIT_EINSUM \
  --latent-h "$((RES / 8))" --latent-w "$((RES / 8))" \
  --o "$(pwd)/output" \
  --bundle-resources-for-swift-cli

# 打成一个压缩包，方便 AirDrop 到手机
cd output
zip -qry "../$(basename "$MODEL")-coreml.zip" .
echo "==> 完成：$(pwd)/../$(basename "$MODEL")-coreml.zip"

# 想更小更快就加 --quantize-nbits 6（6bit 调色板量化，体积约减 60%）
