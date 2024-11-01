#!/bin/sh

set -e

# Wait for MySQL to be ready
wait_for_mysql() {
    echo "Waiting for MySQL to be ready..."
    while ! nc -z db $GLPI_DB_PORT; do
        sleep 1
    done
    echo "MySQL is ready."
}

# Call the wait function
wait_for_mysql

# Check system requirements
echo "==============================="
echo "Checking system requirements..."
echo "==============================="
php bin/console glpi:system:check_requirements --ansi --no-interaction -vv
echo "Check system requirements done."

# Check if GLPI is already installed
if [ ! -f /var/www/glpi/config/config_db.php ]; then
    # GLPI is not installed, run installation
    echo "==========================="
    echo "Installing GLPI database..."
    echo "==========================="
    php bin/console db:install --ansi -vv \
        --db-host="${GLPI_DB_HOST}" \
        --db-port="${GLPI_DB_PORT}" \
        --db-name="${GLPI_DB_DATABASE}" \
        --db-user="${GLPI_DB_USER}" \
        --db-password="${GLPI_DB_PASSWORD}" \
        --no-interaction \
        --force
        
    echo "Install GLPI database done."

    # Check database schema integrity
    echo "====================================="
    echo "Checking database schema integrity..."
    echo "====================================="
    php bin/console db:check_schema_integrity --ansi --no-interaction -vv
    echo "Check database schema integrity done."
else
    echo "GLPI is already installed."
    echo "======================================="
    echo "Reconfigure GLPI database configuration..."
    echo "======================================="
    php bin/console db:configure --ansi -vv \
        --db-host="${GLPI_DB_HOST}" \
        --db-port="${GLPI_DB_PORT}" \
        --db-name="${GLPI_DB_DATABASE}" \
        --db-user="${GLPI_DB_USER}" \
        --db-password="${GLPI_DB_PASSWORD}" \
        --no-interaction \
        --reconfigure
    
    echo "GLPI database configuration updated."
fi

# Access to timezone database
echo "==========================="
echo "Enabling timezones support..."
echo "==========================="
php bin/console db:enable_timezones --ansi --no-interaction -vv
echo "Enable timezones support done."

# Plugins installation
echo "=========================="
echo "Installing GLPI plugins..."
echo "=========================="
php bin/console glpi:plugin:install --ansi --all --username="${GLPI_ADMIN_USER}" --force
php bin/console glpi:plugin:activate --ansi --all
echo "Install GLPI plugins done."

# System status
echo "=============================="
echo "Checking GLPI system status..."
echo "=============================="
php bin/console config:set --ansi --version
php bin/console glpi:system:status --ansi --format=json
echo "Check GLPI system status done."

# Remove install/ directory
echo "=============================="
echo "Removing install/ directory..."
echo "=============================="
if [ -e /var/www/glpi/install ]; then
    rm -rf /var/www/glpi/install
    echo "Removed install/ directory."
else
    echo "install/ directory does not exist."
fi

# Set permissions
echo "=============================="
echo "Setting permissions..."
echo "=============================="
chown -R www-data:www-data /var/www/glpi/files
chmod 2775 /var/www/glpi/files
find /var/www/glpi/files -type d -exec chmod 2775 {} \;
find /var/www/glpi/files -type f -exec chmod 0664 {} \;
echo "Permissions set."

echo ""
echo "==========================="
echo "GLPI installation complete."
echo "==========================="

exec "$@"
