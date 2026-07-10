Mitsuba Fork for CMake
===================================

This project is based on [VicentChen/mitsuba](https://github.com/VicentChen/mitsuba),
a fork of Mitsuba 0.6. The dependency management has been modernized and the
build now works on **Windows (vcpkg)**, **Linux (vcpkg or system packages)**
and **macOS (Homebrew)**.

## Platforms

| OS | Toolchain | Tested |
|---|---|---|
| Windows 10/11 | Visual Studio 2022 + [vcpkg](https://vcpkg.io/en/) | yes |
| **Linux (Ubuntu 24.04)** | **g++ + CMake + apt** | **yes** |
| macOS 15+ (Apple Silicon) | Homebrew + Apple Clang | yes |

## Quick start — Linux

```bash
git clone git@github.com:BlurryLight/Mitsuba0.6_CMakeVcpkg.git
cd Mitsuba0.6_CMakeVcpkg
./scripts/build-linux.sh
```

The script installs every build dependency via `apt` (no vcpkg, no manual
tweaking), configures the CMake project under `./cbuild`, and builds it.
The renderer binaries land in `cbuild/bin/` and the plugins in
`cbuild/bin/plugins/`.

Try a render:
```bash
./cbuild/bin/mitsuba path/to/scene.xml -o out.exr
```

The build script accepts the following flags:
```bash
./scripts/build-linux.sh --debug     # debug build
./scripts/build-linux.sh --clean     # wipe cbuild/ before configuring
./scripts/build-linux.sh --no-apt    # skip the apt install step
```

### Manual Linux build

If you prefer to drive CMake yourself:

```bash
sudo apt install -y --no-install-recommends \
    build-essential cmake ninja-build pkg-config \
    libboost-filesystem-dev libboost-thread-dev libboost-chrono-dev \
    libboost-date-time-dev libboost-atomic-dev libboost-python-dev \
    zlib1g-dev libopenexr-dev libimath-dev \
    libjpeg-turbo8-dev libpng-dev libxerces-c-dev libglew-dev \
    libeigen3-dev libfftw3-dev \
    qtbase5-dev qttools5-dev libqt5xmlpatterns5-dev libqt5opengl5-dev \
    python3-dev python3-numpy \
    libx11-dev libxmu-dev libxi-dev libgl-dev libglu1-mesa-dev libxxf86vm-dev

mkdir cbuild && cd cbuild
cmake -GNinja -DCMAKE_BUILD_TYPE=Release ..
cmake --build . -j
```

## Quick start — macOS

```bash
git clone git@github.com:BlurryLight/Mitsuba0.6_CMakeVcpkg.git
cd Mitsuba0.6_CMakeVcpkg
./scripts/build-macos.sh
```

The script installs the Homebrew dependencies, patches two well-known Homebrew
Qt5 layout quirks, configures the CMake project, and builds it. Produces the
renderer binaries in `cbuild/bin/` and the plugins in `cbuild/bin/plugins/`.

Try a render:
```bash
./cbuild/bin/mitsuba path/to/scene.xml -o out.exr
```

The build script accepts the following flags:
```bash
./scripts/build-macos.sh --debug     # debug build
./scripts/build-macos.sh --clean     # wipe cbuild/ before configuring
./scripts/build-macos.sh --no-brew   # skip the brew install step
```

### Manual macOS build

If you prefer to drive CMake yourself:

```bash
brew install cmake qt@5 boost boost-python3 openexr libjpeg-turbo libpng \
             xerces-c glew eigen fftw

# Patch two Homebrew Qt5 layout quirks (the script does this for you):
ln -sfn /opt/homebrew/Cellar/qt@5/$(ls /opt/homebrew/Cellar/qt@5 | sort -V | tail -1)/mkspecs /opt/homebrew/mkspecs
for p in /opt/homebrew/Cellar/qt@5/*/plugins/*; do
    ln -sfn "$p" /opt/homebrew/plugins/$(basename "$p")
done
ln -sfn /opt/homebrew/include/GL /opt/homebrew/include/OpenGL

mkdir cbuild && cd cbuild
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH=/opt/homebrew \
      -DFFTW3_DIR=/opt/homebrew/lib/cmake/fftw3 \
      -DFFTW3f_DIR=/opt/homebrew/lib/cmake/fftw3 \
      ..
cmake --build . -j
```

## Quick start — Windows

### Environment
 - [CMake](https://cmake.org/download/)
 - [vcpkg](https://vcpkg.io/en/)

### Compilation
```bat
git clone https://github.com/BlurryLight/Mitsuba0.6_CMakeVcpkg.git
cd Mitsuba0.6_CMakeVcpkg
cmake -S . -B cbuild -DCMAKE_TOOLCHAIN_FILE=[path\to\vcpkg.cmake]
cmake --build cbuild --config Release
```

This setup has been tested on Visual Studio 2022 + Windows 10.

## Known Issues
 - Exporting HDR images fails in Debug mode (works fine in Release mode).
 - `mtsgui` (the interactive Qt previewer) is not built on macOS because the
   original sources depend on the long-discontinued `BWToolkitFramework`.
   The CLI tools (`mitsuba`, `mtssrv`, `mtsutil`) are fully functional.
 - `MTS_SSE` is disabled on macOS (no SSE on Apple Silicon); `MTS_HAS_COHERENT_RT`
   is disabled everywhere because Intel Embree is not in the vcpkg dependency
   list. Both are build-time-only defines; the code falls back to portable paths.
 - The OpenMP runtime is not auto-detected on macOS. Multi-threaded rendering
   inside a single image falls back to single-threaded execution. The network
   renderer (`mtssrv`) and the multi-scene scheduler still use threads.

## Layout

```
Mitsuba0.6_CMakeVcpkg/
├── CMakeLists.txt          # top-level build configuration
├── vcpkg.json              # vcpkg dependency manifest
├── scripts/
│   ├── build-linux.sh      # one-shot Linux build (apt + cmake)
│   └── build-macos.sh      # one-shot macOS build (brew + cmake)
├── src/                    # sources (core lib, plugins, CLI tools)
├── include/mitsuba/        # public headers
├── data/                   # schemas, IOR tables, default resources
└── cbuild/                 # build output (gitignored)
    ├── bin/                # mitsuba, mtssrv, mtsutil
    │   └── plugins/        # *.dylib plugin modules
    └── lib/                # libmitsuba-{core,render,hw,bidir,python}.dylib
```
