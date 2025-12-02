# ================================================
# Add User - Pure Creation Logic
# ================================================
# Arguments:
#   $1  - Username
#   $2  - Comment (firstname lastname:department)
#   $3  - Use random password (yes/no)
#   $4  - Shell value (path or role)
#   $5  - Sudo access (allow/deny)
#   $6  - Primary group
#   $7  - Secondary groups (comma-separated)
#   $8  - Password expiry days
#   $9  - Password warning days
#   $10 - Account expiry (days/date/role)
#   $11 - Trusted flag (yes/no, default: no)
# Returns:
#   0 on success, 1 on failure
# ================================================
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
    local trusted="${11}"  # No default here
    
    # Default trusted to "no" if empty
    if [ -z "$trusted" ]; then
        trusted="no"
    fi
    
    # Variables that will be set by role or explicit values
    local user_shell=""
    local sudo_access=""
    local account_expiry_days=""
    local expiry_date=""
    
    local password=""
    local group_option=""
    local groups_option=""
    local safe_comment="${comment//:/ - }"
    
    # Log activity start
    log_activity "Starting user creation for: $username"
    
    # Apply defaults
    if [ -z "$password_expiry" ]; then
        password_expiry="$PASSWORD_EXPIRY_DAYS"
    fi
    
    if [ -z "$password_warning" ]; then
        password_warning="$PASSWORD_WARN_DAYS"
    fi

    # ================================================
    # VALIDATION - Only if NOT trusted
    # ================================================
    if [ "$trusted" != "yes" ]; then
        if ! validate_user_input "$username" "$comment" "$shell_value" "$sudo_input" "$primary_group" "$secondary_groups" "$password_expiry" "$password_warning" "$account_expiry"; then
            log_audit "ADD_USER" "$username" "FAILED" "Input validation failed"
            return 1
        fi
        log_activity "Input validation passed: $username"
    fi

    # ================================================
    # GROUP HANDLING
    # ================================================
    
    # Set sudo_access from input if provided
    sudo_access="$sudo_input"

    # Handle primary group
    if [ -n "$primary_group" ]; then
        if [ "$(group_exists "$primary_group")" = "no" ]; then
            echo "INFO: Primary group '$primary_group' does not exist, creating..."
            if ! add_group "$primary_group" "$trusted"; then
                echo "ERROR: Failed to create primary group '$primary_group'"
                log_audit "ADD_USER" "$username" "FAILED" "Failed to create primary group: $primary_group"
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
                if add_group "$group" "$trusted"; then
                    echo "INFO: Secondary group '$group' created"
                else
                    missing_groups+=("$group")
                fi
            fi
        done
        
        if [ ${#missing_groups[@]} -gt 0 ]; then
            echo "ERROR: Failed to create groups: ${missing_groups[*]}"
            log_audit "ADD_USER" "$username" "FAILED" "Failed to create secondary groups: ${missing_groups[*]}"
            return 1
        fi
        
        groups_option="-G $secondary_groups"
        echo "INFO: Adding user to secondary groups: $secondary_groups"
    fi

    # ================================================
    # SHELL & ROLE DETERMINATION
    # ================================================
    
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
        fi
    else
        # No shell specified, use defaults
        user_shell="$DEFAULT_SHELL"
        sudo_access="${sudo_access:-$DEFAULT_SUDO}"
        echo "INFO: Using default shell: $user_shell"
    fi

    # ================================================
    # ACCOUNT EXPIRY CALCULATION
    # ================================================
    
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

    # ================================================
    # PASSWORD GENERATION
    # ================================================
    
    if [ "$use_random" = "yes" ]; then
        password=$(generate_random_password)
        echo "INFO: Generated random password"
    else
        password="$DEFAULT_PASSWORD"
        echo "INFO: Using default password"
    fi

    # ================================================
    # USER CREATION
    # ================================================
    
    local expiry_option=""
    if [ -n "$expiry_date" ]; then
        expiry_option="-e $expiry_date"
    fi
    
    if useradd -m -c "$safe_comment" -s "$user_shell" $group_option $groups_option $expiry_option "$username"; then
        echo "INFO: User account created successfully"
        log_activity "User account created: $username (Shell: $user_shell, Groups: $primary_group${secondary_groups:+,$secondary_groups})"
        
        # Set password
        echo "$username:$password" | chpasswd
        if [ $? -eq 0 ]; then
            echo "INFO: Password set successfully"
            log_activity "Password configured for: $username"
            
            # Password policies (skip for nologin users)
            if [ "$user_shell" != "/usr/sbin/nologin" ] && [ "$user_shell" != "/sbin/nologin" ]; then
                chage -d 0 "$username"
                chage -M "$password_expiry" -W "$password_warning" "$username"
                echo "INFO: Password must be changed on first login"
                echo "INFO: Password expires every $password_expiry days"
            else
                echo "INFO: Skipping password policies for nologin user"
            fi
            
            # Sudo access
            if [ "$sudo_access" = "allow" ]; then
                grant_sudo_access "$username"
                log_activity "Sudo access granted to: $username"
            else
                echo "INFO: Sudo access denied"
            fi
            
            # Store encrypted password if random
            if [ "$use_random" = "yes" ]; then
                store_encrypted_password "$username" "$password"
                log_activity "Random password encrypted and stored for: $username"
            fi
            
            echo "SUCCESS: User '$username' created successfully"
            log_audit "ADD_USER" "$username" "SUCCESS" "User: $username, Shell: $user_shell, Comment: $safe_comment, Expiry: ${expiry_date:-never}, Sudo: $sudo_access"
            return 0
        else
            echo "ERROR: Failed to set password for user '$username'"
            log_audit "ADD_USER" "$username" "FAILED" "chpasswd failed"
            return 1
        fi
    else
        echo "ERROR: Failed to create user '$username'"
        log_audit "ADD_USER" "$username" "FAILED" "useradd command failed"
        return 1
    fi
}