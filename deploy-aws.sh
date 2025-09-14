#!/bin/bash

# =============================================================================
# Revolt Bot - AWS EC2 Deployment Script
# =============================================================================
# This script sets up the Revolt bot on an AWS EC2 instance
# Usage: ./deploy-aws.sh
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install system dependencies
install_system_deps() {
    print_info "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    
    print_info "Installing system dependencies..."
    sudo apt install -y curl wget git build-essential software-properties-common
    
    # Install Node.js 20.x
    if ! command_exists node; then
        print_info "Installing Node.js 20.x..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt install -y nodejs
        print_status "Node.js installed: $(node --version)"
    else
        print_status "Node.js is already installed: $(node --version)"
    fi
    
    # Install Chromium
    if ! command_exists chromium-browser && ! command_exists chromium; then
        print_info "Installing Chromium..."
        sudo apt install -y chromium-browser
        print_status "Chromium installed successfully"
    else
        print_status "Chromium is already installed"
    fi
    
    # Install Nginx
    if ! command_exists nginx; then
        print_info "Installing Nginx..."
        sudo apt install -y nginx
        sudo systemctl enable nginx
        print_status "Nginx installed successfully"
    else
        print_status "Nginx is already installed"
    fi
    
    # Install PM2 for process management
    if ! command_exists pm2; then
        print_info "Installing PM2..."
        sudo npm install -g pm2
        print_status "PM2 installed successfully"
    else
        print_status "PM2 is already installed"
    fi
}

# Function to setup firewall
setup_firewall() {
    print_info "Configuring firewall..."
    sudo ufw allow ssh
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 49152:50000/tcp  # Dynamic bot port range
    sudo ufw --force enable
    print_status "Firewall configured"
}

# Function to create bot user
create_bot_user() {
    if ! id "revoltbot" &>/dev/null; then
        print_info "Creating bot user..."
        sudo useradd -m -s /bin/bash revoltbot
        sudo usermod -aG sudo revoltbot
        print_status "Bot user created"
    else
        print_status "Bot user already exists"
    fi
}

# Function to setup application
setup_application() {
    print_info "Setting up application..."
    
    # Create application directory
    sudo mkdir -p /opt/revolt-bot
    sudo chown revoltbot:revoltbot /opt/revolt-bot
    
    # Copy application files (handle missing files gracefully)
    if [ -f "package.json" ]; then
        sudo cp -r . /opt/revolt-bot/
        sudo chown -R revoltbot:revoltbot /opt/revolt-bot
    else
        print_error "package.json not found in current directory"
        print_info "Please run this script from the project root directory"
        exit 1
    fi
    
    # Install dependencies
    print_info "Installing Node.js dependencies..."
    cd /opt/revolt-bot
    sudo -u revoltbot npm install --production
    
    print_status "Application setup complete"
}

# Function to create systemd service
create_systemd_service() {
    print_info "Creating systemd service..."
    
    sudo tee /etc/systemd/system/revolt-bot.service > /dev/null <<EOF
[Unit]
Description=Revolt Bot Service
After=network.target

[Service]
Type=simple
User=revoltbot
WorkingDirectory=/opt/revolt-bot
ExecStart=/usr/bin/node puppeteer_revolt.js --user production
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=CHROME_PATH=/usr/bin/chromium-browser

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable revolt-bot
    print_status "Systemd service created"
}

# Function to configure Nginx
configure_nginx() {
    print_info "Configuring Nginx reverse proxy with dynamic port support..."
    
    # Check if nginx-simple.conf exists, if not create a basic one
    if [ -f "nginx-simple.conf" ]; then
        sudo cp nginx-simple.conf /etc/nginx/sites-available/revolt-bot
    else
        print_warning "nginx-simple.conf not found, creating basic configuration..."
        sudo tee /etc/nginx/sites-available/revolt-bot > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:1024;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location /multi {
        proxy_pass http://localhost:49623;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    fi
    
    # Update domain if provided
    if [ ! -z "$DOMAIN" ]; then
        sudo sed -i "s/server_name _;/server_name $DOMAIN;/" /etc/nginx/sites-available/revolt-bot
    fi
    
    # Copy the nginx proxy update script if it exists
    if [ -f "update-nginx-proxy.sh" ]; then
        sudo cp update-nginx-proxy.sh /usr/local/bin/
        sudo chmod +x /usr/local/bin/update-nginx-proxy.sh
        
        # Update the script with the correct domain
        if [ ! -z "$DOMAIN" ]; then
            sudo sed -i "s/yourdomain\.com/$DOMAIN/g" /usr/local/bin/update-nginx-proxy.sh
        fi
    else
        print_warning "update-nginx-proxy.sh not found, skipping dynamic proxy setup"
    fi

    sudo ln -sf /etc/nginx/sites-available/revolt-bot /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t
    sudo systemctl restart nginx
    print_status "Nginx configured with dynamic port support"
}

# Function to setup SSL with Let's Encrypt
setup_ssl() {
    if [ ! -z "$DOMAIN" ]; then
        print_info "Setting up SSL with Let's Encrypt..."
        sudo apt install -y certbot python3-certbot-nginx
        
        # Update Nginx config with domain
        sudo sed -i "s/server_name _;/server_name $DOMAIN;/" /etc/nginx/sites-available/revolt-bot
        sudo nginx -t && sudo systemctl reload nginx
        
        # Get SSL certificate
        sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
        print_status "SSL certificate installed"
    else
        print_warning "No domain specified. Skipping SSL setup."
        print_info "To setup SSL later, run: sudo certbot --nginx -d yourdomain.com"
    fi
}

# Function to create monitoring script
create_monitoring() {
    print_info "Setting up monitoring..."
    
    sudo tee /opt/revolt-bot/monitor.sh > /dev/null <<'EOF'
#!/bin/bash
# Monitor script for Revolt Bot

LOG_FILE="/var/log/revolt-bot-monitor.log"
SERVICE_NAME="revolt-bot"

check_service() {
    if ! systemctl is-active --quiet $SERVICE_NAME; then
        echo "$(date): Service $SERVICE_NAME is not running. Restarting..." >> $LOG_FILE
        systemctl restart $SERVICE_NAME
    fi
}

check_ports() {
    if ! netstat -tlnp | grep -q ":1024"; then
        echo "$(date): Port 1024 is not listening. Restarting service..." >> $LOG_FILE
        systemctl restart $SERVICE_NAME
    fi
}

check_service
check_ports
EOF

    sudo chmod +x /opt/revolt-bot/monitor.sh
    sudo chown revoltbot:revoltbot /opt/revolt-bot/monitor.sh
    
    # Add to crontab
    (sudo crontab -l 2>/dev/null; echo "*/5 * * * * /opt/revolt-bot/monitor.sh") | sudo crontab -
    print_status "Monitoring setup complete"
}

# Function to start services
start_services() {
    print_info "Starting services..."
    
    sudo systemctl start revolt-bot
    sudo systemctl start nginx
    
    sleep 5
    
    if systemctl is-active --quiet revolt-bot; then
        print_status "Revolt bot service started successfully"
    else
        print_error "Failed to start Revolt bot service"
        sudo systemctl status revolt-bot
        exit 1
    fi
    
    if systemctl is-active --quiet nginx; then
        print_status "Nginx service started successfully"
    else
        print_error "Failed to start Nginx service"
        sudo systemctl status nginx
        exit 1
    fi
}

# Function to display status
display_status() {
    print_info "Deployment Status:"
    echo "==================="
    echo "Service Status:"
    sudo systemctl status revolt-bot --no-pager -l
    echo ""
    echo "Nginx Status:"
    sudo systemctl status nginx --no-pager -l
    echo ""
    echo "Ports Listening:"
    sudo netstat -tlnp | grep -E ":(80|443|1024|49623|49152|49153|49154|49155|49156)"
    echo ""
    echo "Access URLs:"
    if [ ! -z "$DOMAIN" ]; then
        echo "  Main Dashboard: https://$DOMAIN"
        echo "  Multi Dashboard: https://$DOMAIN/multi"
    else
        PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
        echo "  Main Dashboard: http://$PUBLIC_IP"
        echo "  Multi Dashboard: http://$PUBLIC_IP/multi"
        echo "  Bot API: http://$PUBLIC_IP/api/"
    fi
}

# Main execution
main() {
    echo "🚀 Revolt Bot - AWS EC2 Deployment"
    echo "==================================="
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please run this script as a regular user, not root"
        exit 1
    fi
    
    # Check if required files exist
    if [ ! -f "package.json" ]; then
        print_error "package.json not found in current directory"
        print_info "Please run this script from the project root directory"
        exit 1
    fi
    
    if [ ! -f "puppeteer_revolt.js" ]; then
        print_error "puppeteer_revolt.js not found in current directory"
        print_info "Please run this script from the project root directory"
        exit 1
    fi
    
    # Check for domain parameter
    if [ ! -z "$1" ]; then
        DOMAIN="$1"
        print_info "Domain set to: $DOMAIN"
    else
        print_info "No domain specified. Using IP address for access."
    fi
    
    print_info "Starting deployment process..."
    
    # Install system dependencies
    install_system_deps
    
    # Setup firewall
    setup_firewall
    
    # Create bot user
    create_bot_user
    
    # Setup application
    setup_application
    
    # Create systemd service
    create_systemd_service
    
    # Configure Nginx
    configure_nginx
    
    # Setup SSL if domain provided
    setup_ssl
    
    # Setup monitoring
    create_monitoring
    
    # Start services
    start_services
    
    # Display status
    display_status
    
    print_status "Deployment completed successfully!"
    print_info "The bot is now running and accessible via web interface"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Deployment interrupted...${NC}"; exit 1' INT

# Run main function
main "$@"
