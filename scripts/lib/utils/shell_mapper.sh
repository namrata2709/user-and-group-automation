#!/bin/bash

get_shell_for_role() {
    local role="$1"
    
    case "$role" in
        admin)
            echo "$SHELL_ROLE_ADMIN"
            return 0
            ;;
        developer)
            echo "$SHELL_ROLE_DEVELOPER"
            return 0
            ;;
        support)
            echo "$SHELL_ROLE_SUPPORT"
            return 0
            ;;
        intern)
            echo "$SHELL_ROLE_INTERN"
            return 0
            ;;
        manager)
            echo "$SHELL_ROLE_MANAGER"
            return 0
            ;;
        contractor)
            echo "$SHELL_ROLE_CONTRACTOR"
            return 0
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

validate_shell_path() {
    local shell_path="$1"
    
    if [ -z "$shell_path" ]; then
        return 1
    fi
    
    if [ -x "$shell_path" ]; then
        return 0
    else
        return 1
    fi
}

validate_shell_path() {
    local shell_path="$1"
    
    if [ -z "$shell_path" ]; then
        return 1
    fi
    
    # Check if shell exists and is executable
    if [ -x "$shell_path" ]; then
        return 0
    else
        return 1
    fi
}