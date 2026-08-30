#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly EXPECTED_LICENSE_SHA256='b9cd0e6149c0b98372caac4eb2d48f025e5070a24026e711965a3d2a74001f14'

blocked=0
if [[ ! -s "${PROJECT_DIR}/LICENSE" ]]; then
    echo "License gate blocked: the repository license requires owner selection." >&2
    blocked=1
else
    readonly ACTUAL_LICENSE_SHA256="$(/usr/bin/shasum -a 256 "${PROJECT_DIR}/LICENSE" | /usr/bin/awk '{print $1}')"
    if [[ "${ACTUAL_LICENSE_SHA256}" != "${EXPECTED_LICENSE_SHA256}" ]]; then
        echo "License gate blocked: LICENSE does not match the owner-approved MIT text and attribution." >&2
        blocked=1
    fi
fi
if /usr/bin/grep -q 'VERIFICATION REQUIRED' "${PROJECT_DIR}/THIRD_PARTY_NOTICES.md"; then
    echo "License gate blocked: third-party notice contains an unresolved assertion." >&2
    blocked=1
fi

[[ "${blocked}" -eq 0 ]] || exit 1

echo "Repository and third-party license gate passed."
