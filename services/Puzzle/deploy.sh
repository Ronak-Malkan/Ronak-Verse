#!/bin/bash

# =============================================================================
# Puzzle Application Deployment Script
# =============================================================================
# Deploys the Puzzle application (all microservices) on Ronak-Verse
# =============================================================================

set -e  # Exit on error

echo "======================================================================"
echo " Puzzle Application Deployment"
echo "======================================================================"
echo ""

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/root/puzzle-app"
REPO_URL="https://github.com/Ronak-Malkan/Puzzle.git"
NETWORK_NAME="ronak-verse-network"

# ------------------------------------------------------------------------------
# Check prerequisites
# ------------------------------------------------------------------------------
echo "[1/6] Checking prerequisites..."

# Check if network exists
if ! docker network inspect $NETWORK_NAME >/dev/null 2>&1; then
    echo "ERROR: Docker network '$NETWORK_NAME' does not exist!"
    echo "Please run database/deploy.sh first."
    exit 1
fi

# Check if infrastructure is running
if ! docker ps | grep -q ronak-verse-postgres; then
    echo "ERROR: PostgreSQL is not running!"
    echo "Please run database/deploy.sh first."
    exit 1
fi

echo "✓ Prerequisites met"
echo ""

# ------------------------------------------------------------------------------
# Clone or update repository
# ------------------------------------------------------------------------------
echo "[2/6] Cloning/updating Puzzle repository..."

if [ -d "$APP_DIR" ]; then
    echo "Repository exists, pulling latest changes..."
    cd "$APP_DIR"
    git pull origin main || git pull origin master
else
    echo "Cloning repository..."
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
fi

echo "✓ Repository updated"
echo ""

# ------------------------------------------------------------------------------
# Run database migrations
# ------------------------------------------------------------------------------
echo "[3/6] Running database migrations..."

# Check if databases exist, create if not
docker exec ronak-verse-postgres psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'puzzle_auth_db'" | grep -q 1

if [ $? -ne 0 ]; then
    echo "Creating databases..."
    docker exec -i ronak-verse-postgres psql -U postgres < "$APP_DIR/migrations/init.sql"
    echo "✓ Databases created"
else
    echo "✓ Databases already exist"
fi

echo ""

# ------------------------------------------------------------------------------
# Stop existing Puzzle containers
# ------------------------------------------------------------------------------
echo "[4/6] Stopping existing Puzzle containers..."
docker-compose -f "$APP_DIR/docker-compose.yml" down 2>/dev/null || true
echo "✓ Stopped"
echo ""

# ------------------------------------------------------------------------------
# Build and start Puzzle services
# ------------------------------------------------------------------------------
echo "[5/6] Building and starting Puzzle services..."
cd "$APP_DIR"
docker-compose -f docker-compose.yml up -d --build

echo "✓ Services started"
echo ""

# ------------------------------------------------------------------------------
# Wait for services to be healthy
# ------------------------------------------------------------------------------
echo "[6/6] Waiting for services to be healthy..."

# Function to check if a container is running
check_container() {
    local container_name=$1
    local max_wait=60
    local count=0

    echo -n "  - $container_name: "
    while [ $count -lt $max_wait ]; do
        if docker ps | grep -q "$container_name"; then
            if docker inspect "$container_name" | grep -q '"Status": "running"'; then
                echo "✓ Running"
                return 0
            fi
        fi
        sleep 1
        count=$((count + 1))
    done
    echo "✗ Timeout"
    return 1
}

# Check all Puzzle services
check_container "puzzle-web"
check_container "puzzle-api-gateway"
check_container "puzzle-auth-service"
check_container "puzzle-block-service"
check_container "puzzle-blog-service"
check_container "puzzle-notification-service"

echo ""

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------
echo "Cleaning up old Docker images..."
docker image prune -f >/dev/null 2>&1
echo "✓ Cleanup complete"
echo ""

# ------------------------------------------------------------------------------
# Display status and access info
# ------------------------------------------------------------------------------
echo "======================================================================"
echo " Puzzle Deployment Complete!"
echo "======================================================================"
echo ""

docker-compose -f "$APP_DIR/docker-compose.yml" ps

echo ""
echo "======================================================================"
echo " Access Information"
echo "======================================================================"
echo ""
echo "Frontend:"
echo "  URL (internal): http://puzzle-web:3000"
echo "  URL (via nginx): https://puzzle.ronakverse.net"
echo ""
echo "API Gateway:"
echo "  URL: http://$(hostname -I | awk '{print $1}'):8080"
echo "  Metrics: http://$(hostname -I | awk '{print $1}'):8080/metrics"
echo ""
echo "Services:"
echo "  Auth Service: http://$(hostname -I | awk '{print $1}'):8001"
echo "  Block Service: http://$(hostname -I | awk '{print $1}'):8002"
echo "  Blog Service: http://$(hostname -I | awk '{print $1}'):8003"
echo "  Notification Service: http://$(hostname -I | awk '{print $1}'):8004"
echo ""
echo "======================================================================"
echo " Next Steps"
echo "======================================================================"
echo ""
echo "1. Configure nginx for puzzle.ronakverse.net"
echo "   See: Ronak-Verse/nginx.conf"
echo ""
echo "2. Obtain SSL certificate:"
echo "   sudo certbot --nginx -d puzzle.ronakverse.net"
echo ""
echo "3. View logs:"
echo "   docker-compose -f $APP_DIR/docker-compose.yml logs -f"
echo ""
echo "4. View specific service logs:"
echo "   docker logs -f puzzle-api-gateway"
echo "   docker logs -f puzzle-blog-service"
echo ""
echo "5. Check metrics in Grafana:"
echo "   http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "======================================================================"
