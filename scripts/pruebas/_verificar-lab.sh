#!/bin/bash
# Función común: aborta si el objetivo no es una IP privada del laboratorio.
verificar_ip_lab() {
    local ip="$1"
    if [[ ! "$ip" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.) ]]; then
        echo "[!] $ip no es una IP privada. Estas pruebas son SOLO para tu laboratorio." >&2
        exit 1
    fi
}
