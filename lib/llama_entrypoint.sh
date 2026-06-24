# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|

#!/bin/sh

# This is a helper script for the llama.cpp server container

if [ -z "$SIA_LOCAL_MODEL" ]; then
    echo 'ERROR: No model configured. Run ./sia llama run'
    exit 1
fi

echo 'Starting llama-server...'

if [ -n "$SIA_LOCAL_MODEL" ]; then
    echo "Loading local model: $SIA_LOCAL_MODEL"
    exec /llama-server \
        -m "$SIA_LOCAL_MODEL" \
        --host 0.0.0.0 \
        --port 8080 \
        -c "${LLAMACPP_CTX_SIZE:-8192}" \
        -ngl "${LLAMACPP_N_GL:-999}" \
        -cb \
        -t "${LLAMACPP_THREADS:-8}"
else
    echo 'Loading from Hugging Face...'
    exec /llama-server \
        $SIA_HF_ARGS \
        --host 0.0.0.0 \
        --port 8080 \
        -c "${LLAMACPP_CTX_SIZE:-8192}" \
        -ngl "${LLAMACPP_N_GL:-999}" \
        -cb \
        -t "${LLAMACPP_THREADS:-8}"
fi
