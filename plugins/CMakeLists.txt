# Bundled plugins. Each one is a .dylib loaded at runtime through the
# Notepad++-compatible plugin API (see sdk/include and PLUGINS.md).

function(quill_plugin name)
  add_library(${name} MODULE ${ARGN})
  set_target_properties(${name} PROPERTIES PREFIX "" SUFFIX ".dylib" OUTPUT_NAME ${name})
  target_include_directories(${name} PRIVATE
    ${CMAKE_SOURCE_DIR}/sdk/include
    ${CMAKE_SOURCE_DIR}/third_party/scintilla/include
    ${CMAKE_SOURCE_DIR}/third_party/scintilla/cocoa
    ${CMAKE_SOURCE_DIR}/plugins/common)
  target_compile_options(${name} PRIVATE -fobjc-arc -Wall -Wno-unused-parameter -Wno-deprecated-declarations)
  # Linking against the app executable (ENABLE_EXPORTS) uses -bundle_loader, so
  # QuillSendMessage and ScintillaView resolve against the running app.
  target_link_libraries(${name} PRIVATE Quill quillcore md4c "-framework Cocoa")
  add_custom_command(TARGET ${name} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_BUNDLE_CONTENT_DIR:Quill>/PlugIns
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${name}> $<TARGET_BUNDLE_CONTENT_DIR:Quill>/PlugIns/
    VERBATIM)
endfunction()

foreach(p Compare JSONViewer XMLTools Exec Explorer MarkdownViewer SpellCheck HexEditor FTP)
  if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${p})
    file(GLOB _src ${CMAKE_CURRENT_SOURCE_DIR}/${p}/*.mm ${CMAKE_CURRENT_SOURCE_DIR}/${p}/*.cpp)
    quill_plugin(${p} ${_src})
  endif()
endforeach()

if(TARGET MarkdownViewer)
  target_link_libraries(MarkdownViewer PRIVATE "-framework WebKit")
endif()
if(TARGET FTP)
  target_link_libraries(FTP PRIVATE "-framework Security" "-framework UniformTypeIdentifiers")
endif()
