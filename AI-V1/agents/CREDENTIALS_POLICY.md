# Kebijakan Pengelolaan Kredensial & Rahasia (AI-V1)

Dokumen ini menetapkan aturan ketat pengelolaan kredensial untuk seluruh tim agent otonom AI-V1.

---

## 1. Penunjukan Pemegang Utama Kredensial

* **Pemegang Utama Kredensial (Custodian):** `00-pm-coordinator` (Profile ID: `pm-lead`).
* **Pemilik Otoritas Tertinggi:** Admin VPS / Pemilik Sistem (manusia).
* **Status Agent Lain (`ops-*` dan `dev-*`):** **Tidak boleh** menyimpan, menggandakan, atau mempublikasikan kredensial master. Agent lain hanya menerima akses berbasis **kebutuhan minimum (*least privilege*)** yang dicatat dan dikontrol oleh `pm-lead`.

---

## 2. Inventaris Kredensial & Klasifikasi Risiko

| Kategori Kredensial | Lokasi Penyimpanan Resmi | Pemegang / Akses | Catatan Keamanan |
| :--- | :--- | :--- | :--- |
| `TELEGRAM_BOT_TOKEN` | `/opt/hermes/data/.env` | **Hanya `pm-lead` (Gateway Utama)** | 1 Token = 1 Gateway. Dilarang dibagikan ke profil lain. |
| `NINEROUTER_API_KEY` | `/opt/hermes/data/.env` (via `key_env`) | Gateway & semua profil via env container | Wajib direferensikan lewat `key_env`, bukan plaintext di `config.yaml`. |
| `DASHBOARD_BASIC_AUTH` | `/opt/hermes/data/config.yaml` (hash) / `.env` | Admin VPS & `pm-lead` (audit) | Wajib hash kuat; tidak pernah disebarkan di chat. |
| `DB_AGENT_USER` / Password Proyek | `/opt/hermes/data/credentials/pm-vault.enc` (terenkripsi) & `.env` per app | **Hanya `pm-lead` (unlock via password)** & Admin VPS | Dilarang memakai user `root` MySQL. Setiap proyek pakai user terpisah. |
| SSH Key Monitoring (`/opt/hermes/ssh`) | `/opt/hermes/ssh` -> `/home/hermes/.ssh` (`:ro`) | `pm-lead` (otorisasi) & `ops-sysadmin` (monitoring) | Khusus monitoring server eksternal; read-only di container. |
| Secret Aplikasi (`/workspace/<app>/.env`) | File `.env` lokal di masing-masing app (di-ignore Git) | `pm-lead` (custodian), `dev-fullstack` (via `.env.example` + inject dari PM) | **Wajib** masuk `.gitignore`. Hanya `.env.example` yang boleh di-commit. |
| Token Backup Off-site (`rclone` / S3 / GDrive) | Host `root` (`/root/.config/rclone` atau `/etc/backup.env`) | **Hanya Host `root`** | **Tidak di-mount ke container.** Agent hanya membaca hasil di `/opt/data/backups/apps:ro`. |

---

## 3. Alur Permintaan & Peminjaman Akses oleh Agent

Jika agent Ops atau Dev membutuhkan akses terautentikasi (misalnya kredensial DB staging untuk proyek baru di `/workspace/<app>`):

1. **Ajukan Request ke `pm-lead`:**
   - Sebutkan nama agent, nama proyek, tujuan penggunaan, scope database/endpoint, dan durasi kebutuhan.
2. **Validasi oleh `pm-lead` (bersama `ops-secops` jika berisiko tinggi):**
   - Pastikan permintaan bukan user `root`, bukan database produksi tanpa approval Admin, dan tidak melanggar aturan AI-V1.
3. **Provisioning & Pencatatan:**
   - `pm-lead` menyiapkan atau menginjeksikan `.env` proyek di `/workspace/<app>/.env` (atau meminta Admin membuat user MySQL non-root baru di host).
   - Catat pemberian akses di `/opt/data/credentials/access-ledger.md` (berisi *siapa, kapan, untuk apa, status aktif/dicabut* — **tanpa menulis nilai password/token mentah**).
4. **Rotasi & Pencabutan:**
   - Saat proyek selesai atau terjadi indikasi kebocoran, `pm-lead` memerintahkan rotasi secret dan melaporkan ke Admin VPS.

---

## 4. Larangan Keras (Zero-Tolerance Rules)

1. **Dilarang menulis rahasia asli** (API key, token Telegram, password DB, private key) ke:
   - Repositori Git (termasuk commit history, `SOUL.md`, `TOOLS.md`, `TASKS.md`, `MEMORY.md`).
   - Output log atau pesan ringkasan Telegram (wajib di-masking, misal `sk-****1234`).
2. **Dilarang menyalin `.env` antar proyek** atau membypass pembatasan dengan membaca file milik proyek lain tanpa izin `pm-lead`.
3. **Dilarang menjalankan perintah destruktif** (`migrate:fresh`, `db:wipe`, `DROP DATABASE`, `rm -rf /workspace/*`) meskipun agent memiliki akses ke DB proyek tersebut.
4. Jika `ops-secops` menemukan secret bocor di `/workspace` atau log, `pm-lead` **wajib segera membekukan task terkait** dan mengirim alert ke Admin VPS untuk rotasi kredensial.

---

## 5. Brankas Terenkripsi PM-Only (`pm-vault.enc` + Master Password)

Seluruh catatan penting resource (**IP/SSH, username, password dashboard, `code-server`, `9Router`, API key upstream, akun DB, token Git/SMTP**) disimpan terenkripsi menggunakan **AES-256-CBC + PBKDF2 (600.000 iterasi)** di `/opt/hermes/data/credentials/pm-vault.enc` (`chmod 600`, pemilik `10001:10001`).

1. **Eksklusif untuk `pm-lead` (`00-pm-coordinator`) & Admin:**
   - Hanya `pm-lead` dan Admin VPS yang diizinkan mendekripsi/membaca `pm-vault.enc` dengan memasukkan **Master Password** lewat `AI-V1/scripts/pm-vault.sh`.
   - Agent lain (`ops-*`, `dev-*`) serta `vps-dashboard` **dilarang keras** membaca atau mencoba mendekripsi `pm-vault.enc`.
2. **Cara Setup & Pemakaian di VPS:**
   ```bash
   # Buat & isi catatan resource penting (memakai template vault.example.md, otomatis terenkripsi)
   bash AI-V1/scripts/pm-vault.sh init
   sudo chown 10001:10001 /opt/hermes/data/credentials/pm-vault.enc

   # Membaca isi brankas (wajib memasukkan Master Password)
   bash AI-V1/scripts/pm-vault.sh read

   # Mengubah / menambah resource baru (diedit di /dev/shm lalu dienkripsi ulang)
   bash AI-V1/scripts/pm-vault.sh edit
   ```
3. **Aturan Master Password:**
   - Master Password **tidak pernah** disimpan di Git, `MEMORY.md`, `TOOLS.md`, atau file plaintext mana pun di VPS. Saat `pm-lead` perlu membukanya, Admin memberikan password secara langsung di sesi terkait (atau sementara via `PM_VAULT_PASSPHRASE` di memori sesi).

