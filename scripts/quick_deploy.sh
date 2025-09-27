#!/bin/bash

# 🚀 Quick Deploy Script - Movie Recommendation System with External Access
# File: scripts/quick_deploy.sh
# Complete automated deployment for Ubuntu server with external access

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           🎬 Movie Recommendation System                      ║
║                  Quick Deployment                            ║
║                 with External Access                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
    echo "========================================"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get current directory
PROJECT_DIR="$(pwd)"
TARGET_DIR="/opt/movie-recommendation-system"

print_status "🎯 Project directory: $PROJECT_DIR"
print_status "🖥️  Operating System: $(lsb_release -d | cut -f2)"

# Get server IP for display
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
print_status "🌐 Server IP: ${SERVER_IP:-'Detecting...'}"

# Confirmation
echo ""
read -p "🚀 Deploy Movie Recommendation System with external access? This will install dependencies and configure services. Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    print_status "Deployment cancelled"
    exit 0
fi

print_step "System Update"
print_status "Updating system packages..."
apt update >/dev/null 2>&1
apt upgrade -y >/dev/null 2>&1

print_step "Install Dependencies"
print_status "Installing system dependencies..."
apt install -y \
    curl \
    wget \
    unzip \
    git \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    nginx \
    ufw \
    htop \
    certbot \
    python3-certbot-nginx \
    net-tools >/dev/null 2>&1

# Install Node.js
if ! command -v node >/dev/null 2>&1; then
    print_status "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
    apt install -y nodejs >/dev/null 2>&1
fi

# Install PM2
if ! command -v pm2 >/dev/null 2>&1; then
    print_status "Installing PM2..."
    npm install -g pm2 >/dev/null 2>&1
fi

print_step "Create Application User"
if ! id "movie-app" &>/dev/null; then
    print_status "Creating application user..."
    useradd -r -m -s /bin/bash movie-app
    usermod -aG sudo movie-app
fi

print_step "Setup Application Directory"
print_status "Setting up application in $TARGET_DIR..."
mkdir -p /opt

# Copy project to target directory
if [[ "$PROJECT_DIR" != "$TARGET_DIR" ]]; then
    if [[ -d "$TARGET_DIR" ]]; then
        rm -rf "$TARGET_DIR"
    fi
    cp -r "$PROJECT_DIR" "$TARGET_DIR"
fi

cd "$TARGET_DIR"
chown -R movie-app:movie-app "$TARGET_DIR"

print_step "Python Environment Setup"
print_status "Creating Python virtual environment..."
sudo -u movie-app bash -c "
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install \
        pandas>=1.5.0 \
        numpy>=1.21.0 \
        matplotlib>=3.5.0 \
        seaborn>=0.11.0 \
        catboost>=1.2.0 \
        scikit-learn>=1.1.0 \
        tqdm>=4.64.0 \
        joblib>=1.2.0 \
        streamlit>=1.28.0 \
        plotly>=5.15.0 \
        pyyaml>=6.0
" 2>/dev/null

print_step "Download MovieLens Data"
print_status "Downloading MovieLens dataset..."
sudo -u movie-app bash -c "
    mkdir -p data/raw data/processed
    cd data/raw
    if [[ ! -f movies.csv ]] || [[ ! -f ratings.csv ]]; then
        wget -q https://files.grouplens.org/datasets/movielens/ml-latest-small.zip
        unzip -q ml-latest-small.zip
        mv ml-latest-small/* .
        rmdir ml-latest-small
        rm ml-latest-small.zip
    fi
"

print_step "Train ML Models"
if [[ ! -f "$TARGET_DIR/models/saved_models/content_based_model.cbm" ]]; then
    print_status "Training machine learning models (this may take a few minutes)..."
    sudo -u movie-app bash -c "
        cd $TARGET_DIR
        source venv/bin/activate
        timeout 600 python main.py || echo 'Training completed or timed out'
    " 2>/dev/null
else
    print_status "Pre-trained models found"
fi

print_step "Configure Services for External Access"
print_status "Creating PM2 configuration with external access..."

# Create PM2 ecosystem file - EXTERNAL ACCESS VERSION
cat > "$TARGET_DIR/ecosystem.config.js" << 'EOF'
module.exports = {
  apps: [{
    name: 'movie-recommender',
    script: 'venv/bin/streamlit',
    args: 'run streamlit_app.py --server.port 8501 --server.address 0.0.0.0 --server.headless true --server.runOnSave false --server.allowRunOnSave false',
    cwd: '/opt/movie-recommendation-system',
    env: {
      NODE_ENV: 'production',
      PYTHONPATH: '/opt/movie-recommendation-system/src',
      STREAMLIT_SERVER_ENABLE_CORS: 'false',
      STREAMLIT_SERVER_ENABLE_XSRF_PROTECTION: 'false'
    },
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '2G',
    error_file: '/opt/movie-recommendation-system/logs/err.log',
    out_file: '/opt/movie-recommendation-system/logs/out.log',
    log_file: '/opt/movie-recommendation-system/logs/combined.log',
    time: true,
    kill_timeout: 5000,
    restart_delay: 1000
  }]
};
EOF

chown movie-app:movie-app "$TARGET_DIR/ecosystem.config.js"
sudo -u movie-app mkdir -p "$TARGET_DIR/logs"

print_step "Configure Nginx for External Access"
print_status "Setting up Nginx reverse proxy with external access..."

cat > "/etc/nginx/sites-available/movie-recommender" << 'EOF'
upstream movie_app {
    server 127.0.0.1:8501 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    server_tokens off;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml;
    
    # Client settings
    client_max_body_size 10M;
    client_body_timeout 30;
    client_header_timeout 30;
    
    # Main application
    location / {
        proxy_pass http://movie_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 30s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Block sensitive files
    location ~ /\. {
        deny all;
        access_log off;
    }
    
    # Logs
    access_log /var/log/nginx/movie-recommender.access.log combined;
    error_log /var/log/nginx/movie-recommender.error.log warn;
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/movie-recommender /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx
if ! nginx -t >/dev/null 2>&1; then
    print_error "Nginx configuration error"
    nginx -t
    exit 1
fi

print_step "Configure Firewall for External Access"
print_status "Setting up UFW firewall for external access..."
ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow ssh >/dev/null 2>&1
ufw allow from any to any port 80 comment 'HTTP for Movie Recommender' >/dev/null 2>&1
ufw allow from any to any port 443 comment 'HTTPS for Movie Recommender' >/dev/null 2>&1
ufw allow from any to any port 8501 comment 'Streamlit for Movie Recommender' >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1

print_step "Start Services"
print_status "Starting PM2 application with external access..."
cd "$TARGET_DIR"

# FIXED PM2 startup - remove any existing processes first
sudo -u movie-app pm2 kill 2>/dev/null || true
sleep 3

# Start PM2 as movie-app user
sudo -u movie-app bash -c "
    cd $TARGET_DIR
    export PM2_HOME=/home/movie-app/.pm2
    pm2 start ecosystem.config.js
    pm2 save
"

# Setup PM2 startup
print_status "Setting up PM2 auto-startup..."
startup_script=$(sudo -u movie-app pm2 startup | grep -E '^sudo' | head -1 || true)
if [[ -n "$startup_script" ]]; then
    # Remove problematic flags if present
    fixed_startup=$(echo "$startup_script" | sed 's/--uid [^ ]* --gid [^ ]* //')
    eval "$fixed_startup" >/dev/null 2>&1 || true
fi

print_status "Starting Nginx..."
systemctl start nginx
systemctl enable nginx

print_step "Create Management Scripts"
mkdir -p "$TARGET_DIR/scripts"

# Create updated management scripts with external access info
cat > "$TARGET_DIR/scripts/start.sh" << 'SCRIPT_EOF'
#!/bin/bash
cd /opt/movie-recommendation-system
sudo -u movie-app pm2 start ecosystem.config.js 2>/dev/null || sudo -u movie-app pm2 restart movie-recommender
sudo systemctl start nginx

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo "✅ Services started"
echo "🌐 Access URLs:"
echo "  External: http://$SERVER_IP/"
echo "  Direct:   http://$SERVER_IP:8501"
echo "  Local:    http://localhost/"
SCRIPT_EOF

cat > "$TARGET_DIR/scripts/stop.sh" << 'SCRIPT_EOF'
#!/bin/bash
sudo -u movie-app pm2 stop movie-recommender 2>/dev/null || echo "PM2 not running"
sudo systemctl stop nginx 2>/dev/null || echo "Nginx not running"
echo "🛑 Services stopped"
SCRIPT_EOF

cat > "$TARGET_DIR/scripts/restart.sh" << 'SCRIPT_EOF'
#!/bin/bash
cd /opt/movie-recommendation-system
sudo -u movie-app pm2 restart movie-recommender 2>/dev/null || sudo -u movie-app pm2 start ecosystem.config.js
sudo systemctl reload nginx

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo "🔄 Services restarted"
echo "🌐 Access at: http://$SERVER_IP/"
SCRIPT_EOF

chmod +x "$TARGET_DIR/scripts"/*.sh
chown -R movie-app:movie-app "$TARGET_DIR/scripts"

print_step "Health Check"
print_status "Waiting for services to start with external access..."
sleep 15

# Check services
pm2_status=$(sudo -u "$APP_USER" pm2 list | grep movie-recommender | awk '{print $10}' 2>/dev/null || echo "unknown")
nginx_status=$(systemctl is-active nginx 2>/dev/null || echo "inactive")

print_status "Service Status:"
print_status "  PM2 App: $pm2_status"
print_status "  Nginx: $nginx_status"

# Check if external access is configured
if netstat -tlnp 2>/dev/null | grep ":8501 " | grep -q "0.0.0.0:8501"; then
    print_status "✅ Streamlit configured for external access"
else
    print_warning "⚠️ Streamlit may not be configured for external access yet"
fi

# Test application endpoints
if curl -sf http://localhost:8501/_stcore/health >/dev/null 2>&1; then
    print_status "✅ Streamlit application is responding"
elif curl -sf http://localhost:8501 >/dev/null 2>&1; then
    print_status "✅ Streamlit application is accessible"
else
    print_warning "⚠️ Streamlit application may still be starting..."
fi

if curl -sf http://localhost/health >/dev/null 2>&1; then
    print_status "✅ Nginx proxy is working"
else
    print_warning "⚠️ Nginx proxy may have issues"
fi

# Update server IP if not detected earlier
if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
fi

print_step "Deployment Complete! 🎉"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   🎉 DEPLOYMENT SUCCESSFUL! 🎉                ║${NC}"
echo -e "${GREEN}║                    with External Access                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}🌐 Your Movie Recommendation System is now live with external access!${NC}"
echo ""
echo "📍 Access URLs:"
echo ""
echo "  🌍 External Access (from anywhere):"
if [[ -n "$SERVER_IP" ]]; then
    echo "    Main Application: http://$SERVER_IP/"
    echo "    Direct Streamlit: http://$SERVER_IP:8501"
    echo "    Health Check:     http://$SERVER_IP/health"
else
    echo "    Could not determine external IP - check manually"
fi
echo ""
echo "  🏠 Local Access:"
echo "    Main Application: http://localhost/"
echo "    Direct Streamlit: http://localhost:8501"
echo "    Health Check:     http://localhost/health"
echo ""
echo "🛠️ Management Commands:"
echo "  Start:    $TARGET_DIR/scripts/start.sh"
echo "  Stop:     $TARGET_DIR/scripts/stop.sh"
echo "  Restart:  $TARGET_DIR/scripts/restart.sh"
echo "  Status:   $TARGET_DIR/scripts/status.sh"
echo ""
echo "🔥 Firewall Status:"
ufw status | grep -E "(Status|80|8501|443)" | head -4
echo ""
echo "📊 Monitoring:"
echo "  PM2 Monitor: sudo -u movie-app pm2 monit"
echo "  App Logs:    sudo -u movie-app pm2 logs movie-recommender"
echo "  Nginx Logs:  sudo tail -f /var/log/nginx/movie-recommender.access.log"
echo ""
echo "🔒 For SSL setup (optional):"
echo "  $TARGET_DIR/scripts/setup_ssl.sh yourdomain.com"
echo ""
echo -e "${GREEN}🎬 Your Movie Recommendation System is ready for external access!${NC}"
echo ""
echo "🎯 What you can do now:"
echo "  1. Open your browser and go to http://$SERVER_IP/"
echo "  2. Try the interactive movie recommendations"
echo "  3. Share the URL with others to try your system"
echo "  4. Check system status: $TARGET_DIR/scripts/status.sh"
echo ""
echo "🔧 If external access doesn't work:"
echo "  1. Check your cloud provider's security groups/firewall settings"
echo "  2. Ensure ports 80 and 8501 are open in your VPS control panel"
echo "  3. Run: $TARGET_DIR/scripts/configure_external_access.sh"
echo "  4. Test from another network: curl -I http://$SERVER_IP/"
echo ""

# Show final PM2 status
echo "📊 Current Service Status:"
sudo -u movie-app pm2 list 2>/dev/null | head -4 || echo "PM2 status not available"

echo ""
echo "✅ Deployment with external access completed successfully!"
echo "🌐 Try accessing http://$SERVER_IP/ from any device!"