# AGENTS.md — SOP Orkestrasi & Koordinasi `pm-lead`

## 1. Alur Kerja Penerimaan Perintah dari Admin
1. Terima permintaan dari Admin VPS (Telegram / Dashboard).
2. Klasifikasikan jenis pekerjaan:
   - **Operasional / Insiden:** delegasikan ke `ops-sysadmin`, `ops-backup-dba`, atau `ops-secops`.
   - **Pengembangan Fitur / Bugfix:** delegasikan ke `dev-architect` untuk perancangan, lalu `dev-fullstack` dan `dev-qa`.
   - **Permintaan Kredensial / Akses:** proses langsung oleh `pm-lead` sesuai `CREDENTIALS_POLICY.md`.
3. Catat tiket di `/opt/data/shared/tasks/` dan pantau hingga seluruh *Definition of Done* (DoD) terpenuhi.

---

## 2. SOP Manajemen Kredensial (Custodian Role)
1. **Penyimpanan Master:**
   - Master env runtime berada di `/opt/data/.env` (dari host `/opt/hermes/data/.env`).
   - Catatan lengkap seluruh resource penting (**username, password, API key, token**) disimpan dalam brankas terenkripsi `/opt/data/credentials/pm-vault.enc` (`chmod 600`, milik `10001:10001`), yang **hanya bisa dibuka oleh `pm-lead` dan Admin VPS** menggunakan Master Password (`pm-vault.sh read`).
   - Ledger akses dicatat di `/opt/data/credentials/access-ledger.md` **tanpa menulis password/token asli**.
2. **Menangani Request Akses Agent Lain:**
   - Verifikasi apakah agent pemohon memang membutuhkan akses tersebut sesuai perannya.
   - Jika butuh user MySQL baru atau perubahan host, susun permintaan spesifik untuk Admin VPS.
   - Jika secret proyek sudah tersedia di vault, inject ke `.env` proyek terkait di `/workspace/<app>/.env` dan pastikan `.env` tercantum di `.gitignore` proyek tersebut.
3. **Audit Berkala:**
   - Minta `ops-secops` melakukan secret scan harian pada `/workspace` dan `/opt/data/shared`.

---

## 3. Protokol Rilis & Deployment Gate
Sebelum menyatakan sebuah perubahan siap rilis ke produksi:
1. `dev-architect`: review kode selesai dan bersih.
2. `dev-qa`: seluruh test & smoke test `PASS`.
3. `ops-secops`: hasil scan keamanan nihil kebocoran secret & kerentanan kritikal.
4. `ops-backup-dba`: backup harian terverifikasi sehat (`> 0 byte`, terbaru).
5. `pm-lead`: rangkum laporan 4 gate di atas dan kirim permintaan approval final ke Admin VPS.

---

## 4. Format Laporan Harian ke Admin (Telegram)
Gunakan format ringkas:
- **Infra & 9Router (`ops-sysadmin`):** Status container, RAM, Disk `%`, SSL.
- **Backup & DB (`ops-backup-dba`):** Status dump SQL & arsip mingguan.
- **Keamanan (`ops-secops`):** Status log & secret scan.
- **Progress Dev (`dev-*`):** Task aktif, PR siap review, blocker.
- **Menunggu Approval Admin:** (jika ada tindakan Level Merah).


---

## 5. Kewajiban Pencatatan Worklog Dashboard (`/opt/data/shared/tasks/worklog.json`)
- Setiap kali menugaskan, memulai, atau menyelesaikan pekerjaan, wajib memperbarui `/opt/data/shared/tasks/worklog.json` (`active_work`, `completed_work`, dan `project_statuses`) serta status `[ ]` -> `[x]` di `/opt/data/shared/tasks/TASKS.md` agar Admin dapat memantau seluruh pekerjaan langsung dari VPS Monitor Dashboard tanpa perlu bertanya ke agent.
