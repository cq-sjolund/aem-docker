#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# start-dispatcher.sh  —  Runs inside the dispatcher container
#
# The AEM SDK unix dispatcher tools self-extract into the dispatcher/ folder.
# After extraction the layout is typically:
#   dispatcher/
#     docker_run.sh          ← launch script (sometimes in bin/)
#     src/                   ← dispatcher config files
#     lib/                   ← dispatcher shared libraries
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

WORKDIR="/aem/dispatcher"

# Locate docker_run.sh — search common locations produced by the .sh extractor
DOCKER_RUN=$(find "$WORKDIR" -maxdepth 3 -name "docker_run.sh" | head -1)

if [[ -z "$DOCKER_RUN" ]]; then
  echo "[WARN] docker_run.sh not found in $WORKDIR"
  echo "       Check that aem-setup.sh successfully ran the dispatcher .sh extractor."
  echo "       Falling back to plain Apache httpd so the container stays visible."
  exec httpd -D FOREGROUND
fi

# Locate src/ config directory — also search flexibly
SRC_DIR=$(find "$WORKDIR" -maxdepth 3 -type d -name "src" | head -1)
if [[ -z "$SRC_DIR" ]]; then
  echo "[WARN] No src/ config directory found — using empty placeholder"
  SRC_DIR="$WORKDIR/src"
  mkdir -p "$SRC_DIR"
fi

echo "[dispatcher] docker_run.sh : $DOCKER_RUN"
echo "[dispatcher] Config src    : $SRC_DIR"
echo "[dispatcher] Publish host  : ${PUBLISH_HOST:-aem-publish}"
echo "[dispatcher] Publish port  : ${PUBLISH_PORT:-4503}"

chmod +x "$DOCKER_RUN"

# Resolve publish container IP via Docker internal DNS
PUBLISH_IP=$(getent hosts "${PUBLISH_HOST:-aem-publish}" | awk '{print $1}' || echo "127.0.0.1")

exec "$DOCKER_RUN" "$SRC_DIR" "${PUBLISH_IP}:${PUBLISH_PORT:-4503}" "${DISPATCHER_PORT:-80}"
