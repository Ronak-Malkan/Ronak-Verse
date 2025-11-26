#!/bin/bash
#
# Cloudflare DDNS Updater for Raspberry Pi
# Updates DNS A records when public IP changes
#
# Usage: Run via cron every 5 minutes
#   */5 * * * * /path/to/ddns-cloudflare.sh
#

set -e

# Load configuration
CONFIG_FILE="${HOME}/.ddns-config"
LAST_IP_FILE="/tmp/last_ip.txt"
LOG_FILE="/var/log/ddns.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOG_FILE" > /dev/null
}

# Function to log errors
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | sudo tee -a "$LOG_FILE" > /dev/null
}

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    log_error "Please create $CONFIG_FILE from .ddns-config.example"
    exit 1
fi

# Load configuration
source "$CONFIG_FILE"

# Validate required variables
if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ZONE_ID" ] || [ -z "$CF_RECORD_ID_ROOT" ] || [ -z "$CF_RECORD_ID_WILDCARD" ] || [ -z "$DOMAIN" ]; then
    log_error "Missing required configuration variables in $CONFIG_FILE"
    log_error "Required: CF_API_TOKEN, CF_ZONE_ID, CF_RECORD_ID_ROOT, CF_RECORD_ID_WILDCARD, DOMAIN"
    exit 1
fi

# Get current public IP
log "Checking current public IP..."
CURRENT_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || curl -4 -s --max-time 10 icanhazip.com 2>/dev/null || curl -4 -s --max-time 10 ipecho.net/plain 2>/dev/null)

# Check if we got a valid IP
if [ -z "$CURRENT_IP" ]; then
    log_error "Failed to retrieve current public IP (network issue or all IP services down)"
    exit 1
fi

# Validate IP format
if ! echo "$CURRENT_IP" | grep -Eq '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    log_error "Invalid IP address format: $CURRENT_IP"
    exit 1
fi

log "Current public IP: $CURRENT_IP"

# Read last known IP
LAST_IP=""
if [ -f "$LAST_IP_FILE" ]; then
    LAST_IP=$(cat "$LAST_IP_FILE")
    log "Last known IP: $LAST_IP"
fi

# Compare IPs
if [ "$CURRENT_IP" == "$LAST_IP" ]; then
    log "IP unchanged, no update needed"
    exit 0
fi

# IP has changed, update DNS
log "IP changed from $LAST_IP to $CURRENT_IP, updating DNS..."

# Function to update a DNS record
update_dns_record() {
    local RECORD_ID=$1
    local RECORD_NAME=$2

    log "Updating DNS record: $RECORD_NAME"

    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":300,\"proxied\":false}" \
        2>/dev/null)

    # Check if update was successful
    if echo "$RESPONSE" | grep -q '"success":true'; then
        log "Successfully updated $RECORD_NAME to $CURRENT_IP"
        return 0
    else
        log_error "Failed to update $RECORD_NAME"
        log_error "Cloudflare API response: $RESPONSE"
        return 1
    fi
}

# Update root domain (ronakverse.net)
if ! update_dns_record "$CF_RECORD_ID_ROOT" "$DOMAIN"; then
    log_error "Failed to update root domain"
    exit 1
fi

# Update wildcard domain (*.ronakverse.net)
if ! update_dns_record "$CF_RECORD_ID_WILDCARD" "*.$DOMAIN"; then
    log_error "Failed to update wildcard domain"
    exit 1
fi

# Save new IP to file
echo "$CURRENT_IP" > "$LAST_IP_FILE"
log "DNS update completed successfully"

# Optional: Add a summary to the log
log "================================================"
log "DDNS Update Summary:"
log "  Previous IP: ${LAST_IP:-None}"
log "  New IP: $CURRENT_IP"
log "  Root domain ($DOMAIN): Updated"
log "  Wildcard domain (*.$DOMAIN): Updated"
log "================================================"

exit 0
