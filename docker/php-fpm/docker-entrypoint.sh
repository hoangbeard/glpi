#!/bin/bash

set -e

# Check system information
echo "----- System Information -----"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d '=' -f 2)"
echo "Kernel: $(uname -r)"
echo "CPU: $(lscpu | grep 'Model name' | cut -d ':' -f 2 | xargs)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $2}')"
echo "User: $(whoami)"
echo "Architecture: $(uname -m)"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
hostname -I | awk '{print "IP Address: " $1}'
echo "------------------------------"

# Wait for MySQL to be ready
echo "----- Checking database connecion -----"
while ! nc -z ${GLPI_DB_HOST} ${GLPI_DB_PORT}; do
    sleep 5
    echo -n "Waiting for MySQL to be ready..."
done
echo "MySQL is ready."

# Setting GLPI configuration
echo "=============================="
echo "Start GLPI configuration setup"
echo "=============================="

echo "----- Checking system requirements -----"
php bin/console glpi:system:check_requirements --no-interaction -vvv
echo "Check system requirements done."

# Check if GLPI is already installed
if [ ! -f /glpi-data/config/config_db.php ]; then
    # GLPI is not installed, run installation
    echo "----- Installing GLPI database -----"
    php bin/console db:install -vvv \
    --db-host="${GLPI_DB_HOST}" \
    --db-port="${GLPI_DB_PORT}" \
    --db-name="${GLPI_DB_DATABASE}" \
    --db-user="${GLPI_DB_USER}" \
    --db-password="${GLPI_DB_PASSWORD}" \
    --no-interaction \
    --force
    
    echo "Install GLPI database done."
    
    # Check database schema integrity
    echo "----- Checking database schema integrity -----"
    php bin/console db:check_schema_integrity --no-interaction -vvv
    echo "Check database schema integrity done."
    
    # Access to timezone database
    echo "----- Enabling timezones support -----"
    php bin/console db:enable_timezones --no-interaction -vvv
    echo "Enable timezones support done."
else
    # Reconfigure GLPI database configuration
    echo "----- GLPI is already installed. Re-configuring database configuration -----"
    php bin/console db:configure -vvv \
    --db-host="${GLPI_DB_HOST}" \
    --db-port="${GLPI_DB_PORT}" \
    --db-name="${GLPI_DB_DATABASE}" \
    --db-user="${GLPI_DB_USER}" \
    --db-password="${GLPI_DB_PASSWORD}" \
    --no-interaction \
    --reconfigure
    
    echo "GLPI database configuration done."

    # Update DB
    echo "----- Updating database -----"
    php bin/console db:update -vvv
    echo "Update database done."

    # Check database schema integrity
    echo "----- Checking database schema integrity -----"
    php bin/console db:check_schema_integrity --no-interaction -vvv
    echo "Check database schema integrity done."
fi

# Plugins installation
echo "----- Installing GLPI plugins -----"
php bin/console glpi:plugin:install --all --username="${GLPI_ADMIN_USER}" --force
php bin/console glpi:plugin:activate --all
echo "Install GLPI plugins done."

# Remove install/ directory
echo "----- Removing Install directory -----"
if [ -e /var/www/glpi/install ]; then
    rm -rf /var/www/glpi/install
    echo "Remove Install directory done."
else
    echo "Install directory does not exist. Skipping removal."
fi

# System status
echo "----- Checking GLPI system status -----"
php bin/console config:set --version
php bin/console glpi:system:status --format=json
echo "Check GLPI system status done."

echo ""
echo "======================="
echo "GLPI setting completed."
echo "======================="

exec "$@"