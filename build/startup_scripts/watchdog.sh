#!/bin/bash
# -------------------------------------------------------------------------
# script: watchdog.sh (v3.0)
# description: Modular health monitor with deferred ID creation.
# -------------------------------------------------------------------------
# CRON CONFIGURATION (for /etc/crontab or sudo crontab -e):
# 0,15,30,45 * * * * /bin/bash /usr/local/bin/watchdog.sh >> /tmp/watchdog.log 2>&1
# -------------------------------------------------------------------------

# --- CONFIGURATION ---
DEBUG="true"
WEBHOOK_URL='https://chat.googleapis.com/v1/spaces/AAQA4IHsZ3w/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=HxKJ-xNo0aRoy6mOIRrPZRizlqgNZz8nCgAFv_LixEA'
DOCKER_SCRIPT="/usr/local/bin/docker.sh"
PERM_LOG="/root/docker-update-script.log"
TEMP_LOG="/tmp/watchdog.log"
ID_FILE="/tmp/watchdog_id"
REPO="tacobayle/avi-edu"

# --- FUNCTIONS ---

log_event() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$msg"
    if [[ "$2" == "perm" ]]; then
        echo "$msg [WATCHDOG]" >> "$PERM_LOG"
    fi
}

send_google_chat_message() {
    local message="$1"
    local payload="{\"text\":\"$message\"}"
    curl -s -X POST -H "Content-Type: application/json; charset=UTF-8" -d "$payload" "$WEBHOOK_URL" > /dev/null
}

# --- MODULE 1: SAFETY (COLLISION GUARD) ---

# We check this FIRST. If docker.sh is active, we exit before creating an ID.
if pgrep -f "$DOCKER_SCRIPT" > /dev/null; then
    log_event "docker.sh is currently active. Deferring ID creation/First Run."
    exit 0
fi

# --- MODULE 2: IDENTITY & FIRST RUN ---

if [[ ! -f "$ID_FILE" ]]; then
    BTIME=$(awk '/btime/ {print $2}' /proc/stat)
    BOOT_HHMM=$(date -d "@$BTIME" +%H%M)
    RAND_ID=$(head /dev/urandom | tr -dc A-F0-9 | head -c 4)
    VAPP_ID="${BOOT_HHMM}-${RAND_ID}"

    # Identify version for initial broadcast
    CURRENT_VER=$(docker ps --format '{{.Image}}' --filter "name=automation" | cut -d':' -f2 || echo "unknown")

    # Broadcast status
    send_google_chat_message "📢 [ID: $VAPP_ID] System Online. Initial Version: $CURRENT_VER"

    # Commit ID to file
    echo "$VAPP_ID" > "$ID_FILE"
    log_event "First run: Generated ID $VAPP_ID"
else
    VAPP_ID=$(cat "$ID_FILE")
fi

# --- MODULE 3: DOCKER HEALTH & VERSION CHECK ---

REMOTE_VER=$(curl -sSLf --connect-timeout 10 "https://hub.docker.com/v2/repositories/${REPO}/tags/?page_size=100" | jq -r '.results[].name' | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -n 1)

if [[ -z "$REMOTE_VER" ]]; then
    if [[ "$DEBUG" == "true" ]]; then
        log_event "Network Check: Unable to reach Docker Hub."
    fi
    exit 0
fi

LOCAL_VER=$(docker ps --format '{{.Image}}' --filter "name=automation" | cut -d':' -f2)

# --- RECOVERY LOGIC ---

if [[ "$REMOTE_VER" != "$LOCAL_VER" ]]; then
    log_event "ISSUE: Version mismatch (Local: $LOCAL_VER, Remote: $REMOTE_VER)" "perm"

    JITTER_SEED=$(echo "$VAPP_ID" | tail -c 2)
    SLEEP_TIME=$(( 16#$JITTER_SEED % 60 ))
    log_event "Recovery: Jittering for $SLEEP_TIME seconds..."
    sleep $SLEEP_TIME

    /bin/bash "$DOCKER_SCRIPT"

    NEW_VER=$(docker ps --format '{{.Image}}' --filter "name=automation" | cut -d':' -f2)

    REPORT="🛠 *Watchdog Recovery Report*
*ID*: \`$VAPP_ID\`
*Issue*: Version mismatch (Found $LOCAL_VER, Hub has $REMOTE_VER)
*Action*: Executed docker.sh
*Result*: Success. Now running version *$NEW_VER*."

    send_google_chat_message "$REPORT"
    log_event "Recovery complete. Updated to $NEW_VER." "perm"

else
    if [[ "$DEBUG" == "true" ]]; then
        log_event "Docker checks good. Version: $LOCAL_VER"
    fi
fi

exit 0