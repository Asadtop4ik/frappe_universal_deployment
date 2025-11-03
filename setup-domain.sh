#!/bin/bash

###############################################################################
# DOMAIN SETUP SCRIPT FOR FRAPPE/ERPNEXT
# Purpose: Add domain and setup SSL for existing Frappe site
# Usage: ./setup-domain.sh
###############################################################################

set -e

# ============================================
# COLORS
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
║   FRAPPE DOMAIN SETUP SCRIPT                 ║
║   Add domain and SSL to existing site        ║
╚═══════════════════════════════════════════════╝
EOF
echo ""

# ============================================
# CHECK ROOT
# ============================================
if [ "$EUID" -ne 0 ]; then 
    error "Script ni root sifatida ishga tushiring: sudo bash $0"
fi

# ============================================
# CONFIGURATION INPUT
# ============================================
log "Konfiguratsiya ma'lumotlarini kiriting..."
echo ""

# Existing site name
read -p "🌐 Site nomi (masalan: mysite.local): " SITE_NAME
[ -z "$SITE_NAME" ] && error "Site name bo'sh bo'lishi mumkin emas!"

# Domain to add
read -p "🔗 Qo'shmoqchi bo'lgan domain (masalan: akfa.uz): " DOMAIN
[ -z "$DOMAIN" ] && error "Domain bo'sh bo'lishi mumkin emas!"

# SSL setup
read -p "🔒 SSL (HTTPS) o'rnatilsinmi? (y/n): " SETUP_SSL
if [[ "$SETUP_SSL" =~ ^[Yy]$ ]]; then
    read -p "📧 Email address (Let's Encrypt uchun): " SSL_EMAIL
    [ -z "$SSL_EMAIL" ] && error "Email bo'sh bo'lishi mumkin emas!"
fi

# Frappe user (default: frappe)
read -p "👤 Frappe user (default: frappe): " FRAPPE_USER
FRAPPE_USER=${FRAPPE_USER:-frappe}

# Bench path
read -p "📁 Bench path (default: /home/frappe/frappe-bench): " BENCH_PATH
BENCH_PATH=${BENCH_PATH:-/home/$FRAPPE_USER/frappe-bench}

echo ""
log "Ma'lumotlar qabul qilindi. Davom etamizmi?"
info "Site: $SITE_NAME"
info "Domain: $DOMAIN"
info "SSL: ${SETUP_SSL}"
info "Bench: $BENCH_PATH"
echo ""
read -p "Davom etamiz? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && error "Bekor qilindi."

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

log "Tekshiruvlar muvaffaqiyatli ✓"

# ============================================
# DNS CHECK
# ============================================
log "DNS checking..."

RESOLVED_IP=$(dig +short "$DOMAIN" | tail -1)
SERVER_IP=$(curl -s ifconfig.me)

if [ -z "$RESOLVED_IP" ]; then
    warning "Domain DNS records topilmadi!"
    warning "DNS sozlamalarini tekshiring:"
    warning "  A Record: $DOMAIN → $SERVER_IP"
    echo ""
    read -p "DNS sozlangan va propagate bo'lganini tasdiqlaysizmi? (y/n): " DNS_CONFIRM
    [[ ! "$DNS_CONFIRM" =~ ^[Yy]$ ]] && error "DNS sozlang va qayta urinib ko'ring."
else
    if [ "$RESOLVED_IP" = "$SERVER_IP" ]; then
        log "DNS to'g'ri sozlangan! $DOMAIN → $RESOLVED_IP ✓"
    else
        warning "DNS noto'g'ri!"
        warning "  Domain points to: $RESOLVED_IP"
        warning "  Server IP: $SERVER_IP"
        echo ""
        read -p "Baribir davom etamizmi? (y/n): " CONTINUE
        [[ ! "$CONTINUE" =~ ^[Yy]$ ]] && error "DNS ni to'g'rilang va qayta urinib ko'ring."
    fi
fi

# ============================================
# BACKUP CURRENT CONFIGURATION
# ============================================
log "Backup yaratilmoqda..."

BACKUP_DIR="/root/domain_setup_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup nginx configs
cp /etc/nginx/nginx.conf "$BACKUP_DIR/" 2>/dev/null || true
cp -r /etc/nginx/sites-enabled/ "$BACKUP_DIR/" 2>/dev/null || true

# Backup site config
cp "$BENCH_PATH/sites/$SITE_NAME/site_config.json" "$BACKUP_DIR/"

log "Backup saqlandi: $BACKUP_DIR ✓"

# ============================================
# ADD DOMAIN TO SITE
# ============================================
log "Domain site ga qo'shilmoqda..."

sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

# Add domain
bench setup add-domain $DOMAIN --site $SITE_NAME

# Verify
bench --site $SITE_NAME show-config | grep -i "host_name"

EOF

log "Domain qo'shildi ✓"

# ============================================
# SETUP SSL (if requested)
# ============================================
if [[ "$SETUP_SSL" =~ ^[Yy]$ ]]; then
    log "SSL o'rnatilmoqda (Let's Encrypt)..."
    
    # Install certbot if not present
    if ! command -v certbot &> /dev/null; then
        log "Certbot o'rnatilmoqda..."
        apt-get update -y
        apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Setup Let's Encrypt
    sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

# Let's Encrypt setup
sudo bench setup lets-encrypt $SITE_NAME \
    --custom-domain $DOMAIN \
    --email $SSL_EMAIL

EOF
    
    log "SSL o'rnatildi ✓"
    
    # Setup auto-renewal
    log "SSL auto-renewal sozlanmoqda..."
    
    CRON_JOB="0 0 * * * certbot renew --quiet && supervisorctl restart all"
    
    # Check if cron job already exists
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        log "Auto-renewal cron job qo'shildi ✓"
    else
        info "Auto-renewal cron job allaqachon mavjud"
    fi
else
    log "SSL o'rnatilmadi (HTTP only)"
fi

# ============================================
# UPDATE NGINX CONFIGURATION
# ============================================
log "Nginx konfiguratsiya yangilanmoqda..."

sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

# Setup nginx config
bench setup nginx --yes

EOF

# Reload nginx
systemctl reload nginx

log "Nginx yangilandi ✓"

# ============================================
# REBUILD AND RESTART
# ============================================
log "Services qayta ishga tushirilmoqda..."

sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

# Clear cache
bench --site $SITE_NAME clear-cache
bench --site $SITE_NAME clear-website-cache

# Build (if needed)
bench build --force

EOF

# Restart all services
supervisorctl restart all
systemctl reload nginx

log "Services qayta ishga tushirildi ✓"

# ============================================
# HEALTH CHECK
# ============================================
log "Health check..."

sleep 5

# Check HTTPS (if SSL enabled)
if [[ "$SETUP_SSL" =~ ^[Yy]$ ]]; then
    SITE_URL="https://$DOMAIN"
else
    SITE_URL="http://$DOMAIN"
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L "$SITE_URL" || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    log "✅ Site accessible! (HTTP $HTTP_CODE)"
elif [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    log "✅ Site redirecting (HTTP $HTTP_CODE) - Bu normal"
else
    warning "Site returned HTTP $HTTP_CODE"
    warning "Manual tekshirish kerak bo'lishi mumkin"
fi

# ============================================
# SUMMARY
# ============================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          DOMAIN SETUP COMPLETED!              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
info "🌐 Domain: $DOMAIN"
info "📁 Site: $SITE_NAME"

if [[ "$SETUP_SSL" =~ ^[Yy]$ ]]; then
    info "🔒 SSL: Enabled (HTTPS)"
    info "🌐 URL: https://$DOMAIN"
else
    info "🔒 SSL: Not enabled"
    info "🌐 URL: http://$DOMAIN"
fi

echo ""
log "Next Steps:"
echo "  1. Brauzerda ochib ko'ring: $SITE_URL"
echo "  2. Login qiling va ishlashini tekshiring"
if [[ ! "$SETUP_SSL" =~ ^[Yy]$ ]]; then
    echo "  3. SSL uchun qayta scriptni ishga tushiring"
fi
echo ""

log "Backup location: $BACKUP_DIR"
echo ""

# ============================================
# ADDITIONAL INFO
# ============================================
cat << EOF

📚 Useful Commands:

# View site config
sudo -u $FRAPPE_USER bench --site $SITE_NAME show-config

# Check SSL certificate
sudo certbot certificates

# Manual SSL renewal
sudo certbot renew

# View nginx config
cat /etc/nginx/conf.d/$SITE_NAME.conf

# Restart services
sudo supervisorctl restart all
sudo systemctl reload nginx

# View logs
sudo -u $FRAPPE_USER bench --site $SITE_NAME logs

EOF

log "Setup yakunlandi! 🎉"
