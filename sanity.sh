set -euo pipefail

REQ=( "secrets/db_root_password.txt" "secrets/db_password.txt" "secrets/credentials.txt" "srcs/.env" )
for f in "${REQ[@]}"; do
  [[ -f "$HOME/inception/$f" ]] || { echo "Missing $f"; exit 1; }
done

grep -q '^DOMAIN_NAME=' "$HOME/inception/srcs/.env" || { echo "No DOMAIN_NAME in .env"; exit 1; }
grep -q '^MYSQL_DATABASE=' "$HOME/inception/srcs/.env" || { echo "No MYSQL_DATABASE in .env"; exit 1; }
grep -q '^MYSQL_USER=' "$HOME/inception/srcs/.env" || { echo "No MYSQL_USER in .env"; exit 1; }

LOGIN=${LOGIN:-$USER}
[[ -d "/home/$LOGIN/data/wordpress" ]] || { echo "Missing /home/$LOGIN/data/wordpress"; exit 1; }
[[ -d "/home/$LOGIN/data/mariadb"   ]] || { echo "Missing /home/$LOGIN/data/mariadb"; exit 1; }

echo "Sanity OK ✅"
