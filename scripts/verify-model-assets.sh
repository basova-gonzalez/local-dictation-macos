#!/bin/bash

set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Usage: verify-model-assets.sh ASSET_BUNDLE_DIRECTORY" >&2
    exit 2
fi

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly MODEL_ID='openai_whisper-large-v3-v20240930_turbo_632MB'
readonly MODEL_MANIFEST="${PROJECT_DIR}/model-manifests/whisper-large-v3-turbo.integrity.tsv"
readonly TOKENIZER_MANIFEST="${PROJECT_DIR}/model-manifests/whisper-large-v3-tokenizer.integrity.tsv"

if [[ ! -d "$1" ]]; then
    echo "Asset gate failed: bundle directory does not exist." >&2
    exit 1
fi

readonly ASSET_ROOT="$(cd "$1" && pwd -P)"
readonly MODEL_ROOT="${ASSET_ROOT}/Models/${MODEL_ID}"
readonly TOKENIZER_ROOT="${ASSET_ROOT}/Tokenizers/models/openai/whisper-large-v3"

if /usr/bin/find "${ASSET_ROOT}" -type l -print -quit | /usr/bin/grep -q .; then
    echo "Asset gate failed: symbolic links are not allowed." >&2
    exit 1
fi

verify_manifest() {
    local manifest="$1"
    local source_root="$2"
    local entry_count=0

    [[ -s "${manifest}" && -d "${source_root}" ]] || {
        echo "Asset gate failed: manifest or source directory is missing." >&2
        exit 1
    }

    while IFS=$'\t' read -r algorithm expected expected_size relative; do
        [[ -z "${algorithm}" || "${algorithm}" == \#* ]] && continue
        [[ "${expected_size}" =~ ^[0-9]+$ ]] || {
            echo "Asset gate failed: invalid size entry." >&2
            exit 1
        }
        if [[ -z "${relative}" || "${relative}" == /* || "${relative}" == *$'\n'* || "/${relative}/" == *'/../'* ]]; then
            echo "Asset gate failed: unsafe manifest path." >&2
            exit 1
        fi

        local file="${source_root}/${relative}"
        [[ -f "${file}" ]] || {
            echo "Asset gate failed: expected file is missing." >&2
            exit 1
        }

        local actual_size
        actual_size="$(/usr/bin/stat -f '%z' "${file}")"
        [[ "${actual_size}" == "${expected_size}" ]] || {
            echo "Asset gate failed: size mismatch." >&2
            exit 1
        }

        local actual
        case "${algorithm}" in
            sha256)
                [[ "${expected}" =~ ^[0-9a-f]{64}$ ]] || {
                    echo "Asset gate failed: invalid SHA-256 entry." >&2
                    exit 1
                }
                actual="$(/usr/bin/shasum -a 256 "${file}" | /usr/bin/awk '{print $1}')"
                ;;
            git-blob-sha1)
                [[ "${expected}" =~ ^[0-9a-f]{40}$ ]] || {
                    echo "Asset gate failed: invalid Git blob entry." >&2
                    exit 1
                }
                actual="$(/usr/bin/git hash-object --no-filters "${file}")"
                ;;
            *)
                echo "Asset gate failed: unsupported integrity algorithm." >&2
                exit 1
                ;;
        esac

        [[ "${actual}" == "${expected}" ]] || {
            echo "Asset gate failed: integrity mismatch." >&2
            exit 1
        }
        entry_count=$((entry_count + 1))
    done < "${manifest}"

    [[ "${entry_count}" -gt 0 ]] || {
        echo "Asset gate failed: manifest contains no files." >&2
        exit 1
    }

    local actual_count
    actual_count="$(/usr/bin/find "${source_root}" -type f | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
    [[ "${actual_count}" == "${entry_count}" ]] || {
        echo "Asset gate failed: unlisted files are present." >&2
        exit 1
    }
}

verify_manifest "${MODEL_MANIFEST}" "${MODEL_ROOT}"
verify_manifest "${TOKENIZER_MANIFEST}" "${TOKENIZER_ROOT}"

readonly TOTAL_EXPECTED=25
readonly TOTAL_ACTUAL="$(/usr/bin/find "${ASSET_ROOT}" -type f | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
[[ "${TOTAL_ACTUAL}" == "${TOTAL_EXPECTED}" ]] || {
    echo "Asset gate failed: bundle contains unexpected files." >&2
    exit 1
}

echo "Model and tokenizer integrity passed."
