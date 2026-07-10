# Findlibjpeg-turbo.cmake
# Locate the system libjpeg-turbo (or compatible libjpeg) installation.
#
# Defines:
#   libjpeg-turbo_FOUND   - true on success
#   libjpeg-turbo::jpeg   - imported target
#   libjpeg-turbo_INCLUDE_DIRS / libjpeg-turbo_LIBRARIES
#
# libjpeg-turbo is ABI-compatible with libjpeg; on Debian/Ubuntu, the package
# `libjpeg-turbo8-dev` installs headers as <jerror.h>, <jpeglib.h>, etc., and
# a libjpeg.so (drop-in replacement).

include(FindPackageHandleStandardArgs)
include(SelectLibraryConfigurations)

# --- hints -------------------------------------------------------------------
set(_libjpeg-turbo_HINTS
    ENV libjpeg-turbo_ROOT
    ENV LIBJPEGTURBO_ROOT
    ${libjpeg-turbo_ROOT}
)

# --- header ------------------------------------------------------------------
find_path(libjpeg-turbo_INCLUDE_DIR
    NAMES jpeglib.h
    HINTS ${_libjpeg-turbo_HINTS}
    PATH_SUFFIXES include
)
mark_as_advanced(libjpeg-turbo_INCLUDE_DIR)

# --- library (prefer the standard libjpeg API) ------------------------------
# The project links against the classical libjpeg API (jpeg_create_decompress
# etc.). MSYS2 / Homebrew ship both libjpeg.a (the libjpeg API) and
# libturbojpeg.a (the TurboJPEG C API), so we look for the standard one
# explicitly. vcpkg only ships the libjpeg-style library, so this order
# still works there.
find_library(libjpeg-turbo_LIBRARY
    NAMES jpeg jpeg-turbo turbojpeg
    HINTS ${_libjpeg-turbo_HINTS}
    PATH_SUFFIXES lib lib64
)
mark_as_advanced(libjpeg-turbo_LIBRARY)

# --- standard args -----------------------------------------------------------
find_package_handle_standard_args(libjpeg-turbo
    REQUIRED_VARS libjpeg-turbo_LIBRARY libjpeg-turbo_INCLUDE_DIR
    VERSION_VAR   libjpeg-turbo_VERSION_STRING
)
unset(libjpeg-turbo_VERSION_STRING CACHE)

# --- imported target ---------------------------------------------------------
if(libjpeg-turbo_FOUND AND NOT TARGET libjpeg-turbo::jpeg)
    add_library(libjpeg-turbo::jpeg UNKNOWN IMPORTED)
    set_target_properties(libjpeg-turbo::jpeg PROPERTIES
        IMPORTED_LOCATION             "${libjpeg-turbo_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${libjpeg-turbo_INCLUDE_DIR}")
endif()

set(libjpeg-turbo_LIBRARIES   "${libjpeg-turbo_LIBRARY}")
set(libjpeg-turbo_INCLUDE_DIRS "${libjpeg-turbo_INCLUDE_DIR}")
