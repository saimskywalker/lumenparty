## What this changes

<!-- One or two sentences. What is different after this merges? -->

## Why

<!-- The problem it solves. If it fixes a bug, what was the symptom? -->

## Checklist

- [ ] `shellcheck -S warning` is clean on the files CI checks
- [ ] `tests/run.sh` passes
- [ ] If this changes a spell: a line in `tests/cases.txt` fails without the
      change and passes with it
- [ ] If this changes a hero or skill: `python3 tools/gen_agents.py` and
      `python3 tools/gen_skills.py` were run and the generated files are
      committed

### AI use

<!-- Using AI is welcome. Please tick one, naming the tool and model if you used AI; a reminder appears if it is missing. See CONTRIBUTING.md. -->

- [ ] None
- [ ] Some (tool or agent, and model: ...)
- [ ] Most (tool or agent, and model: ...)
- [ ] I have read and tested every line.

## tests/run.sh output

<!-- Paste the output. -->
