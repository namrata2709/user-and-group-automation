#!/usr/bin/env bash
# ================================================
# User Add Module
# Version: 1.0.2
# ================================================
# ADDED: Single user creation function
# ================================================

# add_single_user()
# Creates a single user with CLI arguments
# Args:
#   $1 - username
# Uses global variables:
#   GLOBAL_PRIMARY_GROUP, GLOBAL_SECONDARY_GROUPS, GLOBAL_SHELL,
#   GLOBAL_SUDO, GLOBAL_PASSWORD, GLOBAL_EXPIRE, GLOBAL_COMMENT,
#   GLOBAL_PASSWORD_EXPIRY
# Returns:
#   0 on success, 1 on failure
add_single_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        echo "${ICON_ERROR} Username is required"
        return 1
    fi
    
    echo "=========================================="
    echo "Creating Single User: $username"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    echo "=========================================="
    echo ""
    
    # Validate username
    if ! validate_name "$username" "user"; then
        return 1
    fi
    
    # Check if user exists
    if id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' already exists"
        return 1
    fi
    
    # Validate and set primary group
    local primary_group="$GLOBAL_PRIMARY_GROUP"
    if [ -n "$primary_group" ]; then
        if ! getent group "$primary_group" >/dev/null 2>&1; then
            echo "${ICON_ERROR} Primary group '$primary_group' does not exist"
            echo "   Create it first: sudo groupadd $primary_group"
            return 1
        fi
    fi
    
    # Validate secondary groups
    if [ -n "$GLOBAL_SECONDARY_GROUPS" ]; then
        IFS=',' read -ra GROUPS <<< "$GLOBAL_SECONDARY_GROUPS"
        for grp in "${GROUPS[@]}"; do
            grp=$(echo "$grp" | xargs)
            if ! getent group "$grp" >/dev/null 2>&1; then
                echo "${ICON_ERROR} Secondary group '$grp' does not exist"
                echo "   Create it first: sudo groupadd $grp"
                return 1
            fi
        done
    fi
    
    # Validate and normalize shell
    local shell="${GLOBAL_SHELL:-a}"
    if ! validate_shell "$shell"; then
        return 1
    fi
    shell=$(normalize_shell "$shell")
    
    # Validate expiration
    local expiry_date=""
    if [ -n "$GLOBAL_EXPIRE" ]; then
        if [[ "$GLOBAL_EXPIRE" =~ ^[0-9]+$ ]]; then
            expiry_date=$(date -d "+${GLOBAL_EXPIRE} days" +%Y-%m-%d)
        elif validate_date "$GLOBAL_EXPIRE"; then
            expiry_date="$GLOBAL_EXPIRE"
        else
            echo "${ICON_ERROR} Invalid expiry date: $GLOBAL_EXPIRE"
            return 1
        fi
    fi
    
    # Set password
    local user_password="$DEFAULT_PASSWORD"
    if [ "$GLOBAL_PASSWORD" = "random" ]; then
        user_password=$(generate_random_password "${PASSWORD_LENGTH:-16}")
    elif [ -n "$GLOBAL_PASSWORD" ]; then
        user_password="$GLOBAL_PASSWORD"
    fi
    
    # Show what will be created
    echo "User Configuration:"
    echo "  Username:         $username"
    [ -n "$primary_group" ] && echo "  Primary Group:    $primary_group"
    [ -n "$GLOBAL_SECONDARY_GROUPS" ] && echo "  Secondary Groups: $GLOBAL_SECONDARY_GROUPS"
    echo "  Shell:            $shell"
    [ "$GLOBAL_SUDO" = true ] && echo "  Sudo Access:      Yes"
    [ -n "$GLOBAL_COMMENT" ] && echo "  Comment:          $GLOBAL_COMMENT"
    [ -n "$expiry_date" ] && echo "  Account Expires:  $expiry_date"
    [ "$user_password" != "$DEFAULT_PASSWORD" ] && echo "  Password:         Random (will be shown)"
    echo "  Password Expiry:  ${GLOBAL_PASSWORD_EXPIRY} days"
    echo ""
    
    # DRY-RUN mode
    if [ "$DRY_RUN" = true ]; then
        echo "${ICON_SEARCH} [DRY-RUN] Would create user with above settings"
        return 0
    fi
    
    # Create user
    echo "${ICON_USER} Creating user: $username"
    
    local useradd_opts="-m -s $shell"
    [ -n "$GLOBAL_COMMENT" ] && useradd_opts="$useradd_opts -c \"$GLOBAL_COMMENT\""
    [ -n "$primary_group" ] && useradd_opts="$useradd_opts -g $primary_group"
    
    if ! eval sudo useradd $useradd_opts "$username" 2>/dev/null; then
        echo "   ${ICON_ERROR} Failed to create user"
        log_action "add_single_user" "$username" "FAILED" "useradd failed"
        return 1
    fi
    
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
    
    # Add to secondary groups
    if [ -n "$GLOBAL_SECONDARY_GROUPS" ]; then
        sudo usermod -aG "$GLOBAL_SECONDARY_GROUPS" "$username" 2>/dev/null
        echo "   ${ICON_GROUP} Added to groups: $GLOBAL_SECONDARY_GROUPS"
    fi
    
    # Add to sudo group
    if [ "$GLOBAL_SUDO" = true ]; then
        sudo usermod -aG sudo "$username" 2>/dev/null || \
        sudo usermod -aG wheel "$username" 2>/dev/null
        echo "   🔓 Sudo access: granted"
    fi
    
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
    
    local uid=$(id -u "$username")
    echo ""
    echo "${ICON_SUCCESS} User created successfully"
    echo "  Username: $username"
    echo "  UID:      $uid"
    echo "  Home:     /home/$username"
    echo ""
    
    log_action "add_single_user" "$username" "SUCCESS" "primary=$primary_group, groups=$GLOBAL_SECONDARY_GROUPS, sudo=$GLOBAL_SUDO"
    return 0
}

# add_single_group()
# Creates a single group
# Args:
#   $1 - groupname
# Returns:
#   0 on success, 1 on failure
add_single_group() {
    local groupname="$1"
    
    if [ -z "$groupname" ]; then
        echo "${ICON_ERROR} Group name is required"
        return 1
    fi
    
    echo "=========================================="
    echo "Creating Single Group: $groupname"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    echo "=========================================="
    echo ""
    
    # Validate group name
    if ! validate_name "$groupname" "group"; then
        return 1
    fi
    
    # Check if group exists
    if getent group "$groupname" >/dev/null 2>&1; then
        echo "${ICON_WARNING} Group '$groupname' already exists"
        return 0
    fi
    
    # DRY-RUN mode
    if [ "$DRY_RUN" = true ]; then
        echo "${ICON_SEARCH} [DRY-RUN] Would create group: $groupname"
        return 0
    fi
    
    # Create group
    echo "${ICON_GROUP} Creating group: $groupname"
    
    if sudo groupadd "$groupname" 2>/dev/null; then
        local gid=$(getent group "$groupname" | cut -d: -f3)
        echo "   ${ICON_SUCCESS} Group created"
        echo ""
        echo "${ICON_SUCCESS} Group created successfully"
        echo "  Group: $groupname"
        echo "  GID:   $gid"
        echo ""
        log_action "add_single_group" "$groupname" "SUCCESS" "GID: $gid"
        return 0
    else
        echo "   ${ICON_ERROR} Failed to create group"
        log_action "add_single_group" "$groupname" "FAILED" "groupadd failed"
        return 1
    fi
}

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
    [ -n "$GLOBAL_SHELL" ] && echo "🚀 Shell: $GLOBAL_SHELL"
    [ "$GLOBAL_SUDO" = true ] && echo "🔓 Sudo: enabled"
    [ "$GLOBAL_PASSWORD" = "random" ] && echo "🔑 Password: random (unique per user)"
    [ -n "$GLOBAL_PASSWORD_EXPIRY" ] && echo "⏱️  Password expiry: $GLOBAL_PASSWORD_EXPIRY days"
    echo "=========================================="
    echo ""
    
    local count=0 created=0 skipped=0 failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        count=$((count + 1))
        
        local username comment expiry shell sudo password
        IFS=':' read -r username comment expiry shell sudo password <<< "$line"
        username=$(echo "$username" | xargs)
        
        if ! validate_name "$username" "user"; then
            failed=$((failed + 1))
            continue
        fi
        
        [ -z "$shell" ] && shell="$GLOBAL_SHELL"
        [ -z "$shell" ] && shell="a"
        
        if ! validate_shell "$shell"; then
            failed=$((failed + 1))
            continue
        fi
        shell=$(normalize_shell "$shell")
        
        [ -z "$expiry" ] && expiry="$GLOBAL_EXPIRE"
        
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
        
        [ -z "$sudo" ] && [ "$GLOBAL_SUDO" = true ] && sudo="yes"
        sudo=$(normalize_sudo "$sudo")
        
        local user_password="$DEFAULT_PASSWORD"
        
        if [ -n "$password" ]; then
            if [ "$password" = "random" ]; then
                user_password=$(generate_random_password "${PASSWORD_LENGTH:-16}")
            else
                user_password="$password"
            fi
        elif [ "$GLOBAL_PASSWORD" = "random" ]; then
            user_password=$(generate_random_password "${PASSWORD_LENGTH:-16}")
        fi
        
        local gecos=""
        [ -n "$comment" ] && gecos="$comment"
        
        if id "$username" &>/dev/null; then
            echo "${ICON_WARNING} User '$username' already exists. Skipping..."
            skipped=$((skipped + 1))
            continue
        fi
        
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
        
        echo "${ICON_USER} Creating user: $username"
        
        local useradd_opts="-m -s $shell"
        [ -n "$gecos" ] && useradd_opts="$useradd_opts -c \"$gecos\""
        
        if eval sudo useradd $useradd_opts "$username" 2>/dev/null; then
            echo "   ${ICON_SUCCESS} User created"
            
            echo "$username:$user_password" | sudo chpasswd 2>/dev/null
            
            if [ "$user_password" != "$DEFAULT_PASSWORD" ]; then
                echo "   🔑 Random password: $user_password"
            else
                echo "   🔐 Default password set"
            fi
            
            sudo chage -d 0 "$username"
            echo "   🔄 Must change password on first login"
            
            local pwd_expiry="${GLOBAL_PASSWORD_EXPIRY:-${PASSWORD_EXPIRY_DAYS:-90}}"
            local pwd_warn="${PASSWORD_WARN_DAYS:-7}"
            sudo chage -M "$pwd_expiry" -W "$pwd_warn" "$username"
            echo "   ⏱️  Password expires every: $pwd_expiry days"
            
            if [ -n "$expiry_date" ]; then
                sudo chage -E "$expiry_date" "$username"
                echo "   📅 Account expires: $expiry_date"
            fi
            
            if [ "$sudo" = "yes" ]; then
                sudo usermod -aG sudo "$username" 2>/dev/null || \
                sudo usermod -aG wheel "$username" 2>/dev/null
                echo "   🔓 Sudo access: granted"
            fi
            
            [ -n "$gecos" ] && echo "   💬 Comment: $gecos"
            echo "   🚀 Shell: $shell"
            
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
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        local group=$(echo "$line" | cut -d':' -f1 | xargs)
        local users=$(echo "$line" | cut -d':' -f2 | xargs)
        
        if [[ -z "$group" || -z "$users" ]]; then
            echo "${ICON_WARNING} Invalid format: $line"
            continue
        fi
        
        if ! validate_name "$group" "group"; then
            continue
        fi
        
        echo "Processing group: $group"
        
        if ! getent group "$group" >/dev/null 2>&1; then
            if [ "$DRY_RUN" = true ]; then
                echo "  ${ICON_SEARCH} [DRY-RUN] Would create group: $group"
            else
                echo "  ${ICON_GROUP} Creating group: $group"
                sudo groupadd "$group"
                log_action "add_group" "$group" "SUCCESS" "Created for user-group mapping"
            fi
        fi
        
        for user in $users; do
            if ! validate_name "$user" "user"; then
                continue
            fi
            
            if id "$user" &>/dev/null; then
                if [ "$DRY_RUN" = true ]; then
                    echo "  ${ICON_SEARCH} [DRY-RUN] Would add '$user' to '$group'"
                else
                    echo "  ${ICON_USER} Adding '$user' to '$group'"
                    sudo usermod -aG "$group" "$user"
                    log_action "add_user_to_group" "$user" "SUCCESS" "Added to group: $group"
                fi
            else
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