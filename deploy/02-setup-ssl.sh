#!/bin/bash

###############################################################################
# SSL CERTIFICATE SETUP SCRIPT
# Purpose: Setup Let's Encrypt SSL for Frappe/ERPNext site
# Usage: sudo bash deploy/02-setup-ssl.sh
# Requirements: 
#   - Base deployment completed (deploy.sh)
#   - Domain DNS configured and propagated
#   - Domain pointing to this server
###############################################################################

set -e

# ============================================
# COLORS & LOGGING
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# ============================================
# LOAD CONFIGURATION
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    error ".env fayl topilmadi! Avval deploy.sh ni ishga tushiring"
fi

source "$PROJECT_ROOT/.env"

# ============================================
# CHECK ROOT
# ============================================
if [ "$EUID" -ne 0 ]; then 
    error "Bu scriptni root sifatida ishga tushiring: sudo bash $0"
fi

# ============================================
# VALIDATION
# ============================================
log "Konfiguratsiya tekshirilmoqda..."

[ -z "$SITE_NAME" ] && error "SITE_NAME o'rnatilmagan!"
[ -z "$SSL_DOMAIN" ] && error "SSL_DOMAIN o'rnatilmagan! .env da SSL_DOMAIN ni belgilang"
[ -z "$SSL_EMAIL" ] && error "SSL_EMAIL o'rnatilmagan! .env da SSL_EMAIL ni belgilang"

# Check if bench exists
if [ ! -d "$BENCH_PATH" ]; then
    error "Bench topilmadi: $BENCH_PATH. Avval deploy.sh ni ishga tushiring"
fi

log "Konfiguratsiya to'g'ri ✓"

# ============================================
# DNS CHECK
# ============================================
log "DNS tekshirilmoqda..."

SERVER_IP=$(hostname -I | awk '{print $1}')
info "Server IP: $SERVER_IP"

# Try to resolve domain
DOMAIN_IP=$(dig +short $SSL_DOMAIN @8.8.8.8 | tail -1)

if [ -z "$DOMAIN_IP" ]; then
    error "Domain '$SSL_DOMAIN' resolve bo'lmadi! DNS sozlamalarini tekshiring"
fi

info "Domain IP: $DOMAIN_IP"

if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
    warning "DNS mismatch!"
    warning "  Server IP: $SERVER_IP"
    warning "  Domain IP: $DOMAIN_IP"
    echo ""
    read -p "Davom etamizmi? (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
        error "Foydalanuvchi bekor qildi"
    fi
fi

log "DNS tekshiruv tugadi ✓"

# ============================================
# INSTALL CERTBOT
# ============================================
log "Certbot o'rnatilmoqda..."

apt-get update -qq
apt-get install -y certbot python3-certbot-nginx

log "Certbot o'rnatildi ✓"

# ============================================
# SETUP LET'S ENCRYPT
# ============================================
log "Let's Encrypt sozlanmoqda..."
info "Domain: $SSL_DOMAIN"
info "Email: $SSL_EMAIL"

sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

echo "🔒 Setting up SSL certificate..."
sudo bench setup lets-encrypt $SITE_NAME \\
    --custom-domain $SSL_DOMAIN \\
    --email $SSL_EMAIL

EOF

log "SSL sertifikat o'rnatildi ✓"

# ============================================
# VERIFY SSL
# ============================================
log "SSL tekshirilmoqda..."

sleep 5

if curl -sI "https://$SSL_DOMAIN" | grep -q "HTTP/2 200"; then
    log "✅ SSL muvaffaqiyatli o'rnatildi!"
    info "Site: https://$SSL_DOMAIN"
else
    warning "SSL sozlandi, lekin HTTPS javob bermayapti"
    warning "Bir necha daqiqadan keyin tekshiring: https://$SSL_DOMAIN"
fi

# ============================================
# AUTO-RENEWAL SETUP
# ============================================
log "SSL auto-renewal sozlanmoqda..."

# Check if cron job exists
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    # Add cron job for auto-renewal
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    log "Auto-renewal cron job qo'shildi ✓"
else
    info "Auto-renewal allaqachon sozlangan"
fi

# ============================================
# SUCCESS MESSAGE
# ============================================
log "=================================================="
log "🎉 SSL MUVAFFAQIYATLI O'RNATILDI! 🎉"
log "=================================================="
echo ""
info "Site URL: https://$SSL_DOMAIN"
info "Certificate: Let's Encrypt"
info "Auto-renewal: Enabled (har kuni 3:00 AM)"
echo ""
info "Foydali buyruqlar:"
info "  certbot certificates                    # Sertifikatlarni ko'rish"
info "  certbot renew --dry-run                 # Test renewal"
info "  certbot renew --force-renewal           # Manual renewal"
log "=================================================="
