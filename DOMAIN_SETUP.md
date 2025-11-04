# 🌐 Domain Setup Guide

## Quick Start

### 1️⃣ DigitalOcean da DNS Sozlash

```
DigitalOcean → Networking → Domains → Add Domain
```

**DNS Records qo'shing:**

| Type | Hostname | Value | TTL |
|------|----------|-------|-----|
| A | @ | 167.71.112.93 | 3600 |
| A | www | 167.71.112.93 | 3600 |

**5-10 daqiqa DNS propagation kutish:**

```bash
# Test qilish
dig yourdomain.com +short
# Ko'rsatishi kerak: 167.71.112.93
```

---

### 2️⃣ Server ga Script Upload

```bash
# LOCAL da
cd ~/Frappe/frappe_universal_deploy
scp setup-domain.sh root@YOUR_SERVER_IP:/root/
```

---

### 3️⃣ Script Ishga Tushirish

```bash
# Server da
ssh root@YOUR_SERVER_IP
cd /root
chmod +x setup-domain.sh
./setup-domain.sh
```

**Savollar:**
```
🌐 Site nomi: cashflow.local
🔗 Domain: yourdomain.com
🔒 SSL (y/n): y
📧 Email: your@email.com
👤 Frappe user: [ENTER - default]
📁 Bench path: [ENTER - default]
```

---

## 📋 To'liq Jarayon

### Example: `myapp.uz` Domain Qo'shish

**1. DNS Sozlash (DigitalOcean/Cloudflare/etc):**

```
A Record:
  myapp.uz → 167.71.112.93

A Record:
  www.myapp.uz → 167.71.112.93
```

**2. DNS Propagation Tekshirish:**

```bash
dig myapp.uz @8.8.8.8 +short
# Output: 167.71.112.93 ✅
```

**3. Script Ishga Tushirish:**

```bash
ssh root@167.71.112.93
cd /root
./setup-domain.sh
```

**4. Natija:**

```
✅ Domain qo'shildi
✅ SSL o'rnatildi
✅ HTTPS ishlamoqda
✅ Auto-renewal configured

🌐 https://myapp.uz
```

---

## 🔧 Manual Commands

### Domain Qo'shish (Bench)

```bash
ssh root@YOUR_SERVER_IP
su - frappe
cd ~/frappe-bench

bench setup add-domain yourdomain.com --site cashflow.local
bench --site cashflow.local show-config
```

### SSL O'rnatish (Certbot)

```bash
# Root sifatida
certbot --nginx \
  -d yourdomain.com \
  -d www.yourdomain.com \
  --email your@email.com \
  --agree-tos \
  --non-interactive
```

### SSL Renewal Test

```bash
certbot renew --dry-run
```

### SSL Certificate Info

```bash
certbot certificates
```

---

## 🐛 Troubleshooting

### DNS Propagate Bo'lmagan

```bash
# Test
dig yourdomain.com +short

# Agar bo'sh:
# 1. DNS settings tekshiring
# 2. 10-15 daqiqa kuting
# 3. Qayta test qiling
```

### SSL Certificate Error

```bash
# Logs tekshirish
tail -f /var/log/letsencrypt/letsencrypt.log

# Manual renewal
certbot renew --force-renewal
```

### Nginx Error

```bash
# Config test
nginx -t

# Logs
tail -f /var/log/nginx/error.log

# Restart
systemctl restart nginx
```

### Site Ochilmayapti

```bash
# Services status
supervisorctl status

# Site logs
su - frappe
cd ~/frappe-bench
bench --site cashflow.local logs

# Nginx access log
tail -f /var/log/nginx/access.log
```

---

## 📚 Foydali Commandlar

### Site Config

```bash
su - frappe
cd ~/frappe-bench
bench --site cashflow.local show-config
```

### Nginx Config

```bash
cat /etc/nginx/sites-available/frappe-bench.conf
```

### SSL Certificate Location

```bash
ls -la /etc/letsencrypt/live/yourdomain.com/
```

### Cron Jobs

```bash
crontab -l
```

---

## 🔐 Security Best Practices

1. ✅ **Always use HTTPS** (SSL)
2. ✅ **Keep SSL auto-renewal enabled**
3. ✅ **Regular backups** before changes
4. ✅ **Monitor certificate expiration**
5. ✅ **Use strong passwords**

---

## 📊 Multiple Domains

Bir site ga **ko'p domain** qo'shish:

```bash
# Domain 1
./setup-domain.sh
# Input: domain1.com

# Domain 2  
./setup-domain.sh
# Input: domain2.com

# Domain 3
./setup-domain.sh
# Input: domain3.com
```

Har biri **mustaqil SSL** certificate oladi! ✅

---

## 🎯 Quick Reference

| Task | Command |
|------|---------|
| Add domain | `bench setup add-domain DOMAIN --site SITE` |
| Setup SSL | `certbot --nginx -d DOMAIN` |
| Renew SSL | `certbot renew` |
| Check SSL | `certbot certificates` |
| Nginx test | `nginx -t` |
| Reload nginx | `systemctl reload nginx` |
| Site logs | `bench --site SITE logs` |
| Restart services | `supervisorctl restart all` |

---

## 📞 Support

**Issues?** Check:
1. DNS A record to'g'rimi?
2. DNS propagate bo'lganmi?
3. Server firewall ochiqmi? (80, 443 port)
4. Nginx running?
5. Supervisor running?

**Logs:**
```bash
/var/log/letsencrypt/letsencrypt.log
/var/log/nginx/error.log
~/frappe-bench/logs/
```

---

**Script Version:** 2.0 (2025-11-04)
**Tested on:** Ubuntu 24.04 LTS
**Frappe Version:** v15
