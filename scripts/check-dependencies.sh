#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly RESOLVED="${PROJECT_DIR}/Package.resolved"

[[ -s "${RESOLVED}" ]] || {
    echo "Dependency gate failed: Package.resolved is missing." >&2
    exit 1
}

/usr/bin/jq -e '
    .version == 3 and
    (.pins | length) == 5 and
    ([.pins[] | {
        identity,
        version: .state.version,
        revision: .state.revision
    }] | sort_by(.identity)) == ([
        {"identity":"jinja","version":"1.3.0","revision":"5c0a87846dfd36ca6621795ad2f09fdaab82b739"},
        {"identity":"swift-argument-parser","version":"1.8.2","revision":"6a52f3251125d74daf04fcbd5e6f08a75d074382"},
        {"identity":"swift-collections","version":"1.6.0","revision":"a0cb0954ecb21e4e31b0070e6ed5674e8556685a"},
        {"identity":"swift-transformers","version":"0.1.15","revision":"8a83416cc00ab07a5de9991e6ad817a9b8588d20"},
        {"identity":"whisperkit","version":"0.13.0","revision":"b3c412aa7520069f6c71f7cc217fbcf850ba31a1"}
    ] | sort_by(.identity))
' "${RESOLVED}" >/dev/null || {
    echo "Dependency gate failed: the resolved package graph drifted." >&2
    exit 1
}

readonly PACKAGE_SOURCE="$(/usr/bin/tr -d '\n\r' < "${PROJECT_DIR}/Package.swift")"
if ! /usr/bin/grep -Eq '\.package\([[:space:]]*url:[[:space:]]*"https://github\.com/argmaxinc/WhisperKit\.git",[[:space:]]*exact:[[:space:]]*"0\.13\.0"[[:space:]]*\)' <<< "${PACKAGE_SOURCE}"; then
    echo "Dependency gate failed: WhisperKit is not exact-pinned in Package.swift." >&2
    exit 1
fi

if /usr/bin/grep -Eq '\.package\([^)]*(branch:|revision:|path:)' <<< "${PACKAGE_SOURCE}"; then
    echo "Dependency gate failed: mutable or local package requirement present." >&2
    exit 1
fi

echo "Exact dependency lock passed."
