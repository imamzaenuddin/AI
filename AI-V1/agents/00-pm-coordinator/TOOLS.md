# TOOLS.md — Daftar Alat & Batas Akses `pm-lead`

## 1. Path Runtime di Container (`UID 10001`)
| Path Container | Mode | Fungsi |
| :--- | :--- | :--- |
| `/opt/data/.env` | `rw` (`600`) | Kredensial gateway utama (`TELEGRAM_BOT_TOKEN`, `NINEROUTER_API_KEY`, dll.) |
| `/opt/data/credentials/` | `rw` (`700`) | Vault kredensial proyek & `access-ledger.md` |
| `/opt/data/shared/tasks/` | `rw` | Master task board & tiket lintas tim |
| `/opt/data/shared/reports/` | `rw` | Kumpulan laporan harian/mingguan Ops & Dev |
| `/opt/data/profiles/` | `rw` | Konfigurasi & memori profil agent `ops-*` dan `dev-*` |
| `/opt/data/desktop-plugins/` | `rw` | Slot plugin desktop launch scope utama (mis. `office-3d`) |
| `/workspace/` | `rw` | Direktori source code ProjectWeb (`/home/project` di host) |
| `/opt/data/backups/apps` | `ro` | Read-only mount untuk verifikasi hasil backup |
| `/home/hermes/.ssh` | `ro` | Read-only SSH key monitoring server eksternal |

---

## 2. Endpoint & Layanan yang Digunakan
- **AI Gateway (9Router):** `http://host.docker.internal:20128/v1` (env: `NINEROUTER_API_KEY`). Cadangan: `:20129`.
- **Telegram Bot API:** Long polling aktif **eksklusif** di `pm-lead` / `hermes-gateway`.
- **Hermes Dashboard:** `http://127.0.0.1:9119` (publik: `https://hermes.<DOMAIN>`).
- **MySQL Host:** `host.docker.internal:3306` / `172.28.10.1:3306` (hanya memakai akun non-root per proyek).

---

## 3. Tool & Perintah yang Dilarang
- Dilarang mengakses atau memodifikasi `/etc/nginx`, `/etc/systemd`, `/etc/ssh` host (tidak di-mount dan di luar otoritas container).
- Dilarang menjalankan proses Telegram polling kedua dengan token yang sama.
- Dilarang mengirim isi `.env` atau `vault.env` ke output chat atau menyimpannya di `/workspace` yang ter-track Git.
- Dilarang menjalankan `migrate:fresh`, `db:wipe`, atau `DROP DATABASE`.

