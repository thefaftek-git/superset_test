#!/bin/bash
set -e

echo "Configuring Apache Superset..."

# Create superset config directory
sudo -u superset mkdir -p /home/superset/.superset

# Set SUPERSET_CONFIG_PATH
echo "export SUPERSET_CONFIG_PATH=/home/superset/.superset/superset_config.py" | sudo tee -a /home/superset/.bashrc

# Get credentials from environment variables or use placeholders
DB_PASSWORD="${SUPERSET_DB_PASSWORD:-__SUPERSET_DB_PASSWORD__}"

# Create basic Superset configuration
# Note: Using single quotes in EOF to prevent variable expansion
sudo -u superset tee /home/superset/.superset/superset_config.py > /dev/null << 'EOF'
import os
from cachelib.redis import RedisCache

# Superset specific config
ROW_LIMIT = 5000

# Flask App Builder configuration
# SECRET_KEY should be set via SUPERSET_SECRET_KEY environment variable
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', '__SUPERSET_SECRET_KEY__')

# The SQLAlchemy connection string to your database backend
# Database password should be set via SUPERSET_DB_PASSWORD environment variable
db_user = os.environ.get('SUPERSET_DB_USER', 'superset')
db_password = os.environ.get('SUPERSET_DB_PASSWORD', '__SUPERSET_DB_PASSWORD__')
db_host = os.environ.get('SUPERSET_DB_HOST', 'localhost')
db_name = os.environ.get('SUPERSET_DB_NAME', 'superset')

SQLALCHEMY_DATABASE_URI = os.environ.get(
    'SUPERSET_DATABASE_URI',
    f'postgresql://{db_user}:{db_password}@{db_host}/{db_name}'
)

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None

# Set this API key to enable Mapbox visualizations
MAPBOX_API_KEY = os.environ.get('MAPBOX_API_KEY', '')

# Cache configuration
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': 'localhost',
    'CACHE_REDIS_PORT': 6379,
    'CACHE_REDIS_DB': 1,
}

# Celery configuration
class CeleryConfig:
    broker_url = 'redis://localhost:6379/0'
    imports = ('superset.sql_lab', )
    result_backend = 'redis://localhost:6379/0'
    worker_prefetch_multiplier = 1
    task_acks_late = False

CELERY_CONFIG = CeleryConfig
EOF

# Create environment file for systemd service
echo "Creating environment file for systemd service..."
sudo mkdir -p /etc/superset
sudo tee /etc/superset/environment > /dev/null << EOF
SUPERSET_CONFIG_PATH=/home/superset/.superset/superset_config.py
FLASK_APP=superset
SUPERSET_SECRET_KEY=${SUPERSET_SECRET_KEY:-__SUPERSET_SECRET_KEY__}
SUPERSET_DB_PASSWORD=${DB_PASSWORD}
EOF

# Secure the environment file
sudo chmod 600 /etc/superset/environment
sudo chown superset:superset /etc/superset/environment

# Setup PostgreSQL database for Superset
echo "Setting up PostgreSQL database..."
# DB_PASSWORD already set at the top of the script
sudo -u postgres psql << EOF
CREATE DATABASE superset;
CREATE USER superset WITH PASSWORD '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
EOF

# Initialize Superset database
echo "Initializing Superset database..."
sudo -u superset bash -c "source /home/superset/superset-env/bin/activate && \
    export SUPERSET_CONFIG_PATH=/home/superset/.superset/superset_config.py && \
    superset db upgrade"

# Create admin user with credentials from environment variables
echo "Creating admin user..."
ADMIN_USERNAME="${SUPERSET_ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${SUPERSET_ADMIN_PASSWORD:-__SUPERSET_ADMIN_PASSWORD__}"
ADMIN_EMAIL="${SUPERSET_ADMIN_EMAIL:-admin@example.com}"
ADMIN_FIRSTNAME="${SUPERSET_ADMIN_FIRSTNAME:-Admin}"
ADMIN_LASTNAME="${SUPERSET_ADMIN_LASTNAME:-User}"

sudo -u superset bash -c "source /home/superset/superset-env/bin/activate && \
    export SUPERSET_CONFIG_PATH=/home/superset/.superset/superset_config.py && \
    superset fab create-admin \
        --username ${ADMIN_USERNAME} \
        --firstname ${ADMIN_FIRSTNAME} \
        --lastname ${ADMIN_LASTNAME} \
        --email ${ADMIN_EMAIL} \
        --password ${ADMIN_PASSWORD}" || echo "Admin user may already exist"

# Initialize Superset
echo "Initializing Superset..."
sudo -u superset bash -c "source /home/superset/superset-env/bin/activate && \
    export SUPERSET_CONFIG_PATH=/home/superset/.superset/superset_config.py && \
    superset init"

echo "Superset configuration completed successfully"
