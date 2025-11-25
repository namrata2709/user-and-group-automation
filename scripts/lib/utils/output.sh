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
#       OPTIONS: ---
#  REQUIREMENTS: bash, coreutils, tput
#          BUGS: ---\
#         NOTES: This library helps maintain a consistent look and feel across
#                different scripts in the project.
#       AUTHOR: Your Name, your.email@example.com
# ORGANIZATION: Your Company
#      CREATED: YYYY-MM-DD
#     REVISION: 1.4.0
#
# ==============================================================================\n\n# ==============================================================================\n# SECTION: COLOR AND STYLE DEFINITIONS\n# ==============================================================================
# ... existing code ...
# ==============================================================================\n# SECTION: BANNER FUNCTIONS\n# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: _display_banner()
#
# DESCRIPTION:
#   Prints a standardized banner to announce the start of a major operation.
#   This is used to clearly demarcate different stages of the script's execution,
#   such as adding users or provisioning from a file.
#
# ARGUMENTS:
#   $1: operation_name - The name of the operation (e.g., "Adding Users").
#   $2: file_path - The path to the input file being processed.
# ------------------------------------------------------------------------------
_display_banner() {
# ... existing code ...
# ==============================================================================\n# SECTION: RESULT DISPLAY FUNCTIONS\n# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: _display_add_users_bash_results()
#
# DESCRIPTION:
#   Parses a JSON array of user status objects and displays a human-readable
#   summary in the terminal. It reports which users were successfully created,
#   which already existed, and which failed, providing clear feedback for
#   each operation.
#
# GLOBALS:
#   ICON_SUCCESS, ICON_ERROR, ICON_WARNING (read)
#
# ARGUMENTS:
#   $1: json_results - A JSON string containing arrays of created, existing,
#                      and failed user objects.
# ------------------------------------------------------------------------------
_display_add_users_bash_results() {
# ... existing code ...
# ------------------------------------------------------------------------------
# FUNCTION: _display_provision_bash_results()
#
# DESCRIPTION:
#   Parses the complex JSON output from the provisioning process, which includes
#   both user and group creation statuses. It provides a comprehensive,
#   human-readable summary of the entire operation, detailing which groups and
#   users were created, skipped, or failed.
#
# GLOBALS:
#   ICON_SUCCESS, ICON_ERROR, ICON_WARNING (read)
#
# ARGUMENTS:
#   $1: json_results - A JSON string containing the results for both users
#                      and groups.
# ------------------------------------------------------------------------------
_display_provision_bash_results() {
# ... existing code ...
# ==============================================================================\n# SECTION: SUMMARY AND TABLE FUNCTIONS\n# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: print_operation_summary()
#
# DESCRIPTION:
#   Parses a JSON summary object and prints a final tally of all operations.
#   It calculates and displays the total number of items (users and/or groups)
#   that were created, skipped (already existing), or failed. This gives the
#   administrator a quick, at-a-glance overview of the outcome.
#
# ARGUMENTS:
#   $1: json_summary - The JSON string containing the summary block with arrays
#                      for created, existing, and failed items.
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