if(WIN32)
    if(MSVC)
        # MSVC links the .rc into the binary via the IDE; wmain_stub provides
        # the wmain() entry point so the rest of the tree can keep using
        # #if !defined(__MSVC__) for its main() definition.
        file(GLOB DATA_FILES
            "${MITSUBA_ROOT_DIR}/data/windows/wmain_stub.cpp"
            "${MITSUBA_ROOT_DIR}/data/windows/mitsuba_res.rc")
    else()
        # MinGW: rely on the regular main() defined in mitsuba.cpp / mtssrv.cpp
        # / mtsutil.cpp. The .rc file is not consumed (CMake's RC support is
        # MSVC-only) and wmain_stub is MSVC-only too.
        set(DATA_FILES "")
    endif()
else()
    set(DATA_FILES "")
endif()

# mitsuba's getopt is a Visual Studio shim. On MinGW the libc already exports
# getopt, so skip the local copy.
if(MINGW)
    set(MITSUBA_GETOPT_LIB "")
else()
    set(MITSUBA_GETOPT_LIB getopt)
endif()

add_executable(mitsuba "${MITSUBA_ROOT_DIR}/include/mitsuba/mitsuba.h" "mitsuba.cpp" ${DATA_FILES})
target_link_libraries(mitsuba ${MITSUBA_GETOPT_LIB} mitsuba-python ${XERCES_LIB_LIST})

add_executable(mtssrv "mtssrv.cpp" ${DATA_FILES})
target_link_libraries(mtssrv ${MITSUBA_GETOPT_LIB} mitsuba-python ${XERCES_LIB_LIST})

add_executable(mtsutil "mtsutil.cpp" ${DATA_FILES})
target_link_libraries(mtsutil ${MITSUBA_GETOPT_LIB} mitsuba-python ${XERCES_LIB_LIST})

