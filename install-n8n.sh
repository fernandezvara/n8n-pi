#!/bin/bash

# =============================================================================
# n8n Installation Script for Raspberry Pi
# Author: @fernandezvara
# Version: 1.0
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
N8N_USER="n8n"
N8N_HOME="/home/${N8N_USER}"
N8N_PORT="5678"
NODE_VERSION="18"
DOMAIN=""
INSTALL_SSL="false"
NGINX_CONFIG="true"
FIREWALL_CONFIG="true"
TIMEZONE="Europe/Madrid"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Function to display help
show_help() {
    cat << EOF
n8n installation script for Raspberry Pi

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help
    -u, --user USER         User for n8n (default: n8n)
    -p, --port PORT         Port for n8n (default: 5678)
    -d, --domain DOMAIN     Domain to configure SSL
    -s, --ssl               Install and configure SSL with Let's Encrypt
    --no-nginx              Do not install or configure nginx
    --no-firewall           Do not configure firewall
    --node-version VERSION  Node.js version to install (default: 18)

EXAMPLES:
    $0                                    # Basic installation
    $0 -d my-domain.com -s                # With domain and SSL
    $0 -u my-user -p 3000                 # Custom user and port
    $0 --no-nginx --no-firewall           # Only n8n, without nginx or firewall

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--user)
                N8N_USER="$2"
                N8N_HOME="/home/${N8N_USER}"
                shift 2
                ;;
            -p|--port)
                N8N_PORT="$2"
                shift 2
                ;;
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -s|--ssl)
                INSTALL_SSL="true"
                shift
                ;;
            --no-nginx)
                NGINX_CONFIG="false"
                shift
                ;;
            --no-firewall)
                FIREWALL_CONFIG="false"
                shift
                ;;
            --node-version)
                NODE_VERSION="$2"
                shift 2
                ;;
            --timezone)
                TIMEZONE="$2"
                shift 2
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo $0"
    fi
}

# Check operating system
check_system() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine the operating system"
    fi
    
    . /etc/os-release
    
    if [[ "$ID" != "raspbian" && "$ID" != "debian" && "$ID" != "ubuntu" ]]; then
        warn "This script is optimized for Raspberry Pi OS/Debian/Ubuntu"
        read -p "Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# Update system
update_system() {
    log "Updating system..."
    apt update
    apt upgrade -y
}

# Install system dependencies
install_system_dependencies() {
    log "Installing system dependencies..."
    
    local packages=(
        "curl"
        "wget"
        "gnupg2"
        "software-properties-common"
        "build-essential"
        "python3-dev"
        "python3-pip"
        "git"
        "sqlite3"
        "ca-certificates"
        "lsb-release"
    )
    
    if [[ "$NGINX_CONFIG" == "true" ]]; then
        packages+=("nginx")
        if [[ "$INSTALL_SSL" == "true" ]]; then
            packages+=("certbot" "python3-certbot-nginx")
        fi
    fi
    
    if [[ "$FIREWALL_CONFIG" == "true" ]]; then
        packages+=("ufw")
    fi
    
    apt install -y "${packages[@]}"
}

# Create user for n8n
create_n8n_user() {
    log "Creating user ${N8N_USER}..."
    
    if id "$N8N_USER" &>/dev/null; then
        warn "User ${N8N_USER} already exists"
    else
        useradd -m -s /bin/bash "$N8N_USER"
        log "User ${N8N_USER} created successfully"
    fi
}

# Install Node.js
install_nodejs() {
    log "Installing Node.js version ${NODE_VERSION}..."
    
    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    
    # Install Node.js
    apt install -y nodejs
    
    # Verify installation
    local node_version=$(node --version)
    local npm_version=$(npm --version)
    
    log "Node.js ${node_version} installed successfully"
    log "npm ${npm_version} installed successfully"
}

# Install n8n
install_n8n() {
    log "Installing n8n..."
    
    # n8n requires Node.js 16 or higher
    npm install -g n8n
    
    # Verify installation
    local n8n_version=$(n8n --version)
    log "n8n ${n8n_version} installed successfully"
}

# Configure n8n
configure_n8n() {
    log "Configuring n8n..."
    
    # Create configuration directory
    sudo -u "$N8N_USER" mkdir -p "${N8N_HOME}/.n8n"
    
    # Create configuration file
    cat > "${N8N_HOME}/.n8n/.env" << EOF
# n8n configuration
N8N_HOST=0.0.0.0
N8N_PORT=${N8N_PORT}

# Database (SQLite by default)
DB_TYPE=sqlite
DB_SQLITE_DATABASE=${N8N_HOME}/.n8n/database.sqlite

# Data directory
N8N_USER_FOLDER=${N8N_HOME}/.n8n

# Security configuration
N8N_BASIC_AUTH_ACTIVE=false
N8N_JWT_AUTH_ACTIVE=true
N8N_JWT_AUTH_HEADER=authorization
N8N_JWT_AUTH_HEADER_VALUE_PREFIX=Bearer

# Webhook configuration
$(if [[ -n "$DOMAIN" ]]; then
    echo "WEBHOOK_URL=https://${DOMAIN}/"
else
    echo "WEBHOOK_URL=http://$(hostname -I | awk '{print $1}'):${N8N_PORT}/"
fi)

# Log configuration
N8N_LOG_LEVEL=info
N8N_LOG_OUTPUT=file
N8N_LOG_FILE_LOCATION=${N8N_HOME}/.n8n/n8n.log

# Timezone configuration
GENERIC_TIMEZONE=${TIMEZONE}

# Allow running custom code (use with caution)
NODE_FUNCTION_ALLOW_BUILTIN=*
NODE_FUNCTION_ALLOW_EXTERNAL=*

# Performance configuration
N8N_PAYLOAD_SIZE_MAX=1024
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168
EOF
    
    # Set correct permissions
    chown -R "$N8N_USER:$N8N_USER" "${N8N_HOME}/.n8n"
    chmod 600 "${N8N_HOME}/.n8n/.env"
}

# Create systemd service
create_systemd_service() {
    log "Creating systemd service for n8n..."
    
    cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n - Workflow Automation Tool
Documentation=https://docs.n8n.io
After=network.target
Wants=network.target

[Service]
Type=simple
User=${N8N_USER}
Group=${N8N_USER}
WorkingDirectory=${N8N_HOME}
Environment=NODE_ENV=production
EnvironmentFile=${N8N_HOME}/.n8n/.env
ExecStart=/usr/bin/n8n start
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=n8n

# Configuración de seguridad
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${N8N_HOME}/.n8n

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable n8n
}

# Configure nginx
configure_nginx() {
    if [[ "$NGINX_CONFIG" != "true" ]]; then
        return 0
    fi
    
    log "Configuring nginx..."
    
    local server_name="${DOMAIN:-$(hostname -I | awk '{print $1}')}"
    
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name ${server_name};
    
    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:${N8N_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # WebSockets configuration
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 86400;
    }

    # Logs
    access_log /var/log/nginx/n8n_access.log;
    error_log /var/log/nginx/n8n_error.log;
}
EOF
    
    # Enable site and disable default
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Check nginx configuration
    nginx -t
    
    # Enable and restart nginx
    systemctl enable nginx
    systemctl restart nginx
}

# Configure firewall
configure_firewall() {
    if [[ "$FIREWALL_CONFIG" != "true" ]]; then
        return 0
    fi
    
    log "Configuring firewall..."
    
    # Configure UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow ssh
    
    if [[ "$NGINX_CONFIG" == "true" ]]; then
        # Allow HTTP and HTTPS if nginx is configured
        ufw allow 'Nginx Full'
    else
        # Allow n8n port directly if nginx is not present
        ufw allow "$N8N_PORT"
    fi
    
    # Enable firewall
    ufw --force enable
}

# Configure SSL with Let's Encrypt
configure_ssl() {
    if [[ "$INSTALL_SSL" != "true" || "$NGINX_CONFIG" != "true" || -z "$DOMAIN" ]]; then
        return 0
    fi
    
    log "Configuring SSL with Let's Encrypt for ${DOMAIN}..."
    
    # Check that the domain points to this IP
    local domain_ip=$(dig +short "$DOMAIN" | tail -n1)
    local server_ip=$(curl -s ifconfig.me)
    
    if [[ "$domain_ip" != "$server_ip" ]]; then
        warn "The domain ${DOMAIN} does not point to this IP (${server_ip})"
        read -p "Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # Obtain SSL certificate
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email
}

# Start services
start_services() {
    log "Starting services..."
    
    # Start n8n
    systemctl start n8n
    
    # Check status
    if systemctl is-active --quiet n8n; then
        log "n8n service started successfully"
    else
        error "Error starting n8n service"
    fi
    
    if [[ "$NGINX_CONFIG" == "true" ]]; then
        if systemctl is-active --quiet nginx; then
            log "nginx service running correctly"
        else
            error "Error with nginx service"
        fi
    fi
}

# Show final information
show_final_info() {
    local ip_address=$(hostname -I | awk '{print $1}')
    
    echo
    echo "=============================================="
    info " n8n has been installed successfully!"
    echo "=============================================="
    echo
    
    if [[ -n "$DOMAIN" && "$INSTALL_SSL" == "true" ]]; then
        info " Access n8n at: https://${DOMAIN}"
    elif [[ -n "$DOMAIN" ]]; then
        info " Access n8n at: http://${DOMAIN}"
    elif [[ "$NGINX_CONFIG" == "true" ]]; then
        info " Access n8n at: http://${ip_address}"
    else
        info " Access n8n at: http://${ip_address}:${N8N_PORT}"
    fi
    
    echo
    info " Data directory: ${N8N_HOME}/.n8n"
    info " Service user: ${N8N_USER}"
    info " Internal port: ${N8N_PORT}"
    echo
    info " Useful commands:"
    echo "   • Check status: sudo systemctl status n8n"
    echo "   • View logs: sudo journalctl -u n8n -f"
    echo "   • Restart: sudo systemctl restart n8n"
    echo "   • Stop: sudo systemctl stop n8n"
    echo
    
    if [[ "$INSTALL_SSL" != "true" && -n "$DOMAIN" && "$NGINX_CONFIG" == "true" ]]; then
        info "   To enable SSL, run:"
        echo "   sudo certbot --nginx -d ${DOMAIN}"
        echo
    fi
    
    echo "=============================================="
}

# Main function
main() {
    echo "=============================================="
    info " n8n installer for Raspberry Pi"
    echo "=============================================="
    echo
    
    parse_args "$@"
    check_root
    check_system
    
    # Validations
    if [[ "$INSTALL_SSL" == "true" && -z "$DOMAIN" ]]; then
        error "To install SSL you need to specify a domain with -d"
    fi
    
    if [[ "$INSTALL_SSL" == "true" && "$NGINX_CONFIG" != "true" ]]; then
        error "SSL requires nginx. Do not use --no-nginx with -s"
    fi
    
    # Installation process
    update_system
    install_system_dependencies
    create_n8n_user
    install_nodejs
    install_n8n
    configure_n8n
    create_systemd_service
    configure_nginx
    configure_firewall
    configure_ssl
    start_services
    show_final_info
    
    log "✅ Installation completed successfully!"
}

# main function
main "$@"