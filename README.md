# Synthetic Intelligence App

Take back some sovereignty with just a few commands.

Here is a simple, all-in-one Docker Compose app that provides self hosted AI chat, a chat GUI, SearXNG web search, and a reverse proxy.

SIA uses popular open source tools; it's extensible; and setup and management are greatly simplified by the included command line tool (script).


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
**1. [Install docker](https://docs.docker.com/install/)**

**2. Get SIA**

```shell
cd ~
git clone https://github.com/joshua-hvmn/SIA.git
cd SIA
```
### II. Setup
**3. Run the SIA command line tool** (it's just a simple script): 
```
./sia
```
It will ask how your system is configured. Enter the number corresponding to your choice.

If you accidentally pick the wrong one or you change your system (i.e. *upgrade* from an Nvidia GPU to an AMD GPU), you can run `./sia -s` to change the setup!

*Note: If you receive a permission denied error, you might need to make the sia file executable with* `chmod +x sia`

The SearXNG secret key is stored in the .env if you need it.

**Optional:** 

4. *If applicable, edit the [.env](https://github.com/joshua-hvmn/SIA/blob/main/.env) file to set the hostname and an email (not necessary for local use)*
5. *You can edit [searxng/settings.yml](https://github.com/joshua-hvmn/SIA/blob/main/searxng/settings.yml) according to
   your needs.*

### III. Startup
#### Method 1: With Caddy included (recommended for beginners)

**6. Run SIA** in the background and move to Step 10: 
```
./sia
```

#### Method 2: Bring your own reverse proxy (experienced users)

6. Remove the caddy related parts in `.compose.<architecture of choice>.yaml` such as the caddy service and its volumes.
7. Point your reverse proxy to the port set for the `searxng` service in the compose file (8080 by default).
8. Generate and configure the required TLS certificates with the reverse proxy of your choice.
9. Run SIA in the background: `./sia`

----

**10. Install an Ollama LLM** from [their search directory](https://ollama.com/search).

`./sia -dl [model of choice, i.e llama3.2:3b]`

### IV. Post Install

1. Access Open WebUI at [http://localhost:3000](http://localhost:3000) by default.
2. Create an admin account and bookmark the page.
3. Connect Ollama to Open WebUI if necessary:
   - Click name in corner > Admin Panel > Settings > Connections > Ollama API > Manage Ollama API Connections > Configure (gear icon)
   - Make sure Ollama API is enabled, and the API connection is set to `http://ollama:11434`
4. Connect SearXNG to Open WebUI if necessary:
   - Admin Panel > Settings > Web Search
   - Enable, set to SearXNG
   - Set query URL to `http://searxng:8080/search?q=<query>&format=json`
   - Note that in this version of SIA, web searches done by Open WebUI are unencrypted. If this is problematic, skip this step. The self signed keys aren't trusted.
5. Use SearXNG at [https://localhost:443](https://localhost:443) by default, and accept the security warning for the self signed certificates.
   - In Chromium browsers, set the search bar to `https://localhost/search?q=%s`

### V. Restarting
When you restart your computer, you must restart the containers:

1. Restart:
```shell
./sia
```
2. If it fails to restart, you can use the following command to check what is active on the busy port:
```shell
sudo lsof -i :[port number]
```
- ports used are: 443, 11434, 3000, 8888, and 8080
3. Stop whatever is running
```shell
sudo systemctl stop [container name, i.e. ollama]
```
4. Restart the containers again:
```shell
./sia
```

## Troubleshooting

Run `./sia -h` for help, or `./sia -h <command>` for help with a specific command.

### How to access the logs

To access the the last 100 logs from all the containers use: `./sia -l`

To access the logs of one specific container:

`./sia -l [container name]`

Container Names:
- caddy
- searxng
- redis
- ollama
- open-webui

Or pass any arguments that can be used with `docker compose logs`

### Start & Stop Containers
- Start/Restart: `./sia`
- Stop: `./sia -d` (accepts all docker compose down args)
- Restart Harder:
```shell
docker kill $(docker ps -q)
./sia -d -v
./sia
```
- CAUTION: Delete existing stopped containers: `docker container prune`
   - This will delete all chats

The wiki is in production, it will contain more information.