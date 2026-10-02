# UC-01 · Fuerza bruta SSH

| Campo | Valor |
|---|---|
| Endpoint(s) | `lnx-01` (Ubuntu/Debian), `rhel-01` (Red Hat) |
| Táctica / Técnica MITRE | Credential Access · T1110.001 Password Guessing |
| Fuente de datos | `/var/log/auth.log` (Debian) · `/var/log/secure` (Red Hat) — se leen por defecto |
| Reglas Wazuh | 5763, 5712 (nivel 10) · 40112 (nivel 12, éxito tras fallos) |
| Severidad SOC | Alta → Crítica si hay login exitoso |
| Respuesta automática | `firewall-drop` / `firewalld-drop` 600 s · n8n bloquea y escala si 40112 |

## Contexto real

SSH expuesto es uno de los servicios más atacados de Internet: botnets de criptominería y variantes tipo Mirai prueban de forma continua usuarios comunes (`root`, `admin`, `ubuntu`, `oracle`) con contraseñas débiles. Un servidor recién publicado suele recibir intentos en cuestión de minutos. El riesgo real no es el intento fallido, sino **el intento que acierta**.

## Lógica de detección

Usa reglas del ruleset oficial (no hace falta crear nuevas):

| Regla | Condición |
|---|---|
| 5760 → **5763** | 8 contraseñas fallidas desde la misma IP en 120 s |
| 5710 → **5712** | 8 intentos con usuarios inexistentes desde la misma IP en 120 s |
| **40112** | Un login exitoso desde una IP que antes acumuló fallos (240 s) |

## Respuesta

- **Nativa (segundos):** al disparar 5763/5712, el agente bloquea la IP 600 s (iptables en Ubuntu, firewalld en Red Hat).
- **n8n:** notifica cada alerta (≥ nivel 7). Si llega **40112**, solicita bloqueo vía API y marca la alerta como **CRÍTICA**: hay posibilidad de credenciales comprometidas.

## Prueba controlada (solo laboratorio)

Desde `kali`, contra `lnx-01` o `rhel-01`. Usa el script [`scripts/pruebas/uc01-ssh-intentos-fallidos.sh`](../../scripts/pruebas/uc01-ssh-intentos-fallidos.sh):

```bash
sudo apt install -y sshpass
bash scripts/pruebas/uc01-ssh-intentos-fallidos.sh 192.168.100.30
```

El script hace 12 intentos con un usuario y contraseña inexistentes. Al octavo, la conexión empezará a fallar por **timeout**: es el bloqueo funcionando.

Para probar **40112** (éxito tras fallos), desactiva temporalmente la respuesta activa (`<disabled>yes</disabled>`), repite el script y luego inicia sesión con un usuario válido de prueba desde la misma IP.

## Evidencia esperada

| Dónde | Qué ver |
|---|---|
| Dashboard → Threat Hunting | `rule.id: (5712 or 5763) and agent.name: lnx-01` |
| Dashboard → Active Response / `active-responses.log` del agente | Línea `firewall-drop` con `"command":"add"` y la IP de Kali |
| Agente | `sudo iptables -L INPUT -n` (Ubuntu) / `sudo firewall-cmd --list-rich-rules` (RHEL) |
| Telegram | Aviso 🟠 ALTA con IP origen y MITRE T1110.001 |

Tras 600 s el agente ejecuta `delete` y el bloqueo desaparece solo.

## Playbook del analista

1. **Validar**: ¿la IP es interna conocida (escáner, monitoreo)? ¿hubo 40112?
2. **Alcance**: buscar la misma IP en todos los agentes: `data.srcip: 192.168.100.50`.
3. **Contener**: si hubo login exitoso → bloquear IP permanente, cerrar sesiones (`who`, `pkill -u usuario`), cambiar contraseña.
4. **Erradicar**: revisar `~/.ssh/authorized_keys`, crontab y usuarios nuevos (enlaza con UC-07).
5. **Recuperar / mejorar**: deshabilitar contraseña en SSH (`PasswordAuthentication no`), `PermitRootLogin no`, usar llaves.

## Falsos positivos y ajuste

- Usuarios que olvidan su contraseña: 8 fallos en 2 min es poco probable para un humano.
- Herramientas de inventario o Ansible mal configuradas: agrega su IP a la allowlist de n8n y, para el bloqueo nativo, excluye con una regla hija de nivel 0 por `srcip`.
