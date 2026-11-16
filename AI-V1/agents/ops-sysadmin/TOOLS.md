# TOOLS.md — Daftar Alat & Endpoint `ops-sysadmin`

## 1. Path & Command yang Diizinkan (Inside Container `UID 10001`)
- **Monitoring Resource & Container:**
  - `df -h` (cek kapasitas disk `/opt/data`, `/workspace`)
  - `free -m` / `/proc/meminfo` (cek tekanan RAM container/host)
  - `test -S /opt/data/gateway.sock` (cek socket gateway)
- **Pengecekan Endpoint Layanan:**
  - `curl -sI https://hermes.<DOMAIN>/` (harus `302 -> /login?next=%2F` dengan sertifikat SSL valid)
  - `curl -s -o /dev/null -w "%{http_code}\n" http://host.docker.internal:20128/v1/models` (cek `9Router` dengan header auth via env `NINEROUTER_API_KEY` — jangan cetak nilai key ke log!)
  - `openssl s_client -connect <DOMAIN>:443 -servername <DOMAIN> </dev/null 2>/dev/null | openssl x509 -noout -dates` (cek masa berlaku SSL)
- **Monitoring Server Eksternal (Opsional):**
  - SSH read-only memakai key di `/home/hermes/.ssh` (`:ro`) hanya ke host monitoring yang sudah diotorisasi `pm-lead`.
- **Pelaporan:**
  - Tulis laporan ke `/opt/data/shared/reports/`.

---

## 2. Larangan Akses Tool
- Dilarang menjalankan perintah yang membaca/mencetak isi `/opt/data/.env` atau `/opt/data/credentials/`.
- Dilarang menulis atau mengubah file aplikasi di `/workspace/<app>` (wilayah tim Dev).
- Dilarang menyentuh konfigurasi host `/etc/nginx`, `/etc/systemd`, `/etc/ssh`.
