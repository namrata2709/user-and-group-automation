#!/usr/bin/env bash
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0 [options]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_MARKER="/opt/admin_dashboard/.installed"
if [ ! -f "$INSTALL_MARKER" ]; then
    echo "ERROR: System not initialized"
    echo ""
    echo "Please run the installation script first:"
    echo "  sudo ./install.sh"
    echo ""
    exit 1
fi
CONFIG_FILE="/opt/admin_dashboard/config/user_mgmt.conf"

# Source config loader
source "$SCRIPT_DIR/lib/core/config.sh"

# Load and validate configuration
if ! load_config "$CONFIG_FILE"; then
    echo ""
    echo "Configuration validation failed. Please fix the issues above."
    exit 1
fi
# Source core libraries
source "$SCRIPT_DIR/lib/core/config.sh"
source "$SCRIPT_DIR/lib/core/logging.sh"
source "$SCRIPT_DIR/lib/core/validation.sh"

# Source helpers
source "$SCRIPT_DIR/lib/helpers/existence_check.sh"
source "$SCRIPT_DIR/lib/helpers/password.sh"
source "$SCRIPT_DIR/lib/helpers/sudo_manager.sh"
source "$SCRIPT_DIR/lib/helpers/role_policy.sh"

# Source operations
source "$SCRIPT_DIR/lib/operations/user/add.sh"
source "$SCRIPT_DIR/lib/operations/group/add.sh"

source "$SCRIPT_DIR/lib/batch/common.sh"
# Source batch processors
source "$SCRIPT_DIR/lib/batch/processors/user_batch.sh"
source "$SCRIPT_DIR/lib/batch/processors/group_batch.sh"

# Source user parsers
source "$SCRIPT_DIR/lib/batch/parsers/user/text.sh"
source "$SCRIPT_DIR/lib/batch/parsers/user/json.sh"
source "$SCRIPT_DIR/lib/batch/parsers/user/yaml.sh"
source "$SCRIPT_DIR/lib/batch/parsers/user/xlsx.sh"

# Source group parsers
source "$SCRIPT_DIR/lib/batch/parsers/group/text.sh"
source "$SCRIPT_DIR/lib/batch/parsers/group/json.sh"
source "$SCRIPT_DIR/lib/batch/parsers/group/yaml.sh"
source "$SCRIPT_DIR/lib/batch/parsers/group/xlsx.sh"
parse_arguments() {
    command=""
    entity_type=""
    username=""
    comment=""
    use_random="no"
    shell_value=""
    sudo_access=""
    primary_group=""
    secondary_groups=""
    password_expiry=""
    password_warning=""
    account_expiry=""
    batch_file=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --add)
                command="add"
                if [[ -z "$2" ]]; then
                    echo "Error: --add requires 'user' or 'group'" >&2
                    exit 1
                fi
                case "$2" in
                    user|group)
                        entity_type="$2"
                        ;;
                    *)
                        echo "Error: Unknown target for --add: $2" >&2
                        exit 1
                        ;;
                esac
                shift
                ;;
            --name)
                if [[ -z "$2" ]]; then
                    echo "Error: --name requires an argument" >&2
                    exit 1
                fi
                username="$2"
                shift
                ;;
            --comment)
                if [[ -z "$2" ]]; then
                    echo "Error: --comment requires an argument" >&2
                    exit 1
                fi
                comment="$2"
                shift
                ;;
            --random)
                use_random="yes"
                ;;
            --shell)
                if [[ -z "$2" ]]; then
                    echo "Error: --shell requires a path or role name" >&2
                    exit 1
                fi
                shell_value="$2"
                shift
                ;;
            --sudo)
                if [[ -z "$2" ]]; then
                    echo "Error: --sudo requires 'allow' or 'deny'" >&2
                    exit 1
                fi
                case "$2" in
                    allow|deny)
                        sudo_access="$2"
                        ;;
                    *)
                        echo "Error: --sudo must be 'allow' or 'deny'" >&2
                        exit 1
                        ;;
                esac
                shift
                ;;
            --primary-group|--pgroup)
                if [[ -z "$2" ]]; then
                    echo "Error: --primary-group requires a group name" >&2
                    exit 1
                fi
                primary_group="$2"
                shift
                ;;
            --groups|--sgroups)
                if [[ -z "$2" ]]; then
                    echo "Error: --groups requires comma-separated group names" >&2
                    exit 1
                fi
                secondary_groups="$2"
                shift
                ;;
            --password-expiry|--pexpiry)
                if [[ -z "$2" ]]; then
                    echo "Error: --password-expiry requires number of days" >&2
                    exit 1
                fi
                password_expiry="$2"
                shift
                ;;
            --password-warning|--pwarn)
                if [[ -z "$2" ]]; then
                    echo "Error: --password-warning requires number of days" >&2
                    exit 1
                fi
                password_warning="$2"
                shift
                ;;
            --expire|--account-expiry)
                if [[ -z "$2" ]]; then
                    echo "Error: --expire requires days/role/date" >&2
                    exit 1
                fi
                account_expiry="$2"
                shift
                ;;
            --batch-add|--batch)
                command="batch-add"
                if [[ -z "$2" ]]; then
                    echo "Error: --batch-add requires 'user' or 'group'" >&2
                    exit 1
                fi
                case "$2" in
                    user|group)
                        entity_type="$2"
                        ;;
                    *)
                        echo "Error: Unknown target for --batch-add: $2" >&2
                        exit 1
                        ;;
                esac
                shift
                ;;
            --file)
                if [[ -z "$2" ]]; then
                    echo "Error: --file requires a file path" >&2
                    exit 1
                fi
                batch_file="$2"
                if [[ ! -f "$batch_file" ]]; then
                    echo "Error: File not found: $batch_file" >&2
                    exit 1
                fi
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
        shift
    done
}

handle_add_command() {
    if [[ "$entity_type" = "user" ]]; then
        add_user "$username" "$comment" "$use_random" "$shell_value" "$sudo_access" "$primary_group" "$secondary_groups" "$password_expiry" "$password_warning" "$account_expiry"
    elif [[ "$entity_type" = "group" ]]; then
        add_group "$username"
    else
        echo "ERROR: Invalid entity type"
        return 1
    fi
}

handle_batch_add_command() {
    if [ -z "$batch_file" ]; then
        echo "ERROR: --batch-add requires --file parameter"
        return 1
    fi
    
    if [ ! -f "$batch_file" ]; then
        echo "ERROR: File not found: $batch_file"
        return 1
    fi
    
    local file_extension="${batch_file##*.}"
    
    if [[ "$entity_type" = "user" ]]; then
        case "$file_extension" in
            txt|csv)
                parse_user_text_file "$batch_file" || return 1
                ;;
            json)
                parse_user_json_file "$batch_file" || return 1
                ;;
            yaml|yml)
                parse_user_yaml_file "$batch_file" || return 1
                ;;
            xlsx)
                parse_user_xlsx_file "$batch_file" || return 1
                ;;
            *)
                echo "ERROR: Unsupported file format: $file_extension"
                echo "Supported formats: txt, csv, json, yaml, xlsx"
                return 1
                ;;
        esac
        
        process_batch_users || return 1
        
    elif [[ "$entity_type" = "group" ]]; then
        case "$file_extension" in
            txt|csv)
                parse_group_text_file "$batch_file" || return 1
                ;;
            json)
                parse_group_json_file "$batch_file" || return 1
                ;;
            yaml|yml)
                parse_group_yaml_file "$batch_file" || return 1
                ;;
            xlsx)
                parse_group_xlsx_file "$batch_file" || return 1
                ;;
            *)
                echo "ERROR: Unsupported file format: $file_extension"
                echo "Supported formats: txt, csv, json, yaml, xlsx"
                return 1
                ;;
        esac
        
        process_batch_groups || return 1
        
    else
        echo "ERROR: Invalid entity type for batch-add"
        return 1
    fi
}
main() {
    parse_arguments "$@"
    
    case "$command" in
        add)
            handle_add_command
            ;;
        batch-add)
            handle_batch_add_command
            ;;
        *)
            echo "ERROR: No valid command provided"
            echo ""
            echo "Usage: $0 COMMAND [OPTIONS]"
            echo ""
            echo "Commands:"
            echo "  --add user         Add a single user"
            echo "  --add group        Add a single group"
            echo "  --batch-add user   Add multiple users from file"
            echo "  --batch-add group  Add multiple groups from file"
            echo ""
            echo "Examples:"
            echo "  $0 --add user --name alice --comment \"Alice:Eng\""
            echo "  $0 --add group --name developers"
            echo "  $0 --batch-add user --file users.txt"
            echo "  $0 --batch-add group --file groups.json"
            echo ""
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"