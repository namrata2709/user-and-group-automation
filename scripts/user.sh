#!/usr/bin/env bash
# ================================================
# EC2 User Management Script - Main Entry Point
# Version: 2.0.0
# Build Date: 2024-01-15
# ================================================
# Phase 1: Foundation - New argument parsing
# Modular architecture - loads functions from lib/
# ================================================

# ============ VERSION INFO ==================
VERSION="2.0.0"
BUILD_DATE="2024-01-15"

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

# Load expression parser if exists (v2.0.0 feature)
[ -f "$LIB_DIR/expression_parser.sh" ] && source "$LIB_DIR/expression_parser.sh"

# Load validation rules if exists (v2.0.0 feature)
[ -f "$LIB_DIR/validation_rules.sh" ] && source "$LIB_DIR/validation_rules.sh"

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

# ============ NEW VIEW PARAMETERS (v2.0.0) ==================
VIEW_LIMIT=0           # 0 = unlimited
VIEW_SKIP=0
VIEW_SORT=""           # Default varies by view
VIEW_COLUMNS=""        # Empty = all columns
VIEW_COUNT_ONLY=false
VIEW_EXCLUDE=""
VIEW_TIME_PARAM=""     # For dynamic time filters (--days, --hours)
VIEW_DETAILED=false    # For summary --detailed
VIEW_REVERSE=false     # Sort order
VIEW_SEARCH=""         # Pattern matching
VIEW_IN_GROUP=""       # Filter users by group
VIEW_HAS_MEMBER=""     # Filter groups by member
VIEW_WHERE=""          # Custom WHERE expression
VIEW_UID_RANGE=""      # UID range filter
VIEW_GID_RANGE=""      # GID range filter
VIEW_HOME_SIZE_RANGE="" # Home size range
VIEW_MEMBER_COUNT_RANGE="" # Group member count range
VIEW_GROUP_BY=""       # Aggregation grouping
VIEW_AGGREGATE=""      # Aggregation functions
VIEW_TREE_BY=""        # Hierarchical tree view
VIEW_INCLUDE_RELATED=false # Include related data (joins)
VIEW_VALIDATE=false    # Validation mode

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
UPDATE_OPERATION=""
UPDATE_VALUE=""
REPORT_TYPE=""
REPORT_DAYS=30
EXPORT_TYPE=""
EXPORT_OUTPUT=""
EXPORT_FORMAT="table"

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --version|-v)
                echo "EC2 User Management System v$VERSION"
                echo "Build: $BUILD_DATE"
                exit 0
                ;;
                
            --add|--delete|--lock|--unlock|--update|--view|--search|--report|--export|--apply-roles|--manage-groups)
                OPERATION="$1"
                shift
                ;;
                
            user|group|user-group|users|groups|user-groups|summary|security|compliance|activity|storage|recent-logins|all)
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
                
            # ============ FORMAT & INPUT ==================
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
                
            # ============ VIEW PARAMETERS (NEW v2.0.0) ==================
            --search)
                VIEW_SEARCH="$2"
                shift 2
                ;;
                
            --limit)
                VIEW_LIMIT="$2"
                shift 2
                ;;
                
            --skip)
                VIEW_SKIP="$2"
                shift 2
                ;;
                
            --sort)
                VIEW_SORT="$2"
                shift 2
                ;;
                
            --reverse)
                VIEW_REVERSE=true
                shift
                ;;
                
            --columns)
                VIEW_COLUMNS="$2"
                shift 2
                ;;
                
            --count-only)
                VIEW_COUNT_ONLY=true
                shift
                ;;
                
            --exclude)
                VIEW_EXCLUDE="$2"
                shift 2
                ;;
                
            --filter)
                VIEW_FILTER="$2"
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
                
            --where)
                VIEW_WHERE="$2"
                shift 2
                ;;
                
            --uid-range)
                VIEW_UID_RANGE="$2"
                shift 2
                ;;
                
            --gid-range)
                VIEW_GID_RANGE="$2"
                shift 2
                ;;
                
            --home-size-range)
                VIEW_HOME_SIZE_RANGE="$2"
                shift 2
                ;;
                
            --member-count-range)
                VIEW_MEMBER_COUNT_RANGE="$2"
                shift 2
                ;;
                
            --days)
                VIEW_TIME_PARAM="$2"
                if [ "$OPERATION" = "--report" ]; then
                    REPORT_DAYS="$2"
                fi
                shift 2
                ;;
                
            --hours)
                VIEW_TIME_PARAM="$2"
                shift 2
                ;;
                
            --group-by)
                VIEW_GROUP_BY="$2"
                shift 2
                ;;
                
            --aggregate)
                VIEW_AGGREGATE="$2"
                shift 2
                ;;
                
            --tree-by)
                VIEW_TREE_BY="$2"
                shift 2
                ;;
                
            --include-group-details|--include-user-details|--include-related)
                VIEW_INCLUDE_RELATED=true
                shift
                ;;
                
            --validate)
                VIEW_VALIDATE=true
                shift
                ;;
                
            --detailed)
                VIEW_DETAILED=true
                shift
                ;;
                
            # ============ OUTPUT OPTIONS ==================
            --json)
                JSON_OUTPUT=true
                shift
                ;;
                
            --output)
                EXPORT_OUTPUT="$2"
                shift 2
                ;;
                
            # ============ EXISTING OPTIONS ==================
            --user)
                USERNAME="$2"
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
                
            --dry-run)
                DRY_RUN=true
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

# ============ BACKWARD COMPATIBILITY: SEARCH -> VIEW ==================
# Route old --search commands to new --view with search parameter
route_search_to_view() {
    if [ "$OPERATION" = "--search" ]; then
        OPERATION="--view"
        # search pattern is already in VIEW_SEARCH
        # search filters already in VIEW_FILTER, VIEW_IN_GROUP, VIEW_HAS_MEMBER
        log_debug "Routing --search to --view (backward compatibility)"
    fi
}

# ============ OPERATION ROUTER ==================
execute_operation() {
    show_dry_run_banner
    
    # Route old search commands to view
    route_search_to_view
    
    case "$OPERATION" in
        --add)
            [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing --names <file> or --input <file>"; exit 1; }
            case "$ACTION" in
                user)
                    if [ "$JSON_INPUT" = true ]; then
                        add_users_from_json "$FILE"
                    else
                        add_users "$FILE"
                    fi
                    ;;
                group) 
                    add_groups "$FILE" 
                    ;;
                user-group) 
                    add_users_to_groups "$FILE" 
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
                lock_user "$USERNAME" "$LOCK_REASON"
            elif [ -n "$FILE" ]; then
                if [ "$JSON_INPUT" = true ]; then
                    lock_users "$FILE" "json" "$LOCK_REASON"
                else
                    lock_users "$FILE" "text" "$LOCK_REASON"
                fi
            else
                echo "${ICON_ERROR} Missing --name <username> or --names <file>"
                exit 1
            fi
            ;;
            
        --unlock)
            if [ -n "$USERNAME" ]; then
                unlock_user "$USERNAME"
            elif [ -n "$FILE" ]; then
                if [ "$JSON_INPUT" = true ]; then
                    unlock_users "$FILE" "json"
                else
                    unlock_users "$FILE" "text"
                fi
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
            # TODO: Phase 2 - Implement new view.sh functions with all parameters
            # For now, route to existing view functions
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
                        view_recent_logins_json "$VIEW_TIME_PARAM" "" "$USERNAME"
                    else
                        view_recent_logins "$VIEW_TIME_PARAM" "" "$USERNAME"
                    fi
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
            [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing role file"; exit 1; }
            apply_roles_from_json "$FILE"
            ;;
            
        --manage-groups)
            [ -z "$FILE" ] && { echo "${ICON_ERROR} Missing groups file"; exit 1; }
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