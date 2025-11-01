# 📦 Custom Frappe App Template

Template for creating custom Frappe/ERPNext applications.

## 🎯 About This App

**App Name:** [Your App Name]  
**Description:** [Brief description of what your app does]  
**Version:** 1.0.0  
**Frappe Version:** 15.x  
**License:** MIT

## ✨ Features

- 🎯 [Feature 1]
- 📊 [Feature 2]
- 🔒 [Feature 3]
- ⚡ [Feature 4]

## 📋 Requirements

- Frappe Framework v15
- ERPNext v15 (if needed)
- Python 3.10+
- Node.js 18+

## 🚀 Installation

### Development (Local)

```bash
# Get the app
cd ~/frappe-bench
bench get-app https://github.com/yourusername/your_app.git

# Install to site
bench --site your-site.local install-app your_app

# Start development
bench start
```

### Production (Server)

Use the [frappe_deployment](https://github.com/Asadtop4ik/frappe_deployment) package:

```bash
# Clone deployment scripts
git clone https://github.com/Asadtop4ik/frappe_deployment.git
cd frappe_deployment

# Configure
cp .env.example .env
nano .env

# Set your app:
# APPS_TO_INSTALL="frappe,erpnext,your_app"
# CUSTOM_APP_REPO="https://github.com/yourusername/your_app.git"

# Deploy
./deploy/deploy.sh
```

**Detailed guide:** See [DEPLOYMENT_WORKFLOW.md](https://github.com/Asadtop4ik/frappe_deployment/blob/main/DEPLOYMENT_WORKFLOW.md)

## 📚 Usage

### [DocType/Feature Name]

Description of how to use this feature.

```python
# Example code
frappe.get_doc({
    "doctype": "Your DocType",
    "field_name": "value"
}).insert()
```

### [Module Name]

Description of the module.

## 🛠️ Development

### Setup Development Environment

```bash
# Create bench
bench init --frappe-branch version-15 frappe-bench
cd frappe-bench

# Get your app
bench get-app https://github.com/yourusername/your_app.git

# Create site
bench new-site dev.local
bench --site dev.local install-app your_app

# Enable developer mode
bench --site dev.local set-config developer_mode 1

# Start
bench start
```

### File Structure

```
your_app/
├── your_app/              # Main app directory
│   ├── __init__.py
│   ├── hooks.py          # App hooks and configuration
│   ├── patches.txt       # Database patches
│   ├── modules.txt       # Modules list
│   │
│   ├── config/           # Desk configuration
│   │   └── desktop.py
│   │
│   ├── [module_name]/    # Your modules
│   │   ├── doctype/      # DocTypes
│   │   ├── report/       # Reports
│   │   └── page/         # Custom pages
│   │
│   ├── public/           # Static assets
│   │   ├── js/
│   │   └── css/
│   │
│   └── templates/        # Web templates
│       └── pages/
│
├── setup.py              # Python package setup
├── requirements.txt      # Python dependencies
├── package.json          # Node dependencies
└── README.md            # This file
```

### Creating New DocType

```bash
bench --site dev.local console

# In console:
from frappe.core.doctype.doctype.doctype import DocType
doc = frappe.new_doc('DocType')
doc.update({
    'name': 'Your DocType',
    'module': 'Your Module',
    'custom': 0,
    'fields': [...],
    'permissions': [...],
})
doc.insert()
```

### Running Tests

```bash
# Run all tests
bench --site dev.local run-tests --app your_app

# Run specific test
bench --site dev.local run-tests your_app.tests.test_module
```

## 🔄 Update & Migrate

### Local Development

```bash
cd ~/frappe-bench/apps/your_app
git pull origin main

cd ~/frappe-bench
bench --site dev.local migrate
bench --site dev.local clear-cache
```

### Production Server

```bash
ssh user@your-server

su - frappe
cd ~/frappe-bench/apps/your_app
git pull origin main

cd ~/frappe-bench
bench --site your-site.local migrate
bench build --app your_app

exit
sudo supervisorctl restart all
```

## 📦 Dependencies

### Python Packages

```txt
# requirements.txt
frappe>=15.0.0
```

### JavaScript Packages

```json
{
  "dependencies": {
    "frappe": "^15.0.0"
  }
}
```

## 🐛 Troubleshooting

### Issue 1: [Common Issue]

**Problem:** Description

**Solution:**
```bash
# Commands to fix
```

### Issue 2: [Another Issue]

**Problem:** Description

**Solution:**
```bash
# Commands to fix
```

## 📸 Screenshots

![Screenshot 1](path/to/screenshot1.png)
![Screenshot 2](path/to/screenshot2.png)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Your Name** - [GitHub](https://github.com/yourusername)

## 🙏 Acknowledgments

- Frappe Framework Team
- ERPNext Community
- [Any other credits]

## 📞 Support

- **GitHub Issues:** [Report bugs or request features](https://github.com/yourusername/your_app/issues)
- **Documentation:** [Link to docs if available]
- **Community Forum:** [Frappe Forum](https://discuss.erpnext.com)

## 🔗 Related Projects

- [Frappe Framework](https://github.com/frappe/frappe)
- [ERPNext](https://github.com/frappe/erpnext)
- [Frappe Deployment Scripts](https://github.com/Asadtop4ik/frappe_deployment)

---

**Made with ❤️ using Frappe Framework**
