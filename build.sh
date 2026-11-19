#!/bin/bash
# Builds Quill.app on macOS (Xcode command line tools + CMake required).
#   ./build.sh            -> build/app/Quill.app
#   ./build.sh install    -> also copies it to /Applications
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v cmake >/dev/null; then
  echo "CMake not found. Install it with: brew install cmake" >&2
  exit 1
fi
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j "$(sysctl -n hw.ncpu)"
ctest --test-dir build --output-on-failure
codesign --force --deep --sign - build/app/Quill.app
echo "Built: $(pwd)/build/app/Quill.app"
if [[ "${1:-}" == "install" ]]; then
  rm -rf /Applications/Quill.app
  cp -R build/app/Quill.app /Applications/
  echo "Installed to /Applications/Quill.app"
fi
