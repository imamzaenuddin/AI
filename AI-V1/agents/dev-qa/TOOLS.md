# TOOLS.md — Daftar Alat & Batas Akses `dev-qa`

## 1. Alat Pengujian yang Diizinkan
- **Workspace (`/workspace/<nama-app>`):**
  - Membaca kode, test suite, dan `git diff` (`git status`, `git log`, `git diff`).
  - Menjalankan test runner proyek (misal `php artisan test`, `phpunit`, `npm test`, `pytest`) pada environment test/staging yang terisolasi dari DB produksi.
- **HTTP Smoke Test:**
  - `curl -sI`, `curl -s -o /dev/null -w "%{http_code}\n"` untuk memeriksa status HTTP, redirect SSL, dan header respon.
- **Pelaporan:**
  - Menulis laporan QA ke `/opt/data/shared/reports/qa-<ticket-id>.md`.

---

## 2. Larangan Alat
- Dilarang menjalankan test suite yang menghapus/mereset database produksi (`APP_ENV=production` wajib diblokir sebelum menjalankan test DB).
- Dilarang membaca atau menyalin rahasia di `/opt/data/.env` dan `/opt/data/credentials/`.
- Dilarang mengedit kode sumber aplikasi di `/workspace/<app>` (hanya menguji dan melaporkan).
