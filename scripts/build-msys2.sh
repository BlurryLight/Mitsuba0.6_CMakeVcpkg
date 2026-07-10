#!/usr/bin/env bash
#
# Build Mitsuba 0.6 (CMake port) on Windows using MSYS2 (UCRT64).
#
# Tested on:
#   * Windows 10/11 + MSYS2 UCRT64
#   * GCC 16 (mingw-w64) + CMake 4 + Ninja, system Qt 5.15, Boost 1.91
#
# This script does three things:
#   1. Installs the UCRT64 build dependencies via pacboy (skippable with --no-install).
#   2. Configures the CMake project under ./build/cmake-msys2-release (or
#   3. Builds the project.
#
# No vcpkg, no Visual Studio: every dependency comes from MSYS2.
#
# Usage:
#   ./scripts/build-msys2.sh                                    # release build
#   ./scripts/build-msys2.sh --debug                            # debug build
#   ./scripts/build-msys2.sh --build-dir=/path/to/build         # custom build dir
#   ./scripts/build-msys2.sh --no-install                       # skip the pacboy install step
#   ./scripts/build-msys2.sh --clean                            # wipe build dir first
#   ./scripts/build-msys2.sh --no-smoke                         # skip smoke tests
#   ./scripts/build-msys2.sh --no-stage                         # skip stage dlls
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UCRT_PREFIX="/ucrt64"

INSTALL=true
CLEAN=false
BUILD_TYPE=Release
JOBS="$(nproc 2>/dev/null || echo 4)"
SMOKE=true
STAGE=true

for arg in "$@"; do
    case "$arg" in
        --no-install) INSTALL=false ;;
        --clean)      CLEAN=true ;;
        --debug)      BUILD_TYPE=Debug ;;
        --release)    BUILD_TYPE=Release ;;
        --no-smoke)    SMOKE=false ;;
        --no-stage)    STAGE=false ;;
        --build-dir=*) BUILD_DIR="${arg#*=}" ;;
        -j*)          JOBS="${arg#-j}" ;;
        -h|--help)
            sed -n '2,22p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [[ -z "${BUILD_DIR:-}" ]]; then
    BUILD_DIR="${REPO_ROOT}/build/cmake-msys2-${BUILD_TYPE,,}"
fi

log()  { printf '\033[1;34m[build-msys2]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[build-msys2]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[build-msys2]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Sanity checks -----------------------------------------------------------
[[ "$(uname -s)" == "MINGW64_NT-"* ]] || die "This script is MSYS2-only."
[[ "${MSYSTEM:-}" == "UCRT64" ]]      || die "This script requires the UCRT64 environment (current: ${MSYSTEM:-unset}). Run from a 'UCRT64' MSYS2 shell."

command -v g++    >/dev/null || die "g++ is required (pacboy -S toolchain)."
command -v cmake  >/dev/null || die "cmake is required (pacboy -S cmake)."
command -v ninja  >/dev/null || die "ninja is required (pacboy -S ninja)."
command -v pacboy >/dev/null || die "pacboy is required (MSYS2 ships it in base)."

# --- Step 1: install UCRT64 build dependencies ------------------------------
if $INSTALL; then
    log "Installing UCRT64 build dependencies ..."
    # MSYS2 splits every C/C++ library into a headers-only package and a
    # runtime / import-libs package (boost / boost-libs, qt5-base / no-libs,
    # ...). pacboy prefixes the current MSYSTEM automatically -- this list
    # is the MSYS2 equivalent of the apt / brew lists in build-linux.sh and
    # build-macos.sh. `pkgconf` is needed because some packages (libpng,
    # xerces-c) only ship .pc files.
    pacboy -S --noconfirm --needed \
        cmake \
        ninja \
        pkgconf \
        boost \
        boost-libs \
        qt5-base \
        qt5-xmlpatterns \
        eigen3 \
        fftw \
        openexr \
        imath \
        libjpeg-turbo \
        libpng \
        xerces-c \
        glew \
        collada-dom \
        python \
        python-numpy
else
    log "Skipping pacboy install (--no-install). Make sure all dependencies are present."
fi

# --- Step 2: clean ----------------------------------------------------------
if $CLEAN; then
    log "Wiping ${BUILD_DIR} ..."
    rm -rf "${BUILD_DIR}"
fi

# --- Step 3: configure & build ---------------------------------------------
# Python in MSYS2 lives under the same prefix as everything else, so
# find_package(Python) needs an explicit interpreter hint.
PYTHON_EXE="$(command -v python3 || command -v python)"
[[ -n "${PYTHON_EXE}" ]] || die "python3 not found on PATH."

log "Configuring CMake (build type: ${BUILD_TYPE}, generator: Ninja) ..."
cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" \
    -G "Ninja" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_PREFIX_PATH="${UCRT_PREFIX}" \
    -DPython_EXECUTABLE="${PYTHON_EXE}" \
    -DBOOST_ROOT="${UCRT_PREFIX}"

log "Building with ${JOBS} jobs ..."
cmake --build "${BUILD_DIR}" -j "${JOBS}"

# Create symlink for compile_commands.json at repo root
ln -sf "${BUILD_DIR}/compile_commands.json" "${REPO_ROOT}/compile_commands.json"

# --- Step 4: stage runtime DLLs --------------------------------------------
# GCC-built executables depend on the UCRT runtime + the per-package DLLs
# (Qt5Core.dll, libboost_*-mt.dll, libfftw3f-3.dll, ...). On MSVC, vcpkg
# would copy those into the bin dir. Here we do the equivalent with a small
# helper that copies every DLL the produced executables and .dll plugins
# link against. This keeps the build self-contained for manual use -- no
# need to keep /ucrt64/bin on PATH.
log "Staging runtime DLLs into ${BUILD_DIR}/bin ..."
stage_runtime_dlls() {
    local bin_dir="${BUILD_DIR}/bin"
    local ucrt_bin="${UCRT_PREFIX}/bin"

    if ! command -v ldd >/dev/null 2>&1; then
        warn "ldd not available; skipping runtime DLL copy (run with /ucrt64/bin on PATH instead)."
        return 0
    fi

    # Collect every DLL the project artifacts reference. `ldd` follows the
    # usual Windows search rules; we only need to copy the ones that live
    # under UCRT_PREFIX (system DLLs are always available).
    local -A seen=()
    local copied=0
    while IFS= read -r -d '' art; do
        while IFS= read -r line; do
            # Lines look like: "  libfoo.dll => /ucrt64/bin/libfoo.dll (0x...)"
            local path="${line##*=> }"
            path="${path% (*}"
            if [[ -z "${path}" || "${path}" == "${line}" ]]; then
                continue
            fi
            if [[ "${path}" == "${ucrt_bin}/"* && -z "${seen[${path}]:-}" ]]; then
                seen["${path}"]=1
                cp -f "${path}" "${bin_dir}/" && copied=$((copied+1))
            fi
        done < <(ldd "${art}" 2>/dev/null | grep '\.dll')
    done < <(find "${bin_dir}" -maxdepth 2 -type f \( -name "*.exe" -o -name "*.dll" \) -print0)

    log "Copied ${copied} runtime DLL(s) to ${bin_dir}"
    # Qt5 platform plugins (qwindows.dll, etc.) are loaded dynamically at
    # runtime — ldd does not see them, so we copy them explicitly.
    local qt_plugins="${UCRT_PREFIX}/share/qt5/plugins"
    if [[ -d "${qt_plugins}/platforms" ]]; then
        mkdir -p "${BUILD_DIR}/bin/platforms"
        cp -f "${qt_plugins}/platforms/"*.dll "${BUILD_DIR}/bin/platforms/"
        # 必须在可执行的目录下创建一个platforms目录，并将qwindows.dll放入其中，否则Qt无法找到平台插件，程序会报错
        log "Copied Qt platform plugins to ${BUILD_DIR}/bin/platforms/"
    fi
}
if $STAGE; then
    stage_runtime_dlls

else
    log "Skipping runtime DLL copy (--no_stage). Make sure /ucrt64/bin is on PATH."
fi

# --- Smoke test ------------------------------------------------------------
if $SMOKE; then
    log "Smoke-testing binaries ..."
    "${BUILD_DIR}/bin/mitsuba.exe" -h >/dev/null
    "${BUILD_DIR}/bin/mtsutil.exe"  -h >/dev/null
    "${BUILD_DIR}/bin/mtssrv.exe"   -h >/dev/null
    log "Done. Binaries are in ${BUILD_DIR}/bin/"
    log "Plugins are in  ${BUILD_DIR}/bin/plugins/"
    log ""
    log "Try a cli render:"
    log "  ${BUILD_DIR}/bin/mitsuba.exe <scene.xml> -o out.exr"
    log "Try a gui render:"
    log "  ${BUILD_DIR}/bin/mtsgui.exe <scene.xml> -o out.exr"
fi