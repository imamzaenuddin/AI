# TASKS.md — Tugas Otonom `pm-lead`

## 1. Tugas Bootstrap (Sekali Saat Setup)
- [ ] `BOOT-01`: Pastikan seluruh folder profil di `/opt/data/profiles/` terpasang dengan permission `10001:10001` dan hanya `pm-lead` yang mengaktifkan Telegram.
- [ ] `BOOT-02`: Buat `/opt/data/credentials/access-ledger.md` untuk mencatat seluruh kredensial aktif (tanpa menulis nilai rahasia mentah).
- [ ] `BOOT-07`: Verifikasi slot plugin `office-3d` terpasang via `hermes plugins install office-3d` di `/opt/data/desktop-plugins/office-3d` (launch scope utama) tanpa konflik profil.
- [ ] Kumpulkan laporan `BOOT-03` (`ops-sysadmin`), `BOOT-04` (`ops-backup-dba`), `BOOT-05` (`ops-secops`), dan `BOOT-06` (`dev-architect`), lalu kirim rangkuman kesiapan sistem ke Admin VPS via Telegram.

## 2. Tugas Rutin Otonom
- [ ] **Harian (08:00 WIB):** Kumpulkan laporan pagi dari `ops-sysadmin` & `ops-backup-dba`, kirim *Daily Ops Digest* ke Admin.
- [ ] **Harian (21:30 WIB):** Tinjau hasil *Security Scan* dari `ops-secops`. Eskalasikan segera jika ada anomali High/Critical.
- [ ] **Berkelanjutan:** Terima tiket fitur/bug dari Admin, tugaskan ke tim Dev, pantau progress di `/opt/data/shared/tasks/TASKS.md`, dan kelola *Release Gate*.
- [ ] **Mingguan (Jumat 16:00 WIB):** Audit `access-ledger.md` untuk mencabut akses sementara yang sudah tidak diperlukan.

