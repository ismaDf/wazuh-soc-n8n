# 9. Publicar el proyecto en GitHub

## 9.1 Antes de publicar: revisión de seguridad

Un repositorio de portafolio **nunca** debe contener secretos. Revisa:

```bash
cd wazuh-soc-n8n
# Busca tokens, contraseñas o claves que hayas pegado por error
grep -rniE "token|password|passwd|api_key|secret|-100[0-9]{6,}" --exclude-dir=.git . | grep -v -iE "TOKEN_COMPARTIDO|TU_API_KEY|PASSWORD'|cambia_esto|XXXXXXXX"
```

- `n8n/.env` está en `.gitignore`: verifica con `git status` que no aparezca.
- Al exportar workflows desde n8n, las credenciales **no** se incluyen, pero sí el `chat_id` de Telegram si lo escribiste en el nodo: reemplázalo por `-100XXXXXXXXXX` antes de subir.
- En las capturas de `evidencias/`, tapa tokens, contraseñas y cualquier IP pública.

## 9.2 Opción A — Línea de comandos (git)

1. En GitHub, crea un repositorio nuevo **vacío** (sin README ni licencia), por ejemplo `wazuh-soc-n8n`.
2. En tu equipo, dentro de la carpeta del proyecto (ya viene inicializado con un commit):

```bash
git config user.name "Tu Nombre"
git config user.email "tu-correo@ejemplo.com"

# Si quieres que los commits queden a tu nombre, rehace el commit inicial:
git commit --amend --reset-author --no-edit

git branch -M main
git remote add origin https://github.com/TU_USUARIO/wazuh-soc-n8n.git
git push -u origin main
```

Cuando pida contraseña, usa un **Personal Access Token** (GitHub → Settings → Developer settings → Personal access tokens), no tu contraseña de la cuenta.

## 9.3 Opción B — GitHub Desktop (sin comandos)

1. Instala GitHub Desktop e inicia sesión.
2. **File → Add local repository** → elige la carpeta `wazuh-soc-n8n`.
3. **Publish repository** → marca o desmarca *Keep this code private* → **Publish**.

## 9.4 Opción C — Subir desde la web

En el repositorio vacío: **uploading an existing file** → arrastra el contenido de la carpeta (no la carpeta `.git`). GitHub mantiene la estructura de subcarpetas.

## 9.5 Pulir la presentación del repositorio

- **About** (engranaje a la derecha): descripción corta y *topics*: `wazuh`, `siem`, `edr`, `soar`, `n8n`, `mitre-attack`, `blue-team`, `soc`, `cybersecurity`.
- Sube tus capturas a `evidencias/` y enlaza la mejor (la línea de tiempo del escenario encadenado) al inicio del README.
- Fija el repositorio en tu perfil (**Customize your pins**).
- Los diagramas `mermaid` del README y de los capítulos se renderizan automáticamente en GitHub.

## 9.6 Mantener el proyecto vivo

Cada mejora, un commit con mensaje claro:

```bash
git add .
git commit -m "UC-09: detección de Mimikatz con Sysmon EID 10"
git push
```

Ideas para siguientes versiones: integración con TheHive para gestión de casos, YARA en los agentes Linux, detección de movimiento lateral (PsExec, WMI), dashboard personalizado en Wazuh.
