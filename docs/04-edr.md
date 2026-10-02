# 4. Sysmon y telemetría EDR en Windows

Wazuh por sí solo lee el registro de Seguridad de Windows. Para comportarse como **EDR** necesita visibilidad de procesos, red, registro y archivos: eso lo aporta **Sysmon**.

En este laboratorio hay dos endpoints Windows con capacidades distintas:

| | Windows Server 2019 (`ws2019`) | Windows 7 (`win7`) |
|---|---|---|
| Sysmon | Versión actual | Solo una versión antigua compatible con Win7 (las recientes ya no lo soportan); verifica antes de instalar |
| PowerShell | 5.1 → registro de bloques de script (4104) | 2.0 → sin 4104; solo eventos clásicos |
| Auditoría avanzada (`auditpol`) | Sí | Sí |
| Papel en el proyecto | Endpoint principal de detección | Equipo heredado: casos UC-04, UC-06 y UC-08 |

## 4.1 Instalar Sysmon en `ws2019`

1. Descarga Sysmon desde Microsoft Sysinternals: <https://learn.microsoft.com/sysinternals/downloads/sysmon>
2. Descarga una configuración mantenida por la comunidad, por ejemplo la de **SwiftOnSecurity** (`sysmonconfig-export.xml`): <https://github.com/SwiftOnSecurity/sysmon-config>
3. En PowerShell **como Administrador**, desde la carpeta donde descomprimiste:

```powershell
.\Sysmon64.exe -accepteula -i .\sysmonconfig-export.xml
Get-Service Sysmon64
```

### Windows 7

Intenta la instalación igual; si el instalador falla por versión de sistema, **no fuerces nada**: deja `win7` solo con el registro de Seguridad y System. Eso ya alcanza para UC-04, UC-06 y UC-08, y además es un hallazgo real que documentar ("endpoint sin telemetría EDR por obsolescencia").

## 4.2 Enviar los canales a Wazuh

Usa la configuración centralizada para no editar cada máquina. En `wazuh-srv`, edita `/var/ossec/etc/shared/default/agent.conf` y agrega el contenido de [`wazuh/config/agent-windows.conf`](../wazuh/config/agent-windows.conf) (ya viene dentro de `<agent_config os="Windows">`).

Lo esencial:

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>

<localfile>
  <location>Microsoft-Windows-PowerShell/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

Valida la sintaxis y reinicia:

```bash
sudo /var/ossec/bin/verify-agent-conf
sudo systemctl restart wazuh-manager
```

Los agentes reciben la configuración en unos minutos. Para forzarlo en Windows:

```powershell
Restart-Service -Name WazuhSvc
```

## 4.3 Habilitar la auditoría necesaria para los casos de uso

En `ws2019` y `win7` (consola como Administrador):

```powershell
# Inicios de sesión (4624/4625) y gestión de cuentas (4720/4732)
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable
auditpol /set /subcategory:"Security Group Management" /success:enable /failure:enable
```

Solo en `ws2019` (PowerShell 5.1):

```powershell
# Registro de bloques de script de PowerShell (evento 4104)
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockLogging -Value 1
```

> En Windows 7 `auditpol` acepta los nombres de subcategoría en el idioma del sistema. Si tu Win7 está en español, usa `auditpol /list /subcategory:*` para ver los nombres exactos (ej. "Inicio de sesión").

## 4.4 Verificar

En el Dashboard → **Threat Hunting** (o **Discover** sobre `wazuh-alerts-*`), filtra:

```
agent.name: ws2019 and rule.groups: sysmon
```

Abre `notepad.exe` en el servidor y deberías ver eventos de creación de proceso (Sysmon Event ID 1).

## 4.5 Capacidades EDR resultantes

| Capacidad EDR | Cómo se cubre |
|---|---|
| Visibilidad de procesos y línea de comandos | Sysmon EID 1 |
| Conexiones de red por proceso | Sysmon EID 3 |
| Integridad de archivos | FIM (syscheck) de Wazuh |
| Detección de malware | Integración VirusTotal (+ YARA opcional) |
| Inventario y vulnerabilidades | Syscollector + Vulnerability Detection |
| Respuesta en el endpoint | Active Response (bloqueo de IP, eliminación de archivos) |
