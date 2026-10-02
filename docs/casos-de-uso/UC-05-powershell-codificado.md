# UC-05 · PowerShell codificado y "download cradle"

| Campo | Valor |
|---|---|
| Endpoint(s) | `ws2019` (requiere Sysmon y PowerShell 5.1) |
| Táctica / Técnica MITRE | Execution · T1059.001 PowerShell · Defense Evasion · T1027 Obfuscated Files or Information · T1105 Ingress Tool Transfer |
| Fuente de datos | Sysmon EID 1 (creación de proceso) · PowerShell 4104 (bloque de script) |
| Reglas Wazuh | 61603 → **100130** (nivel 13) · 91802 → **100131** (nivel 12) |
| Severidad SOC | Crítica |
| Respuesta automática | Aviso crítico |

## Contexto real

Ejecutar PowerShell con `-EncodedCommand` (Base64) es una forma clásica de ocultar la intención de un comando a los ojos de un analista o de un filtro simple. Loaders y familias de malware ampliamente documentadas, como Emotet, lo han usado para descargar la siguiente etapa. El patrón "descargar y ejecutar en memoria" (`IEX` + `DownloadString`) evita escribir archivos en disco.

## Lógica de detección

Dos capas complementarias:

| Capa | Ve | Regla |
|---|---|---|
| Sysmon EID 1 | La **línea de comandos** del proceso (`powershell.exe -enc JABj...`) | 100130 |
| PowerShell 4104 | El **código ya decodificado** que se ejecutó | 100131 |

> **Detalle técnico:** en Wazuh, entre reglas "hermanas" gana la primera que coincide. La oficial 91837 ya captura cualquier `IEX`, y las 92027/92057 capturan PowerShell lanzado por PowerShell. Por eso 100130 y 100131 se anclan también a esas reglas (`<if_sid>61603,92027,92057</if_sid>` y `<if_sid>91802,91837</if_sid>`); si no, nunca se dispararían. Es un error clásico al escribir reglas personalizadas: compruébalo siempre con `wazuh-logtest`.

La 4104 es poderosa: aunque el atacante codifique u ofusque, PowerShell 5.1 registra el bloque de script tal como se ejecuta.

> Windows 7 tiene PowerShell 2.0: no genera 4104 y permite evadir el registro. Es un argumento más para el caso UC-08.

## Respuesta

Aviso 🔴 inmediato. No se mata el proceso automáticamente: muchas herramientas legítimas de administración (SCCM, instaladores) también usan comandos codificados. El analista decide con el contexto.

## Prueba controlada (solo laboratorio)

En `ws2019`, [`scripts/pruebas/uc05-powershell.ps1`](../../scripts/pruebas/uc05-powershell.ps1). El script es **inofensivo**:

- Codifica y ejecuta `Write-Output 'prueba-soc-uc05'` con `-EncodedCommand` → 100130.
- Imprime (no ejecuta) un texto que contiene `IEX` y `DownloadString` hacia `127.0.0.1` → la 4104 registra el texto del bloque → 100131.

## Evidencia esperada

| Dónde | Qué ver |
|---|---|
| Threat Hunting | `rule.id: (100130 or 100131)` |
| Detalle de alerta | `win.eventdata.commandLine` con la cadena Base64 · `win.eventdata.parentImage` (quién lo lanzó) |
| Decodificar en el análisis | `[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('...'))` |

## Playbook del analista

1. **Validar**: decodifica el Base64. ¿Qué hace? ¿Quién es el proceso padre (`parentImage`)? Un `winword.exe` o `outlook.exe` como padre es muy sospechoso.
2. **Alcance**: buscar el mismo `commandLine` o hash en otros equipos; revisar conexiones Sysmon EID 3 del mismo `processGuid`.
3. **Contener**: aislar el equipo de la red si hubo descarga exitosa.
4. **Erradicar**: buscar persistencia (Run keys, tareas programadas, servicios nuevos).
5. **Mejorar**: Constrained Language Mode, AppLocker/WDAC, eliminar PowerShell 2.0 (`Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root`).

## Falsos positivos y ajuste

- Agentes de gestión (SCCM, Intune, antivirus) usan comandos codificados: identifica su `parentImage` y crea una regla hija de nivel 0 para ese padre exacto.
