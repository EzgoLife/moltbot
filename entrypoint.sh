#!/bin/sh
set -e

# Fix config locks (EBUSY)
rm -f /home/node/.openclaw/openclaw.json.*.tmp
rm -f /home/node/.clawdbot/moltbot.json.*.tmp  # Legacy

# Inject Zeabur env vars (public safe template)
envsubst < /app/openclaw.json > /home/node/.openclaw/openclaw.json

# Fallback legacy path
cp /home/node/.openclaw/openclaw.json /home/node/.clawdbot/moltbot.json || true

# Fix ownership
chown -R node:node /home/node/.openclaw /home/node/.clawdbot || true

# Gateway start (handles OpenClaw/Moltbot CLI)
exec node dist/index.js "$@"
