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

# Configuration
OLLAMA_CONTAINER="ollama"

## Core execution wrapper
# Wraps docker exec ollama
ollama_exec() {
    check_deps 2>/dev/null || true

    if [ -z "$(docker inspect --format='{{.State.Running}}' "$OLLAMA_CONTAINER" 2>/dev/null)" ]; then
        msg_error "Ollama container ('$OLLAMA_CONTAINER') isn't running. Please run './sia up' first."
        error_exit 1
    fi

    if [ -t 0 ]; then
        docker exec -it "$OLLAMA_CONTAINER" ollama "$@"
    else
        docker exec -i "$OLLAMA_CONTAINER" ollama "$@"
    fi
}

## Interactive Menu
ollama_menu() {
    while true; do
        msg_line
        msg_header ${BLUE} "Ollama Model Manager"
        msg_normal "1) Run or pull a model (supports standard Ollama names and hf.co/ URLS)"
        msg_normal "2) List installed models"
        msg_normal "3) Remove a model"
        msg_normal "4) Show running models (ps)"
        back_options
        msg_normal "x) Exit"
        msg_line

        olmenu_opt=$(read_menu_choice "Selection: " 1 4)

        case "$olmenu_opt" in
        1)
            msg_normal "Enter model name or HF URL (e.g., llama3.2:1b, hf.co/user/repo): "
            read -r olmenu_model
            if [ -n "$olmenu_model" ]; then
                ollama_exec run "$olmenu_model"
            fi
            ;;
        2)
            msg_blank
            ollama_exec list
            msg_blank
            ;;
        3)
            msg_blank
            ollama_exec list
            msg_blank
            msg_normal "Enter the name of the model to remove: "
            read -r olmenu_rm
            if yes_no "Are you sure you want to delete '$olmenu_rm'?"; then
                ollama_exec rm "$olmenu_rm"
            else
                msg_info "Deletion cancelled."
            fi
            ;;
        4)
            msg_blank
            ollama_exec ps
            msg_blank
            ;;
        b)
            return 0
            ;;
        x)
            good_exit "Exiting"
            ;;
        *)
            msg_error "Invalid selection: $olmenu_opt"
            ;;
        esac
    done
}

## Command Parser
# Usage: ./sia ollama [menu|run|list|rm|ps|pull]

ollama_command_router() {
    olcmd_cmd="${1:-menu}"
    shift 2>/dev/null || true

    case $olcmd_cmd in
    menu | -m | --menu)
        ollama_menu
        ;;
    run | list | rm | ps | pull | stop | cp)
        # Command pass-through
        ollama_exec "$olcmd_cmd" "$@"
        ;;
    *)
        msg_error "Unknown ollama command: $olcmd_cmd"
        msg_usage "$script_name ollama [ menu | run <model> | list | rm <model> | ps ]"
        error_exit 1
        ;;
    esac
}
