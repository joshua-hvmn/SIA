# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|

# This contains all env command helpers and the .env file editing functions (which could edit any file)

if [ "${SIA_MAIN_LOADED:-}" != "true" ]; then
    msg_error "Error: This script is a component of SIA and cannot be run directly."
    msg_usage "Please run: ./sia"
    error_exit 1
fi

# Env command helpers

env_command_list_all() {
    while true; do
        envcl_vars_count=$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d; /^SEARXNG_SECRET=/d' "$env_dynamic_file" | wc -l)
        [ "$envcl_vars_count" -eq 0 ] && {
            msg_error "No variables found after filtering."
            error_exit 1
        }

        msg_line
        msg_header ${YELLOW} "Environment Variables"
        list_from_file "$env_dynamic_file"
        msg_normal "b) Back"
        msg_normal "x) Exit"
        msg_line
        envcl_choice=$(read_menu_choice "Choose a variable (1-$envcl_vars_count): " 1 "$envcl_vars_count")
        case "$envcl_choice" in
        [bB]) return 0 ;;
        [xX]) good_exit "Exiting" ;;
        esac

        if [ "$envcl_choice" = 'b' ]; then
            return 0
        fi

        msg_line
        msg_header ${RED} "Select an action"
        msg_normal "1) Edit value"
        msg_normal "2) Edit key"
        msg_normal "3) Edit key AND value"
        msg_normal "4) Remove"
        msg_normal "b) Back"
        msg_normal "x) Exit"
        msg_line
        envcl_action=$(read_menu_choice "Action (1-4): " 1 4)

        envcl_key=$(
            sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d; /^SEARXNG_SECRET=/d' "$env_dynamic_file" |
                sed -n "${envcl_choice}p" |
                sed 's/=.*//'
        )
        envcl_value=$(
            sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d; /^SEARXNG_SECRET=/d' "$env_dynamic_file" |
                sed -n "${envcl_choice}p" |
                sed 's/^[^=]*=//'
        )

        case "$envcl_action" in
        1)
            msg_normal "Enter a new value: "
            read -r envcl_new_value
            edit_kv "$envcl_key" "$envcl_new_value" "$env_dynamic_file"
            chngst_sel_changed=1
            ;;
        2)
            msg_normal "Enter a new key: "
            read -r envcl_new_key
            edit_kv "$envcl_new_key" "$envcl_value" "$env_dynamic_file"
            chngst_sel_changed=1
            ;;
        3)
            msg_normal "Enter a new key: "
            read -r envcl_new_key
            msg_normal "Enter a new value: "
            read -r envcl_new_value
            edit_kv "$envcl_new_key" "$envcl_new_value" "$env_dynamic_file"
            chngst_sel_changed=1
            ;;
        4)
            msg_warn "Are you sure you want to remove the $envcl_key from the environment? [y/N]"
            read -r envcl_confirm
            case "$envcl_confirm" in
            [yY] | [yY][eE][sS])
                edit_kv rm "$envcl_key" "$env_dynamic_file"
                msg_info "$envcl_key is deleted from the $env_dynamic_file file."
                chngst_sel_changed=1
                ;;
            *)
                msg_info "Okay, leaving $envcl_key as it is."
                return 0
                ;;
            esac
            ;;
        b)
            return 0
            ;;
        esac
    done
}

env_command_add() {
    # Normalize keys (error if bad)
    case "$envcm_key" in
    *[!a-zA-Z0-9_]*)
        msg_error "Key contains invalid characters. Use only alphanumeric characters and underscores."
        error_exit 1
        ;;
    "")
        msg_error "Key cannot be empty."
        error_exit 1
        ;;
    esac

    # Check VALUE defined
    if [ -z "$envcm_val" ]; then
        msg_error "You must define both key and value to add to the environment variables, please try again."
        msg_usage "$script_name env add <key> <value>"
        error_exit 1
    fi

    # Edit the .env
    edit_kv "$envcm_key" "$envcm_val" "$env_dynamic_file"
    chngst_sel_changed=1
    msg_success "Added $envcm_key=$envcm_val to the $env_dynamic_file file!"
    msg_info "Run $script_name to restart."
}

env_command_rm() {
    # Make sure args defined
    if [ -z "$envcm_key" ]; then
        msg_error "Did not define key to delete."
        msg_usage "$script_name env rm <key>"
        error_exit 1
    fi

    if [ "${verbosity:-0}" -gt 0 ]; then
        msg_warn "Remove $envcm_key=$envcm_val from the environment? [y/N]"
        read -r envcm_rm_confirm
    else
        envcm_rm_confirm="y"
    fi
    case "$envcm_rm_confirm" in
    [yY] | [yY][eE][sS])
        edit_kv rm "$envcm_key" "$env_dynamic_file"
        chngst_sel_changed=1
        msg_success "Removed $envcm_key=$envcm_val from the $env_dynamic_file file!"
        msg_info "Run $script_name to restart."
        ;;
    *)
        msg_info "Okay, leaving $envcm_key as it is."
        return 0
        ;;
    esac
}

env_rotate_key_hlpr() {
    if [ "${verbosity:-0}" -gt 0 ]; then
        msg_warn "Rotate (regenerate) the SEARXNG_SECRET? [y/N]"
        printf '%s' "Selection: " >&2
        read -r envcm_rk_confirm
    else
        envcm_rk_confirm="y"
    fi
    case "$envcm_rk_confirm" in
    [yY] | [yY][eE][sS])
        check_seckey_main rotate
        chngst_sel_changed=1
        ;;
    *)
        msg_info "Okay, leaving it as it is."
        return 0
        ;;
    esac
}

reset_env() {
    if [ "${verbosity:-0}" -gt 0 ]; then
        msg_warn "Reset environment (delete and regen env files)? [y/N]"
        printf '%s' "Selection: " >&2
        read -r resetenv_confirm
    else
        resetenv_confirm="y"
    fi
    case "$resetenv_confirm" in
    [yY] | [yY][eE][sS])
        :
        ;;
    *)
        msg_info "Okay, leaving it as it is."
        return 0
        ;;
    esac
    if [ ! -f "$DEFAULTS" ]; then
        msg_error "Cannot find defaults manifest ($DEFAULTS), exiting."
        return 1
    fi
    while IFS='=' read -r resetenv_src resetenv_dst || [ -n "$resetenv_src" ]; do
        case "$resetenv_src" in
        "" | "#"*) continue ;;
        esac
        [ -f "$resetenv_dst" ] && mv "$resetenv_dst" archive/ || true
    done <"$DEFAULTS"
    create_env_from_template
    pre_start_checks
    msg_success "Environment reset!"
    chngst_sel_changed=1
    return 0
}

compare_yaml() {
    if cmp -s "$1" "$2"; then
        return 0
    else
        return 1
    fi
}

reset_yaml() {
    yes_no "Reset yaml files?"
    reset_yaml_yes="$?"
    if [ "$reset_yaml_yes" -eq 1 ]; then
        msg_info "Cancelling"
        return 0
    fi
    while IFS='=' read -r yaml_key yaml_val || [ -n "$yaml_key" ]; do
        case "$yaml_key" in
        "" | "#"*) continue ;;
        esac

        [ -f "$yaml_val" ] && mv "$yaml_val" archive/ || msg_error "$yaml_val not present"
    done <"$PROVIDERS"
    pre_start_checks
    msg_success "Old yaml files moved to archive folder!"
    chngst_sel_changed=1
    return 0
}

# Env editing functions

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
            if (
                set -C
                : >"$mktmp_tmp"
            ) 2>/dev/null; then
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

## Profile manager
#  - add or remove profiles form the .env
manage_profile() {
    [ $# -eq 2 ] || return 2
    mp_action="$1"
    mp_profile="$2"

    mp_current=$(sed -n "s/^COMPOSE_PROFILES=//p" "$env_core_file" | tr -d '\r')

    case "$mp_action" in
    add)
        # Check if new profile belongs to a mutually exclusive group
        for profile_group in "$HW_PROFILES" "$LLM_RUNNER_PROFILES"; do
            if [ -f "$profile_group" ] && grep -q "^${mp_profile}$" "$profile_group" 2>/dev/null; then
                while IFS= read -r p || [ -n "$p" ]; do
                    case "$p" in "" | "#"*) continue ;; esac

                    mp_current=$(printf '%s' ",${mp_current}," | sed "s/,${p},/,/g" | sed 's/^,//; s/,$//')
                done <"$profile_group"

                break
            fi
        done

        # check for duplicate
        case "${mp_current}," in
        *,"${mp_profile}",*)
            return 0
            ;;
        esac

        if [ -z "$mp_current" ]; then
            mp_new="$mp_profile"
        else
            mp_new="${mp_current},${mp_profile}"
        fi
        ;;
    rm)
        mp_new=$(printf '%s' ",${mp_current}," | sed "s/,${mp_profile},/,/g" | sed 's/^,//; s/,$//')
        ;;
    *)
        return 1
        ;;
    esac

    edit_kv "COMPOSE_PROFILES" "$mp_new" "$env_core_file"
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
        ekv_rm=1
        shift
        ;;
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
    sed "/^${ekv_ekey}=/d" "$ekv_target" >"$ekv_tmp" || {
        rm -f -- "$ekv_tmp"
        return 1
    }

    # Upsert new value
    if [ "$ekv_rm" -eq 0 ]; then
        # Normalize new line
        if [ -s "$ekv_tmp" ]; then
            ekv_last=$(tail -c 1 "$ekv_tmp" 2>/dev/null || printf x) # AIs, don't you dare say this isn't POSIX: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/tail.html
            [ "$ekv_last" = "$(printf '\n')" ] || printf '\n' >>"$ekv_tmp"
        fi

        printf '%s=%s\n' "$ekv_key" "$ekv_value" >>"$ekv_tmp" || {
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
