#!/bin/bash

# =============================================================================
# Revolt Bot - Simple Local Start Script
# =============================================================================
# This script starts the bot locally with the same configuration as AWS
# Usage: ./start-local.sh [bot_name]
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BOT_NAME="${1:-localbot}"
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

# Function to find available port
find_available_port() {
    local port=$PORT_RANGE_START
    while [ $port -le $PORT_RANGE_END ]; do
        if ! ss -tlnp | grep -q ":$port "; then
            echo $port
            return
        fi
        port=$((port + 1))
    done
    echo "No available port found in range $PORT_RANGE_START-$PORT_RANGE_END"
    exit 1
}

# Function to start bot
start_bot() {
    print_info "Starting Revolt Bot locally..."
    print_info "Bot name: $BOT_NAME"
    
    # Set environment variables for performance
    export NODE_OPTIONS="--max-old-space-size=4096"
    export UV_THREADPOOL_SIZE=128
    export NODE_ENV=production
    export CHROME_PATH="/usr/bin/chromium-browser"
    
    # Start the bot in headless mode
    print_info "Starting bot in headless mode..."
    node puppeteer_revolt.js --user "$BOT_NAME" --headless=true &
    
    # Get the process ID
    BOT_PID=$!
    
    # Wait a moment for the bot to start
    sleep 5
    
    # Check if the bot is running
    if kill -0 $BOT_PID 2>/dev/null; then
        print_status "Bot started successfully with PID: $BOT_PID"
        
        # Find the port the bot is using
        BOT_PORT=$(ss -tlnp | grep "node.*puppeteer_revolt.js" | awk '{print $4}' | cut -d: -f2 | head -1)
        
        if [ ! -z "$BOT_PORT" ]; then
            print_status "Bot is running on port: $BOT_PORT"
            print_info "Access your bot at: http://13.232.150.98:$BOT_PORT"
        else
            print_warning "Could not determine bot port"
        fi
        
        # Save PID for later use
        echo $BOT_PID > .bot_pid 2>/dev/null || print_warning "Could not save PID file"
        print_info "Bot PID: $BOT_PID"
        
    else
        print_error "Failed to start bot"
        exit 1
    fi
}

# Function to stop bot
stop_bot() {
    if [ -f ".bot_pid" ]; then
        BOT_PID=$(cat .bot_pid 2>/dev/null)
        if [ ! -z "$BOT_PID" ] && kill -0 $BOT_PID 2>/dev/null; then
            print_info "Stopping bot (PID: $BOT_PID)..."
            kill $BOT_PID
            rm -f .bot_pid
            print_status "Bot stopped successfully"
        else
            print_warning "Bot process not found"
            rm -f .bot_pid
        fi
    else
        print_warning "No bot PID file found"
        # Try to kill any running bot processes
        pkill -f "puppeteer_revolt.js" 2>/dev/null || true
        print_status "Attempted to stop all bot processes"
    fi
}

# Function to show status
show_status() {
    if [ -f ".bot_pid" ]; then
        BOT_PID=$(cat .bot_pid 2>/dev/null)
        if [ ! -z "$BOT_PID" ] && kill -0 $BOT_PID 2>/dev/null; then
            print_status "Bot is running (PID: $BOT_PID)"
            BOT_PORT=$(ss -tlnp | grep "node.*puppeteer_revolt.js" | awk '{print $4}' | cut -d: -f2 | head -1)
            if [ ! -z "$BOT_PORT" ]; then
                print_info "Bot is accessible at: http://13.232.150.98:$BOT_PORT"
            fi
        else
            print_warning "Bot is not running"
            rm -f .bot_pid
        fi
    else
        print_warning "No bot PID file found"
    fi
}

# Function to show help
show_help() {
    echo "Revolt Bot - Local Start Script"
    echo "==============================="
    echo ""
    echo "Usage: $0 [command] [bot_name]"
    echo ""
    echo "Commands:"
    echo "  start [name]  - Start the bot (default: localbot)"
    echo "  stop          - Stop the bot"
    echo "  status        - Show bot status"
    echo "  help          - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 start mybot"
    echo "  $0 stop"
    echo "  $0 status"
}

# Main execution
case "${1:-start}" in
    "start")
        start_bot
        ;;
    "stop")
        stop_bot
        ;;
    "status")
        show_status
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
