#!/bin/bash

lock_user() {
    local username="$1"
    local reason="$2"
    
    validate_update_user "$username" "LOCK_USER" || return 1
    
    if [ -z "$reason" ]; then
        echo "ERROR: Lock reason is required"
        echo "Usage: --lock user --name <username> --reason <reason>"
        return 1
    fi
    
    echo "Locking user: $username"
    echo "Reason: $reason"
    echo ""
    
    local current_comment=$(getent passwd "$username" | cut -d: -f5)
    local lock_comment="${current_comment}:Temporary suspension:${reason}"
    
    local steps_completed=0
    local steps_total=6
    
    if passwd -l "$username" >/dev/null 2>&1; then
        echo "${ICON_SUCCESS} [1/$steps_total] Password locked"
        ((steps_completed++))
    else
        echo "${ICON_ERROR} [1/$steps_total] Failed to lock password"
        log_audit "LOCK_USER" "$username" "FAILED" "Password lock failed"
        return 1
    fi
    
    if update_user_shell "$username" "/sbin/nologin" >/dev/null 2>&1; then
        echo "${ICON_SUCCESS} [2/$steps_total] Shell changed to /sbin/nologin"
        ((steps_completed++))
    else
        echo "${ICON_ERROR} [2/$steps_total] Failed to change shell"
        passwd -u "$username" >/dev/null 2>&1
        log_audit "LOCK_USER" "$username" "FAILED" "Shell change failed, password unlocked"
        return 1
    fi
    
    if update_user_sudo "$username" "deny" >/dev/null 2>&1; then
        echo "${ICON_SUCCESS} [3/$steps_total] Sudo access revoked"
        ((steps_completed++))
    else
        echo "${ICON_ERROR} [3/$steps_total] Failed to revoke sudo"
    fi
    
    local yesterday=$(date -d "yesterday" +%Y-%m-%d)
    if update_user_expiry "$username" "$yesterday" >/dev/null 2>&1; then
        echo "${ICON_SUCCESS} [4/$steps_total] Account expired (date: $yesterday)"
        ((steps_completed++))
    else
        echo "${ICON_ERROR} [4/$steps_total] Failed to set expiry"
    fi
    
    local ssh_dir="/home/$username/.ssh"
    if [ -d "$ssh_dir" ]; then
        if chmod 000 "$ssh_dir" 2>/dev/null; then
            echo "${ICON_SUCCESS} [5/$steps_total] SSH keys locked"
            ((steps_completed++))
        else
            echo "${ICON_WARNING} [5/$steps_total] Could not lock SSH keys"
        fi
    else
        echo "${ICON_INFO} [5/$steps_total] No SSH directory found"
        ((steps_completed++))
    fi
    
    local safe_comment="${lock_comment//:/ - }"
    if usermod -c "$safe_comment" "$username" >/dev/null 2>&1; then
        echo "${ICON_SUCCESS} [6/$steps_total] Comment updated with suspension info"
        ((steps_completed++))
    else
        echo "${ICON_ERROR} [6/$steps_total] Failed to update comment"
    fi
    
    echo ""
    echo "${ICON_SUCCESS} User '$username' locked successfully ($steps_completed/$steps_total steps completed)"
    
    log_audit "LOCK_USER" "$username" "SUCCESS" "Reason: $reason, Password: locked, Shell: /sbin/nologin, Sudo: revoked, Expiry: $yesterday, SSH: locked"
    
    return 0
}