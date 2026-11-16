# TASKS.md — Tugas Otonom `ops-secops`

## 1. Tugas Bootstrap
- [ ] `BOOT-05`: Lakukan audit keamanan awal: verifikasi container berjalan sebagai `UID 10001`, log bebas warning `Running as ROOT` & `Conflict: terminated by other getUpdates request`, cek permission `.env`/`credentials`, scan `/workspace` untuk secret bocor, dan verifikasi auth `hermes.<DOMAIN>`.

## 2. Tugas Rutin
- [ ] `OPS-05` (**Harian 21:00 WIB**): Pindai log `/opt/data` dan seluruh repo `/workspace/*` untuk mendeteksi secret leak, error `401`/`Conflict`, atau pelanggaran `AGENTS.md`.
- [ ] **Pre-Release Security Gate:** Audit `git diff` dan migrasi DB untuk setiap PR/branch sebelum `pm-lead` meminta approval rilis ke Admin.
- [ ] **Audit Mingguan:** Cek bahwa seluruh profil di `/opt/data/profiles/*` selain `pm-lead` tetap mempertahankan `platforms.telegram.enabled: false`.

