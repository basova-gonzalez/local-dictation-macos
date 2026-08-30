#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly APP_PATH="${PROJECT_DIR}/build/Local Dictation.app"
readonly CONTENTS_PATH="${APP_PATH}/Contents"
readonly EXECUTABLE_PATH="${CONTENTS_PATH}/MacOS/LocalDictation"
readonly SIGN_IDENTITY="${LOCAL_DICTATION_SIGN_IDENTITY:-}"
export CLANG_MODULE_CACHE_PATH="${PROJECT_DIR}/.build/clang-module-cache"

if [[ -z "${SIGN_IDENTITY}" ]]; then
    echo "Set LOCAL_DICTATION_SIGN_IDENTITY to one existing code-signing identity." >&2
    echo "This script never creates an identity and never falls back to ad-hoc signing." >&2
    exit 1
fi

cd "${PROJECT_DIR}"
"${SCRIPT_DIR}/check-toolchain.sh"
/usr/bin/xcrun swift build --disable-sandbox --configuration release --product LocalDictation
readonly BIN_PATH="$(/usr/bin/xcrun swift build --disable-sandbox --configuration release --show-bin-path)"

/bin/mkdir -p "${CONTENTS_PATH}/MacOS"
/usr/bin/ditto "${BIN_PATH}/LocalDictation" "${EXECUTABLE_PATH}"
/usr/bin/ditto "${PROJECT_DIR}/Resources/Info.plist" "${CONTENTS_PATH}/Info.plist"
/usr/bin/plutil -lint "${CONTENTS_PATH}/Info.plist"
/usr/bin/codesign --force --sign "${SIGN_IDENTITY}" "${APP_PATH}"
/usr/bin/codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

echo "Built and signed Local Dictation.app with the explicitly selected identity."
