#!/bin/bash

# VARIABLES

fileNames=("compose.cpu.yaml" "compose.nvidia.yaml" "compose.amd.yaml")
scriptWorkingDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# FUNCTIONS

startSetup () {
    echo "Would you like to run the setup script? [Y/n]"
    read -r response

    case "$response" in
        n|N|[nN]o|[nN]O|[nN][oO])
            echo "Exiting..."
            exit
            ;;
        *)
            echo "Running setup..."
            bash "$scriptWorkingDir/setup.sh"
            ;;
    esac
}

stateCheck () {
    local count=0
    local targetCount=${#fileNames[@]}
    local cleanState=1

    # Safety Checks
    for file in "${fileNames[@]}"; do
        if [[ ( -f "$file" && ! -f "Archive/$file" ) || ( -f "Archive/$file" && ! -f "$file" ) ]]; then
            ((count++))
        fi
        [[ -f "Archive/$file" ]] && cleanState=0
    done
    if [[ $count -ne $targetCount ]]; then
        echo "ERROR: UNABLE TO AUTO-RESET: $((targetCount - count)) compose file[s] is/are missing from the SIA system folders!"
        echo "Please check the Wiki for troubleshooting advice."
        exit
    else
        case "$cleanState" in
            1)
                echo "It seems you haven't done the initial setup yet!"
                startSetup
                ;;
            0)
                echo "The compose file is missing and something has been changed, but the setup script might be able to fix it!"
                startSetup
                ;;
            *)
                echo "ERROR: I'm not sure what went wrong!"
                exit
                ;;
        esac
    fi
}

composeCheck () {
    if [[ ! -f "compose.yaml" ]]; then
        stateCheck
    else
        if [[ ! -d "ollama" ]]; then
            echo Compose file present - Starting!
        else
            echo "Compose file present - Restarting!"
        fi
        docker compose up -d --force-recreate
    fi
}

# MAIN
echo "SIA Start Script"
echo "Checking for a compose file!"
composeCheck