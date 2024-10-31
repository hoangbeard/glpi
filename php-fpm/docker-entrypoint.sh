#!/bin/sh

set -e

# Wait for MySQL to be ready
wait_for_mysql() {
    echo "Waiting for MySQL to be ready..."
    while ! nc -z db 3306; do
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
php bin/console glpi:system:check_requirements --no-interaction -vv
echo "Check system requirements done."

# Check if GLPI is already installed
if [ ! -f /var/www/glpi/config/config_db.php ]; then
    # GLPI is not installed, run installation
    echo "==========================="
    echo "Installing GLPI database..."
    echo "==========================="
    php bin/console db:install -vv \
        --db-host=db \
        --db-port=3306 \
        --db-user=glpi \
        --db-password=glpipass \
        --db-name=glpi \
        --no-interaction \
        --force
        
    echo "Install GLPI database done."

    # Check database schema integrity
    echo "====================================="
    echo "Checking database schema integrity..."
    echo "====================================="
    php bin/console db:check_schema_integrity --no-interaction -vv
    echo "Check database schema integrity done."
else
    echo "GLPI is already installed."
    echo "======================================="
    echo "Updating GLPI database configuration..."
    echo "======================================="
    php bin/console db:configure -vv \
        --db-host=db \
        --db-port=3306 \
        --db-user=glpi \
        --db-password=glpipass \
        --db-name=glpi \
        --no-interaction \
        --reconfigure
    
    echo "GLPI database configuration updated."
fi

# Access to timezone database
echo "==========================="
echo "Enabling timezones support..."
echo "==========================="
php bin/console db:enable_timezones --no-interaction -vv
echo "Enable timezones support done."

# Plugins installation
echo "=========================="
echo "Installing GLPI plugins..."
echo "=========================="
php bin/console glpi:plugin:install --all --username=glpi --force
php bin/console glpi:plugin:activate --all
echo "Install GLPI plugins done."

# System status
echo "=============================="
echo "Checking GLPI system status..."
echo "=============================="
php bin/console glpi:system:status --format=json
echo "Check GLPI system status done."

# Remove install/ directory
# if [ -e /var/www/glpi/install ]; then
#     echo "=============================="
#     echo "Removing install/ directory..."
#     echo "=============================="
#     rm -rf /var/www/glpi/install
#     echo "Removed install/ directory."
# else
#     echo "install/ directory does not exist."
# fi

echo "==========================="
echo "GLPI installation complete."
echo "==========================="

exec "$@"
