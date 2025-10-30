#!/bin/bash
set -e

SUPERSET_VERSION=${SUPERSET_VERSION:-"3.0.0"}

echo "Installing Apache Superset version ${SUPERSET_VERSION}..."

# Create superset user if it doesn't exist
if ! id -u superset > /dev/null 2>&1; then
    sudo useradd -m -s /bin/bash superset
fi

# Create virtual environment
sudo -u superset python3 -m venv /home/superset/superset-env

# Upgrade pip
sudo -u superset /home/superset/superset-env/bin/pip install --upgrade pip setuptools wheel

# Install Apache Superset
sudo -u superset /home/superset/superset-env/bin/pip install apache-superset=="${SUPERSET_VERSION}"

# Install additional database drivers and production server
sudo -u superset /home/superset/superset-env/bin/pip install \
    psycopg2-binary \
    redis \
    celery \
    gunicorn \
    gevent

echo "Apache Superset ${SUPERSET_VERSION} installed successfully"
