# syntax=docker/dockerfile:1

# NeoAgent server: the Go API server, the bundled web client, SQLite and the
# QEMU runtime for each user's cloud computer. Everything that changes at
# runtime lives in the /data volume; the image itself is never modified.
#
# The web client is built before `docker build` (CI runs the Flutter web build
# into public/).

ARG GO_IMAGE=golang:1.27-trixie
ARG BASE_IMAGE=debian:trixie-slim

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS build
ARG TARGETOS
ARG TARGETARCH
ENV CGO_ENABLED=0 GOWORK=off
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY cmd ./cmd
COPY internal ./internal
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    version="$(cat internal/buildinfo/VERSION)" \
 && ldflags="-s -w -X github.com/NeoLabs-Systems/neoagent/internal/buildinfo.Version=${version}" \
 && GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags "$ldflags" -o /out/neoagent ./cmd/neoagent \
 && GOOS=linux GOARCH=$TARGETARCH go build -trimpath -ldflags "$ldflags" -o /out/neoagent-guest-linux-$TARGETARCH ./cmd/neoagent-guest

# ARM64 guests boot UEFI firmware. Debian packages every firmware variant
# (about 400 MB); the cloud computer needs only these two files.
FROM ${BASE_IMAGE} AS firmware
RUN mkdir /firmware \
 && if [ "$(dpkg --print-architecture)" = arm64 ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends qemu-efi-aarch64 \
      && cp /usr/share/AAVMF/AAVMF_CODE.no-secboot.fd /firmware/AAVMF_CODE.fd \
      && cp /usr/share/AAVMF/AAVMF_VARS.fd /firmware/AAVMF_VARS.fd; \
    fi

FROM ${BASE_IMAGE}
# QEMU boots cloud computers and xorriso writes their cloud-init seed. The Docker
# CLI (which needs the system CA store to pull base images) is used only with
# TERMINAL_ENV=docker (compose.docker.yaml). Tesseract backs the ocr_extract tool.
RUN if [ "$(dpkg --print-architecture)" = arm64 ]; then qemu=qemu-system-arm; else qemu=qemu-system-x86; fi \
 && apt-get update \
 && apt-get install -y --no-install-recommends "$qemu" qemu-utils xorriso docker-cli docker-buildx ca-certificates tini tesseract-ocr tesseract-ocr-eng \
 && rm -rf /var/lib/apt/lists/*
COPY --from=firmware /firmware/ /usr/share/AAVMF/

# uid/gid 1000 is the "node" user of the earlier Node image, so an existing
# /data volume keeps working unchanged.
RUN groupadd --gid 1000 neoagent \
 && useradd --uid 1000 --gid 1000 --home-dir /data --no-create-home --shell /usr/sbin/nologin neoagent \
 && mkdir /data \
 && chown neoagent:neoagent /data

WORKDIR /app
COPY --from=build /out/neoagent /usr/local/bin/neoagent
COPY --from=build /out/neoagent-guest-linux-* /usr/local/bin/
COPY LICENSE ./
COPY landing ./landing
COPY public ./public

# NEOAGENT_CONTAINER_IMAGE turns off self-update: a new image replaces this one.
ENV NEOAGENT_HOME=/data \
    NEOAGENT_APP_DIR=/app \
    NEOAGENT_CONTAINER_IMAGE=1

USER neoagent
VOLUME ["/data"]
EXPOSE 3333
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD ["neoagent", "healthcheck"]

ENTRYPOINT ["tini", "--"]
CMD ["neoagent", "serve"]
