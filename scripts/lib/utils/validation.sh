validate_username() {
    local username="$1"

    if [ -z "$username" ]; then
        return 2
    fi
    
    # Additional check: cannot end with hyphen
    if echo "$username" | grep -q '-$'; then
        return 1
    fi

    if ! echo "$username" | grep -qE '^[a-z_][a-z0-9_-]*$'; then
        return 1
    fi
    
    # Additional check: cannot end with hyphen
    if echo "$username" | grep -q '-$'; then
        return 1
    fi

    return 0

}