# 🚀 Quick Start Guide - frappe_universal_deploy

**Version:** 2.1.0 (Production-Ready)  
**Last Updated:** 2026-01-27  
**Deployment Time:** 15-20 minutes

---

## 📋 Prerequisites Checklist

Before starting, ensure you have:

- [ ] Ubuntu 24.04 LTS server (DigitalOcean, AWS, or local)
- [ ] Root SSH access to server
- [ ] Minimum 2GB RAM, 2 CPU cores, 20GB disk
- [ ] Server IP address
- [ ] (Optional) Domain name pointed to server

---

## 🎯 Option 1: Fresh Deployment (Recommended)

### Step 1: Clone Repository

```bash
# On your local machine
git clone https://github.com/Asadtop4ik/frappe_universal_deploy.git
cd frappe_universal_deploy
```

### Step 2: Configure Environment

```bash
# Copy template
cp .env.example .env

# Edit configuration
nano .env
```

**Minimal Configuration:**

```bash
# Basic Settings
SITE_NAME="mysite.local"              # Site name (use .local for IP access)
FRAPPE_VERSION="version-15"           # Frappe/ERPNext version
NODE_VERSION="20"                     # Node.js LTS version

# Security
MARIADB_ROOT_PASSWORD="YourSecurePass123!"
ADMIN_PASSWORD="admin"                # Change after first login!

# Apps
APPS_TO_INSTALL="frappe,erpnext,hrms" # Core apps
CUSTOM_APP_REPO=""                    # Leave empty or add your GitHub repo
CUSTOM_APP_NAME=""                    # App name (if custom repo used)

# Optional Features
RESTORE_BACKUP="false"                # Set true if restoring backup
DEVELOPER_MODE="false"                # Set true for development
ENABLE_SCHEDULER="true"               # Enable background jobs
```

### Step 3: Upload to Server

```bash
# Upload deployment package
scp -r frappe_universal_deploy root@YOUR_SERVER_IP:/root/

# SSH to server
ssh root@YOUR_SERVER_IP
```

### Step 4: Run Deployment

```bash
# Navigate to deployment directory
cd /root/frappe_universal_deploy

# Run base deployment
bash deploy/deploy.sh
```

**What happens:**
- ⏱️ Duration: 8-12 minutes
- ✅ Installs: MariaDB, Redis, Nginx, Supervisor
- ✅ Creates: frappe user, bench, site
- ✅ Installs: Frappe, ERPNext, HRMS (or your apps)
- ✅ Configures: Production setup, firewall

**Wait for:**
```
🎉 DEPLOYMENT MUVAFFAQIYATLI TUGADI! 🎉
Site URL: http://YOUR_SERVER_IP
Site Name: mysite.local
Username: Administrator
Password: admin
```

### Step 5: Access Your Site

```bash
# Open in browser
http://YOUR_SERVER_IP

# Login
Username: Administrator
Password: admin (from .env)

# ⚠️ IMPORTANT: Change password immediately!
```

### Step 6: (Optional) Setup Domain & SSL

```bash
# After DNS is configured (A record pointing to server)
bash deploy/02-setup-domain-ssl.sh

# Follow prompts:
# - Site name: mysite.local
# - Domain: yourdomain.com
# - Email: admin@yourdomain.com
```

**Result:** `https://yourdomain.com` with valid SSL ✅

---

## 🔄 Option 2: CI/CD Deployment (Automated)

### For Your Custom Frappe Apps

**Step 1: Setup GitHub Repository**

```bash
# Your custom Frappe app structure
my_custom_app/
├── .github/
│   └── workflows/
│       └── deploy.yml          # ← Copy from templates/
├── my_custom_app/              # App code
│   ├── __init__.py
│   ├── hooks.py
│   └── ...
├── setup.py
└── README.md
```

**Step 2: Copy Workflow Template**

```bash
# From frappe_universal_deploy repository
cp templates/github-workflow.yml my_custom_app/.github/workflows/deploy.yml
```

**Step 3: Configure GitHub Secrets**

Go to: `GitHub → Repository → Settings → Secrets → Actions`

**Required Secrets:**

| Secret Name | Value Example |
|-------------|---------------|
| `SSH_PRIVATE_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `SERVER_IP` | `137.184.83.134` |
| `SITE_NAME` | `mysite.local` |
| `DB_PASSWORD` | `YourMariaDBPassword` |
| `ADMIN_PASSWORD` | `admin` |

**Step 4: Push & Deploy**

```bash
git add .
git commit -m "Initial commit"
git push origin main

# → Automatic deployment starts! 🚀
# Check: GitHub → Actions tab
```

**Timeline:**
- First deploy: 20-25 min (includes base system)
- Updates: 3-5 min (zero-downtime!)

**📚 Detailed Guide:** [CI_CD_SETUP.md](CI_CD_SETUP.md)

---

## 🧪 Option 3: Test Deployment (Before Production)

### For Contributors & Developers

**Step 1: Fork Repository**

```bash
# Fork on GitHub
https://github.com/Asadtop4ik/frappe_universal_deploy

# Clone your fork
git clone https://github.com/YOUR_USERNAME/frappe_universal_deploy.git
```

**Step 2: Configure Test Server**

Create a fresh Ubuntu 24.04 droplet on DigitalOcean (or any provider)

**Step 3: Setup GitHub Secrets**

| Secret Name | Value |
|-------------|-------|
| `DO_DROPLET_IP` | Test server IP |
| `DO_SSH_PRIVATE_KEY` | SSH private key |
| `TEST_SITE_NAME` | `test.local` |
| `TEST_ADMIN_PASSWORD` | `testpass123` |
| `TEST_MARIADB_ROOT_PASSWORD` | `testdb123` |

**Step 4: Run Test Workflow**

```bash
# On GitHub:
Actions → Test Deployment → Run workflow

# Or push to main branch (auto-triggers)
git push origin main
```

**What happens:**
1. Validates configuration
2. Uploads deployment files
3. Runs full deployment
4. Verifies installation
5. Tests HTTP access
6. Reports results

**Timeline:** 15-20 minutes

---

## 📊 Post-Deployment Checklist

After successful deployment:

### Security

- [ ] Change Administrator password
- [ ] Review user permissions
- [ ] Verify firewall rules: `sudo ufw status`
- [ ] (Optional) Setup fail2ban

### Configuration

- [ ] Configure email settings (Frappe → Email Domain)
- [ ] Setup backup schedule
- [ ] Configure S3/backup destination
- [ ] Test scheduler: `bench --site SITE_NAME ready-for-migration`

### Optional Features

- [ ] Setup domain & SSL
- [ ] Configure custom apps
- [ ] Import data/fixtures
- [ ] Setup integrations

### Monitoring

- [ ] Test all major features
- [ ] Check supervisor status: `sudo supervisorctl status`
- [ ] Monitor logs: `bench --site SITE_NAME logs`
- [ ] Setup uptime monitoring (optional)

---

## 🐛 Quick Troubleshooting

### Site Not Accessible

```bash
# Check services
sudo supervisorctl status
sudo systemctl status nginx

# Check logs
sudo tail -f /var/log/nginx/error.log
bench --site SITE_NAME logs
```

### Redis Connection Error

```bash
# Fixed in v2.1.0, but if you encounter:
su - frappe
cd ~/frappe-bench

# Check config
cat sites/common_site_config.json | grep redis

# Should show:
# "redis_cache": "redis://127.0.0.1:6379"
# "redis_queue": "redis://127.0.0.1:6379"
```

### Nginx Permission Error

```bash
# Fix home directory permissions
sudo chmod 755 /home/frappe
sudo chmod -R 755 /home/frappe/frappe-bench/sites
```

### Custom App Installation Failed

```bash
# Base system (ERPNext) still works!
# Manual install:
su - frappe
cd ~/frappe-bench
bench get-app YOUR_APP_REPO
bench --site SITE_NAME install-app YOUR_APP_NAME
```

---

## 📞 Support & Resources

### Documentation

- **Full README:** [README.md](README.md)
- **CI/CD Guide:** [CI_CD_SETUP.md](CI_CD_SETUP.md)
- **DigitalOcean Setup:** [DIGITALOCEAN_SETUP.md](DIGITALOCEAN_SETUP.md)
- **Deployment Workflow:** [DEPLOYMENT_WORKFLOW.md](DEPLOYMENT_WORKFLOW.md)

### Community

- **GitHub Issues:** Report bugs or request features
- **Frappe Forum:** https://discuss.frappe.io
- **ERPNext Docs:** https://docs.erpnext.com

### Commands Reference

```bash
# Frappe user commands
su - frappe
cd ~/frappe-bench

# Site management
bench --site SITE_NAME status
bench --site SITE_NAME list-apps
bench --site SITE_NAME migrate
bench --site SITE_NAME clear-cache

# Service management
bench restart
sudo supervisorctl restart all
sudo systemctl reload nginx

# Logs
bench --site SITE_NAME logs
sudo tail -f /var/log/nginx/error.log
sudo journalctl -xeu mariadb
```

---

## 🎯 Next Steps

After successful deployment:

1. **Customize:** Configure your site (company, users, settings)
2. **Develop:** Build custom apps if needed
3. **Integrate:** Setup CI/CD for automatic updates
4. **Monitor:** Setup monitoring and alerting
5. **Scale:** Add more resources as needed

---

**Made with ❤️ by DevOps Engineers**  
**License:** MIT  
**Repository:** https://github.com/Asadtop4ik/frappe_universal_deploy
