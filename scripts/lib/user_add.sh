
add_user() {
    local username="$1"

    if ! validate_username "$username"; then
        return 1
    fi
    if [ "$(user_exists "$username")" = "yes" ]; then
        return 1
    fi

    if useradd -m "$username"; then
        return 0
    else
        return 1
    fi
}