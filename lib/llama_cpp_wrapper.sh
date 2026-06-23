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
MODELS_DIR="./models"
LLAMACPP_CONTAINER="sia-llama-cpp"

## Download GGUF Function
download_gguf_model() {
    dlmod_url="$1"
    dlmod_filename="${dlmod_url##*/}"
    dlmod_path="${MODELS_DIR}/${dlmod_filename}"

    if [ -z "$dlmod_url" ]; then
        msg_error "./sia llamacpp download <huggingface_gguf_url>"
        error_exit 1
    fi

    check_deps 2>/dev/null || true
    mkdir -p "$MODELS_DIR"

    # Download
    if [ ! -f "$dlmod_path" ]; then
        msg_info "Downloading $dlmod_filename..."
        if ! curl -L -C - --progress-bar -o "dlmod_path" "$dlmod_url"; then
            msg_error "Download failed for $dlmod_filename."
            [ ! -s "$dlmod_path" ] && rm -f "$dlmod_path"
            error_exit 1
        fi
        msg_success "Download complete: $dlmod_filename"
    else
        msg_info "Model file $dlmod_filename already exist. Skipping download."
    fi
}

## Interactive Menu
llamacpp_menu() {
    while true; do
        msg_line
        msg_header ${BLUE} "llama.cpp Model Manager"
        msg_normal "1) Download a new GGUF model from HuggingFace URL"
        msg_normal "2) List downloaded GGUF models"
        msg_normal "3) Delete a local GGUF model"
        back_options
        msg_normal "x) Exit"
        msg_line

        lcmenu_opt=$(read_menu_choice "Selection: " 1 3)

        case "$lcmenu_opt" in
        1)
            msg_normal "Enter HuggingFace GGUF URL: "
            read -r lcmenu_url
            if [ -n "$lcmenu_url" ]; then
                download_gguf_model "$lcmenu_url"
            fi
            ;;
        2)
            msg_blank
            msg_info "Available GGUF Models in $MODELS_DIR:"
            mkdir -p "$MODELS_DIR"
            ls -lh "$MODELS_DIR"/*.gguf 2>/dev/null || msg_warn "No .gguf models found."
            msg_blank
            ;;
        3)
            msg_blank
            mkdir -p "$MODELS_DIR"
            if ! ls "$MODELS_DIR"/*.gguf >/dev/null 2>&1; then
                msg_warn "No models to delete."
                continue
            fi
            msg_normal "Enter the exact filename to delete (or wildcards): "
            read -r lcmenu_rm
            if [ -n "$lcmenu_rm" ] && yes_no "Are you sure you want to delete '$lcmenu_rm'?"; then
                rm -f "${MODELS_DIR}/${lcmenu_rm}"
                msg_success "Deleted."
            fi
            ;;
        b)
            return 0
            ;;
        x)
            good_exit "Exiting"
            ;;
        *)
            msg_error "Invalid selection: $lcmenu_opt"
            ;;
        esac
    done
}

## Command Parser
llamacpp_command_router() {
    lccmd_cmd="${1:-menu}"
    shift 2>/dev/null || true

    case "$lccmd_cmd" in
    menu | -m | --menu)
        llamacpp_menu
        ;;
    download | dl | -d | --download)
        download_gguf_model "$1"
        ;;
    list | ls)
        mkdir -p "$MODELS_DIR"
        ls -lh "$MODELS_DIR"/*.gguf 2>/dev/null || echo "No models found."
        ;;
    *)
        msg_error "Unknown llamacpp command: $lccmd_cmd"
        msg_usage "$script_name llamacpp [ menu | download <url> | list ]"
        error_exit 1
        ;;
    esac
}
