#!/bin/bash
set -e

# -------------------------------------------------------------------
# ClaudeClaw on Railway — init script
# -------------------------------------------------------------------
# Paths: ClaudeClaw resolves everything from process.cwd()/.claude/
# so /app/.claude/ is the daemon state directory.
# Claude Code credentials live at $HOME/.claude/.credentials.json
# -------------------------------------------------------------------

STATE_DIR="/app/.claude/claudeclaw"
JOBS_DIR="$STATE_DIR/jobs"
LOGS_DIR="$STATE_DIR/logs"
CRED_DIR="$HOME/.claude"

mkdir -p "$STATE_DIR" "$JOBS_DIR" "$LOGS_DIR" "$CRED_DIR"

# --- OAuth credentials ---
# CLAUDE_CREDENTIALS env var = full JSON from ~/.claude/.credentials.json
if [ -n "$CLAUDE_CREDENTIALS" ]; then
  echo "$CLAUDE_CREDENTIALS" > "$CRED_DIR/.credentials.json"
  echo "[init] OAuth credentials written"
else
  echo "[init] WARNING: CLAUDE_CREDENTIALS not set — auth will fail"
fi

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
  # Move existing state to volume on first run
  if [ ! -d "/data/claudeclaw" ]; then
    cp -r "$STATE_DIR" "/data/claudeclaw" 2>/dev/null || true
  fi
  # Symlink so ClaudeClaw reads/writes to the volume
  rm -rf "$STATE_DIR"
  ln -sf "/data/claudeclaw" "$STATE_DIR"
  echo "[init] Persistent storage linked: /data/claudeclaw -> $STATE_DIR"
fi

echo "[init] Starting ClaudeClaw daemon..."
echo "[init]   Model: ${MODEL}"
echo "[init]   Security: ${SECURITY}"
echo "[init]   Heartbeat: ${HB_ENABLED} (every ${HB_INTERVAL}m)"
echo "[init]   Web UI: 0.0.0.0:${WEB_PORT}"
echo "[init]   Telegram: $([ -n "$TELEGRAM_BOT_TOKEN" ] && echo "configured" || echo "not configured")"

exec bun run src/index.ts start --web --web-port "$WEB_PORT" --replace-existing
