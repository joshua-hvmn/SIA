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

# HELP MENUS
printHelp_general() {
    msg_blank
    msg_title ${YELLOW} "== $appName Help Menu =="
    msg_blank
    msg_usage "$scriptName [verbosity] <command>"
    msg_blank
    msg_info "$appName is an all-in-one CLI for managing a Docker Compose stack that includes Ollama, OpenWebUI, SearXNG, Caddy, and Valkey. It should greatly simplify your use, enjoy!"
    msg_blank
    msg_header ${BLUE} "Commands"
    msg_col "(no argument)"    "Start or restart the $appName stack (default)."
    msg_col "setup"            "Run or rerun the setup wizard to change the setup."
    msg_col "env"              "View or modify environment variables and $appName's handling of them."
    msg_col "down"             "Stop the $appName stack. Accepts additional arguments."
    msg_col "logs"             "View relevant logs. Accepts additional arguments."
    msg_col "download"         "Download an Ollama model. Requires a model tag."
    msg_col "help"             "Show this help message."
    msg_blank
    msg_header ${BLUE} "Verbosity Options"
    msg_col "--debug  | 3"      "Maximum verbosity: shows all internal debug messages."
    msg_col "(default)| 2"      "Standard output: shows essential info and progress."
    msg_col "--quiet  | 1"      "Warning level: hides everything except critical errors."
    msg_col "--silent | 0"      "Silent mode: suppresses all output."
    msg_normal "(Place before <command> to alter default behavior for that output)"
    msg_blank
    msg_header ${BLUE} "Example Commands"
    msg_col "$scriptName"                 "Starts the containers. On first start, runs setup and generates the secret key."
    msg_col "$scriptName setup"           "Runs setup, for changing which setup you're using."
    msg_col "$scriptName -d"              "Stops all $appName containers."
    msg_col "$scriptName --help"          "Shows the help message."
    msg_col "$scriptName -l --verbose"    "Shows the logs and passes the --verbose argument."
    msg_blank
    msg_normal "Run '$scriptName help [command]' for more help with a specific command."
    msg_blank
    msg_line
}
printHelp_down() {
    msg_blank
    msg_title ${YELLOW} "== $appName Down Command Help Menu =="
    msg_blank
    msg_usage "$scriptName down [subcommands]"
    msg_blank
    msg_normal "${BOLD}[WRAPS]${NC}   docker compose down [subcommands]"
    msg_blank
    msg_info "The 'down' command is a wrapper command so you don't have to type the full command to stop or delete parts of the stack. It accepts multiple flags. Use caution."
    msg_blank
    msg_header ${BLUE} "Subcommands"
    msg_col "(no argument)"       "None, stops the stack, leaves volumes and app images (default)."
    msg_col "--volumes | -v"      "Remove volumes named in the compose file."
    msg_col "--remove-orphans"    "Remove containers for services no longer in the compose file (i.e. you modify it)."
    msg_col "--rmi"               "Remove images used by services."
    msg_col "--help | -h"         "Show the inbuilt Docker help message (not this one)."
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -d, --down"
    msg_blank
    msg_line
}

printHelp_logs() {
    msg_blank
    msg_title ${YELLOW} "== $appName Logs Command Help Menu =="
    msg_blank
    msg_usage "$scriptName logs [subcommands]"
    msg_blank
    msg_normal "${BOLD}[WRAPS]${NC}   docker compose logs [subcommands]"
    msg_blank
    msg_info "The 'logs' command is a wrapper command so you don't have to type the full command to see the Docker Compose logs. It accepts multiple flags."
    msg_blank
    msg_header ${BLUE} "Subcommands"
    msg_col "(no argument)"     "--tail 100 shows last 100 logs by default"
    msg_col "<container name>"  "View logs for that container."
    msg_col "--timestamps | -t" "Show timestamps for each file."
    msg_col "--no-color"        "Black and white."
    msg_col "--no-log-prefix"   "Omit service name/container from each log line."
    msg_col "help | -h"         "Show the inbuilt Docker help message (not this one)."
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -l, --logs"
    msg_blank
    msg_line
}
printHelp_env() {
    msg_blank
    msg_title ${YELLOW} "== $appName Environment Handler Help Menu =="
    msg_blank
    msg_usage "$scriptName env [command] [KEY] [VALUE]"
    msg_blank
    msg_info "The $appName Environment Handler (E.H.) manages the environment variables in the $envFile file and validates or repairs them on each start. Use the E.H. rather than editing the $envFile file directly."
    msg_blank
    msg_warn "You can ADD variables to the $envFile file, but you can't change any that are controlled by the E.H., or they will be overwritten on startup. Use the E.H. to remove them from control if you want to be allowed to write them in the $envFile, it is preferable to change them using the E.H."
    msg_blank
    msg_header ${BLUE} "Subcommands"
    msg_col "(no argument)"    "Show a list of .env variables and view options to manage them."
    msg_col "add"              "Add or modify specific variables directly."
    msg_col "rm"               "WIP. Remove a specific variable from control. (use list for now)"
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -env, environment, --environment"
    msg_blank
    msg_normal "${BOLD}To add specific keys and values directly:${NC}"
    msg_usage "$scriptName env add [KEY] [VALUE]"
    msg_warn "You can use the add command to edit ANY variable in ANY array in the config by defining the array BEFORE the key and value. Use extreme caution."
    msg_blank
    msg_header ${BLUE} "Examples"
    msg_col "$scriptName env"      "Show a list of variables and view options to manage them."
    msg_col "$scriptName env add SEARXNG_SECRET [32 byte hex code]"    "Add a new secret key to the config and $envFile file."
    msg_blank
    msg_line
}
printHelp_download() {
    msg_blank
    msg_title ${YELLOW} "== $appName Download Help Menu =="
    msg_blank
    msg_usage "$scriptName download <model name> [flags]"
    msg_blank
    msg_normal "${BOLD}[WRAPS]${NC}   docker exec ollama ollama run <model name> [flags]"
    msg_blank
    msg_info "The 'download' command is a wrapper so you don't have to type the long Docker exec command. Find models to download at https://ollama.com/search. The command will fail if you don't provide a model tag."
    msg_blank
    msg_header ${BLUE} "Arguments"
    msg_col "<model name>"      "Name of the Ollama model you want to download/run."
    msg_blank
    msg_header ${BLUE} "Common Options"
    msg_col "--verbose"         "Show detailed timing and response stats."
    msg_col "--format json"     "Return output in JSON format."
    msg_col "--help"            "Show the full Ollama internal help menu."
    msg_blank
    msg_info "You can pass any number of flags to the underlying command."
    msg_warn "The messaging might be inaccurate depending on the flags used."
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -dl, --download"
    msg_blank
    msg_line
}
printHelp_setup() {
    msg_blank
    msg_title ${YELLOW} "== $appName Setup Help Menu =="
    msg_blank
    msg_usage "$scriptName setup"
    msg_blank
    msg_info "Run to change system architecture for hardware acceleration (e.g., you change from CPU only to NVIDIA GPU). This is important for maximizing the speed of large language models."
    msg_blank
    msg_warn "To take advantage of hardware acceleration, you have to install Docker correctly. Additional dependencies are required."
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -s, --setup"
    msg_blank
    msg_line
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
    msg_line
}

startMes_startDone() {
    msg_line
    msg_blank
    msg_title ${YELLOW} "$appName Startup Complete!"
    msg_title "Version: $appVersion"
    msg_blank
    msg_col "Access the AI Chat interface at:"      "$webUiURL"
    msg_blank 
    msg_col "Access the SearXNG search engine at:"  "$searxngBaseURL"
    msg_blank
    msg_normal "${YELLOW}Security:${NC} For secure public access, edit the environment variables:"
    msg_col "           -" "Set SEARXNG_HOSTNAME=yourdomain.com"
    msg_col "           -" "Set SEARXNG_TLS=letsencrypt  (your key)"
    msg_col "           -" "See https://docs.searxng.org for TLS setup."
    msg_normal "${YELLOW}Note:${NC}     You CANNOT change the $envFile file like other apps, $appName validates and overwrites changes on each start, except ones not tracked by $appName." 
#    msg_normal "You CANNOT change the $envFile file like other apps: $appName validates and overwrites changes on each start, except ones not tracked by $appName."
    msg_col "           -" "Run '$scriptName env' to view & change environment variables / $appName control! "
    msg_col "           -" "Then run $scriptName to restart, and enjoy!"
    msg_col "           -" "'$scriptName help [optional command]' to show the help menus!"
    msg_blank
    msg_line
}