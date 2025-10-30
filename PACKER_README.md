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
- **Secure by default**: No hardcoded credentials, all secrets via environment variables

## Prerequisites

### For All Builds
- Packer >= 1.9.0
- **Required credentials** (see Credentials section below):
  - Superset secret key
  - Database password
  - Admin user password

### For Local Testing (QEMU)
- QEMU installed (`apt-get install qemu-system-x86 qemu-utils`)
- At least 20GB free disk space
- 4GB RAM minimum

### For Azure Deployment
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

## Credentials Management

**⚠️ IMPORTANT**: This setup does NOT contain hardcoded credentials. All secrets must be provided via environment variables or variables file.

### Required Credentials

1. **Superset Secret Key** - Used for Flask session encryption
2. **Database Password** - PostgreSQL password for Superset database
3. **Admin Password** - Initial Superset admin user password
4. **Azure Credentials** (for Azure builds only)

### Option 1: Environment Variables (Recommended)

Copy the example file and set your credentials:

```bash
# Copy the example
cp .env.example .env

# Edit .env and set your values
nano .env

# Generate a secure secret key
python3 -c "import secrets; print(secrets.token_urlsafe(32))" >> .env

# Source the environment file
source .env
```

Required environment variables:
```bash
export SUPERSET_SECRET_KEY="your-secure-random-secret-key"
export SUPERSET_DB_PASSWORD="your-secure-database-password"
export SUPERSET_ADMIN_USERNAME="admin"
export SUPERSET_ADMIN_PASSWORD="your-secure-admin-password"
export SUPERSET_ADMIN_EMAIL="admin@example.com"

# For Azure builds
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
```

### Option 2: Variables File

```bash
# Copy the example
cp azure.pkrvars.hcl.example variables.pkrvars.hcl

# Edit and set your values
nano variables.pkrvars.hcl

# Build with variables file
packer build -var-file=variables.pkrvars.hcl superset.pkr.hcl
```

### Option 3: CI/CD Pipeline Variables

In your CI/CD pipeline (GitHub Actions, Azure DevOps, etc.):

1. Store credentials as **secret variables**
2. The pipeline will export them as environment variables
3. Packer will automatically pick them up

**GitHub Actions Example:**
```yaml
env:
  SUPERSET_SECRET_KEY: ${{ secrets.SUPERSET_SECRET_KEY }}
  SUPERSET_DB_PASSWORD: ${{ secrets.SUPERSET_DB_PASSWORD }}
  SUPERSET_ADMIN_PASSWORD: ${{ secrets.SUPERSET_ADMIN_PASSWORD }}
```

**Azure DevOps Example:**
```yaml
variables:
- group: superset-credentials  # Variable group with secrets
```

## Quick Start

### 1. Set Up Credentials

```bash
# Copy and configure environment variables
cp .env.example .env
# Edit .env with your secure values
source .env
```

### 2. Initialize Packer

```bash
packer init superset.pkr.hcl
```

### 3. Validate Configuration

```bash
packer validate superset.pkr.hcl
```

### 4. Build Image

#### Local Testing with QEMU

```bash
packer build -only=qemu.superset superset.pkr.hcl
```

This will create a QCOW2 image in the `output-qemu` directory.

**Note**: The QEMU build can take 30-60 minutes depending on your system.

#### Azure Deployment

```bash
# Credentials should already be in environment
packer build -only=azure-arm.superset superset.pkr.hcl
```

## Configuration

### Superset Version

You can specify a different Superset version:

```bash
packer build -var "superset_version=3.1.0" superset.pkr.hcl
```

### Credentials in Built Image

**⚠️ NO DEFAULT CREDENTIALS**: This setup requires you to provide all credentials during the build.

**Admin User:**
- Username: Set via `SUPERSET_ADMIN_USERNAME` (default: `admin`)
- Password: **MUST BE SET** via `SUPERSET_ADMIN_PASSWORD`
- Email: Set via `SUPERSET_ADMIN_EMAIL`

**Database:**
- PostgreSQL User: `superset`
- PostgreSQL Password: **MUST BE SET** via `SUPERSET_DB_PASSWORD`
- Database Name: `superset`

**Application:**
- Secret Key: **MUST BE SET** via `SUPERSET_SECRET_KEY`

**SSH (QEMU only):**
- Username: `superset`
- Password: `superset` (for testing only, change in production)

If credentials are not provided, the build will use placeholder values like `__SUPERSET_DB_PASSWORD__` which will cause the application to fail. **Always provide real credentials.**

## Accessing Superset

After the VM is running:

1. Superset will be available at: `http://<vm-ip>:8088`
2. Login with the credentials you set during build
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

### Built-in Security Features

✅ **No hardcoded credentials** - All secrets must be provided via environment variables  
✅ **Placeholder detection** - Missing credentials will be obvious (`__PLACEHOLDER__`)  
✅ **Sensitive variables** - Credentials marked as sensitive in Packer  
✅ **Gitignore protection** - Credential files excluded from version control  

### Production Security Checklist

1. **Use strong credentials**
   - Generate secure random passwords (min 20 characters)
   - Use `python3 -c "import secrets; print(secrets.token_urlsafe(32))"` for secret keys
   - Different credentials for dev/staging/production

2. **Secure credential storage**
   - Store in secrets vault (Azure Key Vault, HashiCorp Vault)
   - Use CI/CD secret variables
   - Never commit credentials to version control

3. **Network security**
   - Configure firewall rules to restrict access
   - Use HTTPS with proper SSL certificates
   - Limit SSH access

4. **Ongoing maintenance**
   - Rotate credentials regularly
   - Enable authentication (LDAP, OAuth, etc.)
   - Regular updates of Superset and dependencies
   - Monitor logs for suspicious activity

## References

- [Apache Superset Official Documentation](https://superset.apache.org/)
- [Superset PyPI Installation Guide](https://superset.apache.org/docs/installation/pypi)
- [Packer Documentation](https://www.packer.io/docs)
- [Packer Azure Builder](https://www.packer.io/plugins/builders/azure)

## License

This Packer configuration is provided as-is for building Apache Superset images.
Apache Superset is licensed under the Apache License 2.0.
