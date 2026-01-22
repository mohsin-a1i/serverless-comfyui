#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

echo "worker-comfyui: Starting ComfyUI"

# Ensure ComfyUI-Manager runs in offline network mode inside the container
comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

# Allow operators to tweak verbosity; default is INFO.
: "${COMFY_LOG_LEVEL:=INFO}"
: "${COMFY_OUTPUT_DIR:=output}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    python -u comfyui/main.py --listen \
        --use-sage-attention \
        --disable-auto-launch \
        --disable-metadata \
        --output-directory "${COMFY_OUTPUT_DIR}" \
        --verbose "${COMFY_LOG_LEVEL}" \
        --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    python -u comfyui/main.py \
        --use-sage-attention \
        --disable-auto-launch \
        --disable-metadata \
        --output-directory "${COMFY_OUTPUT_DIR}" \
        --verbose "${COMFY_LOG_LEVEL}" \
        --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u handler.py
fi