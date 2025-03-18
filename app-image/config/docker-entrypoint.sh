#!/bin/bash

set -e

# Check system information
echo "{\
\"os\":\"$(cat /etc/os-release | grep PRETTY_NAME | cut -d '=' -f 2 | tr -d '"')\", \
\"kernel\":\"$(uname -r)\", \
\"cpu\":\"$(lscpu | grep 'Model name' | cut -d ':' -f 2 | xargs)\", \
\"memory\":\"$(free -h | grep Mem | awk '{print $2}')\", \
\"disk\":\"$(df -h / | tail -1 | awk '{print $2}')\", \
\"user\":\"$(whoami)\",\"architecture\":\"$(uname -m)\", \
\"hostname\":\"$(hostname)\", \
\"uptime\":\"$(uptime -p | sed 's/up //')\", \
\"ip_address\":\"$(hostname -I | awk '{print $1}')\", \
\"supervisor_version\":\"$(supervisord -v)\", \
\"nginx_version\":\"$(nginx -v 2>&1 | awk -F'/' '{print $2}')\", \
\"php_version\":\"$(php -v | head -1 | awk '{print $2}')\", \
\"php_fpm_version\":\"$(php-fpm -v | head -1 | awk '{print $2}')\", \
\"composer_version\":\"$(composer -V 2>&1 | head -1 | awk '{print $3}') \
\"}"

# Wait for MySQL to be ready
echo "----- Checking database connection -----"
max_retries=30
counter=0
while [ $counter -lt $max_retries ]; do
    if php -r "
        \$conn = @mysqli_connect(
            '${GLPI_DB_HOST}',
            '${GLPI_DB_USER}',
            '${GLPI_DB_PASSWORD}',
            '${GLPI_DB_DATABASE}',
            ${GLPI_DB_PORT}
        );
        exit(is_resource(\$conn) || is_object(\$conn) ? 0 : 1);
    "; then
        echo "MySQL is ready."
        break
    else
        counter=$((counter+1))
        echo "Waiting for MySQL to be ready... ($counter/$max_retries)"
        sleep 5
    fi
    
    if [ $counter -eq $max_retries ]; then
        echo "Could not connect to MySQL after $max_retries attempts. Exiting."
        exit 1
    fi
done

# Setting GLPI configuration
echo "----- Checking system requirements -----"
php bin/console glpi:system:check_requirements --no-interaction -v
echo "Check system requirements done."

# Check if GLPI is already installed
if [ ! -f /glpi-data/config/config_db.php ]; then
    # GLPI is not installed, run installation
    echo "----- Installing GLPI database -----"
    php bin/console db:install -v \
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
    php bin/console db:check_schema_integrity --no-interaction -v
    echo "Check database schema integrity done."
    
    # Access to timezone database
    echo "----- Enabling timezones support -----"
    php bin/console db:enable_timezones --no-interaction -v
    echo "Enable timezones support done."
else
    # Reconfigure GLPI database configuration
    echo "----- GLPI is already installed. Re-configuring database configuration -----"
    php bin/console db:configure -v \
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
    php bin/console db:update -v
    echo "Update database done."

    # Check database schema integrity
    echo "----- Checking database schema integrity -----"
    php bin/console db:check_schema_integrity --no-interaction -v
    echo "Check database schema integrity done."
fi

# Plugins installation
echo "----- Installing GLPI plugins -----"
php bin/console glpi:plugin:install --all --username="${GLPI_ADMIN_USER}" --force
php bin/console glpi:plugin:activate --all
echo "Install GLPI plugins done."

# Remove install/ directory
echo "----- Removing Install directory -----"
if [ -e ${APP_SOURCE_PATH}/install ]; then
    rm -rf ${APP_SOURCE_PATH}/install
    echo "Remove Install directory done."
else
    echo "Install directory does not exist. Skipping removal."
fi

# System status
echo "----- Checking GLPI system status -----"
php bin/console config:set --version
php bin/console glpi:system:status --format=json
echo "Check GLPI system status done."

exec "$@"