#!/bin/bash
#
# Setup Cron Jobs for Raspberry Pi Automation
#
# This script configures automated tasks:
# 1. DDNS updater (every 5 minutes)
# 2. SSL certificate renewal check (daily at midnight)
#
# The script is idempotent - safe to run multiple times
#

set -e

echo "========================================="
echo "Setting Up Automated Tasks (Cron Jobs)"
echo "========================================="
echo ""

# Get the absolute path to the Ronak-Verse directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DDNS_SCRIPT="$SCRIPT_DIR/ddns-cloudflare.sh"

# Verify DDNS script exists
if [ ! -f "$DDNS_SCRIPT" ]; then
    echo "ERROR: DDNS script not found at $DDNS_SCRIPT"
    exit 1
fi

# Make sure DDNS script is executable
chmod +x "$DDNS_SCRIPT"

echo "Step 1: Setting up DDNS updater cron job..."
echo "This will check and update your IP every 5 minutes"
echo ""

# Create cron job entry for DDNS
DDNS_CRON_JOB="*/5 * * * * $DDNS_SCRIPT >> /tmp/ddns-cron.log 2>&1"

# Check if cron job already exists for current user
if crontab -l 2>/dev/null | grep -F "$DDNS_SCRIPT" > /dev/null; then
    echo "DDNS cron job already exists, skipping..."
else
    # Add cron job
    (crontab -l 2>/dev/null || true; echo "$DDNS_CRON_JOB") | crontab -
    echo "Added DDNS cron job: Check IP every 5 minutes"
fi

echo ""
echo "Step 2: Verifying certbot systemd timer..."
echo "Certbot uses systemd timer for automatic renewal (runs twice daily)"
echo ""

# Check if certbot timer exists and is enabled
if systemctl is-enabled certbot.timer > /dev/null 2>&1; then
    echo "Certbot renewal timer is already enabled"

    # Show timer status
    if systemctl is-active certbot.timer > /dev/null 2>&1; then
        echo "Status: Active"
        echo ""
        echo "Timer details:"
        systemctl status certbot.timer --no-pager | grep -E "Active:|Trigger:" || true
    else
        echo "WARNING: Timer exists but is not active"
        echo "Attempting to start..."
        sudo systemctl start certbot.timer
    fi
else
    echo "WARNING: Certbot systemd timer not found"
    echo "This is normal if certbot is not yet installed"
    echo "After running getSSL-pi.sh, the timer will be available"
fi

echo ""
echo "Step 3: Creating log directory..."

# Ensure log directory exists with proper permissions
if [ ! -f /var/log/ddns.log ]; then
    sudo touch /var/log/ddns.log
    sudo chmod 644 /var/log/ddns.log
    echo "Created /var/log/ddns.log"
else
    echo "Log file /var/log/ddns.log already exists"
fi

echo ""
echo "========================================="
echo "Cron Setup Complete!"
echo "========================================="
echo ""
echo "Active cron jobs for current user:"
crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" || echo "  (no cron jobs found)"
echo ""
echo "Automated tasks configured:"
echo "  1. DDNS Update: Every 5 minutes"
echo "     - Script: $DDNS_SCRIPT"
echo "     - Log: /var/log/ddns.log"
echo "     - Cron log: /tmp/ddns-cron.log"
echo ""
echo "  2. SSL Renewal: Twice daily (via certbot.timer)"
echo "     - Checks if certificates need renewal"
echo "     - Auto-renews if expiring within 30 days"
echo "     - Check status: systemctl status certbot.timer"
echo ""
echo "Manual operations:"
echo "  - View DDNS log: sudo tail -f /var/log/ddns.log"
echo "  - Test DDNS script: $DDNS_SCRIPT"
echo "  - List cron jobs: crontab -l"
echo "  - Edit cron jobs: crontab -e"
echo "  - Check SSL expiry: sudo certbot certificates"
echo "  - Manual SSL renewal: sudo certbot renew"
echo ""
echo "To test DDNS immediately, run:"
echo "  $DDNS_SCRIPT"
echo ""
