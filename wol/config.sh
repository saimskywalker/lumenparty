# lumenparty — project config. Sourced by every spell (hook).
# Edit freely; install.sh never overwrites an existing config.sh.

# Who may be merged for (your GitHub login) and how.
WOL_OWNER=""                       # e.g. "octocat"; empty = the gate refuses every merge
WOL_BASE="main"
WOL_MERGE_METHOD="squash"          # squash | rebase | merge
WOL_GH_TIMEOUT=4                   # seconds before a gh call is cut off (the gate then refuses)
WOL_PROTECTED='main|master|develop|release/[^[:space:]:]*|production'

# Reviewers whose requested review means "a human merges this one".
WOL_HUMAN_ONLY_REVIEWERS=""        # e.g. "lead-dev|security-team"

# Models: which Claude model each hero runs on. Set with `lumenparty models`.
#   balanced = as shipped (Opus judges, Sonnet builds, Haiku gathers)
#   quality  = Sonnet heroes on Opus, Haiku heroes on Sonnet
#   economy  = Opus heroes on Sonnet
#   inherit  = every hero uses your main session's model
WOL_MODEL_PROFILE="balanced"
WOL_MODELS=""                      # per-hero overrides, e.g. "squall=sonnet cloud=opus"

# Reply language for the crew ("en", "id", "ja", ...). Code stays English.
WOL_LANG="en"

# Mini: file-size limits for hand-written code.
WOL_LOC_SOFT=300
WOL_LOC_HARD=500
WOL_LOC_EXT='dart|ts|tsx|js|jsx|vue|svelte|kt|swift|rs|go|py|rb'
WOL_LOC_EXEMPT='\.g\.dart$|\.freezed\.dart$|\.gr\.dart$|\.mocks\.dart$|/l10n/|/generated/|/migrations?/|\.min\.|\.d\.ts$|/node_modules/|/build/'

# Slow: commands that must run one at a time through spells/slow.sh.
WOL_HEAVY='flutter[[:space:]]+(test|analyze|build)|dart[[:space:]]+run[[:space:]]+build_runner|(\./)?gradlew|xcodebuild|pod[[:space:]]+install|npm[[:space:]]+run[[:space:]]+(build|test)|pnpm[[:space:]]+(run[[:space:]]+)?(build|test)|yarn[[:space:]]+(build|test)|next[[:space:]]+build|vite[[:space:]]+build'
WOL_MIN_FREE=15                    # % free memory to wait for before a heavy run
WOL_TIMEOUT=1800                   # seconds before a heavy run is stopped
WOL_FULL_SUITE_BLOCK=1             # 1 = `flutter test` must name test files

# Commands never run locally (low-memory machines, CI-only builds). Empty = none.
# Example: 'cargo[[:space:]]+(build|test|clippy)'. Override: touch .claude/wol/allow-local
WOL_BLOCK_LOCAL=""

# Production: tags that deploy, and commands that ship. Built-in store and
# release rules (fastlane, xcrun altool, eas, shorebird, Gradle publish...)
# always apply on top of this list; see WOL_RELEASE_ALWAYS in lib.sh.
WOL_PROD_TAG='v[0-9]+\.[0-9]+\.[0-9]+'
WOL_DEPLOY_BLOCK='firebase[[:space:]]+deploy|vercel[[:space:]].*--prod|netlify[[:space:]]+deploy[[:space:]].*--prod|fastlane[[:space:]].*(release|deploy|appstore|playstore|supply|deliver)|eas[[:space:]]+submit|eas[[:space:]]+build[[:space:]].*production|supabase[[:space:]]+db[[:space:]]+push|kubectl[[:space:]].*prod.*[[:space:]](apply|delete|set|rollout|patch|scale)|terraform[[:space:]]+apply'

# Shell: files the crew never opens or prints, matched case-insensitively.
# Built-in patterns (.env*, signing keys, store credentials...) always apply;
# see WOL_SECRET_ALWAYS in lib.sh.
WOL_SECRET_FILES='\.jks$|\.keystore$|\.p8$|\.p12$|\.pem$|key\.properties$|service[-_]?account[^/]*\.json$|\.env\.production$|\.env\.prod$|secrets\.(tfvars|ya?ml|json)$|AuthKey_[^/]*$|id_(rsa|ed25519)$'

# Silence: MCP tools that run SQL (read-only enforcement). Regex on tool name.
WOL_SQL_TOOLS='mcp__.*(postgres|supabase|mysql|sql).*'

# Crystal Gate: which paths need which reviewer's PASS before a merge.
WOL_GATE_SECURITY='auth|login|signin|session|token|password|payment|billing|checkout|purchase|subscription|wallet|iap|webhook|admin|upload|crypto|secret'
WOL_GATE_COPY='\.arb$|/l10n/|/locales?/|/i18n/|/translations?/|Info\.plist$|/res/values[^/]*/strings\.xml$|store[-_]?listing|metadata/'
WOL_GATE_DB='/migrations?/|schema\.prisma$|\.sql$'
WOL_GATE_HUMAN='^\.github/|^fastlane/|codemagic\.ya?ml$|eas\.json$|\.xcodeproj/|android/app/build\.gradle|^infra(structure)?/|^terraform/|Dockerfile$'

# Laguna (midnight run): power off the machine at the end? macOS only.
WOL_SHUTDOWN=0
WOL_STOP_DOCKER=1
