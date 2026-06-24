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
LCMODELS_DIR="./models"
HF_CACHE_DIR="$LCMODELS_DIR/hf_cache"
LLAMACPP_CONTAINER="llama-cpp-server"

## Run command
llamacpp_run() {
    msg_line
    msg_header ${GREEN} "Deploy Model"

    lcrun_target="${1:-}"
    if [ -z "$lcrun_target" ]; then
        msg_normal "Enter HF Repo (e.g., unsloth/Llama-3.2-3B-Instruct-GGUF:Q4_K_M): "
        read -r lcrun_target
    fi
    [ -z "$lcrun_target" ] && {
        msg_warn "Aborting."
        return 1
    }

    case "$lcrun_target" in
    *:*)
        lcrun_input_repo="${lcrun_target%%:*}"
        lcrun_input_tag="${lcrun_target#*:}"
        ;;
    *)
        lcrun_input_repo="$lcrun_target"
        lcrun_input_tag=""
        ;;
    esac

    # Format
    if [ -z "$lcrun_input_tag" ]; then
        lcrun_input_file="*.gguf"
    elif case "$lcrun_input_tag" in *.gguf) true ;; *) false ;; esac then
        lcrun_input_file="$lcrun_input_tag"
    else
        lcrun_input_file="*${lcrun_input_tag}*.gguf"
    fi

    edit_kv "SIA_HF_REPO" "$lcrun_input_repo" "${env_file:-.env}"
    edit_kv "SIA_HF_FILE" "$lcrun_input_file" "${env_file:-.env}"

    msg_info "Cycling container to load $lcrun_input_repo..."
    docker compose up -d llama-cpp-server-nvidia
    msg_success "Started!"
}

## 2. List Local Cache
llamacpp_list() {
    msg_blank
    msg_info "Locally Cached Models:"
    if [ ! -d "$HF_CACHE_DIR" ]; then
        msg_warn "Cache directory does not exist yet."
        return 0
    fi

    lcls_found_models=0
    for dir in "$HF_CACHE_DIR"/models--*; do
        [ -d "$dir" ] || continue
        found_models=1
        lcls_dirname="${dir##*/}"
        # Convert "models--author--repo" back to "author/repo" for readability
        lcls_formatted_name=$(echo "$lcls_dirname" | sed 's/^models--//; s/--/\//g')
        msg_normal " - $lcls_formatted_name"
    done

    [ "$lcls_found_models" -eq 0 ] && msg_normal " No models downloaded."
    msg_blank
}

## 3. Delete from Cache
llamacpp_rm() {
    lcrm_target="$1"
    if [ -z "$lcrm_target" ]; then
        llamacpp_list
        msg_normal "Enter the Model ID to delete (e.g., author/repo): "
        read -r lcrm_target_repo
    fi
    [ -z "$lcrm_target_repo" ] && return 1

    lcrm_target_repo="${lcrm_target%%:*}"

    # Re-encode the input back to the cache directory format
    lcrm_target_dir="models--$(echo "$lcrm_target_repo" | sed 's/\//--/g')"
    lcrm_target_path="$HF_CACHE_DIR/$lcrm_target_dir"

    if [ -d "$lcrm_target_path" ]; then
        if yes_no "Permenantly delete cache for $lcrm_target_repo?"; then
            rm -rf "$lcrm_target_path"
            msg_success "Deleted $lcrm_target_repo."
        fi
    else
        msg_warn "Could not find $lcrm_target_repo in cache."
    fi
}

## 4. Tune Performance Parameters
llamacpp_tune() {
    msg_line
    msg_header ${BLUE} "Engine Tuning (llama.cpp)"

    lctune_cur_ctx=$(grep "^LLAMACPP_CTX_SIZE=" "${env_file:-.env}" | cut -d '=' -f 2 || echo "8192")
    lctune_cur_ngl=$(grep "^LLAMACPP_N_GL=" "${env_file:-.env}" | cut -d '=' -f 2 || echo "999")

    msg_normal "Current Context Window: $lctune_cur_ctx"
    msg_normal "Enter new Context Window (Press Enter to keep): "
    read -r lctune_new_ctx
    [ -n "$lctune_new_ctx" ] && edit_kv "LLAMACPP_CTX_SIZE" "$lctune_new_ctx" "${env_file:-.env}"

    msg_normal "Current GPU Layers offloaded: $lctune_cur_ngl"
    msg_normal "Enter new GPU Layers (999 for all, Enter to keep): "
    read -r lctune_new_ngl
    [ -n "$lctune_new_ngl" ] && edit_kv "LLAMACPP_N_GL" "$lctune_new_ngl" "${env_file:-.env}"

    if [ -n "$lctune_new_ctx" ] || [ -n "$lctune_new_ngl" ]; then
        msg_success "Parameters updated."
        if yes_no "Restart container to apply changes?"; then
            docker compose up -d llama-cpp-server-nvidia
        fi
    fi
}
