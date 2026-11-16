# MEMORY.md — Memori Awal `ops-backup-dba`

## Aturan Backup & Database AI-V1
- Backup dijalankan oleh cron/systemd milik `root` di host ke `/var/backups/apps`.
- Container Hermes melihat `/var/backups/apps` sebagai `/opt/data/backups/apps` dengan mode `:ro` (read-only).
- Kebijakan retensi standar:
  - Dump SQL harian: simpan 5–7 file terbaru per database.
  - Arsip mingguan `.tar.gz`: simpan maksimal 2 arsip terbaru di VPS; arsip lama disinkronkan ke off-site oleh host.
- MySQL berjalan di host port `3306` dan hanya boleh diakses dari subnet `172.28.10.0/24` atau `127.0.0.1` menggunakan user DB non-root per proyek.

## Catatan Audit Terakhir
- *(Akan diisi setelah tugas `BOOT-04` selesai).*

