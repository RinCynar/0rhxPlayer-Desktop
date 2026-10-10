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
endif()

qt_add_executable(0rhxPlayer WIN32
    ${PROJECT_SOURCES}
)

# Ensure output target binary is strictly named '0rhxPlayer'
set_target_properties(0rhxPlayer PROPERTIES
    OUTPUT_NAME "0rhxPlayer"
)

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
    ${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/lib/bass.lib
    ${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/lib/basswasapi.lib
    ${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/lib/bassflac.lib
    dwmapi
    uxtheme
)

# Copy runtime BASS DLLs to output directory
add_custom_command(TARGET 0rhxPlayer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/bin/bass.dll
        ${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/bin/basswasapi.dll
        ${CMAKE_CURRENT_SOURCE_DIR}/libs/bass/bin/bassflac.dll
        $<TARGET_FILE_DIR:0rhxPlayer>
    COMMENT "Copying BASS runtime libraries..."
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
