#!/bin/bash

# Validate username format
validate_username() {
    local username="$1"

    if [ -z "$username" ]; then
        return 1
    fi
    
    local len=${#username}
    
    if [ "$len" -gt 32 ]; then
        return 1
    fi

    if ! [[ $username =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        return 1
    fi

    if [[ $username == *- ]]; then
        return 1
    fi

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

# Validate comment format
# Arguments:
#   $1 - Comment string
# Returns:
#   0 if valid, 1 if not
# Requires:
#   Comment string in format 'firstname lastname:department'
# Example:
#   validate_comment "John Doe:Sales"
validate_comment() {
    local comment="$1"

    if [ -z "$comment" ]; then
        echo "ERROR: Comment is required. Format: 'firstname lastname:department'"
        return 1
    fi

    if ! [[ "$comment" =~ ^[a-zA-Z'.-]+[[:space:]][a-zA-Z'.-]+:[a-zA-Z0-9_.-[:space:]]+$ ]]; then
        echo "ERROR: Invalid comment format. Expected 'firstname lastname:department'."
        echo "Example: 'John Doe:Sales'"
        return 1
    fi

    return 0
}