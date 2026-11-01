# Changelog

## Unreleased

- Renamed to lumenparty (from Warriors of Light, `warriors-of-light-ai-agents`).
  The plugin is now `lumenparty`: reinstall with `/plugin install lumenparty
  --marketplace saimskywalker/lumenparty`, and plugin agents and skills are
  namespaced `lumenparty:<name>`. The command is now `lumenparty`; `wol` stays
  as an alias. The summon is "Lumenparty, assemble!". Settings and state stay
  in `.claude/wol/`.

## 0.2.0 — 2026-10-22

- `bench/`: four tasks scored by objective checks, run in a plain project
  and with the crew; `bench/run.sh --dry` checks the plumbing for free. Issue
  forms for benchmark results and hero feedback. (#3)
- An up-to-date Indonesian README, with a language switch at the top of both READMEs. (#21)
- Installs as a Claude Code plugin: `/plugin install warriors-of-light --marketplace
  saimskywalker/warriors-of-light-ai-agents`. Spells load as plugin hooks; a `wol` command
  (init, slow, gate, libra, awake, rest) is on PATH. Settings and runtime state
  stay in the project's `.claude/wol/`, and a project `config.sh` overrides the
  defaults instead of replacing them. `install.sh` keeps working. (#1)
- Protect judges wrapped commands: `sh -c`, `bash -c`, `eval`, `$(...)`,
  backticks, `env` / `nice` / `nohup` / `sudo` / `xargs` / `command`
  prefixes, a leading backslash and git `-C` / `-c`. A command held in a
  variable is refused when it could push or merge. (#2)

## 0.1.0

First summon.

- 16 heroes (subagents) with one VERDICT block for every reviewer.
- 14 skills, including the Auron code rules (laziness ladder, never-cut list,
  300/500 line limits) and the Laguna midnight run.
- Spells: Protect (shell guard), Shell (secret files), Silence (read-only
  SQL), Mini (file size), Slow (heavy-work queue), plus Libra (status).
- The Crystal Gate: merges only when CI is green, the PR is mergeable with
  no conflict, up to date, review threads resolved and the required
  verdicts PASS for the head commit.
- `install.sh` (personal or `--team`, presets flutter / web / fullstack),
  `uninstall.sh`, and a test suite run in CI.
