#!/bin/bash

# VARIABLES:

options=("CPU Only" "Nvidia GPU" "AMD GPU" "Exit Setup")
fileNames=("compose.cpu.yaml" "compose.nvidia.yaml" "compose.amd.yaml")

# FUNCTIONS:

editFunc () {
    local index=$1
    local  selectedFile="${fileNames[$index]}"

    echo "Selected ${options[index]}"

    # Safety Checks    
    if [[ ! -f "$selectedFile" ]]; then
        echo "ERROR: "$selectedFile" not found! Maybe you've already done the setup."
        echo "Check the Wiki for troubleshooting advice."
        exit
    fi
    mkdir -p "Archive"

    # Rename File
    echo "Renaming $selectedFile to compose.yaml"
    mv "$selectedFile" "compose.yaml"

    # Move Remaining Files
    echo "Moving extra files to Archive"
    for i in "${!fileNames[@]}"; do
        if [[ -f "${fileNames[i]}" ]]; then
            mv "${fileNames[$i]}"  "Archive/"
        fi
    done
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