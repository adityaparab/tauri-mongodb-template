# ─────────────────────────────────────────────────────────────────────────────
# NOTE: Railway (and all major cloud container platforms) only support Linux
# containers.  Windows containers are not available.
#
# This image runs on Ubuntu 22.04 and cross-compiles the Windows NSIS installer
# using the MinGW-w64 toolchain.  Tauri uses Wine to execute the Windows NSIS
# tools (makensis.exe) that produce the final .exe installer.
# ─────────────────────────────────────────────────────────────────────────────
FROM ubuntu:22.04

# ── Environment ───────────────────────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    # Suppress Wine debug noise
    WINEDEBUG=-all \
    WINEPREFIX=/root/.wine \
    # Rust toolchain location (system-wide so both root and non-root can use it)
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    # MinGW cross-linker for the Windows GNU target
    CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc \
    PKG_CONFIG_ALLOW_CROSS=1

ENV PATH=/usr/local/cargo/bin:$PATH

# ── 0. Make apt resilient to transient mirror failures ────────────────────────
RUN echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries

# ── 1. System packages ────────────────────────────────────────────────────────
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    # Essentials
    curl wget ca-certificates git unzip file patchelf \
    build-essential pkg-config libssl-dev \
    # MinGW cross-compilation toolchain  (Linux → Windows x64)
    gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 \
    binutils-mingw-w64-x86-64 \
    # NSIS — native Linux NSIS compiler; creates Windows installers from Linux.
    # Tauri resolves the system 'makensis' binary via $PATH.  We also add a
    # 'makensis.exe' symlink so older Tauri codepaths that look for the Windows
    # binary name still work without Wine.
    nsis \
    # Wine — fallback for any Tauri NSIS plugin that must run as a Windows exe
    wine wine64 wine32 \
    # GTK/WebKit — required by Tauri's build system even for cross-compilation
    libwebkit2gtk-4.0-dev libgtk-3-dev \
    libayatana-appindicator3-dev librsvg2-dev \
    # Virtual display so Wine console tools don't error on missing DISPLAY
    xvfb \
 && ln -sf /usr/bin/makensis /usr/local/bin/makensis.exe \
 && rm -rf /var/lib/apt/lists/*

# ── 2. Node.js 20 + Yarn ─────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y nodejs \
 && npm install -g yarn \
 && rm -rf /var/lib/apt/lists/*

# ── 3. PowerShell (pwsh) ──────────────────────────────────────────────────────
RUN curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb \
      -o /tmp/packages-microsoft-prod.deb \
 && dpkg -i /tmp/packages-microsoft-prod.deb \
 && rm /tmp/packages-microsoft-prod.deb \
 && apt-get update \
 && apt-get install -y powershell \
 && rm -rf /var/lib/apt/lists/*

# ── 4. Rust + Windows cross-compilation target ────────────────────────────────
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain stable \
 && rustup target add x86_64-pc-windows-gnu

# ── 5. Initialise Wine prefix ─────────────────────────────────────────────────
# Tauri runs NSIS (a Windows .exe) through Wine to create the installer.
# We initialise the Wine prefix now so the first build request is not delayed.
RUN Xvfb :99 -screen 0 1024x768x24 & \
    export DISPLAY=:99 && \
    wineboot --init 2>/dev/null || true

# ── 6. Copy project + install JS dependencies ────────────────────────────────
WORKDIR /app
COPY . .
RUN yarn install --frozen-lockfile

# ── 7. Pre-warm the Rust / Tauri build cache ─────────────────────────────────
# Running a full build here compiles all Rust crates and bundles the frontend.
# Subsequent /generate/:uuid requests hit the incremental Cargo cache and only
# re-run the fast NSIS packaging step (seconds, not minutes).
# "|| true" ensures a packaging failure doesn't break the image build.
RUN DISPLAY=:99 Xvfb :99 -screen 0 1024x768x24 & \
    sleep 2 && \
    yarn tauri build --target x86_64-pc-windows-gnu --bundles nsis || true

# ── 8. Build the NestJS service ───────────────────────────────────────────────
WORKDIR /app/server
RUN yarn install --frozen-lockfile
RUN yarn build

# ── 9. Runtime ────────────────────────────────────────────────────────────────
# Start Xvfb (needed by Wine at runtime) then launch the NestJS server.
EXPOSE 3000
CMD ["sh", "-c", "Xvfb :99 -screen 0 1024x768x24 & export DISPLAY=:99 && node /app/server/dist/main.js"]
