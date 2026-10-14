# syntax=docker/dockerfile:1

# NeoAgent server: Express API, the bundled web client, SQLite and the QEMU
# runtime for each user's cloud computer. Everything that changes at runtime
# lives in the /data volume; the image itself is never modified.

ARG NODE_IMAGE=node:22.23.3-trixie-slim

FROM ${NODE_IMAGE} AS deps
# node-pty ships no Linux prebuilds, so it compiles here.
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 make g++ \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json package-lock.json ./
# As in the desktop runtime, the server gets no Chromium of its own: browsing runs
# inside each cloud computer. Slide (PDF/PNG) and video export need one and stay off.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
RUN npm ci --omit=dev --no-audit --no-fund \
 && npm cache clean --force

# ARM64 guests boot UEFI firmware. Debian packages every firmware variant
# (about 400 MB); the cloud computer needs only these two files.
FROM ${NODE_IMAGE} AS firmware
RUN mkdir /firmware \
 && if [ "$(dpkg --print-architecture)" = arm64 ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends qemu-efi-aarch64 \
      && cp /usr/share/AAVMF/AAVMF_CODE.no-secboot.fd /firmware/AAVMF_CODE.fd \
      && cp /usr/share/AAVMF/AAVMF_VARS.fd /firmware/AAVMF_VARS.fd; \
    fi

FROM ${NODE_IMAGE}
# QEMU boots cloud computers and xorriso writes their cloud-init seed. The Docker
# CLI (which needs the system CA store to pull base images) is used only with
# TERMINAL_ENV=docker (compose.docker.yaml).
RUN if [ "$(dpkg --print-architecture)" = arm64 ]; then qemu=qemu-system-arm; else qemu=qemu-system-x86; fi \
 && apt-get update \
 && apt-get install -y --no-install-recommends "$qemu" qemu-utils xorriso docker-cli docker-buildx ca-certificates tini \
 && rm -rf /var/lib/apt/lists/*
COPY --from=firmware /firmware/ /usr/share/AAVMF/

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json package-lock.json LICENSE ./
COPY bin ./bin
COPY lib ./lib
COPY runtime ./runtime
COPY server ./server
COPY landing ./landing
RUN ln -s /app/bin/neoagent.js /usr/local/bin/neoagent \
 && mkdir /data \
 && chown node:node /data

# NEOAGENT_CONTAINER_IMAGE turns off self-update: a new image replaces this one.
ENV NODE_ENV=production \
    NEOAGENT_HOME=/data \
    NEOAGENT_CONTAINER_IMAGE=1

USER node
VOLUME ["/data"]
EXPOSE 3333
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:' + (process.env.PORT || 3333) + '/api/health').then((r) => process.exit(r.ok ? 0 : 1), () => process.exit(1))"]

ENTRYPOINT ["tini", "--"]
CMD ["node", "server/index.js"]
