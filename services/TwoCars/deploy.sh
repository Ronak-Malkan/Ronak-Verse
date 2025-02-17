#!/bin/bash

# Define the repository URL and the Docker container name
REPO_URL="https://github.com/Ronak-Malkan/JavaScriptGames.git"
BASE_DIR="/tmp/javascript-games"
CONTAINER_NAME="twocars"
IMAGE_NAME="twocars"
GAME_DIR="TwoCars"

# Stop any currently running container of the app
echo "Stopping any existing Docker containers for the app..."
docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true


# Clone the repository once if it doesn't exist
if [ ! -d "$BASE_DIR" ]; then
    echo "Cloning the latest code from GitHub..."
    git clone $REPO_URL $BASE_DIR
else
    echo "Updating the existing repository..."
    cd $BASE_DIR && git pull origin main
fi

# Navigate to the game directory
cd $BASE_DIR/$GAME_DIR

# Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME .

# Run the Docker container
echo "Running Docker container..."
docker run -d --restart unless-stopped -p 8081:80 --name $CONTAINER_NAME $IMAGE_NAME

echo "Deployment of $CONTAINER_NAME completed successfully."
