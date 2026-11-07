#!/usr/bin/env bash
# Slow — run ONE heavy command at a time, for every session and agent.
#
#   .claude/wol/spells/slow.sh 'flutter test test/login_test.dart'
#
# Runs Protect on the command first (exit 126 when refused), then waits
# for the shared lock (stale locks reclaimed), waits out low memory,
# runs at nice 10, stops the whole process group after WOL_TIMEOUT, and
# logs start, end, exit code, duration and the lowest free memory.
set -uo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/../lib.sh"
ROOT="$PROJECT"
wol_state; LOCK="$STATE/heavy.lock"; LOG="$STATE/slow.log"
[[ $# -ge 1 ]] || { echo "usage: slow.sh '<command>'" >&2; exit 2; }
cmd="$*"

# The queue is not a way around Protect: judge the command before it runs
# (heavy is fine here, everything else is checked as if typed directly).
refuse() { echo "Slow: refused, not running it. $1" >&2; exit 126; }
verdict="$(jq -n --arg c "$cmd" '{tool_input:{command:$c}}' | WOL_QUEUED=1 "$WOL/spells/protect.sh")" \
  || refuse "Protect could not check the command."
if [[ -n "$verdict" ]]; then
  decision="$(jq -r '.hookSpecificOutput.permissionDecision // "allow"' <<<"$verdict" 2>/dev/null)" \
    || refuse "Protect gave an unreadable answer."
  [[ "$decision" == deny ]] && refuse "$(jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$verdict")"
fi

mem() {
  if [[ "$(uname)" == Darwin ]]; then sysctl -n kern.memorystatus_level 2>/dev/null || echo 100
  else awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print (t?int(a*100/t):100)}' /proc/meminfo 2>/dev/null || echo 100; fi
}
log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG"; }

waited=0
until mkdir "$LOCK" 2>/dev/null; do
  holder="$(cat "$LOCK/pid" 2>/dev/null || true)"
  if [[ -n "$holder" ]] && ! kill -0 "$holder" 2>/dev/null; then
    log "reclaimed stale lock from pid $holder"; rm -rf "$LOCK"; continue
  fi
  (( waited % 60 == 0 )) && echo "Slow: queued behind pid ${holder:-?}" >&2
  sleep 10; waited=$((waited + 10))
done
echo $$ >"$LOCK/pid"; printf '%s' "$cmd" >"$LOCK/cmd"
trap 'rm -rf "$LOCK"' EXIT

for _ in $(seq 1 30); do
  (( $(mem) >= WOL_MIN_FREE )) && break
  echo "Slow: free memory $(mem)% < ${WOL_MIN_FREE}%, waiting" >&2; sleep 10
done

start=$(date +%s); low=$(mem)
log "START waited=${waited}s free=${low}% :: $cmd"
cd "$ROOT" || exit 1
perl -e 'setpgrp(0,0); exec @ARGV' nice -n 10 bash -c "$cmd" &
pid=$!; status=""
while kill -0 "$pid" 2>/dev/null; do
  m=$(mem); (( m < low )) && low=$m
  if (( $(date +%s) - start > WOL_TIMEOUT )); then
    echo "Slow: time limit ${WOL_TIMEOUT}s reached, stopping" >&2
    kill -TERM -- "-$pid" 2>/dev/null; sleep 5; kill -KILL -- "-$pid" 2>/dev/null
    status=124; break
  fi
  sleep 2
done
[[ -z "$status" ]] && { wait "$pid"; status=$?; }
dur=$(( $(date +%s) - start ))
log "END exit=$status ${dur}s lowest-free=${low}% :: $cmd"
echo "Slow: exit $status in ${dur}s, lowest free memory ${low}%" >&2
exit "$status"
