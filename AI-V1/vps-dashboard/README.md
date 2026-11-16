# AI-V1 VPS Control & Inventory Dashboard (`monitor.<DOMAIN>`)

Dashboard web ringan (**tanpa dependensi pip eksternal**, murni Python 3) untuk memantau secara visual seluruh komponen yang terinstall dan berjalan di VPS AI-V1:
- **Resource VPS:** Hostname, OS, Uptime, CPU Load, RAM, & Disk (`< 70%` hijau, `70–84%` kuning, `>= 85%` merah).
- **Layanan & Software:** Status `systemd` (`nginx`, `mysql`/`mariadb`, `docker`, `9router`, `ssh`, `ufw`) serta versi paket (`Docker`, `Nginx`, `PHP`, `Node`, `Python`, `Certbot`, `Git`, `Rclone`).
- **Docker & Hermes AI-V1:** Status container `hermes-gateway` & `hermes-dashboard`, status `.env` (`chmod 600`, `UID 10001` — tanpa pernah membaca isinya), status slot plugin `office-3d`, serta matriks kepatuhan Telegram pada 7 profil agent.
- **Port & Virtual Host:** Port `80`, `443`, `3306`, `9119`, `9120`, `20128`, `20129`, probe HTTP lokal, daftar domain Nginx (`sites-enabled`) beserta tombol akses cepat HTTPS.
- **SSL, ProjectWeb, & Backup:** Hitung mundur masa berlaku sertifikat Let's Encrypt, status Git proyek di `/home/project`, dan jumlah/usia file backup di `/var/backups/apps`.

> **Keamanan:** Dashboard hanya berjalan *read-only* di `127.0.0.1:9120`, tidak pernah membaca isi `.env` / vault / private key, dan akses publik **wajib** melalui Nginx + `auth_basic` + SSL Let's Encrypt.

---

## Cara Install di VPS (3 Menit)

### 1. Salin Aplikasi Dashboard ke `/opt/vps-dashboard`
```bash
sudo mkdir -p /opt/vps-dashboard
sudo cp -r AI-V1/vps-dashboard/* /opt/vps-dashboard/
sudo chmod +x /opt/vps-dashboard/server.py
```

### 2. Aktifkan Service Systemd (`127.0.0.1:9120`)
```bash
sudo cp /opt/vps-dashboard/deploy/vps-monitor.service /etc/systemd/system/vps-monitor.service
sudo systemctl daemon-reload
sudo systemctl enable --now vps-monitor
sudo systemctl status vps-monitor
```
Uji lokal:
```bash
curl -s http://127.0.0.1:9120/health
```

### 3. Pasang Nginx `auth_basic` + SSL Let's Encrypt
```bash
# Buat folder & user password untuk monitor.<DOMAIN>
sudo apt-get install -y apache2-utils
sudo mkdir -p /etc/nginx/htpasswd
sudo htpasswd -c /etc/nginx/htpasswd/monitor.htpasswd admin

# Pasang virtual host Nginx (ganti <DOMAIN> dengan domain Anda)
sudo cp /opt/vps-dashboard/deploy/nginx-monitor.conf /etc/nginx/sites-available/vps-monitor
sudo sed -i 's/<DOMAIN>/domain-anda.id/g' /etc/nginx/sites-available/vps-monitor
sudo ln -s /etc/nginx/sites-available/vps-monitor /etc/nginx/sites-enabled/vps-monitor

sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d monitor.domain-anda.id --redirect
```

Setelah selesai, buka `https://monitor.domain-anda.id` dan login dengan username/password `htpasswd` yang sudah dibuat.

