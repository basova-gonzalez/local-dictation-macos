#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

check_manifest() {
    local manifest="$1"
    local expected_count="$2"
    local count=0
    local paths=''

    [[ -s "${manifest}" ]] || {
        echo "Manifest gate failed: required inventory is missing." >&2
        exit 1
    }

    while IFS=$'\t' read -r algorithm digest size relative; do
        [[ -z "${algorithm}" || "${algorithm}" == \#* ]] && continue
        case "${algorithm}" in
            sha256) [[ "${digest}" =~ ^[0-9a-f]{64}$ ]] ;;
            git-blob-sha1) [[ "${digest}" =~ ^[0-9a-f]{40}$ ]] ;;
            *) false ;;
        esac || {
            echo "Manifest gate failed: invalid integrity identifier." >&2
            exit 1
        }
        [[ "${size}" =~ ^[0-9]+$ ]] || {
            echo "Manifest gate failed: invalid file size." >&2
            exit 1
        }
        if [[ -z "${relative}" || "${relative}" == /* || "/${relative}/" == *'/../'* ]]; then
            echo "Manifest gate failed: unsafe relative path." >&2
            exit 1
        fi
        if [[ "${paths}" == *$'\n'"${relative}"$'\n'* ]]; then
            echo "Manifest gate failed: duplicate path." >&2
            exit 1
        fi
        paths+=$'\n'"${relative}"$'\n'
        count=$((count + 1))
    done < "${manifest}"

    [[ "${count}" == "${expected_count}" ]] || {
        echo "Manifest gate failed: unexpected file count." >&2
        exit 1
    }
}

check_manifest "${PROJECT_DIR}/model-manifests/whisper-large-v3-turbo.integrity.tsv" 22
check_manifest "${PROJECT_DIR}/model-manifests/whisper-large-v3-tokenizer.integrity.tsv" 3

echo "Pinned model metadata passed."
