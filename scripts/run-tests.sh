#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
export CLANG_MODULE_CACHE_PATH="${PROJECT_DIR}/.build/clang-module-cache"

cd "${PROJECT_DIR}"
"${SCRIPT_DIR}/check-toolchain.sh"
/usr/bin/xcrun swift build --disable-sandbox --configuration release --product LocalDictationSelfTest
readonly BIN_PATH="$(/usr/bin/xcrun swift build --disable-sandbox --configuration release --show-bin-path)"
"${BIN_PATH}/LocalDictationSelfTest"
/usr/bin/xcrun swift build --disable-sandbox --configuration release --product LocalDictation
"${BIN_PATH}/LocalDictation" --self-check
