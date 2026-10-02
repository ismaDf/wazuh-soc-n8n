# 1. Verificación del despliegue actual de Wazuh

Antes de automatizar, confirma que la base funciona. Ejecuta todo en `wazuh-srv` salvo que se indique.

## 1.1 Versión y servicios

```bash
sudo /var/ossec/bin/wazuh-control info
sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard --no-pager
```

Anota la versión (ej. `v4.x.x`). Este manual está escrito para **Wazuh 4.14.x**; los nombres de menú del Dashboard pueden variar ligeramente entre versiones menores.

## 1.2 Agentes conectados

```bash
sudo /var/ossec/bin/agent_control -l
```

Debes ver `ws2019`, `win7`, `lnx-01` y `rhel-01` como **Active**. Anota sus IDs (ej. `001`–`004`); los usarás en n8n y en las pruebas.

## 1.3 Flujo de alertas

```bash
sudo tail -f /var/ossec/logs/alerts/alerts.json | jq '{nivel: .rule.level, regla: .rule.id, desc: .rule.description, agente: .agent.name}'
```

> Si no tienes `jq`: `sudo apt install -y jq`.

Genera un evento sencillo (por ejemplo, un `sudo` en `lnx-01`) y confirma que aparece.

## 1.4 Probar las reglas con wazuh-logtest

`wazuh-logtest` es tu mejor amigo para desarrollar reglas sin esperar eventos reales:

```bash
sudo /var/ossec/bin/wazuh-logtest
```

Pega una línea de log, por ejemplo:

```
Oct  2 10:00:00 lnx-01 sshd[1234]: Failed password for invalid user admin from 192.168.100.50 port 50000 ssh2
```

Verás la fase de decodificación y la regla que coincide (`rule id`, `level`).

## 1.5 Acceso a la API de Wazuh

n8n usará la API. Verifica que responde:

```bash
TOKEN=$(curl -s -k -u wazuh-wui:'TU_PASSWORD' -X POST "https://localhost:55000/security/user/authenticate?raw=true")
curl -s -k -H "Authorization: Bearer $TOKEN" "https://localhost:55000/agents?pretty=true&select=id,name,status"
```

> La contraseña de `wazuh-wui` está en el archivo `wazuh-passwords.txt` generado durante la instalación (dentro de `wazuh-install-files.tar`).

### Crear un usuario de API dedicado a n8n (recomendado)

En **Dashboard → Server management → Security → Users**, crea `n8n-soar` y asígnale un rol con permisos mínimos:

- `active-response:command` sobre `agent:id:*`
- `agents:read` sobre `agent:id:*`

Así, si la credencial de n8n se expone, no compromete toda la plataforma.

## 1.6 Checklist

- [ ] Manager, indexer y dashboard en estado `active (running)`
- [ ] Agentes Windows y Linux en estado `Active`
- [ ] `alerts.json` recibe eventos
- [ ] La API responde con token
- [ ] Usuario `n8n-soar` creado con permisos mínimos
