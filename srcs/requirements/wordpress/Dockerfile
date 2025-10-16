# ------------------------------------------------------------------------------
# Purpose: Build the WordPress PHP-FPM container (listens on :9000)
#
# Cheat sheet:
# - Base: Alpine 3.19 (small & fast)
# - apk add php82*            : PHP 8.2 runtime + FPM + common WP extensions
# - ln -sf php82 -> php       : lets scripts call `php` instead of `php82`
# - php-fpm.conf              : you provide a custom pool config
# - entrypoint.sh             : your bootstrapper; must end with `exec php-fpm82 -F`
# - WORKDIR /var/www/wordpress: WordPress docroot shared with NGINX
# - EXPOSE 9000               : FastCGI port
# - CMD entrypoint.sh         : kicks off setup, then starts php-fpm in foreground
# ------------------------------------------------------------------------------

	# tiny, secure base image
FROM alpine:3.19

# ------------------------------------------------------------------------------
# PHP 8.2 runtime + FPM + the extensions WordPress commonly needs
# - php82-fpm        : FastCGI Process Manager (the PHP server nginx talks to)
# - mysqli, json, curl, dom, exif, fileinfo, mbstring, xml, zip, gd, openssl
# - curl/tar/wget    : used by entrypoint to download/extract WordPress or plugins
# ------------------------------------------------------------------------------
RUN apk add --no-cache \
    php82 php82-fpm php82-mysqli php82-json php82-opcache php82-curl php82-dom \
    php82-exif php82-fileinfo php82-mbstring php82-xml php82-zip php82-gd php82-openssl \
    curl tar wget

# ------------------------------------------------------------------------------
# Convenience: `php` alias points to PHP 8.2 binary (so scripts can call `php`)
# ------------------------------------------------------------------------------
RUN ln -sf /usr/bin/php82 /usr/bin/php

# ------------------------------------------------------------------------------
# PHP-FPM pool configuration
# You ship a custom pool file at conf/php-fpm.conf; it is copied over the default
# location for Alpine's PHP 8.2 pool config. Typical things defined there:
#   - listen = 0.0.0.0:9000        (TCP for Docker cross-container)
#   - user/group = www-data or nobody
#   - clear_env = no               (allow env vars from Docker to reach PHP)
# ------------------------------------------------------------------------------
COPY conf/php-fpm.conf /etc/php82/php-fpm.d/www.conf

# ------------------------------------------------------------------------------
# Entrypoint script
# This script should:
#   - (optionally) wait for MariaDB to be ready
#   - place WordPress files in /var/www/wordpress if missing
#   - generate wp-config.php from env vars (DB host/name/user/pass)
#   - finally exec php-fpm82 -F  (foreground) so the container stays alive
# ------------------------------------------------------------------------------
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ------------------------------------------------------------------------------
# Runtime layout
# ------------------------------------------------------------------------------
	# WordPress docroot
WORKDIR /var/www/wordpress
	# PHP-FPM port
EXPOSE 9000

# Run your bootstrapper; it should create/configure WP then `exec php-fpm82 -F`
CMD ["/usr/local/bin/entrypoint.sh"]
