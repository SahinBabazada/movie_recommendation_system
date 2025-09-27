#!/bin/bash

# 🚀 Quick Deploy Script
# One-command deployment for Ubuntu server

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
║                  Quick Deployment Script                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
    echo "========================================"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    echo "Usage: sudo $0"
    exit 1
fi

# Get current directory (where the project was cloned)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$PROJECT_DIR/main.py" ]]; then
    PROJECT_DIR="$(pwd)"
fi

print_status "🎯 Project directory: $PROJECT_DIR"
print_status "🖥️  Operating System: $(lsb_release -d | cut -f2)"
print_status "👤 Running as: $(whoami)"

# Confirmation prompt
echo ""
read -p "🚀 Ready to deploy Movie Recommendation System? This will install dependencies and configure services. Continue? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    print_status "Deployment cancelled by user"
    exit 0
fi

print_step "System Preparation"

# Update system
print_status "Updating system packages..."
apt update >/dev/null 2>&1

# Install git if not present
if ! command -v git >/dev/null 2>&1; then
    print_status "Installing Git..."
    apt install -y git >/dev/null 2>&1
fi

print_step "Repository Setup"

# If we're not in the project directory, clone it
if [[ ! -f "main.py" ]]; then
    print_status "Cloning Movie Recommendation System repository..."
    if [[ -d "movie-recommendation-system" ]]; then
        rm -rf movie-recommendation-system
    fi
    git clone https://github.com/SahinBabazada/movie-recommendation-system.git
    cd movie-recommendation-system
    PROJECT_DIR="$(pwd)"
fi

# Make all scripts executable
find "$PROJECT_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

print_step "Dependency Installation"

# Check if scripts directory exists
if [[ ! -d "$PROJECT_DIR/scripts" ]]; then
    print_status "Creating scripts directory..."
    mkdir -p "$PROJECT_DIR/scripts"
fi

# Run setup server script if it exists, otherwise install dependencies manually
if [[ -f "$PROJECT_DIR/scripts/setup_server.sh" ]]; then
    print_status "Running server setup script..."
    bash "$PROJECT_DIR/scripts/setup_server.sh"
else
    print_status "Installing dependencies manually..."
    
    # Install Python
    apt install -y python3 python3-pip python3-venv python3-dev >/dev/null 2>&1
    python3 -m pip install --upgrade pip >/dev/null 2>&1
    
    # Install Node.js and PM2
    if ! command -v node >/dev/null 2>&1; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
        apt install -y nodejs >/dev/null 2>&1
    fi
    
    if ! command -v pm2 >/dev/null 2>&1; then
        npm install -g pm2 >/dev/null 2>&1
    fi
    
    # Install Nginx
    if ! command -v nginx >/dev/null 2>&1; then
        apt install -y nginx >/dev/null 2>&1
    fi
    
    # Install other tools
    apt install -y ufw certbot python3-certbot-nginx >/dev/null 2>&1
fi

print_step "Application Setup"

# Move to target directory
TARGET_DIR="/opt/movie-recommendation-system"
if [[ "$PROJECT_DIR" != "$TARGET_DIR" ]]; then
    print_status "Moving application to $TARGET_DIR..."
    mkdir -p /opt
    if [[ -d "$TARGET_DIR" ]]; then
        rm -rf "$TARGET_DIR"
    fi
    cp -r "$PROJECT_DIR" "$TARGET_DIR"
    cd "$TARGET_DIR"
fi

# Create application user
if ! id "movie-app" &>/dev/null; then
    print_status "Creating application user..."
    useradd -r -m -s /bin/bash movie-app
    usermod -aG sudo movie-app
fi

# Set ownership
chown -R movie-app:movie-app "$TARGET_DIR"

print_step "Python Environment Setup"

# Create virtual environment and install dependencies
print_status "Setting up Python virtual environment..."
cd "$TARGET_DIR"

sudo -u movie-app bash -c "
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    pip install streamlit plotly gunicorn
" 2>/dev/null

print_step "Data Download"

# Download MovieLens data
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

print_step "Model Training"

# Train models if they don't exist
if [[ ! -f "$TARGET_DIR/models/saved_models/content_based_model.cbm" ]]; then
    print_status "Training machine learning models (this may take a few minutes)..."
    sudo -u movie-app bash -c "
        cd $TARGET_DIR
        source venv/bin/activate
        python main.py
    " 2>/dev/null || {
        print_warning "Model training failed, but continuing with deployment..."
    }
else
    print_status "Pre-trained models found, skipping training"
fi

print_step "Service Configuration"

# Create PM2 ecosystem file
print_status "Creating PM2 configuration..."
cat > "$TARGET_DIR/ecosystem.config.js" << EOF
module.exports = {
  apps: [{
    name: 'movie-recommender',
    script: 'venv/bin/streamlit',
    args: 'run streamlit_app.py --server.port 8501 --server.address 127.0.0.1 --server.headless true',
    cwd: '$TARGET_DIR',
    user: 'movie-app',
    env: {
      NODE_ENV: 'production',
      PYTHONPATH: '$TARGET_DIR/src'
    },
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '2G',
    error_file: '$TARGET_DIR/logs/err.log',
    out_file: '$TARGET_DIR/logs/out.log',
    log_file: '$TARGET_DIR/logs/combined.log',
    time: true
  }]
};
EOF

chown movie-app:movie-app "$TARGET_DIR/ecosystem.config.js"
sudo -u movie-app mkdir -p "$TARGET_DIR/logs"

# Configure Nginx
print_status "Configuring Nginx..."
cat > "/etc/nginx/sites-available/movie-recommender" << 'EOF'
upstream movie_app {
    server 127.0.0.1:8501;
}

server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
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
        proxy_read_timeout 86400;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    access_log /var/log/nginx/movie-recommender.access.log;
    error_log /var/log/nginx/movie-recommender.error.log;
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/movie-recommender /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
if nginx -t >/dev/null 2>&1; then
    print_status "Nginx configuration is valid"
else
    print_error "Nginx configuration has errors"
    nginx -t
    exit 1
fi

print_step "Firewall Configuration"

# Configure UFW
print_status "Configuring firewall..."
ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow ssh >/dev/null 2>&1
ufw allow 80 >/dev/null 2>&1
ufw allow 443 >/dev/null 2>&1
ufw allow 8501 >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1

print_step "Starting Services"

# Start PM2 application
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

# Start Nginx
print_status "Starting Nginx..."
systemctl start nginx
systemctl enable nginx

print_step "Health Check"

# Wait for services to start
sleep 10

# Check services
pm2_status=$(sudo -u movie-app pm2 list | grep movie-recommender | awk '{print $10}' || echo "stopped")
nginx_status=$(systemctl is-active nginx || echo "inactive")

print_status "Service Status:"
print_status "  PM2 App: $pm2_status"
print_status "  Nginx: $nginx_status"

# Test endpoints
if curl -sf http://localhost:8501/_stcore/health >/dev/null 2>&1; then
    print_status "✅ Streamlit app is responding"
else
    print_warning "⚠️ Streamlit app may not be ready yet"
fi

if curl -sf http://localhost/health >/dev/null 2>&1; then
    print_status "✅ Nginx proxy is working"
else
    print_warning "⚠️ Nginx proxy may have issues"
fi

print_step "Creating Management Scripts"

# Create management scripts
mkdir -p "$TARGET_DIR/scripts"

# Start script
cat > "$TARGET_DIR/scripts/start.sh" << 'EOF'
#!/bin/bash
cd /opt/movie-recommendation-system
sudo -u movie-app pm2 start ecosystem.config.js
sudo systemctl start nginx
echo "✅ Services started"
EOF

# Stop script
cat > "$TARGET_DIR/scripts/stop.sh" << 'EOF'
#!/bin/bash
sudo -u movie-app pm2 stop movie-recommender
sudo systemctl stop nginx
echo "🛑 Services stopped"
EOF

# Restart script
cat > "$TARGET_DIR/scripts/restart.sh" << 'EOF'
#!/bin/bash
cd /opt/movie-recommendation-system
sudo -u movie-app pm2 restart movie-recommender
sudo systemctl reload nginx
echo "🔄 Services restarted"
EOF

# Status script
cat > "$TARGET_DIR/scripts/status.sh" << 'EOF'
#!/bin/bash
echo "📊 Service Status:"
echo "=================="
echo "PM2 Processes:"
sudo -u movie-app pm2 list
echo ""
echo "Nginx Status:"
sudo systemctl status nginx --no-pager -l
echo ""
echo "Firewall Status:"
sudo ufw status
EOF

# Make scripts executable
chmod +x "$TARGET_DIR/scripts"/*.sh
chown -R movie-app:movie-app "$TARGET_DIR/scripts"

print_step "Deployment Complete! 🎉"

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

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
echo -e "${BLUE}🔒 Security:${NC}"
echo "  Firewall:    sudo ufw status"
echo "  For SSL:     sudo certbot --nginx -d yourdomain.com"
echo ""
echo -e "${YELLOW}💡 Next Steps:${NC}"
echo "  1. Point your domain to this server IP: $SERVER_IP"
echo "  2. Setup SSL certificate with: sudo certbot --nginx -d yourdomain.com"
echo "  3. Configure monitoring and backups"
echo ""
echo -e "${GREEN}🎬 Your Movie Recommendation System is now live!${NC}"
echo ""

# Final service status
echo "Current Status:"
sudo -u movie-app pm2 list | head -5