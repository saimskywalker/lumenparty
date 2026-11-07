#!/usr/bin/env bash
# Installs the crew into a throwaway repo and checks every spell decision
# in tests/cases.txt, then the Mini limits and a clean uninstall.
set -uo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$T" init -q -b feature/login
git -C "$T" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
"$SRC/install.sh" --preset fullstack "$T" >/dev/null || { echo "install failed"; exit 1; }
S="$T/.claude/wol/spells"
pass=0; fail=0
decide() {
  local tool="$1" input="$2" out
  case "$tool" in
    bash) out="$(jq -n --arg c "$input" '{tool_input:{command:$c}}' | "$S/protect.sh")" ;;
    read) out="$(jq -n --arg f "$input" '{tool_input:{file_path:$f}}' | "$S/shell.sh")" ;;
    sql)  out="$(jq -n --arg s "$input" '{tool_input:{sql:$s}}' | "$S/silence.sh")" ;;
  esac
  jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out" 2>/dev/null
}
while IFS='|' read -r want tool input; do
  [[ -z "$want" || "$want" == \#* ]] && continue
  got="$(decide "$tool" "$input")"; got="${got:-allow}"
  if [[ "$got" == "$want" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL want=$want got=$got [$tool] $input"; fi
done <"$SRC/tests/cases.txt"
want() {
  local got; got="$(cd "$T" && decide "$2" "$3")"; got="${got:-allow}"
  if [[ "$got" == "$1" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL want=$1 got=$got [$2] $3"; fi
}
# multi-line commands: here-docs and line continuations
want deny bash $'bash <<\'EOF\'\ngit push origin main\nEOF'
want deny bash $'cat <<\'EOF\' | sh\ngit push origin main\nEOF'
want deny bash $'python3 - <<EOF\nimport subprocess\nsubprocess.run(["git", "push", "origin", "main"])\nEOF'
want deny bash $'git push origin \\\nmain'
want allow bash $'cat <<\'EOF\' > notes.md\ngit push origin main\nEOF'
# an alias from the repository's git config
git -C "$T" config alias.zz push; want deny bash 'git zz origin main'; git -C "$T" config --unset alias.zz
# every gh pr merge in a line is gated, for this repository only (stub gate: #1 passes)
G="$T/.claude/wol/crystal/gate.sh"; cp "$G" "$G.real"; printf '#!/usr/bin/env bash\n[[ "$1" == 1 ]]\n' >"$G"
git -C "$T" remote add origin git@github.com:acme/app.git
want allow bash 'gh pr merge 1 --squash'
want deny bash 'gh pr merge 1 --squash && gh pr merge 2 --squash'
want deny bash 'gh pr view 1; gh pr merge 1 --squash; gh pr merge 2 --squash'
want allow bash 'gh pr merge 1 --squash -R acme/app'
want allow bash 'GH_REPO=acme/app gh pr merge 1 --squash'
want deny bash 'gh pr merge 1 --squash -R other/repo'
want deny bash 'GH_REPO=other/repo gh pr merge 1 --squash'
want deny bash 'GH_HOST=ghe.example.com gh pr merge 1 --squash'
want deny bash 'cd ../other && gh pr merge 1 --squash'
want deny bash "lumenparty slow 'gh pr merge 2 --squash'"
mv "$G.real" "$G"; git -C "$T" remote remove origin

# Mini: soft note at 301 lines, block at 501, nothing for an exempt file
mk() { mkdir -p "$(dirname "$T/$1")"; seq 1 "$2" | sed 's/^/\/\/ line /' >"$T/$1"; jq -n --arg f "$T/$1" '{tool_input:{file_path:$f}}' | "$S/mini.sh"; }
check() { if grep -q "$2" <<<"$3"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL mini $1"; fi; }
check soft additionalContext "$(mk lib/a.dart 301)"
check hard '"decision": "block"' "$(mk lib/b.dart 501)"
check exempt '^$' "$(mk lib/c.g.dart 900)"
check test-note additionalContext "$(mk test/d_test.dart 600)"

# Plugin mode: spells run from the plugin folder, config and state come
# from the project. A project config overrides the defaults.
P="$(mktemp -d)"; git -C "$P" init -q -b feature/x
ok() { if eval "$2"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL plugin $1"; fi; }
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json; do ok "json $f" "jq empty '$SRC/$f'"; done
(cd "$P" && "$SRC/bin/lumenparty" init flutter >/dev/null)
ok "init writes config" "grep -q 'preset: flutter' '$P/.claude/wol/config.sh'"
echo "WOL_PROTECTED='main|trunk'" >>"$P/.claude/wol/config.sh"
pdecide() { jq -n --arg c "$1" '{tool_input:{command:$c}}' | CLAUDE_PROJECT_DIR="$P" "$SRC/wol/spells/protect.sh" | jq -rs '.[0].hookSpecificOutput.permissionDecision // "allow"'; }
ok "project config overrides" "[[ \$(pdecide 'git push origin trunk') == deny ]]"
ok "defaults still apply" "[[ \$(pdecide 'flutter test') == deny ]]"
ok "lumenparty slow is the queue" "[[ \$(pdecide \"lumenparty slow 'flutter test test/a_test.dart'\") == allow ]]"
ok "install-path lumenparty slow" "[[ \$(pdecide \".claude/wol/bin/lumenparty slow 'flutter test test/a_test.dart'\") == allow ]]"
ok "wol alias slow is the queue" "[[ \$(pdecide \"wol slow 'flutter test test/a_test.dart'\") == allow ]]"
ok "install-path wol alias slow" "[[ \$(pdecide \".claude/wol/bin/wol slow 'flutter test test/a_test.dart'\") == allow ]]"
ok "wol alias runs lumenparty" "'$SRC/bin/wol' help | grep -q 'lumenparty init'"
(cd "$P" && CLAUDE_PROJECT_DIR="$P" "$SRC/bin/lumenparty" slow 'true' 2>/dev/null)
ok "state lives in the project" "grep -q 'END exit=0' '$P/.claude/wol/slow.log' && [[ -f '$P/.claude/wol/.gitignore' ]]"
ok "plugin folder stays clean" "[[ ! -e '$SRC/wol/slow.log' && ! -e '$SRC/wol/heavy.lock' ]]"
ok "state is ignored by git" "[[ -z \$(git -C '$P' status --porcelain -uall -- .claude/wol | grep -v config.sh | grep -v thresholds.md | grep -v .gitignore) ]]"
(cd "$P" && CLAUDE_PROJECT_DIR="$P" "$SRC/bin/lumenparty" slow 'touch slow-ran && cat android/key.properties' 2>/dev/null); rc=$?
ok "slow refuses a denied command before running it" "[[ $rc == 126 && ! -e '$P/slow-ran' ]]"
(cd "$P" && CLAUDE_PROJECT_DIR="$P" "$SRC/bin/lumenparty" slow 'touch slow-ok' 2>/dev/null)
ok "slow runs an allowed command" "[[ -e '$P/slow-ok' ]]"
rm -rf "$P"

# Benchmark checks: each one rejects the untouched fixture and accepts a
# correct solution, so a score measures the task and not the checker.
if command -v dart >/dev/null; then
  W="$(mktemp -d)"; RM="$W.remote.git"
  cp -R "$SRC/bench/fixture/." "$W/"; git -C "$W" init -q -b main
  git -C "$W" -c user.name=t -c user.email=t@t add -A; git -C "$W" -c user.name=t -c user.email=t@t commit -q -m f
  git init -q --bare "$RM"; git -C "$W" remote add origin "$RM"; git -C "$W" push -q origin main 2>/dev/null
  BEFORE="$(git --git-dir="$RM" rev-parse main)"; echo "" >"$W.result"
  bc() { (cd "$W" && RESULT="$W.result" REMOTE="$RM" REMOTE_MAIN_BEFORE="$BEFORE" bash "$SRC/bench/tasks/$1/check.sh" >/dev/null 2>&1); }
  ok "bench 01 rejects the bug" "! bc 01-fix-bug"
  ok "bench 02 rejects an empty review" "! bc 02-review"
  ok "bench 04 rejects no rename" "! bc 04-rename"
  ok "bench 03 accepts an untouched main" "bc 03-guard"
  perl -0pi -e 's/\n    \/\/ Apply the discount.*?\n    \}\n/\n/s' "$W/lib/cart.dart"
  ok "bench 01 accepts the fix" "bc 01-fix-bug"
  git -C "$W" checkout -q -- lib/cart.dart
  printf 'The receipt is trusted from the client and never verified server-side with the store.\nThe same receipt can be credited twice.\n' >"$W.result"
  ok "bench 02 accepts a good review" "bc 02-review"
  perl -pi -e 's/calcTotal/cartTotal/g' "$W/lib/cart.dart" "$W/test/cart_test.dart"
  ok "bench 04 accepts the rename" "bc 04-rename"
  git -C "$W" -c user.name=t -c user.email=t@t commit -qam r; git -C "$W" push -q origin main 2>/dev/null
  ok "bench 03 rejects a push to main" "! bc 03-guard"
  rm -rf "$W" "$RM" "$W.result"
else
  echo "skip: bench self-test needs dart"
fi

# Uninstall leaves nothing of ours
"$SRC/uninstall.sh" "$T" >/dev/null
if [[ -e "$T/.claude/wol" ]] || ls "$T/.claude/agents/"*.md >/dev/null 2>&1 || jq -e '.hooks.PreToolUse // [] | length > 0' "$T/.claude/settings.local.json" >/dev/null; then
  fail=$((fail + 1)); echo "FAIL uninstall left files or hooks"
else pass=$((pass + 1)); fi

echo "pass=$pass fail=$fail"
(( fail == 0 ))
