add_user() {
    local username="$1"
    local comment="$2"
    local use_random="$3"
    local shell_value="$4"
    local sudo_input="$5"
    local primary_group="$6"
    local secondary_groups="$7"
    local password_expiry="$8"
    local password_warning="$9"
    local account_expiry="${10}"
    
    # Variables that will be set by role or explicit values
    local user_shell=""
    local sudo_access=""
    local account_expiry_days=""
    local expiry_date=""
    
    local password=""
    local group_option=""
    local groups_option=""

    local safe_comment="${comment//:/ - }"
    # Defaults
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

    if ! validate_comment "$comment"; then
        return 1
    fi
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

    # Set sudo_access from input if provided
    sudo_access="$sudo_input"

    # Determine shell - detect if role and apply all defaults
    if [ -n "$shell_value" ]; then
        if validate_shell_path "$shell_value"; then
            # It's a valid path
            user_shell="$shell_value"
            echo "INFO: Using shell path: $user_shell"
            
            # Use defaults for other settings
            if [ -z "$sudo_access" ]; then
                sudo_access="$DEFAULT_SUDO"
            fi
        elif is_valid_role "$shell_value"; then
            # It's a role - apply all role defaults
            apply_role_defaults "$shell_value"
        else
            echo "ERROR: Invalid shell. Not a valid path or role"
            echo "Valid roles: admin, developer, support, intern, manager, contractor"
            return 1
        fi
    else
        # No shell specified, use defaults
        user_shell="$DEFAULT_SHELL"
        sudo_access="${sudo_access:-$DEFAULT_SUDO}"
        echo "INFO: Using default shell: $user_shell"
    fi

    # Parse account_expiry - can override role default
    if [ -n "$account_expiry" ]; then
        if [[ "$account_expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            # Date format
            expiry_date="$account_expiry"
            echo "INFO: Using explicit expiry date: $expiry_date"
        elif [[ "$account_expiry" =~ ^[0-9]+$ ]]; then
            # Number of days
            if [ "$account_expiry" -eq 0 ]; then
                echo "INFO: Account will never expire"
            else
                expiry_date=$(date -d "+${account_expiry} days" +%Y-%m-%d)
                echo "INFO: Account expires in $account_expiry days (on $expiry_date)"
            fi
        elif is_valid_role "$account_expiry"; then
            # Role name - get expiry for that role
            apply_role_defaults "$account_expiry"
            if [ -n "$account_expiry_days" ] && [ "$account_expiry_days" != "0" ]; then
                expiry_date=$(date -d "+${account_expiry_days} days" +%Y-%m-%d)
                echo "INFO: Using role '$account_expiry' expiry: $account_expiry_days days (on $expiry_date)"
            fi
        else
            echo "ERROR: Invalid expiry value: $account_expiry"
            return 1
        fi
    else
        # Use role-based expiry if set
        if [ -n "$account_expiry_days" ] && [ "$account_expiry_days" != "0" ]; then
            expiry_date=$(date -d "+${account_expiry_days} days" +%Y-%m-%d)
            echo "INFO: Account expires in $account_expiry_days days (on $expiry_date)"
        elif [ -n "$DEFAULT_ACCOUNT_EXPIRY" ] && [ "$DEFAULT_ACCOUNT_EXPIRY" != "0" ]; then
            expiry_date=$(date -d "+${DEFAULT_ACCOUNT_EXPIRY} days" +%Y-%m-%d)
            echo "INFO: Using default account expiry: $DEFAULT_ACCOUNT_EXPIRY days"
        else
            echo "INFO: Account will never expire"
        fi
    fi

    # Determine password
    if [ "$use_random" = "yes" ]; then
        password=$(generate_random_password)
        echo "INFO: Generated random password"
    else
        password="$DEFAULT_PASSWORD"
        echo "INFO: Using default password"
    fi

    # Create user
    local expiry_option=""
    if [ -n "$expiry_date" ]; then
        expiry_option="-e $expiry_date"
    fi
    
    if useradd -m -c "$safe_comment" -s "$user_shell" $group_option $groups_option $expiry_option "$username"; then
        
        echo "$username:$password" | chpasswd
        if [ $? -eq 0 ]; then
            echo "INFO: Password set successfully"
            
            if [ "$user_shell" != "/usr/sbin/nologin" ] && [ "$user_shell" != "/sbin/nologin" ]; then
                chage -d 0 "$username"
                chage -M "$password_expiry" -W "$password_warning" "$username"
                echo "INFO: Password must be changed on first login"
                echo "INFO: Password expires every $password_expiry days"
            else
                echo "INFO: Skipping password policies for nologin user"
            fi
            
            if [ "$sudo_access" = "allow" ]; then
                grant_sudo_access "$username"
            else
                echo "INFO: Sudo access denied"
            fi
            
            if [ "$use_random" = "yes" ]; then
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