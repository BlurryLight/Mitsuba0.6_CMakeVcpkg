file(GLOB PYTHON_SRC *.h *.cpp)

add_library(mitsuba-python SHARED ${PYTHON_SRC})
target_compile_definitions(mitsuba-python PRIVATE -DMTS_BUILD_MODULE=MTS_MODULE_PYTHON -DHAVE_SNPRINTF)
if(MSVC)
    target_compile_options(mitsuba-python PRIVATE /bigobj)
endif()
target_link_libraries(mitsuba-python mitsuba-bidir Python::Python ${BOOST_LIB_LIST} ${XERCES_LIB_LIST})
