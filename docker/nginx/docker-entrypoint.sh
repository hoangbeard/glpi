#!/bin/bash

set -e

echo "----- System Information -----"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d '=' -f 2)"
echo "Kernel: $(uname -r)"
echo "CPU: $(lscpu | grep 'Model name' | cut -d ':' -f 2 | xargs)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $2}')"
echo "User: $(whoami)"
echo "Architecture: $(uname -m)"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
hostname -I | awk '{print "IP Address: " $1}'
echo "------------------------------"

# Default value for FASTCGI_PASS
FASTCGI_PASS=${FASTCGI_PASS:-php:9000}

# Replace the placeholder in the nginx configuration
sed -i "s/\${FASTCGI_PASS}/$FASTCGI_PASS/g" /etc/nginx/conf.d/default.conf

# Execute the main container command
exec "$@"
