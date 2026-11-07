#!/usr/bin/env bash
# Silence — PreToolUse guard for SQL MCP tools. Give the database a
# read-only role first; this is the second wall. Only SELECT / WITH /
# EXPLAIN (no ANALYZE) / SHOW go out, one statement, nothing that writes,
# locks, sleeps or changes the session.
set -euo pipefail
# Fail closed: if anything below breaks (no jq, a broken config), refuse the
# call with a fixed answer printed by printf, which needs nothing else.
fail_closed() {
  local rc=$?
  (( rc == 0 )) && return
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s: the guard could not run (exit %s; is jq installed?), so this call is refused."}}\n' Silence "$rc"
  exit 0
}
trap fail_closed EXIT
sql="$(jq -r '.tool_input.sql // .tool_input.query // empty')"
[[ -z "$sql" ]] && exit 0
deny() {
  jq -n --arg r "Silence: $1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
# strip comments and string literals before judging
clean="$(perl -0pe "s/--[^\n]*//g; s{/\*.*?\*/}{}gs; s/'(?:[^']|'')*'/''/g" <<<"$sql")"
first="$(tr '[:upper:]' '[:lower:]' <<<"$clean" | grep -Eo '[a-z]+' | head -1 || true)"
[[ "$first" =~ ^(select|with|explain|show|values|table)$ ]] || deny "only SELECT / WITH / EXPLAIN / SHOW are allowed (got '$first')."
grep -Eqi '\b(insert|update|delete|merge|drop|alter|truncate|create|grant|revoke|copy|vacuum|analyze|reindex|cluster|refresh|lock|call|do|listen|notify|prepare|execute|discard|reset)\b|\bset[[:space:]]+(role|session|local)|for[[:space:]]+(update|share|no[[:space:]]+key)|pg_(terminate|cancel)_backend|pg_sleep|set_config|lo_(import|export)|dblink|nextval|setval|into[[:space:]]+outfile' <<<"$clean" \
  && deny "the query writes, locks, sleeps or changes the session."
[[ "$(grep -o ';' <<<"$clean" | wc -l | tr -d ' ')" -le 1 ]] || deny "one statement per call."
exit 0
