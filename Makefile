# ==============================
# Inception Makefile (staged up)
# ==============================
SHELL := /bin/bash

# ---- project paths ----
LOGIN        ?= nryser
PROJECT      := srcs
COMPOSE_FILE := $(PROJECT)/docker-compose.yml
ENV_FILE     := $(PROJECT)/.env

# host bind-dirs
DB_DIR := /home/$(LOGIN)/data/mariadb
WP_DIR := /home/$(LOGIN)/data/wordpress

# colors (for normal prints, not inside read -p)
BOLD := \033[1m
DIM  := \033[2m
RED  := \033[31m
GRN  := \033[32m
YLW  := \033[33m
BLU  := \033[36m
PRP  := \033[95m
RST  := \033[0m

define PRINT_HEADER
	@printf "$(BOLD)Inception Makefile$(RST) – $(DIM)common tasks$(RST)\n"
	@printf "  $(BLU)make up$(RST)               : Build (if needed), staged start (DB→WP→NGINX)\n"
	@printf "  $(BLU)make build$(RST)            : Build images only\n"
	@printf "  $(BLU)make down$(RST)             : Stop and remove containers (keeps bind-dirs)\n"
	@printf "  $(BLU)make restart$(RST)          : Restart all services (staged)\n"
	@printf "  $(BLU)make logs$(RST)             : Follow logs for all services $(DIM)(Ctrl-C to exit)$(RST)\n"
	@printf "  $(BLU)make ps$(RST)               : Show container status\n"
	@printf "  $(BLU)make sh-db$(RST)            : Shell into MariaDB container\n"
	@printf "  $(BLU)make sh-wp$(RST)            : Shell into WordPress container\n"
	@printf "  $(BLU)make sh-nginx$(RST)         : Shell into NGINX container\n"
	@printf "  $(BLU)make cert-re$(RST)          : Rebuild NGINX and recreate nginx\n"
	@printf "  $(BLU)make env$(RST)              : Show resolved compose config (debug)\n"
	@printf "  $(YLW)make wp-reset$(RST)         : $(RED)NUKE WP bind-dir$(RST) and staged up again (DB-safe)\n"
	@printf "  $(YLW)make db-reset$(RST)         : $(RED)NUKE DB bind-dir$(RST) and staged up again (content lost)\n"
	@printf "  $(YLW)make re$(RST)               : $(RED)FULL NUKE$(RST) both bind-dirs + rebuild + staged up\n"
	@printf "  $(YLW)make pristine$(RST)         : $(RED)ABSOLUTE NUKE$(RST) (dirs + named volumes + images) + staged up\n"
	@printf "  $(PRP)make wp-purge-sample$(RST)  : Remove default sample post/page safely (optional)\n"
	@printf "  $(PRP)make test$(RST)             : Infra smoke tests (TLS, routing, PHP-FPM, DB, WP)\n"
	@printf "  $(PRP)make verify-reset$(RST)     : Show on-disk bind-dirs and quick DB/files state\n"
endef

.PHONY: help
help:
	$(PRINT_HEADER)

# ---------- helpers ----------
define normalize_scripts
	@find $(PROJECT)/requirements -type f -name "*.sh" -exec sed -i 's/\r$$//' {} \;
	@find $(PROJECT)/requirements -type f -name "*.sh" -exec chmod +x {} \;
	@printf "✔ Scripts normalized (LF) and executable\n"
endef

define ensure_files
	@[ -f $(COMPOSE_FILE) ] || { printf "$(RED)✖ Missing $(COMPOSE_FILE)$(RST)\n"; exit 1; }
	@[ -f $(ENV_FILE) ]     || { printf "$(RED)✖ Missing $(ENV_FILE)$(RST)\n"; exit 1; }
	@[ -f secrets/db_root_password.txt ] || { printf "$(RED)✖ Missing secrets/db_root_password.txt$(RST)\n"; exit 1; }
	@[ -f secrets/db_password.txt ]      || { printf "$(RED)✖ Missing secrets/db_password.txt$(RST)\n"; exit 1; }
	@[ -f secrets/credentials.txt ]      || { printf "$(RED)✖ Missing secrets/credentials.txt$(RST)\n"; exit 1; }
	@printf "✔ Files present (compose, env, secrets)\n"
endef

define ensure_dirs
	@install -d -m 755 $(WP_DIR)
	@install -d -m 755 $(DB_DIR)
	@printf "✔ Data dirs ensured: $(WP_DIR)  $(DB_DIR)\n"
endef

# A confirm snippet that exits 0 on "yes" and 1 otherwise (NO colors here)
# Use it with: @bash -lc '$(call _CONFIRM,Message)' && { ... } || true
define _CONFIRM
read -r -p "⚠️  $(1) Type y to continue: " ans; case "$$ans" in y|Y|yes|YES) exit 0;; *) echo "Aborted."; exit 1;; esac
endef

# Wait for service to be healthy (up to ~240s)
# Usage: $(call WAIT_HEALTHY,container_name)
define WAIT_HEALTHY
	@bash -lc 'name="$(1)"; \
	  echo "… waiting for $$name to be healthy"; \
	  for i in {1..240}; do \
	    st=$$(docker inspect -f "{{.State.Health.Status}}" "$$name" 2>/dev/null || echo starting); \
	    if [ "$$st" = "healthy" ]; then echo "✓ $$name is healthy"; exit 0; fi; \
	    sleep 1; \
	  done; \
	  echo "$$name not healthy in time"; exit 1'
endef

# ---------- staged up ----------
.PHONY: up
up:
	$(normalize_scripts)
	$(ensure_files)
	$(ensure_dirs)
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d mariadb
	$(call WAIT_HEALTHY,mariadb)
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d wordpress
	$(call WAIT_HEALTHY,wordpress)
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d nginx
	@printf "✔ Stack is up. Open https://$$(grep ^DOMAIN_NAME= $(ENV_FILE) | cut -d= -f2)\n"

.PHONY: build
build:
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) build

.PHONY: down
down:
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down

.PHONY: restart
restart: down up

.PHONY: logs
logs:
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) logs -f

.PHONY: ps
ps:
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) ps

.PHONY: sh-db
sh-db:
	@docker exec -it mariadb sh || true

.PHONY: sh-wp
sh-wp:
	@docker exec -it wordpress sh || true

.PHONY: sh-nginx
sh-nginx:
	@docker exec -it nginx sh || true

# ---------- nukes (bind-dirs) ----------
# NOTE: We confirm FIRST. Only on "yes" do we stop containers and proceed.

.PHONY: wp-reset
wp-reset:
	@bash -lc '$(call _CONFIRM,This will DELETE WordPress bind-dir ($(WP_DIR)) – uploads & wp core/config will be recreated.)' && { \
		docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down; \
		sudo rm -rf $(WP_DIR)/* || true; \
		printf "→ wordpress dir is now empty\n"; \
		$(MAKE) up; \
	} || true

.PHONY: db-reset
db-reset:
	@bash -lc '$(call _CONFIRM,This will DELETE MariaDB bind-dir ($(DB_DIR)) – ALL site content/users are lost.)' && { \
		docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down; \
		sudo rm -rf $(DB_DIR)/* || true; \
		printf "→ mariadb dir is now empty\n"; \
		$(MAKE) up; \
	} || true

.PHONY: re
re:
	@bash -lc '$(call _CONFIRM,FULL RESET: delete BOTH bind-dirs ($(DB_DIR), $(WP_DIR)); rebuild images; start fresh.)' && { \
		docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down; \
		sudo rm -rf $(DB_DIR)/* $(WP_DIR)/* || true; \
		printf "→ bind-dirs emptied\n"; \
		$(MAKE) build; \
		$(MAKE) up; \
	} || true

# ---------- absolute nuke (also named volumes + images) ----------
.PHONY: pristine
pristine:
	@bash -lc '$(call _CONFIRM,ABSOLUTE NUKE: delete bind-dirs + named volumes + images.)' && { \
		docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down; \
		sudo rm -rf $(DB_DIR)/* $(WP_DIR)/* || true; \
		docker volume rm -f srcs_db_data srcs_wp_data 2>/dev/null || true; \
		docker rmi srcs-mariadb srcs-wordpress srcs-nginx 2>/dev/null || true; \
		$(MAKE) build; \
		$(MAKE) up; \
	} || true

# ---------- optional: purge only the default sample content (safe) ----------
.PHONY: wp-purge-sample
wp-purge-sample:
	@docker exec -it wordpress sh -lc '\
	  set -e; \
	  command -v wp >/dev/null 2>&1 || exit 0; \
	  ids=$$(wp post list --post_type=page,post --name=sample-page,hello-world --format=ids || true); \
	  if [ -n "$$ids" ]; then wp post delete $$ids --force || true; fi; \
	  wp transient delete --all || true; \
	  echo "Purged sample content (if any)." \
	' || true

# ---------- misc ----------
.PHONY: env
env:
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) config

.PHONY: cert-re
cert-re:
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) build nginx
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d nginx

.PHONY: test
test:
	@printf "$(PRP)Running smoke tests…$(RST)\n"
	@docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) ps || true
	# Nginx config parse
	@if docker ps --format '{{.Names}}' | grep -q '^nginx$$'; then docker exec -it nginx sh -lc 'nginx -t'; else echo "[skip] nginx not up"; fi
	# FPM reachable from Nginx netns
	@if docker ps --format '{{.Names}}' | grep -q '^nginx$$'; then docker exec -it nginx sh -lc 'apk add --no-cache busybox-extras >/dev/null 2>&1 || true; nc -zvw2 wordpress 9000 || true'; else echo "[skip] wordpress not up"; fi
	# php-fpm processes
	@if docker ps --format '{{.Names}}' | grep -q '^wordpress$$'; then docker exec -it wordpress sh -lc 'ps aux | grep -v grep | grep php-fpm || true'; else echo "[skip] wordpress not up"; fi
	# MariaDB reachable (try with root secret, then without)
	@if docker ps --format '{{.Names}}' | grep -q '^mariadb$$'; then docker exec -it mariadb sh -lc 'mariadb -uroot -p"$$(cat /run/secrets/db_root_password)" -e "SELECT 1;" >/dev/null 2>&1 || mariadb -uroot -e "SELECT 1;"'; else echo "[skip] mariadb not up"; fi
	@printf "✔ Tests done.\n"

.PHONY: verify-reset
verify-reset:
	@echo "Host bind dir state:"
	@echo "- mariadb ->";  ls -lah $(DB_DIR) | sed -n '1,30p'
	@echo "- wordpress ->"; ls -lah $(WP_DIR) | sed -n '1,30p'
	@echo "If stack is up, DB/files quick check:"
	@if docker ps --format '{{.Names}}' | grep -q '^mariadb$$'; then docker exec -it mariadb sh -lc 'mariadb -uroot -p"$$(cat /run/secrets/db_root_password)" -e "SHOW DATABASES LIKE '\''$$(grep ^MYSQL_DATABASE= $(ENV_FILE) | cut -d= -f2)'\'';" || true'; else echo "[skip] mariadb not up"; fi
	@if docker ps --format '{{.Names}}' | grep -q '^wordpress$$'; then docker exec -it wordpress sh -lc '[ -f /var/www/wordpress/index.php ] && echo "index.php present" || echo "index.php MISSING"'; else echo "[skip] wordpress not up"; fi

# default
.DEFAULT_GOAL := help
