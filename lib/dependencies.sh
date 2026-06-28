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

## Check command dependencies
#  - this function represents a clean alternative to arrays and for loops
check_deps() {
    while IFS= read -r cmd || [ -n "$cmd" ]; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            msg_error "$cmd not found"
            error_exit 2
        fi
    done <"$DEPENDENCIES"
}

## Check SIA file dependencies
#  - repairs missing files. Something is wrong, and it fails to detect files that are present
#  TODO: add env variable to disable this function
check_files() {
    mkdir -p share
    mkdir -p lib
    mkdir -p archive
    chk_errors=0

    while IFS= read -r chk_file || [ -n "$chk_file" ]; do
        case "$chk_file" in
        "" | "#"*) continue ;;
        esac

        if [ ! -f "$chk_file" ]; then
            msg_error "$chk_file missing, attempting to recover..."

            REPO_URL="$LINK/$USERNAME/$REPOSITORY/$BRANCH/$chk_file"

            if curl -fsSL --create-dirs "$REPO_URL" -o "$chk_file"; then
                msg_debug "Successfully recovered $chk_file"
            else
                msg_debug "Unable to recover $chk_file. Proceed with caution."
                chk_errors=$((chk_errors + 1))
            fi
        fi
    done <"$FILES"

    [ "$chk_errors" -gt 0 ] && return 1 || return 0
}

## copy template helper function
#  - Usage: copy_template <src> <dst> [secure]
#  secure=1: mkdir -p parent, skip if non-empty, chmod 600
copy_template() {
    ct_src="$1"
    ct_dst="$2"
    ct_secure="${3:-0}"
    if [ "$ct_secure" -eq 1 ]; then
        mkdir -p "$(dirname "$ct_dst")"
        [ -s "$ct_dst" ] && return 0
    else
        [ -f "$ct_dst" ] && return 0
    fi
    if cp "$ct_src" "$ct_dst"; then
        if [ "$ct_secure" -eq 1 ]; then
            chmod 600 "$ct_dst"
            msg_debug "Successfully initialized '$ct_dst' with chmod 600 permissions"
        else
            msg_debug "Successfully initialized '$ct_dst'"
        fi
    else
        msg_error "Unable to copy $ct_src to $ct_dst."
        return 1
    fi
}

## Copy default file
## Make user env file
create_env_from_template() {
    if [ ! -f "$DEFAULTS" ]; then
        msg_error "$DEFAULTS manifest not found, cannot restore."
        error_exit 2
    fi
    while IFS='=' read -r ceft_src ceft_dst || [ -n "$ceft_src" ]; do
        case "$ceft_src" in
        "" | "#"*) continue ;;
        esac
        copy_template "$ceft_src" "$ceft_dst" 1
    done <"$DEFAULTS"
}

## Make user compose files
# - Copies default backups to main directory.
# - This loop is a remnant of old multi yaml architecture.
# - I am keeping it in case I need that again.
create_yamls_from_templates() {
    while IFS='=' read -r yaml_src yaml_dst || [ -n "$yaml_src" ]; do
        case "$yaml_src" in
        "" | "#"*) continue ;;
        esac
        copy_template "$yaml_src" "$yaml_dst"
    done <"$PROVIDERS"
}
