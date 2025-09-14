#!/bin/bash

# =============================================================================
# EC2 User Data Script for Revolt Bot
# =============================================================================
# This script runs when the EC2 instance starts
# Add this as user data when launching the instance
# =============================================================================

# Update system
apt update && apt upgrade -y

# Install dependencies
apt install -y curl wget git build-essential software-properties-common

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Install Chromium
apt install -y chromium-browser

# Install Nginx
apt install -y nginx

# Install PM2
npm install -g pm2

# Create bot user
useradd -m -s /bin/bash revoltbot
usermod -aG sudo revoltbot

# Create application directory
mkdir -p /opt/revolt-bot
chown revoltbot:revoltbot /opt/revolt-bot

# Configure firewall
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 49152:50000/tcp
ufw --force enable

# Create systemd service for main bot
cat > /etc/systemd/system/revolt-bot.service << 'EOF'
[Unit]
Description=Revolt Bot Main Service
After=network.target

[Service]
Type=simple
User=revoltbot
WorkingDirectory=/opt/revolt-bot
ExecStart=/usr/bin/node puppeteer_revolt.js --user production
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=CHROME_PATH=/usr/bin/chromium-browser
Environment=NODE_OPTIONS=--max-old-space-size=4096
Environment=UV_THREADPOOL_SIZE=128

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service template for dynamic bot instances
cat > /etc/systemd/system/revolt-bot@.service << 'EOF'
[Unit]
Description=Revolt Bot Instance %i
After=network.target

[Service]
Type=simple
User=revoltbot
WorkingDirectory=/opt/revolt-bot
ExecStart=/usr/bin/node puppeteer_revolt.js --user %i
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=CHROME_PATH=/usr/bin/chromium-browser
Environment=NODE_OPTIONS=--max-old-space-size=4096
Environment=UV_THREADPOOL_SIZE=128

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx for dynamic ports
cat > /etc/nginx/sites-available/revolt-bot << 'EOF'
# Dynamic port configuration for Revolt Bot
# This configuration supports multiple bot instances on ports 49152-50000

# Upstream for main bot (port 1024)
upstream main_bot {
    server 127.0.0.1:1024;
}

# Upstream for dynamic bot instances
upstream dynamic_bots {
    # This will be dynamically updated by update-nginx-proxy.sh
    server 127.0.0.1:49152;
}

server {
    listen 80;
    server_name _;
    
    # Main bot dashboard
    location / {
        proxy_pass http://main_bot;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Dynamic bot instances (subdomain-based routing)
    location ~ ^/bot/([a-zA-Z0-9-]+)/? {
        set $bot_name $1;
        proxy_pass http://127.0.0.1:49152;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable Nginx site
ln -s /etc/nginx/sites-available/revolt-bot /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Install dynamic proxy management script
cat > /usr/local/bin/update-nginx-proxy.sh << 'EOF'
#!/bin/bash

# Dynamic Nginx Proxy Update Script for Revolt Bot
# This script updates Nginx configuration when bot instances are added/removed

NGINX_CONFIG="/etc/nginx/sites-available/revolt-bot"
TEMP_CONFIG="/tmp/nginx-revolt-temp.conf"
BOT_DIR="/opt/revolt-bot"

# Function to get active bot ports
get_active_ports() {
    # Find all running bot processes and extract their ports
    ps aux | grep "puppeteer_revolt.js" | grep -v grep | while read line; do
        # Extract port from the process arguments or log files
        echo "$line" | grep -o "localhost:[0-9]*" | cut -d: -f2
    done | sort -n | uniq
}

# Function to update Nginx configuration
update_nginx_config() {
    local ports=($(get_active_ports))
    
    # Create temporary configuration
    cat > "$TEMP_CONFIG" << 'NGINX_EOF'
# Dynamic port configuration for Revolt Bot
# This configuration supports multiple bot instances on ports 49152-50000

# Upstream for main bot (port 1024)
upstream main_bot {
    server 127.0.0.1:1024;
}

# Upstream for dynamic bot instances
upstream dynamic_bots {
NGINX_EOF

    # Add active bot ports to upstream
    for port in "${ports[@]}"; do
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 49152 ] && [ "$port" -le 50000 ]; then
            echo "    server 127.0.0.1:$port;" >> "$TEMP_CONFIG"
        fi
    done
    
    # Add default server if no active bots
    if [ ${#ports[@]} -eq 0 ]; then
        echo "    server 127.0.0.1:49152;" >> "$TEMP_CONFIG"
    fi
    
    cat >> "$TEMP_CONFIG" << 'NGINX_EOF'
}

server {
    listen 80;
    server_name _;
    
    # Main bot dashboard
    location / {
        proxy_pass http://main_bot;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Dynamic bot instances (path-based routing)
    location ~ ^/bot/([a-zA-Z0-9-]+)/? {
        set $bot_name $1;
        proxy_pass http://dynamic_bots;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
NGINX_EOF

    # Test configuration
    if nginx -t -c "$TEMP_CONFIG"; then
        # Backup current config
        cp "$NGINX_CONFIG" "$NGINX_CONFIG.backup.$(date +%s)"
        
        # Replace configuration
        mv "$TEMP_CONFIG" "$NGINX_CONFIG"
        
        # Reload Nginx
        systemctl reload nginx
        
        echo "Nginx configuration updated successfully at $(date)"
        echo "Active bot ports: ${ports[*]}"
    else
        echo "Error: Invalid Nginx configuration generated"
        rm -f "$TEMP_CONFIG"
        exit 1
    fi
}

# Main execution
case "$1" in
    "update")
        update_nginx_config
        ;;
    "status")
        echo "Active bot ports: $(get_active_ports | tr '\n' ' ')"
        ;;
    *)
        echo "Usage: $0 {update|status}"
        exit 1
        ;;
esac
EOF

# Make script executable
chmod +x /usr/local/bin/update-nginx-proxy.sh

# Create cron job to update proxy every minute
echo "* * * * * /usr/local/bin/update-nginx-proxy.sh update >> /var/log/nginx-proxy.log 2>&1" | crontab -

# Create bot management script
cat > /usr/local/bin/revolt-bot-manager.sh << 'EOF'
#!/bin/bash

# Revolt Bot Management Script
# Usage: revolt-bot-manager.sh {start|stop|restart|status|list} [bot_name]

BOT_DIR="/opt/revolt-bot"
SERVICE_PREFIX="revolt-bot"

# Function to start a bot instance
start_bot() {
    local bot_name="$1"
    if [ -z "$bot_name" ]; then
        echo "Error: Bot name required"
        exit 1
    fi
    
    echo "Starting bot instance: $bot_name"
    systemctl start "${SERVICE_PREFIX}@${bot_name}.service"
    systemctl enable "${SERVICE_PREFIX}@${bot_name}.service"
    
    # Update nginx proxy
    /usr/local/bin/update-nginx-proxy.sh update
}

# Function to stop a bot instance
stop_bot() {
    local bot_name="$1"
    if [ -z "$bot_name" ]; then
        echo "Error: Bot name required"
        exit 1
    fi
    
    echo "Stopping bot instance: $bot_name"
    systemctl stop "${SERVICE_PREFIX}@${bot_name}.service"
    systemctl disable "${SERVICE_PREFIX}@${bot_name}.service"
    
    # Update nginx proxy
    /usr/local/bin/update-nginx-proxy.sh update
}

# Function to restart a bot instance
restart_bot() {
    local bot_name="$1"
    if [ -z "$bot_name" ]; then
        echo "Error: Bot name required"
        exit 1
    fi
    
    echo "Restarting bot instance: $bot_name"
    systemctl restart "${SERVICE_PREFIX}@${bot_name}.service"
    
    # Update nginx proxy
    /usr/local/bin/update-nginx-proxy.sh update
}

# Function to show bot status
show_status() {
    local bot_name="$1"
    if [ -z "$bot_name" ]; then
        echo "All bot instances status:"
        systemctl status "${SERVICE_PREFIX}@*.service" --no-pager
    else
        echo "Bot instance '$bot_name' status:"
        systemctl status "${SERVICE_PREFIX}@${bot_name}.service" --no-pager
    fi
}

# Function to list all bot instances
list_bots() {
    echo "Active bot instances:"
    systemctl list-units --type=service | grep "${SERVICE_PREFIX}@" | awk '{print $1}' | sed "s/${SERVICE_PREFIX}@//g" | sed 's/.service//g'
    
    echo ""
    echo "Active bot ports:"
    /usr/local/bin/update-nginx-proxy.sh status
}

# Main execution
case "$1" in
    "start")
        start_bot "$2"
        ;;
    "stop")
        stop_bot "$2"
        ;;
    "restart")
        restart_bot "$2"
        ;;
    "status")
        show_status "$2"
        ;;
    "list")
        list_bots
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|list} [bot_name]"
        echo ""
        echo "Examples:"
        echo "  $0 start mybot          # Start bot instance 'mybot'"
        echo "  $0 stop mybot           # Stop bot instance 'mybot'"
        echo "  $0 restart mybot        # Restart bot instance 'mybot'"
        echo "  $0 status mybot         # Show status of 'mybot'"
        echo "  $0 status               # Show status of all bots"
        echo "  $0 list                 # List all active bot instances"
        exit 1
        ;;
esac
EOF

# Make management script executable
chmod +x /usr/local/bin/revolt-bot-manager.sh

# Enable and start services
systemctl daemon-reload
systemctl enable revolt-bot
systemctl enable nginx

# Start Nginx
systemctl start nginx

# Create a dynamic status page
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Revolt Bot - Dynamic Port Server</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .container { max-width: 800px; margin: 0 auto; }
        .status { background: #f0f0f0; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .success { background: #d4edda; color: #155724; }
        .warning { background: #fff3cd; color: #856404; }
        .info { background: #d1ecf1; color: #0c5460; }
        .code { background: #f8f9fa; padding: 10px; border-radius: 3px; font-family: monospace; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🤖 Revolt Bot Dynamic Server</h1>
        
        <div class="status info">
            <h2>Dynamic Port Configuration</h2>
            <p>This server supports multiple bot instances running on ports <strong>49152-50000</strong></p>
            <p>Each bot instance gets a dynamically assigned port for optimal resource management</p>
        </div>
        
        <div class="grid">
            <div class="status warning">
                <h3>Setup Required</h3>
                <p>Upload your bot code to <code>/opt/revolt-bot/</code></p>
                <p>Start main bot: <code>sudo systemctl start revolt-bot</code></p>
            </div>
            
            <div class="status success">
                <h3>System Ready</h3>
                <p>All dependencies installed</p>
                <p>Dynamic proxy configured</p>
            </div>
        </div>
        
        <div class="status info">
            <h3>Bot Management Commands</h3>
            <div class="code">
                # Start a new bot instance<br>
                sudo revolt-bot-manager.sh start mybot<br><br>
                
                # Stop a bot instance<br>
                sudo revolt-bot-manager.sh stop mybot<br><br>
                
                # List all active bots<br>
                sudo revolt-bot-manager.sh list<br><br>
                
                # Check bot status<br>
                sudo revolt-bot-manager.sh status
            </div>
        </div>
        
        <div class="status success">
            <h3>Access Points</h3>
            <p><strong>Main Dashboard:</strong> <a href="/">http://your-domain/</a></p>
            <p><strong>Bot Instances:</strong> <a href="/bot/mybot/">http://your-domain/bot/mybot/</a></p>
            <p><strong>Health Check:</strong> <a href="/health">http://your-domain/health</a></p>
        </div>
    </div>
</body>
</html>
EOF

# Log completion
echo "Revolt Bot server setup completed at $(date)" >> /var/log/revolt-setup.log
