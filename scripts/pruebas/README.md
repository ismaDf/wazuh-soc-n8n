# Pruebas controladas

Scripts para validar cada caso de uso **únicamente en tu laboratorio**. Los scripts que apuntan a otra máquina verifican que el destino sea una IP privada y se niegan a ejecutarse en caso contrario.

| Script | Dónde se ejecuta | Caso | Qué hace |
|---|---|---|---|
| `alerta-ejemplo.json` | `wazuh-srv` (con `curl`) | — | Alerta de ejemplo para probar el webhook de n8n |
| `uc01-ssh-intentos-fallidos.sh` | Kali | UC-01 | Logins SSH fallidos con usuario inexistente |
| `uc02-windows-intentos-fallidos.sh` | Kali | UC-02 | Logins SMB fallidos (modo `fuerza` o `spray`) |
| `uc03-eicar.sh` | lnx-01 / rhel-01 | UC-03 | Descarga el archivo de prueba EICAR (no es malware) |
| `uc04-cuenta-admin.ps1` | ws2019 / win7 | UC-04 | Crea cuenta de prueba y la agrega a Administradores (`-Limpiar` revierte) |
| `uc05-powershell.ps1` | ws2019 | UC-05 | Ejecuta un `Write-Output` codificado e imprime un patrón sospechoso |
| `uc06-borrado-logs.bat` | ws2019 / win7 | UC-06 | Respalda y borra registros de eventos |
| `uc07-persistencia-linux.sh` | lnx-01 / rhel-01 | UC-07 | Cron, usuario y llave SSH de prueba (`limpiar` revierte) |

En Windows, si PowerShell bloquea el script: `powershell -ExecutionPolicy Bypass -File .\uc04-cuenta-admin.ps1`.
