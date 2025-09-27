#!/bin/bash

# 🔧 Server Setup Script
# File: scripts/setup_server.sh
# Install all dependencies for Movie Recommendation System

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

print_step "System Dependencies Installation"

# Update system
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
print_status "Installing essential packages..."
apt install -y \
    curl \
    wget \
    unzip \
    git \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    htop \
    tree \
    vim \
    build-essential

print_step "Python Installation"

# Install Python 3.9+
print_status "Installing Python and pip..."
apt install -y python3 python3-pip python3-venv python3-dev python3-setuptools

# Upgrade pip
python3 -m pip install --upgrade pip

print_status "Python $(python3 --version) installed"

print_step "Node.js and PM2 Installation"

# Install Node.js 18.x
if ! command -v node >/dev/null 2>&1; then
    print_status "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
fi

print_status "Node.js $(node --version) installed"
print_status "NPM $(npm --version) installed"

# Install PM2
if ! command -v pm2 >/dev/null 2>&1; then
    print_status "Installing PM2..."
    npm install -g pm2
fi

print_status "PM2 $(pm2 --version) installed"

print_step "Nginx Installation"

# Install Nginx
if ! command -v nginx >/dev/null 2>&1; then
    print_status "Installing Nginx..."
    apt install -y nginx
fi

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

print_status "Nginx $(nginx -v 2>&1 | cut -d' ' -f3) installed and started"

print_step "Additional Tools Installation"

# Install UFW firewall
if ! command -v ufw >/dev/null 2>&1; then
    print_status "Installing UFW firewall..."
    apt install -y ufw
fi

# Install SSL tools (for Let's Encrypt)
print_status "Installing SSL tools..."
apt install -y certbot python3-certbot-nginx

# Install monitoring tools
print_status "Installing monitoring tools..."
apt install -y htop iotop nethogs

print_step "System Configuration"

# Configure system limits
print_status "Configuring system limits..."
cat >> /etc/security/limits.conf << EOF

# Movie Recommendation System limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# Configure sysctl for better performance
print_status "Optimizing kernel parameters..."
cat >> /etc/sysctl.conf << EOF

# Movie Recommendation System optimizations
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
EOF

sysctl -p

print_step "Cleanup"

# Clean up package cache
print_status "Cleaning up..."
apt autoremove -y
apt autoclean

print_status "✅ Server setup completed successfully!"
print_status "🔧 Dependencies installed:"
print_status "  - Python $(python3 --version)"
print_status "  - Node.js $(node --version)"
print_status "  - PM2 $(pm2 --version)"
print_status "  - Nginx $(nginx -v 2>&1 | cut -d' ' -f3)"
print_status "  - UFW Firewall"
print_status "  - SSL tools (Certbot)"

echo ""
echo "🚀 Ready for application deployment!"