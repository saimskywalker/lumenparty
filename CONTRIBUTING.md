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
`tests/run.sh` output.

## AI-assisted contributions

Using AI tools is fine; please just be open about it.

- Say in the PR description which AI tools you used, if any: none, some or
  most, plus the tool or agent and the model (for example "Claude Code,
  Opus 5.5" or "Copilot, GPT-5").
- Write the PR description and any issues yourself, in your own words.
  Short, plain descriptions are welcome; please don't paste generated text.
- Read, run and test every line you submit, and be ready to explain it in
  review.
- PRs without the disclosure may be closed.
