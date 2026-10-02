# Evidencias del proyecto

Guarda aquí las capturas y resultados de las pruebas. Convención de nombres:

```
UC-01_01_ejecucion-kali.png
UC-01_02_alerta-wazuh.png
UC-01_03_ejecucion-n8n.png
UC-01_04_telegram.png
UC-01_05_bloqueo-iptables.png
ESCENARIO_linea-de-tiempo-ws2019.png
```

> Antes de subir: tapa tokens, contraseñas, `chat_id` e IPs públicas.

## Matriz de resultados

| Caso | Endpoint | ¿Detectó? | Regla(s) | Evento → alerta | Alerta → Telegram | ¿Respondió? | Tiempo de contención | Observaciones |
|---|---|---|---|---|---|---|---|---|
| UC-01 | lnx-01 | | 5712 / 5763 | | | | | |
| UC-01 | rhel-01 | | 5712 / 5763 | | | | | |
| UC-02 | ws2019 | | 100110 / 100111 / 100112 | | | | | |
| UC-03 | lnx-01 | | 87105 | | | | | |
| UC-04 | ws2019 | | 100120 / 100121 | | | — | — | |
| UC-04 | win7 | | 100120 / 60154 | | | — | — | |
| UC-05 | ws2019 | | 100130 / 100131 | | | — | — | |
| UC-06 | ws2019 | | 100140 / 100141 | | | — | — | |
| UC-06 | win7 | | 100140 / 100141 | | | — | — | |
| UC-07 | rhel-01 | | 100150 / 100151 / 100152 | | | — | — | |
| UC-08 | win7 | | Workflow 03 | | | — | — | |

## Conclusiones

<!-- Qué funcionó, qué no, qué aprendiste y qué mejorarías. -->

## Mejoras propuestas

<!-- Ej.: gestión de casos con TheHive, YARA, detección de movimiento lateral, MFA en RDP. -->
