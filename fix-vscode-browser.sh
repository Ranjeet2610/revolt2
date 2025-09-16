#!/bin/bash

echo "=== VS Code Browser Launch Fix ==="
echo "Fixing browser launch issues for VS Code..."

# Check if we're in VS Code
if [ -n "$VSCODE_PID" ] || [ -n "$VSCODE_INJECTION" ]; then
    echo "✅ Detected VS Code environment"
else
    echo "⚠️  Not running in VS Code, but applying fixes anyway"
fi

# Set environment variables for VS Code
export DISPLAY=${DISPLAY:-:0}
export CHROME_PATH="/snap/chromium/current/usr/lib/chromium-browser/chrome"

# Create a wrapper script for Chromium
cat > chromium-wrapper.sh << 'EOF'
#!/bin/bash
# Chromium wrapper for VS Code compatibility
export DISPLAY=${DISPLAY:-:0}
export CHROME_PATH="/snap/chromium/current/usr/lib/chromium-browser/chrome"

# Run Chromium with VS Code-friendly arguments
exec /snap/chromium/current/usr/lib/chromium-browser/chrome \
    --no-sandbox \
    --disable-setuid-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --password-store=basic \
    --use-mock-keychain \
    --disable-extensions \
    --disable-plugins \
    --disable-default-apps \
    --disable-sync \
    --disable-translate \
    --disable-background-networking \
    --disable-client-side-phishing-detection \
    --disable-crash-reporter \
    --disable-oopr-debug-crash-dump \
    --no-crash-upload \
    --disable-gpu-sandbox \
    --disable-software-rasterizer \
    --disable-background-mode \
    "$@"
EOF

chmod +x chromium-wrapper.sh

# Set permissions for snap Chromium
echo "Setting up snap Chromium permissions..."
sudo snap connect chromium:audio-record
sudo snap connect chromium:avahi-observe
sudo snap connect chromium:bluetooth-control
sudo snap connect chromium:camera
sudo snap connect chromium:hardware-observe
sudo snap connect chromium:network-observe
sudo snap connect chromium:password-manager-service
sudo snap connect chromium:removable-media
sudo snap connect chromium:screen-inhibit-control
sudo snap connect chromium:system-observe
sudo snap connect chromium:wayland
sudo snap connect chromium:x11

echo "✅ Snap Chromium permissions configured"

# Create VS Code environment file
cat > .vscode/.env << EOF
DISPLAY=${DISPLAY:-:0}
CHROME_PATH=/snap/chromium/current/usr/lib/chromium-browser/chrome
NODE_ENV=development
EOF

echo "✅ VS Code environment file created"

# Test browser launch
echo "Testing browser launch..."
timeout 10s node -e "
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

(async () => {
  try {
    const browser = await puppeteer.launch({
      executablePath: '/snap/chromium/current/usr/lib/chromium-browser/chrome',
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
    });
    console.log('✅ Browser launch successful!');
    await browser.close();
  } catch (error) {
    console.log('❌ Browser launch failed:', error.message);
    process.exit(1);
  }
})();
" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Browser test passed!"
else
    echo "❌ Browser test failed. Trying alternative approach..."
    
    # Try with Google Chrome if available
    if command -v google-chrome &> /dev/null; then
        echo "Trying with Google Chrome..."
        timeout 10s node -e "
        const puppeteer = require('puppeteer-extra');
        const StealthPlugin = require('puppeteer-extra-plugin-stealth');
        puppeteer.use(StealthPlugin());

        (async () => {
          try {
            const browser = await puppeteer.launch({
              executablePath: '/usr/bin/google-chrome',
              headless: true,
              args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
            });
            console.log('✅ Google Chrome launch successful!');
            await browser.close();
          } catch (error) {
            console.log('❌ Google Chrome launch failed:', error.message);
            process.exit(1);
          }
        })();
        " 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ Google Chrome works! Updating configuration..."
            echo "CHROME_PATH=/usr/bin/google-chrome" > .vscode/.env
        fi
    fi
fi

echo ""
echo "=== Fix Complete! ==="
echo ""
echo "🎯 Next steps:"
echo "1. Restart VS Code"
echo "2. Try running the bot again"
echo "3. If issues persist, run: ./fix-vscode-browser.sh"
echo ""
echo "📁 Files created:"
echo "• chromium-wrapper.sh - Browser wrapper script"
echo "• .vscode/.env - VS Code environment variables"
echo ""
echo "🔧 Environment variables set:"
echo "• DISPLAY=${DISPLAY:-:0}"
echo "• CHROME_PATH=$(cat .vscode/.env | grep CHROME_PATH | cut -d'=' -f2)"
