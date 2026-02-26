# Architecture

**Analysis Date:** 2026-02-26

## Pattern Overview

**Overall:** Deployment Wrapper + Runtime Configuration Pattern

This repository serves as a **Docker-based deployment harness** for ClaudeClaw, an AI agent orchestration platform. Rather than maintaining a full source tree, the architecture relies on:

1. **Build-time cloning**: ClaudeClaw source is cloned from upstream (`moazbuilds/claudeclaw`) during Docker build
2. **Configuration management**: Environment-driven settings written at container startup
3. **Multi-service coordination**: Orchestrates OAuth credentials, Telegram bot integration, web dashboard, and heartbeat functionality

**Key Characteristics:**
- Stateless container entrypoint with runtime configuration generation
- OAuth credential injection via environment variables
- Persistent state management with optional Railway volume mounting
- Service orchestration through shell script initialization
- Integration with Claude Code CLI and Bun runtime

## Layers

**Container Setup Layer:**
- Purpose: Establish runtime environment with all required dependencies
- Location: `Dockerfile`
- Contains: Base image configuration, Node.js 22 installation, Claude Code CLI setup, dependency installation
- Depends on: Bun package manager, Node.js 22, system packages (curl, git, ca-certificates)
- Used by: Deployment infrastructure

**Configuration Generation Layer:**
- Purpose: Transform environment variables into ClaudeClaw-compatible settings files
- Location: `init.sh`
- Contains: Settings.json generation, OAuth credential handling, Telegram bot setup, web UI configuration, timezone/model/security settings
- Depends on: Environment variables from deployment platform
- Used by: ClaudeClaw daemon startup

**State Management Layer:**
- Purpose: Manage persistent state directories and volume mounting
- Location: `init.sh` (lines 44-61)
- Contains: Directory structure creation, persistent storage symlinks, log/job directory initialization
- Depends on: Filesystem layout, optional Railway persistent volume at `/data`
- Used by: Runtime daemon for session persistence

**Daemon Orchestration Layer:**
- Purpose: Start ClaudeClaw daemon with web UI enabled
- Location: `init.sh` (lines 81-89)
- Contains: Daemon startup command, web port binding, process management
- Depends on: Bun runtime, source code cloned during build
- Used by: Container's main process

## Data Flow

**Deployment to Runtime:**

1. **Build Phase**: Docker build clones ClaudeClaw source, installs dependencies, copies init.sh
2. **Container Startup**: Railway launches container with environment variables
3. **Initialization**: init.sh executes, reading environment variables
4. **Configuration Generation**: Environment variables transformed into `settings.json`:
   - `CLAUDECLAW_MODEL` → `settings.json.model`
   - `CLAUDECLAW_SECURITY` → `settings.json.security.level`
   - `TELEGRAM_BOT_TOKEN` → `settings.json.telegram.token`
   - `TELEGRAM_USER_IDS` → `settings.json.telegram.allowedUserIds` (parsed as JSON array)
   - `HEARTBEAT_*` → `settings.json.heartbeat`
   - `PORT` (Railway) → `settings.json.web.port`
5. **OAuth Credential Setup**: `CLAUDE_CREDENTIALS` env var written to `~/.claude/.credentials.json`
6. **State Directory Creation**: `/app/.claude/claudeclaw/` with subdirectories for jobs and logs
7. **Volume Mounting**: If `/data` exists, state symlinked to persistent storage
8. **Daemon Launch**: `bun run src/index.ts start --web --web-port $PORT`

**State Management:**

```
Environment Variables
    ↓
init.sh Configuration Generation
    ↓
settings.json → ~/.claude/.credentials.json
    ↓
State Directories: /app/.claude/claudeclaw/{jobs,logs}
    ↓
Optional: Symlink to /data/claudeclaw (Railway volume)
    ↓
ClaudeClaw Daemon Read Config & Initialize
```

**Security Credentials Flow:**

1. OAuth credentials arrive as `CLAUDE_CREDENTIALS` environment variable (JSON string)
2. Written to `$HOME/.claude/.credentials.json` (readable by daemon process)
3. Never logged or exposed in stdout
4. Included in `settings.json` via Telegram token injection
5. Security level determines allowed/disallowed tools

## Key Abstractions

**EnvironmentConfiguration:**
- Purpose: Encapsulates environment-to-config mapping
- Examples: Model selection, timezone, security level, web port
- Pattern: Environment variables → Shell variable expansion → JSON file generation
- Implementation: `init.sh` lines 32-56

**CredentialManagement:**
- Purpose: Secure handling of OAuth and bot tokens
- Examples: `.credentials.json`, `TELEGRAM_BOT_TOKEN`
- Pattern: Environment variable injection → File system persistence → Daemon access
- Implementation: `init.sh` lines 22-26, 73-75

**PersistentStateBinding:**
- Purpose: Abstract storage location (local or remote volume)
- Examples: Job logs, session data, state files
- Pattern: Directory structure initialization → Conditional symlink to external volume
- Implementation: `init.sh` lines 44-61

**ServiceOrchestration:**
- Purpose: Coordinate startup of multiple integrated services
- Examples: Telegram bot, web dashboard, heartbeat, Claude Code CLI
- Pattern: Configuration-driven enablement/disablement
- Implementation: `init.sh` settings.json generation for each service

## Entry Points

**Docker Build Entry:**
- Location: `Dockerfile`
- Triggers: Container build invocation
- Responsibilities:
  - Install runtime environment (Bun, Node.js 22)
  - Install Claude Code CLI globally
  - Clone ClaudeClaw source from upstream
  - Install production dependencies
  - Copy deployment files (init.sh)

**Container Startup Entry:**
- Location: `init.sh` (Dockerfile CMD)
- Triggers: Container start
- Responsibilities:
  - Create state directories
  - Parse and inject OAuth credentials
  - Generate `settings.json` from environment variables
  - Set up persistent storage symlinks
  - Launch ClaudeClaw daemon with web UI

**ClaudeClaw Daemon Entry:**
- Location: `src/index.ts` (cloned at build time, not in this repo)
- Triggers: `bun run src/index.ts start --web --web-port $PORT`
- Responsibilities:
  - Load settings.json and credentials
  - Initialize Telegram bot (if token provided)
  - Start web dashboard on specified port
  - Begin heartbeat loop (if enabled)
  - Accept Claude Code CLI connections

## Error Handling

**Strategy:** Fail-safe with warnings; continue initialization where possible

**Patterns:**

**Credential Warnings:**
- Missing `CLAUDE_CREDENTIALS`: Logs warning, continues (auth will fail at runtime)
- Pattern: `if [ -n "$CLAUDE_CREDENTIALS" ]; then ... else echo WARNING ...; fi`
- Location: `init.sh` lines 22-26

**Configuration Fallback:**
- Missing environment variables use sensible defaults
- Examples: `PORT` defaults to 4632, `TIMEZONE` defaults to UTC, `HEARTBEAT_ENABLED` defaults to true
- Pattern: `${VAR_NAME:-default_value}`
- Location: `init.sh` lines 38-56

**Settings File Immutability:**
- Existing `settings.json` preserved unless `FORCE_CONFIG=1`
- Prevents overwriting user customizations
- Pattern: `if [ ! -f "$STATE_DIR/settings.json" ] || [ "${FORCE_CONFIG}" = "1" ]`
- Location: `init.sh` lines 58-63

**Storage Initialization Robustness:**
- Existing state copied to volume on first run with error suppression
- Pattern: `cp -r ... 2>/dev/null || true`
- Location: `init.sh` lines 46-49

## Cross-Cutting Concerns

**Logging:**
- Approach: Shell script echo statements to stdout (captured by container logs)
- Pattern: `echo "[init] message"` for structured log prefix
- Visibility: All startup steps logged with section headers
- Location: Throughout `init.sh`

**Configuration Management:**
- Approach: Environment variable injection → JSON file generation → Daemon reads at startup
- Pattern: Single source of truth is environment variables; settings.json is derived
- Validation: Minimal (JSON correctness assumed); runtime daemon validates semantics
- Location: `init.sh` settings.json generation block

**Security Model:**
- Authentication: OAuth credentials via environment variable (cloud platform secret)
- Authorization: Telegram allowlist and Claude Code security level
- Pattern: Multi-layer approval (OAuth → Telegram ID check → Tool allowlist)
- Implementation: `init.sh` handles credential injection; daemon enforces policies
- Location: Settings generation + upstream daemon logic

**Port Management:**
- Approach: Dynamic binding to Railway-provided PORT environment variable
- Default: 4632 if unspecified
- Pattern: `WEB_PORT="${PORT:-4632}"`
- Special handling: Bound to 0.0.0.0 (all interfaces) for Railway accessibility
- Location: `init.sh` lines 35-36, 74

**Timezone Handling:**
- Approach: Explicit timezone specification via environment variable
- Pattern: `TIMEZONE` env var → `settings.json.timezone` field
- Default: UTC
- Use case: Scheduling heartbeat tasks in user's local timezone
- Location: `init.sh` lines 53

---

*Architecture analysis: 2026-02-26*
