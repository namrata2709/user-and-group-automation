#!/bin/bash

# =================================================================================================
#
# EC2 User Management System
#
# Description:
#   This script provides a comprehensive command-line interface (CLI) for managing users and
#   groups on a Linux system. It supports a wide range of operations, including adding, deleting,
#   updating, and viewing users and groups, with flexible filtering, sorting, and formatting
#   options.
#
#   The script is designed to be modular, sourcing functionality from various library files
#   (in ./lib) to handle specific tasks like user creation, logging, and output formatting.
#
#   It supports both standard text-based output and JSON output, making it suitable for both
#   manual administration and integration with automated systems or web frontends (e.g., Flash).
#
# Key Features:
#   - Add, delete, lock, unlock, and update users and groups.
#   - View detailed information about users and groups with advanced filtering and sorting.
#   - Process operations in batches from input files (text or JSON).
#   - Generate system reports (security, compliance, activity, storage).
#   - Export user and group data to JSON or CSV formats.
#   - Dry-run mode to preview changes without applying them.
#   - Comprehensive logging for all operations.
#
# Usage:
#   ./user.sh <operation> <action> [options]
#
# Examples:
#   - View all users in a table:
#     ./user.sh --view users
#
#   - View a specific user's details in JSON format:
#     ./user.sh --view user --name "john.doe" --json
#
#   - Add new users from a file:
#     ./user.sh --add user --names "new_users.txt"
#
#   - Delete a group:
#     ./user.sh --delete group --name "old-group"
#
#   - Update a user's shell:
#     ./user.sh --update user --name "jane.doe" --shell "/bin/bash"
#
# =================================================================================================

# --- Script Information ---
VERSION="2.5.0"
BUILD_DATE="2024-07-29"

# --- Path Definitions ---
# Ensures that the script can be run from any directory by setting the base path.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB_DIR="$SCRIPT_DIR/lib"

# Source all utility files first to ensure their functions are available to other libraries.
UTILS_DIR="$LIB_DIR/utils"
find "$UTILS_DIR" -type f -name "*.sh" | while read -r utility_file; do
    source "$utility_file"
done

# Source all other library files.
# The find command locates all .sh files in the lib directory (excluding the utils subdirectory).
find "$LIB_DIR" -maxdepth 1 -type f -name "*.sh" | while read -r library_file; do
    source "$library_file"
done

# Load configuration file
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_DIR/user_mgmt.conf"
else
    echo "Error: Configuration file 'user_mgmt.conf' not found in '$CONFIG_DIR'."
    exit 1
fi

# --- Icon Definitions ---
# Defines icons for console output, enhancing readability.
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_INFO="ℹ️"
ICON_WARN="⚠️"
ICON_SEARCH="🔍"
ICON_LOCK="🔒"
ICON_UNLOCK="🔓"
ICON_GROUP="👥"
ICON_USER="👤"
ICON_REPORT="📊"
ICON_EXPORT="📤"

# --- Module Loading ---
# Sources all necessary library files for modular functionality.
source "$LIB_DIR/utils/output.sh"
source "$LIB_DIR/utils/validation.sh"
source "$LIB_DIR/utils/logging.sh"
source "$LIB_DIR/utils/dependency.sh"
source "$LIB_DIR/utils/identity.sh"
source "$LIB_DIR/utils/status.sh"
source "$LIB_DIR/utils/resources.sh"
source "$LIB_DIR/utils/password.sh"
source "$LIB_DIR/utils/config_validation.sh"
source "$LIB_DIR/utils/expression_parser.sh"
source "$LIB_DIR/utils/filesystem.sh"
source "$LIB_DIR/utils/string.sh"
source "$LIB_DIR/help.sh"
source "$LIB_DIR/view.sh"
source "$LIB_DIR/report.sh"
source "$LIB_DIR/report_json.sh"
source "$LIB_DIR/export.sh"
source "$LIB_DIR/user_add.sh"
source "$LIB_DIR/user_delete.sh"
source "$LIB_DIR/user_update.sh"
source "$LIB_DIR/user_lock.sh"
source "$LIB_DIR/group_add.sh"
source "$LIB_DIR/group_delete.sh"
source "$LIB_DIR/group_update.sh"
source "$LIB_DIR/compliance.sh"
source "$LIB_DIR/json_input.sh"

# --- Global Variables ---
# General script behavior flags and parameters.
OPERATION=""
ACTION=""
FILE=""
USERNAME=""
GROUPNAME=""
DRY_RUN=false
SUDO_CMD=""
PASSWORD=""
LOG_LEVEL=${LOG_LEVEL:-"INFO"} # Default log level if not set in config
LOG_FILE="$LOG_DIR/user_management_$(date +%Y-%m-%d).log"

# Input/Output formats
JSON_INPUT=false
JSON_OUTPUT=false
INPUT_FORMAT="text" # text or json

# Operation-specific parameters
DELETE_MODE="default" # default, check, force
UPDATE_OPERATION=""
UPDATE_VALUE=""
LOCK_REASON=""
GLOBAL_HOME_DIR=""
GLOBAL_SHELL=""
GLOBAL_EXPIRE=""
GLOBAL_PASSWORD_EXPIRY=""

# Report parameters
REPORT_TYPE=""
REPORT_DAYS=30

# Export parameters
EXPORT_TYPE=""
EXPORT_FORMAT="json"
EXPORT_OUTPUT=""

# --- VIEW Command Parameters ---
# These variables store settings for the powerful '--view' command.
VIEW_SEARCH=""
VIEW_LIMIT=0
VIEW_SKIP=0
VIEW_SORT="username"
VIEW_FILTER="all"
VIEW_COLUMNS=""
VIEW_EXCLUDE=""
VIEW_IN_GROUP=""
VIEW_HAS_MEMBER=""
VIEW_WHERE=""
VIEW_UID_RANGE=""
VIEW_GID_RANGE=""
VIEW_HOME_SIZE_RANGE=""
VIEW_MEMBER_COUNT_RANGE=""
VIEW_GROUP_BY=""
VIEW_AGGREGATE=""
VIEW_TREE_BY=""
VIEW_INCLUDE_RELATED=false
VIEW_COUNT_ONLY=false
VIEW_DETAILED=false
VIEW_TIME_PARAM=""

# =================================================================================================
# FUNCTION: init_script
# DESCRIPTION:
#   Initializes the script environment. It checks for root privileges, sets up the sudo
#   command if necessary, creates the log directory, and logs the script's start.
#
# PARAMETERS:
#   None
# =================================================================================================
init_script() {
    if [ "$(id -u)" -ne 0 ]; then
        SUDO_CMD="sudo"
        log_info "Running with user privileges. Using 'sudo' for root commands."
    fi

    mkdir -p "$LOG_DIR"
    log_info "Script started: user.sh v$VERSION"
}

# =================================================================================================
# FUNCTION: parse_arguments
# DESCRIPTION:
#   Parses all command-line arguments provided to the script. It uses a while loop and a case
#   statement to identify flags and their corresponding values, setting global variables
#   that control the script's execution flow.
#
#   This function distinguishes between main operations (--add, --view, etc.), actions
#   (user, group), and various filtering/formatting options.
#
# PARAMETERS:
#   $@ - All command-line arguments passed to the script.
# =================================================================================================
parse_arguments() {
    # Handle help request as a priority
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_help "$2"
    fi

    # The first argument is expected to be the primary operation.
    if [[ "$1" =~ ^-- ]]; then
        OPERATION="$1"
        shift
    fi

    # The second argument often specifies the action (e.g., 'user', 'group').
    if [[ ! "$1" =~ ^-- ]] && [ -n "$1" ]; then
        ACTION="$1"
        shift
    fi

    # Loop through the remaining arguments to parse options.
    while [ $# -gt 0 ]; do
        case "$1" in
            # --- Input/Output Flags ---
            --names|--input)
                FILE="$2"
                # Determine if the input is JSON based on file extension.
                if [[ "$FILE" == *.json ]]; then
                    JSON_INPUT=true
                    INPUT_FORMAT="json"
                fi
                shift 2
                ;;
            --name)
                # Handles both --name <username> and --name <groupname>
                if [ "$ACTION" = "user" ]; then
                    USERNAME="$2"
                elif [ "$ACTION" = "group" ]; then
                    GROUPNAME="$2"
                else
                    # Fallback for contexts where action might not be set yet
                    USERNAME="$2"
                    GROUPNAME="$2"
                fi
                shift 2
                ;;
            --json|--output-json)
                JSON_OUTPUT=true
                shift
                ;;
            --output)
                EXPORT_OUTPUT="$2"
                shift 2
                ;;
            --format)
                EXPORT_FORMAT="$2"
                shift 2
                ;;

            # --- View/Search Parameters ---
            --search)
                VIEW_SEARCH="$2"
                shift 2
                ;;
            --limit)
                VIEW_LIMIT="$2"
                shift 2
                ;;
            --sort)
                VIEW_SORT="$2"
                shift 2
                ;;
            --filter)
                VIEW_FILTER="$2"
                shift 2
                ;;
            --where)
                VIEW_WHERE="$2"
                shift 2
                ;;
            --columns)
                VIEW_COLUMNS="$2"
                shift 2
                ;;
            --in-group)
                VIEW_IN_GROUP="$2"
                shift 2
                ;;
            --has-member)
                VIEW_HAS_MEMBER="$2"
                shift 2
                ;;
            --count)
                VIEW_COUNT_ONLY=true
                shift
                ;;
            --detailed)
                VIEW_DETAILED=true
                shift
                ;;
            --hours)
                VIEW_TIME_PARAM="$2"
                shift 2
                ;;

            # --- General Behavior Flags ---
            --user)
                USERNAME="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --sudo)
                SUDO_CMD="sudo"
                shift
                ;;
            --password)
                PASSWORD="$2"
                shift 2
                ;;

            # --- Delete Mode Flags ---
            --check)
                DELETE_MODE="check"
                shift
                ;;
            --force)
                DELETE_MODE="force"
                shift
                ;;
            --with-home)
                DELETE_WITH_HOME=true
                shift
                ;;

            # --- Update Operation Flags ---
            --home)
                # Can be a global default or part of an update operation.
                if [ "$OPERATION" = "--update" ]; then
                    UPDATE_OPERATION="home"
                    UPDATE_VALUE="$2"
                    shift
                else
                    GLOBAL_HOME_DIR="$2"
                fi
                shift
                ;;
            --shell)
                if [ "$OPERATION" = "--update" ]; then
                    UPDATE_OPERATION="shell"
                    UPDATE_VALUE="$2"
                    shift
                else
                    GLOBAL_SHELL="$2"
                fi
                shift
                ;;
            --expire)
                if [ "$OPERATION" = "--update" ]; then
                    UPDATE_OPERATION="expire"
                    if [ $# -gt 1 ] && [[ ! "$2" =~ ^-- ]]; then
                        UPDATE_VALUE="$2"
                        shift
                    fi
                    shift
                else
                    GLOBAL_EXPIRE="$2"
                    shift 2
                fi
                ;;
            --password-expiry)
                if [ "$OPERATION" = "--update" ]; then
                    UPDATE_OPERATION="password-expiry"
                    if [ $# -gt 1 ] && [[ ! "$2" =~ ^-- ]]; then
                        UPDATE_VALUE="$2"
                        shift
                    fi
                    shift
                else
                    GLOBAL_PASSWORD_EXPIRY="$2"
                    shift 2
                fi
                ;;

            # --- Help and Version ---
            --help|-h)
                if [ $# -ge 2 ]; then
                    show_specific_help "$2"
                else
                    show_general_help
                fi
                exit 0
                ;;
            --version|-v)
                echo "EC2 User Management System v$VERSION"
                echo "Build: $BUILD_DATE"
                exit 0
                ;;

            # --- Unknown Options ---
            *)
                echo "${ICON_ERROR} Unknown option: $1"
                echo "Use: ./user.sh --help"
                exit 1
                ;;
        esac
    done
}

# =================================================================================================
# FUNCTION: show_dry_run_banner
# DESCRIPTION:
#   Displays a prominent banner if the script is running in dry-run mode. This serves as a
#   clear warning that no actual system changes will be made.
#
# PARAMETERS:
#   None
# =================================================================================================
show_dry_run_banner() {
    if [ "$DRY_RUN" = true ]; then
        echo "=========================================="
        echo "           ${ICON_SEARCH} DRY-RUN MODE"
        echo "      NO CHANGES WILL BE MADE"
        echo "=========================================="
        echo ""
    fi
}

# =================================================================================================
# FUNCTION: route_search_to_view
# DESCRIPTION:
#   Provides backward compatibility by converting the old `--search` command into the new,
#   more powerful `--view` command. It maps the search parameters to their corresponding
#   `--view` equivalents.
#
# PARAMETERS:
#   None
# =================================================================================================
route_search_to_view() {
    if [ "$OPERATION" = "--search" ]; then
        OPERATION="--view"
        log_debug "Routing --search to --view for backward compatibility."
    fi
}

# =================================================================================================
# FUNCTION: execute_operation
# DESCRIPTION:
#   The main router for the script. After arguments are parsed, this function is called to
#   determine which operation to perform based on the `OPERATION` variable. It then calls
#   the appropriate function from the sourced library files to handle the task.
#
#   It handles all primary commands like --add, --delete, --view, --report, etc.
#
# PARAMETERS:
#   None
# =================================================================================================
execute_operation() {
    show_dry_run_banner
    route_search_to_view

    case "$OPERATION" in
        --add)
            [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing --names <file> or --input <file>"; exit 1; }
            case "$ACTION" in
                user)
                    add_users "$FILE"
                    ;;
                group)
                    add_groups "$FILE"
                    ;;
                user-group)
                    add_users_to_groups "$FILE"
                    ;;
                *)
                    echo "${ICON_ERROR} Invalid action for --add: $ACTION"
                    exit 1
                    ;;
            esac
            ;;

        --delete)
            if [ "$ACTION" = "user" ]; then
                [ -z "$USERNAME" ] && [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing --name or --names"; exit 1; }
                if [ -n "$USERNAME" ]; then
                    delete_user "$USERNAME"
                else
                    # Handles both JSON and text input for deleting users.
                    if [ "$JSON_INPUT" = true ]; then
                        delete_users_from_json "$FILE"
                    else
                        delete_users_batch "$FILE"
                    fi
                fi
            elif [ "$ACTION" = "group" ]; then
                [ -z "$GROUPNAME" ] && [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing --name or --names"; exit 1; }
                if [ -n "$GROUPNAME" ]; then
                    delete_group "$GROUPNAME"
                else
                    delete_groups "$FILE"
                fi
            else
                echo "${ICON_ERROR} Invalid action for --delete: $ACTION"
                exit 1
            fi
            ;;

        --lock)
            local target="${USERNAME:-$FILE}"
            [ -z "$target" ] && { echo "${ICON_ERROR} Missing --name <username> or --names <file>"; exit 1; }
            # The lock_users function handles both single and batch locking.
            lock_users "$target" "$INPUT_FORMAT" "$LOCK_REASON"
            ;;

        --unlock)
            local target="${USERNAME:-$FILE}"
            [ -z "$target" ] && { echo "${ICON_ERROR} Missing --name <username> or --names <file>"; exit 1; }
            # The unlock_users function handles both single and batch unlocking.
            unlock_users "$target" "$INPUT_FORMAT"
            ;;

        --update)
            [ -z "$UPDATE_OPERATION" ] && { echo "${ICON_ERROR} Missing update operation (e.g., --shell)"; exit 1; }
            case "$ACTION" in
                user)
                    [ -z "$USERNAME" ] && { echo "${ICON_ERROR} Missing --name <username>"; exit 1; }
                    update_user "$USERNAME" "$UPDATE_OPERATION" "$UPDATE_VALUE"
                    ;;
                group)
                    [ -z "$GROUPNAME" ] && { echo "${ICON_ERROR} Missing --name <groupname>"; exit 1; }
                    update_group "$GROUPNAME" "$UPDATE_OPERATION" "$UPDATE_VALUE"
                    ;;
                *)
                    echo "${ICON_ERROR} Invalid update target: $ACTION"
                    exit 1
                    ;;
            esac
            ;;

        --view)
            # This is the primary data retrieval and display operation.
            case "$ACTION" in
                users)
                    local data=$(get_users_data \
                        "${VIEW_FILTER:-all}" "$VIEW_SEARCH" "${VIEW_SORT:-username}" \
                        "${VIEW_LIMIT:-0}" "${VIEW_SKIP:-0}" "$VIEW_EXCLUDE" "$VIEW_TIME_PARAM" \
                        "$VIEW_IN_GROUP" "$VIEW_WHERE" "$VIEW_UID_RANGE" "$VIEW_HOME_SIZE_RANGE" \
                        "$VIEW_GROUP_BY" "$VIEW_AGGREGATE" "$VIEW_TREE_BY" "$VIEW_INCLUDE_RELATED")

                    # Output is formatted as either JSON or a text table.
                    if [ "$JSON_OUTPUT" = true ]; then
                        format_users_json "$data" "$VIEW_COLUMNS" "$VIEW_COUNT_ONLY"
                    else
                        display_users "$data" "$VIEW_COLUMNS" "$VIEW_COUNT_ONLY"
                    fi
                    ;;

                groups)
                    local data=$(get_groups_data \
                        "${VIEW_FILTER:-all}" "$VIEW_SEARCH" "${VIEW_SORT:-groupname}" \
                        "${VIEW_LIMIT:-0}" "${VIEW_SKIP:-0}" "$VIEW_EXCLUDE" "$VIEW_HAS_MEMBER" \
                        "$VIEW_WHERE" "$VIEW_GID_RANGE" "$VIEW_MEMBER_COUNT_RANGE" \
                        "$VIEW_GROUP_BY" "$VIEW_AGGREGATE" "$VIEW_INCLUDE_RELATED")

                    if [ "$JSON_OUTPUT" = true ]; then
                        format_groups_json "$data" "$VIEW_COLUMNS" "$VIEW_COUNT_ONLY"
                    else
                        display_groups "$data" "$VIEW_COLUMNS" "$VIEW_COUNT_ONLY"
                    fi
                    ;;

                user)
                    [ -z "$USERNAME" ] && { echo "${ICON_ERROR} Missing --name <username>"; exit 1; }
                    local data=$(get_user_details "$USERNAME" true "${VIEW_TIME_PARAM:-24}")
                    [ -z "$data" ] && { echo "${ICON_ERROR} User '$USERNAME' not found"; exit 1; }

                    if [ "$JSON_OUTPUT" = true ]; then
                        format_user_details_json "$data"
                    else
                        display_user_details "$data"
                    fi
                    ;;

                group)
                    [ -z "$GROUPNAME" ] && { echo "${ICON_ERROR} Missing --name <groupname>"; exit 1; }
                    local data=$(get_group_details "$GROUPNAME")
                    [ -z "$data" ] && { echo "${ICON_ERROR} Group '$GROUPNAME' not found"; exit 1; }

                    if [ "$JSON_OUTPUT" = true ]; then
                        format_group_details_json "$data"
                    else
                        display_group_details "$data"
                    fi
                    ;;

                user-groups)
                    [ -z "$USERNAME" ] && { echo "${ICON_ERROR} Missing --name <username>"; exit 1; }
                    ! id "$USERNAME" &>/dev/null && { echo "${ICON_ERROR} User '$USERNAME' not found"; exit 1; }

                    if [ "$JSON_OUTPUT" = true ]; then
                        view_user_groups_json "$USERNAME"
                    else
                        display_user_groups "$USERNAME"
                    fi
                    ;;

                summary)
                    if [ "$JSON_OUTPUT" = true ]; then
                        view_system_summary_json
                    else
                        display_system_summary "$VIEW_DETAILED"
                    fi
                    ;;

                recent-logins)
                    local hours="${VIEW_TIME_PARAM:-24}"
                    if [ "$JSON_OUTPUT" = true ]; then
                        view_recent_logins_json "$hours" "" "$USERNAME"
                    else
                        display_recent_logins "$hours" "" "$USERNAME"
                    fi
                    ;;
                validate)
                    local data=$(validate_system)
                    # The output format depends on the validation function itself.
                    echo "$data"
                    ;;

                *)
                    echo "${ICON_ERROR} Invalid view target: $ACTION"
                    exit 1
                    ;;
            esac
            ;;

        --report)
            [ -z "$REPORT_TYPE" ] && { echo "${ICON_ERROR} Missing report type"; exit 1; }
            if [ "$JSON_OUTPUT" = true ]; then
                case "$REPORT_TYPE" in
                    security) report_security_json ;;
                    compliance) report_compliance_json ;;
                    activity) report_activity_json "$REPORT_DAYS" ;;
                    storage) report_storage_json ;;
                    *) echo "${ICON_ERROR} Invalid report type: $REPORT_TYPE"; exit 1 ;;
                esac
            else
                case "$REPORT_TYPE" in
                    security) report_security ;;
                    compliance) report_compliance ;;
                    activity) report_activity "$REPORT_DAYS" ;;
                    storage) report_storage ;;
                    *) echo "${ICON_ERROR} Invalid report type: $REPORT_TYPE"; exit 1 ;;
                esac
            fi
            ;;

        --apply-roles)
            [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing role file (must be JSON)"; exit 1; }
            apply_roles_from_json "$FILE"
            ;;

        --manage-groups)
            [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing groups file (must be JSON)"; exit 1; }
            manage_groups_from_json "$FILE"
            ;;

        --compliance)
            run_all_compliance_checks
            ;;

        --export)
            [ -z "$EXPORT_TYPE" ] && { echo "${ICON_ERROR} Missing export type (users/groups/all)"; exit 1; }
            [ -z "$EXPORT_OUTPUT" ] && { echo "${ICON_ERROR} Missing --output <file>"; exit 1; }
            export_data "$EXPORT_TYPE" "$EXPORT_OUTPUT" "$EXPORT_FORMAT"
            ;;

        "")
            # Show help if no operation is specified.
            show_general_help
            exit 0
            ;;

        *)
            echo "${ICON_ERROR} Invalid operation: $OPERATION"
            exit 1
            ;;
    esac
}

# =================================================================================================
# FUNCTION: main
# DESCRIPTION:
#   The main entry point of the script. It handles initial checks for help and version flags,
#   then orchestrates the parsing of arguments, script initialization, and operation execution.
#   Finally, it logs the completion of the script.
# =================================================================================================
main() {
    # Ensure at least one command is given
    if [ "$#" -eq 0 ]; then
        error_message "No command provided."
        show_general_help
        return 1
    fi

    # Strip leading dashes from the command for flexibility (e.g., --add becomes add)
    local command="${1#--}"
    shift

    # Centralized command execution
    execute_operation "$command" "$@"
}

# ==============================================================================\
# COMMAND EXECUTION
# ==============================================================================\
execute_operation() {
    local operation="$1"
    shift

    case "$operation" in
        "add")
            add_users "$operation" "$@"
            ;;
        "add-group")
            add_group_main "$operation" "$@"
            ;;
        "update")
            update_user_main "$@"
            ;;
        "update-group")
            update_group_main "$@"
            ;;
        "delete")
            delete_user_main "$@"
            ;;
        "delete-group")
            delete_group_main "$@"
            ;;
        "lock")
            lock_user_main "$@"
            ;;
        "view")
            view_main "$@"
            ;;
        "export")
            export_data "$@"
            ;;
        "report")
            report_main "$@"
            ;;
        "compliance")
            compliance_main "$@"
            ;;
        "help")
            if [ -n "$1" ]; then
                _display_help "$1"
            else
                show_general_help
            fi
            ;;
        *)
            error_message "Unknown command: $operation"
            show_general_help
            return 1
            ;;
    esac
}

# ==============================================================================
# SCRIPT ENTRYPOINT
# ==============================================================================
#
# This is the main entry point of the script.
# It sources required libraries and then calls the main function.
#
# ==============================================================================

# Call the main function with all provided arguments
main "$@"