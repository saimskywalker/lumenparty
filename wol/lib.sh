# shellcheck shell=bash
# lumenparty — shared paths for every spell. Sourced, never run.
#   WOL      the code: <plugin root>/wol (plugin) or <project>/.claude/wol (install.sh)
#   PROJECT  the project root
#   STATE    the project's own config and runtime state: <project>/.claude/wol
# Defaults come from $WOL/config.sh; the project's config.sh overrides them.
# shellcheck disable=SC2034
WOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$WOL" in
  */.claude/wol) _wol_project="${WOL%/.claude/wol}" ;;
  *) _wol_project="$(git rev-parse --show-toplevel 2>/dev/null || pwd)" ;;
esac
PROJECT="${CLAUDE_PROJECT_DIR:-$_wol_project}"
STATE="$PROJECT/.claude/wol"
# shellcheck source=/dev/null
source "$WOL/config.sh"
if [[ -f "$STATE/config.sh" && ! "$STATE/config.sh" -ef "$WOL/config.sh" ]]; then
  # shellcheck source=/dev/null
  source "$STATE/config.sh"
fi

# Create the state folder on first write, with its runtime files ignored.
wol_state() {
  mkdir -p "$STATE/active" "$STATE/verdicts"
  [[ -f "$STATE/.gitignore" ]] || printf 'heavy.lock/\nslow.log\nallow-local\nactive/\nverdicts/\n*.pid\n' >"$STATE/.gitignore"
}
