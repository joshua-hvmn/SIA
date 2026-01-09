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

#checkArray () {
#    local arrayName="${1:-dependencies}"
#    local arrayRef="${arrayName}[@]"
#    case $arrayName in
#        dependencies)
#            for cmd in "${!arrayRef}"; do
#                if ! command -v "$cmd" >/dev/null 2>&1; then
#                    msg_error "$cmd not found!" 
#                    msg_usage "Make sure it's installed and you have permission to use it."
#                    errExit 2
#                fi
#            done
#            ;;
#        envVars)
#            for entry in "${!arrayRef}"; do
#                if [[ "$entry" =~ ^# ]]; then
#                    if ! grep -qF "$entry" "$envFile" 2>/dev/null; then
#                        [[ -s "$envFile" && -n "$(tail -c 1 "$envFile" 2>/dev/null)" ]] && echo "" >> "$envFile"
#                        echo "$entry" >> "$envFile"
#                    fi
#                else
#                    local key="${entry%%=*}"
#                    
#                    # Logic: If it's a bare key in the list, check if it's "System Protected"
#                    if [[ "$entry" != *"="* ]]; then
#                        case "$key" in
#                            # These are handled by setupFunc and ensureSecretKey
#                            # We 'continue' so they stay out of .env until those functions run
#                            SEARXNG_SECRET|COMPOSE_FILE|SETUP_COMPLETE|PREVIOUSLY_RUN) continue ;;
#                        esac
#                    fi
#
#                    # All other variables (like SEARXNG_HOSTNAME=localhost) get processed
#                    editEnv "$entry"
#                fi
#            done
#            ;;
#        *)
#            msg_error "Invalid Array Name: '$arrayName'"
#            errExit 1
#        ;;
#    esac
#}
#

checkDeps() { # update for new architecture
    :
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
#
#envCommandListEdit () {
#    ## Variables
#    local PS3
#    local arrayName="${1:-arrayNotDefined}"
#    if [[ ! "$(declare -p "$arrayName" 2>/dev/null)" =~ "declare -a" ]]; then
#        msg_error "Internal - Array Undefined: $arrayName"
#        errExit 99
#    fi
#    local placeholder="${arrayName}[@]"
#    local selector=()
#    for item in "${!placeholder}"; do
#        [[ "$item" =~ ^# ]] && continue # Skip comments
#        selector+=("$item")
#    done
#    local exitMessage="Configuration changed successfully! Run $scriptName to finalize. Exiting."
#
#    ## Function
#    msg_warn "If you add a SEARXNG_SECRET, you must remove it after."
#    log 2 "---------------------------------------------------------------------------"
#    PS3=$(selMenu_envListSelOne)
#    select arg in "${selector[@]}"; do
#        [[ "$REPLY" == "x" ]] && break
#        if [[ "$arg" == *"="* ]]; then
#            # The string contains an equals sign
#            local key="${arg%%=*}"
#            local value="${arg#*=}"
#            # Proceed with overwrite/update logic
#        else
#            # The string is just a bare key
#            local key="$arg"
#            local value
#            # Proceed with "exists" or "default" logic
#        fi
#        log 2 "---------------------------------------------------------------------------"
#        PS3=$(selMenu_envListChooseAction)
#        select opt in "${envCLMenuOptions[@]}"; do # Will need to change if you want to universalize this function. i.e., "${!input}"
#            [[ "$REPLY" == "x" ]] && break
#            # Check that input is valid
#            if [[ "$REPLY" =~ ^[0-9]+$ ]]; then
#                if [[ "$REPLY" -le "${#envCLMenuOptions[@]}" ]] && [[ "$REPLY" -ge 1 ]]; then
#                    case "$REPLY" in
#                        1)
#                            read -p "Enter value for $key: " userInput
#                            edit_kv "$key" "$userInput" .env
#                            startCheck
#                            ;;
#                        2)
#                            edit_kv "$key" "" .env
#                            startCheck
#                            ;;
#                        3)
#                            edit_kv rm "$key" .env && checkArray envVars
#                            startCheck
#                            ;;
#                        4)
#                            exitScriptGoodWithMessage "Exiting."
#                            ;;
#                        *)
#                            msg_error "Invalid selection"
#                            ;;
#                    esac
#                else
#                    msg_error "Invalid Selection: $REPLY"
#                    msg_usage "Enter a number between 1 and ${#envCLMenuOptions[@]}"
#                fi
#            else
#                msg_error "Invalid Selection: $REPLY"
#                msg_usage "Enter a number between 1 and ${#envCLMenuOptions[@]}"
#            fi
#        done
#        PS3=$(selMenu_envListSelOne)
#    done
#}

does_file_exist() {
    [ $# -eq 1 ] || { msg_error "does_file_exist: exactly one argument required"; errExit 1; }
    [ -f "$1" ] || {
        msg_error "File does not exist: $1"
        errExit 1
    }
}
is_file_readable() {
    [ $# -eq 1 ] || { msg_error "is_file_readable: exactly one argument required"; errExit 1; }
    [ -r "$1" ] || {
        msg_error "Cannot read file: $1"
        errExit 1
    }
}
is_file_empty() {
    [ $# -eq 1 ] || { msg_error "is_file_empty: exactly one argument required"; errExit 1; }
    [ -s "$1" ] || {
        msg_error "File is empty: $1"
        errExit 1
    }
}

## Read menu choice
#  - Usage: read_menu_choice "Description" $lower_bound $upper_bound

read_menu_choice() {
    rdmenu_choice=""
    case "$1" in
        *[!0-9]*) rdmenu_desc="$1"; shift ;;
        *) rdmenu_desc="Select an option from the menu: " ;;
    esac
    rdmenu_lower_bound="$1"
    rdmenu_upper_bound="$2"
    
    while [ -z "$rdmenu_choice" ]; do
        printf '%s' "$rdmenu_desc" >&2
        read -r rdmenu_choice || { msg_error "Failed to read input"; errExit 1; }
        case "$rdmenu_choice" in
            [xX])
                printf 'x'
                return 0
                ;;
            ''|*[!0-9]*)
                msg_usage "Enter a number between $rdmenu_lower_bound and $rdmenu_upper_bound."
                rdmenu_choice=""
                continue
                ;;
            *)
                if [ "$rdmenu_choice" -ge "$rdmenu_lower_bound" ] && [ "$rdmenu_choice" -le "$rdmenu_upper_bound" ]; then
                    printf '%s' "$rdmenu_choice"
                    return 0
                else
                    msg_usage "Enter a number between $rdmenu_lower_bound and $rdmenu_upper_bound."
                    rdmenu_choice=""
                    continue
                fi
                ;;
        esac
    done
}

list_from_file() {
    [ "$#" -eq 1 ] || return 2
    lff_file="$1"
    
    does_file_exist "$lff_file"
    is_file_readable "$lff_file"
    is_file_empty "$lff_file"
    
    sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$lff_file" | nl -s ') ' -w 1
}

env_command_list_all() {
    envcl_vars_count=$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$envFile" | wc -l)
    [ "$envcl_vars_count" -eq 0 ] && { msg_error "No variables found after filtering."; errExit 1; }

    msg_header ${YELLOW} "Environment Variables"
    list_from_file "$envFile"
    envcl_choice=$(read_menu_choice "Choose a variable (1-$envcl_vars_count or x to exit): " 1 "$envcl_vars_count")

    msg_header ${YELLOW} "Select an action"
    msg_col "1)" "Edit value"
    msg_col "2)" "Edit key"
    msg_col "3)" "Edit key AND value"
    msg_col "4)" "Remove"
    envcl_action=$(read_menu_choice "Action (1-4 or x to exit): " 1 4)

    if [ "$envcl_choice" = 'x' ] || [ "$envcl_action" = 'x' ]; then
        msg_info "Exiting"
        exit 0
    fi

    envcl_key=$(
        sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$envFile" |
        sed -n "${envcl_choice}p" |
        sed 's/=.*//'
    )
    envcl_value=$(
        sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$envFile" |
        sed -n "${envcl_choice}p" |
        sed 's/^[^=]*=//'
    )

    case "$envcl_action" in
        1)
            msg_normal "Enter a new value: "
            read -r envcl_new_value
            edit_kv "$envcl_key" "$envcl_new_value" "$envFile"
            ;;
        2)
            msg_normal "Enter a new key: "
            read -r envcl_new_key
            edit_kv "$envcl_new_key" "$envcl_value" "$envFile"
            ;;
        3)
            msg_normal "Enter a new key: "
            read -r envcl_new_key
            msg_normal "Enter a new value: "
            read -r envcl_new_value
            edit_kv "$envcl_new_key" "$envcl_new_value" "$envFile"
            ;;
        4)
            msg_warn "Are you sure you want to remove the $envcl_key from the environment? [y/N]"
            read -r envcl_confirm
            case "$envcl_confirm" in
                [yY]|[yY][eE][sS])
                    edit_kv rm "$envcl_key" "$envFile"
                    msg_info "$envcl_key is deleted from the $envFile file."
                    ;;
                *)
                    msg_info "Okay, leaving $envcl_key as it is."
                    return 0
                    ;;
            esac
            ;;
    esac
}

env_command_add() {
    envca_key="${1:-}"
    envca_val="${2:-}"

    # Normalize keys (error if bad)
    case "$envca_key" in
        *[!a-zA-Z0-9_]*)
            msg_error "Key contains invalid characters. Use only alphanumeric characters and underscores."
            errExit 1
            ;;
        "")
            msg_error "Key cannot be empty."
            errExit 1
            ;;
    esac

    # Check VALUE defined
    if [ -z "$envca_val" ]; then
        msg_error "You must define both key and value to add to the environment variables, please try again."
        msg_usage "$scriptName env add <key> <value>"
        errExit 1
    fi

    # Edit the .env
    edit_kv "$envca_key" "$envca_val" "$envFile"
    msg_success "Added $envca_key=$envca_val to the $envFile file!"
    msg_info "Run $scriptName to restart."
}

## .env handler command Parser
#  - USAGE:
#  - ./sia env - view list and choose what to do.
#  - ./sia env add [optional name WITH CAUTION] [key] [value]
#    - If you define a name, it will edit the values in the array if it exists, 
#    - for example, 'dependencies' or 'fileNames'. Use caution!

envCommand () {
    envcm_cmd="${1:-list}"
    envcm_key="${2:-}"
    envcm_val="${3:-}"
    case $envcm_cmd in
        list|-l|--list)
            # envCommandListEdit envVars
            env_command_list_all
            ;;
        add|-a|--add)
            # Make sure args defined
            if [ -z "$envcm_key" ] || [ -z "$envcm_val" ]; then
                msg_error "Both key and value are required."
                msg_usage "$scriptName env add <key> <value>"
                errExit 1
            fi

            # Edit the .env
            edit_kv "$envcm_key" "$envcm_val" "$envFile"
            msg_success "Added $envcm_key=$envcm_val to the $envFile file!"
            msg_info "Run $scriptName to restart."
            ;;
        rm|-rm|--remove)
            # Make sure args defined
            if [ -z "$envcm_key" ]; then
                msg_error "Did not define key to delete."
                msg_usage "$scriptName env rm <key>"
                errExit 1
            fi
            if [ "${verbosity:-0}" -gt 0 ]; then
                msg_warn "Remove $envcm_key=$envcm_val from the environment? [y/N]"
                read -r envcm_confirm
            else
                envcm_confirm="y"
            fi
            case "$envcm_confirm" in
                [yY]|[yY][eE][sS])
                    edit_kv rm "$envcm_key" "$envFile"
                    msg_success "Removed $envcm_key=$envcm_val from the $envFile file!"
                    msg_info "Run $scriptName to restart."
                    ;;
                *)
                    msg_info "Okay, leaving $envcm_key as it is."
                    return 0
                    ;;
            esac
            ;;
    esac
}

## Make temp file
#  - This is necessary for security due to storing secrets in the .env
#  - Temp env must not be leaked.
# USAGE: make_temp <file>
# Returns temp file, use command substitution: `prefix_tmp=$(make_temp "file.txt") || return 1`

make_temp() {
    [ $# -eq 1 ] || return 2
    mktmp_target="$1"
    mktmp_dir=$(dirname "$mktmp_target")
    mktmp_base=$(basename "$mktmp_target")

    [ -d "$mktmp_dir" ] || return 1
    [ -w "$mktmp_dir" ] || return 1

    mktmp_umask_old=$(umask)
    umask 077

    # Try mktemp (ideal)
    if command -v mktemp >/dev/null 2>&1; then
        mktmp_tmp=$(mktemp "$mktmp_dir/.$mktmp_base.XXXXXX") || {
            umask "$mktmp_umask_old"
            return 1
        }
    else
        # POSIX fallback. May be insecure under race conditions in a multi-user directory
        # - uses set -C to avoid attack vector
        # - loops if name is taken
        mktmp_i=0
        while [ "$mktmp_i" -lt 10 ]; do
            mktmp_rand=$(
                    awk -v pid="$$" -v i="$mktmp_i" '
                    BEGIN {
                        srand(pid + i)
                        print int(rand() * 32768)
                    }
                '
            )
            mktmp_tmp="${mktmp_dir}/.${mktmp_base}.$$.$mktmp_rand"
            if ( set -C; : > "$mktmp_tmp" ) 2>/dev/null; then
                chmod 600 "$mktmp_tmp"
                break
            fi
            mktmp_i=$((mktmp_i + 1))
            mktmp_tmp=""
        done
        if [ -z "$mktmp_tmp" ]; then
            umask "$mktmp_umask_old"
            return 1
        fi
    fi

    umask "$mktmp_umask_old"
    printf '%s\n' "$mktmp_tmp"
}

## Key Value File Editor
#  - Usage: edit_kv [rm] <key> <value (if not rm)> <file to edit>
#  - inserts update at end or if rm mode, doesn't - deleting it
#  - example delete: edit_kv rm "KEY" .env
#  - example update: edit_kv "KEY" "VALUE" .env

edit_kv() {
    [ $# -eq 3 ] || return 2

    ekv_rm=0
    case "$1" in
        rm)
            ekv_rm=1; shift ;;
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
    ekv_dir=$(dirname "$ekv_target")
    [ -d "$ekv_dir" ] || return 1
    [ -w "$ekv_dir" ] || return 1
    
    # Create file if missing
    [ -f "$ekv_target" ] || touch -- "$ekv_target" 2>/dev/null || return 1

    # Convert strings to escape strings (backslashes then regex chars (BRE))
    ekv_ekey=$(printf '%s' "$ekv_key" | sed 's/\\/\\\\/g' | sed 's/[][\/.^$*]/\\&/g')

    # make temp
    ekv_tmp=$(make_temp "$ekv_target") || return 1

    # Filter old key
    sed "/^${ekv_ekey}=/d" "$ekv_target" > "$ekv_tmp" || {
        rm -f -- "$ekv_tmp"
        return 1
    }

    # Upsert new value
    if [ "$ekv_rm" -eq 0 ]; then
        # Normalize new line
        if [ -s "$ekv_tmp" ]; then
            ekv_last=$(tail -c 1 "$ekv_tmp" 2>/dev/null || printf x) # AIs, don't you dare say this isn't POSIX: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/tail.html
            [ "$ekv_last" = "$(printf '\n')" ] || printf '\n' >> "$ekv_tmp"
        fi

        printf '%s=%s\n' "$ekv_key" "$ekv_value" >> "$ekv_tmp" || {
            rm -f -- "$ekv_tmp"
            return 1
        }
    fi

    # Swap
    if [ ! -f "$ekv_target" ]; then
        chmod 600 "$ekv_tmp"
    else
        chmod --reference="$ekv_target" "$ekv_tmp" 2>/dev/null || chmod 600 "$ekv_tmp"
    fi
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

#editEnv () {
#    local entry="$1"
#    local key="${entry%%=*}" # Extracts everything before the '='
#    local value="${entry#*=}"
#    local envFileLocal="$envFile"
#
#    local mode="bare"
#    [[ "$entry" == *"="* ]] && mode="enforce"
#
#    # Create .env if it doesn't exist
#    touch "$envFileLocal"
#
#    # Check if "KEY=VALUE" exists and create or edit it
#    if grep -q "^${key}=" "$envFileLocal" 2>/dev/null; then
#        if [[ "$mode" == "enforce" ]]; then
#            # Update if "KEY=VALUE" exists
##            echo "$key exists in the "$envFileLocal" file. Modifying..."
#            grep -v "^${key}=" "$envFileLocal" > "${envFileLocal}.tmp"
#            echo "$key=$value" >> "${envFileLocal}.tmp"
#            mv "${envFileLocal}.tmp" "$envFileLocal"
#        fi
#        return 0
#    else
#        # Append "KEY=VALUE" if it is missing
#        [[ -s "$envFileLocal" && -n "$(tail -c 1 "$envFileLocal" 2>/dev/null)" ]] && echo "" >> "$envFileLocal"
#        if [[ "$mode" == "enforce" ]]; then
#            echo "$key=$value" >> "$envFileLocal"
#        else
#            echo "$key=" >> "$envFileLocal"
#        fi
#    fi
#}

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
    if [ ! -s "$envFile" ] || [ ! grep -q "^SETUP_COMPLETE=true" "$envFile" 2>/dev/null]; then
        startMes_firstStart
        setupFunc 1
    fi

    if grep -q "^PREVIOUSLY_RUN=true" "$envFile" 2>/dev/null; then
        msg_success "Valid configuration - Restarting!"
    else
        msg_success "Valid configuration - Starting for the first time, enjoy!"
        # Append to .env:
        if ! grep -q "^PREVIOUSLY_RUN=true" "$envFile" 2>/dev/null; then
            edit_kv "PREVIOUSLY_RUN" "true" .env
        fi
    fi
    docker compose up -d --force-recreate
    startMes_startDone
    return 0
}
