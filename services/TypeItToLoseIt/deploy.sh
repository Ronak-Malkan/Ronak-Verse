#!/bin/bash

# Define the repository URL and the Docker container name
REPO_URL="https://github.com/Ronak-Malkan/JavaScript-Games.git"
BASE_DIR="/tmp/javascript-games"
CONTAINER_NAME="typeittoloseit"
IMAGE_NAME="typeittoloseit"
GAME_DIR="TypeItToLoseIt"

# Stop any currently running container of the app
echo "Stopping any existing Docker containers for the app..."
docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true

# Reuse the already cloned repository
if [ ! -d "$BASE_DIR" ]; then
    echo "Error: The repository has not been cloned yet!"
    exit 1
else
    echo "Using the existing repository at $BASE_DIR..."
    cd $BASE_DIR && git pull origin main
fi


# Navigate to the game directory
cd $BASE_DIR/$GAME_DIR

# Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME .

# Run the Docker container
echo "Running Docker container..."
docker run -d --restart unless-stopped -p 8082:80 --name $CONTAINER_NAME $IMAGE_NAME

# Clean up the temporary files
echo "Cleaning up..."
rm -rf $BASE_DIR

echo "Deployment of $CONTAINER_NAME completed successfully."