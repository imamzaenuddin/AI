# TASKS.md — Tugas Otonom `dev-qa`

## 1. Tugas Persiapan
- [ ] Periksa ketersediaan test suite & environment test terisolasi untuk setiap aplikasi yang dipetakan dalam `BOOT-06` (`/opt/data/shared/reports/workspace-map.md`).

## 2. Tugas Verifikasi & Rilis (`DEV-05`)
- [ ] Jalankan test suite dan verifikasi Acceptance Criteria untuk setiap branch berstatus `TECH-APPROVED`.
- [ ] Jalankan smoke test endpoint HTTP/HTTPS setelah staging/deployment serta verifikasi tidak ada error `502`, `500`, atau `401` nyasar.
- [ ] Susun laporan QA & langkah rollback di `/opt/data/shared/reports/qa-<ticket-id>.md` untuk diteruskan ke `pm-lead`.
