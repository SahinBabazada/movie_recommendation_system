# 🚀 Ubuntu Server Deployment Guide

## Movie Recommendation System - Production Deployment

This guide provides step-by-step instructions for deploying the Movie Recommendation System on an Ubuntu server with full automation, including PM2 process management, firewall configuration, and SSL setup.

## 📋 Prerequisites

### Server Requirements
- **Ubuntu 20.04 LTS** or newer
- **Minimum 4GB RAM** (8GB recommended)
- **20GB free disk space**
- **Root or sudo access**
- **Internet connection**

### Domain & DNS (Optional)
- Domain name pointing to your server IP
- For SSL certificate setup

## ⚡ Quick Deployment (Automated)

### One-Command Setup
```bash
# Clone and deploy in one command
git clone https://github.com/SahinBabazada/movie-recommendation-system.git
cd movie-recommendation-system
chmod +x scripts/deploy.sh
sudo ./scripts/deploy.sh
```

This script will:
- ✅ Install all dependencies (Python, Node.js, PM2)
- ✅ Download MovieLens dataset
- ✅ Train ML models
- ✅ Configure firewall rules
- ✅ Start Streamlit with PM2
- ✅ Setup reverse proxy with Nginx
- ✅ Configure SSL (optional)

## 🔧 Manual Step-by-Step Deployment

### Step 1: System Preparation

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install system dependencies
sudo apt install -y git curl wget unzip python3 python3-pip python3-venv nodejs npm nginx ufw

# Install PM2 globally
sudo npm install -g pm2
```

### Step 2: Clone Project

```bash
# Clone the repository
git clone https://github.com/SahinBabazada/movie-recommendation-system.git
cd movie-recommendation-system

# Make scripts executable
chmod +x scripts/*.sh
```

### Step 3: Run Setup Script

```bash
# Run the automated setup
sudo ./scripts/setup_server.sh
```

### Step 4: Configure and Start Services

```bash
# Configure Nginx and start services
sudo ./scripts/configure_nginx.sh

# Start the application with PM2
./scripts/start_services.sh
```

## 📁 Project Structure on Server

```
/opt/movie-recommendation-system/
├── 📂 data/
│   ├── 📂 raw/                    # MovieLens dataset
│   └── 📂 processed/              # Processed data
├── 📂 models/
│   └── 📂 saved_models/           # Trained ML models
├── 📂 src/                        # Source code
├── 📂 scripts/                    # Deployment scripts
├── 📂 logs/                       # Application logs
├── 📄 streamlit_app.py           # Main application
└── 📄 ecosystem.config.js         # PM2 configuration
```

## 🛠️ Service Management

### PM2 Commands

```bash
# View running processes
pm2 list

# View logs
pm2 logs movie-recommender

# Restart application
pm2 restart movie-recommender

# Stop application
pm2 stop movie-recommender

# Monitor resources
pm2 monit

# Save PM2 configuration
pm2 save

# Setup auto-start on boot
pm2 startup
```

### Nginx Commands

```bash
# Check Nginx status
sudo systemctl status nginx

# Restart Nginx
sudo systemctl restart nginx

# Reload Nginx configuration
sudo systemctl reload nginx

# View Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## 🔥 Firewall Configuration

### UFW Setup

```bash
# Enable UFW
sudo ufw enable

# Allow SSH (important!)
sudo ufw allow ssh

# Allow HTTP and HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Allow Streamlit port (if needed)
sudo ufw allow 8501

# Check status
sudo ufw status
```

## 🌐 Domain & SSL Setup

### With Let's Encrypt (Recommended)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate (replace your-domain.com)
sudo certbot --nginx -d your-domain.com

# Auto-renewal setup
sudo crontab -e
# Add this line:
# 0 12 * * * /usr/bin/certbot renew --quiet
```

### Manual SSL Certificate

```bash
# If you have your own SSL certificates
sudo mkdir -p /etc/nginx/ssl
sudo cp your-cert.crt /etc/nginx/ssl/
sudo cp your-private.key /etc/nginx/ssl/
sudo chmod 600 /etc/nginx/ssl/*
```

## 📊 Monitoring & Maintenance

### System Monitoring

```bash
# Check system resources
htop
df -h
free -h

# Check application logs
pm2 logs movie-recommender

# Check Nginx logs
sudo tail -f /var/log/nginx/movie-recommender.log
```

### Health Check Endpoints

```bash
# Check if application is running
curl http://localhost:8501

# Check through Nginx proxy
curl http://your-domain.com/health
```

### Backup Strategy

```bash
# Backup trained models
tar -czf models-backup-$(date +%Y%m%d).tar.gz models/

# Backup data
tar -czf data-backup-$(date +%Y%m%d).tar.gz data/

# Automated backup script (add to cron)
./scripts/backup.sh
```

## 🔄 Updates & Deployment

### Update Application

```bash
# Pull latest changes
git pull origin main

# Restart services
pm2 restart movie-recommender
sudo systemctl reload nginx
```

### Retrain Models

```bash
# Retrain with new data
python3 main.py

# Restart application to load new models
pm2 restart movie-recommender
```

## ⚠️ Troubleshooting

### Common Issues

**Application won't start:**
```bash
# Check PM2 logs
pm2 logs movie-recommender

# Check Python environment
which python3
pip3 list | grep streamlit
```

**Port already in use:**
```bash
# Find process using port
sudo netstat -tulpn | grep :8501
sudo lsof -i :8501

# Kill process if needed
sudo kill -9 <PID>
```

**Permission issues:**
```bash
# Fix file permissions
sudo chown -R $USER:$USER /opt/movie-recommendation-system
chmod +x scripts/*.sh
```

**Nginx configuration errors:**
```bash
# Test configuration
sudo nginx -t

# Check configuration file
sudo nano /etc/nginx/sites-available/movie-recommender
```

### Performance Optimization

**For high traffic:**
```bash
# Increase PM2 instances
pm2 scale movie-recommender 4

# Tune Nginx worker processes
sudo nano /etc/nginx/nginx.conf
# worker_processes auto;
# worker_connections 1024;
```

**For large datasets:**
```bash
# Increase Python memory limit in ecosystem.config.js
# max_memory_restart: '2G'

# Monitor memory usage
pm2 monit
```

## 📈 Scaling Options

### Horizontal Scaling

```bash
# Load balancer setup with multiple instances
pm2 start ecosystem.config.js --env production

# Configure Nginx upstream
# upstream movie_app {
#     server 127.0.0.1:8501;
#     server 127.0.0.1:8502;
#     server 127.0.0.1:8503;
# }
```

### Database Integration

```bash
# For production with PostgreSQL
sudo apt install -y postgresql postgresql-contrib
sudo -u postgres createdb movie_recommendations
```

## 🔒 Security Best Practices

### Server Hardening

```bash
# Disable root login
sudo nano /etc/ssh/sshd_config
# PermitRootLogin no
sudo systemctl restart ssh

# Install fail2ban
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
```

### Application Security

```bash
# Hide server information
sudo nano /etc/nginx/nginx.conf
# server_tokens off;

# Add security headers in Nginx
# add_header X-Frame-Options DENY;
# add_header X-Content-Type-Options nosniff;
```

## 📞 Support & Maintenance

### Log Locations

- **Application logs**: `pm2 logs movie-recommender`
- **Nginx logs**: `/var/log/nginx/movie-recommender.log`
- **System logs**: `/var/log/syslog`
- **UFW logs**: `/var/log/ufw.log`

### Maintenance Schedule

- **Daily**: Check application status and logs
- **Weekly**: Review resource usage and performance
- **Monthly**: Update system packages and security patches
- **Quarterly**: Backup data and retrain models

### Emergency Procedures

```bash
# Quick restart everything
pm2 restart all
sudo systemctl restart nginx

# Check all services
sudo systemctl status nginx
pm2 list
sudo ufw status

# Emergency stop
pm2 stop all
sudo systemctl stop nginx
```

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Server meets minimum requirements
- [ ] Domain DNS configured (if using)
- [ ] SSH access configured
- [ ] Backup strategy planned

### Deployment
- [ ] Repository cloned
- [ ] Dependencies installed
- [ ] Data downloaded and processed
- [ ] Models trained
- [ ] Services configured and started
- [ ] Firewall rules applied

### Post-Deployment
- [ ] Application accessible via web
- [ ] SSL certificate installed (if applicable)
- [ ] Monitoring setup
- [ ] Backup scripts configured
- [ ] Performance tested
- [ ] Documentation updated

## 🎯 Production Configuration

### Environment Variables

```bash
# Create environment file
sudo nano /opt/movie-recommendation-system/.env

# Add production settings
ENVIRONMENT=production
LOG_LEVEL=INFO
MAX_WORKERS=4
STREAMLIT_SERVER_PORT=8501
STREAMLIT_SERVER_ADDRESS=127.0.0.1
```

### Resource Limits

```bash
# Configure system limits
sudo nano /etc/security/limits.conf

# Add these lines:
# movie-app soft nofile 65536
# movie-app hard nofile 65536
# movie-app soft nproc 32768
# movie-app hard nproc 32768
```

---

**🚀 Your Movie Recommendation System is now live on Ubuntu Server!**

For additional support or advanced configurations, refer to the troubleshooting section or contact the development team.