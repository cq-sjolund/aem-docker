#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# configure-replication.sh
# Runs inside the author container on every startup.
# Waits for both author and publish to accept HTTP, then configures the
# default publish replication agent so content can be replicated OOTB.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

AUTHOR_URL="http://localhost:${AUTHOR_PORT:-4502}"
PUBLISH_HOST="${PUBLISH_HOSTNAME:-aem-publish}"
PUBLISH_URL="http://${PUBLISH_HOST}:${PUBLISH_PORT:-4503}"
ADMIN_USER="${AEM_ADMIN_USER:-admin}"
ADMIN_PASS="${AEM_ADMIN_PASSWORD:-admin}"

wait_for_aem() {
  local url="$1" label="$2"
  echo "[replication] Waiting for ${label} at ${url} ..."
  until curl -sf --max-time 5 \
    -u "${ADMIN_USER}:${ADMIN_PASS}" \
    "${url}/libs/granite/core/content/login.html" -o /dev/null 2>/dev/null
  do
    sleep 15
  done
  echo "[replication] ${label} is ready"
}

wait_for_aem "${AUTHOR_URL}"  "Author"
wait_for_aem "${PUBLISH_URL}" "Publish"

echo "[replication] Configuring default publish replication agent..."

curl -sf -u "${ADMIN_USER}:${ADMIN_PASS}" \
  -X POST \
  "${AUTHOR_URL}/etc/replication/agents.author/publish/jcr:content" \
  -F "enabled=true" \
  -F "transportUri=${PUBLISH_URL}/bin/receive?sling:authRequestLogin=1" \
  -F "transportUser=${ADMIN_USER}" \
  -F "transportPassword=${ADMIN_PASS}" \
  -F "logLevel=error" \
  -F "retryDelay=60000" \
  -F "userId@Delete=true" \
  && echo "[replication] Replication agent configured: ${PUBLISH_URL}" \
  || echo "[replication] WARNING: Failed to configure replication agent — configure it manually at ${AUTHOR_URL}/etc/replication/agents.author/publish"
