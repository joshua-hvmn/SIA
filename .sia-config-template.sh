# |----------------------------------------------------------------------------|
# |                        SIA Management Tool - Config                        |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|
#
# DO NOT DELETE THE CONFIG TEMPLATE.
# Secret Keys and hostname are stored in the local file 'sia-config.sh'.
# Do not accidentally commit the local copy.


#!/usr/bin/env bash

## Arrays
options=( # Must be ordered like fileNames. Associative arrays are avoided for portability.
    "CPU Only"
    "Nvidia GPU"
    "AMD GPU"
)
fileNames=( # Must be ordered like options.
    ".compose.cpu.yaml"
    ".compose.nvidia.yaml"
    ".compose.amd.yaml"
)
dependencies=( # Simply add the command to be tested to this array.
    "docker"
    "git"
)
envVars=( # don't include the secret key or compose file variables, they are handled by other parts of the script. File constructed if necessary.
    "#   $appName  =  $appVersion"
    "#  For public access, change:"
    "#  - SEARXNG_HOSTNAME to your domain name"
    "#  - SEARXNG_TLS=letsencrypt  (your key)"
    "#  - Uncomment and set a LETSENCRYPT email in order to create a Let's Encrypt certificate"
    "#  TO CHANGE:" 
    "#  - $scriptName will overwrite any changes to the $envFile, except changing the SEARXNG_SECRET or COMPOSE_FILE."
    "#  - To change defaults, run '$scriptName env'"
    "# LETSENCRYPT_EMAIL="
    "SEARXNG_HOSTNAME=localhost"
    "SEARXNG_TLS=internal"
    "SEARXNG_BASE_URL=$searxngBaseURL"
    "WEBUI_URL=$webUiURL"
    "OLLAMA_BASE_URL=http://ollama:11434"
    "WEB_SEARCH_ENGINE=searxng"
    "SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>&format=json"
    "SEARXNG_SECRET"
    "COMPOSE_FILE"
    "PREVIOUSLY_RUN"
    "SETUP_COMPLETE"
)