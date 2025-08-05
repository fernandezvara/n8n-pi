# 📝 Usage Examples - n8n Installer

This document contains practical examples for different installation scenarios.

## 🏠 Basic Home Usage

For personal use on a local network:

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash
```

**Result:**

- n8n accessible at `http://192.168.1.XXX`
- Local SQLite database
- Basic security configuration
- Automatic startup with systemd

## 🌍 Public Server with Domain

To make n8n accessible from the internet:

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- -d n8n.my-domain.com -s
```

**Preliminary steps:**

1. Register a domain and point it to your public IP
2. Configure port forwarding on your router (ports 80 and 443)
3. Open ports in your router's firewall

**Result:**

- n8n accessible at `https://n8n.my-domain.com`
- Automatic SSL certificate
- Automatic certificate renewal

## 🏢 Enterprise Installation

For enterprise environments with advanced configuration:

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- \
  -d workflows.company.com \
  -s \
  -u n8n-prod \
  -p 3000 \
  --node-version 20
```

**Post-installation configuration:**

```bash
# Configure authentication
sudo nano /home/n8n-prod/.n8n/.env
# Add:
# N8N_BASIC_AUTH_ACTIVE=true
# N8N_BASIC_AUTH_USER=admin
# N8N_BASIC_AUTH_PASSWORD=secure-password

# Configure PostgreSQL database (optional)
# DB_TYPE=postgresdb
# DB_POSTGRESDB_HOST=localhost
# DB_POSTGRESDB_PORT=5432
# DB_POSTGRESDB_DATABASE=n8n
# DB_POSTGRESDB_USER=n8n
# DB_POSTGRESDB_PASSWORD=password

sudo systemctl restart n8n
```

## 🔬 Development and Testing

For development environments without additional services:

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- \
  --no-nginx \
  --no-firewall \
  -u developer \
  -p 5678
```

**Result:**

- n8n accessible directly at `http://IP:5678`
- No nginx proxy
- No firewall configuration
- Ideal for local development

## 📱 Minimal Installation for IoT

For devices with limited resources:

```bash
# Minimal version without additional services
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- \
  --no-nginx \
  --no-firewall \
  --node-version 16
```

**Additional optimizations:**

```bash
# Limit Node.js memory
echo 'NODE_OPTIONS="--max-old-space-size=512"' | sudo tee -a /home/n8n/.n8n/.env

# Configure data retention
echo 'EXECUTIONS_DATA_MAX_AGE=24' | sudo tee -a /home/n8n/.n8n/.env
echo 'EXECUTIONS_DATA_PRUNE=true' | sudo tee -a /home/n8n/.n8n/.env

sudo systemctl restart n8n
```

## 🔒 Installation with Maximum Security

For environments that require high security:

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- \
  -d secure-n8n.company.com \
  -s \
  -u n8n-secure
```

**Additional security configuration:**

```bash
# Configure JWT authentication
sudo tee -a /home/n8n-secure/.n8n/.env << 'EOF'
N8N_JWT_AUTH_ACTIVE=true
N8N_JWT_AUTH_HEADER=authorization
N8N_JWT_AUTH_HEADER_VALUE_PREFIX=Bearer
N8N_JWT_SECRET=your-jwt-secret

# Disable custom code execution
NODE_FUNCTION_ALLOW_BUILTIN=
NODE_FUNCTION_ALLOW_EXTERNAL=

# Configure HTTPS
N8N_PROTOCOL=https
N8N_HOST=secure-n8n.company.com
EOF

# Configure nginx with security headers
sudo tee /etc/nginx/snippets/security-headers.conf << 'EOF'
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'";
EOF

# Add include to nginx configuration
sudo sed -i '/server_name/a\    include /etc/nginx/snippets/security-headers.conf;' /etc/nginx/sites-available/n8n

sudo systemctl restart n8n nginx
```

## 🌐 Multi-domain with Subdirectories

To serve n8n in a subdirectory:

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- \
  -d my-server.com \
  -s \
  -p 5678
```

**Configure nginx for subdirectory:**

```bash
sudo tee /etc/nginx/sites-available/n8n << 'EOF'
server {
    listen 443 ssl http2;
    server_name my-server.com;

    # SSL configuration...

    location /n8n/ {
        proxy_pass http://127.0.0.1:5678/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Rewrite paths for subdirectory
        proxy_redirect / /n8n/;
    }
}
EOF

# Configure n8n for subdirectory
echo 'N8N_PATH=/n8n' | sudo tee -a /home/n8n/.n8n/.env

sudo systemctl restart nginx n8n
```

## 🔄 Installation with Automatic Backup

Script with automatic backup configuration:

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- \
  -d n8n.my-domain.com \
  -s
```

**Configure automatic backup:**

```bash
# Create backup script
sudo tee /usr/local/bin/n8n-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/n8n"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

# Create backup
systemctl stop n8n
tar -czf "$BACKUP_FILE" -C /home/n8n .n8n/
systemctl start n8n

# Keep only the last 7 backups
find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -type f -mtime +7 -delete

echo "Backup created: $BACKUP_FILE"
EOF

sudo chmod +x /usr/local/bin/n8n-backup.sh

# Configure cron for daily backup
echo "0 2 * * * root /usr/local/bin/n8n-backup.sh" | sudo tee -a /etc/crontab
```

## 🔧 Installation with Custom Configuration

For specific use cases with advanced configuration:

```bash
# Download and modify script
wget https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh
chmod +x install-n8n.sh

# Modify variables if necessary
nano install-n8n.sh

# Run with custom configuration
sudo ./install-n8n.sh -d my-domain.com -s -u n8n-custom -p 4000
```

**Example of custom configuration in .env:**

```bash
# After installation, modify configuration
sudo tee /home/n8n-custom/.n8n/.env << 'EOF'
# Basic configuration
N8N_HOST=0.0.0.0
N8N_PORT=4000
N8N_PROTOCOL=https
N8N_HOST=my-domain.com

# Database
DB_TYPE=sqlite
DB_SQLITE_DATABASE=/home/n8n-custom/.n8n/database.sqlite

# Workflow configuration
EXECUTIONS_TIMEOUT=3600
EXECUTIONS_TIMEOUT_MAX=7200
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_SAVE_ON_PROGRESS=false

# Log configuration
N8N_LOG_LEVEL=debug
N8N_LOG_OUTPUT=console,file
N8N_LOG_FILE_LOCATION=/home/n8n-custom/.n8n/n8n.log
N8N_LOG_FILE_COUNT_MAX=3
N8N_LOG_FILE_SIZE_MAX=16777216

# Email configuration (SMTP)
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=smtp.gmail.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=your-email@gmail.com
N8N_SMTP_PASS=your-app-password
N8N_SMTP_SENDER=your-email@gmail.com

# Webhook configuration
WEBHOOK_URL=https://my-domain.com/
N8N_PAYLOAD_SIZE_MAX=16777216

# Timezone configuration
GENERIC_TIMEZONE=Europe/Madrid
EOF

sudo systemctl restart n8n
```

## 📊 Monitoring and Metrics

Configuration for advanced monitoring:

```bash
# Install n8n with basic configuration
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- \
  -d n8n-monitor.my-domain.com \
  -s
```

**Configure metrics:**

```bash
# Enable Prometheus metrics
echo 'N8N_METRICS=true' | sudo tee -a /home/n8n/.n8n/.env
echo 'N8N_METRICS_PREFIX=n8n_' | sudo tee -a /home/n8n/.n8n/.env

# Configure health check endpoint
echo 'N8N_DIAGNOSTICS_ENABLED=true' | sudo tee -a /home/n8n/.n8n/.env

sudo systemctl restart n8n

# Verify available metrics
curl http://localhost:5678/metrics
curl http://localhost:5678/healthz
```

These examples cover the most common use cases. You can combine different options according to your specific needs.
