<#
  instalar-sysmon.ps1
  Instala o actualiza Sysmon con la configuración de SwiftOnSecurity en Windows Server 2019.
  (La versión actual de Sysmon no soporta oficialmente Windows 7: ver capítulo 4.)

  Uso (PowerShell como Administrador):
    powershell -ExecutionPolicy Bypass -File .\instalar-sysmon.ps1
#>
$ErrorActionPreference = "Stop"
function Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Info($m) { Write-Host "[..] $m" -ForegroundColor Cyan }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw "Ejecuta PowerShell como Administrador." }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dir = "C:\Tools\Sysmon"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Info "Paso 1/4 · Descargando Sysmon (Microsoft Sysinternals)"
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "$dir\Sysmon.zip" -UseBasicParsing
Expand-Archive -Path "$dir\Sysmon.zip" -DestinationPath $dir -Force
Ok "Sysmon en $dir"

Info "Paso 2/4 · Descargando configuración (SwiftOnSecurity/sysmon-config)"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "$dir\sysmonconfig.xml" -UseBasicParsing
Ok "Configuración en $dir\sysmonconfig.xml"

Info "Paso 3/4 · Instalando o actualizando"
if (Get-Service Sysmon64 -ErrorAction SilentlyContinue) {
    & "$dir\Sysmon64.exe" -c "$dir\sysmonconfig.xml"
    Ok "Sysmon ya estaba instalado: configuración actualizada"
} else {
    & "$dir\Sysmon64.exe" -accepteula -i "$dir\sysmonconfig.xml"
    Ok "Sysmon instalado"
}

Info "Paso 4/4 · Verificando"
Get-Service Sysmon64 | Format-Table Name, Status, StartType -AutoSize
Start-Process notepad.exe; Start-Sleep 3; Get-Process notepad -ErrorAction SilentlyContinue | Stop-Process
$ev = Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 50 |
      Where-Object { $_.Id -eq 1 -and $_.Message -match "notepad.exe" } | Select-Object -First 1
if ($ev) { Ok "Evento Sysmon 1 (creación de proceso) registrado: $($ev.TimeCreated)" }
else     { Write-Host "[!!] No se encontró el evento de notepad.exe; revisa el Visor de eventos" -ForegroundColor Yellow }
