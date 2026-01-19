#
# Compilation Stage
#
FROM nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04 AS builder

# Install git and other tools
RUN apt update && apt install -y \
    curl \
    git

# Install uv python manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Create python venv
RUN uv venv --python 3.12 --relocatable
ENV VIRTUAL_ENV=/.venv

# Upgrade and install build tools
RUN uv pip install --upgrade pip setuptools wheel packaging triton

# Install PyTorch for CUDA 12.9
RUN uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu129

# Clone SageAttention
RUN git clone https://github.com/thu-ml/SageAttention.git
WORKDIR /SageAttention

# Configure GPU support
ENV TORCH_CUDA_ARCH_LIST="8.9;8.6"

# Speed and memory optimization
ENV EXT_PARALLEL=4 NVCC_APPEND_FLAGS="--threads 8" MAX_JOBS=32

# Install SageAttention
RUN uv run --active setup.py install

#
# Application Stage
#
FROM nvidia/cuda:12.9.1-cudnn-runtime-ubuntu24.04

# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Persistent Triton kernels
ENV TRITON_HOME=/runpod-volume

# Install git and other tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv python manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Install python
RUN uv python install 3.12

WORKDIR /app

# Configure python venv
COPY --from=builder /.venv /app/.venv
ENV VIRTUAL_ENV=/app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# Install Comfy CLI and python dependencies
RUN uv pip install comfy-cli runpod requests websocket-client

# Clean up to reduce image size
RUN uv cache clean

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /app/comfyui install --version 0.9.2 --cuda-version 12.9 --nvidia;

# Support for the network volume
COPY src/extra_model_paths.yaml /app/comfyui/

# Copy helper script to switch Comfy Manager network mode at container start
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

# Add script to install custom nodes
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

# Install custom nodes using comfy-cli
RUN comfy-node-install comfyui-kjnodes comfyui-videohelpersuite ComfyUI-WanVideoWrapper

# Add application code and scripts
ADD src/start.sh src/network_volume.py src/handler.py /app/
RUN chmod +x /app/start.sh

# Set the default command to run when starting the container
CMD ["./start.sh"]

# ENTRYPOINT ["tail"]
# CMD ["-f","/dev/null"]

