# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|

## Check command dependencies
#  - this function represents a clean alternative to arrays and for loops
#  - adapt if you want true mapping files

check_deps() {
    while IFS= read -r cmd || [ -n "$cmd" ]; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            msg_error "$cmd not found"
            error_exit 2
        fi
    done < "$DEPENDENCIES"
}

## Check SIA file dependencies
#  - this function represents a clean alternative to arrays and for loops

check_files() {
    mkdir -p share
    mkdir -p lib
    mkdir -p archive
    chk_errors=0

    while IFS= read -r chk_file || [ -n "$chk_file" ]; do
        case "$chk_file" in
            ""|"#"*) continue ;;
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
    done < "$FILES"

    [ "$chk_errors" -gt 0 ] && return 1 || return 0
}

## Make user env file
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

## Make user compose files
create_yamls_from_templates() {
    while IFS='=' read -r yaml_key yaml_val || [ -n "$yaml_key" ]; do
        case "$yaml_key" in
            ""|"#"*) continue ;;
        esac

        if [ ! -f "$yaml_val" ]; then
            if cp "$yaml_key" "$yaml_val"; then
                msg_debug "Successfully initialized $yaml_val"
            else
                msg_error "Unable to copy $yaml_key to $yaml_val."
            fi
        fi
    done < "$PROVIDERS"
}