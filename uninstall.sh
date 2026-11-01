#!/usr/bin/env bash
# Dismiss the party from a project.           ./uninstall.sh [--keep-config] <repo>
# Removes the heroes, skills and spells this repo installed, its hook
# entries, and its .git/info/exclude lines. With --keep-config, .claude/wol/
# config.sh and thresholds.md stay.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
keep=0; [[ "${1:-}" == "--keep-config" ]] && { keep=1; shift; }
dst="$(cd "${1:?usage: uninstall.sh [--keep-config] <repo>}" && pwd)"; C="$dst/.claude"
for f in "$SRC"/agents/*.md; do rm -f "$C/agents/$(basename "$f")"; done
for d in "$SRC"/skills/*/; do rm -rf "$C/skills/$(basename "$d")"; done
if (( keep )); then find "$C/wol" -mindepth 1 -not -name config.sh -not -name thresholds.md -exec rm -rf {} + 2>/dev/null || true
else rm -rf "$C/wol"; fi
for S in "$C/settings.local.json" "$C/settings.json"; do
  [[ -f "$S" ]] || continue
  jq 'if .hooks then .hooks |= (with_entries(.value |= map(select((.hooks // []) | map(.command // "") | any(test("\\.claude/wol/")) | not))) | with_entries(select(.value | length > 0))) else . end' \
    "$S" >"$S.tmp" && mv "$S.tmp" "$S"
done
ex="$(git -C "$dst" rev-parse --git-common-dir)/info/exclude"; [[ "$ex" = /* ]] || ex="$dst/$ex"
if [[ -f "$ex" ]]; then
  ours="$( { echo ".claude/wol/"; for f in "$SRC"/agents/*.md; do echo ".claude/agents/$(basename "$f")"; done
             for d in "$SRC"/skills/*/; do echo ".claude/skills/$(basename "$d")/"; done; echo "# lumenparty (personal)"
             echo "# Warriors of Light (personal)"; } )"   # marker from before the rename
  grep -vxF -f <(echo "$ours") "$ex" >"$ex.tmp" || true; mv "$ex.tmp" "$ex"
fi
echo "The party has returned to the crystal."
