FROM alpine:3.19

RUN apk add --no-cache nginx openssl

RUN mkdir -p /etc/nginx/ssl /var/www/wordpress /run/nginx

# copy config + cert generator
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY tools/gen-cert.sh /usr/local/bin/gen-cert.sh
RUN chmod +x /usr/local/bin/gen-cert.sh

# build-time arg to embed domain
ARG DOMAIN_NAME=nryser.42.fr
RUN /usr/local/bin/gen-cert.sh "$DOMAIN_NAME"

EXPOSE 443
CMD ["nginx", "-g", "daemon off;"]
