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

# The AEM SDK Quickstart does not support -adminPassword as a CLI flag.
# The correct approach is to write the password into quickstart.properties
# before the first boot — AEM reads it once during initial repository setup.
PROPS_DIR="$WORKDIR/crx-quickstart/conf"
PROPS_FILE="$PROPS_DIR/quickstart.properties"
mkdir -p "$PROPS_DIR"
if ! grep -qs "quickstart.admin.password" "$PROPS_FILE" 2>/dev/null; then
  echo "[author] Writing admin password to quickstart.properties"
  echo "quickstart.admin.password=${AEM_ADMIN_PASSWORD}" >> "$PROPS_FILE"
fi

exec java \
  ${AUTHOR_JVM_OPTS} \
  -jar "$JAR_NAME" \
  -r "author,${AUTHOR_EXTRA_RUNMODES}" \
  -p "${AUTHOR_PORT}" \
  -nofork \
  -nointeractive
