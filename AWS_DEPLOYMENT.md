# 🚀 Revolt Bot - AWS Deployment Guide

This guide will help you deploy your Revolt bot to AWS EC2 instances with full automation and monitoring.

## 📋 Prerequisites

- AWS Account with EC2 access
- Basic knowledge of AWS EC2
- SSH access to your AWS instance

## 🛠️ AWS Instance Setup

### 1. **Launch EC2 Instance**

**Recommended Instance Configuration:**
- **Instance Type**: `t3.medium` or larger (2+ GB RAM required)
- **OS**: Ubuntu 22.04 LTS
- **Storage**: 20+ GB (for Chromium + dependencies)
- **Security Group**: Allow ports 22 (SSH), 3000-50000 (Bot dashboard)

### 2. **Security Group Configuration**

Create a security group with these rules:
```
Type: SSH
Protocol: TCP
Port: 22
Source: Your IP

Type: Custom TCP
Protocol: TCP
Port: 3000-50000
Source: 0.0.0.0/0 (or restrict to your IP)
```

## 🚀 Deployment Methods

### Method 1: Direct Deployment (Recommended)

1. **Connect to your AWS instance:**
   ```bash
   ssh -i your-key.pem ubuntu@your-aws-ip
   ```

2. **Clone your repository:**
   ```bash
   git clone https://github.com/yourusername/revolt2.git
   cd revolt2
   ```

3. **Make the AWS startup script executable:**
   ```bash
   chmod +x aws-start.sh
   ```

4. **Run the AWS startup script:**
   ```bash
   ./aws-start.sh your-bot-username
   ```

### Method 2: Docker Deployment

1. **Install Docker on AWS instance:**
   ```bash
   sudo apt update
   sudo apt install docker.io
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker ubuntu
   ```

2. **Build the Docker image:**
   ```bash
   docker build -t revolt-bot .
   ```

3. **Run the container:**
   ```bash
   docker run -d \
     --name revolt-bot \
     -p 3000-50000:3000-50000 \
     -e CHROME_PATH=/usr/bin/chromium-browser \
     -e AWS_DEPLOYMENT=true \
     revolt-bot
   ```

### Method 3: PM2 Process Management

1. **Install PM2 globally:**
   ```bash
   sudo npm install -g pm2
   ```

2. **Start with PM2:**
   ```bash
   pm2 start ecosystem.config.js --env production
   ```

3. **Save PM2 configuration:**
   ```bash
   pm2 save
   pm2 startup
   ```

## 🔧 Configuration

### Environment Variables

Set these environment variables for optimal AWS performance:

```bash
export NODE_ENV=production
export AWS_DEPLOYMENT=true
export CHROME_PATH=/usr/bin/chromium-browser
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

### AWS-Specific Settings

The bot automatically detects:
- ✅ AWS instance public IP
- ✅ Optimal browser paths
- ✅ Headless mode configuration
- ✅ Memory optimization

## 📊 Monitoring & Management

### PM2 Commands

```bash
# Check bot status
pm2 status

# View logs
pm2 logs revolt-bot

# Restart bot
pm2 restart revolt-bot

# Stop bot
pm2 stop revolt-bot

# Monitor resources
pm2 monit
```

### Docker Commands

```bash
# Check container status
docker ps

# View logs
docker logs revolt-bot

# Restart container
docker restart revolt-bot

# Stop container
docker stop revolt-bot
```

## 🌐 Accessing Your Bot

After deployment, your bot will be available at:
```
http://YOUR-AWS-IP:PORT
```

The bot automatically detects and displays the correct IP address in the console output.

## 🔒 Security Considerations

1. **Firewall**: Only open necessary ports
2. **SSH Keys**: Use key-based authentication
3. **Updates**: Keep your instance updated
4. **Monitoring**: Set up CloudWatch alarms
5. **Backups**: Regular data backups

## 🚨 Troubleshooting

### Common Issues

1. **Chromium not found:**
   ```bash
   sudo apt install chromium-browser
   ```

2. **Permission denied:**
   ```bash
   sudo chown -R ubuntu:ubuntu /path/to/bot
   ```

3. **Port already in use:**
   ```bash
   sudo netstat -tulpn | grep :PORT
   sudo kill -9 PID
   ```

4. **Memory issues:**
   - Upgrade to larger instance
   - Check PM2 memory limits
   - Monitor with `htop`

### Logs Location

- **PM2 logs**: `~/.pm2/logs/`
- **Docker logs**: `docker logs revolt-bot`
- **Application logs**: Console output

## 📈 Performance Optimization

### Instance Sizing

| Bot Count | Instance Type | RAM | Storage |
|-----------|---------------|-----|---------|
| 1-2 bots  | t3.medium     | 4GB | 20GB    |
| 3-5 bots  | t3.large      | 8GB | 30GB    |
| 5+ bots   | t3.xlarge     | 16GB| 50GB    |

### Monitoring Setup

1. **CloudWatch Metrics:**
   - CPU utilization
   - Memory usage
   - Network I/O

2. **Alarms:**
   - High CPU (>80%)
   - High Memory (>90%)
   - Bot offline detection

## 🔄 Auto-Scaling (Advanced)

For multiple bots, consider:
- **Auto Scaling Groups**
- **Load Balancers**
- **Container Orchestration** (ECS/EKS)

## 📞 Support

If you encounter issues:
1. Check the logs first
2. Verify security group settings
3. Ensure all dependencies are installed
4. Check instance resources (CPU/Memory)

## 🎯 Quick Start Commands

```bash
# One-line deployment
git clone https://github.com/yourusername/revolt2.git && cd revolt2 && chmod +x aws-start.sh && ./aws-start.sh mybot

# PM2 deployment
npm install -g pm2 && pm2 start ecosystem.config.js

# Docker deployment
docker build -t revolt-bot . && docker run -d -p 3000-50000:3000-50000 --name revolt-bot revolt-bot
```

---

**Your Revolt bot is now ready for AWS deployment! 🎉**
