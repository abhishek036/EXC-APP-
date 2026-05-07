module.exports = {
  apps: [
    {
      name: 'excellence-api',
      script: 'dist/server.js',
      instances: 1,               // Single instance on 2GB VPS to avoid RAM pressure
      exec_mode: 'fork',          // Use 'cluster' only when you scale to 4GB+ RAM
      autorestart: true,
      watch: false,
      max_memory_restart: '1200M', // Auto-restart if API leaks past 1.2GB
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      // Graceful shutdown — give open connections 10s to close
      kill_timeout: 10000,
      // Wait 3s after restart before accepting new connections
      wait_ready: false,
      listen_timeout: 8000,
      // Logging
      error_file: './logs/pm2-error.log',
      out_file: './logs/pm2-out.log',
      merge_logs: true,
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      // Restart policy — don't rapid-restart on crash loops
      exp_backoff_restart_delay: 1000,
    },
  ],
};
