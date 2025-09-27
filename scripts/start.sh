#!/bin/bash

# 🚀 Start Services Script
# File: scripts/start.sh
# Start Movie Recommendation System services

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

echo "🚀 Starting Movie Recommendation System..."

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
sleep 5

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
    print_status "✅ Application is responding"
else
    print_status "⚠️ Application may still be starting up..."
fi

# Check proxy health
if curl -sf http://localhost/health >/dev/null 2>&1; then
    print_status "✅ Nginx proxy is working"
else
    print_status "⚠️ Nginx proxy may have issues"
fi

print_step "Service Information"

echo ""
echo "🎬 Movie Recommendation System Started!"
echo ""
echo "📊 Service Status:"
sudo -u "$APP_USER" pm2 list
echo ""
echo "🌐 Access URLs:"
echo "  Local:       http://localhost/"
echo "  Direct:      http://localhost:8501"
echo "  Health:      http://localhost/health"
echo ""
echo "🛠️ Management Commands:"
echo "  Stop:        $APP_DIR/scripts/stop.sh"
echo "  Restart:     $APP_DIR/scripts/restart.sh"
echo "  Status:      $APP_DIR/scripts/status.sh"
echo "  Logs:        sudo -u $APP_USER pm2 logs movie-recommender"
echo ""

echo "✅ All services started successfully!"