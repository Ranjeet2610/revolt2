#!/bin/bash

echo "🧪 Testing Revolt Bot Setup"
echo "=========================="

# Set environment variables
export CHROME_PATH="/usr/bin/chromium-browser"
export NODE_ENV="production"
export AWS_DEPLOYMENT="true"

echo "🚀 Starting bot in background..."
nohup node puppeteer_revolt.js --user testuser --headless=true > bot.log 2>&1 &

# Wait for bot to start
echo "⏳ Waiting for bot to start..."
sleep 5

# Check if bot is running
if pgrep -f "puppeteer_revolt.js" > /dev/null; then
    echo "✅ Bot is running"
    
    # Get the port from the log
    PORT=$(grep "Now listening to:" bot.log | tail -1 | grep -o '[0-9]\+' | tail -1)
    if [ -n "$PORT" ]; then
        echo "✅ Bot is listening on port: $PORT"
        echo "🌐 Try accessing: http://43.205.112.153:$PORT"
        
        # Test local connection
        if curl -s --max-time 5 "http://localhost:$PORT/api/bot_version" > /dev/null; then
            echo "✅ Bot responds locally"
        else
            echo "❌ Bot not responding locally"
        fi
    else
        echo "❌ Could not determine port"
    fi
else
    echo "❌ Bot failed to start"
    echo "📋 Check bot.log for errors:"
    tail -10 bot.log
fi

echo ""
echo "📋 Next steps:"
echo "1. Try accessing: http://43.205.112.153:$PORT"
echo "2. If still not working, check AWS Security Group"
echo "3. Make sure port $PORT is open in AWS Security Group"
