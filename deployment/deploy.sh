#!/bin/bash

# 🚀 Movie Recommendation System - Ubuntu Server Deployment Script
# This script automates the complete deployment process on Ubuntu server

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="movie-recommender"
APP_DIR="/opt/movie-recommendation-system"
APP_USER="movie-app"
DOMAIN=""  # Will be prompted
SSL_ENABLED=false

# Logging
LOG_FILE="/var/log/movie-recommender-deploy.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BLUE}🎬 Movie Recommendation System Deployment${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "📅 Started at: $(date)"
echo "📋 Log file: $LOG_FILE"

# Function to print colored output
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
    echo "----------------------------------------"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to get user input
get_user_input() {
    print_step "Configuration Setup"
    
    # Domain name (optional)
    read -p "Enter your domain name (optional, press Enter to skip): " DOMAIN
    
    if [[ -n "$DOMAIN" ]]; then
        read -p "Do you want to setup SSL with Let's Encrypt? (y/n): " ssl_choice
        if [[ "$ssl_choice" == "y" || "$ssl_choice" == "Y" ]]; then
            SSL_ENABLED=true
        fi
    fi
    
    print_status "Configuration saved:"
    print_status "  Domain: ${DOMAIN:-'None (using IP address)'}"
    print_status "  SSL: $([ "$SSL_ENABLED" = true ] && echo 'Enabled' || echo 'Disabled')"
}

# Function to update system
update_system() {
    print_step "System Update"
    
    print_status "Updating package lists..."
    apt update
    
    print_status "Upgrading system packages..."
    apt upgrade -y
    
    print_status "Installing essential packages..."
    apt install -y curl wget unzip git software-properties-common apt-transport-https ca-certificates
}

# Function to install Python and dependencies
install_python() {
    print_step "Python Installation"
    
    print_status "Installing Python 3.9+ and pip..."
    apt install -y python3 python3-pip python3-venv python3-dev
    
    # Update pip
    python3 -m pip install --upgrade pip
    
    print_status "Python version: $(python3 --version)"
    print_status "Pip version: $(pip3 --version)"
}

# Function to install Node.js and PM2
install_nodejs() {
    print_step "Node.js and PM2 Installation"
    
    if ! command_exists node; then
        print_status "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt install -y nodejs
    fi
    
    print_status "Node.js version: $(node --version)"
    print_status "NPM version: $(npm --version)"
    
    if ! command_exists pm2; then
        print_status "Installing PM2..."
        npm install -g pm2
    fi
    
    print_status "PM2 version: $(pm2 --version)"
}

# Function to install and configure Nginx
install_nginx() {
    print_step "Nginx Installation"
    
    if ! command_exists nginx; then
        print_status "Installing Nginx..."
        apt install -y nginx
    fi
    
    print_status "Starting and enabling Nginx..."
    systemctl start nginx
    systemctl enable nginx
    
    print_status "Nginx version: $(nginx -v 2>&1 | cut -d' ' -f3)"
}

# Function to create application user
create_app_user() {
    print_step "Application User Setup"
    
    if ! id "$APP_USER" &>/dev/null; then
        print_status "Creating application user: $APP_USER"
        useradd -r -m -s /bin/bash "$APP_USER"
        usermod -aG sudo "$APP_USER"
    else
        print_status "User $APP_USER already exists"
    fi
}

# Function to setup application directory
setup_app_directory() {
    print_step "Application Directory Setup"
    
    print_status "Creating application directory: $APP_DIR"
    mkdir -p "$APP_DIR"
    
    # Copy current directory contents to app directory if we're not already there
    if [[ "$(pwd)" != "$APP_DIR" ]]; then
        print_status "Copying application files..."
        cp -r . "$APP_DIR/"
    fi
    
    # Set ownership
    chown -R "$APP_USER:$APP_USER" "$APP_DIR"
    
    # Make scripts executable
    find "$APP_DIR/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    
    print_status "Application directory setup complete"
}

# Function to install Python dependencies
install_python_deps() {
    print_step "Python Dependencies Installation"
    
    cd "$APP_DIR"
    
    # Create virtual environment
    if [[ ! -d "venv" ]]; then
        print_status "Creating Python virtual environment..."
        sudo -u "$APP_USER" python3 -m venv venv
    fi
    
    # Activate virtual environment and install dependencies
    print_status "Installing Python packages..."
    sudo -u "$APP_USER" bash -c "
        source venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        pip install streamlit plotly gunicorn
    "
    
    print_status "Python dependencies installed successfully"
}

# Function to download MovieLens data
download_data() {
    print_step "MovieLens Dataset Download"
    
    cd "$APP_DIR"
    
    # Create data directories
    sudo -u "$APP_USER" mkdir -p data/raw data/processed
    
    if [[ ! -f "data/raw/movies.csv" ]] || [[ ! -f "data/raw/ratings.csv" ]]; then
        print_status "Downloading MovieLens dataset..."
        
        sudo -u "$APP_USER" bash -c "
            cd data/raw
            wget -q https://files.grouplens.org/datasets/movielens/ml-latest-small.zip
            unzip -q ml-latest-small.zip
            mv ml-latest-small/* .
            rmdir ml-latest-small
            rm ml-latest-small.zip
        "
        
        print_status "MovieLens dataset downloaded successfully"
    else
        print_status "MovieLens dataset already exists"
    fi
}

# Function to train models
train_models() {
    print_step "Model Training"
    
    cd "$APP_DIR"
    
    if [[ ! -f "models/saved_models/content_based_model.cbm" ]]; then
        print_status "Training machine learning models..."
        print_warning "This may take several minutes..."
        
        sudo -u "$APP_USER" bash -c "
            source venv/bin/activate
            python main.py
        "
        
        print_status "Models trained successfully"
    else
        print_status "Trained models already exist"
    fi
}

# Function to create PM2 ecosystem file
create_pm2_config() {
    print_step "PM2 Configuration"
    
    cat > "$APP_DIR/ecosystem.config.js" << EOF
module.exports = {
  apps: [{
    name: '$APP_NAME',
    script: 'venv/bin/streamlit',
    args: 'run streamlit_app.py --server.port 8501 --server.address 127.0.0.1',
    cwd: '$APP_DIR',
    user: '$APP_USER',
    env: {
      NODE_ENV: 'production',
      PYTHONPATH: '$APP_DIR/src'
    },
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '2G',
    error_file: '$APP_DIR/logs/err.log',
    out_file: '$APP_DIR/logs/out.log',
    log_file: '$APP_DIR/logs/combined.log',
    time: true
  }]
};
EOF
    
    # Create logs directory
    sudo -u "$APP_USER" mkdir -p "$APP_DIR/logs"
    
    # Set ownership
    chown "$APP_USER:$APP_USER" "$APP_DIR/ecosystem.config.js"
    
    print_status "PM2 configuration created"
}

# Function to configure Nginx
configure_nginx() {
    print_step "Nginx Configuration"
    
    # Create Nginx configuration
    cat > "/etc/nginx/sites-available/$APP_NAME" << EOF
upstream movie_app {
    server 127.0.0.1:8501;
}

server {
    listen 80;
    server_name ${DOMAIN:-_};
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Main application
    location / {
        proxy_pass http://movie_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
    
    # Static files (if any)
    location /static/ {
        alias $APP_DIR/static/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    # Logs
    access_log /var/log/nginx/$APP_NAME.access.log;
    error_log /var/log/nginx/$APP_NAME.error.log;
}
EOF
    
    # Enable the site
    ln -sf "/etc/nginx/sites-available/$APP_NAME" "/etc/nginx/sites-enabled/"
    
    # Remove default site if it exists
    rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    nginx -t
    
    print_status "Nginx configuration created and tested"
}

# Function to configure firewall
configure_firewall() {
    print_step "Firewall Configuration"
    
    print_status "Configuring UFW firewall..."
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (important!)
    ufw allow ssh
    
    # Allow HTTP and HTTPS
    ufw allow 80
    ufw allow 443
    
    # Allow Streamlit port for direct access (optional)
    ufw allow 8501
    
    # Enable UFW
    ufw --force enable
    
    print_status "Firewall configured successfully"
    ufw status
}

# Function to setup SSL with Let's Encrypt
setup_ssl() {
    if [[ "$SSL_ENABLED" = true ]] && [[ -n "$DOMAIN" ]]; then
        print_step "SSL Certificate Setup"
        
        print_status "Installing Certbot..."
        apt install -y certbot python3-certbot-nginx
        
        print_status "Obtaining SSL certificate for $DOMAIN..."
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "admin@$DOMAIN"
        
        # Setup auto-renewal
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
        
        print_status "SSL certificate installed and auto-renewal configured"
    else
        print_status "SSL setup skipped"
    fi
}

# Function to start services
start_services() {
    print_step "Starting Services"
    
    cd "$APP_DIR"
    
    # Start PM2 as app user
    sudo -u "$APP_USER" bash -c "
        cd $APP_DIR
        pm2 delete $APP_NAME 2>/dev/null || true
        pm2 start ecosystem.config.js
        pm2 save
    "
    
    # Setup PM2 startup script
    env_path=$(sudo -u "$APP_USER" pm2 startup | grep "sudo env" | cut -d'"' -f2)
    if [[ -n "$env_path" ]]; then
        eval "$env_path"
    fi
    
    # Restart Nginx
    systemctl restart nginx
    systemctl enable nginx
    
    print_status "All services started successfully"
}

# Function to create management scripts
create_management_scripts() {
    print_step "Creating Management Scripts"
    
    # Create start script
    cat > "$APP_DIR/scripts/start.sh" << 'EOF'
#!/bin/bash
cd /opt/movie-recommendation-system
sudo -u movie-app pm2 start ecosystem.config.js
sudo systemctl start nginx
echo "✅ Services started"
EOF
    
    # Create stop script
    cat > "$APP_DIR/scripts/stop.sh" << 'EOF'
#!/bin/bash
sudo -u movie-app pm2 stop movie-recommender
sudo systemctl stop nginx
echo "🛑 Services stopped"
EOF
    
    # Create restart script
    cat > "$APP_DIR/scripts/restart.sh" << 'EOF'
#!/bin/bash
cd /opt/movie-recommendation-system
sudo -u movie-app pm2 restart movie-recommender
sudo systemctl reload nginx
echo "🔄 Services restarted"
EOF
    
    # Create status script
    cat > "$APP_DIR/scripts/status.sh" << 'EOF'
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
echo ""
echo "Disk Usage:"
df -h /opt/movie-recommendation-system
EOF
    
    # Create backup script
    cat > "$APP_DIR/scripts/backup.sh" << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/backups/movie-recommender"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "📦 Creating backup..."
tar -czf "$BACKUP_DIR/models_$DATE.tar.gz" -C /opt/movie-recommendation-system models/
tar -czf "$BACKUP_DIR/data_$DATE.tar.gz" -C /opt/movie-recommendation-system data/

echo "✅ Backup created: $BACKUP_DIR"
ls -la "$BACKUP_DIR"
EOF
    
    # Make scripts executable
    chmod +x "$APP_DIR/scripts"/*.sh
    chown -R "$APP_USER:$APP_USER" "$APP_DIR/scripts"
    
    print_status "Management scripts created in $APP_DIR/scripts/"
}

# Function to perform health check
health_check() {
    print_step "Health Check"
    
    # Wait for services to start
    sleep 10
    
    # Check if PM2 process is running
    if sudo -u "$APP_USER" pm2 list | grep -q "$APP_NAME"; then
        print_status "✅ PM2 process is running"
    else
        print_error "❌ PM2 process is not running"
        return 1
    fi
    
    # Check if Nginx is running
    if systemctl is-active --quiet nginx; then
        print_status "✅ Nginx is running"
    else
        print_error "❌ Nginx is not running"
        return 1
    fi
    
    # Check if application responds
    if curl -f http://localhost:8501 >/dev/null 2>&1; then
        print_status "✅ Application is responding on port 8501"
    else
        print_warning "⚠️ Application may not be fully ready yet"
    fi
    
    # Check if Nginx proxy works
    if curl -f http://localhost/ >/dev/null 2>&1; then
        print_status "✅ Nginx proxy is working"
    else
        print_warning "⚠️ Nginx proxy may have issues"
    fi
    
    print_status "Health check completed"
}

# Function to display final information
display_final_info() {
    print_step "Deployment Complete! 🎉"
    
    echo ""
    echo -e "${GREEN}🎬 Movie Recommendation System is now live!${NC}"
    echo ""
    echo "📍 Access Information:"
    echo "  Local:     http://localhost:8501"
    echo "  Nginx:     http://localhost/"
    if [[ -n "$DOMAIN" ]]; then
        if [[ "$SSL_ENABLED" = true ]]; then
            echo "  Public:    https://$DOMAIN"
        else
            echo "  Public:    http://$DOMAIN"
        fi
    fi
    echo ""
    echo "🛠️ Management Commands:"
    echo "  Start:     $APP_DIR/scripts/start.sh"
    echo "  Stop:      $APP_DIR/scripts/stop.sh"
    echo "  Restart:   $APP_DIR/scripts/restart.sh"
    echo "  Status:    $APP_DIR/scripts/status.sh"
    echo "  Backup:    $APP_DIR/scripts/backup.sh"
    echo ""
    echo "📊 Monitoring:"
    echo "  PM2:       sudo -u $APP_USER pm2 monit"
    echo "  Logs:      sudo -u $APP_USER pm2 logs $APP_NAME"
    echo "  Nginx:     sudo tail -f /var/log/nginx/$APP_NAME.access.log"
    echo ""
    echo "🔧 Configuration Files:"
    echo "  PM2:       $APP_DIR/ecosystem.config.js"
    echo "  Nginx:     /etc/nginx/sites-available/$APP_NAME"
    echo "  Logs:      $APP_DIR/logs/"
    echo ""
    echo "📅 Deployment completed at: $(date)"
    echo "📋 Full log available at: $LOG_FILE"
}

# Main deployment function
main() {
    print_status "Starting Movie Recommendation System deployment..."
    
    # Pre-flight checks
    check_root
    
    # Get user configuration
    get_user_input
    
    # Installation steps
    update_system
    install_python
    install_nodejs
    install_nginx
    create_app_user
    setup_app_directory
    install_python_deps
    download_data
    train_models
    create_pm2_config
    configure_nginx
    configure_firewall
    setup_ssl
    start_services
    create_management_scripts
    
    # Final checks
    health_check
    display_final_info
}

# Error handling
trap 'print_error "Deployment failed at line $LINENO. Check the log file: $LOG_FILE"' ERR

# Run main function
main "$@"