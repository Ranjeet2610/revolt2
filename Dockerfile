# =============================================================================
# Revolt Bot - Dockerfile for AWS Deployment
# =============================================================================
# This Dockerfile creates a containerized version of the Revolt bot
# optimized for AWS deployment with all necessary dependencies
# =============================================================================

# Use Node.js 18 LTS as base image
FROM node:18-slim

# Set working directory
WORKDIR /app

# Install system dependencies required for Chromium and Puppeteer
RUN apt-get update && apt-get install -y \
    # Chromium browser
    chromium-browser \
    # Additional dependencies for Chromium
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
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
    # Additional utilities
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables for AWS deployment
ENV NODE_ENV=production
ENV AWS_DEPLOYMENT=true
ENV CHROME_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Copy package files
COPY package*.json ./

# Install npm dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application files
COPY . .

# Create directory for bot data
RUN mkdir -p /app/bot-data

# Create non-root user for security
RUN groupadd -r botuser && useradd -r -g botuser -G audio,video botuser \
    && mkdir -p /home/botuser/Downloads \
    && chown -R botuser:botuser /home/botuser \
    && chown -R botuser:botuser /app

# Switch to non-root user
USER botuser

# Expose port range for the application
EXPOSE 3000-50000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/api/bot_version || exit 1

# Default command - start the bot in headless mode
CMD ["node", "puppeteer_revolt.js", "--user", "docker-bot", "--headless=true"]
