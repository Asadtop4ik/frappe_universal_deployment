# 🔄 CI/CD Setup Guide - GitHub Actions

Bu guide **har bir Frappe project**da GitHub Actions orqali avtomatik deployment qanday sozlashni ko'rsatadi.

---

## 🎯 Overview

**Nima bo'ladi?**
- ✅ `main` branch ga code push qilasiz
- ✅ GitHub Actions avtomatik ishga tushadi
- ✅ Code serverga deploy bo'ladi
- ✅ Services restart bo'ladi
- ✅ Site yangilanadi - **MANUAL ISH YO'Q!**

**Timeline:**
```
Developer                GitHub Actions              Server
   |                           |                        |
   |--[git push main]--------->|                        |
   |                           |--[Build .env]          |
   |                           |--[SSH connect]-------->|
   |                           |                    [Pull code]
   |                           |                    [Migrate DB]
   |                           |                    [Build assets]
   |                           |                    [Restart]
   |                           |<-------[Done]----------|
   |<--[✅ Deployment OK]-------|                        |
```

---

## 📋 Prerequisites

### ✅ Checklist:

- [ ] GitHub repository bor (akfa_accounting kabi)
- [ ] Server deploy qilingan (frappe-bench ishlab turibdi)
- [ ] SSH access bor serverga
- [ ] GitHub da admin rights bor (Secrets qo'shish uchun)

---

## 1️⃣ SSH Key Yaratish

GitHub Actions serverga SSH orqali kirishiga kerak.

### **Step 1: SSH Key Generate**

```bash
# LOCAL computer da
cd ~/.ssh
ssh-keygen -t ed25519 -C "github-actions-deploy" -f github_deploy_key

# Passphrase: Bo'sh qoldiring (Enter bosing)
```

**2 ta fayl yaratiladi:**
- `github_deploy_key` - **Private key** (GitHub Secrets ga)
- `github_deploy_key.pub` - **Public key** (Serverga)

### **Step 2: Public Key ni Serverga Qo'shish**

```bash
# Public key ni ko'rish
cat ~/.ssh/github_deploy_key.pub

# Copy output (ssh-ed25519 AAAA... bilan boshlanadi)
```

**Serverga upload:**

```bash
# Server ga kirish
ssh root@137.184.83.134

# Authorized keys ga qo'shish
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... github-actions-deploy
EOF

# Permissions
chmod 600 ~/.ssh/authorized_keys

# Test
exit
```

### **Step 3: Test Connection**

```bash
# LOCAL da
ssh -i ~/.ssh/github_deploy_key root@137.184.83.134

# Ishlaydimi?
# ✅ YES → Davom eting
# ❌ NO → Yuqoridagi qadamlarni qaytaring
```

---

## 2️⃣ GitHub Secrets Setup

### **Step 1: Private Key ni Olish**

```bash
# LOCAL da
cat ~/.ssh/github_deploy_key

# FULL OUTPUT ni copy qiling (-----BEGIN ... -----END gacha)
```

### **Step 2: GitHub da Secrets Qo'shish**

1. **GitHub repository → Settings**
2. **Secrets and variables → Actions**
3. **New repository secret**

### **Kerakli Secrets:**

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SSH_PRIVATE_KEY` | SSH private key (full content) | `-----BEGIN OPENSSH...` |
| `SERVER_IP` | Server IP address | `137.184.83.134` |
| `SITE_NAME` | Frappe site nomi | `akfa.local` yoki `akfa.uz` |
| `DB_PASSWORD` | MariaDB root password | `SecurePass123!` |
| `ADMIN_PASSWORD` | Site admin password | `admin123` |
| `APPS_TO_INSTALL` | Apps list (ixtiyoriy) | `frappe,erpnext,hrms,akfa_accounting` |
| `SETUP_SSL` | SSL enable (ixtiyoriy) | `true` yoki `false` |
| `SSL_DOMAIN` | Domain for SSL (ixtiyoriy) | `akfa.uz` |
| `SSL_EMAIL` | Email for Let's Encrypt | `admin@akfa.uz` |

### **Screenshot Guide:**

```
GitHub → akfa_accounting repository
  └── Settings (⚙️)
      └── Secrets and variables (🔐)
          └── Actions
              └── New repository secret

Name: SSH_PRIVATE_KEY
Value: [paste private key]
[Add secret]
```

**Repeat for each secret!**

---

## 3️⃣ Workflow File Setup

### **Step 1: Template Copy**

```bash
# LOCAL da, sizning app repository da
cd ~/projects/akfa_accounting

# GitHub Actions papka yaratish
mkdir -p .github/workflows

# Template dan nusxa olish
cp ~/frappe_deployment/templates/github-workflow.yml .github/workflows/deploy.yml
```

### **Step 2: Customize (Ixtiyoriy)**

99% hollarda o'zgartirish **KERAK EMAS**! Template universal.

**Agar o'zgartirish kerak bo'lsa:**

```yaml
# .github/workflows/deploy.yml

# Deploy qaysi branch dan?
on:
  push:
    branches:
      - main        # ← "production" yoki "master" ga o'zgartirish mumkin

# Frappe version?
env:
  FRAPPE_VERSION: "version-15"   # ← "version-14" ga o'zgartirish mumkin
```

### **Step 3: Commit & Push**

```bash
git add .github/
git commit -m "Add GitHub Actions CI/CD"
git push origin main
```

---

## 4️⃣ First Deployment

### **Step 1: Trigger Workflow**

**Automatic:** `main` branch ga push qilganda avtomatik

**Manual:**
1. GitHub → **Actions** tab
2. **Deploy to Production** workflow
3. **Run workflow** tugmasi → **Run workflow**

### **Step 2: Monitor Progress**

**GitHub Actions page:**

```
Actions → Deploy to Production → Latest run

[✅] Checkout code
[✅] Setup SSH Key  
[✅] Validate Configuration
[✅] Generate .env from Secrets
[⏳] Check Deployment Status
[⏳] Fresh Deployment / Update Existing
[⏳] Health Check
```

**Timeline:** 3-5 daqiqa (yangilanish uchun), 20-30 daqiqa (fresh install)

### **Step 3: Check Logs**

Har bir step ni bosib, detailed logs ko'rish mumkin:

```
🚀 Starting fresh deployment...
✅ .env file generated successfully
📦 Existing deployment found - will update
🔧 Enabling maintenance mode...
📥 Pulling latest code...
🗄️  Running database migrations...
🎨 Building frontend assets...
✅ Deployment updated!
```

---

## 5️⃣ Troubleshooting

### **Issue 1: SSH Connection Failed**

```
Error: Permission denied (publickey)
```

**Solution:**
```bash
# SSH_PRIVATE_KEY Secret to'g'ri paste qilganmisiz?
# Full content, including:
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----

# Public key serverda bormi?
ssh root@SERVER_IP "cat ~/.ssh/authorized_keys"
```

---

### **Issue 2: Secrets Not Found**

```
❌ ERROR: SERVER_IP secret not set!
```

**Solution:**
- GitHub → Settings → Secrets → Actions
- Barcha kerakli secrets mavjudligini tekshiring
- Secret nomlari **EXACTLY** mos kelishi kerak (case-sensitive!)

---

### **Issue 3: Deployment Failed Mid-Way**

```
Error: bench migrate failed
```

**Solution:**
```bash
# Serverga manual kirib tekshirish
ssh root@SERVER_IP

su - frappe
cd ~/frappe-bench

# Logs
bench --site yoursite.local logs

# Manual migrate
bench --site yoursite.local migrate

# Agar fix bo'lsa, workflow qayta run qiling
```

---

### **Issue 4: Site Still Shows Old Code**

```
Code push qildim lekin site yangilanmadi
```

**Solution:**
```bash
# SSH orqali serverda
su - frappe
cd ~/frappe-bench

# Cache clear
bench --site yoursite.local clear-cache
bench --site yoursite.local clear-website-cache

# Hard reload
bench restart
supervisorctl restart all
```

---

## 6️⃣ Workflow Customization

### **Scenario A: Deploy Faqat Tag da**

```yaml
# deploy.yml
on:
  push:
    tags:
      - 'v*.*.*'    # v1.0.0, v2.1.3, etc.
```

**Usage:**
```bash
git tag v1.0.0
git push origin v1.0.0   # Trigger deployment
```

---

### **Scenario B: Manual Approval**

```yaml
# deploy.yml
jobs:
  deploy:
    environment: 
      name: production
      url: http://${{ secrets.SERVER_IP }}
```

**Setup:**
- GitHub → Settings → Environments → New environment → `production`
- **Required reviewers:** O'zingizni qo'shing
- Push bo'lganda approval so'raydi

---

### **Scenario C: Slack/Discord Notification**

```yaml
# deploy.yml oxirida
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## 7️⃣ Multiple Environments

Agar **staging** va **production** kerak bo'lsa:

### **Approach 1: Branches**

```yaml
# .github/workflows/deploy-staging.yml
on:
  push:
    branches:
      - develop

# .github/workflows/deploy-production.yml
on:
  push:
    branches:
      - main
```

**Secrets:**
- `STAGING_SERVER_IP`
- `PRODUCTION_SERVER_IP`

### **Approach 2: Environments**

```yaml
jobs:
  deploy-staging:
    environment: staging
    # uses: staging secrets

  deploy-production:
    environment: production
    # uses: production secrets
```

---

## 8️⃣ Best Practices

### ✅ DO:

1. **Secrets ni repo da SAQLANG** (Settings → Secrets)
2. **Branch protection** yoqing (`main` branch)
3. **Pull Request** workflow qo'shing (test → merge → deploy)
4. **Backup** oling deploy qilishdan oldin
5. **Maintenance mode** yoqing deploy vaqtida (workflow allaqachon qiladi)

### ❌ DON'T:

1. **Parollarni code da** yozmang (even in comments!)
2. **SSH key ni commit** qilmang
3. **Production ga to'g'ridan-to'g'ri push** qilmang (PR ishlatish)
4. **Test qilmasdan deploy** qilmang
5. **Log da sensitive data** ko'rsatmang

---

## 9️⃣ Security Checklist

- [ ] SSH private key faqat GitHub Secrets da
- [ ] Public repo bo'lsa, sensitive data yo'q
- [ ] Server firewall sozlangan (faqat 22, 80, 443)
- [ ] SSH password authentication disabled
- [ ] GitHub 2FA enabled
- [ ] Secrets faqat kerakli workflow larga accessible
- [ ] Server logs monitoring qilinmoqda

---

## 🔟 Complete Example

### **Real Project: akfa_accounting**

**1. Repository Structure:**
```
akfa_accounting/
├── .github/
│   └── workflows/
│       └── deploy.yml          ← Template dan copy
├── akfa_accounting/            ← App code
│   ├── __init__.py
│   ├── hooks.py
│   └── ...
├── .gitignore
├── setup.py
└── README.md
```

**2. GitHub Secrets:**
```
SSH_PRIVATE_KEY = "-----BEGIN OPENSSH PRIVATE KEY-----..."
SERVER_IP = "137.184.83.134"
SITE_NAME = "akfa.local"
DB_PASSWORD = "SecurePass123!"
ADMIN_PASSWORD = "admin123"
APPS_TO_INSTALL = "frappe,erpnext,hrms,akfa_accounting"
```

**3. Workflow:**
```bash
# Developer local da
git checkout -b feature/new-report
# Code yozish...
git add .
git commit -m "Add new sales report"
git push origin feature/new-report

# GitHub da Pull Request
# Review → Approve → Merge to main

# 🚀 Avtomatik deploy boshlandi!
# 3 daqiqadan keyin site yangilangan!
```

---

## 📚 Resources

- **GitHub Actions Docs:** https://docs.github.com/actions
- **Frappe Developer Guide:** https://frappeframework.com/docs/user/en/guides
- **SSH Key Guide:** https://docs.github.com/authentication/connecting-to-github-with-ssh

---

## 💡 Pro Tips

1. **Local test qiling:** Har doim local da test qilib, keyin push qiling
2. **Branch strategy:** `develop` → `staging` → `main` (production)
3. **Rollback plan:** Agar deploy fail bo'lsa, oldingi version ga qaytish
4. **Monitor logs:** GitHub Actions logs va server logs ikkalasini ham
5. **Document changes:** Har bir deploy uchun CHANGELOG.md yangilang

---

## 🎓 Next Steps

- [ ] Template setup qildingiz
- [ ] Secrets configure qildingiz
- [ ] Birinchi deploy successful
- [ ] Monitoring setup
- [ ] Backup strategy
- [ ] **Optional:** Staging environment qo'shing
- [ ] **Optional:** Slack/Discord notifications
- [ ] **Optional:** Automated tests qo'shing

---

**Tested with:** GitHub Actions, Frappe v15, Ubuntu 24.04  
**Author:** Asadbek (@Asadtop4ik)

---

**Savollar bo'lsa:** GitHub Issues da yozing yoki Telegram: @AzamatovAsadbek
