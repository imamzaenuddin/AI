# AGENTS.md — SOP Coding & Git `dev-fullstack`

## 1. Alur Pengerjaan Tiket (`DEV-03`)
1. Baca spesifikasi teknis tiket di `/opt/data/shared/tasks/<ticket-id>.md` dari `dev-architect`.
2. Jika butuh akses DB dev/staging atau API key pihak ketiga, ajukan request ke `pm-lead` (jangan pernah membuat atau menebak kredensial produksi).
3. Masuk ke `/workspace/<nama-app>` dan pastikan kondisi Git bersih:
   - Buat branch baru dari base branch yang disepakati: `git checkout -b feat/<ticket-id>` atau `fix/<ticket-id>`.
4. Implementasikan perubahan kode secara modular (ikuti pola codebase eksisting, hindari duplikasi).
5. Jika ada perubahan database:
   - Gunakan migrasi inkremental (`up` & `down` jelas).
   - Uji migrasi pada database lokal/staging yang diotorisasi `pm-lead` — **dilarang** `migrate:fresh` atau `db:wipe`.
6. Jalankan linter & test suite lokal proyek sebelum menyerahkan hasil.
7. Periksa `git status` dan `git diff` — pastikan tidak ada `.env` atau file sensitif yang ikut ter-stage.
8. Commit dengan pesan yang jelas, lalu serahkan branch untuk direview oleh `dev-architect` (`DEV-04`).

---

## 2. Penanganan Temuan Review / QA
Jika `dev-architect`, `dev-qa`, atau `ops-secops` mengembalikan temuan:
- Perbaiki di feature branch yang sama.
- Tambahkan regression test agar bug tidak berulang.
- Minta verifikasi ulang setelah perbaikan selesai.


---

## 3. Kewajiban Pencatatan Worklog Dashboard
- Saat mulai mengkode tiket (`feat/...` / `fix/...`) dan saat selesai commit/PR, wajib mencatat status *Sedang Dikerjakan* (`active_work`) dan *Sudah Dikerjakan* (`completed_work` + `project_statuses`) di `/opt/data/shared/tasks/worklog.json` serta memperbarui `/opt/data/shared/tasks/TASKS.md` agar terlihat langsung di VPS Monitor Dashboard.
