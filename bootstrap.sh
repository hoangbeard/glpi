#!/bin/bash


# Define directories
source_code_dir="sources"
plugins_dir="$source_code_dir/plugins"

# Load GLPI_VERSION from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    mv .env.sample .env
    export $(grep -v '^#' .env | xargs)
fi

# Check if the GLPI source file exists, if not download it
if [ ! -f "$source_code_dir/glpi-${GLPI_VERSION}.tgz" ]; then
    echo "Downloading GLPI source..."
    mkdir -p $source_code_dir
    wget -P "$source_code_dir" "https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz"
fi

# Check if the GLPI SAML plugin file exists, if not download it
if [ ! -f "$plugins_dir/glpisaml.zip" ]; then
    echo "Downloading GLPI SAML plugin..."
    mkdir -p $plugins_dir
    wget -P "$plugins_dir" "https://codeberg.org/QuinQuies/glpisaml/releases/download/${GLPI_SAML_VERSION}/glpisaml.zip"
fi

# Extract the GLPI source code
echo "Extracting sources..."
echo "====================="
mkdir -p glpi
tar -xvzf $source_code_dir/glpi-${GLPI_VERSION}.tgz -C glpi --strip-components=1

# Extract the GLPI SAML plugin
unzip $plugins_dir/glpisaml.zip -d glpi/plugins/
# rm -rf $source_code_dir/glpisaml.tgz $plugins_dir/glpi*.zip

# Copy the GLPI source and GLPI SAML plugin to the nginx and php-fpm directories
echo "Copying files..."
rm -rf nginx/glpi php-fpm/glpi
cp -a glpi nginx/glpi
cp -a glpi php-fpm/glpi

# Run docker compose
echo "Building docker images..."
echo "========================="
docker compose up -d --build
docker compose ps

echo "Done!"
echo "========================="
