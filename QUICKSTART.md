# Quick Start Guide

Get Apache Superset running in minutes with this quick start guide.

## Prerequisites

- **Packer** installed (v1.9.0+)
- For local testing: **QEMU** installed
- For Azure: Azure subscription with service principal

## Step 1: Validate Setup

```bash
# Clone the repository (if not already done)
git clone https://github.com/thefaftek-git/superset_test.git
cd superset_test

# Run validation
./validate.sh
```

Expected output: ✅ All validation checks passed!

## Step 2: Choose Your Platform

### Option A: Local Testing with QEMU (Recommended for First Time)

This is the fastest way to test the setup without cloud resources.

```bash
# Initialize Packer
packer init superset.pkr.hcl

# Build the image (takes 30-60 minutes)
packer build -only=qemu.superset superset.pkr.hcl
```

**Note**: The build process:
1. Downloads Ubuntu 22.04 ISO (~1.5GB)
2. Installs the OS automatically
3. Installs all dependencies
4. Configures Apache Superset
5. Creates a QCOW2 image in `output-qemu/`

### Option B: Azure Deployment

For production deployment to Azure.

```bash
# Set Azure credentials
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"

# Create resource group (first time only)
az group create --name superset-images --location "East US"

# Initialize Packer
packer init superset.pkr.hcl

# Build the image
packer build -only=azure-arm.superset superset.pkr.hcl
```

## Step 3: Deploy and Access

### For QEMU Build

```bash
# Start the VM
qemu-system-x86_64 \
  -m 4096 \
  -smp 2 \
  -drive file=output-qemu/superset-ubuntu-22.04,format=qcow2 \
  -net nic \
  -net user,hostfwd=tcp::8088-:8088,hostfwd=tcp::2222-:22 \
  -nographic
```

Or use a VM management tool like `virt-manager` to import the image.

### For Azure Build

```bash
# Create VM from the managed image
az vm create \
  --resource-group superset-production \
  --name superset-vm \
  --image /subscriptions/YOUR_SUB_ID/resourceGroups/superset-images/providers/Microsoft.Compute/images/superset-ubuntu-22.04-TIMESTAMP \
  --admin-username superset \
  --admin-password "YourSecurePassword123!" \
  --size Standard_D2s_v3

# Open port 8088
az vm open-port --resource-group superset-production --name superset-vm --port 8088
```

## Step 4: Access Superset

1. **Get the IP address**:
   - QEMU: `localhost:8088`
   - Azure: Get from Azure portal or `az vm show -d --resource-group superset-production --name superset-vm --query publicIps -o tsv`

2. **Open browser**: `http://<ip-address>:8088`

3. **Login**:
   - Username: `admin`
   - Password: `admin`

⚠️ **IMPORTANT**: Change the admin password immediately after first login!

## Step 5: Post-Deployment

### Change Admin Password

```bash
# SSH into the VM
ssh superset@<vm-ip>

# Activate Superset environment
source ~/superset-env/bin/activate
export SUPERSET_CONFIG_PATH=~/.superset/superset_config.py

# Reset password
superset fab reset-password --username admin
```

### Configure for Production

Edit `/home/superset/.superset/superset_config.py`:

```python
# Generate a new secret key
SECRET_KEY = 'your-new-secret-key-here'

# Optional: Configure external database
SQLALCHEMY_DATABASE_URI = 'postgresql://user:pass@external-db:5432/superset'

# Optional: Add your Mapbox API key
MAPBOX_API_KEY = 'your-mapbox-api-key'
```

Restart Superset:
```bash
sudo systemctl restart superset
```

## Common Tasks

### Check Superset Status
```bash
sudo systemctl status superset
```

### View Logs
```bash
sudo journalctl -u superset -f
```

### Restart Superset
```bash
sudo systemctl restart superset
```

### Update Superset
```bash
sudo -u superset bash
source ~/superset-env/bin/activate
pip install --upgrade apache-superset
superset db upgrade
exit
sudo systemctl restart superset
```

## Need Help?

- 📖 **Full Documentation**: See [PACKER_README.md](PACKER_README.md)
- 🔧 **Troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- 🌐 **Official Docs**: https://superset.apache.org/docs/

## What's Next?

1. **Connect Data Sources**: Add your databases in Superset UI
2. **Create Dashboards**: Build visualizations and dashboards
3. **Configure Authentication**: Set up LDAP, OAuth, or other auth methods
4. **Enable HTTPS**: Configure SSL/TLS for secure access
5. **Set up Backups**: Configure regular database backups

## Architecture Overview

The setup includes:
- ✅ Apache Superset 3.0.0
- ✅ PostgreSQL 14+ (database)
- ✅ Redis 6+ (cache & Celery broker)
- ✅ Gunicorn (WSGI server)
- ✅ Python 3.12 virtual environment
- ✅ Systemd service (auto-start on boot)

## Performance Tuning

For production workloads, consider:
- Increase Gunicorn workers (edit `/etc/systemd/system/superset.service`)
- Use larger VM size (Azure: Standard_D4s_v3 or higher)
- Configure external PostgreSQL database
- Set up Redis cluster for high availability
- Enable CDN for static assets

## Security Checklist

- [ ] Change default admin password
- [ ] Update SECRET_KEY in config
- [ ] Configure firewall (only allow necessary ports)
- [ ] Enable HTTPS/TLS
- [ ] Set up authentication (LDAP/OAuth)
- [ ] Regular security updates
- [ ] Monitor logs for suspicious activity

---

**Ready to build?** Run `./validate.sh` and follow this guide step by step!
