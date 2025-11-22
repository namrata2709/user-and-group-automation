#!/usr/bin/env bash
# ================================================
# EC2 User Management Script - Main Entry Point
# Version: 2.0.0
# Build Date: 2024-01-22
# ================================================
# UPDATED: Refactored to use single-logic functions
# ================================================

# ============ VERSION INFO ==================
VERSION="2.0.0"
BUILD_DATE="2024-01-22"

# ============ PATHS ==================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
CONFIG_FILE="/opt/admin_dashboard/config/user_mgmt.conf"

# ============ LOAD CONFIGURATION ==================
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "⚠️  Config file not found: $CONFIG_FILE"
    echo "   Using hardcoded defaults"
    DEFAULT_PASSWORD="P@ssword1234!"
    LOG_FILE="/var/log/user_mgmt.log"
    PASSWORD_EXPIRY_DAYS=90
    PASSWORD_WARN_DAYS=7
    BACKUP_DIR="/var/backups/users"
    USE_UNICODE="yes"
    MIN_USER_UID=1000
    MAX_USER_UID=60000
    MIN_GROUP_GID=1000
    PASSWORD_LENGTH=16
    INACTIVE_THRESHOLD_DAYS=90
    DETAILED_LOGGING="yes"
    BACKUP_RETENTION_DAYS=90
fi

# ============ DISPLAY ICONS ==================
if [ "${USE_UNICODE}" = "yes" ]; then
    ICON_SUCCESS="✓"
    ICON_ERROR="✗"
    ICON_WARNING="⚠️"
    ICON_INFO="ℹ️"
    ICON_USER="👤"
    ICON_GROUP="👥"
    ICON_LOCK="🔒"
    ICON_UNLOCK="🔓"
    ICON_DELETE="🗑️"
    ICON_BACKUP="📦"
    ICON_SEARCH="🔍"
else
    ICON_SUCCESS="[OK]"
    ICON_ERROR="[X]"
    ICON_WARNING="[!]"
    ICON_INFO="[i]"
    ICON_USER="[+]"
    ICON_GROUP="[G]"
    ICON_LOCK="[L]"
    ICON_UNLOCK="[U]"
    ICON_DELETE="[-]"
    ICON_BACKUP="[B]"
    ICON_SEARCH="[?]"
fi

export ICON_SUCCESS ICON_ERROR ICON_WARNING ICON_INFO ICON_USER ICON_GROUP
export ICON_LOCK ICON_UNLOCK ICON_DELETE ICON_BACKUP ICON_SEARCH

# ============ LOAD MODULES ==================
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/validation.sh"
source "$LIB_DIR/helpers.sh"
source "$LIB_DIR/config_validation.sh"
source "$LIB_DIR/help.sh"
source "$LIB_DIR/json.sh"
source "$LIB_DIR/view.sh"
source "$LIB_DIR/view_json.sh"
source "$LIB_DIR/search.sh"
source "$LIB_DIR/search_json.sh"
source "$LIB_DIR/report.sh"
source "$LIB_DIR/report_json.sh"
source "$LIB_DIR/json_input.sh"
source "$LIB_DIR/user_add.sh"
source "$LIB_DIR/user_delete.sh"
source "$LIB_DIR/user_update.sh"
source "$LIB_DIR/user_lock.sh"
source "$LIB_DIR/group_add.sh"
source "$LIB_DIR/group_delete.sh"
source "$LIB_DIR/group_update.sh"
source "$LIB_DIR/export.sh"

# ============ GLOBAL VARIABLES ==================
DRY_RUN=false
JSON_OUTPUT=false
JSON_INPUT=false
INPUT_FORMAT="text"
GLOBAL_EXPIRE=""
GLOBAL_SHELL=""
GLOBAL_SUDO=false
GLOBAL_PASSWORD=""
GLOBAL_PASSWORD_EXPIRY="${PASSWORD_EXPIRY_DAYS:-90}"
DELETE_MODE="interactive"
FORCE_LOGOUT=false
KILL_PROCESSES=false
BACKUP_ENABLED=false
KEEP_HOME=false

# ============ INITIALIZATION ==================
init_script() {
    if [ "$EUID" -ne 0 ]; then
        echo "${ICON_ERROR} This script must be run as root (use sudo)"
        exit 1
    fi
    
    if pidof -x "$(basename "$0")" -o $$ >/dev/null 2>&1; then
        echo "${ICON_WARNING} Another instance is already running"
        read -p "Continue anyway? [y/N]: " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    if [ "$JSON_INPUT" = true ] || [ "$JSON_OUTPUT" = true ] || [ "$OPERATION" = "--apply-roles" ] || [ "$OPERATION" = "--manage-groups" ]; then
        if ! command -v jq &> /dev/null; then
            echo "${ICON_ERROR} jq is required for JSON operations"
            echo "   Install with:"
            echo "   - Ubuntu/Debian: sudo apt install jq"
            echo "   - Amazon Linux/RHEL: sudo yum install jq"
            exit 1
        fi
    fi
    
    if ! validate_config; then
        exit 1
    fi
    
    if [ ! -f "$LOG_FILE" ]; then
        local log_dir=$(dirname "$LOG_FILE")
        if [ ! -d "$log_dir" ]; then
            mkdir -p "$log_dir" 2>/dev/null || true
        fi
        touch "$LOG_FILE" 2>/dev/null || true
        chmod 640 "$LOG_FILE" 2>/dev/null || true
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR" 2>/dev/null || true
        chmod 700 "$BACKUP_DIR" 2>/dev/null || true
    fi
    
    log_info "Script started: user.sh v$VERSION"
}

# ============ ARGUMENT PARSING ==================
OPERATION=""
ACTION=""
FILE=""
USERNAME=""
GROUPNAME=""
LOCK_REASON=""
TRANSFER_GROUP=""
VIEW_FILTER=""
SEARCH_PATTERN=""
SEARCH_STATUS=""
SEARCH_GROUP=""
SEARCH_MEMBER=""
UPDATE_OPERATION=""
UPDATE_VALUE=""
REPORT_TYPE=""
REPORT_DAYS=30
EXPORT_TYPE=""
EXPORT_OUTPUT=""
EXPORT_FORMAT="table"
RECENT_HOURS=24
RECENT_DAYS=""
RECENT_USER=""

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --version|-v)
                echo "EC2 User Management System v$VERSION"
                echo "Build: $BUILD_DATE"
                exit 0
                ;;
                
            --add|--delete|--lock|--unlock|--update|--view|--search|--report|--export)
                OPERATION="$1"
                shift
                ;;
            
            --apply-roles|--manage-groups)
                OPERATION="$1"
                # Capture the filename as next argument if not --input
                shift
                if [ $# -gt 0 ] && [[ ! "$1" =~ ^-- ]]; then
                    FILE="$1"
                    shift
                fi
                ;;
                
            user|group|user-group|user-provision|users|groups|user-groups|summary|security|compliance|activity|storage|recent-logins|all)
                if [ "$OPERATION" = "--report" ]; then
                    REPORT_TYPE="$1"
                elif [ "$OPERATION" = "--export" ]; then
                    EXPORT_TYPE="$1"
                elif [ "$OPERATION" = "--view" ] && [ "$1" = "recent-logins" ]; then
                    ACTION="$1"
                else
                    ACTION="$1"
                fi
                shift
                ;;
                
            --format)
                case "$2" in
                    json)
                        JSON_INPUT=true
                        INPUT_FORMAT="json"
                        ;;
                    text)
                        JSON_INPUT=false
                        INPUT_FORMAT="text"
                        ;;
                    csv|tsv|table)
                        EXPORT_FORMAT="$2"
                        ;;
                    *)
                        echo "${ICON_ERROR} Invalid format: $2"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
                
            --input)
                FILE="$2"
                JSON_INPUT=true
                INPUT_FORMAT="json"
                shift 2
                ;;
                
            --hours)
                RECENT_HOURS="$2"
                shift 2
                ;;
                
            --user)
                if [ "$OPERATION" = "--view" ] && [ "$ACTION" = "recent-logins" ]; then
                    RECENT_USER="$2"
                else
                    USERNAME="$2"
                fi
                shift 2
                ;;
                
            --days)
                if [ "$OPERATION" = "--view" ] && [ "$ACTION" = "recent-logins" ]; then
                    RECENT_DAYS="$2"
                    RECENT_HOURS=$((2 * 24))
                elif [ "$OPERATION" = "--report" ]; then
                    REPORT_DAYS="$2"
                fi
                shift 2
                ;;
                
            --names)
                FILE="$2"
                shift 2
                ;;
                
            --name)
                if [ "$ACTION" = "user" ]; then
                    USERNAME="$2"
                elif [ "$ACTION" = "group" ]; then
                    GROUPNAME="$2"
                fi
                shift 2
                ;;
                
            --output)
                EXPORT_OUTPUT="$2"
                shift 2
                ;;
                
            --transfer-files)
                TRANSFER_GROUP="$2"
                shift 2
                ;;
                
            --reason)
                LOCK_REASON="$2"
                shift 2
                ;;
                
            --filter)
                VIEW_FILTER="$2"
                shift 2
                ;;
                
            --pattern)
                SEARCH_PATTERN="$2"
                shift 2
                ;;
                
            --status)
                SEARCH_STATUS="$2"
                shift 2
                ;;
                
            --in-group)
                SEARCH_GROUP="$2"
                shift 2
                ;;
                
            --has-member)
                SEARCH_MEMBER="$2"
                shift 2
                ;;
                
            --dry-run)
                DRY_RUN=true
                shift
                ;;
                
            --json)
                JSON_OUTPUT=true
                shift
                ;;
                
            --sudo)
                GLOBAL_SUDO=true
                shift
                ;;
                
            --password)
                GLOBAL_PASSWORD="$2"
                shift 2
                ;;
                
            --check)
                DELETE_MODE="check"
                shift
                ;;
                
            --interactive)
                DELETE_MODE="interactive"
                shift
                ;;
                
            --backup)
                DELETE_MODE="auto"
                BACKUP_ENABLED=true
                shift
                ;;
                
            --force)
                DELETE_MODE="force"
                shift
                ;;
                
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
                
            --force-logout)
                FORCE_LOGOUT=true
                shift
                ;;
                
            --kill-processes)
                KILL_PROCESSES=true
                shift
                ;;
                
            --keep-home)
                KEEP_HOME=true
                shift
                ;;
                
            --reset-password|--add-to-group|--add-to-groups|--remove-from-group|--remove-from-groups|--comment|--primary-group|--add-member|--add-members|--remove-member|--remove-members)
                UPDATE_OPERATION="${1#--}"
                if [ $# -gt 1 ] && [[ ! "$2" =~ ^-- ]]; then
                    UPDATE_VALUE="$2"
                    shift
                fi
                shift
                ;;
                
            --shell)
                if [ "$OPERATION" = "--update" ]; then
                    UPDATE_OPERATION="shell"
                    if [ $# -gt 1 ] && [[ ! "$2" =~ ^-- ]]; then
                        UPDATE_VALUE="$2"
                        shift
                    fi
                    shift
                else
                    GLOBAL_SHELL="$2"
                    shift 2
                fi
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
                
            --help|-h)
                if [ $# -ge 2 ]; then
                    show_specific_help "$2"
                else
                    show_general_help
                fi
                exit 0
                ;;
                
            *)
                echo "${ICON_ERROR} Unknown option: $1"
                echo "Use: ./user.sh --help"
                exit 1
                ;;
        esac
    done
}

# ============ DRY-RUN BANNER ==================
show_dry_run_banner() {
    if [ "$DRY_RUN" = true ]; then
        echo "=========================================="
        echo "           ${ICON_SEARCH} DRY-RUN MODE"
        echo "      NO CHANGES WILL BE MADE"
        echo "=========================================="
        echo ""
    fi
}

# ============ OPERATION ROUTER ==================
execute_operation() {
    show_dry_run_banner
    
    case "$OPERATION" in
        --add)
            [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing --names <file> or --input <file>"; exit 1; }
            case "$ACTION" in
                user)
                    # UPDATED: Use refactored add_users with format detection
                    add_users "$FILE" "$INPUT_FORMAT"
                    ;;
                group) 
                    # UPDATED: Use refactored add_groups with format detection
                    add_groups "$FILE" "$INPUT_FORMAT"
                    ;;
                user-group|user-provision) 
                    # UPDATED: Uses refactored provision_users_with_groups
                    # Supports GLOBAL_* variables for new user creation
                    provision_users_with_groups "$FILE"
                    ;;
                *) 
                    echo "${ICON_ERROR} Invalid action: $ACTION"
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
                echo "${ICON_ERROR} Invalid action: $ACTION"
                exit 1
            fi
            ;;
            
        --lock)
            if [ -n "$USERNAME" ]; then
                # Single user lock
                lock_single_user "$USERNAME" "$LOCK_REASON"
            elif [ -n "$FILE" ]; then
                # Bulk lock from file
                lock_users "$FILE" "$INPUT_FORMAT" "$LOCK_REASON"
            else
                echo "${ICON_ERROR} Missing --name <username> or --names <file>"
                exit 1
            fi
            ;;
            
        --unlock)
            if [ -n "$USERNAME" ]; then
                # Single user unlock
                unlock_single_user "$USERNAME"
            elif [ -n "$FILE" ]; then
                # Bulk unlock from file
                unlock_users "$FILE" "$INPUT_FORMAT"
            else
                echo "${ICON_ERROR} Missing --name <username> or --names <file>"
                exit 1
            fi
            ;;
            
        --update)
            [ -z "$UPDATE_OPERATION" ] && { echo "${ICON_ERROR} Missing update operation"; exit 1; }
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
            case "$ACTION" in
                users) 
                    if [ "$JSON_OUTPUT" = true ]; then
                        view_all_users_json "${VIEW_FILTER:-all}"
                    else
                        view_all_users "${VIEW_FILTER:-all}"
                    fi
                    ;;
                groups) 
                    if [ "$JSON_OUTPUT" = true ]; then
                        view_all_groups_json "${VIEW_FILTER:-all}"
                    else
                        view_all_groups "${VIEW_FILTER:-all}"
                    fi
                    ;;
                user)
                    [ -z "$USERNAME" ] && { echo "${ICON_ERROR} Missing --name <username>"; exit 1; }
                    if [ "$JSON_OUTPUT" = true ]; then
                        view_user_details_json "$USERNAME"
                    else
                        view_user_details "$USERNAME"
                    fi
                    ;;
                group)
                    [ -z "$GROUPNAME" ] && { echo "${ICON_ERROR} Missing --name <groupname>"; exit 1; }
                    if [ "$JSON_OUTPUT" = true ]; then
                        view_group_details_json "$GROUPNAME"
                    else
                        view_group_details "$GROUPNAME"
                    fi
                    ;;
                user-groups)
                    [ -z "$USERNAME" ] && { echo "${ICON_ERROR} Missing --name <username>"; exit 1; }
                    if [ "$JSON_OUTPUT" = true ]; then
                        view_user_groups_json "$USERNAME"
                    else
                        view_user_groups "$USERNAME"
                    fi
                    ;;
                summary) 
                    if [ "$JSON_OUTPUT" = true ]; then
                        view_system_summary_json
                    else
                        view_system_summary
                    fi
                    ;;
                recent-logins) 
                    if [ "$JSON_OUTPUT" = true ]; then
                        view_recent_logins_json "$RECENT_HOURS" "$RECENT_DAYS" "$RECENT_USER"
                    else
                        view_recent_logins "$RECENT_HOURS" "$RECENT_DAYS" "$RECENT_USER"
                    fi
                    ;;
                *)
                    echo "${ICON_ERROR} Invalid view target: $ACTION"
                    exit 1
                    ;;
            esac
            ;;
            
        --search)
            case "$ACTION" in
                users) 
                    if [ "$JSON_OUTPUT" = true ]; then
                        search_users_json "$SEARCH_PATTERN" "$SEARCH_STATUS" "$SEARCH_GROUP"
                    else
                        search_users "$SEARCH_PATTERN" "$SEARCH_STATUS" "$SEARCH_GROUP"
                    fi
                    ;;
                groups) 
                    if [ "$JSON_OUTPUT" = true ]; then
                        search_groups_json "$SEARCH_PATTERN" "$SEARCH_MEMBER" ""
                    else
                        search_groups "$SEARCH_PATTERN" "$SEARCH_MEMBER" ""
                    fi
                    ;;
                *)
                    echo "${ICON_ERROR} Invalid search target: $ACTION"
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
                    *)
                        echo "${ICON_ERROR} Invalid report type: $REPORT_TYPE"
                        exit 1
                        ;;
                esac
            else
                case "$REPORT_TYPE" in
                    security) report_security ;;
                    compliance) report_compliance ;;
                    activity) report_activity "$REPORT_DAYS" ;;
                    storage) report_storage ;;
                    *)
                        echo "${ICON_ERROR} Invalid report type: $REPORT_TYPE"
                        exit 1
                        ;;
                esac
            fi
            ;;
            
        --apply-roles)
            [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing role file (usage: --apply-roles <file>)"; exit 1; }
            apply_roles_from_json "$FILE"
            ;;
            
        --manage-groups)
            [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing groups file (usage: --manage-groups <file>)"; exit 1; }
            manage_groups_from_json "$FILE"
            ;;
            
        --export)
            [ -z "$EXPORT_TYPE" ] && { echo "${ICON_ERROR} Missing export type (users/groups/all)"; exit 1; }
            [ -z "$EXPORT_OUTPUT" ] && { echo "${ICON_ERROR} Missing --output <file>"; exit 1; }
            export_data "$EXPORT_TYPE" "$EXPORT_OUTPUT" "$EXPORT_FORMAT"
            ;;
            
        "")
            show_general_help
            exit 0
            ;;
            
        *)
            echo "${ICON_ERROR} Invalid operation: $OPERATION"
            exit 1
            ;;
    esac
}

# ============ MAIN ==================
main() {
    if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        if [ $# -ge 2 ]; then
            show_specific_help "$2"
        else
            show_general_help
        fi
        exit 0
    fi
    
    if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
        echo "EC2 User Management System v$VERSION"
        echo "Build: $BUILD_DATE"
        exit 0
    fi
    
    parse_arguments "$@"
    init_script
    execute_operation
    
    if [ "$DRY_RUN" = false ] && [ "$DELETE_MODE" != "check" ] && [ "$JSON_OUTPUT" = false ]; then
        echo ""
        echo "${ICON_SUCCESS} Operation completed successfully"
        echo "${ICON_INFO} Log file: $LOG_FILE"
    fi
    
    log_info "Script completed: user.sh v$VERSION"
}

main "$@"