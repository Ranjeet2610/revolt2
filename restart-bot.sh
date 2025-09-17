#!/bin/bash

# =============================================================================
# Restart Revolt Bot with External Access
# =============================================================================
# This script restarts the bot to listen on all interfaces (0.0.0.0)
# =============================================================================

echo "🔄 Restarting Revolt Bot with External Access"
echo "============================================="

# Kill any existing bot processes
echo "🛑 Stopping existing bot processes..."
pkill -f "puppeteer_revolt.js" || echo "No existing processes found"

# Wait a moment
sleep 2

# Set environment variables
export CHROME_PATH="/usr/bin/chromium-browser"
export NODE_ENV="production"
export AWS_DEPLOYMENT="true"

# Get the username from command line or use default
USERNAME=${1:-"aws-bot"}

echo "🚀 Starting bot for user: $USERNAME"
echo "📡 Bot will now listen on all interfaces (0.0.0.0)"
echo "🌐 Access your bot at: http://13.232.150.98:PORT"
echo ""
echo "Press Ctrl+C to stop the bot"
echo "================================"

# Start the bot
node puppeteer_revolt.js --user "$USERNAME" --headless=true
