#!/bin/bash
#
# Raspberry Pi System Setup
# Idempotent - safe to run multiple times
#

set -e

echo "========================================="
echo "Raspberry Pi System Configuration"
echo "========================================="
echo ""

echo "Step 1: System Updates"
echo "----------------------"
sudo apt update && sudo apt upgrade -y

echo ""
echo "Step 2: Installing Basic Utilities"
echo "-----------------------------------"
# Install ufw and curl if not already installed
if ! command -v ufw &> /dev/null; then
    echo "Installing ufw..."
    sudo apt install -y ufw
else
    echo "ufw already installed, skipping..."
fi

if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    sudo apt install -y curl
else
    echo "curl already installed, skipping..."
fi

echo ""
echo "Step 3: Firewall Configuration (UFW)"
echo "-------------------------------------"

# Check if UFW is already configured
UFW_STATUS=$(sudo ufw status | head -n1)

if [[ "$UFW_STATUS" == *"inactive"* ]]; then
    echo "Configuring UFW firewall..."
    sudo ufw allow 22/tcp comment 'SSH'
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    echo "y" | sudo ufw enable
    echo "UFW firewall enabled and configured"
elif [[ "$UFW_STATUS" == *"active"* ]]; then
    echo "UFW already active, ensuring required ports are open..."
    # Ensure ports are allowed (these commands are idempotent)
    sudo ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
    sudo ufw allow 80/tcp comment 'HTTP' 2>/dev/null || true
    sudo ufw allow 443/tcp comment 'HTTPS' 2>/dev/null || true
    echo "UFW configuration verified"
else
    echo "Enabling UFW for the first time..."
    sudo ufw allow 22/tcp comment 'SSH'
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    echo "y" | sudo ufw enable
fi

sudo ufw status

echo ""
echo "Step 4: Installing fail2ban"
echo "----------------------------"
if command -v fail2ban-client &> /dev/null; then
    echo "fail2ban already installed, skipping..."
    sudo systemctl is-active --quiet fail2ban && echo "fail2ban is running" || echo "fail2ban is installed but not running"
else
    echo "Installing fail2ban..."
    sudo apt install -y fail2ban
    echo "fail2ban installed successfully"
fi

echo ""
echo "Step 5: Docker Installation"
echo "---------------------------"

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "Docker already installed: $DOCKER_VERSION"

    # Verify Docker is running
    if sudo systemctl is-active --quiet docker; then
        echo "Docker service is running"
    else
        echo "Docker is installed but not running, starting it..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
else
    echo "Docker not found, installing..."
    echo ""

    # Install necessary packages
    echo "Installing prerequisites..."
    sudo apt-get install -y ca-certificates curl

    # Create a directory for the Docker repository GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    echo "Keyring directory created."

    # Download Docker GPG key for Debian (Raspberry Pi OS)
    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        echo "Docker GPG key downloaded."
    else
        echo "Docker GPG key already exists, skipping download..."
    fi

    # Add Docker repository for Debian
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        echo "Docker repository added to APT sources."
    else
        echo "Docker repository already configured, skipping..."
    fi

    # Update package lists with new sources
    sudo apt-get update
    echo "Package lists updated with Docker repository."

    # Install Docker Engine and related components
    echo "Installing Docker components..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo "Docker components installed."

    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "Docker service started and enabled at boot."

    # Verify installation
    DOCKER_VERSION=$(docker --version)
    echo "Docker installation completed: $DOCKER_VERSION"
fi

echo ""
echo "========================================="
echo "Configuration Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  Environment: Raspberry Pi"
echo "  UFW Firewall: Active (ports 22, 80, 443 open)"
echo "  fail2ban: Installed"
echo "  Docker: Installed and running"
echo ""
echo "Next steps:"
echo "  1. Configure Cloudflare DDNS:"
echo "     cp .ddns-config.example ~/.ddns-config"
echo "     nano ~/.ddns-config"
echo "  2. Set up infrastructure:"
echo "     cd database && cp .env.example .env && nano .env && ./deploy.sh"
echo "  3. Set up observability:"
echo "     cd observability && cp .env.example .env && nano .env && ./deploy.sh"
echo "  4. Deploy services with ./init.sh"
echo "  5. Set up SSL: sudo ./getSSL-pi.sh"
echo "  6. Configure cron jobs: ./setup-cron.sh"
echo ""
