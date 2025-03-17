FROM debian:stable-slim

LABEL maintainer="HoangBeard <hoangbeard@hoangbeard.com>"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV APP_SOURCE_PATH=/var/www/html
ENV APP_LOG_PATH=/var/www/logs

# Install necessary dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        apt-utils \
        ca-certificates \
        curl \
        debian-archive-keyring \
        dnsutils \
        inetutils-ping \
        inetutils-telnet \
        lsb-release \
        lsof \
        net-tools \
        openssh-client \
        openssl \
        procps \
        supervisor \
    ; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Install Nginx
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        gnupg2 \
        libcap2-bin \
    ; \
    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | \
    tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null \
    ; \
    gpg --dry-run --quiet --no-keyring --import \
        --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg \
    ; \
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    http://nginx.org/packages/debian `lsb_release -cs` nginx" | \
    tee /etc/apt/sources.list.d/nginx.list \
    ; \
    printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | \
    tee /etc/apt/preferences.d/99nginx \
    ; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        nginx \
    ; \
    setcap 'cap_net_bind_service=+ep' $(which nginx); \
    apt-get remove --purge --auto-remove -y gnupg2; \
    rm -rf /var/lib/apt/lists/* \
        /etc/nginx/sites-enabled \
        /etc/nginx/sites-available \
        ${APP_SOURCE_PATH}/*

# Install PHP
ADD --chmod=644 https://packages.sury.org/php/apt.gpg /etc/apt/trusted.gpg.d/php.gpg

ENV PHP_VERSION=8.3
ENV DEBCONF_NOWARNINGS="yes"

RUN set -eux; \
    echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections \
    ; \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | \
    tee /etc/apt/sources.list.d/php.list \
    ; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-mcrypt \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-readline \
        php${PHP_VERSION}-redis \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip \
    ; \
    curl -sS https://getcomposer.org/installer | \
        php -- \
        --install-dir=/usr/local/bin \
        --filename=composer \
    ; \
    cp $(which php-fpm${PHP_VERSION}) /usr/sbin/php-fpm \
    ; \
    rm -rf /var/lib/apt/lists/* \
        /etc/apache2 \
    ; \
    mkdir -p ${APP_SOURCE_PATH}; \
    echo "<?php phpinfo(); ?>" > ${APP_SOURCE_PATH}/index.php

# Copy configuration files
COPY config/nginx/. /etc/nginx/
COPY config/php/. /etc/php/${PHP_VERSION}/
COPY config/supervisor/. /etc/supervisor/
COPY config/docker-entrypoint.sh /

# Set correct permissions and remove unnecessary files
RUN set -eux; \
    chmod +x /docker-entrypoint.sh \
    ; \
    DIRS_NEED_GRANTED_PERMISSIONS="${APP_SOURCE_PATH} ${APP_LOG_PATH} /var/lib/nginx /var/cache/nginx /var/log/nginx /var/log/php-fpm" \
    ; \
    mkdir -p ${DIRS_NEED_GRANTED_PERMISSIONS} \
    ; \
    chown -R www-data:www-data ${DIRS_NEED_GRANTED_PERMISSIONS}; \
    chmod 2775 ${DIRS_NEED_GRANTED_PERMISSIONS}; \
    for dir in ${DIRS_NEED_GRANTED_PERMISSIONS}; do \
        find ${dir} -type d -exec chmod 2775 {} \; ; \
        find ${dir} -type f -exec chmod 0664 {} \; ; \
    done

# Set default workdir
WORKDIR ${APP_SOURCE_PATH}

# Expose port 80 for Nginx
EXPOSE 80

# Switch to the www-data user
USER www-data

# Set the entrypoint for the container to be the docker-entrypoint.sh script
ENTRYPOINT ["/docker-entrypoint.sh"]

# Start supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# Persistent data storage volume and guide ECS to configure volume bind mount points
VOLUME [ "/var/www/logs" ]