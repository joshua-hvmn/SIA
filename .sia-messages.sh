# |----------------------------------------------------------------------------|
# |                        SIA Management Tool - Messages                      |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|
#
# This script is used by SIA, do not delete it.


#!/usr/bin/env bash

if [[ "${siaMainLoaded:-}" != "true" ]]; then
    echo "Error: This script is a component of SIA and cannot be run directly."
    echo "Please run: ./sia"
    exit 1
fi

# VERBOSITY AND SEMANTICS
# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color
# Default verbosities: 0: Silent, 1: Errors only, 2: Standard (Info), 3: Debug (Trace)

log() {
    local msg_lvl=$1; shift
    [[ $verbosity -lt $msg_lvl ]] && return 0
    
    # Send errors (Level 1) to stderr, everything else to stdout
    if [[ $msg_lvl -eq 1 ]]; then
        echo -e "$*" >&2
    else
        echo -e "$*"
    fi
}

# SEMANTIC WRAPPERS
# These call log() internally so you don't have to remember the numbers.

msg_error()   { log 1 "${RED}[ERROR]${NC}   $*"; }
msg_usage()   { log 2 "${YELLOW}[USAGE]${NC}   $*"; }
msg_warn()    { log 2 "${YELLOW}[WARN]${NC}    $*"; }
msg_info()    { log 2 "${BLUE}[INFO]${NC}    $*"; }
msg_success() { log 2 "${GREEN}[SUCCESS]${NC} $*"; } # SUCCESS is longest, so it has 1 space
msg_debug()   { log 3 "${BOLD}[DEBUG]${NC}   $*"; }
msg_normal()  { log 2 "          $*"; }           # 10 spaces to match the tags above
msg_header()  { log 2 "\n${BOLD}== $* ==${NC}"; }


# HELP MENUS
printHelp_general() {
    cat << EOF
Usage: $scriptName <command>

Commands:
    (no argument)    Start or restart the $appName stack (default)
    setup | -s       Run or rerun the setup wizard to change the setup
    down | -d        Stop the $appName stack. Accepts an additional argument. (Docker command)
    logs | -l        View relevant logs Accepts an additional argument. (Docker command)
    download | -dl   Download an Ollama model. Requires an additional argument. (Docker command)
    help | -h        Show this help message

Pass additional arguments to pass them to the underlying docker command.

Examples:
    $scriptName                 Starts the containers. On first start, runs setup and generates the secret key.
    $scriptName setup           Runs setup, for changing which setup you're using.
    $scriptName -d              Stops all $appName containers.
    $scriptName --help          Shows the help message.
    $scriptName -l --verbose    Shows the logs and passes the --verbose argument.
EOF
}
printHelp_down() {
    cat << EOF
Usage: $scriptName -d <command>

Command being run: docker compose down <command>

Commands:
    (no argument)       None, leaves volumes and app images (default).
    --volumes | -v      Remove volumes named in the compose file.
    --remove-orphans    Remove containers for services no longer in the compose (i.e. you modify it).
    --rmi               Remove images used by services.
    --help | -h         Show the inbuilt Docker help message (not this one).

Pass additional arguments to pass them to the underlying docker command.

EOF
}
printHelp_logs() {
    cat << EOF
Usage: $scriptName -l <command>

Command being run: docker compose logs <command>

Commands:
    (no argument)     "--tail 100" shows last 100 logs by default
    <container name>  View logs for that container.
    --timestamps | -t Show timestamps for each file.
    --no-color        Black and white.
    --no-log-prefix   Omit service name/container from each log line.
    help | -h         Show the inbuilt Docker help message (not this one).

Pass additional arguments to pass them to the underlying docker command.

EOF
}

# SELECT PS3s

selMenu_envListSelOne() {
    cat << EOF
---------------------------------------------------------------------------
Select a variable to edit or type 'x' to go back:  
EOF
}
selMenu_envListChooseAction() {
    cat << EOF
---------------------------------------------------------------------------
Choose action for $key [current: ${value:-"NOT SET"}] ('x' to go back): 
EOF
}
selMenu_processorMenu() {
    cat << EOF
---------------------------------------------------------------------------
Select your processor style or type 'x' to exit):  
EOF
}

# Start Messages
startMes_firstStart() {
    msg_info "First time setup detected (or missing configuration)!"
    log 2 "---------------------------------------------------------------------------"
}
startMes_startDone() {
    cat << EOF
---------------------------------------------------------------------------

                       $appName Startup Complete!
                          Version: $appVersion

    Access the AI Chat interface at:      $webUiURL

    Access the SearXNG search engine at:  $searxngBaseURL

    Security Tip: For secure public access, edit the environment variables:
        - Set SEARXNG_HOSTNAME=yourdomain.com
        - Set SEARXNG_TLS=letsencrypt  (your key)
    ∙ See https://docs.searxng.org for TLS setup.
    ∙ You CANNOT change the $envFile file like other apps: $appName validates
      and overwrites changes on each start, except ones not tracked by $appName.
    ∙ Run "$scriptName env" to view & change environment variables / $appName control! 
    ∙ Then run $scriptName to restart, and enjoy!
    ∙ '$scriptName help [optional command]' to show the help menus!

---------------------------------------------------------------------------
EOF
}

# Validation Messages
