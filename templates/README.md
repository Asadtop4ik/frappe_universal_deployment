# 🚀 Frappe App CI/CD Template

Bu papkada **universal** template lar bor - har qanday Frappe app uchun ishlatish mumkin.

## 🆕 Recent Updates (2026-01-25)

- ✅ **Zero-downtime deployment** (4 min → 5-10 sec)
- ✅ Build assets while site is live
- ✅ No maintenance mode (users stay connected)
- ✅ Smart restart (only necessary services)

---

## 📋 **TEMPLATES:**

### **1. `github-workflow.yml` - GitHub Actions CI/CD**

Frappe app larni **avtomatik deploy** qilish uchun workflow.

**Features:**
- ✅ Auto-detect app name (repository name dan)
- ✅ **Zero-downtime:** Build → Migrate → Restart (5-10 sec)
- ✅ No maintenance mode (site stays live)
- ✅ Smart error handling
- ✅ Health check
- ✅ Update-only (fresh deployment: `deploy/deploy.sh`)

---

## 🔧 **SETUP - YANGI FRAPPE APP UCHUN:**

### **Step 1: Workflow ni copy qilish**

```bash
# Frappe app repo siga kirish
cd /path/to/your-frappe-app

# .github/workflows papka yaratish
mkdir -p .github/workflows

# Template ni copy qilish
cp /path/to/frappe_universal_deploy/templates/github-workflow.yml \
   .github/workflows/deploy.yml

# Git commit
git add .github/workflows/deploy.yml
git commit -m "Add: GitHub Actions auto-deployment"
git push origin main
```

---

### **Step 2: GitHub Secrets sozlash**

GitHub repo da: **Settings → Secrets and variables → Actions → New repository secret**

**REQUIRED secrets:**

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SERVER_IP` | Server IP address | `167.71.112.93` |
| `SSH_PRIVATE_KEY` | SSH private key (cat ~/.ssh/id_rsa) | `-----BEGIN RSA...` |
| `SITE_NAME` | Frappe site name | `mysite.local` |

**OPTIONAL secrets:**

| Secret Name | Default | Description |
|-------------|---------|-------------|
| `BENCH_PATH` | `/home/frappe/frappe-bench` | Custom bench path |
| `FRAPPE_VERSION` | `version-15` | Frappe/ERPNext version |

---

### **Step 3: Test qilish**

```bash
# Local da commit qiling
git commit -am "Test deployment"
git push origin main

# GitHub Actions automatic ishga tushadi:
# 1. SSH to server
# 2. git pull
# 3. bench migrate
# 4. bench build
# 5. clear-cache
# 6. supervisorctl restart

# Deploy status: GitHub → Actions → Deploy to Production
```

---

## 🎯 **DEPLOYMENT WORKFLOW:**

```
┌─────────────────┐
│  git push       │
│  (local)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ GitHub Actions  │
│ Trigger         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ SSH to Server   │
│ Check bench     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│ Update Deployment:              │
│ 1. git pull                     │
│ 2. bench migrate ← fixtures!    │
│ 3. bench build                  │
│ 4. clear-cache                  │
│ 5. supervisorctl restart        │
└─────────────────────────────────┘
```

---

## 🔒 **SECURITY BEST PRACTICES:**

1. ✅ **SSH_PRIVATE_KEY** - GitHub Secrets da, hech qachon code da EMAS!
2. ✅ **SITE_NAME** - Secret da (private info)
3. ✅ **SERVER_IP** - Secret da (security)
4. ✅ `.env` file ni `.gitignore` ga qo'shing
5. ✅ Parollarni hech qachon commit qilmang!

---

## 🆘 **TROUBLESHOOTING:**

### **1. Deployment fails - "bench not found"**

**Problem:** `BENCH_PATH` noto'g'ri

**Solution:**
```bash
# Serverda bench path ni tekshiring
ssh root@SERVER_IP "su - frappe -c 'which bench'"

# Output: /home/frappe/.local/bin/bench
# BENCH_PATH = /home/frappe/frappe-bench ✅
```

---

### **2. Deployment fails - "site not found"**

**Problem:** `SITE_NAME` noto'g'ri

**Solution:**
```bash
# Serverda site larni ko'ring
ssh root@SERVER_IP "ls /home/frappe/frappe-bench/sites/"

# GitHub Secret da to'g'ri site name qo'ying
```

---

### **3. SSH connection fails**

**Problem:** `SSH_PRIVATE_KEY` noto'g'ri yoki permissions

**Solution:**
```bash
# Local SSH key ni copy qiling (PRIVATE key!)
cat ~/.ssh/id_rsa

# GitHub Secret ga paste qiling (-----BEGIN ... -----END bilan)

# Serverda authorized_keys tekshiring
ssh root@SERVER_IP "cat ~/.ssh/authorized_keys"
```

---

## 📚 **BOSHQA TEMPLATE LAR:**

Kelgusida qo'shiladi:
- [ ] GitLab CI/CD template
- [ ] Bitbucket Pipelines template
- [ ] Docker Compose template
- [ ] Kubernetes deployment template

---

## 📞 **SUPPORT:**

Issues: https://github.com/Asadtop4ik/frappe_universal_deploy/issues

---

**Made with ❤️ for Frappe Community**
