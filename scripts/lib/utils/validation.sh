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
#
# Checks for:
#   - Comment is not empty
#   - Colon separator is present
#   - Name and department parts are not empty
#   - Name part contains at least one space
#   - Name part does not start or end with a space
validate_comment() {
    local comment="$1"

    if [ -z "$comment" ]; then
        echo "ERROR: Comment is required. Format: 'firstname lastname:department'"
        return 1
    fi

    # Check for colon separator
    if ! [[ "$comment" =~ : ]]; then
        echo "ERROR: Invalid comment format. Missing colon separator. Expected 'firstname lastname:department'."
        echo "Example: 'John Doe:Sales'"
        return 1
    fi

    local name_part="${comment%%:*}"
    local dept_part="${comment#*:}"

    # Ensure name and department are not empty
    if [ -z "$name_part" ] || [ -z "$dept_part" ]; then
        echo "ERROR: Invalid comment format. Name and department parts cannot be empty."
        echo "Example: 'John Doe:Sales'"
        return 1
    fi

    # Ensure name part contains at least one space
    if ! [[ "$name_part" =~ [[:space:]] ]]; then
        echo "ERROR: Invalid comment format. The name part must contain a space (e.g., 'firstname lastname')."
        echo "Example: 'John Doe:Sales'"
        return 1
    fi

    # Ensure name part does not start or end with a space
    if [[ "$name_part" =~ ^[[:space:]] || "$name_part" =~ [[:space:]]$ ]]; then
        echo "ERROR: Invalid comment format. The name part cannot start or end with a space."
        return 1
    fi

    return 0
}