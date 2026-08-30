#!/bin/bash

set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Usage: provision-model.sh VERIFIED_ASSET_BUNDLE_DIRECTORY" >&2
    exit 2
fi

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MODEL_ID='openai_whisper-large-v3-v20240930_turbo_632MB'
readonly SOURCE_ROOT="$(cd "$1" && pwd -P)"
readonly DESTINATION_ROOT="${HOME}/Library/Application Support/Local Dictation"
readonly MODEL_DESTINATION="${DESTINATION_ROOT}/Models/${MODEL_ID}"
readonly TOKENIZER_DESTINATION="${DESTINATION_ROOT}/Tokenizers/models/openai/whisper-large-v3"

"${SCRIPT_DIR}/verify-model-assets.sh" "${SOURCE_ROOT}"

if [[ -e "${MODEL_DESTINATION}" || -e "${TOKENIZER_DESTINATION}" ]]; then
    echo "Provisioning blocked: a destination already exists; move or remove it explicitly first." >&2
    exit 1
fi

/bin/mkdir -p "$(/usr/bin/dirname "${MODEL_DESTINATION}")"
/bin/mkdir -p "$(/usr/bin/dirname "${TOKENIZER_DESTINATION}")"
/usr/bin/ditto "${SOURCE_ROOT}/Models/${MODEL_ID}" "${MODEL_DESTINATION}"
/usr/bin/ditto "${SOURCE_ROOT}/Tokenizers/models/openai/whisper-large-v3" "${TOKENIZER_DESTINATION}"

"${SCRIPT_DIR}/verify-model-assets.sh" "${DESTINATION_ROOT}"
echo "Verified local model and tokenizer assets installed."
