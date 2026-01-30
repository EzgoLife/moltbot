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

# === YOUR CUSTOM CONFIG FIX (Prevents crashes) ===
# Copy custom config template (public safe)
COPY openclaw.json /app/openclaw.json
# Create config dir + fix perms
RUN mkdir -p /home/node/.openclaw && \
    chown -R node:node /home/node/.openclaw
# Custom entrypoint: inject env vars + fix locks
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Security: non-root user
USER node

# Use custom entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["openclaw", "gateway", "start"]
