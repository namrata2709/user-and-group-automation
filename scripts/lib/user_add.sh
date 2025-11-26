#!/usr/bin/env bash
# ================================================
# User Add Module
# Version: 1.0.1
# ================================================
# Handles adding users from files or JSON input
# ================================================

# add_users()
# Adds users from a text file
# Args:
#   $1 - user file path
# Format:
#   username:comment:expiry:shell:sudo:password
# Returns:
#   Summary of operations
add_users() {
    local user_file="$1"
    
    if [[ ! -f "$user_file" ]]; then
        echo "${ICON_ERROR} User file not found: $user_file"
        return 1
    fi
    
    echo "=========================================="
    echo "Adding Users from: $user_file"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    [ -n "$GLOBAL_EXPIRE" ] && echo "📅 Expiration: $GLOBAL_EXPIRE"
    [ -n "$GLOBAL_SHELL" ] && echo "🐚 Shell: $GLOBAL_SHELL"
    [ "$GLOBAL_SUDO" = true ] && echo "🔐 Sudo: enabled"
    [ "$GLOBAL_PASSWORD" = "random" ] && echo "🔑 Password: random (unique per user)"
    [ -n "$GLOBAL_PASSWORD_EXPIRY" ] && echo "⏱️  Password expiry: $GLOBAL_PASSWORD_EXPIRY days"
    echo "=========================================="
    echo ""
    
    local count=0 created=0 skipped=0 failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        count=$((count + 1))
        
        # Parse line: username:comment:expiry:shell:sudo:password
        local username comment expiry shell sudo password
        IFS=':' read -r username comment expiry shell sudo password <<< "$line"
        username=$(echo "$username" | xargs)
        
        # Validate username
        if ! validate_name "$username" "user"; then
            failed=$((failed + 1))
            continue
        fi
        
        # Use global shell if not specified
        [ -z "$shell" ] && shell="$GLOBAL_SHELL"
        [ -z "$shell" ] && shell="a"
        
        # Validate and normalize shell
        if ! validate_shell "$shell"; then
            failed=$((failed + 1))
            continue
        fi
        shell=$(normalize_shell "$shell")
        
        # Use global expiry if not specified
        [ -z "$expiry" ] && expiry="$GLOBAL_EXPIRE"
        
        # Calculate expiry date
        local expiry_date=""
        if [ -n "$expiry" ]; then
            if [[ "$expiry" =~ ^[0-9]+$ ]]; then
                expiry_date=$(date -d "+${expiry} days" +%Y-%m-%d)
            elif validate_date "$expiry"; then
                expiry_date="$expiry"
            else
                echo "${ICON_ERROR} Invalid expiry date for $username: $expiry"
                failed=$((failed + 1))
                continue
            fi
        fi
        
        # Handle sudo
        [ -z "$sudo" ] && [ "$GLOBAL_SUDO" = true ] && sudo="yes"
        sudo=$(normalize_sudo "$sudo")
        
        # Handle password (FIXED: uses DEFAULT_PASSWORD now)
        local user_password="$DEFAULT_PASSWORD"
        
        # Priority: file column > global flag > default
        if [ -n "$password" ]; then
            if [ "$password" = "random" ]; then
                user_password=$(generate_random_password "${PASSWORD_LENGTH:-16}")
            else
                user_password="$password"
            fi
        elif [ "$GLOBAL_PASSWORD" = "random" ]; then
            user_password=$(generate_random_password "${PASSWORD_LENGTH:-16}")
        fi
        
        # Comment field
        local gecos=""
        [ -n "$comment" ] && gecos="$comment"
        
        # Check if user already exists
        if id "$username" &>/dev/null; then
            echo "${ICON_WARNING} User '$username' already exists. Skipping..."
            skipped=$((skipped + 1))
            continue
        fi
        
        # DRY-RUN mode
        if [ "$DRY_RUN" = true ]; then
            echo "${ICON_SEARCH} [DRY-RUN] Would create user: $username"
            [ -n "$gecos" ] && echo "   - Comment: $gecos"
            echo "   - Home: /home/$username"
            echo "   - Shell: $shell"
            [ -n "$expiry_date" ] && echo "   - Account expires: $expiry_date"
            [ "$sudo" = "yes" ] && echo "   - Sudo: enabled"
            [ "$user_password" != "$DEFAULT_PASSWORD" ] && echo "   - Password: random (unique)"
            [ -n "$GLOBAL_PASSWORD_EXPIRY" ] && echo "   - Password expires: $GLOBAL_PASSWORD_EXPIRY days"
            created=$((created + 1))
            echo ""
            continue
        fi
        
        # Create user
        echo "${ICON_USER} Creating user: $username"
        
        local useradd_opts="-m -s $shell"
        [ -n "$gecos" ] && useradd_opts="$useradd_opts -c \"$gecos\""
        
        if eval sudo useradd $useradd_opts "$username" 2>/dev/null; then
            echo "   ${ICON_SUCCESS} User created"
            
            # Set password
            echo "$username:$user_password" | sudo chpasswd 2>/dev/null
            
            # Show password info
            if [ "$user_password" != "$DEFAULT_PASSWORD" ]; then
                echo "   🔑 Random password: $user_password"
            else
                echo "   🔐 Default password set"
            fi
            
            # Force password change on first login
            sudo chage -d 0 "$username"
            echo "   🔄 Must change password on first login"
            
            # Set password expiry
            local pwd_expiry="${GLOBAL_PASSWORD_EXPIRY:-${PASSWORD_EXPIRY_DAYS:-90}}"
            local pwd_warn="${PASSWORD_WARN_DAYS:-7}"
            sudo chage -M "$pwd_expiry" -W "$pwd_warn" "$username"
            echo "   ⏱️  Password expires every: $pwd_expiry days"
            
            # Set account expiry
            if [ -n "$expiry_date" ]; then
                sudo chage -E "$expiry_date" "$username"
                echo "   📅 Account expires: $expiry_date"
            fi
            
            # Add to sudo group
            if [ "$sudo" = "yes" ]; then
                sudo usermod -aG sudo "$username" 2>/dev/null || \
                sudo usermod -aG wheel "$username" 2>/dev/null
                echo "   🔐 Sudo access: granted"
            fi
            
            # Display other info
            [ -n "$gecos" ] && echo "   💬 Comment: $gecos"
            echo "   🐚 Shell: $shell"
            
            # Save password to secure file if random
            if [ "$user_password" != "$DEFAULT_PASSWORD" ]; then
                local password_dir="${BACKUP_DIR}/passwords"
                sudo mkdir -p "$password_dir"
                sudo chmod 700 "$password_dir"
                
                local timestamp=$(date '+%Y%m%d_%H%M%S')
                local password_file="$password_dir/${username}_${timestamp}.txt"
                
                {
                    echo "User Creation - Random Password"
                    echo "================================"
                    echo "User: $username"
                    echo "Date: $(date)"
                    echo "Created By: $USER"
                    echo "Password: $user_password"
                    echo ""
                    echo "User must change on first login"
                    echo ""
                    echo "⚠️  DELETE THIS FILE after password is delivered"
                } | sudo tee "$password_file" >/dev/null
                
                sudo chmod 600 "$password_file"
                echo "   📄 Password saved: $password_file"
            fi
            
            log_action "add_user" "$username" "SUCCESS" "shell=$shell, sudo=$sudo, random_pwd=$([[ "$user_password" != "$DEFAULT_PASSWORD" ]] && echo yes || echo no)"
            created=$((created + 1))
        else
            echo "   ${ICON_ERROR} Failed to create user: $username"
            log_action "add_user" "$username" "FAILED" "useradd command failed"
            failed=$((failed + 1))
        fi
        echo ""
    done < "$user_file"
    
    echo "=========================================="
    echo "Summary:"
    echo "  Total processed: $count"
    echo "  Created: $created"
    echo "  Skipped: $skipped"
    echo "  Failed: $failed"
    echo "=========================================="
    
    return 0
}

# add_users_to_groups()
# Adds users to groups from a mapping file
# Args:
#   $1 - mapping file path
# Format:
#   groupname:user1 user2 user3
# Returns:
#   None
add_users_to_groups() {
    local mapping_file="$1"
    
    if [[ ! -f "$mapping_file" ]]; then
        echo "${ICON_ERROR} Mapping file not found: $mapping_file"
        return 1
    fi
    
    echo "=========================================="
    echo "Adding Users to Groups from: $mapping_file"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    echo "=========================================="
    echo ""
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        # Parse: groupname:user1 user2 user3
        local group=$(echo "$line" | cut -d':' -f1 | xargs)
        local users=$(echo "$line" | cut -d':' -f2 | xargs)
        
        if [[ -z "$group" || -z "$users" ]]; then
            echo "${ICON_WARNING} Invalid format: $line"
            continue
        fi
        
        # Validate group name
        if ! validate_name "$group" "group"; then
            continue
        fi
        
        echo "Processing group: $group"
        
        # Create group if doesn't exist
        if ! getent group "$group" >/dev/null 2>&1; then
            if [ "$DRY_RUN" = true ]; then
                echo "  ${ICON_SEARCH} [DRY-RUN] Would create group: $group"
            else
                echo "  ${ICON_GROUP} Creating group: $group"
                sudo groupadd "$group"
                log_action "add_group" "$group" "SUCCESS" "Created for user-group mapping"
            fi
        fi
        
        # Process each user
        for user in $users; do
            if ! validate_name "$user" "user"; then
                continue
            fi
            
            if id "$user" &>/dev/null; then
                # User exists, add to group
                if [ "$DRY_RUN" = true ]; then
                    echo "  ${ICON_SEARCH} [DRY-RUN] Would add '$user' to '$group'"
                else
                    echo "  ${ICON_USER} Adding '$user' to '$group'"
                    sudo usermod -aG "$group" "$user"
                    log_action "add_user_to_group" "$user" "SUCCESS" "Added to group: $group"
                fi
            else
                # User doesn't exist, create and add
                if [ "$DRY_RUN" = true ]; then
                    echo "  ${ICON_SEARCH} [DRY-RUN] Would create '$user' and add to '$group'"
                else
                    echo "  ${ICON_USER} Creating '$user' and adding to '$group'"
                    sudo useradd -m "$user"
                    echo "$user:$DEFAULT_PASSWORD" | sudo chpasswd
                    sudo usermod -aG "$group" "$user"
                    sudo chage -d 0 "$user"
                    log_action "add_user" "$user" "SUCCESS" "Created and added to group: $group"
                fi
            fi
        done
        echo ""
    done < "$mapping_file"
    
    return 0
}