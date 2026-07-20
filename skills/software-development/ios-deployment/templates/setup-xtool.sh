#!/usr/bin/env bash
# One-time setup for an xtool dev container.
# Run inside the container:
#   docker compose run --rm swift-dev bash /workspace/scripts/setup-xtool.sh
#
# Prerequisites:
#   - Xcode.xip downloaded from https://developer.apple.com/download/all/?q=Xcode
#     and copied into the xcode-xip named volume (or bind-mounted at /root/xcode-xip)
#
# This script:
# 1. Installs the Darwin Swift SDK from Xcode.xip
# 2. Authenticates with Apple Developer Services (interactive — needs Apple ID)
# 3. Verifies the setup with `xtool dev build`
#
# After this completes once, the SDK + auth persist in named volumes
# and every subsequent `xtool dev build` works without setup.
set -euo pipefail

echo "=== xtool Dev Container Setup ==="

# 1. Find Xcode.xip
XIP_PATH=""
for candidate in /root/xcode-xip/*.xip /root/xcode-xip/Xcode*.xip; do
    if [ -f "$candidate" ]; then
        XIP_PATH="$candidate"
        break
    fi
done

if [ -z "$XIP_PATH" ]; then
    echo "ERROR: No Xcode.xip found in /root/xcode-xip/"
    echo "Download Xcode 26 from https://developer.apple.com/download/all/?q=Xcode"
    echo "Then: docker compose run --rm -v /path/to/xcode-dir:/root/xcode-xip:ro swift-dev bash /workspace/scripts/setup-xtool.sh"
    exit 1
fi

echo "Found: $XIP_PATH"

# 2. Install Darwin Swift SDK
echo "=== Installing Darwin Swift SDK (several minutes) ==="
xtool sdk install "$XIP_PATH"
swift sdk list

# 3. Authenticate
echo "=== Apple Developer Services Login ==="
echo "API Key (paid Developer Program, recommended) or Password (any Apple ID)"
xtool auth login
xtool auth status

# 4. Test build
echo "=== Test build ==="
cd /workspace
xtool dev build

echo "=== Setup complete ==="
echo "Future: docker compose run --rm swift-dev xtool dev build"
echo "Deploy: docker compose run --rm swift-dev xtool dev"