@echo off
REM UC-06 · Respalda y borra registros de eventos. SOLO en VMs de laboratorio.
REM Ejecutar como Administrador en ws2019 o win7.
echo [*] Respaldando registros en C:\
wevtutil epl Security C:\soc-respaldo-security.evtx
wevtutil epl Application C:\soc-respaldo-application.evtx
echo [*] Borrando Application (evento 104) y Security (evento 1102)
wevtutil cl Application
wevtutil cl Security
echo [*] Revisa en Wazuh: rule.id:(100140 or 100141)
echo [*] Los eventos anteriores siguen en el SIEM aunque ya no esten en este equipo.
