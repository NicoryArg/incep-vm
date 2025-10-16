#!/bin/sh
# -----------------------------------------------------------------------------
# gen-cert.sh — Generate a self-signed TLS certificate/key pair for NGINX
# Usage: ./gen-cert.sh [COMMON_NAME]
# If COMMON_NAME is omitted, defaults to 'localhost'.
#
# Cheat sheet:
# - set -e              : exit immediately on any failure
# - CN="${1:-localhost}": CN = first arg or 'localhost' if none
# - openssl req ...     : makes a new RSA 2048-bit key + self-signed cert (X.509)
# - -nodes              : leave the key unencrypted (no passphrase prompt)
# - -days 3650          : ~10 years validity
# - -subj "/CN=$CN"     : set certificate subject Common Name
# - outputs             : /etc/nginx/ssl/key.pem (private key)
#                         /etc/nginx/ssl/cert.pem (certificate)
# - >/dev/null 2>&1     : suppress command noise
# -----------------------------------------------------------------------------
set -e

# read optional CN from argv, default to 'localhost'
CN="${1:-localhost}"

# create key and cert where nginx.conf expects them
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout /etc/nginx/ssl/key.pem \
  -out /etc/nginx/ssl/cert.pem \
  -subj "/CN=${CN}" >/dev/null 2>&1
