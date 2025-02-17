#!/bin/bash

# Define the repository URL and the Docker container name
REPO_URL="https://github.com/Ronak-Malkan/JavaScript-Games.git"
CONTAINER_NAME="typeittoloseit"
IMAGE_NAME="typeittoloseit"
GAME_DIR="TypeItToLoseIt"

# Stop any currently running container of the app
echo "Stopping any existing Docker containers for the app..."
docker stop $CONTAINER_NAME || true
docker rm $CONTAINER_NAME || true

# Pull the latest code from the GitHub repository
echo "Cloning the latest code from GitHub..."
WORKDIR="/tmp/$CONTAINER_NAME"
rm -rf $WORKDIR
git clone $REPO_URL $WORKDIR
cd $WORKDIR/$GAME_DIR

# Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME .

# Run the Docker container
echo "Running Docker container..."
docker run -d --restart unless-stopped -p 8082:80 --name $CONTAINER_NAME $IMAGE_NAME

# Clean up the temporary files
echo "Cleaning up..."
rm -rf $WORKDIR

echo "Deployment of $CONTAINER_NAME completed successfully."