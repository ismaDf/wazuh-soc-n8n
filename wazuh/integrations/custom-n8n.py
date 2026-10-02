#!/usr/bin/env python3
"""
Integración Wazuh -> n8n.

Wazuh (wazuh-integratord) ejecuta este script por cada alerta que cumple los
filtros de <integration> en ossec.conf, con los argumentos:
    argv[1] = ruta del archivo temporal con la alerta en JSON
    argv[2] = valor de <api_key>   (aquí: token compartido con n8n)
    argv[3] = valor de <hook_url>  (URL del webhook de n8n)

Instalación:
    cp custom-n8n.py /var/ossec/integrations/custom-n8n.py
    cp /var/ossec/integrations/slack /var/ossec/integrations/custom-n8n   # wrapper
    chown root:wazuh /var/ossec/integrations/custom-n8n*
    chmod 750 /var/ossec/integrations/custom-n8n*
"""
import json
import sys
import time
from datetime import datetime, timezone

try:
    import requests
except ImportError:
    print("Falta el módulo 'requests' en el Python del framework de Wazuh")
    sys.exit(1)

LOG_FILE = "/var/ossec/logs/integrations.log"
TIMEOUT = 10
RETRIES = 3


def log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"{ts} custom-n8n: {msg}\n")
    except OSError:
        pass


def main(args) -> int:
    if len(args) < 4:
        log(f"argumentos insuficientes: {args}")
        return 1

    alert_file, token, hook_url = args[1], args[2], args[3]

    try:
        with open(alert_file) as f:
            alert = json.load(f)
    except (OSError, json.JSONDecodeError) as exc:
        log(f"no se pudo leer la alerta {alert_file}: {exc}")
        return 1

    headers = {"Content-Type": "application/json", "X-Wazuh-Token": token}

    for intento in range(1, RETRIES + 1):
        try:
            r = requests.post(hook_url, headers=headers, json=alert, timeout=TIMEOUT)
            if r.status_code < 300:
                log(f"alerta {alert.get('id')} regla {alert.get('rule', {}).get('id')} enviada (HTTP {r.status_code})")
                return 0
            log(f"intento {intento}: HTTP {r.status_code} {r.text[:200]}")
        except requests.RequestException as exc:
            log(f"intento {intento}: error de red {exc}")
        time.sleep(2 * intento)

    log(f"alerta {alert.get('id')} NO entregada tras {RETRIES} intentos")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
