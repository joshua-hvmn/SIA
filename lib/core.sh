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

## Convert GB to KB
#  - USAGE: convert_gb_to_kb <GB as int or float>
convert_gb_to_kb() {
    cgtk_input_gb="${1:-0}"
    cgtk_output_kb=$(awk "BEGIN {print $cgtk_input_gb * 1048576}")
    printf '%s' "$cgtk_output_kb"
}

## Check input is integer
#  - USAGE:  check_int_is_even <int>
check_int_is_even() {
    ci_int_input="$1"

    case "$ci_int_input" in
    '' | *[!0-9]*)
        msg_debug "Check: Input ['$ci_int_input'] is not an even number."
        return 1
        ;;
    *)
        if [ $((ci_int_input % 2)) -ne 0 ]; then
            msg_debug "Check: Input ['$ci_int_input'] is not an even number."
            return 1
        fi
        msg_debug "Check: Input ['$ci_int_input'] is an even number, continuing."
        return 0
        ;;
    esac
}

## Docker Compose Up wrapper
#  Usage: sia_compose_up [mode] [extra_flags]
sia_compose_up() {
    dcup_cmd_mode="${1:-up}"
    shift || true

    dcup_env_args=""

    # Read env filenames from manifest and build args
    if [ -f "${DEFAULTS:-}" ]; then
        while IFS='=' read -r dcup_src dcup_dst || [ -n "$dcup_src" ]; do
            case "$dcup_src" in
            "" | "#"*) continue ;;
            esac
            if [ -f "$dcup_dst" ]; then
                dcup_env_args="$dcup_env_args --env-file $dcup_dst"
            fi
        done <"$DEFAULTS"
    fi

    # Llama.cpp tune injection
    dcup_llm_runner=$(get_llm_runner)

    case "$dcup_llm_runner" in
    "None" | "")
        return
        ;;
    *)
        case "$dcup_llm_runner" in
        llama-cpp | llamacpp | llama.cpp)
            dcup_active_model="${SIA_LOCAL_MODEL:-}"
            if [ -z "$dcup_active_model" ] && [ -f "$env_core_file" ]; then
                dcup_active_model=$(sed -n 's/^SIA_LOCAL_MODEL=//p' .env.dynamic 2>/dev/null | tr -d '"'\' || true)
            fi

            # if active model look for tune
            if [ -n "$dcup_active_model" ]; then
                dcup_safe_model=$(printf '%s' "$dcup_active_model" | sed 's/\//--/g')
                dcup_tuning_env="share/model-configs/llama-cpp-configs/${dcup_safe_model}.env"

                if [ -f "$dcup_tuning_env" ]; then
                    msg_info "Applying tuning profile: $dcup_tuning_env"
                    dcup_env_args="$dcup_env_args --env-file $dcup_tuning_env"
                fi
            fi
            ;;
        ollama)
            # OpenWebUI handles switching, not sure how to detect the active model
            # and switch tunes on the fly. May not be possible like this.
            msg_debug "Ollama runner active."
            ;;
        *)
            msg_error "Runner '$dcup_llm_runner' not valid. Please run './sia setup'"
            error_exit 2
            ;;
        esac
        ;;
    esac
    if [ "$dcup_cmd_mode" = "down" ]; then
        docker compose $dcup_env_args down --remove-orphans "$@"
    else
        docker compose $dcup_env_args up -d --force-recreate --remove-orphans "$@"
    fi
}

## Get HW Profil
get_llm_runner() {
    # Check if already in the environment, fallback to parsing the .env file, default to ollama
    if [ -n "${SIA_LLM_RUNNER:-}" ]; then
        printf '%s' "$SIA_LLM_RUNNER"
    else
        getllm_runner=$(sed -n 's/^SIA_LLM_RUNNER=//p' "$env_core_file" 2>/dev/null)
        if [ -n "$getllm_runner" ]; then
            printf '%s' "$getllm_runner"
        else
            printf '%s' "error"
        fi
    fi
}
get_hw_profile() {
    if [ -n "${SIA_HW_PROFILE:-}" ]; then
        printf '%s' "$SIA_HW_PROFILE"
    elif [ -n "${SIA_HW:-}" ]; then
        printf '%s' "$SIA_HW"
    else
        # Look for SIA_HW_PROFILE first, fallback to SIA_HW
        gethw_hw=$(sed -n 's/^SIA_HW_PROFILE=//p' "$env_core_file" 2>/dev/null)
        if [ -z "$gethw_hw" ]; then
            gethw_hw=$(sed -n 's/^SIA_HW=//p' "$env_core_file" 2>/dev/null)
        fi

        # Strip carriage returns and spaces
        gethw_hw=$(printf '%s' "$gethw_hw" | tr -d '\r ')

        if [ -n "$gethw_hw" ] && [ "$gethw_hw" != "none" ]; then
            printf '%s' "$gethw_hw"
        else
            printf '%s' "error"
        fi
    fi
}

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
            printf '%s' "b"
            return 0
            ;;
        [xX])
            printf '%s' "x"
            return 0
            ;;
        [cC])
            printf '%s' "c"
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
    # Strip the SIA command verb if it was passed through
    case "${1:-}" in down | -d | --down) shift ;; esac
    # Check dependencies only
    check_deps
    # Stop Stack
    msg_header ${RED} "Stopping $app_name..."
    sia_compose_up "down" "$@"
}

logs_helper() {
    # Strip the SIA command verb if it was passed through
    case "$1" in logs | -l | --logs) shift ;; esac
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

## Start :
# - Checks for valid configuration by checking the .env
# - Repairs broken/missing .env files.
# - Checks for previous run for appropriate start/restart messaging.

start_up() {
    # Strip the SIA command verb if it was passed through
    case "${1:-}" in start | up | --start | -st) shift ;; esac
    # Check if a compose file is defined, if not: setup, else start/restart
    if [ ! -s "$env_core_file" ] || ! grep -q "^SETUP_COMPLETE=true" "$env_core_file" 2>/dev/null; then
        stmes_first_start
        change_setup 0
    fi

    if grep -q "^PREVIOUSLY_RUN=true" "$env_core_file" 2>/dev/null; then
        msg_success "Valid configuration - Restarting!"
    else
        msg_success "Valid configuration - Starting for the first time, enjoy!"
        # Append to .env:
        if ! grep -q "^PREVIOUSLY_RUN=true" "$env_core_file" 2>/dev/null; then
            edit_kv "PREVIOUSLY_RUN" "true" "$env_core_file"
        fi
    fi
    sia_compose_up "up" "$@"

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
