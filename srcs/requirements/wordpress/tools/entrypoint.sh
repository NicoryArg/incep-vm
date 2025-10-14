#!/bin/sh
set -e

# -------------------------------
# WordPress container entrypoint
# -------------------------------
WP_PATH="/var/www/wordpress"

# DB coords (from env with defaults)
DB_HOST="${WORDPRESS_DB_HOST:-mariadb:3306}"
DB_NAME="${WORDPRESS_DB_NAME:-wordpress}"
DB_USER="${WORDPRESS_DB_USER:-wpuser}"
DB_PASS_FILE="${WORDPRESS_DB_PASSWORD_FILE:-/run/secrets/db_password}"

# Install behavior (0 = skip core install → browser wizard for admin only)
WP_AUTO_INSTALL="${WP_AUTO_INSTALL:-1}"

# Admin creds for auto install
ADMIN_PASS_FILE="/run/secrets/wp_admin_pass"
ADMIN_USER="${WP_ADMIN_USER:-wpadmin42}"
ADMIN_EMAIL="${WP_ADMIN_EMAIL:-admin@example.com}"
SITE_URL="https://${DOMAIN_NAME:-localhost}"

# --- base dir & ownership (php-fpm runs as nobody:nogroup)
install -d -m 755 "$WP_PATH"
chown -R nobody:nogroup "$WP_PATH" 2>/dev/null || true

# --- always ensure WordPress core exists (tarball = robust on Alpine)
if [ ! -f "$WP_PATH/index.php" ]; then
  echo "[WP] Fetching WordPress core (tarball)…"
  apk add --no-cache wget tar >/dev/null 2>&1 || true
  wget -qO /tmp/wordpress.tgz https://wordpress.org/latest.tar.gz
  tar -xzf /tmp/wordpress.tgz -C /tmp
  cp -a /tmp/wordpress/. "$WP_PATH"/
  chown -R nobody:nogroup "$WP_PATH"
fi

# --- uploads dir & safe perms (for media uploads)
install -d -m 775 "$WP_PATH/wp-content/uploads" || true
chown -R nobody:nogroup "$WP_PATH/wp-content" 2>/dev/null || true
find "$WP_PATH/wp-content" -type d -exec chmod 775 {} \; 2>/dev/null || true
find "$WP_PATH/wp-content" -type f -exec chmod 664 {} \; 2>/dev/null || true

# --- ensure wp-cli available (needs php82-phar on Alpine)
if ! php -m 2>/dev/null | grep -qi 'phar'; then
  apk add --no-cache php82-phar >/dev/null 2>&1 || true
fi
if ! command -v wp >/dev/null 2>&1; then
	if ! command -v curl >/dev/null 2>&1; then
		apk add --no-cache curl >/dev/null 2>&1 || true
	fi
  curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    -o /usr/local/bin/wp || true
  chmod +x /usr/local/bin/wp || true
fi

# --- ALWAYS create wp-config.php when missing so the browser wizard never asks DB
if [ -f "$DB_PASS_FILE" ] && [ ! -f "$WP_PATH/wp-config.php" ] && command -v wp >/dev/null 2>&1; then
  DB_PASS="$(cat "$DB_PASS_FILE")"
  echo "[WP] Creating wp-config.php…"
  wp config create \
    --path="$WP_PATH" \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASS" \
    --dbhost="$DB_HOST" \
    --skip-check \
    --allow-root || echo "[WP] wp-config create failed (will still start php-fpm)…"

  # helpful constants
  wp config set FS_METHOD          direct --type=constant --allow-root --path="$WP_PATH" || true
  wp config set DISALLOW_FILE_EDIT true   --type=constant --raw   --allow-root --path="$WP_PATH" || true
  wp config set FORCE_SSL_ADMIN    true   --type=constant --raw   --allow-root --path="$WP_PATH" || true
fi

# --- optional auto core install
if [ "$WP_AUTO_INSTALL" != "0" ]; then
  if command -v wp >/dev/null 2>&1 && ! wp core is-installed --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
    ADMIN_PASS=""
    [ -f "$ADMIN_PASS_FILE" ] && ADMIN_PASS="$(cat "$ADMIN_PASS_FILE")"
    echo "[WP] Running wp core install…"
    wp core install \
      --path="$WP_PATH" \
      --url="$SITE_URL" \
      --title="Inception" \
      --admin_user="$ADMIN_USER" \
      --admin_password="$ADMIN_PASS" \
      --admin_email="$ADMIN_EMAIL" \
      --skip-email \
      --allow-root || echo "[WP] core install failed (php-fpm will still start)…"
  fi
else
  echo "[WP] Pristine mode: skipping core install (browser wizard will ask only for admin)."
fi

# --- Create required second (non-admin) user (idempotent) ---
SECOND_USER="${WP_SECOND_USER:-writer42}"
SECOND_EMAIL="${WP_SECOND_EMAIL:-writer42@example.com}"

# Optional: get password from secret file if provided
SECOND_PASS=""
if [ -n "${WP_SECOND_PASSWORD_FILE:-}" ] && [ -f "$WP_SECOND_PASSWORD_FILE" ]; then
  SECOND_PASS="$(cat "$WP_SECOND_PASSWORD_FILE")"
fi

if wp core is-installed --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
  if ! wp user get "$SECOND_USER" --field=ID --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
    echo "[WP] Creating second WordPress user: $SECOND_USER"
    if [ -n "$SECOND_PASS" ]; then
      wp user create "$SECOND_USER" "$SECOND_EMAIL" --role=editor --user_pass="$SECOND_PASS" \
        --allow-root --path="$WP_PATH" || true
    else
      wp user create "$SECOND_USER" "$SECOND_EMAIL" --role=editor \
        --allow-root --path="$WP_PATH" || true
    fi
  else
    echo "[WP] Second user already exists: $SECOND_USER"
  fi
fi


echo "[WP] Starting php-fpm82…"
exec php-fpm82 -F
