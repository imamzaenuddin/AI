#!/usr/bin/env python3
"""
AI-V1 Model Health Checker, Auto-Failover & Free-Model Scout (CRON)
Digunakan oleh agent `ops-model-hunter` (atau cron container /opt/data/cron/jobs.json).

Fungsi:
1. Memeriksa `model.default` seluruh profil di /opt/data/profiles/*/config.yaml.
2. Menguji apakah model aktif (HTTP 200), habis kuota (402/429), atau error (404/5xx) via 9Router.
3. Mencari katalog model gratisan (`--discover-free`) dari OpenRouter public API & 9Router.
4. Mengganti otomatis (`--auto-switch`) model agent yang mati/habis ke model aktif pengganti
   yang lolos probe tanpa mengubah `key_env` atau `platforms.telegram.enabled`.
5. Menulis laporan ke /opt/data/shared/reports/model-health.json & .md.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def detect_data_dir() -> Path:
    if os.environ.get("HERMES_DATA_DIR"):
        return Path(os.environ["HERMES_DATA_DIR"])
    if Path("/opt/data").exists():
        return Path("/opt/data")
    return Path("/opt/hermes/data")


DATA_DIR = detect_data_dir()
PROFILES_DIR = DATA_DIR / "profiles"
REPORTS_DIR = DATA_DIR / "shared" / "reports"
NINEROUTER_URL = os.environ.get("NINEROUTER_API_URL", "http://host.docker.internal:20128/v1").rstrip("/")
NINEROUTER_API_KEY = os.environ.get("NINEROUTER_API_KEY", "")
OPENROUTER_MODELS_URL = "https://openrouter.ai/api/v1/models"


def http_json(url: str, method: str = "GET", payload: dict[str, Any] | None = None, headers: dict[str, str] | None = None, timeout: int = 12) -> tuple[int, Any, str]:
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    req_headers = {"Accept": "application/json"}
    if payload is not None:
        req_headers["Content-Type"] = "application/json"
    if headers:
        req_headers.update(headers)
    req = urllib.request.Request(url, data=body, headers=req_headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            try:
                return resp.status, json.loads(raw), ""
            except json.JSONDecodeError:
                return resp.status, raw, ""
    except urllib.error.HTTPError as err:
        raw = err.read().decode("utf-8", errors="replace")
        return err.code, None, raw[:300]
    except Exception as exc:  # noqa: BLE001
        return 0, None, str(exc)


def extract_model_default(config_path: Path) -> str | None:
    text = config_path.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r"(?m)^model:\s*\n\s+default:\s*([^\s#]+)", text)
    return m.group(1).strip() if m else None


def replace_model_default(config_path: Path, old_model: str, new_model: str) -> bool:
    """Ganti model.default secara aman dengan membuat cadangan config.yaml.bak."""
    text = config_path.read_text(encoding="utf-8", errors="ignore")
    pattern = re.compile(r"(?m)^(model:\s*\n\s+default:\s*)" + re.escape(old_model) + r"(\s*(?:#.*)?)$")
    if not pattern.search(text):
        return False
    shutil.copy2(config_path, config_path.with_suffix(".yaml.bak"))
    updated = pattern.sub(rf"\g<1>{new_model}\g<2>", text, count=1)
    # Perbarui juga entri model di bawah providers.custom-http.models jika masih memakai nama lama
    updated = updated.replace(f"      {old_model}:", f"      {new_model}:", 1)
    config_path.write_text(updated, encoding="utf-8")
    return True


def list_ninerouter_models() -> tuple[bool, list[str], str]:
    headers = {"Authorization": f"Bearer {NINEROUTER_API_KEY}"} if NINEROUTER_API_KEY else {}
    code, data, err = http_json(f"{NINEROUTER_URL}/models", headers=headers, timeout=8)
    if code != 200 or not isinstance(data, dict):
        return False, [], err or f"HTTP {code}"
    models = [m["id"] for m in data.get("data", []) if isinstance(m, dict) and m.get("id")]
    return True, models, ""


def probe_model(model_id: str) -> dict[str, Any]:
    """Uji completion ringan untuk memastikan model aktif dan kuota belum habis."""
    if not model_id or model_id.startswith("<"):
        return {"model": model_id, "status": "UNCONFIGURED", "http_code": None, "detail": "Placeholder belum diisi"}

    headers = {"Authorization": f"Bearer {NINEROUTER_API_KEY}"} if NINEROUTER_API_KEY else {}
    payload = {
        "model": model_id,
        "messages": [{"role": "user", "content": "Reply with OK"}],
        "max_tokens": 5,
        "temperature": 0,
    }
    code, data, err = http_json(f"{NINEROUTER_URL}/chat/completions", method="POST", payload=payload, headers=headers, timeout=15)
    if code == 200 and isinstance(data, dict) and data.get("choices"):
        return {"model": model_id, "status": "ACTIVE", "http_code": 200, "detail": "OK"}

    low_err = err.lower()
    if code in (402, 429) or "quota" in low_err or "rate limit" in low_err or "credit" in low_err:
        return {"model": model_id, "status": "QUOTA_EXHAUSTED", "http_code": code, "detail": err or f"HTTP {code}"}

    return {"model": model_id, "status": "ERROR", "http_code": code, "detail": err or f"HTTP {code}"}


def discover_free_models(ninerouter_models: list[str]) -> list[dict[str, Any]]:
    """Cari katalog model gratis (prompt=0 & completion=0, context >= 32k) dari OpenRouter & 9Router."""
    candidates: list[dict[str, Any]] = []
    nr_set = set(ninerouter_models)

    code, data, _ = http_json(OPENROUTER_MODELS_URL, timeout=12)
    if code == 200 and isinstance(data, dict):
        for item in data.get("data", []):
            if not isinstance(item, dict):
                continue
            pricing = item.get("pricing") or {}
            if str(pricing.get("prompt")) == "0" and str(pricing.get("completion")) == "0":
                ctx = int(item.get("context_length") or 0)
                if ctx < 32768:
                    continue
                mid = item.get("id", "")
                candidates.append(
                    {
                        "id": mid,
                        "source": "openrouter-free",
                        "context_length": ctx,
                        "in_ninerouter": mid in nr_set,
                    }
                )

    for mid in ninerouter_models:
        if (":free" in mid or "free" in mid.lower() or "combo" in mid.lower()) and not any(c["id"] == mid for c in candidates):
            candidates.append(
                {
                    "id": mid,
                    "source": "ninerouter-local",
                    "context_length": None,
                    "in_ninerouter": True,
                }
            )

    candidates.sort(key=lambda x: (not x["in_ninerouter"], -(x["context_length"] or 0), x["id"]))
    return candidates[:25]


def run_check(auto_switch: bool, do_discover: bool) -> dict[str, Any]:
    now = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    nr_ok, nr_models, nr_err = list_ninerouter_models()

    free_candidates = discover_free_models(nr_models) if do_discover else []
    working_fallback: str | None = None
    tested_pool: list[str] = []

    # Kumpulkan kandidat yang ada di 9Router untuk fallback bila ada agent yang habis/error
    if nr_ok:
        prioritized = [c["id"] for c in free_candidates if c.get("in_ninerouter")] + [
            m for m in nr_models if m not in {c["id"] for c in free_candidates}
        ]
        for candidate in prioritized[:10]:
            res = probe_model(candidate)
            tested_pool.append(f"{candidate}:{res['status']}")
            if res["status"] == "ACTIVE":
                working_fallback = candidate
                break

    agents_report: list[dict[str, Any]] = []
    switches: list[dict[str, str]] = []

    if PROFILES_DIR.exists():
        for pdir in sorted(PROFILES_DIR.iterdir()):
            cfg = pdir / "config.yaml"
            if not (pdir.is_dir() and cfg.exists()):
                continue
            current_model = extract_model_default(cfg)
            probe = probe_model(current_model or "") if nr_ok else {
                "model": current_model,
                "status": "GATEWAY_UNREACHABLE",
                "http_code": None,
                "detail": nr_err,
            }

            switched_to = None
            if auto_switch and probe["status"] in ("QUOTA_EXHAUSTED", "ERROR") and working_fallback and current_model:
                if working_fallback != current_model and replace_model_default(cfg, current_model, working_fallback):
                    switched_to = working_fallback
                    switches.append({"agent": pdir.name, "from": current_model, "to": working_fallback})

            agents_report.append(
                {
                    "agent": pdir.name,
                    "model": switched_to or current_model,
                    "previous_model": current_model if switched_to else None,
                    "status": "SWITCHED" if switched_to else probe["status"],
                    "http_code": probe.get("http_code"),
                    "detail": probe.get("detail"),
                }
            )

    report = {
        "checked_at": now,
        "ninerouter_url": NINEROUTER_URL,
        "ninerouter_reachable": nr_ok,
        "ninerouter_error": nr_err or None,
        "ninerouter_models_count": len(nr_models),
        "working_fallback": working_fallback,
        "agents": agents_report,
        "switches": switches,
        "free_candidates": free_candidates,
    }

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    (REPORTS_DIR / "model-health.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    md_lines = [
        "# Laporan Kesehatan Model AI & Katalog Model Gratis (AI-V1)",
        "",
        f"- **Diperiksa pada:** `{now}`",
        f"- **9Router Gateway:** `{NINEROUTER_URL}` ({'Reachable' if nr_ok else 'Unreachable: ' + nr_err})",
        f"- **Working Fallback:** `{working_fallback or '-'}`",
        "",
        "## Status Model Per Agent",
        "| Agent | Model Aktif | Status | Keterangan |",
        "| :--- | :--- | :--- | :--- |",
    ]
    for a in agents_report:
        md_lines.append(f"| `{a['agent']}` | `{a['model']}` | `{a['status']}` | {a['detail']} |")

    if free_candidates:
        md_lines.extend(
            [
                "",
                "## Kandidat Model Gratis (>= 32k context)",
                "| Model ID | Sumber | Context | Tersedia di 9Router |",
                "| :--- | :--- | :--- | :--- |",
            ]
        )
        for c in free_candidates:
            md_lines.append(
                f"| `{c['id']}` | {c['source']} | {c['context_length'] or '-'} | {'Ya' if c['in_ninerouter'] else 'Perlu routing 9Router'} |"
            )

    (REPORTS_DIR / "model-health.md").write_text("\n".join(md_lines) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="AI-V1 Model Health & Free-Model Scout")
    parser.add_argument("--auto-switch", action="store_true", help="Otomatis ganti model agent yang habis/error ke fallback aktif")
    parser.add_argument("--discover-free", action="store_true", help="Cari daftar model gratis terbaru dari OpenRouter & 9Router")
    args = parser.parse_args()

    report = run_check(auto_switch=args.auto_switch, do_discover=args.discover_free)
    print(json.dumps({"checked_at": report["checked_at"], "agents": len(report["agents"]), "switches": report["switches"], "free_found": len(report["free_candidates"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
