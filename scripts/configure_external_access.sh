#!/bin/bash

# 🌐 Configure External Access Script
# File: scripts/configure_external_access.sh
# Configure Movie Recommendation System for external access

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

echo "🌐 Configuring Movie Recommendation System for External Access"
echo "============================================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

APP_DIR="/opt/movie-recommendation-system"
APP_USER="movie-app"

# Check if application exists
if [[ ! -d "$APP_DIR" ]]; then
    print_error "Application directory not found: $APP_DIR"
    print_error "Please run the deployment script first"
    exit 1
fi

cd "$APP_DIR"

print_step "Current Configuration Check"

# Check current Streamlit binding
if netstat -tlnp 2>/dev/null | grep ":8501 " | grep -q "0.0.0.0:8501"; then
    print_status "✅ Streamlit is already configured for external access"
    NEEDS_STREAMLIT_CONFIG=false
else
    print_warning "⚠️ Streamlit is not configured for external access"
    NEEDS_STREAMLIT_CONFIG=true
fi

# Check firewall
if ufw status | grep -q "80\|8501"; then
    print_status "✅ Firewall rules exist for external ports"
    NEEDS_FIREWALL_CONFIG=false
else
    print_warning "⚠️ Firewall needs configuration for external access"
    NEEDS_FIREWALL_CONFIG=true
fi

print_step "Update Streamlit Configuration"

if [[ "$NEEDS_STREAMLIT_CONFIG" == true ]]; then
    print_status "Updating PM2 configuration for external access..."
    
    # Backup current configuration
    cp ecosystem.config.js ecosystem.config.js.backup.$(date +%Y%m%d_%H%M%S)
    
    # Create new ecosystem configuration with external access
    cat > ecosystem.config.js << 'ECOSYS_EOF'
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
ECOSYS_EOF

    chown movie-app:movie-app ecosystem.config.js
    print_status "✅ PM2 configuration updated for external access"
else
    print_status "Streamlit configuration is already correct"
fi

print_step "Configure Firewall for External Access"

if [[ "$NEEDS_FIREWALL_CONFIG" == true ]]; then
    print_status "Opening firewall ports for external access..."
    
    # Open ports for external access
    ufw allow from any to any port 80 comment 'HTTP for Movie Recommender'
    ufw allow from any to any port 8501 comment 'Streamlit for Movie Recommender'
    ufw allow from any to any port 443 comment 'HTTPS for Movie Recommender'
    
    # Reload firewall
    ufw reload
    
    print_status "✅ Firewall configured for external access"
else
    print_status "Firewall is already configured correctly"
fi

print_step "Verify Nginx Configuration"

# Check Nginx configuration for external access
print_status "Verifying Nginx configuration..."

if nginx -t >/dev/null 2>&1; then
    print_status "✅ Nginx configuration is valid"
else
    print_error "❌ Nginx configuration has errors"
    nginx -t
    exit 1
fi

# Ensure Nginx is configured to accept external connections
if grep -q "server_name _;" /etc/nginx/sites-available/movie-recommender; then
    print_status "✅ Nginx is configured to accept any domain/IP"
else
    print_warning "⚠️ Nginx may need domain configuration update"
fi

print_step "Restart Services with External Access"

print_status "Restarting services with external access configuration..."

# Stop services first
sudo -u movie-app pm2 stop movie-recommender 2>/dev/null || true
sleep 3

# Start with new configuration
sudo -u movie-app pm2 start ecosystem.config.js
sudo -u movie-app pm2 save

# Restart Nginx
systemctl reload nginx
systemctl enable nginx

print_step "Verify External Access Configuration"

print_status "Waiting for services to start with new configuration..."
sleep 15

# Check if Streamlit is now bound to external interface
if netstat -tlnp 2>/dev/null | grep ":8501 " | grep -q "0.0.0.0:8501"; then
    print_status "✅ Streamlit is now listening on external interface"
else
    print_error "❌ Streamlit is still not configured for external access"
    print_error "Check PM2 logs: sudo -u movie-app pm2 logs movie-recommender"
fi

# Check services status
pm2_status=$(sudo -u movie-app pm2 list | grep movie-recommender | awk '{print $10}' 2>/dev/null || echo "unknown")
nginx_status=$(systemctl is-active nginx 2>/dev/null || echo "inactive")

print_status "Service Status:"
print_status "  PM2 Application: $pm2_status"
print_status "  Nginx: $nginx_status"

# Test local endpoints
print_status "Testing local endpoints..."

if curl -sf http://localhost:8501/_stcore/health >/dev/null 2>&1; then
    print_status "✅ Streamlit health check passed"
elif curl -sf http://localhost:8501 >/dev/null 2>&1; then
    print_status "✅ Streamlit is accessible"
else
    print_warning "⚠️ Streamlit may still be starting"
fi

if curl -sf http://localhost/health >/dev/null 2>&1; then
    print_status "✅ Nginx proxy health check passed"
else
    print_warning "⚠️ Nginx proxy may have issues"
fi

print_step "External Access Information"

# Get server IP
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "🎉 External Access Configuration Complete!"
echo ""
echo "🌐 Your Movie Recommendation System URLs:"
echo ""
echo "  🌍 External Access (from anywhere):"
if [[ -n "$SERVER_IP" ]]; then
    echo "    Main Application: http://$SERVER_IP/"
    echo "    Direct Streamlit: http://$SERVER_IP:8501"
    echo "    Health Check:     http://$SERVER_IP/health"
else
    print_warning "Could not determine external IP address"
fi
echo ""
echo "  🏠 Local Access:"
echo "    Main Application: http://localhost/"
echo "    Direct Streamlit: http://localhost:8501"
echo "    Health Check:     http://localhost/health"
echo ""

print_step "Firewall Status"

echo "🔥 Current Firewall Configuration:"
ufw status | grep -E "(Status|80|8501|443|22)" || echo "No relevant rules found"
echo ""

print_step "Network Status"

echo "🌐 Network Port Status:"
if netstat -tlnp 2>/dev/null | grep -E ":80 |:8501 |:443 "; then
    echo "Listening ports:"
    netstat -tlnp 2>/dev/null | grep -E ":80 |:8501 |:443 " | while read line; do
        echo "  $line"
    done
else
    print_warning "No relevant ports found listening"
fi

print_step "Final Instructions"

echo ""
echo "✅ External Access Configuration Complete!"
echo ""
echo "🎯 Next Steps:"
echo "  1. Open your web browser"
echo "  2. Navigate to: http://$SERVER_IP/"
echo "  3. You should see the Movie Recommendation System interface"
echo ""
echo "🔧 If you still can't access externally:"
echo "  1. Check your cloud provider's security groups/firewall:"
echo "     • AWS: EC2 → Security Groups → Add rules for ports 80, 8501"
echo "     • DigitalOcean: Networking → Firewalls → Add HTTP rules"
echo "     • Google Cloud: VPC Network → Firewall → Create rules"
echo "  2. Verify your server's public IP: curl ifconfig.me"
echo "  3. Test from another network: curl -I http://$SERVER_IP/"
echo "  4. Check application logs: sudo -u movie-app pm2 logs movie-recommender"
echo ""
echo "📊 Monitoring Commands:"
echo "  Status: $APP_DIR/scripts/status.sh"
echo "  Logs:   sudo -u movie-app pm2 logs movie-recommender"
echo "  Restart: $APP_DIR/scripts/restart.sh"
echo ""
echo "🎬 Your Movie Recommendation System is now configured for external access!"
echo "🌐 Try accessing: http://$SERVER_IP/"