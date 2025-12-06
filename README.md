# Synthetic Intelligence App

Create a locally hosted AI chat app with search capabilities via a local SearXNG instance included in the Compose file. Comes bundled with Caddy.

## What is included?

| Name                                          | Description                                                    | Docker image                                                                 | Dockerfile                                                                                                                                                                                    |
|-----------------------------------------------|----------------------------------------------------------------|------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [Caddy](https://github.com/caddyserver/caddy) | Reverse proxy (create a LetsEncrypt certificate automatically) | [docker.io/library/caddy:2-alpine](https://hub.docker.com/_/caddy)           | [Dockerfile](https://github.com/caddyserver/caddy-docker/blob/master/Dockerfile.tmpl)                                                                                                         |
| [SearXNG](https://github.com/searxng/searxng) | SearXNG by itself                                              | [docker.io/searxng/searxng:latest](https://hub.docker.com/r/searxng/searxng) | [builder.dockerfile](https://github.com/searxng/searxng/blob/master/container/builder.dockerfile) [dist.dockerfile](https://github.com/searxng/searxng/blob/master/container/dist.dockerfile) |
| [Valkey](https://github.com/valkey-io/valkey) | In-memory database                                             | [docker.io/valkey/valkey:8-alpine](https://hub.docker.com/r/valkey/valkey)   | [Dockerfile](https://github.com/valkey-io/valkey-container/blob/mainline/Dockerfile.template)                                                                                                 |
| [Ollama](https://github.com/ollama/ollama) | LLM runner                                             | [docker.io/ollama/ollama](https://hub.docker.com/r/ollama/ollama)   |                                                                                                  |
| [Open WebUI](https://github.com/open-webui/open-webui) | AI Chat front end                                             | ghcr.io/open-webui/open-webui   |                                                                                                  |

## How to use it

Firstly, the Caddy proxy is mostly for SearXNG. You can use your own proxy by removing it from the compose file and deleting the caddyfile. 
Currently, any searches done by Open WebUI have to use http.


1. [Install docker](https://docs.docker.com/install/)
2. Get SIA

```shell
cd ~
git clone https://github.com/joshua-hvmn/SIA.git
cd SIA
```

3. Edit the [.env](https://github.com/joshua-hvmn/SIA/blob/main/.env) file to set the hostname and an email
4. Generate the secret key `sed -i "s|ultrasecretkey|$(openssl rand -hex 32)|g" searxng/settings.yml`  
   On a Mac: `sed -i '' "s|ultrasecretkey|$(openssl rand -hex 32)|g" searxng/settings.yml`
5. Edit [searxng/settings.yml](https://github.com/joshua-hvmn/SIA/blob/main/searxng/settings.yml) according to
   your needs

> [!NOTE]
> Windows users can use the following powershell script to generate the secret key:
> ```powershell
> $randomBytes = New-Object byte[] 32
> (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($randomBytes)
> $secretKey = -join ($randomBytes | ForEach-Object { "{0:x2}" -f $_ })
> (Get-Content searxng/settings.yml) -replace 'ultrasecretkey', $secretKey | Set-Content searxng/settings.yml
> ```

### Method 1: With Caddy included (recommended for beginners)

6. Run SearXNG in the background: `docker compose up -d`

### Method 2: Bring your own reverse proxy (experienced users)

6. Remove the caddy related parts in `compose.yaml` such as the caddy service and its volumes.
7. Point your reverse proxy to the port set for the `searxng` service in `compose.yaml` (8080 by default).
8. Generate and configure the required TLS certificates with the reverse proxy of your choice.
9. Run SearXNG in the background: `docker compose up -d`

> [!NOTE]
> You can change the port `searxng` listens on inside the docker container (e.g. if you want to operate in `host`
> network mode) with the `BIND_ADDRESS` environment variable (defaults to `[::]:8080`). The environment variable can be
> set directly inside `compose.yaml`.

10. Install an Ollama LLM from [their search directory](https://ollama.com/search).

`docker exec ollama ollama run [Model ID, i.e. llama3.1:8b]`

## Post Install

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
## Multi Architecture Docker images

Supported architecture:

- amd64
- arm64
- arm/v7

## How to update ?

To update the SearXNG stack:

```sh
git pull
docker compose pull
docker compose up -d
```

Or the old way (with the old docker-compose version):

```sh
git pull
docker-compose pull
docker-compose up -d
``` 
WORK IN PROGRESS