#!/bin/bash
# UC-02 · Genera eventos 4625 en Windows Server DEL LABORATORIO vía SMB.
# Uso (desde Kali):
#   bash uc02-windows-intentos-fallidos.sh <IP_WS2019> fuerza   → 8 fallos, mismo usuario   (100110)
#   bash uc02-windows-intentos-fallidos.sh <IP_WS2019> spray    → 1 fallo por usuario, 6 usuarios (100111)
source "$(dirname "$0")/_verificar-lab.sh"
OBJETIVO="${1:?Indica la IP del Windows Server del laboratorio}"
MODO="${2:-fuerza}"
verificar_ip_lab "$OBJETIVO"
command -v smbclient >/dev/null || { echo "Instala smbclient: sudo apt install -y smbclient"; exit 1; }

intento() { timeout 8 smbclient -L "//$OBJETIVO" -U "$1%$2" -m SMB3 >/dev/null 2>&1; rc=$?; [ $rc -eq 124 ] && echo "  $1 → sin respuesta: probablemente BLOQUEADO (netsh)" || echo "  $1 → rechazado (código $rc)"; }

case "$MODO" in
  fuerza)
    echo "[*] Fuerza bruta simulada: soc.prueba con contraseñas incorrectas"
    for i in $(seq 1 8); do intento "soc.prueba" "incorrecta-$i"; sleep 1; done ;;
  spray)
    echo "[*] Password spraying simulado: una contraseña incorrecta contra varios usuarios"
    for u in soc.prueba admin1 contabilidad soporte backup ventas; do intento "$u" "Primavera2026!"; sleep 1; done ;;
  *) echo "Modo inválido: fuerza | spray"; exit 1 ;;
esac
echo "[*] Revisa en Wazuh: rule.id:(100110 or 100111) · en Windows: netsh advfirewall firewall show rule name=\"WAZUH ACTIVE RESPONSE BLOCKED IP\""
