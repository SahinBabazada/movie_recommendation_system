#!/bin/bash

# 🚀 Start Services Script with External Access
# File: scripts/start.sh
# Start Movie Recommendation System services with external access information

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
    echo "----------------------------------------"
}

# Configuration
APP_DIR="/opt/movie-recommendation-system"
APP_USER="movie-app"

echo "🚀 Starting Movie Recommendation System with External Access..."

# Check if application directory exists
if [[ ! -d "$APP_DIR" ]]; then
    print_error "Application directory not found: $APP_DIR"
    print_error "Please run the deployment script first"
    exit 1
fi

# Check if user exists
if ! id "$APP_USER" &>/dev/null; then
    print_error "User $APP_USER does not exist"
    print_error "Please run the deployment script first"
    exit 1
fi

print_step "Starting PM2 Application"

cd "$APP_DIR"

# Check if ecosystem file exists
if [[ ! -f "ecosystem.config.js" ]]; then
    print_error "PM2 ecosystem file not found"
    exit 1
fi

# Start PM2 application
if sudo -u "$APP_USER" pm2 list | grep -q "movie-recommender"; then
    print_status "Restarting existing PM2 application..."
    sudo -u "$APP_USER" pm2 restart movie-recommender
else
    print_status "Starting new PM2 application..."
    sudo -u "$APP_USER" pm2 start ecosystem.config.js
fi

# Save PM2 configuration
sudo -u "$APP_USER" pm2 save

print_step "Starting Nginx"

# Start Nginx
if systemctl is-active --quiet nginx; then
    print_status "Nginx is already running, reloading configuration..."
    systemctl reload nginx
else
    print_status "Starting Nginx..."
    systemctl start nginx
fi

systemctl enable nginx

print_step "Health Check"

# Wait for services to start
sleep 8

# Check PM2 status
if sudo -u "$APP_USER" pm2 list | grep -q "movie-recommender.*online"; then
    print_status "✅ PM2 application is running"
else
    print_error "❌ PM2 application failed to start"
    sudo -u "$APP_USER" pm2 logs movie-recommender --lines 10
    exit 1
fi

# Check Nginx status
if systemctl is-active --quiet nginx; then
    print_status "✅ Nginx is running"
else
    print_error "❌ Nginx failed to start"
    systemctl status nginx --no-pager
    exit 1
fi

# Check application health
if curl -sf http://localhost:8501/_stcore/health >/dev/null 2>&1; then
    print_status "✅ Streamlit application is responding"
elif curl -sf http://localhost:8501 >/dev/null 2>&1; then
    print_status "✅ Streamlit application is accessible"
else
    print_status "⚠️ Streamlit application may still be starting up..."
fi

# Check proxy health
if curl -sf http://localhost/health >/dev/null 2>&1; then
    print_status "✅ Nginx proxy is working"
else
    print_status "⚠️ Nginx proxy may have issues"
fi

print_step "Service Information"

# Get server IP
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "🎬 Movie Recommendation System Started!"
echo ""
echo "📊 Service Status:"
sudo -u "$APP_USER" pm2 list | head -4
echo ""
echo "🌐 Access URLs:"
echo "  🌍 External Access:"
if [[ -n "$SERVER_IP" ]]; then
    echo "    Main App:     http://$SERVER_IP/"
    echo "    Direct App:   http://$SERVER_IP:8501"
    echo "    Health Check: http://$SERVER_IP/health"
else
    echo "    Could not determine external IP"
fi
echo ""
echo "  🏠 Local Access:"
echo "    Main App:     http://localhost/"
echo "    Direct App:   http://localhost:8501"
echo "    Health Check: http://localhost/health"
echo ""
echo "🛠️ Management Commands:"
echo "  Stop:        $APP_DIR/scripts/stop.sh"
echo "  Restart:     $APP_DIR/scripts/restart.sh"
echo "  Status:      $APP_DIR/scripts/status.sh"
echo "  Logs:        sudo -u $APP_USER pm2 logs movie-recommender"
echo ""
echo "🔧 If you can't access externally, check:"
echo "  1. Your cloud provider's firewall/security groups"
echo "  2. Run: sudo ufw status"
echo "  3. Test local access: curl http://localhost/health"
echo "  4. Check if ports 80 and 8501 are open in your VPS settings"
echo ""

echo "✅ All services started successfully!"
echo "🌐 Try accessing http://$SERVER_IP/ in your browser!"