#!/bin/bash
# =============================================================================
#  instalar-integracion-n8n.sh
#  Instala la integración Wazuh -> n8n en el MANAGER (wazuh-srv).
#
#  Uso (desde la raíz del repositorio, como root):
#    sudo bash scripts/instalar/instalar-integracion-n8n.sh \
#         --url http://192.168.100.10:5678/webhook/wazuh-alertas \
#         --token 3f9c...e1 \
#         [--nivel 7]
#
#  Qué hace:
#    1. Verifica requisitos (root, Wazuh manager, archivos del repo).
#    2. Respalda /var/ossec/etc/ossec.conf con fecha y hora.
#    3. Copia custom-n8n.py y crea el wrapper custom-n8n.
#    4. Agrega el bloque <integration> (si no existe ya).
#    5. Valida la configuración y reinicia wazuh-manager.
#    6. Confirma en ossec.log que la integración quedó habilitada.
#    7. Prueba la conexión con n8n.
# =============================================================================
set -euo pipefail

WAZUH=/var/ossec
CONF=$WAZUH/etc/ossec.conf
INTEG_DIR=$WAZUH/integrations
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
NIVEL=7
URL=""
TOKEN=""

verde() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
info()  { printf '\033[36m[..]\033[0m %s\n' "$*"; }
aviso() { printf '\033[33m[!!]\033[0m %s\n' "$*"; }
error() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --url)   URL="$2"; shift 2 ;;
        --token) TOKEN="$2"; shift 2 ;;
        --nivel) NIVEL="$2"; shift 2 ;;
        -h|--help) sed -n 2,22p "$0"; exit 0 ;;
        *) error "Parámetro desconocido: $1 (usa --help)" ;;
    esac
done

# ---------------------------------------------------------------- 1. Requisitos
info "Paso 1/7 · Verificando requisitos"
[ "$(id -u)" -eq 0 ] || error "Ejecuta como root (sudo)."
[ -n "$URL" ] && [ -n "$TOKEN" ] || error "Faltan --url y/o --token (usa --help)."
[[ "$URL" =~ ^https?://[^/]+/webhook/ ]] || error "La URL debe ser la de producción de n8n: http(s)://HOST:5678/webhook/..."
[[ "$TOKEN" =~ ^[A-Za-z0-9._-]{16,}$ ]] || error "El token debe tener al menos 16 caracteres, sin espacios (genera uno con: openssl rand -hex 24)."
[[ "$NIVEL" =~ ^[0-9]+$ ]] && [ "$NIVEL" -le 15 ] || error "--nivel debe ser un número entre 0 y 15."
[ -f "$CONF" ] || error "No existe $CONF. ¿Este equipo es el Wazuh manager?"
[ -f "$INTEG_DIR/slack" ] || error "No existe $INTEG_DIR/slack (wrapper genérico de Wazuh)."
[ -f "$REPO_DIR/wazuh/integrations/custom-n8n.py" ] || error "No encuentro wazuh/integrations/custom-n8n.py. Ejecuta el script desde el repositorio."
verde "Requisitos completos (repositorio: $REPO_DIR)"

# ---------------------------------------------------------------- 2. Respaldo
info "Paso 2/7 · Respaldando ossec.conf"
BACKUP="$CONF.bak-$(date +%Y%m%d-%H%M%S)"
cp -p "$CONF" "$BACKUP"
verde "Respaldo creado: $BACKUP"

# ---------------------------------------------------------------- 3. Script
info "Paso 3/7 · Instalando el script de integración"
install -m 750 -o root -g wazuh "$REPO_DIR/wazuh/integrations/custom-n8n.py" "$INTEG_DIR/custom-n8n.py"
install -m 750 -o root -g wazuh "$INTEG_DIR/slack" "$INTEG_DIR/custom-n8n"
ls -l "$INTEG_DIR"/custom-n8n*
verde "Script y wrapper instalados"

# ---------------------------------------------------------------- 4. ossec.conf
info "Paso 4/7 · Configurando ossec.conf"
if grep -q "<name>custom-n8n</name>" "$CONF"; then
    aviso "ossec.conf ya tiene una integración custom-n8n: no se agrega otra."
    aviso "Si quieres cambiar URL/token, edítalo con: sudo nano $CONF"
else
    cat >> "$CONF" <<EOF

<!-- Integración Wazuh -> n8n (agregado por instalar-integracion-n8n.sh el $(date '+%F %T')) -->
<ossec_config>
  <integration>
    <name>custom-n8n</name>
    <hook_url>$URL</hook_url>
    <api_key>$TOKEN</api_key>
    <level>$NIVEL</level>
    <alert_format>json</alert_format>
  </integration>
</ossec_config>
EOF
    verde "Bloque <integration> agregado (nivel >= $NIVEL)"
fi

# ---------------------------------------------------------------- 5. Validar y reiniciar
info "Paso 5/7 · Validando configuración"
if ! "$WAZUH/bin/wazuh-analysisd" -t >/tmp/wazuh-analysisd-t.log 2>&1; then
    cat /tmp/wazuh-analysisd-t.log
    cp -p "$BACKUP" "$CONF"
    error "La validación falló. Se restauró el respaldo. Revisa el mensaje anterior."
fi
verde "Configuración válida"

info "Reiniciando wazuh-manager (puede tardar ~30 s)"
MARCA=$(date '+%Y/%m/%d %H:%M:%S')
systemctl restart wazuh-manager
sleep 10

# ---------------------------------------------------------------- 6. Confirmar
info "Paso 6/7 · Confirmando en ossec.log"
for _ in 1 2 3 4 5 6; do
    if awk -v m="$MARCA" '$0 >= m' "$WAZUH/logs/ossec.log" | grep -q "Enabling integration for: 'custom-n8n'"; then
        verde "wazuh-integratord habilitó la integración custom-n8n"
        break
    fi
    sleep 5
done
awk -v m="$MARCA" '$0 >= m' "$WAZUH/logs/ossec.log" | grep -E "integrator" | tail -5 || true
if awk -v m="$MARCA" '$0 >= m' "$WAZUH/logs/ossec.log" | grep -qE "integrator.*(ERROR|Unable)"; then
    aviso "Hay errores de integratord arriba. Consulta docs/10-troubleshooting.md"
fi

# ---------------------------------------------------------------- 7. Conectividad
info "Paso 7/7 · Probando conexión con n8n"
BASE=$(echo "$URL" | sed -E 's#(https?://[^/]+)/.*#\1#')
if CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$BASE/healthz"); [ "$CODE" = "200" ]; then
    verde "n8n responde en $BASE (HTTP 200)"
else
    aviso "n8n no respondió en $BASE/healthz (código: ${CODE:-sin respuesta}). Revisa firewall o que el contenedor esté arriba."
fi

echo
verde "Instalación terminada."
echo "    Siguiente: prueba el webhook (docs/06, paso 7) y luego genera una alerta real (paso 8)."
echo "    Para revertir: sudo cp -p $BACKUP $CONF && sudo systemctl restart wazuh-manager"
