# UC-06 · Borrado de registros de eventos

| Campo | Valor |
|---|---|
| Endpoint(s) | `ws2019`, `win7` |
| Táctica / Técnica MITRE | Defense Evasion · T1070.001 Indicator Removal: Clear Windows Event Logs |
| Fuente de datos | Security 1102 (registro de seguridad borrado) · System 104 (otro registro borrado) |
| Reglas Wazuh | 60117 / 63103 → **100140** (nivel 14) · 63104 → **100141** (nivel 12) |
| Severidad SOC | Crítica |
| Respuesta automática | Aviso crítico |

## Contexto real

Borrar los registros es un paso anti-forense típico al final de una intrusión. El ataque NotPetya (2017) usaba `wevtutil` para limpiar los registros del equipo, y la misma técnica aparece en manuales de operadores de ransomware. En operación normal **casi nunca** hay motivo legítimo para vaciar el registro de Seguridad de un servidor.

## Por qué Wazuh es clave aquí

Windows escribe el evento 1102 **justo después** de vaciar el registro. El agente de Wazuh lo envía al manager en segundos, y todos los eventos anteriores ya están guardados fuera del equipo. El atacante borra la copia local, pero **la evidencia sobrevive en el SIEM**. Este es uno de los argumentos más fuertes para centralizar logs.

## Lógica de detección

```xml
<rule id="100140" level="14">
  <if_sid>60117,63103</if_sid>   <!-- 1102 -->
  ...
</rule>

<rule id="100141" level="12">
  <if_sid>63104</if_sid>   <!-- 104 -->
  ...
</rule>
```

Solo elevan el nivel de reglas oficiales y añaden el mapeo MITRE para que n8n las trate como críticas.

## Prueba controlada (solo laboratorio)

En `ws2019` o `win7`, consola como Administrador ([`scripts/pruebas/uc06-borrado-logs.bat`](../../scripts/pruebas/uc06-borrado-logs.bat)):

```bat
:: 1. Respaldar primero (buena práctica incluso en lab)
wevtutil epl Security C:\soc-respaldo-security.evtx
wevtutil epl Application C:\soc-respaldo-application.evtx

:: 2. Borrar
wevtutil cl Application
wevtutil cl Security
```

## Evidencia esperada

| Dónde | Qué ver |
|---|---|
| Threat Hunting | `rule.id: (100140 or 100141)` |
| Visor de eventos local | Security solo tiene el evento 1102 |
| Wazuh | Los eventos **anteriores** al borrado siguen visibles: demuéstralo con una captura comparando ambas vistas |

## Playbook del analista

1. **Validar**: ¿quién lo hizo (`win.logFileCleared.subjectUserName`)? ¿hay ventana de mantenimiento?
2. **Reconstruir**: en Wazuh, revisar todo lo que hizo esa cuenta y ese equipo en las horas previas al 1102.
3. **Contener**: tratar el equipo como comprometido: aislar y preservar evidencia.
4. **Mejorar**: restringir el privilegio de gestión de logs, reenviar eventos en tiempo real (ya cubierto por Wazuh).

## Falsos positivos y ajuste

- Scripts de mantenimiento que vacían registros llenos: identifícalos y prográmalos en una ventana documentada; mejor aún, aumenta el tamaño máximo del registro en lugar de vaciarlo.
