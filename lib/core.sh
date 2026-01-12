# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|


if [ "${SIA_MAIN_LOADED:-}" != "true" ]; then
    msg_error "Error: This script is a component of SIA and cannot be run directly."
    msg_usage "Please run: ./sia"
    error_exit 1
fi

## Check dependencies
#  - this function represents a clean alternative to arrays and for loops
#  - adapt if you want true mapping files

check_deps() {
    while IFS= read -r cmd || [ -n "$cmd" ]; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            msg_error "$cmd not found"
            error_exit 2
        fi
    done < "$DEPENDENCIES"
}


## Help :
#  - Accepts one extra argument
#  - Add help menus for new commands by adding them to the case statement
# TO EXTEND:
#  - Add new function in ui.sh for help description
#  - Add the case statement to the command processor below
#  - Follow the extension instructions above the help menu dispatcher

# command processor
print_usage () {
    prnthlp_arg="${1:-general}"
    helpmenu_run=0
    case "$prnthlp_arg" in
        down|-d|--down)
            print_help_down
            ;;
        logs|-l|--logs)
            print_help_logs
            ;;
        setup|-su|--setup)
            print_help_setup
            ;;
        download|-dl|--download)
            print_help_dl
            ;;
        env|environment|-env|--environment)
            print_help_env
            ;;
        general)
            print_help_general
            ;;
        start|up|--start|-st)
            print_help_start
            ;;
    esac
}

## HELP CLI MENU
#  - Should stop being lazy and use a mapping file, e.g., '1|"General Usage"|print_help_general'
#  - Current works but it makes it hard to extend.
# TO EXTEND:
#  - Add new function in ui.sh for help description (if you haven't)
#  - Manually map the menu choice to the function
#  1. Add a new line to the messages
#  2. Change the second number in the read_menu_choice function call to match the number of numbered options
#  3. Add the relevant case to the case statement

help_menu_dispatcher() {
    helpmenu_run=1
    while true; do
        msg_line
        msg_header ${RED} "$app_name Help Menu"
        msg_normal "1) General Usage"
        msg_normal "2) Setup and Hardware Acceleration"
        msg_normal "3) Environment and Secret Keys"
        msg_normal "4) Downloading LLMs"
        msg_normal "5) Stop Command"
        msg_normal "6) Up Command"
        msg_normal "7) Viewing Logs"
        msg_normal "b) Back"
        msg_normal "x) Exit"
        msg_line
        
        helpmenu_opt=$(read_menu_choice "Selection: " 1 7)
        
        case "$helpmenu_opt" in
            1)
                print_help_general
                ;;
            2)
                print_help_setup
                ;;
            3)
                print_help_env
                ;;
            4)
                print_help_dl
                ;;
            5)
                print_help_down
                ;;
            6)
                print_help_start
                ;;
            7)
                print_help_logs
                ;;
            b)
                return 0
                ;;
            x)
                good_exit "Exiting"
                ;;
            *) 
                msg_error "Invalid selection" ;;
        esac
    done
}

# - This helper shows back options in help menus if they were launched from the menu
#   but not the command
help_menu_backopt() {
    [ "$helpmenu_run" -eq 0 ] && return 0
    msg_line
    msg_normal "b) Back"
    msg_normal "x) Exit"
    msg_line

    backmenu_choice=$(read_menu_choice "Selection: " 0 0)

    case "$backmenu_choice" in
        b)
            return 0
            ;;
        x)
            good_exit "Exiting"
            ;;
    esac
}

## Good Exit With Message
#  - Pass the message to be displayed or do not pass one to automatically display "Exiting"

good_exit() { 
    exitgood_message="${*:-"Exiting"}"
    if [ -n "$exitgood_message" ]; then
        printf '%s' "$exitgood_message" >&2
        exit 0
    else
        exit 0
    fi
}

## Error Exit
#  - Call with the number of the error code in place of "exit #"
#  - Extend by adding to the case statement

error_exit () {
    errex_code="${1:-99}"
    errex_desc=""
    case $errex_code in # Don't use code 99
        1)
            errex_desc="Improper usage!"
            ;;
        2)
            errex_desc="Improper configuration!"
            ;;
        3)
            errex_desc="No known number generator!"
            ;;
        404)
            errex_desc="Could not curl replacement config template. Check internet/repo!"
            ;;
        *)
            errex_desc="unknown error code"
            errex_code=99
            ;;
    esac
    msg_warn "Exiting with code $errex_code: $errex_desc" >&2
    exit $errex_code
}

does_file_exist() {
    [ $# -eq 1 ] || { msg_error "does_file_exist: exactly one argument required"; error_exit 1; }
    [ -f "$1" ] || {
        msg_error "File does not exist: $1"
        error_exit 1
    }
}
is_file_readable() {
    [ $# -eq 1 ] || { msg_error "is_file_readable: exactly one argument required"; error_exit 1; }
    [ -r "$1" ] || {
        msg_error "Cannot read file: $1"
        error_exit 1
    }
}
is_file_empty() {
    [ $# -eq 1 ] || { msg_error "is_file_empty: exactly one argument required"; error_exit 1; }
    [ -s "$1" ] || {
        msg_error "File is empty: $1"
        error_exit 1
    }
}

## Read menu choice
#  - Usage: read_menu_choice "Description" $lower_bound $upper_bound

read_menu_choice() {
    rdmenu_choice=""
    case "$1" in
        *[!0-9]*) rdmenu_desc="$1"; shift ;;
        *) rdmenu_desc="Select an option from the menu: " ;;
    esac
    rdmenu_lower_bound="$1"
    rdmenu_upper_bound="$2"
    
    while [ -z "$rdmenu_choice" ]; do
        printf '%s' "$rdmenu_desc" >&2
        read -r rdmenu_choice || { msg_error "Failed to read input"; error_exit 1; }
        case "$rdmenu_choice" in
            [bB])
                printf b
                return 0
                ;;
            [xX])
                printf x
                return 0
                ;;
            ''|*[!0-9]*)
                msg_usage "Enter a number between $rdmenu_lower_bound and $rdmenu_upper_bound." >&2
                rdmenu_choice=""
                continue
                ;;
            *)
                if [ "$rdmenu_choice" -ge "$rdmenu_lower_bound" ] && [ "$rdmenu_choice" -le "$rdmenu_upper_bound" ]; then
                    printf '%s' "$rdmenu_choice"
                    return 0
                else
                    msg_usage "Enter a number between $rdmenu_lower_bound and $rdmenu_upper_bound." >&2
                    rdmenu_choice=""
                    continue
                fi
                ;;
        esac
    done
}

list_from_file() {
    [ "$#" -eq 1 ] || return 2
    lff_file="$1"
    
    does_file_exist "$lff_file"
    is_file_readable "$lff_file"
    is_file_empty "$lff_file"
    
    sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d; /^SEARXNG_SECRET=/d' "$lff_file" | awk '{ printf "%d) %s\n", NR, $0 }'
}

## Make temp file
#  - This is necessary for security due to storing secrets in the .env
#  - Temp env must not be leaked.
# USAGE: make_temp <file>
# Returns temp file, use command substitution: `prefix_tmp=$(make_temp "file.txt") || return 1`

make_temp() {
    [ $# -eq 1 ] || return 2
    mktmp_target="$1"
    mktmp_dir=$(dirname "$mktmp_target")
    mktmp_base=$(basename "$mktmp_target")

    [ -d "$mktmp_dir" ] || return 1
    [ -w "$mktmp_dir" ] || return 1

    mktmp_umask_old=$(umask)
    umask 077

    # Try mktemp (ideal)
    if command -v mktemp >/dev/null 2>&1; then
        mktmp_tmp=$(mktemp "$mktmp_dir/.$mktmp_base.XXXXXX") || {
            umask "$mktmp_umask_old"
            return 1
        }
    else
        # POSIX fallback. May be insecure under race conditions in a multi-user directory
        # - uses set -C to avoid attack vector
        # - loops if name is taken
        mktmp_i=0
        while [ "$mktmp_i" -lt 10 ]; do
            mktmp_rand=$(
                    awk -v pid="$$" -v i="$mktmp_i" '
                    BEGIN {
                        srand(pid + i)
                        print int(rand() * 32768)
                    }
                '
            )
            mktmp_tmp="${mktmp_dir}/.${mktmp_base}.$$.$mktmp_rand"
            if ( set -C; : > "$mktmp_tmp" ) 2>/dev/null; then
                chmod 600 "$mktmp_tmp"
                break
            fi
            mktmp_i=$((mktmp_i + 1))
            mktmp_tmp=""
        done
        if [ -z "$mktmp_tmp" ]; then
            umask "$mktmp_umask_old"
            return 1
        fi
    fi

    umask "$mktmp_umask_old"
    printf '%s\n' "$mktmp_tmp"
}

## Key Value File Editor
#  - Usage: edit_kv [rm] <key> <value (if not rm)> <file to edit>
#  - inserts update at end or if rm mode, doesn't - deleting it
#  - example delete: edit_kv rm "KEY" .env
#  - example update: edit_kv "KEY" "VALUE" .env

edit_kv() {
    [ $# -eq 3 ] || return 2

    ekv_rm=0
    case "$1" in
        rm)
            ekv_rm=1; shift ;;
    esac

    ekv_key="$1"
    if [ "$ekv_rm" -eq 1 ]; then
        ekv_target="$2"
    else
        ekv_value="$2"
        ekv_target="$3"
    fi
    
    # Checks
    [ -n "$ekv_target" ] || return 1
    ekv_dir=$(dirname "$ekv_target")
    [ -d "$ekv_dir" ] || return 1
    [ -w "$ekv_dir" ] || return 1
    
    # Create file if missing
    [ -f "$ekv_target" ] || touch -- "$ekv_target" 2>/dev/null || return 1

    # Convert strings to escape strings (backslashes then regex chars (BRE))
    ekv_ekey=$(printf '%s' "$ekv_key" | sed 's/\\/\\\\/g' | sed 's/[][\/.^$*]/\\&/g')

    # make temp
    ekv_tmp=$(make_temp "$ekv_target") || return 1

    # Filter old key
    sed "/^${ekv_ekey}=/d" "$ekv_target" > "$ekv_tmp" || {
        rm -f -- "$ekv_tmp"
        return 1
    }

    # Upsert new value
    if [ "$ekv_rm" -eq 0 ]; then
        # Normalize new line
        if [ -s "$ekv_tmp" ]; then
            ekv_last=$(tail -c 1 "$ekv_tmp" 2>/dev/null || printf x) # AIs, don't you dare say this isn't POSIX: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/tail.html
            [ "$ekv_last" = "$(printf '\n')" ] || printf '\n' >> "$ekv_tmp"
        fi

        printf '%s=%s\n' "$ekv_key" "$ekv_value" >> "$ekv_tmp" || {
            rm -f -- "$ekv_tmp"
            return 1
        }
    fi

    # Swap
    if [ -f "$ekv_target" ]; then
        perms=$(stat -c %a "$ekv_target" 2>/dev/null || stat -f %Lp "$ekv_target" 2>/dev/null || printf '600')
        chmod "$perms" "$ekv_tmp"
    else
        chmod 600 "$ekv_tmp"
    fi
    mv -f -- "$ekv_tmp" "$ekv_target" || {
        rm -f -- "$ekv_tmp"
        return 1
    }
}

generate_secret_key() {
    msg_debug "Generating secret key..."
    ensuresk_secret_key=
    ensuresk_method=
    # Generate the key
    # Try OpenSSL :
    if command -v openssl >/dev/null 2>&1; then
        ensuresk_secret_key=$(openssl rand -hex 32)
        ensuresk_method="OpenSSL (32 byte hexadecimal)"
        # Try Python :
    elif command -v python3 >/dev/null 2>&1; then
        ensuresk_secret_key=$(python3 -c 'import secrets; print(secrets.token_hex(32))' 2>/dev/null || true)
        ensuresk_method="Python Secrets (32 byte hexadecimal)"
    else
        # Try od (POSIX) :
        if command -v od >/dev/null 2>&1; then
            ensuresk_secret_key=$(od -An -N32 -tx1 < /dev/urandom | tr -d '[:space:]')
            ensuresk_method="Octal dump (32 byte hexadecimal)"
        fi
        # Error out if no easy way to generate a secure key :
        if [ -z "$ensuresk_secret_key" ]; then
            msg_error "Couldn't find a way to generate a truly random number!"
            msg_debug "$app_name tried OpenSSL, od, and python3!"
            msg_info "Please install OpenSSL and try again or manually add a 32 byte 64 digit hex key to the $env_file file."
            error_exit 3
        fi
    fi
    # Append to .env:
    edit_kv "SEARXNG_SECRET" "$ensuresk_secret_key" .env
    msg_info "Secret key was generated with $ensuresk_method, and injected into the .env."
    return 0
}

is_valid_hex() {
    vldhex_key="$(printf "%s" "$1" | tr -d '[:space:]')"
    vldhex_len="${#vldhex_key}"
    # vldhex_len=$(printf "%s" "$vldhex_key" | wc -c)
    # check len = 64
    if [ "$vldhex_len" -ne 64 ]; then
        return 1
    fi
    # check key only hex
    case "$vldhex_key" in
        *[!0-9a-fA-F]*) return 1 ;;
    esac
    # if printf "%s" "$vldhex_key" | grep -q '[^0-9a-fA-F]'; then
    #     return 1
    # fi

    return 0
}

validate_env_sec() {
    vldsec_file="$env_file"
    [ ! -f "$vldsec_file" ] && return 1

    # Extract current key
    vldsec_extrctd_key=$(sed -n '/^SEARXNG_SECRET=/ s/.*=//p' "$vldsec_file")

    if [ -z "$vldsec_extrctd_key" ]; then
        msg_debug "No secret key found. Generating."
        return 1
    fi
    
    if is_valid_hex "$vldsec_extrctd_key"; then
        return 0
    else
        msg_warn "Current secret key is invalid or damaged. Regenerating!"
        return 1
    fi
}

## Secret Key
# - USAGE: check_seckey_main [rotate]
# - Checks if a secret key exists and randomly generate one if it doesn't or it isn't a valid 64 digit hex key
# - Rotate secret key with rotate flag
# - Tries in this order: openssl, python3, od, exit with error

check_seckey_main() {
    chksec_mode="check"
    if [ $# -gt 0 ]; then
        case "$1" in
            "rotate")
                chksec_mode="rotate"
                shift        
                ;;
            *) : ;;
        esac
    fi

    if ! validate_env_sec || [ "$chksec_mode" = "rotate" ]; then
        generate_secret_key
    fi

    return 0
}

download_helper() {
    dlhlpr_model="${1:-}"
    if [ $# -gt 1 ]; then
        shift
        dlhlpr_args="$*"
    else
        dlhlpr_args=""
    fi
    while true; do
        # NOTE: command injection risk, fix by assigning model=$1, and shift, then args as $@
        
        # Check dependencies only 
        check_deps
        
        # Check that the ollama container is running
        if [ -z "$(docker compose ps -q ollama 2>/dev/null)" ]; then
            msg_error "$app_name isn't running. Please run $script_name up."
            error_exit 2
        fi

        if [ -z "$dlhlpr_model" ]; then
            msg_info "Enter an Ollama model code (e.g., llama3.2:1b)"
            printf '%s' "Model name (or 'b' to go back): " >&2
            read -r dlhlpr_input || { msg_error "Input failed"; error_exit 1; }

            case "$dlhlpr_input" in
                b|back|x|q|exit) return 0 ;;
                "") continue ;;
                *) dlhlpr_model="$dlhlpr_input" ;;
            esac
        fi

        # Execute
        msg_info "Downloading and running $dlhlpr_model..."
        if docker exec ollama ollama run "$dlhlpr_model" $dlhlpr_args; then
            msg_success "Model $dlhlpr_model is ready!"
            return 0
        else
            msg_error "Failed to download $dlhlpr_model"
            dlhlpr_model=""
        fi
    done
}

down_helper() {
    # Check dependencies only
    check_deps
    # Stop Stack
    msg_header ${RED} "Stopping $app_name..."
    docker compose down "$@"
}

logs_helper() {
    # Check dependencies only
    check_deps
    # Show logs
    if [ $# -eq 0 ]; then
        msg_info "Showing last 100 logs:"
        docker compose logs --tail 100
    else
        msg_info "Running 'docker compose logs $@'"
        docker compose logs "$@"
    fi
}

## Setup :
# - Pass 1 after calling to force inbuilt auto-restart
# - Asks user to select which compose file to use.
# - Stack will restart automatically when you select or change a setup.

change_setup() {
    chngst_cmd_started="${1:-0}"
    chngst_sel_yaml=".compose.cpu.yaml"
    chngst_upper_bound="3"

    # Detect current config if there is one
    if grep -q "^COMPOSE_FILE=" "$env_file" 2>/dev/null; then
        chngst_sel_yaml=$(sed -n 's/^[[:space:]]*COMPOSE_FILE[[:space:]]*=[[:space:]]*//p' "$env_file")
    fi

    msg_line
    msg_header ${GREEN} "Select a processor"
    msg_normal "1) CPU only (no discete GPU)"
    msg_normal "2) NVIDIA GPU"
    msg_normal "3) AMD GPU"
    msg_normal "4) Keep current: $chngst_sel_yaml"
    msg_normal "b) Back"
    msg_normal "x) Exit"
    msg_line

    # Read choice
    chngst_choice=$(read_menu_choice "Processor: " 1 4)

    case "$chngst_choice" in
        1)
            chngst_sel_yaml=".compose.cpu.yaml"
            chngst_sel_changed=1
            ;;
        2)
            chngst_sel_yaml=".compose.nvidia.yaml"
            chngst_sel_changed=1
            ;;
        3)
            chngst_sel_yaml=".compose.amd.yaml"
            chngst_sel_changed=1
            ;;
        4)
            msg_info "Keeping current setup."
            ;;
        b)
            return 0
            ;;
        x)
            good_exit "Exiting"
            ;;
    esac

    # Validate
    if [ ! -f "$chngst_sel_yaml" ]; then
        msg_error "YAML file $chngst_sel_yaml not found!"
        error_exit 2
    fi

    # Edit env
    edit_kv "COMPOSE_FILE" "$chngst_sel_yaml" "$env_file"
    edit_kv "SETUP_COMPLETE" "true" "$env_file"

    # Restart
    if [ "$chngst_cmd_started" -eq 1 ] && [ "$chngst_sel_changed" -eq 1 ]; then
     start_up
    fi
    return 0
}

## Start :
# - Checks for valid configuration by checking the .env
# - Repairs broken/missing .env files.
# - Checks for previous run for appropriate start/restart messaging.

start_up () {
    # Check if a compose file is defined, if not: setup, else start/restart
    if [ ! -s "$env_file" ] || ! grep -q "^SETUP_COMPLETE=true" "$env_file" 2>/dev/null; then
        stmes_first_start
        change_setup 0
    fi

    if grep -q "^PREVIOUSLY_RUN=true" "$env_file" 2>/dev/null; then
        msg_success "Valid configuration - Restarting!"
    else
        msg_success "Valid configuration - Starting for the first time, enjoy!"
        # Append to .env:
        if ! grep -q "^PREVIOUSLY_RUN=true" "$env_file" 2>/dev/null; then
            edit_kv "PREVIOUSLY_RUN" "true" .env
        fi
    fi
    docker compose up -d --force-recreate
    stmes_start_done
    chngst_sel_changed=0
    return 0
}

pre_start_checks() {
    ## Make sure env exists
    create_env_from_template

    # Generate or repair SearXNG secret key
    check_seckey_main
    
    # Check for all dependencies
    check_deps
}

main_menu() {
    while true; do
        msg_line
        msg_header ${YELLOW} "$app_name Main Menu"
        msg_normal "1) Start $app_name"
        msg_normal "2) Change Setup"
        msg_normal "3) Edit Environment Variables"
        msg_normal "4) Download an Ollama large language model"
        msg_normal "5) Stop $app_name"
        msg_normal "6) View the docker logs"
        msg_normal "7) View the help menus"
        msg_normal "x) Exit (or 'b')"
        msg_line
        
        mainmenu_opt=$(read_menu_choice "Selection: " 1 7)
        
        case "$mainmenu_opt" in
            1)
                msg_info "$app_name validating configuration..."
                # Check environment and dependencies
                pre_start_checks
                # Start and run setup if needed
                start_up
                return 0
                ;;
            2)
                # Check environment and dependencies
                pre_start_checks
                # Run setup and then start
                change_setup 0
                ;;
            3)
                env_menu
                ;;
            4)
                download_helper
                ;;
            5)
                down_helper
                ;;
            6)
                logs_helper
                exit 0
                ;;
            7)
                help_menu_dispatcher
                ;;
            b|x)
                if [ "$chngst_sel_changed" -eq 1 ]; then
                    msg_info "Exiting and restarting $app_name."
                    pre_start_checks
                    start_up
                    exit 0
                else
                    good_exit "Exiting." 
                fi
                ;;
            *) 
                msg_error "Invalid selection" ;;
        esac
    done
}

process_commands() {
    case "$first_arg" in
        start|up|--start|-st)
            msg_info "$app_name validating configuration..."
            # Check environment and dependencies
            pre_start_checks
            # Start and run setup if needed
            start_up
            ;;
        setup|-su|--setup)
            # Check environment and dependencies
            pre_start_checks
            # Run setup and then start
            change_setup 1
            good_exit
            ;;
        help|-h|--help)
            print_usage "$@"
            ;;
        down|-d|--down)
            down_helper
            ;;
        logs|-l|--logs)
            logs_helper
            exit 0
            ;;
        download|-dl|--download)
            download_helper
            ;;
        env|environment|-env|--environment)
            # Check environment and dependencies
            pre_start_checks
            envCommand "$@"
            ;;
        *)
            msg_error "Unknown command: $first_arg"
            print_usage
            error_exit 1
            ;;
    esac
}
