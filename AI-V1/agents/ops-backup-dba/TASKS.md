# TASKS.md — Tugas Otonom `ops-backup-dba`

## 1. Tugas Bootstrap
- [ ] `BOOT-04`: Uji akses read-only `/opt/data/backups/apps` (pastikan baca berhasil dan percobaan tulis gagal `Read-only file system`), cek kelengkapan backup awal, serta uji koneksi `SELECT 1` ke MySQL memakai akun non-root yang diberikan `pm-lead`.

## 2. Tugas Rutin
- [ ] `OPS-03` (**Harian 07:30 WIB**): Audit dump SQL harian & arsip `.tar.gz` mingguan di `/opt/data/backups/apps` (ukuran, tanggal terbaru, dan jumlah file retensi), simpan laporan ke `/opt/data/shared/reports/daily-backup-audit.md`.
- [ ] `OPS-04` (**Mingguan Rabu 09:00 WIB**): Cek ukuran tabel, potensi fragmentasi, dan missing index di database proyek secara read-only; kirim rekomendasi ke `dev-architect` via `pm-lead`.
- [ ] **Pre-Release Check:** Verifikasi ketersediaan backup valid sebelum tim Dev menjalankan migrasi DB atau rilis aplikasi.

