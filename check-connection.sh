#!/bin/bash

# =============================================================================
# Connection Check Script for Revolt Bot
# =============================================================================
# This script helps troubleshoot connection issues
# =============================================================================

echo "🔍 Revolt Bot Connection Troubleshooting"
echo "========================================"

# Get the current IP
CURRENT_IP=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "43.205.112.153")
echo "📍 Current IP: $CURRENT_IP"

# Check if the bot is running
echo ""
echo "🤖 Checking if bot is running..."
if pgrep -f "puppeteer_revolt.js" > /dev/null; then
    echo "✅ Bot process is running"
    
    # Get the port from the process
    PORT=$(netstat -tlnp 2>/dev/null | grep node | grep LISTEN | awk '{print $4}' | cut -d: -f2 | head -1)
    if [ -n "$PORT" ]; then
        echo "✅ Bot is listening on port: $PORT"
        echo "🌐 Dashboard URL: http://$CURRENT_IP:$PORT"
    else
        echo "❌ Could not determine port"
    fi
else
    echo "❌ Bot process not found"
fi

# Check if port is accessible
echo ""
echo "🔌 Checking port accessibility..."
if [ -n "$PORT" ]; then
    if netstat -tlnp 2>/dev/null | grep ":$PORT " > /dev/null; then
        echo "✅ Port $PORT is listening"
    else
        echo "❌ Port $PORT is not listening"
    fi
fi

# Check firewall status
echo ""
echo "🔥 Checking firewall status..."
if command -v ufw > /dev/null; then
    UFW_STATUS=$(sudo ufw status | head -1)
    echo "UFW Status: $UFW_STATUS"
    if echo "$UFW_STATUS" | grep -q "active"; then
        echo "⚠️  UFW is active - you may need to open port $PORT"
        echo "   Run: sudo ufw allow $PORT"
    fi
fi

# Check if we can reach the dashboard
echo ""
echo "🌐 Testing dashboard connectivity..."
if [ -n "$PORT" ]; then
    if curl -s --max-time 5 "http://localhost:$PORT/api/bot_version" > /dev/null; then
        echo "✅ Dashboard is responding locally"
    else
        echo "❌ Dashboard is not responding locally"
    fi
fi

echo ""
echo "📋 Next Steps:"
echo "1. Make sure your AWS Security Group allows port $PORT"
echo "2. Try accessing: http://$CURRENT_IP:$PORT"
echo "3. If still not working, check if you're behind a corporate firewall"
echo "4. Try using a different port by restarting the bot"
