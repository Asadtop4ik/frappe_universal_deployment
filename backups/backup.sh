#!/bin/bash
set -e

# ============================================
# Frappe Backup Script
# Version: 1.1.0
# ============================================

# ============================================
# Load .env
# ============================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
LOG_FILE="/var/log/frappe-backup.log"

# Logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $message"
}

# Error handler
error_handler() {
  local line_no=$1
  log "ERROR" "Script xatosi ${line_no}-qatorda"
  exit 1
}
trap 'error_handler $LINENO' ERR

if [ ! -f "$ENV_FILE" ]; then
  log "ERROR" ".env file topilmadi: $ENV_FILE"
  exit 1
fi

# .env faylni xavfsiz yuklash
set -a
source "$ENV_FILE"
set +a

# ============================================
# Check backup enabled
# ============================================
if [ "$ENABLE_AUTO_BACKUP" != "true" ]; then
  log "INFO" "Auto backup o'chirilgan"
  exit 0
fi

# ============================================
# Required variables validation
# ============================================
REQUIRED_VARS=("BENCH_PATH" "SITE_NAME" "RCLONE_REMOTE" "GDRIVE_BACKUP_FOLDER" "BACKUP_RETENTION_DAYS")
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    log "ERROR" "Majburiy o'zgaruvchi topilmadi: $var"
    exit 1
  fi
done

# ============================================
# Variables
# ============================================
BACKUP_DIR="${BENCH_PATH}/sites/${SITE_NAME}/private/backups"
REMOTE_PATH="${RCLONE_REMOTE}:${GDRIVE_BACKUP_FOLDER}/${SITE_NAME}"

# Backup directory mavjudligini tekshirish
if [ ! -d "$BACKUP_DIR" ]; then
  log "ERROR" "Backup directory topilmadi: $BACKUP_DIR"
  exit 1
fi

# rclone mavjudligini tekshirish
if ! command -v rclone &> /dev/null; then
  log "ERROR" "rclone o'rnatilmagan. O'rnatish: curl https://rclone.org/install.sh | sudo bash"
  exit 1
fi

if command -v bench &> /dev/null; then
  BENCH_CMD="$(command -v bench)"
elif [ -x "${HOME}/.local/bin/bench" ]; then
  BENCH_CMD="${HOME}/.local/bin/bench"
else
  log "ERROR" "bench command topilmadi"
  log "ERROR" "Iltimos 'bench --version' bilan tekshiring"
  exit 1
fi

log "INFO" "Bench command topildi: $BENCH_CMD"

log "INFO" "============================================"
log "INFO" "🚀 Backup boshlandi"
log "INFO" "Site: $SITE_NAME"
log "INFO" "Bench Path: $BENCH_PATH"
log "INFO" "============================================"

# ============================================
# 1️⃣ LOCAL OLD BACKUPS CLEANUP
# ============================================
log "INFO" "🧹 Lokal: $BACKUP_RETENTION_DAYS kundan eski backup'lar o'chirilmoqda..."

DELETED_COUNT=$(find "$BACKUP_DIR" -type f -mtime +"$BACKUP_RETENTION_DAYS" -print -delete 2>/dev/null | wc -l || echo "0")
log "INFO" "Lokal o'chirilgan fayllar soni: $DELETED_COUNT"

# ============================================
# 2️⃣ CREATE NEW BACKUP
# ============================================
log "INFO" "📦 Yangi backup yaratilmoqda..."
cd "$BENCH_PATH"

if [ "$BACKUP_WITH_FILES" = "true" ]; then
  log "INFO" "Backup turi: Database + Files"
  "$BENCH_CMD" --site "$SITE_NAME" backup --with-files --compress
else
  log "INFO" "Backup turi: Faqat Database"
  "$BENCH_CMD" --site "$SITE_NAME" backup --compress
fi

# ============================================
# 3️⃣ UPLOAD TO GOOGLE DRIVE
# ============================================
log "INFO" "☁️ Google Drive'ga yuklanmoqda..."

# rclone remote mavjudligini tekshirish
if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:"; then
  log "ERROR" "rclone remote topilmadi: ${RCLONE_REMOTE}"
  log "ERROR" "rclone config buyrug'i bilan sozlang"
  exit 1
fi

# Remote papka mavjud bo'lmasa yaratish
rclone mkdir "$REMOTE_PATH" 2>/dev/null || true

# Fayllarni yuklash
if rclone copy "$BACKUP_DIR" "$REMOTE_PATH" --ignore-existing --progress; then
  log "INFO" "☁️ Google Drive'ga muvaffaqiyatli yuklandi"
else
  log "ERROR" "Google Drive'ga yuklashda xatolik"
  exit 1
fi

# ============================================
# 4️⃣ REMOTE OLD BACKUPS CLEANUP (Google Drive)
# ============================================
log "INFO" "🧹 Google Drive: $BACKUP_RETENTION_DAYS kundan eski backup'lar o'chirilmoqda..."

if rclone delete "$REMOTE_PATH" --min-age "${BACKUP_RETENTION_DAYS}d" 2>/dev/null; then
  log "INFO" "Google Drive'dan eski fayllar o'chirildi"
else
  log "WARN" "Google Drive tozalashda xatolik (davom etmoqda)"
fi

# ============================================
# 5️⃣ BACKUP SUMMARY
# ============================================
LOCAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "N/A")
log "INFO" "============================================"
log "INFO" "✅ Backup muvaffaqiyatli yakunlandi"
log "INFO" "Lokal backup hajmi: $LOCAL_SIZE"
log "INFO" "Remote: $REMOTE_PATH"
log "INFO" "============================================"
