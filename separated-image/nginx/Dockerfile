FROM nginx:stable

# Add LABEL instructions
LABEL author="HoangBeard - <github.com/hoangbeard>" \
    description="Nginx image for web applications"

# Install the other dependencies
RUN apt-get update && apt-get install -y \
    procps \
    nano && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    rm -rf /etc/nginx/conf.d/* \
    rm -rf /usr/share/nginx/html/*

# Copy Nginx configuration
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx_web.conf /etc/nginx/conf.d/default.conf

# Copy the docker-entrypoint.sh script to the root directory
COPY docker-entrypoint.sh /

# Copy source
COPY --chown=nginx:nginx glpi/public /var/www/glpi/public

# Set correct permissions and remove unnecessary files
RUN chmod 2775 /var/www/glpi/public && \
    find /var/www/glpi/public -type d -exec chmod 2775 {} \; && \
    find /var/www/glpi/public -type f -exec chmod 0664 {} \; && \
    chmod +x /docker-entrypoint.sh 
    # && \
    # mkdir -p /var/cache/nginx && \
    # chown -R nginx:nginx /var/cache/nginx && \
    # chmod -R 755 /var/cache/nginx

# Set default workdir and expose port 80 for HTTP
WORKDIR /var/www/glpi/public
EXPOSE 80

# Switch to the www-data user
# USER nginx

# Set the entrypoint for the container to be the docker-entrypoint.sh script
ENTRYPOINT ["/docker-entrypoint.sh"]

# Set default command to run Nginx in foreground mode
CMD ["nginx", "-g", "daemon off;"]

# Volume for persistent data storage
# VOLUME [ "/glpi-data" ]