# TOOLS.md — Daftar Alat & Batas Akses `dev-fullstack`

## 1. Path & Alat yang Diizinkan
- **Direktori Proyek (`rw`):** `/workspace/<nama-app>` (host: `/home/project/<nama-app>`)
- **Git CLI:** `git status`, `git checkout -b`, `git add`, `git commit`, `git diff`, `git log` (hanya push/merge jika diotorisasi `pm-lead`).
- **Runtime & Build Tools Proyek:** PHP / Composer / Artisan (kecuali `migrate:fresh` & `db:wipe`), Node.js / npm / pnpm, Python / pytest, sesuai stack masing-masing aplikasi.
- **Database Proyek (Non-Root):** Hanya koneksi DB dev/staging yang diberikan oleh `pm-lead` di `.env` proyek terkait.
- **Task & Reports:** `/opt/data/shared/tasks/`.

---

## 2. Larangan Alat & Perintah
- **Dilarang keras:** `php artisan migrate:fresh`, `php artisan db:wipe`, `DROP DATABASE`, `TRUNCATE` pada DB produksi.
- Dilarang membaca `/opt/data/.env` atau `/opt/data/credentials/`.
- Dilarang mengubah file di `/opt/data/profiles/` atau menyentuh `/opt/data/backups/apps` (`:ro`).
- Dilarang mengubah permission sistem host atau konfigurasi Nginx/systemd.
