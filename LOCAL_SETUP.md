# 🔄 Local Development Setup Guide

Lokal kompyuterda Frappe/ERPNext o'rnatish va backup restore qilish qo'llanmasi.

## 📋 Tizim Talablari

- **OS:** Ubuntu 22.04, 24.04, macOS, yoki Windows (WSL2)
- **RAM:** Minimum 4GB
- **Python:** 3.10 yoki 3.11 (3.12 ham ishlaydi)
- **Node.js:** v18 (LTS)
- **MariaDB:** 10.6+
- **Redis:** Latest

## 🚀 1-Qadam: Tizimni Tayyorlash

### Ubuntu/Debian:

```bash
# System update
sudo apt-get update
sudo apt-get upgrade -y

# Python va kerakli paketlar
sudo apt-get install -y git python3-dev python3-pip python3-venv \
    python3-setuptools python3-distutils redis-server

# MariaDB
sudo apt-get install -y mariadb-server mariadb-client

# Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# wkhtmltopdf (PDF uchun)
sudo apt-get install -y xvfb libfontconfig wkhtmltopdf

# Yarn
sudo npm install -g yarn
```

### macOS:

```bash
# Homebrew orqali
brew install python@3.11 mariadb redis node@18 git

# Yarn
npm install -g yarn

# wkhtmltopdf
brew install --cask wkhtmltopdf
```

## 🔧 2-Qadam: Database Konfiguratsiyasi

```bash
# MariaDB ni ishga tushirish
sudo systemctl start mariadb
sudo systemctl enable mariadb

# MySQL secure installation
sudo mysql_secure_installation
```

MariaDB konfiguratsiyasi:

```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```

Quyidagi qatorlarni qo'shing yoki o'zgartiring:

```ini
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
```

Restart qiling:

```bash
sudo systemctl restart mariadb
```

## 📦 3-Qadam: Frappe Bench O'rnatish

```bash
# Bench o'rnatish
sudo pip3 install frappe-bench

# Ubuntu 24.04 uchun:
sudo pip3 install --break-system-packages frappe-bench

# Bench papka yaratish
cd ~
bench init --frappe-branch version-15 frappe-bench

# Bench papkaga kirish
cd frappe-bench
```

## 🎯 4-Qadam: Development Mode Setup

```bash
# Developer mode yoqish
bench set-config -g developer_mode 1

# Watchdog o'rnatish (auto-reload uchun)
pip3 install watchdog
```

## 📱 5-Qadam: Applarni O'rnatish

```bash
cd ~/frappe-bench

# ERPNext
bench get-app erpnext --branch version-15

# HRMS
bench get-app hrms --branch version-15

# Custom app (GitHub dan)
bench get-app https://github.com/AbdullohUchkunov/ruxsora_shirinlik.git

# Applarni ko'rish
bench version
```

## 🌐 6-Qadam: Site Yaratish

### Yangi Site (bo'sh):

```bash
bench new-site mysite.local \
    --mariadb-root-password YourRootPassword \
    --admin-password admin

# Applarni site ga o'rnatish
bench --site mysite.local install-app erpnext
bench --site mysite.local install-app hrms
bench --site mysite.local install-app ext_accounts
```

### Backup dan Restore Qilish:

```bash
# Site yaratish (bo'sh database bilan)
bench new-site mysite.local \
    --mariadb-root-password YourRootPassword \
    --admin-password admin

# Backup fayllarni nusxalash
cp /path/to/backup.sql.gz ~/frappe-bench/sites/mysite.local/private/backups/
cp /path/to/site_config_backup.json ~/frappe-bench/sites/mysite.local/

# Database restore
bench --site mysite.local --force restore \
    ~/frappe-bench/sites/mysite.local/private/backups/backup.sql.gz

# Migrate (agar kerak bo'lsa)
bench --site mysite.local migrate

# Admin parolni o'rnatish
bench --site mysite.local set-admin-password admin123
```

## 🏃 7-Qadam: Development Server Ishga Tushirish

```bash
cd ~/frappe-bench

# Barcha servislarni ishga tushirish
bench start
```

Bu quyidagilarni ishga tushiradi:
- Web server: http://localhost:8000
- SocketIO: port 9000
- Redis: port 6379
- Scheduler
- Workers

### Faqat web server:

```bash
bench serve
```

### Background da ishlatish:

```bash
# Supervisor orqali (production kabi)
bench setup supervisor
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all
```

## 🔍 8-Qadam: Site Ochish

Brauzerni oching:
```
http://localhost:8000
```

yoki

```
http://mysite.local:8000
```

**Login:**
- Username: `Administrator`
- Password: `admin123` (siz belgilagan parol)

## 🛠️ Foydali Komandalar

### Site boshqaruvi:

```bash
# Site ro'yxati
bench --site mysite.local list-apps

# Console ochish
bench --site mysite.local console

# Database console
bench --site mysite.local mariadb

# Loglarni ko'rish
bench --site mysite.local logs
```

### Development:

```bash
# Assets build qilish
bench build

# Clear cache
bench --site mysite.local clear-cache

# Migrate
bench --site mysite.local migrate

# Scheduler enable/disable
bench --site mysite.local scheduler enable
bench --site mysite.local scheduler disable
```

### Backup:

```bash
# Full backup
bench --site mysite.local backup

# Faqat database
bench --site mysite.local backup --only-db

# Faqat files
bench --site mysite.local backup --only-files

# Backuplar joyi
ls ~/frappe-bench/sites/mysite.local/private/backups/
```

## 🐛 Troubleshooting

### Port band bo'lsa:

```bash
# Portni tekshirish
sudo lsof -i :8000

# Procesni to'xtatish
sudo kill -9 <PID>
```

### Database connection error:

```bash
# MariaDB holatini tekshirish
sudo systemctl status mariadb

# Root parolni reset qilish
sudo mysql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'newpassword';
FLUSH PRIVILEGES;
exit;
```

### Redis error:

```bash
# Redis ishga tushirish
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

### Bench command not found:

```bash
# PATH ga qo'shish
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
source ~/.bashrc
```

## 📊 IDE Setup

### VS Code Extensions:

- Python
- Frappe/ERPNext Snippets
- SQLTools (MySQL/MariaDB)
- Git Graph

### VS Code Settings:

```json
{
    "python.defaultInterpreterPath": "~/frappe-bench/env/bin/python",
    "python.linting.pylintEnabled": true,
    "python.formatting.provider": "black",
    "editor.formatOnSave": true
}
```

## 🔗 Multi-Site Development

```bash
# Ikkinchi site yaratish
bench new-site site2.local --admin-password admin

# Site o'zgartirish
bench use site2.local

# Barcha siteni ko'rish
bench --site all list-apps
```

## 🚀 Production ga Deploy

Lokal development tayyor bo'lgach:

1. Kodingizni Git ga push qiling
2. Server da production deployment scripti ishga tushiring
3. Custom appni serverdagi bench ga get-app orqali olasiz

```bash
# Serverda
cd /home/frappe/frappe-bench
bench get-app https://github.com/yourname/yourapp.git
bench --site yoursite.local install-app yourapp
bench restart
```

---

**Savollar bo'lsa GitHub Issues da so'rang! 🙋‍♂️**
