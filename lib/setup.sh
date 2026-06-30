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

## Select Services
select_services() {
    selsrv_cur_srv="$1"

    msg_line
    msg_header ${GREEN} "Step 1: Select Active Services"
    msg_normal "1) Full SIA stack (AI and SearXNG)"
    msg_normal "2) SearXNG only (Search Engine)"
    msg_normal "3) AI only (WebUI, LLM Runner)"
    msg_normal "4) Keep current [${selsrv_cur_srv}]"
    back_options
    msg_normal ""
    msg_line

    srv_choice=$(read_menu_choice "Services: " 1 4)
    case "$srv_choice" in
    1) printf '%s' "full" ;;
    2) printf '%s' "searxng" ;;
    3) printf '%s' "ai" ;;
    4) printf '%s' "${selsrv_cur_srv}" ;;
    b) printf '%s' "GO_BACK" ;;
    x) good_exit "Exiting" ;;
    esac
}

## Select processor architecture
select_processor_architecture() {
    selproc_cur_proc="$1"

    msg_line
    msg_header ${GREEN} "Step 2: Select Architecture for GPU Acceleration"
    msg_normal "1) CPU Only (No GPU acceleration)"
    msg_normal "2) NVIDIA GPU (CUDA)"
    msg_normal "3) AMD GPU (ROCm)"
    msg_normal "4) Keep current: [${selproc_cur_proc}]"
    back_options
    msg_normal "x) Exit"
    msg_line

    hw_choice=$(read_menu_choice "Hardware: " 1 4)

    case "$hw_choice" in
    1) printf '%s' "cpu" ;;
    2) printf '%s' "nvidia" ;;
    3) printf '%s' "amd" ;;
    4) [ "$selproc_cur_proc" = "None" ] && [ -z "$selproc_cur_proc" ] && printf '%s' "cpu" || printf '%s' "$selproc_cur_proc" ;;
    b) printf '%s' "GO_BACK" ;;
    x) good_exit "Exiting" ;;
    esac
}

## Select LLM Runner
select_llm_runner() {
    selrun_cur_run="$1"

    msg_line
    msg_header ${GREEN} "Step 3: Select LLM Runner"
    msg_normal "1) Ollama"
    msg_normal "2) llama.cpp"
    msg_normal "3) Keep current [${selrun_cur_run}]"
    back_options
    msg_normal "x) Exit"
    msg_line

    run_choice=$(read_menu_choice "Runner: " 1 3)
    case "$run_choice" in
    1) printf '%s' "ollama" ;;
    2) printf '%s' "llama-cpp" ;;
    3) [ "$selrun_cur_run" = "None" ] && [ -z "$selrun_cur_run" ] && printf '%s' "ollama" || printf '%s' "$selrun_cur_run" ;;
    b) printf '%s' "GO_BACK" ;;
    x) good_exit "Exiting" ;;
    esac
}

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
    chngst_new_srv=$(select_services "$cur_srv")
    if [ "$chngst_new_srv" = "GO_BACK" ]; then
        return 0
    elif [ "$chngst_new_srv" != "$cur_srv" ]; then
        chngst_sel_changed=1
    fi

    if [ "$chngst_new_srv" = "ai" ] || [ "$chngst_new_srv" = full ]; then
        # 2. Hardware profile
        chngst_new_hw=$(select_processor_architecture "$cur_hw")
        if [ "$chngst_new_hw" = "GO_BACK" ]; then
            return 0
        elif [ "$chngst_new_hw" != "$cur_hw" ]; then
            chngst_sel_changed=1
        fi

        # 3. LLM Runner
        chngst_new_run=$(select_llm_runner "$cur_run ")
        if [ "$chngst_new_run" = "GO_BACK" ]; then
            return 0
        elif [ "$chngst_new_run" != "$cur_run" ]; then
            chngst_sel_changed=1
        fi
    fi
    # -----------------
    ## INITIALIZATION
    # -----------------
    # 1. Save / Inject variables
    if [ "$chngst_sel_changed" -eq 1 ]; then
        # A. Inject SIA state variables into environment
        edit_kv "SIA_SERVICES" "$chngst_new_srv" "$env_core_file"
        edit_kv "SIA_HW_PROFILE" "$chngst_new_hw" "$env_core_file"
        edit_kv "SIA_LLM_RUNNER" "$chngst_new_run" "$env_core_file"

        # B. Compile Docker Compose exececution string
        compiled_profiles=""

        if [ "$chngst_new_srv" = "searxng" ] || [ "$chngst_new_srv" = "full" ]; then
            compiled_profiles="searxng"
        fi

        if [ "$chngst_new_srv" = "ai" ] || [ "$chngst_new_srv" = "full" ]; then
            [ -n "$compiled_profiles" ] && compiled_profiles="${compiled_profiles},"
            compiled_profiles="${compiled_profiles}webui-${chngst_new_hw},${chngst_new_run}-${chngst_new_hw}"
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
