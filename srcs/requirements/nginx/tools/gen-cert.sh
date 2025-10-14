#!/bin/sh
set -e
CN="${1:-localhost}"
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout /etc/nginx/ssl/key.pem \
  -out /etc/nginx/ssl/cert.pem \
  -subj "/CN=${CN}" >/dev/null 2>&1
