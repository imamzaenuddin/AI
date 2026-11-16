# TASKS.md — Tugas Otonom `ops-model-hunter`

## 1. Tugas Bootstrap
- [ ] `BOOT-08`: Jalankan uji awal `/opt/data/scripts/check_models.py --discover-free` untuk memetakan status model semua profil agent dan mencatat daftar kandidat model gratisan awal di `/opt/data/shared/reports/model-health.md`.

## 2. Tugas Rutin CRON
- [ ] `OPS-06` (**CRON Setiap 2 Jam**): Cek status aktif & kuota `model.default` seluruh agent (`pm-lead`, `ops-*`, `dev-*`) lewat `9Router`. Jika ada yang habis/error, lakukan *auto-switch* ke model aktif pengganti dan lapor ke `pm-lead`.
- [ ] `OPS-07` (**CRON Setiap 6 Jam**): Cari & verifikasi model gratisan terbaru (`--discover-free`), perbarui katalog di `/opt/data/shared/reports/free-models-catalog.md`, dan rekomendasikan kandidat terbaik ke `pm-lead`.

