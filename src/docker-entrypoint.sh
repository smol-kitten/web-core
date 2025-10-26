#!/bin/bash

# Start services
service php8.4-fpm start
service nginx start

# Keep container running, and get logs
tail -f /dev/null /var/log/nginx/access.log /var/log/nginx/error.log
