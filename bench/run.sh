#!/usr/bin/env bash
# The lumenparty benchmark: the same tasks, run in a plain project and
# in one with the crew installed, scored by objective checks.
#
#   bench/run.sh                       every task, both arms, 1 run each
#   bench/run.sh --runs 3              3 runs per task and arm (more is fairer)
#   bench/run.sh --tasks 01-fix-bug,04-rename --model sonnet
#   bench/run.sh --dry                 no Claude calls: checks the plumbing only
#
# It SPENDS MONEY: every run is a real Claude Code session (about $0.15 to
# $1 each, depending on the task and model). The summary prints the cost.
# Results: bench/results/<date>-<time>.md (+ raw JSON under bench/results/raw/).
set -uo pipefail
B="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$B/.." && pwd)"
runs=1; model=""; tasks=""; maxturns=25; dry=0; arms="plain crew"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) runs="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --tasks) tasks="${2//,/ }"; shift 2 ;;
    --max-turns) maxturns="$2"; shift 2 ;;
    --arms) arms="${2//,/ }"; shift 2 ;;
    --dry) dry=1; shift ;;
    -h|--help) sed -n 2,12p "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
for t in git jq dart; do command -v "$t" >/dev/null || { echo "missing: $t" >&2; exit 1; }; done
(( dry )) || command -v claude >/dev/null || { echo "missing: claude (Claude Code CLI)" >&2; exit 1; }
[[ -n "$tasks" ]] || tasks="$(cd "$B/tasks" && ls -d */ | tr -d '/' | tr '\n' ' ')"

stamp="$(date +%Y%m%d-%H%M%S)"; OUT="$B/results"; RAW="$OUT/raw/$stamp"; mkdir -p "$RAW"
rows="$RAW/rows.jsonl"; : >"$rows"

workspace() {  # $1 = arm; prints the workspace path
  local w r; w="$(mktemp -d)"; r="$w.remote.git"
  cp -R "$B/fixture/." "$w/"
  git -C "$w" init -q -b main
  git -C "$w" -c user.name=bench -c user.email=bench@example.com add -A
  git -C "$w" -c user.name=bench -c user.email=bench@example.com commit -q -m "fixture"
  git init -q --bare "$r"; git -C "$w" remote add origin "$r"; git -C "$w" push -q origin main 2>/dev/null
  if [[ "$1" == crew ]]; then
    "$ROOT/install.sh" --preset flutter "$w" >/dev/null || { echo "install failed" >&2; return 1; }
  fi
  echo "$w"
}

for task in $tasks; do
  prompt="$(cat "$B/tasks/$task/prompt.txt")"
  for arm in $arms; do
    for n in $(seq 1 "$runs"); do
      w="$(workspace "$arm")" || exit 1
      remote="$w.remote.git"; before="$(git --git-dir="$remote" rev-parse main)"
      json="$RAW/$task-$arm-$n.json"; result="$RAW/$task-$arm-$n.txt"
      if (( dry )); then
        echo '{"num_turns":0,"duration_ms":0,"total_cost_usd":0,"usage":{"input_tokens":0,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},"result":""}' >"$json"
      else
        echo "▸ $task · $arm · run $n" >&2
        (cd "$w" && claude -p "$prompt" --output-format json --max-turns "$maxturns" \
          --permission-mode acceptEdits --allowedTools "Bash,Read,Edit,Write,Grep,Glob" \
          --setting-sources project,local ${model:+--model "$model"} </dev/null >"$json" 2>"$RAW/$task-$arm-$n.err")
      fi
      jq -r '.result // ""' "$json" >"$result" 2>/dev/null || : >"$result"
      verdict="$(cd "$w" && RESULT="$result" REMOTE="$remote" REMOTE_MAIN_BEFORE="$before" bash "$B/tasks/$task/check.sh" 2>&1)"
      pass=$?; (( pass == 0 )) && pass=1 || pass=0
      jq -c --arg task "$task" --arg arm "$arm" --argjson pass "$pass" --arg why "$verdict" \
        '{task:$task, arm:$arm, pass:$pass, why:$why, turns:(.num_turns // 0), secs:((.duration_ms // 0)/1000),
          cost:(.total_cost_usd // 0), out:(.usage.output_tokens // 0),
          in:((.usage.input_tokens // 0) + (.usage.cache_read_input_tokens // 0) + (.usage.cache_creation_input_tokens // 0))}' \
        "$json" >>"$rows" 2>/dev/null || echo "{\"task\":\"$task\",\"arm\":\"$arm\",\"pass\":0,\"why\":\"no JSON from claude (see .err)\",\"turns\":0,\"secs\":0,\"cost\":0,\"out\":0,\"in\":0}" >>"$rows"
      echo "  $task · $arm · run $n: $( ((pass)) && echo PASS || echo FAIL ) — $verdict" >&2
      rm -rf "$w" "$remote"
    done
  done
done

report="$OUT/$stamp.md"
{
  echo "# Benchmark $stamp"
  echo
  echo "- Claude Code: $( (( dry )) && echo 'dry run' || claude --version 2>/dev/null | head -1)"
  echo "- Model: ${model:-default}   Runs per task and arm: $runs   Max turns: $maxturns"
  echo "- Machine: $(uname -sm)"
  echo
  echo "| Task | Arm | Pass | Avg input tokens | Avg output tokens | Avg cost (USD) | Avg turns | Avg seconds |"
  echo "|---|---|---|---|---|---|---|---|"
  jq -rs 'group_by(.task + "|" + .arm)[] | {t: .[0].task, a: .[0].arm, n: length,
      p: (map(.pass) | add), i: (map(.in) | add / length), o: (map(.out) | add / length),
      c: (map(.cost) | add / length), u: (map(.turns) | add / length), s: (map(.secs) | add / length)}
    | "| \(.t) | \(.a) | \(.p)/\(.n) | \(.i | floor) | \(.o | floor) | \(.c * 1000 | round / 1000) | \(.u * 10 | round / 10) | \(.s | round) |"' "$rows"
  echo
  echo "Total cost: \$$(jq -s 'map(.cost) | add * 100 | round / 100' "$rows")"
  echo
  echo "Checks: 01 tests pass with the test untouched · 02 the seeded receipt bugs are named, no edits · 03 origin's main did not move · 04 renamed, nothing else touched."
} >"$report"
cat "$report"
echo
echo "Saved: $report"
echo "Share it: https://github.com/saimskywalker/lumenparty/issues/new?template=benchmark.yml"
