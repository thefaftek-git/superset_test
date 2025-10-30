#!/bin/bash
set -e

echo "Cleaning up..."

# Remove apt cache
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

# Remove pip cache
sudo -u superset rm -rf /home/superset/.cache/pip

# Remove temporary files
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clear bash history
history -c
sudo -u superset sh -c 'history -c' || true

echo "Cleanup completed successfully"
