# Changelog

## Unreleased

- Renamed to lumenparty (from Warriors of Light, `warriors-of-light-ai-agents`).
  The plugin is now `lumenparty`: reinstall with `/plugin install lumenparty
  --marketplace saimskywalker/lumenparty`, and plugin agents and skills are
  namespaced `lumenparty:<name>`. The command is now `lumenparty`; `wol` stays
  as an alias. The summon is "Lumenparty, assemble!". Settings and state stay
  in `.claude/wol/`.
- Protect closes the 0.2.0 bypasses. `lumenparty slow '<command>'` no longer
  skips the rules: Protect reads into its argument, and Slow runs Protect
  again before it starts (exit 126 when refused). Lines are split into simple
  commands with Perl's `Text::ParseWords`, so `;`, `&`, subshells, `{ }`,
  `if`, `!`, quoted branch names, `refs/heads/main`, `+src:dst` refspecs, an
  absolute git path, git's `--no-pager` / `-P` / `--git-dir` and inline
  aliases no longer hide a push. Pipes, here-docs and here-strings into a
  shell and `python -c` / `perl -e` / `node -e` one-liners are judged. Every
  `gh pr merge` in a line is gated, and `-R` / `--repo` / `GH_REPO` for
  another repository, `gh api graphql` merge or ref mutations and `curl` /
  `wget` writes to the GitHub API are refused. Runner prefixes (`bundle exec`,
  `npx`, `pnpm dlx`, `fvm`, `dart run` ...) are stripped; fastlane pilot /
  beta / upload_to_*, `xcrun altool --upload-app`, iTMSTransporter,
  `shorebird release|patch`, `eas update` to production,
  `firebase appdistribution:distribute` and Gradle `publish*` tasks are
  releases. Secret paths match case-insensitively and cover `.env*` (not
  `.env.example`), Play Store credentials and `gh/hosts.yml`, while an env
  file handed to a build (`--dart-define-from-file=.env`) stays allowed; `fvm flutter
  test`, `dart test` and `very_good test` without a path are full suites.
  The built-in release and secret rules apply on top of an older
  `config.sh`.

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
