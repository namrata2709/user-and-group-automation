#!/usr/bin/env bash
# ================================================
# User Update Module
# Version: 1.0.1
# ================================================

update_user_password() {
    local username="$1"
    local custom_password="${2:-}"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    echo "=========================================="
    echo "Password Reset: $username"
    echo "=========================================="
    echo ""
    
    local new_password
    if [ -n "$custom_password" ]; then
        new_password="$custom_password"
        echo "Using custom password"
    else
        new_password=$(generate_random_password "${PASSWORD_LENGTH:-16}")
        echo "Generated random password"
    fi
    
    echo "$username:$new_password" | sudo chpasswd 2>/dev/null
    sudo chage -d 0 "$username"
    
    echo "${ICON_SUCCESS} Password reset successfully"
    echo "${ICON_SUCCESS} User MUST change password on next login"
    echo ""
    echo "=========================================="
    echo "Temporary Password: $new_password"
    echo "=========================================="
    echo ""
    echo "${ICON_WARNING} Securely provide this password to $username"
    echo ""
    
    local password_dir="${BACKUP_DIR}/passwords"
    sudo mkdir -p "$password_dir"
    sudo chmod 700 "$password_dir"
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local password_file="$password_dir/${username}_${timestamp}.txt"
    
    {
        echo "Password Reset Record"
        echo "====================="
        echo "User: $username"
        echo "Date: $(date)"
        echo "Reset By: $USER"
        echo "Temporary Password: $new_password"
        echo ""
        echo "User must change on first login"
    } | sudo tee "$password_file" >/dev/null
    
    sudo chmod 600 "$password_file"
    echo "Password saved to: $password_file"
    echo ""
    
    log_action "update_password" "$username" "SUCCESS" "Password reset, forced change"
}

update_user_shell() {
    local username="$1"
    local new_shell="$2"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    if ! validate_shell "$new_shell"; then
        return 1
    fi
    
    new_shell=$(normalize_shell "$new_shell")
    local current_shell=$(getent passwd "$username" | cut -d: -f7)
    
    echo "Changing shell for: $username"
    echo "  Current: $current_shell"
    echo "  New:     $new_shell"
    
    if [ "$current_shell" = "$new_shell" ]; then
        echo "${ICON_WARNING} Shell is already set to $new_shell"
        return 0
    fi
    
    if sudo usermod -s "$new_shell" "$username"; then
        echo "${ICON_SUCCESS} Shell changed successfully"
        log_action "update_shell" "$username" "SUCCESS" "$current_shell -> $new_shell"
    else
        echo "${ICON_ERROR} Failed to change shell"
        return 1
    fi
}

update_user_add_to_groups() {
    local username="$1"
    local groups="$2"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    echo "Adding $username to groups: $groups"
    echo ""
    
    local success=0
    local failed=0
    
    IFS=',' read -ra GROUP_ARRAY <<< "$groups"
    for group in "${GROUP_ARRAY[@]}"; do
        group=$(echo "$group" | xargs)
        
        if ! getent group "$group" >/dev/null 2>&1; then
            echo "  ${ICON_ERROR} Group '$group' does not exist"
            ((failed++))
            continue
        fi
        
        if groups "$username" 2>/dev/null | grep -qw "$group"; then
            echo "  ${ICON_WARNING} Already in group: $group"
            continue
        fi
        
        if sudo usermod -aG "$group" "$username"; then
            echo "  ${ICON_SUCCESS} Added to: $group"
            ((success++))
        else
            echo "  ${ICON_ERROR} Failed to add to: $group"
            ((failed++))
        fi
    done
    
    echo ""
    echo "Summary: $success added, $failed failed"
    
    if [ $success -gt 0 ]; then
        echo ""
        echo "Current groups:"
        groups "$username"
    fi
    
    log_action "update_add_groups" "$username" "SUCCESS" "Added to: $groups"
}

update_user_remove_from_groups() {
    local username="$1"
    local groups="$2"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    local primary_group=$(id -gn "$username")
    
    echo "Removing $username from groups: $groups"
    echo ""
    
    local success=0
    local failed=0
    
    IFS=',' read -ra GROUP_ARRAY <<< "$groups"
    for group in "${GROUP_ARRAY[@]}"; do
        group=$(echo "$group" | xargs)
        
        if [ "$group" = "$primary_group" ]; then
            echo "  ${ICON_WARNING} Cannot remove from primary group: $group"
            ((failed++))
            continue
        fi
        
        if ! getent group "$group" >/dev/null 2>&1; then
            echo "  ${ICON_WARNING} Group '$group' does not exist"
            continue
        fi
        
        if ! groups "$username" 2>/dev/null | grep -qw "$group"; then
            echo "  ${ICON_WARNING} Not in group: $group"
            continue
        fi
        
        if sudo gpasswd -d "$username" "$group" &>/dev/null; then
            echo "  ${ICON_SUCCESS} Removed from: $group"
            ((success++))
        else
            echo "  ${ICON_ERROR} Failed to remove from: $group"
            ((failed++))
        fi
    done
    
    echo ""
    echo "Summary: $success removed, $failed failed"
    
    if [ $success -gt 0 ]; then
        echo ""
        echo "Current groups:"
        groups "$username"
    fi
    
    log_action "update_remove_groups" "$username" "SUCCESS" "Removed from: $groups"
}

update_user_expiration() {
    local username="$1"
    local expiry="$2"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    echo "Updating account expiration for: $username"
    echo ""
    
    local expiry_date=""
    
    if [ "$expiry" = "never" ]; then
        expiry_date=""
        echo "Setting: No expiration"
    elif [[ "$expiry" =~ ^[0-9]+$ ]]; then
        expiry_date=$(date -d "+${expiry} days" +%Y-%m-%d)
        echo "Setting: $expiry days from now ($expiry_date)"
    elif validate_date "$expiry"; then
        expiry_date="$expiry"
        echo "Setting: $expiry_date"
    else
        echo "${ICON_ERROR} Invalid expiration format"
        return 1
    fi
    
    if [ -z "$expiry_date" ]; then
        sudo chage -E -1 "$username"
    else
        sudo chage -E "$expiry_date" "$username"
    fi
    
    echo "${ICON_SUCCESS} Account expiration updated"
    echo ""
    sudo chage -l "$username" | grep "Account expires"
    
    log_action "update_expiration" "$username" "SUCCESS" "Expiration: $expiry_date"
}

update_user_password_expiry() {
    local username="$1"
    local days="$2"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    echo "Updating password expiry policy for: $username"
    echo ""
    
    if [ "$days" = "never" ]; then
        sudo chage -M 99999 "$username"
        echo "Setting: Password never expires"
    elif [[ "$days" =~ ^[0-9]+$ ]]; then
        sudo chage -M "$days" "$username"
        echo "Setting: Password expires every $days days"
    else
        echo "${ICON_ERROR} Invalid value. Use number of days or 'never'"
        return 1
    fi
    
    echo "${ICON_SUCCESS} Password expiry policy updated"
    echo ""
    sudo chage -l "$username" | grep "Maximum number of days"
    
    log_action "update_password_expiry" "$username" "SUCCESS" "Policy: $days days"
}

update_user_comment() {
    local username="$1"
    local comment="$2"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    local current_comment=$(getent passwd "$username" | cut -d: -f5)
    
    echo "Updating comment for: $username"
    echo "  Current: ${current_comment:-(none)}"
    echo "  New:     $comment"
    
    if sudo usermod -c "$comment" "$username"; then
        echo "${ICON_SUCCESS} Comment updated successfully"
        log_action "update_comment" "$username" "SUCCESS" "Comment: $comment"
    else
        echo "${ICON_ERROR} Failed to update comment"
        return 1
    fi
}

update_user_primary_group() {
    local username="$1"
    local new_group="$2"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    if ! getent group "$new_group" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Group '$new_group' does not exist"
        return 1
    fi
    
    local current_group=$(id -gn "$username")
    
    echo "Changing primary group for: $username"
    echo "  Current: $current_group"
    echo "  New:     $new_group"
    
    if [ "$current_group" = "$new_group" ]; then
        echo "${ICON_WARNING} Primary group is already $new_group"
        return 0
    fi
    
    read -p "Confirm change? [y/n]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return 0
    fi
    
    if sudo usermod -g "$new_group" "$username"; then
        echo "${ICON_SUCCESS} Primary group changed successfully"
        log_action "update_primary_group" "$username" "SUCCESS" "$current_group -> $new_group"
    else
        echo "${ICON_ERROR} Failed to change primary group"
        return 1
    fi
}

update_user() {
    local username="$1"
    local operation="$2"
    shift 2
    local value="$*"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    case "$operation" in
        reset-password)
            update_user_password "$username" "$value"
            ;;
        shell)
            update_user_shell "$username" "$value"
            ;;
        add-to-group|add-to-groups)
            update_user_add_to_groups "$username" "$value"
            ;;
        remove-from-group|remove-from-groups)
            update_user_remove_from_groups "$username" "$value"
            ;;
        expire)
            update_user_expiration "$username" "$value"
            ;;
        password-expiry)
            update_user_password_expiry "$username" "$value"
            ;;
        comment)
            update_user_comment "$username" "$value"
            ;;
        primary-group)
            update_user_primary_group "$username" "$value"
            ;;
        *)
            echo "${ICON_ERROR} Unknown update operation: $operation"
            return 1
            ;;
    esac
}