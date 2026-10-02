# UC-02 · Fuerza bruta y password spraying en Windows (RDP/SMB)

| Campo | Valor |
|---|---|
| Endpoint(s) | `ws2019` (Windows Server 2019) |
| Táctica / Técnica MITRE | Credential Access · T1110.001 Password Guessing, T1110.003 Password Spraying · T1078 Valid Accounts |
| Fuente de datos | Security: 4625 (fallo), 4624 (éxito) |
| Reglas Wazuh | 60122 (base) · **100110**, **100111**, **100112** (propias) |
| Severidad SOC | Alta (100110) · Crítica (100111, 100112) |
| Respuesta automática | `netsh` bloquea la IP 600 s · n8n bloquea y escala en 100112 |

## Contexto real

RDP expuesto con contraseñas débiles es, según avisos reiterados de agencias como CISA y el FBI, uno de los vectores de acceso inicial más usados por operadores de ransomware. Una variante más sigilosa es el **password spraying**: probar *una* contraseña común (`Verano2026!`, `Empresa123`) contra *muchos* usuarios, para no disparar bloqueos de cuenta por usuario.

## Lógica de detección

```xml
<!-- 6 fallos desde la misma IP en 2 min -->
<rule id="100110" level="10" frequency="6" timeframe="120">
  <if_matched_sid>60122</if_matched_sid>
  <same_field>win.eventdata.ipAddress</same_field>
  ...
</rule>

<!-- 5 fallos desde la misma IP contra usuarios DISTINTOS en 5 min -->
<rule id="100111" level="12" frequency="5" timeframe="300">
  <if_matched_sid>60122</if_matched_sid>
  <same_field>win.eventdata.ipAddress</same_field>
  <different_field>win.eventdata.targetUserName</different_field>
  ...
</rule>

<!-- Login exitoso desde una IP que antes disparó 100110 -->
<!-- Se ancla a 60106 y a sus reglas hijas (92651, 92652, 92657...), porque
     un 4624 remoto suele terminar en ellas y no en 60106 -->
<rule id="100112" level="14" timeframe="600">
  <if_sid>60106,...,92651,92652,92657,...</if_sid>
  <if_matched_sid>100110</if_matched_sid>
  <same_field>win.eventdata.ipAddress</same_field>
  ...
</rule>
```

> El ruleset oficial ya trae la 60204 ("Multiple Windows Logon Failures"), pero no distingue spraying ni correlaciona con el éxito posterior. Por eso se crean las 1001xx.
>
> La regla 40112 de UC-01 no aplica a Windows porque compara `srcip`, y en Windows la IP viene en `win.eventdata.ipAddress`. La 100112 resuelve eso.

## Respuesta

- **Nativa:** 100110 / 100111 → `netsh` crea la regla de firewall *WAZUH ACTIVE RESPONSE BLOCKED IP* por 600 s.
- **n8n:** en 100112 solicita bloqueo vía API y envía alerta 🔴 CRÍTICA con el usuario comprometido. La desactivación de la cuenta queda en manos del analista.

## Prueba controlada (solo laboratorio)

1. En `ws2019` crea una cuenta de prueba: `net user soc.prueba Lab-Prueba-2026! /add`.
2. Desde `kali` ejecuta [`scripts/pruebas/uc02-windows-intentos-fallidos.sh`](../../scripts/pruebas/uc02-windows-intentos-fallidos.sh):

```bash
sudo apt install -y smbclient
# Prueba A: fuerza bruta contra un usuario → 100110
bash scripts/pruebas/uc02-windows-intentos-fallidos.sh 192.168.100.20 fuerza
# Prueba B: spraying contra varios usuarios → 100111
bash scripts/pruebas/uc02-windows-intentos-fallidos.sh 192.168.100.20 spray
```

3. Para **100112**: desactiva temporalmente la respuesta `netsh` (si no, Kali queda bloqueada), repite la prueba A y luego:

```bash
smbclient -L //192.168.100.20 -U 'soc.prueba%Lab-Prueba-2026!'
```

4. Limpieza: `net user soc.prueba /delete` y reactiva la respuesta activa.

## Evidencia esperada

| Dónde | Qué ver |
|---|---|
| Threat Hunting | `rule.id: (100110 or 100111 or 100112)` |
| `ws2019` | `netsh advfirewall firewall show rule name="WAZUH ACTIVE RESPONSE BLOCKED IP"` |
| n8n → Executions | Ejecución con rama **¿Contener?** = true y respuesta del API |
| Telegram | 🔴 alerta + 🛡️ "Contención ejecutada" |

## Playbook del analista

1. **Validar**: tipo de logon (`win.eventdata.logonType`: 10 = RDP, 3 = red/SMB). ¿La IP es un servidor legítimo?
2. **Alcance**: ¿qué cuentas fallaron? ¿alguna tuvo éxito (4624)? ¿esa cuenta inició sesión en otros equipos?
3. **Contener**: deshabilitar la cuenta comprometida (`net user USUARIO /active:no`), forzar cambio de contraseña.
4. **Erradicar**: revisar lo que hizo la sesión: UC-04, UC-05 y UC-06 suelen venir después.
5. **Mejorar**: RDP solo por VPN, NLA activado, política de bloqueo de cuentas, MFA.

## Falsos positivos y ajuste

- Servicios con contraseña vencida reintentando (genera muchos 4625 del mismo usuario y misma IP): identifica por `win.eventdata.processName` y excluye.
- Equipos detrás de NAT comparten IP: en redes reales, ajusta `frequency` hacia arriba.
