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

env_command_list_all() {
while true; do
    envcl_vars_count=$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d; /^SEARXNG_SECRET=/d' "$env_file" | wc -l)
    [ "$envcl_vars_count" -eq 0 ] && { msg_error "No variables found after filtering."; error_exit 1; }

    msg_line
    msg_header ${YELLOW} "Environment Variables"
    list_from_file "$env_file"
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
    edit_kv "$envcm_key" "$envcm_val" "$env_file"
    msg_success "Added $envcm_key=$envcm_val to the $env_file file!"
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
        [yY]|[yY][eE][sS])
            check_seckey_main rotate
            ;;
        *)
            msg_info "Okay, leaving it as it is."
            return 0
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
        error_exit 2
    fi
}

reset_env() {
    if [ "${verbosity:-0}" -gt 0 ]; then
        msg_warn "Reset environment (delete and regen $env_file file)? [y/N]"
        printf '%s' "Selection: " >&2
        read -r resetenv_confirm
    else
        resetenv_confirm="y"
    fi
    case "$resetenv_confirm" in
        [yY]|[yY][eE][sS])
            :
            ;;
        *)
            msg_info "Okay, leaving it as it is."
            return 0
            ;;
    esac
    if [ -f "$DEFAULTS" ]; then
        [ -f "$env_file" ] && rm "$env_file"
    else
        msg_error "Cannot find $script_name template, exiting function."
        return 1
    fi
    create_env_from_template
    pre_start_checks
    msg_success "Environment reset!"
    chngst_sel_changed=1
    return 0
}

## .env handler command Parser
#  - USAGE:
#  - ./sia env - view list and choose what to do.
#  - ./sia env add [optional name WITH CAUTION] [key] [value]
#  - ./sia env rotate: to rotate key
#  - ./sia --silent env rotate: rotate key and skip confirmation

envCommand () {
    envcm_cmd="${1:-menu}"
    envcm_key="${2:-}"
    envcm_val="${3:-}"
    case $envcm_cmd in
        menu|-m|--menu)
            env_menu
            ;;
        list|-l|--list)
            # envCommandListEdit envVars
            env_command_list_all
            ;;
        add|-a|--add)
            # Make sure args defined
            env_command_add
            ;;
        rm|-rm|--remove|remove)
            env_command_rm
            ;;
        rk|-rk|--rotate|rotate)
            env_rotate_key_hlpr
            ;;
    esac
}

env_list_menu() {
    while true; do
        msg_line
        msg_header ${RED} "Edit $app_name Environment"
        msg_normal "1) List variables to edit"
        msg_normal "2) Add a variable by name"
        msg_normal "3) Remove a variable by name"
        msg_normal "b) Back"
        msg_normal "x) Exit"
        msg_line
        
        
        envlsmenu_opt=$(read_menu_choice "Selection: " 1 3)
        
        case "$envlsmenu_opt" in
            1)
                env_command_list_all
                ;;
            2)
                msg_normal "Enter a new key: "
                read -r envclmenu_new_key
                msg_normal "Enter a new value: "
                read -r envclmenu_new_value
                envCommand add "$envclmenu_new_key" "$envclmenu_new_value"
                ;;
            3)
                msg_normal "Enter the key you want to remove: "
                read -r envclmenu_rm_key
                envCommand rm "$envclmenu_rm_key"
                ;;
            b)
                return 0
                ;;
            x)
                good_exit "Exiting"
                ;;
            *) 
                msg_error "Invalid selection: $envlsmenu_opt" ;;
        esac
    done
}

env_menu() {
    while true; do
        msg_line
        msg_header ${YELLOW} "$app_name Environment Menu"
        msg_normal "1) Edit Variables"
        msg_normal "2) Rotate SearXNG secret key (security)"
        msg_normal "3) Restore Defaults (Reset)"
        msg_normal "b) Back"
        msg_normal "x) Exit"
        msg_line
        
        
        envmenu_opt=$(read_menu_choice "Selection: " 1 3)
        
        case "$envmenu_opt" in
            1)
                env_list_menu
                ;;
            2)
                env_rotate_key_hlpr
                ;;
            3)
                reset_env
                ;;
            b)
                return 0
                ;;
            x)
                [ "$chngst_sel_changed" -eq 1 ] && pre_start_checks && start_up
                good_exit "Exiting"
                ;;
            *) 
                msg_error "Invalid selection: $envmenu_opt" ;;
        esac
    done
}