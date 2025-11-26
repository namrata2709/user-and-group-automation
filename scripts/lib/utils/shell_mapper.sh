#!/bin/bash

# ================================================
# Shell Role Mapper
# File: lib/utils/shell_mapper.sh
# ================================================

# ================================================
# Get shell path based on role
# ================================================
# Arguments:
#   $1 - Role name (admin, developer, support, intern, manager)
# Returns:
#   Shell path or empty string if invalid role
# ================================================
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
        *)
            echo ""
            return 1
            ;;
    esac
}

# ================================================
# Validate shell path exists on system
# ================================================
# Arguments:
#   $1 - Shell path
# Returns:
#   0 if valid, 1 if not
# ================================================
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