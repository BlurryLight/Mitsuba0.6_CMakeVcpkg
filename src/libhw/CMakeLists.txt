file(GLOB HW_INC "${MITSUBA_ROOT_DIR}/include/mitsuba/hw/*.h" "${MITSUBA_ROOT_DIR}/include/mitsuba/hw/*.inl")
file(GLOB HW_CPP "session.cpp" "device.cpp" "gputexture.cpp" "gpugeometry.cpp"
				"gpuprogram.cpp" "renderer.cpp" "glrenderer.cpp" "glprogram.cpp"
				"glgeometry.cpp" "gltexture.cpp" "gpusync.cpp" "glsync.cpp"
				"vpl.cpp" "font.cpp" "viewer.cpp" "basicshader.cpp" "shadow.cpp")

if(WIN32)
    list(APPEND HW_CPP "wglsession.cpp" "wgldevice.cpp" "wglrenderer.cpp")
elseif(APPLE)
    file(GLOB HW_CPP_MM "nsgl*.mm")
else()
    list(APPEND HW_CPP "glxdevice.cpp" "glxrenderer.cpp" "x11device.cpp" "x11session.cpp")
endif()

add_library(mitsuba-hw SHARED ${HW_INC} ${HW_CPP} ${HW_CPP_MM})
target_compile_definitions(mitsuba-hw PRIVATE -DMTS_BUILD_MODULE=MTS_MODULE_HW)
target_include_directories(mitsuba-hw PRIVATE ${GLEW_INCLUDE_DIRS})
if(APPLE)
    # Original Mitsuba 0.6 nsgl* sources predate ARC; keep them on the legacy runtime.
    set_source_files_properties(${HW_CPP_MM} PROPERTIES COMPILE_FLAGS "-fno-objc-arc")
endif()
target_link_libraries(mitsuba-hw mitsuba-render ${BASE_LIB_LIST} ${GL_LIB_LIST})
