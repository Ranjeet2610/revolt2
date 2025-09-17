#!/bin/bash

# =============================================================================
# Revolt Bot - Simplified AWS Startup Script
# =============================================================================
# This script provides a more robust installation process for AWS
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

# Function to install packages with fallback
install_package() {
    local package=$1
    local fallback=$2
    
    print_info "Installing $package..."
    if sudo apt install -y "$package" 2>/dev/null; then
        print_status "$package installed successfully"
    elif [ -n "$fallback" ] && sudo apt install -y "$fallback" 2>/dev/null; then
        print_warning "$package not found, using $fallback instead"
    else
        print_warning "Could not install $package, continuing..."
    fi
}

# Function to install system dependencies
install_aws_deps() {
    print_info "Installing AWS dependencies..."
    
    # Update package list
    sudo apt update
    
    # Install Node.js
    if ! command -v node &> /dev/null; then
        print_info "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt install -y nodejs
        print_status "Node.js installed successfully"
    else
        print_status "Node.js is already installed: $(node --version)"
    fi
    
    # Install Chromium
    if ! command -v chromium-browser &> /dev/null; then
        print_info "Installing Chromium..."
        sudo apt install -y chromium-browser
        print_status "Chromium installed successfully"
    else
        print_status "Chromium is already installed: $(which chromium-browser)"
    fi
    
    # Install PM2
    if ! command -v pm2 &> /dev/null; then
        print_info "Installing PM2..."
        sudo npm install -g pm2
        print_status "PM2 installed successfully"
    else
        print_status "PM2 is already installed: $(pm2 --version)"
    fi
    
    # Install dependencies with fallbacks
    print_info "Installing additional dependencies..."
    
    # Core packages
    install_package "fonts-liberation"
    install_package "libcups2"
    install_package "libdbus-1-3"
    install_package "libdrm2"
    install_package "libgtk-3-0"
    install_package "libnspr4"
    install_package "libnss3"
    install_package "libx11-xcb1"
    install_package "libxcomposite1"
    install_package "libxdamage1"
    install_package "libxfixes3"
    install_package "libxrandr2"
    install_package "libxss1"
    install_package "libxtst6"
    install_package "xdg-utils"
    install_package "libxkbcommon0"
    install_package "libgbm1"
    
    # Audio packages with fallbacks
    install_package "libasound2t64" "libasound2"
    install_package "libatk-bridge2.0-0" "libatk-bridge2.0-0"
    install_package "libatk1.0-0" "libatk1.0-0"
    install_package "libatspi2.0-0" "libatspi2.0-0"
    
    print_status "All dependencies installed successfully"
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

# Function to start the application
start_application() {
    local username=${1:-"aws-bot"}
    
    print_info "Starting Revolt Bot for user: $username"
    
    # Set environment variables
    export CHROME_PATH="/usr/bin/chromium-browser"
    export NODE_ENV="production"
    export AWS_DEPLOYMENT="true"
    
    # Start the application
    node puppeteer_revolt.js --user "$username" --headless=true
}

# Main execution
main() {
    echo "🚀 Revolt Bot - Simplified AWS Startup"
    echo "======================================"
    
    USERNAME=${1:-"aws-bot"}
    
    print_info "Setting up Revolt Bot for user: $USERNAME"
    
    # Install dependencies
    install_aws_deps
    install_npm_deps
    
    # Make scripts executable
    chmod +x aws-start.sh aws-start-simple.sh
    
    # Start the application
    start_application "$USERNAME"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Shutting down...${NC}"; exit 0' INT

# Run main function
main "$@"
