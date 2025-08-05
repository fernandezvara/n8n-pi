# 🚀 n8n Installer for Raspberry Pi

Automated script to install n8n (workflow automation tool) on Raspberry Pi with a single command line.
No tested on other ubuntu or debian distributions but it should work.

## ✨ Features

- ✅ **Fully automated installation** of n8n and all its dependencies
- 🔧 **Node.js** automatic installation and configuration
- 🌐 **Nginx** as reverse proxy (optional)
- 🔒 **SSL/TLS** with Let's Encrypt (optional)
- 🛡️ **Firewall** automatic configuration with UFW (optional)
- 🔄 **systemd service** for automatic startup
- 🎯 **Optimized for Raspberry Pi** (compatible with Debian/Ubuntu)
- 📝 **Customizable configuration** via parameters

## 🚀 Quick Installation

### Basic installation (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash
```

### With wget

```bash
wget -qO- https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash
```

### Installation with domain and SSL

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- -d tu-dominio.com -s
```

## 🔧 Configuration options

| Option                   | Description                    | Default value |
| ------------------------ | ------------------------------ | ------------- |
| `-h, --help`             | Show help                      | -             |
| `-u, --user USER`        | User to run n8n                | `n8n`         |
| `-p, --port PORT`        | Internal port for n8n          | `5678`        |
| `-d, --domain DOMAIN`    | Domain for SSL                 | -             |
| `-s, --ssl`              | Install SSL with Let's Encrypt | `false`       |
| `--no-nginx`             | Do not install nginx           | `false`       |
| `--no-firewall`          | Do not configure firewall      | `false`       |
| `--node-version VERSION` | Node.js version                | `18`          |

## 📋 Usage examples

### Basic installation

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash
```

- Installs n8n with nginx and firewall
- Accessible at `http://IP_RASPBERRY`

### With custom domain

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- -d my-domain.com
```

- Configures nginx for the specified domain
- Accessible at `http://my-domain.com`

### With SSL/HTTPS automatic

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- -d my-domain.com -s
```

- Installs SSL certificate with Let's Encrypt
- Accessible at `https://my-domain.com`

### User and port customization

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- -u my-user -p 3000
```

- Creates user `my-user`
- n8n running on port `3000`

### Only n8n (without nginx or firewall)

```bash
curl -fsSL https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh | sudo bash -s -- --no-nginx --no-firewall
```

- Minimal n8n installation
- Accessible directly at `http://IP_RASPBERRY:5678`

### Offline installation

```bash
# Download script
wget https://raw.githubusercontent.com/fernandezvara/n8n-pi/main/install-n8n.sh
chmod +x install-n8n.sh

# Run with options
sudo ./install-n8n.sh -d my-domain.com -s
```

## 🏗️ Installation architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Internet      │────│     Nginx       │────│      n8n        │
│   (Port 80/443) │    │  (Reverse Proxy)│    │   (Port 5678)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         │              │   Let's Encrypt │              │
         │              │   (SSL/TLS)     │              │
         │              └─────────────────┘              │
         │                                               │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│      UFW        │    │    Systemd      │    │    SQLite       │
│   (Firewall)    │    │   (Service)     │    │   (Database)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📁 File structure

After installation:

```
/home/n8n/
├── .n8n/
│   ├── .env                # n8n configuration
│   ├── database.sqlite     # Database
│   ├── n8n.log             # Application logs
│   └── nodes/              # Custom nodes
│
/etc/systemd/system/
├── n8n.service             # Systemd service
│
/etc/nginx/sites-available/
├── n8n                     # Nginx configuration
│
/var/log/nginx/
├── n8n_access.log          # Access logs
└── n8n_error.log           # Error logs
```

## 🔧 Post-installation management

### Useful commands

```bash
# service status
sudo systemctl status n8n

# real-time logs
sudo journalctl -u n8n -f

# restart n8n
sudo systemctl restart n8n

# stop n8n
sudo systemctl stop n8n

# start n8n
sudo systemctl start n8n

# disable n8n
sudo systemctl disable n8n
```

### Advanced configuration

The main configuration file is in `/home/n8n/.n8n/.env`:

```bash
# Edit configuration
sudo nano /home/n8n/.n8n/.env

# restart n8n
sudo systemctl restart n8n
```

### Backup and restore

```bash
# create backup
sudo tar -czf n8n-backup-$(date +%Y%m%d).tar.gz -C /home/n8n .n8n/

# restore backup
sudo systemctl stop n8n
sudo tar -xzf n8n-backup-YYYYMMDD.tar.gz -C /home/n8n/
sudo chown -R n8n:n8n /home/n8n/.n8n
sudo systemctl start n8n
```

## 🔒 Security

### SSL/HTTPS

If you installed with `-s`, the certificate will be automatically renewed. To verify:

```bash
# certificate status
sudo certbot certificates

# renew certificate
sudo certbot renew

# test renewal
sudo certbot renew --dry-run
```

### Firewall

The script configures UFW automatically:

```bash
# firewall status
sudo ufw status

# detailed rules
sudo ufw status verbose
```

#### Secure access after execution (allow specific IP)

```bash
sudo ufw allow from 192.168.1.100
```

### Authentication

By default, n8n does not have authentication. To enable basic authentication:

1. Edit `/home/n8n/.n8n/.env`:

```bash
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=your-user
N8N_BASIC_AUTH_PASSWORD=your-password
```

2. Restart n8n:

```bash
sudo systemctl restart n8n
```

## 🚨 Troubleshooting

### n8n does not start

```bash
# Error logs
sudo journalctl -u n8n --no-pager

# Verify configuration
sudo -u n8n n8n --version

# Verify permissions
ls -la /home/n8n/.n8n/
```

### Nginx error

```bash
# nginx configuration
sudo nginx -t

# nginx error logs
sudo tail -f /var/log/nginx/n8n_error.log

# restart nginx
sudo systemctl restart nginx
```

### Connectivity issues

```bash
# open ports
sudo netstat -tlnp | grep -E ':(80|443|5678)'

# firewall status
sudo ufw status

# local connectivity test
curl -I http://localhost:5678
```

### SSL error

```bash
# certificate status
sudo certbot certificates

# certbot logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# renew certificate
sudo certbot renew --force-renewal
```

## 📦 Uninstall

To completely uninstall n8n:

```bash
# stop and disable services
sudo systemctl stop n8n
sudo systemctl disable n8n

# remove system files
sudo rm /etc/systemd/system/n8n.service
sudo rm /etc/nginx/sites-available/n8n
sudo rm /etc/nginx/sites-enabled/n8n

# remove user and data
sudo userdel -r n8n

# uninstall n8n globally
sudo npm uninstall -g n8n

# reload systemd
sudo systemctl daemon-reload

# restart nginx
sudo systemctl restart nginx
```

## 🔄 Update

To update n8n to the latest version:

```bash
# stop service
sudo systemctl stop n8n

# update n8n
sudo npm update -g n8n

# start service
sudo systemctl start n8n

# check version
n8n --version
```

## 🏷️ Compatibility

### Supported operating systems

- ✅ **Raspberry Pi OS** (Bullseye, Bookworm)
- ✅ **Debian** 10+ (Buster, Bullseye, Bookworm)
- ✅ **Ubuntu** 18.04+ (LTS)
- ⚠️ **Other systems** (not tested but may work)

### Minimum hardware requirements

- **RAM**: 1GB minimum, 2GB+ recommended
- **Storage**: 4GB available minimum
- **CPU**: ARM v7+ or x86_64
- **Network**: Internet connection for download and installation

### Software versions

- **Node.js**: v18+ (default v22)
- **npm**: v10+
- **nginx**: v1.14+
- **Python**: v3.6+

## 🤝 Contribute

### Report issues

If you find any issues:

1. Make sure your system is compatible
2. Check the [troubleshooting section](#-troubleshooting)
3. Create an [issue](https://github.com/fernandezvara/n8n-pi/issues) with:
   - System information (`uname -a`, `cat /etc/os-release`)
   - Command executed
   - Full error logs
   - Steps to reproduce the problem

### Improvements and features

Contributions are welcome:

1. Fork the repository
2. Create a branch for your feature (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Create a Pull Request

## 📚 Additional resources

### Official documentation

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community](https://community.n8n.io/)
- [n8n GitHub](https://github.com/n8n-io/n8n)

### Recommended tutorials

- [Getting Started with n8n](https://docs.n8n.io/getting-started/)
- [n8n Workflow Examples](https://n8n.io/workflows/)
- [Advanced n8n Configuration](https://docs.n8n.io/reference/configuration.html)

## 📄 License

This script is available under the [MIT License](LICENSE).

## ❤️ Acknowledgments

- [n8n.io](https://n8n.io/) for creating this incredible tool
- [Raspberry Pi Foundation](https://www.raspberrypi.org/) for the hardware
- [Let's Encrypt](https://letsencrypt.org/) for free SSL
- The open source community for free software

---

**⭐ If this script was useful to you, consider giving the repository a star.**

**🐛 Found a bug? [Report it here](https://github.com/fernandezvara/n8n-pi/issues)**

**💡 Have an idea to improve it? [Share it here](https://github.com/fernandezvara/n8n-pi/discussions)**
