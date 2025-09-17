// =============================================================================
// Revolt Bot - PM2 Ecosystem Configuration
// =============================================================================
// This file configures PM2 for process management on AWS instances
// =============================================================================

module.exports = {
    apps: [
        {
            name: 'revolt-bot',
            script: 'puppeteer_revolt.js',
            args: '--user aws-bot --headless=true',
            instances: 1,
            autorestart: true,
            watch: false,
            max_memory_restart: '1G',
            env: {
                NODE_ENV: 'production',
                AWS_DEPLOYMENT: 'true',
                CHROME_PATH: '/usr/bin/chromium-browser',
                PUPPETEER_SKIP_CHROMIUM_DOWNLOAD: 'true',
                PUPPETEER_EXECUTABLE_PATH: '/usr/bin/chromium-browser'
            },
            env_production: {
                NODE_ENV: 'production',
                AWS_DEPLOYMENT: 'true',
                CHROME_PATH: '/usr/bin/chromium-browser'
            },
            // Logging configuration
            log_file: './logs/revolt-bot.log',
            out_file: './logs/revolt-bot-out.log',
            error_file: './logs/revolt-bot-error.log',
            log_date_format: 'YYYY-MM-DD HH:mm:ss Z',

            // Restart configuration
            min_uptime: '10s',
            max_restarts: 10,
            restart_delay: 4000,

            // Process management
            kill_timeout: 5000,
            wait_ready: true,
            listen_timeout: 10000,

            // Monitoring
            pmx: true,

            // Advanced features
            node_args: '--max-old-space-size=1024',
            ignore_watch: ['node_modules', 'logs', '*.log'],

            // Health monitoring
            health_check_grace_period: 3000,
            health_check_fatal_exceptions: true
        }
    ],

    // Deployment configuration (optional)
    deploy: {
        production: {
            user: 'ubuntu',
            host: 'your-aws-instance-ip',
            ref: 'origin/main',
            repo: 'your-git-repo-url',
            path: '/home/ubuntu/revolt-bot',
            'pre-deploy-local': '',
            'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env production',
            'pre-setup': ''
        }
    }
};
