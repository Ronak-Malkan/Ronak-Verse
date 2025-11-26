#!/bin/bash
#
# Raspberry Pi Deployment Script
# Deploys RonakVerse services to Raspberry Pi
#

echo "========================================="
echo "RonakVerse Raspberry Pi Deployment"
echo "========================================="
echo ""

# Make all scripts executable
chmod +x init.sh nginx.sh basic-config.sh
chmod +x ddns-cloudflare.sh getSSL-pi.sh setup-cron.sh
chmod +x services/Gateway/deploy.sh
chmod +x services/TwoCars/deploy.sh
chmod +x services/TypeItToLoseIt/deploy.sh
chmod +x services/Portfolio/deploy.sh
chmod +x services/WindBorne/deploy.sh

echo "Starting initial configuration..."
echo ""

./basic-config.sh

echo ""
echo "Deploying services..."
echo ""

./services/Gateway/deploy.sh
./services/TwoCars/deploy.sh
./services/TypeItToLoseIt/deploy.sh
./services/Portfolio/deploy.sh
./services/WindBorne/deploy.sh

echo ""
echo "Configuring Nginx reverse proxy..."
echo ""

./nginx.sh

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Services deployed successfully."
echo ""
echo "IMPORTANT: Manual steps remaining:"
echo "  1. Deploy infrastructure (database/observability)"
echo "  2. Configure Cloudflare DDNS credentials"
echo "  3. Obtain SSL certificates"
echo "  4. Set up automated tasks (cron)"
echo ""
echo "See README-RASPBERRY-PI.md for detailed instructions."
echo ""