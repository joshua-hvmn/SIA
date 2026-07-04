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

# -------------------------------------------------------------
# SELECT SIA SERVICES
# -------------------------------------------------------------

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
    msg_normal "x) Exit"
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

# -------------------------------------------------------------
## HARDWARE ACCELERATION
# -------------------------------------------------------------

## Autodetect GPU achitecture and VRAM (Output: vendor:vram_kb)
detect_gpu_hardware() {
    dgh_vendor="cpu"
    dgh_vram_kb="0"

    # Check for nvidia
    if command -v nvidia-smi >/dev/null 2>&1; then
        vram_mib=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | awk '{s+=$1} END {print s}')
        if [ -n "$vram_mib" ] && [ "$vram_mib" -ne 0 ] 2>/dev/null; then
            dgh_vendor="nvidia"
            dgh_vram_kb=$((vram_mib * 1024))
        fi
    # Check for AMD
    else
        total_sysfs_vram=0
        for mem_file in /sys/class/drm/card*/device/mem_info_vram_total; do
            if [ -r "$mem_file" ]; then
                dgh_val=$(cat "$mem_file")
                total_sysfs_vram=$((total_sysfs_vram + dgh_val))
            fi
        done
        if [ "$total_sysfs_vram" -gt 0 ]; then
            dgh_vendor="amd"
            dgh_vram_kb=$((total_sysfs_vram / 1024))
        fi
    fi

    printf '%s:%s' "$dgh_vendor" "$dgh_vram_kb"
}

## User prompt for VRAM in GiB, convert to KiB
read_vram_kb() {
    msg_normal "Please enter the total amount of GPU VRAM in gibibytes: "

    while true; do
        read -r rrvkb_vram_input_gb || true
        if [ -n "$rrvkb_vram_input_gb" ] && [ "$rrvkb_vram_input_gb" -eq "$rrvkb_vram_input_gb" ] 2>/dev/null; then
            break
        else
            msg_error "Invalid input. Please enter a number."
            msg_normal "Please enter the amount of GPU VRAM in gibibytes: "
        fi
    done

    read_ram_output_kb=$(convert_gb_to_kb "$rrvkb_vram_input_gb")
    printf '%s' "$read_ram_output_kb"
}

## Select processor architecture
select_hardware_profile() {
    shp_cur_hw="$1"
    shp_cur_vram="$2"

    shp_detect_str=$(detect_gpu_hardware)
    shp_det_vendor="${shp_detect_str%%:*}"
    shp_det_vram_kb="${shp_detect_str##*:}"

    shp_det_vram_gb=$(((shp_det_vram_kb + (1024 * 1024 / 2)) / (1024 * 1024)))
    shp_cur_vram_gb=$(((shp_cur_vram + (1024 * 1024 / 2)) / (1024 * 1024)))

    msg_line
    msg_header ${GREEN} "Step 2: Select Architecture for GPU Acceleration"
    msg_normal "${BOLD}Automatically detected (enter to accept, 'n' to edit):${NC}
        ${BLUE}Vendor: ${GREEN}${shp_det_vendor}${NC}
        ${BLUE}VRAM:   ${GREEN}${shp_det_vram_gb} GiB${NC}
    "
    msg_normal "If you have a GPU, and $app_name did not detect it, Docker might not utilize your GPU."
    msg_normal "Install the necessary dependencies, if applicable."
    msg_blank
    msg_normal "1) CPU Only (No GPU acceleration)"
    msg_normal "2) NVIDIA GPU (CUDA)"
    msg_normal "3) AMD GPU (ROCm)"
    msg_normal "4) Keep previous: [ Vendor: ${shp_cur_hw} | VRAM: ${shp_cur_vram_gb} GiB ]"
    msg_normal "x) Exit"
    msg_line

    yes_no "Accept autodetected options?"
    case $? in
    0)
        hw_choice="auto"
        ;;
    1)
        hw_choice=$(read_menu_choice "Hardware choice: " 1 4)
        ;;
    2)
        hw_choice="x"
        ;;
    esac

    case "$hw_choice" in
    1)
        shp_final_vendor="cpu"
        shp_final_vram="0"
        ;;
    2)
        shp_final_vendor="nvidia"
        if [ "$shp_det_vendor" = "nvidia" ] && [ "$shp_det_vram_kb" -gt 0 ]; then
            shp_final_vram="$shp_det_vram_kb"
        else
            shp_final_vram=$(read_vram_kb)
        fi
        ;;
    3)
        shp_final_vendor="amd"
        if [ "$shp_det_vendor" = "amd" ] && [ "$shp_det_vram_kb" -gt 0 ]; then
            shp_final_vram="$shp_det_vram_kb"
        else
            shp_final_vram=$(read_vram_kb)
        fi
        ;;
    4)
        [ "$shp_cur_hw" = "None" ] && shp_final_vendor="cpu" || shp_final_vendor="$shp_cur_hw"
        [ -z "$shp_cur_vram" ] && shp_final_vram="0" || shp_final_vram="$shp_cur_vram"
        ;;
    auto)
        shp_final_vendor="$shp_det_vendor"
        shp_final_vram="$shp_det_vram_kb"
        ;;
    b | x | c)
        printf '%s' "CANCEL"
        return
        ;;
    esac

    printf '%s:%s' "$shp_final_vendor" "$shp_final_vram"
}

# -------------------------------------------------------------
# SELECT LLM RUNNER
# -------------------------------------------------------------

## Select LLM Runner
select_llm_runner() {
    selrun_cur_run="$1"

    msg_line
    msg_header ${GREEN} "Step 3: Select LLM Runner"
    if [ "$selrun_cur_run" != "None" ]; then
        msg_normal "1) Ollama"
    else
        msg_normal "1) Ollama (default)"
    fi
    msg_normal "2) llama.cpp"
    if [ "$selrun_cur_run" != "None" ]; then
        msg_normal "3) Keep current [${selrun_cur_run}]"
    fi
    back_options
    msg_normal "x) Exit"
    msg_line

    run_choice=$(read_menu_choice "Runner: " 1 3)
    case "$run_choice" in
    1) printf '%s' "ollama" ;;
    2) printf '%s' "llama-cpp" ;;
    3) [ "$selrun_cur_run" = "None" ] && [ -z "$selrun_cur_run" ] && printf '%s' "ollama" || printf '%s' "$selrun_cur_run" ;;
    b | x | c) printf '%s' "CANCEL" ;;
    esac
}

# -------------------------------------------------------------
# CPU CORE COUNT SELECTION / DETECTION
# -------------------------------------------------------------

## Prompt for CPU cores if autodetect fails
select_cpu_cores() {
    scc_cores=""

    msg_line
    msg_error "Failed to detect CPU core count."
    msg_normal "Please enter the number of physical cores in your CPU: "
    msg_line

    while true; do
        read -r scc_cores || true
        case "$scc_cores" in
        n | c | x) scc_cores="CANCEL" && break ;;
        esac
        if [ -n "$scc_cores" ] && [ $((scc_cores % 2)) -eq 0 ]; then
            break
        elif [ -n "$scc_cores" ]; then
            msg_warn "Odd CPU core count indicated ($scc_cores), almost all CPUs have an even number of cores."
            yes_no "Are you sure you want to continue with '$scc_cores' total CPU cores?: "
            case "$?" in
            0)
                break
                ;;
            1)
                msg_normal "Cancelled selection. Enter the corrected amount of CPU cores: "
                ;;
            2)
                scc_cores="CANCEL"
                ;;
            esac
        else
            msg_error "Input not detected. Please try aqain."
            msg_normal "Please enter the number of the physical cores in your CPU:"
        fi
    done

    [ -n "$scc_cores" ] && printf '%s' "$scc_cores" || {
        msg_error "Unknown error, select_cpu_cores() in setup.sh failed."
        error_exit 2
    }
}
## Autodetect CPU cores
#  - USAGE: detect_cpu_cores [sel]
#  'sel' flag forces select_cpu_cores on failure to detect
detect_cpu_cores() {
    dcc_mode="${1:-}"
    dcc_cores=""
    # use getconf if present
    if command -v getconf >/dev/null 2>&1; then
        dcc_cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null)
    # Linux
    elif [ -r /proc/cpuinfo ]; then
        dcc_cores=$(awk '/^processor/ { n++ } END { print n }' /proc/cpuinfo)
    # Mac / BSD
    elif command -v sysctl >/dev/null 2>&1; then
        dcc_cores=$(sysctl -n hw.ncpu 2>/dev/null)
    # Fail
    else
        dcc_cores="CORE_NUM_DETECTION_FAILED"
    fi

    # If fail to detect, prompt for selection
    if [ "$dcc_cores" = "CORE_NUM_DETECTION_FAILED" ] && [ "$dcc_mode" = "sel" ]; then
        dcc_cores=$(select_cpu_cores)
    fi

    printf '%s' "$dcc_cores"
}

# -------------------------------------------------------------
# SYSTEM RAM DETECTION / SELECTION
# -------------------------------------------------------------

## User prompt for RAM in GB, convert to KB
read_ram_kb() {
    msg_normal "Please enter the         chngst_new_cpu_cores="$cur_cpu_cores"
        chngst_new_sys_ram="$cur_sys_ram"
        chngst_new_run="$cur_run"amount of system RAM in gigabytes: "

    while true; do
        read -r rrkb_ram_input_gb || true
        case "$rrkb_ram_input_gb" in
        n | c | x) read_ram_output_kb="CANCEL" && break ;;
        esac
        if [ -n "$rrkb_ram_input_gb" ] && [ $((rrkb_ram_input_gb % 8)) -eq 0 ]; then
            read_ram_output_kb=$(convert_gb_to_kb "$rrkb_ram_input_gb")
            break
        elif [ -n "$rrkb_ram_input_gb" ]; then
            msg_warn "Non-standard RAM amount indicated: $rrkb_ram_input_gb GB"
            yes_no "Are you sure you want to continue with $rrkb_ram_input_gb GB total system RAM?: "
            case "$?" in
            0)
                read_ram_output_kb=$(convert_gb_to_kb "$rrkb_ram_input_gb")
                break
                ;;
            1)
                msg_normal "Cancelled selection. Enter the corrected amount of system RAM in GB: "
                ;;
            2)
                read_ram_output_kb="CANCEL"
                ;;
            esac
        else
            msg_error "Input not detected. Please try again."
            msg_normal "Please enter the amount of system RAM in gigabytes: "
        fi
    done

    [ -n "$read_ram_output_kb" ] && printf '%s' "$read_ram_output_kb" || {
        msg_error "Unknown error, read_ram_kb() in setup.sh failed."
        error_exit 2
    }

}

## Autodetect RAM
#  - USAGE: detect_ram_kb [read]
#  'read' flag forces read_ram_kb on failure to detect
detect_ram_kb() {
    dramkb_mode="${1:-}"
    dramkb_ram_kb=""
    # use getconf if present
    if [ -r /proc/meminfo ]; then
        dramkb_ram_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
    # Mac / BSD
    elif command -v sysctl >/dev/null 2>&1; then
        dramkb_ram_kb=$(sysctl -n hw.memsize 2>/dev/null)
        if [ -n "$dramkb_ram_kb" ]; then
            dramkb_ram_kb=$((dramkb_ram_kb / 1024))
        fi
    # Fail
    else
        dramkb_ram_kb="DETECT_RAM_KB_FAILED"
    fi

    # If fail to detect, prompt for selection
    if [ "$dramkb_ram_kb" = "DETECT_RAM_KB_FAILED" ] && [ "$dramkb_mode" = "read" ]; then
        msg_line
        msg_error "Failed to detect system RAM."
        dramkb_ram_kb=$(read_ram_kb)
    fi

    printf '%s' "$dramkb_ram_kb"
}

# -------------------------------------------------------------
# MAIN
# -------------------------------------------------------------
## Setup :
# - Pass 1 after calling to force inbuilt auto-restart
# - Multi-step setup wizard: Services -> Hardware -> LLM Runner.
# - Stack will restart automatically when you select or change a setup.

change_setup() {
    chngst_cmd_started="${1:-0}"
    chngst_sel_changed=0

    # Check state
    cur_srv="${SIA_SERVICES:-None}"
    cur_hw="${SIA_HW_PROFILE:-None}"
    cur_vram="${SIA_VRAM_KB:-0}"
    cur_cpu_cores="${SIA_CPU_CORES:-0}"
    cur_sys_ram="${SIA_SYSTEM_MEMORY:-0}"
    cur_run="${SIA_LLM_RUNNER:-None}"

    ## PROFILE SETTINGS
    # -----------------
    # 1. Services
    chngst_new_srv=$(select_services "$cur_srv")
    case "$chngst_new_srv" in
    *CANCEL* | *GO_BACK* | *Exiting*)
        chngst_sel_changed=0
        return 0
        ;;
    esac

    if [ "$chngst_new_srv" != "$cur_srv" ]; then
        chngst_sel_changed=1
    fi

    if [ "$chngst_new_srv" = "ai" ] || [ "$chngst_new_srv" = full ]; then
        # 2. Hardware profile & VRAM
        chngst_hw_result=$(select_hardware_profile "$cur_hw" "$cur_vram")
        case "$chngst_hw_result" in
        *CANCEL*)
            chngst_sel_changed=0
            return 0
            ;;
        esac
        chngst_new_hw="${chngst_hw_result%%:*}"
        chngst_new_vram="${chngst_hw_result##*:}"

        if [ "$chngst_new_hw" != "$cur_hw" ] || [ "$chngst_new_vram" != "$cur_vram" ]; then
            chngst_sel_changed=1
        fi

        # 3. Detect / Select CPU core count
        chngst_new_cpu_cores=$(detect_cpu_cores "sel")
        case "$chngst_new_cpu_cores" in
        *CANCEL*)
            chngst_sel_changed=0
            return 0
            ;;
        esac

        if [ "$chngst_new_cpu_cores" != "$cur_cpu_cores" ]; then
            chngst_sel_changed=1
        fi

        # 4. Detect / Select System RAM
        chngst_new_sys_ram=$(detect_ram_kb "read")
        case "$chngst_new_sys_ram" in
        *CANCEL*)
            chngst_sel_changed=0
            return 0
            ;;
        esac

        if [ "$chngst_new_sys_ram" != "$cur_sys_ram" ]; then
            chngst_sel_changed=1
        fi

        # 5. LLM Runner
        chngst_new_run=$(select_llm_runner "$cur_run")
        case "$chngst_new_run" in
        *CANCEL*)
            chngst_sel_changed=0
            return 0
            ;;
        esac
        if [ "$chngst_new_run" != "$cur_run" ]; then
            chngst_sel_changed=1
        fi
    else
        chngst_new_hw="$cur_hw"
        chngst_new_vram="$cur_vram"
        chngst_new_cpu_cores="$cur_cpu_cores"
        chngst_new_sys_ram="$cur_sys_ram"
        chngst_new_run="$cur_run"
    fi
    # -----------------
    ## INITIALIZATION
    # -----------------
    # 1. Save / Inject variables
    if [ "$chngst_sel_changed" -eq 1 ]; then
        # A. Stop stack before changing environment
        sia_compose_up "down"
        # B. Inject SIA state variables into environment
        edit_kv "SIA_SERVICES" "$chngst_new_srv" "$env_core_file"
        edit_kv "SIA_HW_PROFILE" "$chngst_new_hw" "$env_core_file"
        edit_kv "SIA_VRAM_KB" "$chngst_new_vram" "$env_core_file"
        edit_kv "SIA_CPU_CORES" "$chngst_new_cpu_cores" "$env_core_file"
        edit_kv "SIA_SYSTEM_MEMORY" "$chngst_new_sys_ram" "$env_core_file"
        edit_kv "SIA_LLM_RUNNER" "$chngst_new_run" "$env_core_file"
        export SIA_SERVICES="$chngst_new_srv"
        export SIA_HW_PROFILE="$chngst_new_hw"
        export SIA_VRAM_KB="$chngst_new_vram"
        export SIA_CPU_CORES="$chngst_new_cpu_cores"
        export SIA_SYSTEM_MEMORY="$chngst_new_sys_ram"
        export SIA_LLM_RUNNER="$chngst_new_run"

        # C. Compile Docker Compose exececution string
        compiled_profiles=""

        if [ "$chngst_new_srv" = "searxng" ] || [ "$chngst_new_srv" = "full" ]; then
            compiled_profiles="searxng"
        fi

        if [ "$chngst_new_srv" = "ai" ] || [ "$chngst_new_srv" = "full" ]; then
            [ -n "$compiled_profiles" ] && compiled_profiles="${compiled_profiles},"
            compiled_profiles="${compiled_profiles}ai,webui-${chngst_new_hw},${chngst_new_run}-${chngst_new_hw}"
        fi

        # D. Inject Compose variable and setup complete into environment
        edit_kv "COMPOSE_PROFILES" "$compiled_profiles" "$env_core_file"
        export COMPOSE_PROFILES="$compiled_profiles"
        edit_kv "SETUP_COMPLETE" "true" "$env_core_file"
    fi

    # 2. Restart containers
    if [ "$chngst_sel_changed" -eq 1 ]; then
        start_up
    fi
    return 0
}
