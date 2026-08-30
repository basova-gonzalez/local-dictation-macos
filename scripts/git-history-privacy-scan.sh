#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd -P)"

if ! GIT_ROOT="$(/usr/bin/git -C "${PROJECT_DIR}" rev-parse --show-toplevel 2>/dev/null)"; then
    echo "History scan failed: this directory is not a Git repository." >&2
    exit 1
fi
readonly GIT_ROOT

if [[ "$(cd "${GIT_ROOT}" && pwd -P)" != "${PROJECT_DIR}" ]]; then
    echo "History scan failed: the Git root does not match the public project root." >&2
    exit 1
fi

if ! /usr/bin/git -C "${PROJECT_DIR}" rev-parse --verify 'HEAD^{commit}' >/dev/null 2>&1; then
    echo "History scan failed: the public repository has no HEAD commit." >&2
    exit 1
fi

publishable_commits() {
    /usr/bin/git -C "${PROJECT_DIR}" rev-list HEAD --all | /usr/bin/sort -u
}

readonly COMMIT_COUNT="$(publishable_commits | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')"
if [[ "${COMMIT_COUNT}" -eq 0 ]]; then
    echo "History scan failed: zero commits were selected for inspection." >&2
    exit 1
fi

readonly PRIVATE_PATH_PATTERN='(^|/)(Models?|Audio|Recordings?|History)(/|$)|\.(wav|m4a|mp3|webm|sqlite|p12|log|mlmodelc|mlpackage|safetensors)$|(^|/)\.env(\.|$)'
history_contains_path() {
    local commit
    while IFS= read -r commit; do
        if /usr/bin/git -C "${PROJECT_DIR}" ls-tree -r --name-only "${commit}" \
            | /usr/bin/grep -Eq "${PRIVATE_PATH_PATTERN}"; then
            return 0
        fi
    done < <(publishable_commits)
    return 1
}

if history_contains_path; then
    echo "History scan failed: private artifact path found." >&2
    exit 1
fi

history_contains_regex() {
    local pattern="$1"
    local commit
    while IFS= read -r commit; do
        if /usr/bin/git -C "${PROJECT_DIR}" grep -IqE "${pattern}" "${commit}" -- . \
            ':(exclude)scripts/privacy-scan.sh' \
            ':(exclude)scripts/git-history-privacy-scan.sh'; then
            return 0
        fi
    done < <(publishable_commits)
    return 1
}

history_contains_fixed() {
    local pattern="$1"
    local commit
    while IFS= read -r commit; do
        if /usr/bin/git -C "${PROJECT_DIR}" grep -IqF "${pattern}" "${commit}" -- . \
            ':(exclude)scripts/privacy-scan.sh' \
            ':(exclude)scripts/git-history-privacy-scan.sh'; then
            return 0
        fi
    done < <(publishable_commits)
    return 1
}

readonly SECRET_PATTERN='(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-[A-Za-z0-9_-]{20,})'
if history_contains_regex "${SECRET_PATTERN}"; then
    echo "History scan failed: credential-shaped content found." >&2
    exit 1
fi

readonly ABSOLUTE_HOME_PREFIX='/''Users/'
if history_contains_fixed "${ABSOLUTE_HOME_PREFIX}"; then
    echo "History scan failed: absolute user path found." >&2
    exit 1
fi

echo "Git history privacy scan passed (${COMMIT_COUNT} commits inspected)."
