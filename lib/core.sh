# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|

# This contains universal helpers and the main command helpers that aren't big
# enough for their own files. Some helpers are used across other functions.
# For example, edit_kv() lives in env_logic.sh, but it is called in security.sh

if [ "${SIA_MAIN_LOADED:-}" != "true" ]; then
    msg_error "Error: This script is a component of SIA and cannot be run directly."
    msg_usage "Please run: ./sia"
    error_exit 1
fi

## [Y/n]
#  - Move the '' to the no section to change to default no.
yes_no() {
    yes_no_msg="${1:-''}"
    while true; do
        msg_normal "$yes_no_msg [Y/n]"
        read -r response

        case "$response" in
        n | N | [nN]o | [nN]O | [nN][oO])
            return 1
            ;;
        '' | [yY] | [yY]es | [yY][eE][sS])
            return 0
            ;;
        *)
            echo "Invalid response"
            ;;
        esac
    done
}

# - This helper shows back options in help menus if they were launched from the menu
#   but not the command
help_menu_backopt() {
    [ "$mainmenu_run" -eq 0 ] && return 0
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
back_options() { # for if the menu already has input processing, like setup
    [ "$mainmenu_run" -eq 0 ] && return 0
    msg_line
    msg_normal "b) Back"
}

## Good Exit With Message
#  - Pass the message to be displayed or do not pass one to automatically display "Exiting"

good_exit() {
    exitgood_message="${*:-"Exiting"}"
    if [ -n "$exitgood_message" ]; then
        if [ "$chngst_sel_changed" -eq 1 ]; then
            msg_info "Exiting and restarting $app_name."
            pre_start_checks
            start_up
            exit 0
        else
            printf '%s' "$exitgood_message" >&2
            exit 0
        fi
    else
        exit 0
    fi
}

## Error Exit
#  - Call with the number of the error code in place of "exit #"
#  - Extend by adding to the case statement

error_exit() {
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
    [ $# -eq 1 ] || {
        msg_error "does_file_exist: exactly one argument required"
        error_exit 1
    }
    [ -f "$1" ] || {
        msg_error "File does not exist: $1"
        error_exit 1
    }
}
is_file_readable() {
    [ $# -eq 1 ] || {
        msg_error "is_file_readable: exactly one argument required"
        error_exit 1
    }
    [ -r "$1" ] || {
        msg_error "Cannot read file: $1"
        error_exit 1
    }
}
is_file_empty() {
    [ $# -eq 1 ] || {
        msg_error "is_file_empty: exactly one argument required"
        error_exit 1
    }
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
    *[!0-9]*)
        rdmenu_desc="$1"
        shift
        ;;
    *) rdmenu_desc="Select an option from the menu: " ;;
    esac
    rdmenu_lower_bound="$1"
    rdmenu_upper_bound="$2"

    while [ -z "$rdmenu_choice" ]; do
        printf '%s' "$rdmenu_desc" >&2
        read -r rdmenu_choice || {
            msg_error "Failed to read input"
            error_exit 1
        }
        case "$rdmenu_choice" in
        [bB])
            printf b
            return 0
            ;;
        [xX])
            printf x
            return 0
            ;;
        '' | *[!0-9]*)
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

# MAIN HELPERS
# - not big enough for their own scripts

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
# - Multi-step setup wizard: Services -> Hardware -> LLM Runner.
# - Stack will restart automatically when you select or change a setup.

change_setup() {
    chngst_cmd_started="${1:-0}"
    chngst_sel_changed=0

    # Check state
    cur_srv="${SIA_SERVICES:-None}"
    cur_hw="${SIA_HW:-None}"
    cur_run="${SIA_RUNNER:-None}"

    # 1. Services
    msg_line
    msg_header ${GREEN} "Step 1: Select Active Services"
    msg_normal "1) Full SIA stack (AI and SearXNG)"
    msg_normal "2) SearXNG only (Search Engine)"
    msg_normal "3) AI only (WebUI, LLM Runner)"
    msg_normal "4) Keep current [${cur_srv}]"
    back_options
    msg_normal ""
    msg_line

    srv_choice=$(read_menu_choice "Services: " 1 4)
    case "$srv_choice" in
    1) new_srv="full" ;;
    2) new_srv="searxng" ;;
    3) new_srv="ai" ;;
    4)
        new_srv="${cur_srv}"
        [ "$new_srv" = "None" ] && new_srv="full"
        ;;
    b) return 0 ;;
    x) good_exit "Exiting" ;;
    esac
    [ "$new_srv" != "$cur_srv" ] && chngst_sel_changed=1

    new_hw="$cur_hw"
    new_run="$cur_run"

    if [ "$new_srv" = "ai" ] || [ "$new_srv" = full ]; then

        # 2. Select hardware profile
        msg_line
        msg_header ${GREEN} "Step 2: Select Hardware Optimization"
        msg_normal "1) CPU only (no discete GPU)"
        msg_normal "2) NVIDIA GPU (CUDA)"
        msg_normal "3) AMD GPU (ROCm)"
        msg_normal "4) Keep current: [${cur_hw}]"
        back_options
        msg_normal "x) Exit"
        msg_line

        hw_choice=$(read_menu_choice "Hardware: " 1 4)

        case "$hw_choice" in
        1) new_hw="cpu" ;;
        2) new_hw="nvidia" ;;
        3) new_hw="amd" ;;
        4) [ "$new_hw" = "None" ] && new_hw="cpu" ;;
        b) return 0 ;;
        x) good_exit "Exiting" ;;
        esac
        [ "$new_hw" != "cur_hw" ] && chngst_sel_changed=1

        # 3. LLM Runner
        msg_line
        msg_header ${GREEN} "Step 3: Select LLM Runner"
        msg_normal "1) Ollama"
        msg_normal "2) llama.cpp"
        msg_normal "3) Keep current [${cur_run}]"
        back_options
        msg_normal "x) Exit"
        msg_line

        run_choice=$(read_menu_choice "Runner: " 1 3)
        case "$run_choice" in
        1) new_run="ollama" ;;
        2) new_run="llammacpp" ;;
        3) [ "$new_run" = "None" ] && new_run="ollama" ;;
        b) return 0 ;;
        x) good_exit "Exiting" ;;
        esac
        [ "$new_run" != "$cur_run" ] && chngst_sel_changed=1
    fi

    # Finish
    if [ "$chngst_sel_changed" -eq 1 ]; then
        # i. Save state
        edit_kv "SIA_SERVICES" "$new_srv" "$env_file"
        edit_kv "SIA_HW" "$new_hw" "$env_file"
        edit_kv "SIA_RUNNER" "$new_run" "$env_file"

        # ii. compile DC exec string
        compiled_profiles=""

        if [ "$new_srv" = "searxng" ] || [ "$new_srv" = "full" ]; then
            compiled_profiles="searxng"
        fi

        if [ "$new_srv" = "searxng" ] || [ "$new_srv" = "full" ]; then
            [ -n "$compiled_profiles" ] && compiled_profiles="${compiled_profiles},"
            compiled_profiles="${compiled_profiles}webui-${new_hw},${new_run}-${new_hw}"
        fi

        edit_kv "COMPOSE_PROFILES" "$compiled_profiles" "$env_file"
        edit_kv "SETUP_COMPLETE" "true" "$env_file"
    fi

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

start_up() {
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

    # Check if caddy cert needs to be configured
    if [ "${SIA_NEEDS_CERT_INSTALL:-}" = "true" ]; then
        install_caddy_cert
    else
        stmes_start_done
    fi

    chngst_sel_changed=0
    return 0
}

pre_start_checks() {
    # Check for all dependencies
    check_deps
    check_files
    ## Make sure env exists
    create_env_from_template
    create_yamls_from_templates

    # Generate or repair SearXNG secret key
    check_seckey_main
}
