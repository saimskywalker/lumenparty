"""Generates skills/<name>/SKILL.md. Edit here, then run: python3 tools/gen_skills.py"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = {}

S["cosmos"] = ("""Load when the owner says "Lumenparty, assemble!" (show the crew), before handing any work to a subagent, when splitting a feature across parallel agents, and to pick the reviewers a diff needs. Decides self vs agent first.""", """
# Cosmos: the one who summons

The owner is **Cosmos**, the one who summons the party. The main
session acts in the owner's name and decides who is called.

## Summon: "Lumenparty, assemble!"

SHOW the crew, spawn NOTHING. Answer in the owner's language
(`WOL_LANG` in `.claude/wol/config.sh`), opening with:

> 「仲間たちよ、クリスタルが汝らを選んだ。集え——このコードに調和を取り戻すために。」
> *"Party, the crystals have chosen you. Gather, and restore harmony to this code."* — Cosmos

Then, one screen: the self-first rule; the heroes (name, role, model,
access); the skills and when each loads; the spells; the Crystal Gate; the
pipelines, one line each; how to call them ("Cosmos, send Noctis to review
PR #12", "Cid, prepare release 2.3.0", "Aerith, run the health check").

## 0. Self first (mana is precious)

An agent starts with no context and re-reads what the session already
knows, so a small job costs MORE through an agent. Work in the main session
unless one of these holds:
- the owner asked for a hero by name;
- the work splits into independent parts that run in PARALLEL;
- answering means reading many files and only the conclusion is needed;
- an independent review is wanted, once per PR-ready point.
Never for a 1-3 file change, a single lookup, or something already in
context. Say in one line which hero ran and why.

Models: haiku gathers, sonnet builds and reads deep, opus judges risk.
Reviewers return a VERDICT block, never diffs or logs.

## 1. Conditional gates (what the diff touches → whose PASS it needs)

| Diff touches (patterns in config.sh) | Needs PASS from |
|---|---|
| `WOL_GATE_SECURITY`: auth, session, payment, IAP, webhook, admin, upload | noctis |
| `WOL_GATE_COPY`: i18n files, store listing, permission strings | terra |
| `WOL_GATE_DB`: migrations, schema | shantotto |
| UI files | rosa (skill, advisory) |
| `WOL_GATE_HUMAN`: CI, release, infra | a human merges |

`lumenparty gate <N> --report` prints the same list for a PR. (`lumenparty` is on PATH with
the plugin; after install.sh it is `.claude/wol/bin/lumenparty`.)
PASS continues, BLOCK is a fix round, NEEDS-HUMAN stops and asks.

## 2. A parallel job

Write ONE brief file first (decisions already made, literal contracts:
endpoints, JSON keys, routes, i18n keys; an ownership table so no two
heroes edit one file; shared files such as the router and i18n stay with
the session; the gates). Each prompt: "read brief.md, you are X, touch only
your files, return conclusions". Then merge their notes, run each gate
once through the Slow queue, review once, commit per area (skill: ignis).
""")

S["auron"] = ("""Load BEFORE writing or changing any code, by the main session or any builder. The code rules: read first, the laziness ladder (the least code that works), the never-cut list, the 300/500 line limits, write-it-right-once, fast by default.""", """
# Auron: no wasted motion

A legendary guardian wastes no swing. Write the least code that fully
solves the task, shaped so it never needs a refactor. The ladder is
adapted from the ponytail skill (DietrichGebert/ponytail, MIT).

## 1. Read first, then climb the ladder

Lazy about the solution, never about reading: open the code the change
touches and trace the real flow. Then stop at the FIRST rung that holds:
1. Does this need to exist at all?
2. Is it already in this codebase? (search before writing a helper,
   widget, hook, provider, query, i18n key)
3. Does the standard library do it?
4. Is there a platform or framework feature? (a Material widget, a browser
   API, a router feature, the database itself)
5. Is there a dependency already installed? Never add one for a few lines.
6. Can it be one line?
7. Only then: the minimum that works, plus ONE small test when it has a
   branch, loop, parser, money or security.

## 2. Never cut

Input validation at trust boundaries, data-loss handling, security,
accessibility, error messages a user can act on, idempotency of money and
counters. Small because necessary, never golfed. A deliberate shortcut gets
`// shortcut: <what> — revisit when <condition>`.

## 3. File size (enforced by the Mini spell)

Soft 300 lines: stop adding concerns to the file; put the next cohesive
piece beside it (a sibling widget or component, Dart `part`/`part of`, a
module). Hard 500: a change may not take a file over it or grow one
already over it. Generated files, i18n, migrations and tests are exempt.
The fix is cohesion, never line golf.

## 4. Write it right once

Follow the surrounding code (naming, comment density, layering). `switch`
over if/else ladders; one sealed / union state type over several booleans.
Inline first, extract on the third real use. No drive-by refactors in a
feature change (note them for cecil).

## 5. Fast by default (measured, not guessed)

No N+1: one query or batched endpoint per list. One poll per screen, opt-in.
Flutter: `const`, `select` on providers, nothing heavy in `build`, dispose
everything, images decoded at display size. Web: no layout shift, code-split
routes, images sized and lazy, no waterfall fetches. Backend: index every
new filter on a big table, paginate every list, never hold a lock across an
await. Optimise a hot path only with a number.

## 6. Close every change

Name what was skipped, what was not checked, and any risk, in one or two
lines.
""")

S["lulu"] = ("""Load BEFORE running builds, tests, analyzers or code generators on this machine. Owns the local-run limits: the Slow queue, no full suites, CI-only commands, quoting and timeouts.""", """
# Lulu: power, controlled

A black mage who never wastes a spell. The machine is shared by the session
and every hero; heavy work runs one at a time.

1. Heavy commands (`WOL_HEAVY`) run only through the queue, never directly:
   `lumenparty slow 'flutter test test/a_test.dart test/b_test.dart'` (after install.sh:
   `.claude/wol/bin/lumenparty slow '...'`).
   The Protect spell denies them otherwise.
2. Narrowest command that proves the change: the touched test files, the
   touched files' analysis. Never the full suite locally; that is CI's job.
3. `WOL_BLOCK_LOCAL` commands run in CI only. The owner can allow them by
   creating `.claude/wol/allow-local`; never create it yourself.
4. Parallel heroes are fine; parallel heavy runs are not.
5. Quote globs; prefer the tool's own timeout parameter.
6. `lumenparty libra` shows the queue holder, heavy processes,
   free memory and recent runs. A stale lock is reclaimed automatically.
""")

S["ignis"] = ("""Load before any commit, rebase, push, or PR / issue text. Owns commit shape, autosquash, PR bodies, and the never-merge / no-AI-attribution rules.""", """
# Ignis: every detail in its place

1. One PR per feature; one commit per area (app, backend, web, infra) when
   the owner wants it; fixups + `GIT_SEQUENCE_EDITOR=: git rebase -i
   --autosquash origin/<base>`, then `git push --force-with-lease` on the
   feature branch only.
2. Audit before every commit: `git status --short` and
   `git diff --cached --name-only`. Nothing from another task, no secrets,
   no generated noise the project does not commit.
3. Commit messages: what changed and why, in the project's style. No AI
   attribution of any kind unless the owner asks for it.
4. PR body: the problem, the change, how it was verified (commands and
   results), risks, screenshots for UI, and the linked issue.
5. Never merge, never push a protected branch, never switch the git
   strategy the owner chose. Merges happen only through Laguna and the
   Crystal Gate, or by a human.
6. Commit only when the owner says so.
""")

S["rikku"] = ("""Load when a PR has red or cancelled checks, or when asked why CI failed.""", """
# Rikku: take the machine apart, find the broken gear

1. Send lightning for the failing items (file:line + first real error).
2. Classify: REAL (fix it), FLAKE (rerun once, then treat as REAL),
   INFRA (runner lost, cancelled, quota: rerun, do not touch code).
3. REAL static errors → warrior-of-light; REAL test failures → clive.
4. Reproduce locally only with the narrowest command, through the queue.
5. After a fix: push, wait with ONE background waiter, report each check.
Never mark a check as passing by skipping it or loosening a test.
""")

S["lunafreya"] = ("""Load when asked what is waiting on a person, for a decision or review recap, a standup, or a chat draft chasing open issues and PRs.""", """
# Lunafreya: the messenger

1. vaan collects: open issues/PRs where the person was @-mentioned and has
   not replied since, classified DECISION / REVIEW / FYI.
2. Draft the message in the owner's language: lead with the asks, one line
   each with the link, newest first, FYI compressed to one line of links.
3. Questions as options with the recommended one first; no imperative
   tone; never guess a person's name.
4. Save as a DRAFT only. Sending is the owner's click.
""")

S["relm"] = ("""Load for any Figma → code work (a Figma URL or node id, "implement this screen"), for Flutter or web.""", """
# Relm: paint it exactly

1. bartz first: the design system and the frames, returned as a spec.
2. Map before calling: keep a node → component table in the repo
   (e.g. `docs/FIGMA-MAP.md`); a mapped node costs zero Figma calls.
3. Budget: one design-context call per COMPONENT, never per screen;
   variables for tokens; export every icon instead of drawing it.
4. Conversion traps: Figma line-height px is a multiplier in Flutter
   (`height`); a 360-wide frame is a constraint, not a fixed width; only
   bundled font weights exist; auto-layout gaps become `spacing` / `gap`.
5. zidane builds; compare against a screenshot of the frame at the end.
6. A refused or rate-limited call: stop and report; never draw from a
   screenshot.
""")

S["laguna"] = ("""Midnight autopilot. Load ONLY when the owner invokes it by name for named PRs ("Laguna, finish PR #12", "Laguna, land #12 and rest"). Finishes the agreed work, keeps the machine awake, waits for green CI, merges only through the Crystal Gate, hands off, then rests.""", """
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
""")

S["yuna"] = ("""Load before the owner clears context or ends a session ("handoff", "I'm clearing context"), and at the end of a Laguna run. The Sending: nothing important is left behind.""", """
# Yuna: the Sending

1. Collect from this conversation and git: PRs touched (state, CI, what is
   left), decisions with absolute dates, open questions and who owns them,
   promised follow-ups, unpushed or stashed work.
2. Write ONE handoff note where the next session will read it (the
   project's memory or `docs/HANDOFF.md` if the owner keeps one), leading
   with the first thing to do.
3. Follow-ups that belong to the team: ready-to-paste issue text, posted
   only when the owner says so.
4. Stop the background waiters this session started.
5. Tell the owner, briefly, what was saved and where.
""")

S["steiner"] = ("""Load when a leak or breach is suspected or found: a secret committed or pasted, a token or personal data seen where it should not be, a critical finding from firion or noctis, an unexplained admin action or payment. Contain, rotate, revoke, verify, record.""", """
# Steiner: the knight holds the gate

Prepare every step; run a production-changing step only on the owner's
explicit go for that step.

1. Triage (read-only, minutes): what leaked, since when, where visible,
   which environment, which users. Severity in three lines to the owner.
2. Contain: a secret in a public place is burned even if deleted (forks,
   caches). Disable the exposed key or flow; revoke sessions of a taken
   account first.
3. Rotate in order: new value in the secret store (never in git) → deploy
   or restart what reads it → revoke the old value at the provider
   (Firebase, Apple, Google, Stripe, Supabase, cloud keys). Mobile trap: an
   app secret baked into released builds needs a new app release.
4. Agent credentials are credentials too: MCP logins, read-only database
   URLs, CLI tokens. Rotate those as well.
5. Verify: the old value is refused, logs show who used it, firion sweeps
   for a second copy.
6. Record: a private timeline (no secret values), and the follow-up fix.
""")

S["cid"] = ("""Load when the owner asks to prepare or ship a release ("Cid, prepare release 2.3.0", a store build, a production tag, a staged rollout). Prepares everything, then ALWAYS stops for the owner; the crew never pushes a production tag, deploys or submits to a store.""", """
# Cid: the airship is ready, the captain says when

1. Prepare: the exact version (name and build number), the changelog since
   the last tag, the checklist, and the gates on the release diff (noctis,
   shantotto for migrations, terra for store copy, yshtola for the current
   crash baseline).
2. Pre-flight: the release commit is on the base branch; config that a new
   build depends on ships with or after it; mobile version name bumped for
   every store submission; release notes in every store language.
3. STOP. One screen: version, contents, verdicts, risks, the exact
   commands. The owner pushes the tag / submits / promotes the rollout.
   The Protect spell blocks those commands for the crew anyway.
4. After release, on the owner's word: watch the pipeline; 24 h later
   yshtola (and luneth) compare the new version with the previous one
   against the thresholds; the owner moves the rollout.
""")

S["aerith"] = ("""Load when the owner asks for the health check ("Aerith, run the health check"). Runs the read-only monitors in parallel and returns one summary.""", """
# Aerith: the morning rounds

On the owner's word (a cloud schedule usually cannot reach local MCP logins).

1. Pre-check the sources: crash tool MCP, analytics, read-only database.
   Skip a missing one and say so.
2. In PARALLEL (a legitimate fan-out): yshtola (crashes, last 24 h and 7
   days, new in the newest version), luneth (performance and funnels vs
   thresholds), shantotto (counts only: stuck jobs, failed payments or
   webhooks, error spikes, queue backlogs).
3. One screen: 🔴 act today / 🟡 watch / 🟢 fine, each with the number and a
   link or file:line. Any BLOCK is 🔴. Offer a crash pipeline for a 🔴 crash
   and a lunafreya draft for the team.
Never writes to any monitored system.
""")

S["rosa"] = ("""Load on any UI change (Flutter widgets, web components, screens) before it is called done. Accessibility review: semantics, contrast, text scale, focus, touch targets, motion.""", """
# Rosa: no one is left behind

Check the changed UI, citing file:line:
1. Semantics: every interactive element has a label (Flutter `Semantics`,
   `tooltip`, web `aria-*` / alt text); images decorative or described.
2. Contrast: text 4.5:1, large text and icons 3:1, in light and dark.
3. Text scale: nothing clips or overlaps at 200% (Flutter textScaler, web
   zoom); no fixed-height text containers.
4. Focus and keyboard: logical order, visible focus, no traps; web reachable
   by keyboard alone.
5. Touch targets: at least 48x48 dp (44 pt iOS).
6. Motion: respects reduce-motion; nothing flashes.
7. Screen readers announce state changes (loading, errors, success).
Return the VERDICT block (AGENT: rosa); it is advisory for the Crystal Gate.
""")

S["ashe"] = ("""Load before a store submission, or on any change to purchases, subscriptions, permissions, login options, account deletion, privacy manifests or store metadata. The App Store and Google Play review checklist.""", """
# Ashe: the queen negotiates with the stores

Check against the current store guidelines (state the date you read them):
1. Purchases of digital goods use the store's billing where required; no
   links or copy steering users to outside payment where it is forbidden;
   restore purchases is reachable.
2. Subscriptions: price, period, renewal and how to cancel shown before the
   purchase.
3. Sign-in: if third-party login is offered, the platform's required
   option is offered too; account deletion is reachable in the app.
4. Permissions: each usage string names the feature and gives an example;
   nothing is requested before it is needed.
5. Privacy: the privacy manifest / data-safety form matches what the app
   and its SDKs actually collect; tracking consent before tracking.
6. Background modes and foreground services: each one has a feature a
   reviewer can see.
7. Reviewer notes: a demo account, and anything the reviewer will meet
   (paywalls, region locks, capture restrictions) explained up front.
Return the VERDICT block (AGENT: ashe).
""")

for n, (desc, body) in S.items():
    d = os.path.join(ROOT, "skills", n); os.makedirs(d, exist_ok=True)
    safe = desc.replace("\\", "\\\\").replace('"', '\\"')
    open(os.path.join(d, "SKILL.md"), "w").write(f'---\nname: {n}\ndescription: "{safe}"\n---\n{body}')
print(len(S), "skills")
