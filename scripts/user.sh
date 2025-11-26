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
source "$SCRIPT_DIR/lib/user_helper.sh"
source "$SCRIPT_DIR/lib/user_add.sh"

# Rest of your main() function stays the same...
main() {
    local command=""
    local target_type=""
    local username=""
    local use_random="no"
    local shell_path=""
    local shell_role=""

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

            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
        shift
    done

    if [ "$command" = "add" ]; then
        if [[ "$target_type" = "user" ]]; then
            add_user "$username" "$use_random" "$shell_path" "$shell_role"
        elif [[ "$target_type" = "group" ]]; then
            echo "ERROR: Group operations not yet implemented"
        else
            echo "ERROR: Invalid target. Use --add user or --add group"
            return 1
        fi
        return
    fi

    echo "No valid command provided"
    exit 1
}

main "$@"