#!/bin/bash
set -e

echo "Installing system dependencies..."

# Install Python and related tools
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    build-essential \
    libssl-dev \
    libffi-dev \
    libsasl2-dev \
    libldap2-dev \
    libxml2-dev \
    libxslt1-dev \
    libjpeg-dev \
    libpq-dev \
    libmysqlclient-dev \
    pkg-config

# Install database and cache dependencies
sudo apt-get install -y \
    postgresql \
    postgresql-contrib \
    redis-server

echo "System dependencies installed successfully"
