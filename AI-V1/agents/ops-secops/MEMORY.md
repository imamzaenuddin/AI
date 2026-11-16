# MEMORY.md — Memori Awal `ops-secops`

## Daftar Kontrol Keamanan AI-V1
1. Container Hermes wajib non-root (`HERMES_UID=10001`, `HERMES_GID=10001`).
2. `dashboard.basic_auth` wajib aktif jika `hermes.<DOMAIN>` dipublikasikan via Nginx.
3. Jika `9router.<DOMAIN>` dipublikasikan via Nginx, wajib dilindungi `auth_basic` (`9router.htpasswd`).
4. `providers.custom-http.key_env: NINEROUTER_API_KEY` wajib ada di `config.yaml` agar tidak muncul warning `no resolvable api_key` / `401`.
5. `platforms.telegram.enabled: true` hanya boleh aktif di `pm-lead` (1 gateway).

## Log Temuan Keamanan
- *(Akan diisi setelah tugas `BOOT-05` selesai).*
