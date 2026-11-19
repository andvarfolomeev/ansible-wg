#!/usr/bin/env bash

# Look for leaked keys and gitignored secret files in git history (all refs) and the index
# Usage: ./secrets-check.sh
# Matches are printed with values masked; exits 1 if anything is found

cd "$(git rev-parse --show-toplevel)" || exit 1

FOUND=0

# Hide everything after the first 6 characters of long tokens
mask() {
    sed -E 's/([A-Za-z0-9+\/_-]{6})[A-Za-z0-9+\/_=-]{10,}/\1…[masked]/g'
}

report() {
    local title="$1" hits="$2"
    if [ -n "$hits" ]; then
        echo "❌ $title:"
        echo "$hits" | mask | sed 's/^/   /'
        FOUND=1
    else
        echo "✅ $title: none"
    fi
}

# Files that must never be committed (see .gitignore)
SECRET_FILES='(^|/)(peers|xray_clients|fialka)\.yml$|(^|/)inventory\.ini$|^clients/|\.(key|pem)$|(^|/)\.env$|(^|/)id_(rsa|ed25519)'
report "Secret files in history" "$(
    { git log --all --pretty=format: --name-only; git ls-files; } | sort -u | grep -E "$SECRET_FILES"
)"

# WireGuard / X25519 keys, Reality keys, Xray client UUIDs, PEM private keys
KEYS='[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=|(key|pbk)["'"'"': =]+[A-Za-z0-9_-]{43}\b|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|BEGIN [A-Z ]*PRIVATE KEY'
# Every revision plus the index, so staged files are checked before commit;
# devenv.lock holds nix hashes that look like base64 keys
report "Key-like values in history and index" "$(
    {
        git rev-list --all | xargs -r git grep -nIE "$KEYS" -- ':!devenv.lock' | sed -E 's/^[0-9a-f]{40}://'
        git grep --cached -nIE "$KEYS" -- ':!devenv.lock'
    } | sort -u
)"

exit $FOUND
