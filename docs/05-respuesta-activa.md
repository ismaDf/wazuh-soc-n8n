# 5. Respuesta activa (Wazuh + n8n)

Este proyecto usa **dos niveles de respuesta**, como en un SOC real:

| Nivel | Quién actúa | Cuándo | Ejemplo |
|---|---|---|---|
| **Reflejo** (segundos) | Active Response nativo de Wazuh | Patrón inequívoco y acción reversible | Fuerza bruta → bloquear IP 10 min |
| **Orquestado** (decisión) | n8n vía API de Wazuh | Requiere contexto (allowlist, tipo de agente, severidad combinada) | Login exitoso tras fuerza bruta → bloquear IP + escalar al analista |
| **Humano** | Analista | Acción de alto impacto | Deshabilitar cuenta, aislar servidor, restaurar |

## 5.1 Matriz de respuesta del proyecto

| Caso | Regla(s) | Respuesta automática | Dónde se configura |
|---|---|---|---|
| UC-01 SSH | 5763, 5712 | `firewall-drop` (Ubuntu) / `firewalld-drop` (Red Hat), 600 s | ossec.conf (nativo) |
| UC-01 SSH comprometido | 40112 | Bloqueo vía API + aviso crítico | n8n |
| UC-02 RDP | 100110, 100111 | `netsh` en Windows, 600 s | ossec.conf (nativo) |
| UC-02 RDP comprometido | 100112 | Bloqueo vía API + aviso crítico | n8n |
| UC-03 Malware | 87105 | `remove-threat.sh` elimina el archivo | ossec.conf (nativo) |
| UC-04 a UC-07 | 1001xx | Solo aviso: requiere validación humana | n8n |
| UC-08 SO obsoleto | Inventario API | Aviso semanal | n8n |

## 5.2 Agregar los comandos y respuestas en el manager

Edita `/var/ossec/etc/ossec.conf` en `wazuh-srv` y agrega los bloques `<command>` y `<active-response>` de [`wazuh/config/manager-ossec.conf`](../wazuh/config/manager-ossec.conf).

Puntos importantes verificados en Wazuh 4.14:

- El `ossec.conf` por defecto define `firewall-drop`, pero **no** `netsh` ni `firewalld-drop`: hay que agregarlos (los binarios ya vienen instalados en los agentes).
- Los scripts de bloqueo toman la IP de `data.srcip` y, en alertas de Windows, de `data.win.eventdata.ipAddress`. Por eso `netsh` funciona directamente con las reglas UC-02.
- `location local` ejecuta la acción en el equipo que generó la alerta, que es lo correcto para bloquear al atacante en el equipo atacado.

```bash
sudo systemctl restart wazuh-manager
```

## 5.3 Instalar `remove-threat.sh` en los agentes Linux (UC-03)

En `lnx-01` y `rhel-01`:

```bash
# Ubuntu/Debian
sudo apt install -y jq
# Red Hat
sudo dnf install -y jq

sudo cp remove-threat.sh /var/ossec/active-response/bin/
sudo chown root:wazuh /var/ossec/active-response/bin/remove-threat.sh
sudo chmod 750 /var/ossec/active-response/bin/remove-threat.sh
sudo systemctl restart wazuh-agent
```

El script tiene una **lista de rutas permitidas** (`/tmp`, `Downloads`): nunca borrará archivos de sistema aunque una alerta mal formada lo pida.

## 5.4 Respuesta orquestada desde n8n

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

## 5.5 Revertir un bloqueo (rollback)

| Sistema | Ver bloqueos | Quitar bloqueo |
|---|---|---|
| Ubuntu/Debian | `sudo iptables -L INPUT -n --line-numbers` | `sudo iptables -D INPUT -s IP -j DROP` y `sudo iptables -D FORWARD -s IP -j DROP` (el script bloquea en ambas cadenas) |
| Red Hat | `sudo firewall-cmd --list-rich-rules` | `sudo firewall-cmd --remove-rich-rule='rule family=ipv4 source address=IP drop'` (la regla es solo *runtime*: también desaparece con `firewall-cmd --reload`) |
| Windows | `netsh advfirewall firewall show rule name="WAZUH ACTIVE RESPONSE BLOCKED IP"` | `netsh advfirewall firewall delete rule name="WAZUH ACTIVE RESPONSE BLOCKED IP"` |

Registro de lo ejecutado en cada agente: `/var/ossec/logs/active-responses.log` (Linux) o `C:\Program Files (x86)\ossec-agent\active-response\active-responses.log` (Windows).

## 5.6 Checklist

- [ ] `netsh` y `firewalld-drop` definidos como `<command>`
- [ ] `remove-threat.sh` instalado en ambos Linux con `jq`
- [ ] Prueba manual de `PUT /active-response` exitosa
- [ ] Sabes revertir un bloqueo en los 3 sistemas
