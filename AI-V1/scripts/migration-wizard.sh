#!/usr/bin/env bash
# ==============================================================================
# AI-V1 Clean-Slate Migration Wizard (Domain · Project Existing · Code-Server)
# Membantu mencatat, memetakan, dan membuat konfigurasi Nginx + folder bersih
# di /home/project serta penempatan layanan sistem (hermes, monitor, code-server).
#
# Penggunaan:
#   sudo bash AI-V1/scripts/migration-wizard.sh [--dry-run]
# ==============================================================================

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[MODE DRY-RUN] Tidak akan mengubah /etc/nginx atau membuat folder sistem secara langsung."
fi

if [[ "${DRY_RUN}" == "false" && "${EUID}" -ne 0 ]]; then
  echo "Jalankan sebagai root/sudo (atau gunakan --dry-run untuk simulasi)."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_AIV1_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUTPUT_STAGING="/tmp/ai-v1-wizard-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${OUTPUT_STAGING}/nginx"

MANIFEST_TARGET="/opt/hermes/data/shared/reports/migration-manifest.md"
if [[ "${DRY_RUN}" == "true" || ! -d "/opt/hermes/data/shared/reports" ]]; then
  MANIFEST_TARGET="${OUTPUT_STAGING}/migration-manifest.md"
fi

echo "============================================================"
echo "   AI-V1 MIGRATION WIZARD: DOMAIN & PROJECT EXISTING"
echo "============================================================"
echo

read -r -p "1. Domain utama VPS (contoh: imam.my.id): " BASE_DOMAIN
if [[ -z "${BASE_DOMAIN}" ]]; then
  echo "Domain utama tidak boleh kosong."
  exit 1
fi

read -r -p "2. Subdomain Hermes Dashboard [hermes.${BASE_DOMAIN}]: " HERMES_DOMAIN
HERMES_DOMAIN="${HERMES_DOMAIN:-hermes.${BASE_DOMAIN}}"

read -r -p "3. Subdomain VPS Monitor Dashboard [monitor.${BASE_DOMAIN}]: " MONITOR_DOMAIN
MONITOR_DOMAIN="${MONITOR_DOMAIN:-monitor.${BASE_DOMAIN}}"

read -r -p "4. Subdomain Code-Server (/home/project) [code.${BASE_DOMAIN}]: " CODE_DOMAIN
CODE_DOMAIN="${CODE_DOMAIN:-code.${BASE_DOMAIN}}"

read -r -p "5. Ekspos 9Router via Nginx auth_basic? (y/N): " EXPOSE_9ROUTER
NINEROUTER_DOMAIN=""
if [[ "${EXPOSE_9ROUTER,,}" == "y" ]]; then
  read -r -p "   Subdomain 9Router [9router.${BASE_DOMAIN}]: " NINEROUTER_DOMAIN
  NINEROUTER_DOMAIN="${NINEROUTER_DOMAIN:-9router.${BASE_DOMAIN}}"
fi

# Siapkan header manifest
cat > "${MANIFEST_TARGET}" <<EOF
# AI-V1 Migration Manifest (Domain, Layanan Sistem & Project Existing)

- **Tanggal Wizard:** $(date -Iseconds)
- **Domain Utama:** \`${BASE_DOMAIN}\`

## 1. Peta Domain Layanan Inti AI-V1
| Layanan | Domain / Subdomain | Target Bind Lokal | Workspace / Catatan |
| :--- | :--- | :--- | :--- |
| Hermes Dashboard | \`${HERMES_DOMAIN}\` | \`127.0.0.1:9119\` | \`/opt/hermes/data\` |
| VPS Monitor Dashboard | \`${MONITOR_DOMAIN}\` | \`127.0.0.1:9120\` | \`/opt/vps-dashboard\` + \`auth_basic\` |
| Code-Server (VS Code Web) | \`${CODE_DOMAIN}\` | \`127.0.0.1:8443\` | \`/home/project\` (user \`codeserver\`) |
EOF

if [[ -n "${NINEROUTER_DOMAIN}" ]]; then
  echo "| 9Router AI Gateway | \`${NINEROUTER_DOMAIN}\` | \`127.0.0.1:20128\` | \`auth_basic\` wajib aktif |" >> "${MANIFEST_TARGET}"
fi

cat >> "${MANIFEST_TARGET}" <<EOF

## 2. Daftar ProjectWeb Existing (Target Bersih: \`/home/project/<app>\`)
| App Folder | Domain Publik | Stack | Target / Root | Database Terkait |
| :--- | :--- | :--- | :--- | :--- |
EOF

# Generate config Nginx layanan sistem ke staging
cat > "${OUTPUT_STAGING}/nginx/hermes" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${HERMES_DOMAIN};

    client_max_body_size 50m;

    location / {
        proxy_pass http://127.0.0.1:9119;
        proxy_http_version 1.1;
        proxy_set_header Upgrade           \$http_upgrade;
        proxy_set_header Connection        "upgrade";
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
        proxy_buffering off;
    }
}
EOF

sed "s/<DOMAIN>/${BASE_DOMAIN}/g; s/monitor\.${BASE_DOMAIN}/${MONITOR_DOMAIN}/g" \
  "${REPO_AIV1_DIR}/vps-dashboard/deploy/nginx-monitor.conf" > "${OUTPUT_STAGING}/nginx/vps-monitor"

sed "s/<DOMAIN>/${BASE_DOMAIN}/g; s/code\.${BASE_DOMAIN}/${CODE_DOMAIN}/g" \
  "${REPO_AIV1_DIR}/code-server/deploy/nginx-code-server.conf" > "${OUTPUT_STAGING}/nginx/code-server"

CERTBOT_DOMAINS=("${HERMES_DOMAIN}" "${MONITOR_DOMAIN}" "${CODE_DOMAIN}")
if [[ -n "${NINEROUTER_DOMAIN}" ]]; then
  CERTBOT_DOMAINS+=("${NINEROUTER_DOMAIN}")
  cat > "${OUTPUT_STAGING}/nginx/9router" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${NINEROUTER_DOMAIN};

    location / {
        auth_basic "9Router Gateway";
        auth_basic_user_file /etc/nginx/htpasswd/9router.htpasswd;

        proxy_pass http://127.0.0.1:20128;
        proxy_http_version 1.1;
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
fi

echo
echo "--- Input ProjectWeb Existing yang Akan Dimigrasi ke /home/project ---"
PROJECT_APPS=()
while true; do
  read -r -p "Tambah project existing? (y/N): " ADD_PROJ
  if [[ "${ADD_PROJ,,}" != "y" ]]; then
    break
  fi

  read -r -p "  Nama folder bersih (tanpa spasi, contoh: sim-pt): " APP_NAME
  if [[ -z "${APP_NAME}" || ! "${APP_NAME}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "  Nama folder tidak valid. Gunakan huruf/angka/dash/underscore."
    continue
  fi

  read -r -p "  Domain publik project (contoh: sim.${BASE_DOMAIN}): " APP_DOMAIN
  if [[ -z "${APP_DOMAIN}" ]]; then
    echo "  Domain project wajib diisi."
    continue
  fi

  echo "  Pilih tipe stack:"
  echo "    1) PHP / Laravel (document root: /home/project/${APP_NAME}/public)"
  echo "    2) PHP Native    (document root: /home/project/${APP_NAME})"
  echo "    3) Proxy Port    (Node/Python/Go di 127.0.0.1:<PORT>)"
  echo "    4) Static HTML   (document root: /home/project/${APP_NAME})"
  read -r -p "  Pilihan [1-4]: " STACK_CHOICE

  STACK_LABEL=""
  TARGET_INFO=""
  NGINX_BLOCK=""
  case "${STACK_CHOICE}" in
    1|2)
      read -r -p "  Versi PHP-FPM socket [8.3]: " PHP_VER
      PHP_VER="${PHP_VER:-8.3}"
      DOC_ROOT="/home/project/${APP_NAME}"
      if [[ "${STACK_CHOICE}" == "1" ]]; then
        DOC_ROOT="/home/project/${APP_NAME}/public"
        STACK_LABEL="PHP/Laravel (${PHP_VER})"
      else
        STACK_LABEL="PHP Native (${PHP_VER})"
      fi
      TARGET_INFO="${DOC_ROOT}"
      NGINX_BLOCK=$(cat <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${APP_DOMAIN};

    root ${DOC_ROOT};
    index index.php index.html;

    client_max_body_size 50m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VER}-fpm.sock;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
)
      ;;
    3)
      read -r -p "  Port lokal aplikasi [3000]: " APP_PORT
      APP_PORT="${APP_PORT:-3000}"
      STACK_LABEL="Reverse Proxy"
      TARGET_INFO="127.0.0.1:${APP_PORT}"
      NGINX_BLOCK=$(cat <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${APP_DOMAIN};

    client_max_body_size 50m;

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade           \$http_upgrade;
        proxy_set_header Connection        "upgrade";
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
)
      ;;
    *)
      STACK_LABEL="Static HTML"
      TARGET_INFO="/home/project/${APP_NAME}"
      NGINX_BLOCK=$(cat <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${APP_DOMAIN};

    root /home/project/${APP_NAME};
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ /\. {
        deny all;
    }
}
EOF
)
      ;;
  esac

  read -r -p "  Nama database MySQL terkait (kosongkan jika tidak ada): " APP_DB
  APP_DB="${APP_DB:--}"

  echo "${NGINX_BLOCK}" > "${OUTPUT_STAGING}/nginx/${APP_NAME}"
  echo "| \`${APP_NAME}\` | \`${APP_DOMAIN}\` | ${STACK_LABEL} | \`${TARGET_INFO}\` | \`${APP_DB}\` |" >> "${MANIFEST_TARGET}"
  PROJECT_APPS+=("${APP_NAME}")
  CERTBOT_DOMAINS+=("${APP_DOMAIN}")
  echo "  -> Ditambahkan: ${APP_NAME} (${APP_DOMAIN})"
done

echo
echo "=== Ringkasan Hasil Wizard ==="
echo "Manifest : ${MANIFEST_TARGET}"
echo "Nginx cfg: ${OUTPUT_STAGING}/nginx/"
ls -1 "${OUTPUT_STAGING}/nginx/"

if [[ "${DRY_RUN}" == "true" ]]; then
  echo
  echo "[DRY-RUN SELESAI] Periksa file di ${OUTPUT_STAGING} sebelum menjalankan tanpa --dry-run."
  exit 0
fi

read -r -p "Terapkan folder /home/project/<app> dan virtual host Nginx sekarang? (y/N): " APPLY_NOW
if [[ "${APPLY_NOW,,}" != "y" ]]; then
  echo "Dibatalkan. File konfigurasi tersimpan di ${OUTPUT_STAGING}/nginx/ untuk ditinjau manual."
  exit 0
fi

# Buat folder /home/project/<app> dan set ACL untuk hermes (10001) & codeserver
mkdir -p /home/project
for app in "${PROJECT_APPS[@]}"; do
  mkdir -p "/home/project/${app}"
done

if command -v setfacl >/dev/null 2>&1; then
  id -u hermes >/dev/null 2>&1 && setfacl -R -m u:10001:rwX,d:u:10001:rwX /home/project
  id -u codeserver >/dev/null 2>&1 && setfacl -R -m u:codeserver:rwX,d:u:codeserver:rwX /home/project
fi

# Pasang virtual host ke /etc/nginx/sites-available & sites-enabled
for cfg in "${OUTPUT_STAGING}/nginx/"*; do
  name="$(basename "${cfg}")"
  cp "${cfg}" "/etc/nginx/sites-available/${name}"
  ln -sfn "/etc/nginx/sites-available/${name}" "/etc/nginx/sites-enabled/${name}"
done

echo "Menguji konfigurasi Nginx..."
nginx -t
systemctl reload nginx || systemctl start nginx

echo
echo "Langkah terakhir — jalankan Certbot SSL untuk domain yang DNS-nya sudah mengarah ke VPS:"
for dom in "${CERTBOT_DOMAINS[@]}"; do
  echo "  sudo certbot --nginx -d ${dom} --redirect"
done
echo
echo "Selesai! Manifest tercatat di: ${MANIFEST_TARGET}"

