# 🚀 Universal Frappe/ERPNext Deployment Package

Professional deployment solution for Frappe/ERPNext projects with backup restore capabilities.

## 📋 Features

- ✅ Universal deployment script for any Frappe/ERPNext project
- ✅ Flexible app configuration (ERPNext, HRMS, custom apps)
- ✅ Optional backup restore
- ✅ Production-ready setup (Nginx, Supervisor)
- ✅ All lessons learned from production deployments
- ✅ Senior DevOps best practices

## 🎯 Quick Start

### 1. Setup Configuration

```bash
# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

### 2. Configure Your Project

**Required settings in `.env`:**

```bash
SITE_NAME="mysite.local"
FRAPPE_VERSION="version-15"
MARIADB_ROOT_PASSWORD="YourSecurePassword123!"
ADMIN_PASSWORD="admin"
APPS_TO_INSTALL="frappe,erpnext,hrms"
```

### 3. (Optional) Add Backup Files

If you need to restore from backup:

```bash
# Copy backup files to backups/ folder
cp your-backup.sql.gz backups/
cp site_config_backup.json backups/

# Enable in .env
RESTORE_BACKUP="true"
SQL_BACKUP_FILE="your-backup.sql.gz"
CONFIG_BACKUP_FILE="site_config_backup.json"
```

### 4. Deploy to Server

```bash
# Upload to server
scp -r frappe_deployment root@your-server-ip:/root/

# SSH to server
ssh root@your-server-ip

# Run deployment
cd /root/frappe_deployment
chmod +x deploy/deploy.sh
./deploy/deploy.sh
```

## 📦 Project Structure

```
frappe_deployment/
├── .env.example              # Configuration template
├── README.md                 # This file
├── deploy/
│   ├── deploy.sh            # Main deployment script
│   └── README.md            # Deployment details
├── backups/                 # Backup files (git ignored)
│   ├── .gitignore
│   └── .gitkeep
```

## 🔧 Configuration Guide

### Basic Configuration

**For a simple Frappe site:**
```bash
APPS_TO_INSTALL="frappe"
```

**For ERPNext:**
```bash
APPS_TO_INSTALL="frappe,erpnext"
```

**For ERPNext + HRMS:**
```bash
APPS_TO_INSTALL="frappe,erpnext,hrms"
```

**With custom app:**
```bash
APPS_TO_INSTALL="frappe,erpnext,hrms,my_custom_app"
CUSTOM_APP_REPO="https://github.com/user/my_custom_app.git"
```

### Advanced Configuration

**Multiple custom apps:**
```bash
# Edit deploy.sh and add your custom logic
# Or run multiple deployments
```

**Development mode:**
```bash
DEVELOPER_MODE="true"
```

**With SSL (after domain setup):**
```bash
SETUP_SSL="true"
SSL_DOMAIN="yourdomain.com"
SSL_EMAIL="admin@yourdomain.com"
```

## 🎓 Use Cases

### Case 1: New Empty Site

```bash
# .env configuration
SITE_NAME="newsite.local"
APPS_TO_INSTALL="frappe,erpnext"
RESTORE_BACKUP="false"
```

### Case 2: Restore from Backup

```bash
# .env configuration
SITE_NAME="oldsite.local"
APPS_TO_INSTALL="frappe,erpnext,hrms"
RESTORE_BACKUP="true"
SQL_BACKUP_FILE="database-backup.sql.gz"
CONFIG_BACKUP_FILE="site_config_backup.json"
```

### Case 3: Custom App Only

```bash
# .env configuration
APPS_TO_INSTALL="frappe,my_custom_app"
CUSTOM_APP_REPO="https://github.com/mycompany/my_custom_app.git"
RESTORE_BACKUP="false"
```

## 🐛 Troubleshooting

### Permission Issues

```bash
# Check nginx can read files
sudo -u www-data ls /home/frappe/frappe-bench/sites/assets/

# Fix permissions
sudo chmod 755 /home/frappe
sudo chmod -R 755 /home/frappe/frappe-bench/sites
```

### Static Files Not Loading

```bash
# Rebuild assets
su - frappe
cd ~/frappe-bench
bench build --force
exit
sudo supervisorctl restart all
```

### Database Connection Error

```bash
# Check MariaDB
sudo systemctl status mariadb

# Test connection
mysql -u root -p
```

### Nginx Not Starting

```bash
# Test config
sudo nginx -t

# Check logs
sudo tail -f /var/log/nginx/error.log
```

## 📊 Server Requirements

- **OS:** Ubuntu 20.04, 22.04, or 24.04 (recommended)
- **RAM:** Minimum 2GB, recommended 4GB+
- **CPU:** Minimum 2 cores
- **Disk:** Minimum 20GB, recommended 40GB+
- **Network:** Stable internet connection

## 🔐 Security Checklist

After deployment:

- [ ] Change Administrator password
- [ ] Setup firewall (UFW)
- [ ] Configure SSL certificate
- [ ] Setup automatic backups
- [ ] Disable developer mode in production
- [ ] Review user permissions
- [ ] Enable fail2ban (optional)

## 📞 Support

For issues or questions:
1. Check logs: `bench --site yoursite.local logs`
2. Supervisor status: `sudo supervisorctl status`
3. Nginx logs: `/var/log/nginx/error.log`

## 📝 Changelog

### v2.0 (2025-11-01)
- ✅ Ubuntu 24.04 support
- ✅ Fixed pip externally-managed error
- ✅ Added Redis auto-configuration
- ✅ Fixed nginx permissions issue
- ✅ Added flexible app configuration
- ✅ Optional backup restore

### v1.0 (2025-10-31)
- Initial release

## 📄 License

MIT License - Free to use for personal and commercial projects

---

**Made with ❤️ by Senior DevOps Engineers**
