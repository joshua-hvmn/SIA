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

env_command_list_all() {
    envcl_vars_count=$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d; /^SEARXNG_SECRET=/d' "$env_file" | wc -l)
    [ "$envcl_vars_count" -eq 0 ] && { msg_error "No variables found after filtering."; errExit 1; }

    msg_header ${YELLOW} "Environment Variables"
    list_from_file "$env_file"
    envcl_choice=$(read_menu_choice "Choose a variable (1-$envcl_vars_count or x to exit): " 1 "$envcl_vars_count")
    if [ "$envcl_choice" = 'x' ]; then
        msg_info "Exiting"
        exit 0
    fi

    msg_header ${YELLOW} "Select an action"
    msg_col "1)" "Edit value"
    msg_col "2)" "Edit key"
    msg_col "3)" "Edit key AND value"
    msg_col "4)" "Remove"
    envcl_action=$(read_menu_choice "Action (1-4 or x to exit): " 1 4)

    if [ "$envcl_action" = 'x' ]; then
        msg_info "Exiting"
        exit 0
    fi

    envcl_key=$(
        sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d; /^SEARXNG_SECRET=/d' "$env_file" |
        sed -n "${envcl_choice}p" |
        sed 's/=.*//'
    )
    envcl_value=$(
        sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d; /^SEARXNG_SECRET=/d' "$env_file" |
        sed -n "${envcl_choice}p" |
        sed 's/^[^=]*=//'
    )

    case "$envcl_action" in
        1)
            msg_normal "Enter a new value: "
            read -r envcl_new_value
            edit_kv "$envcl_key" "$envcl_new_value" "$env_file"
            ;;
        2)
            msg_normal "Enter a new key: "
            read -r envcl_new_key
            edit_kv "$envcl_new_key" "$envcl_value" "$env_file"
            ;;
        3)
            msg_normal "Enter a new key: "
            read -r envcl_new_key
            msg_normal "Enter a new value: "
            read -r envcl_new_value
            edit_kv "$envcl_new_key" "$envcl_new_value" "$env_file"
            ;;
        4)
            msg_warn "Are you sure you want to remove the $envcl_key from the environment? [y/N]"
            read -r envcl_confirm
            case "$envcl_confirm" in
                [yY]|[yY][eE][sS])
                    edit_kv rm "$envcl_key" "$env_file"
                    msg_info "$envcl_key is deleted from the $env_file file."
                    ;;
                *)
                    msg_info "Okay, leaving $envcl_key as it is."
                    return 0
                    ;;
            esac
            ;;
    esac
}

env_command_add() {
    envca_key="${1:-}"
    envca_val="${2:-}"

    # Normalize keys (error if bad)
    case "$envca_key" in
        *[!a-zA-Z0-9_]*)
            msg_error "Key contains invalid characters. Use only alphanumeric characters and underscores."
            errExit 1
            ;;
        "")
            msg_error "Key cannot be empty."
            errExit 1
            ;;
    esac

    # Check VALUE defined
    if [ -z "$envca_val" ]; then
        msg_error "You must define both key and value to add to the environment variables, please try again."
        msg_usage "$script_name env add <key> <value>"
        errExit 1
    fi

    # Edit the .env
    edit_kv "$envca_key" "$envca_val" "$env_file"
    msg_success "Added $envca_key=$envca_val to the $env_file file!"
    msg_info "Run $script_name to restart."
}

## .env handler command Parser
#  - USAGE:
#  - ./sia env - view list and choose what to do.
#  - ./sia env add [optional name WITH CAUTION] [key] [value]
#    - If you define a name, it will edit the values in the array if it exists, 
#    - for example, 'dependencies' or 'fileNames'. Use caution!

envCommand () {
    envcm_cmd="${1:-list}"
    envcm_key="${2:-}"
    envcm_val="${3:-}"
    case $envcm_cmd in
        list|-l|--list)
            # envCommandListEdit envVars
            env_command_list_all
            ;;
        add|-a|--add)
            # Make sure args defined
            if [ -z "$envcm_key" ] || [ -z "$envcm_val" ]; then
                msg_error "Both key and value are required."
                msg_usage "$script_name env add <key> <value>"
                errExit 1
            fi

            # Edit the .env
            edit_kv "$envcm_key" "$envcm_val" "$env_file"
            msg_success "Added $envcm_key=$envcm_val to the $env_file file!"
            msg_info "Run $script_name to restart."
            ;;
        rm|-rm|--remove)
            # Make sure args defined
            if [ -z "$envcm_key" ]; then
                msg_error "Did not define key to delete."
                msg_usage "$script_name env rm <key>"
                errExit 1
            fi
            if [ "${verbosity:-0}" -gt 0 ]; then
                msg_warn "Remove $envcm_key=$envcm_val from the environment? [y/N]"
                read -r envcm_confirm
            else
                envcm_confirm="y"
            fi
            case "$envcm_confirm" in
                [yY]|[yY][eE][sS])
                    edit_kv rm "$envcm_key" "$env_file"
                    msg_success "Removed $envcm_key=$envcm_val from the $env_file file!"
                    msg_info "Run $script_name to restart."
                    ;;
                *)
                    msg_info "Okay, leaving $envcm_key as it is."
                    return 0
                    ;;
            esac
            ;;
    esac
}

create_env_from_template() {
    if [ -f "$DEFAULTS" ]; then
        if [ ! -s "$env_file" ]; then
            cp "$DEFAULTS" "$env_file"
            chmod 600 "$env_file"
        fi
    else
        msg_error "$DEFAULTS not found, cannot restore."
        errExit 2
    fi
}