#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly EXECUTABLE_PATH="${PROJECT_DIR}/build/Local Dictation.app/Contents/MacOS/LocalDictation"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
    echo "Signed app executable is missing." >&2
    exit 1
fi

"${EXECUTABLE_PATH}" --self-check
echo "Headless app self-check passed."
