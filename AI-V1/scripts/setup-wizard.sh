#!/usr/bin/env bash
# ==============================================================================
# AI-V1 Interactive Step-by-Step Setup & Credentials Wizard
# Memandu pengisian:
#   Step 1: Info VPS (IP VPS, Username, Password awal + wajib ganti setelah selesai)
#   Step 2: Domain & Subdomain Layanan (hermes, monitor, code, 9router)
#   Step 3: Telegram Bot untuk PM (1 Token = 1 Gateway pm-lead)
#   Step 4: 9Router AI Gateway (URL, API Key, Model Default/Gratis, Upstream)
#   Step 5: Dashboard & Code-Server Credentials
#   Step 6: Database MySQL Non-Root untuk Agent
#   Step 7: Enkripsi Catatan Resource ke Brankas PM-Only (pm-vault.enc)
#
# Penggunaan:
#   bash AI-V1/scripts/setup-wizard.sh --dry-run    # Simulasi aman ke /tmp
#   sudo bash AI-V1/scripts/setup-wizard.sh         # Terapkan ke /opt/hermes & /opt/code-server
# ==============================================================================

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[MODE DRY-RUN] Semua file akan ditulis ke folder staging /tmp tanpa menyentuh sistem live."
fi

if [[ "${DRY_RUN}" == "false" && "${EUID}" -ne 0 ]]; then
  echo "Jalankan dengan sudo/root (atau pakai --dry-run untuk simulasi)."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_AIV1_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

STAGING_DIR="/tmp/ai-v1-setup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${STAGING_DIR}"

if [[ "${DRY_RUN}" == "true" ]]; then
  TARGET_HERMES_DIR="${STAGING_DIR}/opt/hermes"
  TARGET_CODE_DIR="${STAGING_DIR}/opt/code-server"
  TARGET_HTPASSWD_DIR="${STAGING_DIR}/etc/nginx/htpasswd"
else
  TARGET_HERMES_DIR="/opt/hermes"
  TARGET_CODE_DIR="/opt/code-server"
  TARGET_HTPASSWD_DIR="/etc/nginx/htpasswd"
fi

TARGET_DATA_DIR="${TARGET_HERMES_DIR}/data"
TMP_PLAIN_VAULT=""
cleanup() {
  if [[ -n "${TMP_PLAIN_VAULT}" && -f "${TMP_PLAIN_VAULT}" ]]; then
    if command -v shred >/dev/null 2>&1; then
      shred -u -z "${TMP_PLAIN_VAULT}" 2>/dev/null || rm -f "${TMP_PLAIN_VAULT}"
    else
      rm -f "${TMP_PLAIN_VAULT}"
    fi
  fi
}
trap cleanup EXIT

prompt_secret() {
  local prompt_msg="$1"
  local var_name="$2"
  local default_val="${3:-}"
  local val=""
  read -r -s -p "${prompt_msg}" val
  echo
  if [[ -z "${val}" && -n "${default_val}" ]]; then
    val="${default_val}"
  fi
  printf -v "${var_name}" '%s' "${val}"
}

echo "======================================================================"
echo "          AI-V1 STEP-BY-STEP BOOTSTRAP & CREDENTIALS WIZARD"
echo "======================================================================"
echo

echo "--- STEP 1/7: Informasi VPS & Akses Awal Admin ---"
echo "Catatan Keamanan: Setelah proses setup selesai, Anda WAJIB mengganti"
echo "password VPS awal ini dan mengunci login hanya memakai SSH Key!"
read -r -p "  IP Publik VPS                   : " VPS_IP
read -r -p "  Username Admin VPS [ubuntu]     : " VPS_USER
VPS_USER="${VPS_USER:-ubuntu}"
prompt_secret "  Password VPS Awal (tersembunyi) : " VPS_INIT_PASS
echo

echo "--- STEP 2/7: Domain Utama & Subdomain Layanan ---"
read -r -p "  Domain Utama (contoh: imam.my.id): " BASE_DOMAIN
if [[ -z "${BASE_DOMAIN}" ]]; then
  echo "Error: Domain utama wajib diisi."
  exit 1
fi
read -r -p "  Hermes Dashboard [hermes.${BASE_DOMAIN}]   : " HERMES_DOMAIN
HERMES_DOMAIN="${HERMES_DOMAIN:-hermes.${BASE_DOMAIN}}"
read -r -p "  VPS Monitor      [monitor.${BASE_DOMAIN}]  : " MONITOR_DOMAIN
MONITOR_DOMAIN="${MONITOR_DOMAIN:-monitor.${BASE_DOMAIN}}"
read -r -p "  Code-Server      [code.${BASE_DOMAIN}]     : " CODE_DOMAIN
CODE_DOMAIN="${CODE_DOMAIN:-code.${BASE_DOMAIN}}"
read -r -p "  9Router Web      [9router.${BASE_DOMAIN}]  : " NINEROUTER_DOMAIN
NINEROUTER_DOMAIN="${NINEROUTER_DOMAIN:-9router.${BASE_DOMAIN}}"
echo

echo "--- STEP 3/7: Kredensial Telegram Bot untuk PM (pm-lead) ---"
echo "Aturan AI-V1: 1 Token Bot hanya untuk 1 gateway (pm-lead)."
prompt_secret "  TELEGRAM_BOT_TOKEN (tersembunyi)   : " TG_TOKEN
read -r -p "  TELEGRAM_ALLOWED_USERS (User ID)   : " TG_USERS
read -r -p "  TELEGRAM_HOME_CHANNEL (Chat ID)    : " TG_CHAT
echo

echo "--- STEP 4/7: Informasi 9Router AI Gateway ---"
read -r -p "  URL 9Router dari container [http://host.docker.internal:20128/v1]: " NR_URL
NR_URL="${NR_URL:-http://host.docker.internal:20128/v1}"
prompt_secret "  NINEROUTER_API_KEY (tersembunyi)   : " NR_KEY
read -r -p "  Nama Model Default / Combo [openrouter/llama-3.3-70b:free]: " MODEL_DEFAULT
MODEL_DEFAULT="${MODEL_DEFAULT:-openrouter/llama-3.3-70b:free}"
read -r -p "  Catatan Provider Upstream di 9Router (mis. OpenRouter/Gemini/Groq): " NR_UPSTREAM
NR_UPSTREAM="${NR_UPSTREAM:-OpenRouter/Gemini}"
echo

echo "--- STEP 5/7: Kredensial Dashboard & Code-Server ---"
read -r -p "  Username Hermes Dashboard [admin]  : " DASH_USER
DASH_USER="${DASH_USER:-admin}"
prompt_secret "  Password Hermes Dashboard          : " DASH_PASS
read -r -p "  Username VPS Monitor [admin]       : " MON_USER
MON_USER="${MON_USER:-admin}"
prompt_secret "  Password VPS Monitor               : " MON_PASS
prompt_secret "  Password Code-Server (/home/project): " CODE_PASS
echo

echo "--- STEP 6/7: Akun MySQL Non-Root untuk Tim Agent ---"
read -r -p "  Nama Database Proyek Utama [app_db]: " DB_NAME
DB_NAME="${DB_NAME:-app_db}"
read -r -p "  Username DB Non-Root [ai_agent]    : " DB_AGENT_USER
DB_AGENT_USER="${DB_AGENT_USER:-ai_agent}"
prompt_secret "  Password DB Non-Root               : " DB_AGENT_PASS
echo

echo "--- STEP 7/7: Master Password Brankas PM-Only (pm-vault.enc) ---"
prompt_secret "  Masukkan Master Password Vault     : " VAULT_PASS_1
prompt_secret "  Ulangi Master Password Vault       : " VAULT_PASS_2
if [[ -z "${VAULT_PASS_1}" || "${VAULT_PASS_1}" != "${VAULT_PASS_2}" ]]; then
  echo "Error: Master Password kosong atau tidak cocok."
  exit 1
fi
echo

# Siapkan direktori target
mkdir -p "${TARGET_DATA_DIR}"/{profiles,shared/tasks,shared/reports,credentials,desktop-plugins,scripts,cron}
mkdir -p "${TARGET_HERMES_DIR}/ssh" "${TARGET_CODE_DIR}/data" "${TARGET_CODE_DIR}/extensions" "${TARGET_HTPASSWD_DIR}"

# 1. Tulis /opt/hermes/data/.env
cat > "${TARGET_DATA_DIR}/.env" <<EOF
TELEGRAM_BOT_TOKEN=${TG_TOKEN}
TELEGRAM_ALLOWED_USERS=${TG_USERS}
TELEGRAM_HOME_CHANNEL=${TG_CHAT}
NINEROUTER_API_KEY=${NR_KEY}
DASHBOARD_USER=${DASH_USER}
TZ=Asia/Jakarta
EOF
chmod 600 "${TARGET_DATA_DIR}/.env"

# 2. Hasilkan hash dashboard jika python3/openssl tersedia, lalu tulis config.yaml & docker-compose.yml
DASH_HASH="<REPLACE_WITH_BCRYPT_OR_SHA256_HASH>"
if [[ -n "${DASH_PASS}" ]]; then
  if python3 -c 'import hashlib' >/dev/null 2>&1; then
    DASH_HASH="$(python3 -c 'import hashlib, os, sys; salt=os.urandom(8).hex(); h=hashlib.pbkdf2_hmac("sha256", sys.argv[1].encode(), salt.encode(), 200000).hex(); print(f"pbkdf2:sha256:200000${salt}${h}")' "${DASH_PASS}")"
  elif command -v openssl >/dev/null 2>&1; then
    DASH_HASH="$(openssl passwd -6 "${DASH_PASS}" 2>/dev/null || echo "<REPLACE_WITH_BCRYPT_OR_SHA256_HASH>")"
  fi
fi

sed -e "s|<NAMA_MODEL_COMBO>|${MODEL_DEFAULT}|g" \
    -e "s|http://host.docker.internal:20128/v1|${NR_URL}|g" \
    -e "s|<DOMAIN>|${BASE_DOMAIN}|g" \
    -e "s|<ADMIN_DASHBOARD_USER>|${DASH_USER}|g" \
    -e "s|<STRONG_PASSWORD_HASH>|${DASH_HASH}|g" \
    "${REPO_AIV1_DIR}/templates/config.root.example.yaml" > "${TARGET_DATA_DIR}/config.yaml"
chmod 600 "${TARGET_DATA_DIR}/config.yaml"

cp "${REPO_AIV1_DIR}/templates/docker-compose.yml.example" "${TARGET_HERMES_DIR}/docker-compose.yml"

# 3. Salin seluruh 8 profil agent & isi model.default
for agent_dir in 00-pm-coordinator ops-sysadmin ops-backup-dba ops-secops ops-model-hunter dev-architect dev-fullstack dev-qa; do
  case "${agent_dir}" in
    00-pm-coordinator) profile_name="pm-lead" ;;
    *) profile_name="${agent_dir}" ;;
  esac
  mkdir -p "${TARGET_DATA_DIR}/profiles/${profile_name}"
  cp -r "${REPO_AIV1_DIR}/agents/${agent_dir}/." "${TARGET_DATA_DIR}/profiles/${profile_name}/"
  sed -i "s|<NAMA_MODEL_COMBO>|${MODEL_DEFAULT}|g" "${TARGET_DATA_DIR}/profiles/${profile_name}/config.yaml"
done

# 4. Salin shared tasks, worklog, cron, dan check_models.py
cp "${REPO_AIV1_DIR}/agents/TASKS.md" "${TARGET_DATA_DIR}/shared/tasks/TASKS.md"
cp "${REPO_AIV1_DIR}/agents/worklog.example.json" "${TARGET_DATA_DIR}/shared/tasks/worklog.json"
cp "${REPO_AIV1_DIR}/agents/CREDENTIALS_POLICY.md" "${TARGET_DATA_DIR}/credentials/CREDENTIALS_POLICY.md"
cp "${REPO_AIV1_DIR}/agents/cron.jobs.example.json" "${TARGET_DATA_DIR}/cron/jobs.json"
cp "${REPO_AIV1_DIR}/scripts/check_models.py" "${TARGET_DATA_DIR}/scripts/check_models.py"

# 5. Konfigurasi code-server
sed "s|<STRONG_CODE_SERVER_PASSWORD>|${CODE_PASS}|g" \
    "${REPO_AIV1_DIR}/code-server/config.yaml.example" > "${TARGET_CODE_DIR}/config.yaml"
chmod 600 "${TARGET_CODE_DIR}/config.yaml"

# 6. Buat monitor.htpasswd jika htpasswd tersedia
if command -v htpasswd >/dev/null 2>&1 && [[ -n "${MON_PASS}" ]]; then
  htpasswd -bc "${TARGET_HTPASSWD_DIR}/monitor.htpasswd" "${MON_USER}" "${MON_PASS}" >/dev/null 2>&1
  chown root:www-data "${TARGET_HTPASSWD_DIR}/monitor.htpasswd" 2>/dev/null || true
  chmod 640 "${TARGET_HTPASSWD_DIR}/monitor.htpasswd"
fi

# 7. Buat SQL siap pakai untuk DB Non-Root (tidak mengeksekusi otomatis agar aman)
cat > "${STAGING_DIR}/mysql-agent-setup.sql" <<EOF
-- Jalankan sebagai admin MySQL di host:
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_AGENT_USER}'@'172.28.10.%' IDENTIFIED BY '${DB_AGENT_PASS}';
CREATE USER IF NOT EXISTS '${DB_AGENT_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_AGENT_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_AGENT_USER}'@'172.28.10.%';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_AGENT_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
chmod 600 "${STAGING_DIR}/mysql-agent-setup.sql"

# 8. Enkripsi seluruh catatan penting ke brankas PM-Only (/opt/hermes/data/credentials/pm-vault.enc)
if [[ -d "/dev/shm" ]] && TMP_PLAIN_VAULT="$(mktemp "/dev/shm/pm-vault-init.XXXXXX" 2>/dev/null)"; then
  :
else
  TMP_PLAIN_VAULT="$(mktemp "/tmp/pm-vault-init.XXXXXX")"
fi
chmod 600 "${TMP_PLAIN_VAULT}"

cat > "${TMP_PLAIN_VAULT}" <<EOF
# PM-Only Credentials Vault AI-V1 (Dibuat via setup-wizard.sh pada $(date -Iseconds))
# PERINGATAN: Hanya boleh dibaca oleh Admin VPS dan pm-lead (00-pm-coordinator).

## 1. Akses VPS & SSH (WAJIB GANTI PASSWORD AWAL!)
- IP VPS: ${VPS_IP}
- Username: ${VPS_USER}
- Password Awal (HARUS DIGANTI): ${VPS_INIT_PASS}

## 2. Domain & Dashboard
- Domain Utama: ${BASE_DOMAIN}
- Hermes Dashboard: https://${HERMES_DOMAIN} | User: ${DASH_USER} | Pass: ${DASH_PASS}
- VPS Monitor Dashboard: https://${MONITOR_DOMAIN} | User: ${MON_USER} | Pass: ${MON_PASS}
- Code-Server (/home/project): https://${CODE_DOMAIN} | User: codeserver | Pass: ${CODE_PASS}

## 3. Telegram Bot (PM-Lead Gateway Tunggal)
- TELEGRAM_BOT_TOKEN: ${TG_TOKEN}
- TELEGRAM_ALLOWED_USERS: ${TG_USERS}
- TELEGRAM_HOME_CHANNEL: ${TG_CHAT}

## 4. 9Router AI Gateway
- URL Container: ${NR_URL}
- Subdomain Web: https://${NINEROUTER_DOMAIN}
- NINEROUTER_API_KEY: ${NR_KEY}
- Model Default: ${MODEL_DEFAULT}
- Upstream Providers: ${NR_UPSTREAM}

## 5. Database MySQL Non-Root Agent
- Database: ${DB_NAME}
- DB Agent User: ${DB_AGENT_USER}
- DB Agent Password: ${DB_AGENT_PASS}
EOF

VAULT_PASS_1="${VAULT_PASS_1}" openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt \
  -in "${TMP_PLAIN_VAULT}" \
  -out "${TARGET_DATA_DIR}/credentials/pm-vault.enc" \
  -pass env:VAULT_PASS_1
chmod 600 "${TARGET_DATA_DIR}/credentials/pm-vault.enc"
chmod 700 "${TARGET_DATA_DIR}/credentials"

if [[ "${DRY_RUN}" == "false" ]]; then
  id -u hermes >/dev/null 2>&1 && chown -R 10001:10001 "${TARGET_DATA_DIR}" "${TARGET_HERMES_DIR}/ssh"
  id -u codeserver >/dev/null 2>&1 && chown -R codeserver:dev "${TARGET_CODE_DIR}"
fi

echo "======================================================================"
echo "  SETUP WIZARD SELESAI!"
echo "======================================================================"
echo "File yang dibuat:"
echo "  - Env Gateway         : ${TARGET_DATA_DIR}/.env (chmod 600)"
echo "  - Config Root Hermes  : ${TARGET_DATA_DIR}/config.yaml"
echo "  - Docker Compose      : ${TARGET_HERMES_DIR}/docker-compose.yml"
echo "  - 8 Profil Agent      : ${TARGET_DATA_DIR}/profiles/"
echo "  - Brankas PM-Only     : ${TARGET_DATA_DIR}/credentials/pm-vault.enc (terenkripsi)"
echo "  - Config Code-Server  : ${TARGET_CODE_DIR}/config.yaml"
echo "  - SQL DB Non-Root     : ${STAGING_DIR}/mysql-agent-setup.sql (hapus setelah dieksekusi)"
echo
echo "TINDAKAN WAJIB BERIKUTNYA:"
echo "  1. WAJIB ganti password VPS awal (${VPS_USER}@${VPS_IP}): sudo passwd ${VPS_USER}"
echo "     dan pastikan SSH Key-Only aktif (PasswordAuthentication no)."
echo "  2. Jalankan SQL DB non-root di MySQL lalu hapus ${STAGING_DIR}/mysql-agent-setup.sql."
echo "  3. Jalankan wizard domain & project: sudo bash AI-V1/scripts/migration-wizard.sh"
echo "  4. Untuk membaca ulang catatan rahasia PM: bash AI-V1/scripts/pm-vault.sh read"
