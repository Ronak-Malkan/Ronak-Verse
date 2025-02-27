# This script is used to get a free SSL certificate from Let's Encrypt using Certbot.
# It uses the DNS challenge to verify domain ownership.
# The script will prompt you to add a TXT record to your DNS settings.
# Once the TXT record is added, press Enter to continue.
# The script will then generate the SSL certificate and save it to the specified path.

sudo apt update
sudo apt install snapd -y
sudo snap install core; sudo snap refresh core


sudo snap install --classic certbot

sudo certbot -d "ronakverse.net,*.ronakverse.net" --manual --preferred-challenges dns certonly

# After the above command the Certbot will store the certificate in the following path:
#  /etc/letsencrypt/live/ronakverse.net/

# Now auto renew using

# sudo apt install python3-certbot-dns-digitalocean

# Go to DigitalOcean API Tokens
# Click "Generate New Token"
# Enable Read & Write permissions for DNS
# Copy the token.

# echo "dns_digitalocean_token=YOUR_DIGITALOCEAN_API_TOKEN" | sudo tee /etc/letsencrypt/digitalocean.ini 
#sudo chmod 600 /etc/letsencrypt/digitalocean.ini

# sudo crontab -e

 # Add the following line to the crontab file to auto renew the certificate
# 0 2 * * * certbot renew --dns-digitalocean --dns-digitalocean-credentials /etc/letsencrypt/digitalocean.ini && systemctl reload nginx
