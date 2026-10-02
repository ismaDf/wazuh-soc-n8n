# 5. Instalación de n8n con Docker

n8n será el **SOAR** del laboratorio. Se instala en contenedor para aislarlo y poder recrearlo fácilmente. Puede ir en `wazuh-srv` o en una VM aparte; si va en `wazuh-srv`, asegúrate de que tenga al menos 10 GB de RAM en total.

## 5.1 Instalar Docker (Ubuntu)

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER   # cierra sesión y vuelve a entrar
```

## 5.2 Levantar n8n

Copia la carpeta [`n8n/`](../n8n/) de este repositorio al servidor:

```bash
cd ~/wazuh-soc-n8n/n8n
cp .env.example .env
sed -i "s/^N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)/" .env
nano .env        # ajusta N8N_HOST con la IP de la VM
docker compose up -d
docker compose logs -f n8n   # espera "Editor is now accessible via"
```

Abre `http://N8N_IP:5678` y crea la cuenta de propietario.

> **Guarda el `N8N_ENCRYPTION_KEY`**: con él se cifran las credenciales. Si lo pierdes, tendrás que volver a crearlas.

## 5.3 Firewall del servidor

Si usas `ufw`:

```bash
sudo ufw allow from 192.168.100.0/24 to any port 5678 proto tcp
```

Ajusta la subred a la de tu laboratorio. **No expongas 5678 a Internet.**

## 5.4 Crear las credenciales en n8n

En n8n → **Credentials → Add credential**:

| Nombre (exacto) | Tipo | Valores |
|---|---|---|
| `Wazuh Webhook Token` | Header Auth | Name: `X-Wazuh-Token` · Value: un token largo (`openssl rand -hex 24`) |
| `Wazuh API` | Basic Auth | Usuario `n8n-soar` y su contraseña (capítulo 2.5) |
| `Wazuh Indexer` | Basic Auth | Usuario `admin` del indexer (o uno de solo lectura) |
| `Telegram SOC Bot` | Telegram API | Token del bot (ver 3.5) |

## 5.5 Crear el bot de Telegram (canal de notificación)

1. En Telegram, habla con **@BotFather** → `/newbot` → guarda el token.
2. Crea un grupo "SOC Lab", agrega el bot y escribe cualquier mensaje.
3. Obtén el `chat_id` abriendo en el navegador:
   `https://api.telegram.org/bot<TOKEN>/getUpdates`
   y busca `"chat":{"id":-100...}`. Los grupos tienen ID negativo.

> ¿Prefieres correo? Reemplaza el nodo Telegram por un nodo **Send Email** (SMTP) en los workflows; el resto no cambia.

## 5.6 Checklist

- [ ] `docker ps` muestra el contenedor `n8n` en estado `Up`
- [ ] El editor abre en `http://N8N_IP:5678`
- [ ] Las 4 credenciales creadas con los nombres exactos
- [ ] El bot de Telegram responde en el grupo
