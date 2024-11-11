#!/bin/sh

set -e

# Constants
GLPI_SOURCES_DIR='/tmp/sources'
GLPI_PLUGINS_DIR="$GLPI_SOURCES_DIR/plugins"

# Wait for MySQL to be ready
wait_for_mysql() {
    echo "Waiting for MySQL to be ready..."
    while ! nc -z ${GLPI_DB_HOST} ${GLPI_DB_PORT}; do
        sleep 1
    done
    echo "MySQL is ready."
}

# Download GLPI source
download_glpi() {
    GLPI_SOURCE="$GLPI_SOURCES_DIR/glpi-${GLPI_VERSION}.tgz"
    if [ ! -f "$GLPI_SOURCE" ]; then
        echo "Downloading GLPI source..."
        wget -q -P "$GLPI_SOURCES_DIR" \
        "https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz"
        echo "Download GLPI source complete."
    fi
}

# Download GLPI SAML plugin
download_plugin() {
    SAML_PLUGIN="$GLPI_PLUGINS_DIR/glpisaml.zip"
    if [ ! -f "$SAML_PLUGIN" ]; then
        echo "Downloading GLPI SAML plugin..."
        wget -q -P "$GLPI_PLUGINS_DIR" \
        "https://codeberg.org/QuinQuies/glpisaml/releases/download/${GLPI_SAML_VERSION}/glpisaml.zip"
        echo "Download GLPI SAML plugin complete."
    fi
}

# Extract files
extract_files() {
    echo "Extracting GLPI files..."
    tar -xzf "$GLPI_SOURCE" -C "${GLPI_SOURCES_DIR}/glpi" --strip-components=1
    unzip -q "$SAML_PLUGIN" -d "${GLPI_SOURCES_DIR}/glpi/plugins/"
    echo "Extract complete."
}

# Deploy files to web servers
deploy_files() {
    echo "Deploying files..."
    cp -a "${GLPI_SOURCES_DIR}/glpi/." /var/www/glpi/
    echo "Deployment complete."

    echo "Cleaning up..."
    rm -rf "${GLPI_SOURCES_DIR}" "/tmp/*"
    echo "Cleanup complete."
}

setup_glpi_sources() {
    echo "===== Setting up GLPI Sources and Plugins... ====="

    # Create directories if they don't exist
    mkdir -p "${GLPI_SOURCES_DIR}/glpi" "${GLPI_PLUGINS_DIR}"

    echo "------------------------------------------------"
    echo "GLPI version: ${GLPI_VERSION}"
    echo "GLPI SAML version: ${GLPI_SAML_VERSION}"
    echo "------------------------------------------------"

    download_glpi
    echo "------------------------------------------------"
    download_plugin
    echo "------------------------------------------------"
    extract_files
    echo "------------------------------------------------"
    deploy_files
    echo "------------------------------------------------"

    echo "GLPI setup sources complete."
}

setup_glpi_configs() {
    echo "===== Setting up GLPI Configurations... ====="
    # Check system requirements
    echo "===== Checking system requirements... ====="
    php bin/console glpi:system:check_requirements --ansi --no-interaction -vv
    echo "Check system requirements done."

    # Check if GLPI is already installed
    if [ ! -f /var/www/glpi/config/config_db.php ]; then
        # GLPI is not installed, run installation
        echo "===== Installing GLPI database... ====="
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
        echo "===== Checking database schema integrity... ====="
        php bin/console db:check_schema_integrity --ansi --no-interaction -vv
        echo "Check database schema integrity done."
    else
        echo "GLPI is already installed."
        echo "===== Reconfigure GLPI database configuration... ====="
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
    echo "===== Enabling timezones support... ====="
    php bin/console db:enable_timezones --ansi --no-interaction -vv
    echo "Enable timezones support done."

    # Plugins installation
    echo "===== Installing GLPI plugins... ====="
    php bin/console glpi:plugin:install --ansi --all --username="${GLPI_ADMIN_USER}" --force
    php bin/console glpi:plugin:activate --ansi --all
    echo "Install GLPI plugins done."

    # System status
    echo "===== Checking GLPI system status... ====="
    php bin/console config:set --ansi --version
    php bin/console glpi:system:status --ansi --format=json
    echo "Check GLPI system status done."

    # Remove install/ directory
    echo "===== Removing install/ directory... ====="
    if [ -e /var/www/glpi/install ]; then
        rm -rf /var/www/glpi/install
        echo "Removed install/ directory."
    else
        echo "install/ directory does not exist."
    fi

    # Set permissions
    echo "===== Setting permissions... ====="
    chown -R www-data:www-data /var/www/glpi
    chmod 2775 /var/www/glpi
    find /var/www/glpi -type d -exec chmod 2775 {} \;
    find /var/www/glpi -type f -exec chmod 0664 {} \;
    echo "Set permissions done."

    echo "==========================="
    echo "GLPI installation complete."
    echo "==========================="
}

main() {
    # 1. Setup GLPI sources
    if [ -d /var/www/glpi ]; then
        echo "GLPI is already installed."
        if [ -z "$(ls -A /var/www/glpi)" ]; then
            echo "GLPI directory is empty. Installing GLPI..."
            setup_glpi_sources
        else
            echo "GLPI directory is not empty. Skipping GLPI installation."
        fi
    else
        echo "GLPI is not exited."
        exit 1
    fi

    # 2. Wait for MySQL to be ready
    wait_for_mysql
    # 3. Setup GLPI database
    setup_glpi_configs
}

# Call the main function
main

# Execute the main container command
exec "$@"