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

## Setup :
# - Pass 1 after calling to force inbuilt auto-restart
# - Multi-step setup wizard: Services -> Hardware -> LLM Runner.
# - Stack will restart automatically when you select or change a setup.

change_setup() {
    chngst_cmd_started="${1:-0}"
    chngst_sel_changed=0

    # Check state
    cur_srv="${SIA_SERVICES:-None}"
    cur_hw="${SIA_HW:-None}"
    cur_run="${SIA_LLM_RUNNER:-None}"

    ## PROFILE SETTINGS
    # -----------------
    # 1. Services
    msg_line
    msg_header ${GREEN} "Step 1: Select Active Services"
    msg_normal "1) Full SIA stack (AI and SearXNG)"
    msg_normal "2) SearXNG only (Search Engine)"
    msg_normal "3) AI only (WebUI, LLM Runner)"
    msg_normal "4) Keep current [${cur_srv}]"
    back_options
    msg_normal ""
    msg_line

    srv_choice=$(read_menu_choice "Services: " 1 4)
    case "$srv_choice" in
    1) new_srv="full" ;;
    2) new_srv="searxng" ;;
    3) new_srv="ai" ;;
    4)
        new_srv="${cur_srv}"
        [ "$new_srv" = "None" ] && new_srv="full"
        ;;
    b) return 0 ;;
    x) good_exit "Exiting" ;;
    esac
    [ "$new_srv" != "$cur_srv" ] && chngst_sel_changed=1

    new_hw="$cur_hw"
    new_run="$cur_run"

    if [ "$new_srv" = "ai" ] || [ "$new_srv" = full ]; then

        # 2. Hardware profile
        msg_line
        msg_header ${GREEN} "Step 2: Select Hardware Optimization"
        msg_normal "1) CPU only (no discete GPU)"
        msg_normal "2) NVIDIA GPU (CUDA)"
        msg_normal "3) AMD GPU (ROCm)"
        msg_normal "4) Keep current: [${cur_hw}]"
        back_options
        msg_normal "x) Exit"
        msg_line

        hw_choice=$(read_menu_choice "Hardware: " 1 4)

        case "$hw_choice" in
        1) new_hw="cpu" ;;
        2) new_hw="nvidia" ;;
        3) new_hw="amd" ;;
        4) [ "$new_hw" = "None" ] && new_hw="cpu" ;;
        b) return 0 ;;
        x) good_exit "Exiting" ;;
        esac
        [ "$new_hw" != "$cur_hw" ] && chngst_sel_changed=1

        # 3. LLM Runner
        msg_line
        msg_header ${GREEN} "Step 3: Select LLM Runner"
        msg_normal "1) Ollama"
        msg_normal "2) llama.cpp"
        msg_normal "3) Keep current [${cur_run}]"
        back_options
        msg_normal "x) Exit"
        msg_line

        run_choice=$(read_menu_choice "Runner: " 1 3)
        case "$run_choice" in
        1) new_run="ollama" ;;
        2) new_run="llama-cpp" ;;
        3) [ "$new_run" = "None" ] && new_run="ollama" ;;
        b) return 0 ;;
        x) good_exit "Exiting" ;;
        esac
        [ "$new_run" != "$cur_run" ] && chngst_sel_changed=1
    fi
    # -----------------

    ## INITIALIZATION
    # -----------------
    # 1. Save / Inject variables
    if [ "$chngst_sel_changed" -eq 1 ]; then
        # A. Inject SIA state variables into environment
        edit_kv "SIA_SERVICES" "$new_srv" "$env_core_file"
        edit_kv "SIA_HW_PROFILE" "$new_hw" "$env_core_file"
        edit_kv "SIA_LLM_RUNNER" "$new_run" "$env_core_file"

        # B. Compile Docker Compose exececution string
        compiled_profiles=""

        if [ "$new_srv" = "searxng" ] || [ "$new_srv" = "full" ]; then
            compiled_profiles="searxng"
        fi

        if [ "$new_srv" = "ai" ] || [ "$new_srv" = "full" ]; then
            [ -n "$compiled_profiles" ] && compiled_profiles="${compiled_profiles},"
            compiled_profiles="${compiled_profiles}webui-${new_hw},${new_run}-${new_hw}"
        fi

        # C. Inject Compose variable and setup complete into environment
        edit_kv "COMPOSE_PROFILES" "$compiled_profiles" "$env_core_file"
        edit_kv "SETUP_COMPLETE" "true" "$env_core_file"
    fi

    # 2. Restart containers
    if [ "$chngst_cmd_started" -eq 1 ] && [ "$chngst_sel_changed" -eq 1 ]; then
        start_up
    fi
    return 0
}
