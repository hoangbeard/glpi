FROM glpi-base:latest AS base
# =======================================
# Stage 1: Download GLPI source and plugins
# =======================================
FROM base AS bootstrap

# Switch to root for managed tasks
USER root

# Define an argument for the GLPI version to be used
# Default to latest if not specified
ARG GLPI_VERSION=latest
ARG GLPI_SAML_VERSION=v1.1.10

# Set environment variables
ENV GLPI_VERSION=${GLPI_VERSION}
ENV GLPI_SAML_VERSION=${GLPI_SAML_VERSION}

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        unzip \
        wget \
    ; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR ${APP_SOURCE_PATH}

# Copy scripts files to the working directory
COPY scripts/bootstrap.sh ${APP_SOURCE_PATH}/
COPY config/appconfig/glpi/. ${APP_SOURCE_PATH}/

# Run script to download GLPI source
RUN set -eux; \
    chmod +x ${APP_SOURCE_PATH}/bootstrap.sh; \
    ${APP_SOURCE_PATH}/bootstrap.sh

# =======================================
# Stage 2: Build runtime image
# =======================================
FROM base AS runtime

# Add a label for image metadata about the maintainer of this image
LABEL maintainer="HoangBeard <hoangbeard@hoangbeard.com>"

# Switch to root for managed tasks
USER root

# Install packages needed for HTTPS
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        certbot \
        python3-certbot-nginx \
    ; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    # Clean default configuration
    rm -rf /etc/nginx/conf.d \
    /etc/supervisor/conf.d \
    /etc/php/${PHP_VERSION}/fpm/pool.d

# Set default workdir
WORKDIR ${APP_SOURCE_PATH}

# Copy the nginx, php, supervisor, and appconfig config files to the appropriate directories
COPY config/nginx/. /etc/nginx/
COPY config/php/. /etc/php/${PHP_VERSION}/
COPY config/supervisor/. /etc/supervisor/
COPY config/docker-entrypoint.sh /
COPY scripts/generate-cert.sh /usr/local/bin/

# Copy application files from bootstrap
COPY --from=bootstrap --chown=www-data:www-data --chmod=2775 ${APP_SOURCE_PATH}/glpi/. ${APP_SOURCE_PATH}/

# Run composer install and set correct permissions and remove unnecessary files
RUN set -eux; \
    chmod +x /docker-entrypoint.sh \
    ; \
    chmod +x /usr/local/bin/generate-cert.sh \
    ; \
    DIRS_NEED_GRANTED_PERMISSIONS="/glpi-data/files /glpi-data/log /glpi-data/config /glpi-data/certs" \
    ; \
    mkdir -p ${DIRS_NEED_GRANTED_PERMISSIONS}; \
    cp -r ${APP_SOURCE_PATH}/files/* /glpi-data/files/ \
    ; \
    chown -R www-data:www-data ${DIRS_NEED_GRANTED_PERMISSIONS}; \
    chmod 2775 ${DIRS_NEED_GRANTED_PERMISSIONS}; \
    for dir in ${DIRS_NEED_GRANTED_PERMISSIONS}; do \
        find ${dir} -type d -exec chmod 2775 {} \; ; \
        find ${dir} -type f -exec chmod 0664 {} \; ; \
    done

# Expose ports for Nginx (HTTP and HTTPS)
EXPOSE 80 443

# Switch to the www-data user
USER www-data

# Set the entrypoint for the container to be the docker-entrypoint.sh script
ENTRYPOINT ["/docker-entrypoint.sh"]

# Start supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# Persistent data storage volume and guide ECS to configure volume bind mount points
VOLUME [ "/glpi-data" ]
