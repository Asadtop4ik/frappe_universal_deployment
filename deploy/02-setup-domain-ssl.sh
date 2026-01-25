#!/bin/bash

###############################################################################
# DOMAIN & SSL SETUP SCRIPT
# Purpose: Add domain and SSL certificate to existing Frappe site
# Usage: sudo bash deploy/02-setup-domain-ssl.sh
# Requirements: 
#   - Base deployment completed (deploy.sh)
#   - Domain DNS configured and propagated
#   - Domain A record pointing to this server
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
# BANNER
# ============================================
clear
cat << "EOF"
╔═══════════════════════════════════════════════╗
║     FRAPPE DOMAIN & SSL SETUP                ║
║     Frappe-Native Method (Recommended)       ║
╚═══════════════════════════════════════════════╝
EOF
echo ""

# ============================================
# CHECK ROOT
# ============================================
if [ "$EUID" -ne 0 ]; then 
    error "Bu scriptni root sifatida ishga tushiring: sudo bash $0"
fi

# ============================================
# LOAD CONFIGURATION
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Try to load .env if exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    info "Konfiguratsiya .env dan yuklandi"
else
    warning ".env fayl topilmadi - manual konfiguratsiya"
fi

# ============================================
# INTERACTIVE CONFIGURATION
# ============================================
log "Konfiguratsiya ma'lumotlarini kiriting..."
echo ""

# Site name (from .env or ask)
if [ -z "$SITE_NAME" ]; then
    read -p "🌐 Site nomi (masalan: mysite.local): " SITE_NAME
else
    read -p "🌐 Site nomi [$SITE_NAME]: " INPUT_SITE
    SITE_NAME=${INPUT_SITE:-$SITE_NAME}
fi
[ -z "$SITE_NAME" ] && error "Site name bo'sh bo'lishi mumkin emas!"

# Domain to add
if [ -z "$SSL_DOMAIN" ]; then
    read -p "🔗 Domain (masalan: akfa.uz): " DOMAIN
else
    read -p "🔗 Domain [$SSL_DOMAIN]: " INPUT_DOMAIN
    DOMAIN=${INPUT_DOMAIN:-$SSL_DOMAIN}
fi
[ -z "$DOMAIN" ] && error "Domain bo'sh bo'lishi mumkin emas!"

# Email for SSL
if [ -z "$SSL_EMAIL" ]; then
    read -p "📧 Email (SSL uchun): " EMAIL
else
    read -p "📧 Email [$SSL_EMAIL]: " INPUT_EMAIL
    EMAIL=${INPUT_EMAIL:-$SSL_EMAIL}
fi
[ -z "$EMAIL" ] && error "Email bo'sh bo'lishi mumkin emas!"

# Frappe user (default: frappe)
FRAPPE_USER=${FRAPPE_USER:-frappe}
read -p "👤 Frappe user [$FRAPPE_USER]: " INPUT_USER
FRAPPE_USER=${INPUT_USER:-$FRAPPE_USER}

# Bench path
BENCH_PATH=${BENCH_PATH:-/home/$FRAPPE_USER/frappe-bench}
read -p "📁 Bench path [$BENCH_PATH]: " INPUT_PATH
BENCH_PATH=${INPUT_PATH:-$BENCH_PATH}

echo ""
log "═══════════════════════════════════════════"
log "Konfiguratsiya xulosasi:"
log "═══════════════════════════════════════════"
info "Site Name:    $SITE_NAME"
info "Domain:       $DOMAIN"
info "Email:        $EMAIL"
info "Frappe User:  $FRAPPE_USER"
info "Bench Path:   $BENCH_PATH"
log "═══════════════════════════════════════════"
echo ""
read -p "Davom etamiz? [y/N]: " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && error "Foydalanuvchi bekor qildi"

# ============================================
# VALIDATION
# ============================================
log "Tekshiruvlar..."

# Check if frappe user exists
if ! id "$FRAPPE_USER" &>/dev/null; then
    error "User '$FRAPPE_USER' topilmadi!"
fi

# Check if bench exists
if [ ! -d "$BENCH_PATH" ]; then
    error "Bench directory topilmadi: $BENCH_PATH"
fi

# Check if site exists
if [ ! -d "$BENCH_PATH/sites/$SITE_NAME" ]; then
    error "Site topilmadi: $SITE_NAME"
fi

log "Validatsiya muvaffaqiyatli ✓"

# ============================================
# DNS CHECK
# ============================================
log "DNS tekshirilmoqda..."

SERVER_IP=$(hostname -I | awk '{print $1}')
info "Server IP: $SERVER_IP"

# Try to resolve domain
DOMAIN_IP=$(dig +short $DOMAIN @8.8.8.8 | tail -1)

if [ -z "$DOMAIN_IP" ]; then
    warning "Domain '$DOMAIN' resolve bo'lmadi!"
    warning "DNS sozlamalarini tekshiring:"
    warning "  A Record: $DOMAIN → $SERVER_IP"
    echo ""
    read -p "DNS sozlangan va propagate bo'lganini tasdiqlaysizmi? [y/N]: " DNS_CONFIRM
    [[ ! "$DNS_CONFIRM" =~ ^[Yy]$ ]] && error "DNS sozlang va qayta urinib ko'ring"
else
    info "Domain resolves to: $DOMAIN_IP"
    
    if [ "$SERVER_IP" = "$DOMAIN_IP" ]; then
        log "✅ DNS to'g'ri sozlangan!"
    else
        warning "⚠️  DNS mismatch:"
        warning "   Server IP: $SERVER_IP"
        warning "   Domain IP: $DOMAIN_IP"
        echo ""
        read -p "Davom etamizmi? [y/N]: " CONTINUE
        [[ ! "$CONTINUE" =~ ^[Yy]$ ]] && error "DNS ni to'g'rilang va qayta urinib ko'ring"
    fi
fi

log "DNS tekshiruv tugadi ✓"

# ============================================
# BACKUP CURRENT CONFIGURATION
# ============================================
log "Backup yaratilmoqda..."

BACKUP_DIR="/root/domain_ssl_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup site config
if [ -f "$BENCH_PATH/sites/$SITE_NAME/site_config.json" ]; then
    cp "$BENCH_PATH/sites/$SITE_NAME/site_config.json" "$BACKUP_DIR/"
fi

# Backup nginx configs
if [ -d "/etc/nginx/sites-enabled" ]; then
    cp -r /etc/nginx/sites-enabled/ "$BACKUP_DIR/" 2>/dev/null || true
fi

log "Backup saqlandi: $BACKUP_DIR ✓"

# ============================================
# STEP 1: ADD DOMAIN TO SITE
# ============================================
log "═══════════════════════════════════════════"
log "STEP 1/3: Domain site ga qo'shilmoqda..."
log "═══════════════════════════════════════════"

sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

echo "🔗 Adding domain: $DOMAIN"

# Add domain using Frappe's built-in command
bench setup add-domain $DOMAIN --site $SITE_NAME

# Verify domain was added
echo ""
echo "✅ Domain added. Current site configuration:"
bench --site $SITE_NAME show-config | grep -A 5 "host_name"

EOF

log "Domain muvaffaqiyatli qo'shildi ✓"

# ============================================
# STEP 2: SETUP SSL (Let's Encrypt)
# ============================================
log "═══════════════════════════════════════════"
log "STEP 2/3: SSL sertifikat o'rnatilmoqda..."
log "═══════════════════════════════════════════"

# Install certbot if not present
if ! command -v certbot &> /dev/null; then
    log "Certbot o'rnatilmoqda..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y certbot python3-certbot-nginx -qq
    log "Certbot o'rnatildi ✓"
fi

info "Let's Encrypt sertifikat olinmoqda..."
info "Bu 30-60 soniya davom etishi mumkin..."
echo ""

sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

echo "🔒 Setting up Let's Encrypt SSL..."

# Use Frappe's built-in Let's Encrypt setup
sudo bench setup lets-encrypt $SITE_NAME \\
    --custom-domain $DOMAIN \\
    --email $EMAIL

echo ""
echo "✅ SSL certificate installed!"

EOF

log "SSL sertifikat muvaffaqiyatli o'rnatildi ✓"

# ============================================
# STEP 3: AUTO-RENEWAL SETUP
# ============================================
log "═══════════════════════════════════════════"
log "STEP 3/3: SSL auto-renewal sozlanmoqda..."
log "═══════════════════════════════════════════"

# Check if cron job exists
if crontab -l 2>/dev/null | grep -q "certbot renew"; then
    info "Auto-renewal allaqachon sozlangan"
else
    # Add cron job for auto-renewal
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    log "Auto-renewal cron job qo'shildi ✓"
fi

info "SSL sertifikatlari har kuni 3:00 AM da tekshiriladi"

# ============================================
# VERIFICATION
# ============================================
log "═══════════════════════════════════════════"
log "Tekshirish..."
log "═══════════════════════════════════════════"

sleep 5

# Test HTTPS
SITE_URL="https://$DOMAIN"
info "Testing: $SITE_URL"

HTTP_CODE=$(curl -sL -o /dev/null -w "%{http_code}" "$SITE_URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    log "✅ Site accessible via HTTPS! (HTTP $HTTP_CODE)"
elif [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    log "✅ Site redirecting (HTTP $HTTP_CODE) - Normal"
else
    warning "⚠️  Site returned HTTP $HTTP_CODE"
    warning "Manual tekshirish kerak bo'lishi mumkin"
fi

# Show certificate info
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem 2>/dev/null | cut -d= -f2 || echo 'N/A')
    info "📅 Certificate expires: $CERT_EXPIRY"
fi

# ============================================
# SUCCESS MESSAGE
# ============================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     DOMAIN & SSL SETUP COMPLETED! 🎉         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
log "═══════════════════════════════════════════"
log "Setup Summary:"
log "═══════════════════════════════════════════"
info "✅ Domain:        $DOMAIN"
info "✅ Site:          $SITE_NAME"
info "✅ SSL:           Enabled (HTTPS)"
info "✅ Auto-renewal:  Configured"
info "✅ Site URL:      https://$DOMAIN"
echo ""
info "💾 Backup:        $BACKUP_DIR"
log "═══════════════════════════════════════════"
echo ""

# ============================================
# NEXT STEPS
# ============================================
log "📝 Next Steps:"
echo ""
echo "  1. Brauzerda ochib ko'ring:"
echo "     https://$DOMAIN"
echo ""
echo "  2. Login credentials:"
echo "     Username: Administrator"
echo "     Password: [your admin password]"
echo ""
echo "  3. SSL badge tekshiring:"
echo "     Addressbar da 🔒 icon bo'lishi kerak"
echo ""

# ============================================
# USEFUL COMMANDS
# ============================================
cat << EOF
📚 Foydali Buyruqlar:

# Site konfiguratsiyasini ko'rish
sudo -u $FRAPPE_USER bench --site $SITE_NAME show-config

# SSL sertifikatlarni ko'rish
sudo certbot certificates

# SSL ni manual yangilash
sudo certbot renew --force-renewal

# Site loglarini ko'rish
sudo -u $FRAPPE_USER bench --site $SITE_NAME logs

# Servislarni qayta ishga tushirish
sudo supervisorctl restart all
sudo systemctl reload nginx

# SSL muddatini tekshirish
echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates

EOF

log "✅ Setup yakunlandi!"
