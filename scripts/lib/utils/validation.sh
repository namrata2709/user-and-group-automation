validate_username() {
    local username="$1"

    # Empty username
    if [[ -z "$username" ]]; then
        return 1
    fi

    # Length check
    local len=${#username}
    if (( len > 32 )); then
        return 1
    fi

    # Cannot end with hyphen
    if [[ $username == *- ]]; then
        return 1
    fi

    # Main regex validation
    if ! [[ $username =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        return 1
    fi

    return 0
}
