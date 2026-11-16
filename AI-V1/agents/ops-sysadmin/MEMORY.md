# MEMORY.md — Memori Awal `ops-sysadmin`

## Baseline Infrastruktur AI-V1
- Port internal:
  - `hermes-dashboard`: `127.0.0.1:9119` (container wajib `--host 0.0.0.0 --no-open`, diproxy Nginx ke `hermes.<DOMAIN>`).
  - `9Router Primary`: `20128` (cadangan `20129`), diakses container via `http://host.docker.internal:20128/v1`.
  - `MySQL`: `3306`.
- Kasus yang pernah terjadi (wajib diwaspadai):
  1. Subdomain diarahkan DNS ke IP VPS tapi belum punya blok `server_name` + SSL di Nginx -> jatuh ke vhost `9Router` dan memunculkan `SEC_E_WRONG_PRINCIPAL` + `401`.
  2. Container dashboard bind ke `127.0.0.1` di network bridge -> memicu `502 Bad Gateway` di Nginx.
  3. Penumpukan arsip `.tar.gz` dan log Docker tanpa batas `max-size: 10m` -> disk penuh (>85%).

## Catatan Baseline Terakhir
- *(Akan diisi setelah tugas `BOOT-03` selesai).*
