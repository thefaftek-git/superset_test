# Apache Superset Packer Setup

This repository contains Packer configuration to build Apache Superset images for both local testing (QEMU) and Azure deployment.

## Overview

The Packer setup installs Apache Superset following the official PyPI installation guide: https://superset.apache.org/docs/installation/pypi

## Features

- **Multi-platform support**: QEMU (for local testing) and Azure ARM (for production)
- **Automated installation**: Complete setup of Apache Superset with dependencies
- **PostgreSQL database**: Pre-configured PostgreSQL database backend
- **Redis cache**: Redis for caching and Celery task queue
- **Systemd service**: Automatic startup with systemd
- **Production-ready**: Uses Gunicorn with gevent workers

## Prerequisites

### For Local Testing (QEMU)
- Packer >= 1.9.0
- QEMU installed (`apt-get install qemu-system-x86 qemu-utils`)
- At least 20GB free disk space
- 4GB RAM minimum

### For Azure Deployment
- Packer >= 1.9.0
- Azure subscription
- Azure service principal with appropriate permissions
- Resource group created: `superset-images`

## File Structure

```
.
├── superset.pkr.hcl              # Main Packer configuration
├── scripts/
│   ├── install_dependencies.sh   # Install system dependencies
│   ├── install_superset.sh       # Install Apache Superset
│   ├── configure_superset.sh     # Configure Superset and create admin user
│   └── cleanup.sh                # Clean up before image creation
├── configs/
│   └── superset.service          # Systemd service file
├── http/
│   ├── user-data                 # Cloud-init configuration for QEMU
│   └── meta-data                 # Cloud-init metadata for QEMU
└── .github/workflows/
    └── packer-validate.yml       # CI/CD validation workflow
```

## Quick Start

### 1. Initialize Packer

```bash
packer init superset.pkr.hcl
```

### 2. Validate Configuration

```bash
packer validate superset.pkr.hcl
```

### 3. Build Image

#### Local Testing with QEMU

```bash
packer build -only=qemu.superset superset.pkr.hcl
```

This will create a QCOW2 image in the `output-qemu` directory.

**Note**: The QEMU build can take 30-60 minutes depending on your system.

#### Azure Deployment

First, set your Azure credentials as environment variables:

```bash
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
```

Then build:

```bash
packer build -only=azure-arm.superset superset.pkr.hcl
```

## Configuration

### Superset Version

You can specify a different Superset version:

```bash
packer build -var "superset_version=3.1.0" superset.pkr.hcl
```

### Default Credentials

**Admin User:**
- Username: `admin`
- Password: `admin`

**Database:**
- PostgreSQL User: `superset`
- PostgreSQL Password: `superset`
- Database Name: `superset`

**SSH (QEMU only):**
- Username: `superset`
- Password: `superset`

⚠️ **IMPORTANT**: Change these default credentials in production!

## Accessing Superset

After the VM is running:

1. Superset will be available at: `http://<vm-ip>:8088`
2. Login with username `admin` and password `admin`
3. The Superset service runs automatically via systemd

### Service Management

```bash
# Check status
sudo systemctl status superset

# Restart service
sudo systemctl restart superset

# View logs
sudo journalctl -u superset -f
```

## Customization

### Superset Configuration

The Superset configuration file is located at:
```
/home/superset/.superset/superset_config.py
```

Key settings you may want to customize:
- `SECRET_KEY`: Change for production
- `SQLALCHEMY_DATABASE_URI`: Database connection string
- `CACHE_CONFIG`: Redis cache settings
- `MAPBOX_API_KEY`: For map visualizations

### Modifying the Build

1. Edit provisioning scripts in `scripts/` directory
2. Update `superset.pkr.hcl` as needed
3. Validate: `packer validate superset.pkr.hcl`
4. Build with your changes

## Testing with QEMU

To test the built QEMU image:

```bash
# Start the VM
qemu-system-x86_64 \
  -m 4096 \
  -smp 2 \
  -drive file=output-qemu/superset-ubuntu-22.04,format=qcow2 \
  -net nic -net user,hostfwd=tcp::8088-:8088 \
  -nographic
```

Then access Superset at `http://localhost:8088`

## CI/CD Integration

The repository includes a GitHub Actions workflow (`.github/workflows/packer-validate.yml`) that:
- Validates Packer configuration on every push/PR
- Checks formatting
- Can be manually triggered to test builds

## Troubleshooting

### Build Failures

1. **QEMU build timeout**: Increase `ssh_timeout` in `superset.pkr.hcl`
2. **Disk space**: Ensure you have at least 20GB free
3. **Memory**: Allocate at least 4GB RAM to the VM

### Superset Issues

Check logs:
```bash
sudo journalctl -u superset -f
```

Database issues:
```bash
sudo -u postgres psql
\l  # List databases
\c superset  # Connect to superset database
```

### Azure Build Issues

1. Verify service principal permissions
2. Ensure resource group exists: `superset-images`
3. Check Azure quota limits for VM size

## Security Considerations

1. **Change default passwords** before production use
2. **Configure firewall rules** to restrict access
3. **Use HTTPS** with proper SSL certificates
4. **Rotate SECRET_KEY** in production
5. **Enable authentication** (LDAP, OAuth, etc.)
6. **Regular updates** of Superset and dependencies

## References

- [Apache Superset Official Documentation](https://superset.apache.org/)
- [Superset PyPI Installation Guide](https://superset.apache.org/docs/installation/pypi)
- [Packer Documentation](https://www.packer.io/docs)
- [Packer Azure Builder](https://www.packer.io/plugins/builders/azure)

## License

This Packer configuration is provided as-is for building Apache Superset images.
Apache Superset is licensed under the Apache License 2.0.
