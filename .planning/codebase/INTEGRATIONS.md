# External Integrations

**Analysis Date:** 2026-02-26

## APIs & External Services

**Anthropic Claude API:**
- Upstream dependency via ClaudeClaw from `https://github.com/moazbuilds/claudeclaw`
- What it's used for: AI model inference, code analysis, task execution
- SDK/Client: `@anthropic-ai/claude-code` (npm/bun package)
- Auth: OAuth credentials via `CLAUDE_CREDENTIALS` environment variable
- Credentials location: `$HOME/.claude/.credentials.json`

**Telegram Bot API:**
- What it's used for: Optional command interface and notifications
- SDK/Client: Native HTTP API (likely via Telegram Node.js library in upstream)
- Auth: `TELEGRAM_BOT_TOKEN` environment variable
- Allowed users: `TELEGRAM_USER_IDS` (comma-separated numeric IDs)
- Status: Optional - if `TELEGRAM_BOT_TOKEN` is not set, feature is disabled

## Git Integration

**Version Control:**
- Git CLI - For repository operations
- Upstream repository: `https://github.com/moazbuilds/claudeclaw`
- Cloning strategy: `git clone --depth 1` (shallow clone for fast deployment)

## Data Storage

**State Management:**
- File-based storage (local filesystem)
  - Primary location: `/app/.claude/claudeclaw/`
  - Persistent location: `/data/claudeclaw/` (Railway volumes)
  - Format: JSON configuration files

**Configuration Files:**
- `settings.json` - Generated from environment variables at startup
- Includes: model selection, security settings, timezone, telegram config, web UI settings
- Auto-created if missing (can be forced via `FORCE_CONFIG=1`)

**Job & Log Storage:**
- `jobs/` directory - Job queue and execution records
- `logs/` directory - Application logs
- Both stored in state directory with optional persistence to Railway volume

**File Storage:**
- None detected - Uses local filesystem only for application state

**Caching:**
- Not explicitly configured - May use in-memory caching (defer to upstream ClaudeClaw)

## Authentication & Identity

**Auth Provider:**
- Anthropic OAuth - For Claude API access
  - Credentials: `CLAUDE_CREDENTIALS` JSON environment variable
  - File: `~/.claude/.credentials.json`

**Telegram Bot Authentication:**
- Telegram Bot Token (`TELEGRAM_BOT_TOKEN`)
- User ID allowlist (`TELEGRAM_USER_IDS`)
- No advanced auth - simple token + user ID filtering

## Monitoring & Observability

**Error Tracking:**
- Not detected - Defer to upstream ClaudeClaw implementation

**Logs:**
- Local file logging to `/app/.claude/claudeclaw/logs/`
- Log files: Created and managed by ClaudeClaw daemon

**Heartbeat & Health Checks:**
- Built-in heartbeat system:
  - Enabled: `HEARTBEAT_ENABLED` (default: `true`)
  - Interval: `HEARTBEAT_INTERVAL` minutes (default: 30)
  - Custom prompt: `HEARTBEAT_PROMPT` (optional)
  - Provides periodic health checks and task execution

## CI/CD & Deployment

**Hosting:**
- Railway.app - Primary deployment platform
  - Auto-injected environment variables: `PORT`
  - Persistent volumes: `/data` (optional)

**Container Registry:**
- Docker image built from Dockerfile
- Build process:
  1. Base image: `oven/bun:1-debian`
  2. Install Node.js 22.x and system dependencies
  3. Install Claude Code CLI globally
  4. Clone upstream ClaudeClaw repository
  5. Install production dependencies via `bun install --production`
  6. Copy deployment configuration
  7. Entry point: `bash init.sh` → `bun run src/index.ts start --web`

**CI Pipeline:**
- Not detected in this repository - Upstream ClaudeClaw likely has CI/CD

**Build Environment:**
- Docker - Containerized builds for Railway deployment

## Environment Configuration

**Required Environment Variables:**

**Authentication:**
- `CLAUDE_CREDENTIALS` - OAuth credentials JSON string (required for API access)

**Deployment:**
- `PORT` - Server port (injected by Railway, default: 4632)
- `WEB_PORT` - Override for web UI port

**Telegram (Optional):**
- `TELEGRAM_BOT_TOKEN` - Bot token for Telegram integration
- `TELEGRAM_USER_IDS` - Allowed user IDs (comma-separated)

**Runtime Configuration:**
- `CLAUDECLAW_MODEL` - Model selection (default: `opus`)
- `CLAUDECLAW_SECURITY` - Security level: loose/moderate/strict (default: `moderate`)
- `TIMEZONE` - Timezone name (default: `UTC`)

**Heartbeat Configuration:**
- `HEARTBEAT_ENABLED` - Enable heartbeat (default: `true`)
- `HEARTBEAT_INTERVAL` - Interval in minutes (default: 30)
- `HEARTBEAT_PROMPT` - Custom prompt for heartbeat tasks

**Advanced:**
- `DISABLE_AUTOUPDATER` - Set to `1` in Docker to prevent auto-updates
- `FORCE_CONFIG` - Set to `1` to regenerate settings.json

**Secrets Location:**
- OAuth credentials: `$HOME/.claude/.credentials.json`
- Expected format: JSON file with authentication tokens
- Environment override: `CLAUDE_CREDENTIALS` environment variable

## Webhooks & Callbacks

**Incoming Webhooks:**
- None detected in deployment configuration

**Outgoing Webhooks:**
- Telegram API - For sending messages/notifications (if Telegram bot is configured)
- Anthropic Claude API - For model requests

## Railway-Specific Integration

**Platform Features Used:**
- Environment variable injection (`PORT`)
- Persistent volumes at `/data`
- Automatic process restart on exit code
- Long-running daemon service (no timeout)

**Volume Mounting:**
- Automatic detection of `/data` directory
- Symlink setup: `/app/.claude/claudeclaw` → `/data/claudeclaw`
- Preserves state across deployments

---

*Integration audit: 2026-02-26*
