# 📖 Deployment Script Details

## Overview

This deployment script (`deploy.sh`) automates the complete setup of a Frappe/ERPNext production environment.

## What It Does

### 1. System Preparation
- Updates system packages
- Installs all required dependencies
- Configures MariaDB and Redis
- Sets up Python 3.12 environment
- Installs Node.js 18

### 2. Frappe Installation
- Creates dedicated `frappe` user
- Initializes bench with specified Frappe version
- Configures bench for production use

### 3. App Installation
- Installs apps in correct order (Frappe first)
- Handles custom app installation from Git
- Creates new site or prepares for restore

### 4. Backup Restore (Optional)
- Restores database from `.sql.gz` backup
- Restores site configuration
- Sets administrator password

### 5. Production Setup
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

**Last Updated:** November 1, 2025
