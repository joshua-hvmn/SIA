# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|


if [[ "${SIA_MAIN_LOADED:-}" != "true" ]]; then
    echo "Error: This script is a component of SIA and cannot be run directly."
    echo "Please run: ./sia"
    exit 1
fi

### Instead of 'for cmd in "${dependencies[@]}"; do..'
# while IFS= read -r cmd || [ -n "$cmd" ]; do
#     if ! command -v "$cmd" >/dev/null 2>&1; then
#         msg_error "$cmd not found"
#     fi
# done < "$SHARE_DIR/dependencies"

## Help :
#  - Accepts one extra argument
#  - Add help menus for new commands by adding them to the case statement

printUsage () {
    local arg="${1:-}"
    case "$arg" in
        down|-d|--down)
            printHelp_down
            ;;
        logs|-l|--logs)
            printHelp_logs
            ;;
        setup|-s|--setup)
            printHelp_setup
            ;;
        download|-dl|--download)
            printHelp_download
            ;;
        env|environment|-env|--environment)
            printHelp_env
            ;;
        *)
            printHelp_general
            ;;
    esac
}

## Good Exit With Message
#  - Pass the message to be displayed or do not pass one to automatically display "Exiting"

exitScriptGoodWithMessage() { 
    local message="${*:-}"
    if [[ -n "$message" ]]; then
        echo "$message" >&2
        exit 0
    else
        exit 0
    fi
}

## Error Exit
#  - Call with the number of the error code in place of "exit #"
#  - Extend by adding to the case statement

errExit () {
    local errorCode="${1:-99}"
    local errorDesc
    case $errorCode in # Don't use code 99
        1)
            errorDesc="Improper usage!"
            ;;
        2)
            errorDesc="Improper configuration!"
            ;;
        3)
            errorDesc="No known number generator!"
            ;;
        404)
            errorDesc="Could not curl replacement config template. Check internet/repo!"
            ;;
        *)
            errorDesc="unknown error code"
            errorCode=99
            ;;
    esac
    msg_warn "Exiting with code $errorCode: $errorDesc" >&2
    exit $errorCode
}

## Check Arrays
#  - Add more dependencies in the dependencies array.
#  - Add more environment variables in the envVars array.
#  - Add additional cases to handle new arrays.
#  - Pass the name of the array you want to check.

checkArray () {
    local arrayName="${1:-dependencies}"
    local arrayRef="${arrayName}[@]"
    case $arrayName in
        dependencies)
            for cmd in "${!arrayRef}"; do
                if ! command -v "$cmd" >/dev/null 2>&1; then
                    msg_error "$cmd not found!" 
                    msg_usage "Make sure it's installed and you have permission to use it."
                    errExit 2
                fi
            done
            ;;
        envVars)
            for entry in "${!arrayRef}"; do
                if [[ "$entry" =~ ^# ]]; then
                    if ! grep -qF "$entry" "$envFile" 2>/dev/null; then
                        [[ -s "$envFile" && -n "$(tail -c 1 "$envFile" 2>/dev/null)" ]] && echo "" >> "$envFile"
                        echo "$entry" >> "$envFile"
                    fi
                else
                    local key="${entry%%=*}"
                    
                    # Logic: If it's a bare key in the list, check if it's "System Protected"
                    if [[ "$entry" != *"="* ]]; then
                        case "$key" in
                            # These are handled by setupFunc and ensureSecretKey
                            # We 'continue' so they stay out of .env until those functions run
                            SEARXNG_SECRET|COMPOSE_FILE|SETUP_COMPLETE|PREVIOUSLY_RUN) continue ;;
                        esac
                    fi

                    # All other variables (like SEARXNG_HOSTNAME=localhost) get processed
                    editEnv "$entry"
                fi
            done
            ;;
        *)
            msg_error "Invalid Array Name: '$arrayName'"
            errExit 1
        ;;
    esac
}

checkDeps() {
    checkArray
    checkArray envVars
}

## Edit Script Arrays
# Usage: editAnyArray "arrayName" "KEY=VALUE" (to add/update)
# Usage: editAnyArray "arrayName" "KEY"      (to remove default overrides and normalize .env editing for that KEY)
# Usage: editAnyArray "arrayName" "KEY"       (to remove)
# Note: this function was vibecoded, I haven't internalized it, there may be problems. I might have the usage wrong.
# - The idea is that it mimics the editEnv function but edits the arrays in the config file.
# - I will refactor into multiple functions eventually so I understand it fully.

# editAnyArray() {
#     local arrayName="$1"
#     local arg="$2"
#     local arg2="${3:-}"
#     local scriptFile="$SIA_HOME_DIR/sia-config.sh"
#     local backupFile="${scriptFile}.bak"
# 
#     [[ -z "$arrayName" || -z "$arg" ]] && { msg_usage "editAnyArray [arrayName] [key] [value]"; return 1; }
# 
#     cp "$scriptFile" "$backupFile" || return 1
# 
#     local lines=()
#     while IFS= read -r line || [[ -n "$line" ]]; do
#         lines[${#lines[@]}]="$line"
#     done < "$scriptFile"
# 
#     local start_idx=-1 end_idx=-1
#     local i
#     for i in "${!lines[@]}"; do
#         # Dynamically match the array name passed as $1
#         if [[ "${lines[i]}" =~ ^[[:space:]]*${arrayName}=\( ]]; then
#             start_idx=$i
#         elif [[ $start_idx -ge 0 && "${lines[i]}" =~ ^[[:space:]]*\) ]]; then
#             end_idx=$i
#             break
#         fi
#     done
# 
#     [[ $start_idx -lt 0 || $end_idx -lt 0 ]] && { 
#         msg_error "Array $arrayName not found in $scriptFile"; 
#         rm -f "$backupFile"; return 1; 
#     }
# 
#     local base_indent="${lines[start_idx]%%[![:space:]]*}"
#     local indent="${base_indent}    "
#     local remove_mode=0
#     local key entry
# 
#     if [[ "$arg2" == "rm" ]]; then
#         entry="$arg"
#         key="${entry%%=*}"
#         remove_mode=1
#     else
#         entry="$arg"
#         key="${entry%%=*}"
#         remove_mode=0
#     fi
# 
#     local match_idx=-1
#     local j
#     local regex="^[[:space:]]*\"?${key}(=[^\"]*)?\"?[[:space:]]*(#.*)?$"
# 
#     for ((j = start_idx + 1; j < end_idx; j++)); do
#         if [[ "${lines[j]}" =~ $regex ]]; then
#             match_idx=$j
#             break
#         fi
#     done
# 
#     if [[ $remove_mode -eq 1 ]]; then
#         if [[ $match_idx -ne -1 ]]; then
#             local before=("${lines[@]:0:match_idx}")
#             local after=("${lines[@]:match_idx+1}")
#             lines=("${before[@]}" "${after[@]}")
#         fi
#     else
#         if [[ $match_idx -ne -1 ]]; then
#             local current_indent="${lines[match_idx]%%[![:space:]]*}"
#             lines[match_idx]="${current_indent}\"${entry}\""
#         else
#             local before=("${lines[@]:0:end_idx}")
#             local after=("${lines[@]:$end_idx}")
#             lines=("${before[@]}" "${indent}\"${entry}\"" "${after[@]}")
#         fi
#     fi
# 
#     printf "%s\n" "${lines[@]}" > "$scriptFile"
# 
#     if ! bash -n "$scriptFile" >/dev/null 2>&1; then
#         mv "$backupFile" "$scriptFile"
#         return 1
#     fi
#     rm -f "$backupFile"
# }

## envCommand List
#  - pass the name of the array to see a list of options to edit it. Currently this
#    list function only supports the envVars array.
#  - can make this function universal by using an additional arg to indicate which menu options array to choose from, and storing the subfunction names in arrays
#    and calling them based on the index of the selected option menu. That will take some thinking, not necessary for this app. It might be better to 
#    switch to a newer Bash target so I can use associative arrays, but it isn't necessary for this function.
#  - make another SIA command like env to bring up a list of arrays so you can edit the whole config
#    without using the env add command

envCommandListEdit () {
    ## Variables
    local PS3
    local arrayName="${1:-arrayNotDefined}"
    if [[ ! "$(declare -p "$arrayName" 2>/dev/null)" =~ "declare -a" ]]; then
        msg_error "Internal - Array Undefined: $arrayName"
        errExit 99
    fi
    local placeholder="${arrayName}[@]"
    local selector=()
    for item in "${!placeholder}"; do
        [[ "$item" =~ ^# ]] && continue # Skip comments
        selector+=("$item")
    done
    local exitMessage="Configuration changed successfully! Run $scriptName to finalize. Exiting."

    ## Function
    msg_warn "If you add a SEARXNG_SECRET, you must remove it after."
    log 2 "---------------------------------------------------------------------------"
    PS3=$(selMenu_envListSelOne)
    select arg in "${selector[@]}"; do
        [[ "$REPLY" == "x" ]] && break
        if [[ "$arg" == *"="* ]]; then
            # The string contains an equals sign
            local key="${arg%%=*}"
            local value="${arg#*=}"
            # Proceed with overwrite/update logic
        else
            # The string is just a bare key
            local key="$arg"
            local value
            # Proceed with "exists" or "default" logic
        fi
        log 2 "---------------------------------------------------------------------------"
        PS3=$(selMenu_envListChooseAction)
        select opt in "${envCLMenuOptions[@]}"; do # Will need to change if you want to universalize this function. i.e., "${!input}"
            [[ "$REPLY" == "x" ]] && break
            # Check that input is valid
            if [[ "$REPLY" =~ ^[0-9]+$ ]]; then
                if [[ "$REPLY" -le "${#envCLMenuOptions[@]}" ]] && [[ "$REPLY" -ge 1 ]]; then
                    case "$REPLY" in
                        1)
                            read -p "Enter value for $key: " userInput
                            edit_kv "$key" "$userInput" .env
                            startCheck
                            ;;
                        2)
                            edit_kv "$key" "" .env
                            startCheck
                            ;;
                        3)
                            edit_kv rm "$key" .env && checkArray envVars
                            startCheck
                            ;;
                        4)
                            exitScriptGoodWithMessage "Exiting."
                            ;;
                        *)
                            msg_error "Invalid selection"
                            ;;
                    esac
                else
                    msg_error "Invalid Selection: $REPLY"
                    msg_usage "Enter a number between 1 and ${#envCLMenuOptions[@]}"
                fi
            else
                msg_error "Invalid Selection: $REPLY"
                msg_usage "Enter a number between 1 and ${#envCLMenuOptions[@]}"
            fi
        done
        PS3=$(selMenu_envListSelOne)
    done
}

## .env handler command Parser
#  - USAGE:
#  - ./sia env - view list and choose what to do.
#  - ./sia env add [optional name WITH CAUTION] [key] [value]
#    - If you define a name, it will edit the values in the array if it exists, 
#    - for example, 'dependencies' or 'fileNames'. Use caution!

envCommand () {
    local firstArg="${1:-list}"
    local arrayName="${2:-envVars}"
    local key="${3:-}"
    local value="${4:-}"
    local toCheck=( "key" "value" )
    case $firstArg in
        list|-l|--list)
            envCommandListEdit envVars
            ;;
        add|-a|--add)
            # Make sure chosen array can be edited
            local validArr=0
            for arr in "${configArrays[@]}"; do
                [[ "$arrayName" = "$arr" ]] && validArr=1 && break
            done
            if [[ "$validArr" -eq 0 ]]; then
                msg_error "'$arrayName' is not an editable array."
                msg_info "Allowed arrays: ${configArrays[*]}"
                errExit 1
            fi
            # Make sure args defined
            for item in "${toCheck[@]}"; do
                if [[ -n "$item" ]]; then
                    msg_error "Please define a $item. Make sure key/value are separate."
                    msg_usage "$scriptName env add <key> <value>"
                    errExit 1
                fi
            done
            editEnv "$key=$value"
            msg_success "Successfully added/updated '$key=$value' in array '$arrayName'."
            msg_info "Run $scriptName to apply changes."
            ;;
        rm|-rm|--remove)
            msg_info "Shortcut planned"
            ;;
    esac
}

## Make temp file
#  - This is necessary for security due to storing secrets in the .env
#  - Temp env must not be leaked.

make_temp() {
    mktmp_target="$1"

    if command -v mktemp >/dev/null/ 2>&1; then
        mktmp_target=$()
    elif [ -z "$" ]; then
    fi


}

## Key Value File Editor
#  - Usage: edit_kv [rm] <key> <value (if not rm)> <file to edit>
#  - inserts update at end or if rm mode, doesn't - deleting it
#  - example delete: edit_kv rm "KEY" .env
#  - example update: edit_kv "KEY" "VALUE" .env

edit_kv() {
    [ $# -eq 3 ] || return 2
    declare ekv_dir ekv_ekey ekv_tmp ekv_target ekv_value
    ekv_rm=0
    case "$1" in
        rm)
            rm=1
            shift
            ;;
    esac
    ekv_key="$1"
    if [ "$ekv_rm" -eq 1 ]; then
        ekv_target="$2"
    else
        ekv_value="$2"
        ekv_target="$3"
    fi
    

    # Checks
    [ -n "$ekv_target" ] || return 1
    ekv_dir=$(dirname "$target")
    [ -d "$ekv_dir" ] || return 1
    [ -w "$ekv_dir" ] || return 1
    # Create file if missing
    [ -f "$ekv_target" ] || touch -- "$ekv_target" 2>/dev/null || return 1

    # Convert strings to escape strings
    ekv_ekey=$(printf '%s' "$ekv_key" | sed 's/[][\/.^$*]/\\&/g')

    # make temp
    if command -v mktemp >/dev/null 2>&1; then
        ekv_tmp=$(mktemp -- "$ekv_target.XXXXXX") || return 1
    elif printf '%s' | grep '^[0-9]*$' >/dev/null 2>&1; then
        ekv_tmp="${ekv_target}.${$}$(date +%s 2>/dev/null || echo 0)"
    else
        ekv_tmp="${ekv_target}.$$"
    fi
    # POSIX version: (?)
#    ekv_tmp="${ekv_target}.$$" : > "$ekv_tmp" || return 1

    # Filter old key
    grep -v "^${ekv_ekey}=" -- "$ekv_target" 2>/dev/null > "$ekv_tmp" || :

    # new line
    if [ -s "$ekv_tmp" ]; then
        if [ -n "$(tail -c 1 "$ekv_tmp" 2>/dev/null)" ]; then
            printf "\n" >> "$ekv_tmp"
        fi
    fi

    # Upsert new value
    if [ "$ekv_rm" -eq 0 ]; then
        printf '%s=%s\n' "$ekv_key" "$ekv_value" >> "$ekv_tmp" || {
            rm -f -- "$ekv_tmp"
            return 1
        }
    fi

    # Swap
    mv -f -- "$ekv_tmp" "$ekv_target" || {
        rm -f -- "$ekv_tmp"
        return 1
    }
}

## .env editor
#  - Pass "KEY=VALUE" to update the VALUE or append if missing.
#  - Pass "VALUE" to just write it to the .env
#  - Ensures new line and creates an .env if necessary
#  - DEV NOTE: my gut says this function might be a little too simple with the addition of the other env editor functions.

editEnv () {
    local entry="$1"
    local key="${entry%%=*}" # Extracts everything before the '='
    local value="${entry#*=}"
    local envFileLocal="$envFile"

    local mode="bare"
    [[ "$entry" == *"="* ]] && mode="enforce"

    # Create .env if it doesn't exist
    touch "$envFileLocal"

    # Check if "KEY=VALUE" exists and create or edit it
    if grep -q "^${key}=" "$envFileLocal" 2>/dev/null; then
        if [[ "$mode" == "enforce" ]]; then
            # Update if "KEY=VALUE" exists
#            echo "$key exists in the "$envFileLocal" file. Modifying..."
            grep -v "^${key}=" "$envFileLocal" > "${envFileLocal}.tmp"
            echo "$key=$value" >> "${envFileLocal}.tmp"
            mv "${envFileLocal}.tmp" "$envFileLocal"
        fi
        return 0
    else
        # Append "KEY=VALUE" if it is missing
        [[ -s "$envFileLocal" && -n "$(tail -c 1 "$envFileLocal" 2>/dev/null)" ]] && echo "" >> "$envFileLocal"
        if [[ "$mode" == "enforce" ]]; then
            echo "$key=$value" >> "$envFileLocal"
        else
            echo "$key=" >> "$envFileLocal"
        fi
    fi
}

## Secret Key
# - Checks if a secret key exists and randomly generate one if it doesn't
# - Tries in this order: openssl, od, python3, cksum
# - Nested conditional make this annoying to extend, but it shouldn't need to be extended.

ensureSecretKey () {
    # Check if key exists and generate one if it doesn't
    [ "$1" = "update" ] && local mode="$1"
    touch "$envFile"
    if ! grep -q "^SEARXNG_SECRET=" "$envFile" 2>/dev/null || "$mode" = "update" ; then
        msg_debug "Generating secret key..."
        local secretKey
        # Generate the key
        # Try OpenSSL :
        if command -v openssl >/dev/null 2>&1; then
            secretKey=$(openssl rand -hex 32)
        # Try od (POSIX) :
        elif command -v od >/dev/null 2>&1; then
            secretKey=$(od -An -N32 -tx1 < /dev/urandom | tr -d '[:space:]')
        else
            # Try Python :
            if command -v python3 >/dev/null 2>&1; then
                secretKey=$(python3 -c 'import secrets; print(secrets.token_hex(32))' 2>/dev/null || true)
            fi
            # Error out if no easy way to generate a secure key :
            if [[ -z "$secretKey" ]]; then
                msg_error "Couldn't find a way to generate a truly random number!"
                msg_debug "$appName tried OpenSSL, od, and python3!"
                msg_info "Please install OpenSSL and try again or manually add a 32 byte 64 digit hex key to the $envFile file."
                errExit 3
            fi
        fi
        # Append to .env:
        keyPrefix=${secretKey:0:5}
        msg_info "Secret key beginning with '$keyPrefix' was generated and injected into the .env."

        edit_kv "SEARXNG_SECRET" "$secretKey" .env
        return 0
    fi
}

## Setup :
# - Pass 1 after calling to prevent inbuilt auto-restart
# - Asks user to select which compose file to use.
# - Checks for or generates secret key with ensureSecretKey
# - Stack will restart automatically when you select or change a setup.

setupFunc () {
    local dontRestart="${1:-0}"

    PS3=$(selMenu_processorMenu)
    select opt in "${options[@]}"; do
        [[ "$REPLY" == "x" ]] && exitScriptGoodWithMessage
        # Check that input is valid
        if [[ "$REPLY" =~ ^[0-9]+$ ]]; then
            if [[ "$REPLY" -le "${#options[@]}" ]] && [[ "$REPLY" -ge 1 ]]; then
                case "$opt" in # Only leaving this in case I want to add options not related to fileNames like the old exit option.
                    *)
                        local index="$((REPLY-1))"
                        # Check menu choice is associated with a file name
                        if [[ -n "${fileNames[index]}" ]]; then
                            local selectedFile=${fileNames[index]}
                            msg_debug "Selected: $REPLY: $opt ($selectedFile). Making sure it's present..."
                            # Check file is present
                            if [[ ! -f $selectedFile ]]; then
                                msg_error "YAML file $selectedFile not found!"
                                errExit 2
                            fi
                            msg_debug "YAML found!"
                            # Create or Update .env
                            edit_kv "COMPOSE_FILE" "$selectedFile" .env
                            ensureSecretKey
                            edit_kv "SETUP_COMPLETE" "true" .env
                            msg_debug "Configuration saved to "$envFile"."

                            # Check if previously run / need to restart
                            if [[ $dontRestart -eq 0 ]] && grep -q "^PREVIOUSLY_RUN=true" "$envFile" 2>/dev/null; then
                                msg_debug "Previous run detected: automatically restarting..."
                                startCheck
                            fi
                            break
                        else
                            msg_error "Invalid selection"
                        fi
                esac
            else
                msg_error "Invalid Selection: $REPLY"
                msg_usage "Try again. Enter a number between 1 and ${#options[@]}"
            fi
        else
            msg_error "Invalid Selection: $REPLY"
            msg_usage "Try again. Enter a number between 1 and ${#options[@]}"
        fi
    done
}

## Start :
# - Checks for valid configuration by checking the .env
# - Repairs broken/missing .env files.
# - Checks for previous run for appropriate start/restart messaging.

startCheck () {
    # Check if a compose file is defined, if not: setup, else start/restart
    if [[ ! -s "$envFile" ]] || ! grep -q "^SETUP_COMPLETE=true" "$envFile" 2>/dev/null; then
        startMes_firstStart
        setupFunc 1
    fi
    # Re-source modified config
#    source "$SIA_HOME_DIR/$configScript"
    # Validate state
#    checkArray envVars
    if grep -q "^PREVIOUSLY_RUN=true" "$envFile" 2>/dev/null; then
        msg_success "Valid configuration - Restarting!"
    else
        msg_success "Valid configuration - Starting for the first time, enjoy!"
        # Append to .env:
        if ! grep -q "^PREVIOUSLY_RUN=true" "$envFile" 2>/dev/null; then
            edit_kv "PREVIOUSLY_RUN" "true"
        fi
    fi
    docker compose up -d --force-recreate
    startMes_startDone
    return 0
}
