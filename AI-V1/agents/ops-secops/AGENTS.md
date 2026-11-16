# AGENTS.md — SOP Audit Keamanan `ops-secops`

## 1. Alur Audit Harian (`OPS-05`)
1. Periksa log runtime di `/opt/data` untuk mencari:
   - Warning `Running as ROOT`
   - Error Telegram `Conflict: terminated by other getUpdates request`
   - Warning `custom-http has no resolvable api_key` atau error `401` berulang
2. Pindai seluruh proyek di `/workspace/*`:
   - Pastikan tidak ada `.env`, `*.pem`, `*.key`, `auth.json`, atau token mentah yang ter-track di Git (`git ls-files`).
   - Pastikan `config.yaml` profil lain tidak mengaktifkan `platforms.telegram.enabled: true`.
3. Cek permission file sensitif di `/opt/data` (misal `.env` harus `600`, `/opt/data/credentials` harus `700`).
4. Simpan laporan ke `/opt/data/shared/reports/security-audit-YYYY-MM-DD.md` dan kirim ke `pm-lead`.

---

## 2. Alur Review Keamanan Pre-Release
Saat `dev-qa` atau `pm-lead` mengajukan rilis:
1. Periksa `git diff main...<feature-branch>` pada `/workspace/<app>`:
   - Tidak ada hardcoded secret/password.
   - Tidak ada perintah berbahaya (`migrate:fresh`, `db:wipe`, `exec`/`shell_exec` tanpa sanitasi).
   - Validasi input, autentikasi, dan proteksi CSRF/SQLi terpenuhi.
2. Keluarkan keputusan `SEC-PASS` atau `SEC-BLOCK` (disertai daftar temuan High/Medium/Low).

---

## 3. Penanganan Insiden Kebocoran Secret
Jika menemukan kredensial asli di file yang ter-track Git atau output log:
1. Segera laporkan ke `pm-lead` dengan label `[CRITICAL - SECRET EXPOSURE]`.
2. Sebutkan path file, nomor baris, dan jenis secret **tanpa menulis ulang nilai secret aslinya**.
3. Rekomendasikan rotasi kredensial ke Admin VPS dan pembersihan riwayat Git bila perlu.

