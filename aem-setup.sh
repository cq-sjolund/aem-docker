#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# aem-setup.sh
# Prepares the AEM local SDK environment before docker compose up.
#
# What it does:
#   1. Locates the AEM SDK zip (dynamic filename support)
#   2. Extracts the Quickstart JAR for author + publish
#   3. Extracts the Dispatcher Tools zip
#   4. Creates author/, publish/, dispatcher/ working directories
#   5. Writes a resolved .env so docker-compose.yml picks up correct filenames
#
# Usage:
#   ./aem-setup.sh              — auto-detect SDK zip in current directory
#   ./aem-setup.sh my-sdk.zip   — specify SDK zip explicitly
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Load .env.example defaults, then override with .env if present ───────────
if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a; source .env; set +a
elif [[ -f .env.example ]]; then
  set -a; source .env.example; set +a
fi

# ── Defaults ──────────────────────────────────────────────────────────────────
JAVA_VERSION="${JAVA_VERSION:-17}"
AUTHOR_PORT="${AUTHOR_PORT:-4502}"
PUBLISH_PORT="${PUBLISH_PORT:-4503}"
DISPATCHER_PORT="${DISPATCHER_PORT:-80}"
AEM_ADMIN_USER="${AEM_ADMIN_USER:-admin}"
AEM_ADMIN_PASSWORD="${AEM_ADMIN_PASSWORD:-admin}"
AUTHOR_JVM_OPTS="${AUTHOR_JVM_OPTS:--Xmx2048m -Xms512m}"
PUBLISH_JVM_OPTS="${PUBLISH_JVM_OPTS:--Xmx2048m -Xms512m}"
AUTHOR_EXTRA_RUNMODES="${AUTHOR_EXTRA_RUNMODES:-nosamplecontent}"
PUBLISH_EXTRA_RUNMODES="${PUBLISH_EXTRA_RUNMODES:-nosamplecontent}"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   AEM Local SDK — Setup Script           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 1. Locate SDK zip
# ─────────────────────────────────────────────────────────────────────────────
if [[ -n "${1:-}" ]]; then
  SDK_ZIP="$1"
elif [[ -n "${AEM_SDK_ZIP:-}" && -f "${AEM_SDK_ZIP}" ]]; then
  SDK_ZIP="$AEM_SDK_ZIP"
else
  # Auto-detect: find any aem-sdk-*.zip in the current directory
  SDK_ZIP=$(find . -maxdepth 1 -name "aem-sdk-*.zip" | sort | tail -1)
fi

[[ -z "$SDK_ZIP" ]] && error "No AEM SDK zip found. Place aem-sdk-*.zip in this directory or set AEM_SDK_ZIP in .env"
[[ ! -f "$SDK_ZIP" ]] && error "SDK zip not found: $SDK_ZIP"

SDK_ZIP=$(basename "$SDK_ZIP")
info "Using SDK: ${BOLD}$SDK_ZIP${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Create working directories
# ─────────────────────────────────────────────────────────────────────────────
info "Creating instance directories..."
mkdir -p author/crx-quickstart
mkdir -p publish/crx-quickstart
mkdir -p dispatcher/src
mkdir -p sdk-extracted
success "Directories ready: author/ publish/ dispatcher/"

# ─────────────────────────────────────────────────────────────────────────────
# 3. Extract SDK zip into sdk-extracted/
# ─────────────────────────────────────────────────────────────────────────────
info "Extracting SDK zip..."
unzip -q -o "$SDK_ZIP" -d sdk-extracted/
success "SDK extracted to sdk-extracted/"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Locate Quickstart JAR
# ─────────────────────────────────────────────────────────────────────────────
QUICKSTART_JAR=$(find sdk-extracted/ -maxdepth 3 -name "aem-sdk-quickstart-*.jar" | head -1)
[[ -z "$QUICKSTART_JAR" ]] && \
  QUICKSTART_JAR=$(find sdk-extracted/ -maxdepth 3 -name "*.jar" | grep -i quickstart | head -1)
[[ -z "$QUICKSTART_JAR" ]] && \
  error "Could not find Quickstart JAR inside $SDK_ZIP. Expected: aem-sdk-quickstart-*.jar"

QUICKSTART_JAR_NAME=$(basename "$QUICKSTART_JAR")
info "Found Quickstart JAR: ${BOLD}$QUICKSTART_JAR_NAME${NC}"

# Copy JAR into author and publish directories (each needs its own copy)
if [[ ! -f "author/$QUICKSTART_JAR_NAME" ]]; then
  cp "$QUICKSTART_JAR" "author/$QUICKSTART_JAR_NAME"
  success "Copied JAR → author/"
else
  warn "author/$QUICKSTART_JAR_NAME already exists, skipping copy"
fi

if [[ ! -f "publish/$QUICKSTART_JAR_NAME" ]]; then
  cp "$QUICKSTART_JAR" "publish/$QUICKSTART_JAR_NAME"
  success "Copied JAR → publish/"
else
  warn "publish/$QUICKSTART_JAR_NAME already exists, skipping copy"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. Locate and extract Dispatcher Tools
# The SDK ships a self-extracting unix shell script (.sh) for macOS/Linux,
# and a .zip for Windows. We handle both.
# ─────────────────────────────────────────────────────────────────────────────

# Try .sh self-extracting script first (macOS/Linux SDK)
DISP_SH=$(find sdk-extracted/ -maxdepth 3 -name "aem-sdk-dispatcher-tools-*-unix.sh" | head -1)
# Fallback: .zip (Windows SDK or older versions)
DISP_ZIP=$(find sdk-extracted/ -maxdepth 3 -name "aem-sdk-dispatcher-tools-*.zip" | head -1)

if [[ -n "$DISP_SH" ]]; then
  DISP_NAME=$(basename "$DISP_SH")
  info "Found Dispatcher Tools (unix .sh): ${BOLD}$DISP_NAME${NC}"
  chmod +x "$DISP_SH"
  # Self-extracting script unpacks into the current directory — run it inside dispatcher/
  (cd dispatcher/ && bash "../$DISP_SH")
  success "Dispatcher Tools extracted → dispatcher/"
elif [[ -n "$DISP_ZIP" ]]; then
  DISP_NAME=$(basename "$DISP_ZIP")
  info "Found Dispatcher Tools (.zip): ${BOLD}$DISP_NAME${NC}"
  unzip -q -o "$DISP_ZIP" -d dispatcher/
  success "Dispatcher Tools extracted → dispatcher/"
else
  warn "Dispatcher Tools not found inside SDK."
  warn "Expected: aem-sdk-dispatcher-tools-*-unix.sh (or .zip) inside the SDK zip."
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. Write resolved .env
# ─────────────────────────────────────────────────────────────────────────────
info "Writing resolved .env..."
cat > .env << EOF
# Auto-generated by aem-setup.sh — edit as needed
AEM_SDK_ZIP=${SDK_ZIP}
QUICKSTART_JAR=${QUICKSTART_JAR_NAME}
JAVA_VERSION=${JAVA_VERSION}
AEM_ADMIN_USER=${AEM_ADMIN_USER}
AEM_ADMIN_PASSWORD=${AEM_ADMIN_PASSWORD}
AUTHOR_PORT=${AUTHOR_PORT}
PUBLISH_PORT=${PUBLISH_PORT}
DISPATCHER_PORT=${DISPATCHER_PORT}
AUTHOR_JVM_OPTS=${AUTHOR_JVM_OPTS}
PUBLISH_JVM_OPTS=${PUBLISH_JVM_OPTS}
AUTHOR_EXTRA_RUNMODES=${AUTHOR_EXTRA_RUNMODES}
PUBLISH_EXTRA_RUNMODES=${PUBLISH_EXTRA_RUNMODES}
EOF
success ".env written"

# ─────────────────────────────────────────────────────────────────────────────
# 7. Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Setup complete!${NC}"
echo ""
echo -e "  SDK zip       : ${BOLD}$SDK_ZIP${NC}"
echo -e "  Quickstart JAR: ${BOLD}$QUICKSTART_JAR_NAME${NC}"
echo -e "  Java version  : ${BOLD}$JAVA_VERSION${NC}"
echo -e "  Author port   : ${BOLD}$AUTHOR_PORT${NC}"
echo -e "  Publish port  : ${BOLD}$PUBLISH_PORT${NC}"
echo -e "  Dispatcher    : ${BOLD}$DISPATCHER_PORT${NC}"
echo ""
echo -e "Next step:"
echo -e "  ${BOLD}docker compose up --build${NC}"
echo ""
