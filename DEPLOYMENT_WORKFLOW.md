# 🚀 Real-World Deployment Workflow

Bu qo'llanma **haqiqiy** deployment jarayonini ko'rsatadi.

## 📋 Scenario

Siz 1 oy davomida custom app yaratdingiz va uni serverga deploy qilmoqchisiz.

## 🎯 Prerequisites

- ✅ Custom app tayyor va GitHub da
- ✅ Server sotib olgan (Ubuntu 22.04/24.04)
- ✅ SSH access bor
- ✅ Domain (ixtiyoriy, keyinroq ham qo'shish mumkin)

## 📝 Step-by-Step Deployment

### 1️⃣ LOCAL: Deployment Tayorlash

```bash
# Deployment repo ni clone qilish
cd ~/projects/
git clone https://github.com/Asadtop4ik/frappe_deployment.git
cd frappe_deployment

# Configuration yaratish
cp .env.example .env
```

### 2️⃣ LOCAL: Configure Environment

`.env` faylini tahrirlash:

```bash
nano .env
```

**MUHIM sozlamalar:**

```bash
# ============================================
# SERVER CONFIGURATION
# ============================================
SITE_NAME="akfa.local"                     # Domain yoki .local
SERVER_IP="137.184.83.134"                 # Serveringiz IP

# ============================================
# FRAPPE CONFIGURATION
# ============================================
FRAPPE_VERSION="version-15"                # v15 stable
PYTHON_VERSION="3.11"                      # 3.10, 3.11, yoki 3.12

# ============================================
# DATABASE CONFIGURATION
# ============================================
MARIADB_ROOT_PASSWORD="VerySecure123!"    # KUCHLI parol!
ADMIN_PASSWORD="admin123"                  # Administrator login

# ============================================
# APPS TO INSTALL (IMPORTANT!)
# ============================================
APPS_TO_INSTALL="frappe,erpnext,hrms,akfa_accounting"

# ============================================
# CUSTOM APP CONFIGURATION
# ============================================
CUSTOM_APP_REPO="https://github.com/Asadtop4ik/akfa_accounting.git"
CUSTOM_APP_BRANCH="main"                   # yoki "develop"

# ============================================
# BACKUP RESTORE (Yangi site uchun false)
# ============================================
RESTORE_BACKUP="false"
# SQL_BACKUP_FILE="backup.sql.gz"          # Agar backup bo'lsa
# CONFIG_BACKUP_FILE="site_config.json"
```

**Saqlash:** `Ctrl+O`, `Enter`, `Ctrl+X`

### 3️⃣ LOCAL: Validate Configuration

```bash
# Config tekshirish
cat .env | grep -E "SITE_NAME|CUSTOM_APP|APPS_TO"

# Expected output:
# SITE_NAME="akfa.local"
# APPS_TO_INSTALL="frappe,erpnext,hrms,akfa_accounting"
# CUSTOM_APP_REPO="https://github.com/Asadtop4ik/akfa_accounting.git"
```

### 4️⃣ LOCAL: Upload to Server

```bash
# Serverga yuklash
scp -r frappe_deployment root@137.184.83.134:/root/

# Parol so'ralsa kiritasiz
# Yoki SSH key setup qilgan bo'lsangiz avtomatik
```

**Alternative (agar scp ishlamasa):**

```bash
# Server da clone qilish
ssh root@137.184.83.134
cd /root/
git clone https://github.com/Asadtop4ik/frappe_deployment.git
exit

# .env ni alohida yuklash
scp .env root@137.184.83.134:/root/frappe_deployment/
```

### 5️⃣ SERVER: SSH Login

```bash
# Serverga kirish
ssh root@137.184.83.134

# Papkani tekshirish
ls -la /root/frappe_deployment/
# Ko'rinishi kerak: deploy/, backups/, .env, README.md
```

### 6️⃣ SERVER: Deploy Script ni Ishga Tushirish

```bash
# Deploy papkaga kirish
cd /root/frappe_deployment

# Script ga permission berish
chmod +x deploy/deploy.sh

# Deploy qilish (20-30 minut davom etadi)
./deploy/deploy.sh
```

**Script nima qiladi:**

```
[1/10] System packages install... ✓
[2/10] MariaDB setup... ✓
[3/10] Redis setup... ✓
[4/10] Node.js install... ✓
[5/10] Frappe bench init... ✓
[6/10] Installing apps:
       - frappe ✓
       - erpnext ✓
       - hrms ✓
       - akfa_accounting (from GitHub) ✓
[7/10] Creating site... ✓
[8/10] Production setup (Nginx + Supervisor)... ✓
[9/10] Applying security fixes... ✓
[10/10] Starting services... ✓

✅ Deployment completed!
🌐 Site: http://137.184.83.134
👤 Login: Administrator
🔑 Password: admin123
```

### 7️⃣ BROWSER: Test Site

```
1. Brauzerda oching: http://137.184.83.134
2. Login qiling:
   - Username: Administrator
   - Password: admin123
3. Sizning akfa_accounting app ko'rinishi kerak!
```

---

## 🔄 Development Workflow (Keyingi marta)

### Lokal da o'zgarish kiritdingiz:

```bash
# LOCAL
cd ~/frappe-bench/apps/akfa_accounting

# Kod yozdingiz, test qildingiz
git add .
git commit -m "Add new feature"
git push origin main
```

### Serverda yangilash:

```bash
# SERVER
ssh root@137.184.83.134
su - frappe
cd ~/frappe-bench

# App ni yangilash (pull latest code)
cd apps/akfa_accounting
git pull origin main
cd ~/frappe-bench

# Database migrate (agar model o'zgargan bo'lsa)
bench --site akfa.local migrate

# Assets rebuild
bench build --app akfa_accounting

# Restart
bench restart

# Yoki production da:
exit  # frappe userdan chiqish
sudo supervisorctl restart all
```

---

## 🎯 Common Scenarios

### Scenario 1: Yangi Server, Yangi Site

```bash
RESTORE_BACKUP="false"
APPS_TO_INSTALL="frappe,erpnext,akfa_accounting"
```

### Scenario 2: Eski Site ni Ko'chirish

```bash
# Eski serverdan backup oling
bench --site old.local backup --with-files

# Backup fayllarni ko'chiring
scp old-backup.sql.gz root@new-server:/root/frappe_deployment/backups/

# .env da
RESTORE_BACKUP="true"
SQL_BACKUP_FILE="old-backup.sql.gz"
```

### Scenario 3: Faqat Custom App (ERPNext kerak emas)

```bash
APPS_TO_INSTALL="frappe,akfa_accounting"
```

### Scenario 4: Multiple Custom Apps

```bash
APPS_TO_INSTALL="frappe,erpnext,akfa_accounting,cashflow_app"

# deploy.sh da qo'shimcha qo'shish kerak:
# elif [[ "$app" == "cashflow_app" ]]; then
#     bench get-app https://github.com/user/cashflow_app.git
```

---

## ⚠️ Important Notes

### 1. GitHub Access

Agar private repo bo'lsa:

```bash
# SERVER da (deploy qilishdan oldin)
ssh root@137.184.83.134

# SSH key yaratish
ssh-keygen -t ed25519 -C "server@akfa.com"
cat ~/.ssh/id_ed25519.pub

# Bu key ni GitHub Settings > SSH Keys ga qo'shing
```

### 2. .env File Security

```bash
# .env ni HECH QACHON GitHub ga push qilmang!
# Har safar yangi serverda create qiling

# .gitignore da bor:
.env
```

### 3. Config Fayllar

Har bir server uchun **yangi .env** yaratish kerak:

```
Local computer:     development.env
Staging server:     staging.env
Production server:  production.env
```

### 4. Domain Setup

Domen olganingizdan keyin:

```bash
# SERVER da
su - frappe
cd ~/frappe-bench

# Domen qo'shish
bench setup add-domain yourdomain.com --site akfa.local

# SSL setup
sudo bench setup lets-encrypt akfa.local

# Yoki manual Cloudflare SSL
```

---

## 🐛 Troubleshooting

### Error: "App not found"

```bash
# GitHub repo public ekanligini tekshiring
# Yoki SSH key setup qiling
```

### Error: "Permission denied"

```bash
# Home directory permissions
sudo chmod 755 /home/frappe
sudo chmod -R 755 /home/frappe/frappe-bench/sites
```

### Error: "Port already in use"

```bash
# Boshqa process ni to'xtatish
sudo lsof -ti:80 | xargs sudo kill -9
sudo systemctl restart nginx
```

### Site ochilmayapti

```bash
# Logs tekshirish
sudo tail -f /var/log/nginx/error.log
su - frappe
cd ~/frappe-bench
bench --site akfa.local logs
```

---

## 📊 Timeline

**Total deployment time:** ~25-35 daqiqa

- System setup: 5-10 min
- Frappe init: 3-5 min
- Apps install: 5-10 min
- Site creation: 2-3 min
- Production setup: 3-5 min
- Services start: 1-2 min

**Network speed ga bog'liq!**

---

## ✅ Post-Deployment Checklist

- [ ] Site ochiladi va login qilish mumkin
- [ ] Sizning custom app ko'rinadi
- [ ] Static files (images, CSS) yuklanyapti
- [ ] Admin parolni o'zgartirdingiz
- [ ] Firewall setup (UFW)
- [ ] Backup strategy qo'ydingiz
- [ ] Domain setup (agar bor bo'lsa)
- [ ] SSL certificate (production uchun)
- [ ] Monitoring setup (ixtiyoriy)

---

## 🎓 Learning Resources

### Sizning repolarga:
- **Deployment:** https://github.com/Asadtop4ik/frappe_deployment
- **Custom App:** https://github.com/Asadtop4ik/akfa_accounting

### Official Docs:
- Frappe: https://frappeframework.com/docs
- ERPNext: https://docs.erpnext.com

---

**Savollar bo'lsa, GitHub Issues da so'rang!** 🚀
