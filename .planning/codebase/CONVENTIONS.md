# Coding Conventions

**Analysis Date:** 2026-02-26

## Project Context

This repository (`claudeclaw`) is a deployment wrapper for ClaudeClaw. It contains only deployment configuration files:
- `Dockerfile` - Container build configuration
- `init.sh` - Railway/container initialization script
- `.dockerignore`, `.gitattributes` - Git/Docker metadata

The actual ClaudeClaw application source code is fetched from the upstream repository (https://github.com/moazbuilds/claudeclaw.git) during the Docker build process. Therefore, **no source code analysis is available**.

## Deployment Code Observations

### Shell Script Conventions (`init.sh`)

**Naming Patterns:**
- Environment variables: UPPER_SNAKE_CASE (e.g., `STATE_DIR`, `JOBS_DIR`, `CRED_DIR`, `WEB_PORT`)
- Local variables: lowercase_snake_case (e.g., `HB_ENABLED`, `TG_IDS_JSON`, `TZ_NAME`)
- File paths: Use standard Unix conventions with descriptive names

**Code Style:**
```bash
# Strict mode at top of script
set -e

# Clear variable initialization
STATE_DIR="/app/.claude/claudeclaw"
JOBS_DIR="$STATE_DIR/jobs"

# Directory creation with mkdir -p
mkdir -p "$STATE_DIR" "$JOBS_DIR" "$LOGS_DIR" "$CRED_DIR"

# Conditional blocks with environment variable checks
if [ -n "$CLAUDE_CREDENTIALS" ]; then
  # Action
fi

# Default values using parameter expansion
WEB_PORT="${PORT:-4632}"
```

**Comments:**
- Section headers use dashed lines: `# ---[text]---`
- Inline comments explain configuration logic
- Comments explain Railway-specific behavior and state management

**Error Handling:**
- `set -e` ensures script exits on first error
- Conditional checks before critical operations (`if [ ! -f "$STATE_DIR/settings.json" ]`)
- Try-catch patterns using `|| true` for non-critical file operations

**Configuration as Code:**
- Settings written as structured JSON to `settings.json`
- Environment variables drive configuration (no hardcoded secrets)
- Configuration only written if missing OR `FORCE_CONFIG=1` is set

### Dockerfile Conventions

**Layering:**
- Multi-stage approach with clear separation of concerns
- System dependencies installed with `apt-get` before app setup
- Application code copied separately for layer caching

**Build Variables:**
- Use `ARG` for build-time variables (none explicitly shown)
- Use `ENV` for runtime environment: `DISABLE_AUTOUPDATER=1`

**Best Practices Observed:**
- `apt-get clean && rm -rf /var/lib/apt/lists/*` reduces layer size
- `--no-install-recommends` minimizes dependencies
- `--production` flag on `bun install` for production builds
- Working directory set early: `WORKDIR /app`

## Runtime Environment

**Key Variables Expected:**
- `CLAUDE_CREDENTIALS` - OAuth credentials JSON
- `PORT` - Web server port (defaults to 4632)
- `TELEGRAM_USER_IDS` - Comma-separated Telegram user IDs
- `TELEGRAM_BOT_TOKEN` - Telegram bot authentication token
- `TIMEZONE` - Timezone name (defaults to UTC)
- `CLAUDECLAW_MODEL` - Model selection (defaults to opus)
- `CLAUDECLAW_SECURITY` - Security level (defaults to moderate)
- `HEARTBEAT_ENABLED` - Enable heartbeat feature (defaults to true)
- `HEARTBEAT_INTERVAL` - Heartbeat interval in minutes (defaults to 30)
- `HEARTBEAT_PROMPT` - Custom heartbeat prompt (optional)
- `FORCE_CONFIG` - Override existing settings.json when set to 1

**State Directories:**
- Application state: `/app/.claude/claudeclaw/`
- Jobs: `/app/.claude/claudeclaw/jobs/`
- Logs: `/app/.claude/claudeclaw/logs/`
- Credentials: `$HOME/.claude/.credentials.json`

## Application Conventions (from upstream)

The upstream ClaudeClaw application is written in:
- **Language:** TypeScript
- **Runtime:** Bun (see `bun install` and `bun run src/index.ts`)
- **Entry point:** `src/index.ts` with `start --web --web-port` command

No conventions can be analyzed from the local codebase as source code is not included.

---

*Convention analysis: 2026-02-26*
