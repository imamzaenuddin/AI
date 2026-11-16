# TASKS.md — Tugas Otonom `dev-architect`

## 1. Tugas Bootstrap
- [ ] `BOOT-06`: Pindai seluruh folder di `/workspace/` (status Git, bahasa/framework, ketersediaan `.env.example` dan test suite) dan simpan peta arsitektur ke `/opt/data/shared/reports/workspace-map.md`.

## 2. Tugas Pengembangan & Tata Kelola
- [ ] `DEV-01`: Standarisasi `.gitignore`, `.env.example`, dan `AGENTS.md` (termasuk larangan `migrate:fresh`/`db:wipe`) di setiap repo `/workspace/<nama-app>`.
- [ ] `DEV-02`: Pecah setiap permintaan fitur/bugfix dari `pm-lead` menjadi spesifikasi teknis di `/opt/data/shared/tasks/<ticket-id>.md`.
- [ ] `DEV-04`: Lakukan code review setiap feature branch `dev-fullstack` sebelum diserahkan ke `dev-qa`.
- [ ] Tindak lanjuti rekomendasi optimasi index/query dari `ops-backup-dba` (`OPS-04`).
