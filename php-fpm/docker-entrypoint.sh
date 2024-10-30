#!/bin/sh

set -e

# Check system requirements
# echo "Checking system requirements..."
# php bin/console glpi:system:check_requirements --no-interaction

# Set necessary permissions
echo "Setting necessary permissions..."
chmod 777 -R /var/www/glpi/config
chmod 777 -R /var/www/glpi/files
chmod 777 -R /var/www/glpi/marketplace

# Install GLPI database
echo "Installing GLPI database..."
php bin/console db:install \
    --db-host=db \
    --db-port=3306 \
    --db-user=glpi \
    --db-password=glpipass \
    --db-name=glpi \
    --reconfigure \
    --no-interaction

# Database schema check
# echo "Checking database schema integrity..."
# php bin/console db:check_schema_integrity --no-interaction

# Plugins installation
echo "Installing GLPI plugins..."
php bin/console glpi:plugin:install --all --no-interaction
php bin/console glpi:plugin:activate --all --no-interaction

# Rollback permissions
echo "Rolling back permissions..."
chmod 775 -R /var/www/glpi/config
chmod 775 -R /var/www/glpi/files
chmod 775 -R /var/www/glpi/marketplace

echo "GLPI installation complete."

exec "$@"