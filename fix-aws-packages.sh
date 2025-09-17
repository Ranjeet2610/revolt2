#!/bin/bash

# =============================================================================
# Quick Fix for AWS Package Installation Issues
# =============================================================================
# This script fixes common package installation issues on AWS Ubuntu 22.04
# =============================================================================

echo "🔧 Fixing AWS package installation issues..."

# Update package list
sudo apt update

# Install essential packages first
sudo apt install -y software-properties-common apt-transport-https ca-certificates

# Add universe repository if not present
sudo add-apt-repository universe -y

# Update again
sudo apt update

# Install packages with correct names for Ubuntu 22.04
echo "Installing core packages..."
sudo apt install -y \
    fonts-liberation \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    libxkbcommon0 \
    libgbm1

# Try to install audio packages with fallbacks
echo "Installing audio packages..."
if sudo apt install -y libasound2t64 2>/dev/null; then
    echo "✓ libasound2t64 installed"
elif sudo apt install -y libasound2 2>/dev/null; then
    echo "✓ libasound2 installed (fallback)"
else
    echo "⚠ Could not install audio library, continuing..."
fi

# Install ATK packages
echo "Installing ATK packages..."
sudo apt install -y libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0

# Install Chromium
echo "Installing Chromium..."
sudo apt install -y chromium-browser

echo "✅ Package installation completed!"
echo "You can now run: ./aws-start-simple.sh your-username"
