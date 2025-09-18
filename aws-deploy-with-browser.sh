#!/bin/bash

# =============================================================================
# AWS Deployment with Browser Access
# =============================================================================
# This script deploys the bot and provides instructions for browser access
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Get AWS instance IP
get_aws_ip() {
    if PUBLIC_IP=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); then
        echo "$PUBLIC_IP"
    else
        echo "43.205.112.153"
    fi
}

# Install required packages
install_dependencies() {
    print_info "Installing dependencies..."
    
    # Update package list
    sudo apt update
    
    # Install Node.js if not present
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
    
    # Install Chromium
    if ! command -v chromium-browser &> /dev/null; then
        sudo apt install -y chromium-browser
    fi
    
    # Install additional dependencies
    sudo apt install -y \
        fonts-liberation \
        libasound2t64 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libatspi2.0-0 \
        libcups2 \
        libdbus-1-3 \
        libdrm2 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libx11-xcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxrandr2 \
        libxss1 \
        libxtst6 \
        xdg-utils \
        libxkbcommon0 \
        libgbm1
    
    # Install npm dependencies
    if [ ! -d "node_modules" ]; then
        npm install
    fi
}

# Start the bot
start_bot() {
    local username=${1:-"aws-bot"}
    local aws_ip=$(get_aws_ip)
    
    print_info "Starting Revolt Bot for user: $username"
    print_info "AWS Instance IP: $aws_ip"
    
    # Set environment variables
    export CHROME_PATH="/usr/bin/chromium-browser"
    export NODE_ENV="production"
    export AWS_DEPLOYMENT="true"
    
    # Start bot in background
    nohup node puppeteer_revolt.js --user "$username" --headless=true > bot.log 2>&1 &
    local bot_pid=$!
    
    # Wait for bot to start
    print_info "Waiting for bot to start..."
    sleep 10
    
    # Get the port from logs
    local port=$(grep "Now listening to:" bot.log | tail -1 | grep -o '[0-9]\+' | tail -1)
    
    if [ -n "$port" ]; then
        print_status "Bot started successfully!"
        print_status "Bot Dashboard: http://$aws_ip:$port"
        print_status "Bot PID: $bot_pid"
        
        echo ""
        echo "🌐 ACCESS YOUR BOT:"
        echo "=================="
        echo "1. Open your web browser"
        echo "2. Go to: http://$aws_ip:$port"
        echo "3. The bot will automatically connect to Revolt"
        echo ""
        echo "📋 IMPORTANT NOTES:"
        echo "- The bot runs in headless mode on AWS"
        echo "- You can monitor it via the web dashboard"
        echo "- Check bot.log for detailed logs"
        echo "- Use 'kill $bot_pid' to stop the bot"
        echo ""
        echo "🔧 TROUBLESHOOTING:"
        echo "- If you can't access the dashboard, check AWS Security Group"
        echo "- Make sure port $port is open in Security Group"
        echo "- Check UFW firewall: sudo ufw status"
        
        # Keep the script running to show status
        print_info "Bot is running in background. Press Ctrl+C to exit this script (bot will continue running)"
        
        # Monitor the bot
        while kill -0 $bot_pid 2>/dev/null; do
            sleep 5
            echo "🤖 Bot is running... Dashboard: http://$aws_ip:$port"
        done
        
    else
        print_error "Failed to start bot. Check bot.log for errors:"
        tail -20 bot.log
        exit 1
    fi
}

# Main function
main() {
    echo "🚀 Revolt Bot - AWS Deployment with Browser Access"
    echo "=================================================="
    
    USERNAME=${1:-"aws-bot"}
    
    # Install dependencies
    install_dependencies
    
    # Start the bot
    start_bot "$USERNAME"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Script stopped. Bot continues running in background.${NC}"; exit 0' INT

# Run main function
main "$@"
