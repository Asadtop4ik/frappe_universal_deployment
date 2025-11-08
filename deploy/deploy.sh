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
    
    [ -z "$SITE_NAME" ] && error "SITE_NAME o'rnatilmagan!"
    [ -z "$FRAPPE_VERSION" ] && error "FRAPPE_VERSION o'rnatilmagan!"
    [ -z "$MARIADB_ROOT_PASSWORD" ] && error "MARIADB_ROOT_PASSWORD o'rnatilmagan!"
    [ -z "$APPS_TO_INSTALL" ] && error "APPS_TO_INSTALL o'rnatilmagan!"
    
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
    
    # Root password o'rnatish (agar hali o'rnatilmagan bo'lsa)
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';" 2>/dev/null || true
    
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

# Har bir appni o'rnatish
IFS=',' read -ra APPS <<< "$APPS_TO_INSTALL"
for app in "\${APPS[@]}"; do
    app=\$(echo \$app | xargs)  # trim whitespace
    
    if [ "\$app" = "frappe" ]; then
        echo "Frappe allaqachon o'rnatilgan"
        continue
    fi
    
    if [ "\$app" = "erpnext" ]; then
        bench get-app --branch $FRAPPE_VERSION erpnext
    elif [ "\$app" = "hrms" ]; then
        bench get-app --branch $FRAPPE_VERSION hrms
    else
        # Custom app (GitHub URL kerak)
        if [ -n "$CUSTOM_APP_REPO" ]; then
            bench get-app $CUSTOM_APP_REPO
        else
            echo "WARNING: Custom app \$app uchun CUSTOM_APP_REPO o'rnatilmagan!"
        fi
    fi
done

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

# Site yaratish
bench new-site $SITE_NAME \
    --admin-password $ADMIN_PASSWORD \
    --mariadb-root-password '$MARIADB_ROOT_PASSWORD'

# Applarni site ga o'rnatish
IFS=',' read -ra APPS <<< "$APPS_TO_INSTALL"
for app in "\${APPS[@]}"; do
    app=\$(echo \$app | xargs)
    
    if [ "\$app" != "frappe" ]; then
        bench --site $SITE_NAME install-app \$app || true
    fi
done

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
# RESTORE BACKUP
# ============================================
restore_backup() {
    if [ "$RESTORE_BACKUP" != "true" ]; then
        info "Backup restore o'tkazib yuborildi"
        return
    fi
    
    log "Backup restore qilinmoqda..."
    
    # Backup fayllarni ko'chirish
    mkdir -p /home/$FRAPPE_USER/backups
    cp "$PROJECT_ROOT/backups/$SQL_BACKUP_FILE" /home/$FRAPPE_USER/backups/
    
    if [ -n "$CONFIG_BACKUP_FILE" ]; then
        cp "$PROJECT_ROOT/backups/$CONFIG_BACKUP_FILE" /home/$FRAPPE_USER/backups/
    fi
    
    chown -R $FRAPPE_USER:$FRAPPE_USER /home/$FRAPPE_USER/backups
    
    # Restore
    sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

bench --site $SITE_NAME set-maintenance-mode on

bench --site $SITE_NAME restore \
    /home/$FRAPPE_USER/backups/$SQL_BACKUP_FILE \
    --mariadb-root-password '$MARIADB_ROOT_PASSWORD'

bench --site $SITE_NAME migrate
bench --site $SITE_NAME clear-cache
bench --site $SITE_NAME set-maintenance-mode off

EOF

    log "Backup restore tugadi ✓"
}

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
# BUILD ASSETS
# ============================================
build_assets() {
    log "Assets build qilinmoqda..."
    
    sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

bench build --force

EOF

    log "Assets build tugadi ✓"
}

# ============================================
# SETUP SSL (opsional)
# ============================================
setup_ssl() {
    if [ "$SETUP_SSL" != "true" ]; then
        info "SSL setup o'tkazib yuborildi"
        return
    fi
    
    log "SSL o'rnatilmoqda..."
    
    apt-get install -y certbot python3-certbot-nginx
    
    sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

sudo bench setup lets-encrypt $SITE_NAME \
    --custom-domain $SSL_DOMAIN \
    --email $SSL_EMAIL

EOF

    log "SSL o'rnatildi ✓"
}

# ============================================
# FIREWALL
# ============================================
configure_firewall() {
    log "Firewall sozlanmoqda..."
    
    if command -v ufw &> /dev/null; then
        ufw allow 22/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw --force enable
        log "Firewall sozlandi ✓"
    else
        warning "ufw topilmadi"
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
    restore_backup
    setup_production
    build_assets
    setup_ssl
    configure_firewall
    
    print_success
}

# Run
main "$@"
