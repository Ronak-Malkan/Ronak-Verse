#!/bin/bash

# ==============================================================================
# WindBorne Coverage Analyzer Deployment Script
# ==============================================================================
# Deploys the WindBorne Coverage Analyzer on Ronak-Verse
# ==============================================================================

set -e  # Exit on error

echo "======================================================================"
echo " WindBorne Coverage Analyzer Deployment"
echo "======================================================================"
echo ""

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
REPO_URL="https://github.com/Ronak-Malkan/windborne-coverage-analyzer.git"
APP_DIR="/root/windborne-coverage-analyzer"
CONTAINER_NAME="windborne-coverage"
IMAGE_NAME="windborne-coverage"
PORT=3005  # External port (nginx will proxy to this)

# ------------------------------------------------------------------------------
# Stop and remove existing container
# ------------------------------------------------------------------------------
echo "[1/6] Stopping existing Docker containers..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true
echo "✓ Stopped"
echo ""

# ------------------------------------------------------------------------------
# Clone or update repository
# ------------------------------------------------------------------------------
echo "[2/6] Cloning/updating repository..."

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
# Fetch weather station data (if not present)
# ------------------------------------------------------------------------------
echo "[3/6] Checking weather station data..."

if [ ! -f "$APP_DIR/data/weather-stations.json" ]; then
    echo "Weather station data not found. Fetching from NOAA..."

    # Install dependencies temporarily to run fetch script
    npm install --silent
    npm run fetch-stations

    echo "✓ Weather station data fetched"
else
    echo "✓ Weather station data already exists"
fi

echo ""

# ------------------------------------------------------------------------------
# Build Docker image
# ------------------------------------------------------------------------------
echo "[4/6] Building Docker image..."
docker build -t $IMAGE_NAME .
echo "✓ Image built"
echo ""

# ------------------------------------------------------------------------------
# Run Docker container
# ------------------------------------------------------------------------------
echo "[5/6] Starting Docker container..."
docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -p $PORT:3000 \
    -e NODE_ENV=production \
    $IMAGE_NAME

echo "✓ Container started"
echo ""

# ------------------------------------------------------------------------------
# Verify container is healthy
# ------------------------------------------------------------------------------
echo "[6/6] Waiting for application to be healthy..."

MAX_WAIT=30
COUNT=0

while [ $COUNT -lt $MAX_WAIT ]; do
    if docker exec $CONTAINER_NAME wget -q -O- http://localhost:3000/api/health >/dev/null 2>&1; then
        echo "✓ Application is healthy"
        break
    fi
    sleep 1
    COUNT=$((COUNT + 1))
done

if [ $COUNT -eq $MAX_WAIT ]; then
    echo "⚠ Warning: Health check timeout, but container is running"
fi

echo ""

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------
echo "Cleaning up old Docker images..."
docker image prune -f >/dev/null 2>&1
echo "✓ Cleanup complete"
echo ""

# ------------------------------------------------------------------------------
# Display status
# ------------------------------------------------------------------------------
echo "======================================================================"
echo " Deployment Complete!"
echo "======================================================================"
echo ""
docker ps | grep $CONTAINER_NAME
echo ""
