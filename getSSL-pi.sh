#!/bin/bash
#
# SSL Certificate Acquisition for Raspberry Pi
# Uses Cloudflare DNS-01 challenge to obtain wildcard certificates
#
# This script:
# - Installs certbot with Cloudflare DNS plugin
# - Obtains a wildcard SSL certificate (*.ronakverse.net)
# - Works behind NAT (no need for port 80 during renewal)
# - Sets up automatic certificate renewal
#
# Prerequisites:
# - Cloudflare API credentials configured in ~/.cloudflare.ini
#

set -e

echo "========================================="
echo "SSL Certificate Setup for Raspberry Pi"
echo "Using Cloudflare DNS-01 Challenge"
echo "========================================="
echo ""

# Configuration
DOMAIN="ronakverse.net"
CLOUDFLARE_INI="/etc/letsencrypt/cloudflare.ini"
CONFIG_FILE="${HOME}/.ddns-config"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    echo "Please create $CONFIG_FILE from .ddns-config.example"
    exit 1
fi

# Load configuration to get API token
source "$CONFIG_FILE"

if [ -z "$CF_API_TOKEN" ]; then
    echo "ERROR: CF_API_TOKEN not set in $CONFIG_FILE"
    exit 1
fi

echo "Step 1: Updating package list..."
apt update

echo ""
echo "Step 2: Installing certbot and Cloudflare DNS plugin..."
apt install -y python3-certbot-nginx python3-certbot-dns-cloudflare

echo ""
echo "Step 3: Creating Cloudflare credentials file..."
mkdir -p /etc/letsencrypt

# Create Cloudflare credentials file
cat > "$CLOUDFLARE_INI" << EOF
# Cloudflare API token for DNS-01 challenge
dns_cloudflare_api_token = $CF_API_TOKEN
EOF

# Set secure permissions
chmod 600 "$CLOUDFLARE_INI"
echo "Created $CLOUDFLARE_INI with secure permissions (600)"

echo ""
echo "Step 4: Obtaining SSL certificate..."
echo "Requesting wildcard certificate for *.$DOMAIN and $DOMAIN"
echo ""

# Obtain certificate using Cloudflare DNS-01 challenge
certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials "$CLOUDFLARE_INI" \
    --dns-cloudflare-propagation-seconds 30 \
    -d "$DOMAIN" \
    -d "*.$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --email "admin@$DOMAIN" \
    --preferred-challenges dns-01

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "SUCCESS! SSL Certificate Obtained"
    echo "========================================="
    echo ""
    echo "Certificate location: /etc/letsencrypt/live/$DOMAIN/"
    echo ""
    echo "Files:"
    echo "  - fullchain.pem  (certificate + chain)"
    echo "  - privkey.pem    (private key)"
    echo "  - cert.pem       (certificate only)"
    echo "  - chain.pem      (chain only)"
    echo ""
    echo "This wildcard certificate covers:"
    echo "  - $DOMAIN"
    echo "  - *.$DOMAIN (all subdomains)"
    echo ""
    echo "Subdomains covered:"
    echo "  - portfolio.$DOMAIN"
    echo "  - puzzle.$DOMAIN"
    echo "  - twocars.$DOMAIN"
    echo "  - typeit.$DOMAIN"
    echo "  - windborne.$DOMAIN"
    echo "  - metrics.$DOMAIN"
    echo ""
else
    echo ""
    echo "ERROR: Failed to obtain SSL certificate"
    echo "Please check:"
    echo "  1. Cloudflare API token is correct and has DNS edit permissions"
    echo "  2. Domain $DOMAIN is active in Cloudflare"
    echo "  3. Internet connection is working"
    exit 1
fi

echo "Step 5: Setting up automatic renewal..."
echo ""

# Test the renewal process (dry run)
echo "Testing renewal configuration (dry run)..."
certbot renew --dry-run --dns-cloudflare --dns-cloudflare-credentials "$CLOUDFLARE_INI"

if [ $? -eq 0 ]; then
    echo ""
    echo "Renewal test passed!"
    echo ""
    echo "Certbot will automatically renew certificates before they expire."
    echo "Renewal checks run twice daily via systemd timer."
    echo ""
    echo "To manually renew: sudo certbot renew"
    echo "To check renewal timer: systemctl status certbot.timer"
    echo ""
else
    echo ""
    echo "WARNING: Renewal test failed"
    echo "Certificates may not renew automatically"
    echo "Please investigate before certificates expire (90 days)"
fi

echo "Step 6: Configuring Nginx to use certificates..."
echo ""
echo "Make sure your nginx.conf uses these certificate paths:"
echo "  ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;"
echo "  ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;"
echo ""

echo "========================================="
echo "SSL Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Restart Nginx: sudo systemctl restart nginx"
echo "  2. Test your domains via HTTPS"
echo "  3. Check certificate expiry: sudo certbot certificates"
echo ""
echo "Certificate will auto-renew before expiry (90 days)"
echo ""
