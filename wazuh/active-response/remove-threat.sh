#!/bin/bash
# =============================================================================
# remove-threat.sh — Respuesta activa de Wazuh (UC-03)
# Elimina el archivo que VirusTotal marcó como malicioso (regla 87105).
#
# Instalar en cada agente Linux:
#   cp remove-threat.sh /var/ossec/active-response/bin/
#   chown root:wazuh /var/ossec/active-response/bin/remove-threat.sh
#   chmod 750 /var/ossec/active-response/bin/remove-threat.sh
# Requiere: jq  (Ubuntu: apt install jq · RHEL: dnf install jq)
# =============================================================================

LOG_FILE="/var/ossec/logs/active-responses.log"
log() { echo "$(date '+%Y/%m/%d %H:%M:%S') remove-threat: $*" >> "$LOG_FILE"; }

read -r INPUT_JSON

COMMAND=$(echo "$INPUT_JSON" | jq -r '.command // empty')
FILENAME=$(echo "$INPUT_JSON" | jq -r '.parameters.alert.data.virustotal.source.file // empty')

if [ "$COMMAND" != "add" ]; then
    log "comando '$COMMAND' ignorado"
    exit 0
fi

if [ -z "$FILENAME" ]; then
    log "la alerta no contiene data.virustotal.source.file"
    exit 1
fi

# Medida de seguridad: solo se actúa dentro de rutas monitoreadas de descarga
case "$FILENAME" in
    /tmp/*|/root/Downloads/*|/home/*/Downloads/*) ;;
    *) log "ruta fuera de la lista permitida, no se elimina: $FILENAME"; exit 1 ;;
esac

if [ ! -f "$FILENAME" ]; then
    log "el archivo ya no existe: $FILENAME"
    exit 0
fi

HASH=$(sha256sum "$FILENAME" | awk '{print $1}')
if rm -f -- "$FILENAME"; then
    log "ELIMINADO $FILENAME sha256=$HASH"
else
    log "ERROR al eliminar $FILENAME"
    exit 1
fi
exit 0
