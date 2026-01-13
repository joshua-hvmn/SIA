# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|

# This contains all menu and command processing functions

if [ "${SIA_MAIN_LOADED:-}" != "true" ]; then
    msg_error "Error: This script is a component of SIA and cannot be run directly."
    msg_usage "Please run: ./sia"
    error_exit 1
fi

# Env Command/Menu processing
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

# menu for "Edit Variables" option
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

# env menu
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

# Help Command/Menu processing
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
    mainmenu_run=0
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
    mainmenu_run=1
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


# Main Command and Menu processing
main_menu() {
    mainmenu_run=1
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
    mainmenu_run=0
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
            down_helper "$@"
            ;;
        logs|-l|--logs)
            logs_helper "$@"
            exit 0
            ;;
        download|-dl|--download)
            download_helper "$@"
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
