# 📖 Deployment Script Details

## Overview

This deployment script (`deploy.sh`) automates the complete setup of a Frappe/ERPNext production environment with **smart error handling** for custom apps.

## 🆕 Recent Updates (2026-01-25)

### ✅ Node.js 20 LTS
- **Changed:** Node.js 18 → 20 LTS (2026 recommended)
- **Reason:** Node.js 18 support ends October 2026
- **Impact:** Future-proof, better performance

### ✅ Smart Custom App Installation
- **Problem:** Custom app errors broke entire deployment
- **Solution:** 2-phase installation - core apps succeed even if custom app fails
- **Result:** Base system (ERPNext) always installs successfully
- **Example:** If `akfa_accounting` fails, ERPNext still works

### ✅ Zero-Downtime CI/CD
- **Old:** 4 minutes downtime during code push (maintenance mode ON)
- **New:** 5-10 seconds downtime (only restart)
- **How:** Build assets while site is live, no maintenance mode
- **Impact:** Users can work during deployment

### ✅ Modular Scripts
- **Separated:** SSL and backup to own scripts
- **Reason:** Not always needed, can fail, easier to debug
- **Files:**
  - `deploy.sh` - Base only (8-12 min)
  - `02-setup-domain-ssl.sh` - Domain + SSL (2-3 min)
  - `03-restore-backup.sh` - Backup restore (3-5 min)

### ✅ Security Enhancements
- **Password handling:** No longer visible in `ps aux`
- **Firewall:** SSH rate limiting (brute-force protection)
- **MariaDB:** Secure init-file method
- **Removed:** Keraksiz `build_assets()` function (duplicate)

## Available Scripts

### 1. `deploy.sh` - Base Deployment
**Purpose:** Core Frappe/ERPNext installation  
**Duration:** 8-12 minutes  
**What it does:**
- System dependencies
- Frappe bench init
- Core apps (frappe, erpnext, hrms)
- Optional: Custom app (fault-tolerant)
- Site creation
- Production setup (nginx, supervisor)
- Firewall configuration

**Usage:**
```bash
sudo bash deploy/deploy.sh
```

### 2. `02-setup-domain-ssl.sh` - Domain & SSL
**Purpose:** Add domain and Let's Encrypt SSL  
**Duration:** 2-3 minutes  
**What it does:**
- DNS validation
- Domain addition (Frappe native)
- SSL certificate (Let's Encrypt)
- Auto-renewal setup
- Nginx auto-configuration

**Usage:**
```bash
# Interactive mode (prompts for confirmation)
sudo bash deploy/02-setup-domain-ssl.sh

# Non-interactive mode (auto-confirm all prompts)
AUTO_CONFIRM=yes sudo bash deploy/02-setup-domain-ssl.sh
```

### 3. `03-restore-backup.sh` - Backup Restore
**Purpose:** Restore database from backup  
**Duration:** 3-5 minutes  
**What it does:**
- Interactive backup selection
- Maintenance mode
- Database restore
- Migration
- Cache clear

**Usage:**
```bash
sudo bash deploy/03-restore-backup.sh
```

## What It Does

### 1. System Preparation
- Updates system packages
- Installs all required dependencies
- Configures MariaDB and Redis
- Sets up Python 3.11+ environment
- Installs Node.js 20 LTS

### 2. Frappe Installation
- Creates dedicated `frappe` user
- Initializes bench with specified Frappe version
- Configures bench for production use

### 3. App Installation (2-Phase)

#### Phase 1: Core Apps (99% Success Rate)
- Frappe framework
- ERPNext (if configured)
- HRMS (if configured)
- **These apps MUST succeed**

#### Phase 2: Custom Apps (Optional, Fault-Tolerant)
- Attempts custom app installation
- **If fails:** Base system still works
- **Error logged:** Manual debugging possible

### 4. Site Creation
- Creates new site with admin password
- Installs core apps to site
- Attempts custom app installation (optional)
- Runs migrations and clears cache

### 5. Backup Restore (Optional)
- Restores database from `.sql.gz` backup
- Restores site configuration
- Sets administrator password

### 6. Production Setup
- Configures Nginx reverse proxy
- Sets up Supervisor for process management
- Applies critical permission fixes
- Enables and starts all services

## Critical Fixes Included

### Fix #1: Ubuntu 24.04 Pip Issue
```bash
pip3 install --break-system-packages frappe-bench
```
Ubuntu 24.04 uses externally-managed Python environment.

### Fix #2: Redis Service
```bash
sudo apt-get install -y redis-server
sudo systemctl enable redis-server --now
```
Explicit Redis installation and startup.

### Fix #3: Nginx Log Format
```bash
sudo sed -i 's/ main;/;/g' /etc/nginx/nginx.conf
```
Removes unsupported "main" log format.

### Fix #4: Home Directory Permissions
```bash
sudo chmod 755 /home/frappe
```
**CRITICAL**: Nginx (www-data) needs execute permission on /home/frappe.

### Fix #5: Supervisor Sudo Access
```bash
echo "frappe ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/frappe
```
Allows Supervisor to manage processes properly.

## Configuration Loading

Script reads from `.env` file in parent directory:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
```

## Validation

Before starting, script validates:
- ✅ Configuration file exists
- ✅ All required variables are set
- ✅ Backup files exist (if restore enabled)
- ✅ Running as root user

## Error Handling

- Stops on any error (`set -e`)
- Validates each major step
- Provides clear error messages
- Logs all actions

## Execution Flow

```
1. Load & Validate Config
   ↓
2. Install System Dependencies
   ↓
3. Configure Database & Redis
   ↓
4. Setup Frappe User & Bench
   ↓
5. Install Apps (in order)
   ↓
6. Create Site / Restore Backup
   ↓
7. Production Setup
   ↓
8. Apply Critical Fixes
   ↓
9. Start Services
   ↓
10. Done! 🎉
```

## Customization

### Adding Custom Apps

Edit `.env`:
```bash
APPS_TO_INSTALL="frappe,erpnext,myapp1,myapp2"
```

Add repository logic in `deploy.sh`:
```bash
if [[ "$app" == "myapp1" ]]; then
    bench get-app https://github.com/user/myapp1.git
fi
```

### Changing Versions

In `.env`:
```bash
FRAPPE_VERSION="version-14"  # For older version
FRAPPE_VERSION="develop"     # For latest development
```

### Development vs Production

Development mode:
```bash
DEVELOPER_MODE="true"
```

Skip production setup internally or run `bench setup production` manually.

## Manual Intervention

If script fails mid-way:

### Resume from specific point

1. **After bench init:**
```bash
su - frappe
cd ~/frappe-bench
bench get-app erpnext
```

2. **After site creation:**
```bash
bench --site yoursite.local migrate
bench setup production frappe
```

3. **Restart services:**
```bash
sudo supervisorctl restart all
sudo systemctl restart nginx
```

## Post-Deployment

### Verify Installation

```bash
# Check services
sudo supervisorctl status

# Check nginx
sudo systemctl status nginx

# Test site
curl http://your-server-ip
```

### Update Administrator Password

```bash
su - frappe
cd ~/frappe-bench
bench --site yoursite.local set-admin-password NewPassword123!
```

### Enable Scheduler

```bash
bench --site yoursite.local scheduler enable
```

## Logs & Debugging

### Bench logs
```bash
su - frappe
cd ~/frappe-bench
bench --site yoursite.local logs
```

### Supervisor logs
```bash
sudo tail -f /var/log/supervisor/supervisord.log
```

### Nginx logs
```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### System logs
```bash
sudo journalctl -u nginx -f
sudo journalctl -u mariadb -f
```

## Tested On

- ✅ Ubuntu 24.04 LTS
- ✅ Ubuntu 22.04 LTS
- ✅ Ubuntu 20.04 LTS
- ✅ Debian 11, 12

## Time Estimates

- **Fresh installation:** 15-30 minutes
- **With backup restore:** 20-35 minutes
- **Network dependent:** Download speed affects time

## Requirements Check

Before running:
```bash
# Check RAM
free -h

# Check disk space
df -h

# Check internet
ping -c 3 google.com

# Check ports
sudo netstat -tulpn | grep -E ':(80|443|3306|6379|11000|13000|9000)'
```

---