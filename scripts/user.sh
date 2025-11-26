#!/usr/bin/env bash

# Source configuration
CONFIG_FILE="/opt/admin_dashboard/config/user_mgmt.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source ./lib/utils/validation.sh
source ./lib/user_helper.sh
source ./lib/user_add.sh
# In future: source ./lib/group_add.sh

main() {
    local command=""
    local target_type=""
    local username=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --add)
                command="add"
                # The next argument must be "user" or "group"
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

            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
        shift
    done

    # Execute requested action
    if [ "$command" = "add" ]; then
        if [ "$target" = "user" ]; then
            add_user "$username"
        elif [ "$target" = "group" ]; then
            # add_group "$groupname"  # Future implementation
            echo "ERROR: Group operations not yet implemented"
        else
            echo "ERROR: Invalid target. Use --target user or --target group"
            return 1
        fi
        return
    fi

    echo "No valid command provided"
    exit 1
}

main "$@"
