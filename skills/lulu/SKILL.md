---
name: lulu
description: "Load BEFORE running builds, tests, analyzers or code generators on this machine. Owns the local-run limits: the Slow queue, no full suites, CI-only commands, quoting and timeouts."
---

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
