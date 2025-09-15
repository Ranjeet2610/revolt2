#!/bin/bash

# =============================================================================
# Revolt Bot - AWS EC2 Deployment Script with Dynamic Ports
# =============================================================================
# This script sets up the Revolt bot on an AWS EC2 instance with dynamic port support
# Usage: ./deploy-aws.sh [domain.com]
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BOT_USER="revoltbot"
BOT_DIR="/opt/revolt-bot"
DOMAIN="${1:-}"
PORT_RANGE_START=49152
PORT_RANGE_END=50000

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
    if [ "$EUID" -eq 0 ]; then
        apt update && apt upgrade -y
    else
        sudo apt update && sudo apt upgrade -y
    fi
    
    print_info "Installing system dependencies..."
    if [ "$EUID" -eq 0 ]; then
        apt install -y curl wget git build-essential software-properties-common ufw
    else
        sudo apt install -y curl wget git build-essential software-properties-common ufw
    fi
    
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
}

# Function to setup firewall
setup_firewall() {
    print_info "Configuring firewall with dynamic port support..."
    sudo ufw allow ssh
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow ${PORT_RANGE_START}:${PORT_RANGE_END}/tcp  # Dynamic bot port range
    sudo ufw --force enable
    print_status "Firewall configured for ports ${PORT_RANGE_START}-${PORT_RANGE_END}"
}

# Function to create bot user
create_bot_user() {
    if ! id "$BOT_USER" &>/dev/null; then
        print_info "Creating bot user..."
        sudo useradd -m -s /bin/bash $BOT_USER
        sudo usermod -aG sudo $BOT_USER
        print_status "Bot user created"
    else
        print_status "Bot user already exists"
    fi
}

# Function to setup application
setup_application() {
    print_info "Setting up application..."
    
    # Create application directory
    sudo mkdir -p $BOT_DIR
    sudo chown $BOT_USER:$BOT_USER $BOT_DIR
    
    # Copy application files
    if [ -f "package.json" ]; then
        if [ "$EUID" -eq 0 ]; then
            cp -r . $BOT_DIR/
            chown -R $BOT_USER:$BOT_USER $BOT_DIR
        else
            sudo cp -r . $BOT_DIR/
            sudo chown -R $BOT_USER:$BOT_USER $BOT_DIR
        fi
    else
        print_error "package.json not found in current directory"
        print_info "Please run this script from the project root directory"
        exit 1
    fi
    
    # Install dependencies
    print_info "Installing Node.js dependencies..."
    cd $BOT_DIR
    if [ "$EUID" -eq 0 ]; then
        sudo -u $BOT_USER npm install --production
    else
        sudo -u $BOT_USER npm install --production
    fi
    
    print_status "Application setup complete"
}

# Function to create systemd service for main bot
create_main_systemd_service() {
    print_info "Creating main bot systemd service..."
    
    sudo tee /etc/systemd/system/revolt-bot.service > /dev/null <<EOF
[Unit]
Description=Revolt Bot Main Service
After=network.target

[Service]
Type=simple
User=$BOT_USER
WorkingDirectory=$BOT_DIR
ExecStart=/usr/bin/node puppeteer_revolt.js --user production
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=CHROME_PATH=/usr/bin/chromium-browser
Environment=NODE_OPTIONS=--max-old-space-size=4096
Environment=UV_THREADPOOL_SIZE=128

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable revolt-bot
    print_status "Main bot systemd service created"
}

# Function to create systemd service template for dynamic bot instances
create_dynamic_systemd_service() {
    print_info "Creating dynamic bot instances systemd service template..."
    
    sudo tee /etc/systemd/system/revolt-bot@.service > /dev/null <<EOF
[Unit]
Description=Revolt Bot Instance %i
After=network.target

[Service]
Type=simple
User=$BOT_USER
WorkingDirectory=$BOT_DIR
ExecStart=/usr/bin/node puppeteer_revolt.js --user %i
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=CHROME_PATH=/usr/bin/chromium-browser
Environment=NODE_OPTIONS=--max-old-space-size=4096
Environment=UV_THREADPOOL_SIZE=128

[Install]
WantedBy=multi-user.target
EOF

    print_status "Dynamic bot instances systemd service template created"
}

# Function to configure Nginx with dynamic port support
configure_nginx() {
    print_info "Configuring Nginx with dynamic port support..."
    
    sudo tee /etc/nginx/sites-available/revolt-bot > /dev/null <<EOF
# Dynamic port configuration for Revolt Bot
# This configuration supports multiple bot instances on ports ${PORT_RANGE_START}-${PORT_RANGE_END}

# Upstream for main bot (port 1024)
upstream main_bot {
    server 127.0.0.1:1024;
}

# Upstream for dynamic bot instances
upstream dynamic_bots {
    # This will be dynamically updated by the proxy update script
    server 127.0.0.1:${PORT_RANGE_START};
}

server {
    listen 80;
    server_name ${DOMAIN:-_};
    
    # Main bot dashboard
    location / {
        proxy_pass http://main_bot;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Dynamic bot instances (path-based routing)
    location ~ ^/bot/([a-zA-Z0-9-]+)/? {
        set \$bot_name \$1;
        proxy_pass http://dynamic_bots;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # API endpoints
    location /api/ {
        proxy_pass http://main_bot;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Socket.IO support
    location /socket.io/ {
        proxy_pass http://main_bot;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/revolt-bot /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload nginx
    sudo nginx -t
    sudo systemctl restart nginx
    print_status "Nginx configured with dynamic port support"
}

# Function to create dynamic proxy management script
create_proxy_management_script() {
    print_info "Creating dynamic proxy management script..."
    
    sudo tee /usr/local/bin/update-nginx-proxy.sh > /dev/null <<'EOF'
#!/bin/bash

# Dynamic Nginx Proxy Update Script for Revolt Bot
# This script updates Nginx configuration when bot instances are added/removed

NGINX_CONFIG="/etc/nginx/sites-available/revolt-bot"
TEMP_CONFIG="/tmp/nginx-revolt-temp.conf"
BOT_DIR="/opt/revolt-bot"
PORT_RANGE_START=49152
PORT_RANGE_END=50000

# Function to get active bot ports
get_active_ports() {
    # Find all running bot processes and extract their ports
    ps aux | grep "puppeteer_revolt.js" | grep -v grep | while read line; do
        # Extract port from the process arguments or log files
        echo "$line" | grep -o "localhost:[0-9]*" | cut -d: -f2
    done | sort -n | uniq
}

# Function to update Nginx configuration
update_nginx_config() {
    local active_ports=($(get_active_ports))
    
    # Create temporary configuration
    cat > "$TEMP_CONFIG" << 'NGINX_EOF'
# Dynamic port configuration for Revolt Bot
# Generated on: $(date)
# Active bot ports: ${active_ports[*]}

# Upstream for main bot (port 1024)
upstream main_bot {
    server 127.0.0.1:1024;
}

# Upstream for dynamic bot instances
upstream dynamic_bots {
NGINX_EOF

    # Add active bot ports to upstream
    for port in "${active_ports[@]}"; do
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge $PORT_RANGE_START ] && [ "$port" -le $PORT_RANGE_END ]; then
            echo "    server 127.0.0.1:$port;" >> "$TEMP_CONFIG"
        fi
    done
    
    # Add default server if no active bots
    if [ ${#active_ports[@]} -eq 0 ]; then
        echo "    server 127.0.0.1:$PORT_RANGE_START;" >> "$TEMP_CONFIG"
    fi
    
    cat >> "$TEMP_CONFIG" << 'NGINX_EOF'
}

server {
    listen 80;
    server_name _;
    
    # Main bot dashboard
    location / {
        proxy_pass http://main_bot;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Dynamic bot instances (path-based routing)
    location ~ ^/bot/([a-zA-Z0-9-]+)/? {
        set $bot_name $1;
        proxy_pass http://dynamic_bots;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # API endpoints
    location /api/ {
        proxy_pass http://main_bot;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Socket.IO support
    location /socket.io/ {
        proxy_pass http://main_bot;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
NGINX_EOF

    # Test configuration
    if nginx -t -c "$TEMP_CONFIG"; then
        # Backup current config
        cp "$NGINX_CONFIG" "$NGINX_CONFIG.backup.$(date +%s)"
        
        # Replace configuration
        mv "$TEMP_CONFIG" "$NGINX_CONFIG"
        
        # Reload Nginx
        systemctl reload nginx
        
        echo "Nginx configuration updated successfully at $(date)"
        echo "Active bot ports: ${ports[*]}"
    else
        echo "Error: Invalid Nginx configuration generated"
        rm -f "$TEMP_CONFIG"
        exit 1
    fi
}

# Main execution
case "$1" in
    "update")
        update_nginx_config
        ;;
    "status")
        echo "Active bot ports: $(get_active_ports | tr '\n' ' ')"
        ;;
    *)
        echo "Usage: $0 {update|status}"
        exit 1
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/update-nginx-proxy.sh
    print_status "Dynamic proxy management script created"
}

# Function to create bot management script
create_bot_management_script() {
    print_info "Creating bot management script..."
    
    sudo tee /usr/local/bin/revolt-bot-manager.sh > /dev/null <<'EOF'
#!/bin/bash

# Revolt Bot Management Script
# Usage: revolt-bot-manager.sh {start|stop|restart|status|list} [bot_name]

BOT_DIR="/opt/revolt-bot"
SERVICE_PREFIX="revolt-bot"

# Function to start a bot instance
start_bot() {
    local bot_name="$1"
    if [ -z "$bot_name" ]; then
        echo "Error: Bot name required"
        exit 1
    fi
    
    echo "Starting bot instance: $bot_name"
    systemctl start "${SERVICE_PREFIX}@${bot_name}.service"
    systemctl enable "${SERVICE_PREFIX}@${bot_name}.service"
    
    # Update nginx proxy
    /usr/local/bin/update-nginx-proxy.sh update
}

# Function to stop a bot instance
stop_bot() {
    local bot_name="$1"
    if [ -z "$bot_name" ]; then
        echo "Error: Bot name required"
        exit 1
    fi
    
    echo "Stopping bot instance: $bot_name"
    systemctl stop "${SERVICE_PREFIX}@${bot_name}.service"
    systemctl disable "${SERVICE_PREFIX}@${bot_name}.service"
    
    # Update nginx proxy
    /usr/local/bin/update-nginx-proxy.sh update
}

# Function to restart a bot instance
restart_bot() {
    local bot_name="$1"
    if [ -z "$bot_name" ]; then
        echo "Error: Bot name required"
        exit 1
    fi
    
    echo "Restarting bot instance: $bot_name"
    systemctl restart "${SERVICE_PREFIX}@${bot_name}.service"
    
    # Update nginx proxy
    /usr/local/bin/update-nginx-proxy.sh update
}

# Function to show bot status
show_status() {
    local bot_name="$1"
    if [ -z "$bot_name" ]; then
        echo "All bot instances status:"
        systemctl status "${SERVICE_PREFIX}@*.service" --no-pager
    else
        echo "Bot instance '$bot_name' status:"
        systemctl status "${SERVICE_PREFIX}@${bot_name}.service" --no-pager
    fi
}

# Function to list all bot instances
list_bots() {
    echo "Active bot instances:"
    systemctl list-units --type=service | grep "${SERVICE_PREFIX}@" | awk '{print $1}' | sed "s/${SERVICE_PREFIX}@//g" | sed 's/.service//g'
    
    echo ""
    echo "Active bot ports:"
    /usr/local/bin/update-nginx-proxy.sh status
}

# Main execution
case "$1" in
    "start")
        start_bot "$2"
        ;;
    "stop")
        stop_bot "$2"
        ;;
    "restart")
        restart_bot "$2"
        ;;
    "status")
        show_status "$2"
        ;;
    "list")
        list_bots
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|list} [bot_name]"
        echo ""
        echo "Examples:"
        echo "  $0 start mybot          # Start bot instance 'mybot'"
        echo "  $0 stop mybot           # Stop bot instance 'mybot'"
        echo "  $0 restart mybot        # Restart bot instance 'mybot'"
        echo "  $0 status mybot         # Show status of 'mybot'"
        echo "  $0 status               # Show status of all bots"
        echo "  $0 list                 # List all active bot instances"
        exit 1
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/revolt-bot-manager.sh
    print_status "Bot management script created"
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
    if ! ss -tlnp | grep -q ":1024"; then
        echo "$(date): Port 1024 is not listening. Restarting service..." >> $LOG_FILE
        systemctl restart $SERVICE_NAME
    fi
}

check_service
check_ports
EOF

    sudo chmod +x /opt/revolt-bot/monitor.sh
    sudo chown $BOT_USER:$BOT_USER /opt/revolt-bot/monitor.sh
    
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
    sudo ss -tlnp | grep -E ":(80|443|1024|49152|49153|49154|49155|49156)"
    echo ""
    echo "Access URLs:"
    if [ ! -z "$DOMAIN" ]; then
        echo "  Main Dashboard: https://$DOMAIN"
        echo "  Bot Instances: https://$DOMAIN/bot/botname/"
    else
        PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
        echo "  Main Dashboard: http://$PUBLIC_IP"
        echo "  Bot Instances: http://$PUBLIC_IP/bot/botname/"
        echo "  Bot API: http://$PUBLIC_IP/api/"
    fi
    echo ""
    echo "Management Commands:"
    echo "  Start bot: sudo revolt-bot-manager.sh start mybot"
    echo "  Stop bot: sudo revolt-bot-manager.sh stop mybot"
    echo "  List bots: sudo revolt-bot-manager.sh list"
    echo "  Update proxy: sudo update-nginx-proxy.sh update"
}

# Main execution
main() {
    echo "🚀 Revolt Bot - AWS EC2 Deployment with Dynamic Ports"
    echo "====================================================="
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root - this is not recommended but will proceed"
        print_info "Consider creating a regular user for better security"
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
    if [ ! -z "$DOMAIN" ]; then
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
    
    # Create systemd services
    create_main_systemd_service
    create_dynamic_systemd_service
    
    # Configure Nginx
    configure_nginx
    
    # Create management scripts
    create_proxy_management_script
    create_bot_management_script
    
    # Setup SSL if domain provided
    setup_ssl
    
    # Setup monitoring
    create_monitoring
    
    # Start services
    start_services
    
    # Display status
    display_status
    
    print_status "Deployment completed successfully!"
    print_info "The bot is now running with dynamic port support (${PORT_RANGE_START}-${PORT_RANGE_END})"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Deployment interrupted...${NC}"; exit 1' INT

# Run main function
main "$@"
