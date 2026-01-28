#!/bin/bash

###############################################################################
# DOMAIN & SSL SETUP SCRIPT
# Purpose: Add domain and SSL certificate to existing Frappe site
# Usage: sudo bash deploy/02-setup-domain-ssl.sh
#        or: AUTO_CONFIRM=yes sudo bash deploy/02-setup-domain-ssl.sh
# Requirements:
#   - Base deployment completed (deploy.sh)
#   - Domain DNS configured and propagated
#   - Domain A record pointing to this server
###############################################################################

set -e

# Non-interactive mode support
AUTO_CONFIRM=${AUTO_CONFIRM:-no}

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
clear 2>/dev/null || true
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
    if [[ "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
        error "AUTO_CONFIRM mode but SITE_NAME not set!"
    fi
    read -p "🌐 Site nomi (masalan: mysite.local): " SITE_NAME
else
    if [[ ! "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
        read -p "🌐 Site nomi [$SITE_NAME]: " INPUT_SITE
        SITE_NAME=${INPUT_SITE:-$SITE_NAME}
    else
        info "Site: $SITE_NAME (auto)"
    fi
fi
[ -z "$SITE_NAME" ] && error "Site name bo'sh bo'lishi mumkin emas!"

# Domain to add
if [ -z "$SSL_DOMAIN" ]; then
    if [[ "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
        error "AUTO_CONFIRM mode but SSL_DOMAIN not set!"
    fi
    read -p "🔗 Domain (masalan: akfa.uz): " DOMAIN
else
    DOMAIN="$SSL_DOMAIN"
    if [[ ! "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
        read -p "🔗 Domain [$DOMAIN]: " INPUT_DOMAIN
        DOMAIN=${INPUT_DOMAIN:-$DOMAIN}
    else
        info "Domain: $DOMAIN (auto)"
    fi
fi
[ -z "$DOMAIN" ] && error "Domain bo'sh bo'lishi mumkin emas!"

# Email for SSL
if [ -z "$SSL_EMAIL" ]; then
    if [[ "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
        error "AUTO_CONFIRM mode but SSL_EMAIL not set!"
    fi
    read -p "📧 Email (SSL uchun): " EMAIL
else
    EMAIL="$SSL_EMAIL"
    if [[ ! "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
        read -p "📧 Email [$EMAIL]: " INPUT_EMAIL
        EMAIL=${INPUT_EMAIL:-$EMAIL}
    else
        info "Email: $EMAIL (auto)"
    fi
fi
[ -z "$EMAIL" ] && error "Email bo'sh bo'lishi mumkin emas!"

# Frappe user (default: frappe)
FRAPPE_USER=${FRAPPE_USER:-frappe}
if [[ ! "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
    read -p "👤 Frappe user [$FRAPPE_USER]: " INPUT_USER
    FRAPPE_USER=${INPUT_USER:-$FRAPPE_USER}
else
    info "Frappe user: $FRAPPE_USER (auto)"
fi

# Bench path
BENCH_PATH=${BENCH_PATH:-/home/$FRAPPE_USER/frappe-bench}
if [[ ! "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
    read -p "📁 Bench path [$BENCH_PATH]: " INPUT_PATH
    BENCH_PATH=${INPUT_PATH:-$BENCH_PATH}
else
    info "Bench path: $BENCH_PATH (auto)"
fi

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
if [[ "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
    info "AUTO_CONFIRM=yes - avtomatik davom ettirilmoqda..."
    CONFIRM="y"
else
    read -p "Davom etamiz? [y/N]: " CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && error "Foydalanuvchi bekor qildi"
fi

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
    if [[ "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
        warning "AUTO_CONFIRM=yes - DNS tekshiruvi o'tkazib yuborildi"
    else
        read -p "DNS sozlangan va propagate bo'lganini tasdiqlaysizmi? [y/N]: " DNS_CONFIRM
        [[ ! "$DNS_CONFIRM" =~ ^[Yy]$ ]] && error "DNS sozlang va qayta urinib ko'ring"
    fi
else
    info "Domain resolves to: $DOMAIN_IP"
    
    if [ "$SERVER_IP" = "$DOMAIN_IP" ]; then
        log "✅ DNS to'g'ri sozlangan!"
    else
        warning "⚠️  DNS mismatch:"
        warning "   Server IP: $SERVER_IP"
        warning "   Domain IP: $DOMAIN_IP"
        echo ""
        if [[ "$AUTO_CONFIRM" =~ ^[Yy]es$ ]]; then
            warning "AUTO_CONFIRM=yes - DNS mismatch e'tiborsiz qoldirildi"
        else
            read -p "Davom etamizmi? [y/N]: " CONTINUE
            [[ ! "$CONTINUE" =~ ^[Yy]$ ]] && error "DNS ni to'g'rilang va qayta urinib ko'ring"
        fi
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
bench setup add-domain $DOMAIN --site $SITE_NAME || {
    echo "⚠️  Domain may already exist, continuing..."
}

# Verify domain was added (non-blocking)
echo ""
echo "✅ Domain added. Verifying configuration..."
bench --site $SITE_NAME show-config | grep -A 5 "host_name" || echo "Configuration check skipped"

# Regenerate nginx config to include new domain
echo ""
echo "🔄 Regenerating nginx configuration..."
echo "y" | bench setup nginx || echo "⚠️  Nginx config generation had warnings, continuing..."

echo "✓ Step 1 completed successfully"

EOF

# Ensure nginx config is properly symlinked
NGINX_BENCH_CONF="$BENCH_PATH/config/nginx.conf"
NGINX_SYMLINK="/etc/nginx/conf.d/frappe-bench.conf"

if [ ! -L "$NGINX_SYMLINK" ] || [ ! -e "$NGINX_SYMLINK" ]; then
    info "Creating nginx config symlink..."
    ln -sf "$NGINX_BENCH_CONF" "$NGINX_SYMLINK"
fi

# Reload nginx to apply new configuration
info "Reloading nginx to apply domain changes..."
systemctl reload nginx || systemctl restart nginx

log "Domain muvaffaqiyatli qo'shildi va nginx yangilandi ✓"

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

# Run SSL setup using certbot
info "🔒 Setting up Let's Encrypt SSL with certbot..."

# Check for staging mode (for testing when rate limited)
STAGING_FLAG=""
if [ "${USE_STAGING:-no}" = "yes" ]; then
    STAGING_FLAG="--staging"
    warning "Using Let's Encrypt STAGING server (certificates won't be trusted)"
fi

# Get SSL certificate using certbot - certonly first to avoid nginx plugin issues
if certbot certonly --webroot -w $BENCH_PATH/sites -d $DOMAIN --non-interactive --agree-tos --email $EMAIL $STAGING_FLAG 2>&1; then
    info "✅ Certificate obtained successfully"
elif certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email $EMAIL $STAGING_FLAG --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx" 2>&1; then
    info "✅ Certificate obtained with standalone method"
else
    error "Failed to obtain SSL certificate. If rate limited, try: USE_STAGING=yes"
fi

# Now configure nginx for SSL
info "Configuring nginx for HTTPS..."

NGINX_CONF="$BENCH_PATH/config/nginx.conf"
cp "$NGINX_CONF" "${NGINX_CONF}.pre-ssl-backup"

# Use Python for reliable config modification
python3 << PYTHON_EOF
import re

nginx_conf = "$NGINX_CONF"
domain = "$DOMAIN"

with open(nginx_conf, 'r') as f:
    content = f.read()

# Check if SSL already configured
if 'listen 443' in content:
    print("SSL already configured, skipping...")
else:
    # Add SSL listen directives after "listen 80;"
    ssl_listen = '''listen 80;
\tlisten 443 ssl http2;
\tlisten [::]:443 ssl http2;'''
    content = content.replace('listen 80;', ssl_listen, 1)

    # Find the first server block and add SSL config after server_name
    ssl_config = f'''
\t# SSL Configuration
\tssl_certificate /etc/letsencrypt/live/{domain}/fullchain.pem;
\tssl_certificate_key /etc/letsencrypt/live/{domain}/privkey.pem;
\tssl_protocols TLSv1.2 TLSv1.3;
\tssl_prefer_server_ciphers off;
\tssl_session_cache shared:SSL:10m;

'''
    # Insert after the server_name block ends (after the semicolon)
    pattern = r'(server_name[^;]+;)'
    content = re.sub(pattern, r'\1' + ssl_config, content, count=1)

    # Add HTTP to HTTPS redirect (if not already present)
    if 'return 301 https://' not in content:
        redirect_block = '''

# HTTP to HTTPS redirect
server {
\tlisten 80;
\tlisten [::]:80;
\tserver_name ''' + domain + ''';
\treturn 301 https://$host$request_uri;
}
'''
        content += redirect_block

    with open(nginx_conf, 'w') as f:
        f.write(content)

    print("SSL configuration added successfully")
PYTHON_EOF

chown frappe:frappe "$NGINX_CONF"

# Test nginx configuration
if nginx -t 2>&1; then
    info "✅ Nginx configuration valid"
    systemctl reload nginx
    log "✅ SSL certificate installed and nginx configured!"
else
    warning "Nginx config test failed, attempting recovery..."
    cp "${NGINX_CONF}.pre-ssl-backup" "$NGINX_CONF"
    chown frappe:frappe "$NGINX_CONF"
    systemctl reload nginx || systemctl restart nginx
    error "SSL nginx configuration failed - please configure manually"
fi

# Verify SSL is working
sleep 2
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    info "Certificate location: /etc/letsencrypt/live/$DOMAIN/"
else
    error "SSL certificate not found after installation!"
fi

echo "✓ Step 2 completed successfully"

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
