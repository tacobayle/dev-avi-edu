#!/bin/bash
# -------------------------------------------------------------------------
# script: docker.sh (v4.0)
# description: Automated update utility for lab docker images.
# usage: Intended for execution via crontab @reboot.
# -------------------------------------------------------------------------

set -euo pipefail

# --- CONFIGURATION ---
REPO="tacobayle/avi-edu"
LOG_FILE="/root/docker-update-script.log"
WEB_PORT_MAPPING="172.20.10.131:8080:8080"
AUTOMATION_VOLUME_NAME="automation"
AUTOMATION_VOLUME_PATH="/home/aviadmin/automation"
MAX_RETRIES=30 # 30 attempts * 60 seconds = 30 minute timeout

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "--- Initializing Environment Update Sequence (v4.0) ---"

# --- 1. SERVICE AVAILABILITY CHECK ---
log "Checking network and docker daemon availability..."
count=0
READY=false

while [ $count -lt $MAX_RETRIES ]; do
    # Verify external connectivity to Docker Hub and local daemon health
    if curl -sSL --connect-timeout 10 "https://hub.docker.com/v2/repositories/${REPO}/tags/" > /dev/null && docker info > /dev/null 2>&1; then
        log "Network and Docker services are online."
        READY=true
        break
    else
        count=$((count + 1))
        log "Waiting for services (Attempt $count/$MAX_RETRIES). Retrying in 60s..."
        sleep 60
    fi
done

if [ "$READY" = false ]; then
    log "CRITICAL: Services did not stabilize within timeout period. Aborting update to preserve state."
    exit 1
fi

# --- 2. DYNAMIC VERSION DISCOVERY ---
log "Querying Docker Hub for latest production tag..."
API_RESPONSE=$(curl -sSLf "https://hub.docker.com/v2/repositories/${REPO}/tags/?page_size=100" || echo "API_ERROR")

if [ "$API_RESPONSE" == "API_ERROR" ]; then
    log "ERROR: Failed to communicate with Docker Hub API. Exiting."
    exit 1
fi

LATEST_VERSION=$(echo "$API_RESPONSE" | jq -r '.results[].name' | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -n 1)

if [ -z "${LATEST_VERSION}" ]; then
    log "ERROR: Unable to parse version tag from API response."
    exit 1
fi
log "Target version identified: ${LATEST_VERSION}"

# --- 3. INFRASTRUCTURE SANITIZATION ---
log "Preparing local filesystem and volumes..."
rm -f "${AUTOMATION_VOLUME_PATH}/terraform/terraform.tfstate"

if [ -z "$(docker volume ls -q -f name=^${AUTOMATION_VOLUME_NAME}$)" ]; then
    log "Provisioning volume: ${AUTOMATION_VOLUME_NAME}"
    docker volume create --name "${AUTOMATION_VOLUME_NAME}" --opt type=none --opt device="${AUTOMATION_VOLUME_PATH}" --opt o=bind
else
    log "Status: Automation volume verified."
fi

# --- 4. ENVIRONMENT REFRESH ---
log "Clearing existing container stack..."
REMOVED_IDS=$(docker ps -a -q)
if [ -n "$REMOVED_IDS" ]; then
    log "Removing container IDs: ${REMOVED_IDS}"
    docker rm -f $REMOVED_IDS > /dev/null
    log "Status: Containers removed."
else
    log "Status: No active containers found."
fi

log "Synchronizing image: ${REPO}:${LATEST_VERSION}"
docker pull "${REPO}:${LATEST_VERSION}"

log "Starting lab containers..."
# Web/Interface Container
WEB_ID=$(docker run -d -p "${WEB_PORT_MAPPING}" "${REPO}:${LATEST_VERSION}")
# Automation/Logic Container
AUTO_ID=$(docker run -d --name "${AUTOMATION_VOLUME_NAME}" --mount source="${AUTOMATION_VOLUME_NAME}",target=/opt/automation "${REPO}:${LATEST_VERSION}")

# Capture short IDs for logging
log "Deployment successful. IDs: ${WEB_ID:0:12} (Web), ${AUTO_ID:0:12} (Auto)"

# --- 5. POST-DEPLOYMENT VERIFICATION ---
sleep 5
WEB_STATUS=$(docker inspect -f '{{.State.Status}}' "$WEB_ID" 2>/dev/null || echo "not_found")
AUTO_STATUS=$(docker inspect -f '{{.State.Status}}' "$AUTO_ID" 2>/dev/null || echo "not_found")
log "Verification: Web is [${WEB_STATUS}], Automation is [${AUTO_STATUS}]."

# --- 6. DISK MAINTENANCE ---
log "Executing image prune to reclaim disk space..."
PRUNE_REPORT=$(docker image prune -af)
echo "$PRUNE_REPORT" >> "$LOG_FILE"
log "Maintenance complete."

log "--- Update Sequence Finalized: ${LATEST_VERSION} is active ---"

