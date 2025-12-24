#!/bin/bash

echo "Welcome to SIA - Initial Setup"
echo "System Architecture:"
options=("CPU Only" "Nvidia GPU" "AMD GPU")
select opt in "${options[@]}"; do
    case "$opt" in
        "CPU Only")
            echo "CPU"
            ;;
        "Nvidia GPU")
            echo "Nvidia"
            ;;
        "AMD GPU")
            echo "AMD"
            ;;
        *)
            echo "Invalid choice, try again."
            ;;
    esac
done