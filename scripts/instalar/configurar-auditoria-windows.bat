@echo off
REM ===========================================================================
REM  configurar-auditoria-windows.bat
REM  Política de auditoría necesaria para el EDR y los casos de uso.
REM  Funciona en Windows Server 2019 y Windows 7 (CMD como Administrador).
REM  Usa los GUID de subcategoría: no depende del idioma del sistema.
REM ===========================================================================

echo [..] Paso 1/4 - Politica de auditoria
REM Logon (4624/4625)
auditpol /set /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
REM Account Lockout (4625 por bloqueo)
auditpol /set /subcategory:"{0CCE9217-69AE-11D9-BED3-505054503030}" /failure:enable
REM User Account Management (4720, 4722, 4724, 4726)
auditpol /set /subcategory:"{0CCE9235-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
REM Security Group Management (4728, 4732)
auditpol /set /subcategory:"{0CCE9237-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
REM Process Creation (4688) - telemetria de procesos, clave en Windows 7 sin Sysmon
auditpol /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:enable

echo [..] Paso 2/4 - Linea de comandos en el evento 4688
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f

echo [..] Paso 3/4 - Registro de bloques de script de PowerShell (4104, solo PowerShell 5.1)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" /v EnableScriptBlockLogging /t REG_DWORD /d 1 /f

echo [..] Paso 4/4 - Tamano del registro de Seguridad (200 MB)
wevtutil sl Security /ms:209715200

echo.
echo [OK] Verificacion:
auditpol /get /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030},{0CCE9235-69AE-11D9-BED3-505054503030},{0CCE9237-69AE-11D9-BED3-505054503030},{0CCE922B-69AE-11D9-BED3-505054503030}"
