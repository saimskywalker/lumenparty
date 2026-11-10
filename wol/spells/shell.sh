#!/usr/bin/env bash
# Shell — PreToolUse guard for Read / Edit / Write: secret files
# (signing keys, service accounts, production env files) are never opened.
set -euo pipefail
# Fail closed: if anything below breaks (no jq, a broken config), refuse the
# call with a fixed answer printed by printf, which needs nothing else.
fail_closed() {
  local rc=$?
  (( rc == 0 )) && return
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s: the guard could not run (exit %s; is jq installed?), so this call is refused."}}\n' Shell "$rc"
  exit 0
}
trap fail_closed EXIT
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
