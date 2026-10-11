cmake_minimum_required(VERSION 3.20)

project(0rhxPlayer VERSION 1.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml Svg Widgets)

set(PROJECT_SOURCES
    src/main.cpp
    src/core/PathManager.h
    src/core/PathManager.cpp
    src/audio/AudioEngine.h
    src/audio/AudioEngineWorker.h
    src/audio/AudioEngine.cpp
    src/ui/SvgIcon.h
    src/ui/SvgIcon.cpp
    src/ui/RoundedImage.h
    src/ui/RoundedImage.cpp
    src/model/TrackItem.h
    src/model/TrackModel.h
    src/model/TrackModel.cpp
    src/model/AlbumItem.h
    src/model/AlbumModel.h
    src/model/AlbumModel.cpp
    src/model/LyricItem.h
    src/model/LyricModel.h
    src/model/LyricModel.cpp
    src/model/PlaylistItem.h
    src/model/PlaylistModel.h
    src/model/PlaylistModel.cpp
    src/library/LibraryManager.h
    src/library/LibraryScanWorker.h
    src/library/LibraryManager.cpp
    src/config/ConfigManager.h
    src/config/ConfigManager.cpp
    resources.qrc
)

if (WIN32)
    list(APPEND PROJECT_SOURCES app.rc)
    qt_add_executable(0rhxPlayer WIN32
        ${PROJECT_SOURCES}
    )
else()
    qt_add_executable(0rhxPlayer
        ${PROJECT_SOURCES}
    )
endif()

# Ensure output target binary is strictly named '0rhxPlayer'
set_target_properties(0rhxPlayer PROPERTIES
    OUTPUT_NAME "0rhxPlayer"
)

# Detect architecture for BASS libraries
if(NOT BASS_TARGET_ARCH)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64|ARM64)")
        set(BASS_TARGET_ARCH "arm64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64|x64)")
        set(BASS_TARGET_ARCH "x64")
    elseif(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64|ARM64)")
        set(BASS_TARGET_ARCH "arm64")
    else()
        set(BASS_TARGET_ARCH "x64")
    endif()
endif()

set(BASS_LIBRARIES)
set(PLATFORM_LIBS)

if(WIN32)
    set(BASS_PLATFORM_DIR "win-${BASS_TARGET_ARCH}")
    set(BASS_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/${BASS_PLATFORM_DIR}/lib")
    set(BASS_BIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/${BASS_PLATFORM_DIR}/bin")

    list(APPEND BASS_LIBRARIES
        ${BASS_LIB_DIR}/bass.lib
        ${BASS_LIB_DIR}/bassflac.lib
    )
    if(EXISTS "${BASS_LIB_DIR}/basswasapi.lib")
        list(APPEND BASS_LIBRARIES ${BASS_LIB_DIR}/basswasapi.lib)
    endif()

    list(APPEND PLATFORM_LIBS dwmapi uxtheme)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(BASS_PLATFORM_DIR "linux-${BASS_TARGET_ARCH}")
    set(BASS_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/${BASS_PLATFORM_DIR}/lib")
    set(BASS_BIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/${BASS_PLATFORM_DIR}/lib")

    list(APPEND BASS_LIBRARIES
        ${BASS_LIB_DIR}/libbass.so
        ${BASS_LIB_DIR}/libbassflac.so
    )

    set_target_properties(0rhxPlayer PROPERTIES
        BUILD_RPATH "$ORIGIN"
        INSTALL_RPATH "$ORIGIN"
    )
else()
    message(FATAL_ERROR "Unsupported target platform: ${CMAKE_SYSTEM_NAME}. Only Windows and Linux are supported.")
endif()

message(STATUS "Selected BASS platform directory: ${BASS_PLATFORM_DIR}")

target_include_directories(0rhxPlayer PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/include
)

target_link_libraries(0rhxPlayer PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::Svg
    Qt6::Widgets
    ${BASS_LIBRARIES}
    ${PLATFORM_LIBS}
)

# Copy runtime BASS libraries to output directory
if(WIN32)
    file(GLOB BASS_RUNTIME_FILES "${BASS_BIN_DIR}/*.dll")
else()
    file(GLOB BASS_RUNTIME_FILES "${BASS_LIB_DIR}/*.so")
endif()

add_custom_command(TARGET 0rhxPlayer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${BASS_RUNTIME_FILES}
        $<TARGET_FILE_DIR:0rhxPlayer>
    COMMENT "Copying BASS runtime libraries (${BASS_PLATFORM_DIR})..."
)

# Copy runtime font assets to output directory
add_custom_command(TARGET 0rhxPlayer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:0rhxPlayer>/assets/fonts
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_SOURCE_DIR}/assets/fonts
        $<TARGET_FILE_DIR:0rhxPlayer>/assets/fonts
    COMMENT "Copying font assets to output directory..."
)

# Copy translation files to output directory
add_custom_command(TARGET 0rhxPlayer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:0rhxPlayer>/translations
    COMMAND ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_SOURCE_DIR}/translations/0rhxplayer_zh_CN.qm
        ${CMAKE_CURRENT_SOURCE_DIR}/translations/0rhxplayer_ja_JP.qm
        $<TARGET_FILE_DIR:0rhxPlayer>/translations/
    COMMENT "Copying translation files to output directory..."
)

# Automated windeployqt deployment step (local development only; CI packages via scripts/package.ps1)
find_program(WINDEPLOYQT_EXECUTABLE NAMES windeployqt HINTS "C:/Users/RinCynar/Qt/6.11.2/mingw_64/bin" "${Qt6_DIR}/../../../bin")
if(WINDEPLOYQT_EXECUTABLE AND NOT DEFINED ENV{CI})
    add_custom_command(TARGET 0rhxPlayer POST_BUILD
        COMMAND "${WINDEPLOYQT_EXECUTABLE}"
            --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/src/qml"
            --compiler-runtime
            "$<TARGET_FILE:0rhxPlayer>"
        COMMENT "Running windeployqt to deploy runtime dependencies..."
    )
endif()
