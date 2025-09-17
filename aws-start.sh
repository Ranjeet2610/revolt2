#!/bin/bash

# =============================================================================
# Revolt Bot - AWS Deployment Startup Script
# =============================================================================
# This script prepares and starts the Revolt bot on AWS instances
# Usage: ./aws-start.sh [username]
# Example: ./aws-start.sh mybot
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

# Function to install system dependencies for AWS
install_aws_deps() {
    print_info "Installing AWS-specific dependencies..."
    
    # Update package list
    sudo apt update
    
    # Install Node.js if not present
    if ! command_exists node; then
        print_warning "Node.js not found. Installing..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt install -y nodejs
        print_status "Node.js installed successfully"
    else
        print_status "Node.js is already installed: $(node --version)"
    fi
    
    # Install Chromium for AWS
    if ! command_exists chromium-browser; then
        print_warning "Chromium not found. Installing..."
        sudo apt install -y chromium-browser
        print_status "Chromium installed successfully"
    else
        print_status "Chromium is already installed: $(which chromium-browser)"
    fi
    
    # Install PM2 for process management
    if ! command_exists pm2; then
        print_warning "PM2 not found. Installing..."
        sudo npm install -g pm2
        print_status "PM2 installed successfully"
    else
        print_status "PM2 is already installed: $(pm2 --version)"
    fi
    
    # Install additional dependencies for AWS (Ubuntu 22.04 compatible)
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
    
    print_status "All AWS dependencies installed successfully"
}

# Function to install npm dependencies
install_npm_deps() {
    print_info "Installing npm dependencies..."
    
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
        print_warning "Node modules not found. Installing dependencies..."
        npm install
        print_status "Dependencies installed successfully"
    else
        print_status "Dependencies are already installed"
    fi
}

# Function to get AWS instance public IP
get_aws_ip() {
    print_info "Detecting AWS instance IP..."
    
    # Try to get public IP from AWS metadata
    if PUBLIC_IP=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); then
        print_status "AWS public IP detected: $PUBLIC_IP"
        echo "$PUBLIC_IP"
    else
        print_warning "Could not detect AWS public IP, using localhost"
        echo "localhost"
    fi
}

# Function to start the application
start_application() {
    local username=${1:-"aws-bot"}
    local public_ip=$(get_aws_ip)
    
    print_info "Starting Revolt Bot for user: $username"
    print_info "AWS Instance IP: $public_ip"
    print_info "The application will be available at http://$public_ip:PORT"
    print_info "Press Ctrl+C to stop the application"
    echo "=================================="
    
    # Set environment variables for AWS
    export CHROME_PATH="/usr/bin/chromium-browser"
    export NODE_ENV="production"
    export AWS_DEPLOYMENT="true"
    
    # Start the application in headless mode
    node puppeteer_revolt.js --user "$username" --headless=true
}

# Function to start with PM2
start_with_pm2() {
    local username=${1:-"aws-bot"}
    local public_ip=$(get_aws_ip)
    
    print_info "Starting Revolt Bot with PM2 for user: $username"
    print_info "AWS Instance IP: $public_ip"
    
    # Set environment variables
    export CHROME_PATH="/usr/bin/chromium-browser"
    export NODE_ENV="production"
    export AWS_DEPLOYMENT="true"
    
    # Start with PM2
    pm2 start puppeteer_revolt.js --name "revolt-bot-$username" -- --user "$username" --headless=true
    
    print_status "Bot started with PM2. Use 'pm2 status' to check status."
    print_status "Use 'pm2 logs revolt-bot-$username' to view logs."
    print_status "Use 'pm2 stop revolt-bot-$username' to stop the bot."
}

# Main execution
main() {
    echo "🚀 Revolt Bot - AWS Deployment Script"
    echo "====================================="
    
    # Get username from command line argument or use default
    USERNAME=${1:-"aws-bot"}
    
    print_info "Preparing Revolt Bot for AWS deployment: $USERNAME"
    
    # Install AWS dependencies
    install_aws_deps
    
    # Install npm dependencies
    install_npm_deps
    
    # Make scripts executable
    chmod +x aws-start.sh
    
    # Ask user for deployment method
    echo ""
    print_info "Choose deployment method:"
    echo "1) Direct start (recommended for testing)"
    echo "2) PM2 start (recommended for production)"
    read -p "Enter choice (1 or 2): " choice
    
    case $choice in
        1)
            start_application "$USERNAME"
            ;;
        2)
            start_with_pm2 "$USERNAME"
            ;;
        *)
            print_warning "Invalid choice, starting with direct method..."
            start_application "$USERNAME"
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Shutting down...${NC}"; exit 0' INT

# Run main function
main "$@"
