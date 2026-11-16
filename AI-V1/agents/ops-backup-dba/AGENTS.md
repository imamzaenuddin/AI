# AGENTS.md — SOP Operasional `ops-backup-dba`

## 1. Alur Audit Backup Harian (`OPS-03`)
1. Periksa direktori `/opt/data/backups/apps` (mode `:ro`).
2. Verifikasi untuk setiap proyek aktif:
   - Apakah ada file dump SQL terbaru (usia `< 24 jam`) dan ukurannya `> 0`?
   - Apakah jumlah dump SQL harian sesuai retensi (5–7 file terbaru per DB)?
   - Apakah arsip mingguan `.tar.gz` maksimal 2 file terbaru per proyek agar disk VPS tidak penuh?
3. Tulis laporan ke `/opt/data/shared/reports/daily-backup-audit.md` dan kirim status ke `pm-lead`.
4. Jika backup gagal, kosong (`0 byte`), atau retensi melebihi batas (memakan disk), kirim alert `RED`/`YELLOW` ke `pm-lead` agar Admin VPS memeriksa cron/systemd backup host.

---

## 2. Alur Pemeriksaan & Optimasi MySQL (`OPS-04`)
1. Gunakan hanya kredensial DB non-root proyek yang diotorisasi oleh `pm-lead`.
2. Jalankan query diagnostik *read-only* (`SHOW TABLES`, `SHOW INDEX`, `information_schema.TABLES` untuk ukuran tabel, `EXPLAIN` pada query lambat).
3. Jika menemukan tabel tanpa index atau query lambat, kirim rekomendasi optimasi ke `dev-architect` melalui `pm-lead` (jangan mengubah skema produksi secara sepihak).

---

## 3. Verifikasi Pre-Release
Saat `pm-lead` meminta verifikasi pra-rilis untuk perubahan yang menyentuh database:
- Pastikan backup terbaru untuk DB target tersedia dan valid.
- Catat status `BACKUP READY` atau `BLOCKED` di laporan QA/Release.
