# Contributing

Thanks for joining the party.

## Ground rules

- **Agents and skills are generated.** Edit `tools/gen_agents.py` or
  `tools/gen_skills.py`, run both, and commit the generated files with it.
  CI fails if they drift.
- **A spell change needs a test case.** Add a line to `tests/cases.txt`
  (`expected|bash|read|sql|input`) that fails before your change and passes
  after, then run `tests/run.sh`.
- **Shell stays portable**: bash 3.2 (macOS) and Linux, `shellcheck -S warning` clean.
- **Least code that works** (skill: auron). No new dependencies for the
  spells beyond `jq`, `git`, `perl`.
- **Project-agnostic.** No company, product or person names; patterns go in
  `wol/config.sh` or a preset, not hardcoded in a spell.

## Good first contributions

- A preset: React Native, Kotlin Multiplatform, SwiftUI, Laravel, Django.
- Deploy commands for more platforms in `WOL_DEPLOY_BLOCK`.
- Test cases for commands the spells should allow but currently block (or the reverse).
- Translations of the summon line.

## Pull requests

One topic per PR, a clear description of the behaviour change, and the
`tests/run.sh` output. Every CI check must pass before a pull request can be
merged. The `PR rules` check enforces these:

- **Issue first.** Open an issue and wait until a maintainer labels it
  `accepted`, then write `Closes #N` in the pull request.
- **Tests.** Every change to `bin/`, `hooks/`, the `.sh` and `.json` files in
  `wol/`, `install.sh`, `uninstall.sh` or a `bench/tasks/*/check.sh` needs a
  test change under `tests/`. A bug fix needs a test that fails without the
  fix. Changes to heroes and skills (`tools/gen_*.py` and the generated
  files) and to the benchmark runner and fixture do not.
- **Small.** At most 400 changed lines, one issue per pull request.
- **No suppressions.** No new `# shellcheck disable` lines in the shell files,
  no `.shellcheckrc`. Fix the finding.
- **At most 2 open pull requests** per person.

If a rule really does not fit your change, say why in the description. A
maintainer can waive it with a label (`no-tests-needed`, `large-change` or
`suppression-ok`).

## Legal notice

By submitting a contribution you confirm that you wrote it, that you have the
right to submit it, and that it may be distributed under the project license
(see [LICENSE](LICENSE)).

## AI-assisted contributions

Using AI tools is fine; please just be open about it.

- Say in the PR description which AI tools you used, if any: none, some or
  most, plus the tool or agent and the model (for example "Claude Code,
  Opus 5.5" or "Copilot, GPT-5").
- Please write the PR description in your own words; short and plain is fine.
  It shows us what you understood about the change. Please don't paste
  generated text.
- Read, run and test every line you submit, and be ready to explain it in
  review. If you don't understand what a line does, don't submit it.
- Keep the change focused. Agents like to add unrelated "improvements",
  long comments and dead code; remove them before you open the pull request.
- Pull requests that are raw, unreviewed agent output will be closed.
- If you use an agent, point it at [AGENTS.md](AGENTS.md).
- If the disclosure is missing, a check adds a reminder to the PR. It does
  not fail the PR, but a maintainer will ask about it before merging.

## Stay in touch

Don't forget to follow [@saimskywalker](https://github.com/saimskywalker) on
GitHub to see new releases and other open-source projects as they come out.
