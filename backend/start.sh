#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Download loras defined by COMFY_LORAS environment variable
# Expected format: COMFY_LORAS="https://huggingface.co/... https://civitai.com/..."
if [ -z "$COMFY_LORAS" ]; then
    for url in $COMFY_LORAS; do
        [ -z "$url" ] && continue

        echo "Downloading from $url ..."

        comfy model download \
            --relative-path models/loras \
            --url "$url"

        if [ $? -ne 0 ]; then
            echo "Failed to download from $url"
        else
            echo "Downloaded successfully from $url"
        fi
    done
fi

python comfyui/main.py --listen --use-sage-attention