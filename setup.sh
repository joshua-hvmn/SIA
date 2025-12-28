#!/bin/bash

# VARIABLES:

options=("CPU Only" "Nvidia GPU" "AMD GPU" "Exit Setup")
fileNames=("compose.cpu.yaml" "compose.nvidia.yaml" "compose.amd.yaml")
changeSetup=0

# FUNCTIONS:

resetFunc () {
    local count=0
    local targetCount=${#fileNames[@]}

    echo "AUTO-RESETTING..."

    # Safety Checks
    for file in "${fileNames[@]}"; do
        if [[ -e "$file" ]] || [[ -e "Archive/$file" ]]; then
            ((count++))
        fi
    done
    [[ -f "compose.yaml" ]] && ((count++))
    if [[ $count -ne $targetCount ]]; then
        echo "ERROR: UNABLE TO AUTO-RESET: a compose file is missing from the SIA system folders!"
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
    echo "ERROR FIXED!"
}

editFunc () {
    local index=$1
    local  selectedFile="${fileNames[$index]}"

    echo "Selected ${options[index]}"

    # Safety Checks    
    if [[ ! -f "$selectedFile" ]]; then
        echo "ERROR: "$selectedFile" isn't in the right place! Maybe you've already done the setup."
        resetFunc
    fi
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

# MAIN SECTION:

echo "Welcome to SIA - Initial Setup"
echo "System Architecture:"
select opt in "${options[@]}"; do
executeFunc "$opt"
done