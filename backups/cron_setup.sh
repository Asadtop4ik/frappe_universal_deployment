#!/bin/bash
set -e

# ============================================
# Frappe Backup Cron Setup Script
# Version: 1.1.0
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"
LOG_FILE="/var/log/frappe-backup.log"

# Ranglar
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================
# Check .env file
# ============================================
if [ ! -f "$ENV_FILE" ]; then
  log_error ".env file topilmadi: $ENV_FILE"
  log_info "Namuna: cp .env.example .env && nano .env"
  exit 1
fi

# .env faylni xavfsiz yuklash
set -a
source "$ENV_FILE"
set +a

# ============================================
# Check backup script exists
# ============================================
if [ ! -f "$BACKUP_SCRIPT" ]; then
  log_error "backup.sh topilmadi: $BACKUP_SCRIPT"
  exit 1
fi

# backup.sh ni executable qilish
chmod +x "$BACKUP_SCRIPT"

# ============================================
# Check if backup enabled
# ============================================
if [ "$ENABLE_AUTO_BACKUP" != "true" ]; then
  log_warn "Auto backup o'chirilgan (.env: ENABLE_AUTO_BACKUP=true qiling)"
  
  # Agar backup o'chirilgan bo'lsa, eski cron'ni ham o'chiramiz
  if crontab -l 2>/dev/null | grep -q 'backup.sh'; then
    (crontab -l 2>/dev/null | grep -v 'backup.sh') | crontab -
    log_info "Mavjud backup cron o'chirildi"
  fi
  exit 0
fi

# ============================================
# Validate BACKUP_CRON format
# ============================================
if [ -z "$BACKUP_CRON" ]; then
  log_error "BACKUP_CRON o'zgaruvchisi topilmadi"
  log_info "Namuna: BACKUP_CRON='0 2 * * *' (har kuni soat 2:00 da)"
  exit 1
fi

# Cron format validation (basic check - 5 fields)
CRON_FIELDS=$(echo "$BACKUP_CRON" | awk '{print NF}')
if [ "$CRON_FIELDS" -ne 5 ]; then
  log_error "Noto'g'ri BACKUP_CRON formati: '$BACKUP_CRON'"
  log_info "To'g'ri format: 'daqiqa soat kun oy hafta_kuni'"
  log_info "Namuna: '0 2 * * *' = har kuni 02:00"
  log_info "Namuna: '0 */6 * * *' = har 6 soatda"
  exit 1
fi

# ============================================
# Create log file if not exists
# ============================================
if [ ! -f "$LOG_FILE" ]; then
  sudo touch "$LOG_FILE" 2>/dev/null || touch "$LOG_FILE"
  sudo chmod 666 "$LOG_FILE" 2>/dev/null || chmod 666 "$LOG_FILE"
  log_info "Log file yaratildi: $LOG_FILE"
fi

# ============================================
# Setup cron job
# ============================================
CRON_CMD="${BACKUP_CRON} ${BACKUP_SCRIPT} >> ${LOG_FILE} 2>&1"

# Eski cron'ni o'chirib, yangisini qo'shamiz
(crontab -l 2>/dev/null | grep -v 'backup.sh'; echo "$CRON_CMD") | crontab -

echo ""
echo "============================================"
log_info "✅ Backup cron muvaffaqiyatli o'rnatildi!"
echo "============================================"
echo ""
echo "📋 Cron buyruq:"
echo "   $CRON_CMD"
echo ""
echo "📂 Log fayl:"
echo "   $LOG_FILE"
echo "   Ko'rish: tail -f $LOG_FILE"
echo ""
echo "🔧 Boshqarish:"
echo "   Cron ko'rish:   crontab -l"
echo "   Cron o'chirish: crontab -l | grep -v 'backup.sh' | crontab -"
echo "   Test qilish:    bash $BACKUP_SCRIPT"
echo "============================================"
