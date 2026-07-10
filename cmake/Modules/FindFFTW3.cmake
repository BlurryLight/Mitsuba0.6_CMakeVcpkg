# FindFFTW3.cmake
# Locate the system FFTW3 installation (both double- and single-precision).
#
# Defines:
#   FFTW3_FOUND           - true if both libraries are found
#   FFTW3::fftw3          - imported target for the double-precision library
#   FFTW3::fftw3f         - imported target for the single-precision library
#   FFTW3_LIBRARIES       - list of both libraries
#   FFTW3_INCLUDE_DIRS    - include directory
#   FFTW3_LIBRARY_DIRS    - library directories
#   FFTW3_VERSION_STRING  - detected version (best effort)
#
# Honours the standard hints/vars: FFTW3_ROOT, FFTW3_INC_DIR, FFTW3_LIB_DIR,
# FFTW3f_ROOT, etc.

include(FindPackageHandleStandardArgs)
include(SelectLibraryConfigurations)

# --- hints / paths -----------------------------------------------------------
set(_FFTW3_HINTS
    ENV FFTW3_ROOT
    ENV FFTW3DIR
    ENV FFTW3_PATH
    ${FFTW3_ROOT}
    ${FFTW3_INC_DIR}
)
set(_FFTW3f_HINTS
    ENV FFTW3f_ROOT
    ENV FFTW3fDIR
    ENV FFTW3f_PATH
    ${FFTW3f_ROOT}
    ${FFTW3f_INC_DIR}
)

# --- header (use the double-precision one to find the include dir) ----------
find_path(FFTW3_INCLUDE_DIR
    NAMES fftw3.h
    HINTS ${_FFTW3_HINTS}
    PATH_SUFFIXES include
)
mark_as_advanced(FFTW3_INCLUDE_DIR)

# --- libraries ---------------------------------------------------------------
find_library(FFTW3_LIBRARY
    NAMES fftw3 libfftw3
    HINTS ${_FFTW3_HINTS}
    PATH_SUFFIXES lib lib64
)
find_library(FFTW3f_LIBRARY
    NAMES fftw3f libfftw3f
    HINTS ${_FFTW3f_HINTS}
    PATH_SUFFIXES lib lib64
)
mark_as_advanced(FFTW3_LIBRARY FFTW3f_LIBRARY)

# --- find_package_handle_standard_args ---------------------------------------
find_package_handle_standard_args(FFTW3
    REQUIRED_VARS FFTW3_LIBRARY FFTW3f_LIBRARY FFTW3_INCLUDE_DIR
    VERSION_VAR   FFTW3_VERSION_STRING
)
unset(FFTW3_VERSION_STRING CACHE)

# --- imported targets --------------------------------------------------------
if(FFTW3_FOUND AND NOT TARGET FFTW3::fftw3)
    add_library(FFTW3::fftw3  UNKNOWN IMPORTED)
    set_target_properties(FFTW3::fftw3 PROPERTIES
        IMPORTED_LOCATION             "${FFTW3_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${FFTW3_INCLUDE_DIR}")
    add_library(FFTW3::fftw3f UNKNOWN IMPORTED)
    set_target_properties(FFTW3::fftw3f PROPERTIES
        IMPORTED_LOCATION             "${FFTW3f_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${FFTW3_INCLUDE_DIR}")
endif()

# --- compatibility output variables (used by the project) --------------------
set(FFTW3_LIBRARIES   "${FFTW3_LIBRARY};${FFTW3f_LIBRARY}")
set(FFTW3_LIBRARY_DIRS "")
set(FFTW3_INCLUDE_DIRS "${FFTW3_INCLUDE_DIR}")
