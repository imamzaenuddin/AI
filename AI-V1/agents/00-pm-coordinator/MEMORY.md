# MEMORY.md — Memori Awal `pm-lead`

## Fakta Arsitektur AI-V1
- VPS menjalankan Docker Compose non-root (`UID 10001:10001`, user `hermes`) di `/opt/hermes/docker-compose.yml`.
- Subnet Docker bridge: `hermes-net` (`172.28.10.0/24`, gateway `172.28.10.1`).
- `9Router` berjalan sebagai systemd service di host pada port `20128` (cadangan `20129`), diakses dari container via `http://host.docker.internal:20128/v1` dengan `key_env: NINEROUTER_API_KEY`.
- Satu token Telegram hanya boleh dipakai oleh satu gateway (`hermes-gateway` / `pm-lead`). Semua profil agent lain memiliki `platforms.telegram.enabled: false`.
- `/var/backups/apps` di-mount read-only (`:ro`) ke `/opt/data/backups/apps` agar agent bisa mengaudit tanpa bisa menghapus/mengubah backup.

## Tim di Bawah Koordinasi `pm-lead`
- **Tim Operasional:** `ops-sysadmin`, `ops-backup-dba`, `ops-secops`
- **Tim Development:** `dev-architect`, `dev-fullstack`, `dev-qa`

## Catatan Kredensial & Keputusan Aktif
- *(Belum ada catatan runtime — isi `access-ledger.md` setelah `BOOT-02` selesai).*
