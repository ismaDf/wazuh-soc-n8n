#!/bin/bash
# UC-01 · Genera intentos fallidos de SSH contra un equipo DEL LABORATORIO.
# Uso (desde Kali): bash uc01-ssh-intentos-fallidos.sh <IP_LINUX_LAB> [intentos]
# Usa un usuario y contraseña inexistentes: no adivina nada, solo produce los logs.
source "$(dirname "$0")/_verificar-lab.sh"
OBJETIVO="${1:?Indica la IP del Linux del laboratorio}"
INTENTOS="${2:-12}"
verificar_ip_lab "$OBJETIVO"
command -v sshpass >/dev/null || { echo "Instala sshpass: sudo apt install -y sshpass"; exit 1; }

echo "[*] $INTENTOS intentos fallidos contra $OBJETIVO (usuario inexistente soc_no_existe)"
for i in $(seq 1 "$INTENTOS"); do
    inicio=$(date +%s)
    timeout 8 sshpass -p 'contraseña-incorrecta' ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR \
        soc_no_existe@"$OBJETIVO" exit 2>/dev/null
    duracion=$(( $(date +%s) - inicio ))
    if [ "$duracion" -ge 5 ]; then
        echo "  intento $i: sin respuesta (${duracion}s) → probablemente BLOQUEADO por Active Response"
    else
        echo "  intento $i: rechazado (esperado)"
    fi
    sleep 1
done
echo "[*] Revisa en Wazuh: rule.id:(5712 or 5763) · y en el agente: iptables -L / firewall-cmd --list-rich-rules"
