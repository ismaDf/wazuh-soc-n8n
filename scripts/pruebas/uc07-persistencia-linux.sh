#!/bin/bash
# UC-07 · Simula persistencia INOFENSIVA en Linux (laboratorio). Ejecutar como root.
#   bash uc07-persistencia-linux.sh          → crea los artefactos
#   bash uc07-persistencia-linux.sh limpiar  → los elimina
[ "$(id -u)" -eq 0 ] || { echo "Ejecuta como root (sudo)"; exit 1; }
CRON=/etc/cron.d/prueba-soc
USUARIO=socprueba
LLAVE=/root/.ssh/prueba-soc-uc07
AK=/root/.ssh/authorized_keys

if [ "$1" = "limpiar" ]; then
    rm -f "$CRON"
    id "$USUARIO" >/dev/null 2>&1 && userdel -r "$USUARIO" 2>/dev/null
    [ -f "$AK" ] && sed -i '/prueba-soc-uc07/d' "$AK"
    rm -f "$LLAVE" "$LLAVE.pub"
    echo "[*] Limpieza completa"; exit 0
fi

echo "[*] 1/3 Tarea cron inofensiva → regla 100150"
echo "*/30 * * * * root /bin/true # prueba-soc-uc07" > "$CRON"
sleep 3

echo "[*] 2/3 Usuario de prueba → reglas 5902 y 100151"
useradd -m "$USUARIO"
sleep 3

echo "[*] 3/3 Llave SSH de prueba en authorized_keys → regla 100152"
mkdir -p /root/.ssh && chmod 700 /root/.ssh
ssh-keygen -q -t ed25519 -N '' -C 'prueba-soc-uc07' -f "$LLAVE"
cat "$LLAVE.pub" >> "$AK"

echo "[*] Revisa en Wazuh: rule.id:(100150 or 100151 or 100152 or 5902)"
echo "[*] Limpieza: sudo bash $0 limpiar"
