FROM php:8.2-fpm

# Add LABEL instructions
LABEL author="HoangBeard - <github.com/hoangbeard>" \
    description="PHP-FPM image for web applications"

# Install Nginx and other dependencies
RUN apt-get update && apt-get install -y \
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

# Copy source
WORKDIR /var/www/glpi
COPY --chown=www-data:www-data glpi/ ./

# Install Composer and set correct permissions and remove unnecessary files
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    composer --ansi --version --no-interaction && \
    # composer install --ansi --no-scripts --no-interaction && \
    chmod 2775 /var/www/glpi && \
    find /var/www/glpi -type d -exec chmod 2775 {} \; && \
    find /var/www/glpi -type f -exec chmod 0664 {} \;

# Expose port 9000 for PHP-FPM
EXPOSE 9000

# Start php-fpm
CMD ["php-fpm", "-F"]