#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# start-dispatcher.sh  —  Run on the HOST (not inside Docker)
#
# The AEM SDK Dispatcher Tools ship a docker_run.sh script that manages
# its own Docker container internally — it cannot be nested inside Compose.
# Run this script directly from your terminal after docker compose up.
#
# Usage:
#   ./start-dispatcher.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load .env
if [[ -f .env ]]; then
  set -a; source .env; set +a
elif [[ -f .env.example ]]; then
  set -a; source .env.example; set +a
fi

DISPATCHER_PORT="${DISPATCHER_PORT:-80}"
PUBLISH_PORT="${PUBLISH_PORT:-4503}"

# ── Locate docker_run.sh extracted by aem-setup.sh ───────────────────────────
DOCKER_RUN=$(find dispatcher/ -maxdepth 3 -name "docker_run.sh" 2>/dev/null | head -1)

[[ -z "$DOCKER_RUN" ]] && error "docker_run.sh not found in dispatcher/
       Run ./aem-setup.sh first to extract the Dispatcher Tools."

# ── Locate src/ config directory ─────────────────────────────────────────────
SRC_DIR=$(find dispatcher/ -maxdepth 3 -type d -name "src" 2>/dev/null | head -1)

if [[ -z "$SRC_DIR" ]]; then
  warn "No src/ config directory found — creating empty placeholder"
  SRC_DIR="dispatcher/src"
  mkdir -p "$SRC_DIR"
fi

# ── Resolve publish host ──────────────────────────────────────────────────────
# The dispatcher container needs to reach aem-publish.
# On macOS/Linux, host.docker.internal resolves to the host from within Docker,
# but aem-publish is already exposed on the host at localhost:4503.
PUBLISH_HOST="host.docker.internal:${PUBLISH_PORT}"

info "Starting AEM Dispatcher"
info "  docker_run.sh : $DOCKER_RUN"
info "  Config src    : $SRC_DIR"
info "  Publish target: $PUBLISH_HOST"
info "  Dispatcher port: $DISPATCHER_PORT"
echo ""

chmod +x "$DOCKER_RUN"

# docker_run.sh signature:
#   docker_run.sh <src-dir> <publish-host:port> <dispatcher-port>
exec "$DOCKER_RUN" "$SRC_DIR" "$PUBLISH_HOST" "$DISPATCHER_PORT"
