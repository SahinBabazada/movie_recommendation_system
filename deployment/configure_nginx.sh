#!/bin/bash

# 🌐 Nginx Configuration Script
# Configures Nginx reverse proxy for the Movie Recommendation System

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
APP_NAME="movie-recommender"
DOMAIN="${1:-_}"  # Use first argument as domain, or _ for any domain

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
    echo "----------------------------------------"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

print_step "Nginx Configuration Setup"

print_status "Configuring Nginx for domain: $DOMAIN"

# Backup existing configuration if it exists
if [[ -f "/etc/nginx/sites-available/$APP_NAME" ]]; then
    print_status "Backing up existing configuration..."
    cp "/etc/nginx/sites-available/$APP_NAME" "/etc/nginx/sites-available/$APP_NAME.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create Nginx configuration
print_status "Creating Nginx configuration..."
cat > "/etc/nginx/sites-available/$APP_NAME" << EOF
# Movie Recommendation System - Nginx Configuration
# Generated on $(date)

# Rate limiting
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone \$binary_remote_addr zone=login:10m rate=1r/s;

# Upstream configuration
upstream movie_app {
    server 127.0.0.1:8501 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

# HTTP Server Block
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    
    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    
    # Hide server information
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
        application/atom+xml
        image/svg+xml;
    
    # Client settings
    client_max_body_size 10M;
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;
    
    # Main application with rate limiting
    location / {
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://movie_app;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        
        # Headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Caching
        proxy_cache_bypass \$http_upgrade;
        proxy_no_cache \$http_upgrade;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
    
    # Health check endpoint (no rate limiting)
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
    
    # Status endpoint for monitoring
    location /status {
        access_log off;
        return 200 '{"status":"ok","timestamp":"'"$(date -Iseconds)"'"}';
        add_header Content-Type application/json;
    }
    
    # Static files (if any)
    location /static/ {
        alias /opt/movie-recommendation-system/static/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
        
        # Security for static files
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Block access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ \.(md|yml|yaml|json|log)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Robots.txt
    location /robots.txt {
        return 200 "User-agent: *\\nDisallow: /";
        add_header Content-Type text/plain;
    }
    
    # Favicon
    location /favicon.ico {
        log_not_found off;
        access_log off;
        return 204;
    }
    
    # Logs
    access_log /var/log/nginx/$APP_NAME.access.log combined;
    error_log /var/log/nginx/$APP_NAME.error.log warn;
}

# HTTPS Server Block (will be configured by Certbot if SSL is enabled)
# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     server_name $DOMAIN;
#     
#     # SSL configuration will be added here by Certbot
#     
#     # All the same configuration as HTTP block above...
# }
EOF

print_step "Nginx Configuration Validation"

# Test Nginx configuration
print_status "Testing Nginx configuration..."
if nginx -t; then
    print_status "✅ Nginx configuration is valid"
else
    print_error "❌ Nginx configuration has errors"
    exit 1
fi

print_step "Site Activation"

# Enable the site
print_status "Enabling site configuration..."
ln -sf "/etc/nginx/sites-available/$APP_NAME" "/etc/nginx/sites-enabled/"

# Remove default site if it exists
if [[ -f "/etc/nginx/sites-enabled/default" ]]; then
    print_status "Removing default Nginx site..."
    rm -f /etc/nginx/sites-enabled/default
fi

print_step "Security Configuration"

# Create security configuration snippet
print_status "Creating security configuration..."
cat > "/etc/nginx/snippets/security-headers.conf" << 'EOF'
# Security headers configuration
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
EOF

# Create SSL configuration snippet
print_status "Creating SSL configuration..."
cat > "/etc/nginx/snippets/ssl-params.conf" << 'EOF'
# SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_stapling on;
ssl_stapling_verify on;
EOF

print_step "Log Rotation Setup"

# Setup log rotation for application logs
print_status "Setting up log rotation..."
cat > "/etc/logrotate.d/$APP_NAME" << EOF
/var/log/nginx/$APP_NAME.*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 \$(cat /var/run/nginx.pid)
        fi
    endscript
}
EOF

print_step "Firewall Configuration"

# Configure UFW if available
if command -v ufw >/dev/null 2>&1; then
    print_status "Configuring firewall rules..."
    
    # Allow HTTP and HTTPS
    ufw allow 'Nginx Full' 2>/dev/null || {
        ufw allow 80
        ufw allow 443
    }
    
    print_status "Firewall rules updated"
fi

print_step "Service Restart"

# Reload Nginx
print_status "Reloading Nginx..."
systemctl reload nginx

# Ensure Nginx is enabled
systemctl enable nginx

print_status "✅ Nginx configuration completed successfully!"

print_step "Configuration Summary"

echo ""
echo "📋 Nginx Configuration Summary:"
echo "  Config file: /etc/nginx/sites-available/$APP_NAME"
echo "  Enabled in:  /etc/nginx/sites-enabled/$APP_NAME"
echo "  Domain:      $DOMAIN"
echo "  Upstream:    127.0.0.1:8501"
echo ""
echo "📊 Log Files:"
echo "  Access:      /var/log/nginx/$APP_NAME.access.log"
echo "  Error:       /var/log/nginx/$APP_NAME.error.log"
echo ""
echo "🔧 Useful Commands:"
echo "  Test config: sudo nginx -t"
echo "  Reload:      sudo systemctl reload nginx"
echo "  Status:      sudo systemctl status nginx"
echo "  Logs:        sudo tail -f /var/log/nginx/$APP_NAME.access.log"
echo ""

if [[ "$DOMAIN" != "_" ]]; then
    echo "🔒 For SSL setup with Let's Encrypt, run:"
    echo "  sudo certbot --nginx -d $DOMAIN"
    echo ""
fi

echo "✅ Ready to serve requests!"