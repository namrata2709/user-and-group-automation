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
        # Set default password from config
        echo "$username:$DEFAULT_PASSWORD" | chpasswd
        if [ $? -eq 0 ]; then
            # Force password change on first login
            chage -d 0 "$username"
            if [ $? -eq 0 ]; then
                echo "SUCCESS: User '$username' created with default password"
                echo "INFO: User must change password on first login"
                return 0
            else
                echo "WARNING: User created but password expiration failed"
                return 1
            fi
        else
            echo "WARNING: User '$username' created but password setting failed"
            return 1
        fi
    else
        echo "ERROR: Failed to create user '$username'"
        return 1
    fi
}