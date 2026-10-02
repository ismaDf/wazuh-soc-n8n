# 8. Solución de problemas

## 8.1 Las alertas no llegan a n8n

| Síntoma | Revisión | Solución |
|---|---|---|
| Nada en `/var/ossec/logs/integrations.log` | `grep -i integrator /var/ossec/logs/ossec.log` | Revisa el bloque `<integration>`; el nombre debe empezar con `custom-` y existir el wrapper `custom-n8n` |
| `Permission denied` en ossec.log | `ls -l /var/ossec/integrations/custom-n8n*` | `chown root:wazuh` y `chmod 750` en ambos archivos |
| `HTTP 403` en integrations.log | Token | El `<api_key>` debe ser idéntico al valor de la credencial Header Auth en n8n |
| `HTTP 404` | URL | Workflow sin activar, o usaste `/webhook-test/` en vez de `/webhook/` |
| `error de red` / timeout | `curl -v http://N8N_IP:5678/healthz` desde wazuh-srv | Firewall (ufw) o `N8N_HOST` incorrecto |
| Llega a n8n pero no a Telegram | Executions → nodo Telegram en rojo | `chat_id` incorrecto (los grupos son negativos) o bot no agregado al grupo |
| Primer aviso llega, los siguientes no | Comportamiento esperado | Anti-spam: misma regla + agente + IP en 5 min. Ajusta `ventanaDedupMin` |

## 8.2 Las reglas personalizadas no se disparan

1. Valida sintaxis: `sudo /var/ossec/bin/wazuh-analysisd -t`.
2. Prueba con `wazuh-logtest` pegando el **JSON del evento** (cópialo de `archives.json` o de un alerta similar). En la fase 3 verás qué regla ganó.
3. Si gana una regla oficial "hermana" en lugar de la tuya, agrega su ID a tu `<if_sid>` (ver la explicación en UC-05).
4. Para ver eventos que **no** generan alerta, activa temporalmente `<logall_json>yes</logall_json>` en `<global>` del ossec.conf y revisa `/var/ossec/logs/archives/archives.json`. Desactívalo después: crece muy rápido.

## 8.3 Active Response no bloquea

| Síntoma | Revisión |
|---|---|
| Nada en `active-responses.log` del agente | ¿El `<command>` existe en el ossec.conf del **manager**? ¿El `rules_id` es el que realmente se disparó? |
| Windows: `netsh` sin efecto | El servicio del agente debe correr como SYSTEM; revisa `active-response\active-responses.log` |
| Red Hat: `firewall-cmd` falla | `systemctl status firewalld` debe estar activo |
| Red Hat: script propio bloqueado | SELinux: `sudo ausearch -m avc -ts recent`; restaura contexto con `sudo restorecon -v /var/ossec/active-response/bin/remove-threat.sh` |
| `remove-threat.sh` no borra | ¿`jq` instalado? ¿la ruta está en la lista permitida del script? |
| API devuelve error en n8n | Permisos del usuario `n8n-soar` (`active-response:command`); ID de agente correcto (3 dígitos, ej. `001`) |

## 8.4 Windows 7

- **El agente no se conecta:** revisa la versión de agente compatible en la documentación oficial de Wazuh y que el equipo tenga TLS 1.2 habilitado.
- **Sysmon no instala:** esperable en versiones recientes. Deja el equipo solo con Security/System (ver capítulo 2).
- **`auditpol` dice que la subcategoría no existe:** el nombre depende del idioma; lista con `auditpol /list /subcategory:*`.

## 8.5 n8n

| Problema | Solución |
|---|---|
| No puedo iniciar sesión por http | `N8N_SECURE_COOKIE=false` ya está en el compose; recrea con `docker compose up -d --force-recreate` |
| "Credentials could not be decrypted" | Cambió `N8N_ENCRYPTION_KEY`; restaura el valor original del `.env` |
| SSL error al llamar al API de Wazuh | Activa *Ignore SSL Issues* en el nodo (los JSON ya lo traen) |
| Workflow importado sin credenciales | Normal: n8n no exporta credenciales. Selecciónalas en cada nodo |

## 8.6 Comandos de diagnóstico útiles

```bash
# Manager
sudo tail -f /var/ossec/logs/ossec.log
sudo tail -f /var/ossec/logs/integrations.log
sudo tail -f /var/ossec/logs/alerts/alerts.json | jq '.rule.id, .rule.description'

# Agente Linux
sudo tail -f /var/ossec/logs/active-responses.log

# n8n
docker compose -f ~/wazuh-soc-n8n/n8n/docker-compose.yml logs -f --tail 100
```
