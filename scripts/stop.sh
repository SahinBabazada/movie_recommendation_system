#!/bin/bash

# 🛑 Stop Services Script
# File: scripts/stop.sh
# Stop Movie Recommendation System services

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
    echo "----------------------------------------"
}

# Configuration
APP_USER="movie-app"

echo "🛑 Stopping Movie Recommendation System..."

print_step "Stopping PM2 Application"

# Stop PM2 application
if sudo -u "$APP_USER" pm2 list | grep -q "movie-recommender"; then
    print_status "Stopping PM2 application..."
    sudo -u "$APP_USER" pm2 stop movie-recommender
    print_status "✅ PM2 application stopped"
else
    print_warning "PM2 application is not running"
fi

print_step "Stopping Nginx"

# Stop Nginx
if systemctl is-active --quiet nginx; then
    print_status "Stopping Nginx..."
    systemctl stop nginx
    print_status "✅ Nginx stopped"
else
    print_warning "Nginx is not running"
fi

print_step "Final Status Check"

# Check if services are stopped
pm2_status=$(sudo -u "$APP_USER" pm2 list | grep movie-recommender | awk '{print $10}' 2>/dev/null || echo "stopped")
nginx_status=$(systemctl is-active nginx 2>/dev/null || echo "inactive")

echo ""
echo "📊 Service Status:"
echo "  PM2 App: $pm2_status"
echo "  Nginx: $nginx_status"
echo ""

if [[ "$pm2_status" == "stopped" ]] && [[ "$nginx_status" == "inactive" ]]; then
    echo "✅ All services stopped successfully!"
else
    echo "⚠️ Some services may still be running"
    echo ""
    echo "🔧 To force stop everything:"
    echo "  sudo pkill -f streamlit"
    echo "  sudo systemctl stop nginx"
    echo "  sudo -u $APP_USER pm2 kill"
fi

echo ""
echo "🚀 To start again: ./scripts/start.sh"