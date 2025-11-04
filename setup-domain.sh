#!/bin/bash

###############################################################################
# DOMAIN SETUP SCRIPT FOR FRAPPE/ERPNEXT
# Author: Senior DevOps Engineer
# Version: 2.0 (2025-11-04)
# Purpose: Add domain and setup SSL for existing Frappe site
#
# USAGE:
#   1. DigitalOcean da DNS sozlang:
#      - A Record: yourdomain.com → SERVER_IP
#      - A Record: www.yourdomain.com → SERVER_IP
#   2. 5-10 daqiqa DNS propagation kutish
#   3. Script ishga tushiring: sudo ./setup-domain.sh
#
# FEATURES:
#   ✅ Automatic domain addition to Frappe site
#   ✅ Let's Encrypt SSL certificate (HTTPS)
#   ✅ Auto-renewal cron job
#   ✅ Nginx configuration with SSL
#   ✅ HTTP to HTTPS redirect
#   ✅ Backup before changes
#
# REQUIREMENTS:
#   - Root access
#   - DNS A record configured (manual in DigitalOcean)
#   - Existing Frappe site
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
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y certbot python3-certbot-nginx -qq
    fi
    
    # Get SSL certificate
    log "SSL sertifikat olinmoqda..."
    certbot certonly --nginx \
        -d $DOMAIN \
        -d www.$DOMAIN \
        --non-interactive \
        --agree-tos \
        --email $SSL_EMAIL \
        --quiet || {
            warning "Certbot xatolik berdi, manual configuration ishlatilmoqda..."
        }
    
    # Check if certificate exists
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        log "SSL sertifikat muvaffaqiyatli olindi ✓"
        
        # Configure Nginx with SSL
        log "Nginx SSL konfiguratsiya qilinmoqda..."
        
        # Create SSL snippet
        cat > /tmp/ssl_snippet_$DOMAIN.conf << SSLEOF
    # SSL Configuration
    listen 443 ssl http2;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # HTTP to HTTPS redirect
    if (\$scheme != "https") {
        return 301 https://\$host\$request_uri;
    }
SSLEOF
        
        # Add SSL to nginx config
        if ! grep -q "ssl_certificate.*$DOMAIN" /etc/nginx/sites-available/frappe-bench.conf; then
            sed -i "/listen 80;/a\    include /tmp/ssl_snippet_$DOMAIN.conf;" /etc/nginx/sites-available/frappe-bench.conf
            log "Nginx SSL config qo'shildi ✓"
        else
            info "SSL config allaqachon mavjud"
        fi
        
        # Test nginx
        if nginx -t 2>/dev/null; then
            systemctl reload nginx
            log "Nginx qayta yuklandi ✓"
        else
            error "Nginx config xatosi! Manual tekshiring: nginx -t"
        fi
        
        log "SSL o'rnatildi ✓"
    else
        error "SSL sertifikat olinmadi! DNS to'g'ri sozlanganini tekshiring."
    fi
    
    # Setup auto-renewal
    log "SSL auto-renewal sozlanmoqda..."
    
    CRON_JOB="0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'"
    
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
info "🖥️  Server IP: $SERVER_IP"

if [[ "$SETUP_SSL" =~ ^[Yy]$ ]]; then
    info "🔒 SSL: Enabled (HTTPS)"
    info "🌐 URL: https://$DOMAIN"
    info "🔄 Auto-renewal: Configured (daily check at 3 AM)"
    info "📅 Certificate expires: $(openssl x509 -enddate -noout -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem 2>/dev/null | cut -d= -f2 || echo 'N/A')"
else
    info "🔒 SSL: Not enabled (HTTP only)"
    info "🌐 URL: http://$DOMAIN"
fi

echo ""
log "✅ Next Steps:"
echo "  1. Brauzerda ochib ko'ring: https://$DOMAIN"
echo "  2. Login: Administrator / [your password]"
echo "  3. SSL badge tekshiring (🔒 Secure)"
if [[ ! "$SETUP_SSL" =~ ^[Yy]$ ]]; then
    echo "  4. SSL uchun qayta scriptni ishga tushiring"
fi
echo ""

info "💾 Backup location: $BACKUP_DIR"
info "📝 Logs: /var/log/letsencrypt/letsencrypt.log"
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
