#!/usr/bin/env bash
# ==============================================================================
#
#          FILE: output_helpers.sh
#
#         USAGE: source output_helpers.sh
#
#   DESCRIPTION: A library for standardized terminal output, providing
#                functions for printing banners, tables, summaries, and
#                formatted messages with consistent styling (colors and icons).
#
#       OPTIONS: ---
#  REQUIREMENTS: bash, coreutils, tput
#          BUGS: ---
#         NOTES: This library helps maintain a consistent look and feel across
#                different scripts in the project.
#       AUTHOR: Your Name, your.email@example.com
# ORGANIZATION: Your Company
#      CREATED: YYYY-MM-DD
#     REVISION: 1.3.0
#
# ==============================================================================

# ==============================================================================
# SECTION: COLOR AND STYLE DEFINITIONS
# ==============================================================================

# Check if stdout is a terminal and tput is available
if [ -t 1 ] && command -v tput &>/dev/null; then
    # Get the number of colors the terminal supports
    ncolors=$(tput colors)

    if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
        # Terminal supports colors
        BOLD=$(tput bold)
        UNDERLINE=$(tput smul)
        STANDOUT=$(tput smso)
        NORMAL=$(tput sgr0)
        BLACK=$(tput setaf 0)
        RED=$(tput setaf 1)
        GREEN=$(tput setaf 2)
        YELLOW=$(tput setaf 3)
        BLUE=$(tput setaf 4)
        MAGENTA=$(tput setaf 5)
        CYAN=$(tput setaf 6)
        WHITE=$(tput setaf 7)
        COLOR_RESET=$(tput sgr0)
    fi
fi

# Fallback to empty strings if colors are not supported
: "${BOLD=}" "${UNDERLINE=}" "${STANDOUT=}" "${NORMAL=}"
: "${BLACK=}" "${RED=}" "${GREEN=}" "${YELLOW=}" "${BLUE=}"
: "${MAGENTA=}" "${CYAN=}" "${WHITE=}" "${COLOR_RESET=}"


# ==============================================================================
# SECTION: ICONS
# ==============================================================================
ICON_SUCCESS="${GREEN}✔${COLOR_RESET}"
ICON_ERROR="${RED}✖${COLOR_RESET}"
ICON_WARNING="${YELLOW}⚠${COLOR_RESET}"
ICON_INFO="${BLUE}ℹ${COLOR_RESET}"
ICON_QUESTION="${MAGENTA}?${COLOR_RESET}"
ICON_ARROW="${CYAN}➜${COLOR_RESET}"

# ==============================================================================
# SECTION: BANNER FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: _display_banner()
#
# DESCRIPTION:
#   Prints a standardized banner for a given operation.
#
# ARGUMENTS:
#   $1: operation_name - The name of the operation (e.g., "Adding Users").
#   $2: file_path - The path to the input file.
# ------------------------------------------------------------------------------
_display_banner() {
    local operation_name="$1"
    local file_path="$2"
    echo -e "${BOLD}${CYAN}===================================================${COLOR_RESET}"
    echo -e "${BOLD}${CYAN}  ${operation_name} from: ${file_path}${COLOR_RESET}"
    echo -e "${BOLD}${CYAN}===================================================${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# FUNCTION: print_section_banner()
#
# DESCRIPTION:
#   Prints a banner for a major section of output.
#
# ARGUMENTS:
#   $1: title - The title of the section.
# ------------------------------------------------------------------------------
print_section_banner() {
    echo -e "\n${BOLD}${UNDERLINE}${WHITE}${1}${NORMAL}"
}

# ------------------------------------------------------------------------------
# FUNCTION: print_success_banner()
#
# DESCRIPTION:
#   Prints a green banner for success messages.
#
# ARGUMENTS:
#   $1: message - The message to display.
# ------------------------------------------------------------------------------
print_success_banner() {
    echo -e "${GREEN}${BOLD}✔ SUCCESS:${NORMAL} ${1}"
}

# ------------------------------------------------------------------------------
# FUNCTION: print_error_banner()
#
# DESCRIPTION:
#   Prints a red banner for error messages.
#
# ARGUMENTS:
#   $1: message - The message to display.
# ------------------------------------------------------------------------------
print_error_banner() {
    echo -e "${RED}${BOLD}✖ ERROR:${NORMAL} ${1}" >&2
}

# ------------------------------------------------------------------------------
# FUNCTION: print_warning_banner()
#
# DESCRIPTION:
#   Prints a yellow banner for warning messages.
#
# ARGUMENTS:
#   $1: message - The message to display.
# ------------------------------------------------------------------------------
print_warning_banner() {
    echo -e "${YELLOW}${BOLD}⚠ WARNING:${NORMAL} ${1}"
}

# ------------------------------------------------------------------------------
# FUNCTION: print_info_banner()
#
# DESCRIPTION:
#   Prints a blue banner for informational messages.
#
# ARGUMENTS:
#   $1: message - The message to display.
# ------------------------------------------------------------------------------
print_info_banner() {
    echo -e "${BLUE}${BOLD}ℹ INFO:${NORMAL} ${1}"
}

# ==============================================================================
# SECTION: RESULT DISPLAY FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: _display_add_users_bash_results()
#
# DESCRIPTION:
#   Parses the JSON output from the core user addition logic and displays it
#   in a human-readable format in the terminal.
#
# GLOBALS:
#   ICON_SUCCESS, ICON_ERROR, ICON_WARNING (read)
#
# ARGUMENTS:
#   $1: json_results - A JSON string containing the results.
# ------------------------------------------------------------------------------
_display_add_users_bash_results() {
    local json_results="$1"

    print_section_banner "User Addition Results"

    # Created Users
    echo "$json_results" | jq -r '.created[] | "  \(.status) User '\''\(.username)'\'' created successfully." | sed "s/success/${ICON_SUCCESS}/"

    # Existing Users
    echo "$json_results" | jq -r '.existing[] | "  \(.status) User '\''\(.username)'\'' already exists." | sed "s/skipped/${ICON_WARNING}/"

    # Failed Users
    echo "$json_results" | jq -r '.failed[] | "  \(.status) Failed to create user '\''\(.username)'\'': \(.reason)"' | sed "s/error/${ICON_ERROR}/"

    print_operation_summary "$json_results"
}

# ------------------------------------------------------------------------------
# FUNCTION: _display_provision_bash_results()
#
# DESCRIPTION:
#   Parses the JSON output from the core provisioning logic and displays it
#   in a human-readable format in the terminal.
#
# GLOBALS:
#   ICON_SUCCESS, ICON_ERROR, ICON_WARNING (read)
#
# ARGUMENTS:
#   $1: json_results - A JSON string containing the results.
# ------------------------------------------------------------------------------
_display_provision_bash_results() {
    local json_results="$1"

    print_section_banner "User and Group Provisioning Results"

    # Created Groups
    echo "$json_results" | jq -r '.groups.created[] | "  \(.status) Group '\''\(.groupname)'\'' created successfully." | sed "s/success/${ICON_SUCCESS}/"
    # Existing Groups
    echo "$json_results" | jq -r '.groups.existing[] | "  \(.status) Group '\''\(.groupname)'\'' already exists." | sed "s/skipped/${ICON_WARNING}/"

    # Created Users
    echo "$json_results" | jq -r '.users.created[] | "  \(.status) User '\''\(.username)'\'' created and configured." | sed "s/success/${ICON_SUCCESS}/"
    # Existing Users
    echo "$json_results" | jq -r '.users.existing[] | "  \(.status) User '\''\(.username)'\'' already exists." | sed "s/skipped/${ICON_WARNING}/"
    # Failed Users
    echo "$json_results" | jq -r '.users.failed[] | "  \(.status) Failed to provision user '\''\(.username)'\'': \(.reason)"' | sed "s/error/${ICON_ERROR}/"

    print_operation_summary "$json_results"
}


# ==============================================================================
# SECTION: SUMMARY AND TABLE FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: print_operation_summary()
#
# DESCRIPTION:
#   Parses a JSON summary object and prints a formatted summary of operations.
#   It dynamically calculates counts for created, existing/skipped, and failed
#   items for both users and groups.
#
# ARGUMENTS:
#   $1: json_summary - The JSON string containing the summary block.
# ------------------------------------------------------------------------------
print_operation_summary() {
    local json_summary="$1"
    local total_created total_skipped total_failed

    # Calculate totals from the JSON input
    total_created=$(echo "$json_summary" | jq '[.users.created, .groups.created | select(. != null)] | flatten | length')
    total_skipped=$(echo "$json_summary" | jq '[.users.existing, .groups.existing | select(. != null)] | flatten | length')
    total_failed=$(echo "$json_summary" | jq '[.users.failed, .groups.failed | select(. != null)] | flatten | length')

    print_section_banner "Operation Summary"
    echo -e "  ${ICON_SUCCESS} ${BOLD}Created:${NORMAL} ${total_created}"
    echo -e "  ${ICON_WARNING} ${BOLD}Skipped:${NORMAL} ${total_skipped} (already exist)"
    echo -e "  ${ICON_ERROR} ${BOLD}Failed:${NORMAL}  ${total_failed}"
    print_horizontal_line
}


# ------------------------------------------------------------------------------
# FUNCTION: print_horizontal_line()
#
# DESCRIPTION:
#   Prints a horizontal line across the terminal width.
# ------------------------------------------------------------------------------
print_horizontal_line() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
}


# ------------------------------------------------------------------------------
# FUNCTION: print_table_header()
#
# DESCRIPTION:
#   Prints a formatted header for a table.
#
# ARGUMENTS:
#   $@: columns - A list of column names.
# ------------------------------------------------------------------------------
print_table_header() {
    printf "${BOLD}%-20s %-15s %-25s %-10s${NORMAL}\n" "$@"
}


# ------------------------------------------------------------------------------
# FUNCTION: print_table_row()
#
# DESCRIPTION:
#   Prints a formatted row for a table.
#
# ARGUMENTS:
#   $@: values - A list of values for the row.
# ------------------------------------------------------------------------------
print_table_row() {
    printf "%-20s %-15s %-25s %-10s\n" "$@"
}