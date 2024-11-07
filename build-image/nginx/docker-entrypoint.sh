#!/bin/sh

set -e

# Default value for FASTCGI_PASS
FASTCGI_PASS=${FASTCGI_PASS:-php:9000}

# Replace the placeholder in the nginx configuration
sed -i "s/\${FASTCGI_PASS}/$FASTCGI_PASS/g" /etc/nginx/conf.d/default.conf

# Execute the main container command
exec "$@"
