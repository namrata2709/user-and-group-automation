#!/usr/bin/env bash

# ================================================
# User Management System - Main Entry Point
# File: user.sh
# Version: 1.0
# ================================================

# ================================================
# Check if running as root
# ================================================
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0 [options]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_MARKER="/opt/admin_dashboard/.installed"

# ================================================
# Check if system is initialized
# ================================================
if [ ! -f "$INSTALL_MARKER" ]; then
    echo "ERROR: System not initialized"
    echo ""
    echo "Please run the installation script first:"
    echo "  sudo ./install.sh"
    echo ""
    exit 1
fi

# Source configuration
CONFIG_FILE="/opt/admin_dashboard/config/user_mgmt.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Source library files
source "$SCRIPT_DIR/lib/utils/validation.sh"
source "$SCRIPT_DIR/lib/utils/helpers.sh"
source "$SCRIPT_DIR/lib/utils/shell_mapper.sh"
source "$SCRIPT_DIR/lib/utils/sudo_manager.sh"
source "$SCRIPT_DIR/lib/helpers/existence_check.sh"
source "$SCRIPT_DIR/lib/add/user_add.sh"
source "$SCRIPT_DIR/lib/add/group_add.sh"

# Rest of your main() function stays the same...
main() {
    local command=""
    local target_type=""
    local username=""
    local use_random="no"
    local shell_path=""
    local shell_role=""
    local sudo_access=""
    local primary_group=""
    local secondary_groups=""
    local password_expiry=""
    local password_warning=""

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
            
            --random)
                use_random="yes"
                ;;
            
            --shell)
                if [[ -z "$2" ]]; then
                    echo "Error: --shell requires a path argument" >&2
                    exit 1
                fi
                shell_path="$2"
                shift
                ;;
            
            --shell-role)
                if [[ -z "$2" ]]; then
                    echo "Error: --shell-role requires an argument" >&2
                    exit 1
                fi
                shell_role="$2"
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

            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
        shift
    done

    if [ "$command" = "add" ]; then
        if [[ "$target_type" = "user" ]]; then
            add_user "$username" "$use_random" "$shell_path" "$shell_role" "$sudo_access" "$primary_group" "$secondary_groups" "$password_expiry" "$password_warning"
        elif [[ "$target_type" = "group" ]]; then
            add_group "$username"
        else
            echo "ERROR: Invalid target"
            return 1
        fi
        return
    fi

    echo "No valid command provided"
    exit 1
}

main "$@"s