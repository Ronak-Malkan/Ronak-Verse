#!/bin/bash
# Basic VM setup
sudo apt update && sudo apt upgrade -y
sudo apt install -y ufw curl

# Firewall setup
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
sudo ufw status
sudo apt install fail2ban

# Update package lists
sudo apt-get update
echo "Package lists updated."

# Install necessary packages
sudo apt-get install -y ca-certificates curl
echo "Certificates and Curl installed."

# Create a directory for the Docker repository GPG key
sudo install -m 0755 -d /etc/apt/keyrings
echo "Keyring directory created."

# Download and save the Docker repository GPG key
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "Docker GPG key downloaded."

# Set permissions for the GPG key
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "Permissions set for the Docker GPG key."

# Add Docker repository to the APT sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list
echo "Docker repository added to APT sources."

# Update package lists with new sources
sudo apt-get update
echo "Package lists updated with Docker repository."

# Install Docker Engine and related components
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
echo "Docker components installed."

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker
echo "Docker service started and enabled at boot."

# Confirmation of completion
echo "Docker installation completed successfully. Basic VM configuration done."

