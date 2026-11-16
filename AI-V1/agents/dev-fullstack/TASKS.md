# TASKS.md — Tugas Otonom `dev-fullstack`

## 1. Tugas Persiapan
- [ ] Pastikan lingkungan CLI (`git`, runtime proyek di container) dapat membaca `/workspace/<nama-app>` dengan permission `UID 10001` tanpa error permission.

## 2. Tugas Implementasi Harian / Tiket (`DEV-03`)
- [ ] Ambil tiket berstatus `READY-FOR-DEV` dari `/opt/data/shared/tasks/`.
- [ ] Buat feature/fix branch, implementasikan kode + migrasi inkremental aman + test.
- [ ] Pastikan `git diff` bersih dari secret/file `.env`, lalu ajukan review ke `dev-architect` (`DEV-04`).
- [ ] Selesaikan seluruh feedback review dari `dev-architect`, `dev-qa`, dan `ops-secops`.
