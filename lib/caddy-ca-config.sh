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

suggest_fix_missing_certutil() {
    msg_error "'certutil' (NSS tools) is missing - Chromium and Firefox need it for profile injection."
    if command -v pacman >/dev/null 2>&1; then
        msg_info "FIX: Run 'sudo pacman -S nss'"
    elif command -v apt-get >/dev/null 2>&1; then
        msg_info "FIX: Run 'sudo apt install libnss3-tools'"
    elif command -v dnf >/dev/null 2>&1; then
        msg_info "FIX: Run 'sudo dnf install nss-tools'"
    else
        msg_info "FIX: Please install the NSS utilities package."
    fi
    msg_info "Then regenerate the secret key in the CLI environment menu."
}

add_to_linux_cert_store() {
    msg_debug "Detected Linux, attempting to install to system store..."

    ## Install
    # Debian / Ubuntu
    if command -v update-ca-certificates >/dev/null 2>&1; then
        sudo cp "$icc_tmp_cert" "/usr/local/share/ca-certificates/sia-root.crt"
        sudo update-ca-certificates 2>&1 | grep -v "ca-certificates.crt"

    # Arch
    elif [ -d "/etc/ca-certificates/trust-source/anchors" ]; then
        sudo cp "$icc_tmp_cert" "/etc/ca-certificates/trust-source/anchors/sia-root.crt"
        sudo update-ca-trust

    # Fedora / RHEL
    elif command -v update-ca-trust >/dev/null 2>&1; then
        sudo cp "$icc_tmp_cert" "/etc/pki/ca-trust/source/anchors/sia-root.crt"
        sudo update-ca-trust
    fi

    ## Configure
    # Firefox
    firefox_policy_dir=""
    if [ -d "/etc/firefox" ]; then
        firefox_policy_dir="/etc/firefox/policies"
    elif [ -d "/usr/lib/firefox/distribution" ]; then
        firefox_policy_dir="/usr/lib/firefox/distribution"
    elif [ -d "/usr/lib64/firefox/distribution" ]; then
        firefox_policy_dir="/usr/lib64/firefox/distribution"
    fi

    if [ -n "$firefox_policy_dir" ]; then
        msg_debug "Applying Firefox enterprise policy to: $firefox_policy_dir"
        sudo mkdir -p "$firefox_policy_dir"
        cat <<EOF | sudo tee "$firefox_policy_dir/policies.json" >/dev/null
{
  "policies": {
    "Certificates": { "ImportEnterpriseRoots": true }
  }
}
EOF
    fi
}

add_to_mac_keyring() {
    msg_debug "Detected macOS, adding to System Keychain..."

    sudo security add-trusted-cert \
        -d -r trustRoot \
        -k /Library/Keychains/System.keychain \
        "$icc_tmp_cert"
}

inject_firefox_cert() {
    if command -v certutil >/dev/null 2>&1; then
        msg_debug "Locating Firefox profiles dynamically under $REAL_HOME..."
        ff_injected="false"

        # Temporarily set the Internal Field Separator to newline only.
        # This prevents POSIX sh from splitting macOS filepaths that contain spaces.
        OLD_IFS="$IFS"
        IFS='
'
        # Scan up to 6 levels deep to catch native, Flatpak, Snap, and custom CachyOS paths
        for ff_profile_dir in $(find "$REAL_HOME" -maxdepth 6 -type d -name "*default*" 2>/dev/null); do

            # Verify it's an actual NSS database folder, not just a random directory named 'default'
            if [ -f "$ff_profile_dir/cert9.db" ] || [ -f "$ff_profile_dir/cert8.db" ]; then
                msg_debug "Updating Firefox profile NSS DB at: $ff_profile_dir"
                certutil -d "sql:$ff_profile_dir" -D -n "SIA Root" 2>/dev/null || true
                certutil -d "sql:$ff_profile_dir" -A -t "CT,," -n "SIA Root" -i "$icc_tmp_cert"
                ff_injected="true"
            fi
        done

        # Restore standard shell spacing
        IFS="$OLD_IFS"

        if [ "$ff_injected" != "true" ]; then
            msg_error "No active Firefox profile directory found."
            msg_info "FIX: Launch Firefox at least once to initialize the profile, then run SIA again."
        fi
    else
        suggest_fix_missing_certutil
    fi
}

inject_chromium_cert() {
    # Note: Mac Chromium browsers use the system keychain automatically, so this is Linux-only
    if [ "$systemOS" = "Linux" ]; then
        msg_debug "Locating Chromium NSS databases dynamically under $REAL_HOME..."

        OLD_IFS="$IFS"
        IFS='
'
        # Scan for the actual nssdb folder across standard and sandboxed paths
        for chrome_db_dir in $(find "$REAL_HOME" -maxdepth 6 -type d -name "nssdb" 2>/dev/null); do
            if [ -f "$chrome_db_dir/cert9.db" ] || [ -f "$chrome_db_dir/cert8.db" ]; then
                icc_target_db="sql:$chrome_db_dir"
                msg_debug "Updating Chromium DB at: $icc_target_db"
                certutil -d "$icc_target_db" -D -n "SIA Root" 2>/dev/null || true
                certutil -d "$icc_target_db" -A -t "C,," -n "SIA Root" -i "$icc_tmp_cert"
            fi
        done
        IFS="$OLD_IFS"
    fi
}

install_caddy_cert() {
    msg_info "Installing SIA security certificates to system store, password may be required..."

    if [ -n "${SUDO_USER:-}" ]; then
        REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d -f6)
        msg_debug "Running as sudo. Target user home: $REAL_HOME"
    else
        REAL_HOME="${HOME:-$HOME}"
    fi

    icc_tmp_cert="/tmp/sia-root.crt"
    icc_attempts=0

    while [ "$icc_attempts" -lt 10 ]; do
        if docker cp caddy:/data/caddy/pki/authorities/local/root.crt "$icc_tmp_cert" >/dev/null 2>&1; then
            msg_debug "Certificate found and extracted."
            break
        fi
        sleep 1
        icc_attempts=$((icc_attempts + 1))
    done

    if [ ! -f "$icc_tmp_cert" ]; then
        msg_error "Failed to extract certificate from Caddy container."
        msg_info "Make sure the container is running."
        return 1
    fi

    # Linux
    if [ "$systemOS" = "Linux" ]; then
        add_to_linux_cert_store
    # Mac
    elif [ "$systemOS" = "Darwin" ]; then
        add_to_mac_keyring
    fi

    # Inject Certs
    inject_firefox_cert
    inject_chromium_cert

    # Cleanup
    rm -f "$icc_tmp_cert"
    msg_info "Certificate installation complete. Please restart SIA."
    return 0
}
