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

validate_user_input() {
    local username="$1"
    local comment="$2"
    local shell_value="$3"
    local sudo_access="$4"
    local primary_group="$5"
    local secondary_groups="$6"
    local password_expiry="$7"
    local password_warning="$8"
    local account_expiry="$9"
    
    local has_errors=0
    
    # Validate username
    if ! validate_username "$username"; then
        echo "ERROR: Invalid username format: $username"
        has_errors=1
    fi
    
    # Validate comment
    if ! validate_comment "$comment"; then
        has_errors=1
    fi
    
    # Check if user exists
    if [ "$(user_exists "$username")" = "yes" ]; then
        echo "ERROR: User '$username' already exists"
        has_errors=1
    fi
    
    # Validate shell value (if provided)
    if [ -n "$shell_value" ]; then
        # Check if it's a valid role or valid path
        if ! is_valid_role "$shell_value" && ! validate_shell_path "$shell_value"; then
            echo "ERROR: Invalid shell value: $shell_value"
            echo "Must be a valid role (admin/developer/support/intern/manager/contractor) or valid shell path"
            has_errors=1
        fi
    fi
    
    # Validate sudo access (if provided)
    if [ -n "$sudo_access" ]; then
        if [[ "$sudo_access" != "allow" && "$sudo_access" != "deny" ]]; then
            echo "ERROR: Invalid sudo access value: $sudo_access"
            echo "Must be 'allow' or 'deny'"
            has_errors=1
        fi
    fi
    
    # Validate primary group (if provided)
    if [ -n "$primary_group" ]; then
        if ! validate_groupname "$primary_group"; then
            echo "ERROR: Invalid primary group name: $primary_group"
            has_errors=1
        fi
    fi
    
    # Validate secondary groups (if provided)
    if [ -n "$secondary_groups" ]; then
        IFS=',' read -ra GROUP_ARRAY <<< "$secondary_groups"
        for group in "${GROUP_ARRAY[@]}"; do
            group=$(echo "$group" | xargs)  # trim whitespace
            if ! validate_groupname "$group"; then
                echo "ERROR: Invalid secondary group name: $group"
                has_errors=1
            fi
        done
    fi
    
    # Validate password expiry (if provided)
    if [ -n "$password_expiry" ]; then
        if ! [[ "$password_expiry" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid password expiry value: $password_expiry"
            echo "Must be a number (days)"
            has_errors=1
        fi
    fi
    
    # Validate password warning (if provided)
    if [ -n "$password_warning" ]; then
        if ! [[ "$password_warning" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid password warning value: $password_warning"
            echo "Must be a number (days)"
            has_errors=1
        fi
    fi
    
    # Validate account expiry (if provided)
    if [ -n "$account_expiry" ]; then
        # Can be: number (days), date (YYYY-MM-DD), or role name
        if ! [[ "$account_expiry" =~ ^[0-9]+$ ]] && \
           ! [[ "$account_expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && \
           ! is_valid_role "$account_expiry"; then
            echo "ERROR: Invalid account expiry value: $account_expiry"
            echo "Must be: number (days), date (YYYY-MM-DD), or valid role name"
            has_errors=1
        fi
    fi
    
    # Return result
    if [ $has_errors -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

validate_groupname() {
    local groupname="$1"

    # Check if empty
    if [ -z "$groupname" ]; then
        return 1
    fi
    
    # Check length (1-32 characters)
    local len=${#groupname}
    if [ "$len" -lt 1 ] || [ "$len" -gt 32 ]; then
        return 1
    fi

    # Check format: start with lowercase or underscore, contain lowercase/digits/hyphens/underscores
    if ! [[ $groupname =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        return 1
    fi

    # Cannot end with hyphen
    if [[ $groupname == *- ]]; then
        return 1
    fi

    return 0
}