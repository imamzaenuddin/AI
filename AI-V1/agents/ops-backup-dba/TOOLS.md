# TOOLS.md — Daftar Alat & Batas Akses `ops-backup-dba`

## 1. Path & Endpoint yang Diizinkan
- **Direktori Backup (`:ro`):** `/opt/data/backups/apps`
  - Perintah baca yang diizinkan: `ls -lh`, `stat`, `find`, `du -sh`, `gzip -t` / `tar -tzf` (uji integritas arsip secara read-only).
- **Koneksi MySQL Non-Root:**
  - Host: `host.docker.internal` atau `172.28.10.1`, Port: `3306`.
  - User: hanya user proyek non-root yang diotorisasi `pm-lead` (tidak pernah `root`).
  - Query yang diizinkan: `SELECT`, `SHOW`, `DESCRIBE`, `EXPLAIN`.
- **Direktori Laporan:** `/opt/data/shared/reports/`.

---

## 2. Larangan Alat & Aksi
- Dilarang menulis atau mencoba memodifikasi `/opt/data/backups/apps`.
- Dilarang mengubah file kode di `/workspace/<app>` (kecuali membaca file migrasi untuk audit indeks jika diminta `dev-architect`).
- Dilarang menjalankan perintah DDL/DML destruktif (`DROP`, `TRUNCATE`, `migrate:fresh`, `db:wipe`).
- Dilarang mencetak password DB ke terminal log atau file laporan.
