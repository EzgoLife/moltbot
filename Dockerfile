FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Copy package files + install deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# Copy source + build
COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# === CRASH FIX: Custom Config + Entrypoint ===
# Copy config template (env vars injected at runtime)
COPY openclaw.json /app/openclaw.json
# Create config dirs (OpenClaw + legacy)
RUN mkdir -p /home/node/.openclaw /home/node/.clawdbot && \
    chown -R node:node /home/node/.openclaw /home/node/.clawdbot

# Custom entrypoint (fixes EBUSY + injects Zeabur env vars)
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Non-root security
USER node

# Custom entrypoint + gateway
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["node", "dist/index.js"]
