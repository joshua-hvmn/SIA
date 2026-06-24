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
        msg_normal "Enter HF Repo (e.g., unsloth/Qwen3.5-4B-GGUF:Q4_K_M) or local filename: "
        read -r lcrun_target
    fi
    [ -z "$lcrun_target" ] && {
        msg_warn "Aborting."
        return 1
    }

    # Check for local file, or download from HF
    if [ -f "./models/$lcrun_target" ]; then
        msg_info "Local model detected. Loading."

        edit_kv "SIA_LOCAL_MODEL" "/models/$lcrun_target" "${env_file:-.env}"
        edit_kv "SIA_HF_ARGS" "" "${env_file:-.env}"

    else
        # Downloading
        msg_debug "Formatting..."
        edit_kv "SIA_LOCAL_MODEL" "" "${env_file:-.env}"

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
            msg_warn "No quantization tag specified. Defaulting to Q4_K_M.gguf"
            lcrun_resolved_tag="Q4_K_M"
        else
            lcrun_resolved_tag="$lcrun_input_tag"
        fi

        # Check for literal filename
        lcrun_is_not_gguf=1
        case "$lcrun_resolved_tag" in
        *.gguf) lcrun_is_not_gguf=0 ;;
        esac

        if [ "$lcrun_is_not_gguf" -eq 1 ]; then
            lcrun_hf_args="--hf-model ${lcrun_input_repo}:${lcrun_resolved_tag}"
        else
            lcrun_hf_args="--hf-model $lcrun_input_repo --hf-file $lcrun_resolved_tag"
        fi

        edit_kv "SIA_HF_ARGS" "$lcrun_hf_args" "${env_file:-.env}"
    fi

    # Get hardware profile
    lcrun_hw_profile=$(get_hw_profile)
    [ "$lcrun_hw_profile" = "error" ] && msg_error "Could not detect HW profile, run './sia setup'" && error_exit 2

    msg_info "Cycling container to load $lcrun_input_repo..."
    docker compose up -d --force-recreate "llama-cpp-server-$lcrun_hw_profile"
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
