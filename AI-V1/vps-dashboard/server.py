#!/usr/bin/env python3
"""
AI-V1 VPS Monitor Dashboard Server (Zero-Dependency Python 3)
Menampilkan inventaris layanan, container Docker/Hermes, profil agent,
port, virtual host Nginx & SSL expiry, ProjectWeb, dan status backup secara visual.

Keamanan:
- Default bind ke 127.0.0.1:9120 (akses publik wajib lewat Nginx + auth_basic + SSL).
- Read-only telemetry: tidak pernah membaca isi .env, vault, atau private key.
- Tidak mengeksekusi input user ke shell (subprocess selalu memakai list argumen tetap).
"""

from __future__ import annotations

import json
import os
import platform
import re
import shutil
import socket
import stat
import subprocess
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

HOST = os.environ.get("VPS_MONITOR_HOST", "127.0.0.1")
PORT = int(os.environ.get("VPS_MONITOR_PORT", "9120"))
BASE_DIR = Path(__file__).resolve().parent
STATIC_INDEX = BASE_DIR / "static" / "index.html"

HERMES_DATA_DIR = Path(os.environ.get("HERMES_DATA_DIR", "/opt/hermes/data"))
PROJECT_DIR = Path(os.environ.get("PROJECT_DIR", "/home/project"))
BACKUP_DIR = Path(os.environ.get("BACKUP_DIR", "/var/backups/apps"))
NGINX_ENABLED_DIR = Path(os.environ.get("NGINX_ENABLED_DIR", "/etc/nginx/sites-enabled"))
LETSENCRYPT_LIVE_DIR = Path(os.environ.get("LETSENCRYPT_LIVE_DIR", "/etc/letsencrypt/live"))

EXPECTED_PROFILES = [
    ("pm-lead", "PM & Credential Custodian", True),
    ("ops-sysadmin", "Ops SysAdmin", False),
    ("ops-backup-dba", "Ops Backup & DBA", False),
    ("ops-secops", "Ops SecOps", False),
    ("dev-architect", "Dev Architect", False),
    ("dev-fullstack", "Dev Fullstack", False),
    ("dev-qa", "Dev QA", False),
]


def run_cmd(args: list[str], timeout: int = 3) -> tuple[int, str, str]:
    """Jalankan perintah read-only tanpa shell=True."""
    if not shutil.which(args[0]):
        return 127, "", f"{args[0]} not found"
    try:
        proc = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except (subprocess.TimeoutExpired, OSError) as exc:
        return 1, "", str(exc)


def check_tcp_port(host: str, port: int, timeout: float = 0.6) -> bool:
    """Cek apakah port TCP lokal sedang listening."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def check_http_status(url: str, timeout: float = 1.5) -> dict[str, Any]:
    """Probe HTTP lokal tanpa mengikuti redirect eksternal."""
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return {"reachable": True, "status": resp.status}
    except urllib.error.HTTPError as err:
        return {"reachable": True, "status": err.code}
    except Exception as exc:  # noqa: BLE001
        return {"reachable": False, "status": None, "error": str(exc)}


def get_system_metrics() -> dict[str, Any]:
    """Kumpulkan metrik OS, uptime, CPU load, RAM, dan Disk."""
    uptime_seconds: float | None = None
    uptime_path = Path("/proc/uptime")
    if uptime_path.exists():
        try:
            uptime_seconds = float(uptime_path.read_text(encoding="utf-8").split()[0])
        except (ValueError, OSError):
            uptime_seconds = None

    load_avg = None
    if hasattr(os, "getloadavg"):
        try:
            l1, l5, l15 = os.getloadavg()
            load_avg = {"1m": round(l1, 2), "5m": round(l5, 2), "15m": round(l15, 2)}
        except OSError:
            load_avg = None

    mem = {"total_mb": None, "used_mb": None, "available_mb": None, "percent": None}
    meminfo = Path("/proc/meminfo")
    if meminfo.exists():
        parsed: dict[str, int] = {}
        for line in meminfo.read_text(encoding="utf-8").splitlines():
            parts = line.split(":")
            if len(parts) == 2:
                val = parts[1].strip().split()[0]
                if val.isdigit():
                    parsed[parts[0]] = int(val)
        total_kb = parsed.get("MemTotal")
        avail_kb = parsed.get("MemAvailable", parsed.get("MemFree"))
        if total_kb and avail_kb is not None:
            used_kb = max(total_kb - avail_kb, 0)
            mem = {
                "total_mb": round(total_kb / 1024),
                "used_mb": round(used_kb / 1024),
                "available_mb": round(avail_kb / 1024),
                "percent": round((used_kb / total_kb) * 100, 1),
            }

    disks: list[dict[str, Any]] = []
    seen_targets: set[str] = set()
    for label, path in [("Root (/)", Path("/")), ("Backups", BACKUP_DIR), ("Projects", PROJECT_DIR)]:
        target = path if path.exists() else Path("/")
        key = f"{label}:{target}"
        if key in seen_targets:
            continue
        seen_targets.add(key)
        try:
            usage = shutil.disk_usage(target)
            pct = round((usage.used / usage.total) * 100, 1) if usage.total else 0.0
            disks.append(
                {
                    "label": label,
                    "path": str(target),
                    "total_gb": round(usage.total / (1024**3), 1),
                    "used_gb": round(usage.used / (1024**3), 1),
                    "free_gb": round(usage.free / (1024**3), 1),
                    "percent": pct,
                }
            )
        except OSError:
            continue

    os_pretty = f"{platform.system()} {platform.release()}"
    os_release = Path("/etc/os-release")
    if os_release.exists():
        for line in os_release.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("PRETTY_NAME="):
                os_pretty = line.split("=", 1)[1].strip().strip('"')
                break

    return {
        "hostname": socket.gethostname(),
        "os": os_pretty,
        "arch": platform.machine(),
        "cpu_cores": os.cpu_count(),
        "uptime_seconds": uptime_seconds,
        "load_avg": load_avg,
        "memory": mem,
        "disks": disks,
    }


def get_installed_software() -> list[dict[str, Any]]:
    """Cek tool & service inti yang terinstall di VPS."""
    checks = [
        ("Docker Engine", ["docker", "--version"]),
        ("Docker Compose", ["docker", "compose", "version"]),
        ("Nginx", ["nginx", "-v"]),
        ("MySQL / MariaDB", ["mysql", "--version"]),
        ("Certbot SSL", ["certbot", "--version"]),
        ("PHP", ["php", "-v"]),
        ("Node.js", ["node", "--version"]),
        ("Python 3", ["python3", "--version"]),
        ("Git", ["git", "--version"]),
        ("UFW Firewall", ["ufw", "version"]),
        ("Rclone", ["rclone", "version"]),
    ]
    items: list[dict[str, Any]] = []
    for name, cmd in checks:
        rc, out, err = run_cmd(cmd)
        raw = out or err
        first_line = raw.splitlines()[0] if raw else ""
        items.append(
            {
                "name": name,
                "installed": rc == 0,
                "version": first_line if rc == 0 else "Tidak terpasang",
            }
        )
    return items


def get_systemd_services() -> list[dict[str, Any]]:
    """Cek status service systemd utama AI-V1."""
    candidates = [
        ("nginx", "Nginx Reverse Proxy"),
        ("mysql", "MySQL Server"),
        ("mariadb", "MariaDB Server"),
        ("docker", "Docker Daemon"),
        ("9router", "9Router Primary (:20128)"),
        ("9router-secondary", "9Router Secondary (:20129)"),
        ("vps-monitor", "AI-V1 VPS Monitor (:9120)"),
        ("ssh", "OpenSSH Daemon"),
        ("ufw", "UFW Firewall"),
    ]
    services: list[dict[str, Any]] = []
    has_systemctl = shutil.which("systemctl") is not None
    for unit, label in candidates:
        if not has_systemctl:
            services.append({"unit": unit, "label": label, "state": "unknown"})
            continue
        rc, out, _ = run_cmd(["systemctl", "is-active", unit])
        state = out if out else ("inactive" if rc != 0 else "active")
        # Cek apakah unit benar-benar ada sebelum menampilkan error palsu
        rc_load, out_load, _ = run_cmd(["systemctl", "show", unit, "--property=LoadState", "--value"])
        if rc_load == 0 and out_load == "not-found":
            state = "not-installed"
        services.append({"unit": unit, "label": label, "state": state})
    return services


def get_docker_containers() -> dict[str, Any]:
    """Ambil daftar container Docker beserta status health."""
    rc, out, err = run_cmd(
        ["docker", "ps", "-a", "--format", "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"],
        timeout=4,
    )
    if rc != 0:
        return {"available": False, "error": err or "Docker tidak tersedia", "containers": []}

    containers: list[dict[str, Any]] = []
    for line in out.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        name = parts[0] if len(parts) > 0 else ""
        image = parts[1] if len(parts) > 1 else ""
        status = parts[2] if len(parts) > 2 else ""
        ports = parts[3] if len(parts) > 3 else ""
        containers.append(
            {
                "name": name,
                "image": image,
                "status": status,
                "ports": ports,
                "healthy": "(healthy)" in status.lower() or status.lower().startswith("up "),
            }
        )
    return {"available": True, "containers": containers}


def _extract_telegram_enabled(config_path: Path) -> bool | None:
    """Baca hanya flag platforms.telegram.enabled tanpa membaca secret apa pun."""
    if not config_path.exists():
        return None
    text = config_path.read_text(encoding="utf-8", errors="ignore")
    match = re.search(r"telegram:\s*\n\s*enabled:\s*(true|false)", text, re.IGNORECASE)
    if not match:
        return None
    return match.group(1).lower() == "true"


def get_hermes_status() -> dict[str, Any]:
    """Inspeksi struktur AI-V1 Hermes, profil agent, permission, dan plugin office-3d."""
    env_file = HERMES_DATA_DIR / ".env"
    env_mode = None
    env_uid = None
    if env_file.exists():
        st = os.stat(env_file)
        env_mode = oct(stat.S_IMODE(st.st_mode))
        env_uid = st.st_uid

    office3d_dir = HERMES_DATA_DIR / "desktop-plugins" / "office-3d"
    profiles_dir = HERMES_DATA_DIR / "profiles"
    profiles: list[dict[str, Any]] = []
    for profile_id, role, expected_tg in EXPECTED_PROFILES:
        pdir = profiles_dir / profile_id
        cfg = pdir / "config.yaml"
        tg_enabled = _extract_telegram_enabled(cfg)
        profiles.append(
            {
                "id": profile_id,
                "role": role,
                "installed": pdir.exists() and cfg.exists(),
                "telegram_enabled": tg_enabled,
                "telegram_compliant": (tg_enabled == expected_tg) if tg_enabled is not None else False,
            }
        )

    return {
        "data_dir_exists": HERMES_DATA_DIR.exists(),
        "env_exists": env_file.exists(),
        "env_mode": env_mode,
        "env_uid": env_uid,
        "gateway_sock_exists": (HERMES_DATA_DIR / "gateway.sock").exists(),
        "office_3d_installed": office3d_dir.exists(),
        "credentials_dir_exists": (HERMES_DATA_DIR / "credentials").exists(),
        "profiles": profiles,
    }


def get_ports_and_endpoints() -> list[dict[str, Any]]:
    """Cek port layanan standar AI-V1 & health HTTP lokal."""
    endpoints = [
        {"name": "Nginx HTTP", "host": "127.0.0.1", "port": 80, "probe": None},
        {"name": "Nginx HTTPS", "host": "127.0.0.1", "port": 443, "probe": None},
        {"name": "Hermes Dashboard", "host": "127.0.0.1", "port": 9119, "probe": "http://127.0.0.1:9119/login"},
        {"name": "VPS Monitor Dashboard", "host": "127.0.0.1", "port": PORT, "probe": None},
        {"name": "9Router Primary", "host": "127.0.0.1", "port": 20128, "probe": "http://127.0.0.1:20128/v1/models"},
        {"name": "9Router Secondary", "host": "127.0.0.1", "port": 20129, "probe": None},
        {"name": "MySQL / MariaDB", "host": "127.0.0.1", "port": 3306, "probe": None},
    ]
    results: list[dict[str, Any]] = []
    for ep in endpoints:
        listening = check_tcp_port(ep["host"], ep["port"])
        http_info = check_http_status(ep["probe"]) if (listening and ep["probe"]) else None
        results.append(
            {
                "name": ep["name"],
                "address": f"{ep['host']}:{ep['port']}",
                "listening": listening,
                "http": http_info,
            }
        )
    return results


def get_nginx_and_ssl() -> dict[str, Any]:
    """Daftar virtual host di sites-enabled & masa berlaku sertifikat Let's Encrypt."""
    vhosts: list[dict[str, Any]] = []
    if NGINX_ENABLED_DIR.exists():
        for entry in sorted(NGINX_ENABLED_DIR.iterdir()):
            if not (entry.is_file() or entry.is_symlink()):
                continue
            try:
                content = entry.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            names = re.findall(r"^\s*server_name\s+([^;]+);", content, re.MULTILINE)
            proxies = re.findall(r"^\s*proxy_pass\s+([^;]+);", content, re.MULTILINE)
            roots = re.findall(r"^\s*root\s+([^;]+);", content, re.MULTILINE)
            vhosts.append(
                {
                    "file": entry.name,
                    "server_names": [n.strip() for group in names for n in group.split() if n.strip() != "_"],
                    "targets": proxies or roots,
                    "ssl_configured": "ssl_certificate" in content,
                }
            )

    certs: list[dict[str, Any]] = []
    if LETSENCRYPT_LIVE_DIR.exists():
        for domain_dir in sorted(LETSENCRYPT_LIVE_DIR.iterdir()):
            cert_file = domain_dir / "cert.pem"
            if not cert_file.exists():
                continue
            rc, out, _ = run_cmd(["openssl", "x509", "-in", str(cert_file), "-noout", "-enddate"])
            days_left = None
            not_after = None
            if rc == 0 and out.startswith("notAfter="):
                not_after = out.split("=", 1)[1].strip()
                try:
                    dt = datetime.strptime(not_after, "%b %d %H:%M:%S %Y %Z").replace(tzinfo=timezone.utc)
                    days_left = (dt - datetime.now(timezone.utc)).days
                except ValueError:
                    days_left = None
            certs.append({"domain": domain_dir.name, "not_after": not_after, "days_left": days_left})

    return {"vhosts": vhosts, "certs": certs}


def get_projects_inventory() -> list[dict[str, Any]]:
    """Daftar aplikasi ProjectWeb di /home/project tanpa membaca isi .env."""
    if not PROJECT_DIR.exists():
        return []
    projects: list[dict[str, Any]] = []
    for entry in sorted(PROJECT_DIR.iterdir()):
        if not entry.is_dir() or entry.name.startswith("."):
            continue
        is_git = (entry / ".git").exists()
        branch = None
        dirty = None
        if is_git:
            rc_b, out_b, _ = run_cmd(["git", "-C", str(entry), "rev-parse", "--abbrev-ref", "HEAD"])
            if rc_b == 0:
                branch = out_b
            rc_s, out_s, _ = run_cmd(["git", "-C", str(entry), "status", "--porcelain"])
            if rc_s == 0:
                dirty = bool(out_s.strip())
        projects.append(
            {
                "name": entry.name,
                "path": str(entry),
                "is_git": is_git,
                "branch": branch,
                "dirty": dirty,
                "has_env": (entry / ".env").exists(),
                "has_env_example": (entry / ".env.example").exists(),
                "has_agents_md": (entry / "AGENTS.md").exists(),
            }
        )
    return projects


def get_backup_inventory() -> dict[str, Any]:
    """Audit ringkas direktori backup /var/backups/apps secara read-only."""
    if not BACKUP_DIR.exists():
        return {"exists": False, "sql_count": 0, "tar_count": 0, "pre_migration_snapshots": [], "recent_files": []}

    sql_files: list[Path] = []
    tar_files: list[Path] = []
    pre_mig: list[str] = []
    all_files: list[tuple[float, Path, int]] = []

    for root, dirs, files in os.walk(BACKUP_DIR):
        root_path = Path(root)
        for d in dirs:
            if d.startswith("pre-migration-"):
                pre_mig.append(d)
        for f in files:
            fpath = root_path / f
            try:
                st = fpath.stat()
            except OSError:
                continue
            if f.endswith((".sql", ".sql.gz")):
                sql_files.append(fpath)
            elif f.endswith(".tar.gz"):
                tar_files.append(fpath)
            all_files.append((st.st_mtime, fpath, st.st_size))

    all_files.sort(key=lambda x: x[0], reverse=True)
    recent = [
        {
            "name": str(path.relative_to(BACKUP_DIR)),
            "size_mb": round(size / (1024 * 1024), 2),
            "modified_at": datetime.fromtimestamp(mtime, tz=timezone.utc).astimezone().isoformat(timespec="seconds"),
        }
        for mtime, path, size in all_files[:10]
    ]
    return {
        "exists": True,
        "path": str(BACKUP_DIR),
        "sql_count": len(sql_files),
        "tar_count": len(tar_files),
        "pre_migration_snapshots": sorted(pre_mig, reverse=True),
        "recent_files": recent,
    }


def collect_snapshot() -> dict[str, Any]:
    """Kumpulkan seluruh status VPS untuk endpoint /api/status."""
    return {
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "system": get_system_metrics(),
        "software": get_installed_software(),
        "services": get_systemd_services(),
        "docker": get_docker_containers(),
        "hermes": get_hermes_status(),
        "endpoints": get_ports_and_endpoints(),
        "nginx_ssl": get_nginx_and_ssl(),
        "projects": get_projects_inventory(),
        "backups": get_backup_inventory(),
    }


class MonitorHandler(BaseHTTPRequestHandler):
    """HTTP handler untuk UI dashboard dan JSON API /api/status."""

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        return

    def _send_json(self, payload: dict[str, Any], status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, path: Path) -> None:
        if not path.exists():
            self.send_error(HTTPStatus.NOT_FOUND, "index.html not found")
            return
        body = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        route = self.path.split("?", 1)[0]
        if route == "/api/status":
            self._send_json(collect_snapshot())
        elif route == "/health":
            self._send_json({"ok": True, "ts": int(time.time())})
        elif route in ("/", "/index.html"):
            self._send_html(STATIC_INDEX)
        else:
            self.send_error(HTTPStatus.NOT_FOUND, "Not Found")


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), MonitorHandler)
    print(f"AI-V1 VPS Monitor listening on http://{HOST}:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

