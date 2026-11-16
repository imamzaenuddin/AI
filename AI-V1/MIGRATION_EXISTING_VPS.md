# Standar Setup AI-V1 pada VPS dengan Data Existing (Pre-Migration & Backup Runbook)

Dokumen ini adalah aturan wajib apabila arsitektur **AI-V1** diimplementasikan pada **VPS yang sudah aktif dan memiliki data existing** (website berjalan, database produksi, virtual host Nginx, sertifikat SSL, `9Router`, atau instalasi Hermes/bot Telegram lama).

> **Prinsip Utama Setup Data Existing:**
> 1. **Wajib Backup Penuh Sebelum Menyentuh Apa Pun.** Tidak ada perintah modifikasi sistem, database, permission, atau service sebelum backup terverifikasi valid.
> 2. **Non-Destructive & Side-by-Side:** Layanan baru (Docker Hermes non-root `UID 10001`, virtual host baru, user DB baru) dipasang berdampingan tanpa menimpa konfigurasi aplikasi yang sedang live.
> 3. **Dual-Access Permission Aman:** Jangan pernah menjalankan `chown -R 10001:10001` pada folder web yang sedang dilayani `www-data` / PHP-FPM. Gunakan ACL atau grup bersama.

---

## Fase 0 — Audit & Inventarisasi Pra-Migrasi (Read-Only, Nol Perubahan)

Jalankan perintah inspeksi berikut untuk memetakan kondisi VPS sebelum melakukan perubahan:

```bash
# 1. Cek kapasitas disk & RAM (pastikan ruang kosong cukup untuk backup + Docker image; target < 70%)
df -h
free -h

# 2. Cek proses aktif (Hermes lama, bot Telegram, 9Router, Nginx, MySQL, PHP-FPM)
ps aux | grep -E 'hermes|9router|python|node|nginx|mysql|mariadb|php-fpm'
ss -tulpn

# 3. Inventarisasi virtual host Nginx & sertifikat SSL aktif
ls -la /etc/nginx/sites-enabled/
sudo nginx -T 2>/dev/null | grep -E 'server_name|root |proxy_pass'
sudo certbot certificates 2>/dev/null || true

# 4. Cek lokasi & ukuran folder project / web existing
ls -la /home/project /var/www 2>/dev/null || true
du -sh /home/project/* /var/www/* /var/backups/* 2>/dev/null || true
```

> **Gate Kapasitas Disk:** Jika penggunaan disk VPS sudah `>= 75%` sebelum setup, **hentikan proses setup** dan bersihkan/arsipkan off-site file lama atau log besar terlebih dahulu agar proses backup dan build Docker tidak kehabisan disk.

---

## Fase 1 — Backup Wajib Sebelum Setup (*Pre-Migration Snapshot*)

Buat satu folder khusus pra-migrasi di luar `/home/project` dan `/opt/hermes`:

```bash
BACKUP_TAG="pre-migration-$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/var/backups/apps/${BACKUP_TAG}"
sudo mkdir -p "${BACKUP_DIR}"/{db,web,system,hermes-old}
sudo chmod 700 "${BACKUP_DIR}"
```

### 1. Backup Seluruh Database MySQL / MariaDB
```bash
# Full dump semua database (non-locking untuk InnoDB)
sudo mysqldump --single-transaction --routines --triggers --events --all-databases \
  | gzip > "${BACKUP_DIR}/db/all-databases.sql.gz"

# Verifikasi integritas file gzip & pastikan dump selesai sempurna
gzip -t "${BACKUP_DIR}/db/all-databases.sql.gz"
zcat "${BACKUP_DIR}/db/all-databases.sql.gz" | tail -n 5
# Output terakhir wajib mengandung: "-- Dump completed"
```

### 2. Backup Source Code & File Aplikasi Web Existing
```bash
# Sesuaikan path web existing di VPS (/home/project dan/atau /var/www)
[ -d /home/project ] && sudo tar -czpf "${BACKUP_DIR}/web/home-project.tar.gz" /home/project
[ -d /var/www ] && sudo tar -czpf "${BACKUP_DIR}/web/var-www.tar.gz" /var/www

# Verifikasi arsip terbaca
sudo tar -tzf "${BACKUP_DIR}/web/home-project.tar.gz" >/dev/null && echo "Archive OK"
```

### 3. Backup Konfigurasi Inti Host (`/etc/nginx`, `/etc/letsencrypt`, `/etc/systemd`, `/etc/ssh`)
```bash
sudo tar -czpf "${BACKUP_DIR}/system/etc-nginx.tar.gz" /etc/nginx
[ -d /etc/letsencrypt ] && sudo tar -czpf "${BACKUP_DIR}/system/etc-letsencrypt.tar.gz" /etc/letsencrypt
sudo tar -czpf "${BACKUP_DIR}/system/etc-systemd-system.tar.gz" /etc/systemd/system
sudo cp /etc/ssh/sshd_config "${BACKUP_DIR}/system/sshd_config.bak"
```

### 4. Backup Data Hermes / Bot Lama (Jika Sebelumnya Sudah Terpasang)
```bash
# Contoh jika sebelumnya berjalan di /root/.hermes atau ~/.hermes
[ -d /root/.hermes ] && sudo tar -czpf "${BACKUP_DIR}/hermes-old/root-hermes.tar.gz" /root/.hermes
[ -d /opt/hermes ] && sudo tar -czpf "${BACKUP_DIR}/hermes-old/opt-hermes-old.tar.gz" /opt/hermes
```

### 5. Snapshot VPS / Salinan Off-Site (Sangat Disarankan)
- Buat **VPS Snapshot** dari panel provider cloud sebelum memulai Fase 2, atau salin `${BACKUP_DIR}` ke penyimpanan luar VPS (lokal admin / S3 / Google Drive via `rclone`) agar tetap aman jika terjadi kesalahan tingkat host.

---

## Fase 2 — Aturan Standar Penanganan Data Existing

### A. Aturan Folder ProjectWeb Existing (`/home/project` atau `/var/www`)
1. **Jangan Rusak Ownership Web Server:**
   - **DILARANG** menjalankan `chown -R 10001:10001 /home/project` karena akan membuat `www-data` (Nginx / PHP-FPM) gagal membaca/menulis cache, session, atau upload aplikasi yang sudah live.
   - Gunakan **ACL** agar user `10001` (`hermes`) dan `www-data` bisa berbagi akses tanpa bentrok:
     ```bash
     sudo apt-get update && sudo apt-get install -y acl
     sudo setfacl -R -m u:10001:rwX,d:u:10001:rwX /home/project
     ```
     *(Atau gunakan grup bersama `dev` yang beranggotakan `www-data` dan `hermes` dengan `chmod 2775`.)*
2. **Jangan Pindahkan Folder Web yang Sedang Live Secara Mendadak:**
   - Jika aplikasi existing berada di `/var/www/<app>`, biarkan tetap di `/var/www/<app>` terlebih dahulu atau siapkan symlink/cutover Nginx terencana. Hanya mount folder yang memang dikelola tim agent ke `/workspace`.
3. **Wajib Git Baseline Sebelum Agent Bekerja:**
   - Untuk setiap aplikasi existing di `/home/project/<app>`:
     ```bash
     cd /home/project/<app>
     git status
     # Jika belum ada Git atau ada perubahan lokal yang belum di-commit:
     # Simpan commit baseline dulu sebelum agent membuat feature branch.
     ```
   - Pastikan `.env` produksi sudah tercantum di `.gitignore` sebelum agent mengakses `/workspace/<app>`.

### B. Aturan Database Existing (MySQL / MariaDB)
1. **Jangan Gunakan User DB Aplikasi Existing atau `root`:**
   - Biarkan aplikasi produksi tetap memakai user DB existing-nya.
   - Buat user DB **baru khusus agent** (`<DB_AGENT_USER>`) dengan hak akses terbatas hanya untuk database yang diizinkan (atau lebih aman: kloning dulu ke database staging `<NAMA_DB>_staging` untuk pengembangan awal).
2. **Larangan Mutlak:**
   - Jangan pernah mengizinkan `dev-fullstack` atau agent lain menjalankan `migrate:fresh`, `db:wipe`, atau `DROP DATABASE` pada database existing.

### C. Aturan Nginx & SSL Existing
1. **Jangan Timpa Konfigurasi Default atau Website Live:**
   - Tambahkan file virtual host baru secara terpisah di `/etc/nginx/sites-available/hermes` (dan `9router` bila diekspos).
   - Selalu jalankan `sudo nginx -t` sebelum `sudo systemctl reload nginx`.
2. **Cegah Error `SEC_E_WRONG_PRINCIPAL` / Fallthrough ke Vhost Lain:**
   - Pastikan DNS subdomain (`hermes.<DOMAIN>`) diarahkan hanya setelah virtual host + sertifikat `certbot --nginx -d hermes.<DOMAIN>` dibuat.

### D. Aturan Migrasi Hermes / Bot Telegram Existing (Zero-Conflict Cutover)
Jika sebelumnya Hermes atau bot Telegram sudah berjalan langsung di host (misal sebagai `root` atau `systemd --user`):
1. **Salin data runtime lama ke `/opt/hermes/data`** (jangan jalankan container dulu):
   - Salin `state.db`, `skills/`, `cron/`, dan konfigurasi relevan ke `/opt/hermes/data/`, lalu `sudo chown -R 10001:10001 /opt/hermes/data`.
   - Periksa dan ubah semua path hardcoded `/root/.hermes/...` menjadi `/opt/data/...` dan `/home/project/...` menjadi `/workspace/...`.
2. **Hentikan total proses/service lama sebelum menyalakan container:**
   ```bash
   sudo systemctl stop hermes-gateway 2>/dev/null || true
   sudo systemctl disable hermes-gateway 2>/dev/null || true
   pgrep -af hermes
   # Pastikan tidak ada proses polling Telegram lama yang masih hidup!
   ```
3. **Baru jalankan container baru:**
   ```bash
   docker compose -f /opt/hermes/docker-compose.yml up -d
   ```

### E. Aturan Hardening SSH pada VPS Aktif
- Sebelum mengatur `PasswordAuthentication no` di `/etc/ssh/sshd_config`, **wajib uji login SSH Key di tab terminal baru** sambil tetap mempertahankan sesi terminal aktif yang lama terbuka sebagai cadangan.

---

## Fase 3 — Checklist Verifikasi & Prosedur Rollback Darurat

### Checklist Pasca-Migrasi VPS Existing
- [ ] Seluruh website & database existing tetap merespons `HTTP 200` tanpa error permission (`www-data` masih bisa baca/tulis cache & storage).
- [ ] `docker compose ps` menunjukkan `hermes-gateway` dan `hermes-dashboard` berstatus `Up (healthy)` sebagai `UID 10001`.
- [ ] Log `hermes-gateway` bersih dari `Running as ROOT` dan `Conflict: terminated by other getUpdates request`.
- [ ] Agen dapat membaca/menulis `/workspace/<app>` tetapi **gagal menulis** ke `/opt/data/backups/apps` (`Read-only file system`).
- [ ] Folder backup `${BACKUP_DIR}` utuh, terverifikasi, dan tidak terhapus oleh retensi harian.

### Prosedur Rollback Cepat (Jika Terjadi Gangguan pada Layanan Existing)
1. Hentikan stack Docker Hermes baru:
   ```bash
   docker compose -f /opt/hermes/docker-compose.yml down
   ```
2. Jika ada perubahan Nginx yang bermasalah, pulihkan dari backup:
   ```bash
   sudo tar -xzpf "${BACKUP_DIR}/system/etc-nginx.tar.gz" -C /
   sudo nginx -t && sudo systemctl reload nginx
   ```
3. Jika sebelumnya memakai service Hermes/bot lama, jalankan kembali service lama sementara investigasi dilakukan.
4. Jika terjadi perubahan tak terduga pada database, pulihkan dari `${BACKUP_DIR}/db/all-databases.sql.gz` (atau dump per database terkait).

