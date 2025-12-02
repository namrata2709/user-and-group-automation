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
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi
source "$SCRIPT_DIR/lib/utils/validation.sh"
source "$SCRIPT_DIR/lib/utils/logging.sh"
source "$SCRIPT_DIR/lib/utils/role_validator.sh"
source "$SCRIPT_DIR/lib/utils/helpers.sh"
source "$SCRIPT_DIR/lib/utils/sudo_manager.sh"
source "$SCRIPT_DIR/lib/helpers/existence_check.sh"
source "$SCRIPT_DIR/lib/add/user_add.sh"
source "$SCRIPT_DIR/lib/add/group_add.sh"
source "$SCRIPT_DIR/lib/batch/batch_processor.sh"
source "$SCRIPT_DIR/lib/batch/parsers/text_parser.sh"
main() {
    local command=""
    local target_type=""
    local username=""
    local comment=""
    local use_random="no"
    local shell_value=""
    local sudo_access=""
    local primary_group=""
    local secondary_groups=""
    local password_expiry=""
    local password_warning=""
    local account_expiry=""
    local batch_file=""
    
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
                        target_type="$2"
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
                command="batch_add"
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

    if [ "$command" = "add" ]; then
        if [[ "$target_type" = "user" ]]; then
            add_user "$username" "$comment" "$use_random" "$shell_value" "$sudo_access" "$primary_group" "$secondary_groups" "$password_expiry" "$password_warning" "$account_expiry"
        elif [[ "$target_type" = "group" ]]; then
            add_group "$username"
        else
            echo "ERROR: Invalid target"
            return 1
        fi
        return
    fi
    if [ "$command" = "batch_add" ]; then
        if [[ -z "$batch_file" ]]; then
            echo "ERROR: --file argument required for batch operations"
            return 1
        fi
        
        # Detect file type and parse
        local file_ext="${batch_file##*.}"
        
        case "$file_ext" in
            txt)
                if ! parse_text_file "$batch_file"; then
                    echo "ERROR: Failed to parse text file"
                    return 1
                fi
                ;;
            csv)
                echo "ERROR: CSV parser not yet implemented"
                return 1
                ;;
            json)
                echo "ERROR: JSON parser not yet implemented"
                return 1
                ;;
            yaml|yml)
                echo "ERROR: YAML parser not yet implemented"
                return 1
                ;;
            xlsx)
                echo "ERROR: XLSX parser not yet implemented"
                return 1
                ;;
            *)
                echo "ERROR: Unsupported file type: .$file_ext"
                echo "Supported: .txt, .csv, .json, .yaml, .xlsx"
                return 1
                ;;
        esac
        
        # Run batch processor
        process_batch_users
        return $?
    fi
    echo "No valid command provided"
    exit 1
}

main "$@"