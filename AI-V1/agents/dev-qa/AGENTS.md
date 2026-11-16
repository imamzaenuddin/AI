# AGENTS.md — SOP Pengujian & Release Gate `dev-qa`

## 1. Alur Verifikasi Tiket (`DEV-05`)
1. Ambil tiket yang sudah berstatus `TECH-APPROVED` dari `dev-architect`.
2. Periksa daftar kriteria penerimaan (*Acceptance Criteria*) di `/opt/data/shared/tasks/<ticket-id>.md`.
3. Jalankan pengujian di lingkungan non-produksi:
   - Automated unit & feature test suite proyek.
   - Uji kasus positif, negatif, validasi input, dan hak akses (otorisasi).
   - Verifikasi jika ada migrasi DB baru: cek migrasi berjalan bersih tanpa `migrate:fresh`/`db:wipe` dan punya jalur rollback.
4. Lakukan smoke test HTTP endpoint (`curl -sI` / `curl` read-only) jika tersedia lingkungan staging/preview.
5. Catat hasil aktual pengujian (jumlah test passed/failed, output singkat, temuan bug bila ada) ke `/opt/data/shared/reports/qa-<ticket-id>.md`.

---

## 2. Keputusan QA & Koordinasi Release Gate (`DEV-06`)
- **Jika `FAIL`:** Kembalikan tiket ke `dev-fullstack` dengan langkah reproduksi yang jelas, dan beri tahu `pm-lead`.
- **Jika `PASS`:**
  1. Pastikan `ops-secops` telah mengeluarkan `SEC-PASS`.
  2. Pastikan `ops-backup-dba` mengonfirmasi `BACKUP READY` (khusus tiket yang menyentuh DB/produksi).
  3. Serahkan paket laporan `QA-PASS` + rencana rollback ke `pm-lead` untuk dimintakan approval rilis ke Admin VPS.


---

## 3. Kewajiban Pencatatan Worklog Dashboard
- Saat mulai pengujian dan setelah hasil QA (`PASS`/`FAIL`) keluar, wajib mencatat status *Sedang Dikerjakan* (`active_work`) dan *Sudah Dikerjakan* (`completed_work` + `project_statuses`) di `/opt/data/shared/tasks/worklog.json` serta memperbarui `/opt/data/shared/tasks/TASKS.md` agar terlihat langsung di VPS Monitor Dashboard.
