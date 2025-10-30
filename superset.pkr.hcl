packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
    azure = {
      version = ">= 2.0.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "ubuntu_iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso"
}

variable "ubuntu_iso_checksum" {
  type    = string
  default = "sha256:a4acfda10b18da50e2ec50ccaf860d7f20b389df8765611142305c0e911d16fd"
}

variable "superset_version" {
  type    = string
  default = "3.0.0"
}

# Superset credentials - should be provided via environment variables or variables file
variable "superset_secret_key" {
  type      = string
  default   = env("SUPERSET_SECRET_KEY")
  sensitive = true
}

variable "superset_db_password" {
  type      = string
  default   = env("SUPERSET_DB_PASSWORD")
  sensitive = true
}

variable "superset_admin_username" {
  type    = string
  default = env("SUPERSET_ADMIN_USERNAME")
}

variable "superset_admin_password" {
  type      = string
  default   = env("SUPERSET_ADMIN_PASSWORD")
  sensitive = true
}

variable "superset_admin_email" {
  type    = string
  default = env("SUPERSET_ADMIN_EMAIL")
}

variable "azure_client_id" {
  type    = string
  default = env("AZURE_CLIENT_ID")
}

variable "azure_client_secret" {
  type    = string
  default = env("AZURE_CLIENT_SECRET")
}

variable "azure_subscription_id" {
  type    = string
  default = env("AZURE_SUBSCRIPTION_ID")
}

variable "azure_tenant_id" {
  type    = string
  default = env("AZURE_TENANT_ID")
}

# QEMU builder for local testing and GitHub Actions
source "qemu" "superset" {
  iso_url          = var.ubuntu_iso_url
  iso_checksum     = var.ubuntu_iso_checksum
  output_directory = "output-qemu"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  disk_size        = "20480"
  format           = "qcow2"
  accelerator      = "tcg"
  http_directory   = "http"
  ssh_username     = "superset"
  ssh_password     = "superset"
  ssh_timeout      = "30m"
  vm_name          = "superset-ubuntu-22.04"
  net_device       = "virtio-net"
  disk_interface   = "virtio"
  headless         = true
  memory           = 4096
  cpus             = 2

  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ --- <enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>"
  ]
}

# Azure ARM builder for production
source "azure-arm" "superset" {
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id

  managed_image_resource_group_name = "superset-images"
  managed_image_name                = "superset-ubuntu-22.04-{{timestamp}}"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  location = "East US"
  vm_size  = "Standard_D2s_v3"
}

build {
  name = "superset"

  sources = [
    "source.qemu.superset",
    "source.azure-arm.superset"
  ]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || echo 'cloud-init not available, continuing...'"
    ]
    only = ["azure-arm.superset"]
  }

  # Update system packages
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y"
    ]
  }

  # Install dependencies
  provisioner "shell" {
    script = "scripts/install_dependencies.sh"
  }

  # Install Apache Superset
  provisioner "shell" {
    script = "scripts/install_superset.sh"
    environment_vars = [
      "SUPERSET_VERSION=${var.superset_version}"
    ]
  }

  # Configure Superset
  provisioner "shell" {
    script = "scripts/configure_superset.sh"
    environment_vars = [
      "SUPERSET_SECRET_KEY=${var.superset_secret_key}",
      "SUPERSET_DB_PASSWORD=${var.superset_db_password}",
      "SUPERSET_ADMIN_USERNAME=${var.superset_admin_username}",
      "SUPERSET_ADMIN_PASSWORD=${var.superset_admin_password}",
      "SUPERSET_ADMIN_EMAIL=${var.superset_admin_email}"
    ]
  }

  # Setup systemd service
  provisioner "file" {
    source      = "configs/superset.service"
    destination = "/tmp/superset.service"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/superset.service /etc/systemd/system/superset.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable superset"
    ]
  }

  # Cleanup
  provisioner "shell" {
    script = "scripts/cleanup.sh"
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
}
