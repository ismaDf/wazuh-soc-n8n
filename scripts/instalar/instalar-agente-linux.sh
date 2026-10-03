#!/bin/bash
# =============================================================================
#  instalar-agente-linux.sh
#  Instala y registra el agente Wazuh en Ubuntu/Debian (apt) o Red Hat (dnf/yum).
#
#  Uso (como root, en el cliente):
#    sudo bash instalar-agente-linux.sh --manager 192.168.100.10 --version 4.14.7 \
#         [--nombre lnx-01] [--grupo linux] [--password CLAVE_DE_REGISTRO]
#
#  --version debe ser IGUAL o MENOR que la del manager
#  (en el manager: /var/ossec/bin/wazuh-control info | grep VERSION)
# =============================================================================
set -euo pipefail

MANAGER=""; VERSION=""; NOMBRE="$(hostname -s)"; GRUPO="linux"; PASSWORD=""

verde() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
info()  { printf '\033[36m[..]\033[0m %s\n' "$*"; }
aviso() { printf '\033[33m[!!]\033[0m %s\n' "$*"; }
error() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --manager)  MANAGER="$2"; shift 2 ;;
        --version)  VERSION="${2#v}"; shift 2 ;;
        --nombre)   NOMBRE="$2"; shift 2 ;;
        --grupo)    GRUPO="$2"; shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        -h|--help)  sed -n 2,13p "$0"; exit 0 ;;
        *) error "Parámetro desconocido: $1" ;;
    esac
done

# ---------------------------------------------------------------- 1. Requisitos
info "Paso 1/6 · Verificando requisitos"
[ "$(id -u)" -eq 0 ] || error "Ejecuta como root (sudo)."
[ -n "$MANAGER" ] && [ -n "$VERSION" ] || error "Faltan --manager y/o --version (usa --help)."
[[ "$VERSION" =~ ^4\.[0-9]+\.[0-9]+$ ]] || error "--version debe tener el formato 4.14.7"
[ -d /var/ossec ] && aviso "Ya existe /var/ossec: el agente parece instalado. Se intentará actualizar/reconfigurar."
if command -v apt-get >/dev/null; then PM=apt
elif command -v dnf >/dev/null; then PM=dnf
elif command -v yum >/dev/null; then PM=yum
else error "No se encontró apt, dnf ni yum."; fi
timeout 4 bash -c "</dev/tcp/$MANAGER/1515" 2>/dev/null || error "No hay conexión al puerto 1515 de $MANAGER (ver capítulo 1, paso 5)."
timeout 4 bash -c "</dev/tcp/$MANAGER/1514" 2>/dev/null || error "No hay conexión al puerto 1514 de $MANAGER."
verde "Gestor de paquetes: $PM · manager $MANAGER alcanzable en 1514/1515"

# ---------------------------------------------------------------- 2. Repositorio
info "Paso 2/6 · Agregando el repositorio oficial de Wazuh"
if [ "$PM" = apt ]; then
    apt-get install -y gnupg apt-transport-https curl >/dev/null
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
    chmod 644 /usr/share/keyrings/wazuh.gpg
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
    apt-get update >/dev/null
else
    rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
    # Documentación oficial: EL8 o anterior usa "protect=1"; EL9 o posterior usa "priority=1"
    EL_MAJOR=$(. /etc/os-release && echo "${VERSION_ID%%.*}")
    if [ "${EL_MAJOR:-9}" -le 8 ]; then OPCION="protect=1"; else OPCION="priority=1"; fi
    cat > /etc/yum.repos.d/wazuh.repo <<EOF
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-\$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
$OPCION
EOF
fi
verde "Repositorio agregado"

# ---------------------------------------------------------------- 3. Instalación
info "Paso 3/6 · Instalando wazuh-agent $VERSION"
export WAZUH_MANAGER="$MANAGER" WAZUH_AGENT_NAME="$NOMBRE" WAZUH_AGENT_GROUP="$GRUPO"
[ -n "$PASSWORD" ] && export WAZUH_REGISTRATION_PASSWORD="$PASSWORD"
if [ "$PM" = apt ]; then
    apt-get install -y "wazuh-agent=${VERSION}-1"
else
    $PM install -y "wazuh-agent-${VERSION}-1"
fi
verde "Paquete instalado"

# ---------------------------------------------------------------- 4. Servicio
info "Paso 4/6 · Habilitando e iniciando el servicio"
systemctl daemon-reload
systemctl enable wazuh-agent >/dev/null 2>&1
systemctl restart wazuh-agent
sleep 10

# ---------------------------------------------------------------- 5. Bloquear actualizaciones
info "Paso 5/6 · Desactivando el repositorio (el agente nunca debe superar la versión del manager)"
if [ "$PM" = apt ]; then
    sed -i "s/^deb /#deb /" /etc/apt/sources.list.d/wazuh.list
    echo "wazuh-agent hold" | dpkg --set-selections
else
    sed -i "s/^enabled=1/enabled=0/" /etc/yum.repos.d/wazuh.repo
fi
verde "Repositorio desactivado"

# ---------------------------------------------------------------- 6. Verificación
info "Paso 6/6 · Verificando conexión con el manager"
systemctl is-active --quiet wazuh-agent && verde "Servicio wazuh-agent activo" || error "El servicio no está activo: journalctl -u wazuh-agent"
if grep -q "Connected to the server" /var/ossec/logs/ossec.log; then
    verde "$(grep 'Connected to the server' /var/ossec/logs/ossec.log | tail -1)"
else
    aviso "Aún no aparece 'Connected to the server'. Revisa: tail -n 30 /var/ossec/logs/ossec.log"
fi
echo
verde "Listo. En el manager confirma con: sudo /var/ossec/bin/agent_control -l"
