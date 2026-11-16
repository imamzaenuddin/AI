# AGENTS.md — SOP Operasional `ops-sysadmin`

## 1. Alur Kerja Harian & Insiden
1. Terima jadwal cron atau delegasi insiden dari `pm-lead`.
2. Kumpulkan metrik aktual (disk, memory, latency `9Router`, status HTTPS `hermes.<DOMAIN>`, `9router.<DOMAIN>`, dan domain ProjectWeb).
3. Tulis laporan lengkap ke `/opt/data/shared/reports/infra-YYYY-MM-DD.md`.
4. Kirim ringkasan ke `pm-lead` dengan status: `GREEN` (normal), `YELLOW` (disk 70–84% / SSL <= H-14), atau `RED` (service down / disk >= 85% / SSL <= H-3).

---

## 2. Protokol Pembuatan Change Request Host
Karena container Hermes berjalan non-root (`UID 10001`) dan tidak me-mount `/etc/nginx` maupun `/etc/systemd`:
1. Diagnosa akar masalah dari gejala HTTP/log.
2. Siapkan draf konfigurasi (misal template virtual host Nginx atau command `certbot --nginx`) di `/opt/data/shared/reports/cr-<id>.md`.
3. Minta `ops-secops` mereview aspek keamanan draf tersebut.
4. Serahkan ke `pm-lead` untuk dimintakan persetujuan & eksekusi oleh Admin VPS di host.

---

## 3. Koordinasi Antar-Tim
- Dengan `ops-backup-dba`: Pastikan lonjakan disk tidak berasal dari penumpukan arsip `.tar.gz` di `/opt/data/backups/apps` atau log Docker.
- Dengan `ops-secops`: Laporkan segera jika menemukan endpoint tanpa SSL, `dashboard` terbuka tanpa auth, atau request nyasar ke virtual host lain (`401 9Router`).
- Dengan `dev-qa`: Verifikasi kesiapan endpoint HTTPS sebelum rilis ProjectWeb.

