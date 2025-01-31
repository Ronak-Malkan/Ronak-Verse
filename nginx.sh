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

# Main site
# Copy an existing configuration from your project setup for the main site
sudo cp /root/Ronak-Verse/services/Gateway/nginx.conf /etc/nginx/sites-available/ronakverse.net
sudo ln -s /etc/nginx/sites-available/ronakverse.net /etc/nginx/sites-enabled/

# # Service TwoCars
# sudo cp /root/Ronak-Verse/services/TwoCars/nginx.conf /etc/nginx/sites-available/twocars
# sudo ln -s /etc/nginx/sites-available/twocars /etc/nginx/sites-enabled/

# # Service TypeItToLoseIt
# # Same for this service
# sudo cp /root/Ronak-Verse/services/TypeItToLoseIt/nginx.conf /etc/nginx/sites-available/typeittoloseit
# sudo ln -s /etc/nginx/sites-available/typeittoloseit /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Restart Nginx to apply new configuration
sudo systemctl restart nginx

echo "Nginx configurations for services have been updated and applied successfully."
