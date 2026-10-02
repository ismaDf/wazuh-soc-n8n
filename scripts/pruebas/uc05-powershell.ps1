# UC-05 · Simulación INOFENSIVA de PowerShell codificado y de un "download cradle".
# Ejecutar en ws2019 (laboratorio). No descarga ni ejecuta nada externo.

# 1) Comando codificado: solo imprime un texto → Sysmon EID 1 → regla 100130
$comando = "Write-Output 'prueba-soc-uc05'"
$b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($comando))
# Se lanza desde cmd.exe para que el proceso padre no sea PowerShell
cmd.exe /c "powershell.exe -NoProfile -EncodedCommand $b64"

# 2) Texto con patrón de download cradle: se IMPRIME, no se ejecuta.
#    PowerShell 5.1 registra el bloque de script (4104) → regla 100131
Write-Output "Simulacion: IEX (New-Object Net.WebClient).DownloadString('http://127.0.0.1/no-existe')"

Write-Output "[*] Revisa en Wazuh: rule.id:(100130 or 100131)"
