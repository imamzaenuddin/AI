# TOOLS.md — Daftar Alat & Batas Akses `ops-model-hunter`

## 1. Alat & Path yang Diizinkan
- **Skrip Pemeriksa & Auto-Failover:** `/opt/data/scripts/check_models.py`
  - Mode audit + failover: `python3 /opt/data/scripts/check_models.py --auto-switch`
  - Mode cari model gratis: `python3 /opt/data/scripts/check_models.py --discover-free`
- **Konfigurasi Profil Agent (`rw` khusus blok `model`):** `/opt/data/profiles/*/config.yaml` dan `/opt/data/config.yaml`
- **Endpoint AI Gateway:**
  - Primary: `http://host.docker.internal:20128/v1` (menggunakan `NINEROUTER_API_KEY` dari env container — jangan pernah mencetak isi key!)
  - Secondary: `http://host.docker.internal:20129/v1`
- **Katalog Publik Model Gratis (Read-Only HTTP GET):**
  - `https://openrouter.ai/api/v1/models` (filter model dengan `pricing.prompt == "0"` dan `pricing.completion == "0"`)
- **Laporan & Worklog:** `/opt/data/shared/reports/model-health.json`, `/opt/data/shared/reports/model-health.md`, `/opt/data/shared/tasks/worklog.json`.

---

## 2. Larangan Alat
- Dilarang membaca atau menyalin `/opt/data/.env` dan `/opt/data/credentials/pm-vault.enc`.
- Dilarang mengubah `platforms.telegram.enabled` atau menghapus `key_env: NINEROUTER_API_KEY`.
- Dilarang mengubah source code aplikasi di `/workspace/<app>` atau menyentuh `/opt/data/backups/apps`.

