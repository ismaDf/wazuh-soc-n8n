<#
  instalar-agente-windows.ps1
  Instala y registra el agente Wazuh en Windows Server 2019 (PowerShell 5.1).
  Para Windows 7 sigue el procedimiento manual del capítulo 3 (PowerShell 2.0 no
  puede ejecutar este script).

  Uso (PowerShell como Administrador):
    powershell -ExecutionPolicy Bypass -File .\instalar-agente-windows.ps1 `
        -Manager 192.168.100.10 -Version 4.14.7 [-Nombre ws2019] [-Grupo windows] [-Password CLAVE]

  -Version debe ser IGUAL o MENOR que la del manager.
#>
param(
    [Parameter(Mandatory = $true)][string]$Manager,
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Nombre = $env:COMPUTERNAME.ToLower(),
    [string]$Grupo = "windows",
    [string]$Password = ""
)
$ErrorActionPreference = "Stop"
function Ok($m)    { Write-Host "[OK] $m" -ForegroundColor Green }
function Info($m)  { Write-Host "[..] $m" -ForegroundColor Cyan }
function Aviso($m) { Write-Host "[!!] $m" -ForegroundColor Yellow }

# 1. Requisitos ---------------------------------------------------------------
Info "Paso 1/5 · Verificando requisitos"
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw "Ejecuta PowerShell como Administrador." }
$Version = $Version.TrimStart("v")
if ($Version -notmatch '^4\.\d+\.\d+$') { throw "-Version debe tener el formato 4.14.7" }
foreach ($p in 1514, 1515) {
    if (-not (Test-NetConnection $Manager -Port $p -WarningAction SilentlyContinue).TcpTestSucceeded) {
        throw "No hay conexión al puerto $p de $Manager (ver capítulo 1, paso 5)."
    }
}
Ok "Manager $Manager alcanzable en 1514/1515"

# 2. Descarga -----------------------------------------------------------------
Info "Paso 2/5 · Descargando wazuh-agent-$Version-1.msi"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$msi = Join-Path $env:TEMP "wazuh-agent-$Version-1.msi"
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-$Version-1.msi" -OutFile $msi -UseBasicParsing
Ok "Descargado en $msi"

# 3. Instalación --------------------------------------------------------------
Info "Paso 3/5 · Instalando y registrando (nombre: $Nombre, grupo: $Grupo)"
$argumentos = @("/i", "`"$msi`"", "/q", "/l*v", "`"$env:TEMP\wazuh-agent-install.log`"",
                "WAZUH_MANAGER=`"$Manager`"", "WAZUH_AGENT_NAME=`"$Nombre`"", "WAZUH_AGENT_GROUP=`"$Grupo`"")
if ($Password) { $argumentos += "WAZUH_REGISTRATION_PASSWORD=`"$Password`"" }
$proc = Start-Process msiexec.exe -ArgumentList $argumentos -Wait -PassThru
if ($proc.ExitCode -ne 0) { throw "msiexec terminó con código $($proc.ExitCode). Revisa $env:TEMP\wazuh-agent-install.log" }
Ok "Agente instalado"

# 4. Servicio -----------------------------------------------------------------
Info "Paso 4/5 · Iniciando el servicio WazuhSvc"
Start-Service WazuhSvc
Start-Sleep -Seconds 10
Get-Service WazuhSvc | Format-Table Name, Status, StartType -AutoSize

# 5. Verificación -------------------------------------------------------------
Info "Paso 5/5 · Verificando conexión con el manager"
$log = "C:\Program Files (x86)\ossec-agent\ossec.log"
$conectado = Select-String -Path $log -Pattern "Connected to the server" | Select-Object -Last 1
if ($conectado) { Ok $conectado.Line } else { Aviso "Aún no aparece 'Connected to the server'. Revisa: Get-Content '$log' -Tail 30" }
Ok "Listo. En el manager confirma con: sudo /var/ossec/bin/agent_control -l"
