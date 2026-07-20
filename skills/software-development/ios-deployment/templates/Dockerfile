FROM swift:6.3-jammy

# System dependencies for xtool + iOS development
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    git \
    curl \
    wget \
    unzip \
    libssl-dev \
    pkg-config \
    libxml2 \
    libcurl4-openssl-dev \
    zip \
    liblzma-dev \
    zlib1g-dev \
    usbmuxd \
    libimobiledevice-utils \
    socat \
    vim \
    less \
    file \
    && rm -rf /var/lib/apt/lists/*

# Install xtool — extract AppImage since FUSE isn't available in Docker
ENV APPIMAGE_EXTRACT_AND_RUN=1
RUN curl -fL \
    "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" \
    -o /tmp/xtool.AppImage \
    && chmod +x /tmp/xtool.AppImage \
    && /tmp/xtool.AppImage --appimage-extract \
    && mv squashfs-root /opt/xtool \
    && ln -s /opt/xtool/AppRun /usr/local/bin/xtool \
    && rm /tmp/xtool.AppImage

WORKDIR /workspace

# Verify installations
RUN swift --version && xtool --help

CMD ["/bin/bash"]