add_user() {
    local username="$1"
    local use_random="$2"  # "yes" or "no"
    local password=""

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

    # Determine password to use
    if [ "$use_random" = "yes" ]; then
        password=$(generate_random_password)
        echo "INFO: Generated random password for user '$username'"
    else
        password="$DEFAULT_PASSWORD"
        echo "INFO: Using default password from config"
    fi

    # Create user
    if useradd -m "$username"; then
        echo "INFO: User account created, setting password..."
        
        # Set password
        echo "$username:$password" | chpasswd
        if [ $? -eq 0 ]; then
            echo "INFO: Password set successfully"
            
            # Force password change on first login
            chage -d 0 "$username"
            if [ $? -eq 0 ]; then
                echo "INFO: Password expiration configured"
                
                # Store encrypted password if random was used
                if [ "$use_random" = "yes" ]; then
                    echo "INFO: Storing encrypted password..."
                    store_encrypted_password "$username" "$password"
                fi
                
                echo "SUCCESS: User '$username' created successfully"
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