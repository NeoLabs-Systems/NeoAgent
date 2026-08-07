# syntax=docker/dockerfile:1

# NeoAgent server image.
#
# The container runs the same entry point as a native install
# (`node server/index.js`), so runtime/paths.js still creates the data
# directories, generates SESSION_SECRET and the other identity values, and
# applies migrations on first start. Nothing about that bootstrap is repeated
# here; the image only supplies the runtime and the app source.

FROM node:22-bookworm-slim AS deps

# better-sqlite3, bcrypt, and node-pty compile native addons whenever no
# prebuilt binary matches this platform.
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential python3 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/neoagent

# Chromium belongs to the isolated guest image built at runtime by
# server/services/runtime/guest_image.js, never to this one, so the Playwright
# browser download is skipped.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

# Source of the Docker CLI that DockerVMManager shells out to. It is only
# reachable when the host socket is mounted by docker-compose.isolation.yml.
FROM docker:28-cli AS docker-cli

FROM node:22-bookworm-slim AS runtime

# NEOAGENT_DEPLOYMENT_MODE=managed turns off the in-app self-update, which pulls
# a git checkout the image does not have; container installs update by rebuilding
# the image. NEOAGENT_CONTAINER makes the CLI point lifecycle commands at Compose.
ENV NODE_ENV=production \
    NEOAGENT_CONTAINER=1 \
    NEOAGENT_DEPLOYMENT_MODE=managed \
    NEOAGENT_HOME=/home/node/.neoagent \
    PORT=3333

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker

WORKDIR /opt/neoagent

COPY --from=deps /opt/neoagent/node_modules ./node_modules
COPY package.json package-lock.json ./
COPY bin ./bin
COPY lib ./lib
COPY runtime ./runtime
COPY server ./server
COPY extensions ./extensions
COPY landing ./landing
COPY docker ./docker
COPY flutter_app/assets/branding/app_icon_512.png ./flutter_app/assets/branding/
COPY .env.example LICENSE README.md ./

# `docker compose exec neoagent neoagent <command>` reaches the same CLI a
# native install exposes, and the runtime home is pre-created so the named
# volume mounted over it inherits the unprivileged owner.
RUN chmod +x bin/neoagent.js docker/entrypoint.sh \
  && ln -s /opt/neoagent/bin/neoagent.js /usr/local/bin/neoagent \
  && install -d -o node -g node -m 700 /home/node/.neoagent

USER node
EXPOSE 3333

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=5 \
  CMD ["node", "/opt/neoagent/docker/healthcheck.js"]

ENTRYPOINT ["/opt/neoagent/docker/entrypoint.sh"]
