#!/bin/bash

# 🔄 Restart Services Script
# File: scripts/restart.sh
# Restart Movie Recommendation System services

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
    echo "----------------------------------------"
}

# Configuration
APP_DIR="/opt/movie-recommendation-system"
APP_USER="movie-app"

echo "🔄 Restarting Movie Recommendation System..."

print_step "Restarting PM2 Application"

cd "$APP_DIR"

# Restart PM2 application
if sudo -u "$APP_USER" pm2 list | grep -q "movie-recommender"; then
    print_status "Restarting PM2 application..."
    sudo -u "$APP_USER" pm2 restart movie-recommender
else
    print_status "Starting PM2 application..."
    sudo -u "$APP_USER" pm2 start ecosystem.config.js
fi

print_step "Restarting Nginx"

# Reload Nginx configuration
print_status "Reloading Nginx configuration..."
systemctl reload nginx

# Ensure Nginx is running
if ! systemctl is-active --quiet nginx; then
    print_status "Starting Nginx..."
    systemctl start nginx
fi

print_step "Health Check"

# Wait for services to restart
sleep 5

# Check services
pm2_status=$(sudo -u "$APP_USER" pm2 list | grep movie-recommender | awk '{print $10}' 2>/dev/null || echo "unknown")
nginx_status=$(systemctl is-active nginx 2>/dev/null || echo "inactive")

echo ""
echo "📊 Service Status After Restart:"
echo "  PM2 App: $pm2_status"
echo "  Nginx: $nginx_status"
echo ""

# Test application
if curl -sf http://localhost/health >/dev/null 2>&1; then
    print_status "✅ Application is responding"
else
    print_status "⚠️ Application may still be starting up..."
fi

echo "✅ Services restarted successfully!"
echo ""
echo "🌐 Access your application at:"
echo "  http://localhost/"
echo "  http://localhost:8501 (direct)"