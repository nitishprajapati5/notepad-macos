cmake_minimum_required(VERSION 3.20)
project(Notepad OBJCXX CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64")
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0")

set(SCI_ROOT "${CMAKE_SOURCE_DIR}/scintilla")

# -----------------------------------------------------------------------------
# Scintilla Core & Cocoa Platform Layer
# -----------------------------------------------------------------------------
file(GLOB SCI_CORE_SRCS "${SCI_ROOT}/src/*.cxx")

set(SCI_COCOA_SRCS
    "${SCI_ROOT}/cocoa/PlatCocoa.mm"
    "${SCI_ROOT}/cocoa/ScintillaCocoa.mm"
    "${SCI_ROOT}/cocoa/ScintillaView.mm"
    "${SCI_ROOT}/cocoa/InfoBar.mm"
)

add_library(scintilla STATIC ${SCI_CORE_SRCS} ${SCI_COCOA_SRCS})

target_include_directories(scintilla PUBLIC
    "${SCI_ROOT}/include"
    "${SCI_ROOT}/src"
    "${SCI_ROOT}/cocoa"
)

target_compile_definitions(scintilla PRIVATE
    SCI_NAMESPACE
    NDEBUG
)

set_source_files_properties(${SCI_COCOA_SRCS} PROPERTIES
    COMPILE_FLAGS "-fobjc-arc"
)

# -----------------------------------------------------------------------------
# Notepad Application Bundle
# -----------------------------------------------------------------------------
file(GLOB APP_SRCS "src/*.mm")
file(GLOB APP_HEADERS "src/*.h")

add_executable(Notepad MACOSX_BUNDLE ${APP_SRCS} ${APP_HEADERS})

set_target_properties(Notepad PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/resources/Info.plist"
    MACOSX_BUNDLE_BUNDLE_NAME "Notepad"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.notepad.mac"
)

target_include_directories(Notepad PRIVATE
    "${CMAKE_SOURCE_DIR}/src"
    "${SCI_ROOT}/include"
    "${SCI_ROOT}/src"
    "${SCI_ROOT}/cocoa"
)

target_compile_definitions(Notepad PRIVATE
    SCI_NAMESPACE
    NDEBUG
)

set_source_files_properties(${APP_SRCS} PROPERTIES
    COMPILE_FLAGS "-fobjc-arc"
)

target_link_libraries(Notepad PRIVATE
    scintilla
    "-framework Cocoa"
    "-framework QuartzCore"
)

add_custom_command(TARGET Notepad POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/scintilla/cocoa/res"
        "$<TARGET_BUNDLE_DIR:Notepad>/Contents/Resources"
    COMMENT "Copying Scintilla Cocoa resources into bundle")
