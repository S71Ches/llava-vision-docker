# ------------------------------------------------------------
# 0) Базовый образ NVIDIA CUDA 12.2 (developer)
# ------------------------------------------------------------
FROM nvidia/cuda:12.2.0-devel-ubuntu22.04

# ------------------------------------------------------------
# 1) Аргументы и переменные окружения
# ------------------------------------------------------------
ARG PORT=8000
ARG WORKERS=1
ENV PORT=${PORT} \
    WORKERS=${WORKERS}

# ------------------------------------------------------------
# 2) Настройка APT: HTTPS-репозитории + universe
# ------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      apt-transport-https \
      ca-certificates \
      software-properties-common && \
    sed -i \
      -e 's|http://archive.ubuntu.com/ubuntu|https://archive.ubuntu.com/ubuntu|g' \
      -e 's|http://security.ubuntu.com/ubuntu|https://security.ubuntu.com/ubuntu|g' \
      /etc/apt/sources.list && \
    add-apt-repository universe && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# 3) Системные зависимости + ccache + Python + symlink для stub-CUDA
# ------------------------------------------------------------
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential \
      git \
      cmake \
      ninja-build \
      wget \
      curl \
      unzip \
      python3 \
      python3-pip \
      python3-dev \
      libopenblas-dev \
      libssl-dev \
      zlib1g-dev \
      libcurl4-openssl-dev \
      ccache && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m pip install --upgrade pip setuptools wheel && \
    ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/lib/x86_64-linux-gnu/libcuda.so.1

# ------------------------------------------------------------
# 4) Установка cloudflared для Cloudflare Tunnel
# ------------------------------------------------------------
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && \
    mv cloudflared-linux-amd64 /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# ------------------------------------------------------------
# 5) Клонируем llama-cpp-python (с Vision API support) и собираем с CUDA
# ------------------------------------------------------------
RUN git clone --recurse-submodules \
      https://github.com/abetlen/llama-cpp-python.git \
      /app/llama-cpp-python

WORKDIR /app/llama-cpp-python

ENV CMAKE_ARGS="-DGGML_CUDA=ON \
    -DGGML_CCACHE=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES=80;86 \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_TOOLS=OFF \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DCMAKE_SHARED_LINKER_FLAGS=-lcuda" \
    CMAKE_BUILD_PARALLEL_LEVEL=4 \
    MAKEFLAGS="-j4" \
    FORCE_CMAKE=1

RUN pip3 install .[server] pillow python-multipart --no-cache-dir --verbose

# ------------------------------------------------------------
# 6) Копируем server.py и entrypoint.sh, настраиваем запуск
# ------------------------------------------------------------
WORKDIR /app
COPY server.py entrypoint.sh ./
RUN chmod +x entrypoint.sh

# ------------------------------------------------------------
# 7) Папка для модели (монтируется volume в RunPod)
# ------------------------------------------------------------
RUN mkdir -p /models

# ------------------------------------------------------------
# 8) Открываем порт и задаём точку входа
# ------------------------------------------------------------
EXPOSE ${PORT}
ENTRYPOINT ["./entrypoint.sh"]
