#!/bin/bash
set -e

echo "Configuring Apache Superset..."

# Create superset config directory
sudo -u superset mkdir -p /home/superset/.superset

# Set SUPERSET_CONFIG_PATH
echo "export SUPERSET_CONFIG_PATH=/home/superset/.superset/superset_config.py" | sudo tee -a /home/superset/.bashrc

# Create basic Superset configuration
sudo -u superset tee /home/superset/.superset/superset_config.py > /dev/null << 'EOF'
import os
from cachelib.redis import RedisCache

# Superset specific config
ROW_LIMIT = 5000

# Flask App Builder configuration
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'CHANGE_THIS_SECRET_KEY_FOR_PRODUCTION')

# The SQLAlchemy connection string to your database backend
SQLALCHEMY_DATABASE_URI = 'postgresql://superset:superset@localhost/superset'

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

# Setup PostgreSQL database for Superset
echo "Setting up PostgreSQL database..."
sudo -u postgres psql << EOF
CREATE DATABASE superset;
CREATE USER superset WITH PASSWORD 'superset';
GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
EOF

# Initialize Superset database
echo "Initializing Superset database..."
sudo -u superset bash -c "source /home/superset/superset-env/bin/activate && \
    export SUPERSET_CONFIG_PATH=/home/superset/.superset/superset_config.py && \
    superset db upgrade"

# Create admin user (username: admin, password: admin)
echo "Creating admin user..."
sudo -u superset bash -c "source /home/superset/superset-env/bin/activate && \
    export SUPERSET_CONFIG_PATH=/home/superset/.superset/superset_config.py && \
    superset fab create-admin \
        --username admin \
        --firstname Admin \
        --lastname User \
        --email admin@example.com \
        --password admin" || echo "Admin user may already exist"

# Initialize Superset
echo "Initializing Superset..."
sudo -u superset bash -c "source /home/superset/superset-env/bin/activate && \
    export SUPERSET_CONFIG_PATH=/home/superset/.superset/superset_config.py && \
    superset init"

echo "Superset configuration completed successfully"
