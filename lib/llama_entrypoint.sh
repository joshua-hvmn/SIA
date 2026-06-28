#!/bin/sh
# SIA llama.cpp entrypoint - POSIX compatible
# SPDX-License-Identifier: MIT
# This is a helper script for the llama.cpp server container

set -e

echo 'Starting llama-server...'

if [ -n "$SIA_LOCAL_MODEL" ]; then
    echo "Loading local model: $SIA_LOCAL_MODEL"
    LCCP_TARGET_MODEL="$SIA_LOCAL_MODEL"
elif [ -n "$SIA_HF_ARGS" ]; then
    echo 'Loading from Hugging Face...'
    LCCP_TARGET_MODEL="$SIA_HF_ARGS"
else
    echo 'ERROR: No model configured. Run ./sia llama run'
    exit 1
fi

exec /app/llama-server \
    $LCCP_TARGET_MODEL \
    --host 0.0.0.0 \
    --port 8080 \
    -c "${LLAMACPP_CTX_SIZE:-8192}" \
    -ngl "${LLAMACPP_N_GL:-24}" \
    -t "${LLAMACPP_THREADS:-8}" \
    -np "${LLAMACPP_PARALLEL:-1}" \
    --cache-type-k "${LLAMACPP_CACHE_K:-q8_0}" \
    --cache-type-v "${LLAMACPP_CACHE_V:-q8_0}" \
    -b "${LLAMACPP_BATCH_SIZE:-512}" \
    \
    --flash-attn on \
    --no-mmap \
    ${SIA_LLAMA_CPP_EXTRA_ARGS} # --alias "${LLAMACPP_ALIAS:-Qwen3.6-35B}" \
