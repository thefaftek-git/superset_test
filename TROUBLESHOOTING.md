# Troubleshooting Guide

This guide helps you resolve common issues when building and deploying Apache Superset with Packer.

## Packer Build Issues

### Issue: "Failed to initialize Packer plugins"

**Solution:**
```bash
# Clean plugin cache and reinitialize
rm -rf ~/.config/packer/plugins
packer init superset.pkr.hcl
```

### Issue: "QEMU build timeout" or SSH connection failures

**Symptoms:**
- Build hangs at "Waiting for SSH"
- Timeout after 30 minutes

**Solutions:**
1. Increase SSH timeout in `superset.pkr.hcl`:
   ```hcl
   ssh_timeout = "60m"  # Increase from 30m
   ```

2. Check if virtualization is enabled:
   ```bash
   # On Linux
   egrep -c '(vmx|svm)' /proc/cpuinfo
   # Should return > 0
   ```

3. Try using KVM accelerator (if available):
   ```hcl
   accelerator = "kvm"  # Instead of "tcg"
   ```

### Issue: "Disk space error during build"

**Symptoms:**
- "No space left on device"
- Build fails during apt-get or pip install

**Solutions:**
1. Check available disk space:
   ```bash
   df -h
   ```

2. Increase disk size in `superset.pkr.hcl`:
   ```hcl
   disk_size = "30720"  # 30GB instead of 20GB
   ```

3. Clean up Docker and system cache:
   ```bash
   docker system prune -a
   sudo apt-get clean
   ```

## Azure Build Issues

### Issue: "Authentication failed"

**Symptoms:**
- "Error validating credentials"
- "Service principal not found"

**Solutions:**
1. Verify credentials are set:
   ```bash
   echo $AZURE_CLIENT_ID
   echo $AZURE_SUBSCRIPTION_ID
   # Should print non-empty values
   ```

2. Test Azure CLI authentication:
   ```bash
   az login --service-principal \
     -u $AZURE_CLIENT_ID \
     -p $AZURE_CLIENT_SECRET \
     --tenant $AZURE_TENANT_ID
   ```

3. Verify service principal has required permissions:
   - Contributor role on subscription or resource group
   - Permissions to create managed images

### Issue: "Resource group not found"

**Solution:**
Create the resource group first:
```bash
az group create --name superset-images --location "East US"
```

### Issue: "VM size not available in region"

**Solution:**
Change VM size or location in `superset.pkr.hcl`:
```hcl
source "azure-arm" "superset" {
  location = "West US"  # Try different region
  vm_size  = "Standard_B2s"  # Or different size
}
```

Check available sizes:
```bash
az vm list-sizes --location "East US" -o table
```

## Superset Installation Issues

### Issue: "pip install fails for apache-superset"

**Symptoms:**
- Build errors during `install_superset.sh`
- Compilation errors for C extensions

**Solutions:**
1. Verify all system dependencies are installed in `install_dependencies.sh`

2. Try pinning specific versions:
   ```bash
   # In install_superset.sh
   sudo -u superset /home/superset/superset-env/bin/pip install \
     apache-superset==3.0.0 \
     --no-cache-dir
   ```

3. Check Python version compatibility:
   ```bash
   python3 --version
   # Superset 3.0 requires Python 3.9+
   ```

### Issue: "PostgreSQL connection refused"

**Symptoms:**
- Database initialization fails
- "Connection refused" errors

**Solutions:**
1. Verify PostgreSQL is running:
   ```bash
   sudo systemctl status postgresql
   ```

2. Check PostgreSQL is accepting connections:
   ```bash
   sudo -u postgres psql -c "SELECT 1"
   ```

3. Verify database and user exist:
   ```bash
   sudo -u postgres psql -c "\l" | grep superset
   sudo -u postgres psql -c "\du" | grep superset
   ```

### Issue: "Superset initialization fails"

**Symptoms:**
- `superset db upgrade` fails
- `superset init` errors

**Solutions:**
1. Check Superset logs:
   ```bash
   sudo journalctl -u superset -n 100
   ```

2. Manually test initialization:
   ```bash
   sudo -u superset bash
   source ~/superset-env/bin/activate
   export SUPERSET_CONFIG_PATH=~/.superset/superset_config.py
   superset db upgrade
   superset init
   ```

3. Reset database (if needed):
   ```bash
   sudo -u postgres psql << EOF
   DROP DATABASE superset;
   CREATE DATABASE superset;
   GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
   EOF
   ```

## Runtime Issues

### Issue: "Superset service won't start"

**Solutions:**
1. Check service status:
   ```bash
   sudo systemctl status superset
   ```

2. View detailed logs:
   ```bash
   sudo journalctl -u superset -f
   ```

3. Test Superset manually:
   ```bash
   sudo -u superset bash
   source ~/superset-env/bin/activate
   export SUPERSET_CONFIG_PATH=~/.superset/superset_config.py
   superset run -h 0.0.0.0 -p 8088 --with-threads
   ```

4. Check if port is already in use:
   ```bash
   sudo netstat -tlnp | grep 8088
   ```

### Issue: "Cannot access Superset UI"

**Solutions:**
1. Verify Superset is running:
   ```bash
   curl http://localhost:8088/health
   ```

2. Check firewall rules:
   ```bash
   # On Ubuntu
   sudo ufw status
   sudo ufw allow 8088/tcp
   ```

3. For Azure VMs, check Network Security Group:
   - Allow inbound traffic on port 8088
   - Or use Azure Bastion/SSH tunnel

4. Use SSH tunnel for testing:
   ```bash
   ssh -L 8088:localhost:8088 superset@vm-ip
   # Then access http://localhost:8088 on your machine
   ```

### Issue: "Login fails with admin/admin"

**Solutions:**
1. Reset admin password:
   ```bash
   sudo -u superset bash
   source ~/superset-env/bin/activate
   export SUPERSET_CONFIG_PATH=~/.superset/superset_config.py
   superset fab reset-password --username admin
   ```

2. Create new admin user:
   ```bash
   superset fab create-admin
   ```

## Performance Issues

### Issue: "Slow query performance"

**Solutions:**
1. Increase Gunicorn workers in `configs/superset.service`:
   ```
   ExecStart=/home/superset/superset-env/bin/gunicorn \
     -w 20 \  # Increase from 10
     ...
   ```

2. Verify Redis is running:
   ```bash
   redis-cli ping
   # Should return PONG
   ```

3. Monitor system resources:
   ```bash
   htop
   # Or
   top
   ```

### Issue: "Out of memory errors"

**Solutions:**
1. Increase VM memory in `superset.pkr.hcl`:
   ```hcl
   memory = 8192  # 8GB instead of 4GB
   ```

2. For Azure, use larger VM size:
   ```hcl
   vm_size = "Standard_D4s_v3"  # 4 vCPUs, 16GB RAM
   ```

3. Add swap space:
   ```bash
   sudo fallocate -l 4G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

## Validation Issues

### Issue: "Packer validate fails"

**Solutions:**
1. Check HCL syntax:
   ```bash
   packer fmt superset.pkr.hcl
   packer validate superset.pkr.hcl
   ```

2. Verify plugin versions:
   ```bash
   packer init superset.pkr.hcl
   ```

3. Check for missing variables:
   ```bash
   packer validate -var-file=azure.pkrvars.hcl superset.pkr.hcl
   ```

### Issue: "Shell scripts fail shellcheck"

**Solution:**
```bash
shellcheck scripts/*.sh
# Fix reported issues
```

## Getting Help

If you're still experiencing issues:

1. Check Superset documentation: https://superset.apache.org/docs/
2. Review Packer logs in detail
3. Test components individually (PostgreSQL, Redis, Python, etc.)
4. Check system logs: `journalctl -xe`
5. Verify network connectivity and DNS resolution

## Debug Mode

Enable detailed logging for troubleshooting:

```bash
# For Packer
export PACKER_LOG=1
packer build superset.pkr.hcl

# For Superset
export SUPERSET_LOG_LEVEL=DEBUG
sudo systemctl restart superset
```

## Common Commands Reference

```bash
# Packer
packer init superset.pkr.hcl
packer validate superset.pkr.hcl
packer build superset.pkr.hcl
packer build -force superset.pkr.hcl  # Rebuild from scratch

# Superset service
sudo systemctl status superset
sudo systemctl restart superset
sudo systemctl stop superset
sudo systemctl start superset
sudo journalctl -u superset -f

# Database
sudo -u postgres psql
\l  # List databases
\c superset  # Connect to database
\dt  # List tables
\q  # Quit

# Redis
redis-cli ping
redis-cli info
redis-cli keys '*'
```
