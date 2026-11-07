#!/usr/bin/env bash
# Shell — PreToolUse guard for Read / Edit / Write: secret files
# (signing keys, service accounts, production env files) are never opened.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/../lib.sh"
f="$(jq -r '.tool_input.file_path // .tool_input.path // empty')"
[[ -z "$f" ]] && exit 0
secret="${WOL_SECRET_FILES:-}"; secret="${secret:+$secret|}${WOL_SECRET_ALWAYS}"
if grep -Eiq -- "(${secret})" <<<"$f" && ! grep -Eiq -- "(${WOL_SECRET_OK})" <<<"$f"; then
  jq -n --arg r "Shell: $f is a secret file; the crew does not open it." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
fi
exit 0
