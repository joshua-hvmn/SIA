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
    log 2 "$(cat << EOF
${BOLD}Usage:${NC} $scriptName [verbosity] <command>

${BLUE}Commands:${NC}
    (no argument)    Start or restart the $appName stack (default).
    setup            Run or rerun the setup wizard to change the setup.
    env              View or modify environment variables and $appName's 
                     handling of them.
    down             Stop the $appName stack. Accepts additional arguments.
    logs             View relevant logs. Accepts additional arguments.
    download         Download an Ollama model. Requires a model tag.
    help             Show this help message.

${BLUE}Verbosity Options:${NC}   (Place before <command> to alter default behavior)
    --debug  | 3      Maximum verbosity: shows all internal debug messages.
    (default)| 2      Standard output: shows essential info and progress.
    --quiet  | 1      Warning level: hides everything except critical errors.
    --silent | 0      Silent mode: suppresses all output.

${BLUE}Example Commands:${NC}
    $scriptName                 Starts the containers. On first start, runs setup 
                                and generates the secret key.
    $scriptName setup           Runs setup, for changing which setup you're using.
    $scriptName -d              Stops all $appName containers.
    $scriptName --help          Shows the help message.
    $scriptName -l --verbose    Shows the logs and passes the --verbose argument.

You can run '$scriptName' help [command] for more help with a specific command.
---------------------------------------------------------------------------
EOF
)"
}
printHelp_down() {
    log 2 "$(cat << EOF
${BOLD}Usage:${NC} $scriptName down [subcommands]

${YELLOW}Wrapper For:${NC} docker compose down [subcommands]

${BLUE}Subcommands:${NC}
    (no argument)       None, leaves volumes and app images (default).
    --volumes | -v      Remove volumes named in the compose file.
    --remove-orphans    Remove containers for services no longer in the compose file 
                        (i.e. you modify it).
    --rmi               Remove images used by services.
    --help | -h         Show the inbuilt Docker help message (not this one).

Pass additional arguments to pass them to the underlying docker command.

${GREEN}Aliases:${NC} -d, --down
---------------------------------------------------------------------------
EOF
)"
}
printHelp_logs() {
    log 2 "$(cat << EOF
${BOLD}Usage:${NC} $scriptName logs [subcommands]

${YELLOW}Wrapper For:${NC} docker compose logs [subcommands]

${BLUE}Subcommands:${NC}
    (no argument)     "--tail 100" shows last 100 logs by default
    <container name>  View logs for that container.
    --timestamps | -t Show timestamps for each file.
    --no-color        Black and white.
    --no-log-prefix   Omit service name/container from each log line.
    help | -h         Show the inbuilt Docker help message (not this one).

Pass additional arguments to pass them to the underlying docker command.

${GREEN}Aliases:${NC} -l, --logs
---------------------------------------------------------------------------
EOF
)"
}
printHelp_env() {
    log 2 "$(cat << EOF
${BOLD}Usage:${NC} $scriptName env [command] [KEY] [VALUE]

${BOLD}Description:${NC} $appName manages the environment variables in 
                    $envFile file and validates or repairs them on each
                    start. You can ADD variables to the file, but you cannot 
                    change anything that is controlled by $appName.

${BOLD}It is best to edit environment variables with the 'env' 
subcommand of $appName${NC}

${BLUE}Subcommands:${NC}
    (no argument)    Show a list of .env variables and view options to manage them.
    add              Add or modify specific variables directly.
    rm               WIP. Remove a specific variable from control. (use list for now)

Pass additional arguments to pass them to the underlying docker command.

${GREEN}Aliases:${NC} -env, environment, --environment

${GREEN}'add' Usage:${NC} $scriptName env add [KEY] [VALUE]
    ${RED}CAUTION:${NC} You can use the add command to edit ANY variable in ANY array
                   in the config by defining the array BEFORE the key and value.
                   Use extreme caution.

${BLUE}Examples:${NC}
    $scriptName env   -    Show a list of variables and view options to manage them.
    $scriptName env add SEARXNG_SECRET [32 byte hex code]  -  Add a new secret key to the config and $envFile file.
---------------------------------------------------------------------------
EOF
)"
}
printHelp_download() {
    log 2 "$(cat << EOF
${BOLD}Usage:${NC} $scriptName download <model name> [flags]

${YELLOW}Wrapper For:${NC} docker exec ollama ollama run <model name> [flags]

${BLUE}Arguments:${NC}
    <model name>      Name of the Ollama model you want to download/run.

${BLUE}Common Options:${NC}
    --verbose         Show detailed timing and response stats.
    --format json     Return output in JSON format.
    --help            Show the full Ollama internal help menu.

 ${RED}NOTE:${NC} You can pass any number of flags to the underlying command.
             The messaging might be inaccurate depending on the flags used.

${GREEN}Aliases:${NC} -dl, --download
---------------------------------------------------------------------------
EOF
)"
}
printHelp_setup() {
    log 2 "$(cat << EOF
${BOLD}Usage:${NC} $scriptName setup

${BOLD}Description:${NC} Run to change system architecture for hardware acceleration.
                    (i.e., you change from CPU only to NVIDIA GPU).

${GREEN}Aliases:${NC} -s, --setup
---------------------------------------------------------------------------
EOF
)"
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
    - See https://docs.searxng.org for TLS setup.
    - You CANNOT change the $envFile file like other apps: $appName validates
      and overwrites changes on each start, except ones not tracked by $appName.
    - Run "$scriptName env" to view & change environment variables / $appName control! 
    - Then run $scriptName to restart, and enjoy!
    - '$scriptName help [optional command]' to show the help menus!

---------------------------------------------------------------------------
EOF
}

# Validation Messages
