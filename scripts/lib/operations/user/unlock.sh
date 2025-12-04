#!/bin/bash

unlock_user() {
    local username="$1"
    local shell_value="$2"
    local sudo_value="$3"
    local expiry_value="$4"
    
    validate_update_user "$username" "UNLOCK_USER" || return 1
    
    local current_comment=$(getent passwd "$username" | cut -d: -f5)
    local original_comment=""
    
    if [[ "$current_comment" =~ (.+)" - Temporary suspension" ]]; then
        original_comment="${BASH_REMATCH[1]}"
    else
        original_comment="$current_comment"
    fi
    
    [ -z "$shell_value" ] && shell_value="$DEFAULT_SHELL"
    [ -z "$sudo_value" ] && sudo_value="$DEFAULT_SUDO"
    [ -z "$expiry_value" ] && expiry_value="$DEFAULT_ACCOUNT_EXPIRY"
    
    echo "Unlocking user: $username"
    echo "Shell: $shell_value"
    echo "Sudo: $sudo_value"
    echo "Expiry: ${expiry_value:-never}"
    echo ""
    
    local steps_completed=0
    local steps_total=7
    
    if passwd -u "$username" >/dev/null 2>&1; then
        echo "${ICON_SUCCESS} [1/$steps_total] Password unlocked"
        ((steps_completed++))
    else
        echo "${ICON_ERROR} [1/$steps_total] Failed to unlock password"
        log_audit "UNLOCK_USER" "$username" "FAILED" "Password unlock failed"
        return 1
    fi
    
    local new_password=$(generate_random_password)
    
    if echo "$username:$new_password" | chpasswd 2>/dev/null; then
        echo "${ICON_SUCCESS} [2/$steps_total] New password generated"
        ((steps_completed++))
    else
        echo "${ICON_ERROR} [2/$steps_total] Failed to set new password"
        log_audit "UNLOCK_USER" "$username" "FAILED" "Password generation failed"
        return 1
    fi
    
    if chage -d 0 "$username" 2>/dev/null; then
        echo "${ICON_SUCCESS} [3/$steps_total] Password change required on login"
        ((steps_completed++))
    else
        echo "${ICON_ERROR} [3/$steps_total] Failed to set password change"
    fi
    
    if update_user_shell "$username" "$shell_value" >/dev/null 2>&1; then
        echo "${ICON_SUCCESS} [4/$steps_total] Shell restored to $shell_value"
        ((steps_completed++))
    else
        echo "${ICON_ERROR} [4/$steps_total] Failed to restore shell"
    fi
    
    if update_user_sudo "$username" "$sudo_value" >/dev/null 2>&1; then
        echo "${ICON_SUCCESS} [5/$steps_total] Sudo access set to $sudo_value"
        ((steps_completed++))
    else
        echo "${ICON_ERROR} [5/$steps_total] Failed to set sudo access"
    fi
    
    if [ -n "$expiry_value" ] && [ "$expiry_value" != "0" ]; then
        if update_user_expiry "$username" "$expiry_value" >/dev/null 2>&1; then
            echo "${ICON_SUCCESS} [6/$steps_total] Account expiry set"
            ((steps_completed++))
        else
            echo "${ICON_ERROR} [6/$steps_total] Failed to set expiry"
        fi
    else
        if update_user_expiry "$username" "0" >/dev/null 2>&1; then
            echo "${ICON_SUCCESS} [6/$steps_total] Account set to never expire"
            ((steps_completed++))
        else
            echo "${ICON_ERROR} [6/$steps_total] Failed to set expiry"
        fi
    fi
    
    local ssh_dir="/home/$username/.ssh"
    if [ -d "$ssh_dir" ]; then
        if chmod 700 "$ssh_dir" 2>/dev/null; then
            echo "${ICON_SUCCESS} [7/$steps_total] SSH keys unlocked"
            ((steps_completed++))
        else
            echo "${ICON_WARNING} [7/$steps_total] Could not unlock SSH keys"
        fi
    else
        echo "${ICON_INFO} [7/$steps_total] No SSH directory found"
        ((steps_completed++))
    fi
    
    if usermod -c "$original_comment" "$username" >/dev/null 2>&1; then
        echo "${ICON_SUCCESS} Comment restored"
    else
        echo "${ICON_WARNING} Failed to restore comment"
    fi
    
    if store_encrypted_password "$username" "$new_password"; then
        echo "${ICON_SUCCESS} Password encrypted and stored"
    else
        echo "${ICON_WARNING} Failed to store encrypted password"
    fi
    
    echo ""
    echo "${ICON_SUCCESS} User '$username' unlocked successfully ($steps_completed/$steps_total steps completed)"
    echo ""
    echo "IMPORTANT: New password generated - user must change on first login"
    
    log_audit "UNLOCK_USER" "$username" "SUCCESS" "Shell: $shell_value, Sudo: $sudo_value, Expiry: ${expiry_value:-never}, NewPassword: yes"
    
    return 0
}