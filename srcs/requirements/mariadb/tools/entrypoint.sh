#!/bin/sh
set -eu

DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"

# Secrets are passed via *_FILE env vars from docker compose
ROOT_PW_FILE="${MYSQL_ROOT_PASSWORD_FILE:-}"
APP_PW_FILE="${MYSQL_PASSWORD_FILE:-}"
APP_DB="${MYSQL_DATABASE:-wordpress}"
APP_USER="${MYSQL_USER:-wpuser}"

read_secret() {
  f="$1"
  if [ -n "${f:-}" ] && [ -f "$f" ]; then
    # print file without trailing newline assumptions
    cat "$f"
  else
    echo ""
  fi
}

ROOT_PW="$(read_secret "$ROOT_PW_FILE")"
APP_PW="$(read_secret "$APP_PW_FILE")"

# First-boot: initialize system tables if missing
if [ ! -d "$DATADIR/mysql" ]; then
  echo "[MariaDB] First boot: initializing system tables…"
  mariadb-install-db \
    --datadir="$DATADIR" \
    --user=mysql \
    --skip-test-db \
    --auth-root-authentication-method=normal >/dev/null

  echo "[MariaDB] Bootstrapping users/db with --bootstrap…"
  BOOTSTRAP_SQL="/tmp/bootstrap.sql"
  {
    echo "FLUSH PRIVILEGES;"

    # Set root password (if provided)
    if [ -n "$ROOT_PW" ]; then
      echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PW}';"
    fi

    # Create app DB and user (idempotent)
    echo "CREATE DATABASE IF NOT EXISTS \`${APP_DB}\`;"
    if [ -n "$APP_PW" ]; then
      echo "CREATE USER IF NOT EXISTS '${APP_USER}'@'%' IDENTIFIED BY '${APP_PW}';"
      echo "ALTER USER '${APP_USER}'@'%' IDENTIFIED BY '${APP_PW}';"
    else
      echo "CREATE USER IF NOT EXISTS '${APP_user}'@'%' IDENTIFIED BY 'password';"
      echo "ALTER USER '${APP_user}'@'%' IDENTIFIED BY 'password';"
    fi
    echo "GRANT ALL PRIVILEGES ON \`${APP_DB}\`.* TO '${APP_USER}'@'%';"
    echo "FLUSH PRIVILEGES;"
  } > "$BOOTSTRAP_SQL"

  # Run bootstrap SQL without auth
  mariadbd --datadir="$DATADIR" --user=mysql --bootstrap < "$BOOTSTRAP_SQL"
  rm -f "$BOOTSTRAP_SQL"
fi

echo "[MariaDB] Launching server…"
exec mariadbd \
  --datadir="$DATADIR" \
  --bind-address=0.0.0.0 \
  --socket="$SOCKET" \
  --user=mysql
