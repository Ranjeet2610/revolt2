#!/bin/bash

# =============================================================================
# Open Revolt in Local Browser
# =============================================================================
# This script opens Revolt in your local browser for testing
# =============================================================================

echo "🌐 Opening Revolt in your local browser..."

# Try to open Revolt in different browsers
if command -v google-chrome &> /dev/null; then
    google-chrome --new-window "https://revolt.onech.at/" &
    echo "✅ Opened Revolt in Google Chrome"
elif command -v firefox &> /dev/null; then
    firefox --new-window "https://revolt.onech.at/" &
    echo "✅ Opened Revolt in Firefox"
elif command -v chromium-browser &> /dev/null; then
    chromium-browser --new-window "https://revolt.onech.at/" &
    echo "✅ Opened Revolt in Chromium"
else
    echo "❌ No supported browser found"
    echo "Please manually open: https://revolt.onech.at/"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Log in to your Revolt account"
echo "2. The bot will automatically connect once you're logged in"
echo "3. Check the bot dashboard for connection status"
