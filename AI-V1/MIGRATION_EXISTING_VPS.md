# Standar Migrasi Clean-Slate AI-V1 (Catat · Backup · Takedown · Rebuild Bersih)

Dokumen ini adalah prosedur standar migrasi VPS yang sudah memiliki data *existing* menggunakan pendekatan **Clean-Slate Takedown**: seluruh layanan dan struktur folder lama **dicatat, di-backup penuh, di-takedown, dan dibersihkan**, lalu VPS dibangun ulang agar **100% bersih mengikuti struktur direktori resmi AI-V1** (tanpa folder sembarangan atau sisa konfigurasi lama).

> **Prinsip Utama Migrasi Clean-Slate:**
> 1. **Catat Sebelum Hapus:** Semua domain, database, cron, service, `.env`, dan lokasi folder lama wajib dicatat ke file `INVENTORY.md`.
> 2. **Backup Terverifikasi Sebelum Takedown:** Tidak ada layanan atau folder lama yang boleh dihentikan/dihapus sebelum arsip backup lulus uji integritas (`gzip -t` / `tar -tzf`) dan **VPS Snapshot** dibuat.
> 3. **Struktur Bersih Tanpa Folder Liar:** Setelah rebuild, hanya direktori standar AI-V1 yang boleh eksis (`/opt/hermes`, `/opt/vps-dashboard`, `/home/project`, `/var/backups/apps`).

---

## Peta Struktur Akhir yang Diizinkan (Clean Target State)

Setelah migrasi selesai, hanya direktori berikut yang menjadi standar resmi di VPS:

| Path di Host | Pemilik | Fungsi Tunggal |
| :--- | :--- | :--- |
| `/opt/hermes` | `root:root` / `10001:10001` (`data`, `ssh`) | Stack Docker Compose Hermes (`docker-compose.yml`, `data/`, `ssh/`) |
| `/opt/vps-dashboard` | `root:root` | Dashboard monitoring visual AI-V1 (`127.0.0.1:9120`) |
| `/opt/code-server` | `codeserver:dev` | Konfigurasi, data & ekstensi `code-server` (`127.0.0.1:8443`, membaca `/home/project`) |
| `/home/project/<nama-app>` | `www-data` / grup `dev` + ACL `10001` | Seluruh aplikasi web produksi yang rapi (satu folder per app, dikelola Git) |
| `/var/backups/apps` | `root:root` (`700` untuk `pre-migration-*`) | Arsip backup harian/mingguan & arsip `pre-migration-*` |
| `/etc/nginx/sites-available/*` | `root:root` | 1 file virtual host per subdomain/app aktif (`sites-enabled/` symlink bersih) |

> **Dilarang ada:** folder proyek tercecer di `/root/`, `/home/<user>/coba*`, `/var/www/html-backup*`, skrip bot Telegram liar di `/tmp` atau `~/.local`, serta duplikasi instalasi Hermes di `/root/.hermes`.

---

## Fase 0 — Pencatatan Data Existing (*Inventory Manifest*)

Jalankan langkah ini untuk mencatat seluruh kondisi sebelum takedown ke dalam file laporan `/root/pre-migration-inventory.txt`:

```bash
INV_FILE="/root/pre-migration-inventory-$(date +%Y%m%d-%H%M%S).txt"
{
  echo "=== 1. SYSTEM & DISK ==="
  hostname; uname -a; df -h; free -h
  echo "=== 2. RUNNING PROCESSES & PORTS ==="
  ps aux | grep -E 'hermes|9router|python|node|nginx|mysql|mariadb|php|docker'
  ss -tulpn
  echo "=== 3. SYSTEMD SERVICES & USER CRON ==="
  systemctl list-units --type=service --state=running
  crontab -l 2>/dev/null || echo "No root crontab"
  ls -la /etc/cron.d /var/spool/cron/crontabs 2>/dev/null || true
  echo "=== 4. NGINX SITES & SSL CERTS ==="
  ls -la /etc/nginx/sites-enabled/ /etc/nginx/sites-available/
  nginx -T 2>/dev/null | grep -E 'server_name|root |proxy_pass|ssl_certificate '
  certbot certificates 2>/dev/null || true
  echo "=== 5. WEB & PROJECT FOLDERS ==="
  ls -la /var/www /home /home/project /opt 2>/dev/null || true
  echo "=== 6. MYSQL DATABASES & USERS ==="
  mysql -e "SHOW DATABASES; SELECT User, Host FROM mysql.user;" 2>/dev/null || true
} | sudo tee "${INV_FILE}"
```

Catat juga secara manual oleh Admin:
- Daftar domain/subdomain aktif dan target folder atau port masing-masing.
- Daftar token/kredensial aktif (`TELEGRAM_BOT_TOKEN`, `NINEROUTER_API_KEY`, `.env` masing-masing web app) untuk dimasukkan ke vault `pm-lead` (`/opt/hermes/data/.env` & `/opt/hermes/data/credentials/`).

---

## Fase 1 — Backup Penuh & Verifikasi Sebelum Takedown

Buat satu folder arsip tunggal di `/var/backups/apps/`:

```bash
BACKUP_TAG="pre-migration-$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/var/backups/apps/${BACKUP_TAG}"
sudo mkdir -p "${BACKUP_DIR}"/{db,web,system,hermes-old,other}
sudo chmod 700 "${BACKUP_DIR}"
sudo cp /root/pre-migration-inventory-*.txt "${BACKUP_DIR}/INVENTORY.txt"

# 1. Backup semua database MySQL/MariaDB
sudo mysqldump --single-transaction --routines --triggers --events --all-databases \
  | gzip > "${BACKUP_DIR}/db/all-databases.sql.gz"
gzip -t "${BACKUP_DIR}/db/all-databases.sql.gz"
zcat "${BACKUP_DIR}/db/all-databases.sql.gz" | tail -n 5   # Wajib ada: "-- Dump completed"

# 2. Backup semua folder web/project lama
[ -d /var/www ] && sudo tar -czpf "${BACKUP_DIR}/web/var-www.tar.gz" /var/www
[ -d /home/project ] && sudo tar -czpf "${BACKUP_DIR}/web/home-project.tar.gz" /home/project

# 3. Backup konfigurasi host & SSL
sudo tar -czpf "${BACKUP_DIR}/system/etc-nginx.tar.gz" /etc/nginx
[ -d /etc/letsencrypt ] && sudo tar -czpf "${BACKUP_DIR}/system/etc-letsencrypt.tar.gz" /etc/letsencrypt
sudo tar -czpf "${BACKUP_DIR}/system/etc-systemd-system.tar.gz" /etc/systemd/system
sudo cp /etc/ssh/sshd_config "${BACKUP_DIR}/system/sshd_config.bak"

# 4. Backup data Hermes / 9Router / skrip lama (bila ada)
[ -d /root/.hermes ] && sudo tar -czpf "${BACKUP_DIR}/hermes-old/root-hermes.tar.gz" /root/.hermes
[ -d /opt/hermes ] && sudo tar -czpf "${BACKUP_DIR}/hermes-old/opt-hermes-old.tar.gz" /opt/hermes
[ -d /root/.9router ] && sudo tar -czpf "${BACKUP_DIR}/hermes-old/root-9router.tar.gz" /root/.9router
```

> **Gate Wajib Sebelum Takedown:**
> 1. Verifikasi seluruh file `.tar.gz` bisa dibuka (`tar -tzf <file> >/dev/null`).
> 2. **Wajib** buat **VPS Snapshot** di panel cloud provider atau unduh `${BACKUP_DIR}` ke penyimpanan luar VPS (*off-site*).

---

## Fase 2 — Takedown Layanan Lama & Pembersihan Struktur Kotor

> Jalankan hanya setelah Fase 1 **100% terverifikasi aman**.

### 1. Takedown Service, Container, & Cron Lama
```bash
# Matikan semua layanan Hermes, bot Telegram liar, dan web app sementara (maintenance window)
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl stop hermes-gateway hermes-dashboard 9router 2>/dev/null || true
sudo systemctl disable hermes-gateway hermes-dashboard 2>/dev/null || true

# Hentikan semua container Docker lama bila ada
docker ps -aq | xargs -r docker stop
docker ps -aq | xargs -r docker rm

# Pastikan tidak ada proses Hermes atau bot Telegram polling tersisa
pkill -f "hermes" || true
pgrep -af "hermes|getUpdates" || echo "Clean: no lingering bot processes"
```
Periksa juga `crontab -e` dan `/etc/cron.d/` — hapus cron lama yang memanggil path usang (`/root/.hermes`, skrip duplikat).

### 2. Bersihkan Folder & Konfigurasi Lama yang Sembarangan
```bash
# Bersihkan instalasi Hermes lama yang tidak standar
sudo rm -rf /root/.hermes /home/*/.hermes
sudo rm -rf /opt/hermes

# Bersihkan virtual host Nginx lama yang berantakan (SSL di /etc/letsencrypt tetap dipertahankan atau disesuaikan)
sudo rm -f /etc/nginx/sites-enabled/*
sudo rm -f /etc/nginx/sites-available/*

# Bersihkan folder web lama di /var/www atau /home/project yang akan ditata ulang
# (Semua source code aman di ${BACKUP_DIR}/web/)
sudo rm -rf /var/www/html/* /home/project/*
```
*(Database MySQL tidak di-drop agar tidak kehilangan data; cukup bersihkan nanti hanya DB sampah/test yang tidak terpakai berdasarkan `INVENTORY.txt`.)*

---

## Fase 3 — Rebuild Struktur Bersih Standar AI-V1

Ikuti panduan utama dari nol pada struktur yang sudah bersih:
1. **Hardening & Struktur Direktori Resmi** sesuai [AI-V1/README.md](./README.md#3-breakdown-setup-bagian-1--hardening-vps-host):
   - Buat user `hermes` (`UID 10001:10001`) dan user `codeserver` (grup bersama `dev`).
   - Buat folder resmi: `/opt/hermes/data`, `/opt/hermes/ssh`, `/opt/vps-dashboard`, `/opt/code-server`, `/home/project`, `/var/backups/apps`.
2. **Deploy Docker Hermes (`hermes-gateway` & `hermes-dashboard`)** (`UID 10001:10001`), pasang profil agent dari [`agents/README.md`](./agents/README.md), isi `/opt/hermes/data/.env`, dan pasang slot `office-3d` bila diperlukan.
3. **Deploy `9Router` (`:20128`), [`vps-dashboard/`](./vps-dashboard/README.md) (`:9120`), dan [`code-server/`](./code-server/README.md) (`:8443` membuka `/home/project`):**
   - Pastikan config & ekstensi `code-server` berada di `/opt/code-server/`, bukan di dalam `/home/project`, agar folder proyek tetap bersih.
4. **Jalankan Wizard Domain & Project Existing (`scripts/migration-wizard.sh`):**
   ```bash
   # Simulasi (dry-run) terlebih dahulu untuk meninjau konfigurasi yang dihasilkan:
   bash AI-V1/scripts/migration-wizard.sh --dry-run

   # Jalankan interaktif untuk memetakan domain utama, hermes, monitor, code-server, dan setiap project existing:
   sudo bash AI-V1/scripts/migration-wizard.sh
   ```
   Wizard ini secara interaktif akan:
   - Memetakan domain inti (`hermes.<DOMAIN>`, `monitor.<DOMAIN>`, `code.<DOMAIN>`, opsional `9router.<DOMAIN>`).
   - Mendaftarkan setiap aplikasi web existing (`PHP/Laravel`, `PHP Native`, `Proxy Port`, `Static`) beserta database terkait.
   - Menghasilkan file virtual host Nginx bersih di `/etc/nginx/sites-available/`, mengatur ACL `/home/project` untuk `10001` (`hermes`) & `codeserver`, mencetak perintah `certbot --nginx`, serta menyimpan manifest ke `/opt/hermes/data/shared/reports/migration-manifest.md`.

---

## Fase 4 — Restore Selektif Data Penting ke Struktur Bersih

Masukkan kembali **hanya data yang memang dibutuhkan** dari `${BACKUP_DIR}` atau `INVENTORY.txt` ke lokasi standar AI-V1:

1. **Aplikasi Web Produksi -> `/home/project/<nama-app>`:**
   - Ekstrak hanya aplikasi yang aktif (buang folder backup/tes/sampah) ke `/home/project/<nama-app>`.
   - Pastikan masing-masing folder memiliki `.git`, `.gitignore` (mengabaikan `.env`), dan `AGENTS.md`.
   - Terapkan izin akses bersama `www-data` + `UID 10001` via ACL:
     ```bash
     sudo setfacl -R -m u:10001:rwX,d:u:10001:rwX /home/project
     ```
2. **Database Produksi:**
   - Data MySQL tetap utuh (atau restore database spesifik dari `${BACKUP_DIR}/db/all-databases.sql.gz` bila diperlukan).
   - Buat user MySQL non-root baru untuk tim agent (`<DB_AGENT_USER>`) dengan izin terbatas hanya ke DB proyek terkait.
3. **Nginx & SSL Bersih (1 File per Subdomain):**
   - Buat file konfigurasi bersih di `/etc/nginx/sites-available/<nama-app>` (beserta `hermes`, `9router`, dan `vps-monitor`), symlink ke `sites-enabled/`, jalankan `sudo nginx -t`, lalu aktifkan SSL (`certbot --nginx -d <subdomain> --redirect`), dan jalankan `sudo systemctl start nginx`.
4. **Data Runtime Hermes Lama (Opsional):**
   - Jika ingin mempertahankan histori `state.db` atau `skills/` dari backup `${BACKUP_DIR}/hermes-old/`, salin hanya file yang bersih ke `/opt/hermes/data/`, ubah seluruh path `/root/.hermes` -> `/opt/data`, lalu `sudo chown -R 10001:10001 /opt/hermes/data`.

---

## Fase 5 — Audit Kebersihan Struktur (*Zero Stray Folders Checklist*)

- [ ] Tidak ada lagi folder Hermes lama di `/root/.hermes` atau folder proyek liar di `/var/www` / `/root`.
- [ ] `ls -la /opt` hanya berisi folder resmi (`hermes`, `vps-dashboard`, `code-server`, `9router` bila di `/opt`).
- [ ] `https://code.<DOMAIN>` membuka workspace `/home/project` dengan user non-root `codeserver` tanpa membuat file config editor di dalam `/home/project`.
- [ ] `ls -la /home/project` hanya berisi folder aplikasi aktif yang rapi (masing-masing berbasis Git).
- [ ] `ls -la /etc/nginx/sites-enabled` hanya berisi symlink layanan aktif yang semuanya sudah HTTPS (`certbot`).
- [ ] `docker compose -f /opt/hermes/docker-compose.yml ps` menunjukkan `hermes-gateway` & `hermes-dashboard` `Up (healthy)` tanpa error `Running as ROOT` atau `Conflict: getUpdates`.
- [ ] Folder `${BACKUP_DIR}` (`INVENTORY.txt` + arsip `db/`, `web/`, `system/`, `hermes-old/`) tersimpan aman dengan `chmod 700` dan sudah disalin ke *off-site* sebelum dihapus dari VPS setelah masa observasi selesai.
