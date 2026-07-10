#!/usr/bin/env bash
#
# Build Mitsuba 0.6 (CMake port) on macOS.
#
# Tested on:
#   * Apple Silicon (M1/M2/M3/M4), macOS 15+
#   * Homebrew + Apple Clang 16
#   * Qt 5.15, Boost 1.90, OpenEXR 3.4
#
# This script does three things:
#   1. Installs the Homebrew dependencies (skipped if already installed).
#   2. Patches the two Homebrew quirks that block the CMake configure step
#      (Qt5 mkspecs/plugins and GLEW header layout).
#   3. Configures and builds the project under ./cbuild.
#
# Usage:
#   ./scripts/build-macos.sh                # release build
#   ./scripts/build-macos.sh --debug        # debug build
#   ./scripts/build-macos.sh --no-brew      # skip the brew install step
#   ./scripts/build-macos.sh --clean        # wipe cbuild/ first
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/cbuild"

BREW=true
CLEAN=false
BUILD_TYPE=Release
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

for arg in "$@"; do
    case "$arg" in
        --no-brew)  BREW=false ;;
        --clean)    CLEAN=true ;;
        --debug)    BUILD_TYPE=Debug ;;
        --release)  BUILD_TYPE=Release ;;
        -j*)        JOBS="${arg#-j}" ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

log()  { printf '\033[1;34m[build-macos]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[build-macos]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[build-macos]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Sanity checks -----------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || die "This script is macOS-only."
[[ "$(uname -m)" == "arm64" ]]  || warn "Non-Apple-Silicon Mac: untested. SSE code paths are x86-only and are disabled in CMakeLists.txt."

command -v brew >/dev/null    || die "Homebrew is required. Install from https://brew.sh"
command -v cmake >/dev/null   || die "cmake is required (brew install cmake)"
xcode-select -p >/dev/null 2>&1 || die "Xcode Command Line Tools are required (xcode-select --install)"

# --- Step 1: install Homebrew dependencies ----------------------------------
if $BREW; then
    log "Installing Homebrew dependencies (skip if already present) ..."
    brew install --quiet \
        cmake \
        autoconf automake pkg-config \
        qt@5 boost boost-python3 \
        openexr libjpeg-turbo libpng \
        xerces-c glew eigen fftw
else
    log "Skipping brew install (--no-brew)."
fi

# --- Step 2: patch Homebrew quirks ------------------------------------------
# (1) Qt5 ships its mkspecs/ and plugins/ inside the Cellar but find_package
#     looks for them at HOMEBREW_PREFIX. Create compat symlinks if missing.
BREW_PREFIX="$(brew --prefix)"
QT_CELLAR_DIR="${BREW_PREFIX}/Cellar/qt@5"
QT_VERSION="$(ls -1 "${QT_CELLAR_DIR}" 2>/dev/null | sort -V | tail -1 || true)"

if [[ -n "${QT_VERSION}" ]]; then
    QT_SRC="${QT_CELLAR_DIR}/${QT_VERSION}"
    [[ -e "${BREW_PREFIX}/mkspecs" ]] || ln -sfn "${QT_SRC}/mkspecs" "${BREW_PREFIX}/mkspecs"
    [[ -d "${BREW_PREFIX}/plugins"  ]] || mkdir -p "${BREW_PREFIX}/plugins"
    for sub in "${QT_SRC}/plugins"/*; do
        [[ -e "${BREW_PREFIX}/plugins/$(basename "$sub")" ]] || \
            ln -sfn "$sub" "${BREW_PREFIX}/plugins/$(basename "$sub")"
    done
    # (2) mitsuba's GL code includes <OpenGL/glew.h> on macOS but Homebrew's
    #     GLEW installs as <GL/glew.h>. Bridge them.
    [[ -e "${BREW_PREFIX}/include/OpenGL" ]] || ln -sfn "${BREW_PREFIX}/include/GL" "${BREW_PREFIX}/include/OpenGL"
    log "Homebrew Qt5 + GLEW symlinks verified."
else
    warn "Qt5 not found in ${QT_CELLAR_DIR}. Did you skip --no-brew?"
fi

# --- Step 3: configure & build --------------------------------------------
if $CLEAN; then
    log "Wiping ${BUILD_DIR} ..."
    rm -rf "${BUILD_DIR}"
fi

log "Configuring CMake (build type: ${BUILD_TYPE}) ..."
cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_PREFIX_PATH="${BREW_PREFIX}" \
    -DFFTW3_DIR="${BREW_PREFIX}/lib/cmake/fftw3" \
    -DFFTW3f_DIR="${BREW_PREFIX}/lib/cmake/fftw3"

log "Building with ${JOBS} jobs ..."
cmake --build "${BUILD_DIR}" -j "${JOBS}"

# --- Smoke test ------------------------------------------------------------
log "Smoke-testing binaries ..."
"${BUILD_DIR}/bin/mitsuba" -h >/dev/null
"${BUILD_DIR}/bin/mtsutil" -h >/dev/null
"${BUILD_DIR}/bin/mtssrv"  -h >/dev/null
log "Done. Binaries are in ${BUILD_DIR}/bin/"
log "Plugins are in  ${BUILD_DIR}/bin/plugins/"
log ""
log "Try a render:"
log "  ${BUILD_DIR}/bin/mitsuba <scene.xml> -o /tmp/out.exr"
