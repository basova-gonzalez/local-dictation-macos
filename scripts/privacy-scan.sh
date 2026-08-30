#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

if /usr/bin/find . \
    -path './.git' -prune -o \
    -path './.build' -prune -o \
    -path './build' -prune -o \
    -type f \( \
        -name '*.wav' -o -name '*.m4a' -o -name '*.mp3' -o \
        -name '*.webm' -o -name '*.sqlite' -o -name '*.p12' -o \
        -name '*.mobileprovision' -o -name '*.mlmodelc' -o \
        -name '*.mlpackage' -o -name '*.safetensors' \
    \) -print | /usr/bin/grep -q .; then
    echo "Privacy scan failed: private runtime or model artifact present." >&2
    exit 1
fi

if /usr/bin/grep -RInE \
    --exclude-dir=.git --exclude-dir=.build --exclude-dir=build \
    --exclude='privacy-scan.sh' \
    '(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-[A-Za-z0-9_-]{20,})' \
    .; then
    echo "Privacy scan failed: credential-shaped content present." >&2
    exit 1
fi

readonly ABSOLUTE_HOME_PREFIX='/''Users/'
if /usr/bin/grep -RIlF \
    --exclude-dir=.git --exclude-dir=.build --exclude-dir=build \
    --exclude='privacy-scan.sh' \
    "${ABSOLUTE_HOME_PREFIX}" . | /usr/bin/grep -q .; then
    echo "Privacy scan failed: absolute user path present." >&2
    exit 1
fi

if /usr/bin/grep -RInE \
    '(URLSession|NWConnection|Process\(|NSTask|NSLog|os_log|127\.0\.0\.1|localhost|0\.0\.0\.0|CORS|SharedModel|Qwen|LM Studio)' \
    Sources Resources; then
    echo "Privacy scan failed: network, process, logging, or dormant-runtime code present." >&2
    exit 1
fi

if /usr/bin/grep -RIn 'CGEvent' Sources \
    | /usr/bin/grep -v 'Sources/LocalDictation/PasteboardFallbackInserter.swift'; then
    echo "Privacy scan failed: event synthesis outside guarded Command+V fallback." >&2
    exit 1
fi

if /usr/bin/grep -InE '(kVK_Return|virtualKey:[[:space:]]*36|CGKeyCode\([[:space:]]*36[[:space:]]*\))' \
    Sources/LocalDictation/PasteboardFallbackInserter.swift; then
    echo "Privacy scan failed: Enter/Return synthesis is forbidden." >&2
    exit 1
fi

if ! /usr/bin/grep -q 'download: false' Sources/LocalDictation/WhisperModelConfig.swift; then
    echo "Privacy scan failed: model downloader is not explicitly disabled." >&2
    exit 1
fi

if ! /usr/bin/grep -q 'tokenizerFolder: tokenizerBaseFolder' Sources/LocalDictation/WhisperModelConfig.swift; then
    echo "Privacy scan failed: tokenizer is not pinned to the local asset folder." >&2
    exit 1
fi

if ! /usr/bin/grep -q 'OfflineNetworkGuard.install()' Sources/LocalDictation/main.swift; then
    echo "Privacy scan failed: the additional shared/default Foundation HTTP(S) guard is not installed." >&2
    exit 1
fi

if /usr/bin/grep -RInE 'https?://' Sources; then
    echo "Privacy scan failed: runtime source contains an external endpoint." >&2
    exit 1
fi

echo "Privacy and static security scan passed."
