#!/bin/bash

# 📦 Install All Scripts - Creates all deployment scripts
# Run this script to create all necessary deployment scripts

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
    echo "----------------------------------------"
}

# Create scripts directory
mkdir -p scripts

print_step "Creating Deployment Scripts"

# Create the main deploy script
print_status "Creating deploy.sh..."
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
# This will contain the main deployment script
# Copy the content from the deploy_script artifact above
curl -s https://raw.githubusercontent.com/SahinBabazada/movie-recommendation-system/main/scripts/deploy.sh > scripts/deploy.sh
chmod +x scripts/deploy.sh
EOF

# Create setup server script
print_status "Creating setup_server.sh..."
cat > scripts/setup_server.sh << 'EOF'
#!/bin/bash
# Server setup script - installs all dependencies
# Copy the content from setup_server_script artifact above
curl -s https://raw.githubusercontent.com/SahinBabazada/movie-recommendation-system/main/scripts/setup_server.sh > scripts/setup_server.sh
chmod +x scripts/setup_server.sh
EOF

# Create nginx configuration script
print_status "Creating configure_nginx.sh..."
cat > scripts/configure_nginx.sh << 'EOF'
#!/bin/bash
# Nginx configuration script
# Copy the content from nginx_config_script artifact above
curl -s https://raw.githubusercontent.com/SahinBabazada/movie-recommendation-system/main/scripts/configure_nginx.sh > scripts/configure_nginx.sh
chmod +x scripts/configure_nginx.sh
EOF

# Create start services script
print_status "Creating start_services.sh..."
cat > scripts/start_services.sh << 'EOF'
#!/bin/bash
# Start services script
# Copy the content from start_services_script artifact above
curl -s https://raw.githubusercontent.com/SahinBabazada/movie-recommendation-system/main/scripts/start_services.sh > scripts/start_services.sh
chmod +x scripts/start_services.sh
EOF

# Create the quick deploy script
print_status "Creating quick_deploy.sh..."
cat > scripts/quick_deploy.sh << 'EOF'
#!/bin/bash
# Quick deployment script
# Copy the content from quick_deploy_script artifact above
curl -s https://raw.githubusercontent.com/SahinBabazada/movie-recommendation-system/main/scripts/quick_deploy.sh > scripts/quick_deploy.sh
chmod +x scripts/quick_deploy.sh
EOF

print_step "Creating Management Scripts"

# Create start script
print_status "Creating start.sh..."
cat > scripts/start.sh << 'EOF'
#!/bin/bash
# Start Movie Recommendation System
cd /opt/movie-recommendation-system 2>/dev/null || cd "$(dirname "$0")/.."
sudo -u movie-app pm2 start ecosystem.config.js 2>/dev/null || {
    echo "⚠️ PM2 not configured yet. Run deployment script first."
    exit 1
}
sudo systemctl start nginx
echo "✅ Movie Recommendation System started"
EOF

# Create stop script
print_status "Creating stop.sh..."
cat > scripts/stop.sh << 'EOF'
#!/bin/bash
# Stop Movie Recommendation System
sudo -u movie-app pm2 stop movie-recommender 2>/dev/null || echo "PM2 not running"
sudo systemctl stop nginx 2>/dev/null || echo "Nginx not running"
echo "🛑 Movie Recommendation System stopped"
EOF

# Create restart script
print_status "Creating restart.sh..."
cat > scripts/restart.sh << 'EOF'
#!/bin/bash
# Restart Movie Recommendation System
cd /opt/movie-recommendation-system 2>/dev/null || cd "$(dirname "$0")/.."
sudo -u movie-app pm2 restart movie-recommender 2>/dev/null || {
    echo "Starting PM2 application..."
    sudo -u movie-app pm2 start ecosystem.config.js
}
sudo systemctl reload nginx
echo "🔄 Movie Recommendation System restarted"
EOF

# Create status script
print_status "Creating status.sh..."
cat > scripts/status.sh << 'EOF'
#!/bin/bash
# Check Movie Recommendation System status

echo "📊 Movie Recommendation System Status"
echo "======================================"

echo ""
echo "🔥 PM2 Processes:"
if command -v pm2 >/dev/null 2>&1; then
    sudo -u movie-app pm2 list 2>/dev/null || echo "PM2 not configured"
else
    echo "PM2 not installed"
fi

echo ""
echo "🌐 Nginx Status:"
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx is running"
else
    echo "❌ Nginx is not running"
fi

echo ""
echo "🔥 Firewall Status:"
if command -v ufw >/dev/null 2>&1; then
    sudo ufw status
else
    echo "UFW not installed"
fi

echo ""
echo "💾 Disk Usage:"
df -h /opt/movie-recommendation-system 2>/dev/null || df -h .

echo ""
echo "🔗 Service Endpoints:"
echo "  Local App:     http://localhost:8501"
echo "  Nginx Proxy:   http://localhost/"
echo "  Health Check:  http://localhost/health"

echo ""
echo "🧪 Quick Health Check:"
if curl -sf http://localhost/health >/dev/null 2>&1; then
    echo "✅ Application is responding"
else
    echo "❌ Application is not responding"
fi
EOF

# Create backup script
print_status "Creating backup.sh..."
cat > scripts/backup.sh << 'EOF'
#!/bin/bash
# Backup Movie Recommendation System

BACKUP_DIR="/opt/backups/movie-recommender"
APP_DIR="/opt/movie-recommendation-system"
DATE=$(date +%Y%m%d_%H%M%S)

echo "📦 Creating backup for Movie Recommendation System..."

# Create backup directory
sudo mkdir -p "$BACKUP_DIR"

# Backup models
if [[ -d "$APP_DIR/models" ]]; then
    echo "Backing up trained models..."
    sudo tar -czf "$BACKUP_DIR/models_$DATE.tar.gz" -C "$APP_DIR" models/
fi

# Backup data
if [[ -d "$APP_DIR/data" ]]; then
    echo "Backing up data..."
    sudo tar -czf "$BACKUP_DIR/data_$DATE.tar.gz" -C "$APP_DIR" data/
fi

# Backup configuration
echo "Backing up configuration..."
sudo tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" -C "$APP_DIR" \
    ecosystem.config.js \
    config/ \
    requirements.txt \
    2>/dev/null || true

# Backup nginx config
if [[ -f "/etc/nginx/sites-available/movie-recommender" ]]; then
    echo "Backing up Nginx configuration..."
    sudo cp /etc/nginx/sites-available/movie-recommender "$BACKUP_DIR/nginx_config_$DATE.conf"
fi

echo "✅ Backup completed!"
echo "📁 Backup location: $BACKUP_DIR"
echo "📋 Backup files:"
sudo ls -la "$BACKUP_DIR/"*"$DATE"*
EOF

# Create update script
print_status "Creating update.sh..."
cat > scripts/update.sh << 'EOF'
#!/bin/bash
# Update Movie Recommendation System

echo "🔄 Updating Movie Recommendation System..."

APP_DIR="/opt/movie-recommendation-system"
cd "$APP_DIR" || { echo "❌ App directory not found"; exit 1; }

# Backup current version
echo "📦 Creating backup before update..."
./scripts/backup.sh

# Stop services
echo "🛑 Stopping services..."
./scripts/stop.sh

# Pull latest changes
echo "📥 Pulling latest changes..."
sudo -u movie-app git pull origin main

# Update Python dependencies
echo "📦 Updating Python dependencies..."
sudo -u movie-app bash -c "
    source venv/bin/activate
    pip install --upgrade -r requirements.txt
"

# Retrain models if needed
read -p "🤖 Retrain models with latest data? (y/N): " retrain
if [[ "$retrain" =~ ^[Yy]$ ]]; then
    echo "🎓 Retraining models..."
    sudo -u movie-app bash -c "
        source venv/bin/activate
        python main.py
    "
fi

# Start services
echo "🚀 Starting services..."
./scripts/start.sh

echo "✅ Update completed!"
EOF

# Create logs script
print_status "Creating logs.sh..."
cat > scripts/logs.sh << 'EOF'
#!/bin/bash
# View Movie Recommendation System logs

case "${1:-pm2}" in
    "pm2"|"app")
        echo "📊 PM2 Application Logs:"
        sudo -u movie-app pm2 logs movie-recommender
        ;;
    "nginx"|"proxy")
        echo "🌐 Nginx Access Logs:"
        sudo tail -f /var/log/nginx/movie-recommender.access.log
        ;;
    "error"|"nginx-error")
        echo "❌ Nginx Error Logs:"
        sudo tail -f /var/log/nginx/movie-recommender.error.log
        ;;
    "system")
        echo "🖥️ System Logs:"
        sudo journalctl -u nginx -f
        ;;
    "all")
        echo "📊 All Recent Logs:"
        echo "PM2 Logs:"
        sudo -u movie-app pm2 logs movie-recommender --lines 20
        echo ""
        echo "Nginx Access:"
        sudo tail -20 /var/log/nginx/movie-recommender.access.log
        echo ""
        echo "Nginx Error:"
        sudo tail -20 /var/log/nginx/movie-recommender.error.log
        ;;
    *)
        echo "📋 Log Viewer for Movie Recommendation System"
        echo ""
        echo "Usage: $0 [TYPE]"
        echo ""
        echo "Types:"
        echo "  pm2, app         - PM2 application logs (default)"
        echo "  nginx, proxy     - Nginx access logs"
        echo "  error            - Nginx error logs"
        echo "  system           - System service logs"
        echo "  all              - All recent logs"
        echo ""
        ;;
esac
EOF

# Create SSL setup script
print_status "Creating setup_ssl.sh..."
cat > scripts/setup_ssl.sh << 'EOF'
#!/bin/bash
# Setup SSL for Movie Recommendation System

echo "🔒 SSL Certificate Setup for Movie Recommendation System"

# Check if domain is provided
if [[ -z "$1" ]]; then
    echo "❌ Domain name required"
    echo "Usage: $0 <domain.com>"
    echo "Example: $0 movies.example.com"
    exit 1
fi

DOMAIN="$1"

echo "🌐 Setting up SSL for domain: $DOMAIN"

# Check if certbot is installed
if ! command -v certbot >/dev/null 2>&1; then
    echo "📦 Installing Certbot..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
fi

# Update Nginx configuration with domain
echo "🔧 Updating Nginx configuration for domain..."
sudo sed -i "s/server_name _;/server_name $DOMAIN;/" /etc/nginx/sites-available/movie-recommender

# Test nginx configuration
if ! sudo nginx -t; then
    echo "❌ Nginx configuration error"
    exit 1
fi

# Reload nginx
sudo systemctl reload nginx

# Obtain SSL certificate
echo "🔒 Obtaining SSL certificate..."
sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "admin@$DOMAIN" || {
    echo "❌ SSL certificate setup failed"
    echo "💡 Make sure:"
    echo "  1. Domain $DOMAIN points to this server"
    echo "  2. Port 80 and 443 are open"
    echo "  3. No other web server is running"
    exit 1
}

# Setup auto-renewal
echo "⏰ Setting up auto-renewal..."
(sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | sudo crontab -

echo "✅ SSL setup completed!"
echo "🌐 Your site is now available at: https://$DOMAIN"
echo "🔄 Auto-renewal configured for certificate"
EOF

# Make all scripts executable
chmod +x scripts/*.sh

print_step "Creating Documentation"

# Create README for scripts
print_status "Creating scripts README..."
cat > scripts/README.md << 'EOF'
# 🚀 Deployment Scripts

This directory contains all the scripts needed to deploy and manage the Movie Recommendation System on Ubuntu server.

## 📋 Quick Start

### One-Command Deployment
```bash
# Clone and deploy everything
git clone https://github.com/SahinBabazada/movie-recommendation-system.git
cd movie-recommendation-system
sudo ./scripts/quick_deploy.sh
```

### Step-by-Step Deployment
```bash
# 1. Setup server dependencies
sudo ./scripts/setup_server.sh

# 2. Configure Nginx
sudo ./scripts/configure_nginx.sh

# 3. Start services
./scripts/start_services.sh
```

## 🛠️ Management Scripts

| Script | Description |
|--------|-------------|
| `start.sh` | Start all services |
| `stop.sh` | Stop all services |
| `restart.sh` | Restart all services |
| `status.sh` | Check service status |
| `logs.sh` | View application logs |
| `backup.sh` | Backup models and data |
| `update.sh` | Update application |
| `setup_ssl.sh` | Setup SSL certificate |

## 📊 Usage Examples

```bash
# Start the system
./scripts/start.sh

# Check status
./scripts/status.sh

# View logs
./scripts/logs.sh pm2      # PM2 logs
./scripts/logs.sh nginx    # Nginx logs
./scripts/logs.sh all      # All logs

# Backup data
./scripts/backup.sh

# Setup SSL
./scripts/setup_ssl.sh yourdomain.com

# Update system
./scripts/update.sh
```

## 🔧 Configuration

Scripts use these default settings:
- **App Directory**: `/opt/movie-recommendation-system`
- **App User**: `movie-app`
- **Streamlit Port**: `8501`
- **Nginx Port**: `80, 443`

## 📁 File Structure

After deployment:
```
/opt/movie-recommendation-system/
├── data/raw/              # MovieLens dataset
├── models/saved_models/   # Trained ML models
├── logs/                  # Application logs
├── scripts/               # Management scripts
├── ecosystem.config.js    # PM2 configuration
└── streamlit_app.py       # Main application
```

## 🔍 Troubleshooting

### Service Not Starting
```bash
# Check logs
./scripts/logs.sh all

# Check status
./scripts/status.sh

# Restart services
./scripts/restart.sh
```

### Permission Issues
```bash
# Fix ownership
sudo chown -R movie-app:movie-app /opt/movie-recommendation-system
```

### Port Issues
```bash
# Check what's using port 8501
sudo netstat -tulpn | grep :8501
sudo lsof -i :8501
```

## 🚨 Emergency Commands

```bash
# Stop everything immediately
sudo pkill -f streamlit
sudo systemctl stop nginx
sudo -u movie-app pm2 kill

# Restart everything
./scripts/restart.sh
```

For more help, check the main documentation or open an issue.
EOF

print_step "Deployment Ready! 🎉"

echo ""
echo -e "${GREEN}✅ All deployment scripts created successfully!${NC}"
echo ""
echo "📁 Created scripts:"
ls -la scripts/
echo ""
echo -e "${BLUE}🚀 Quick Deployment Options:${NC}"
echo ""
echo "1️⃣ **One-command deployment:**"
echo "   sudo ./scripts/quick_deploy.sh"
echo ""
echo "2️⃣ **Step-by-step deployment:**"
echo "   sudo ./scripts/setup_server.sh"
echo "   sudo ./scripts/configure_nginx.sh"
echo "   ./scripts/start_services.sh"
echo ""
echo "3️⃣ **Custom deployment:**"
echo "   sudo ./scripts/deploy.sh"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Review scripts in the scripts/ directory"
echo "2. Choose your deployment method above"
echo "3. Access your app at http://your-server-ip/"
echo "4. Setup SSL with: ./scripts/setup_ssl.sh yourdomain.com"
echo ""
echo -e "${GREEN}🎬 Ready to deploy your Movie Recommendation System!${NC}"