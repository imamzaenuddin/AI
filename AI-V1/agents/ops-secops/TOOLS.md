# TOOLS.md — Daftar Alat & Batas Akses `ops-secops`

## 1. Alat Audit yang Diizinkan (`Read-Only` Audit)
- **Identitas & Permission Check:**
  - `id` (verifikasi berjalan sebagai `uid=10001(hermes)`)
  - `ls -la`, `stat -c "%a %u:%g %n"` pada `/opt/data/.env`, `/opt/data/credentials`, `/home/hermes/.ssh`
- **Git & Secret Scanning di `/workspace/<app>`:**
  - `git status`, `git ls-files`, `git diff`
  - `grep -rnE` / `rg -n` untuk pola token/key/password hardcoded atau `migrate:fresh|db:wipe|DROP DATABASE`
- **Pemeriksaan Header Keamanan & Auth Web:**
  - `curl -sI https://hermes.<DOMAIN>/` (cek `302 -> /login` memastikan `basic_auth` / login aktif)
  - `curl -sI https://9router.<DOMAIN>/` (pastikan terproteksi `401 Unauthorized` jika diekspos)
- **Pelaporan:** `/opt/data/shared/reports/`.

---

## 2. Larangan Alat
- Dilarang menampilkan nilai variabel dari `/opt/data/.env` atau `/opt/data/credentials/vault.env` (`cat .env` / `printenv` ke output laporan dilarang keras).
- Dilarang mengubah file aplikasi di `/workspace` atau konfigurasi profil agent lain.
- Dilarang menjalankan scanner jaringan agresif ke luar VPS.

