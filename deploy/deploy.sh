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
# APPS CONFIGURATION
# ============================================
# BASE_APPS: Stable apps with retry logic
BASE_APPS="frappe,erpnext,hrms"

# CUSTOM_APPS: User apps that may fail (non-critical)
# Will be installed with try/catch - failure won't stop deployment
CUSTOM_APPS=""
if [ -n "$CUSTOM_APP_REPO" ] && [ -n "$CUSTOM_APP_NAME" ]; then
    CUSTOM_APPS="$CUSTOM_APP_NAME"
fi

# Combined list for backward compatibility
APPS_TO_INSTALL="$BASE_APPS"
if [ -n "$CUSTOM_APPS" ]; then
    APPS_TO_INSTALL="$APPS_TO_INSTALL,$CUSTOM_APPS"
fi

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
    
    # MariaDB ni avval start qilish (fresh install uchun)
    systemctl enable mariadb
    
    if systemctl start mariadb; then
        log "MariaDB started successfully ✓"
    else
        warning "MariaDB start failed, checking logs..."
        journalctl -xeu mariadb.service --no-pager | tail -20
        error "MariaDB ishga tushmadi! Logs yuqorida ko'rsatilgan"
    fi
    
    sleep 2
    
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
    
    # ============================================
    # CRITICAL FIX: Ubuntu 22.04+ MariaDB Authentication
    # Problem: Default unix_socket plugin, Frappe needs mysql_native_password
    # Solution: Force mysql_native_password + cleanup test users/databases
    # ============================================
    log "MariaDB root authentication sozlanmoqda (Production Fix)..."
    
    # Execute as root (unix_socket still works at this point)
    mysql -u root << SQLEOF
-- Force mysql_native_password authentication
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${MARIADB_ROOT_PASSWORD}');

-- Security hardening: Remove test users and databases
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Apply changes
FLUSH PRIVILEGES;
SQLEOF

    # Verify connection with password
    if mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1;" &>/dev/null; then
        log "✅ MariaDB root password verified"
    else
        error "❌ MariaDB password verification failed!"
    fi
    
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
    
    sudo -u $FRAPPE_USER bash << 'EOF'
set -e

# Ubuntu 24.04 fix: --break-system-packages
pip3 install frappe-bench --break-system-packages

# PATH ga qo'shish (check if already exists)
if ! grep -q "export PATH=\$PATH:~/.local/bin" ~/.bashrc; then
    echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
fi
export PATH=$PATH:~/.local/bin

# Bench init with retry logic for yarn issues
cd /home/frappe
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "🔄 Bench init attempt $((RETRY_COUNT + 1))/$MAX_RETRIES..."
    
    if bench init --frappe-branch version-15 frappe-bench; then
        echo "✅ Bench init successful!"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "⚠️  Bench init failed, retrying in 10 seconds..."
            echo "   (This is normal if yarn registry is temporarily unavailable)"
            sleep 10
            # Clean up failed attempt
            rm -rf frappe-bench
        else
            echo "❌ Bench init failed after $MAX_RETRIES attempts"
            exit 1
        fi
    fi
done

EOF

    log "Frappe Bench o'rnatildi ✓"
}

# ============================================
# INSTALL APPS
# ============================================
install_apps() {
    log "Applar o'rnatilmoqda..."
    info "BASE apps (retry logic): $BASE_APPS"
    if [ -n "$CUSTOM_APPS" ]; then
        info "CUSTOM apps (try/catch): $CUSTOM_APPS"
    fi
    
    sudo -u $FRAPPE_USER bash << EOF
set -e
cd /home/frappe/frappe-bench
export PATH=\$PATH:~/.local/bin

# ============================================
# HELPER FUNCTION: Retry logic for BASE apps
# ============================================
install_app_with_retry() {
    local app_name=\$1
    local app_source=\$2
    local max_retries=3
    local retry_count=0
    
    while [ \$retry_count -lt \$max_retries ]; do
        echo "🔄 Installing \$app_name (attempt \$((retry_count + 1))/\$max_retries)..."
        
        if bench get-app \$app_source; then
            echo "✅ \$app_name installed successfully!"
            return 0
        else
            retry_count=\$((retry_count + 1))
            if [ \$retry_count -lt \$max_retries ]; then
                echo "⚠️  Installation failed, retrying in 10 seconds..."
                sleep 10
                rm -rf "apps/\$app_name" 2>/dev/null || true
            else
                echo "❌ \$app_name installation failed after \$max_retries attempts"
                return 1
            fi
        fi
    done
}

# ============================================
# HELPER FUNCTION: Try/catch for CUSTOM apps
# ============================================
install_custom_app() {
    local app_name=\$1
    local app_repo=\$2
    
    echo ""
    echo "📦 Installing CUSTOM app: \$app_name"
    echo "⚠️  WARNING: Custom app may fail (non-critical)"
    
    # Try to install with limited retries
    local retry_count=0
    local max_retries=2  # Only 2 attempts for custom apps
    
    while [ \$retry_count -lt \$max_retries ]; do
        if bench get-app \$app_repo; then
            echo "✅ Custom app installed successfully!"
            return 0
        else
            retry_count=\$((retry_count + 1))
            if [ \$retry_count -lt \$max_retries ]; then
                echo "⚠️  Retrying custom app installation..."
                sleep 5
                rm -rf "apps/\$app_name" 2>/dev/null || true
            fi
        fi
    done
    
    # Failed - but don't exit
    echo "❌ ERROR: Custom app installation failed!"
    echo "   App: \$app_name"
    echo "   Repo: \$app_repo"
    echo "   ⚠️  Base deployment will continue..."
    return 1
}

# ============================================
# PHASE 1: BASE APPS (frappe, erpnext, hrms)
# Critical apps - must succeed
# ============================================
echo ""
echo "═══════════════════════════════════════════"
echo "📦 PHASE 1: Installing BASE apps (critical)"
echo "═══════════════════════════════════════════"

IFS=',' read -ra APPS <<< "$BASE_APPS"
for app in "\${APPS[@]}"; do
    app=\$(echo \$app | xargs)  # trim whitespace
    
    if [ "\$app" = "frappe" ]; then
        echo "✓ Frappe already installed (bench init)"
        continue
    fi
    
    if [ "\$app" = "erpnext" ]; then
        install_app_with_retry "erpnext" "--branch $FRAPPE_VERSION erpnext"
    elif [ "\$app" = "hrms" ]; then
        install_app_with_retry "hrms" "--branch $FRAPPE_VERSION hrms"
    else
        echo "⚠️  Unknown base app: \$app (skipping)"
    fi
done

echo "✅ BASE apps installation complete!"

# ============================================
# PHASE 2: CUSTOM APPS (optional, non-critical)
# Will not stop deployment if fails
# ============================================
if [ -n "$CUSTOM_APP_REPO" ] && [ -n "$CUSTOM_APP_NAME" ]; then
    echo ""
    echo "═══════════════════════════════════════════"
    echo "📦 PHASE 2: Installing CUSTOM apps"
    echo "═══════════════════════════════════════════"
    
    # Install custom app with try/catch
    if install_custom_app "$CUSTOM_APP_NAME" "$CUSTOM_APP_REPO"; then
        echo "✅ Custom app installed successfully"
    else
        echo "⚠️  Custom app failed, but continuing deployment"
    fi
else
    echo ""
    echo "ℹ️  No custom apps to install (CUSTOM_APP_REPO not set)"
fi

EOF

    log "Applar o'rnatildi ✓"
}

# ============================================
# CONFIGURE REDIS (FIX PORT ISSUE)
# ============================================
configure_redis_ports() {
    log "Redis portlarini sozlash (6379)..."
    
    sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

# Create proper common_site_config.json
cat > sites/common_site_config.json << 'CONFIG'
{
  "background_workers": 1,
  "file_watcher_port": 6787,
  "frappe_user": "$FRAPPE_USER",
  "gunicorn_workers": 4,
  "live_reload": true,
  "rebase_on_pull": false,
  "redis_cache": "redis://127.0.0.1:6379",
  "redis_queue": "redis://127.0.0.1:6379",
  "redis_socketio": "redis://127.0.0.1:6379",
  "restart_supervisor_on_update": true,
  "restart_systemd_on_update": false,
  "serve_default_site": true,
  "shallow_clone": true,
  "socketio_port": 9000,
  "use_redis_auth": false,
  "webserver_port": 8000,
  "developer_mode": 0,
  "scheduler_enabled": 1
}
CONFIG

EOF

    log "Redis konfiguratsiyasi sozlandi ✓"
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
    ln -sf $BENCH_PATH/config/supervisor.conf /etc/supervisor/conf.d/frappe-bench.conf
    
    # Nginx config - Add log_format if missing
    if ! grep -q "log_format main" /etc/nginx/nginx.conf; then
        sed -i '/http {/a \    log_format main '"'"'$remote_addr - $remote_user [$time_local] "$request" '"'"'\n                      '"'"'$status $body_bytes_sent "$http_referer" '"'"'\n                      '"'"'"$http_user_agent" "$http_x_forwarded_for"'"'"';' /etc/nginx/nginx.conf
    fi
    
    # Link nginx config
    ln -sf $BENCH_PATH/config/nginx.conf /etc/nginx/conf.d/frappe-bench.conf
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configs
    nginx -t
    
    # Start/reload services
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
    else
        systemctl start nginx
    fi
    systemctl enable nginx
    
    if systemctl is-active --quiet supervisor; then
        supervisorctl reread
        supervisorctl update
        systemctl reload supervisor
    else
        systemctl start supervisor
        systemctl enable supervisor
        sleep 2
        supervisorctl reread
        supervisorctl update
    fi
    
    log "Production setup tugadi ✓"
    
    # Wait and check status
    sleep 3
    log "Servislar holati:"
    supervisorctl status || warning "Supervisor hali to'liq ishlamagan"
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
    configure_redis_ports  # Fix Redis port 13000 -> 6379
    install_apps
    create_site
    setup_production
    configure_firewall
    
    print_success
}

# Run
main "$@"
