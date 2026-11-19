cmake_minimum_required(VERSION 3.21)

if(APPLE)
  set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum macOS version")
  if(NOT CMAKE_OSX_ARCHITECTURES)
    set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "Build a universal binary")
  endif()
endif()

project(Quill VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 99)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

# ---- Portable code (also builds and tests on Linux) --------------------------

add_library(md4c STATIC
  third_party/md4c/md4c.c
  third_party/md4c/md4c-html.c
  third_party/md4c/entity.c)
target_include_directories(md4c PUBLIC third_party/md4c)

add_library(quillcore STATIC
  core/src/Diff.cpp
  core/src/Encoding.cpp
  core/src/Json.cpp
  core/src/TextTools.cpp)
target_include_directories(quillcore PUBLIC core/include)
target_link_libraries(quillcore PRIVATE md4c)
set_target_properties(quillcore md4c PROPERTIES POSITION_INDEPENDENT_CODE ON)

enable_testing()
add_executable(core_tests tests/core_tests.cpp)
target_link_libraries(core_tests PRIVATE quillcore md4c)
add_test(NAME core_tests COMMAND core_tests)

# Checks that the plugin SDK headers compile as plain C++ (no Cocoa needed).
add_library(sdk_header_check STATIC tests/sdk_header_check.cpp)
target_include_directories(sdk_header_check PRIVATE sdk/include third_party/scintilla/include)

if(APPLE)
  enable_language(OBJC OBJCXX)
  include(cmake/Scintilla.cmake)
  add_subdirectory(app)
  add_subdirectory(plugins)
endif()
