#!/usr/bin/env bash

# Download loras defined by COMFY_LORAS environment variable
# Expected format: COMFY_LORAS="https://huggingface.co/... https://civitai.com/..."
if [ -n "$COMFY_LORAS" ]; then
    for url in $COMFY_LORAS; do
        [ -z "$url" ] && continue

        echo "Downloading from $url ..."

        if ! comfy model download \
            --relative-path models/loras \
            --url "$url"; then
            echo "ERROR: Failed to download from $url" >&2
            exit 1
        fi

        echo "Downloaded successfully from $url"
    done
fi

#Download common models for Wan2.2 workflows
comfy model download --relative-path models/diffusion_models --filename Wan2_2-I2V-A14B-HIGH_fp8_e4m3fn_scaled_KJ.safetensors --url  "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/I2V/Wan2_2-I2V-A14B-HIGH_fp8_e4m3fn_scaled_KJ.safetensors"
comfy model download --relative-path models/diffusion_models --filename Wan2_2-I2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors --url "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/I2V/Wan2_2-I2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors"
comfy model download --relative-path models/vae --filename wan_2.1_vae.safetensors --url "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
comfy model download --relative-path models/clip --filename umt5_xxl_fp8_e4m3fn_scaled.safetensors --url "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
comfy model download --relative-path models/loras --filename Wan_2_2_I2V_A14B_HIGH_lightx2v_MoE_distill_lora_rank_64_bf16.safetensors --url "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22_Lightx2v/Wan_2_2_I2V_A14B_HIGH_lightx2v_MoE_distill_lora_rank_64_bf16.safetensors"
comfy model download --relative-path models/loras --filename wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors --url "https://huggingface.co/lightx2v/Wan2.2-Distill-Loras/resolve/main/wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors"
comfy model download --relative-path models/loras --filename SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors --url "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors"
comfy model download --relative-path models/loras --filename SVI_v2_PRO_Wan2.2-I2V-A14B_LOW_lora_rank_128_fp16.safetensors --url "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_LOW_lora_rank_128_fp16.safetensors"

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

echo "worker-comfyui: Starting ComfyUI"

# Ensure ComfyUI-Manager runs in offline network mode inside the container
comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

# Allow operators to tweak verbosity; default is INFO.
: "${COMFY_LOG_LEVEL:=INFO}"
: "${COMFY_OUTPUT_DIR:=output}"

python -u comfyui/main.py \
    --use-sage-attention \
    --disable-auto-launch \
    --disable-metadata \
    --output-directory "${COMFY_OUTPUT_DIR}" \
    --verbose "${COMFY_LOG_LEVEL}" \
    --log-stdout &

echo "worker-comfyui: Starting RunPod Handler"
python -u handler.py