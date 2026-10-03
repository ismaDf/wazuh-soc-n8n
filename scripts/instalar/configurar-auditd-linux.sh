#!/bin/bash
# =============================================================================
#  configurar-auditd-linux.sh
#  Prepara auditd para el EDR de Wazuh en Ubuntu/Debian y Red Hat:
#   - instala auditd si falta
#   - registra todos los comandos ejecutados como root (clave audit-wazuh-c,
#     reconocida por el ruleset oficial: regla 80792)
#   - deja auditd listo para el modo whodata de FIM (quién cambió un archivo)
#
#  Uso: sudo bash configurar-auditd-linux.sh
# =============================================================================
set -euo pipefail
REGLAS=/etc/audit/rules.d/wazuh-soc.rules

verde() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
info()  { printf '\033[36m[..]\033[0m %s\n' "$*"; }
error() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || error "Ejecuta como root (sudo)."

info "Paso 1/4 · Instalando auditd"
if ! command -v auditctl >/dev/null; then
    if command -v apt-get >/dev/null; then apt-get install -y auditd audispd-plugins
    else dnf install -y audit; fi
fi
systemctl enable auditd >/dev/null 2>&1 || true
verde "auditd presente: $(auditctl -v 2>/dev/null || echo instalado)"

info "Paso 2/4 · Escribiendo reglas en $REGLAS"
cat > "$REGLAS" <<'EOF'
## Wazuh SOC Lab — comandos ejecutados con privilegios de root
-a exit,always -F euid=0 -F arch=b64 -S execve -k audit-wazuh-c
-a exit,always -F euid=0 -F arch=b32 -S execve -k audit-wazuh-c
EOF
verde "Reglas escritas"

info "Paso 3/4 · Cargando reglas"
if command -v augenrules >/dev/null; then augenrules --load >/dev/null; else auditctl -R "$REGLAS"; fi
# En Red Hat el servicio se recarga con "service", no con systemctl
if [ -f /etc/redhat-release ]; then service auditd reload >/dev/null 2>&1 || true
else systemctl restart auditd; fi
auditctl -l | grep audit-wazuh-c || error "Las reglas no quedaron cargadas: revisa 'auditctl -l'"
verde "Reglas activas"

info "Paso 4/4 · Prueba"
id >/dev/null
sleep 1
if ausearch -k audit-wazuh-c -ts recent >/dev/null 2>&1; then
    verde "auditd ya registra eventos con la clave audit-wazuh-c"
else
    printf '\033[33m[!!]\033[0m %s\n' "Sin eventos aún; ejecuta un comando con sudo y revisa: ausearch -k audit-wazuh-c -ts recent"
fi
echo
verde "Listo. El agente leerá /var/log/audit/audit.log con la configuración del grupo 'linux' (capítulo 4)."
