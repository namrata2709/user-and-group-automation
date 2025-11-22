#!/usr/bin/env bash
# ================================================
# User Add Module - REFACTORED
# Version: 2.0.0
# ================================================
# Single add_user logic, multiple format parsers
# ================================================

# ============================================
# CORE FUNCTION - Single user creation logic
# ============================================
# add_single_user()
# Creates a single user with given parameters
# Args:
#   $1 - username (required)
#   $2 - comment/GECOS (optional)
#   $3 - expiry_days (optional, 0=never)
#   $4 - shell (optional, default from config)
#   $5 - sudo (yes/no, optional)
#   $6 - password (optional, "random" or specific password)
#   $7 - password_expiry_days (optional, default from config)
#   $8 - groups (comma-separated, optional)
# Returns:
#   0 on success, 1 on failure
add_single_user() {
    local username="$1"
    local comment="${2:-}"
    local expiry_days="${3:-0}"
    local shell="${4:-$DEFAULT_SHELL}"
    local sudo_access="${5:-no}"
    local password="${6:-$DEFAULT_PASSWORD}"
    local password_expiry="${7:-${PASSWORD_EXPIRY_DAYS:-90}}"
    local groups="${8:-}"
    
    # Validate username
    if ! validate_name "$username" "user"; then
        log_action "add_user" "$username" "FAILED" "Invalid username"
        return 1
    fi
    
    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo "${ICON_WARNING} User '$username' already exists. Skipping..."
        log_action "add_user" "$username" "SKIPPED" "Already exists"
        return 1
    fi
    
    # Normalize shell
    if ! validate_shell "$shell"; then
        log_action "add_user" "$username" "FAILED" "Invalid shell: $shell"
        return 1
    fi
    shell=$(normalize_shell "$shell")
    
    # Normalize sudo
    sudo_access=$(normalize_sudo "$sudo_access")
    
    # DRY-RUN mode
    if [ "$DRY_RUN" = true ]; then
        echo "${ICON_SEARCH} [DRY-RUN] Would create user: $username"
        [ -n "$comment" ] && echo "   - Comment: $comment"
        echo "   - Home: /home/$username"
        echo "   - Shell: $shell"
        [ "$expiry_days" -gt 0 ] && echo "   - Account expires: $(date -d "+${expiry_days} days" +%Y-%m-%d)"
        [ "$sudo_access" = "yes" ] && echo "   - Sudo: enabled"
        [ "$password" = "random" ] && echo "   - Password: random (unique)"
        [ -n "$groups" ] && echo "   - Groups: $groups"
        echo "   - Password expires: $password_expiry days"
        return 0
    fi
    
    # Create user
    echo "${ICON_USER} Creating user: $username"
    
    local useradd_opts="-m -s $shell"
    [ -n "$comment" ] && useradd_opts="$useradd_opts -c \"$comment\""
    
    if eval sudo useradd $useradd_opts "$username" 2>/dev/null; then
        echo "   ${ICON_SUCCESS} User created"
        
        # Set password
        local user_password="$DEFAULT_PASSWORD"
        local is_random=false
        
        if [ "$password" = "random" ]; then
            user_password=$(generate_random_password "${PASSWORD_LENGTH:-16}")
            is_random=true
            echo "   🔑 Random password: $user_password"
        elif [ -n "$password" ] && [ "$password" != "$DEFAULT_PASSWORD" ]; then
            user_password="$password"
            echo "   🔐 Custom password set"
        else
            echo "   🔐 Default password set"
        fi
        
        echo "$username:$user_password" | sudo chpasswd 2>/dev/null
        
        # Force password change on first login
        sudo chage -d 0 "$username"
        echo "   🔄 Must change password on first login"
        
        # Set password expiry
        local pwd_warn="${PASSWORD_WARN_DAYS:-7}"
        sudo chage -M "$password_expiry" -W "$pwd_warn" "$username"
        echo "   ⏱️  Password expires every: $password_expiry days"
        
        # Set account expiry
        if [ "$expiry_days" -gt 0 ]; then
            local expiry_date=$(date -d "+${expiry_days} days" +%Y-%m-%d)
            sudo chage -E "$expiry_date" "$username"
            echo "   📅 Account expires: $expiry_date"
        fi
        
        # Add to groups
        if [ -n "$groups" ]; then
            sudo usermod -aG "$groups" "$username" 2>/dev/null
            echo "   👥 Added to groups: $groups"
        fi
        
        # Add to sudo group
        if [ "$sudo_access" = "yes" ]; then
            sudo usermod -aG sudo "$username" 2>/dev/null || \
            sudo usermod -aG wheel "$username" 2>/dev/null
            echo "   🔐 Sudo access: granted"
        fi
        
        # Display other info
        [ -n "$comment" ] && echo "   💬 Comment: $comment"
        echo "   🐚 Shell: $shell"
        
        # Save random password to secure file
        if [ "$is_random" = true ]; then
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
        log_action "add_user" "$username" "SUCCESS" "shell=$shell, sudo=$sudo_access, random_pwd=$is_random, groups=$groups"
        return 0
    else
        echo "   ${ICON_ERROR} Failed to create user: $username"
        log_action "add_user" "$username" "FAILED" "useradd command failed"
        return 1
    fi
}

# ============================================
# PARSER: Text File Format
# ============================================
# parse_users_from_text()
# Parses text file and calls add_single_user for each
# Format: username:comment:expiry:shell:sudo:password
# Args:
#   $1 - text file path
# Returns:
#   Summary counts
parse_users_from_text() {
    local user_file="$1"
    
    if [[ ! -f "$user_file" ]]; then
        echo "${ICON_ERROR} User file not found: $user_file"
        return 1
    fi
    
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
        
        # Use global overrides if set
        [ -z "$shell" ] && shell="$GLOBAL_SHELL"
        [ -z "$expiry" ] && expiry="$GLOBAL_EXPIRE"
        [ -z "$sudo" ] && [ "$GLOBAL_SUDO" = true ] && sudo="yes"
        [ -z "$password" ] && [ "$GLOBAL_PASSWORD" = "random" ] && password="random"
        
        # Call core function
        if add_single_user "$username" "$comment" "$expiry" "$shell" "$sudo" "$password" "$GLOBAL_PASSWORD_EXPIRY" ""; then
            ((created++))
        else
            if id "$username" &>/dev/null 2>&1; then
                ((skipped++))
            else
                ((failed++))
            fi
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

# ============================================
# PARSER: JSON Format
# ============================================
# parse_users_from_json()
# Parses JSON file and calls add_single_user for each
# Args:
#   $1 - JSON file path
# Returns:
#   Summary counts
parse_users_from_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        echo "${ICON_ERROR} JSON file not found: $json_file"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "${ICON_ERROR} jq not installed. Install with: sudo apt install jq"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$json_file" 2>/dev/null; then
        echo "${ICON_ERROR} Invalid JSON format: $json_file"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.users' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure - missing 'users' array"
        return 1
    fi
    
    local count=0 created=0 skipped=0 failed=0
    local start_time=$(date +%s)
    
    # Parse each user from JSON
    while IFS= read -r user_json; do
        ((count++))
        
        # Extract fields from JSON
        local username=$(echo "$user_json" | jq -r '.username')
        local comment=$(echo "$user_json" | jq -r '.comment // ""')
        local groups=$(echo "$user_json" | jq -r '.groups[]?' 2>/dev/null | paste -sd,)
        local shell=$(echo "$user_json" | jq -r '.shell // "/bin/bash"')
        local expire_days=$(echo "$user_json" | jq -r '.expire_days // "0"')
        local password_type=$(echo "$user_json" | jq -r '.password_policy.type // "default"')
        local password_expiry=$(echo "$user_json" | jq -r '.password_policy.expiry_days // "90"')
        
        # Determine password
        local password="$DEFAULT_PASSWORD"
        if [ "$password_type" = "random" ]; then
            password="random"
        fi
        
        # Determine sudo (not in JSON, use global default)
        local sudo="no"
        [ "$GLOBAL_SUDO" = true ] && sudo="yes"
        
        # Call core function
        if add_single_user "$username" "$comment" "$expire_days" "$shell" "$sudo" "$password" "$password_expiry" "$groups"; then
            ((created++))
        else
            if id "$username" &>/dev/null 2>&1; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < <(jq -c '.users[]' "$json_file" 2>/dev/null)
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "=========================================="
    echo "Summary:"
    echo "  Total processed: $count"
    echo "  Created: $created"
    echo "  Skipped: $skipped"
    echo "  Failed: $failed"
    echo "  Duration: ${duration}s"
    echo "=========================================="
    
    return 0
}

# ============================================
# PUBLIC INTERFACE - Called from user.sh
# ============================================
# add_users()
# Main entry point - detects format and routes to appropriate parser
# Args:
#   $1 - file path
#   $2 - format (optional: "text", "json", auto-detect if not provided)
# Returns:
#   0 on success, 1 on failure
add_users() {
    local user_file="$1"
    local format="${2:-auto}"
    
    if [[ ! -f "$user_file" ]]; then
        echo "${ICON_ERROR} User file not found: $user_file"
        return 1
    fi
    
    # Auto-detect format if not specified
    if [ "$format" = "auto" ]; then
        if [[ "$user_file" =~ \.json$ ]]; then
            format="json"
        else
            format="text"
        fi
    fi
    
    echo "=========================================="
    echo "Adding Users from: $user_file"
    echo "Format: $format"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    [ -n "$GLOBAL_EXPIRE" ] && echo "📅 Global Expiration: $GLOBAL_EXPIRE days"
    [ -n "$GLOBAL_SHELL" ] && echo "🐚 Global Shell: $GLOBAL_SHELL"
    [ "$GLOBAL_SUDO" = true ] && echo "🔐 Global Sudo: enabled"
    [ "$GLOBAL_PASSWORD" = "random" ] && echo "🔑 Global Password: random (unique per user)"
    [ -n "$GLOBAL_PASSWORD_EXPIRY" ] && echo "⏱️  Password expiry: $GLOBAL_PASSWORD_EXPIRY days"
    echo "=========================================="
    echo ""
    
    # Route to appropriate parser
    case "$format" in
        json)
            parse_users_from_json "$user_file"
            ;;
        text|txt)
            parse_users_from_text "$user_file"
            ;;
        *)
            echo "${ICON_ERROR} Unknown format: $format"
            echo "Supported formats: text, json"
            return 1
            ;;
    esac
}

# ============================================
# LEGACY COMPATIBILITY
# ============================================
# Keep old function names for backward compatibility
add_users_from_json() {
    parse_users_from_json "$1"
}

# ============================================
# USER-GROUP MAPPING - REFACTORED
# ============================================
# Uses add_single_group() and add_single_user() core functions
# ============================================

# parse_user_group_mapping()
# Parses user-group mapping file and creates users/groups as needed
# Format: groupname:user1 user2 user3
# Args:
#   $1 - mapping file path
# Returns:
#   Summary counts
parse_user_group_mapping() {
    local mapping_file="$1"
    
    if [[ ! -f "$mapping_file" ]]; then
        echo "${ICON_ERROR} Mapping file not found: $mapping_file"
        return 1
    fi
    
    local groups_processed=0
    local groups_created=0
    local users_added=0
    local users_created=0
    local failed=0
    
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
            ((failed++))
            continue
        fi
        
        # Validate group name
        if ! validate_name "$group" "group"; then
            ((failed++))
            continue
        fi
        
        ((groups_processed++))
        echo "Processing group: $group"
        
        # Create group if doesn't exist - USE CORE FUNCTION
        if ! getent group "$group" >/dev/null 2>&1; then
            if add_single_group "$group" ""; then
                ((groups_created++))
            else
                echo "  ${ICON_ERROR} Failed to create group, skipping users"
                ((failed++))
                continue
            fi
        else
            echo "  ${ICON_INFO} Group already exists"
        fi
        
        # Process each user
        for user in $users; do
            if ! validate_name "$user" "user"; then
                ((failed++))
                continue
            fi
            
            if id "$user" &>/dev/null; then
                # User exists, add to group
                if [ "$DRY_RUN" = true ]; then
                    echo "  ${ICON_SEARCH} [DRY-RUN] Would add '$user' to '$group'"
                    ((users_added++))
                else
                    echo "  ${ICON_USER} Adding '$user' to '$group'"
                    if sudo usermod -aG "$group" "$user" 2>/dev/null; then
                        ((users_added++))
                        log_action "add_user_to_group" "$user" "SUCCESS" "Added to group: $group"
                    else
                        echo "  ${ICON_ERROR} Failed to add '$user' to '$group'"
                        ((failed++))
                    fi
                fi
            else
                # User doesn't exist, create and add - USE CORE FUNCTION
                echo "  ${ICON_INFO} User '$user' doesn't exist, creating..."
                if add_single_user "$user" "" "0" "$DEFAULT_SHELL" "no" "$DEFAULT_PASSWORD" "${PASSWORD_EXPIRY_DAYS:-90}" "$group"; then
                    ((users_created++))
                    ((users_added++))
                else
                    ((failed++))
                fi
            fi
        done
        echo ""
    done < "$mapping_file"
    
    echo "=========================================="
    echo "Summary:"
    echo "  Groups processed: $groups_processed"
    echo "  Groups created: $groups_created"
    echo "  Users added to groups: $users_added"
    echo "  Users created: $users_created"
    echo "  Failed operations: $failed"
    echo "=========================================="
    
    return 0
}

# ============================================
# PUBLIC INTERFACE
# ============================================
add_users_to_groups() {
    local mapping_file="$1"
    
    echo "=========================================="
    echo "User-Group Mapping from: $mapping_file"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    echo "=========================================="
    echo ""
    
    parse_user_group_mapping "$mapping_file"
}