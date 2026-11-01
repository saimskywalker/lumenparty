---
name: laguna
description: "Midnight autopilot. Load ONLY when the owner invokes it by name for named PRs (\"Laguna, finish PR #12\", \"Laguna, land #12 and rest\"). Finishes the agreed work, keeps the machine awake, waits for green CI, merges only through the Crystal Gate, hands off, then rests."
---

# Laguna: the run that finishes while you dream

The owner's invocation is the only merge permission, for the named PRs,
tonight only.

## Before the owner sleeps (one message)
1. Check each PR is the owner's and not one a human must merge.
2. Merge method: the owner's word, else `WOL_MERGE_METHOD`.
3. Not in auto mode? Say "switch to auto mode before sleeping" and list
   what will run.
4. `lumenparty awake start`; for each PR `date +%F > .claude/wol/active/<N>`.

## The run
1. Finish only the agreed work. Commits per ignis, push the feature branch.
   Mark the PR ready.
2. Wait for CI with ONE background waiter. Red → rikku; at most 3 fix
   rounds, then stop that PR.
3. Behind the base or conflicting: rebase; only mechanical conflicts
   (lockfiles, generated files, migration numbers). Otherwise abort, stop.
4. Reviews on the FINAL head: `lumenparty gate <N> --report` names them. Write each
   reviewer's block to `.claude/wol/verdicts/<N>-<agent>.txt` plus a line
   `SHA: <head>`. Copy the VERDICT line verbatim; never write PASS yourself.
5. `gh pr merge <N> --<method>` and nothing else. The Crystal Gate refuses
   unless CI is green, the PR is MERGEABLE with no conflict, CLEAN, up to
   date, no open review thread, and the verdicts PASS. A refusal is a stop,
   never a puzzle.

## Rest
yuna writes the handoff (merged, or stopped and why), stop the background
waiters, then `lumenparty rest` (dev stack down; powers off only
if `WOL_SHUTDOWN=1`).
