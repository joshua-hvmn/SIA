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
    printf "%s" "$wrptxt_text" | fold -w "$((term_max_width - wrptxt_prefix_width))" | \
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
    log 2 " ${msghdr_color}== $* ==${NC}"
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
    msgcol_padding="${3:-18}"

    msgcol_leftLength=${#msgcol_left}
    msgcol_diff="$((msgcol_padding - msgcol_leftLength))"

    [ "$msgcol_diff" -lt 1 ] && msgcol_diff=1

    msgcol_spacer="$(printf '%*s' "$msgcol_diff" "")"
    
    log 2 "$(wrap_text "${msgcol_left}${msgcol_spacer}${msgcol_right}" "$msgcol_padding")"
}

# Messages
# HELP MENUS
print_help_general() {
    msg_blank
    msg_header ${YELLOW} "$app_name General Help Menu"
    msg_blank
    msg_usage "$script_name [verbosity] <command> [flags]"
    msg_blank
    msg_info "$app_name is an all-in-one CLI for managing a Docker Compose stack that includes Ollama, OpenWebUI, SearXNG, Caddy, and Valkey. It should greatly simplify your use, enjoy!"
    msg_blank
    msg_header ${BLUE} "Commands"
    msg_col "(no argument)"    "Show the $app_name main menu (default)."
    msg_col "up / start"       "Start or restart $app_name."
    msg_col "setup"            "Run or rerun the setup wizard to change the setup."
    msg_col "env"              "View or modify environment variables, or rotate the SearXNG secret key."
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
    msg_usage "Use as the first argument only."
    msg_blank
    msg_header ${BLUE} "Example Commands"
    msg_col "$script_name up"              "Starts the containers. On first start, runs setup and generates the secret key." 25
    msg_col "$script_name setup"           "Runs setup, for changing which setup you're using." 25
    msg_col "$script_name -d"              "Stops all $app_name containers." 25
    msg_col "$script_name --help"          "Shows the help message." 25
    msg_col "$script_name -l --verbose"    "Shows the logs and passes the --verbose argument." 25
    msg_blank
    msg_normal "Run '$script_name help [command]' for more help with a specific command, you can pass their alias names."
    msg_blank
    help_menu_backopt || msg_line
}
print_help_down() {
    msg_blank
    msg_header ${YELLOW} "$app_name Down Command Help Menu"
    msg_blank
    msg_usage "$script_name down [flags]"
    msg_blank
    msg_normal "${BOLD}[WRAPS]${NC}   docker compose down [flags]"
    msg_blank
    msg_info "The 'down' command is a wrapper command so you don't have to type the full command to stop or delete parts of the stack. It accepts multiple flags. Use caution."
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -d, --down"
    msg_blank
    msg_header ${BLUE} "Common Flags"
    msg_col "(no argument)"       "None, stops the stack, leaves volumes and app images (default)." 23
    msg_col "--volumes | -v"      "Remove volumes named in the compose file." 23
    msg_col "--remove-orphans"    "Remove containers for services no longer in the compose file (i.e. you modify it)." 23
    msg_col "--rmi"               "Remove images used by services." 23
    msg_col "--help | -h"         "Show the inbuilt Docker help message (not this one)." 23
    msg_blank
    help_menu_backopt || msg_line
}

print_help_logs() {
    msg_blank
    msg_header ${YELLOW} "$app_name Logs Command Help Menu"
    msg_blank
    msg_usage "$script_name logs [flags]"
    msg_blank
    msg_normal "${BOLD}[WRAPS]${NC}   docker compose logs [flags]"
    msg_blank
    msg_info "The 'logs' command is a wrapper command so you don't have to type the full command to see the Docker Compose logs. It accepts multiple flags."
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -l, --logs"
    msg_blank
    msg_header ${BLUE} "Common Flags"
    msg_col "(no argument)"     "--tail 100 shows last 100 logs by default" 21
    msg_col "<container name>"  "View logs for that container." 21
    msg_col "--timestamps | -t" "Show timestamps for each file." 21
    msg_col "--no-color"        "Black and white." 21
    msg_col "--no-log-prefix"   "Omit service name/container from each log line." 21
    msg_col "help | -h"         "Show the inbuilt Docker help message (not this one)." 21
    msg_blank
    help_menu_backopt || msg_line
}
print_help_env() {
    msg_blank
    msg_header ${YELLOW} "$app_name Environment Handler Help Menu"
    msg_blank
    msg_usage "$script_name env [command] [KEY] [VALUE]"
    msg_blank
    msg_info "The $app_name Environment Handler (E.H.) manages the environment variables in the $env_file file. It will automatically replace the SearXNG secret key if it is not 64 digit hexadecimal."
    msg_blank
    msg_info "As of $app_name version v3.0.0, you can either use the E.H., or edit the $env_file file directly (prohibited in prior versions)."
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -env, environment, --environment"
    msg_blank
    msg_header ${BLUE} "Commands"
    msg_col "(no argument)"    "Show the E.H. menu."
    msg_col "list"             "Show a list of $env_file variables and view options to manage them."
    msg_col "add"              "Add or modify specific variables directly."
    msg_col "rm"               "Remove a specific variable from the environment."
    msg_col "rotate"           "Automatically rotate the SearXNG secret key."
    msg_blank
    msg_warn "Note that the E.H. list cannot show the SearXNG secret key line. If $app_name starts without error, the secret key does exist and is sufficiently random. You can see the key in the $env_file file."
    msg_blank
    msg_header ${GREEN} "Add"
    msg_normal "${GREEN}[USAGE]${NC} $script_name env add [KEY] [VALUE]"
    msg_blank
    msg_header ${RED} "Remove"
    msg_normal "${RED}[USAGE]${NC} $script_name env rm [KEY]"
    msg_normal "${RED}[ALIASES]${NC} -rm, --remove, remove"
    msg_blank
    msg_header ${YELLOW} "Rotate"
    msg_usage "$script_name env rotate [KEY]"
    msg_normal "${YELLOW}[ALIASES]${NC} rk, -rk, --rotate"
    msg_blank
    msg_info "Use --silent (0) mode to skip validation."
    msg_blank
    msg_header ${BLUE} "Examples"
    msg_col "$script_name env list"      "Show a list of variables and view options to manage them." 28
    msg_col "$script_name env add key var"  "Inserts 'key=var' into the $env_file file." 28
    msg_col "$script_name --silent env -rk"  "Silences validation and all outputs and rotates secret key (for automation)." 28
    msg_blank
    help_menu_backopt || msg_line
}
print_help_dl() {
    msg_blank
    msg_header ${YELLOW} "$app_name Download Help Menu"
    msg_blank
    msg_usage "$script_name download [model tag] [flags]"
    msg_blank
    msg_normal "${BOLD}[WRAPS]${NC}   docker exec ollama ollama run <model tag> [flags]"
    msg_blank
    msg_info "The 'download' command is a wrapper so you don't have to type the long Docker exec command. The command will ask for a model tag if you don't provide one."
    msg_info "Find models to download at https://ollama.com/search."
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -dl, --download"
    msg_blank
    msg_header ${BLUE} "Arguments"
    msg_col "<model name>"      "Name of the Ollama model you want to download/run."
    msg_blank
    msg_header ${BLUE} "Common Flags"
    msg_col "--verbose"         "Show detailed timing and response stats."
    msg_col "--format json"     "Return output in JSON format."
    msg_col "--help"            "Show the full Ollama internal help menu."
    msg_blank
    msg_info "You can pass any number of flags."
    msg_warn "The messaging might be inaccurate depending on the flags used."
    msg_blank
    msg_header ${YELLOW} "Choosing a Model"
    msg_blank
    msg_info "The quality of large language models that you can run is determined by the amount and speed of RAM in your system. Ollama can use VRAM if Docker is configured properly, and it will automatically share load with the CPU and slower system RAM if necessary."
    msg_blank
    msg_info "The way it works is that the entire model is stored in RAM (or VRAM). So the maximum size of the model you can run is determined by how much RAM/VRAM you have. Models that go beyond the limit of your access to VRAM will respond much more slowly than ones that don't."
    msg_blank
    help_menu_backopt || msg_line
}
print_help_setup() {
    msg_blank
    msg_header ${YELLOW} "$app_name Setup Help Menu"
    msg_blank
    msg_usage "$script_name setup"
    msg_blank
    msg_info "Run to change system architecture for hardware acceleration (e.g., you change from CPU only to NVIDIA GPU). This is necessary to maximize the performance of LLMs."
    msg_blank
    msg_warn "To take advantage of hardware acceleration, you must install Docker correctly. Additional dependencies are required."
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} -su, --setup"
    msg_blank
    help_menu_backopt || msg_line
}
print_help_start() {
    msg_blank
    msg_header ${YELLOW} "$app_name Start Help Menu"
    msg_blank
    msg_usage "$script_name up"
    msg_blank
    msg_normal "${BOLD}[WRAPS]${NC}   docker compose up -d --force-recreate"
    msg_blank
    msg_info "This command starts or restarts $app_name, and on first start, it automatically runs the setup command."
    msg_blank
    msg_warn "As of $app_name version $app_version, this command always runs --force-recreate."
    msg_blank
    msg_normal "${GREEN}[ALIASES]${NC} start, -st, --start"
    msg_blank
    help_menu_backopt || msg_line
}

# Start Messages
stmes_first_start() {
    msg_info "First time setup detected (or missing configuration)!"
}

stmes_start_done() {
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
    msg_normal "${YELLOW}Note:${NC}    Change environment variables easily with the environment handler!" 
    msg_col "           -" "Run '$script_name env' to open the E.H. or rotate secret keys! "
    msg_col "           -" "Then run $script_name to restart, and enjoy!"
    msg_col "           -" "'$script_name help [optional command]' to show the help menus!"
    msg_blank
    msg_line
}