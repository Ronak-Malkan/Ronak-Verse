# RonakVerse Raspberry Pi Deployment Guide

Complete guide for deploying RonakVerse infrastructure on Raspberry Pi 5 at home.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Key Differences from Digital Ocean](#key-differences-from-digital-ocean)
- [Network Architecture](#network-architecture)
- [Initial Setup](#initial-setup)
- [Cloudflare Configuration](#cloudflare-configuration)
- [Infrastructure Deployment](#infrastructure-deployment)
- [Service Deployment](#service-deployment)
- [SSL Certificate Setup](#ssl-certificate-setup)
- [Automated Tasks Setup](#automated-tasks-setup)
- [Verification](#verification)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

---

## Overview

This branch (`raspberry-pi`) contains deployment scripts optimized for Raspberry Pi 5 running at my home behind a NAT router. The main differences from the Digital Ocean deployment (on `main` branch) are:

- **Dynamic IP management** using Cloudflare DDNS
- **Cloudflare DNS-01 SSL challenges** (works behind NAT)
- **Idempotent scripts** (safe to re-run)
- **8GB RAM** optimizations (vs 1GB Digital Ocean droplet)

---

## Prerequisites

### ✅ Already Completed (Before Starting)

- [x] Raspberry Pi 5 with Raspberry Pi OS installed
- [x] Static local IP configured
- [x] Router port forwarding configured:
  - Port 22 (SSH)
  - Port 80 (HTTP)
  - Port 443 (HTTPS)
- [x] UFW firewall active (allows 22, 80, 443)
- [x] SSH key-based authentication enabled
- [x] User account with sudo access

### ❌ Still Required

- [ ] Cloudflare account (free tier is sufficient)
- [ ] Domain registered and using Cloudflare DNS (`ronakverse.net`)
- [ ] Cloudflare API token with DNS edit permissions
- [ ] Docker and Docker Compose (installed by scripts)
- [ ] Nginx (installed by scripts)
- [ ] SSL certificates (obtained by scripts)

---

## Key Differences from Digital Ocean

### 1. Dynamic IP Problem

**Digital Ocean:**

- Static public IP that never changes
- Set DNS once, works forever

**Raspberry Pi:**

- Home ISP assigns dynamic IP
- IP can change every few days/weeks
- **Solution:** Cloudflare DDNS runs every 5 minutes to auto-update DNS

### 2. SSL Certificate Acquisition

**Digital Ocean:**

- Uses DigitalOcean DNS-01 challenge
- Requires DigitalOcean API token

**Raspberry Pi:**

- Uses Cloudflare DNS-01 challenge
- Requires Cloudflare API token
- Works behind NAT (no port 80 needed during renewal)
- Gets wildcard certificate: `*.ronakverse.net`

### 3. Network Topology

**Digital Ocean:**

- Direct internet access
- Public IP directly on server

**Raspberry Pi:**

- Behind NAT router
- Port forwarding required
- Public IP changes periodically

### 4. Resource Availability

**Digital Ocean:**

- 1GB RAM (strict limits)
- Resource-constrained

**Raspberry Pi:**

- 8GB RAM available
- Can use more generous limits (optional)

---

## Network Architecture

```
                Internet
                   ↓
         Home Public IP: 99.61.165.33
              (Dynamic - changes periodically)
                   ↓
         AT&T Router: 192.168.1.254
         ├─ Port Forwarding Rules:
         │  ├─ 22 → 192.168.1.50
         │  ├─ 80 → 192.168.1.50
         │  └─ 443 → 192.168.1.50
                   ↓
         Raspberry Pi: 192.168.1.50
         ├─ UFW Firewall (allows 22, 80, 443)
         ├─ Docker Network (ronak-verse-network)
         │  ├─ Infrastructure Layer
         │  │  ├─ PostgreSQL (5432)
         │  │  ├─ Redis (6379)
         │  │  └─ RabbitMQ (5672, 15672)
         │  ├─ Observability Layer
         │  │  ├─ Prometheus (9090)
         │  │  ├─ Grafana (3000)
         │  │  ├─ Loki (3100)
         │  │  └─ Promtail
         │  └─ Application Services
         │     ├─ Gateway (8000)
         │     ├─ Portfolio (8003)
         │     ├─ TwoCars (8081)
         │     ├─ TypeIt (8082)
         │     ├─ Puzzle (3000, 8080+)
         │     └─ WindBorne (3005)
         └─ Nginx (80, 443)
            └─ Reverse proxy to services

         DNS Resolution:
         ronakverse.net → 99.61.165.33
         *.ronakverse.net → 99.61.165.33
         (Updated automatically by DDNS)
```

---

## Initial Setup

### Step 1: Clone the Repository

On your Raspberry Pi:

```bash
cd /home/ronakmalkan
git clone -b raspberry-pi https://github.com/YOUR_USERNAME/Ronak-Verse.git
cd Ronak-Verse
```

### Step 2: Run Basic System Configuration

This script is idempotent - safe to run multiple times:

```bash
chmod +x basic-config.sh
./basic-config.sh
```

**What it does:**

- Updates system packages
- Installs UFW firewall (or verifies existing configuration)
- Installs fail2ban
- Installs Docker and Docker Compose
- Ensures all ports are correctly configured

**Time:** ~10-15 minutes (first run)

---

## Cloudflare Configuration

### Step 1: Create Cloudflare Account

1. Go to [cloudflare.com](https://cloudflare.com)
2. Sign up for free account
3. Add your domain: `ronakverse.net`
4. Update nameservers at your domain registrar

### Step 2: Get Cloudflare API Token

1. Go to Cloudflare Dashboard
2. Click on your profile (top right) → **API Tokens**
3. Click **Create Token**
4. Use template: **Edit Zone DNS**
5. Configure:
   - **Permissions:** Zone → DNS → Edit
   - **Zone Resources:** Include → Specific zone → `ronakverse.net`
6. Click **Continue to summary** → **Create Token**
7. **Copy the token** (you'll need this)

### Step 3: Get Zone ID

1. Go to Cloudflare Dashboard
2. Select your domain (`ronakverse.net`)
3. On Overview tab, scroll down right sidebar
4. Find **Zone ID** (under API section)
5. Copy this value

### Step 4: Create DNS Records (If Not Exist)

1. Go to **DNS** tab in Cloudflare
2. Add A record for root domain:
   - **Type:** A
   - **Name:** @ (or `ronakverse.net`)
   - **IPv4 address:** Your current IP (e.g., `99.61.165.33`)
   - **Proxy status:** DNS only (grey cloud)
   - **TTL:** Auto
3. Add A record for wildcard:
   - **Type:** A
   - **Name:** `*`
   - **IPv4 address:** Your current IP
   - **Proxy status:** DNS only (grey cloud)
   - **TTL:** Auto

### Step 5: Get DNS Record IDs

Use the Cloudflare API to get record IDs:

**Get root domain record ID:**

```bash
curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records?type=A&name=ronakverse.net" \
     -H "Authorization: Bearer YOUR_API_TOKEN" \
     -H "Content-Type: application/json"
```

Look for `"id": "..."` in the response and copy it.

**Get wildcard record ID:**

```bash
curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records?type=A&name=*.ronakverse.net" \
     -H "Authorization: Bearer YOUR_API_TOKEN" \
     -H "Content-Type: application/json"
```

Copy the `"id"` value from this response too.

### Step 6: Configure DDNS Credentials

```bash
cd /home/ronakmalkan/Ronak-Verse
cp .ddns-config.example ~/.ddns-config
chmod 600 ~/.ddns-config
nano ~/.ddns-config
```

Fill in your actual values:

```bash
CF_API_TOKEN="your-actual-api-token-here"
CF_ZONE_ID="your-actual-zone-id-here"
CF_RECORD_ID_ROOT="root-domain-record-id-here"
CF_RECORD_ID_WILDCARD="wildcard-record-id-here"
DOMAIN="ronakverse.net"
```

Save and exit (Ctrl+X, Y, Enter).

**Security Note:** The `~/.ddns-config` file is in your home directory and will NOT be committed to Git.

---

## Infrastructure Deployment

### Step 1: Deploy Database Layer

```bash
cd database
cp .env.example .env
nano .env
```

Generate secure passwords:

```bash
openssl rand -base64 32
```

Update `.env` with strong passwords:

```
POSTGRES_PASSWORD=your_secure_postgres_password
RABBITMQ_PASSWORD=your_secure_rabbitmq_password
```

Deploy:

```bash
./deploy.sh
```

**Verify:**

```bash
docker ps | grep ronak-verse
```

You should see:

- `ronak-verse-postgres`
- `ronak-verse-redis`
- `ronak-verse-rabbitmq`

### Step 2: Deploy Observability Stack

```bash
cd ../observability
cp .env.example .env
nano .env
```

Update `.env`:

```
GRAFANA_PASSWORD=your_secure_grafana_password
POSTGRES_PASSWORD=same_as_database_env
```

Deploy:

```bash
./deploy.sh
```

**Verify:**

```bash
docker ps | grep ronak-verse
```

You should see:

- `ronak-verse-prometheus`
- `ronak-verse-grafana`
- `ronak-verse-loki`
- `ronak-verse-promtail`
- `ronak-verse-postgres-exporter`
- `ronak-verse-redis-exporter`

---

## Service Deployment

### Deploy All Services

From the repository root:

```bash
cd /home/ronakmalkan/Ronak-Verse
./init.sh
```

**What it does:**

1. Makes all scripts executable
2. Runs `basic-config.sh` (idempotent)
3. Deploys all application services:
   - Gateway (ronakverse.net)
   - Portfolio (portfolio.ronakverse.net)
   - TwoCars (twocars.ronakverse.net)
   - TypeIt (typeit.ronakverse.net)
   - WindBorne (windborne.ronakverse.net)
4. Configures Nginx reverse proxy

**Time:** ~10-15 minutes

### Deploy Puzzle Microservices (Separate)

Puzzle has multiple microservices and requires database:

```bash
cd services/Puzzle
./deploy.sh
```

**Verify all services:**

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## SSL Certificate Setup

### Obtain Wildcard Certificate

Run as root:

```bash
cd /home/ronakmalkan/Ronak-Verse
sudo ./getSSL-pi.sh
```

**What it does:**

1. Installs certbot with Cloudflare DNS plugin
2. Uses your `~/.ddns-config` for Cloudflare API access
3. Obtains wildcard certificate: `*.ronakverse.net`
4. Covers all subdomains with one certificate
5. Sets up automatic renewal via systemd timer

**Certificate location:** `/etc/letsencrypt/live/ronakverse.net/`

**Time:** ~3-5 minutes

### Restart Nginx

After obtaining certificates:

```bash
sudo systemctl restart nginx
```

**Verify SSL:**

```bash
curl -I https://ronakverse.net
```

Should show `HTTP/2 200` or similar with no certificate errors.

---

## Automated Tasks Setup

### Configure Cron Jobs

```bash
cd /home/ronakmalkan/Ronak-Verse
./setup-cron.sh
```

**What it sets up:**

1. **DDNS Updater:** Runs every 5 minutes

   - Checks if public IP changed
   - Updates Cloudflare DNS if needed
   - Logs to `/var/log/ddns.log`

2. **SSL Renewal:** Managed by certbot.timer
   - Runs twice daily
   - Auto-renews certificates before expiry
   - Reloads Nginx automatically

**Verify cron jobs:**

```bash
crontab -l
```

**Verify certbot timer:**

```bash
systemctl status certbot.timer
```

---

## Verification

### Complete Testing Checklist

Run through this checklist to verify everything works:

#### Infrastructure

- [ ] All Docker containers running:

  ```bash
  docker ps | wc -l  # Should show 15+ containers
  ```

- [ ] PostgreSQL accessible:

  ```bash
  docker exec ronak-verse-postgres pg_isready
  ```

- [ ] Redis accessible:

  ```bash
  docker exec ronak-verse-redis redis-cli ping
  ```

- [ ] RabbitMQ accessible:
  ```bash
  docker exec ronak-verse-rabbitmq rabbitmq-diagnostics ping
  ```

#### DDNS

- [ ] DDNS script works:

  ```bash
  ./ddns-cloudflare.sh
  ```

- [ ] Check DDNS log:

  ```bash
  sudo tail -f /var/log/ddns.log
  ```

- [ ] DNS points to current IP:
  ```bash
  dig +short ronakverse.net
  curl -4 ifconfig.me
  ```
  (Both should return the same IP)

#### SSL Certificates

- [ ] Certificates exist:

  ```bash
  sudo ls -la /etc/letsencrypt/live/ronakverse.net/
  ```

- [ ] Check certificate expiry:

  ```bash
  sudo certbot certificates
  ```

- [ ] Test renewal (dry run):
  ```bash
  sudo certbot renew --dry-run
  ```

#### Services

Test all services via HTTPS:

- [ ] Main site: https://ronakverse.net
- [ ] Portfolio: https://portfolio.ronakverse.net
- [ ] TwoCars game: https://twocars.ronakverse.net
- [ ] TypeIt game: https://typeit.ronakverse.net
- [ ] Puzzle app: https://puzzle.ronakverse.net
- [ ] WindBorne: https://windborne.ronakverse.net
- [ ] Grafana: https://metrics.ronakverse.net

**All should:**

- Load without certificate warnings
- Show valid SSL lock icon
- Return HTTP/2 (check with: `curl -I https://domain`)

#### Monitoring

- [ ] Prometheus accessible: http://192.168.1.50:9090
- [ ] Grafana accessible: https://metrics.ronakverse.net
- [ ] Grafana login works (admin / your_password)
- [ ] Data sources connected (check Grafana → Configuration → Data Sources)
- [ ] Metrics being collected (check Prometheus → Status → Targets)

---

## Maintenance

### Daily Checks (Optional)

```bash
# Check all containers are running
docker ps

# Check DDNS logs for IP changes
sudo tail -20 /var/log/ddns.log

# Check system resources
htop
```

### Weekly Checks

```bash
# Check certificate expiry (should auto-renew at 30 days)
sudo certbot certificates

# Check disk space
df -h

# Check Docker disk usage
docker system df
```

### Monthly Maintenance

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Clean up old Docker images
docker system prune -a

# Check fail2ban status
sudo fail2ban-client status
```

### Manual Operations

**Manually trigger DDNS update:**

```bash
cd /home/ronakmalkan/Ronak-Verse
./ddns-cloudflare.sh
```

**Manually renew SSL certificates:**

```bash
sudo certbot renew
sudo systemctl reload nginx
```

**View all logs:**

```bash
# DDNS log
sudo tail -f /var/log/ddns.log

# Nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# Docker container logs
docker logs -f container_name
```

**Restart all services:**

```bash
cd /home/ronakmalkan/Ronak-Verse/database
docker-compose restart

cd ../observability
docker-compose restart

# Individual services
docker restart gateway portfolio twocars typeittoloseit windborne-coverage
```

---

## Troubleshooting

### Issue: DDNS not updating DNS

**Symptoms:**

- Public IP changed but DNS still points to old IP
- DDNS script shows errors in log

**Check:**

```bash
# Test DDNS script manually
./ddns-cloudflare.sh

# Check log for errors
sudo tail -50 /var/log/ddns.log

# Verify Cloudflare credentials
cat ~/.ddns-config  # Should show your API token

# Test Cloudflare API manually
curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID" \
     -H "Authorization: Bearer YOUR_API_TOKEN"
```

**Solutions:**

- Verify API token is still valid (check Cloudflare dashboard)
- Check API token has DNS edit permissions
- Ensure Zone ID and Record IDs are correct
- Check network connectivity: `ping cloudflare.com`

### Issue: SSL certificates not renewing

**Symptoms:**

- Certificate expired or about to expire
- Certbot renewal fails

**Check:**

```bash
# Check certificate expiry
sudo certbot certificates

# Test renewal (dry run)
sudo certbot renew --dry-run

# Check certbot timer status
systemctl status certbot.timer
```

**Solutions:**

- Ensure Cloudflare API token is valid
- Check `/etc/letsencrypt/cloudflare.ini` exists and has correct token
- Manually renew: `sudo certbot renew --force-renewal`
- Check Cloudflare API rate limits

### Issue: Website not accessible from internet

**Symptoms:**

- Can access locally (http://192.168.1.50) but not via domain
- Connection timeout from external network

**Check:**

```bash
# Check public IP
curl -4 ifconfig.me

# Check DNS resolution
dig +short ronakverse.net

# Check if port forwarding is working
# (from external network or use online port checker)
```

**Solutions:**

- Verify DNS points to current public IP
- Check router port forwarding rules (22, 80, 443 → 192.168.1.50)
- Verify UFW firewall allows ports: `sudo ufw status`
- Check if ISP blocks port 80/443 (some do)
- Restart router if needed

### Issue: Docker containers keep restarting

**Symptoms:**

- Containers show "Restarting" status
- Services not accessible

**Check:**

```bash
# Check container status
docker ps -a

# Check container logs
docker logs container_name

# Check resource usage
docker stats

# Check system resources
free -h
df -h
```

**Solutions:**

- Check for port conflicts: `sudo netstat -tlnp`
- Verify environment variables in `.env` files
- Check Docker logs for specific errors
- Ensure database is running before dependent services
- Restart Docker daemon: `sudo systemctl restart docker`

### Issue: Service shows "502 Bad Gateway"

**Symptoms:**

- Nginx returns 502 error
- Service container is running

**Check:**

```bash
# Check if service container is healthy
docker ps | grep service_name

# Check service logs
docker logs service_name

# Check Nginx error log
sudo tail -50 /var/log/nginx/error.log

# Test service directly (bypass Nginx)
curl http://localhost:SERVICE_PORT
```

**Solutions:**

- Verify service is listening on correct port
- Check service health endpoint
- Restart service container: `docker restart service_name`
- Check Nginx configuration: `sudo nginx -t`
- Restart Nginx: `sudo systemctl restart nginx`

### Issue: Grafana not showing data

**Symptoms:**

- Grafana accessible but no metrics/logs
- Dashboards show "No data"

**Check:**

```bash
# Check Prometheus targets
# Open: http://192.168.1.50:9090/targets

# Check Loki is receiving logs
curl http://localhost:3100/ready

# Verify exporters are running
docker ps | grep exporter

# Check data source configuration in Grafana
# Go to Configuration → Data Sources
```

**Solutions:**

- Verify Prometheus is scraping targets
- Check data source URLs in Grafana
- Restart observability stack:
  ```bash
  cd observability
  docker-compose restart
  ```
- Check for network connectivity between containers

### Issue: Out of disk space

**Symptoms:**

- Services failing
- Cannot pull Docker images
- Logs full

**Check:**

```bash
# Check disk usage
df -h

# Check Docker disk usage
docker system df

# Check large log files
sudo du -sh /var/log/*
```

**Solutions:**

```bash
# Clean Docker images
docker system prune -a -f

# Clean old logs
sudo journalctl --vacuum-time=7d

# Rotate DDNS logs
sudo truncate -s 0 /var/log/ddns.log
```

### Getting Help

If you encounter issues not covered here:

1. Check container logs: `docker logs container_name`
2. Check system logs: `sudo journalctl -xe`
3. Verify all prerequisites are met
4. Review Cloudflare dashboard for DNS/API issues
5. Check the main README.md for service-specific information

---

## Summary

You now have a fully automated home server deployment with:

- ✅ All services running in Docker containers
- ✅ Automatic DNS updates every 5 minutes (DDNS)
- ✅ Automatic SSL certificate renewal
- ✅ Reverse proxy with HTTPS
- ✅ Monitoring and logging stack
- ✅ Production-ready infrastructure

**Key Files:**

- `~/.ddns-config` - DDNS credentials (keep secure)
- `database/.env` - Database passwords (keep secure)
- `observability/.env` - Grafana password (keep secure)
- `/var/log/ddns.log` - DDNS activity log
- `/etc/letsencrypt/live/ronakverse.net/` - SSL certificates

**Maintenance Schedule:**

- Automatic: DDNS (every 5 min), SSL renewal (twice daily)
- Weekly: Check logs and certificate expiry
- Monthly: System updates and cleanup

Enjoy your self-hosted RonakVerse! 🍓🚀
