# Synthetic Intelligence App

Take back some sovereignty in just *ten* simple steps, if that!

Here's a simple, all-in-one tool for running a Docker Compose stack which provides *simple, secure, self-hosted* alternatives to ChatGPT and Google — with a foolproof setup process on Linux and Mac, SIA should also be compatible with Windows via Docker Desktop and WSL.

SIA uses popular open-source tools; it's extensible; and setup and management are made dead simple with its robust and portable command line interface.

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
**3. <u>Run the SIA command line tool</u>:** (main script only)
```
./sia
```

*Note: If you receive a 'permission denied' error, you might need to make the sia file executable with* `chmod +x sia`, or the appropriate command for your system.

**4. <u>Select a system architecture</u>:**  The tool will ask how your system is configured. Enter the corresponding number of your choice.

If you accidentally pick the wrong one or you modify your system (i.e., *upgrade* from an NVIDIA GPU to an AMD GPU), you can run `./sia -s` to change the setup!

The SearXNG secret key will be randomly generated upon first setup, and stored in the .env file if you need it. (Show hidden files in your file explorer to see it, and the YAML files!).

If you want to use your own proxy rather than Caddy, Complete [Using Another Proxy](#using-another-proxy-advanced-users) below **before** running the script.

**5. <u>Install an Ollama LLM</u>** from [their search directory](https://ollama.com/search).

```
./sia -dl <model-tag>
```
- *e.g., llama3.2:1b*


---------

*Additional Info:*

FOR CHANGING ENVIRONMENT VARIABLES: 
- You can't *change* environment variables directly in the .env file.
- You *must* change them with the SIA Environment Handler: `./sia env`
- You *may* add new variables to the file directly, and SIA will leave them alone.
- You can trigger SearXNG secret key *regeneration* by deleting the key in the .env file.
- You can trigger a full reset of the environment, but not any other data in the stack, by *deleting:* `.env` and `sia-config.sh`.
- Keep in mind the .env file is a hidden file, click "View hidden files".
---------

### III. Post Install

6. Access Open WebUI at [http://localhost:3000](http://localhost:3000) by default.
7. Create an "Admin Account" and bookmark the page.
8. Connect Ollama to Open WebUI if necessary: (SIA should inject the settings, but it might not work)
   - Click name in corner > Admin Panel > Settings > Connections > Ollama API > Manage Ollama API Connections > Configure (gear icon)
   - Make sure Ollama API is enabled, and the API connection is set to `http://ollama:11434`
9. Connect SearXNG to Open WebUI if necessary:
   - Admin Panel > Settings > Web Search
   - Enable, set to SearXNG
   - Set query URL to `http://searxng:8080/search?q=<query>&format=json`
   - Note: In this version of SIA, web searches are sent over HTTP (unencrypted) between containers to avoid certificate trust issues.
10. Use SearXNG at [https://localhost:443](https://localhost:443) by default. You will need to accept the security warning for the self-signed certificates. You have to configure the Caddy TLS certificate for your system to resolve this issue. It is in fact secure and encrypted, the warning is mostly an annoyance.

Set your default search bar in your browser: 
| Browser       | Search Query                                            |                                     |
| ----------    | ------------------------------------------------------- | ----------------------------------- |
| Chromium      | `https://localhost/search?q=%s`                         |                                     |
| Firefox       | Need additional extensions.                             | (Switch to Ungoogled Chromium *ha*) |
| Edge.        | `https://localhost/search?q=%s`                         | (Chromium)                          |
| Safari        | Need an extension Like AnySearch. Easier than Firefox.  | Query URL is the same as Chromium.  |

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

The SIA command line tool comes equipped with several subcommands and an ability to pass arguments to the underlying Docker Compose commands. This feature set may well be extended in the future.

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
- Start/restart: `./sia`
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

## Design Philosophy
You may wonder why I've built a whole CLI for a Docker Compose stack.

These are the **Core Principles** of my design:
- **Beginner Friendly:** This project was motivated by my own struggles to get this stack to run correctly (and trust it). Offload some struggling, it's mostly done.
- **Automation Friendly:** Users should not have to open a file to manage the environment. Use the CLI yourself or via other tools with the `--silent` tag at the start.
- **Explicit & Stateful:** Dependencies and the .env file are validated (or repaired) on each start.
- **Idempotent:** Run the same commands repeatedly without risk.
- **Very Portable:** Broad hardware support and a focus on Bash 3.2 compatibility.
- **Secure:** Greatly simplified security concerns for the user.

Under this philosophy I have done three things: one, include optimized YAML files for various processors; two, build a CLI; and three, eliminate the normal way to manage a Docker Compose stack: by the editing of the .env file — in favor of storing them in a local copy of the `sia-config-template.sh` file.

This has made SIA:

1. Beginner friendly:
   - User do not have to worry about configuring the `compose.yaml` file, they just select their processor type and the tooling handles the rest.
   - Users can change to a different processor type in the config with the `./sia setup` command.
   - Users can view, edit, and understand environment variables without the high-context abstractions of Docker Compose. 

2. Stateful:
   - Give SIA something to validate the .env file against.
   - Give SIA the ability to edit the .env file.
   - Give SIA the ability to create a valid .env file if one is missing, or repair it if it's damaged.
   - Users can *manually* trigger a reset of the state by *deleting* the .env and *local* `sia-config.sh` files totally.

3. Automation friendly, secure, and portable:
   - The tooling runs perfectly with `set -euo pipefail`.
   - My careful design of the included scripts involves a strict focus on supporting Bash 3.2 at the latest, with a long term goal for even more portability by switching to a fully POSIX standard design. I am *explicitly* avoiding newer standards, despite exclusively using Pop!_OS 24.04 myself.

As a result of my efforts, I've built a command line interface that has *complete* control over Docker Compose environment variables in the SIA stack. This makes automatic secret key rotation easy to implement (which it is not yet). Best of all, the tool should work out of the box on the majority of systems.

## Security
Security is a primary focus of this project. SIA is meant to enforce better security than what most users will do on their own.

Assumptions:

1. Most users are not technically literate to the same degree as tech enthusiasts or developers.
2. Most users are mostly ignorant of crypto security.
3. **ALL** users **will** break things and configure them incorrectly in some way if they have the ability.

Consequently:

- The SearXNG secret key is automatically generated on first start, and injected into the .env file without SIA storing the key long-term. There are robust fallbacks in case the user is missing OpenSSL, and it will error out if it can't find a way to generate a *safe* 32 byte hex code. The secret key is only stored in the .env file unless the user manually updates it by adding one with the SIA Environment Handler (E.H.).
- SIA will automatically generate a new secret key if it is missing. Meaning the *easiest* way to rotate keys is by simply *deleting* the secret key in the .env file.

In conclusion, I gave SIA control over the environment *primarily* to enable secret key generation, repair, and rotation; and *secondarily* to enable general state validation and repair.

Additional Information:
- SIA requires additional configuration for public usage. Follow the prompt shown on startup.
- Due to the way the SIA E.H. works, you can use it to *replace* secret keys in the .env file manually. *Importantly*, as it currently stands, it will store the key in `sia-config.sh` (if you add one with the E.H.), making the key visible to anyone who can run the script, until you manually untrack it. If you want to manually update the SearXNG secret key in this version with the E.H., you must remove it through the E.H. **after** you add them and restart SIA (or manually edit the envVars array in the local config file: remove the SEARXNG_SECRET's value and the = symbol). I intend to add a built in secret key rotator that does not use the E.H. at all.


## Roadmap

- Additional commands will be added to the SIA tool. (It's simple to extend, if you want to try!)
- Additional compose files will be added for ARM and possible Intel GPU support.
- The wiki will begin production soon, it will contain more information.

------------

## Licensing

This project is multi-licensed to respect the upstream source while providing maximum flexibility for the original tooling created for SIA.

### 1. GNU AGPL-3.0

- All files are derived from the [searxng-docker](https://github.com/searxng/searxng-docker) project unless otherwise specified below. This project is a deeply modified clone with a broadened scope (Ollama/OpenWebUI).
- These files inherit the GNU Affero General Public License v3.0.
- **Key Requirement:** If you modify these files and run them on a server accessible over a network, you must make your modified source code available to your users.

### 2. MIT License

- The following scripts in this repository are *original works* by [Joshua Haveman](https://github.com/joshua-hvmn).
   - `sia`
   - `.sia-config-template.sh`
   - `.sia-messages.sh`
- These three files are licensed under the permissive MIT License.
- You are free to use, copy, modify, and distribute these files specifically with minimal restrictions.

------------