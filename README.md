# Revolt Bot - Ubuntu/Linux Setup Guide

This project is a Revolt bot application that works on both Windows and Ubuntu/Linux systems.

## 🚀 Quick Start (Recommended)

**Just run this ONE command to get everything working:**

```bash
./run.sh your_username
```

**Examples:**
```bash
./run.sh mybot
./run.sh testuser
./run.sh revolthandler
```

This single command will:
- ✅ Install all dependencies automatically
- ✅ Start the Revolt bot with Chromium
- ✅ Open the web dashboard for configuration

**See [QUICK_START.md](QUICK_START.md) for more details.**

## Prerequisites

### System Requirements
- Node.js (v18 or higher recommended)
- npm (comes with Node.js)
- Chromium browser (recommended) or Google Chrome

### Installing Prerequisites on Ubuntu

```bash
# Update package list
sudo apt update

# Install Node.js and npm
sudo apt install nodejs npm

# Install Chromium (recommended)
sudo apt install chromium-browser

# Alternative: Install Google Chrome (if you prefer)
# wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
# echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
# sudo apt update
# sudo apt install google-chrome-stable
```

## Installation & Setup

### Method 1: Using the Start Script (Recommended)

1. Clone or download the project
2. Navigate to the project directory
3. Make the start script executable and run it:

```bash
chmod +x start.sh
./start.sh --user YOUR_USERNAME
```

The start script will:
- ✅ Check if dependencies are installed
- ✅ Install dependencies if missing
- ✅ Verify Chrome/Chromium installation
- ✅ Start the application

### Method 2: Manual Installation

1. Install dependencies:
```bash
npm install
```

2. Run the application:
```bash
node puppeteer_revolt.js --user YOUR_USERNAME
```

## Usage

### Basic Usage
```bash
./start.sh --user testuser
```

### Command Line Arguments
- `--user`: Required. Specify the username for the bot session
- `--headless`: Optional. Run in headless mode (default: false for testing)

### Example
```bash
./start.sh --user mybot --headless false
```

## Features

- 🤖 Automated Revolt bot with web dashboard
- 🎯 Channel-based response system
- ⚡ Real-time messaging and server management
- 🛡️ Stealth mode with Puppeteer
- 🌐 Web interface for configuration (runs on localhost)
- 📊 Server monitoring and logging

## Troubleshooting

### Common Issues

1. **"Cannot find package" errors**
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

2. **Chromium not found**
   ```bash
   sudo apt install chromium-browser
   ```

3. **Permission denied on start.sh**
   ```bash
   chmod +x start.sh
   ```

4. **Port already in use**
   - The application will automatically find an available port
   - Check the console output for the actual port number
   - Access the web dashboard at `http://localhost:PORT`

### File Structure
```
revolt2/
├── puppeteer_revolt.js    # Main application file
├── start.sh              # Linux startup script
├── start.bat             # Windows startup script
├── package.json          # Dependencies
├── package-lock.json     # Dependency lock file
├── public/               # Web dashboard files
└── README.md            # This file
```

## Windows vs Ubuntu Differences

### Windows
- Uses `start.bat` script
- Chromium path: Auto-detected by Puppeteer
- Process title: Set via `process.title`

### Ubuntu/Linux
- Uses `start.sh` script
- Chromium path: `/usr/bin/chromium-browser`
- Process title: Set via escape sequences

## Support

If you encounter any issues:
1. Check that all prerequisites are installed
2. Verify Chrome/Chromium is available
3. Ensure dependencies are properly installed with `npm install`
4. Check the console output for error messages

## License

This project is for educational purposes. Please respect Revolt's terms of service when using this bot.
