# 🌊 DigitalOcean Setup Guide (UI orqali)

Bu guide DigitalOcean UI orqali server yaratish va sozlashni ko'rsatadi.

---

## 📋 Prerequisites

- ✅ DigitalOcean account (https://digitalocean.com)
- ✅ Payment method qo'shilgan
- ✅ Domain sotib olingan (ixtiyoriy, keyinroq ham qo'shish mumkin)

---

## 1️⃣ Droplet (Server) Yaratish

### **Step 1: Create Droplet**

1. DigitalOcean dashboard ga kiring: https://cloud.digitalocean.com
2. **Create** → **Droplets** tugmasini bosing
3. Yoki to'g'ridan-to'g'ri: https://cloud.digitalocean.com/droplets/new

### **Step 2: Image tanlash**

**Choose an image:**
- **Distribution** tab ni tanlang
- **Ubuntu** ni tanlang
- **Version:** `24.04 LTS x64` yoki `22.04 LTS x64` ✅ (Tavsiya: 24.04)

> **Nima uchun Ubuntu?** Frappe official qo'llab-quvvatlaydi

### **Step 3: Plan tanlash**

**Choose Size:**

| Use Case | Plan | CPU | RAM | Disk | Price/mo |
|----------|------|-----|-----|------|----------|
| **Test/Development** | Basic | 1 vCPU | 1 GB | 25 GB | $6 |
| **Small Business** | Basic | 1 vCPU | 2 GB | 50 GB | $12 ✅ |
| **Production (10-20 users)** | Basic | 2 vCPU | 2 GB | 60 GB | $18 |
| **Production (50+ users)** | Basic | 2 vCPU | 4 GB | 80 GB | $24 |
| **Large Enterprise** | General Purpose | 4 vCPU | 8 GB | 160 GB | $48 |

**Tavsiya:** Boshlash uchun **$12/mo (2GB RAM)** ✅

> **Muhim:** Frappe uchun minimum 2GB RAM tavsiya etiladi!

### **Step 4: Data Center tanlash**

**Choose a datacenter region:**

**Yaqin region tanlang:**
- 🇸🇬 **Singapore** - Osiyo uchun eng yaxshi
- 🇩🇪 **Frankfurt** - Yevropa
- 🇺🇸 **New York** - Amerika
- 🇮🇳 **Bangalore** - Hindiston (O'zbekistonga yaqin)

**Tavsiya:** **Singapore** (tez va barqaror) ✅

### **Step 5: Authentication**

**Authentication Method:**

**2 ta variant:**

#### **Variant A: SSH Key** ✅ (Tavsiya - Xavfsiz)

```bash
# LOCAL computer da
ssh-keygen -t ed25519 -C "asadtop4ik@gmail.com"

# Enter qiling (default joylashuvda saqlaydi)
# Passphrase ixtiyoriy (bo'sh qoldirish mumkin)

# Public key ni ko'rish
cat ~/.ssh/id_ed25519.pub
```

**Output:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG... asadtop4ik@gmail.com
```

**DigitalOcean da:**
1. **New SSH Key** tugmasini bosing
2. Public key ni paste qiling
3. Name: `My MacBook` yoki `Dev Laptop`
4. **Add SSH Key**

#### **Variant B: Password** (Oddiy lekin kam xavfsiz)

- DigitalOcean email ga parol yuboradi
- Birinchi login da parolni o'zgartirishingiz kerak

**Tavsiya:** SSH Key ishlatish! ✅

### **Step 6: Qo'shimcha Sozlamalar**

**Additional Options:**

- ☑️ **Monitoring** - Free, yoqib qo'ying! (CPU, RAM ko'rsatadi)
- ☐ **IPv6** - Ixtiyoriy
- ☑️ **User data** - Keyinroq kerak bo'lsa
- ☐ **Backups** - $1.20/mo (+20%) - Production uchun yoqing!

**Finalize Details:**

- **Hostname:** `frappe-prod-01` (o'zingizga qulay nom)
- **Tags:** `frappe`, `production`, `akfa` (filter qilish uchun)
- **Project:** `AKFA Project` (yangi project yaratish mumkin)

### **Step 7: Create Droplet**

- **Create Droplet** tugmasini bosing
- 30-60 soniya kutasiz
- **IP Address** paydo bo'ladi: `137.184.83.134` ✅

---

## 2️⃣ Firewall Sozlash

### **Variant A: DigitalOcean Cloud Firewall** ✅ (Tavsiya)

**1. Firewall yaratish:**

- **Networking** → **Firewalls** → **Create Firewall**
- Name: `frappe-firewall`

**2. Inbound Rules:**

| Type | Protocol | Port | Sources |
|------|----------|------|---------|
| SSH | TCP | 22 | Your IP yoki All IPv4 |
| HTTP | TCP | 80 | All IPv4 |
| HTTPS | TCP | 443 | All IPv4 |
| Custom | TCP | 3306 | Droplets (MariaDB - faqat internal!) |

**3. Outbound Rules:**

- **All TCP** → All IPv4 ✅ (default)
- **All UDP** → All IPv4 ✅

**4. Apply to Droplets:**

- Sizning `frappe-prod-01` dropletni tanlang
- **Create Firewall**

### **Variant B: UFW (Server ichida)** 

```bash
ssh root@137.184.83.134

# UFW sozlash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

**Tavsiya:** Cloud Firewall + UFW ikkalasini ham ishlating! (Double security)

---

## 3️⃣ SSH orqali Serverga Kirish

### **SSH Key bilan:**

```bash
# LOCAL da
ssh root@137.184.83.134

# Birinchi marta:
# "Are you sure you want to continue connecting?" → yes
```

### **Password bilan:**

```bash
ssh root@137.184.83.134
# Email dagi parolni kiriting
# Yangi parol o'rnating
```

### **Test:**

```bash
# Server ichida
whoami    # Output: root
hostname  # Output: frappe-prod-01
df -h     # Disk space
free -h   # RAM
```

---

## 4️⃣ Domain Sozlash (DNS)

### **Scenario 1: Domain DigitalOcean da**

#### **Step 1: Domain qo'shish**

1. **Networking** → **Domains** → **Add a Domain**
2. Domain kiriting: `akfa.uz`
3. **Add Domain**

#### **Step 2: DNS Records yaratish**

**A Records:**

| Hostname | Will Direct To | TTL |
|----------|----------------|-----|
| @ | `137.184.83.134` | 3600 |
| www | `137.184.83.134` | 3600 |
| *.akfa.uz | `137.184.83.134` | 3600 (Wildcard - barcha subdomain) |

**Qo'shish:**
1. **Create new record** → **A**
2. **HOSTNAME:** `@` (root domain)
3. **WILL DIRECT TO:** Droplet IP
4. **Create Record**

**Repeat** for `www` and `*`

#### **Step 3: Nameservers (Domain registrar da)**

Domeningiz qayerda sotib olingan (Namecheap, GoDaddy, etc.)?

**Nameserverlarni o'zgartiring:**
```
ns1.digitalocean.com
ns2.digitalocean.com
ns3.digitalocean.com
```

**Masalan, Namecheap da:**
1. Domain list → **Manage**
2. **Nameservers** → Custom DNS
3. DigitalOcean nameserverlarni kiriting

> **Eslatma:** DNS propagation 1-24 soat davom etadi (odatda 1 soat)

---

### **Scenario 2: Domain Cloudflare da** (Ko'p ishlatiladigan)

#### **Step 1: Cloudflare da A Record qo'shish**

1. Cloudflare dashboard → Sizning domain
2. **DNS** → **Records** → **Add record**

**A Record:**
- **Type:** A
- **Name:** `@` (root) yoki `erp` (subdomain)
- **IPv4 address:** `137.184.83.134`
- **Proxy status:** 🟠 DNS only (SSL setup qilguncha)
- **TTL:** Auto

**WWW Record:**
- **Type:** A
- **Name:** `www`
- **IPv4 address:** `137.184.83.134`

#### **Step 2: SSL/TLS Mode**

- **SSL/TLS** → **Overview**
- **Mode:** `Full` (SSL setup qilgandan keyin `Full (strict)`)

---

### **Scenario 3: Boshqa Registrar (GoDaddy, Namecheap, etc.)**

**DNS Management:**

1. Domain settings → DNS Management
2. **A Record** qo'shish:
   - **Host:** `@` yoki `www`
   - **Points to:** `137.184.83.134`
   - **TTL:** 1 Hour (3600)

---

## 5️⃣ DNS Propagation Tekshirish

### **Variant 1: Terminal orqali**

```bash
# LOCAL da
dig akfa.uz +short
# Output bo'lishi kerak: 137.184.83.134

# Yoki
nslookup akfa.uz
```

### **Variant 2: Online tools**

- https://dnschecker.org - Dunyo bo'ylab tekshiradi
- https://www.whatsmydns.net

---

## 6️⃣ Domain ni Serverga Ulash

SSH orqali serverga kirib:

```bash
ssh root@137.184.83.134
```

### **Agar hali deploy qilmagan bo'lsangiz:**

`.env` da to'g'ri domain ni ko'rsating:

```bash
# .env
SITE_NAME="akfa.uz"           # .local o'rniga real domain
SETUP_SSL="true"              # SSL yoqish
SSL_DOMAIN="akfa.uz"
SSL_EMAIL="admin@akfa.uz"
```

### **Agar allaqachon deploy qilgan bo'lsangiz:**

```bash
su - frappe
cd ~/frappe-bench

# Domain qo'shish
bench setup add-domain akfa.uz --site akfa.local

# SSL setup (Let's Encrypt - FREE)
sudo bench setup lets-encrypt akfa.uz

# Yoki manual (agar Cloudflare SSL bo'lsa)
bench set-ssl-certificate akfa.uz /path/to/cert.crt
bench set-ssl-key akfa.uz /path/to/cert.key
```

---

## 7️⃣ SSL Certificate (HTTPS)

### **Variant A: Let's Encrypt** ✅ (FREE, avtomatik)

```bash
su - frappe
cd ~/frappe-bench

sudo bench setup lets-encrypt akfa.uz
# Email kiriting: admin@akfa.uz
# Agree to terms: Y
```

**Test:**
```bash
https://akfa.uz  # HTTPS bilan ochilishi kerak
```

### **Variant B: Cloudflare SSL** (Universal SSL)

Cloudflare da:
1. **SSL/TLS** → **Overview**
2. **Encryption mode:** `Full (strict)`
3. **Edge Certificates:** Auto (FREE Universal SSL)

Serverda nginx config:
```bash
# Cloudflare Origin Certificate generate qiling
# SSL/TLS → Origin Server → Create Certificate
# Certificate va Private Key ni save qiling

sudo nano /etc/nginx/conf.d/akfa.uz.conf
# SSL sertifikat yo'llarini ko'rsating
```

---

## 8️⃣ Server Monitoring

### **DigitalOcean Monitoring:**

1. Droplet → **Graphs** tab
2. CPU, Memory, Disk, Bandwidth ko'rsatadi

### **Alerts o'rnatish:**

1. **Monitoring** → **Alerts** → **Create Alert Policy**
2. **Metric:** CPU usage
3. **Threshold:** `> 80%` for `5 minutes`
4. **Notify:** Email

---

## 9️⃣ Backup Sozlash

### **DigitalOcean Snapshots:**

**Manual Snapshot:**
1. Droplet → **Snapshots** → **Take Snapshot**
2. Name: `frappe-prod-before-update-2025-11-03`
3. Wait 2-5 minutes

**Automated Backups:** (+20% droplet narxi)
1. Droplet → **Settings** → **Backups**
2. **Enable Backups** ($2.40/mo for $12 droplet)
3. Weekly automatic snapshots

### **Frappe Bench Backup:**

```bash
su - frappe
cd ~/frappe-bench

# Manual backup
bench --site akfa.uz backup --with-files

# Backup fayllar:
# ~/frappe-bench/sites/akfa.uz/private/backups/

# Cron (avtomatik kunlik backup)
bench --site akfa.uz scheduler enable
# Bench auto-backup qiladi (default: daily)
```

---

## 🔟 Post-Deployment Checklist

- [ ] Server yaratildi va SSH orqali kiriladi
- [ ] Firewall sozlandi (22, 80, 443 portlar ochiq)
- [ ] Domain DNS records qo'shildi
- [ ] DNS propagation tugadi (dig bilan tekshirildi)
- [ ] Frappe deploy qilindi
- [ ] Domain serverga ulandi
- [ ] SSL certificate o'rnatildi (HTTPS ishlayapti)
- [ ] Site ochiladi va login qilish mumkin
- [ ] Backup strategiya sozlandi
- [ ] Monitoring va alerts yoqildi

---

## 🐛 Troubleshooting

### **Issue 1: SSH connection refused**

```bash
# Firewall tekshirish
# DigitalOcean Firewall → Port 22 ochiqmi?

# Droplet console orqali kirish (Emergency Access)
# Droplet → Access → Launch Droplet Console
```

### **Issue 2: Domain ochilmayapti**

```bash
# DNS propagation tekshirish
dig akfa.uz +short

# Nginx running?
sudo systemctl status nginx

# Logs
sudo tail -f /var/log/nginx/error.log
```

### **Issue 3: SSL certificate error**

```bash
# Let's Encrypt renew
sudo certbot renew

# Manual renew
sudo bench renew-lets-encrypt
```

### **Issue 4: Site slow / crashed**

```bash
# Check resources
htop    # yoki top
df -h   # Disk space
free -h # RAM

# DigitalOcean Graphs da ham ko'ring
# Agar RAM to'lib ketgan bo'lsa → Resize droplet
```

---

## 📞 Useful Commands

```bash
# Server info
uname -a            # OS version
df -h               # Disk usage
free -h             # RAM usage
uptime              # Server uptime

# Network
ip addr             # IP addresses
netstat -tulpn      # Open ports
curl ifconfig.me    # Public IP

# Services
sudo systemctl status nginx
sudo systemctl status mariadb
sudo supervisorctl status

# Frappe
su - frappe
cd ~/frappe-bench
bench version       # Frappe version
bench --site akfa.uz doctor  # Health check
```

---

## 🎓 Resources

- **DigitalOcean Docs:** https://docs.digitalocean.com
- **Community Tutorials:** https://www.digitalocean.com/community/tutorials
- **Frappe Docs:** https://frappeframework.com/docs/user/en/installation
- **Let's Encrypt:** https://letsencrypt.org

---

## 💰 Cost Estimation

**Monthly Costs:**

| Service | Price |
|---------|-------|
| Droplet (2GB) | $12 |
| Backups (20%) | $2.40 |
| Snapshots (10GB) | $1 |
| **Total** | **~$15.40/mo** |

**Yearly:** ~$185

**Scaling options:**
- Resize droplet (vertical scaling)
- Add load balancer (horizontal scaling)
- Add managed database (separate DB server)

---

**Last Updated:** November 3, 2025  
**Tested on:** Ubuntu 24.04 LTS, DigitalOcean Droplets  
**Author:** Asadbek (@Asadtop4ik)
