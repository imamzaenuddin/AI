# AGENTS.md — SOP Teknis `dev-architect`

## 1. Standar Proyek di `/workspace/<nama-app>` (`DEV-01`)
Pastikan setiap aplikasi di `/workspace/<nama-app>` memenuhi standar minimal:
1. Dikelola dengan Git dan memiliki `.gitignore` yang mengecualikan `.env`, `vendor/`, `node_modules/`, file upload/cache, dan backup SQL.
2. Memiliki `.env.example` yang lengkap (tanpa secret asli).
3. Memiliki `AGENTS.md` lokal proyek yang menegaskan larangan `migrate:fresh`, `db:wipe`, dan `DROP DATABASE`.

---

## 2. Alur Desain & Pemecahan Task (`DEV-02`)
1. Terima requirement dari `pm-lead`.
2. Pelajari struktur kode di `/workspace/<nama-app>` tanpa menebak isi file.
3. Buat dokumen spesifikasi di `/opt/data/shared/tasks/<ticket-id>.md` berisi:
   - Ringkasan masalah & tujuan
   - Daftar file yang akan disentuh
   - Desain perubahan skema DB (wajib inkremental & backward-compatible)
   - Rencana pengujian (unit/feature/smoke test) & rencana rollback
4. Serahkan ke `dev-fullstack` setelah disetujui `pm-lead`.

---

## 3. Checklist Code Review (`DEV-04`)
Saat mereview branch hasil `dev-fullstack`:
- [ ] Perubahan fokus pada scope tiket, tidak ada perubahan file yang tidak relevan.
- [ ] Tidak ada secret/password hardcoded atau `.env` yang ikut ter-stage.
- [ ] Query database aman dari SQL Injection & N+1 query; migrasi bersifat inkremental.
- [ ] Error handling & validasi input lengkap.
- [ ] Test berjalan dan mencakup kasus utama + edge case.
- Jika lolos, beri status `TECH-APPROVED` ke `pm-lead` untuk diteruskan ke `dev-qa`.

