#!/bin/bash

# =============================================================================
# Revolt Bot - Auto Setup and Run Script
# =============================================================================
# This script automatically installs all dependencies and starts the Revolt bot
# Usage: ./run.sh [username]
# Example: ./run.sh mybot
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
    print_info "Checking system dependencies..."
    
    # Check and install Node.js if needed
    if ! command_exists node; then
        print_warning "Node.js not found. Installing..."
        sudo apt update
        sudo apt install -y nodejs npm
        print_status "Node.js installed successfully"
    else
        print_status "Node.js is already installed: $(node --version)"
    fi
    
    # Check and install Chromium if needed
    if ! command_exists chromium-browser && ! command_exists chromium; then
        print_warning "Chromium not found. Installing..."
        sudo apt update
        sudo apt install -y chromium-browser
        print_status "Chromium installed successfully"
    else
        if command_exists chromium-browser; then
            print_status "Chromium is already installed: $(which chromium-browser)"
        else
            print_status "Chromium is already installed: $(which chromium)"
        fi
    fi
}

# Function to install npm dependencies
install_npm_deps() {
    print_info "Checking npm dependencies..."
    
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
        print_warning "Node modules not found. Installing dependencies..."
        npm install
        print_status "Dependencies installed successfully"
    else
        print_status "Dependencies are already installed"
    fi
}

# Function to make scripts executable
make_executable() {
    if [ -f "start.sh" ]; then
        chmod +x start.sh
        print_status "Made start.sh executable"
    fi
}

# Function to start the application
start_application() {
    local username=${1:-"testuser"}
    
    print_info "Starting Revolt Bot for user: $username"
    print_info "The application will be available at http://localhost:PORT"
    print_info "Press Ctrl+C to stop the application"
    echo "=================================="
    
    if [ -f "start.sh" ]; then
        ./start.sh --user "$username"
    else
        node puppeteer_revolt.js --user "$username"
    fi
}

# Main execution
main() {
    echo "🚀 Revolt Bot - Auto Setup & Run Script"
    echo "========================================"
    
    # Get username from command line argument or use default
    USERNAME=${1:-"testuser"}
    
    print_info "Setting up Revolt Bot for user: $USERNAME"
    
    # Install system dependencies
    install_system_deps
    
    # Install npm dependencies
    install_npm_deps
    
    # Make scripts executable
    make_executable
    
    # Start the application
    start_application "$USERNAME"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Shutting down...${NC}"; exit 0' INT

# Run main function
main "$@"
