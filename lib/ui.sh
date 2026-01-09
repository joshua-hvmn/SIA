# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|


# Check that main was loaded
if [ "${SIA_MAIN_LOADED:-}" != "true" ]; then
    printf '%s' "Error: This script is a component of SIA and cannot be run directly."
    printf '%s' "Please run: ./sia"
    exit 1
fi

# VERBOSITY AND SEMANTICS
# ANSI Color Codes
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Log func to filter outputs based on global verbosity
log() {
    log_lvl=$1; shift

    [ ${verbosity:-2} -lt $log_lvl ] && return 0
    
    if [ $log_lvl -eq 1 ]; then
        printf "%b\n" "$*" >&2
    else
        printf "%b\n" "$*"
    fi
}

# SEMANTIC WRAPPERS
# These call log() internally so you don't have to remember the numbers.
wrap_text() {
    wrptxt_text="$1"
    wrptxt_prefix_width=0  # Extra space reserved for the prefix (e.g., "[INFO]    ")
    wrptxt_wrap_indent="${2:-10}"    # How far in the continued lines should start

    # Wrap the text to the available width (total 75 minus prefix space)
    printf "%s" "$wrptxt_text" | fold -w "$((75 - wrptxt_prefix_width))" | \
    awk -v pw="$wrptxt_prefix_width" -v iw="$wrptxt_wrap_indent" '
    {
        if (NR == 1) {
            printf "%*s%s\n", pw, "", $0
        } else {
            printf "%*s%s\n", iw, "", $0
        }
    }'
}

msg_error()   { log 1 "${RED}[ERROR]${NC}   $(wrap_text "$*")"; }
msg_usage()   { log 2 "${YELLOW}[USAGE]${NC}   $(wrap_text "$*")"; }
msg_warn()    { log 2 "${YELLOW}[WARN]${NC}    $(wrap_text "$*")"; }
msg_info()    { log 2 "${BLUE}[INFO]${NC}    $(wrap_text "$*")"; }
msg_success() { log 2 "${GREEN}[CHECK]${NC}   $(wrap_text "$*")"; }
msg_debug()   { log 3 "${BOLD}[DEBUG]${NC}   $(wrap_text "$*")"; }
msg_normal()  { log 2 "$(wrap_text "$*")"; }
# msg_normal()  { log 2 "$(printf "%*s" $((10)) '')$(wrap_text "$*")"; }
msg_header() {
    msghdr_color="$BOLD"
    # POSIX way to check for ANSI prefix
    case "$1" in
        \\033*) msghdr_color="$1"; shift ;;
    esac
    log 2 "${msghdr_color}== $* ==${NC}"
}
msg_title() {
    msgttl_term_width=$(tput cols 2>/dev/null || printf '%s' $term_width_fallback)
    [ "$msgttl_term_width" -gt $term_width_fallback ] && msgttl_term_width=$term_width_fallback
    
    msgttl_color="$BOLD"
    case "$1" in
        \\033*) msgttl_color="$1"; shift ;;
    esac
    
    msgttl_text="$*"
    # Calc visible chars
    msgttl_visible_text=$(printf "%b" "$msgttl_text" | sed 's/\x1b\[[0-9;]*m//g')
    msgttl_text_length=${#msgttl_visible_text}
    
    msgttl_padding=$(( (msgttl_term_width - msgttl_text_length) / 2 ))
    [ "$msgttl_padding" -lt 0 ] && msgttl_padding=0

    log 2 "$(printf '%*s%b%b%b' "$msgttl_padding" '' "$msgttl_color" "$msgttl_text" "$NC")"
}
msg_blank()  { log 2 ""; }
msg_line() { # for lines that are terminal width
    msgline_term_width=$(tput cols 2>/dev/null || printf '%s' $term_width_fallback)
    [ "$msgline_term_width" -gt $term_max_width ] && msgline_term_width=$term_max_width
    msgline_line=$(printf '%*s' "$msgline_term_width" '' | tr ' ' '-')
    log 2 "${NC}$msgline_line${NC}"
}
msg_col() {
    msgcol_left="   $1"
    msgcol_right="$2"
    msgcol_padding=18

    msgcol_leftLength=${#msgcol_left}
    msgcol_diff="$((msgcol_padding - msgcol_leftLength))"

    [ "$msgcol_diff" -lt 1 ] && msgcol_diff=1

    msgcol_spacer="$(printf '%*s' "$msgcol_diff" "")"
    
    log 2 "$(wrap_text "${msgcol_left}${msgcol_spacer}${msgcol_right}" "$msgcol_padding")"
}

# Messages
# HELP MENUS
printHelp_general() {
    msg_blank
    msg_title ${YELLOW} "== $app_name Help Menu =="
    msg_blank
    msg_usage "$script_name [verbosity] <command>"
    msg_blank
    msg_info "$app_name is an all-in-one CLI for managing a Docker Compose stack that includes Ollama, OpenWebUI, SearXNG, Caddy, and Valkey. It should greatly simplify your use, enjoy!"
    msg_blank
    msg_header ${BLUE} "Commands"
    msg_col "(no argument)"    "Start or restart the $app_name stack (default)."
    msg_col "setup"            "Run or rerun the setup wizard to change the setup."
    msg_col "env"              "View or modify environment variables and $app_name's handling of them."
    msg_col "down"             "Stop the $app_name stack. Accepts additional arguments."
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
    msg_col "$script_name"                 "Starts the containers. On first start, runs setup and generates the secret key."
    msg_col "$script_name setup"           "Runs setup, for changing which setup you're using."
    msg_col "$script_name -d"              "Stops all $app_name containers."
    msg_col "$script_name --help"          "Shows the help message."
    msg_col "$script_name -l --verbose"    "Shows the logs and passes the --verbose argument."
    msg_blank
    msg_normal "Run '$script_name help [command]' for more help with a specific command."
    msg_blank
    msg_line
}
printHelp_down() {
    msg_blank
    msg_title ${YELLOW} "== $app_name Down Command Help Menu =="
    msg_blank
    msg_usage "$script_name down [subcommands]"
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
    msg_title ${YELLOW} "== $app_name Logs Command Help Menu =="
    msg_blank
    msg_usage "$script_name logs [subcommands]"
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
    msg_title ${YELLOW} "== $app_name Environment Handler Help Menu =="
    msg_blank
    msg_usage "$script_name env [command] [KEY] [VALUE]"
    msg_blank
    msg_info "The $app_name Environment Handler (E.H.) manages the environment variables in the $env_file file and validates or repairs them on each start. Use the E.H. rather than editing the $env_file file directly."
    msg_blank
    msg_warn "You can ADD variables to the $env_file file, but you can't change any that are controlled by the E.H., or they will be overwritten on startup. Use the E.H. to remove them from control if you want to be allowed to write them in the $env_file, it is preferable to change them using the E.H."
    msg_blank
    msg_header ${BLUE} "Subcommands"
    msg_col "(no argument)"    "Show a list of .env variables and view options to manage them."
    msg_col "add"              "Add or modify specific variables directly."
    msg_col "rm"               "WIP. Remove a specific variable from control. (use list for now)"
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -env, environment, --environment"
    msg_blank
    msg_normal "${BOLD}To add specific keys and values directly:${NC}"
    msg_usage "$script_name env add [KEY] [VALUE]"
    msg_warn "You can use the add command to edit ANY variable in ANY array in the config by defining the array BEFORE the key and value. Use extreme caution."
    msg_blank
    msg_header ${BLUE} "Examples"
    msg_col "$script_name env"      "Show a list of variables and view options to manage them."
    msg_col "$script_name env add SEARXNG_SECRET [32 byte hex code]"    "Add a new secret key to the config and $env_file file."
    msg_blank
    msg_line
}
printHelp_download() {
    msg_blank
    msg_title ${YELLOW} "== $app_name Download Help Menu =="
    msg_blank
    msg_usage "$script_name download <model name> [flags]"
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
    msg_title ${YELLOW} "== $app_name Setup Help Menu =="
    msg_blank
    msg_usage "$script_name setup"
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
    msg_title ${YELLOW} "$app_name Startup Complete!"
    msg_title "Version: $app_version"
    msg_blank
    msg_col "Access the AI Chat interface at:"      "$open_webui_url"
    msg_blank 
    msg_col "Access the SearXNG search engine at:"  "$searxng_base_url"
    msg_blank
    msg_normal "${YELLOW}Security:${NC} For secure public access, edit the environment variables:"
    msg_col "           -" "Set SEARXNG_HOSTNAME=yourdomain.com"
    msg_col "           -" "Set SEARXNG_TLS=letsencrypt  (your key)"
    msg_col "           -" "See https://docs.searxng.org for TLS setup."
    msg_normal "${YELLOW}Note:${NC}     You CANNOT change the $env_file file like other apps, $app_name validates and overwrites changes on each start, except ones not tracked by $app_name." 
#    msg_normal "You CANNOT change the $env_file file like other apps: $app_name validates and overwrites changes on each start, except ones not tracked by $app_name."
    msg_col "           -" "Run '$script_name env' to view & change environment variables / $app_name control! "
    msg_col "           -" "Then run $script_name to restart, and enjoy!"
    msg_col "           -" "'$script_name help [optional command]' to show the help menus!"
    msg_blank
    msg_line
}