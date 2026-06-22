# Synthetic Intelligence App

Take back some sovereignty in just *ten* simple steps, if that!

Here's a simple, all-in-one tool for running a Docker Compose stack which provides *simple, secure, self-hosted* alternatives to ChatGPT and Google — with a foolproof setup process on Linux and Mac, SIA should also mostly be compatible with Windows via Docker Desktop and WSL.

SIA features a carefully designed command line interface, you should never have to type long commands or search for hidden files to manage something so simple.
- Automated setup and configuration!
- Use menus or commands
- Rotate secret keys, configure trust certificates
- Extremely portable — designed to be POSIX sh compliant. 

And best of all, the CLI source code is *yours* to keep, copy, and use — licensed under the permissive MIT license!

### Table of Contents
1. [Install](#i-install)
2. [Quick Start](#ii-quick-start)
3. [Post Install](#iii-post-install)
4. [Restarting](#iv-restarting)
5. [Updating](#v-updating)
6. [Using Another Proxy (Advanced Users)](#using-another-proxy-advanced-users)
7. [Commands](#commands)
8. [Troubleshooting](#troubleshooting)
9. [Design Philosophy](#design-philosophy)
10. [Security](#security)
11. [Licensing](#licensing)

------------

## What is included?

| Name                                          | Description                                                    | Docker image                                                                 | Dockerfile                                                                                                                                                                                    |
|-----------------------------------------------|----------------------------------------------------------------|------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [Caddy](https://github.com/caddyserver/caddy) | Reverse proxy (create a Let's Encrypt certificate automatically) | [docker.io/library/caddy:2-alpine](https://hub.docker.com/_/caddy)           | [Dockerfile](https://github.com/caddyserver/caddy-docker/blob/master/Dockerfile.tmpl)                                                                                                         |
| [SearXNG](https://github.com/searxng/searxng) | SearXNG by itself                                              | [docker.io/searxng/searxng:latest](https://hub.docker.com/r/searxng/searxng) | [builder.dockerfile](https://github.com/searxng/searxng/blob/master/container/builder.dockerfile) [dist.dockerfile](https://github.com/searxng/searxng/blob/master/container/dist.dockerfile) |
| [Valkey](https://github.com/valkey-io/valkey) | In-memory database                                             | [docker.io/valkey/valkey:8-alpine](https://hub.docker.com/r/valkey/valkey)   | [Dockerfile](https://github.com/valkey-io/valkey-container/blob/mainline/Dockerfile.template)                                                                                                 |
| [Ollama](https://github.com/ollama/ollama) | LLM runner                                             | [docker.io/ollama/ollama](https://hub.docker.com/r/ollama/ollama)   |                                                                                                  |
| [Open WebUI](https://github.com/open-webui/open-webui) | AI chat GUI                                             | ghcr.io/open-webui/open-webui   |                                                                                                  |
| SIA CLI | POSIX compliant sh CLI for managing this stack                                             |    |           |

------------

## Usage


### I. Install
**1. [Install docker](https://docs.docker.com/install/)** (make sure you install it correctly for your GPU if you have one, or it will say "runtime not found")

**2. <u>Clone the SIA Repository</u>**

```shell
cd ~
git clone https://github.com/joshua-hvmn/SIA.git
cd SIA
```
------------
### II. Quick Start
**3. <u>Run the SIA command line tool</u>:**
```
chmod +x sia && ./sia up
```

**4. <u>Select a system architecture</u>:**  The tool will ask how your system is configured. Enter the corresponding number of your choice.

If you accidentally pick the wrong one or you modify your system (i.e., *upgrade* from an NVIDIA GPU to an AMD GPU), you can run `./sia setup` to change the setup!

The SearXNG secret key will be randomly generated upon first setup, and stored in the .env file if you need it. (Show hidden files in your file explorer to see it, and the YAML files!).

If you want to use your own proxy rather than Caddy, Complete [Using Another Proxy](#using-another-proxy-advanced-users) below **before** running the script.

After the Docker containers start, SIA will configure the Caddy CA certificates so your system and browser can trust them. After this is finished, you have to restart SIA one more time:
```
./sia up
```

**5. <u>Install an LLM</u>** from [Ollama](https://ollama.com/search) or from [HuggingFace](https://huggingface.co/models).

```
./sia ollama run <model-tag>
```
- *e.g., llama3.2:1b*
- *Note: This is just a wrapper for the command `docker exec ollama ollama ...`*

**<u>Additional Information</u>**

Extra functionality is accessible through the carefully designed menus! To use them, run:
```
./sia
```

Editing Environment Variables: 
- You can edit the `.env` file manually or use the built in Environment Handler (E.H.): `./sia env`, which can be accessed by either menus or commands.
- You can rotate SearXNG secret keys easily with: `./sia env rotate`
- You can trigger a full reset of the environment, but not any other data in the stack, by *deleting* the `.env` file. It will create a new one from the template `env_defaults`.

*Run `./sia help [command]` for help!*

------------

### III. Post Install

6. Access Open WebUI at [https://chat.localhost](https://chat.localhost) by default.
7. Create an "Admin Account" and bookmark the page.
8. Connect Ollama to Open WebUI if necessary: (SIA should inject the settings, but it might not work, make sure you have a model running)
   - Click name in corner > Admin Panel > Settings > Connections > Ollama API > Manage Ollama API Connections > Configure (gear icon)
   - Make sure Ollama API is enabled, and the API connection is set to `http://ollama:11434`
9. Connect SearXNG to Open WebUI if necessary (again, this should be set up automatically):
   - Admin Panel > Settings > Web Search
   - Enable, set to SearXNG
   - Set query URL to `http://searxng:8080/search?q=<query>&format=json`
10. Use SearXNG at [https://localhost:443](https://localhost:443) by default and set your default search engine in your browser:

**Firefox:**

* **A.** Navigate to `https://localhost`
* **B.** Right click on the Firefox search bar at the top
* **C.** Click **"Add SearXNG"**
* **D.** Go to **Settings > Search**, and change the default to **SearXNG**
      
**Chromium / Chrome / Brave:**
      
* **A.** Navigate to `https://localhost`, and do a test search to ensure Chromium detects the search engine.
* **B.** Go to **Settings > Search engine > Manage search engines and site search.**
* *Note: If Chromium fails to detect SearXNG, set the default search URL to: `https://localhost/search?q=%s`*
* **C.** Under **Site search**, locate `localhost`. Click the three dots next to it and **Make default**.
      
**Safari:**

> *Note: Safari doesn't natively support custom OpenSearch URLs. To use a custom instance, you must use a third-party extension.*
      
* **A.** Download a search-routing extension from the Mac App Store [Customize Search Engine (FOSS)](https://apps.apple.com/app/customize-search-engine/id6445840140) or [xSearch (Paid, cloud sync)](https://apps.apple.com/app/xsearch-for-safari/id1579902068).
* **B.** Open the extension's settings.
* **C.** Set your custom Query URL to: `https://localhost/search?q=%s`
* **D.** Enable the extension in **Safari > Settings > Extensions**.

11. That's pretty much everything, enjoy!

------------

### IV. Restarting
When you restart your computer, you have to restart the containers:

<u>Restart:</u>
```shell
./sia up
```
If it fails to restart, you can use the following command to check what is active on the busy port:

`sudo lsof -i :[port number]`

- ports used are: 443, 11434, 3000, 8888, and 8080

Stop whatever is running by force: `sudo systemctl stop [container name, i.e., ollama]`

Restart the containers again: `./sia up`

------------

### V. Updating
SIA wraps different update commands so you can easily update its components, or the Docker images, and it will optionally clean up old images.

<u>Update:</u>
```shell
./sia update [argument]
```

<u>Arguments:</u>
- sia: updates the SIA components with `git pull` (or curl).
- docker: updates the Docker images with `docker compose pull`
- all: updates SIA components and Docker images.

<u>**Important:**</u>
- If the env or yaml file defaults are updated, you will have to restore defaults with `./sia env reset [arg]` (args: blank=menu, otherwise, specify `env` or `yaml`).
- If you customized any of those files, they are stored in the `archive/` folder. The tool overwrites files in the archive if they have their default names. Change the names of archived files if you want them to stay around.


------------

### <u>Using Another Proxy</u> (advanced users)

Bring your own reverse proxy

1. Remove the caddy related parts in `.compose.<architecture of choice>.yaml` such as the caddy service and its volumes. (Hidden files!)
2. Point your reverse proxy to the port set for the `searxng` service in the compose file (8080 by default).
3. Generate and configure the required TLS certificates with the reverse proxy of your choice.
4. Run SIA: `./sia`

------------

## Commands

The SIA tool comes with many commands. More features are planned.

| Command       | Other Names                | Description |
| ----------    | -------------------------- | ----------- |
| (no command)  | menu                       | Opens the CLI menu system. |
| up            | -st, start, --start        | Start/restart. Automatically runs setup on first start. |
| setup         | -su, --setup               | Run the setup wizard. Run if you change between CPU/Nvidia/AMD. |
| down          | -d, --down                 | Stop the SIA stack. Accepts additional arguments. (Docker Compose wrapper) |
| logs          | -l, --logs                 | View relevant logs Accepts additional arguments. (Docker Compose wrapper) |
| ollama        | -o, --ollama               | Open the Ollama command wrapper menu, or run the ollama command you define. (Ollama wrapper) |
| help          | -h, --help                 | Show useful help messages. Add another command at the end for that command's help menu! |
| environment   | env, -env, --environment   | Open the Environment Handler. Has subcommands, check help (or just use the menus). |

------------

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
- Start/restart: `./sia up`
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
You may wonder why I would build a whole CLI for a simple Docker Compose stack.

These are the **Core Principles** of my design:
- **Beginner Friendly:** This project was motivated by my own struggles to get this stack to run correctly (and trust it). I wanted to make it easy for others.
- **Automation Friendly:** Users should not have to open a file to manage the environment variables. Use the CLI yourself or via other tools with the `--silent` tag at the start.
- **Explicit & Stateful:** Dependencies and the environment are validated (or repaired) on each start.
- **Idempotent:** Run the same commands repeatedly without risk.
- **Portable:** Broad hardware support and POSIX compliance and minimal dependencies beyond Docker itself.
- **Secure:** Greatly simplified security concerns for the user. It won't start if the SearXNG secret key isn't 64 hexadecimal characters, and you lack the three tools it attempts to use to generate a safe one.

To accomplish these goals, I set out to build the most portable and secure CLI that I could, with little prior knowledge.

How have I made SIA:

1. Beginner friendly?
   - User do not have to worry about configuring the `compose.yaml` file, they just select their processor type and the tooling handles the rest.
   - Users can change to a different processor type in the config with the `./sia setup` command.
   - Users can view, edit, and understand environment variables without the high-context abstractions of Docker Compose. 

2. Stateful?
   - SIA stores state data in the .env file, like whether it has been run before.
   - SIA can edit the .env file, or possibly other data files.
   - SIA creates a valid .env file if one is missing, or repair parts if they're damaged.
   - Users can trigger a reset of the state by *deleting* the .env file totally.

3. Automation friendly, secure, and portable?
   - The tooling ran with `set -euo pipefail` when it was Bash.
   - The tool was redesigned to be POSIX sh compliant, nearly maximizing theoretical portability, despite exclusively using Pop!_OS 24.04 myself.

As a result of my efforts, I've built a command line interface that has *complete* control over Docker Compose environment variables in the SIA stack, and the tool should work out of the box on the majority of systems.

## Security
Security is a primary focus of this project. SIA is meant to enforce a stricter security policy than most users will on their own.

Core assumptions:

1. Most users are not technically literate to the same degree as tech enthusiasts or developers.
2. Most users are ignorant of cryptography.
3. **ALL** users **will** break things and configure them incorrectly in some way if they can — even power users.

So, by design:

- The SearXNG secret key is automatically generated on first start, and injected into the .env file without SIA storing the key long-term. There are robust fallbacks in case the user is missing OpenSSL, and it will error out if it can't find a way to generate a *safe* 32 byte hex code. The secret key is only stored in the .env file, and the SIA tool can't show the key.
- SIA will automatically generate a new secret key if it's missing, ***or*** if it isn't 64 digits of hexadecimal characters (i.e., it's damaged by the user).
- You can rotate secret keys with one command. By running in --silent mode, you can skip the validation checks, meaning you can automate key rotation with another tool if needed.

In conclusion, I gave SIA control over the environment variables *primarily* to enable secret key generation, repair, and rotation; and *secondarily* for statefulness and ease of use — secret key automation was my ultimate goal. In old versions of SIA, there were no scripts at all; it was once just a simple guide. I worried that someone might skip the steps in the guide to generate a safe secret key, and that they might accidentally leak what they do have.

Additional Security Information:
- SIA requires additional configuration for public usage. Follow the prompt shown on startup or in the .env file, and check the SearXNG and Open WebUI documentation.
- The SIA E.H. **cannot** display the SearXNG secret key. To view it, you *must* open the .env file.
- Whenever SIA edits the .env file (or any file by using the edit_kv function), it uses a sophisticated temp file creation system:
   - It tries mktemp, and if that isn't available, it uses a hardened and randomized PID approach to minimize the attack surface.
   - It checks that the given name is not taken, and it will fail if it cannot create an original temp file name after 10 attempts, if mktemp isn't available.
   - It copies the permissions of the original to the new version, or defaults to chmod 600.


## Roadmap

- Additional commands will be added to the SIA tool. (It's simple to extend, if you want to try!)
- Additional compose files will be added for ARM and possible Intel GPU support.
- The wiki will begin production soon, it will contain additional information.

------------

## Licensing

This project is multi-licensed to respect the upstream source while providing maximum flexibility for the original tooling created for SIA.

All files are provided under open source licenses, as is, without warranty. Use at your own risk.

### 1. GNU AGPL-3.0

- Files are derived from the [searxng-docker](https://github.com/searxng/searxng-docker) project unless otherwise specified below. This project is a deeply modified clone with a broadened scope (Ollama, OpenWebUI, management tool).
- Any files *not specified as MIT licensed* inherit the GNU Affero General Public License v3.0.
- **Key Requirement:** If you modify these files and run them on a server accessible over a network, you must make your modified source code available to your users.

### 2. MIT License

- The following files in this repository are *original works* by [Joshua Haveman](https://github.com/joshua-hvmn).
   - The `sia` script in the main directory
   - All **ten** files in the `lib/` directory:
      - `lib/router.sh`
      - `lib/core.sh`
      - `lib/env_logic.sh`
      - `lib/security.sh`
      - `lib/ui.sh`
      - `lib/messages.sh`
      - `lib/dependencies.sh`
      - `lib/update.sh`
      - `lib/caddy-ca-config.sh`
      - `lib/model_manager.sh`
   - These **four** files in the `share/` directory (NOT the yaml files): 
      - `share/dependencies`
      - `share/env_defaults`
      - `share/providers`
      - `share/files`
- These fifteen files are licensed under the permissive MIT License.
- You are free to use, copy, modify, and distribute these files specifically with minimal restrictions.

------------
