#!/bin/bash

source_code_dir="sources"
plugins_dir="$source_code_dir/plugins"

# echo "Cleaning directories..."
# echo "======================="
# rm -rf glpi nginx/glpi php-fpm/glpi

echo "Extracting sources..."
echo "====================="
tar -xvzf $source_code_dir/glpi-*.tgz -C .
unzip $plugins_dir/glpi*.zip -d glpi/plugins/
# rm -rf $source_code_dir/glpi-*.tgz $plugins_dir/glpi*.zip

echo "Copying files..."
cp -a glpi nginx/glpi
cp -a glpi php-fpm/glpi

# echo "Building docker images..."
# echo "========================="
# docker compose up -d --build

echo "Done!"
echo "========================="