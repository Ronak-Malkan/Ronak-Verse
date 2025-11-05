#!/bin/bash

# =============================================================================
# Ronak-Verse Observability Stack Deployment Script
# =============================================================================
# Deploys monitoring and logging: Prometheus, Grafana, Loki, Promtail
# =============================================================================

set -e  # Exit on error

echo "======================================================================"
echo " Ronak-Verse Observability Stack Deployment"
echo "======================================================================"
echo ""

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_NAME="ronak-verse-network"

# ------------------------------------------------------------------------------
# Check if .env file exists
# ------------------------------------------------------------------------------
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "ERROR: .env file not found!"
    echo "Please copy .env.example to .env and fill in the values:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# ------------------------------------------------------------------------------
# Check if ronak-verse-network exists
# ------------------------------------------------------------------------------
echo "[1/4] Checking Docker network..."
if ! docker network inspect $NETWORK_NAME >/dev/null 2>&1; then
    echo "ERROR: Docker network '$NETWORK_NAME' does not exist!"
    echo "Please run database/deploy.sh first to create the network."
    exit 1
fi
echo "✓ Network exists"
echo ""

# ------------------------------------------------------------------------------
# Stop existing containers (if any)
# ------------------------------------------------------------------------------
echo "[2/4] Stopping existing containers..."
cd "$SCRIPT_DIR"
docker-compose down 2>/dev/null || true
echo "✓ Stopped"
echo ""

# ------------------------------------------------------------------------------
# Start observability services
# ------------------------------------------------------------------------------
echo "[3/4] Starting observability services..."
docker-compose up -d
echo "✓ Services started"
echo ""

# ------------------------------------------------------------------------------
# Wait for services to be healthy
# ------------------------------------------------------------------------------
echo "[4/4] Waiting for services to be healthy..."

# Wait for Prometheus
echo -n "  - Prometheus: "
for i in {1..30}; do
    if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
        echo "✓ Ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ Timeout waiting for Prometheus"
        exit 1
    fi
    sleep 1
done

# Wait for Loki
echo -n "  - Loki: "
for i in {1..30}; do
    if curl -s http://localhost:3100/ready >/dev/null 2>&1; then
        echo "✓ Ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ Timeout waiting for Loki"
        exit 1
    fi
    sleep 1
done

# Wait for Grafana
echo -n "  - Grafana: "
for i in {1..30}; do
    if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        echo "✓ Ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ Timeout waiting for Grafana"
        exit 1
    fi
    sleep 1
done

echo ""

# ------------------------------------------------------------------------------
# Display status and connection info
# ------------------------------------------------------------------------------
echo "Deployment complete!"
echo ""
echo "======================================================================"
echo " Observability Stack Status"
echo "======================================================================"
echo ""

docker-compose ps

echo ""
echo "======================================================================"
echo " Access Information"
echo "======================================================================"
echo ""
echo "Grafana:"
echo "  URL: http://localhost:3000"
echo "  URL (external): http://$(hostname -I | awk '{print $1}'):3000"
echo "  User: admin"
echo "  Password: (from .env file)"
echo ""
echo "Prometheus:"
echo "  URL: http://localhost:9090"
echo "  URL (external): http://$(hostname -I | awk '{print $1}'):9090"
echo ""
echo "Loki:"
echo "  URL: http://localhost:3100 (internal only)"
echo ""
echo "======================================================================"
echo " Next Steps"
echo "======================================================================"
echo ""
echo "1. Access Grafana:"
echo "   http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "2. View Prometheus targets:"
echo "   http://$(hostname -I | awk '{print $1}'):9090/targets"
echo ""
echo "3. Check logs:"
echo "   docker-compose logs -f grafana"
echo "   docker-compose logs -f prometheus"
echo "   docker-compose logs -f loki"
echo ""
echo "4. Create dashboards in Grafana using:"
echo "   - Datasource: Prometheus (metrics)"
echo "   - Datasource: Loki (logs)"
echo ""
echo "======================================================================"
