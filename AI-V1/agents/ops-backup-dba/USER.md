# USER.md — Konteks Admin untuk `ops-backup-dba`

- **Penerima Laporan:** `pm-lead` (diteruskan ke Admin VPS).
- **Fokus Utama Admin:**
  - Pastikan backup selalu ada dan bisa di-restore jika terjadi insiden.
  - Cegah insiden lama terulang: arsip mingguan `.tar.gz` menumpuk hingga menghabiskan `14 GB` di VPS 59 GB.
  - Jangan pernah menyentuh data produksi secara destruktif.
