#!/usr/bin/env bash
# ================================================
# User Lock Module
# Version: 1.0.1
# ================================================

lock_user() {
    local username="$1"
    local reason="${2:-No reason provided}"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    if passwd -S "$username" 2>/dev/null | grep -q " L "; then
        echo "${ICON_WARNING} User '$username' is already locked"
        return 0
    fi
    
    echo "${ICON_LOCK} Locking user: $username"
    echo "   Reason: $reason"
    
    if sudo passwd -l "$username" &>/dev/null; then
        echo "   ${ICON_SUCCESS} User locked successfully"
        log_action "lock_user" "$username" "SUCCESS" "Reason: $reason"
        
        echo ""
        echo "User '$username' is now locked:"
        echo "  - Cannot login via SSH or terminal"
        echo "  - Existing sessions remain active"
        echo "  - All data preserved"
        echo "  - Can be unlocked: ./user.sh --unlock user --name $username"
    else
        echo "   ${ICON_ERROR} Failed to lock user"
        log_action "lock_user" "$username" "FAILED" "Command failed"
        return 1
    fi
}

unlock_user() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    if ! passwd -S "$username" 2>/dev/null | grep -q " L "; then
        echo "${ICON_WARNING} User '$username' is not locked"
        return 0
    fi
    
    echo "${ICON_UNLOCK} Unlocking user: $username"
    
    if sudo passwd -u "$username" &>/dev/null; then
        echo "   ${ICON_SUCCESS} User unlocked successfully"
        log_action "unlock_user" "$username" "SUCCESS" "User unlocked"
        
        echo ""
        echo "User '$username' is now unlocked and can login"
    else
        echo "   ${ICON_ERROR} Failed to unlock user"
        log_action "unlock_user" "$username" "FAILED" "Command failed"
        return 1
    fi
}