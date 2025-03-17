#!/bin/bash

set -e

GLPI_VERSION=${GLPI_VERSION}
GLPI_SAML_VERSION=${GLPI_SAML_VERSION}

# Download sources
download_glpi() {
    echo "----- Downloading GLPI source -----"
    
    # Handle "latest" keyword in GLPI_VERSION
    if [ "${GLPI_VERSION}" = "latest" ]; then
        GLPI_VERSION=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep tag_name | cut -d '"' -f 4)
    else
        echo "GLPI Version: ${GLPI_VERSION}"
    fi

    GLPI_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/tags/${GLPI_VERSION} | grep browser_download_url | cut -d '"' -f 4)
    echo "GLPI Download URL: ${GLPI_DOWNLOAD_URL}"

    if [ ! -f "glpi-${GLPI_VERSION}.tgz" ]; then
        wget -q -P . ${GLPI_DOWNLOAD_URL}
    fi
    echo "Download GLPI source done."
}

download_glpi_saml_plugin() {
    echo "----- Downloading GLPI SAML plugin -----"
    if [ -z ${GLPI_SAML_VERSION} ]; then
        GLPI_SAML_VERSION=v1.1.10
    fi

    GLPI_SAML_DOWNLOAD_URL="https://codeberg.org/QuinQuies/glpisaml/releases/download/${GLPI_SAML_VERSION}/glpisaml.zip"
    echo "GLPI SAML Download URL: ${GLPI_SAML_DOWNLOAD_URL}"

    if [ ! -f glpisaml.zip ]; then
        wget -q -P . ${GLPI_SAML_DOWNLOAD_URL}
    fi
    echo "Download GLPI SAML plugin done."
}

deploy_glpi() {
    echo "----- Extracting files -----"
    mkdir -p glpi
    tar -xzf "glpi-${GLPI_VERSION}.tgz" -C glpi --strip-components=1
    unzip -q glpisaml.zip -d glpi/plugins/
    echo "Extract files done."

    echo "----- Copying files -----"
    cp inc/downstream.php glpi/inc/
    cp config/local_define.php glpi/config/
    echo "Copy files done."
}

download_glpi
download_glpi_saml_plugin
deploy_glpi
echo "----- Bootstrap complete -----"
