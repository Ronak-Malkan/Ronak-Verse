# Ronak-Verse Deployment Guide

Complete guide for deploying all applications on the Digital Ocean droplet.

---

## **Architecture Overview**

```
Digital Ocean Droplet (1GB RAM)
├── Shared Infrastructure
│   ├── PostgreSQL (multiple databases)
│   ├── Redis (cache & sessions)
│   └── RabbitMQ (message queue)
├── Observability Stack
│   ├── Prometheus (metrics)
│   ├── Grafana (dashboards)
│   ├── Loki (logs)
│   └── Promtail (log shipper)
├── Applications
│   ├── Puzzle (microservices)
│   ├── Gateway (main site)
│   ├── Portfolio
│   └── Games (TwoCars, TypeIt)
└── Nginx (SSL + reverse proxy)
```

---

## **Initial Server Setup** (One-Time)

### **1. Connect to Droplet**

```bash
ssh root@your-droplet-ip
```

### **2. Clone Ronak-Verse Repository**

```bash
cd /root
git clone git@github.com:Ronak-Malkan/Ronak-Verse.git
cd Ronak-Verse
```

### **3. Basic Configuration** (if not already done)

```bash
./basic-config.sh
```

This installs:
- Docker Engine
- UFW firewall
- Fail2ban
- Basic security

---

## **Deployment Steps**

### **Step 1: Deploy Database Infrastructure**

```bash
cd /root/Ronak-Verse/database

# Copy and configure environment variables
cp .env.example .env
nano .env  # Fill in POSTGRES_PASSWORD and RABBITMQ_PASSWORD

# Deploy
./deploy.sh
```

**Expected Output:**
```
[1/5] Checking Docker network...
✓ Network created
[2/5] Stopping existing containers...
✓ Stopped
[3/5] Starting infrastructure services...
✓ Services started
[4/5] Waiting for services to be healthy...
  - PostgreSQL: ✓ Ready
  - Redis: ✓ Ready
  - RabbitMQ: ✓ Ready
[5/5] Deployment complete!
```

**Verify:**
```bash
docker ps | grep ronak-verse
```

Should show:
- `ronak-verse-postgres`
- `ronak-verse-redis`
- `ronak-verse-rabbitmq`

---

### **Step 2: Deploy Observability Stack**

```bash
cd /root/Ronak-Verse/observability

# Copy and configure environment variables
cp .env.example .env
nano .env  # Fill in GRAFANA_PASSWORD and POSTGRES_PASSWORD

# Deploy
./deploy.sh
```

**Expected Output:**
```
[1/4] Checking Docker network...
✓ Network exists
[2/4] Stopping existing containers...
✓ Stopped
[3/4] Starting observability services...
✓ Services started
[4/4] Waiting for services to be healthy...
  - Prometheus: ✓ Ready
  - Loki: ✓ Ready
  - Grafana: ✓ Ready
Deployment complete!
```

**Access Grafana:**
```
http://your-droplet-ip:3000
User: admin
Password: (from .env)
```

---

### **Step 3: Deploy Puzzle Application**

```bash
cd /root/Ronak-Verse/services/Puzzle

# Deploy (will clone Puzzle repo and run migrations)
./deploy.sh
```

**Expected Output:**
```
[1/6] Checking prerequisites...
✓ Prerequisites met
[2/6] Cloning/updating Puzzle repository...
✓ Repository updated
[3/6] Running database migrations...
✓ Databases created
[4/6] Stopping existing Puzzle containers...
✓ Stopped
[5/6] Building and starting Puzzle services...
✓ Services started
[6/6] Waiting for services to be healthy...
  - puzzle-web: ✓ Running
  - puzzle-api-gateway: ✓ Running
  - puzzle-auth-service: ✓ Running
  - puzzle-block-service: ✓ Running
  - puzzle-blog-service: ✓ Running
  - puzzle-notification-service: ✓ Running
Puzzle Deployment Complete!
```

**Verify:**
```bash
docker ps | grep puzzle
```

Should show 6 Puzzle containers running.

---

### **Step 4: Configure Nginx**

```bash
cd /root/Ronak-Verse

# Copy updated nginx.conf to nginx sites-available
sudo cp nginx.conf /etc/nginx/sites-available/ronakverse.net

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

---

### **Step 5: Obtain SSL Certificates**

**For new subdomains (puzzle, metrics):**

```bash
# Add DNS records first (in DigitalOcean dashboard):
# puzzle.ronakverse.net  → A record → your-droplet-ip
# metrics.ronakverse.net → A record → your-droplet-ip

# Obtain certificates
sudo certbot --nginx -d puzzle.ronakverse.net -d www.puzzle.ronakverse.net
sudo certbot --nginx -d metrics.ronakverse.net
```

**OR use existing wildcard certificate:**

If you already have `*.ronakverse.net` certificate, it covers all subdomains automatically!

---

## **Verification & Testing**

### **1. Check All Containers**

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Expected containers:
- ronak-verse-postgres
- ronak-verse-redis
- ronak-verse-rabbitmq
- ronak-verse-prometheus
- ronak-verse-grafana
- ronak-verse-loki
- ronak-verse-promtail
- ronak-verse-postgres-exporter
- ronak-verse-redis-exporter
- puzzle-web
- puzzle-api-gateway
- puzzle-auth-service
- puzzle-block-service
- puzzle-blog-service
- puzzle-notification-service

### **2. Test Endpoints**

**Puzzle Frontend:**
```bash
curl -I https://puzzle.ronakverse.net
# Should return: 200 OK
```

**Puzzle API:**
```bash
curl https://puzzle.ronakverse.net/api/health
# Should return: {"status": "ok"}
```

**Grafana:**
```bash
curl -I https://metrics.ronakverse.net
# Should return: 200 OK
```

### **3. Check Metrics**

Visit Grafana:
```
https://metrics.ronakverse.net
```

Navigate to:
- Explore → Select "Prometheus" datasource
- Query: `up{application="puzzle"}`
- Should show all Puzzle services as `1` (up)

### **4. Check Logs**

**In Grafana:**
- Explore → Select "Loki" datasource
- Query: `{application="puzzle"}`
- Should show logs from all Puzzle services

**Via CLI:**
```bash
# View API Gateway logs
docker logs -f puzzle-api-gateway

# View all Puzzle logs
docker-compose -f /root/puzzle-app/docker-compose.yml logs -f
```

---

## **Updating Applications**

### **Update Puzzle**

```bash
cd /root/Ronak-Verse/services/Puzzle
./deploy.sh
```

This will:
1. Pull latest code from GitHub
2. Run any new migrations
3. Rebuild Docker images
4. Restart containers with zero downtime (future: rolling updates)

### **Update Infrastructure**

```bash
# Update database infrastructure
cd /root/Ronak-Verse/database
git pull
./deploy.sh

# Update observability
cd /root/Ronak-Verse/observability
git pull
./deploy.sh
```

---

## **Monitoring & Maintenance**

### **View System Resources**

```bash
# Memory usage
free -h

# Disk usage
df -h

# Docker stats (real-time)
docker stats

# Top containers by memory
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" | sort -k2 -h
```

### **Backup Database**

```bash
# Full backup (all databases)
docker exec ronak-verse-postgres pg_dumpall -U postgres > /root/backups/backup-$(date +%Y%m%d).sql

# Backup specific Puzzle databases
docker exec ronak-verse-postgres pg_dump -U postgres puzzle_auth_db > /root/backups/puzzle_auth-$(date +%Y%m%d).sql
docker exec ronak-verse-postgres pg_dump -U postgres puzzle_blocks_db > /root/backups/puzzle_blocks-$(date +%Y%m%d).sql
docker exec ronak-verse-postgres pg_dump -U postgres puzzle_blog_db > /root/backups/puzzle_blog-$(date +%Y%m%d).sql
```

### **Restore Database**

```bash
# Restore full backup
docker exec -i ronak-verse-postgres psql -U postgres < /root/backups/backup-20251105.sql

# Restore specific database
docker exec -i ronak-verse-postgres psql -U postgres puzzle_auth_db < /root/backups/puzzle_auth-20251105.sql
```

### **View Logs**

```bash
# Infrastructure logs
docker-compose -f /root/Ronak-Verse/database/docker-compose.yml logs -f postgres
docker-compose -f /root/Ronak-Verse/database/docker-compose.yml logs -f redis
docker-compose -f /root/Ronak-Verse/database/docker-compose.yml logs -f rabbitmq

# Observability logs
docker-compose -f /root/Ronak-Verse/observability/docker-compose.yml logs -f grafana
docker-compose -f /root/Ronak-Verse/observability/docker-compose.yml logs -f prometheus

# Puzzle logs
docker logs -f puzzle-api-gateway
docker logs -f puzzle-blog-service
docker logs --tail=100 puzzle-auth-service  # Last 100 lines
```

---

## **Troubleshooting**

### **Problem: Out of Memory**

```bash
# Check memory usage
free -h

# Check SWAP
swapon --show

# Add SWAP if needed (2GB)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### **Problem: Container Won't Start**

```bash
# Check container logs
docker logs container_name

# Check Docker network
docker network inspect ronak-verse-network

# Restart container
docker restart container_name

# Remove and recreate
docker stop container_name
docker rm container_name
docker-compose up -d container_name
```

### **Problem: Database Connection Failed**

```bash
# Check if PostgreSQL is running
docker exec ronak-verse-postgres pg_isready -U postgres

# Check PostgreSQL logs
docker logs ronak-verse-postgres

# Test connection from container
docker exec puzzle-auth-service ping ronak-verse-postgres
```

### **Problem: Nginx 502 Bad Gateway**

```bash
# Check if backend is running
docker ps | grep puzzle

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Test backend directly
curl http://localhost:3000  # Puzzle frontend
curl http://localhost:8080  # API Gateway

# Reload nginx
sudo nginx -t
sudo systemctl reload nginx
```

### **Problem: SSL Certificate Expired**

```bash
# Check certificate expiry
sudo certbot certificates

# Renew certificates
sudo certbot renew

# Reload nginx
sudo systemctl reload nginx
```

---

## **Security Checklist**

- [ ] UFW firewall enabled (ports 22, 80, 443 only)
- [ ] Fail2ban running (SSH brute force protection)
- [ ] Strong passwords in `.env` files
- [ ] SSL certificates valid and auto-renewing
- [ ] Grafana password changed from default
- [ ] PostgreSQL password strong and unique
- [ ] RabbitMQ password strong and unique
- [ ] Docker containers restart automatically
- [ ] Regular backups configured
- [ ] Monitoring alerts configured

---

## **Performance Optimization**

### **For 1GB RAM:**

1. **Monitor memory constantly:**
   ```bash
   watch -n 5 free -h
   ```

2. **Adjust container memory limits in docker-compose files**

3. **Enable SWAP (2GB recommended)**

4. **Tune PostgreSQL:**
   ```bash
   # Edit database/postgresql.conf
   shared_buffers = 128MB
   effective_cache_size = 256MB
   ```

5. **Tune Redis:**
   ```bash
   # Already configured in database/docker-compose.yml
   maxmemory 50mb
   maxmemory-policy allkeys-lru
   ```

6. **Monitor with Grafana:**
   - Create dashboard for memory usage
   - Set alerts at 80% memory

---

## **Quick Reference**

### **Common Commands**

```bash
# View all containers
docker ps -a

# Restart all Puzzle services
docker-compose -f /root/puzzle-app/docker-compose.yml restart

# View Puzzle API Gateway logs
docker logs -f puzzle-api-gateway

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Access RabbitMQ Management
open http://your-droplet-ip:15672

# Check nginx configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### **URLs**

- **Puzzle**: https://puzzle.ronakverse.net
- **Grafana**: https://metrics.ronakverse.net
- **Prometheus**: http://your-droplet-ip:9090 (internal)
- **RabbitMQ**: http://your-droplet-ip:15672 (internal)

---

## **Next Steps**

**Phase 2: Frontend Modernization**
- Migrate to Vite + TypeScript
- Implement Tailwind CSS
- Add Framer Motion animations
- Improve UI/UX

**Phase 3: Complete Microservices**
- Implement actual API Gateway logic
- Implement Auth Service (Go)
- Implement Blog Service
- Implement Notification Service

**Phase 4: New Features**
- Table blocks
- Blog platform
- Social features (likes, comments)

---

## **Support**

For issues or questions:
1. Check logs: `docker logs -f container_name`
2. Check Grafana for metrics/alerts
3. Review this guide
4. Check container status: `docker ps`

Happy deploying! 🚀
