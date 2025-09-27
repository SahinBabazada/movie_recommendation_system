#!/bin/bash

# 🚀 Quick Deploy Script - Movie Recommendation System
# File: scripts/quick_deploy.sh
# Complete automated deployment for Ubuntu server

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

# Confirmation
echo ""
read -p "🚀 Deploy Movie Recommendation System? This will install dependencies and configure services. Continue? (y/N): " confirm
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
    python3-certbot-nginx >/dev/null 2>&1

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
        plotly>=5.15.0
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

print_step "Configure Services"
print_status "Creating PM2 configuration..."

# Create PM2 ecosystem file
cat > "$TARGET_DIR/ecosystem.config.js" << 'EOF'
module.exports = {
  apps: [{
    name: 'movie-recommender',
    script: 'venv/bin/streamlit',
    args: 'run streamlit_app.py --server.port 8501 --server.address 127.0.0.1 --server.headless true --server.runOnSave false',
    cwd: '/opt/movie-recommendation-system',
    user: 'movie-app',
    env: {
      NODE_ENV: 'production',
      PYTHONPATH: '/opt/movie-recommendation-system/src'
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
    kill_timeout: 5000
  }]
};
EOF

chown movie-app:movie-app "$TARGET_DIR/ecosystem.config.js"
sudo -u movie-app mkdir -p "$TARGET_DIR/logs"

print_step "Configure Nginx"
print_status "Setting up Nginx reverse proxy..."

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

print_step "Configure Firewall"
print_status "Setting up UFW firewall..."
ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow ssh >/dev/null 2>&1
ufw allow 80 >/dev/null 2>&1
ufw allow 443 >/dev/null 2>&1
ufw allow 8501 >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1

print_step "Start Services"
print_status "Starting PM2 application..."
cd "$TARGET_DIR"
sudo -u movie-app pm2 delete movie-recommender 2>/dev/null || true
sudo -u movie-app pm2 start ecosystem.config.js
sudo -u movie-app pm2 save

# Setup PM2 startup
startup_cmd=$(sudo -u movie-app pm2 startup | grep "sudo env" | head -1 || true)
if [[ -n "$startup_cmd" ]]; then
    eval "$startup_cmd" >/dev/null 2>&1 || true
fi

print_status "Starting Nginx..."
systemctl start nginx
systemctl enable nginx

print_step "Create Management Scripts"
mkdir -p "$TARGET_DIR/scripts"

# Create management scripts here (start.sh, stop.sh, etc.)
cat > "$TARGET_DIR/scripts/start.sh" << 'SCRIPT_EOF'
#!/bin/bash
cd /opt/movie-recommendation-system
sudo -u movie-app pm2 start ecosystem.config.js
sudo systemctl start nginx
echo "✅ Services started"
SCRIPT_EOF

cat > "$TARGET_DIR/scripts/stop.sh" << 'SCRIPT_EOF'
#!/bin/bash
sudo -u movie-app pm2 stop movie-recommender
sudo systemctl stop nginx
echo "🛑 Services stopped"
SCRIPT_EOF

cat > "$TARGET_DIR/scripts/restart.sh" << 'SCRIPT_EOF'
#!/bin/bash
cd /opt/movie-recommendation-system
sudo -u movie-app pm2 restart movie-recommender
sudo systemctl reload nginx
echo "🔄 Services restarted"
SCRIPT_EOF

cat > "$TARGET_DIR/scripts/status.sh" << 'SCRIPT_EOF'
#!/bin/bash
echo "📊 Service Status:"
echo "=================="
echo "PM2 Processes:"
sudo -u movie-app pm2 list
echo ""
echo "Nginx Status:"
sudo systemctl status nginx --no-pager -l
SCRIPT_EOF

chmod +x "$TARGET_DIR/scripts"/*.sh
chown -R movie-app:movie-app "$TARGET_DIR/scripts"

print_step "Health Check"
sleep 10

# Check services
pm2_status=$(sudo -u movie-app pm2 list | grep movie-recommender | awk '{print $10}' 2>/dev/null || echo "unknown")
nginx_status=$(systemctl is-active nginx 2>/dev/null || echo "inactive")

print_status "Service Status:"
print_status "  PM2 App: $pm2_status"
print_status "  Nginx: $nginx_status"

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

print_step "Deployment Complete! 🎉"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   🎉 DEPLOYMENT SUCCESSFUL! 🎉                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}🌐 Access Your Movie Recommendation System:${NC}"
echo "  Local:      http://localhost/"
echo "  Direct:     http://localhost:8501"
if [[ -n "$SERVER_IP" ]]; then
    echo "  Public:     http://$SERVER_IP/"
    echo "  Direct:     http://$SERVER_IP:8501"
fi
echo ""
echo -e "${BLUE}🛠️ Management Commands:${NC}"
echo "  Start:      $TARGET_DIR/scripts/start.sh"
echo "  Stop:       $TARGET_DIR/scripts/stop.sh"
echo "  Restart:    $TARGET_DIR/scripts/restart.sh"
echo "  Status:     $TARGET_DIR/scripts/status.sh"
echo ""
echo -e "${BLUE}📊 Monitoring:${NC}"
echo "  PM2 Monitor: sudo -u movie-app pm2 monit"
echo "  App Logs:    sudo -u movie-app pm2 logs movie-recommender"
echo "  Nginx Logs:  sudo tail -f /var/log/nginx/movie-recommender.access.log"
echo ""
echo -e "${GREEN}🎬 Your Movie Recommendation System is now live!${NC}"
echo ""