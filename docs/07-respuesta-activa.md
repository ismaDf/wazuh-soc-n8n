# 7. Respuesta activa (Wazuh + n8n)

Este proyecto usa **dos niveles de respuesta**, como en un SOC real:

| Nivel | Quién actúa | Cuándo | Ejemplo |
|---|---|---|---|
| **Reflejo** (segundos) | Active Response nativo de Wazuh | Patrón inequívoco y acción reversible | Fuerza bruta → bloquear IP 10 min |
| **Orquestado** (decisión) | n8n vía API de Wazuh | Requiere contexto (allowlist, tipo de agente, severidad combinada) | Login exitoso tras fuerza bruta → bloquear IP + escalar al analista |
| **Humano** | Analista | Acción de alto impacto | Deshabilitar cuenta, aislar servidor, restaurar |

## 7.1 Matriz de respuesta del proyecto

| Caso | Regla(s) | Respuesta automática | Dónde se configura |
|---|---|---|---|
| UC-01 SSH | 5763, 5712 | `firewall-drop` (Ubuntu) / `firewalld-drop` (Red Hat), 600 s | ossec.conf (nativo) |
| UC-01 SSH comprometido | 40112 | Bloqueo vía API + aviso crítico | n8n |
| UC-02 RDP | 100110, 100111 | `netsh` en Windows, 600 s | ossec.conf (nativo) |
| UC-02 RDP comprometido | 100112 | Bloqueo vía API + aviso crítico | n8n |
| UC-03 Malware | 87105 | `remove-threat.sh` elimina el archivo | ossec.conf (nativo) |
| UC-04 a UC-07 | 1001xx | Solo aviso: requiere validación humana | n8n |
| UC-08 SO obsoleto | Inventario API | Aviso semanal | n8n |

## 7.2 Paso a paso: comandos y respuestas en el manager

Puntos verificados en Wazuh 4.14 que explican la configuración:

- El `ossec.conf` por defecto define `firewall-drop`, pero **no** `netsh` ni `firewalld-drop`: hay que agregarlos (los binarios ya vienen instalados en los agentes).
- Los scripts de bloqueo toman la IP de `data.srcip` y, en alertas de Windows, de `data.win.eventdata.ipAddress`. Por eso `netsh` funciona directamente con las reglas UC-02.
- `location local` ejecuta la acción en el equipo que generó la alerta: se bloquea al atacante en el equipo atacado.

En `wazuh-srv`, desde la carpeta del repositorio:

**Paso 1 · Respaldar y comprobar qué comandos existen ya**

```bash
cd ~/wazuh-soc-n8n
sudo cp -p /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak-$(date +%Y%m%d-%H%M%S)
sudo grep -A1 "<command>" /var/ossec/etc/ossec.conf | grep "<name>"
```

**Salida esperada** (por defecto): `disable-account`, `restart-wazuh`, `firewall-drop`, `host-deny`, `route-null`, `win_route-null`. Si ya aparecen `netsh`, `firewalld-drop` o `remove-threat`, borra esos `<command>` del archivo del repositorio antes del paso 2 para no duplicarlos.

**Paso 2 · Agregar comandos y respuestas activas**

```bash
cat wazuh/config/manager-active-response.xml | sudo tee -a /var/ossec/etc/ossec.conf > /dev/null
sudo /var/ossec/bin/wazuh-analysisd -t && echo "CONFIG OK"
```

El archivo [`manager-active-response.xml`](../wazuh/config/manager-active-response.xml) trae, dentro de su propio `<ossec_config>`, los comandos `netsh`, `firewalld-drop`, `remove-threat` y las 4 respuestas activas de la matriz 5.1.

**Paso 3 · Agregar la integración con VirusTotal (UC-03)**

Crea una cuenta gratuita en <https://www.virustotal.com>, copia tu API key (perfil → *API key*) y:

```bash
export VT_KEY="pega_aqui_tu_api_key"
sed "s/TU_API_KEY_VIRUSTOTAL/$VT_KEY/" wazuh/config/manager-virustotal.xml | sudo tee -a /var/ossec/etc/ossec.conf > /dev/null
sudo grep -A3 "<name>virustotal</name>" /var/ossec/etc/ossec.conf
```

Comprueba que la línea `<api_key>` muestra tu clave real.

**Paso 4 · Reiniciar y verificar**

```bash
sudo /var/ossec/bin/wazuh-analysisd -t && sudo systemctl restart wazuh-manager
sleep 15
sudo grep -iE "virustotal|active.response|ERROR" /var/ossec/logs/ossec.log | tail -8
```

**Salida esperada:** `Enabling integration for: 'virustotal'.` y ningún `ERROR` nuevo.

**Paso 5 · Probar un bloqueo a mano con agent_control** (sin esperar un ataque)

```bash
# Lista las respuestas configuradas y su nombre interno
sudo /var/ossec/bin/agent_control -L

# Bloquea una IP inexistente del lab en lnx-01 (ID 003)
sudo /var/ossec/bin/agent_control -b 192.168.100.99 -f firewall-drop600 -u 003
```

En `lnx-01` verifica y luego revierte:

```bash
sudo tail -2 /var/ossec/logs/active-responses.log
sudo iptables -L INPUT -n | grep 192.168.100.99
sudo iptables -D INPUT -s 192.168.100.99 -j DROP; sudo iptables -D FORWARD -s 192.168.100.99 -j DROP
```

> El nombre interno es el comando + el timeout en segundos: `firewall-drop` con `<timeout>600</timeout>` se llama `firewall-drop600`. Usa exactamente el que muestre `agent_control -L`.

## 7.3 Paso a paso: `remove-threat.sh` en los agentes Linux (UC-03)

En `lnx-01` y en `rhel-01`, con el repositorio clonado (`git clone https://github.com/ismaDf/wazuh-soc-n8n.git`):

```bash
# Dependencia
sudo apt install -y jq          # Ubuntu/Debian
sudo dnf install -y jq          # Red Hat

# Instalación
cd ~/wazuh-soc-n8n
sudo install -m 750 -o root -g wazuh wazuh/active-response/remove-threat.sh /var/ossec/active-response/bin/remove-threat.sh
ls -l /var/ossec/active-response/bin/remove-threat.sh

# Solo Red Hat: restaurar el contexto SELinux del script
sudo restorecon -v /var/ossec/active-response/bin/remove-threat.sh

sudo systemctl restart wazuh-agent
```

Prueba el script **sin Wazuh**, simulando la entrada que recibe:

```bash
mkdir -p /tmp/descargas-lab && echo prueba > /tmp/descargas-lab/archivo-prueba.txt
echo '{"command":"add","parameters":{"alert":{"data":{"virustotal":{"source":{"file":"/tmp/descargas-lab/archivo-prueba.txt"}}}}}}' \
  | sudo /var/ossec/active-response/bin/remove-threat.sh
ls /tmp/descargas-lab
sudo tail -1 /var/ossec/logs/active-responses.log
```

**Salida esperada:** la carpeta queda vacía y el log muestra `ELIMINADO /tmp/descargas-lab/archivo-prueba.txt sha256=...`.

Prueba también la protección de rutas (no debe borrar nada fuera de la lista permitida):

```bash
echo '{"command":"add","parameters":{"alert":{"data":{"virustotal":{"source":{"file":"/etc/hostname"}}}}}}' \
  | sudo /var/ossec/active-response/bin/remove-threat.sh
sudo tail -1 /var/ossec/logs/active-responses.log     # → "ruta fuera de la lista permitida"
ls -l /etc/hostname                                    # sigue existiendo
```

## 7.4 Respuesta orquestada desde n8n

El workflow 01 llama al API así (puedes probarlo a mano para entenderlo):

```bash
TOKEN=$(curl -s -k -u n8n-soar:'PASSWORD' -X POST "https://WAZUH_IP:55000/security/user/authenticate?raw=true")

curl -s -k -X PUT "https://WAZUH_IP:55000/active-response?agents_list=003&wait_for_complete=true" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"command":"firewall-drop","arguments":[],"alert":{"data":{"srcip":"192.168.100.50"}}}'
```

- `command` es el **nombre** definido en `<command>` (`firewall-drop`, `firewalld-drop`, `netsh`). Con prefijo `!` se refiere al nombre del ejecutable.
- n8n elige el comando según el agente: Windows → `netsh`; IDs listados en `agentesRhel` → `firewalld-drop`; resto → `firewall-drop`.
- El nodo **Normalizar alerta** nunca contiene una IP que esté en `allowlist`.

> **Importante:** el bloqueo solicitado por API no siempre aplica el `timeout` de la configuración nativa. Trátalo como **bloqueo hasta revisión** y levántalo manualmente (5.5) al cerrar el incidente.

## 7.5 Revertir un bloqueo (rollback)

| Sistema | Ver bloqueos | Quitar bloqueo |
|---|---|---|
| Ubuntu/Debian | `sudo iptables -L INPUT -n --line-numbers` | `sudo iptables -D INPUT -s IP -j DROP` y `sudo iptables -D FORWARD -s IP -j DROP` (el script bloquea en ambas cadenas) |
| Red Hat | `sudo firewall-cmd --list-rich-rules` | `sudo firewall-cmd --remove-rich-rule='rule family=ipv4 source address=IP drop'` (la regla es solo *runtime*: también desaparece con `firewall-cmd --reload`) |
| Windows | `netsh advfirewall firewall show rule name="WAZUH ACTIVE RESPONSE BLOCKED IP"` | `netsh advfirewall firewall delete rule name="WAZUH ACTIVE RESPONSE BLOCKED IP"` |

Registro de lo ejecutado en cada agente: `/var/ossec/logs/active-responses.log` (Linux) o `C:\Program Files (x86)\ossec-agent\active-response\active-responses.log` (Windows).

## 7.6 Checklist

- [ ] `netsh` y `firewalld-drop` definidos como `<command>`
- [ ] `remove-threat.sh` instalado en ambos Linux con `jq`
- [ ] Prueba manual de `PUT /active-response` exitosa
- [ ] Sabes revertir un bloqueo en los 3 sistemas
