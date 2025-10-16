# -----------------------------------------------------------------------------
# NGINX Dockerfile — serves WordPress via HTTPS (TLS 1.2/1.3)
# Base: Alpine 3.19 (tiny, fast)
# Cheat sheet:
# - apk add nginx openssl        : web server + tool to make self-signed certs
# - /etc/nginx/ssl               : where cert.pem/key.pem live
# - conf/nginx.conf              : main nginx config (copied below)
# - tools/gen-cert.sh            : script to generate certs at build time
# - ARG DOMAIN_NAME              : lets you embed CN into the self-signed cert
# - EXPOSE 443                   : only HTTPS is exposed
# - CMD nginx -g 'daemon off;'   : run in foreground inside container
# -----------------------------------------------------------------------------
FROM alpine:3.19

# 1) install nginx + openssl (for local self-signed certs)
RUN apk add --no-cache nginx openssl

# 2) create expected directories (nginx fails if missing)
RUN mkdir -p /etc/nginx/ssl /var/www/wordpress /run/nginx

# 3) copy nginx config + certificate generator
# main nginx config
COPY conf/nginx.conf /etc/nginx/nginx.conf

# small helper to make certs
COPY tools/gen-cert.sh /usr/local/bin/gen-cert.sh
RUN chmod +x /usr/local/bin/gen-cert.sh

# 4) optional build-time domain to put in the CN of the cert (default shown)
ARG DOMAIN_NAME=nryser.42.fr
RUN /usr/local/bin/gen-cert.sh "$DOMAIN_NAME"

# 5) only HTTPS is exposed (HTTP is disabled in nginx.conf)
EXPOSE 443

# 6) run nginx in foreground so the container keeps running
CMD ["nginx", "-g", "daemon off;"]
