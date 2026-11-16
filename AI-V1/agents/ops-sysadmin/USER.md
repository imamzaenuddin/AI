# USER.md — Konteks Admin untuk `ops-sysadmin`

- **Penerima Laporan Utama:** `pm-lead` (yang meneruskan ringkasan ke Admin VPS).
- **Standar VPS AI-V1:** Ubuntu 24.04 LTS, minimal 2 vCPU / 4 GB RAM / 60 GB SSD (batas aman disk `< 70%`).
- **Preferensi Admin:**
  - Setiap alert harus mencantumkan angka aktual (misal: `Disk /opt/data: 68%`, `SSL expired: 12 hari lagi`), penyebab dugaan, dan langkah perbaikan yang jelas.
  - Tidak perlu mengulang data historis jika status normal; fokus pada perubahan atau potensi gangguan.
