FROM alpine:3.19

# PHP 8.2 + FPM + common extensions for WP
RUN apk add --no-cache \
    php82 php82-fpm php82-mysqli php82-json php82-opcache php82-curl php82-dom \
    php82-exif php82-fileinfo php82-mbstring php82-xml php82-zip php82-gd php82-openssl \
    curl tar wget

# Create php alias for convenience
RUN ln -sf /usr/bin/php82 /usr/bin/php

# Pool config
COPY conf/php-fpm.conf /etc/php82/php-fpm.d/www.conf

# Entrypoint
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/wordpress
EXPOSE 9000
CMD ["/usr/local/bin/entrypoint.sh"]
