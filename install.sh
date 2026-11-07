#!/usr/bin/env bash
# Summon the party into a project.
#
#   ./install.sh [--preset flutter|web|fullstack] [--team] <path-to-your-repo>
#
# Default (personal): files go to <repo>/.claude/ and are hidden from git
# through .git/info/exclude; hooks go to the ignored settings.local.json.
# --team: hooks go to .claude/settings.json and nothing is hidden, so you
# can commit .claude/ and the whole team gets the crew.
# Safe to run again: it replaces its own files and hook entries only, and
# never overwrites an existing .claude/wol/config.sh.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
preset=""; team=0; dst=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset) preset="${2:?}"; shift 2 ;;
    --team) team=1; shift ;;
    -h|--help) sed -n 2,12p "$0"; exit 0 ;;
    *) dst="$1"; shift ;;
  esac
done
[[ -n "$dst" ]] || { echo "usage: install.sh [--preset flutter|web|fullstack] [--team] <repo>" >&2; exit 1; }
for t in jq git perl; do command -v "$t" >/dev/null || { echo "missing: $t" >&2; exit 1; }; done
dst="$(cd "$dst" && pwd)"
git -C "$dst" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $dst" >&2; exit 1; }
C="$dst/.claude"; W="$C/wol"
mkdir -p "$C/agents" "$C/skills" "$W"

# heroes and skills
cp "$SRC"/agents/*.md "$C/agents/"
for d in "$SRC"/skills/*/; do n="$(basename "$d")"; mkdir -p "$C/skills/$n"; cp "$d/SKILL.md" "$C/skills/$n/"; done

# spells, gate, presets; config only if absent
mkdir -p "$W/spells" "$W/crystal" "$W/active" "$W/verdicts" "$W/presets" "$W/bin"
cp "$SRC"/wol/spells/*.sh "$W/spells/"; cp "$SRC"/wol/crystal/*.sh "$W/crystal/"
cp "$SRC/wol/lib.sh" "$W/"; cp "$SRC/bin/lumenparty" "$SRC/bin/wol" "$W/bin/"
cp "$SRC"/wol/presets/*.sh "$W/presets/"
[[ -f "$W/thresholds.md" ]] || cp "$SRC/wol/thresholds.md" "$W/"
if [[ ! -f "$W/config.sh" ]]; then
  cp "$SRC/wol/config.sh" "$W/config.sh"
  if [[ -n "$preset" ]]; then
    [[ -f "$SRC/wol/presets/$preset.sh" ]] || { echo "unknown preset: $preset" >&2; exit 1; }
    { echo; echo "# --- preset: $preset ---"; cat "$SRC/wol/presets/$preset.sh"; } >>"$W/config.sh"
  fi
  login="$(perl -e 'alarm shift; exec @ARGV' 4 gh api user --jq .login 2>/dev/null || true)"
  [[ -n "$login" ]] && perl -pi -e "s/^WOL_OWNER=\"\"/WOL_OWNER=\"$login\"/" "$W/config.sh"
fi
chmod +x "$W"/spells/*.sh "$W"/crystal/*.sh "$W/bin/lumenparty" "$W/bin/wol"

# hooks: drop our old entries, add the current ones, keep everything else
# shellcheck source=/dev/null
source "$W/config.sh"
S="$C/settings.local.json"; (( team )) && S="$C/settings.json"
[[ -f "$S" ]] || echo '{}' >"$S"
cp "$S" "$S.wol-backup"
hooks="$(sed "s/__SQL_TOOLS__/${WOL_SQL_TOOLS//\//\\/}/" "$SRC/wol/install-hooks.json")"
jq --argjson h "$hooks" '
  def ours: (.hooks // []) | map(.command // "") | any(test("\\.claude/wol/"));
  .hooks = (.hooks // {})
  | reduce ($h | keys[]) as $ev (.; .hooks[$ev] = (((.hooks[$ev] // []) | map(select(ours | not))) + $h[$ev]))' \
  "$S" >"$S.tmp" && mv "$S.tmp" "$S"

# personal: hide everything we added from git
if (( ! team )); then
  ex="$(git -C "$dst" rev-parse --git-common-dir)/info/exclude"; [[ "$ex" = /* ]] || ex="$dst/$ex"
  mkdir -p "$(dirname "$ex")"; touch "$ex"
  add() { grep -qxF "$1" "$ex" || echo "$1" >>"$ex"; }
  grep -qxF "# lumenparty (personal)" "$ex" || printf "\n# lumenparty (personal)\n" >>"$ex"
  add ".claude/wol/"; add ".claude/settings.local.json"
  for f in "$SRC"/agents/*.md; do add ".claude/agents/$(basename "$f")"; done
  for d in "$SRC"/skills/*/; do add ".claude/skills/$(basename "$d")/"; done
fi
# runtime state is never committed, in either mode
printf 'heavy.lock/\nslow.log\nallow-local\nactive/\nverdicts/\n*.pid\n' >"$W/.gitignore"

echo "✦ The party has answered: $(ls "$SRC"/agents | wc -l | tr -d ' ') heroes, $(ls "$SRC"/skills | wc -l | tr -d ' ') skills, 5 spells."
echo "  config: $W/config.sh (owner: ${WOL_OWNER:-<set WOL_OWNER>})"
(( team )) && echo "  team mode: commit .claude/ to share the crew." || echo "  personal mode: hidden from git."
echo "  Open a NEW Claude Code session in $dst and say: Lumenparty, assemble!"
