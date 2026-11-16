# PM-Only Credentials Vault — Catatan Penting Resource (Username, Password, Key)
# ==============================================================================
# PERINGATAN:
# - File ini HANYA template! JANGAN PERNAH mengisi secret asli lalu meng-commit ke Git.
# - Saat setup di VPS, isi file ini lewat `bash AI-V1/scripts/pm-vault.sh init`
#   agar langsung dienkripsi menjadi `/opt/hermes/data/credentials/pm-vault.enc`
#   (AES-256-CBC + PBKDF2 600k iterasi, chmod 600, UID 10001).
# - HANYA `pm-lead` (00-pm-coordinator) & Admin VPS yang berhak mendekripsi dengan Master Password.
# ==============================================================================

## 1. Akses VPS & SSH
- **IP VPS Produksi:** `<VPS_PUBLIC_IP>`
- **Port SSH:** `22`
- **Admin User:** `ubuntu` (SSH Key-Only; PasswordAuth: disabled)
- **SSH Key Monitoring (`/opt/hermes/ssh`):**
  - Target Host: `<EXTERNAL_HOST_OR_NONE>`
  - Key Name / Fingerprint: `<KEY_NAME>`

## 2. Domain & Dashboard Kontrol
- **Domain Utama:** `<DOMAIN>`
- **Hermes Dashboard (`https://hermes.<DOMAIN>`):**
  - Username: `<HERMES_DASHBOARD_USER>`
  - Password: `<HERMES_DASHBOARD_PASSWORD>`
- **VPS Monitor Dashboard (`https://monitor.<DOMAIN>`):**
  - Username (`htpasswd`): `<MONITOR_USER>`
  - Password: `<MONITOR_PASSWORD>`
- **Code-Server (`https://code.<DOMAIN>`):**
  - System User: `codeserver`
  - Web Login Password (`/opt/code-server/config.yaml`): `<CODE_SERVER_PASSWORD>`

## 3. Telegram Bot & AI Gateway (9Router)
- **Telegram Bot (`@<BOT_USERNAME>`):**
  - `TELEGRAM_BOT_TOKEN`: `<TELEGRAM_BOT_TOKEN>` (Hanya dipakai gateway `pm-lead`)
  - `TELEGRAM_ALLOWED_USERS`: `<USER_ID_ADMIN_TELEGRAM>`
  - `TELEGRAM_HOME_CHANNEL`: `<CHAT_ID_UTAMA>`
- **9Router Primary (`http://127.0.0.1:20128` / `https://9router.<DOMAIN>`):**
  - Web `auth_basic` Username: `<9ROUTER_WEB_USER>`
  - Web `auth_basic` Password: `<9ROUTER_WEB_PASSWORD>`
  - `NINEROUTER_API_KEY`: `<NINEROUTER_API_KEY>`
- **Upstream Provider API Keys (di dalam 9Router):**
  - OpenRouter Key: `<OPENROUTER_KEY>`
  - Gemini / Google AI Key: `<GEMINI_KEY>`
  - Groq / Lainnya: `<OTHER_PROVIDER_KEY>`

## 4. Database MySQL / MariaDB
- **MySQL Root (HANYA dipegang Admin VPS, TIDAK untuk container):**
  - Host: `127.0.0.1:3306`
  - Catatan: Tidak disimpan untuk agent; hanya dipakai Admin saat membuat DB/user baru.
- **Database Proyek & Akun Non-Root Agent:**
  - Project `<app-1>`:
    - Database: `<DB_NAME_1>`
    - App Prod User: `<APP_DB_USER_1>` / `<APP_DB_PASS_1>`
    - Agent Non-Root User: `<DB_AGENT_USER_1>` / `<DB_AGENT_PASS_1>`

## 5. Kredensial Lainnya (Git, Off-Site Backup, SMTP, Payment/API)
- **GitHub Deploy Key / PAT (bila ada):** `<GITHUB_TOKEN_OR_SSH>`
- **Off-Site Backup (`rclone` / S3 / GDrive - Host Root Only):**
  - Remote Name: `<RCLONE_REMOTE>`
  - Akun / Bucket: `<BUCKET_OR_EMAIL>`
- **SMTP / Notifikasi Email:**
  - Host/Port: `<SMTP_HOST>`
  - Username / Password: `<SMTP_USER>` / `<SMTP_PASS>`

