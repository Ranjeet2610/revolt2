#!/bin/bash

# =============================================================================
# Nginx Proxy Update Script for Revolt Bot
# =============================================================================
# This script updates nginx configuration to handle dynamic bot ports
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NGINX_CONFIG="/etc/nginx/sites-available/revolt-bot"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled/revolt-bot"
NGINX_TEST="/etc/nginx/sites-available/revolt-bot"
BOT_PORT_MIN=49152
BOT_PORT_MAX=50000
DOMAIN="yourdomain.com"

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if port is in valid range
validate_port() {
    local port=$1
    if [[ $port -ge $BOT_PORT_MIN && $port -le $BOT_PORT_MAX ]]; then
        return 0
    else
        return 1
    fi
}

# Function to get active bot ports
get_active_ports() {
    # Get all ports in the range that have active processes
    netstat -tlnp 2>/dev/null | grep -E ":(49[1-9][0-9][0-9]|50000)" | awk '{print $4}' | cut -d: -f2 | sort -n
}

# Function to generate nginx configuration
generate_nginx_config() {
    local active_ports=("$@")
    
    cat > /tmp/revolt-bot-nginx.conf << EOF
# Auto-generated Nginx configuration for Revolt Bot
# Generated on: $(date)
# Active bot ports: ${active_ports[*]}

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    
    # Main server block
    server {
        listen 80;
        server_name $DOMAIN www.$DOMAIN;
        
        # Main bot dashboard (port 1024)
        location / {
            proxy_pass http://127.0.0.1:1024;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
        }
        
        # API endpoints
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://127.0.0.1:1024;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
        
        # Socket.IO support
        location /socket.io/ {
            proxy_pass http://127.0.0.1:1024;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
EOF

    # Add server blocks for each active port
    for port in "${active_ports[@]}"; do
        if validate_port "$port"; then
            cat >> /tmp/revolt-bot-nginx.conf << EOF
    
    # Bot instance on port $port
    server {
        listen 80;
        server_name bot$port.$DOMAIN;
        
        location / {
            proxy_pass http://127.0.0.1:$port;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            proxy_read_timeout 86400;
        }
        
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://127.0.0.1:$port;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
        
        location /socket.io/ {
            proxy_pass http://127.0.0.1:$port;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
EOF
        fi
    done
    
    echo "}" >> /tmp/revolt-bot-nginx.conf
}

# Function to update nginx configuration
update_nginx() {
    local active_ports=("$@")
    
    print_info "Updating nginx configuration..."
    print_info "Active bot ports: ${active_ports[*]}"
    
    # Generate new configuration
    generate_nginx_config "${active_ports[@]}"
    
    # Backup current configuration
    if [[ -f "$NGINX_CONFIG" ]]; then
        cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up current configuration"
    fi
    
    # Install new configuration
    sudo cp /tmp/revolt-bot-nginx.conf "$NGINX_CONFIG"
    print_status "Installed new configuration"
    
    # Test nginx configuration
    if sudo nginx -t; then
        print_status "Nginx configuration test passed"
        
        # Reload nginx
        if sudo systemctl reload nginx; then
            print_status "Nginx reloaded successfully"
        else
            print_error "Failed to reload nginx"
            return 1
        fi
    else
        print_error "Nginx configuration test failed"
        return 1
    fi
    
    # Clean up temporary file
    rm -f /tmp/revolt-bot-nginx.conf
    print_status "Configuration updated successfully"
}

# Function to add a specific port
add_port() {
    local port=$1
    
    if ! validate_port "$port"; then
        print_error "Port $port is not in valid range ($BOT_PORT_MIN-$BOT_PORT_MAX)"
        exit 1
    fi
    
    print_info "Adding port $port to nginx configuration"
    
    # Get current active ports
    local active_ports=($(get_active_ports))
    
    # Add the new port if not already present
    if [[ ! " ${active_ports[@]} " =~ " $port " ]]; then
        active_ports+=("$port")
    fi
    
    update_nginx "${active_ports[@]}"
}

# Function to remove a specific port
remove_port() {
    local port=$1
    
    print_info "Removing port $port from nginx configuration"
    
    # Get current active ports
    local active_ports=($(get_active_ports))
    
    # Remove the port
    local new_ports=()
    for p in "${active_ports[@]}"; do
        if [[ "$p" != "$port" ]]; then
            new_ports+=("$p")
        fi
    done
    
    update_nginx "${new_ports[@]}"
}

# Function to show current status
show_status() {
    print_info "Current nginx proxy status:"
    echo ""
    
    # Show active ports
    local active_ports=($(get_active_ports))
    if [[ ${#active_ports[@]} -gt 0 ]]; then
        print_status "Active bot ports: ${active_ports[*]}"
        echo ""
        print_info "Available URLs:"
        echo "  Main dashboard: http://$DOMAIN"
        for port in "${active_ports[@]}"; do
            echo "  Bot $port: http://bot$port.$DOMAIN"
        done
    else
        print_warning "No active bot ports found"
    fi
    
    echo ""
    print_info "Nginx status:"
    sudo systemctl status nginx --no-pager -l
}

# Main script logic
case "${1:-}" in
    "add")
        if [[ -z "${2:-}" ]]; then
            print_error "Usage: $0 add <port>"
            exit 1
        fi
        add_port "$2"
        ;;
    "remove")
        if [[ -z "${2:-}" ]]; then
            print_error "Usage: $0 remove <port>"
            exit 1
        fi
        remove_port "$2"
        ;;
    "update")
        local active_ports=($(get_active_ports))
        update_nginx "${active_ports[@]}"
        ;;
    "status")
        show_status
        ;;
    *)
        echo "Revolt Bot Nginx Proxy Manager"
        echo "=============================="
        echo ""
        echo "Usage: $0 {add|remove|update|status} [port]"
        echo ""
        echo "Commands:"
        echo "  add <port>    - Add a specific port to nginx configuration"
        echo "  remove <port> - Remove a specific port from nginx configuration"
        echo "  update        - Update nginx configuration with all active ports"
        echo "  status        - Show current status"
        echo ""
        echo "Examples:"
        echo "  $0 add 49152"
        echo "  $0 remove 49152"
        echo "  $0 update"
        echo "  $0 status"
        ;;
esac
