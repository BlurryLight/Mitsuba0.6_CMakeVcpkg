# On MinGW/MSYS2, skip find_package(collada_dom) entirely — the collada-dom
# CMake config hard-pins Boost to a specific version and pulls in defines
# (BOOST_ALL_DYN_LINK) that conflict with the project's Boost imported
# targets. Use the manual fallback below instead.
if(MINGW OR MSYS)
    set(_skip_collada_config TRUE)
else()
    set(_skip_collada_config FALSE)
endif()

if(NOT _skip_collada_config)
    find_package(collada_dom QUIET)
endif()

if(collada_dom_FOUND AND NOT _skip_collada_config)
    string(STRIP "${COLLADA_DOM_CXX_FLAGS}" _flags)
    separate_arguments(_flags NATIVE_COMMAND "${_flags}")
    set(COLLADA_DOM_COMPILE_DEFS)
    foreach(_flag ${_flags})
        if(_flag MATCHES "^-D(.+)$")
            list(APPEND COLLADA_DOM_COMPILE_DEFS "${CMAKE_MATCH_1}")
        endif()
    endforeach()
    find_library(COLLADA_DOM_LIBRARY
        NAMES collada-dom2.5-dp collada-dom2.5
        HINTS ${COLLADA_DOM_LIBRARY_DIRS}
    )
    set(COLLADA_DOM_INCLUDE_DIRS ${COLLADA_DOM_INCLUDE_DIRS})
    set(COLLADA_DOM_LIBRARIES ${COLLADA_DOM_LIBRARY})
    # Add versioned include path (collada-dom 2.5 puts headers under 1.4/)
    find_path(COLLADA_DOM_INCLUDE_14
        NAMES dom/domCOLLADA.h
        HINTS ${COLLADA_DOM_INCLUDE_DIRS}/1.4
    )
    if(COLLADA_DOM_INCLUDE_14)
        list(APPEND COLLADA_DOM_INCLUDE_DIRS ${COLLADA_DOM_INCLUDE_14})
    endif()
else()
    # Manual fallback. The collada-dom CMake config that ships with
    # MSYS2's mingw-w64-ucrt-x86_64-collada-dom package pins Boost to an
    # exact older version (1.89) which the system does not have, so the
    # find_package(collada_dom QUIET) call above fails. The library,
    # headers and CMake config are still perfectly usable -- we just have
    # to locate them ourselves. Search the standard system locations
    # rather than hardcoding /usr/include so MSYS2 (/ucrt64), Homebrew
    # (/opt/homebrew), and Debian (/usr) all work.
    set(_converter_hints
        ENV COLLADA_DOM_DIR
        ENV COLLADA_DOM_ROOT
        ${COLLADA_DOM_DIR}
        ${COLLADA_DOM_ROOT}
    )
    find_path(COLLADA_DOM_INCLUDE_14
        NAMES dom/domCOLLADA.h
        HINTS ${_converter_hints}
        PATH_SUFFIXES
            include/collada-dom2.5/1.4
            include/collada-dom2.5/1.5
    )
    find_path(COLLADA_DOM_INCLUDE_BASE
        NAMES dae.h
        HINTS ${_converter_hints}
        PATH_SUFFIXES
            include/collada-dom2.5
    )
    find_library(COLLADA_DOM_LIBRARY
        NAMES collada-dom2.5-dp collada-dom2.5
        HINTS ${_converter_hints}
        PATH_SUFFIXES lib
    )
    if(NOT COLLADA_DOM_INCLUDE_14 OR NOT COLLADA_DOM_LIBRARY)
        message(STATUS "collada-dom not found — skipping mtsimport converter")
        return()
    endif()
    set(COLLADA_DOM_INCLUDE_DIRS ${COLLADA_DOM_INCLUDE_14} ${COLLADA_DOM_INCLUDE_BASE})
    set(COLLADA_DOM_LIBRARIES ${COLLADA_DOM_LIBRARY})
    set(COLLADA_DOM_COMPILE_DEFS
        COLLADA_DOM_SUPPORT141
        COLLADA_DOM_SUPPORT150
        COLLADA_DOM_DAEFLOAT_IS64
        COLLADA_DOM_USING_141
        DOM_DYNAMIC
    )
endif()

add_executable(mtsimport
    mtsimport.cpp
    converter.cpp
    collada.cpp
    obj.cpp
)
set_target_properties(mtsimport PROPERTIES WIN32_EXECUTABLE FALSE)

target_include_directories(mtsimport PRIVATE
    ${COLLADA_DOM_INCLUDE_DIRS}
)

target_compile_definitions(mtsimport PRIVATE
    ${COLLADA_DOM_COMPILE_DEFS}
    COLLADA_DOM_USING_141
)

target_link_libraries(mtsimport
    mitsuba-python
    mitsuba-hw
    ${XERCES_LIB_LIST}
    ${COLLADA_DOM_LIBRARIES}
)
