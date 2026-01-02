# Synthetic Intelligence App

Take back some sovereignty in just *ten* simple steps. (If that!)

Here is a simple, all-in-one Docker Compose app that provides *simple, secure, self-hosted* alternatives to ChatGPT and Google, with a foolproof setup process on Linux and Mac. SIA is also compatible with Windows via Docker Desktop and WSL.

SIA uses popular open-source tools; it's extensible; and setup and management are greatly simplified by the included *novel* command line tool (highly portable, permissive license).

Enjoy!


## What is included?

| Name                                          | Description                                                    | Docker image                                                                 | Dockerfile                                                                                                                                                                                    |
|-----------------------------------------------|----------------------------------------------------------------|------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [Caddy](https://github.com/caddyserver/caddy) | Reverse proxy (create a Let's Encrypt certificate automatically) | [docker.io/library/caddy:2-alpine](https://hub.docker.com/_/caddy)           | [Dockerfile](https://github.com/caddyserver/caddy-docker/blob/master/Dockerfile.tmpl)                                                                                                         |
| [SearXNG](https://github.com/searxng/searxng) | SearXNG by itself                                              | [docker.io/searxng/searxng:latest](https://hub.docker.com/r/searxng/searxng) | [builder.dockerfile](https://github.com/searxng/searxng/blob/master/container/builder.dockerfile) [dist.dockerfile](https://github.com/searxng/searxng/blob/master/container/dist.dockerfile) |
| [Valkey](https://github.com/valkey-io/valkey) | In-memory database                                             | [docker.io/valkey/valkey:8-alpine](https://hub.docker.com/r/valkey/valkey)   | [Dockerfile](https://github.com/valkey-io/valkey-container/blob/mainline/Dockerfile.template)                                                                                                 |
| [Ollama](https://github.com/ollama/ollama) | LLM runner                                             | [docker.io/ollama/ollama](https://hub.docker.com/r/ollama/ollama)   |                                                                                                  |
| [Open WebUI](https://github.com/open-webui/open-webui) | AI chat GUI                                             | ghcr.io/open-webui/open-webui   |                                                                                                  |

## Usage


### I. Install
**1. [Install docker](https://docs.docker.com/install/)**

**2. <u>Get SIA</u>**

```shell
cd ~
git clone https://github.com/joshua-hvmn/SIA.git
cd SIA
```
---------
### II. Quick Start
**3. <u>Run the SIA command line tool</u>** (script): 
```
./sia
```

*Note: If you receive a 'permission denied' error, you might need to make the sia file executable with* `chmod +x sia`, or the appropriate command for your system.

**4. <u>Select a system architecture</u>**:  The tool will ask how your system is configured. Enter the corresponding number of your choice.

If you accidentally pick the wrong one or you modify your system (i.e., *upgrade* from an NVIDIA GPU to an AMD GPU), you can run `./sia -s` to change the setup!

The SearXNG secret key will be randomly generated upon first setup, and stored in the .env file if you need it, or want to change it. (Show hidden files in your file explorer to see it, and the YAML files!)

If you want to use your own proxy rather than Caddy, Complete [Using Another Proxy](#using-another-proxy-advanced-users) below **before** running the script.

**5. <u>Install an Ollama LLM</u>** from [their search directory](https://ollama.com/search).

```
./sia -dl [model of choice, i.e., llama3.2:3b]
```


---------

<u>**[Important!]**</u> *Optional / Advanced Usage:*

- *For public usage, follow the instructions provided at start (not necessary for local use).* 
- NOTES FOR CHANGING ENVIRONMENT VARIABLES: 
   - SIA is unique: you must change the environment variables using the `sia` tool.
   - The tool will overwrite any changes you make to the .env file (except the SearXNG secret key and COMPOSE_FILE variables, they can be modified manually by default).
   - You can manage the environment variables easily with the built in `./sia env` command.
   - Remember that the .env file is hidden by default.
- *You can manually edit [searxng/settings.yml](https://github.com/joshua-hvmn/SIA/blob/main/searxng/settings.yml) according to
   your needs.*

---------

### III. Post Install

6. Access Open WebUI at [http://localhost:3000](http://localhost:3000) by default.
7. Create an "admin account" and bookmark the page.
8. Connect Ollama to Open WebUI if necessary:
   - Click name in corner > Admin Panel > Settings > Connections > Ollama API > Manage Ollama API Connections > Configure (gear icon)
   - Make sure Ollama API is enabled, and the API connection is set to `http://ollama:11434`
9. Connect SearXNG to Open WebUI if necessary:
   - Admin Panel > Settings > Web Search
   - Enable, set to SearXNG
   - Set query URL to `http://searxng:8080/search?q=<query>&format=json`
   - Note: In this version of SIA, web searches are sent over HTTP (unencrypted) between containers to avoid certificate trust issues.
10. Use SearXNG at [https://localhost:443](https://localhost:443) by default. You will need to accept the security warning for the self-signed certificates.
   - In Chromium browsers, set the search bar to `https://localhost/search?q=%s`

11. That's pretty much everything, enjoy!

---------

### IV. Restarting
When you restart your computer, you have to restart the containers:

<u>Restart:</u>
```shell
./sia
```
If it fails to restart, you can use the following command to check what is active on the busy port:

`sudo lsof -i :[port number]`

- ports used are: 443, 11434, 3000, 8888, and 8080

Stop whatever is running: `sudo systemctl stop [container name, i.e., ollama]`

Restart the containers again: `./sia`

------------

### <u>Using Another Proxy</u> (advanced users)

Bring your own reverse proxy

1. Remove the caddy related parts in `.compose.<architecture of choice>.yaml` such as the caddy service and its volumes. (Hidden files!)
2. Point your reverse proxy to the port set for the `searxng` service in the compose file (8080 by default).
3. Generate and configure the required TLS certificates with the reverse proxy of your choice.
4. Run SIA: `./sia`

------------

## Commands

The `./sia` command line tool comes equipped with several subcommands and an ability to pass arguments to the underlying Docker Compose commands. This feature set may well be extended in the future.

| Command       | Other Names                | Description |
| ----------    | -------------------------- | ----------- |
| (no command)  | n/a                        | Runs start/restart subcommand. Automatically runs setup on first start. |
| setup         | -s, --setup                | Runs the setup wizard. Run if you change between CPU/Nvidia/AMD. |
| down          | -d, --down                 | Stop the SIA stack. Accepts additional arguments. (Docker Compose command) |
| logs          | -l, --logs                 | View relevant logs Accepts additional arguments. (Docker Compose command) |
| download      | -dl, --download            | Download an Ollama model. Requires an additional argument. (Ollama command) |
| help          | -h, --help                 | Show a useful help message. Can pass "down" or "logs" commands for extra help. |
| environment   | env, -env, --environment   | Shows the list of controlled environment variables and gives options to modify/release. Subcommands planned. |

-----------

## Troubleshooting

#### <u>How to Access The Logs</u>

To access the last 100 logs from all containers in use: `./sia -l`

To access the logs of one specific container: `./sia -l [container name]`

Container Names:
- caddy
- searxng
- redis (valkey)
- ollama
- open-webui

Or pass any arguments that can be used with `docker compose logs`

#### <u>Start & Stop Containers</u>
- Start/Restart: `./sia`
- Stop: `./sia -d` (accepts all docker compose down args)
- Deep restart:
```shell
docker kill $(docker ps -q)
./sia -d -v
./sia
```
- CAUTION: Delete existing stopped containers: `docker container prune`
   - This will delete any data not stored in persistent volumes. By default this command will erase your chats.

------------

## Roadmap

- Additional commands will be added to the SIA tool. (It's simple to extend, if you want to try!)
- Additional compose files will be added for ARM and possible Intel GPU support.
- The wiki is in production, it will contain more information.

------------

## Licensing

This project is multi-licensed to respect the upstream source while providing maximum flexibility for the original tooling created for SIA.

### 1. GNU AGPL-3.0

- All files are derived from the [searxng-docker](https://github.com/searxng/searxng-docker) project unless otherwise specified below. This project is a deeply modified clone with a broadened scope (Ollama/OpenWebUI).
- These files inherit the GNU Affero General Public License v3.0.
- **Key Requirement:** If you modify these files and run them on a server accessible over a network, you must make your modified source code available to your users.

### 2. MIT License

- The primary management script (`sia`) in this repository is an *original work* created by [Joshua Haveman](https://github.com/joshua-hvmn).
- The sia file is licensed under the permissive MIT License.
- You are free to use, copy, modify, and distribute the sia script (only) with minimal restrictions.

------------