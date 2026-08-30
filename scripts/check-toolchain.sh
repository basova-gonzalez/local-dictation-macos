#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly MINIMUM_SWIFT_MAJOR=6
readonly MINIMUM_SWIFT_MINOR=2
readonly SWIFT_VERSION_OUTPUT="$(/usr/bin/xcrun swiftc --version)"
readonly SDK_PATH="$(/usr/bin/xcrun --show-sdk-path)"
readonly MODULE_CACHE="${PROJECT_DIR}/.build/toolchain-module-cache"

/bin/mkdir -p "${MODULE_CACHE}"
/usr/bin/printf '%s\n' "${SWIFT_VERSION_OUTPUT}"

if [[ ! "${SWIFT_VERSION_OUTPUT}" =~ Apple[[:space:]]Swift[[:space:]]version[[:space:]]([0-9]+)\.([0-9]+) ]]; then
    echo "Toolchain check failed: could not determine the Apple Swift version." >&2
    exit 1
fi

readonly SWIFT_MAJOR="${BASH_REMATCH[1]}"
readonly SWIFT_MINOR="${BASH_REMATCH[2]}"
if (( SWIFT_MAJOR < MINIMUM_SWIFT_MAJOR )) || \
    (( SWIFT_MAJOR == MINIMUM_SWIFT_MAJOR && SWIFT_MINOR < MINIMUM_SWIFT_MINOR )); then
    echo "Toolchain check failed: Swift ${MINIMUM_SWIFT_MAJOR}.${MINIMUM_SWIFT_MINOR} or later is required; found ${SWIFT_MAJOR}.${SWIFT_MINOR}." >&2
    exit 1
fi

if ! /usr/bin/grep -q '^// swift-tools-version: 6\.2$' "${PROJECT_DIR}/Package.swift"; then
    echo "Toolchain check failed: Package.swift must declare swift-tools-version 6.2." >&2
    exit 1
fi

/usr/bin/printf 'import AppKit\n' | /usr/bin/xcrun swiftc \
    -typecheck \
    -sdk "${SDK_PATH}" \
    -module-cache-path "${MODULE_CACHE}" \
    -

cd "${PROJECT_DIR}"
CLANG_MODULE_CACHE_PATH="${MODULE_CACHE}" \
    /usr/bin/xcrun swift package --disable-sandbox dump-package >/dev/null

echo "Swift ${SWIFT_MAJOR}.${SWIFT_MINOR}, active macOS SDK, and the Swift 6.2 package manifest are compatible."
