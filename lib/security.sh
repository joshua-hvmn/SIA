# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|

# This contains all secret key logic except the helper env_rotate_key_hlpr in lib/env_logic.sh

if [ "${SIA_MAIN_LOADED:-}" != "true" ]; then
    msg_error "Error: This script is a component of SIA and cannot be run directly."
    msg_usage "Please run: ./sia"
    error_exit 1
fi

generate_secret_key() {
    msg_debug "Generating secret key..."
    ensuresk_secret_key=
    ensuresk_method=
    # Generate the key
    # Try OpenSSL :
    if command -v openssl >/dev/null 2>&1; then
        ensuresk_secret_key=$(openssl rand -hex 32)
        ensuresk_method="OpenSSL (32 byte hexadecimal)"
        # Try Python :
    elif command -v python3 >/dev/null 2>&1; then
        ensuresk_secret_key=$(python3 -c 'import secrets; print(secrets.token_hex(32))' 2>/dev/null || true)
        ensuresk_method="Python Secrets (32 byte hexadecimal)"
    else
        # Try od (POSIX) :
        if command -v od >/dev/null 2>&1; then
            ensuresk_secret_key=$(od -An -N32 -tx1 </dev/urandom | tr -d '[:space:]')
            ensuresk_method="Octal dump (32 byte hexadecimal)"
        fi
        # Error out if no easy way to generate a secure key :
        if [ -z "$ensuresk_secret_key" ]; then
            msg_error "Couldn't find a way to generate a truly random number!"
            msg_debug "$app_name tried OpenSSL, od, and python3!"
            msg_info "Please install OpenSSL and try again or manually add a 32 byte 64 digit hex key to the $env_secrets_file file."
            error_exit 3
        fi
    fi
    # Append to .env:
    edit_kv "SEARXNG_SECRET" "$ensuresk_secret_key" "$env_secrets_file"
    msg_info "Secret key was generated with $ensuresk_method, and injected into $env_secrets_file"

    export SIA_NEEDS_CERT_INSTALL="true"

    return 0
}

is_valid_hex() {
    vldhex_key="$(printf "%s" "$1" | tr -d '[:space:]')"
    vldhex_len="${#vldhex_key}"
    # vldhex_len=$(printf "%s" "$vldhex_key" | wc -c)
    # check len = 64
    if [ "$vldhex_len" -ne 64 ]; then
        return 1
    fi
    # check key only hex
    case "$vldhex_key" in
    *[!0-9a-fA-F]*) return 1 ;;
    esac
    # if printf "%s" "$vldhex_key" | grep -q '[^0-9a-fA-F]'; then
    #     return 1
    # fi

    return 0
}

validate_env_sec() {
    vldsec_file="$env_secrets_file"
    [ ! -f "$vldsec_file" ] && return 1

    # Extract current key
    vldsec_extrctd_key=$(sed -n '/^SEARXNG_SECRET=/ s/.*=//p' "$vldsec_file")

    if [ -z "$vldsec_extrctd_key" ]; then
        msg_debug "No secret key found. Generating."
        return 1
    fi

    if is_valid_hex "$vldsec_extrctd_key"; then
        return 0
    else
        msg_warn "Current secret key is invalid or damaged. Regenerating!"
        return 1
    fi
}

## Secret Key
# - USAGE: check_seckey_main [rotate]
# - Checks if a secret key exists and randomly generate one if it doesn't or it isn't a valid 64 digit hex key
# - Rotate secret key with rotate flag
# - Tries in this order: openssl, python3, od, exit with error

check_seckey_main() {
    chksec_mode="check"
    if [ $# -gt 0 ]; then
        case "$1" in
        "rotate")
            chksec_mode="rotate"
            shift
            ;;
        *) : ;;
        esac
    fi

    if ! validate_env_sec || [ "$chksec_mode" = "rotate" ]; then
        generate_secret_key
    fi

    return 0
}
