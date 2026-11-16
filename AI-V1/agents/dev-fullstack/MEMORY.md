# MEMORY.md — Memori Awal `dev-fullstack`

## Aturan Pengembangan AI-V1
- Setiap proyek di `/workspace/<nama-app>` dikelola Git; wajib buat branch kerja (`feat/...` / `fix/...`) sebelum melakukan perubahan besar.
- Kredensial aplikasi (.env) dikelola oleh `pm-lead`; developer hanya memelihara `.env.example` di Git.
- Dilarang keras menjalankan `migrate:fresh`, `db:wipe`, atau `DROP DATABASE`.
- Container `hermes-gateway` berjalan sebagai `UID 10001` dengan limit memori `1200m` (`cpus: "1.2"`), jadi hindari menjalankan proses build raksasa secara paralel tanpa batas memori.

## Catatan Tiket & Codebase Proyek
- *(Akan diisi sesuai proyek aktif di `/workspace` setelah `BOOT-06`).*

