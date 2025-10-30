# superset_test

Apache Superset deployment automation using Packer.

## 🚀 Quick Start

This repository contains a Packer setup to build Apache Superset VM images for both local testing and Azure deployment.

📖 **New here? Start with [QUICKSTART.md](QUICKSTART.md)**

📚 **Full documentation: [PACKER_README.md](PACKER_README.md)**

🔧 **Having issues? Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)**

### Validate Configuration

```bash
packer init superset.pkr.hcl
packer validate superset.pkr.hcl
```

### Build for Azure

```bash
# Set credentials via environment variables (see .env.example)
source .env  # Or export variables individually

# Build image
packer build -only=azure-arm.superset superset.pkr.hcl

# Or use a variables file
packer build -var-file=variables.pkrvars.hcl -only=azure-arm.superset superset.pkr.hcl
```

**⚠️ Important**: All credentials must be provided via environment variables or variables file. See `.env.example` and `azure.pkrvars.hcl.example` for templates.

### Test Locally with QEMU

```bash
packer build -only=qemu.superset superset.pkr.hcl
```

## What's Included

- ✅ Apache Superset (PyPI installation)
- ✅ PostgreSQL database backend
- ✅ Redis cache and Celery support
- ✅ Systemd service for automatic startup
- ✅ Production-ready Gunicorn configuration
- ✅ Multi-platform support (QEMU and Azure)
- ✅ GitHub Actions validation workflow
