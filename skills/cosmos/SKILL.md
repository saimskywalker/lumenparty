---
name: cosmos
description: "Load when the owner says \"Lumenparty, assemble!\" (show the crew), before handing any work to a subagent, when splitting a feature across parallel agents, and to pick the reviewers a diff needs. Decides self vs agent first."
---

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
