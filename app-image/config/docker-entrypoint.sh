#!/bin/bash

set -e

# Set default values for environment variables if not provided
GLPI_HTTPS_MODE=${GLPI_HTTPS_MODE:-self-signed}
GLPI_DOMAIN=${GLPI_DOMAIN:-localhost}
GLPI_EMAIL=${GLPI_EMAIL:-admin@example.com}

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

# Verify certificates exist before starting Nginx
echo "Verifying SSL certificates"
if [ ! -f "/glpi-data/certs/domain/server.crt" ] || [ ! -f "/glpi-data/certs/domain/server.key" ]; then
    echo "SSL certificates not found at /glpi-data/certs/domain/"
    
    if [ "$GLPI_HTTPS_MODE" = "self-signed" ]; then
        echo "Generating self-signed certificates for domain: ${GLPI_DOMAIN}"

        export CERT_DIR="/glpi-data/certs"
        export DOMAIN="${GLPI_DOMAIN}"

        mkdir -p ${CERT_DIR}/domain

        /usr/local/bin/generate-cert.sh

        echo "Self-signed certificates generated successfully."
    
    elif [ "$GLPI_HTTPS_MODE" = "letsencrypt" ]; then
        echo "Setting up Let's Encrypt certificates for domain: ${GLPI_DOMAIN}"

        if [ -f "/etc/letsencrypt/live/${GLPI_DOMAIN}/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/${GLPI_DOMAIN}/privkey.pem" ]; then
            echo "Let's Encrypt certificates already exist."
        else
            echo "Obtaining Let's Encrypt certificates..."
            
            # Create webroot directory for ACME challenge
            mkdir -p ${APP_SOURCE_PATH}/public/.well-known/acme-challenge
            
            # Obtain certificates using certbot
            certbot certonly --webroot \
                --webroot-path=${APP_SOURCE_PATH}/public \
                --email=${GLPI_EMAIL} \
                --agree-tos \
                --no-eff-email \
                --domain=${GLPI_DOMAIN}
                
            echo "Let's Encrypt certificates obtained successfully."
        fi
        
        # Create symbolic links to Let's Encrypt certificates
        mkdir -p /glpi-data/certs/domain
        ln -sf /etc/letsencrypt/live/${GLPI_DOMAIN}/fullchain.pem /glpi-data/certs/domain/server.crt
        ln -sf /etc/letsencrypt/live/${GLPI_DOMAIN}/privkey.pem /glpi-data/certs/domain/server.key
        
        # Set up automatic renewal
        # echo "0 0,12 * * * root certbot renew --quiet" > /etc/cron.d/certbot-renew
        
        echo "Let's Encrypt certificates setup completed."
    else
        echo "Invalid HTTPS mode: ${GLPI_HTTPS_MODE}. Using self-signed certificates as fallback."

        export CERT_DIR="/glpi-data/certs"
        export DOMAIN="${GLPI_DOMAIN}"

        mkdir -p ${CERT_DIR}/domain

        /usr/local/bin/generate-cert.sh
        
        echo "Self-signed certificates generated successfully."
    fi
else
    echo "SSL certificates found at /glpi-data/certs/domain/"
    ls -la /glpi-data/certs/domain/
fi

# Wait for MySQL to be ready
echo "Checking database connection"
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
echo "Checking system requirements"
php bin/console glpi:system:check_requirements --no-interaction --quiet

# Check if GLPI is already installed
if [ ! -f /glpi-data/config/config_db.php ]; then
    # GLPI is not installed, run installation
    echo "Installing GLPI database"
    php bin/console db:install --quiet \
    --db-host="${GLPI_DB_HOST}" \
    --db-port="${GLPI_DB_PORT}" \
    --db-name="${GLPI_DB_DATABASE}" \
    --db-user="${GLPI_DB_USER}" \
    --db-password="${GLPI_DB_PASSWORD}" \
    --no-interaction \
    --force
    
    # Check database schema integrity
    echo "Checking database schema integrity"
    php bin/console db:check_schema_integrity --no-interaction --quiet
    
    # Access to timezone database
    echo "Enabling timezones support"
    php bin/console db:enable_timezones --no-interaction --quiet
else
    # Reconfigure GLPI database configuration
    echo "GLPI is already installed. Re-configuring database configuration"
    php bin/console db:configure --quiet \
    --db-host="${GLPI_DB_HOST}" \
    --db-port="${GLPI_DB_PORT}" \
    --db-name="${GLPI_DB_DATABASE}" \
    --db-user="${GLPI_DB_USER}" \
    --db-password="${GLPI_DB_PASSWORD}" \
    --no-interaction \
    --reconfigure

    # Update DB
    echo "Updating database"
    php bin/console db:update --quiet

    # Check database schema integrity
    echo "Checking database schema integrity"
    php bin/console db:check_schema_integrity --no-interaction --quiet
fi

# Plugins installation
echo "Installing GLPI plugins"
php bin/console glpi:plugin:install --all --username="${GLPI_ADMIN_USER}" --force
php bin/console glpi:plugin:activate --all

# Remove install/ directory
echo "Removing Install directory"
if [ -e ${APP_SOURCE_PATH}/install ]; then
    rm -rf ${APP_SOURCE_PATH}/install
fi

# System status
echo "Checking GLPI system status"
php bin/console config:set --version
php bin/console glpi:system:status --format=json

echo "GLPI is ready to start"

# Start supervisord
exec "$@"
