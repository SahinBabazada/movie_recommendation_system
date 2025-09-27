#!/bin/bash

# 📊 Status Check Script with External Access
# File: scripts/status.sh
# Check Movie Recommendation System status including external access

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
    echo "========================================"
}

# Configuration
APP_USER="movie-app"
APP_DIR="/opt/movie-recommendation-system"

echo "📊 Movie Recommendation System Status"
echo "======================================"

print_step "System Information"
echo "🖥️  OS: $(lsb_release -d | cut -f2)"
echo "📅 Date: $(date)"
echo "⏰ Uptime: $(uptime -p)"

# Get server IP
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo "🌐 Server IP: ${SERVER_IP:-'Unknown'}"

print_step "Service Status"

# PM2 Status
echo "🔥 PM2 Processes:"
if command -v pm2 >/dev/null 2>&1; then
    if sudo -u "$APP_USER" pm2 list 2>/dev/null | grep -q movie-recommender; then
        sudo -u "$APP_USER" pm2 list
    else
        print_warning "No PM2 processes found"
    fi
else
    print_error "PM2 not installed"
fi

echo ""
echo "🌐 Nginx Status:"
if systemctl is-active --quiet nginx; then
    print_status "✅ Nginx is running"
    echo "   Version: $(nginx -v 2>&1 | cut -d' ' -f3)"
    echo "   PID: $(pidof nginx | awk '{print $1}' 2>/dev/null || echo 'N/A')"
else
    print_error "❌ Nginx is not running"
fi

echo ""
echo "🔥 Firewall Status:"
if command -v ufw >/dev/null 2>&1; then
    echo "Overall Status: $(ufw status | head -1 | cut -d: -f2 | xargs)"
    echo ""
    echo "Relevant Rules:"
    ufw status | grep -E "(80|8501|443|22)" || echo "No relevant rules found"
else
    print_warning "UFW not installed"
fi

print_step "Application Health"

echo "🧪 Local Health Checks:"

# Direct Streamlit check
if curl -sf http://localhost:8501/_stcore/health >/dev/null 2>&1; then
    print_status "✅ Streamlit app (port 8501) - responding"
elif curl -sf http://localhost:8501 >/dev/null 2>&1; then
    print_status "✅ Streamlit app (port 8501) - accessible"
else
    print_error "❌ Streamlit app (port 8501) - not responding"
fi

# Nginx proxy check
if curl -sf http://localhost/health >/dev/null 2>&1; then
    print_status "✅ Nginx proxy (port 80) - working"
else
    print_error "❌ Nginx proxy (port 80) - not working"
fi

# Check if main app loads
if curl -sf http://localhost/ >/dev/null 2>&1; then
    print_status "✅ Main application - accessible"
else
    print_error "❌ Main application - not accessible"
fi

print_step "External Access Information"

echo "🌐 External Access URLs:"
if [[ -n "$SERVER_IP" ]]; then
    echo "  Main App:     http://$SERVER_IP/"
    echo "  Direct App:   http://$SERVER_IP:8501"
    echo "  Health Check: http://$SERVER_IP/health"
else
    print_error "Could not determine external IP address"
fi

echo ""
echo "🧪 External Access Test:"
echo "  Testing local endpoints for external readiness..."

# Test if services are bound to external interfaces
if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
    print_status "✅ Port 80 (HTTP) - listening"
else
    print_error "❌ Port 80 (HTTP) - not listening"
fi

if netstat -tlnp 2>/dev/null | grep -q ":8501 "; then
    port_8501_binding=$(netstat -tlnp 2>/dev/null | grep ":8501 " | awk '{print $4}')
    if echo "$port_8501_binding" | grep -q "0.0.0.0:8501"; then
        print_status "✅ Port 8501 (Streamlit) - listening externally"
    elif echo "$port_8501_binding" | grep -q "127.0.0.1:8501"; then
        print_warning "⚠️ Port 8501 (Streamlit) - listening locally only"
        echo "      Run configure_external_access.sh to fix this"
    else
        print_status "✅ Port 8501 (Streamlit) - listening"
    fi
else
    print_error "❌ Port 8501 (Streamlit) - not listening"
fi

if netstat -tlnp 2>/dev/null | grep -q ":443 "; then
    print_status "✅ Port 443 (HTTPS) - listening"
else
    print_warning "⚠️ Port 443 (HTTPS) - not listening (SSL not configured)"
fi

print_step "Resource Usage"

echo "💾 Disk Usage:"
if [[ -d "$APP_DIR" ]]; then
    du -sh "$APP_DIR" 2>/dev/null | awk '{print "   App Directory: " $1}'
fi
df -h / | tail -1 | awk '{print "   Root Partition: " $3 " used / " $2 " total (" $5 " used)"}'

echo ""
echo "🧠 Memory Usage:"
free -h | grep Mem | awk '{print "   Memory: " $3 " used / " $2 " total"}'

echo ""
echo "🔥 CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print "   CPU: " $2 " user, " $4 " system, " $8 " idle"}'

# PM2 Memory usage
if command -v pm2 >/dev/null 2>&1; then
    if sudo -u "$APP_USER" pm2 list 2>/dev/null | grep -q movie-recommender; then
        echo ""
        echo "🎬 Application Memory:"
        sudo -u "$APP_USER" pm2 list | grep movie-recommender | awk '{print "   PM2 App: " $9 " memory, " $10 " cpu"}'
    fi
fi

print_step "Recent Logs"

echo "📋 Recent PM2 Logs (last 5 lines):"
if sudo -u "$APP_USER" pm2 logs movie-recommender --lines 5 2>/dev/null; then
    echo ""
else
    print_warning "No PM2 logs available"
fi

echo "📋 Recent Nginx Access Logs (last 3 lines):"
if [[ -f "/var/log/nginx/movie-recommender.access.log" ]]; then
    sudo tail -3 /var/log/nginx/movie-recommender.access.log 2>/dev/null || echo "   No recent access logs"
else
    print_warning "Nginx access log not found"
fi

echo ""
echo "📋 Recent Nginx Error Logs (last 3 lines):"
if [[ -f "/var/log/nginx/movie-recommender.error.log" ]]; then
    sudo tail -3 /var/log/nginx/movie-recommender.error.log 2>/dev/null || echo "   No recent error logs"
else
    print_warning "Nginx error log not found"
fi

print_step "Quick Actions"

echo "🛠️ Management Commands:"
echo "   Start:    $APP_DIR/scripts/start.sh"
echo "   Stop:     $APP_DIR/scripts/stop.sh"
echo "   Restart:  $APP_DIR/scripts/restart.sh"
echo "   Logs:     sudo -u $APP_USER pm2 logs movie-recommender"
echo ""
echo "🔍 Monitoring Commands:"
echo "   PM2 Monitor:     sudo -u $APP_USER pm2 monit"
echo "   System Load:     htop"
echo "   Nginx Logs:      sudo tail -f /var/log/nginx/movie-recommender.access.log"
echo "   External Access: $APP_DIR/scripts/configure_external_access.sh"
echo ""
echo "🌐 Access URLs:"
echo "   🌍 External:"
if [[ -n "$SERVER_IP" ]]; then
    echo "     Main: http://$SERVER_IP/"
    echo "     Direct: http://$SERVER_IP:8501"
fi
echo "   🏠 Local:"
echo "     Main: http://localhost/"
echo "     Health: http://localhost/health"

print_step "Summary"

# Overall health assessment
pm2_healthy=false
nginx_healthy=false
app_healthy=false
external_ready=false

if sudo -u "$APP_USER" pm2 list 2>/dev/null | grep -q "movie-recommender.*online"; then
    pm2_healthy=true
fi

if systemctl is-active --quiet nginx; then
    nginx_healthy=true
fi

if curl -sf http://localhost/health >/dev/null 2>&1; then
    app_healthy=true
fi

if netstat -tlnp 2>/dev/null | grep ":8501 " | grep -q "0.0.0.0:8501"; then
    external_ready=true
fi

echo ""
if [[ "$pm2_healthy" == true ]] && [[ "$nginx_healthy" == true ]] && [[ "$app_healthy" == true ]]; then
    if [[ "$external_ready" == true ]]; then
        print_status "🎉 Overall Status: HEALTHY - All services running, external access ready"
        echo "🌐 Try accessing: http://$SERVER_IP/"
    else
        print_warning "⚠️ Overall Status: HEALTHY - Services running, but external access needs configuration"
        echo "🔧 Run: sudo $APP_DIR/scripts/configure_external_access.sh"
    fi
elif [[ "$pm2_healthy" == true ]] && [[ "$nginx_healthy" == true ]]; then
    print_warning "⚠️ Overall Status: PARTIALLY HEALTHY - Services running but app may be starting"
else
    print_error "❌ Overall Status: UNHEALTHY - Some services not running"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   1. Check logs: sudo -u $APP_USER pm2 logs movie-recommender"
    echo "   2. Restart: $APP_DIR/scripts/restart.sh"
    echo "   3. If issues persist, redeploy: sudo $APP_DIR/scripts/quick_deploy.sh"
fi

echo ""
echo "📋 If external access doesn't work:"
echo "   1. Check your cloud provider's security groups/firewall settings"
echo "   2. Ensure ports 80 and 8501 are open in your VPS control panel"
echo "   3. Run: sudo $APP_DIR/scripts/configure_external_access.sh"
echo "   4. Test: curl -I http://$SERVER_IP/ (from another machine)"