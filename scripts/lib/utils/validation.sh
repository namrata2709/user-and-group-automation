#!/bin/bash

# Validate username format
validate_username() {
    local username="$1"

    [ -z "$username" ] && return 1
    
    local len=${#username}
    [ "$len" -gt 32 ] && return 2
    
    echo "$username" | grep -qE '^[a-z_][a-z0-9_-]*$' || return 3
    
    echo "$username" | grep -q '-$' && return 4
    
    return 0
}

# Validate shell path exists and is executable
validate_shell_path() {
    local shell_path="$1"
    
    [ -z "$shell_path" ] && return 1
    [ -x "$shell_path" ] && return 0
    return 1
}

# Check if value is a valid role
is_valid_role() {
    local role="$1"
    case "$role" in
        admin|developer|support|intern|manager|contractor)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}