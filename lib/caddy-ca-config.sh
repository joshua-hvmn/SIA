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
        msg_debug "Detected Linux, attempting to install to system store..."

        ## Install
        # Debian / Ubuntu
        if command -v update-ca-certificates >/dev/null 2>&1; then
            sudo cp "$icc_tmp_cert" "/usr/local/share/ca-certificates/sia-root.crt"
            sudo update-ca-certificates 2>&1 | grep -v "ca-certificates.crt"
    
        # Fedora / RHEL
        elif command -v update-ca-trust >/dev/null 2>&1; then
            sudo cp "$icc_tmp_cert" "/etc/pki/ca-trust/source/anchors/sia-root.crt"
            sudo update-ca-trust
    
        # Arch (p11-kit)
        elif command -v trust >/dev/null 2>&1; then
            sudo trust anchor --store "$icc_tmp_cert"
        fi

        ## Configure
        # Firefox
        if [ -d "/etc/firefox" ]; then
             msg_debug "Applying Firefox enterprise policy..."
             sudo mkdir -p /etc/firefox/policies
             cat <<EOF | sudo tee /etc/firefox/policies/policies.json >/dev/null
{
  "policies": {
    "Certificates": { "ImportEnterpriseRoots": true }
  }
}
EOF
        fi
        # Chromium
        if command -v certutil >/dev/null 2>&1; then
            icc_target_db="sql:$REAL_HOME/.pki/nssdb"
            if [ -d "$REAL_HOME/.pki/nssdb" ]; then
                msg_debug "Updating Chromium DB at: $icc_target_db"
                # Clean previous certs
                certutil -d "$icc_target_db" -D -n "SIA Root" 2>/dev/null || true
                # Install
                certutil -d "$icc_target_db" -A -t "C,," -n "SIA Root" -i "$icc_tmp_cert"
            fi
        else
            msg_error "Chromium detected but 'certutil' is missing."
            msg_info "FIX: 'sudo apt install libnss3-tools' (Debian/Ubuntu), or 'sudo dnf install nss-tools' (Fedora)"
            msg_info "Then regenerate the secret key in the CLI environment menu."
        fi

    # Mac
    elif [ "$systemOS" = "Darwin" ]; then
        msg_debug "Detected macOS, adding to System Keychain..."
        
        sudo security add-trusted-cert \
            -d -r trustRoot \
            -k /Library/Keychains/System.keychain \
            "$icc_tmp_cert"
    fi

    # Cleanup
    rm -f "$icc_tmp_cert"
    msg_info "Certificate installation complete. Please restart SIA."
    return 0
}