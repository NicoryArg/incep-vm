FROM alpine:3.19

# Server + client (creates mysql user/group)
RUN apk add --no-cache mariadb mariadb-client

# Required dirs + perms
RUN mkdir -p /var/lib/mysql /run/mysqld \
 && chown -R mysql:mysql /var/lib/mysql /run/mysqld

# Basic config
COPY conf/my.cnf /etc/my.cnf

# Entrypoint script (handles first-boot init)
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
# ---- normalize inside the image: strip CRLF and UTF-8 BOM, then chmod +x
RUN f=/usr/local/bin/entrypoint.sh; \
    # strip CRLF
    sed -i 's/\r$//' "$f"; \
    # strip BOM if present (BusyBox-friendly)
    if [ "$(head -c3 "$f" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; then \
      tail -c +4 "$f" > "$f.nobom" && mv "$f.nobom" "$f"; \
    fi; \
    chmod +x "$f"

EXPOSE 3306

CMD ["/usr/local/bin/entrypoint.sh"]
