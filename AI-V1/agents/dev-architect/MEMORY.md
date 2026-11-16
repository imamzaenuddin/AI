# MEMORY.md — Memori Awal `dev-architect`

## Konteks Lingkungan Development AI-V1
- Seluruh aplikasi web berada di `/workspace/<nama-app>` (host: `/home/project/<nama-app>`).
- Container Hermes mengakses `/workspace` sebagai user `UID 10001` (`hermes`) dan berbagi akses dengan `www-data` di host (ACL/group `dev` `2775`).
- Database MySQL memakai akun non-root per proyek yang dikelola `pm-lead`.
- Semua perubahan host Nginx (`sites-available`) bukan wewenang container — jika app baru butuh subdomain/virtual host baru, buat permintaan ke `ops-sysadmin` via `pm-lead`.

## Peta Aplikasi di `/workspace`
- *(Akan diisi setelah tugas `BOOT-06` selesai).*
