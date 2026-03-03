#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# start-author.sh  —  Runs inside the author container
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

WORKDIR="/aem/author"
JAR_FILE=$(find "$WORKDIR" -maxdepth 1 -name "aem-sdk-quickstart-*.jar" | head -1)

if [[ -z "$JAR_FILE" ]]; then
  echo "[ERROR] No Quickstart JAR found in $WORKDIR"
  echo "        Run ./aem-setup.sh first to extract the SDK."
  exit 1
fi

JAR_NAME=$(basename "$JAR_FILE")
echo "[author] Starting AEM Author using: $JAR_NAME"
echo "[author] Run modes : author,${AUTHOR_EXTRA_RUNMODES}"
echo "[author] JVM opts  : ${AUTHOR_JVM_OPTS}"
echo "[author] Port      : ${AUTHOR_PORT}"

cd "$WORKDIR"

exec java \
  ${AUTHOR_JVM_OPTS} \
  -jar "$JAR_NAME" \
  -r "author,${AUTHOR_EXTRA_RUNMODES}" \
  -p "${AUTHOR_PORT}" \
  -adminPassword "${AEM_ADMIN_PASSWORD}" \
  -nofork \
  -nointeractive
