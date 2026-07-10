cmake_minimum_required(VERSION 3.15) # Required for reliable vcpkg and modern CMake target support.

project(Mitsuba)

# --- Local CMake module path -------------------------------------------------
# Bundled Find<Package>.cmake modules let this project build with system
# (apt) packages, not just vcpkg/brew provided ones. Insert BEFORE the
# first find_package() call below.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- Project setup ---
if(NOT COMPILE_THREAD)
    include(ProcessorCount)
    ProcessorCount(COMPILE_THREAD)
    message(STATUS "Using ${COMPILE_THREAD} threads for parallel builds.")
endif()

if(MSVC)
  add_compile_options(/MP) # Enable parallel compilation in Visual Studio.
endif()

if(APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")
    set(CMAKE_CXX_VISIBILITY_PRESET hidden)
    set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
    # Silence the avalanche of deprecation warnings on macOS SDK headers.
    add_compile_options(-Wno-deprecated-declarations -Wno-unknown-pragmas)
endif()

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

set(MITSUBA_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})
file(TO_CMAKE_PATH "${MITSUBA_ROOT_DIR}" MITSUBA_ROOT_DIR)
add_compile_definitions(MITSUBA_ROOT_DIR="${MITSUBA_ROOT_DIR}")

set(MITSUBA_BIN_DIR ${CMAKE_BINARY_DIR}/bin)
file(TO_CMAKE_PATH "${MITSUBA_BIN_DIR}" MITSUBA_BIN_DIR)
add_compile_definitions(MITSUBA_BIN_DIR="${MITSUBA_BIN_DIR}")


file(MAKE_DIRECTORY ${MITSUBA_BIN_DIR})

# Keep runtime outputs in a single bin directory so tools can find plugins and data files.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${MITSUBA_BIN_DIR})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# --- Dependencies supplied by vcpkg ---
# The vcpkg toolchain resolves these packages and exposes imported targets.

find_package(Qt5 COMPONENTS Core Gui Widgets Xml Network OpenGL XmlPatterns REQUIRED)
find_package(ZLIB REQUIRED)
find_package(OpenEXR REQUIRED)
# Let vcpkg select the Boost version to avoid conflicts with local CMake overrides.
find_package(Boost REQUIRED COMPONENTS filesystem thread chrono date_time atomic)
find_package(Imath REQUIRED)
find_package(libjpeg-turbo REQUIRED)
find_package(XercesC REQUIRED)
find_package(PNG REQUIRED)
find_package(GLEW REQUIRED)
find_package(Eigen3 REQUIRED)
find_package(FFTW3 REQUIRED)
# FFTW3f (single-precision) is found by the same FindFFTW3.cmake module above.

# --- FFTW3 imported targets (vcpkg provides these; Homebrew's package does not) ---
if(NOT TARGET FFTW3::fftw3)
    find_library(FFTW3_LIB NAMES fftw3 HINTS "${FFTW3_LIBRARY_DIRS}" REQUIRED)
    add_library(FFTW3::fftw3 UNKNOWN IMPORTED)
    set_target_properties(FFTW3::fftw3 PROPERTIES
        IMPORTED_LOCATION "${FFTW3_LIB}"
        INTERFACE_INCLUDE_DIRECTORIES "${FFTW3_INCLUDE_DIRS}")
endif()
if(NOT TARGET FFTW3::fftw3f)
    find_library(FFTW3f_LIB NAMES fftw3f HINTS "${FFTW3f_LIBRARY_DIRS}" REQUIRED)
    add_library(FFTW3::fftw3f UNKNOWN IMPORTED)
    set_target_properties(FFTW3::fftw3f PROPERTIES
        IMPORTED_LOCATION "${FFTW3f_LIB}"
        INTERFACE_INCLUDE_DIRECTORIES "${FFTW3f_INCLUDE_DIRS}")
endif()

# --- Python integration ---
find_package(Python COMPONENTS Interpreter Development REQUIRED)
set(PYTHON_VERSION_WITHOUT_DOT "python${Python_VERSION_MAJOR}${Python_VERSION_MINOR}")
message(STATUS "Found Python: ${Python_EXECUTABLE} (version ${Python_VERSION})")
# Match Boost.Python to the Python version found above.
find_package(Boost REQUIRED COMPONENTS ${PYTHON_VERSION_WITHOUT_DOT})


# --- Include paths ---
# Imported targets provide dependency include paths; only the project headers are added globally.
include_directories("${MITSUBA_ROOT_DIR}/include")
# --- OpenEXR/Imath compatibility include paths ---
# Modern OpenEXR (>=3) and Imath ship their headers under versioned subdirectories.
if(EXISTS "${OpenEXR_INCLUDE_DIRS}/OpenEXR")
    include_directories("${OpenEXR_INCLUDE_DIRS}")
endif()
if(EXISTS "${Imath_DIR}/../../../include/Imath")
    include_directories("${Imath_DIR}/../../../include")
endif()

# --- Mitsuba compile definitions ---
set(Mitsuba_Float_Percision "SINGLE_PRECISION")
set(Mitsuba_Spectrum_Samples "SPECTRUM_SAMPLES=3")
set(Mitsuba_Debug "MTS_DEBUG")

if(MSVC)
    set(Mitsuba_OpenEXR "OPENEXR_DLL")
    set(Mitsuba_SSE "MTS_SSE")
    set(Mitsuba_Has_Coherent_RT "MTS_HAS_COHERENT_RT")
    set(MITS_MSVC_DEBUG "DEBUG")
    set(MITS_MSVC_CONSOLE "_CONSOLE")
else()
    # Intel Embree (required by MTS_HAS_COHERENT_RT) is not a vcpkg dependency and
    # SSE intrinsics are not portable to Apple Silicon / non-x86 builds.
    set(Mitsuba_OpenEXR "")
    set(Mitsuba_SSE "")
    set(Mitsuba_Has_Coherent_RT "")
    set(MITS_MSVC_DEBUG "")
    set(MITS_MSVC_CONSOLE "")
endif()

add_compile_definitions(
    ${Mitsuba_Float_Percision}
    ${Mitsuba_Spectrum_Samples}
    ${Mitsuba_SSE}
    ${Mitsuba_Has_Coherent_RT}
    ${Mitsuba_Debug}
    ${Mitsuba_OpenEXR}
    MTS_HAS_LIBPNG=1
    MTS_HAS_LIBJPEG=1
    MTS_HAS_OPENEXR=1
    MTS_HAS_FFTW=1
    ${MITS_MSVC_DEBUG}
    ${MITS_MSVC_CONSOLE}
)

# --- OpenMP ---
find_package(OpenMP)
if(OpenMP_CXX_FOUND)
    if(MSVC)
        add_compile_options(/openmp)
    else()
        add_compile_options(${OpenMP_CXX_FLAGS})
    endif()
    set(MITSUBA_OPENMP_LIBS ${OpenMP_CXX_LIBRARIES})
else()
    set(MITSUBA_OPENMP_LIBS "")
endif()

if(MSVC)
    add_link_options(/FIXED:NO /SUBSYSTEM:CONSOLE /NODEFAULTLIB:LIBCMT /MANIFEST)
endif()

# --- Shared library lists ---
# Subdirectory CMake files consume these variables when linking Mitsuba components.
if(WIN32)
    set(BASE_LIB_LIST ws2_32 psapi Eigen3::Eigen)
    set(GL_LIB_LIST opengl32 glu32 GLEW::glew gdi32 user32)
elseif(APPLE)
    set(BASE_LIB_LIST Eigen3::Eigen)
    set(GL_LIB_LIST "-framework OpenGL" "-framework Cocoa" "-framework IOKit" GLEW::glew)
else()
    set(BASE_LIB_LIST Eigen3::Eigen pthread)
    set(GL_LIB_LIST GL GLEW::glew GLU X11 Xxf86vm)
endif()
set(QT_LIB_LIST Qt5::Core Qt5::Gui Qt5::Widgets Qt5::Xml Qt5::Network Qt5::OpenGL Qt5::XmlPatterns)
set(OPENEXR_LIB_LIST OpenEXR::OpenEXR)
set(BOOST_LIB_LIST Boost::${PYTHON_VERSION_WITHOUT_DOT} Boost::filesystem Boost::thread)
set(JEPG_LIB_LIST libjpeg-turbo::jpeg)
set(XERCES_LIB_LIST XercesC::XercesC)
set(PNG_LIB_LIST PNG::PNG)
set(FFTW_LIB_LIST FFTW3::fftw3f FFTW3::fftw3)

# --- FFTW3 threads support (needed for fftw_init_threads etc.) -------------
# vcpkg's FFTW3Config.cmake transitively links the threads flavour, but
# Homebrew/apt do not — resolve the threads library explicitly.
if(NOT APPLE AND NOT WIN32)
    find_library(FFTW3_THREADS_LIB
        NAMES fftw3_threads
        HINTS "${FFTW3_LIBRARY_DIRS}" "${FFTW3f_LIBRARY_DIRS}"
        PATH_SUFFIXES lib lib64
    )
    if(FFTW3_THREADS_LIB)
        list(APPEND FFTW_LIB_LIST "${FFTW3_THREADS_LIB}")
    endif()
endif()

# --- OpenMP linkage ---------------------------------------------------------
# MITSUBA_OPENMP_LIBS is set by the find_package(OpenMP) block above, but the
# executables and shared libraries need the runtime in their link line as
# well. Append it to BASE_LIB_LIST so every subdirectory picks it up.
if(MITSUBA_OPENMP_LIBS)
    list(APPEND BASE_LIB_LIST ${MITSUBA_OPENMP_LIBS})
endif()


# --- Core targets ---
add_subdirectory(src/libcore)
add_subdirectory(src/librender)
add_subdirectory(src/libhw)
add_subdirectory(src/libbidir)
add_subdirectory(src/libpython)
add_subdirectory(src/mitsuba)

# --- Converter (COLLADA/OBJ -> XML, requires collada-dom) ---
add_subdirectory(src/converter)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
# The Qt previewer depends on the now-defunct BWToolkitFramework on macOS, so
# only build it on platforms where we know it works (Windows + Linux).
if(NOT APPLE)
    add_subdirectory(src/mtsgui)
endif()
set(CMAKE_AUTOMOC OFF)
set(CMAKE_AUTORCC OFF)
set(CMAKE_AUTOUIC OFF)

set(MITSUBA_PLUGIN_BIN_DIR ${MITSUBA_BIN_DIR}/plugins)
file(MAKE_DIRECTORY ${MITSUBA_PLUGIN_BIN_DIR})

message(STATUS "MITSUBA_BIN_DIR = ${MITSUBA_BIN_DIR}")
message(STATUS "MITSUBA_PLUGIN_BIN_DIR = ${MITSUBA_PLUGIN_BIN_DIR}")

# Plugin targets are added after this point and should be emitted under bin/plugins.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${MITSUBA_PLUGIN_BIN_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${MITSUBA_PLUGIN_BIN_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL ${MITSUBA_PLUGIN_BIN_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO ${MITSUBA_PLUGIN_BIN_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE ${MITSUBA_PLUGIN_BIN_DIR})
# On macOS/Linux, add_library(SHARED) emits to LIBRARY_OUTPUT_DIRECTORY, not RUNTIME.
if(NOT WIN32)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${MITSUBA_PLUGIN_BIN_DIR})
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${MITSUBA_PLUGIN_BIN_DIR})
    # Match the original SCons build (SHLIBPREFIX='') so plugin files are
    # named 'foo.dylib' rather than 'libfoo.dylib'. Mitsuba's PluginManager
    # resolves plugins by short name without a 'lib' prefix.
    set(CMAKE_SHARED_LIBRARY_PREFIX "")
endif()
add_subdirectory(src/utils)
add_subdirectory(src/bsdfs)
add_subdirectory(src/phase)
add_subdirectory(src/shapes)
add_subdirectory(src/samplers)
add_subdirectory(src/rfilters)
add_subdirectory(src/films)
add_subdirectory(src/sensors)
add_subdirectory(src/emitters)
add_subdirectory(src/medium)
add_subdirectory(src/volume)
add_subdirectory(src/subsurface)
add_subdirectory(src/textures)
add_subdirectory(src/integrators)
add_subdirectory(src/tests)

# Restore the default runtime directory here if more non-plugin targets are added later.
# set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${MITSUBA_BIN_DIR})

# --- Runtime data files ---
file(MAKE_DIRECTORY ${MITSUBA_ROOT_DIR}/data)
file(COPY ${MITSUBA_ROOT_DIR}/data/schema DESTINATION ${MITSUBA_BIN_DIR}/data/)
file(COPY ${MITSUBA_ROOT_DIR}/data/ior DESTINATION ${MITSUBA_BIN_DIR}/data/)
file(COPY ${MITSUBA_ROOT_DIR}/data/microfacet DESTINATION ${MITSUBA_BIN_DIR}/data/)

# --- Deployment note ---
# vcpkg copies dependent DLLs into MITSUBA_BIN_DIR during the build.
# If Qt platform plugins are missing at runtime, deploy the executable with Qt's windeployqt tool.
