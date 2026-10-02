# UC-07 · Persistencia en Linux: cron, cuentas y llaves SSH

| Campo | Valor |
|---|---|
| Endpoint(s) | `lnx-01`, `rhel-01` |
| Táctica / Técnica MITRE | Persistence · T1053.003 Cron · T1136.001 Create Local Account · T1098.004 SSH Authorized Keys · Privilege Escalation · T1548.003 Sudo |
| Fuente de datos | FIM en tiempo real ([`agent-linux.conf`](../../wazuh/config/agent-linux.conf)) + logs de `useradd` |
| Reglas Wazuh | 550/554 → **100150** (cron) · **100151** (cuentas/sudoers) · **100152** (authorized_keys) · 5902 (usuario nuevo) |
| Severidad SOC | Crítica |
| Respuesta automática | Aviso con el *diff* del cambio |

## Contexto real

Las campañas de criptominería contra servidores Linux y nubes mal configuradas (por ejemplo, las atribuidas a grupos como TeamTNT o al malware Kinsing) suelen asegurar su permanencia con tres trucos: una línea en cron que vuelve a descargar el minero, una llave SSH propia en `authorized_keys` y, a veces, un usuario nuevo con sudo. Los tres dejan huella en archivos que **casi nunca cambian** en un servidor estable.

## Lógica de detección

FIM vigila en tiempo real (`realtime="yes"`) y con `report_changes="yes"`, de modo que la alerta incluye **qué línea se agregó**:

| Regla | Archivos |
|---|---|
| 100150 | `/etc/crontab`, `/etc/cron.d/*`, `/var/spool/cron/*` |
| 100151 | `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/sudoers`, `/etc/sudoers.d/*` |
| 100152 | `*/.ssh/authorized_keys` |

> `report_changes` guarda copias de los archivos en el agente. Nunca lo actives sobre archivos con secretos de aplicaciones; para `/etc/shadow` Wazuh solo reporta el cambio, no el contenido de los hashes. Si prefieres no arriesgar, quítalo de esa línea.

## Respuesta

Aviso 🔴 con la ruta y el contenido agregado (`syscheck.diff`). No se revierte automáticamente: una tarea cron o un usuario pueden ser cambios legítimos de un administrador.

## Prueba controlada (solo laboratorio)

En `lnx-01` o `rhel-01` (como root): [`scripts/pruebas/uc07-persistencia-linux.sh`](../../scripts/pruebas/uc07-persistencia-linux.sh). Todo es inofensivo:

- Crea `/etc/cron.d/prueba-soc` con una tarea que ejecuta `/bin/true` → 100150.
- Crea el usuario `socprueba` → 5902 y 100151.
- Genera una llave de prueba y la agrega a `/root/.ssh/authorized_keys` → 100152.

El mismo script tiene el modo `limpiar` para revertir todo:

```bash
sudo bash scripts/pruebas/uc07-persistencia-linux.sh limpiar
```

## Evidencia esperada

| Dónde | Qué ver |
|---|---|
| Threat Hunting | `rule.id: (100150 or 100151 or 100152)` |
| Detalle de alerta | `syscheck.diff` con la línea añadida · `syscheck.path` |
| Dashboard → File Integrity Monitoring | Historial de cambios por archivo |

## Playbook del analista

1. **Validar**: ¿hubo cambio aprobado? ¿quién estaba conectado (`last`, alertas de SSH de UC-01)?
2. **Analizar**: leer la línea agregada: ¿descarga algo (`curl`, `wget`)? ¿a qué dominio?
3. **Contener**: eliminar la tarea / llave / usuario, cambiar contraseñas, bloquear el dominio.
4. **Erradicar**: buscar binarios en `/tmp`, `/dev/shm`, procesos con alto CPU.
5. **Mejorar**: activar `whodata` (auditd) en FIM para saber **qué proceso y usuario** hizo el cambio.

## Falsos positivos y ajuste

- Actualizaciones de paquetes que tocan `/etc/cron.d` (ej. `logrotate`, `sysstat`): verás el proceso en `whodata` o coincidirán con ventanas de parches. Excluye archivos concretos con `<ignore>` en syscheck.
