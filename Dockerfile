#
# Compilation Stage
#
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS builder

# Speed and memory optimization
ENV EXT_PARALLEL=4 NVCC_APPEND_FLAGS="--threads 8" MAX_JOBS=32

# Configure GPU support
ENV TORCH_CUDA_ARCH_LIST="8.9;8.6;8.0"

RUN set -eux; \
    apt update && \
    apt install -y --no-install-recommends \
      curl \
      git && \
    rm -rf /var/lib/apt/lists/* && \
    \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    export PATH="/root/.local/bin:$PATH" &&
    \
    uv venv --python 3.12 --relocatable && \
    uv pip install --upgrade pip setuptools wheel packaging triton && \
    uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 && \
    \
    git clone https://github.com/thu-ml/SageAttention.git && \
    cd SageAttention && \
    uv run --active setup.py install

#
# Application Stage
#
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Configure python venv
ENV VIRTUAL_ENV=/app/.venv
ENV PATH="/app/.venv/bin:$PATH"

COPY --from=builder /.venv /app/.venv

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* && \
    \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    export PATH="/root/.local/bin:$PATH" && \
    \
    uv python install 3.12 && \
    uv pip install comfy-cli runpod requests websocket-client && \
    uv cache clean

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /app/comfyui install --version 0.9.2 --skip-torch-or-directml --nvidia;

# Support for the network volume
COPY backend/comfyui/extra_model_paths.yaml /app/comfyui/

# Add script to install custom nodes
COPY backend/scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

# Copy helper script to switch Comfy Manager network mode at container start
COPY backend/scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

# Add application code and scripts
COPY backend/start.sh backend/network_volume.py backend/handler.py /app/
RUN chmod +x /app/start.sh

# Install custom nodes using comfy-cli
RUN comfy-node-install comfyui-kjnodes rgthree-comfy

# Download Wan video generation models
RUN set -eux; \
    mkdir -p models/{diffusion_models,vae,clip,loras} && \
    curl -fL --retry 3 -o models/diffusion_models/Wan2_2-I2V-A14B-HIGH_SVI_consistent_face_nsfw_fp8.safetensors "https://civitai.com/api/download/models/2609141?type=Model&format=SafeTensor&size=full&fp=fp8" & \
    curl -fL --retry 3 -o models/diffusion_models/Wan2_2-I2V-A14B-LOW_SVI_consistent_face_nsfw_fp8.safetensors "https://civitai.com/api/download/models/2609148?type=Model&format=SafeTensor&size=full&fp=fp8" & \
    curl -fL --retry 3 -o models/vae/wan_2.1_vae.safetensors "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" & \
    curl -fL --retry 3 -o models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" & \
    curl -fL --retry 3 -o models/loras/Wan_2_2_I2V_A14B_HIGH_lightx2v_MoE_distill_lora_rank_64_bf16.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22_Lightx2v/Wan_2_2_I2V_A14B_HIGH_lightx2v_MoE_distill_lora_rank_64_bf16.safetensors" & \
    curl -fL --retry 3 -o models/loras/wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors "https://civitai.com/api/download/models/2337903?type=Model&format=SafeTensor" & \
    curl -fL --retry 3 -o models/loras/SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors" & \
    curl -fL --retry 3 -o models/loras/SVI_v2_PRO_Wan2.2-I2V-A14B_LOW_lora_rank_128_fp16.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_LOW_lora_rank_128_fp16.safetensors" & \
    wait

# Set the default command to run when starting the container
CMD ["./start.sh"]

# ENTRYPOINT ["tail"]
# CMD ["-f","/dev/null"]

