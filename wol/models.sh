#!/usr/bin/env bash
# lumenparty models — choose the Claude model each hero runs on.
#
#   lumenparty models                       every hero: shipped model, override, effective model
#   lumenparty models profile <name>        balanced (default) | quality | economy | inherit
#   lumenparty models set <hero> <model>    opus | sonnet | haiku | fable | inherit | a full id (claude-...)
#   lumenparty models set <hero> default    drop that hero's override
#   lumenparty models apply                 write the effective models into the installed heroes
#
# Saved in .claude/wol/config.sh as WOL_MODEL_PROFILE and WOL_MODELS, so a
# re-install or an update keeps your choice (install.sh runs `apply`).
set -uo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
DEFAULTS="$WOL/models.default"
AGENTS="$PROJECT/.claude/agents"
CONF="$STATE/config.sh"
PROFILES="balanced quality economy inherit"

die() { echo "lumenparty models: $*" >&2; exit 1; }
heroes() { grep -v '^#' "$DEFAULTS" | cut -d= -f1; }
shipped() { grep "^$1=" "$DEFAULTS" | cut -d= -f2; }
valid_model() { [[ "$1" =~ ^(opus|sonnet|haiku|fable|inherit|claude-[a-z0-9.-]+)(\[1m\])?$ ]]; }

# The profile turns a hero's shipped model into the one it runs on.
#   balanced  as shipped: Opus judges, Sonnet builds, Haiku gathers
#   quality   every Sonnet hero on Opus, every Haiku hero on Sonnet
#   economy   every Opus hero on Sonnet; the rest as shipped
#   inherit   every hero uses the model of your main session
by_profile() {
  case "$1:$2" in
    quality:haiku) echo sonnet ;;
    quality:*) echo opus ;;
    economy:opus) echo sonnet ;;
    inherit:*) echo inherit ;;
    *) echo "$2" ;;
  esac
}
override() { local w; for w in ${WOL_MODELS:-}; do [[ "${w%%=*}" == "$1" ]] && { echo "${w#*=}"; return; }; done; }
effective() {
  local o; o="$(override "$1")"
  if [[ -n "$o" ]]; then echo "$o"; else by_profile "${WOL_MODEL_PROFILE:-balanced}" "$(shipped "$1")"; fi
}
installed_mode() { [[ "$WOL" -ef "$STATE" ]]; }

save() {   # save KEY VALUE into the project's config.sh
  [[ -f "$CONF" ]] || die "no $CONF yet; run \`lumenparty init\` first"
  if grep -q "^$1=" "$CONF"; then KEY="$1" VAL="$2" perl -pi -e 's/^\Q$ENV{KEY}\E=.*/$ENV{KEY}="$ENV{VAL}"/' "$CONF"
  else printf '%s="%s"\n' "$1" "$2" >>"$CONF"; fi
}

apply() {
  if ! installed_mode; then
    cat <<EOF
Saved. Plugin heroes are read from the plugin folder, so a per-hero model
needs the install.sh setup (./install.sh <repo>), which writes the heroes
into .claude/agents/ where this command can set them.
With the plugin you can still run every subagent on one model: add to
.claude/settings.local.json  "env": {"CLAUDE_CODE_SUBAGENT_MODEL": "sonnet",
"CLAUDE_CODE_SUBAGENT_MODEL_FORCE": "1"}  (Claude Code 2.1.257 or later).
EOF
    return 0
  fi
  local h f m n=0
  for h in $(heroes); do
    f="$AGENTS/$h.md"; [[ -f "$f" ]] || continue
    m="$(effective "$h")"
    # only the first model: line, inside the front matter
    MODEL="$m" perl -0pi -e 's/\A(---\n(?:(?!---\n).*\n)*?)model: [^\n]*\n/$1model: $ENV{MODEL}\n/' "$f"
    n=$((n + 1))
  done
  echo "applied: $n heroes (profile ${WOL_MODEL_PROFILE:-balanced}${WOL_MODELS:+, overrides: $WOL_MODELS})"
}

list() {
  printf '%-18s %-8s %-10s %-10s %s\n' HERO SHIPPED OVERRIDE RUNS-ON INSTALLED
  local h f now
  for h in $(heroes); do
    f="$AGENTS/$h.md"
    if installed_mode && [[ -f "$f" ]]; then now="$(sed -n 's/^model: //p' "$f" | head -1)"; else now="(plugin)"; fi
    printf '%-18s %-8s %-10s %-10s %s\n' "$h" "$(shipped "$h")" "$(override "$h")" "$(effective "$h")" "$now"
  done
  echo "profile: ${WOL_MODEL_PROFILE:-balanced}   (change: lumenparty models profile <$(echo "$PROFILES" | tr ' ' '|')>)"
}

[[ -f "$DEFAULTS" ]] || die "missing $DEFAULTS"
case "${1:-list}" in
  list) list ;;
  profile)
    p="${2:-}"; [[ " $PROFILES " == *" $p "* ]] || die "profile must be one of: $PROFILES"
    save WOL_MODEL_PROFILE "$p"; WOL_MODEL_PROFILE="$p"; apply ;;
  set)
    h="${2:-}"; m="${3:-}"
    [[ -n "$(shipped "$h")" ]] || die "unknown hero: ${h:-<none>} (see: lumenparty models)"
    new=""; for w in ${WOL_MODELS:-}; do [[ "${w%%=*}" == "$h" ]] || new="$new $w"; done
    if [[ "$m" != default ]]; then valid_model "$m" || die "model must be opus, sonnet, haiku, fable, inherit, a full claude-... id, or default"; new="$new $h=$m"; fi
    new="${new# }"; save WOL_MODELS "$new"; WOL_MODELS="$new"; apply ;;
  apply) apply ;;
  *) sed -n 2,11p "$0" ;;
esac
