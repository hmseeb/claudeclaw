#!/bin/bash
set -e

# -------------------------------------------------------------------
# ClaudeClaw on Railway — init script
# -------------------------------------------------------------------
# Paths: ClaudeClaw resolves everything from process.cwd()/.claude/
# so /app/.claude/ is the daemon state directory.
# Claude Code authenticates via CLAUDE_CODE_OAUTH_TOKEN env var
# (generated locally with: claude setup-token)
# -------------------------------------------------------------------

STATE_DIR="/app/.claude/claudeclaw"
JOBS_DIR="$STATE_DIR/jobs"
LOGS_DIR="$STATE_DIR/logs"

# Clean up stale symlinks from previous deploys before creating dirs
# (mkdir -p fails if path is a broken symlink)
[ -L "$STATE_DIR" ] && rm -f "$STATE_DIR"
[ -L "$HOME/.claude" ] && rm -f "$HOME/.claude"

mkdir -p "$STATE_DIR" "$JOBS_DIR" "$LOGS_DIR" "$HOME/.claude"

# --- Railway port ---
# Railway injects PORT. ClaudeClaw web UI must bind 0.0.0.0:$PORT
WEB_PORT="${PORT:-4632}"

# --- Telegram user IDs ---
# TELEGRAM_USER_IDS can be comma-separated: "123,456,789"
# Convert to JSON array: [123,456,789]
if [ -n "$TELEGRAM_USER_IDS" ]; then
  TG_IDS_JSON="[$(echo "$TELEGRAM_USER_IDS" | sed 's/ //g')]"
else
  TG_IDS_JSON="[]"
fi

# --- Timezone ---
TZ_NAME="${TIMEZONE:-UTC}"

# --- Model ---
MODEL="${CLAUDECLAW_MODEL:-sonnet}"

# --- Security ---
SECURITY="${CLAUDECLAW_SECURITY:-moderate}"

# --- Heartbeat ---
HB_ENABLED="${HEARTBEAT_ENABLED:-true}"
HB_INTERVAL="${HEARTBEAT_INTERVAL:-30}"
HB_PROMPT="${HEARTBEAT_PROMPT:-}"

# --- Write settings.json (only if it doesn't exist OR FORCE_CONFIG=1) ---
if [ ! -f "$STATE_DIR/settings.json" ] || [ "${FORCE_CONFIG}" = "1" ]; then
  cat > "$STATE_DIR/settings.json" << SETTINGS_EOF
{
  "model": "${MODEL}",
  "api": "",
  "fallback": {
    "model": "",
    "api": ""
  },
  "timezone": "${TZ_NAME}",
  "timezoneOffsetMinutes": 0,
  "heartbeat": {
    "enabled": ${HB_ENABLED},
    "interval": ${HB_INTERVAL},
    "prompt": "${HB_PROMPT}",
    "excludeWindows": []
  },
  "telegram": {
    "token": "${TELEGRAM_BOT_TOKEN}",
    "allowedUserIds": ${TG_IDS_JSON}
  },
  "security": {
    "level": "${SECURITY}",
    "allowedTools": [],
    "disallowedTools": []
  },
  "web": {
    "enabled": true,
    "host": "0.0.0.0",
    "port": ${WEB_PORT}
  }
}
SETTINGS_EOF
  echo "[init] settings.json written"
else
  echo "[init] settings.json exists, skipping (set FORCE_CONFIG=1 to overwrite)"
fi

# --- Symlink volume state if using persistent storage ---
# If /data exists (Railway volume), use it for logs and session persistence
if [ -d "/data" ]; then
  # Ensure all dirs exist directly on the volume BEFORE symlinking.
  # Bun's mkdir cannot create dirs through symlinks (oven-sh/bun#16466).
  sudo mkdir -p /data/claudeclaw/jobs /data/claudeclaw/logs /data/claudeclaw/inbox/telegram
  sudo chown -R "$(id -u):$(id -g)" /data/claudeclaw
  # First run: copy settings/state to volume
  if [ ! -f "/data/claudeclaw/.initialized" ]; then
    cp -r "$STATE_DIR/." "/data/claudeclaw/" 2>/dev/null || true
    touch "/data/claudeclaw/.initialized"
  fi
  # Symlink so ClaudeClaw reads/writes to the volume
  rm -rf "$STATE_DIR"
  ln -sf "/data/claudeclaw" "$STATE_DIR"
  echo "[init] Persistent storage linked: /data/claudeclaw -> $STATE_DIR"

  # Persist Claude Code home dir (conversation sessions live here)
  # Without this, --resume fails after redeploy because session data is gone
  CLAUDE_HOME="$HOME/.claude"
  CLAUDE_HOME_VOL="/data/claude-home"
  # Volume is root-owned at runtime; use sudo to create and chown
  sudo mkdir -p "$CLAUDE_HOME_VOL"
  sudo chown -R "$(id -u):$(id -g)" "$CLAUDE_HOME_VOL"
  # First run: copy existing Claude home to volume
  if [ ! -f "$CLAUDE_HOME_VOL/.initialized" ]; then
    cp -r "$CLAUDE_HOME/." "$CLAUDE_HOME_VOL/" 2>/dev/null || true
    touch "$CLAUDE_HOME_VOL/.initialized"
  fi
  # Replace home .claude with symlink to volume
  rm -rf "$CLAUDE_HOME"
  ln -sf "$CLAUDE_HOME_VOL" "$CLAUDE_HOME"
  echo "[init] Persistent storage linked: $CLAUDE_HOME_VOL -> $CLAUDE_HOME"

  # Put TMPDIR on the same volume so plugin installs (rename from /tmp)
  # don't fail with EXDEV (cross-device link not permitted)
  sudo mkdir -p /data/tmp
  sudo chown "$(id -u):$(id -g)" /data/tmp
  export TMPDIR=/data/tmp
fi

# --- Authentication ---
# CLAUDE_CODE_OAUTH_TOKEN is read directly by Claude Code from the env.
# Generate it locally with: claude setup-token
# Also write the onboarding flag so Claude skips interactive prompts.
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
  # Strip newlines/whitespace that may sneak in from copy-paste
  CLAUDE_CODE_OAUTH_TOKEN="$(echo "$CLAUDE_CODE_OAUTH_TOKEN" | tr -d '[:space:]')"
  export CLAUDE_CODE_OAUTH_TOKEN
  echo '{"hasCompletedOnboarding": true}' > "$HOME/.claude.json"
  echo "[init] OAuth token detected, onboarding bypass written"
else
  echo "[init] WARNING: CLAUDE_CODE_OAUTH_TOKEN not set — auth will fail"
fi

echo "[init] Starting ClaudeClaw daemon..."
echo "[init]   Model: ${MODEL}"
echo "[init]   Security: ${SECURITY}"
echo "[init]   Heartbeat: ${HB_ENABLED} (every ${HB_INTERVAL}m)"
echo "[init]   Web UI: 0.0.0.0:${WEB_PORT}"
echo "[init]   Telegram: $([ -n "$TELEGRAM_BOT_TOKEN" ] && echo "configured" || echo "not configured")"

exec bun run src/index.ts start --web --web-port "$WEB_PORT" --replace-existing
