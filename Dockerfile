FROM oven/bun:1-debian

# Install Node.js 22 (required for Claude Code CLI), git, and system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates sudo \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Disable auto-updater in container environment
ENV DISABLE_AUTOUPDATER=1

# Create non-root user (Claude Code refuses --dangerously-skip-permissions as root)
# Grant passwordless sudo for runtime volume ownership fixes
RUN useradd -m -s /bin/bash claw \
    && echo "claw ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/chown" >> /etc/sudoers.d/claw

# Set working directory — ClaudeClaw uses process.cwd()/.claude/ for all state
WORKDIR /app

# Clone latest ClaudeClaw from upstream and install deps
RUN git clone --depth 1 https://github.com/moazbuilds/claudeclaw.git /tmp/claudeclaw \
    && cp -r /tmp/claudeclaw/src /tmp/claudeclaw/prompts /tmp/claudeclaw/package.json /app/ \
    && (cp /tmp/claudeclaw/bun.lock /app/ 2>/dev/null || true) \
    && (cp /tmp/claudeclaw/tsconfig.json /app/ 2>/dev/null || true) \
    && rm -rf /tmp/claudeclaw \
    && bun install --production

# Patch: send actual error text to Telegram instead of generic "Unknown error"
RUN sed -i 's/result\.stderr || "Unknown error"/result.stdout || result.stderr || "Unknown error"/' src/commands/telegram.ts

# Patch: work around Bun mkdir EEXIST bug with symlinked dirs (oven-sh/bun#16466)
# Bun's mkdir({recursive:true}) throws EEXIST on symlinks to existing directories
RUN sed -i 's/await mkdir(\([^)]*\), { recursive: true });/await mkdir(\1, { recursive: true }).catch((e) => { if (e.code !== "EEXIST") throw e; });/g' \
    src/config.ts src/commands/start.ts src/runner.ts

# Patch: add 5-minute timeout to Claude process to prevent infinite hangs
RUN sed -i 's/const \[rawStdout, stderr\] = await Promise\.all/const _killTimer = setTimeout(() => { try { proc.kill(); } catch(e) {} }, 300000); const [rawStdout, stderr] = await Promise.all/' src/runner.ts \
    && sed -i 's/await proc\.exited;/await proc.exited; clearTimeout(_killTimer);/' src/runner.ts

# Copy deployment files (init.sh, .dockerignore, etc.)
COPY init.sh .
RUN chmod +x init.sh

# Pre-create /data for Railway volume mount and give claw ownership
# Railway mounts the volume here at runtime; pre-creating ensures correct perms
RUN mkdir -p /data && chown -R claw:claw /app /home/claw /data

USER claw
ENV HOME=/home/claw

CMD ["bash", "init.sh"]
