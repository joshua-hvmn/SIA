#!/usr/bin/env bash

# ADDITIONAL COMMIT SO I CAN COME BACK TO SOME LOGIC
# For example, the yes/no menu in the startSetup function.
# will clean in next commit

# VARIABLES

options=("CPU Only" "Nvidia GPU" "AMD GPU" "Exit Setup")
fileNames=("compose.cpu.yaml" "compose.nvidia.yaml" "compose.amd.yaml")
scriptWorkingDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
changeSetup=0
firstArg="${1:-start}"
shift || true
scriptName="./start.sh"

cd $scriptWorkingDir

# FUNCTIONS

## Secret Key

ensureSecretKey () {
    if ! grep -q "SEARXNG_SECRET" .env 2>/dev/null; then
        echo "Generating secret key..."
        local secretKey=$(openssl rand -hex 32)

        echo "SEARXNG_SECRET=$secretKey" >> .env
    fi
}

#genSecretKey () {
#    if [[ ! -f ".siaSecretKey" ]]; then
#        echo "Generating secret key..."
#        openssl rand -hex 32 > .siaSecretKey
#    fi
#
#    local secretKey=$(cat .siaSecretKey)
#
#    if [[ "$OSTYPE" == "darwin"* ]]; then
#        sed -i '' "s/ultrasecretkey/$secretKey/g" searxng/settings.yml # Mac
#    else
#        sed -i "s/ultrasecretkey/$secretKey/g" searxng/settings.yml   # Linux
#    fi
#}

## Help :

printUsage () {
    local arg=$1
    case "$arg" in
        down|-d|--down)
            cat << EOF
Usage: $scriptName -d <command>

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
Usage: $scriptName -l <command>

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
Usage: $scriptName <command>

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

#resetFunc () {
#    local count=0
#    local targetCount=${#fileNames[@]}
#
#    echo "Auto-resetting..."
#
#    # Safety Checks
#    for file in "${fileNames[@]}"; do
#        if [[ ( -f "$file" && ! -f "Archive/$file" ) || ( -f "Archive/$file" && ! -f "$file" ) ]]; then
#            ((count++))
#        fi
#    done
#    [[ -f "compose.yaml" ]] && ((count++))
#    if [[ $count -ne $targetCount ]]; then
#        echo "ERROR: UNABLE TO AUTO-RESET: $((targetCount - count)) compose file[s] is/are missing from the SIA system folders!"
#        echo "Please check the Wiki for troubleshooting advice."
#        exit
#    fi
#
#    # Reset File Names
#    for file in "${fileNames[@]}"; do
#        if [[ ! -f "Archive/$file" ]]; then
#            [[ -f "compose.yaml" ]] && mv "compose.yaml"  "$file"
#            echo "Renamed compose.yaml to $file and restored other files from the archive."
#            break
#        fi
#    done
#    for file in "${fileNames[@]}"; do
#        [[ -f "Archive/$file" ]] && mv "Archive/$file"  .
#    done
#
#    changeSetup=1
#    echo "Reset successful!"
#}
#
#editFunc () {
#    local index=$1
#    local  selectedFile="${fileNames[$index]}"
#
#    echo "Selected ${options[index]}"
#
#    # Safety Checks
#    for file in "${fileNames[@]}"; do
#        if [[ ! -f "$file" ]]; then
#            echo "Previous setup detected: "$file" isn't in the right place!"
#            resetFunc
#        fi
#    done
#    mkdir -p "Archive"
#
#    # Rename File
#    mv "$selectedFile" "compose.yaml"
#    echo "Renamed $selectedFile to compose.yaml"
#
#    # Move Remaining Files
#    for i in "${!fileNames[@]}"; do
#        [[ -f "${fileNames[$i]}" ]] && mv "${fileNames[$i]}"  "Archive/"
#    done
#    echo "Moved extra files to Archive"
#    echo "SIA Initial Setup Complete"
#    [[ $changeSetup = 1 ]] && echo "If you've run SIA before on the previous architecture, run $scriptName to restart on the new one."
#}
#
#executeFunc () {
#    case "$1" in
#        "CPU Only")
#            editFunc 0
#            ;;
#        "Nvidia GPU")
#            editFunc 1
#            ;;
#        "AMD GPU")
#            editFunc 2
#            ;;
#        "Exit Setup")
#            echo "Exiting."
#            exit
#            ;;
#        *)
#            echo "Invalid choice, select a number between 1 and 4."
#            ;;
#    esac
#}

setupFunc () {
    echo "Please select your processor type."
    echo "System Architecture:"
    select opt in "${options[@]}"; do
        local index="$((REPLY-1))"

        echo "You chose $opt at index $index", AKA $selectedFile
        case "$opt" in
            "Exit Setup")
                echo "Exiting."
                exit
                ;;
            *)
                if [[ -n "${fileNames[index]}" ]]; then
                    local selectedFile=${fileNames[index]}
                    echo "Selected: $REPLY: $opt "$selectedFile" "

                    # Create or Update .env
                    if grep -q "COMPOSE_FILE=" .env 2>/dev/null; then
                        sed -i.bak "s|^COMPOSE_FILE=.*|COMPOSE_FILE=$selectedFile|" .env && rm .env.bak
                    else
                        echo "COMPOSE_FILE=$selectedFile" >> .env
                    fi

                    ensureSecretKey
                    echo "Configuration saved to .env."
                    break
                else
                    echo "Invalid selection"
                fi
        esac
#        executeFunc "$opt"
        break
    done
}

## Start :

#startSetup () {
#    echo "Would you like to run the setup? [Y/n]"
#    read -r response
#
#    local input="${response:-y}"
#
#    case "$input" in
#        n|N|[nN]o|[nN]O|[nN][oO])
#            echo "Exiting..."
#            exit
#            ;;
#        [yY]|[yY][eE][sS])
#            echo "Running setup..."
#            setupFunc
#            ;;
#        *)
#            echo "Invalid choice, exiting."
#            exit   
#            ;;
#    esac
#}

#stateCheck () {
#    local count=0
#    local targetCount=${#fileNames[@]}
#    local cleanState=1
#
#    # Safety Checks
#    for file in "${fileNames[@]}"; do
#        if [[ ( -f "$file" && ! -f "Archive/$file" ) || ( -f "Archive/$file" && ! -f "$file" ) ]]; then
#            ((count++))
#        fi
#        [[ -f "Archive/$file" ]] && cleanState=0
#    done
#    if [[ $count -ne $targetCount ]]; then
#        echo "ERROR: UNABLE TO AUTO-RESET: $((targetCount - count)) compose file[s] is/are missing from the SIA system folders!"
#        echo "Please check the Wiki for troubleshooting advice."
#        exit
#    else
#        case "$cleanState" in
#            1)
#                echo "It seems you haven't done the initial setup yet!"
#                startSetup
#                genSecretKey
#                exit
#                ;;
#            0)
#                echo "The compose file is missing and something has been changed, but the setup script might be able to fix it!"
#                startSetup
#                exit
#                ;;
#            *)
#                echo "ERROR: I'm not sure what went wrong!"
#                exit
#                ;;
#        esac
#    fi
#}

#composeCheck () {
#    if [[ ! -f "compose.yaml" ]]; then
#        stateCheck
#    else
#        if [[ ! -d "ollama" ]]; then
#            echo Compose file present - Starting!
#        else
#            echo "Compose file present - Restarting!"
#        fi
#        docker compose up -d --force-recreate
#    fi
#}

startCheck () {
    if [[ ! -f .env ]] || ! grep -q "COMPOSE_FILE" .env; then
        echo "First time setup detected (or missing configuration)"
        setupFunc
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
        echo "Checking configuration!"
        startCheck
        ;;
    setup|-s|--setup)
        setupFunc
        exit
        ;;
    help|-h|--help)
        printUsage "$1"
        ;;
    down|-d|--down)
            echo "Stopping SIA..."
            docker compose down "$@"
        ;;
    logs|-l|--logs)
        if [[ $# -eq 0 ]]; then
            echo "Showing last 100 logs:"
            docker compose logs --tail 100
        else
            echo "Running 'docker compose logs $@'"
            docker compose logs "$@"
        fi
        ;;
    download|-dl|--download)
        if [[ -z "$(docker compose ps -q ollama 2>/dev/null)" ]]; then
            echo "ERROR: SIA isn't running. Please run $scriptName without arguments."
            exit
        fi
        if [[ $1 ]]; then
            echo "Running docker exec ollama ollama run $@"
            docker exec ollama ollama run "$@"
            echo "$1 is ready to use!"
            exit
        else
            echo "Please enter an Ollama model code to download (i.e. llama3.2:1b)"
            echo "Example: $scriptName download llama3.2:1b"
            exit
        fi
        ;;
    *)
        echo "ERROR: Unknown command: $firstArg"
        printUsage
        exit
        ;;
esac