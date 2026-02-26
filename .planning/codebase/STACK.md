# Technology Stack

**Analysis Date:** 2026-02-26

## Languages

**Primary:**
- TypeScript - Application logic for ClaudeClaw daemon and CLI
- Bash - Deployment and initialization scripts (`init.sh`)

**Secondary:**
- JavaScript - Package ecosystem and build tools

## Runtime

**Environment:**
- Node.js 22.x - Installed in Docker environment via deb.nodesource.com
- Bun 1.x - JavaScript runtime and package manager (base image: `oven/bun:1-debian`)

**Package Manager:**
- Bun - Runtime, package manager, and bundler
- Lockfile: `bun.lock` - Committed to repository

## Frameworks

**Core:**
- ClaudeClaw - CLI framework for Claude Code automation and orchestration
  - Version: Latest from upstream (`https://github.com/moazbuilds/claudeclaw`)
  - Entry point: `src/index.ts`

**Web UI:**
- Built-in web interface served by ClaudeClaw daemon
  - Binding: `0.0.0.0:{PORT}` (configurable via `WEB_PORT` or Railway `PORT` env var)
  - Default port: 4632

**Communication:**
- Telegram Bot API - Optional integration for bot commands
  - Configuration: `TELEGRAM_BOT_TOKEN` environment variable
  - User filtering: `TELEGRAM_USER_IDS` (comma-separated)

## Key Dependencies

**Critical:**
- `@anthropic-ai/claude-code` - Claude Code CLI package (installed globally)
- Anthropic Claude API - AI model backend for code execution and analysis

**Infrastructure:**
- Bun runtime and package manager - Complete JavaScript/TypeScript execution
- Node.js 22.x - Required for Claude Code CLI compatibility
- Git - Version control and repository operations

## Configuration

**Environment Variables:**

**Authentication:**
- `CLAUDE_CREDENTIALS` - OAuth credentials JSON (usually from `~/.claude/.credentials.json`)
  - Written to: `$HOME/.claude/.credentials.json`

**Model Selection:**
- `CLAUDECLAW_MODEL` - Model to use (default: `opus`)
- Supported models referenced in code: opus, other Claude variants

**Telegram Integration:**
- `TELEGRAM_BOT_TOKEN` - Bot token for Telegram integration
- `TELEGRAM_USER_IDS` - Comma-separated allowed user IDs

**Deployment & Web:**
- `PORT` - Railway-injected port (falls back to 4632)
- `WEB_PORT` - Explicit web server port override

**Runtime Behavior:**
- `TIMEZONE` - Timezone configuration (default: `UTC`)
- `HEARTBEAT_ENABLED` - Enable periodic heartbeat tasks (default: `true`)
- `HEARTBEAT_INTERVAL` - Heartbeat interval in minutes (default: 30)
- `HEARTBEAT_PROMPT` - Custom prompt for heartbeat execution
- `CLAUDECLAW_SECURITY` - Security level: loose/moderate/strict (default: `moderate`)
- `FORCE_CONFIG` - Force regenerate `settings.json` (default: not set)
- `DISABLE_AUTOUPDATER` - Disable auto-updater in container (set to `1`)

**Build:**
- Dockerfile: Multi-stage Docker build for containerized deployment
- `bun install --production` - Production dependency installation

## Platform Requirements

**Development:**
- TypeScript 5.x (inferred from usage)
- Node.js 22.x
- Bun 1.x for development/testing
- Git for cloning upstream repository

**Production:**
- Docker container environment (Debian-based)
- Bun runtime
- Node.js 22.x
- Railway deployment platform (or compatible Docker host)
- Persistent storage volume at `/data` (optional, for state persistence)

**Deployment Target:**
- Railway.app - Primary deployment platform
  - Configured via environment variables
  - Uses Railway `PORT` injection
  - Supports persistent volumes at `/data`
- Docker-compatible container orchestration (Kubernetes, Docker Swarm, etc.)

## Storage & State

**State Directory:**
- `/app/.claude/claudeclaw/` - Main state directory
  - `jobs/` - Job queue and execution history
  - `logs/` - Application logs
- `settings.json` - Configuration file (auto-generated from env vars)

**Persistent Storage:**
- `/data/claudeclaw/` - Optional Railway volume mounting
  - Automatically symlinked from `/app/.claude/claudeclaw/`
  - Used for state persistence across deployments

## Security Configuration

**Level Setting:**
- `loose`, `moderate` (default), `strict`
- Stored in `settings.json` under `security.level`
- Affects allowed/disallowed tools and operations

**Credentials:**
- OAuth credentials via `CLAUDE_CREDENTIALS` environment variable
- Never committed to git (should use `.env` or secrets management)

---

*Stack analysis: 2026-02-26*
