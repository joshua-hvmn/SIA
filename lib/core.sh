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
    errExit 1
fi

## Help :
#  - Accepts one extra argument
#  - Add help menus for new commands by adding them to the case statement

checkDeps() { # update for new architecture
    while IFS= read -r cmd || [ -n "$cmd" ]; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            msg_error "$cmd not found"
        fi
    done < "$DEPENDENCIES"
}

printUsage () {
    prnthlp_arg="${1:-}"
    case "$arg" in
        down|-d|--down)
            printHelp_down
            ;;
        logs|-l|--logs)
            printHelp_logs
            ;;
        setup|-s|--setup)
            printHelp_setup
            ;;
        download|-dl|--download)
            printHelp_download
            ;;
        env|environment|-env|--environment)
            printHelp_env
            ;;
        *)
            printHelp_general
            ;;
    esac
}

## Good Exit With Message
#  - Pass the message to be displayed or do not pass one to automatically display "Exiting"

exitScriptGoodWithMessage() { 
    exitgood_message="${*:-}"
    if [ -n "$message" ]; then
        printf '%s' "$message" >&2
        exit 0
    else
        exit 0
    fi
}

## Error Exit
#  - Call with the number of the error code in place of "exit #"
#  - Extend by adding to the case statement

errExit () {
    errex_errex_code="${1:-99}"
    errex_errex_desc=""
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
    [ $# -eq 1 ] || { msg_error "does_file_exist: exactly one argument required"; errExit 1; }
    [ -f "$1" ] || {
        msg_error "File does not exist: $1"
        errExit 1
    }
}
is_file_readable() {
    [ $# -eq 1 ] || { msg_error "is_file_readable: exactly one argument required"; errExit 1; }
    [ -r "$1" ] || {
        msg_error "Cannot read file: $1"
        errExit 1
    }
}
is_file_empty() {
    [ $# -eq 1 ] || { msg_error "is_file_empty: exactly one argument required"; errExit 1; }
    [ -s "$1" ] || {
        msg_error "File is empty: $1"
        errExit 1
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
        read -r rdmenu_choice || { msg_error "Failed to read input"; errExit 1; }
        case "$rdmenu_choice" in
            [xX])
                printf 'x'
                return 0
                ;;
            ''|*[!0-9]*)
                msg_usage "Enter a number between $rdmenu_lower_bound and $rdmenu_upper_bound."
                rdmenu_choice=""
                continue
                ;;
            *)
                if [ "$rdmenu_choice" -ge "$rdmenu_lower_bound" ] && [ "$rdmenu_choice" -le "$rdmenu_upper_bound" ]; then
                    printf '%s' "$rdmenu_choice"
                    return 0
                else
                    msg_usage "Enter a number between $rdmenu_lower_bound and $rdmenu_upper_bound."
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

## Secret Key
# - Checks if a secret key exists and randomly generate one if it doesn't
# - Tries in this order: openssl, od, python3, cksum
# - Nested conditional make this annoying to extend, but it shouldn't need to be extended.

ensureSecretKey () {
    # Check if force regenerate
    ensuresk_mode="${1:-no}"
    case "$ensuresk_mode" in
        "update")
            ensuresk_mode="update"
            ;;
        *)
            :
            ;;
    esac

    # Check if key exists and generate one if it doesn't
    touch "$env_file"
    if ! grep -q "^SEARXNG_SECRET=" "$env_file" 2>/dev/null || [ "$ensuresk_mode" = "update" ] ; then
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
                errExit 3
            fi
        fi
        # Append to .env:
        edit_kv "SEARXNG_SECRET" "$ensuresk_secret_key" .env
        msg_info "Secret key was generated with $ensuresk_method, and injected into the .env."
        return 0
    fi
}

## Setup :
# - Pass 1 after calling to prevent inbuilt auto-restart
# - Asks user to select which compose file to use.
# - Checks for or generates secret key with ensureSecretKey
# - Stack will restart automatically when you select or change a setup.

change_setup() {
    chngst_cmd_started="${1:-0}"
    chngst_sel_yaml=".compose.cpu.yaml"
    chngst_upper_bound="3"

    # Detect current config if there is one
    if grep -q "^COMPOSE_FILE=" "$env_file" 2>/dev/null; then
        chngst_sel_yaml=$(sed -n 's/^[[:space:]]*COMPOSE_FILE[[:space:]]*=[[:space:]]*//p' "$env_file")
    fi

    msg_header ${YELLOW} "Select a processor"
    msg_col "1)" "CPU only (no discete GPU)"
    msg_col "2)" "NVIDIA GPU"
    msg_col "3)" "AMD GPU"
    msg_col "4)" "Keep current: $chngst_sel_yaml"

    # Read choice
    chngst_choice=$(read_menu_choice "Processor (1-3 or x to exit): " 1 4)
    
    if [ "$chngst_choice" = 'x' ]; then
        msg_info "Exiting"
        exit 0
    fi

    case "$chngst_choice" in
        1)
            chngst_sel_yaml=".compose.cpu.yaml"
            ;;
        2)
            chngst_sel_yaml=".compose.nvidia.yaml"
            ;;
        3)
            chngst_sel_yaml=".compose.amd.yaml"
            ;;
        4)
            msg_info "Keeping current setup."
            ;;
    esac

    # Validate
    if [ ! -f "$chngst_sel_yaml" ]; then
        msg_error "YAML file $chngst_sel_yaml not found!"
        errExit 2
    fi

    # Edit env
    edit_kv "COMPOSE_FILE" "$chngst_sel_yaml" "$env_file"
    ensureSecretKey
    edit_kv "SETUP_COMPLETE" "true" "$env_file"

    # Restart
    if [ "$chngst_cmd_started" -eq 1 ]; then
     startCheck
    fi
}

## Start :
# - Checks for valid configuration by checking the .env
# - Repairs broken/missing .env files.
# - Checks for previous run for appropriate start/restart messaging.

startCheck () {
    # Check if a compose file is defined, if not: setup, else start/restart
    if [ ! -s "$env_file" ] || ! grep -q "^SETUP_COMPLETE=true" "$env_file" 2>/dev/null; then
        startMes_firstStart
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
    startMes_startDone
    return 0
}
