#!/bin/sh
set -eu  # -e: exit on error, -u: undefined var is error

# ------------------------------------------------------------------------------
# Purpose: First-boot init (system tables + DB/user) then start MariaDB as PID 1
#
# Notes:
# - No infinite loops, no tail/sleep hacks. Ends with `exec mariadbd …`.
# - Uses Docker secrets (…_FILE envs) for root/app passwords if provided.
# - Idempotent: safe to re-run; only initializes on empty datadir.
# ------------------------------------------------------------------------------

DATADIR="/var/lib/mysql"                 # MariaDB data directory (persisted)
SOCKET="/run/mysqld/mysqld.sock"         # Local socket path

# Secrets are passed via *_FILE env vars from docker-compose
ROOT_PW_FILE="${MYSQL_ROOT_PASSWORD_FILE:-}"  # e.g., /run/secrets/db_root_password
APP_PW_FILE="${MYSQL_PASSWORD_FILE:-}"        # e.g., /run/secrets/db_password
APP_DB="${MYSQL_DATABASE:-wordpress}"         # DB name to create
APP_USER="${MYSQL_USER:-wpuser}"              # DB user to (create|alter)

# Helper: read a secret file if set and exists; otherwise echo empty string
read_secret() {
  f="$1"
  if [ -n "${f:-}" ] && [ -f "$f" ]; then
    cat "$f"
  else
    echo ""
  fi
}

ROOT_PW="$(read_secret "$ROOT_PW_FILE")"
APP_PW="$(read_secret "$APP_PW_FILE")"

# ----------------------------- First boot init ------------------------------
# If the system tables don't exist, initialize the datadir and bootstrap SQL.
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

    # Set root password (only if provided)
    if [ -n "$ROOT_PW" ]; then
      echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PW}';"
    fi

    # Create app database and user (idempotent)
    echo "CREATE DATABASE IF NOT EXISTS \`${APP_DB}\`;"
    if [ -n "$APP_PW" ]; then
      echo "CREATE USER IF NOT EXISTS '${APP_USER}'@'%' IDENTIFIED BY '${APP_PW}';"
      echo "ALTER USER '${APP_USER}'@'%' IDENTIFIED BY '${APP_PW}';"
    else
      # Fallback password only if none provided (dev convenience)
      echo "CREATE USER IF NOT EXISTS '${APP_USER}'@'%' IDENTIFIED BY 'password';"
      echo "ALTER USER '${APP_USER}'@'%' IDENTIFIED BY 'password';"
    fi
    echo "GRANT ALL PRIVILEGES ON \`${APP_DB}\`.* TO '${APP_USER}'@'%';"
    echo "FLUSH PRIVILEGES;"
  } > "$BOOTSTRAP_SQL"

  # Run bootstrap SQL with server in bootstrap mode (no auth)
  mariadbd --datadir="$DATADIR" --user=mysql --bootstrap < "$BOOTSTRAP_SQL"
  rm -f "$BOOTSTRAP_SQL"
fi

# ----------------------------- Launch server -------------------------------
echo "[MariaDB] Launching server…"
exec mariadbd \
  --datadir="$DATADIR" \
  --bind-address=0.0.0.0 \
  --socket="$SOCKET" \
  --user=mysql
# `exec` makes mariadbd PID 1; foreground mode so the container stays up.
