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

gNpiDo1+kt/U2bMBFLt9gJMNB8VtE9lFeX4eAj2P+88=
Deploy:
9dujXOT8nNkHInieCXUPpGsDGQMstanOoeZYDDrl22o=

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

## SSL Certificate Setup

⚠️ **IMPORTANT:** Obtain SSL certificates BEFORE deploying services and configuring Nginx!

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

**Verify certificates exist:**

```bash
sudo ls -la /etc/letsencrypt/live/ronakverse.net/
```

You should see:

- `fullchain.pem`
- `privkey.pem`
- `cert.pem`
- `chain.pem`

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
4. Configures Nginx reverse proxy (requires SSL certificates from previous step)

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
