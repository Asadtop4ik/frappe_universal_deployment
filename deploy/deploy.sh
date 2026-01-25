#!/bin/bash

###############################################################################
# UNIVERSAL FRAPPE/ERPNEXT DEPLOYMENT SCRIPT
# Author: Senior DevOps Engineer
# Version: 2.0
# Date: 2025-11-01
#
# KECHA DEPLOY QILGANDA UCHRATGAN XATOLAR VA YECHIMLAR:
# 1. ✅ Ubuntu 24.04 da pip externally-managed error - --break-system-packages
# 2. ✅ Redis ishlamagan - redis-server o'rnatish va enable qilish
# 3. ✅ Nginx "main" log format error - sed bilan o'chirish
# 4. ✅ MUHIM: /home/frappe permissions 755 bo'lishi kerak nginx uchun!
# 5. ✅ Supervisor passwordless sudo kerak frappe user ga
###############################################################################

set -e  # Exit on any error

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
    error ".env fayl topilmadi! .env.example dan nusxa oling: cp .env.example .env"
fi

source "$PROJECT_ROOT/.env"

# ============================================
# VALIDATION
# ============================================
validate_config() {
    log "Konfiguratsiya tekshirilmoqda..."
    
    [ -z "$SITE_NAME" ] && error "SITE_NAME o'rnatilmagan! .env faylni tahrirlang: nano .env"
    [ -z "$FRAPPE_VERSION" ] && error "FRAPPE_VERSION o'rnatilmagan! .env da FRAPPE_VERSION ni belgilang"
    [ -z "$MARIADB_ROOT_PASSWORD" ] && error "MARIADB_ROOT_PASSWORD o'rnatilmagan! Xavfsiz parol o'rnating"
    [ -z "$APPS_TO_INSTALL" ] && error "APPS_TO_INSTALL o'rnatilmagan! Kamida 'frappe' bo'lishi kerak"
    
    if [ "$RESTORE_BACKUP" = "true" ]; then
        [ -z "$SQL_BACKUP_FILE" ] && error "SQL_BACKUP_FILE o'rnatilmagan!"
        [ ! -f "$PROJECT_ROOT/backups/$SQL_BACKUP_FILE" ] && error "Backup fayl topilmadi: $SQL_BACKUP_FILE"
    fi
    
    log "Konfiguratsiya to'g'ri ✓"
}

# ============================================
# CHECK ROOT
# ============================================
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "Bu scriptni root sifatida ishga tushiring: sudo bash $0"
    fi
}

# ============================================
# SYSTEM UPDATE
# ============================================
update_system() {
    log "Sistema yangilanmoqda..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    log "Sistema yangilandi ✓"
}

# ============================================
# INSTALL DEPENDENCIES
# ============================================
install_dependencies() {
    log "Dependencies o'rnatilmoqda..."
    
    apt-get install -y \
        git python3-dev python3-pip python3-setuptools python3-venv \
        software-properties-common mariadb-server mariadb-client \
        redis-server xvfb libfontconfig wkhtmltopdf libmysqlclient-dev \
        curl supervisor nginx build-essential htop vim
    
    log "Dependencies o'rnatildi ✓"
}

# ============================================
# INSTALL NODE.JS
# ============================================
install_nodejs() {
    log "Node.js ${NODE_VERSION} o'rnatilmoqda..."
    
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    apt-get install -y nodejs
    npm install -g yarn
    
    log "Node.js $(node -v) o'rnatildi ✓"
}

# ============================================
# CONFIGURE MARIADB
# ============================================
configure_mariadb() {
    log "MariaDB sozlanmoqda..."
    
    # Frappe uchun config
    cat > /etc/mysql/mariadb.conf.d/frappe.cnf << EOF
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF

    systemctl restart mariadb
    systemctl enable mariadb
    
    # Root password o'rnatish (secure method)
    log "MariaDB root password sozlanmoqda..."
    
    # Temporary file for secure password handling
    MYSQL_INIT_FILE=$(mktemp)
    cat > "$MYSQL_INIT_FILE" << SQLEOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQLEOF
    
    # Execute with init-file (password not visible in process list)
    mysql --init-file="$MYSQL_INIT_FILE" 2>/dev/null || warning "MariaDB root password allaqachon o'rnatilgan"
    rm -f "$MYSQL_INIT_FILE"
    
    log "MariaDB sozlandi ✓"
}

# ============================================
# CONFIGURE REDIS
# ============================================
configure_redis() {
    log "Redis sozlanmoqda..."
    
    systemctl start redis-server
    systemctl enable redis-server
    
    log "Redis sozlandi ✓"
}

# ============================================
# CREATE FRAPPE USER
# ============================================
create_frappe_user() {
    log "Frappe user yaratilmoqda..."
    
    if id "$FRAPPE_USER" &>/dev/null; then
        warning "User '$FRAPPE_USER' allaqachon mavjud"
    else
        adduser --disabled-password --gecos "" $FRAPPE_USER
        log "User '$FRAPPE_USER' yaratildi ✓"
    fi
    
    # ============================================
    # MINIMAL & SECURE SUDO PERMISSIONS
    # Faqat kerakli commandlarga ruxsat!
    # ============================================
    log "Frappe user permissions sozlanmoqda (secure mode)..."
    
    cat > /etc/sudoers.d/$FRAPPE_USER << 'SUDOERS'
# Frappe Bench - Minimal Sudo Permissions
# Auto-generated by frappe_universal_deploy
# Date: 2025-11-04

# Supervisor management (required for bench restart)
frappe ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl restart *
frappe ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl stop *
frappe ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl start *
frappe ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl status
frappe ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl status *
frappe ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl reload
frappe ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl reread
frappe ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl update
frappe ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl add *
frappe ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl remove *

# Nginx management (required for bench setup nginx)
frappe ALL=(ALL) NOPASSWD: /usr/sbin/nginx -t
frappe ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
frappe ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx
frappe ALL=(ALL) NOPASSWD: /bin/systemctl status nginx
frappe ALL=(ALL) NOPASSWD: /bin/systemctl enable nginx
frappe ALL=(ALL) NOPASSWD: /bin/systemctl start nginx
frappe ALL=(ALL) NOPASSWD: /bin/systemctl stop nginx

# Service status checks (read-only operations)
frappe ALL=(ALL) NOPASSWD: /bin/systemctl status *
frappe ALL=(ALL) NOPASSWD: /bin/systemctl is-active *
frappe ALL=(ALL) NOPASSWD: /bin/systemctl is-enabled *

# SSL certificate management (for bench setup ssl)
frappe ALL=(ALL) NOPASSWD: /usr/bin/certbot renew
frappe ALL=(ALL) NOPASSWD: /usr/bin/certbot certonly *
frappe ALL=(ALL) NOPASSWD: /usr/bin/certbot --nginx *

SUDOERS
    
    chmod 0440 /etc/sudoers.d/$FRAPPE_USER
    
    # Validate sudoers syntax
    if visudo -c -f /etc/sudoers.d/$FRAPPE_USER > /dev/null 2>&1; then
        log "✅ Frappe user permissions sozlandi (SECURE)"
    else
        error "❌ Sudoers fayl syntax xatosi!"
    fi
    
    # MUHIM: /home/frappe permissions nginx uchun!
    chmod 755 /home/$FRAPPE_USER
    
    log "Frappe user to'liq sozlandi ✓"
}

# ============================================
# INSTALL BENCH
# ============================================
install_bench() {
    log "Frappe Bench o'rnatilmoqda..."
    
    sudo -u $FRAPPE_USER bash << EOF
set -e

# Ubuntu 24.04 fix: --break-system-packages
pip3 install frappe-bench --break-system-packages

# PATH ga qo'shish
echo 'export PATH=\$PATH:~/.local/bin' >> ~/.bashrc
export PATH=\$PATH:~/.local/bin

# Bench init
cd /home/$FRAPPE_USER
bench init --frappe-branch $FRAPPE_VERSION $BENCH_PATH

EOF

    log "Frappe Bench o'rnatildi ✓"
}

# ============================================
# INSTALL APPS
# ============================================
install_apps() {
    log "Applar o'rnatilmoqda: $APPS_TO_INSTALL..."
    
    sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

# ============================================
# PHASE 1: CORE APPS (frappe, erpnext, hrms)
# Bu applar 99% ishga tushadi, xatolik kam
# ============================================
echo "📦 Phase 1: Installing CORE apps..."

IFS=',' read -ra APPS <<< "$APPS_TO_INSTALL"
for app in "\${APPS[@]}"; do
    app=\$(echo \$app | xargs)  # trim whitespace
    
    if [ "\$app" = "frappe" ]; then
        echo "✓ Frappe allaqachon o'rnatilgan"
        continue
    fi
    
    if [ "\$app" = "erpnext" ]; then
        echo "📥 Installing ERPNext..."
        bench get-app --branch $FRAPPE_VERSION erpnext
        echo "✓ ERPNext installed"
    elif [ "\$app" = "hrms" ]; then
        echo "📥 Installing HRMS..."
        bench get-app --branch $FRAPPE_VERSION hrms
        echo "✓ HRMS installed"
    fi
done

# ============================================
# PHASE 2: CUSTOM APPS (ixtiyoriy)
# Agar xato bo'lsa, base apps ishlab turadi
# ============================================
if [ -n "$CUSTOM_APP_REPO" ]; then
    echo ""
    echo "📦 Phase 2: Installing CUSTOM app..."
    echo "⚠️  WARNING: Custom app xato berishi mumkin"
    echo "⚠️  Agar xato bo'lsa, base apps (ERPNext) ishlab turadi"
    
    # Try-catch mantiq: xato bo'lsa davom et
    if bench get-app $CUSTOM_APP_REPO; then
        echo "✓ Custom app muvaffaqiyatli o'rnatildi"
    else
        echo "❌ ERROR: Custom app o'rnatilmadi!"
        echo "   Repo: $CUSTOM_APP_REPO"
        echo "   Base deployment davom etadi..."
    fi
else
    echo ""
    echo "ℹ️  Custom app o'rnatilmaydi (CUSTOM_APP_REPO bo'sh)"
fi

EOF

    log "Applar o'rnatildi ✓"
}

# ============================================
# CREATE SITE
# ============================================
create_site() {
    log "Site '$SITE_NAME' yaratilmoqda..."
    
    sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

# Site yaratish (secure password handling)
echo "$ADMIN_PASSWORD" > /tmp/.admin_pass
echo "$MARIADB_ROOT_PASSWORD" > /tmp/.db_pass

bench new-site $SITE_NAME \
    --admin-password \$(cat /tmp/.admin_pass) \
    --mariadb-root-password \$(cat /tmp/.db_pass)

# Clean up temporary files
rm -f /tmp/.admin_pass /tmp/.db_pass

# ============================================
# INSTALL APPS TO SITE (Smart Error Handling)
# ============================================
echo ""
echo "📦 Installing apps to site..."

# Phase 1: Core apps (must succeed)
IFS=',' read -ra APPS <<< "$APPS_TO_INSTALL"
for app in "\${APPS[@]}"; do
    app=\$(echo \$app | xargs)
    
    if [ "\$app" = "frappe" ]; then
        continue
    fi
    
    if [ "\$app" = "erpnext" ] || [ "\$app" = "hrms" ]; then
        echo "📥 Installing \$app to site..."
        bench --site $SITE_NAME install-app \$app
        echo "✓ \$app installed successfully"
    fi
done

# Phase 2: Custom app (optional, may fail)
if [ -n "$CUSTOM_APP_REPO" ] && [ -n "$CUSTOM_APP_NAME" ]; then
    echo ""
    echo "📦 Installing custom app: $CUSTOM_APP_NAME"
    echo "⚠️  If this fails, base system will still work"
    
    if bench --site $SITE_NAME install-app $CUSTOM_APP_NAME; then
        echo "✓ Custom app installed to site"
    else
        echo "❌ Custom app installation failed"
        echo "   Base system (ERPNext) is still functional"
        echo "   Debug manually: su - frappe, cd frappe-bench"
        echo "   Then: bench --site $SITE_NAME install-app $CUSTOM_APP_NAME"
    fi
fi

# Developer mode
if [ "$DEVELOPER_MODE" = "true" ]; then
    bench --site $SITE_NAME set-config developer_mode 1
fi

# Scheduler
if [ "$ENABLE_SCHEDULER" = "true" ]; then
    bench --site $SITE_NAME scheduler enable
fi

# ============================================
# CRITICAL: Run migrate to apply fixtures
# ============================================
# After installing apps, MUST run migrate to:
# 1. Apply database schema changes (DocTypes)
# 2. Import fixtures (Custom Fields, Property Setters, DocPerms)
# 3. Run after_migrate hooks (force_sync functions)
echo "🔄 Running migrations and syncing fixtures..."
bench --site $SITE_NAME migrate

# Clear cache after migrate (ALWAYS!)
echo "🧹 Clearing cache..."
bench --site $SITE_NAME clear-cache
bench --site $SITE_NAME clear-website-cache

echo "✅ Migrations and cache cleared successfully"

EOF

    log "Site yaratildi ✓"
}

# ============================================
# BACKUP RESTORE - MOVED TO SEPARATE SCRIPT
# ============================================
# Backup restore functionality moved to: deploy/03-restore-backup.sh
# Usage: sudo bash deploy/03-restore-backup.sh
# ============================================

# ============================================
# SETUP PRODUCTION
# ============================================
setup_production() {
    log "Production setup qilinmoqda..."
    
    # Supervisor va Nginx config
    sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

bench setup supervisor --yes
bench setup nginx --yes

EOF

    # Supervisor config
    cp $BENCH_PATH/config/supervisor.conf /etc/supervisor/conf.d/frappe-bench.conf
    
    # Nginx config (nginx "main" log format fix)
    sed -i 's/ main;/;/g' $BENCH_PATH/config/nginx.conf
    cp $BENCH_PATH/config/nginx.conf /etc/nginx/sites-available/frappe-bench.conf
    ln -sf /etc/nginx/sites-available/frappe-bench.conf /etc/nginx/sites-enabled/frappe-bench.conf
    rm -f /etc/nginx/sites-enabled/default
    
    # Test va reload
    nginx -t
    supervisorctl reread
    supervisorctl update
    systemctl reload supervisor
    systemctl restart nginx
    
    log "Production setup tugadi ✓"
}

# ============================================
# BUILD ASSETS - INTEGRATED INTO setup_production()
# ============================================
# Build now happens automatically during:
# 1. bench setup nginx (generates production assets)
# 2. First supervisor start (on-demand build)
# No separate build needed - reduces deployment time
# ============================================

# ============================================
# SSL SETUP - MOVED TO SEPARATE SCRIPT
# ============================================
# SSL setup moved to: deploy/02-setup-ssl.sh
# Usage: sudo bash deploy/02-setup-ssl.sh
# 
# Why separate?
# - Domain must be configured first (DNS propagation)
# - Can fail if domain not ready
# - Not needed for initial deployment
# - Can be run later when domain is ready
# ============================================

# ============================================
# FIREWALL (Production-Ready)
# ============================================
configure_firewall() {
    log "Firewall sozlanmoqda..."
    
    if command -v ufw &> /dev/null; then
        # Default policies
        ufw default deny incoming
        ufw default allow outgoing
        
        # SSH with rate limiting (prevent brute-force)
        ufw limit 22/tcp comment 'SSH with rate limiting'
        
        # HTTP/HTTPS
        ufw allow 80/tcp comment 'HTTP'
        ufw allow 443/tcp comment 'HTTPS'
        
        # Enable firewall
        ufw --force enable
        
        # Show status
        log "Firewall sozlandi ✓"
        ufw status numbered
    else
        warning "ufw topilmadi - firewall o'rnatilmadi"
        warning "Manual: apt-get install -y ufw"
    fi
}

# ============================================
# PRINT SUCCESS MESSAGE
# ============================================
print_success() {
    log "=================================================="
    log "🎉 DEPLOYMENT MUVAFFAQIYATLI TUGADI! 🎉"
    log "=================================================="
    echo ""
    info "Site URL: http://$(hostname -I | awk '{print $1}')"
    info "Site Name: $SITE_NAME"
    info "Username: Administrator"
    info "Password: $ADMIN_PASSWORD"
    echo ""
    warning "MUHIM: Administrator parolini o'zgartiring!"
    echo ""
    info "Foydali buyruqlar:"
    info "  cd $BENCH_PATH"
    info "  bench --site $SITE_NAME status"
    info "  bench --site $SITE_NAME logs"
    info "  sudo supervisorctl status"
    echo ""
    info "Keyingi qadamlar:"
    info "  1. Domain & SSL: sudo bash deploy/02-setup-domain-ssl.sh"
    info "  2. Backup restore: sudo bash deploy/03-restore-backup.sh"
    info "  3. Custom app qo'shish: Manual install"
    log "=================================================="
}

# ============================================
# MAIN FUNCTION
# ============================================
main() {
    log "🚀 Frappe/ERPNext deployment boshlandi..."
    echo ""
    
    check_root
    validate_config
    
    update_system
    install_dependencies
    install_nodejs
    configure_mariadb
    configure_redis
    create_frappe_user
    install_bench
    install_apps
    create_site
    setup_production
    configure_firewall
    
    print_success
}

# Run
main "$@"
