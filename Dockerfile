FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git build-essential libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 ffmpeg && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv python manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Configure python environment
COPY backend/dependencies/sageattention-2.2.0-cp312-cp312-linux_x86_64.whl .
RUN uv venv --python 3.12 && \
    uv pip install --upgrade pip && \
    uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 && \
    uv pip install triton && \
    uv pip install sageattention-2.2.0-cp312-cp312-linux_x86_64.whl --no-deps && \
    uv pip install comfy-cli && \
    uv cache clean
ENV VIRTUAL_ENV=/.venv
ENV PATH="/.venv/bin:$PATH"

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace comfyui install --version 0.9.2 --skip-torch-or-directml --nvidia && \
comfy node install comfyui-kjnodes rgthree-comfy
COPY backend/workflows/ comfyui/user/default/workflows/

COPY backend/start.sh start.sh
RUN chmod +x start.sh

EXPOSE 8188

CMD ["./start.sh"]