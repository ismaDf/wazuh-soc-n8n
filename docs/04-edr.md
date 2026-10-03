# 4. EDR: telemetría de endpoints con Wazuh — Guía paso a paso

Con el agente instalado (capítulo 3), Wazuh ya ve los registros básicos. Este capítulo le da **visibilidad de EDR**: qué proceso se ejecutó, con qué línea de comandos, quién cambió un archivo y qué comandos corrió root. Todo se configura **desde el manager** por grupos, sin tocar uno por uno los `ossec.conf` de los agentes.

## Qué aporta cada componente

| Endpoint | Fuente de telemetría | Qué ve | Casos de uso |
|---|---|---|---|
| `ws2019` | **Sysmon** (EID 1, 3, 11, 13…) | Procesos con línea de comandos y proceso padre, conexiones de red, archivos y registro | UC-05 |
| `ws2019` | PowerShell 4104 | El código de PowerShell ya decodificado | UC-05 |
| `ws2019`, `win7` | Auditoría de Windows (4624/4625/4720/4732/4688/1102) | Inicios de sesión, cuentas, grupos, procesos, borrado de logs | UC-02, UC-04, UC-06 |
| `lnx-01`, `rhel-01` | **auditd** (clave `audit-wazuh-c`) | Cada comando ejecutado como root | UC-01, UC-07 |
| `lnx-01`, `rhel-01` | **FIM whodata** | Qué archivo cambió, **quién** y **con qué proceso** | UC-03, UC-07 |
| Todos | Syscollector + Vulnerability Detection + SCA | Inventario, vulnerabilidades, hardening | UC-08 |

> **Windows 7 sin Sysmon:** la versión actual de Sysmon solo soporta oficialmente Windows Server 2019+ y Windows 11. En `win7` la telemetría de procesos se obtiene del evento nativo **4688 con línea de comandos** (requiere la actualización KB3004375). Es un EDR degradado, y documentarlo así es parte del hallazgo de UC-08.

## Mapa de la guía

| Paso | Dónde | Qué haces | Punto de control |
|---|---|---|---|
| 1 | wazuh-srv | Publicar `agent.conf` en los grupos `windows` y `linux` | `verify-agent-conf` OK y agentes sincronizados |
| 2 | ws2019 | Instalar Sysmon | Evento Sysmon 1 de `notepad.exe` |
| 3 | ws2019, win7 | Política de auditoría de Windows | `auditpol /get` muestra *Success and Failure* |
| 4 | lnx-01, rhel-01 | auditd + reglas de comandos root | `auditctl -l` muestra `audit-wazuh-c` |
| 5 | wazuh-srv | Verificar que la telemetría llega | Eventos de prueba visibles en Wazuh |
| 6 | VMware | Snapshot `agente-edr-ok` | Snapshot en cada cliente |

---

## Paso 1 · Publicar la configuración EDR por grupos (manager)

En `wazuh-srv`, desde el repositorio:

```bash
cd ~/wazuh-soc-n8n

# Respaldo de lo que hubiera
sudo cp -p /var/ossec/etc/shared/windows/agent.conf /var/ossec/etc/shared/windows/agent.conf.bak 2>/dev/null || true
sudo cp -p /var/ossec/etc/shared/linux/agent.conf   /var/ossec/etc/shared/linux/agent.conf.bak   2>/dev/null || true

# Publicar
sudo install -m 660 -o wazuh -g wazuh wazuh/config/agent-windows.conf /var/ossec/etc/shared/windows/agent.conf
sudo install -m 660 -o wazuh -g wazuh wazuh/config/agent-linux.conf   /var/ossec/etc/shared/linux/agent.conf

# Validar
sudo /var/ossec/bin/verify-agent-conf
```

**Salida esperada:** una línea por grupo sin errores, por ejemplo `verify-agent-conf: Verifying [etc/shared/windows/agent.conf]` seguida de `verify-agent-conf: OK`.

Qué contiene cada archivo:

| Archivo | Contenido |
|---|---|
| [`agent-windows.conf`](../wazuh/config/agent-windows.conf) | Canales Sysmon y PowerShell/Operational, FIM de carpetas de descarga/inicio y la clave `Run` del registro |
| [`agent-linux.conf`](../wazuh/config/agent-linux.conf) | Lectura de `audit.log`, FIM **whodata** en cuentas, sudoers, cron, `.ssh` y systemd; FIM en tiempo real en carpetas de descarga |

> Security, System y Application **no** se declaran: el agente Windows ya los recolecta por defecto y repetirlos duplicaría eventos.

Los agentes descargan la configuración en su siguiente contacto (≈1 minuto) y se reinician solos. Comprueba la sincronización:

```bash
for id in 001 002 003 004; do sudo /var/ossec/bin/agent_groups -S -i $id; done
```

**Salida esperada:** `Agent '001' is synchronized.` para cada agente.

Si alguno sigue sin sincronizar después de 2–3 minutos, reinícialo: `sudo systemctl restart wazuh-agent` (Linux) o `Restart-Service WazuhSvc` (Windows).

## Paso 2 · Sysmon en Windows Server 2019

### Opción A — Instalador

Copia `scripts\instalar\instalar-sysmon.ps1` a `ws2019` y, en PowerShell **como Administrador**:

```powershell
powershell -ExecutionPolicy Bypass -File .\instalar-sysmon.ps1
```

El script descarga Sysmon de Microsoft Sysinternals y la configuración comunitaria de **SwiftOnSecurity**, lo instala (o actualiza la configuración si ya existía) y comprueba que registra la creación de un proceso de prueba.

**Salida esperada (final):**

```
Name     Status  StartType
----     ------  ---------
Sysmon64 Running Automatic
[OK] Evento Sysmon 1 (creación de proceso) registrado: 02/10/2026 19:40:12
```

### Opción B — Manual

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -ItemType Directory -Force C:\Tools\Sysmon | Out-Null
Invoke-WebRequest https://download.sysinternals.com/files/Sysmon.zip -OutFile C:\Tools\Sysmon\Sysmon.zip -UseBasicParsing
Expand-Archive C:\Tools\Sysmon\Sysmon.zip -DestinationPath C:\Tools\Sysmon -Force
Invoke-WebRequest https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml -OutFile C:\Tools\Sysmon\sysmonconfig.xml -UseBasicParsing

C:\Tools\Sysmon\Sysmon64.exe -accepteula -i C:\Tools\Sysmon\sysmonconfig.xml
Get-Service Sysmon64
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 3 | Format-Table TimeCreated, Id, LevelDisplayName -AutoSize
```

Comandos útiles de mantenimiento:

| Acción | Comando |
|---|---|
| Ver la configuración activa | `C:\Tools\Sysmon\Sysmon64.exe -c` |
| Aplicar una configuración nueva | `C:\Tools\Sysmon\Sysmon64.exe -c nueva-config.xml` |
| Desinstalar | `C:\Tools\Sysmon\Sysmon64.exe -u` |

**Confirmar que el agente lee el canal** (en `ws2019`):

```powershell
Select-String -Path "C:\Program Files (x86)\ossec-agent\ossec.log" -Pattern "Analyzing event log" | Select-Object -Last 5
```

**Salida esperada:** una línea `(1951): Analyzing event log: 'Microsoft-Windows-Sysmon/Operational'.` y otra para `PowerShell/Operational`.

## Paso 3 · Política de auditoría de Windows (`ws2019` y `win7`)

Copia `scripts\instalar\configurar-auditoria-windows.bat` a cada equipo y ejecútalo en **CMD como Administrador**:

```bat
configurar-auditoria-windows.bat
```

El script usa los **GUID** de cada subcategoría, así que funciona igual en Windows en español o en inglés. Activa:

| Subcategoría | Eventos | Para qué |
|---|---|---|
| Logon | 4624, 4625 | UC-02 |
| Account Lockout | 4625 por bloqueo | UC-02 |
| User Account Management | 4720, 4722, 4726 | UC-04 |
| Security Group Management | 4728, 4732 | UC-04 |
| Process Creation + línea de comandos | 4688 | Telemetría de procesos (clave en `win7`) |
| ScriptBlockLogging (registro) | 4104 | UC-05 (solo PowerShell 5.1: `ws2019`) |

Además amplía el registro de Seguridad a 200 MB para que no se sobrescriba durante las pruebas.

**Salida esperada (verificación al final del script):**

```
Category/Subcategory                      Setting
Logon/Logoff
  Logon                                   Success and Failure
Account Management
  User Account Management                 Success and Failure
  Security Group Management               Success and Failure
Detailed Tracking
  Process Creation                        Success
```

(En un Windows en español los nombres aparecen traducidos: *Inicio de sesión*, *Aciertos y errores*…)

**Solo en `win7` — confirmar la línea de comandos en el 4688:**

```bat
wmic qfe get HotFixID | findstr KB3004375
```

Si no aparece, el 4688 se registrará **sin** la línea de comandos. Instala esa actualización si la tienes disponible para tu laboratorio; si no, documenta la limitación en UC-08.

**Prueba rápida en `win7`:** abre `cmd.exe` y ejecuta `whoami`. En el Visor de eventos → Registros de Windows → Seguridad debe aparecer un **4688** para `whoami.exe`.

## Paso 4 · auditd y whodata en Linux (`lnx-01` y `rhel-01`)

### Opción A — Script

```bash
cd ~/wazuh-soc-n8n
sudo bash scripts/instalar/configurar-auditd-linux.sh
```

**Salida esperada:**

```
[OK] auditd presente: auditctl version 3.x
[OK] Reglas escritas
-a always,exit -F arch=b64 -S execve -F euid=0 -F key=audit-wazuh-c
-a always,exit -F arch=b32 -S execve -F euid=0 -F key=audit-wazuh-c
[OK] Reglas activas
[OK] auditd ya registra eventos con la clave audit-wazuh-c
```

### Opción B — Manual

```bash
# Instalar
sudo apt-get install -y auditd audispd-plugins     # Ubuntu/Debian
sudo dnf install -y audit                          # Red Hat (normalmente ya viene)

# Reglas persistentes: comandos ejecutados como root
sudo tee /etc/audit/rules.d/wazuh-soc.rules > /dev/null <<'EOF'
-a exit,always -F euid=0 -F arch=b64 -S execve -k audit-wazuh-c
-a exit,always -F euid=0 -F arch=b32 -S execve -k audit-wazuh-c
EOF
sudo augenrules --load
sudo auditctl -l | grep audit-wazuh-c
```

La clave `audit-wazuh-c` ya está en la lista CDB oficial de Wazuh (`/var/ossec/etc/lists/audit-keys`) y la regla **80792** la convierte en alerta *"Audit: Command"*: no hace falta crear reglas.

**Reiniciar el agente** para que inicie whodata con auditd ya activo:

```bash
sudo systemctl restart wazuh-agent
sudo grep -iE "whodata|audit" /var/ossec/logs/ossec.log | tail -5
```

**Salida esperada:** mensajes de `wazuh-syscheckd` indicando que el monitoreo *who-data* quedó iniciado, sin `ERROR`.

> **Red Hat y SELinux:** si ves errores de permisos de audit en `ossec.log`, revisa `sudo ausearch -m avc -ts recent`. Con las políticas por defecto el agente funciona sin cambios.

## Paso 5 · Verificar que la telemetría llega a Wazuh

Genera un evento inofensivo en cada tipo de fuente y búscalo en el manager.

| # | Dónde | Acción de prueba | Verificación en `wazuh-srv` |
|---|---|---|---|
| 1 | lnx-01 | `sudo id` | `rule.id: 80792` con `data.audit.exe: /usr/bin/id` |
| 2 | rhel-01 | `sudo touch /etc/sudoers.d/prueba-edr` | Alerta FIM 554 con `syscheck.audit.login_user.name` = tu usuario |
| 3 | ws2019 | `net user prueba.edr Lab-2026-Edr! /add` | `rule.id: (60109 or 100120)` |
| 4 | win7 | `net user prueba.edr Lab-2026-Edr! /add` | `rule.id: (60109 or 100120)` con `agent.name: win7` |

Comando para observar en vivo mientras haces las pruebas:

```bash
sudo tail -f /var/ossec/logs/alerts/alerts.json | jq -c '{regla:.rule.id, nivel:.rule.level, agente:.agent.name, desc:.rule.description, quien:(.syscheck.audit.login_user.name // .data.audit.auid // .data.win.eventdata.subjectUserName // "")}'
```

**Salida esperada (ejemplo):**

```
{"regla":"80792","nivel":3,"agente":"lnx-01","desc":"Audit: Command: /usr/bin/id.","quien":"1000"}
{"regla":"554","nivel":5,"agente":"rhel-01","desc":"File added to the system.","quien":"admin"}
{"regla":"100120","nivel":10,"agente":"ws2019","desc":"UC-04: Cuenta local creada: prueba.edr por Administrador","quien":"Administrador"}
```

Limpieza: `sudo rm /etc/sudoers.d/prueba-edr` en `rhel-01` y `net user prueba.edr /delete` en ambos Windows.

> **¿Por qué no aparece Sysmon aquí?** La mayoría de eventos Sysmon tienen nivel 0 (solo contexto) y no generan alerta por sí solos: se convierten en alerta cuando una regla detecta algo sospechoso, como en UC-05. Para ver eventos Sysmon "crudos" activa temporalmente `logall_json` (capítulo 10.2) o confía en la línea `Analyzing event log` del paso 2.

En el Dashboard: **Endpoint security → File Integrity Monitoring**, **Threat Hunting** (filtra por agente) y **Vulnerability Detection** deben mostrar datos de los 4 agentes.

## Paso 6 · Snapshot `agente-edr-ok`

En VMware, para cada cliente: **VM → Snapshot → Take Snapshot** → `agente-edr-ok`. Desde este punto puedes ejecutar y revertir las pruebas de los casos de uso cuantas veces quieras.

## Puntos de control del capítulo

| # | Verificación | Comando | Correcto si… |
|---|---|---|---|
| 1 | Configuración de grupo válida | `sudo /var/ossec/bin/verify-agent-conf` | Sin errores |
| 2 | Agentes sincronizados | `sudo /var/ossec/bin/agent_groups -S -i 001` | `is synchronized` |
| 3 | Sysmon activo | `Get-Service Sysmon64` (ws2019) | `Running` |
| 4 | Agente lee Sysmon | `Select-String ... "Analyzing event log"` | Línea con `Sysmon/Operational` |
| 5 | Auditoría Windows | `auditpol /get /category:*` | Logon y Account Management en *Success and Failure* |
| 6 | auditd | `sudo auditctl -l` | Reglas `audit-wazuh-c` |
| 7 | Alertas EDR llegan | `alerts.json` con `jq` | Pruebas 1–4 visibles |

## Checklist del capítulo

- [ ] `agent.conf` publicado en `shared/windows` y `shared/linux`, verificado y sincronizado
- [ ] Sysmon instalado en `ws2019` y leído por el agente
- [ ] Política de auditoría aplicada en `ws2019` y `win7` (4688 con línea de comandos)
- [ ] auditd con reglas `audit-wazuh-c` en `lnx-01` y `rhel-01`
- [ ] Las 4 pruebas del paso 5 visibles en Wazuh
- [ ] Snapshot `agente-edr-ok` en cada cliente
