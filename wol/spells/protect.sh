#!/usr/bin/env bash
# Protect — PreToolUse guard for Bash. Runs for the main session and every
# subagent, deterministically, at zero token cost. Judges every simple
# command the line would run (see unwrap.sh) and denies:
#   1. reading or copying secret files;
#   2. local merges; pushes to or from a protected branch, in any refspec
#      form; mirror / --all / delete / wildcard pushes; production tag pushes;
#   3. merges and ref writes through gh api (REST or GraphQL) or curl;
#   4. `gh pr merge` without a number, for another repo, or refused by the
#      Crystal Gate (every merge in the line is gated);
#   5. production tags, releases, workflow runs, deploys and store uploads;
#   6. WOL_BLOCK_LOCAL commands; 7. full test suites;
#   8. heavy commands not sent through the Slow queue (lumenparty slow).
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/../lib.sh"
raw="$(jq -r '.tool_input.command // empty')"
[[ -z "$raw" ]] && exit 0
# Judge what would really run: Unwrap prints one line per simple command,
# "<queued><TAB><words>", with wrappers, prefixes and quoting removed.
deny() {
  jq -n --arg r "Protect: $1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
tagged="$("$WOL/spells/unwrap.sh" <<<"$raw")" || deny "the command could not be read; write it out plainly."
[[ -z "$tagged" ]] && exit 0
grep -q '^!' <<<"$tagged" && deny "the command nests too deeply to be checked; write it out plainly."
cmd="$(cut -f2- <<<"$tagged")"
unqueued="$(grep '^0' <<<"$tagged" | cut -f2- || true)"
[[ "${WOL_QUEUED:-0}" == 1 ]] && unqueued=""
X=$'\x1f'
redir='^[0-9]*(>>?|<|<>|&>>?|>&|<&|>\|)$'
# A rule matches a command at its start, so an echo or a grep that merely
# mentions "git push origin main" is never blocked.
lines() { grep -E -- "^($1)" <<<"$cmd" || true; }
has() { grep -Eq -- "^($1)" <<<"$cmd"; }
hasi() { grep -Eiq -- "^($1)" <<<"$cmd"; }

# A command held in a variable cannot be read before it runs: refuse it
# when the line could push or merge.
seg='(^|[;&|(]|then|do)[[:space:]]*(command[[:space:]]+)?'
if grep -Eqi '\b(push|merge)\b' <<<"$raw"; then
  if grep -Eq "${seg}\"?\\\$[A-Za-z_{(]" <<<"$raw" || grep -Eq '^[^[:space:]=]*[$`]' <<<"$cmd"; then
    deny "a command held in a variable cannot be checked; write the git/gh command out in full."
  fi
fi

# 1. secrets: no word of a command (pattern of a grep, text of an echo and
#    multi-word messages and wrapped commands aside, which are judged on
#    their own lines) and no redirect may name a secret file. An
#    env file handed to a build as --dart-define-from-file (or another
#    --*define-from-file flag) is allowed: the build reads it, not the agent.
envfile='(^|/)\.env($|\.)'
secret="${WOL_SECRET_FILES:-}"; secret="${secret:+$secret|}${WOL_SECRET_ALWAYS}"
cands=""
while IFS= read -r l; do
  [[ -z "$l" ]] && continue
  read -ra w <<<"$l"
  c0="${w[0]}"; pat=0; exempt=0; msg=0; skipnext=0; candnext=0; envarg=0
  case "$c0" in grep|egrep|fgrep|rg|ag|ack) pat=1 ;; echo|printf|ls|test|'['|'[[') exempt=1 ;; git|gh|lumenparty|wol|slow.sh|sh|bash|zsh|dash|ksh|eval|watch) msg=1 ;; esac
  [[ "$c0" == git && "${w[1]:-}" == grep ]] && pat=1
  for ((k = 1; k < ${#w[@]}; k++)); do
    a="${w[k]}"
    if (( skipnext )); then skipnext=0; continue; fi
    if (( candnext )); then cands+="$a"$'\n'; candnext=0; continue; fi
    if [[ "$a" =~ $redir ]]; then candnext=1; continue; fi
    (( exempt )) && continue
    if (( pat )); then
      case "$a" in
        -e|--regexp) skipnext=1; pat=0; continue ;;
        -f|--file) candnext=1; pat=0; continue ;;
        -A|-B|-C|-m|-g|-t|-T|-j|-M|--glob|--type|--max-count|--context) skipnext=1; continue ;;
        -*) continue ;;
        *) pat=0; continue ;;
      esac
    fi
    if (( envarg )); then envarg=0; [[ "$a" =~ $envfile ]] && continue; fi
    case "$a" in
      --*define-from-file) envarg=1; continue ;;
      --*define-from-file=*) [[ "${a#*=}" =~ $envfile ]] && continue ;;
    esac
    (( msg )) && [[ "$a" == *"$X"* ]] && continue
    cands+="$a"$'\n'
  done
done <<<"$cmd"
hits="$(grep -Ei -- "(${secret})" <<<"${cands//$X/ }" | grep -Eiv -- "(${WOL_SECRET_OK})" || true)"
[[ -n "$hits" ]] && deny "secret files are never read or copied by the crew."

# 2. protected branches: no local merge, no push to them or from them,
#    no mirror / --all / delete / wildcard push, no production tag push
while IFS= read -r l; do
  [[ -z "$l" ]] && continue
  grep -Eq -- '(^|[[:space:]])--abort([[:space:]]|$)' <<<"$l" \
    || deny "no local merge; branches move by rebase, protected branches only by a gated PR merge."
done < <(lines 'git[[:space:]]+merge([[:space:]]|$)')
cur="$(git -C "$PROJECT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
while IFS= read -r l; do
  [[ -z "$l" ]] && continue
  grep -Eqx "(${WOL_PROTECTED})" <<<"$cur" && deny "no push while checked out on $cur."
  read -ra w <<<"$l"
  pos=(); byrepo=0; skip=0
  for ((k = 2; k < ${#w[@]}; k++)); do
    a="${w[k]}"
    if (( skip )); then skip=0; continue; fi
    if [[ "$a" =~ $redir ]]; then skip=1; continue; fi
    case "$a" in
      --mirror|--all|--prune|--delete) deny "mirror, --all, --prune and ref-deleting pushes are not allowed." ;;
      --tags|--follow-tags) deny "a production tag ships to users; the owner pushes it (skill: cid)." ;;
      --repo=*) byrepo=1 ;;
      --repo) byrepo=1; skip=1 ;;
      -o|--push-option|--receive-pack|--exec) skip=1 ;;
      --*) ;;
      -*d*) deny "mirror, --all, --prune and ref-deleting pushes are not allowed." ;;
      -*) ;;
      *) pos+=("$a") ;;
    esac
  done
  first=1; (( byrepo )) && first=0
  for ((k = first; k < ${#pos[@]}; k++)); do
    r="${pos[k]//$X/ }"
    case "$r" in *'$'* | *'`'*) deny "a refspec held in a variable cannot be checked; write the branch name out." ;; esac
    [[ "$r" == :* || "$r" == +:* ]] && deny "mirror, --all, --prune and ref-deleting pushes are not allowed."
    [[ "$r" == *'*'* ]] && deny "a wildcard refspec pushes many branches at once; name the branch."
    grep -Eq "^\+?([^:]*:)?(refs/heads/)?(${WOL_PROTECTED})$" <<<"$r" \
      && deny "no push to a protected branch; it moves only by a gated PR merge."
    grep -Eq "refs/tags/|^\+?([^:]*:)?(${WOL_PROD_TAG})$" <<<"$r" \
      && deny "a production tag ships to users; the owner pushes it (skill: cid)."
  done
done < <(lines 'git[[:space:]]+(push|send-pack)([[:space:]]|$)')

# 3. merges and ref writes outside the gate: gh api (REST and GraphQL), curl
while IFS= read -r l; do
  [[ -z "$l" ]] && continue
  grep -Eiq '/merge|/git/refs|/git/tags|/releases|/protection|/dispatches' <<<"$l" \
    && deny "gh api calls that merge, move refs, tag, release or dispatch are not allowed."
  grep -Eiq '(-X|--method)[[:space:]=]*(PUT|PATCH|DELETE)' <<<"$l" && grep -Eiq 'repos/' <<<"$l" \
    && deny "write calls to the repository API are not allowed."
  if grep -Eq '(^|[[:space:]])graphql([[:space:]]|$)' <<<"$l"; then
    grep -Eiq 'mergePullRequest|enablePullRequestAutoMerge|updateRefs?|createRef|deleteRef|mergeBranch|createCommitOnBranch|updatePullRequestBranch' <<<"$l" \
      && deny "GraphQL mutations that merge or move refs are not allowed."
    grep -Eq -- '--input|=@' <<<"$l" && deny "a GraphQL query read from a file cannot be checked; pass it inline."
  fi
done < <(lines 'gh[[:space:]]+api([[:space:]]|$)')
while IFS= read -r l; do
  [[ -z "$l" ]] && continue
  grep -Eiq '(-X|--request|--method)[[:space:]=]*(POST|PUT|PATCH|DELETE)|(^|[[:space:]])(-d|--data[a-z-]*|-F|--form|--json|-T|--upload-file|--post-data|--post-file|--body-data|--body-file)([[:space:]=]|$)|^(http|https|xh)[[:space:]]+(POST|PUT|PATCH|DELETE)' <<<"$l" || continue
  grep -Eiq 'api\.github\.com|/repos/[^[:space:]]*/(pulls/[0-9]+/merge|merges|git/refs|git/tags|releases|dispatches|branches/[^[:space:]]*/protection)|/graphql' <<<"$l" \
    && deny "write calls to the GitHub API outside gh are not allowed."
done < <(lines '(curl|wget|http|https|xh)([[:space:]]|$)')
lines 'gh[[:space:]]' | grep -Eq -- '(^|[[:space:]])--admin([[:space:]=]|$)' && deny "--admin bypasses every check; never used."

# 4. every `gh pr merge <N>` in the line goes through the Crystal Gate, for
#    this repository only
prs=(); repos=()
while IFS= read -r l; do
  [[ -z "$l" ]] && continue
  read -ra w <<<"$l"
  pr=""; skip=""
  for ((k = 3; k < ${#w[@]}; k++)); do
    a="${w[k]}"
    if [[ -n "$skip" ]]; then [[ "$skip" == repo ]] && repos+=("$a"); skip=""; continue; fi
    if [[ "$a" =~ $redir ]]; then skip=1; continue; fi
    case "$a" in
      --auto|--delete-branch) deny "no --auto and no branch deletion on merge." ;;
      -R|--repo) skip=repo ;;
      --repo=*) repos+=("${a#--repo=}") ;;
      -R?*) repos+=("${a#-R}") ;;
      -b|--body|-F|--body-file|-t|--subject|-A|--author-email|--match-head-commit) skip=1 ;;
      --*) ;;
      -*d*) deny "no --auto and no branch deletion on merge." ;;
      -*) ;;
      *) if [[ -z "$pr" ]]; then pr="$a"; fi ;;
    esac
  done
  pr="${pr#\#}"
  [[ "$pr" =~ ^[0-9]+$ ]] || deny "gh pr merge needs an explicit PR number."
  prs+=("$pr")
done < <(lines 'gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)')
if (( ${#prs[@]} )); then
  here="$(git remote get-url origin 2>/dev/null | sed -E 's#^[a-z+]+://([^@/]*@)?[^/]+/##; s#^[^@/:]*@[^:]+:##; s#\.git$##' | tr '[:upper:]' '[:lower:]' || true)"
  envs="$(grep -Eo 'GH_(REPO|HOST)=[^[:space:];&|)]*' <<<"$raw" || true)"
  [[ -n "${GH_REPO:-}" ]] && envs+=$'\n'"GH_REPO=$GH_REPO"
  [[ -n "${GH_HOST:-}" ]] && envs+=$'\n'"GH_HOST=$GH_HOST"
  while IFS= read -r e; do
    [[ -z "$e" ]] && continue
    v="${e#*=}"; v="${v//\"/}"; v="${v//\'/}"
    case "$e" in
      GH_HOST=*) [[ "$v" == github.com ]] || deny "gh pr merge against another host is not allowed." ;;
      GH_REPO=*) repos+=("$v") ;;
    esac
  done <<<"$envs"
  for ((k = 0; k < ${#repos[@]}; k++)); do
    r="$(tr '[:upper:]' '[:lower:]' <<<"${repos[k]}")"; r="${r#https://}"; r="${r#github.com/}"
    [[ -n "$here" && "$r" == "$here" ]] \
      || deny "gh pr merge for another repository ($r) is not allowed; the gate checks this one."
  done
  has '(cd|pushd)([[:space:]]|$)' && deny "run gh pr merge from the project folder, not after cd."
  for ((k = 0; k < ${#prs[@]}; k++)); do
    why="$("$WOL/crystal/gate.sh" "${prs[k]}" 2>&1)" || deny "the Crystal Gate refused #${prs[k]}: $why"
  done
fi

# 5. production: tags, releases, workflow runs, deploys and store uploads
while IFS= read -r l; do
  [[ -z "$l" ]] && continue
  grep -Eq -- '(^|[[:space:]])(-d|--delete|-l|--list|-v|--verify)([[:space:]]|$)' <<<"$l" && continue
  grep -Eq "(^|[[:space:]])(${WOL_PROD_TAG})([[:space:]]|$)" <<<"$l" \
    && deny "creating a production tag is the owner's step (skill: cid)."
done < <(lines 'git[[:space:]]+tag([[:space:]]|$)')
has 'gh[[:space:]]+(release[[:space:]]+(create|upload|edit)|workflow[[:space:]]+run)([[:space:]]|$)' \
  && deny "releases and workflow runs are started by the owner."
ship="${WOL_DEPLOY_BLOCK:-}"; ship="${ship:+$ship|}${WOL_RELEASE_ALWAYS}"
hasi "$ship" && deny "deploys, store uploads and releases are the owner's step (skill: cid)."

# 6. CI-only commands
if [[ -n "${WOL_BLOCK_LOCAL:-}" ]] && has "${WOL_BLOCK_LOCAL}" && [[ ! -e "$STATE/allow-local" ]]; then
  deny "this command runs in CI, not on this machine (WOL_BLOCK_LOCAL). Override: touch .claude/wol/allow-local"
fi

# 7. full test suites
if [[ "${WOL_FULL_SUITE_BLOCK:-1}" == 1 ]]; then
  while IFS= read -r l; do
    [[ -z "$l" ]] && continue
    grep -Eq '(\.dart|(^|[[:space:]])(integration_)?test/)' <<<"$l" \
      || deny "full test suite is off; name the test files (flutter test test/a_test.dart ...)."
  done < <(lines '(flutter|dart|very_good)[[:space:]]+test([[:space:]]|$)')
fi

# 8. heavy commands go through the queue (Slow runs Protect on them again)
if [[ -n "${WOL_HEAVY:-}" ]] && [[ -n "$unqueued" ]] && grep -Eq -- "^(${WOL_HEAVY})\b" <<<"$unqueued"; then
  deny "heavy command; queue it: lumenparty slow '<command>' (after install.sh: .claude/wol/bin/lumenparty slow '<command>'): one at a time, low priority, memory check, time limit, log."
fi

exit 0
