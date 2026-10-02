#!/bin/bash
# UC-03 · Descarga el ARCHIVO DE PRUEBA EICAR (no es malware) en una carpeta vigilada por FIM.
# Uso (en lnx-01 o rhel-01): bash uc03-eicar.sh
DESTINO=/tmp/descargas-lab
mkdir -p "$DESTINO"
echo "[*] Descargando archivo de prueba estándar EICAR en $DESTINO"
curl -fsSL -o "$DESTINO/eicar.com" https://secure.eicar.org/eicar.com \
  || { echo "[!] No se pudo descargar. Descárgalo manualmente desde https://www.eicar.org y cópialo a $DESTINO"; exit 1; }
ls -l "$DESTINO"
echo "[*] Espera ~1 minuto: FIM (554) → VirusTotal (87105) → remove-threat.sh lo eliminará."
echo "[*] Verifica: ls $DESTINO  ·  sudo tail /var/ossec/logs/active-responses.log"
