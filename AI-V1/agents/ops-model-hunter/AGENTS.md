# AGENTS.md — SOP Audit & Pencarian Model Gratis `ops-model-hunter`

## 1. Alur Pemeriksaan Rutin CRON (`OPS-06`)
1. Jalankan `/opt/data/scripts/check_models.py --auto-switch --discover-free`.
2. Skrip akan:
   - Membaca `model.default` dari seluruh `/opt/data/profiles/*/config.yaml` dan `/opt/data/config.yaml`.
   - Menguji setiap model via `http://host.docker.internal:20128/v1/chat/completions` (`max_tokens: 5`, key dari env `NINEROUTER_API_KEY`).
   - Memeriksa katalog model gratis terbaru (seperti daftar `:free` OpenRouter yang `prompt == "0"` dan `completion == "0"`) dan menguji mana yang dapat dipanggil melalui `9Router`.
3. Jika ada model agent berstatus `QUOTA_EXHAUSTED` (`402`/`429`) atau `DOWN` (`404`/`5xx`):
   - Pilih kandidat model aktif/gratis terbaik dari hasil probe (prioritaskan yang mendukung context >= 32k & tool calling).
   - Simpan cadangan `config.yaml.bak` sebelum mengubah `model.default`.
   - Verifikasi `key_env: NINEROUTER_API_KEY` dan `platforms.telegram.enabled` tetap utuh.
4. Simpan laporan ke `/opt/data/shared/reports/model-health.json` dan `/opt/data/shared/reports/model-health.md`.
5. Kirim ringkasan ke `pm-lead` (wajib kirim alert instan jika terjadi *auto-switch* atau jika seluruh model di `9Router` habis).

---

## 2. Kriteria Model Gratis yang Layak Diimplementasikan
1. Harga prompt & completion terverifikasi `0` (`free tier`) atau masuk combo kuota gratis `9Router`.
2. `context_length >= 32768` (diutamakan `>= 128000` untuk `dev-architect`, `dev-fullstack`, dan `pm-lead`).
3. Lolos uji respons nyata melalui `9Router` (`HTTP 200`, bukan sekadar terdaftar di daftar teks).
4. Jika memerlukan koneksi provider baru di `9Router` (misal tambah API key gratis baru), susun daftar rekomendasi model + provider lalu kirim ke `pm-lead` agar Admin menambahkan ke `9Router` / `pm-vault.enc`.

---

## 3. Kewajiban Pencatatan Worklog Dashboard
- Setiap selesai audit CRON, perbarui `/opt/data/shared/tasks/worklog.json` (`active_work`, `completed_work`, dan `project_statuses`) serta `/opt/data/shared/tasks/TASKS.md` agar hasil pengecekan dan pergantian model terlihat langsung di VPS Monitor Dashboard.

