#!/usr/bin/env bash
# The Crystal Gate — called by Protect for every `gh pr merge <N>`.
# Exit 0 only when every condition holds, read live from GitHub:
#   - Laguna was invoked for this PR today (active/<N> = today);
#   - the PR is WOL_OWNER's, targets WOL_BASE, is not a draft, carries no
#     `needs-human` label, has no review requested from WOL_HUMAN_ONLY_REVIEWERS;
#   - MERGEABLE (no conflict with the base) and mergeStateStatus CLEAN;
#   - every check on the head finished green, none pending;
#   - the head is up to date with the base (CI tested today's base);
#   - no unresolved review thread;
#   - no WOL_GATE_HUMAN path (CI, release, infra: a human merges those);
#   - a PASS verdict for the head SHA from each reviewer the diff needs.
#
#   gate.sh <N>            the gate
#   gate.sh <N> --report   every line, pass or fail
set -uo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/../lib.sh"
pr="${1:?usage: gate.sh <pr> [--report]}"
report=0; [[ "${2:-}" == "--report" ]] && report=1
fail=0
no() { echo "✗ $*"; fail=1; (( report )) || exit 1; }
ok() { (( report )) && echo "✓ $*"; return 0; }

repo="$(wol_gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || { echo "✗ not a GitHub repo"; exit 1; }
[[ -n "${WOL_OWNER:-}" ]] || no "WOL_OWNER is empty in .claude/wol/config.sh: the gate refuses every merge"

tok="$STATE/active/$pr"
[[ -f "$tok" && "$(cat "$tok")" == "$(date +%F)" ]] && ok "Laguna invoked for #$pr today" \
  || no "Laguna was not invoked for #$pr today; outside that run only a human merges"

j="$(wol_gh pr view "$pr" --repo "$repo" --json author,isDraft,mergeable,mergeStateStatus,labels,headRefOid,baseRefName,reviewRequests,files,statusCheckRollup 2>/dev/null)" \
  || { echo "✗ cannot read PR #$pr"; exit 1; }
q() { jq -r "$1" <<<"$j"; }
head="$(q .headRefOid)"

[[ "$(q .author.login)" == "${WOL_OWNER:-}" ]] && ok "author is the owner" || no "author is $(q .author.login), not WOL_OWNER"
[[ "$(q .baseRefName)" == "$WOL_BASE" ]] && ok "base is $WOL_BASE" || no "base is $(q .baseRefName), not $WOL_BASE"
[[ "$(q .isDraft)" == "false" ]] && ok "not a draft" || no "still a draft"
q '[.labels[].name] | index("needs-human")' | grep -q null && ok "no needs-human label" || no "labelled needs-human"
if [[ -n "${WOL_HUMAN_ONLY_REVIEWERS:-}" ]] && q '[.reviewRequests[] | (.login // .name)] | join(" ")' | grep -Eqw -- "(${WOL_HUMAN_ONLY_REVIEWERS})"; then
  no "review requested from a human-only reviewer"
fi

[[ "$(q .mergeable)" == "MERGEABLE" ]] && ok "mergeable, no conflict" || no "mergeable=$(q .mergeable)"
[[ "$(q .mergeStateStatus)" == "CLEAN" ]] && ok "merge state CLEAN" || no "mergeStateStatus=$(q .mergeStateStatus)"

total="$(q '.statusCheckRollup | length')"
bad="$(q '[.statusCheckRollup[] | select(
    (.__typename == "CheckRun" and ((.status != "COMPLETED") or ((.conclusion // "") | IN("SUCCESS","SKIPPED","NEUTRAL") | not)))
    or (.__typename == "StatusContext" and .state != "SUCCESS"))
  | (.name // .context) + "=" + (if ((.conclusion // "") == "") then (.status // .state // "?") else .conclusion end | tostring)] | join(", ")')"
(( total > 0 )) || no "no checks reported on the head"
[[ -z "$bad" ]] && ok "all $total checks green" || no "checks not green: $bad"

behind="$(wol_gh api "repos/$repo/compare/$WOL_BASE...$head" --jq .behind_by 2>/dev/null || echo '?')"
[[ "$behind" == "0" ]] && ok "up to date with $WOL_BASE" || no "behind $WOL_BASE by $behind: rebase and let CI run again"

owner="${repo%%/*}"; name="${repo##*/}"
open="$(wol_gh api graphql -f query="query{repository(owner:\"$owner\",name:\"$name\"){pullRequest(number:$pr){reviewThreads(first:100){nodes{isResolved}}}}}" \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)] | length' 2>/dev/null || echo '?')"
[[ "$open" == "0" ]] && ok "no unresolved review thread" || no "unresolved review threads: $open"

files="$(q '.files[].path')"
grep -Eq -- "(${WOL_GATE_HUMAN})" <<<"$files" && no "touches CI, release or infra files: a human merges it"
need=()
grep -Eiq -- "(${WOL_GATE_SECURITY})" <<<"$files" && need+=(noctis)
grep -Eq -- "(${WOL_GATE_COPY})" <<<"$files" && need+=(terra)
grep -Eq -- "(${WOL_GATE_DB})" <<<"$files" && need+=(shantotto)
for a in "${need[@]:-}"; do
  [[ -z "$a" ]] && continue
  v="$STATE/verdicts/$pr-$a.txt"
  if [[ -f "$v" ]] && grep -qx "VERDICT: PASS" "$v" && grep -qx "SHA: $head" "$v"; then ok "$a PASS for ${head:0:9}"
  else no "$a verdict PASS for head ${head:0:9} missing (.claude/wol/verdicts/$pr-$a.txt)"; fi
done

(( fail )) && exit 1
(( report )) && echo "✓ #$pr may be merged"
exit 0
