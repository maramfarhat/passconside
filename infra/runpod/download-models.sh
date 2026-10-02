#!/usr/bin/env bash
set -euo pipefail
source /workspace/pass-ai/config/env.sh
source /workspace/pass-ai/venv/bin/activate

mkdir -p /workspace/models

echo "=== Already on disk ==="
ls -la /workspace/models || true

if [ ! -e "/workspace/huggingface/hub/models--Qwen--Qwen3-Coder-Next-FP8" ]; then
  echo "Downloading Qwen3-Coder-Next-FP8..."
  hf download Qwen/Qwen3-Coder-Next-FP8
else
  echo "Qwen3-Coder-Next-FP8 cache present."
fi

if [ ! -d "/workspace/models/Qwen2.5-Coder-32B-Instruct" ]; then
  echo "Downloading Qwen2.5-Coder-32B-Instruct (dense 32B)..."
  hf download Qwen/Qwen2.5-Coder-32B-Instruct \
    --local-dir /workspace/models/Qwen2.5-Coder-32B-Instruct
else
  echo "Qwen2.5-Coder-32B-Instruct already present."
fi

if [ ! -e "/workspace/huggingface/hub/models--Qwen--Qwen3-Coder-30B-A3B-Instruct" ]; then
  echo "Downloading Qwen3-Coder-30B-A3B-Instruct (recommended Cline agent)..."
  hf download Qwen/Qwen3-Coder-30B-A3B-Instruct
else
  echo "Qwen3-Coder-30B-A3B-Instruct cache present."
fi

if [ "x${PASS_AI_DOWNLOAD_VL:-0}" = "x1" ]; then
  if [ ! -e "/workspace/huggingface/hub/models--Qwen--Qwen3-VL-30B-A3B-Instruct-FP8" ]; then
    echo "Downloading Qwen3-VL-30B-A3B-Instruct-FP8 (optional vision)..."
    hf download Qwen/Qwen3-VL-30B-A3B-Instruct-FP8
  else
    echo "Qwen3-VL-30B-A3B-Instruct-FP8 cache present."
  fi
fi

if [ "x${PASS_AI_DOWNLOAD_GLM_FLASH:-0}" = "x1" ]; then
  echo "WARNING: GLM-4.7-Flash is not recommended on Blackwell until SGLang fixes land."
  hf download zai-org/GLM-4.7-Flash || true
fi

echo "Done. Catalog: /workspace/pass-ai/config/models.catalog.json"
