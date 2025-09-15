#!/bin/bash

# =============================================================================
# Quick Redeploy Script for AWS Headless Mode Fix
# =============================================================================
# This script applies the headless mode fixes to an existing AWS deployment
# Usage: ./redeploy-aws-fix.sh
# =============================================================================

set -e

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

print_info "Applying headless mode fixes to AWS deployment..."

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root - using root deployment script"
    DEPLOY_SCRIPT="./deploy-aws-root.sh"
else
    print_info "Running as regular user - using standard deployment script"
    DEPLOY_SCRIPT="./deploy-aws.sh"
fi

# Check if deployment script exists
if [ ! -f "$DEPLOY_SCRIPT" ]; then
    print_error "Deployment script not found: $DEPLOY_SCRIPT"
    exit 1
fi

# Stop existing services
print_info "Stopping existing services..."
if systemctl is-active --quiet revolt-bot 2>/dev/null; then
    systemctl stop revolt-bot
    print_status "Main bot service stopped"
fi

# Stop any dynamic bot instances
for service in $(systemctl list-units --type=service | grep "revolt-bot@" | awk '{print $1}'); do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        systemctl stop "$service"
        print_status "Stopped $service"
    fi
done

# Reload systemd and restart services
print_info "Reloading systemd configuration..."
systemctl daemon-reload

print_info "Starting main bot service with headless mode..."
systemctl start revolt-bot

# Wait a moment for the service to start
sleep 5

# Check if the service is running
if systemctl is-active --quiet revolt-bot; then
    print_status "Main bot service started successfully in headless mode"
else
    print_error "Failed to start main bot service"
    systemctl status revolt-bot --no-pager -l
    exit 1
fi

# Show service status
print_info "Service Status:"
systemctl status revolt-bot --no-pager -l

print_info "Ports Listening:"
ss -tlnp | grep -E ":(80|443|1024|49152|49153|49154|49155|49156)" || echo "No bot ports found"

print_status "Headless mode fix applied successfully!"
print_info "The bot should now be running in headless mode on your AWS instance."
print_info "Check the service logs with: sudo journalctl -u revolt-bot -f"
