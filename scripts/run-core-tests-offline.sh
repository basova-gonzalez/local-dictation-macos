#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly OUTPUT_DIR="${PROJECT_DIR}/.build/offline-core-tests"

/bin/mkdir -p "${OUTPUT_DIR}/module-cache"
cd "${PROJECT_DIR}"

# Compile the dependency-free core and its self-test sources in one module.
# The self-test imports that same module, so Swift emits harmless ignored-import
# warnings; no package resolution or network access occurs.
/usr/bin/xcrun swiftc \
    -suppress-warnings \
    -module-name LocalDictationCore \
    -module-cache-path "${OUTPUT_DIR}/module-cache" \
    Sources/LocalDictationCore/*.swift \
    Sources/LocalDictationSelfTest/*.swift \
    -o "${OUTPUT_DIR}/LocalDictationSelfTest"

"${OUTPUT_DIR}/LocalDictationSelfTest"
