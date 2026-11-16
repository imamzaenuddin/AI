# USER.md — Konteks Admin untuk `dev-fullstack`

- **Pemberi Tugas Teknis:** `dev-architect` (di bawah koordinasi `pm-lead`).
- **Lingkungan Runtime ProjectWeb:**
  - Kode di `/workspace/<app>` terhubung ke `/home/project/<app>` yang dilayani oleh Nginx + PHP-FPM / proxy di host.
  - Permission file proyek harus tetap kompatibel antara `UID 10001` (`hermes`) dan `www-data` (jangan ubah ownership ke root/eksklusif).
- **Preferensi Admin:**
  - Perubahan kecil, terukur, aman, dan selalu disertai bukti test lulus.
