#!/bin/bash

# VARIABLES:

options=("CPU Only" "Nvidia GPU" "AMD GPU")
fileNames=("compose.cpu.yaml" "compose.nvidia.yaml" "compose.amd.yaml")

# FUNCTIONS:

editFunc () {
    mv ${fileNames[$1]} "compose.yaml"
    unset 'fileNames[$1]'
    fileNames=("${fileNames[@]}")
    for i in "${!fileNames[@]}"; do
        mv "$fileNames" "Archive/"
        unset 'fileNames[$i]'
        fileNames=("${fileNames[@]}")
    done
}

executeFunc () {
    case "$1" in
        "CPU Only")
            editFunc 0
            exit
            ;;
        "Nvidia GPU")
            editFunc 1
            exit
            ;;
        "AMD GPU")
            editFunc 2
            exit
            ;;
        *)
            echo "Invalid choice, select a number between 1 and 3."
            ;;
    esac
}

# MAIN SECTION:

echo "Welcome to SIA - Initial Setup"
echo "System Architecture:"
select opt in "${options[@]}"; do
executeFunc "$opt"
done