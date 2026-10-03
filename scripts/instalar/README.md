# Instaladores

Scripts que automatizan los pasos de los capítulos. Cada uno verifica requisitos, muestra el avance (`[..]`, `[OK]`, `[!!]`) y termina con una verificación. Todos tienen su **equivalente manual** documentado en el capítulo correspondiente.

| Script | Dónde se ejecuta | Capítulo | Qué hace |
|---|---|---|---|
| `instalar-agente-linux.sh` | lnx-01, rhel-01 | [3](../../docs/03-despliegue-agentes.md) | Repositorio oficial, agente en la versión exacta del manager, registro en grupo, bloqueo de actualizaciones |
| `instalar-agente-windows.ps1` | ws2019 | [3](../../docs/03-despliegue-agentes.md) | Descarga el MSI, instala y registra en el grupo, inicia `WazuhSvc` |
| `instalar-sysmon.ps1` | ws2019 | [4](../../docs/04-edr.md) | Sysmon + configuración SwiftOnSecurity, con prueba de evento |
| `configurar-auditoria-windows.bat` | ws2019, win7 | [4](../../docs/04-edr.md) | Auditoría por GUID (independiente del idioma), 4688 con línea de comandos, PowerShell 4104 |
| `configurar-auditd-linux.sh` | lnx-01, rhel-01 | [4](../../docs/04-edr.md) | auditd con la clave `audit-wazuh-c` (comandos root) |
| `instalar-integracion-n8n.sh` | wazuh-srv | [6](../../docs/06-integracion-wazuh-n8n.md) | Integración Wazuh → n8n con respaldo, validación y reinicio |

Windows 7 no puede ejecutar los `.ps1` (PowerShell 2.0): sigue el procedimiento manual del capítulo 3, paso 5. El `.bat` de auditoría sí funciona en Windows 7.

Si PowerShell bloquea un script: `powershell -ExecutionPolicy Bypass -File .\nombre.ps1`.
