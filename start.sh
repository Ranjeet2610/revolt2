#!/bin/bash

echo "=== Revolt Bot Startup Script for Ubuntu/Linux ==="
echo "Checking dependencies..."

# Check if node_modules directory exists
if [ -d "node_modules" ]; then
    echo "✓ node_modules directory exists"
    
    # Check if package-lock.json exists and is newer than package.json
    if [ -f "package-lock.json" ]; then
        echo "✓ package-lock.json exists"
    else
        echo "⚠ package-lock.json missing, reinstalling dependencies..."
        npm install
    fi
else
    echo "⚠ node_modules directory does not exist. Installing dependencies..."
    echo "This may take a few minutes..."
    npm install
    echo "✓ Dependencies installed successfully"
fi

# Check if Chromium is available
if command -v chromium-browser &> /dev/null; then
    echo "✓ Chromium found at: $(which chromium-browser)"
elif command -v chromium &> /dev/null; then
    echo "✓ Chromium found at: $(which chromium)"
elif command -v google-chrome-stable &> /dev/null; then
    echo "✓ Google Chrome found at: $(which google-chrome-stable) (fallback)"
elif command -v google-chrome &> /dev/null; then
    echo "✓ Google Chrome found at: $(which google-chrome) (fallback)"
else
    echo "⚠ Warning: Chromium not found. Please install it for Puppeteer to work properly."
    echo "Install with: sudo apt-get install chromium-browser"
fi

echo ""
echo "Starting Revolt Bot..."
echo "The application will open in your browser at http://localhost:PORT"
echo ""
echo "Chromium will open in visible mode by default for testing."
echo "To run in headless mode, add --headless=true to the command"
echo "Example: ./start.sh --user testuser --headless=true"
echo ""
echo "Press Ctrl+C to stop the application"
echo "=================================="

# Start the application
node puppeteer_revolt.js "$@"
