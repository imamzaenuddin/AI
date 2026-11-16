# AI-V1 Code-Server (`code.<DOMAIN>` -> `/home/project`)

`code-server` menyediakan VS Code di browser bagi Admin/Developer untuk meninjau, mengedit, dan mengontrol seluruh kode proyek di `/home/project` tanpa mencemari folder proyek dengan file konfigurasi editor.

---

## Standar Penempatan & Keamanan AI-V1
1. **Lokasi Instalasi & Data:** `/opt/code-server/` (`config.yaml`, `data/`, `extensions/`), **bukan** di dalam `/home/project`.
2. **Workspace Target:** `/home/project` (dibuka langsung saat login).
3. **User Non-Root & Permission Bersama:**
   - Berjalan sebagai user non-root (misal `codeserver` atau `devuser` yang tergabung dalam grup `dev` bersama `www-data` dan `hermes`, atau diberi ACL `rwX` ke `/home/project`) — **dilarang** berjalan sebagai `root`.
4. **Bind & Akses Publik:**
   - Wajib listen hanya pada `127.0.0.1:8443`.
   - Dipublikasikan via Nginx Reverse Proxy (`https://code.<DOMAIN>`) dengan WebSocket `Upgrade` dan SSL Let's Encrypt (`certbot --nginx`).
   - Wajib autentikasi password kuat (`auth: password` di `/opt/code-server/config.yaml`, `chmod 600`).

---

## Cara Setup Cepat di VPS
```bash
# 1. Install code-server (menggunakan installer resmi)
curl -fsSL https://code-server.dev/install.sh | sh

# 2. Buat user non-root & direktori khusus /opt/code-server
sudo groupadd -f dev
sudo id -u codeserver >/dev/null 2>&1 || sudo useradd -m -s /bin/bash -G dev codeserver
sudo usermod -aG dev www-data
sudo usermod -aG dev hermes 2>/dev/null || true

sudo mkdir -p /opt/code-server/{data,extensions}
sudo cp AI-V1/code-server/config.yaml.example /opt/code-server/config.yaml
# Edit /opt/code-server/config.yaml dan ganti <STRONG_PASSWORD_OR_HASH>
sudo chown -R codeserver:dev /opt/code-server
sudo chmod 750 /opt/code-server
sudo chmod 600 /opt/code-server/config.yaml

# 3. Pastikan ACL /home/project kompatibel untuk codeserver, hermes (10001), dan www-data
sudo setfacl -R -m u:codeserver:rwX,d:u:codeserver:rwX /home/project
sudo setfacl -R -m u:10001:rwX,d:u:10001:rwX /home/project

# 4. Pasang systemd & Nginx
sudo cp AI-V1/code-server/deploy/code-server.service /etc/systemd/system/code-server.service
sudo systemctl daemon-reload
sudo systemctl enable --now code-server

sudo cp AI-V1/code-server/deploy/nginx-code-server.conf /etc/nginx/sites-available/code-server
sudo sed -i 's/<DOMAIN>/domain-anda.id/g' /etc/nginx/sites-available/code-server
sudo ln -s /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/code-server
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d code.domain-anda.id --redirect
```
