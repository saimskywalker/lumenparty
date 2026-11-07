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

# Every gh call is cut off after WOL_GH_TIMEOUT seconds (default 4), so a hung
# network cannot hold a hook open: perl's alarm, since older macOS has no
# timeout(1). gh runs in its own process group and the whole group is killed,
# so a child it started (git, a credential helper) cannot keep the pipe open.
wol_gh() {
  perl -e '
    my $t = shift; my $pid = fork // exit 125;
    if (!$pid) { setpgrp(0, 0); exec @ARGV or exit 127 }
    setpgrp($pid, $pid);
    $SIG{ALRM} = sub { kill "KILL", -$pid; kill "KILL", $pid; exit 124 };
    alarm $t; waitpid $pid, 0;
    exit($? & 127 ? 128 + ($? & 127) : $? >> 8);' "${WOL_GH_TIMEOUT:-4}" gh "$@"
}

# Create the state folder on first write, with its runtime files ignored.
wol_state() {
  mkdir -p "$STATE/active" "$STATE/verdicts"
  [[ -f "$STATE/.gitignore" ]] || printf 'heavy.lock/\nslow.log\nallow-local\nactive/\nverdicts/\n*.pid\n' >"$STATE/.gitignore"
}
