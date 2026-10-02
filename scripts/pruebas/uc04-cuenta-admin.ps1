# UC-04 · Crea una cuenta de prueba y la agrega al grupo de administradores locales.
# Ejecutar como Administrador en ws2019 o win7 (laboratorio).
#   .\uc04-cuenta-admin.ps1            → crea
#   .\uc04-cuenta-admin.ps1 -Limpiar   → elimina
param([switch]$Limpiar)
$usuario = "soc.persist"

# Nombre del grupo Administradores en el idioma del sistema (SID universal S-1-5-32-544)
$grupo = (New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")).Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]

if ($Limpiar) {
    net user $usuario /delete
    Write-Output "[*] Cuenta $usuario eliminada"
    exit
}
net user $usuario "Lab-Prueba-2026!" /add
Start-Sleep -Seconds 5
net localgroup "$grupo" $usuario /add
Write-Output "[*] Revisa en Wazuh: rule.id:(100120 or 60154 or 100121)"
Write-Output "[*] Limpieza: .\uc04-cuenta-admin.ps1 -Limpiar"
