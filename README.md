# superset_test

Apache Superset deployment automation using Packer.

## Quick Start

This repository contains a Packer setup to build Apache Superset VM images for both local testing and Azure deployment.

📖 **See [PACKER_README.md](PACKER_README.md) for complete documentation.**

### Validate Configuration

```bash
packer init superset.pkr.hcl
packer validate superset.pkr.hcl
```

### Build for Azure

```bash
# Set Azure credentials
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"

# Build image
packer build -only=azure-arm.superset superset.pkr.hcl
```

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
