FROM php:8.2-fpm

# Add LABEL instructions
LABEL author="HoangBeard - <github.com/hoangbeard>" \
    description="PHP-FPM image for web applications"

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    netcat-openbsd \
    procps \
    libbz2-dev \
    libc-dev \
    libkrb5-dev \
    libldap2-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    libzip-dev \
    libgettextpo-dev \
    zlib1g-dev \
    wget \
    zip && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) gd && \
    docker-php-ext-install bz2 exif opcache intl mysqli pdo pdo_mysql zip phar ldap && \
    pecl install apcu && \
    docker-php-ext-enable apcu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /etc/supervisor/conf.d/* && \
    rm -rf /etc/nginx/conf.d/* && \
    rm -rf /usr/local/etc/php-fpm.d/* && \
    rm -rf /var/www/html/*

# Copy PHP-FPM configuration
COPY config/php.ini /usr/local/etc/php/php.ini
COPY config/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY config/www.conf /usr/local/etc/php-fpm.d/www.conf

COPY --chown=www-data:www-data config/local_define.php /glpi-data/config/local_define.php

# Copy the docker-entrypoint.sh script to the root directory
COPY docker-entrypoint.sh /

# Copy source
WORKDIR /var/www/glpi
COPY --chown=www-data:www-data glpi/ ./

# Set correct permissions and remove unnecessary files
RUN mkdir -p /glpi-data/files /glpi-data/log && \
    chmod 2775 /var/www/glpi /glpi-data && \
    find /var/www/glpi -type d -exec chmod 2775 {} \; && \
    find /var/www/glpi -type f -exec chmod 0664 {} \; && \
    find /glpi-data -type d -exec chmod 2775 {} \; && \
    find /glpi-data -type f -exec chmod 0664 {} \; && \
    chmod +x /docker-entrypoint.sh

# Set the entrypoint for the container to be the docker-entrypoint.sh script
ENTRYPOINT ["/docker-entrypoint.sh"]

# Expose port 9000 for PHP-FPM
EXPOSE 9000

# Set default command to run PHP-FPM in foreground mode
CMD ["php-fpm", "-F"]

# Volume for persistent data storage
VOLUME [ "/var/www/glpi" ]