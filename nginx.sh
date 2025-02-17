#!/bin/bash

# Update package lists
sudo apt update

# Install Nginx if it's not already installed
sudo apt install -y nginx

# Ensure Nginx is running
sudo systemctl start nginx
sudo systemctl enable nginx

# Setup directories - assuming the Docker container places built files in /var/www/ronakverse.net/html
sudo mkdir -p /var/www/ronakverse.net/html

# Adjust permissions and ownership
sudo chmod -R 755 /var/www/ronakverse.net
sudo chown -R www-data:www-data /var/www/ronakverse.net

# NGINX configuration for the main domain and services
echo "Creating NGINX configurations..."

# Path to the main Nginx configuration file
NGINX_CONF="/root/Ronak-Verse/nginx.conf"
NGINX_AVAILABLE="/etc/nginx/sites-available/ronakverse.net"
NGINX_ENABLED="/etc/nginx/sites-enabled/ronakverse.net"

# Ensure the main Nginx configuration file exists before copying
if [ -f "$NGINX_CONF" ]; then
    sudo cp "$NGINX_CONF" "$NGINX_AVAILABLE"
    # Remove the symlink if it already exists to prevent conflicts
    sudo rm -f "$NGINX_ENABLED"
    sudo ln -s "$NGINX_AVAILABLE" "$NGINX_ENABLED"
else
    echo "Error: $NGINX_CONF not found!"
    exit 1
fi

# Test Nginx configuration
sudo nginx -t

# Restart Nginx to apply new configuration
sudo systemctl restart nginx

echo "Nginx configurations for services have been updated and applied successfully."
