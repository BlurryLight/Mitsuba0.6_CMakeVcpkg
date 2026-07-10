file(GLOB GUI_RES *.ui *.qrc)
file(GLOB GUI_INC *.h)
file(GLOB GUI_CPP *.cpp)
if(APPLE)
    # Cocoa-specific headers/sources live in a subdirectory so AUTOMOC on
    # non-Apple platforms does not see the Q_OBJECT declaration in
    # previewsettingsdlg_cocoa.h (whose destructor is defined in the .mm).
    file(GLOB GUI_MM "macos/*.mm")
    set(APPLE_INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/macos")
else()
    set(GUI_MM "")
    set(APPLE_INCLUDE_DIRS "")
endif()

add_executable(mtsgui ${GUI_RES} ${GUI_INC} ${GUI_CPP} ${GUI_MM})
target_compile_definitions(mtsgui PRIVATE -DMTS_CUSTOM_QTMAIN -DMTSGUI_STATIC_QFILEDIALOG=1)
target_include_directories(mtsgui PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}/mtsgui_autogen/include
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${APPLE_INCLUDE_DIRS})
if(APPLE)
    set_source_files_properties(${GUI_MM} PROPERTIES COMPILE_FLAGS "-fno-objc-arc")
    find_library(SECURITY_FRAMEWORK Security)
    find_library(CARBON_FRAMEWORK Carbon)
    find_library(APPKIT_FRAMEWORK_GUI AppKit)
    find_library(APPLICATIONSERVICES_FRAMEWORK ApplicationServices)
    target_link_libraries(mtsgui mitsuba-python ${QT_LIB_LIST}
        ${SECURITY_FRAMEWORK} ${CARBON_FRAMEWORK} ${APPKIT_FRAMEWORK_GUI} ${APPLICATIONSERVICES_FRAMEWORK})
elseif(WIN32)
    target_link_libraries(mtsgui mitsuba-python ${GL_LIB_LIST} ${QT_LIB_LIST} shell32)
else()
    target_link_libraries(mtsgui mitsuba-python ${QT_LIB_LIST})
endif()
