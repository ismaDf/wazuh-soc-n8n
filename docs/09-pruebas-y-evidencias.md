# 9. Pruebas, evidencias y métricas

Un proyecto de SOC se evalúa por su **evidencia**: no basta con decir que funciona, hay que mostrarlo. Este capítulo convierte tus pruebas en un informe defendible.

## 9.1 Orden recomendado de pruebas

Ejecútalas en este orden: las primeras validan la plataforma y las últimas construyen un incidente completo.

| Paso | Prueba | Valida |
|---|---|---|
| 1 | `curl` con [`alerta-ejemplo.json`](../scripts/pruebas/alerta-ejemplo.json) | Webhook, token y Telegram |
| 2 | UC-01 contra `lnx-01` y luego `rhel-01` | Active Response en ambas distros |
| 3 | UC-03 en `lnx-01` | FIM + VirusTotal + eliminación |
| 4 | UC-07 en `rhel-01` | FIM con diff |
| 5 | UC-08 (ejecutar workflow 03) | API + inventario |
| 6 | **Escenario encadenado** en `ws2019` (7.2) | Correlación y línea de tiempo |

> Entre pruebas espera ~5 minutos o cambia de equipo: n8n suprime avisos repetidos (misma regla + agente + IP) durante la ventana anti-spam.

## 9.2 Escenario encadenado: "intrusión por RDP" (ws2019)

Reproduce la secuencia típica de una intrusión real, paso a paso:

| Hora | Acción (lab) | Táctica | Detección esperada |
|---|---|---|---|
| T+0 | `uc02 ... fuerza` desde Kali (con `netsh` desactivado) | Credential Access | 100110 |
| T+2 | Login correcto con `soc.prueba` desde Kali | Initial Access | **100112** → n8n contiene |
| T+4 | `uc04-cuenta-admin.ps1` en ws2019 | Persistence / Priv. Esc. | 100120, 60154, **100121** |
| T+6 | `uc05-powershell.ps1` en ws2019 | Execution / Defense Evasion | 100130, 100131 |
| T+8 | `uc06-borrado-logs.bat` en ws2019 | Defense Evasion | **100140** |

Al terminar, en Threat Hunting filtra `agent.name: ws2019 and rule.groups: soc_lab` y ordena por fecha: verás la **historia completa del ataque** aunque el registro local se haya borrado. Esa captura es la pieza central del portafolio.

Limpieza: `uc04-cuenta-admin.ps1 -Limpiar`, `net user soc.prueba /delete`, reactiva `netsh` y revierte bloqueos (capítulo 7.5).

## 9.3 Qué capturar en cada caso (carpeta `evidencias/`)

Nombra los archivos `UC-XX_NN_descripcion.png`:

1. **Ejecución de la prueba** (terminal de Kali o del endpoint).
2. **Alerta en Wazuh** (Threat Hunting con el detalle: `rule.id`, `rule.mitre`, campos clave).
3. **Ejecución en n8n** (vista de Executions con el recorrido de nodos en verde).
4. **Mensaje en Telegram**.
5. **Efecto de la respuesta** (regla de firewall, archivo eliminado, `active-responses.log`).

## 9.4 Matriz de resultados

Completa esta tabla en [`evidencias/README.md`](../evidencias/README.md):

| Caso | ¿Detectó? | Regla | Tiempo evento → alerta Telegram | ¿Respondió? | Tiempo de contención | Observaciones |
|---|---|---|---|---|---|---|
| UC-01 | | | | | | |
| … | | | | | | |

### Cómo medir los tiempos

- **MTTD (detección):** `timestamp` de la alerta en Wazuh − hora de la acción de prueba.
- **Tiempo a notificación:** hora del mensaje de Telegram − `timestamp` de la alerta.
- **MTTR (contención):** hora en `active-responses.log` − hora de la acción de prueba.

Valores de referencia razonables en un lab: detección < 10 s, notificación < 5 s, contención < 15 s.

## 9.5 Lista de verificación final del proyecto

- [ ] 8 casos de uso probados con evidencia
- [ ] Escenario encadenado documentado con línea de tiempo
- [ ] Matriz de resultados completa con tiempos
- [ ] Workflows exportados **sin credenciales** (n8n no las incluye al exportar)
- [ ] Ningún token, contraseña o IP pública en el repositorio
- [ ] Conclusiones y mejoras propuestas en `evidencias/README.md`
