#!/bin/bash

# 🔄 Restart Services Script with External Access
# File: scripts/restart.sh
# Restart Movie Recommendation System services with external access information

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
APP_DIR="/opt/movie-recommendation-system"
APP_USER="movie-app"

echo "🔄 Restarting Movie Recommendation System with External Access..."

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

# Save PM2 configuration
sudo -u "$APP_USER" pm2 save

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
sleep 8

# Check services
pm2_status=$(sudo -u "$APP_USER" pm2 list | grep movie-recommender | awk '{print $10}' 2>/dev/null || echo "unknown")
nginx_status=$(systemctl is-active nginx 2>/dev/null || echo "inactive")

echo ""
echo "📊 Service Status After Restart:"
echo "  PM2 App: $pm2_status"
echo "  Nginx: $nginx_status"
echo ""

# Check if external access is configured
if netstat -tlnp 2>/dev/null | grep ":8501 " | grep -q "0.0.0.0:8501"; then
    print_status "✅ Streamlit configured for external access"
else
    print_warning "⚠️ Streamlit may not be configured for external access"
    echo "   Run: sudo $APP_DIR/scripts/configure_external_access.sh"
fi

# Test application
if curl -sf http://localhost/health >/dev/null 2>&1; then
    print_status "✅ Application is responding"
else
    print_status "⚠️ Application may still be starting up..."
fi

print_step "Access Information"

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "🌐 Access your Movie Recommendation System:"
echo ""
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

# Show firewall status
echo "🔥 Firewall Status:"
if command -v ufw >/dev/null 2>&1; then
    ufw_status=$(ufw status | head -1 | cut -d: -f2 | xargs)
    echo "  Status: $ufw_status"
    
    if ufw status | grep -q "80\|8501"; then
        print_status "✅ External ports are open in firewall"
    else
        print_warning "⚠️ External ports may not be open in firewall"
    fi
else
    print_warning "UFW firewall not available"
fi

echo ""
echo "✅ Services restarted successfully!"
echo ""
echo "🔧 If you can't access externally:"
echo "  1. Check your cloud provider's security groups/firewall"
echo "  2. Run: sudo $APP_DIR/scripts/configure_external_access.sh"
echo "  3. Check status: $APP_DIR/scripts/status.sh"
echo "  4. View logs: sudo -u movie-app pm2 logs movie-recommender"
echo ""
echo "🎬 Try accessing http://$SERVER_IP/ in your browser!"