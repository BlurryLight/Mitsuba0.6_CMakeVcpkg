# AGENTS.md — Mitsuba 0.6 CMake+vcpkg

## Build

```bash
# One-shot (recommended):
./scripts/build-linux.sh              # Release  → build/cmake-linux-release/
./scripts/build-linux.sh --debug      # Debug    → build/cmake-linux-debug/
./scripts/build-linux.sh --clean      # Wipe build dir first

# Manual (any build dir):
mkdir build && cd build
cmake -GNinja -DCMAKE_BUILD_TYPE=Release ..
cmake --build . -j
```

### Agent builds must not overwrite user artefacts

When an AI agent compiles or runs tests, it MUST use `--build-dir` to isolate
its output from the user's manual build. The pattern is:

```
build/cmake-{platform}-{build-type}-agent
```

Examples:

```bash
# Agent doing a Release build on Linux:
./scripts/build-linux.sh --build-dir=build/cmake-linux-release-agent

# Agent running tests on macOS Debug:
./scripts/build-macos.sh --debug --build-dir=build/cmake-macos-debug-agent --no-brew
./build/cmake-macos-debug-agent/bin/mtsutil test_chisquare
```

Never use the default build dirs (`build/cmake-linux-release/` etc.) — the
user may have work in progress there.

Build output lands in the build directory:
- `<build>/bin/` — CLIs (`mitsuba`, `mtssrv`, `mtsutil`, `mtsimport`) and all plugin `.so`s
- `<build>/lib/` — shared libs (`libmitsuba-core`, `libmitsuba-render`, `libmitsuba-hw`, `libmitsuba-bidir`, `libmitsuba-python`)

## Architecture

Mitsuba is a **plugin-based renderer**. Core is thin; almost all functionality (BSDFs, integrators, sensors, shapes, etc.) lives in shared-library plugins loaded by the PluginManager.

```
src/libcore/      → libmitsuba-core       (logging, threading, plugin system, math, serialization)
src/librender/    → libmitsuba-render     (scene graph, shapes, emitters, sensors, films, samplers, integrators)
src/libhw/        → libmitsuba-hw         (OpenGL preview, GPU textures)
src/libbidir/     → libmitsuba-bidir      (bidirectional path tracing)
src/libpython/    → libmitsuba-python     (Boost.Python bindings)
src/mitsuba/      → mitsuba, mtssrv, mtsutil  (CLI tools, link everything)
src/converter/    → mtsimport             (COLLADA/OBJ → XML)
src/mtsgui/       → mtsgui                (Qt5 GUI, not built on macOS)
src/bsdfs/        → BSDF plugins
src/integrators/  → Integrator plugins
src/sensors/      → Camera plugins
src/emitters/     → Light plugins
src/films/        → Film (output) plugins
src/shapes/       → Geometry plugins
src/tests/        → Test plugins (see below)
```

## Tests

Tests are **shared-library plugins**, not executables. There is no CTest integration.

```bash
# List available test plugins (adjust path for your build dir):
ls build/cmake-linux-release/bin/plugins/test_*.so

# Run a single test via mtsutil:
./build/cmake-linux-release/bin/mtsutil test_chisquare
```

Test scenes live in `data/tests/` (`.xml`, `.ply`, `.exr`).

The CI also runs a render smoke test (create XML scene, render 32×32, verify output).

## Critical quirks

- **Plugin naming**: On Linux/macOS, `CMAKE_SHARED_LIBRARY_PREFIX` is set to **empty** so plugins are `foo.so` not `libfoo.so`. The Mitsuba PluginManager resolves plugins by short name. Do not change this.
- **No code generation** step exists. Qt AUTOMOC/AUTORCC/AUTOUIC run automatically as part of the CMake build for `mtsgui` only.
- **`dependencies/CMakeLists.txt`** is a legacy self-build script with hardcoded proxy settings. It is **not used** by the main build. Ignore it.
- `MTS_HAS_COHERENT_RT` is disabled everywhere (no Intel Embree).
- OpenMP may fail on macOS; single-threaded fallback.
- `mtsimport` is skipped on MSYS2 (collada-dom CMake config conflicts with Boost).
- `mtsgui` is skipped on macOS (BWToolkitFramework is defunct).
- Exporting HDR images fails in Debug builds (works in Release).

## Code style

```bash
bash data/check-style.sh
```

Checks for tabs, CRLF, trailing whitespace, and missing spaces around `if(`, `for(`, etc.

## Platform builds

| Platform | Script | Package manager |
|----------|--------|-----------------|
| Linux | `scripts/build-linux.sh` | apt |
| macOS | `scripts/build-macos.sh` | Homebrew |
| Windows | `scripts/build-msys2.sh` | MSYS2 UCRT64 pacboy |

vcpkg (`vcpkg.json`) is only used for the native MSVC path, not the build scripts above.
