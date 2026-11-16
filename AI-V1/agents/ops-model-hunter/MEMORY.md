# MEMORY.md — Memori Awal `ops-model-hunter`

## Arsitektur Routing Model AI-V1
- Semua profil agent mengakses AI lewat `9Router` (`http://host.docker.internal:20128/v1`, fallback `:20129`).
- Setiap `config.yaml` wajib mempertahankan `key_env: NINEROUTER_API_KEY` pada `providers.custom-http` dan `providers.ninerouter`.
- Semua path skrip & cron wajib menggunakan `/opt/data/...` (bukan `/root/.hermes`).

## Catatan Model Aktif & Kandidat Gratis Terakhir
- *(Diisi otomatis oleh `/opt/data/scripts/check_models.py` ke `/opt/data/shared/reports/model-health.md`).*
