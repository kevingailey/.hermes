---
name: ios-deploy
description: "Cross-platform iOS app deployment using xtool — build, sign, and install iOS apps from Linux, Windows, or macOS without Xcode."
version: 1.4.0
---

# iOS Deploy — xtool

## Overview

Build, sign, and deploy iOS apps from any platform using [xtool](https://github.com/xtool-org/xtool) — a cross-platform Xcode replacement. Works on Linux, Windows (via WSL), and macOS. No Xcode required on Linux/Windows.

**Core principle:** Write SwiftPM packages, deploy to real iOS devices. Same workflow on any OS.

## Prerequisites

| Platform | Requirements |
|----------|-------------|
| **Docker (recommended)** | Docker + docker-compose, no host Swift install needed |
| **Linux (direct)** | Swift 6.3 toolchain, usbmuxd, libimobiledevice-utils |
| **Windows** | WSL2 + USBIPD for USB passthrough, then same as Linux |
| **macOS** | Xcode installed (for SDK, not build system) |

## Installation

### Dev Container (Recommended)

The cleanest approach: a self-contained Docker container with Swift 6.3, xtool, usbmuxd, and libimobiledevice pre-installed. No host-level Swift install needed. The project repo is mounted as a volume.

**Dockerfile:**

```dockerfile
FROM swift:6.3-jammy

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates build-essential git curl wget unzip \
    libssl-dev pkg-config libxml2 libcurl4-openssl-dev \
    zip liblzma-dev zlib1g-dev \
    usbmuxd libimobiledevice-utils socat \
    vim less file \
    && rm -rf /var/lib/apt/lists/*

# xtool AppImage needs extract-and-run (FUSE not available in Docker)
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
RUN swift --version && xtool --help
CMD ["/bin/bash"]
```

**docker-compose.yml:**

```yaml
services:
  swift-dev:
    build: .
    image: <project-slug>-swift-dev:6.3
    container_name: swift-dev
    volumes:
      - .:/workspace
      # Persist xtool auth + SDK across container rebuilds (CRITICAL)
      - xtool-cache:/root/.cache/xtool    # Apple Developer Services auth tokens
      - swift-sdks:/root/.swiftpm         # Darwin iOS SDK (~5GB, extracted from Xcode.xip)
      - xcode-xip:/root/xcode-xip:ro     # Mount point for Xcode.xip during setup
    stdin_open: true
    tty: true
    cap_add:
      - sys_ptrace
    security_opt:
      - seccomp:unconfined
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - USBMUXD_SOCKET_ADDRESS=host.docker.internal:27015

volumes:
  xtool-cache:
  swift-sdks:
  xcode-xip:
```

**Named volumes are essential.** Without them, `xtool setup` (auth + SDK extraction, ~20 min) must be repeated after every `docker compose build`. The three volumes persist:
- `xtool-cache` → `/root/.cache/xtool` — Apple ID auth tokens and session data
- `swift-sdks` → `/root/.swiftpm` — Darwin Swift SDK extracted from Xcode.xip
- `xcode-xip` → `/root/xcode-xip` — read-only mount for the Xcode.xip during one-time setup

**VS Code devcontainer** (`.devcontainer/devcontainer.json`):

```json
{
  "name": "Swift Dev",
  "dockerFile": "Dockerfile",
  "context": ".",
  "workspaceFolder": "/workspace",
  "mounts": [
    "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached"
  ],
  "extensions": ["swiftlang.swift"],
  "postCreateCommand": "swift --version && xtool --help"
}
```

**Build and use:**

```bash
# Build the container
docker compose build

# Interactive shell
docker compose run --rm swift-dev

# Run a single command
docker compose run --rm swift-dev swift build
docker compose run --rm swift-dev xtool dev build

# VS Code: reopen in container (Command Palette > "Reopen in Container")
```

**USB forwarding for device deployment:**

The container can't access USB directly. Forward usbmuxd from the host:

```bash
# On host: forward usbmuxd socket to TCP port 27015
socat -dd TCP-LISTEN:27015,range=127.0.0.1/32,reuseaddr,fork UNIX-CLIENT:/var/run/usbmuxd

# The docker-compose.yml sets USBMUXD_SOCKET_ADDRESS=host.docker.internal:27015
# so xtool inside the container connects through the forwarded socket
```

**Pitfalls:**
- AppImage needs `APPIMAGE_EXTRACT_AND_RUN=1` — FUSE is not available in Docker containers. The Dockerfile extracts the AppImage at build time and symlinks `AppRun` to `/usr/local/bin/xtool`.
- `host.docker.internal` doesn't exist by default on Linux hosts. The `extra_hosts` entry in docker-compose.yml maps it to `host-gateway`.
- First `swift build` inside the container downloads and caches SDK modules (~several minutes). Subsequent builds are cached in the mounted volume.

### Linux (Direct Install)

If not using Docker:

```bash
# 1. Install Swift 6.3 from https://swift.org/install/linux
# 2. Install usbmuxd
sudo apt-get install usbmuxd libimobiledevice-utils

# 3. Download xtool AppImage
curl -fL \
  "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" \
  -o xtool
chmod +x xtool
sudo mv xtool /usr/local/bin/

# 4. Verify
xtool --help
```

### macOS

```bash
brew install xtool-org/tap/xtool
# or download xtool.app from GitHub releases
```

## Setup (One-Time)

```bash
xtool setup
```

This walks through:
1. **Login mode** — choose API Key (paid Apple Developer account, recommended) or Password (any Apple ID, uses private APIs)
2. **Credentials** — API key file or email + password + 2FA
3. **Xcode.xip path** — xtool extracts the iOS SDK from Xcode. Requires **Xcode 26** (download from <https://developer.apple.com/download/all/?q=Xcode> — needs browser auth, `curl` won't work). Enter the path when prompted, e.g. `~/Downloads/Xcode_26.xip`.

Verify the SDK was installed:

```bash
swift sdk list
# darwin
```

## Project Lifecycle

### Create a new project

```bash
xtool new Hello
cd Hello
```

This creates a SwiftPM package with:
- `Sources/Hello/` — app code
- `xtool.yml` — app configuration
- `.sourcekit-lsp/config.json` — IDE support config

### Build and deploy

```bash
# Build, sign, install, and launch on connected device
xtool dev

# Build only (no deploy)
xtool dev build
```

`xtool dev` handles the full pipeline:
1. Build with `swift build --swift-sdk arm64-apple-ios`
2. Sign with generated certificate + provisioning profile
3. Install via usbmuxd to connected device
4. Launch the app

### Device management

```bash
# List connected devices
xtool devices

# Install an IPA directly
xtool install path/to/app.ipa

# Uninstall an app
xtool uninstall com.example.Hello

# Launch an installed app
xtool launch com.example.Hello
```

### Apple Developer Services

```bash
# Interact with Apple Developer Services
xtool ds <subcommand>

# Manage authentication
xtool auth
```

## Configuration (xtool.yml)

Every xtool project has an `xtool.yml` file:

```yaml
version: 1
bundleID: com.example.Hello
product: Hello                    # SwiftPM product name (default: package name)
iconPath: Resources/AppIcon.png   # App icon (1024x1024 PNG)
infoPath: Custom-Info.plist       # Custom Info.plist overrides
entitlementsPath: App.entitlements # Entitlements file
resources:                        # Top-level bundle resources
  - Resources/GoogleServices-Info.plist
extensions:                       # App extensions
  - product: HelloWidget
    infoPath: HelloWidget-Info.plist
```

### Bundle ID

```yaml
bundleID: com.example.MyApp
```

xtool prefixes the bundle ID with a team identifier on real devices (e.g. `XTL-1234.com.example.MyApp`) to avoid conflicts between free accounts.

### Custom Info.plist

Create a partial `Info.plist` with only the keys you want to add/override:

```yaml
infoPath: path/to/Info.plist
```

Example `Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>CFBundleDisplayName</key>
    <string>My App</string>
</dict>
</plist>
```

### App Icon

```yaml
iconPath: Resources/AppIcon.png
```

Must be a PNG, ideally 1024x1024px.

### Entitlements

```yaml
entitlementsPath: App.entitlements
```

Example `App.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.homekit</key>
    <true/>
</dict>
</plist>
```

**Known limitations:**
- Some entitlements (Network Extension, etc.) require paid Developer Program membership
- Some entitlements require special Apple permission
- xtool handles Capability→Entitlement mapping for common cases; file an issue if one is missing

### Resources

Two ways to include resources:

**SwiftPM Resources** (bundled in `.bundle` directory):

```swift
// Package.swift
.target(
    name: "Hello",
    resources: [.copy("Blob.png")]
)
```

```swift
// In code
Image("Blob", bundle: Bundle.module)
```

**Top-level resources** (copied to `.app` root):

```yaml
resources:
  - Resources/GoogleServices-Info.plist
```

## App Extensions

xtool supports app extensions (Widgets, Share Extensions, Safari Extensions, etc.).

### Add a Widget Extension

**1. Add product to Package.swift:**

```diff
  products: [
      .library(name: "Hello", targets: ["Hello"]),
+     .library(name: "HelloWidget", targets: ["HelloWidget"]),
  ],
  targets: [
      .target(name: "Hello"),
+     .target(name: "HelloWidget"),
  ]
```

**2. Update xtool.yml:**

```yaml
version: 1
bundleID: com.example.Hello
product: Hello
extensions:
  - product: HelloWidget
    infoPath: HelloWidget-Info.plist
```

**3. Create extension Info.plist:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
```

**4. Write widget code in `Sources/HelloWidget/`.**

**5. Build and deploy:** `xtool dev`

## CI/CD Integration

### GitHub Actions (Linux)

```yaml
name: Build iOS App
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: swift-actions/setup-swift@v2
        with:
          swift-version: "6.3"
      - uses: actions/checkout@v4
      - name: Install usbmuxd
        run: sudo apt-get install -y usbmuxd
      - name: Install xtool
        run: |
          curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o xtool
          chmod +x xtool
          sudo mv xtool /usr/local/bin/
      - name: Setup xtool
        run: |
          # Non-interactive setup requires pre-configured auth
          # See xtool auth --help for options
          xtool setup --non-interactive
      - name: Build
        run: xtool dev build
```

### Docker (Dev Container)

If the project already has a `Dockerfile` + `docker-compose.yml` for the dev container (see Installation > Dev Container), use those directly:

```bash
# Build once
docker compose build

# Run build inside container
docker compose run --rm swift-dev xtool dev build

# Run tests
docker compose run --rm swift-dev swift test

# For device deployment, forward usbmuxd on host first:
socat -dd TCP-LISTEN:27015,range=127.0.0.1/32,reuseaddr,fork UNIX-CLIENT:/var/run/usbmuxd

# Then deploy to device
docker compose run --rm swift-dev xtool dev
```

Note: `swift build` on Linux only verifies non-UI code — SwiftUI requires the iOS SDK via `xtool setup`. Use `xtool dev build` for full iOS builds.

## Pitfalls

### Package.swift: use standard .library, not .iOSApplication

xtool projects use standard SwiftPM `Package.swift` with a `.library` product — NOT `.iOSApplication`. The `.iOSApplication` product type doesn't exist in standard SwiftPM and will fail to compile with `swift build` or `xtool dev build`. xtool reads `xtool.yml` for iOS-specific bundling configuration (bundle ID, app icon, entitlements, extensions).

Correct Package.swift:
```swift
products: [
    .library(name: "MyApp", targets: ["MyApp"]),
],
```

Wrong (doesn't exist):
```swift
products: [
    .iOSApplication(name: "MyApp", targets: ["MyApp"], bundleId: "...", ...),
],
```

### SwiftUI doesn't compile on Linux

`swift build` on a Linux host will fail with `no such module 'SwiftUI'` for any file importing SwiftUI. This is expected — SwiftUI is an iOS/macOS framework not available in the Linux Swift toolchain. To compile SwiftUI code, you need `xtool dev build` which uses the iOS SDK (installed via `xtool setup`).

Non-UI Swift code (models, networking, data parsing) compiles fine on Linux and can be tested with `swift test`.

### xtool new requires interactive auth

`xtool new` and `xtool setup` require interactive authentication (Apple ID login + 2FA or API key). They cannot run headless in a Docker build or CI pipeline without pre-configured auth. For CI, use `xtool auth` with pre-stored credentials or API keys.

### AppImage FUSE requirement

The xtool AppImage requires FUSE to mount at runtime. In Docker containers (and other FUSE-less environments), extract the AppImage with `--appimage-extract` and set `APPIMAGE_EXTRACT_AND_RUN=1`. See the Docker section above for a working Dockerfile.

## Troubleshooting

### "Trust this computer?" prompt

First-time device connection shows a trust dialog on iOS. Tap **Trust** and enter your passcode. If xtool errors after this, just run `xtool dev` again.

### "Enable Developer Mode" error

Go to **Settings > Privacy & Security > Developer Mode** on your iOS device and enable it. Then re-run `xtool dev`.

### "Untrusted Developer" alert on app launch

Go to **Settings > General > VPN & Device Management > [your email] > Trust**. Then launch the app again.

### Device not detected

```bash
# Check if usbmuxd is running
sudo systemctl status usbmuxd

# Check if device is visible
ideviceinfo

# Restart usbmuxd
sudo systemctl restart usbmuxd
```

### Build fails on first run

First build downloads and caches iOS SDK modules. This can take several minutes. Subsequent builds are much faster.

### Bundle ID conflicts

xtool prefixes bundle IDs with a team identifier for free accounts. If you share an app, the recipient won't have bundle ID conflicts.

### Entitlement not working

- Some entitlements require paid Developer Program membership
- Some require special Apple permission
- xtool may not handle the Capability→Entitlement mapping yet — [file an issue](https://github.com/xtool-org/xtool/issues/new)

## Integration with the Pipeline

The ios-deploy skill is the **shipping layer** — it takes built artifacts and puts them on devices. It fits after night-shift:

```
CTO → project-manager → dev-lead → night-shift → ios-deploy
     (shape)   (PRD)      (stories)   (build)     (deploy to device)
```

After night-shift builds the app, use xtool to:
1. Sign and install on a test device
2. Run integration tests on real hardware
3. Deploy to beta testers via Apple Developer Services

## References

- **[iOS/tvOS Video Playback Libraries](references/ios-video-playback-libraries.md)** — Comparison of AVPlayer vs VLCKit vs Swift wrappers for HLS, non-HLS HTTP streams (HDHomeRun), PiP, self-signed HTTPS, SwiftPM compatibility, and licensing. Includes the AVPlayer + local proxy architecture pattern for handling self-signed certs and non-HLS streams without VLCKit. Read this when the project involves video playback.
- **[setup-xtool.sh template](templates/setup-xtool.sh)** — One-time setup script for the dev container. Installs Darwin SDK from Xcode.xip, authenticates with Apple, verifies with `xtool dev build`. Copy into the project's `scripts/` directory and run inside the container.

## Tips

- **Docker is the recommended path.** No host Swift install, no version conflicts, reproducible builds. The dev container has everything pre-installed.
- **First build is slow.** The iOS SDK modules need to compile. Subsequent builds are cached.
- **Use API Key auth for CI.** Password auth is interactive (2FA). API keys work headless.
- **Docker for reproducible builds.** The Dockerfile pins exact libimobiledevice versions.
- **xtool dev does everything.** Build + sign + install + launch in one command. Use `xtool dev build` to just build.
- **Check the built app.** After `xtool dev build`, inspect `./xtool/YourApp.app` for Info.plist and resources.
- **App Extensions need their own Info.plist.** Each extension type has a different `NSExtensionPointIdentifier`.
- **Free accounts are limited.** Some entitlements and capabilities require paid Developer Program membership.
