#!/bin/sh

set -e

# ========== Collect the System Information ========== 

echo "{\
\"os\":\"$(cat /etc/os-release | grep PRETTY_NAME | cut -d '=' -f 2 | tr -d '"')\", \
\"kernel\":\"$(uname -r)\", \
\"cpu\":\"$(lscpu | grep 'Model name' | cut -d ':' -f 2 | xargs)\", \
\"memory\":\"$(free -h | grep Mem | awk '{print $2}')\", \
\"disk\":\"$(df -h / | tail -1 | awk '{print $2}')\", \
\"user\":\"$(whoami)\",\"architecture\":\"$(uname -m)\", \
\"hostname\":\"$(hostname)\", \
\"uptime\":\"$(uptime -p | sed 's/up //')\", \
\"ip_address\":\"$(hostname -I | awk '{print $1}')\", \
\"supervisor_version\":\"$(supervisord -v)\", \
\"nginx_version\":\"$(nginx -v 2>&1 | awk -F'/' '{print $2}')\", \
\"php_version\":\"$(php -v | head -1 | awk '{print $2}')\", \
\"php_fpm_version\":\"$(php-fpm -v | head -1 | awk '{print $2}')\", \
\"composer_version\":\"$(composer -V 2>&1 | head -1 | awk '{print $3}') \
\"}"

# ========== End of collect system info ========== 

# set -x  # Enable command tracing for this section
# Add commands to execute when container starts at here
# ========== START HERE ========== 



# ========== END HERE ==========
# set +x  # Disable command tracing after this section

# Execute the main container command
exec "$@"
