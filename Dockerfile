FROM nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04 AS builder

# Install Python, git and other build tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-venv \
    python3-dev \
    git \
    build-essential

# Create python venv
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip / setuptools / wheel
RUN pip install --upgrade pip setuptools wheel packaging triton

# Install PyTorch for CUDA 12.9
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu129

# Install SageAttention
RUN git clone https://github.com/thu-ml/SageAttention.git
WORKDIR /SageAttention
RUN python setup.py install

FROM nvidia/cuda:12.9.1-cudnn-runtime-ubuntu24.04

ARG COMFYUI_VERSION=0.9.2

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-venv \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Copy the venv from builder
COPY --from=builder /opt/venv /opt/venv

# Configure python venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip list

# Copy the built wheel from builder stage
COPY --from=builder /SageAttention/dist/*.whl /SageAttention/

# Install SageAttention wheel
RUN pip install /SageAttention/*.whl

# Install comfy-cli
RUN pip install comfy-cli

# Install ComfyUI
RUN comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --cuda-version 12.9 --nvidia;

# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Install Python runtime dependencies for the handler
RUN pip install runpod requests websocket-client

# Copy helper script to switch Manager network mode at container start
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

# Add script to install custom nodes
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

# Prevent pip from asking for confirmation during uninstall steps in custom nodes
ENV PIP_NO_INPUT=1

# install custom nodes using comfy-cli
RUN comfy-node-install comfyui-kjnodes comfyui-videohelpersuite ComfyUI-WanVideoWrapper

# Add application code and scripts
ADD src/start.sh src/network_volume.py handler.py ./
RUN chmod +x /start.sh

# Set the default command to run when starting the container
CMD ["/start.sh"]

