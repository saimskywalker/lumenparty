#!/usr/bin/env bash
# Protect — PreToolUse guard for Bash. Runs for the main session and every
# subagent, deterministically, at zero token cost. Denies:
#   1. commands listed in WOL_BLOCK_LOCAL (CI-only work on this machine);
#   2. a full `flutter test` (no test path) and check scripts that run all;
#   3. heavy commands not sent through spells/slow.sh;
#   4. every road to a protected branch: local merge, push to it, force /
#      mirror / delete pushes, gh api merge or ref writes, --admin, --auto;
#   5. a production tag, release or workflow dispatch, and deploy commands;
#   6. reading secret files;
#   and sends `gh pr merge <N>` through the Crystal Gate.
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/../lib.sh"
raw="$(jq -r '.tool_input.command // empty')"
[[ -z "$raw" ]] && exit 0
# Judge what would really run: the command plus everything wrapped inside
# it (sh -c, eval, $(...), env/nice/sudo prefixes, git -C <dir>).
cmd="$("$WOL/spells/unwrap.sh" <<<"$raw")"

deny() {
  jq -n --arg r "Protect: $1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
has() { grep -Eq -- "$1" <<<"$cmd"; }
hasi() { grep -Eqi -- "$1" <<<"$cmd"; }
# A command word counts only at the start of a shell segment, so an echo or
# a grep that merely mentions "flutter test" is never blocked.
seg='(^|[;&|(]|then|do)[[:space:]]*(command[[:space:]]+)?'
parts() { perl -pe 's/(&&|\|\||;|\|)/\n/g' <<<"$cmd"; }

# 1. CI-only commands
if [[ -n "${WOL_BLOCK_LOCAL:-}" ]] && has "${seg}(${WOL_BLOCK_LOCAL})" && [[ ! -e "$STATE/allow-local" ]]; then
  deny "this command runs in CI, not on this machine (WOL_BLOCK_LOCAL). Override: touch .claude/wol/allow-local"
fi

# 2. full Flutter suite
if [[ "${WOL_FULL_SUITE_BLOCK:-1}" == 1 ]]; then
  while IFS= read -r part; do
    if grep -Eq '^[[:space:]]*(command[[:space:]]+)?flutter[[:space:]]+test\b' <<<"$part" \
      && ! grep -Eq '(\.dart|(^|[[:space:]])(integration_)?test/)' <<<"$part"; then
      deny "full flutter test is off; name the test files (flutter test test/a_test.dart ...)."
    fi
  done < <(parts)
fi

# 3. heavy commands go through the queue
if [[ -n "${WOL_HEAVY:-}" ]] && has "${seg}(${WOL_HEAVY})\b" && ! has 'spells/slow\.sh|(^|[;&|/[:space:]])(lumenparty|wol)[[:space:]]+slow\b'; then
  deny "heavy command; queue it: lumenparty slow '<command>' (after install.sh: .claude/wol/bin/lumenparty slow '<command>'): one at a time, low priority, memory check, time limit, log."
fi

# 4. every road to a protected branch
prot="(${WOL_PROTECTED})"
# A command held in a variable cannot be read before it runs: refuse it
# when the line could push or merge.
if grep -Eq "${seg}\"?\\\$[A-Za-z_{(]" <<<"$raw" && grep -Eqi '\b(push|merge)\b' <<<"$raw"; then
  deny "a command held in a variable cannot be checked; write the git/gh command out in full."
fi
has "${seg}git[[:space:]]+merge\b" && ! has 'git[[:space:]]+merge[[:space:]]+--abort' \
  && deny "no local merge; branches move by rebase, protected branches only by a gated PR merge."
while IFS= read -r part; do
  p() { grep -Eq -- "$1" <<<"$part"; }
  if p '^[[:space:]]*git[[:space:]]+push\b'; then
    p '--mirror|--all|--delete|[[:space:]]-d([[:space:]]|$)|[[:space:]]:[^[:space:]]+' \
      && deny "mirror, --all and ref-deleting pushes are not allowed."
    p "[[:space:]+:]${prot}([[:space:]]|$)" && deny "no push to a protected branch; it moves only by a gated PR merge."
    p "--tags|--follow-tags|refs/tags/|[[:space:]]${WOL_PROD_TAG}([[:space:]]|$)" \
      && deny "a production tag ships to users; the owner pushes it (skill: cid)."
  fi
done < <(parts)
cur="$(git -C "$PROJECT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
if has "${seg}git[[:space:]]+push\b" && grep -Eqx "${prot}" <<<"$cur"; then
  deny "no push while checked out on $cur."
fi
if has "${seg}gh[[:space:]]+api\b"; then
  hasi '/merge|/git/refs|/git/tags|/releases|/protection|/dispatches' \
    && deny "gh api calls that merge, move refs, tag, release or dispatch are not allowed."
  hasi '(-X|--method)[[:space:]]*(PUT|PATCH|DELETE)' && hasi 'repos/' \
    && deny "write calls to the repository API are not allowed."
fi
has '--admin' && has "${seg}gh[[:space:]]" && deny "--admin bypasses every check; never used."
if has "${seg}gh[[:space:]]+pr[[:space:]]+merge\b"; then
  pr="$(grep -Eo 'gh[[:space:]]+pr[[:space:]]+merge[[:space:]]+#?[0-9]+' <<<"$cmd" | grep -Eo '[0-9]+$' | head -1 || true)"
  [[ -z "$pr" ]] && deny "gh pr merge needs an explicit PR number."
  has '--auto|--delete-branch|[[:space:]]-d([[:space:]]|$)' && deny "no --auto and no branch deletion on merge."
  why="$("$WOL/crystal/gate.sh" "$pr" 2>&1)" || deny "the Crystal Gate refused #$pr: $why"
fi

# 5. production
has "${seg}git[[:space:]]+tag[[:space:]]+(-[as][[:space:]]+)?${WOL_PROD_TAG}([[:space:]]|$)" \
  && deny "creating a production tag is the owner's step (skill: cid)."
has "${seg}gh[[:space:]]+(release[[:space:]]+create|workflow[[:space:]]+run)\b" \
  && deny "releases and workflow runs are started by the owner."
[[ -n "${WOL_DEPLOY_BLOCK:-}" ]] && hasi "${seg}(${WOL_DEPLOY_BLOCK})" \
  && deny "deploys and store submissions are the owner's step (skill: cid)."

# 6. secrets
while IFS= read -r part; do
  if grep -Eq '^[[:space:]]*(cat|less|more|head|tail|bat|base64|xxd|strings|cp|scp|open|pbcopy|xclip)\b' <<<"$part"; then
    for w in $part; do
      grep -Eq -- "(${WOL_SECRET_FILES})" <<<"$w" && deny "secret files are never read or copied by the crew."
    done
  fi
done < <(parts)

exit 0
