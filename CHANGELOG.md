# 📝 Changelog

All notable changes to this deployment package are documented here.

## [2.0.0] - 2025-11-01

### 🎉 Major Release - Universal Deployment Package

#### Added
- ✅ Universal deployment script for any Frappe/ERPNext project
- ✅ Flexible app configuration system
- ✅ Optional backup restore functionality
- ✅ Comprehensive `.env` configuration template
- ✅ Local development setup guide (LOCAL_SETUP.md)
- ✅ Complete documentation and troubleshooting guides
- ✅ GitIgnore for sensitive files

#### Fixed
- 🐛 Ubuntu 24.04 pip externally-managed environment error
  - Solution: `pip3 install --break-system-packages frappe-bench`
  
- 🐛 Redis connection refused on port 13000
  - Solution: Explicit Redis installation and startup
  
- 🐛 Nginx "main" log format error
  - Solution: `sed -i 's/ main;/;/g' /etc/nginx/nginx.conf`
  
- 🐛 **CRITICAL**: Static files 404 error (permission issue)
  - Root cause: nginx (www-data user) couldn't access /home/frappe
  - Solution: `chmod 755 /home/frappe`
  - Debug method: `sudo -u www-data test -r /home/frappe/...`
  
- 🐛 Supervisor sudo access issues
  - Solution: Added passwordless sudo for frappe user

#### Improved
- 📈 Better error handling and validation
- 📈 Detailed logging throughout deployment
- 📈 Configuration validation before deployment
- 📈 Step-by-step progress indicators
- 📈 Professional documentation structure

#### Technical Details
- Tested on: Ubuntu 24.04, 22.04, 20.04
- Frappe version: v15 (configurable)
- Python: 3.10, 3.11, 3.12
- Node.js: v18 LTS
- MariaDB: 10.6+

### Deployment Statistics
- Fresh installation: ~20-30 minutes
- With backup restore: ~25-35 minutes
- Server requirements: 2GB RAM minimum (4GB recommended)

## [1.0.0] - 2025-10-31

### Initial Release

#### Features
- Basic Frappe/ERPNext deployment script
- Single project focus
- Manual configuration
- Fixed app list (erpnext, hrms, ext_accounts)

#### Issues Discovered
- ❌ Not tested on Ubuntu 24.04
- ❌ Redis startup issues
- ❌ Permission problems with static files
- ❌ Nginx configuration conflicts
- ❌ Not reusable across projects

#### Lessons Learned
- Need for universal configuration
- Importance of permission testing
- Ubuntu version-specific handling required
- Service startup order matters

---

## Version History

| Version | Date       | Type    | Description                          |
|---------|------------|---------|--------------------------------------|
| 2.0.0   | 2025-11-01 | Major   | Universal deployment package         |
| 1.0.0   | 2025-10-31 | Initial | First production deployment attempt  |

## Upgrade Guide

### From v1.0 to v2.0

If you used the old script:

1. **Backup your site:**
```bash
cd /home/frappe/frappe-bench
bench --site yoursite.local backup --with-files
```

2. **No need to redeploy** - v2.0 is for new deployments
   - Your existing site continues working
   - Use v2.0 for new projects

3. **Want to use new features?**
   - Scripts are deployment-only (not for upgrades)
   - Consider manual updates or new site migration

## Roadmap

### Planned Features (v2.1)
- [ ] Docker support
- [ ] Automated SSL certificate renewal script
- [ ] Health check endpoints
- [ ] Backup automation script
- [ ] Multi-site deployment
- [ ] One-click app updates
- [ ] Monitoring setup (Prometheus/Grafana)

### Under Consideration (v3.0)
- [ ] Kubernetes deployment
- [ ] High availability setup
- [ ] Load balancer configuration
- [ ] Database replication setup
- [ ] Automated failover
- [ ] CI/CD pipeline templates

## Contributing

Found a bug or have a suggestion? 

1. Check existing issues
2. Create detailed bug report with:
   - OS version
   - Error messages
   - Steps to reproduce
   - `.env` configuration (remove sensitive data)

## Credits

**Developed by:** Senior DevOps Team
**Based on:** Real production deployment experience
**Tested on:** DigitalOcean, AWS, Hetzner, Linode

---

**Latest Stable:** v2.0.0
**Status:** Production Ready ✅
**Support:** Community Driven
