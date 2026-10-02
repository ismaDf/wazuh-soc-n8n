# UC-04 · Cuenta local creada y agregada a Administradores

| Campo | Valor |
|---|---|
| Endpoint(s) | `ws2019`, `win7` |
| Táctica / Técnica MITRE | Persistence · T1136.001 Create Local Account · Privilege Escalation · T1098 Account Manipulation |
| Fuente de datos | Security: 4720 (cuenta creada), 4732 (miembro añadido a grupo local) |
| Reglas Wazuh | 60109 → **100120** (nivel 10) · 60154 (grupo Administradores, nivel 12) · **100121** (correlación, nivel 14) |
| Severidad SOC | Alta / Crítica |
| Respuesta automática | Solo aviso (requiere validación humana) |

## Contexto real

Tras obtener acceso, los atacantes crean cuentas propias con nombres que parecen legítimos (`support`, `admin1`, `svc_backup`) y las meten en Administradores para no depender de la credencial robada. Es una técnica recurrente en intrusiones de ransomware y en ataques a servidores RDP expuestos. Un servidor rara vez gana administradores nuevos: cuando pasa, alguien debe saber por qué.

## Lógica de detección

```xml
<rule id="100120" level="10">
  <if_sid>60109</if_sid>
  <field name="win.system.eventID">^4720$</field>
  ...
</rule>

<!-- Creación + elevación en el mismo equipo en menos de 10 min -->
<rule id="100121" level="14" timeframe="600">
  <if_sid>60154</if_sid>
  <if_matched_sid>100120</if_matched_sid>
  <same_location />
  ...
</rule>
```

La regla oficial 60154 (nivel 12) detecta cualquier cambio del grupo Administradores identificándolo por su SID universal `S-1-5-32-544`, así que funciona aunque Windows esté en español ("Administradores").

## Respuesta

No se automatiza la eliminación: borrar una cuenta legítima del equipo de TI causa una interrupción. n8n envía aviso 🔴 con quién creó la cuenta (`subjectUserName`) para validación inmediata.

## Prueba controlada (solo laboratorio)

En `ws2019` o `win7` (consola como Administrador): [`scripts/pruebas/uc04-cuenta-admin.ps1`](../../scripts/pruebas/uc04-cuenta-admin.ps1) — o manualmente:

```bat
net user soc.persist Lab-Prueba-2026! /add
net localgroup Administradores soc.persist /add
:: (si Windows está en inglés: Administrators)
```

Limpieza:

```bat
net user soc.persist /delete
```

## Evidencia esperada

| Dónde | Qué ver |
|---|---|
| Threat Hunting | `rule.id: (100120 or 60154 or 100121)` |
| Telegram | 🟠 cuenta creada · 🔴 correlación 100121 |
| Línea de tiempo | 4720 → 4722 (habilitada) → 4732 (añadida a grupo) |

## Playbook del analista

1. **Validar**: ¿existe un ticket de TI? ¿quién la creó (`win.eventdata.subjectUserName`)? ¿desde qué sesión?
2. **Alcance**: ¿la cuenta creadora tuvo fallos de login antes (UC-02)? ¿se crearon cuentas en otros equipos?
3. **Contener**: `net user soc.persist /active:no` y quitarla del grupo.
4. **Erradicar**: revisar inicios de sesión de la cuenta nueva (4624 con `targetUserName`).
5. **Mejorar**: LAPS, tiering de cuentas administrativas, alertas de grupos privilegiados de dominio.

## Falsos positivos y ajuste

- Altas de personal legítimas: documenta las cuentas de servicio de TI que crean usuarios y baja el nivel con una regla hija por `subjectUserName`.
