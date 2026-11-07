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

# Built-in rules, applied on top of the project's own lists so that an older
# config.sh still gets them. Matched case-insensitively.
#   releases: at the start of a command (after runners such as bundle exec)
#   secrets:  against every file-like word of a command, and Read/Edit/Write paths
WOL_RELEASE_ALWAYS='fastlane[[:space:]].*(release|deploy|appstore|app_store|playstore|play_store|supply|deliver|pilot|beta|testflight|upload_to_testflight|upload_to_play_store|upload_to_app_store|firebase_app_distribution)|(xcrun[[:space:]]+)?altool[[:space:]].*--upload-(app|package)|(xcrun[[:space:]]+)?itmstransporter|shorebird[[:space:]]+(release|patch)|eas[[:space:]]+(submit|build[[:space:]].*(production|--auto-submit)|update[[:space:]].*(production|prod([[:space:]]|$)))|expo[[:space:]]+publish|firebase[[:space:]]+(deploy|appdistribution:distribute)|gradlew?[[:space:]](.*[[:space:]:])?(publish[a-z]*|promote[a-z]*artifact|appdistributionupload[a-z]*)([[:space:]]|$)'
WOL_SECRET_ALWAYS='\.jks$|\.keystore$|\.p8$|\.p12$|\.pem$|key\.properties$|service[-_]?account[^/]*\.json$|play[-_]?store[^/]*\.json$|google[-_]?play[^/]*\.json$|(^|/)[^/]*credentials[^/]*\.json$|(^|[/=])\.env($|\.)|secrets\.(tfvars|ya?ml|json)$|AuthKey_[^/]*$|id_(rsa|ed25519|ecdsa)$|gh/hosts\.ya?ml$|\.netrc$|\.git-credentials$'
WOL_SECRET_OK='\.env\.(example|sample|template|dist)$'
