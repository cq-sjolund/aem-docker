#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# start-publish.sh  —  Runs inside the publish container
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

WORKDIR="/aem/publish"
JAR_FILE=$(find "$WORKDIR" -maxdepth 1 -name "aem-sdk-quickstart-*.jar" | head -1)

if [[ -z "$JAR_FILE" ]]; then
  echo "[ERROR] No Quickstart JAR found in $WORKDIR"
  echo "        Run ./aem-setup.sh first to extract the SDK."
  exit 1
fi

JAR_NAME=$(basename "$JAR_FILE")
echo "[publish] Starting AEM Publish using: $JAR_NAME"
echo "[publish] Run modes : publish,${PUBLISH_EXTRA_RUNMODES}"
echo "[publish] JVM opts  : ${PUBLISH_JVM_OPTS}"
echo "[publish] Port      : ${PUBLISH_PORT}"

cd "$WORKDIR"

exec java \
  ${PUBLISH_JVM_OPTS} \
  -jar "$JAR_NAME" \
  -r "publish,${PUBLISH_EXTRA_RUNMODES}" \
  -p "${PUBLISH_PORT}" \
  -adminPassword "${AEM_ADMIN_PASSWORD}" \
  -nofork \
  -nointeractive
