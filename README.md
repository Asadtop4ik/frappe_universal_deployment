# 🚀 Universal Frappe/ERPNext Deployment Package

Professional deployment solution for Frappe/ERPNext projects with CI/CD, domain setup, and backup restore capabilities.

## 📋 Features

- ✅ Universal deployment script for any Frappe/ERPNext project
- ✅ Flexible app configuration (ERPNext, HRMS, custom apps)
- ✅ **GitHub Actions CI/CD template** (automatic deployment)
- ✅ **Domain & SSL setup** (Let's Encrypt)
- ✅ **DigitalOcean UI guide** (step-by-step)
- ✅ Optional backup restore
- ✅ Production-ready setup (Nginx, Supervisor)
- ✅ All lessons learned from production deployments
- ✅ Senior DevOps best practices

## 🎯 Quick Start (Manual Deploy)

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
scp -r frappe_universal_deploy root@your-server-ip:/root/

# SSH to server
ssh root@your-server-ip

# Run deployment
cd /root/frappe_universal_deploy
chmod +x deploy/deploy.sh
./deploy/deploy.sh
```

---

## 🤖 CI/CD Setup (Automatic Deployment)

**GitHub Actions orqali avtomatik deploy!**

### Quick Setup:

```bash
# 1. Copy workflow template to your Frappe app
cp templates/github-workflow.yml your-app/.github/workflows/deploy.yml

# 2. GitHub Secrets configure qiling:
#    - SSH_PRIVATE_KEY
#    - SERVER_IP
#    - SITE_NAME
#    - DB_PASSWORD
#    - ADMIN_PASSWORD

# 3. Push to main branch
git push origin main
# → Avtomatik deploy bo'ladi! 🚀
```

**📚 Batafsil guide:** [CI_CD_SETUP.md](CI_CD_SETUP.md)

---

## 🌐 Domain & SSL Setup

**Domain ulash va HTTPS yoqish:**

### Option 1: Initial Deploy bilan

```bash
# .env da
SITE_NAME="akfa.uz"          # .local o'rniga real domain
SETUP_SSL="true"
SSL_DOMAIN="akfa.uz"
SSL_EMAIL="admin@akfa.uz"

# Deploy qiling - avtomatik SSL o'rnatiladi
```

### Option 2: Existing Site ga

```bash
# Server ga SSH qiling
ssh root@your-server-ip

# Domain setup script ishga tushiring
./setup-domain.sh
# Interactive prompts follow...
```

**📚 Batafsil guide:** [DIGITALOCEAN_SETUP.md](DIGITALOCEAN_SETUP.md) - Section 4

---

## 📦 Project Structure

```
frappe_deployment/
├── .env.example              # Configuration template
├── README.md                 # This file
├── DIGITALOCEAN_SETUP.md     # DigitalOcean UI guide (NEW!)
├── CI_CD_SETUP.md            # GitHub Actions guide (NEW!)
├── DEPLOYMENT_WORKFLOW.md    # Real-world workflow
├── deploy/
│   ├── deploy.sh            # Main deployment script
│   └── README.md            # Deployment details
├── templates/
│   └── github-workflow.yml  # CI/CD template (NEW!)
├── setup-domain.sh          # Domain & SSL setup (NEW!)
└── backups/                 # Backup files (git ignored)
    ├── .gitignore
    └── .gitkeep
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
## 📚 Documentation

- **[DIGITALOCEAN_SETUP.md](DIGITALOCEAN_SETUP.md)** - DigitalOcean UI orqali server yaratish, firewall, domain sozlash
- **[CI_CD_SETUP.md](CI_CD_SETUP.md)** - GitHub Actions avtomatik deployment setup
- **[DEPLOYMENT_WORKFLOW.md](DEPLOYMENT_WORKFLOW.md)** - Real-world deployment scenario
- **[deploy/README.md](deploy/README.md)** - Deploy script batafsil ma'lumot
- **[APP_README_TEMPLATE.md](APP_README_TEMPLATE.md)** - Custom app uchun README template

---

## 🎓 Usage Examples

### Case 1: Fresh Installation

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

### Case 4: Production with Domain & SSL

```bash
# .env configuration
SITE_NAME="erp.company.com"
APPS_TO_INSTALL="frappe,erpnext,hrms,custom_app"
SETUP_SSL="true"
SSL_DOMAIN="erp.company.com"
SSL_EMAIL="admin@company.com"
```

### Case 5: CI/CD Deployment

```bash
# GitHub Secrets configure qiling (once):
# - SSH_PRIVATE_KEY, SERVER_IP, SITE_NAME, etc.

# Keyin har safar:
git add .
git commit -m "New feature"
git push origin main
# → Avtomatik deploy! 🎉
```

---

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

### SSL Certificate Error

```bash
# Manual renewal
sudo certbot renew

# Check certificate
sudo certbot certificates

# Re-run Let's Encrypt
sudo -u frappe bench renew-lets-encrypt
```

### Domain Not Accessible

```bash
# Check DNS
dig yourdomain.com +short

# Check Nginx
sudo systemctl status nginx
sudo nginx -t

# Check site config
sudo -u frappe bench --site yoursite show-config
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
