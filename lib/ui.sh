# |----------------------------------------------------------------------------|
# |                        SIA Management Tool                                 |
# |----------------------------------------------------------------------------|
# |              SPDX-License-Identifier: MIT                                  |
# |              SPDX-FileCopyrightText: 2025-2026 Joshua Haveman              |
# |  This tool is released under the MIT License: modify & distribute freely.  |
# |----------------------------------------------------------------------------|

# This contains all UI and semantic functions but not menu processors
# Terminal variables are set in the main sia script.

# Check that main was loaded
if [ "${SIA_MAIN_LOADED:-}" != "true" ]; then
    printf '%s' "Error: This script is a component of SIA and cannot be run directly."
    printf '%s' "Please run: ./sia"
    exit 1
fi

# VERBOSITY AND SEMANTICS
# ANSI Color Codes
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Log func to filter outputs based on global verbosity
log() {
    log_lvl=$1
    shift

    [ ${verbosity:-2} -lt $log_lvl ] && return 0

    printf "%b\n" "$*" >&2
}

# SEMANTIC WRAPPERS
# These call log() internally so you don't have to remember the numbers.
wrap_text() {
    wrptxt_text="$1"
    wrptxt_prefix_width=0         # Extra space reserved for the prefix (e.g., "[INFO]    ")
    wrptxt_wrap_indent="${2:-10}" # How far in the continued lines should start

    # Wrap the text to the available width (total 75 minus prefix space)
    printf "%s" "$wrptxt_text" | fold -w "$((term_max_width - wrptxt_prefix_width))" |
        awk -v pw="$wrptxt_prefix_width" -v iw="$wrptxt_wrap_indent" '
    {
        if (NR == 1) {
            printf "%*s%s\n", pw, "", $0
        } else {
            printf "%*s%s\n", iw, "", $0
        }
    }'
}

msg_error() { log 1 "${RED}[ERROR]${NC}   $(wrap_text "$*")"; }
msg_usage() { log 2 "${YELLOW}[USAGE]${NC}   $(wrap_text "$*")"; }
msg_warn() { log 2 "${YELLOW}[WARN]${NC}    $(wrap_text "$*")"; }
msg_info() { log 2 "${BLUE}[INFO]${NC}    $(wrap_text "$*")"; }
msg_success() { log 2 "${GREEN}[CHECK]${NC}   $(wrap_text "$*")"; }
msg_debug() { log 3 "${BOLD}[DEBUG]${NC}   $(wrap_text "$*")"; }
msg_normal() { log 2 "$(wrap_text "$*")"; }
# msg_normal()  { log 2 "$(printf "%*s" $((10)) '')$(wrap_text "$*")"; }
msg_header() {
    msghdr_color="$BOLD"
    # POSIX way to check for ANSI prefix
    case "$1" in
    \\033*)
        msghdr_color="$1"
        shift
        ;;
    esac
    log 2 " ${msghdr_color}== $* ==${NC}"
}
msg_title() {
    msgttl_term_width=$(tput cols 2>/dev/null || printf '%s' $term_width_fallback)
    [ "$msgttl_term_width" -gt $term_width_fallback ] && msgttl_term_width=$term_width_fallback

    msgttl_color="$BOLD"
    case "$1" in
    \\033*)
        msgttl_color="$1"
        shift
        ;;
    esac

    msgttl_text="$*"
    # Calc visible chars
    msgttl_visible_text=$(printf "%b" "$msgttl_text" | sed 's/\x1b\[[0-9;]*m//g')
    msgttl_text_length=${#msgttl_visible_text}

    msgttl_padding=$(((msgttl_term_width - msgttl_text_length) / 2))
    [ "$msgttl_padding" -lt 0 ] && msgttl_padding=0

    log 2 "$(printf '%*s%b%b%b' "$msgttl_padding" '' "$msgttl_color" "$msgttl_text" "$NC")"
}
msg_blank() { log 2 ""; }
msg_line() { # for lines that are terminal width
    msgline_term_width=$(tput cols 2>/dev/null || printf '%s' $term_width_fallback)
    [ "$msgline_term_width" -gt $term_max_width ] && msgline_term_width=$term_max_width
    msgline_line=$(printf '%*s' "$msgline_term_width" '' | tr ' ' '-')
    log 2 "${NC}$msgline_line${NC}"
}
msg_col() {
    msgcol_left="   $1"
    msgcol_right="$2"
    msgcol_padding="${3:-18}"

    msgcol_leftLength=${#msgcol_left}
    msgcol_diff="$((msgcol_padding - msgcol_leftLength))"

    [ "$msgcol_diff" -lt 1 ] && msgcol_diff=1

    msgcol_spacer="$(printf '%*s' "$msgcol_diff" "")"

    log 2 "$(wrap_text "${msgcol_left}${msgcol_spacer}${msgcol_right}" "$msgcol_padding")"
}
