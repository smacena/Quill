# Scintilla looks for its cursor / info bar images as TIFF in the bundle that
# contains the ScintillaView class (our app bundle).
set(SCI_RES ${SCI_DIR}/cocoa/res)
set(SCI_TIFFS)
foreach(img mac_cursor_busy mac_cursor_flipped info_bar_bg)
  set(out ${CMAKE_CURRENT_BINARY_DIR}/sci_res/${img}.tiff)
  add_custom_command(OUTPUT ${out}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/sci_res
    COMMAND tiffutil -cathidpicheck ${SCI_RES}/${img}.png ${SCI_RES}/${img}@2x.png -out ${out}
    DEPENDS ${SCI_RES}/${img}.png ${SCI_RES}/${img}@2x.png
    VERBATIM)
  list(APPEND SCI_TIFFS ${out})
endforeach()

file(GLOB QUILL_APP_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/*.mm)

set(QUILL_RESOURCES
  ${CMAKE_CURRENT_SOURCE_DIR}/resources/languages.json
  ${CMAKE_SOURCE_DIR}/README.md
  ${CMAKE_SOURCE_DIR}/README.pt-BR.md
  ${CMAKE_SOURCE_DIR}/PLUGINS.md
  ${SCI_TIFFS})

set(QUILL_ICON ${CMAKE_BINARY_DIR}/Quill.icns)
add_custom_command(OUTPUT ${QUILL_ICON}
  COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_BINARY_DIR}/Quill.iconset
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/resources/Quill.iconset ${CMAKE_BINARY_DIR}/Quill.iconset
  COMMAND iconutil -c icns ${CMAKE_BINARY_DIR}/Quill.iconset -o ${QUILL_ICON}
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/resources/Quill.iconset/icon_512x512.png
  VERBATIM)
list(APPEND QUILL_RESOURCES ${QUILL_ICON})

add_executable(Quill MACOSX_BUNDLE ${QUILL_APP_SOURCES} ${QUILL_RESOURCES})
set_source_files_properties(${QUILL_RESOURCES} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

target_include_directories(Quill PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/src
  ${CMAKE_SOURCE_DIR}/sdk/include)
target_compile_options(Quill PRIVATE
  -fobjc-arc
  -Wall
  -Wno-unused-parameter
  -Wno-deprecated-declarations
  -Wno-objc-protocol-method-implementation
  -Wno-incomplete-implementation
  -Wno-arc-performSelector-leaks)
target_link_libraries(Quill PRIVATE
  scintilla lexilla quillcore md4c
  "-framework Cocoa"
  "-framework WebKit"
  "-framework QuartzCore"
  "-framework UniformTypeIdentifiers")

set_target_properties(Quill PROPERTIES
  OUTPUT_NAME Quill
  ENABLE_EXPORTS ON
  MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
  MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
  MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION})
