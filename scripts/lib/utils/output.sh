#!/usr/bin/env bash
# ==============================================================================
#
#          FILE: output.sh
#
#         USAGE: source output.sh
#
#   DESCRIPTION: A library for standardized terminal output, providing
#                functions for printing banners, tables, summaries, and
#                formatted messages with consistent styling (colors and icons).
#
#     REVISION: 2.0.0
#
# ==============================================================================

# ==============================================================================
# SECTION: COLOR AND STYLE DEFINITIONS
# ==============================================================================
# Check if stdout is a terminal
if [[ -t 1 ]]; then
    # Use tput to get terminal capabilities
    BOLD=$(tput bold)
    UNDERLINE=$(tput smul)
    NORMAL=$(tput sgr0)
    BLACK=$(tput setaf 0)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7)
else
    # If not a terminal, disable colors and styles
    BOLD=""
    UNDERLINE=""
    NORMAL=""
    BLACK=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
fi

# ==============================================================================
# SECTION: ICON DEFINITIONS
# ==============================================================================
ICON_SUCCESS="✔"
ICON_ERROR="✖"
ICON_WARNING="⚠"
ICON_INFO="ℹ"

# ==============================================================================
# SECTION: CORE MESSAGING FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: info_message()
# DESCRIPTION: Prints an informational message.
# ARGUMENTS: $1 - The message to print.
# ------------------------------------------------------------------------------
info_message() {
    echo -e "${BLUE}${ICON_INFO}${NORMAL} $1"
}

# ------------------------------------------------------------------------------
# FUNCTION: success_message()
# DESCRIPTION: Prints a success message.
# ARGUMENTS: $1 - The message to print.
# ------------------------------------------------------------------------------
success_message() {
    echo -e "${GREEN}${ICON_SUCCESS}${NORMAL} $1"
}

# ------------------------------------------------------------------------------
# FUNCTION: warning_message()
# DESCRIPTION: Prints a warning message.
# ARGUMENTS: $1 - The message to print.
# ------------------------------------------------------------------------------
warning_message() {
    echo -e "${YELLOW}${ICON_WARNING}${NORMAL} $1"
}

# ------------------------------------------------------------------------------
# FUNCTION: error_message()
# DESCRIPTION: Prints an error message to stderr.
# ARGUMENTS: $1 - The message to print.
# ------------------------------------------------------------------------------
error_message() {
    echo -e "${RED}${ICON_ERROR}${NORMAL} $1" >&2
}

# ==============================================================================
# SECTION: BANNER FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: print_horizontal_line()
# DESCRIPTION: Prints a horizontal line across the terminal width.
# ------------------------------------------------------------------------------
print_horizontal_line() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
}

# ------------------------------------------------------------------------------
# FUNCTION: display_banner()
# DESCRIPTION: Prints a standardized banner for a major operation.
# ARGUMENTS: $1 - The title of the banner.
# ------------------------------------------------------------------------------
display_banner() {
    local title="$1"
    print_horizontal_line
    echo -e "${BOLD}${CYAN}${title}${NORMAL}"
    print_horizontal_line
}

# ------------------------------------------------------------------------------
# FUNCTION: print_section_banner()
# DESCRIPTION: Prints a smaller banner for a section.
# ARGUMENTS: $1 - The title of the section.
# ------------------------------------------------------------------------------
print_section_banner() {
    echo -e "\n${BOLD}${UNDERLINE}${WHITE}$1${NORMAL}"
}


# ==============================================================================
# SECTION: TABLE FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: print_table_header()
# DESCRIPTION: Prints a formatted header for a table.
# ARGUMENTS: $@ - A list of column names.
# ------------------------------------------------------------------------------
print_table_header() {
    printf "${BOLD}%-20s %-15s %-25s %-10s${NORMAL}\n" "$@"
}

# ------------------------------------------------------------------------------
# FUNCTION: print_table_row()
# DESCRIPTION: Prints a formatted row for a table.
# ARGUMENTS: $@ - A list of values for the row.
# ------------------------------------------------------------------------------
print_table_row() {
    printf "%-20s %-15s %-25s %-10s\n" "$@"
}

# ==============================================================================
# SECTION: SUMMARY FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: print_operation_summary()
# DESCRIPTION: Prints a final summary of an operation.
# ARGUMENTS:
#   $1: total_count - Total items processed.
#   $2: action_verb - The verb for the success count (e.g., "Created", "Updated").
#   $3: success_count - Number of successful operations.
#   $4: skipped_count - Number of skipped items.
#   $5: failed_count - Number of failed operations.
#   $6: duration - The total time taken in seconds.
# ------------------------------------------------------------------------------
print_operation_summary() {
    local total_count="$1"
    local action_verb="$2"
    local success_count="$3"
    local skipped_count="$4"
    local failed_count="$5"
    local duration="$6"

    print_section_banner "Operation Summary"
    echo -e "  Total items processed: ${total_count}"
    echo -e "  ${GREEN}${action_verb}:${NORMAL} ${success_count}"
    echo -e "  ${YELLOW}Skipped:${NORMAL} ${skipped_count}"
    echo -e "  ${RED}Failed:${NORMAL}  ${failed_count}"
    echo -e "  Duration: ${duration}s"
    print_horizontal_line
}