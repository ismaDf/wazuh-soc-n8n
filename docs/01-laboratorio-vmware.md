# 1. Levantamiento del laboratorio en VMware — Guía paso a paso

Este capítulo deja las máquinas cliente listas para recibir el agente de Wazuh: red aislada, IP fija, nombre de equipo, hora sincronizada y un snapshot limpio. **El servidor Wazuh ya está instalado**, así que aquí solo se prepara su red y se omite su instalación.

## Mapa de la guía

| Paso | Dónde | Qué haces | Punto de control |
|---|---|---|---|
| 1 | VMware (host) | Crear la red virtual del laboratorio | `VMnet2` existe con la subred 192.168.100.0/24 |
| 2 | VMware | Crear o ajustar cada VM | Cada VM usa `VMnet2` |
| 3 | Cada VM | Nombre de equipo e IP estática | `hostname` e IP coinciden con la tabla |
| 4 | Cada VM | Sincronizar la hora | Diferencia < 2 s con `wazuh-srv` |
| 5 | Cada cliente | Probar conectividad con el manager | Puertos 1514 y 1515 abiertos |
| 6 | VMware | Snapshot `base-limpia` | Snapshot visible en cada VM |

## Inventario objetivo

| Hostname | SO | IP | vCPU / RAM / Disco | Agente Wazuh |
|---|---|---|---|---|
| `wazuh-srv` | Ubuntu (ya instalado) | 192.168.100.10 | 4 / 8 GB / 50 GB | Es el manager |
| `ws2019` | Windows Server 2019 | 192.168.100.20 | 2 / 4 GB / 60 GB | Sí |
| `win7` | Windows 7 SP1 x64 | 192.168.100.21 | 2 / 2 GB / 40 GB | Sí |
| `lnx-01` | Ubuntu Server / Debian | 192.168.100.30 | 1 / 2 GB / 20 GB | Sí |
| `rhel-01` | Red Hat Enterprise Linux 8/9 | 192.168.100.31 | 1 / 2 GB / 20 GB | Sí |
| `kali` | Kali Linux 2026 | 192.168.100.50 | 2 / 4 GB / 40 GB | No (es el origen de pruebas) |

Gateway: `192.168.100.2` (NAT de VMware) · DNS: `192.168.100.2`. Si usas otra subred, reemplázala en todos los comandos.

---

## Paso 1 · Crear la red virtual del laboratorio

En el equipo anfitrión: **VMware Workstation → Edit → Virtual Network Editor → Change Settings** (requiere administrador).

1. **Add Network…** → elige `VMnet2`.
2. Selecciona `VMnet2` y configura:
   - Tipo: **NAT** (las VMs salen a Internet para descargar paquetes, pero nada de fuera entra a ellas).
   - *Subnet IP:* `192.168.100.0` · *Subnet mask:* `255.255.255.0`.
   - Desmarca **Use local DHCP service** (usaremos IPs fijas).
3. **NAT Settings…** → confirma que *Gateway IP* sea `192.168.100.2`.
4. **Apply**.

> **¿NAT o Host-only?** NAT es más práctico mientras instalas agentes y Sysmon. Cuando todo esté desplegado puedes pasar `win7` a **Host-only** para aislarlo por completo (ver UC-08).

**Punto de control (Windows host):**

```powershell
ipconfig | Select-String -Context 0,4 "VMnet2"
```

Debe aparecer el adaptador `VMware Network Adapter VMnet2` con una IP `192.168.100.x`.

## Paso 2 · Crear o ajustar cada VM

Para cada VM (nueva o existente): **VM → Settings → Network Adapter → Custom: VMnet2 → OK**.

Recomendaciones por sistema:

| VM | Ajuste recomendado |
|---|---|
| `ws2019` | Instala VMware Tools. En la instalación elige *Desktop Experience* para tener interfaz gráfica |
| `win7` | Usa SP1 x64. **No** lo conectes a tu red real en ningún momento |
| `lnx-01` | Ubuntu Server LTS con OpenSSH Server marcado durante la instalación |
| `rhel-01` | Registra la suscripción gratuita de desarrollador para tener repositorios: `sudo subscription-manager register` |
| `kali` | Imagen oficial para VMware |

## Paso 3 · Nombre de equipo e IP estática

### `lnx-01` (Ubuntu con netplan)

```bash
sudo hostnamectl set-hostname lnx-01
ip -br link                                   # anota el nombre de la interfaz (ej. ens33)

sudo tee /etc/netplan/60-laboratorio.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: false
      addresses: [192.168.100.30/24]
      routes:
        - to: default
          via: 192.168.100.2
      nameservers:
        addresses: [192.168.100.2]
EOF
sudo chmod 600 /etc/netplan/60-laboratorio.yaml
sudo netplan apply
ip -br addr show ens33
```

**Salida esperada:** `ens33  UP  192.168.100.30/24 ...`

> Si tu instalación ya trae un archivo en `/etc/netplan/` con DHCP para esa interfaz, desactívalo (renómbralo a `.bak`) para que no compita con este.

### `rhel-01` (Red Hat con NetworkManager)

```bash
sudo hostnamectl set-hostname rhel-01
nmcli -t -f NAME,DEVICE con show               # anota el nombre de la conexión (ej. ens160)

sudo nmcli con mod ens160 ipv4.method manual \
     ipv4.addresses 192.168.100.31/24 ipv4.gateway 192.168.100.2 ipv4.dns 192.168.100.2
sudo nmcli con up ens160
ip -br addr
```

### `kali`

```bash
sudo hostnamectl set-hostname kali
nmcli -t -f NAME,DEVICE con show
sudo nmcli con mod "Wired connection 1" ipv4.method manual \
     ipv4.addresses 192.168.100.50/24 ipv4.gateway 192.168.100.2 ipv4.dns 192.168.100.2
sudo nmcli con up "Wired connection 1"
```

### `ws2019` (PowerShell como Administrador)

```powershell
Get-NetAdapter                                   # anota el nombre (ej. Ethernet0)
New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress 192.168.100.20 -PrefixLength 24 -DefaultGateway 192.168.100.2
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 192.168.100.2
Rename-Computer -NewName "ws2019" -Restart
```

Tras el reinicio:

```powershell
hostname; Get-NetIPAddress -InterfaceAlias "Ethernet0" -AddressFamily IPv4 | Select IPAddress
```

### `win7` (CMD como Administrador)

Windows 7 trae PowerShell 2.0 sin los cmdlets de red, así que se usa `netsh`:

```bat
netsh interface show interface
netsh interface ipv4 set address name="Conexión de área local" static 192.168.100.21 255.255.255.0 192.168.100.2
netsh interface ipv4 set dnsservers name="Conexión de área local" static 192.168.100.2 primary
wmic computersystem where name="%COMPUTERNAME%" call rename name="win7"
shutdown /r /t 0
```

> Si tu Windows 7 está en inglés, la interfaz se llama `Local Area Connection`.

### Resolución de nombres (opcional, recomendado)

Para usar nombres en lugar de IPs entre las VMs Linux, agrega al final de `/etc/hosts` de `wazuh-srv`, `lnx-01`, `rhel-01` y `kali`:

```bash
sudo tee -a /etc/hosts > /dev/null <<'EOF'
192.168.100.10  wazuh-srv
192.168.100.20  ws2019
192.168.100.21  win7
192.168.100.30  lnx-01
192.168.100.31  rhel-01
192.168.100.50  kali
EOF
```

## Paso 4 · Sincronizar la hora

La correlación de un SIEM depende de la hora: si un equipo está adelantado, sus eventos aparecen fuera de orden y las reglas con `timeframe` no correlacionan. Todos los equipos usan la zona `America/Lima` y `wazuh-srv` como referencia.

**`wazuh-srv` como servidor de hora (chrony):**

```bash
sudo timedatectl set-timezone America/Lima
sudo apt install -y chrony
echo "allow 192.168.100.0/24" | sudo tee -a /etc/chrony/chrony.conf
echo "local stratum 10"       | sudo tee -a /etc/chrony/chrony.conf
sudo systemctl restart chrony
sudo ufw allow from 192.168.100.0/24 to any port 123 proto udp   # si usas ufw
```

**`lnx-01` y `kali`:**

```bash
sudo timedatectl set-timezone America/Lima
sudo apt install -y chrony
echo "server 192.168.100.10 iburst prefer" | sudo tee -a /etc/chrony/chrony.conf
sudo systemctl restart chrony
chronyc sources
```

**`rhel-01`** (chrony ya viene instalado; el archivo está en otra ruta):

```bash
sudo timedatectl set-timezone America/Lima
echo "server 192.168.100.10 iburst prefer" | sudo tee -a /etc/chrony.conf
sudo systemctl restart chronyd
chronyc sources
```

**Salida esperada en Linux:** una línea `^* 192.168.100.10` (el asterisco indica la fuente elegida).

**`ws2019` y `win7`** (consola como Administrador):

```bat
tzutil /s "SA Pacific Standard Time"
w32tm /config /manualpeerlist:"192.168.100.10" /syncfromflags:manual /update
net stop w32time & net start w32time
w32tm /resync
w32tm /stripchart /computer:192.168.100.10 /samples:3 /dataonly
```

**Salida esperada:** desfases (`o:`) menores a ±2 segundos.

## Paso 5 · Probar conectividad con el manager

Los agentes usan **1515/TCP** para registrarse y **1514/TCP** para enviar eventos.

**En `wazuh-srv`, confirma que escucha y que el firewall lo permite:**

```bash
sudo ss -ltnp | grep -E ':1514|:1515|:55000'
sudo ufw status | grep -E '1514|1515' || echo "ufw sin reglas para 1514/1515 (o inactivo)"
```

Si `ufw` está activo y no aparecen:

```bash
sudo ufw allow from 192.168.100.0/24 to any port 1514,1515 proto tcp
```

**Desde `lnx-01`, `rhel-01`:**

```bash
for p in 1514 1515; do timeout 3 bash -c "</dev/tcp/192.168.100.10/$p" && echo "puerto $p ABIERTO" || echo "puerto $p CERRADO"; done
```

**Desde `ws2019`:**

```powershell
1514,1515 | ForEach-Object { Test-NetConnection 192.168.100.10 -Port $_ | Select-Object RemotePort, TcpTestSucceeded }
```

**Desde `win7`** (no tiene `Test-NetConnection`): instala temporalmente el cliente Telnet y prueba.

```bat
dism /online /Enable-Feature /FeatureName:TelnetClient
telnet 192.168.100.10 1515
```

Si la pantalla queda en negro, el puerto está abierto (cierra con `Ctrl+]` y luego `quit`).

## Paso 6 · Snapshot de base limpia

Antes de instalar nada, toma un snapshot en cada cliente: **VM → Snapshot → Take Snapshot** → nombre `base-limpia`. Es tu punto de regreso si una prueba deja el equipo en mal estado.

Después del capítulo 4 (agente + EDR) toma un segundo snapshot, `agente-edr-ok`: desde ahí repetirás las pruebas de los casos de uso tantas veces como necesites.

## Checklist del capítulo

- [ ] `VMnet2` creada (NAT, sin DHCP, 192.168.100.0/24)
- [ ] Las 6 VMs en `VMnet2` con hostname e IP de la tabla
- [ ] Hora sincronizada contra `wazuh-srv` en todos los equipos
- [ ] Puertos 1514 y 1515 accesibles desde los 4 clientes
- [ ] Snapshot `base-limpia` en cada cliente
