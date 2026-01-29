# 📦 Frappe / ERPNext Google Drive Backup – OAuth (Personal Google Account)

Bu hujjat **Frappe / ERPNext (v15+)** loyihalari uchun **avtomatik backup tizimini** sozlashni tushuntiradi. Ushbu loyiha **Google OAuth (Personal Google Account)** orqali ishlaydi va **development, test, lokal serverlar** uchun mo‘ljallangan.


---

## 📋 Mundarija

1. Umumiy ko‘rinish
2. Qachon OAuth ishlatiladi
3. Talablar
4. Google Drive tayyorlash
5. rclone o‘rnatish
6. rclone sozlash (OAuth bilan)
7. `.env` fayl sozlash
8. Backup script ishlash logikasi
9. Cron (kuniga 1 marta backup)
10. Tekshirish va test
11. Restore qilish
12. Keng tarqalgan xatolar
13. Xavfsizlik bo‘yicha tavsiyalar

---

## 🎯 Umumiy ko‘rinish

Backup tizimi quyidagicha ishlaydi:

1. Eski backup’lar (7 kundan eski) **OLDIN o‘chiriladi**
2. Yangi backup olinadi (`bench backup`)
3. Backup Google Drive **My Drive**’ga yuklanadi (`rclone`)

👉 Natija: har doim **faqat oxirgi 7 kunlik backup** saqlanadi.

---

## ❓ Qachon OAuth ishlatiladi

OAuth usuli quyidagi holatlar uchun **eng mos**:

* Lokal development
* Test serverlar
* Shaxsiy VPS
* Google Workspace yo‘q bo‘lsa


---

## 📌 Talablar

* Linux (Ubuntu 20.04+ tavsiya etiladi)
* Frappe / ERPNext v15+
* Shaxsiy Google akkaunt (Gmail)
* Internet aloqasi
* Serverda `sudo` huquqi

---

## 📂 Google Drive tayyorlash

1. Google Drive’ga kiring
2. **New → Folder**
3. Folder nomi:

```
Frappe Backup
```

👉 Backup’lar shu papkaga tushadi

---

## 🔧 rclone o‘rnatish

```bash
sudo apt update
sudo apt install rclone -y
```

Tekshirish:

```bash
rclone version
```

---

## 🔐 rclone sozlash (OAuth bilan)

```bash
rclone config
```

Interaktiv sozlash (ANIQ SHU TARTIBDA):

```
n                       # new remote
name> gdrive_oauth      # remote nomi
type> drive
client_id>              # BO‘SH (Enter)
client_secret>          # BO‘SH (Enter)
scope> 1                # Full access
root_folder_id>         # BO‘SH
service_account_file>   # BO‘SH (MUHIM)
Edit advanced config> n
Use auto config> y      # Brauzer ochiladi
Configure this as a team drive> n
y/e/d> y
q
```

👉 Brauzerda Google akkauntingiz bilan login qiling va **Allow** bosing.

Tekshirish:

```bash
rclone lsd gdrive_oauth:
```

---

## 📝 `.env` fayl sozlash

```bash
cp .env.example .env
nano .env
```

### Backup bilan bog‘liq muhim o‘zgaruvchilar

```env
ENABLE_AUTO_BACKUP=true

# Har kuni soat 02:00 da
BACKUP_CRON="0 2 * * *"

# Faqat oxirgi 7 kunlik backup saqlanadi
BACKUP_RETENTION_DAYS=7

BACKUP_WITH_FILES=true

RCLONE_REMOTE="gdrive_oauth"
GDRIVE_BACKUP_FOLDER="Frappe Backup"
```

⚠️ `.env` faylni Git’ga **commit qilmang**

---

## ⚙️ Backup script ishlash logikasi

Backup script quyidagi tartibda ishlaydi:

1. Lokal va Google Drive’dagi **7 kundan eski** backup’lar o‘chiriladi
2. `bench --site backup` orqali yangi backup olinadi
3. `rclone copy` orqali My Drive’ga yuklanadi

Bu **rolling backup** mexanizmi:

* 8-kuni → 1-kun backup o‘chadi
* 9-kuni → 2-kun backup o‘chadi

---

## ⏰ Cron – kuniga 1 marta backup

Cron avtomatik `.env` dagi `BACKUP_CRON` qiymatidan olinadi.

Cron o‘rnatish:

```bash
bash backups/cron_setup.sh
```

Tekshirish:

```bash
crontab -l
```

Log:

```bash
tail -f /var/log/frappe-backup.log
```

---

## 🧪 Test qilish

Manual ishga tushirish:

```bash
bash backups/backup.sh
```

Google Drive’da tekshirish:

```bash
rclone ls gdrive_oauth:"Frappe Backup/<SITE_NAME>/"
```

---

## ♻️ Restore qilish

```bash
cd /home/frappe/frappe-bench

bench --site <SITE_NAME> restore backup.sql.gz \
  --with-private-files private-files.tar \
  --with-public-files files.tar
```

---

## 🛠 Keng tarqalgan xatolar

### `rclone lsd gdrive_oauth` xato beradi

To‘g‘risi:

```bash
rclone lsd gdrive_oauth:
```

### Google Drive’ga yuklanmayapti

* OAuth ruxsat berilmagan → `rclone config reconnect gdrive_oauth`

### bench command topilmadi

```bash
which bench
```

Agar kerak bo‘lsa:

```bash
export PATH=$PATH:$HOME/.local/bin
```

---

## 🔐 Xavfsizlik bo‘yicha tavsiyalar

* `.env` faylni Git’ga qo‘shmang
* Backup retention’ni 7–14 kundan oshirmang
* OAuth token faqat ishonchli serverlarda ishlatilsin
* Production’da **Service Account + Shared Drive** ga o‘ting

---

## 📦 Versiya

* **Versiya**: 1.3.0
* **Oxirgi yangilanish**: 2026-01-28
* **Auth modeli**: Google OAuth (My Drive)

---

Agar savollar bo‘lsa yoki qo‘shimcha (Service Account, S3, encryption, alert) kerak bo‘lsa — bemalol murojaat qiling 🚀
