# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|

update_docker_images() {
    yes_no "Are you sure? Updating the Docker images may take a while. "
    if [ $? -ne 0 ]; then
        msg_info "Cancelling." && return 0
    fi

    docker compose pull || msg_error "Unable to update"

    yes_no "Do you want to delete the old, unused images? (recommended) "
    if [ $? -eq 0 ]; then
        msg_info "Running sudo docker image prune -f"
        sudo docker image prune -f
    else
        msg_info "Leaving old images."
    fi
}

update_sia() {
    yes_no "Are you sure? Updating $app_name will overwrite any changes to the sia script, the scripts in lib/ and all of share/. "
    if [ $? -ne 0 ]; then
        msg_info "Cancelling." && return 0
    fi

    msg_info "Updating SIA..."
    
    # Try pull
    if git pull origin "$BRANCH"; then
        msg_info "Update successful."
        msg_warn "Please restart the script to apply changes."
        exit 0
    else
        # Force update
        msg_warn "Standard update failed (local changes detected in defaults)."
        msg_warn "Forcing update to match repository..."
        
        git fetch origin "$BRANCH"
        git reset --hard "origin/$BRANCH"
        
        msg_info "Forced update successful."
        msg_warn "Please restart the script to apply changes."
        exit 0
    fi
}