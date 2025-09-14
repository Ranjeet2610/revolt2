# Revolt Bot - AWS EC2 Deployment Guide

This guide will help you deploy your Revolt bot on an AWS EC2 instance with proper configuration, security, and monitoring.

## Prerequisites

- AWS Account
- AWS CLI configured (optional but recommended)
- Domain name (optional, for SSL)

## Quick Start

### Option 1: Automated Deployment (Recommended)

1. **Launch EC2 Instance**
   - Instance Type: `t3.medium` or larger (minimum 2GB RAM)
   - OS: Ubuntu 22.04 LTS
   - Storage: 20GB+ EBS volume
   - Security Group: Allow ports 22, 80, 443, and 3000-6000

2. **Connect to Instance**
   ```bash
   ssh -i revolt_updated.pem ubuntu@13.232.150.98
   ```

3. **Upload and Run Deployment Script**
   ```bash
   # Upload the deployment script
   scp -i revolt_updated.pem deploy-aws.sh ubuntu@13.232.150.98:~/
   
   # Connect to instance
   ssh -i revolt_updated.pem ubuntu@13.232.150.98
   
   # Make executable and run
   chmod +x deploy-aws.sh
   ./deploy-aws.sh [your-domain.com]
   ```

### Option 2: Docker Deployment

1. **Install Docker on EC2**
   ```bash
   sudo apt update
   sudo apt install -y docker.io docker-compose
   sudo systemctl enable docker
   sudo usermod -aG docker $USER
   ```

2. **Deploy with Docker Compose**
   ```bash
   # Clone or upload your code
   git clone https://github.com/Ranjeet2610/revolt2.git
   cd revolt2
   
   # Start services
   docker-compose up -d
   ```

## Manual Setup (Step by Step)

### 1. Launch EC2 Instance

**Recommended Instance Specifications:**
- **Instance Type**: t3.medium (2 vCPU, 4GB RAM) or larger
- **AMI**: Ubuntu Server 22.04 LTS
- **Storage**: 20GB+ GP3 EBS volume
- **Security Group**: 
  - SSH (22) from your IP
  - HTTP (80) from anywhere
  - HTTPS (443) from anywhere
  - Custom TCP (3000-6000) from anywhere (for bot ports)

### 2. Connect and Update System

```bash
# Connect to your instance
ssh -i revolt_updated.pem ubuntu@13.232.150.98

# Update system
sudo apt update && sudo apt upgrade -y
```

### 3. Install Dependencies

```bash
# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install Chromium
sudo apt install -y chromium-browser

# Install Nginx
sudo apt install -y nginx

# Install PM2 for process management
sudo npm install -g pm2
```

### 4. Setup Application

```bash
# Create application directory
sudo mkdir -p /opt/revolt-bot
sudo chown ubuntu:ubuntu /opt/revolt-bot

# Copy your application
scp -r -i your-key.pem . ubuntu@your-instance-ip:/opt/revolt-bot/

# Install dependencies
cd /opt/revolt-bot
npm install --production
```

### 5. Configure Firewall

```bash
# Configure UFW
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000:6000/tcp
sudo ufw --force enable
```

### 6. Create Systemd Service

```bash
sudo tee /etc/systemd/system/revolt-bot.service > /dev/null <<EOF
[Unit]
Description=Revolt Bot Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/revolt-bot
ExecStart=/usr/bin/node puppeteer_revolt.js --user production
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=CHROME_PATH=/usr/bin/chromium-browser

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable revolt-bot
sudo systemctl start revolt-bot
```

### 7. Configure Nginx

```bash
sudo tee /etc/nginx/sites-available/revolt-bot > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:1024;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location /multi {
        proxy_pass http://localhost:49623;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/revolt-bot /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

### 8. Setup SSL (Optional but Recommended)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com --non-interactive --agree-tos --email your-email@domain.com
```

## Monitoring and Maintenance

### Check Service Status

```bash
# Check bot service
sudo systemctl status revolt-bot

# Check Nginx
sudo systemctl status nginx

# Check logs
sudo journalctl -u revolt-bot -f
```

### View Logs

```bash
# Bot logs
sudo journalctl -u revolt-bot -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Restart Services

```bash
# Restart bot
sudo systemctl restart revolt-bot

# Restart Nginx
sudo systemctl restart nginx
```

## Security Considerations

1. **Firewall**: Only open necessary ports
2. **SSL**: Use HTTPS for production
3. **Updates**: Keep system and dependencies updated
4. **Monitoring**: Set up CloudWatch or similar monitoring
5. **Backups**: Regular backups of bot data
6. **Access**: Use SSH keys, disable password authentication

## Troubleshooting

### Common Issues

1. **Bot not starting**: Check logs with `sudo journalctl -u revolt-bot -f`
2. **Port conflicts**: Ensure ports 1024 and 49623 are available
3. **Permission issues**: Check file ownership and permissions
4. **Memory issues**: Increase instance size if needed
5. **Browser issues**: Ensure Chromium is properly installed

### Performance Optimization

1. **Instance Size**: Use t3.medium or larger for production
2. **Memory**: Monitor memory usage, increase if needed
3. **Storage**: Use GP3 EBS volumes for better performance
4. **Load Balancing**: Use Application Load Balancer for high availability

## Cost Optimization

1. **Instance Type**: Start with t3.medium, scale as needed
2. **Reserved Instances**: For long-term usage
3. **Spot Instances**: For non-critical workloads
4. **Auto Scaling**: Scale based on demand

## Access URLs

After deployment, your bot will be accessible at:

- **Main Dashboard**: `http://your-instance-ip` or `https://your-domain.com`
- **Multi Dashboard**: `http://your-instance-ip/multi` or `https://your-domain.com/multi`
- **API**: `http://your-instance-ip/api/` or `https://your-domain.com/api/`

## Support

For issues or questions:
1. Check the logs first
2. Verify all services are running
3. Check firewall and security group settings
4. Ensure all dependencies are installed correctly
