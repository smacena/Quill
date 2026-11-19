# Builds Scintilla (Cocoa) and Lexilla as static libraries.

set(SCI_DIR ${CMAKE_SOURCE_DIR}/third_party/scintilla)
set(LEX_DIR ${CMAKE_SOURCE_DIR}/third_party/lexilla)

file(GLOB SCI_CORE_SOURCES ${SCI_DIR}/src/*.cxx)
set(SCI_COCOA_SOURCES
  ${SCI_DIR}/cocoa/PlatCocoa.mm
  ${SCI_DIR}/cocoa/ScintillaCocoa.mm
  ${SCI_DIR}/cocoa/ScintillaView.mm
  ${SCI_DIR}/cocoa/InfoBar.mm)

add_library(scintilla STATIC ${SCI_CORE_SOURCES} ${SCI_COCOA_SOURCES})
target_include_directories(scintilla PUBLIC ${SCI_DIR}/include ${SCI_DIR}/cocoa PRIVATE ${SCI_DIR}/src)
target_compile_definitions(scintilla PRIVATE NDEBUG)
target_compile_options(scintilla PRIVATE
  $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>
  -Wno-deprecated-declarations -Wno-unused-parameter)
target_link_libraries(scintilla PUBLIC "-framework Cocoa" "-framework QuartzCore")

file(GLOB LEX_SOURCES ${LEX_DIR}/lexlib/*.cxx ${LEX_DIR}/lexers/*.cxx)
add_library(lexilla STATIC ${LEX_SOURCES} ${LEX_DIR}/src/Lexilla.cxx)
target_include_directories(lexilla PUBLIC ${LEX_DIR}/include PRIVATE ${LEX_DIR}/lexlib ${SCI_DIR}/include)
target_compile_definitions(lexilla PRIVATE NDEBUG)
target_compile_options(lexilla PRIVATE -Wno-deprecated-declarations)

