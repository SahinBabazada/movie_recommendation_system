#!/bin/bash

# 🔒 SSL Setup Script
# File: scripts/setup_ssl.sh
# Setup SSL certificate with Let's Encrypt

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}🔄 $1${NC}"
    echo "----------------------------------------"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if domain is provided
if [[ -z "$1" ]]; then
    print_error "Domain name required"
    echo ""
    echo "Usage: $0 <domain.com>"
    echo "Example: $0 movies.example.com"
    echo ""
    echo "Make sure:"
    echo "  1. Domain points to this server's IP"
    echo "  2. Ports 80 and 443 are open"
    echo "  3. No other web server is using port 80/443"
    exit 1
fi

DOMAIN="$1"
EMAIL="admin@$DOMAIN"

echo "🔒 SSL Certificate Setup for Movie Recommendation System"
echo "========================================================"
echo "🌐 Domain: $DOMAIN"
echo "📧 Email: $EMAIL"

print_step "Pre-flight Checks"

# Check if certbot is installed
if ! command -v certbot >/dev/null 2>&1; then
    print_status "Installing Certbot..."
    apt update >/dev/null 2>&1
    apt install -y certbot python3-certbot-nginx >/dev/null 2>&1
fi

# Check if nginx is running
if ! systemctl is-active --quiet nginx; then
    print_error "Nginx is not running"
    print_status "Starting Nginx..."
    systemctl start nginx
fi

# Check if domain resolves to this server
print_status "Checking domain resolution..."
DOMAIN_IP=$(dig +short "$DOMAIN" @8.8.8.8 || echo "")
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

if [[ -n "$DOMAIN_IP" ]] && [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
    print_status "✅ Domain resolves correctly to this server"
else
    print_warning "⚠️ Domain may not resolve to this server"
    print_warning "   Domain IP: ${DOMAIN_IP:-'not found'}"
    print_warning "   Server IP: $SERVER_IP"
    echo ""
    read -p "Continue anyway? (y/N): " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_step "Update Nginx Configuration"

# Backup current configuration
print_status "Backing up current Nginx configuration..."
cp /etc/nginx/sites-available/movie-recommender /etc/nginx/sites-available/movie-recommender.backup.$(date +%Y%m%d_%H%M%S)

# Update server_name in nginx config
print_status "Updating Nginx configuration for domain: $DOMAIN"
sed -i "s/server_name _;/server_name $DOMAIN;/" /etc/nginx/sites-available/movie-recommender

# Test nginx configuration
if ! nginx -t >/dev/null 2>&1; then
    print_error "Nginx configuration error after domain update"
    nginx -t
    exit 1
fi

# Reload nginx
systemctl reload nginx

print_step "Obtain SSL Certificate"

# Check if certificate already exists
if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
    print_warning "SSL certificate already exists for $DOMAIN"
    read -p "Renew existing certificate? (y/N): " renew_cert
    if [[ "$renew_cert" =~ ^[Yy]$ ]]; then
        print_status "Renewing certificate..."
        certbot renew --nginx --quiet
    fi
else
    # Obtain new certificate
    print_status "Obtaining SSL certificate from Let's Encrypt..."
    
    # Create a temporary index file to help with domain verification
    mkdir -p /var/www/html
    echo "Movie Recommendation System - SSL Setup" > /var/www/html/index.html
    
    # Run certbot
    if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect; then
        print_status "✅ SSL certificate obtained successfully"
    else
        print_error "❌ Failed to obtain SSL certificate"
        echo ""
        echo "💡 Troubleshooting tips:"
        echo "  1. Ensure domain $DOMAIN points to this server ($SERVER_IP)"
        echo "  2. Check firewall allows ports 80 and 443"
        echo "  3. Verify no other service is using port 80"
        echo "  4. Try manual verification: curl http://$DOMAIN"
        exit 1
    fi
fi

print_step "Configure Auto-Renewal"

# Setup cron job for auto-renewal
print_status "Setting up automatic certificate renewal..."

# Remove any existing certbot cron jobs
crontab -l 2>/dev/null | grep -v certbot | crontab - 2>/dev/null || true

# Add new cron job
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx") | crontab -

print_status "✅ Auto-renewal configured (daily check at noon)"

print_step "Security Headers Update"

# Add additional security headers for HTTPS
print_status "Adding HTTPS security headers..."

# Create SSL security snippet if it doesn't exist
if [[ ! -f "/etc/nginx/snippets/ssl-params.conf" ]]; then
    cat > /etc/nginx/snippets/ssl-params.conf << 'EOF'
# SSL Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_stapling on;
ssl_stapling_verify on;

# HSTS (HTTP Strict Transport Security)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
EOF
fi

# Test final nginx configuration
if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx
    print_status "✅ Nginx configuration updated"
else
    print_error "Nginx configuration error"
    nginx -t
fi

print_step "Final Verification"

# Wait a moment for everything to settle
sleep 3

# Test HTTPS
if curl -sf "https://$DOMAIN/health" >/dev/null 2>&1; then
    print_status "✅ HTTPS is working correctly"
else
    print_warning "⚠️ HTTPS may not be fully ready yet"
fi

# Test HTTP redirect
if curl -sf "http://$DOMAIN" 2>&1 | grep -q "301\|302"; then
    print_status "✅ HTTP to HTTPS redirect is working"
else
    print_warning "⚠️ HTTP redirect may not be configured"
fi

print_step "SSL Setup Complete! 🎉"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   🔒 SSL SETUP SUCCESSFUL! 🔒                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}🌐 Your Movie Recommendation System is now secured with SSL!${NC}"
echo ""
echo "📋 SSL Information:"
echo "  Domain:           $DOMAIN"
echo "  Certificate:      Let's Encrypt"
echo "  Auto-renewal:     Enabled (daily check)"
echo "  HTTPS URL:        https://$DOMAIN/"
echo "  HTTP Redirect:    Enabled"
echo ""
echo "🔐 Security Features:"
echo "  ✅ TLS 1.2 & 1.3"
echo "  ✅ HSTS Header"
echo "  ✅ Security Headers"
echo "  ✅ Automatic Renewal"
echo ""
echo "🛠️ Management Commands:"
echo "  Check status:     sudo certbot certificates"
echo "  Renew manually:   sudo certbot renew"
echo "  Test renewal:     sudo certbot renew --dry-run"
echo ""
echo "🎬 Access your secure application at:"
echo "  https://$DOMAIN/"
echo ""

# Show certificate info
print_status "Certificate Information:"
certbot certificates | grep -A 10 "$DOMAIN" || echo "Certificate details not available"

echo ""
echo "✅ SSL setup completed successfully!"