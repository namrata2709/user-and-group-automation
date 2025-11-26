add_user() {
    local username="$1"

    # Validate username
    if ! validate_username "$username"; then
        echo "ERROR: Invalid username format"
        return 1
    fi
    
    # Check if user exists
    if [ "$(user_exists "$username")" = "yes" ]; then
        echo "ERROR: User '$username' already exists"
        return 1
    fi

    # Create user
    if useradd -m "$username"; then
        echo "SUCCESS: User '$username' created successfully"
        return 0
    else
        echo "ERROR: Failed to create user '$username'"
        return 1
    fi
}