# ------------------------------------------------------------------------------
# File: srcs/requirements/mariadb/Dockerfile
# Purpose: Build a minimal MariaDB server image for WordPress
#
# Cheat sheet:
# - apk add mariadb mariadb-client   : server + client tools
# - /var/lib/mysql                   : data dir (persist via docker-compose volume)
# - /run/mysqld                      : runtime socket/pid dir
# - /etc/my.cnf                      : our server config (bind, charset, etc.)
# - entrypoint.sh                    : first-boot init then exec mysqld (PID 1)
# - EXPOSE 3306                      : MySQL/MariaDB TCP port
# ------------------------------------------------------------------------------

FROM alpine:3.19

# Server + client (creates mysql user/group)
RUN apk add --no-cache mariadb mariadb-client

# Required dirs + perms
RUN mkdir -p /var/lib/mysql /run/mysqld \
 && chown -R mysql:mysql /var/lib/mysql /run/mysqld

# Basic config (ensure bind-address/charset/etc. in this file)
COPY conf/my.cnf /etc/my.cnf

# Entrypoint script (handles first-boot init then starts mysqld in foreground)
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

# Normalize line endings & strip UTF-8 BOM in case the script was edited on Windows
# strip CRLF
RUN f=/usr/local/bin/entrypoint.sh; \
    sed -i 's/\r$//' "$f"; \
    if [ "$(head -c3 "$f" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; then \
      tail -c +4 "$f" > "$f.nobom" && mv "$f.nobom" "$f"; \
    fi; \
    chmod +x "$f"

EXPOSE 3306

# IMPORTANT: entrypoint.sh should end with:
#   exec mysqld --user=mysql --datadir=/var/lib/mysql --console
# so mysqld runs in the foreground as PID 1 (no hacky loops).
CMD ["/usr/local/bin/entrypoint.sh"]
