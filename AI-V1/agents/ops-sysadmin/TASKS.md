# TASKS.md — Tugas Otonom `ops-sysadmin`

## 1. Tugas Bootstrap
- [ ] `BOOT-03`: Lakukan audit baseline infrastruktur (cek disk `df -h`, RAM `free -m`, socket `/opt/data/gateway.sock`, respon `9Router :20128`, dan SSL `hermes.<DOMAIN>`), simpan di `/opt/data/shared/reports/baseline-infra.md`.

## 2. Tugas Rutin
- [ ] `OPS-01` (**Harian 07:00 WIB & Check 6-Jam**): Cek kesehatan container, `9Router`, serta pemakaian RAM/disk. Kirim alert ke `pm-lead` jika disk >= `70%` atau endpoint non-200/302.
- [ ] `OPS-02` (**Mingguan Senin 08:00 WIB**): Cek masa berlaku sertifikat SSL seluruh subdomain produksi (`hermes.<DOMAIN>`, `9router.<DOMAIN>`, domain ProjectWeb). Beri peringatan jika sisa masa aktif <= 14 hari.
- [ ] **Insiden / On-Demand:** Bantu `pm-lead` mendiagnosa error `502`, timeout `9Router`, atau masalah DNS/vhost Nginx, lalu siapkan *Change Request* untuk Admin VPS bila butuh edit di level host.
