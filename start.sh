#!/bin/bash

# VARIABLES

options=("CPU Only" "Nvidia GPU" "AMD GPU" "Exit Setup")
fileNames=("compose.cpu.yaml" "compose.nvidia.yaml" "compose.amd.yaml")
scriptWorkingDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
changeSetup=0
firstArg="${1:-start}"
shift || true

# FUNCTIONS

## Help :

printUsage () {
    local arg=$1
    case "$arg" in
        down|-d|--down)
            cat << EOF
Usage: ./start.sh -d <command>

Command being run: docker compose down <command>

Commands:
    (no argument)       None, leaves volumes and app images (default).
    --volumes | -v      Remove volumes named in the compose file.
    --remove-orphans    Remove containers for services no longer in the compose (i.e. you modify it).
    --rmi               Remove images used by services.
    --help | -h         Show the inbuilt Docker help message (not this one).

Pass a 2nd arg to pass an arg to the underlying docker command.

EOF
            ;;
        logs|-l|--logs)
            cat << EOF
Usage: ./start.sh -l <command>

Command being run: docker compose logs <command>

Commands:
    (no argument)     -f, full logs, CTRL+C to stop (default)
    <container name>  View logs for that container.
    --timestamps | -t Show timestamps for each file.
    --no-color        Black and white.
    --no-log-prefix   Omit service name/container from each log line.
    help | -h         Show the inbuilt Docker help message (not this one).

Pass a 2nd arg to pass an arg to the underlying docker command.

EOF
            ;;
        *)
            cat << EOF
Usage: ./start.sh <command>

Commands:
    (no argument)    Start or restart the SIA stack (default)
    setup | -s       Run or rerun the setup wizard to change the setup
    down | -d        Stop the SIA stack. Accepts an additional argument.
    logs | -l        View relevant logs Accepts an additional argument.
    download | -dl   Download an Ollama model. Requires an additional argument.
    help | -h        Show this help message

Pass a 2nd arg to pass an arg to the underlying docker command.

Examples:
    ./start.sh                 Starts the containers. On first start, runs setup.
    ./start.sh setup           Runs setup, for changing which setup you're using.
    ./start.sh -d              Stops all SIA containers.
    ./start.sh --help          Shows the help message.
    ./start.sh -l --verbose    Shows the logs and passes the --verbose argument.
EOF
            ;;
    esac
}

## Setup :

resetFunc () {
    local count=0
    local targetCount=${#fileNames[@]}

    echo "Auto-resetting..."

    # Safety Checks
    for file in "${fileNames[@]}"; do
        if [[ ( -f "$file" && ! -f "Archive/$file" ) || ( -f "Archive/$file" && ! -f "$file" ) ]]; then
            ((count++))
        fi
    done
    [[ -f "compose.yaml" ]] && ((count++))
    if [[ $count -ne $targetCount ]]; then
        echo "ERROR: UNABLE TO AUTO-RESET: $((targetCount - count)) compose file[s] is/are missing from the SIA system folders!"
        echo "Please check the Wiki for troubleshooting advice."
        exit
    fi

    # Reset File Names
    for file in "${fileNames[@]}"; do
        if [[ ! -f "Archive/$file" ]]; then
            [[ -f "compose.yaml" ]] && mv "compose.yaml"  "$file"
            echo "Renamed compose.yaml to $file and restored other files from the archive."
            break
        fi
    done
    for file in "${fileNames[@]}"; do
        [[ -f "Archive/$file" ]] && mv "Archive/$file"  .
    done

    changeSetup=1
    echo "Reset successful!"
}

editFunc () {
    local index=$1
    local  selectedFile="${fileNames[$index]}"

    echo "Selected ${options[index]}"

    # Safety Checks
    for file in "${fileNames[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "Previous setup detected: "$file" isn't in the right place!"
            resetFunc
        fi
    done
    mkdir -p "Archive"

    # Rename File
    mv "$selectedFile" "compose.yaml"
    echo "Renamed $selectedFile to compose.yaml"

    # Move Remaining Files
    for i in "${!fileNames[@]}"; do
        [[ -f "${fileNames[$i]}" ]] && mv "${fileNames[$i]}"  "Archive/"
    done
    echo "Moved extra files to Archive"
    echo "SIA Initial Setup Complete"
    [[ $changeSetup = 1 ]] && echo "If you've run SIA before on the previous architecture, run ./start.sh to restart on the new one."
    exit
}

executeFunc () {
    case "$1" in
        "CPU Only")
            editFunc 0
            ;;
        "Nvidia GPU")
            editFunc 1
            ;;
        "AMD GPU")
            editFunc 2
            ;;
        "Exit Setup")
            echo "Exiting."
            exit
            ;;
        *)
            echo "Invalid choice, select a number between 1 and 4."
            ;;
    esac
}

setupFunc () {
    echo "Please select your processor type."
    echo "System Architecture:"
    select opt in "${options[@]}"; do
    executeFunc "$opt"
    done
}

## Start :

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
            setupFunc
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

# Main

case "$firstArg" in
    start|"")
        # Default
        echo "SIA Startup"
        echo "Checking for a compose file!"
        composeCheck
        ;;
    setup|-s|--setup)
        setupFunc
        ;;
    help|-h|--help)
        printUsage "$1"
        ;;
    down|-d|--down)
        if [[ $1 ]]; then
            docker compose down $1
        else
            docker compose down
        fi
        ;;
    logs|-l|--logs)
        if [[ $1 ]]; then
            docker compose logs $1
        else
            docker compose logs -f
        fi
        ;;
    download|-dl|--download)
        if [[ $1 ]]; then
            docker exec ollama ollama run $1
            echo "$1 is ready to use!"
            exit
        else
            echo "Please enter an Ollama model code to download (i.e. llama3.2:1b)"
            exit
        ;;
    *)
        echo "ERROR: Unknown command: $firstArg"
        printUsage
        exit
        ;;
esac