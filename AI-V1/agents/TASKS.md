# Catatan Tugas Tim Agent Otonom AI-V1 (Master Task Board)

Dokumen ini menjadi panduan tugas awal (*bootstrap*), tugas operasional rutin, dan pipeline kerja pengembangan yang langsung dieksekusi tim agent setelah setup di VPS selesai.

> **Koordinator Utama:** `pm-lead` (`00-pm-coordinator`) bertanggung jawab memecah tugas, memantau status, menjaga batas kredensial, dan melaporkan ringkasan ke Admin VPS melalui Telegram/Dashboard.
> **Kewajiban Worklog Dashboard:** Setiap agent **wajib** mencatat pekerjaan yang *Sedang Dikerjakan* (`active_work`) dan *Sudah Dikerjakan* (`completed_work` + `project_statuses`) di `/opt/data/shared/tasks/worklog.json` serta mengubah `[ ]` menjadi `[x]` di file ini agar langsung terlihat di VPS Monitor Dashboard.

---

## Fase 1 — Bootstrap & Verifikasi Infrastruktur Awal (Sekali Saat Setup)

> **Catatan VPS Existing:** Jika diimplementasikan pada VPS yang sudah memiliki aplikasi web/DB/Hermes aktif, Admin wajib menyelesaikan **Fase 0 & Fase 1** di [`../MIGRATION_EXISTING_VPS.md`](../MIGRATION_EXISTING_VPS.md) (backup DB, web, Nginx, SSL, & data Hermes lama) sebelum `BOOT-01`.

| ID | Tugas | PIC Agent | Dependensi | Definisi Selesai (DoD) | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `BOOT-01` | Verifikasi seluruh profil agent terpasang di `/opt/data/profiles/` dengan `UID 10001` dan `telegram.enabled: false` kecuali `pm-lead` | `pm-lead` | Setup container Hermes | Semua folder profil terbaca, nol konflik `getUpdates` di log gateway | `[ ]` |
| `BOOT-02` | Inventarisasi kredensial & buat `access-ledger.md` di `/opt/data/credentials/` tanpa plaintext secret | `pm-lead` | `/opt/hermes/data/.env` terisi | Daftar kredensial aktif terdata, permission folder `700` milik `10001` | `[ ]` |
| `BOOT-03` | Audit kesehatan VPS baseline: `hermes-gateway`, `hermes-dashboard`, `9Router (:20128)`, RAM (`free -h`), disk (`<70%`), log rotation Docker | `ops-sysadmin` | `BOOT-01` | Laporan baseline tersimpan di `/opt/data/shared/reports/baseline-infra.md` | `[ ]` |
| `BOOT-04` | Uji akses DB non-root MySQL, verifikasi mount `/opt/data/backups/apps` berstatus read-only (`:ro`), dan cek skrip backup host | `ops-backup-dba` | `BOOT-02` | Query `SELECT 1` sukses dengan user non-root; tulis ke `/opt/data/backups/apps` gagal (`Read-only file system`) | `[ ]` |
| `BOOT-05` | Audit keamanan awal: cek `Running as ROOT`, cek secret bocor di `/workspace`, validasi `dashboard.basic_auth` & SSL domain `hermes.<DOMAIN>` | `ops-secops` | `BOOT-01` | Laporan audit keamanan nol temuan kritikal | `[ ]` |
| `BOOT-06` | Pindai seluruh proyek eksisting di `/workspace/` (status Git, stack teknologi, ketersediaan `.env.example` & test suite) | `dev-architect` | `BOOT-01` | Peta arsitektur aplikasi `/workspace` terdokumentasi di `/opt/data/shared/reports/workspace-map.md` | `[ ]` |
| `BOOT-07` | Verifikasi slot plugin `office-3d` terpasang di `/opt/data/desktop-plugins/office-3d` (`hermes plugins install office-3d`) dan seluruh 7 profil agent tampil tanpa duplikasi plugin auth di `profiles/*/config.yaml` | `pm-lead` | `BOOT-01` | Plugin `office-3d` aktif di launch scope utama & dashboard merespons normal | `[ ]` |

---

## Fase 2 — Tugas Rutin Otonom Tim Operasional (`ops`)

| ID | Tugas Rutin | PIC Agent | Jadwal / Trigger | Output / Artefak | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `OPS-01` | Cek health container, penggunaan CPU/RAM/disk (`alert` jika disk >= `70%` atau RAM >= `85%`), dan respon endpoint `9Router` (`:20128`) | `ops-sysadmin` | Harian (07:00 WIB) & 6-jam check | Ringkasan status harian ke `pm-lead` | `[ ]` |
| `OPS-02` | Verifikasi sertifikat SSL Let's Encrypt seluruh subdomain (`hermes.<DOMAIN>`, `9router.<DOMAIN>`, domain ProjectWeb) minimal H-14 sebelum expired | `ops-sysadmin` | Mingguan (Senin 08:00 WIB) | Laporan masa berlaku SSL | `[ ]` |
| `OPS-03` | Audit harian dump SQL & arsip mingguan di `/opt/data/backups/apps` (cek ukuran file > 0, usia file terbaru, dan kepatuhan retensi 5–7 harian / max 2 mingguan) | `ops-backup-dba` | Harian (07:30 WIB) | Laporan `daily-backup-audit.md` | `[ ]` |
| `OPS-04` | Cek performa & kesehatan tabel MySQL proyek (slow query / ukuran tabel / koneksi idle) menggunakan akun non-root | `ops-backup-dba` | Mingguan (Rabu 09:00 WIB) | Rekomendasi indeks / optimasi ke `dev-architect` via `pm-lead` | `[ ]` |
| `OPS-05` | Pindai repositori `/workspace/*` dan log `/opt/data` untuk mendeteksi kebocoran `.env`/API key, permission melenceng, atau error `401`/`Conflict` | `ops-secops` | Harian (21:00 WIB) & setiap pre-release | Laporan keamanan ke `pm-lead` (alert instan jika ada temuan High/Critical) | `[ ]` |

---

## Fase 3 — Tugas Otonom Tim Development (`dev`)

| ID | Tugas | PIC Agent | Alur Kerja Otonom | Definisi Selesai (DoD) | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `DEV-01` | Standarisasi Git & `AGENTS.md` di setiap subfolder `/workspace/<nama-app>` | `dev-architect` | Pastikan setiap proyek punya branch `main` bersih, `.gitignore` aman, dan aturan larangan `migrate:fresh`/`db:wipe` | Semua repo di `/workspace` memiliki baseline Git & `AGENTS.md` | `[ ]` |
| `DEV-02` | Terima spesifikasi fitur/bugfix dari `pm-lead`, pecah menjadi sub-task teknis & kontrak API/DB | `dev-architect` | Buat spec teknis di `/opt/data/shared/tasks/<ticket-id>.md` | Spec disetujui `pm-lead` dan siap diambil `dev-fullstack` | `[ ]` |
| `DEV-03` | Implementasi fitur/bugfix pada branch kerja terpisah (`feat/...` atau `fix/...`) di `/workspace/<nama-app>` | `dev-fullstack` | Coding, buat migrasi DB inkremental yang aman, lengkapi unit/feature test, jangan sentuh `.env` produksi | Kode ter-commit di feature branch, `.env` tidak ikut ter-commit | `[ ]` |
| `DEV-04` | Review arsitektur & kualitas kode hasil `dev-fullstack` | `dev-architect` | Cek diff Git, query N+1, validasi input, dan keamanan | Approval teknis sebelum masuk tahap QA | `[ ]` |
| `DEV-05` | Jalankan automated test, smoke test endpoint HTTP, cek regresi, dan pastikan siap rollback | `dev-qa` | Uji di lingkungan aman; serahkan checklist rilis ke `pm-lead` & `ops-secops` | Laporan QA `PASS` tanpa error | `[ ]` |
| `DEV-06` | Minta persetujuan akhir Admin VPS (jika menyentuh produksi/DB/Nginx) dan koordinasikan rilis | `pm-lead` | Gabungkan laporan `dev-qa` + `ops-secops` + verifikasi backup `ops-backup-dba` | Rilis disetujui & tercatat di changelog | `[ ]` |

---

## Aturan Eskalasi Cepat
1. **Level Hijau (Otonom Penuh):** Baca log, audit backup, tulis laporan, jalankan test lokal, buat feature branch, analisis bug.
2. **Level Kuning (Perlu Approval `pm-lead`):** Pemberian akses kredensial scoped proyek baru, merge ke branch `main` staging, restart worker non-gateway.
3. **Level Merah (Wajib Approval Eksplisit Admin VPS via `pm-lead`):**
   - Perubahan konfigurasi host (`/etc/nginx`, `/etc/systemd`, `/etc/ssh`, `ufw`).
   - Migrasi skema DB produksi atau perubahan data massal.
   - Rilis ke domain produksi yang melayani user publik.
   - Rotasi atau pencabutan kredensial master (`TELEGRAM_BOT_TOKEN`, `NINEROUTER_API_KEY`, password DB).

