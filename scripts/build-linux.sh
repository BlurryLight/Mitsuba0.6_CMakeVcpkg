#!/usr/bin/env bash
#
# Build Mitsuba 0.6 (CMake port) on Linux (Ubuntu / Debian-family).
#
# Tested on:
#   * Ubuntu 24.04 (Noble), x86_64
#   * GCC 13 + CMake 3.28, system Qt 5.15, Boost 1.83
#
# This script does three things:
#   1. Installs the apt build dependencies (skippable with --no-apt).
#   2. Configures the CMake project under ./build/cmake-linux-release (or
#      --debug, or --build-dir=...).
#   3. Builds the project.
#
# No vcpkg, no Homebrew: every dependency comes from the system package
# manager.
#
# Usage:
#   ./scripts/build-linux.sh                                    # release build
#   ./scripts/build-linux.sh --debug                            # debug build
#   ./scripts/build-linux.sh --build-dir=/path/to/build         # custom build dir
#   ./scripts/build-linux.sh --no-apt                           # skip the apt install step
#   ./scripts/build-linux.sh --clean                            # wipe build dir first
#   ./scripts/build-linux.sh --no-smoke                         # skip smoke tests
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

APT=true
CLEAN=false
BUILD_TYPE=Release
JOBS="$(nproc 2>/dev/null || echo 4)"
SMOKE=true

for arg in "$@"; do
    case "$arg" in
        --no-apt)    APT=false ;;
        --clean)     CLEAN=true ;;
        --debug)     BUILD_TYPE=Debug ;;
        --release)   BUILD_TYPE=Release ;;
        --no-smoke)  SMOKE=false ;;
        --build-dir=*) BUILD_DIR="${arg#*=}" ;;
        -j*)         JOBS="${arg#-j}" ;;
        -h|--help)
            sed -n '2,23p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [[ -z "${BUILD_DIR:-}" ]]; then
    BUILD_TYPE_LOWER=$(echo "${BUILD_TYPE}" | tr '[:upper:]' '[:lower:]')
    BUILD_DIR="${REPO_ROOT}/build/cmake-linux-${BUILD_TYPE_LOWER}"
fi

log()  { printf '\033[1;34m[build-linux]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[build-linux]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[build-linux]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Sanity checks -----------------------------------------------------------
[[ "$(uname -s)" == "Linux" ]] || die "This script is Linux-only."

command -v cmake >/dev/null  || die "cmake is required (apt install cmake)."
command -v g++   >/dev/null  || die "A C++ compiler is required (apt install build-essential)."

# --- Step 1: install apt dependencies ---------------------------------------
if $APT; then
    if command -v sudo >/dev/null && [[ "$EUID" -ne 0 ]]; then
        SUDO=sudo
    else
        SUDO=""
    fi
    log "Installing apt build dependencies ..."
    $SUDO apt-get update
    $SUDO apt-get install -y --no-install-recommends \
        build-essential cmake ninja-build pkg-config \
        libboost-filesystem-dev libboost-thread-dev libboost-chrono-dev \
        libboost-date-time-dev libboost-atomic-dev libboost-python-dev \
        zlib1g-dev libopenexr-dev libimath-dev \
        libjpeg-turbo8-dev libpng-dev libxerces-c-dev libglew-dev \
        libeigen3-dev libfftw3-dev \
        qtbase5-dev qttools5-dev libqt5xmlpatterns5-dev libqt5opengl5-dev \
        python3-dev python3-numpy \
        libx11-dev libxmu-dev libxi-dev libgl-dev libglu1-mesa-dev libxxf86vm-dev
else
    log "Skipping apt install (--no-apt). Make sure all dependencies are present."
fi

# --- Step 2: clean ----------------------------------------------------------
if $CLEAN; then
    log "Wiping ${BUILD_DIR} ..."
    rm -rf "${BUILD_DIR}"
fi

# --- Step 3: configure & build ---------------------------------------------
log "Configuring CMake (build type: ${BUILD_TYPE}) ..."
cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -GNinja

log "Building with ${JOBS} jobs ..."
cmake --build "${BUILD_DIR}" -j "${JOBS}"

# Create symlink for compile_commands.json at repo root
ln -sf "${BUILD_DIR}/compile_commands.json" "${REPO_ROOT}/compile_commands.json"

# --- Smoke test ------------------------------------------------------------
if $SMOKE; then
    log "Smoke-testing binaries ..."
    "${BUILD_DIR}/bin/mitsuba" -h >/dev/null
    "${BUILD_DIR}/bin/mtsutil" -h >/dev/null
    "${BUILD_DIR}/bin/mtssrv"  -h >/dev/null
else
    log "Skipping smoke test (--no-smoke)."
fi

log "Done. Binaries are in ${BUILD_DIR}/bin/"
log "Plugins are in  ${BUILD_DIR}/bin/plugins/"
log ""
log "Try a render:"
log "  ${BUILD_DIR}/bin/mitsuba <scene.xml> -o /tmp/out.exr"
