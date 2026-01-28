# Domain & SSL Setup Script

**Script:** `02-setup-domain-ssl.sh`
**Version:** 2.0
**Last Updated:** 2026-01-28

## Overview

Bu script Frappe/ERPNext saytiga domain va SSL sertifikat qo'shish uchun to'liq avtomatlashtirilgan yechim. Script hech qanday user input kutmasdan ishlaydi (non-interactive mode).

## Requirements

- Base deployment tugallangan (`deploy.sh` ishlatilgan)
- Domain DNS sozlangan (A record server IP ga yo'naltirilgan)
- Root access
- Internet connection

## Quick Start

### Interactive Mode (default)
```bash
sudo bash deploy/02-setup-domain-ssl.sh
```

### Fully Automated Mode
```bash
AUTO_CONFIRM=yes \
SITE_NAME="mysite.local" \
SSL_DOMAIN="mydomain.com" \
SSL_EMAIL="admin@mydomain.com" \
sudo bash deploy/02-setup-domain-ssl.sh
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SITE_NAME` | Yes | - | Frappe site nomi (masalan: `mysite.local`) |
| `SSL_DOMAIN` | Yes | - | Domain nomi (masalan: `erp.company.uz`) |
| `SSL_EMAIL` | Yes | - | SSL sertifikat uchun email |
| `FRAPPE_USER` | No | `frappe` | Frappe user nomi |
| `BENCH_PATH` | No | `/home/frappe/frappe-bench` | Bench yo'li |
| `AUTO_CONFIRM` | No | `no` | `yes` = barcha promptlarni skip qilish |
| `USE_STAGING` | No | `no` | `yes` = Let's Encrypt staging server (test uchun) |

## Usage Examples

### 1. Basic Interactive Setup
```bash
sudo bash deploy/02-setup-domain-ssl.sh
```
Script sizdan quyidagilarni so'raydi:
- Site nomi
- Domain
- Email
- Frappe user
- Bench path

### 2. CI/CD Pipeline (Fully Automated)
```bash
#!/bin/bash
export AUTO_CONFIRM="yes"
export SITE_NAME="production.local"
export SSL_DOMAIN="erp.mycompany.com"
export SSL_EMAIL="devops@mycompany.com"
export FRAPPE_USER="frappe"
export BENCH_PATH="/home/frappe/frappe-bench"

sudo -E bash deploy/02-setup-domain-ssl.sh
```

### 3. Testing (Rate Limit Bypass)
Let's Encrypt 1 hafta ichida 5 ta sertifikat beradi. Test qilayotganda staging server ishlating:
```bash
USE_STAGING=yes AUTO_CONFIRM=yes \
SITE_NAME="test.local" \
SSL_DOMAIN="test.example.com" \
SSL_EMAIL="test@example.com" \
sudo bash deploy/02-setup-domain-ssl.sh
```
> **Note:** Staging sertifikatlar brauzerda "Not Secure" ko'rsatadi, lekin workflow test qilish uchun yetarli.

### 4. Using .env File
Agar `.env` fayl mavjud bo'lsa, script undan o'qiydi:
```bash
# .env file
SITE_NAME=mysite.local
SSL_DOMAIN=erp.company.uz
SSL_EMAIL=admin@company.uz
FRAPPE_USER=frappe
BENCH_PATH=/home/frappe/frappe-bench
```

Keyin:
```bash
AUTO_CONFIRM=yes sudo bash deploy/02-setup-domain-ssl.sh
```

## What the Script Does

### Step 1: Domain Setup
1. DNS validatsiyasi (domain IP tekshiruvi)
2. Domain site ga qo'shish (`bench setup add-domain`)
3. Nginx config regenerate (`bench setup nginx`)
4. Nginx reload

### Step 2: SSL Certificate
1. Certbot o'rnatish (agar yo'q bo'lsa)
2. Let's Encrypt sertifikat olish
3. Nginx SSL configuration (Python script orqali)
4. HTTP → HTTPS redirect qo'shish
5. Nginx test va reload

### Step 3: Auto-Renewal
1. Certbot timer tekshirish
2. Cron job sozlash (agar kerak bo'lsa)

## Output Example

```
╔═══════════════════════════════════════════════╗
║     FRAPPE DOMAIN & SSL SETUP                ║
║     Frappe-Native Method (Recommended)       ║
╚═══════════════════════════════════════════════╝

[INFO] Site: mysite.local (auto)
[INFO] Domain: erp.company.uz (auto)
[INFO] Email: admin@company.uz (auto)

[2026-01-28 10:00:00] STEP 1/3: Domain site ga qo'shilmoqda...
✅ Domain added. Verifying configuration...
✓ Step 1 completed successfully

[2026-01-28 10:00:02] STEP 2/3: SSL sertifikat o'rnatilmoqda...
[INFO] 🔒 Setting up Let's Encrypt SSL with certbot...
Successfully received certificate.
[INFO] ✅ Nginx configuration valid
✓ Step 2 completed successfully

[2026-01-28 10:00:10] STEP 3/3: SSL auto-renewal sozlanmoqda...
✓ Auto-renewal configured

╔═══════════════════════════════════════════════╗
║     DOMAIN & SSL SETUP COMPLETED! 🎉         ║
╚═══════════════════════════════════════════════╝

✅ Site URL: https://erp.company.uz
```

## Troubleshooting

### DNS Not Resolving
```
[WARNING] Domain 'example.com' resolve bo'lmadi!
```
**Solution:** DNS A record qo'shing va 5-10 daqiqa kuting.
```bash
# DNS tekshirish
dig example.com +short
nslookup example.com
```

### Let's Encrypt Rate Limit
```
too many certificates (5) already issued for this exact set of identifiers
```
**Solution:**
- Staging server ishlating: `USE_STAGING=yes`
- Yoki 1 hafta kuting

### Nginx Config Error
```
[ERROR] Nginx configuration test failed!
```
**Solution:** Script avtomatik backup tiklaydi. Manual tekshirish:
```bash
sudo nginx -t
sudo cat /home/frappe/frappe-bench/config/nginx.conf
```

### Certificate Not Found
```
[ERROR] SSL certificate not found after installation!
```
**Solution:**
```bash
sudo certbot certificates
sudo certbot certonly --standalone -d yourdomain.com
```

## Manual Commands

### SSL Sertifikatlarni Ko'rish
```bash
sudo certbot certificates
```

### SSL Manual Yangilash
```bash
sudo certbot renew --force-renewal
```

### Nginx Config Qayta Yaratish
```bash
su - frappe
cd ~/frappe-bench
bench setup nginx --yes
exit
sudo systemctl reload nginx
```

### Domain O'chirish
```bash
su - frappe
cd ~/frappe-bench
bench --site mysite.local remove-from-hosts mydomain.com
```

### SSL Muddatini Tekshirish
```bash
echo | openssl s_client -servername yourdomain.com -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
```

## Security Notes

- SSL sertifikatlar `/etc/letsencrypt/live/` da saqlanadi
- Private key faqat root o'qiy oladi
- Auto-renewal har kuni tekshiriladi
- TLS 1.2 va 1.3 protokollari ishlatiladi

## Backup & Recovery

Script har safar backup yaratadi:
```
/root/domain_ssl_backup_YYYYMMDD_HHMMSS/
├── nginx.conf.backup
├── site_config.json.backup
└── ssl_info.txt
```

Tiklash:
```bash
# Nginx config tiklash
sudo cp /root/domain_ssl_backup_*/nginx.conf.backup /home/frappe/frappe-bench/config/nginx.conf
sudo chown frappe:frappe /home/frappe/frappe-bench/config/nginx.conf
sudo systemctl reload nginx
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Setup Domain & SSL
  run: |
    ssh root@${{ secrets.SERVER_IP }} << 'EOF'
    export AUTO_CONFIRM="yes"
    export SITE_NAME="${{ secrets.SITE_NAME }}"
    export SSL_DOMAIN="${{ secrets.DOMAIN }}"
    export SSL_EMAIL="${{ secrets.EMAIL }}"
    bash /root/deploy/02-setup-domain-ssl.sh
    EOF
```

### GitLab CI Example
```yaml
deploy_ssl:
  script:
    - ssh root@$SERVER_IP "AUTO_CONFIRM=yes SITE_NAME=$SITE_NAME SSL_DOMAIN=$DOMAIN SSL_EMAIL=$EMAIL bash /root/deploy/02-setup-domain-ssl.sh"
```

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0 | 2026-01-28 | Full automation, Python nginx config, HTTP redirect |
| 1.5 | 2026-01-25 | Added AUTO_CONFIRM mode |
| 1.0 | 2026-01-20 | Initial release |

---

**Author:** DevOps Team
**Support:** Create an issue at GitHub repository
