#!/bin/bash

# =============================================================================
# Revolt Bot - Local Deployment Script
# =============================================================================
# This script sets up the Revolt bot locally with the same configuration as AWS
# Usage: ./deploy-local.sh
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
    print_info "Installing system dependencies..."
    
    # Install Node.js if not present
    if ! command_exists node; then
        print_info "Installing Node.js..."
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
    print_info "Configuring firewall..."
    sudo ufw allow ssh
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow ${PORT_RANGE_START}:${PORT_RANGE_END}/tcp
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
        sudo cp -r . $BOT_DIR/
        sudo chown -R $BOT_USER:$BOT_USER $BOT_DIR
    else
        print_error "package.json not found in current directory"
        print_info "Please run this script from the project root directory"
        exit 1
    fi
    
    # Install dependencies
    print_info "Installing Node.js dependencies..."
    cd $BOT_DIR
    sudo -u $BOT_USER npm install --production
    
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
ExecStart=/usr/bin/node puppeteer_revolt.js --user production --headless=true
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
ExecStart=/usr/bin/node puppeteer_revolt.js --user %i --headless=true
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

# Function to configure Nginx
configure_nginx() {
    print_info "Configuring Nginx..."
    
    sudo tee /etc/nginx/sites-available/revolt-bot > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Main bot dashboard
    location / {
        proxy_pass http://127.0.0.1:1024;
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
    
    # Bot instance
    location /bot/ {
        proxy_pass http://127.0.0.1:1024/;
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
        proxy_pass http://127.0.0.1:1024;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Socket.IO support
    location /socket.io/ {
        proxy_pass http://127.0.0.1:1024;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Health check
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
    
    # Test and restart nginx
    sudo nginx -t
    sudo systemctl restart nginx
    print_status "Nginx configured"
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
    
    # Wait a moment for the service to start
    sleep 3
    
    # Check if it's running
    if systemctl is-active --quiet "${SERVICE_PREFIX}@${bot_name}.service"; then
        echo "✓ Bot instance '$bot_name' started successfully"
    else
        echo "❌ Failed to start bot instance '$bot_name'"
        systemctl status "${SERVICE_PREFIX}@${bot_name}.service" --no-pager
    fi
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
    echo "✓ Bot instance '$bot_name' stopped"
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
    
    # Wait a moment for the service to restart
    sleep 3
    
    # Check if it's running
    if systemctl is-active --quiet "${SERVICE_PREFIX}@${bot_name}.service"; then
        echo "✓ Bot instance '$bot_name' restarted successfully"
    else
        echo "❌ Failed to restart bot instance '$bot_name'"
        systemctl status "${SERVICE_PREFIX}@${bot_name}.service" --no-pager
    fi
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
    ss -tlnp | grep -E ":(49152|49153|49154|49155|49156|49157|49158|49159|49160)" | awk '{print $4}' | cut -d: -f2 | sort -n
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
        echo "Revolt Bot Manager"
        echo "================="
        echo ""
        echo "Usage: $0 {start|stop|restart|status|list} [bot_name]"
        echo ""
        echo "Commands:"
        echo "  start <name>    - Start a new bot instance"
        echo "  stop <name>     - Stop a bot instance"
        echo "  restart <name>  - Restart a bot instance"
        echo "  status [name]   - Show status of bot(s)"
        echo "  list            - List all active bot instances"
        echo ""
        echo "Examples:"
        echo "  $0 start mybot"
        echo "  $0 stop mybot"
        echo "  $0 restart mybot"
        echo "  $0 status mybot"
        echo "  $0 list"
        exit 1
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/revolt-bot-manager.sh
    print_status "Bot management script created"
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
    echo "  Main Dashboard: http://localhost"
    echo "  Bot Instances: http://localhost/bot/"
    echo "  Health Check: http://localhost/health"
    echo ""
    echo "Management Commands:"
    echo "  Start bot: revolt-bot-manager.sh start mybot"
    echo "  Stop bot: revolt-bot-manager.sh stop mybot"
    echo "  List bots: revolt-bot-manager.sh list"
}

# Main execution
main() {
    echo "🚀 Revolt Bot - Local Deployment"
    echo "================================="
    
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
    
    print_info "Starting local deployment process..."
    
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
    create_bot_management_script
    
    # Start services
    start_services
    
    # Display status
    display_status
    
    print_status "Local deployment completed successfully!"
    print_info "The bot is now running with the same configuration as AWS"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Deployment interrupted...${NC}"; exit 1' INT

# Run main function
main "$@"

