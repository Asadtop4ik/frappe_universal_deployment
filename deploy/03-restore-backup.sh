#!/bin/bash

###############################################################################
# BACKUP RESTORE SCRIPT
# Purpose: Restore Frappe/ERPNext database from backup
# Usage: sudo bash deploy/03-restore-backup.sh
# Requirements: 
#   - Base deployment completed (deploy.sh)
#   - Backup files in backups/ directory
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
[ -z "$MARIADB_ROOT_PASSWORD" ] && error "MARIADB_ROOT_PASSWORD o'rnatilmagan!"

# Check if bench exists
if [ ! -d "$BENCH_PATH" ]; then
    error "Bench topilmadi: $BENCH_PATH. Avval deploy.sh ni ishga tushiring"
fi

# Check if site exists
if [ ! -d "$BENCH_PATH/sites/$SITE_NAME" ]; then
    error "Site topilmadi: $SITE_NAME. Avval deploy.sh ni ishga tushiring"
fi

log "Konfiguratsiya to'g'ri ✓"

# ============================================
# FIND BACKUP FILES
# ============================================
log "Backup fayllar qidirilmoqda..."

BACKUP_DIR="$PROJECT_ROOT/backups"

if [ ! -d "$BACKUP_DIR" ]; then
    error "Backup papka topilmadi: $BACKUP_DIR"
fi

# List available backups
echo ""
info "Mavjud backup fayllar:"
echo ""

SQL_FILES=($(ls -1t "$BACKUP_DIR"/*.sql.gz 2>/dev/null || true))

if [ ${#SQL_FILES[@]} -eq 0 ]; then
    error "Backup fayl topilmadi: $BACKUP_DIR/*.sql.gz"
fi

# Display backups with numbers
for i in "${!SQL_FILES[@]}"; do
    FILE="${SQL_FILES[$i]}"
    FILENAME=$(basename "$FILE")
    SIZE=$(du -h "$FILE" | cut -f1)
    DATE=$(stat -c %y "$FILE" | cut -d' ' -f1)
    echo "  [$((i+1))] $FILENAME (Size: $SIZE, Date: $DATE)"
done

echo ""
read -p "Qaysi backupni restore qilmoqchisiz? [1-${#SQL_FILES[@]}]: " CHOICE

# Validate choice
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#SQL_FILES[@]} ]; then
    error "Noto'g'ri tanlov: $CHOICE"
fi

SELECTED_BACKUP="${SQL_FILES[$((CHOICE-1))]}"
BACKUP_FILENAME=$(basename "$SELECTED_BACKUP")

log "Tanlangan backup: $BACKUP_FILENAME"

# ============================================
# CONFIRMATION
# ============================================
warning "⚠️  DIQQAT: Bu amal hozirgi ma'lumotlarni o'chiradi!"
warning "⚠️  Site: $SITE_NAME"
warning "⚠️  Backup: $BACKUP_FILENAME"
echo ""
read -p "Davom etamizmi? [yes/NO]: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    info "Foydalanuvchi bekor qildi"
    exit 0
fi

# ============================================
# PREPARE BACKUP FILES
# ============================================
log "Backup fayllar tayyorlanmoqda..."

# Create temporary directory
TEMP_BACKUP_DIR="/home/$FRAPPE_USER/backups"
mkdir -p "$TEMP_BACKUP_DIR"

# Copy backup file
cp "$SELECTED_BACKUP" "$TEMP_BACKUP_DIR/"
chown -R $FRAPPE_USER:$FRAPPE_USER "$TEMP_BACKUP_DIR"

log "Backup fayllar ko'chirildi ✓"

# ============================================
# RESTORE BACKUP
# ============================================
log "Backup restore boshlanmoqda..."
warning "Bu jarayon bir necha daqiqa davom etishi mumkin..."

# Create password file for secure handling
echo "$MARIADB_ROOT_PASSWORD" > /tmp/.db_pass_restore
chmod 600 /tmp/.db_pass_restore

sudo -u $FRAPPE_USER bash << EOF
set -e
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

# Enable maintenance mode
echo "🔧 Maintenance mode yoqilmoqda..."
bench --site $SITE_NAME set-maintenance-mode on

# Restore database
echo "📥 Database restore qilinmoqda..."
bench --site $SITE_NAME restore \\
    "$TEMP_BACKUP_DIR/$BACKUP_FILENAME" \\
    --mariadb-root-password \$(cat /tmp/.db_pass_restore)

# Run migrations (important!)
echo "🔄 Migrations bajarilmoqda..."
bench --site $SITE_NAME migrate

# Clear cache
echo "🧹 Cache tozalanmoqda..."
bench --site $SITE_NAME clear-cache
bench --site $SITE_NAME clear-website-cache

# Disable maintenance mode
echo "✅ Maintenance mode o'chirilmoqda..."
bench --site $SITE_NAME set-maintenance-mode off

EOF

# Clean up password file
rm -f /tmp/.db_pass_restore

log "Backup restore tugadi ✓"

# ============================================
# RESTART SERVICES
# ============================================
log "Servislar qayta ishga tushirilmoqda..."

supervisorctl restart all
systemctl reload nginx

sleep 3

# ============================================
# VERIFY SITE
# ============================================
log "Site tekshirilmoqda..."

sudo -u $FRAPPE_USER bash << EOF
cd $BENCH_PATH
export PATH=\$PATH:~/.local/bin

bench --site $SITE_NAME doctor
EOF

# ============================================
# SUCCESS MESSAGE
# ============================================
log "=================================================="
log "🎉 BACKUP MUVAFFAQIYATLI RESTORE QILINDI! 🎉"
log "=================================================="
echo ""
info "Site: $SITE_NAME"
info "Backup: $BACKUP_FILENAME"
info "Status: Active"
echo ""
warning "MUHIM: Administrator parolni yangilang!"
echo ""
info "Foydali buyruqlar:"
info "  cd $BENCH_PATH"
info "  bench --site $SITE_NAME status"
info "  bench --site $SITE_NAME logs"
log "=================================================="
