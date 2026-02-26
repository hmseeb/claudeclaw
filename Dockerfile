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
RUN useradd -m -s /bin/bash claw

# Set working directory — ClaudeClaw uses process.cwd()/.claude/ for all state
WORKDIR /app

# Clone latest ClaudeClaw from upstream and install deps
RUN git clone --depth 1 https://github.com/moazbuilds/claudeclaw.git /tmp/claudeclaw \
    && cp -r /tmp/claudeclaw/src /tmp/claudeclaw/prompts /tmp/claudeclaw/package.json /app/ \
    && (cp /tmp/claudeclaw/bun.lock /app/ 2>/dev/null || true) \
    && (cp /tmp/claudeclaw/tsconfig.json /app/ 2>/dev/null || true) \
    && rm -rf /tmp/claudeclaw \
    && bun install --production

# Copy deployment files (init.sh, .dockerignore, etc.)
COPY init.sh .
RUN chmod +x init.sh

# Give claw user ownership of /app and its home .claude dir
RUN chown -R claw:claw /app /home/claw

USER claw
ENV HOME=/home/claw

CMD ["bash", "init.sh"]
