# Synthetic Intelligence App

Take back some sovereignty with just a few commands.

Here is a simple, all-in-one Docker Compose app that provides self hosted AI chat, a chat GUI, SearXNG web search, and a reverse proxy.

SIA uses popular open source tools, and it's extensible.


## What is included?

| Name                                          | Description                                                    | Docker image                                                                 | Dockerfile                                                                                                                                                                                    |
|-----------------------------------------------|----------------------------------------------------------------|------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [Caddy](https://github.com/caddyserver/caddy) | Reverse proxy (create a LetsEncrypt certificate automatically) | [docker.io/library/caddy:2-alpine](https://hub.docker.com/_/caddy)           | [Dockerfile](https://github.com/caddyserver/caddy-docker/blob/master/Dockerfile.tmpl)                                                                                                         |
| [SearXNG](https://github.com/searxng/searxng) | SearXNG by itself                                              | [docker.io/searxng/searxng:latest](https://hub.docker.com/r/searxng/searxng) | [builder.dockerfile](https://github.com/searxng/searxng/blob/master/container/builder.dockerfile) [dist.dockerfile](https://github.com/searxng/searxng/blob/master/container/dist.dockerfile) |
| [Valkey](https://github.com/valkey-io/valkey) | In-memory database                                             | [docker.io/valkey/valkey:8-alpine](https://hub.docker.com/r/valkey/valkey)   | [Dockerfile](https://github.com/valkey-io/valkey-container/blob/mainline/Dockerfile.template)                                                                                                 |
| [Ollama](https://github.com/ollama/ollama) | LLM runner                                             | [docker.io/ollama/ollama](https://hub.docker.com/r/ollama/ollama)   |                                                                                                  |
| [Open WebUI](https://github.com/open-webui/open-webui) | AI chat GUI                                             | ghcr.io/open-webui/open-webui   |                                                                                                  |

## Usage


### I. Install
1. [Install docker](https://docs.docker.com/install/)
2. Get SIA

```shell
cd ~
git clone https://github.com/joshua-hvmn/SIA.git
cd SIA
```
### II. Setup
3. If applicable, edit the [.env](https://github.com/joshua-hvmn/SIA/blob/main/.env) file to set the hostname and an email (not necessary for local use)
4. Generate the secret key

   Linux: `sed -i "s|ultrasecretkey|$(openssl rand -hex 32)|g" searxng/settings.yml`  
   Mac: `sed -i '' "s|ultrasecretkey|$(openssl rand -hex 32)|g" searxng/settings.yml`  
   Windows Powershell Script:
 ```powershell
 $randomBytes = New-Object byte[] 32
 (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($randomBytes)
 $secretKey = -join ($randomBytes | ForEach-Object { "{0:x2}" -f $_ })
 (Get-Content searxng/settings.yml) -replace 'ultrasecretkey', $secretKey | Set-Content searxng/settings.yml
 ``` 
5. You may edit [searxng/settings.yml](https://github.com/joshua-hvmn/SIA/blob/main/searxng/settings.yml) according to
   your needs.
6. Select the appropriate compose file based on your GPU (or lack thereof), rename it to `compose.yaml`
7. Delete or move the other two compose files.

### III. Startup
#### Method 1: With Caddy included (recommended for beginners)

8. Run SIA in the background: `docker compose up -d`

- Move to Step 12.

#### Method 2: Bring your own reverse proxy (experienced users)

8. Remove the caddy related parts in `compose.yaml` such as the caddy service and its volumes.
9. Point your reverse proxy to the port set for the `searxng` service in `compose.yaml` (8080 by default).
10. Generate and configure the required TLS certificates with the reverse proxy of your choice.
11. Run SIA in the background: `docker compose up -d`

> [!NOTE]
> You can change the port `searxng` listens on inside the docker container (e.g. if you want to operate in `host`
> network mode) with the `BIND_ADDRESS` environment variable (defaults to `[::]:8080`). The environment variable can be
> set directly inside `compose.yaml`.

12. Install an Ollama LLM from [their search directory](https://ollama.com/search).

`docker exec ollama ollama run [Model ID, i.e. llama3.1:8b]`

### IV. Post Install

1. Access Open WebUI at [http://localhost:3000](http://localhost:3000) by default.
2. Create an admin account and bookmark the page.
3. Connect Ollama to Open WebUI:
   - Click name in corner > Admin Panel > Settings > Connections > Ollama API > Manage Ollama API Connections > Configure (gear icon)
   - Make sure Ollama API is enabled, and the API connection is set to `http://ollama:11434`
4. Connect SearXNG to Open WebUI:
   - Admin Panel > Settings > Web Search
   - Enable, set to SearXNG
   - Set query URL to `http://searxng:8080/search?q=<query>&format=json`
   - Note that in this version of SIA, web searches done by Open WebUI are unencrypted. If this is problematic, skip this step. The self signed keys aren't trusted.
5. Use SearXNG at [https://localhost:443](https://localhost:443) by default, and accept the security warning for the self signed certificates.
   - In Chromium browsers, set the search bar to `https://localhost/search?q=%s`

### V. Restarting
When you restart your computer, you must restart the containers, you may have errors.

1. Try to restart:
```shell
docker compose up -d --force-recreate
```
2. It may fail to start all containers. You can use the following command to check what is active on a given port:
```shell
sudo lsof -i :[port number]
```
- ports used are: 80, 443, 11434, 3000, and 8080
3. Stop whatever is running
```shell
sudo systemctl stop [container name, i.e. apache2]
```
- I only need to stop apache2
4. Restart the containers again:
```shell
docker compose up -d --force-recreate
```

## Troubleshooting

### How to access the logs

To access the logs from all the containers use: `docker compose logs -f`.

To access the logs of one specific container:

`docker compose logs -f [container name]`

Container Names:
- caddy
- searxng
- redis
- ollama
- open-webui

### Start & Stop Containers
- Start: `docker compose up -d`
- Stop: `docker compose down`
- Restart: `docker compose up -d --force-recreate`
- Restart Harder:
```shell
docker kill $(docker ps -q)
docker compose down -v
docker compose up -d
```
- CAUTION: Delete existing stopped containers: `docker container prune`
   - This will delete all chats

## How to update


WORK IN PROGRESS