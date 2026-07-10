find_package(collada_dom QUIET)

if(collada_dom_FOUND)
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
    # Manual fallback
    find_path(COLLADA_DOM_INCLUDE_14
        NAMES dom/domCOLLADA.h
        PATHS /usr/include/collada-dom2.5/1.4
        NO_DEFAULT_PATH
    )
    find_path(COLLADA_DOM_INCLUDE_BASE
        NAMES dae.h
        PATHS /usr/include/collada-dom2.5
        NO_DEFAULT_PATH
    )
    find_library(COLLADA_DOM_LIBRARY
        NAMES collada-dom2.5-dp collada-dom2.5
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
