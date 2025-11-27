add_user() {
    local username="$1"
    local use_random="$2"
    local shell_path="$3"
    local shell_role="$4"
    local sudo_access="$5"
    local primary_group="$6"
    local secondary_groups="$7"
    local password_expiry="$8"    # Days until password expires (optional)
    local password_warning="$9"   # Warning days before expiry (optional)
    local password=""
    local user_shell=""
    local group_option=""
    local groups_option=""

    # Use defaults if not specified
    if [ -z "$password_expiry" ]; then
        password_expiry="$PASSWORD_EXPIRY_DAYS"
    fi
    
    if [ -z "$password_warning" ]; then
        password_warning="$PASSWORD_WARN_DAYS"
    fi

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

    # Handle primary group
    if [ -n "$primary_group" ]; then
        if [ "$(group_exists "$primary_group")" = "no" ]; then
            echo "INFO: Primary group '$primary_group' does not exist, creating..."
            if ! add_group "$primary_group"; then
                echo "ERROR: Failed to create primary group '$primary_group'"
                return 1
            fi
        fi
        group_option="-g $primary_group"
        echo "INFO: Using primary group: $primary_group"
    else
        echo "INFO: Using default primary group (same as username)"
    fi

    # Handle secondary groups
    if [ -n "$secondary_groups" ]; then
        IFS=',' read -ra GROUP_ARRAY <<< "$secondary_groups"
        local missing_groups=()
        
        for group in "${GROUP_ARRAY[@]}"; do
            group=$(echo "$group" | xargs)
            
            if [ "$(group_exists "$group")" = "no" ]; then
                echo "INFO: Secondary group '$group' does not exist, creating..."
                if add_group "$group"; then
                    echo "INFO: Secondary group '$group' created"
                else
                    missing_groups+=("$group")
                fi
            fi
        done
        
        if [ ${#missing_groups[@]} -gt 0 ]; then
            echo "ERROR: Failed to create groups: ${missing_groups[*]}"
            return 1
        fi
        
        groups_option="-G $secondary_groups"
        echo "INFO: Adding user to secondary groups: $secondary_groups"
    fi

    # Determine shell
    if [ -n "$shell_path" ]; then
        if validate_shell_path "$shell_path"; then
            user_shell="$shell_path"
            echo "INFO: Using explicitly specified shell: $user_shell"
        else
            echo "ERROR: Invalid or non-existent shell path: $shell_path"
            return 1
        fi
    elif [ -n "$shell_role" ]; then
        user_shell=$(get_shell_for_role "$shell_role")
        if [ -z "$user_shell" ]; then
            echo "ERROR: Invalid shell role: $shell_role"
            echo "Valid roles: admin, developer, support, intern, manager"
            return 1
        fi
        echo "INFO: Using shell for role '$shell_role': $user_shell"
    else
        user_shell="$DEFAULT_SHELL"
        echo "INFO: Using default shell from config: $user_shell"
    fi

    # Determine sudo access
    if [ -z "$sudo_access" ]; then
        sudo_access="$DEFAULT_SUDO"
    fi

    # Determine password
    if [ "$use_random" = "yes" ]; then
        password=$(generate_random_password)
        echo "INFO: Generated random password for user '$username'"
    else
        password="$DEFAULT_PASSWORD"
        echo "INFO: Using default password from config"
    fi

    # Create user
    if useradd -m -s "$user_shell" $group_option $groups_option "$username"; then
        echo "INFO: User account created successfully"
        
        # Set password
        echo "$username:$password" | chpasswd
        if [ $? -eq 0 ]; then
            echo "INFO: Password set successfully"
            
            # Configure password policies (skip for nologin users)
            if [ "$user_shell" != "/usr/sbin/nologin" ] && [ "$user_shell" != "/sbin/nologin" ]; then
                # Force password change on first login
                chage -d 0 "$username"
                
                # Set password expiry and warning
                chage -M "$password_expiry" -W "$password_warning" "$username"
                
                if [ $? -eq 0 ]; then
                    echo "INFO: Password must be changed on first login"
                    echo "INFO: Password expires every $password_expiry days"
                    echo "INFO: Warning $password_warning days before expiry"
                fi
            else
                echo "INFO: Skipping password policies for nologin user"
            fi
            
            # Handle sudo access
            if [ "$sudo_access" = "allow" ]; then
                grant_sudo_access "$username"
            elif [ "$sudo_access" = "deny" ]; then
                echo "INFO: Sudo access denied"
            else
                echo "WARNING: Invalid sudo option '$sudo_access', defaulting to deny"
            fi
            
            # Store encrypted password if random
            if [ "$use_random" = "yes" ]; then
                echo "INFO: Storing encrypted password..."
                store_encrypted_password "$username" "$password"
            fi
            
            echo "SUCCESS: User '$username' created successfully"
            return 0
        else
            echo "WARNING: User created but password setting failed"
            return 1
        fi
    else
        echo "ERROR: Failed to create user '$username'"
        return 1
    fi
}