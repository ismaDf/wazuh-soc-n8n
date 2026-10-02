# 0. Arquitectura y laboratorio

## 0.1 Objetivo

Cerrar el ciclo completo de un SOC: **recolectar → detectar → priorizar → notificar → contener → documentar**. Wazuh ya cubre recolección y detección; este proyecto añade:

- Telemetría de endpoint de alta calidad (Sysmon) para actuar como **EDR**.
- **Reglas propias** mapeadas a MITRE ATT&CK.
- **Respuesta activa** nativa (bloqueo, eliminación de amenazas).
- **Orquestación con n8n** (SOAR): triage, enriquecimiento, notificación y contención por API.

## 0.2 Inventario del laboratorio

Edita esta tabla con los valores reales de tus VMs. **En todo el manual se usan estos nombres de variable.**

| Rol | Hostname | SO | IP (variable) | Notas |
|---|---|---|---|---|
| Servidor Wazuh 4.14.x (manager + indexer + dashboard) | `wazuh-srv` | Ubuntu | `WAZUH_IP` (ej. 192.168.100.10) | 4 vCPU, 8 GB RAM mínimo |
| n8n (Docker) | `wazuh-srv` o VM aparte | Ubuntu | `N8N_IP` | 2 vCPU, 2 GB RAM |
| Endpoint Windows Server | `ws2019` | Windows Server 2019 | `WS_IP` (ej. 192.168.100.20) | Sysmon + auditoría avanzada |
| Endpoint Windows heredado | `win7` | Windows 7 SP1 | `W7_IP` (ej. 192.168.100.21) | Sin soporte del fabricante: caso UC-08 |
| Endpoint Linux | `lnx-01` | Linux (Ubuntu/Debian) | `LNX_IP` (ej. 192.168.100.30) | iptables → `firewall-drop` |
| Endpoint Red Hat | `rhel-01` | Red Hat Enterprise Linux | `RHEL_IP` (ej. 192.168.100.31) | firewalld → `firewalld-drop` |
| Origen de pruebas | `kali` | Kali Linux 2026 | `KALI_IP` (ej. 192.168.100.50) | Solo dentro del lab |

> Recomendación: todas las VMs en una red **Host-only** o **NAT dedicada** de VMware. n8n necesita salida a Internet solo si usas Telegram/VirusTotal. El Windows 7 **nunca** debe tener acceso a Internet ni a tu red real.

## 0.3 Puertos que deben estar abiertos

| Origen → Destino | Puerto | Uso |
|---|---|---|
| Agentes → Manager | 1514/TCP | Envío de eventos |
| Agentes → Manager | 1515/TCP | Registro de agentes |
| Analista → Dashboard | 443/TCP | Interfaz web de Wazuh |
| n8n → Manager | 55000/TCP | API de Wazuh (respuesta activa) |
| n8n → Indexer | 9200/TCP | Consultas para reportes |
| Manager → n8n | 5678/TCP | Webhook de alertas |
| Analista → n8n | 5678/TCP | Editor de n8n |

## 0.4 Consideraciones por sistema operativo

| Endpoint | Telemetría | Respuesta activa | Limitaciones |
|---|---|---|---|
| Windows Server 2019 | Security, System, Sysmon, PowerShell/Operational | `netsh` (bloqueo de IP) | Ninguna relevante |
| Windows 7 | Security, System; Sysmon solo si la versión instalada lo soporta | `netsh` | PowerShell 2.0 (sin evento 4104); sin parches; revisa la versión mínima de agente Wazuh y Sysmon compatibles |
| Linux (Ubuntu/Debian) | auth.log, syslog, FIM, auditd opcional | `firewall-drop` (iptables) | — |
| Red Hat | /var/log/secure, FIM, auditd | `firewalld-drop` | SELinux puede bloquear scripts personalizados (ver troubleshooting) |

## 0.5 Modelo de severidad SOC

n8n traduce el nivel de regla de Wazuh (0–15) a una severidad de operación:

| Nivel Wazuh | Severidad SOC | SLA de atención (lab) | Acción automática |
|---|---|---|---|
| 7–9 | Media | 4 h | Notificación |
| 10–11 | Alta | 1 h | Notificación con prioridad |
| 12–15 | Crítica | 15 min | Notificación + contención si hay IP origen fuera del allowlist |

## 0.6 Principios de diseño de la respuesta

1. **Contener solo lo que es reversible**: el bloqueo de IP expira (timeout); nunca se borran cuentas automáticamente.
2. **Allowlist obligatoria**: IPs del servidor, gateway y del analista nunca se bloquean.
3. **Humano en el bucle** para acciones de alto impacto (cuentas, aislamiento total).
4. **Todo queda registrado**: cada acción de n8n incluye el ID de alerta para trazabilidad.
