#!/bin/bash

update_user_shell() {
    local username="$1"
    local shell_value="$2"
    
    validate_update_user "$username" "UPDATE_SHELL" || return 1
    
    if [ -z "$shell_value" ]; then
        echo "ERROR: Shell value is required"
        return 1
    fi
    
    local new_shell=""
    
    if validate_shell_path "$shell_value"; then
        new_shell="$shell_value"
    elif is_valid_role "$shell_value"; then
        new_shell=$(get_shell_from_role "$shell_value")
        echo "INFO: Using shell from role '$shell_value': $new_shell"
    else
        echo "ERROR: Invalid shell value: $shell_value"
        log_audit "UPDATE_SHELL" "$username" "FAILED" "Invalid shell value: $shell_value"
        return 1
    fi
    
    local current_shell=$(getent passwd "$username" | cut -d: -f7)
    
    if [ "$current_shell" = "$new_shell" ]; then
        echo "INFO: Shell already set to: $new_shell"
        return 0
    fi
    
    if usermod -s "$new_shell" "$username" 2>/dev/null; then
        echo "${ICON_SUCCESS} Shell updated"
        echo "  Old: $current_shell"
        echo "  New: $new_shell"
        log_audit "UPDATE_SHELL" "$username" "SUCCESS" "Old: $current_shell, New: $new_shell"
        return 0
    else
        echo "${ICON_ERROR} Failed to update shell"
        log_audit "UPDATE_SHELL" "$username" "FAILED" "usermod failed"
        return 1
    fi
}

update_user_sudo() {
    local username="$1"
    local sudo_value="$2"
    
    validate_update_user "$username" "UPDATE_SUDO" || return 1
    
    if [ -z "$sudo_value" ]; then
        echo "ERROR: Sudo value required (allow/deny)"
        return 1
    fi
    
    if [[ "$sudo_value" != "allow" && "$sudo_value" != "deny" ]]; then
        echo "ERROR: Invalid sudo value: $sudo_value"
        log_audit "UPDATE_SUDO" "$username" "FAILED" "Invalid value"
        return 1
    fi
    
    local current_status="deny"
    has_sudo_access "$username" && current_status="allow"
    
    if [ "$current_status" = "$sudo_value" ]; then
        echo "INFO: Sudo already set to: $sudo_value"
        return 0
    fi
    
    if [ "$sudo_value" = "allow" ]; then
        if grant_sudo_access "$username"; then
            echo "${ICON_SUCCESS} Sudo granted"
            log_audit "UPDATE_SUDO" "$username" "SUCCESS" "Old: $current_status, New: allow"
            return 0
        fi
    else
        if revoke_sudo_access "$username"; then
            echo "${ICON_SUCCESS} Sudo revoked"
            log_audit "UPDATE_SUDO" "$username" "SUCCESS" "Old: $current_status, New: deny"
            return 0
        fi
    fi
    
    echo "${ICON_ERROR} Failed to update sudo"
    log_audit "UPDATE_SUDO" "$username" "FAILED" "Command failed"
    return 1
}

update_user_expiry() {
    local username="$1"
    local expiry_value="$2"
    
    validate_update_user "$username" "UPDATE_EXPIRY" || return 1
    
    if [ -z "$expiry_value" ]; then
        echo "ERROR: Expiry value required"
        return 1
    fi
    
    local parsed=$(calculate_expiry_date "$expiry_value")
    if [ $? -ne 0 ]; then
        echo "ERROR: Invalid expiry: $expiry_value"
        log_audit "UPDATE_EXPIRY" "$username" "FAILED" "Invalid value"
        return 1
    fi
    
    local expiry_date=$(echo "$parsed" | cut -d'|' -f1)
    local expiry_display=$(echo "$parsed" | cut -d'|' -f2)
    
    local current=$(chage -l "$username" | grep "Account expires" | cut -d: -f2 | xargs)
    
    if [ -z "$expiry_date" ]; then
        if chage -E -1 "$username" 2>/dev/null; then
            echo "${ICON_SUCCESS} Expiry updated"
            echo "  Old: $current"
            echo "  New: never"
            log_audit "UPDATE_EXPIRY" "$username" "SUCCESS" "Old: $current, New: never"
            return 0
        fi
    else
        if chage -E "$expiry_date" "$username" 2>/dev/null; then
            echo "${ICON_SUCCESS} Expiry updated"
            echo "  Old: $current"
            echo "  New: $expiry_display"
            log_audit "UPDATE_EXPIRY" "$username" "SUCCESS" "Old: $current, New: $expiry_date"
            return 0
        fi
    fi
    
    echo "${ICON_ERROR} Failed to update expiry"
    log_audit "UPDATE_EXPIRY" "$username" "FAILED" "chage failed"
    return 1
}

update_user_comment() {
    local username="$1"
    local comment="$2"
    
    validate_update_user "$username" "UPDATE_COMMENT" || return 1
    
    if [ -z "$comment" ]; then
        echo "ERROR: Comment required"
        return 1
    fi
    
    validate_comment "$comment" || return 1
    
    local current=$(getent passwd "$username" | cut -d: -f5)
    local safe="${comment//:/ - }"
    
    if [ "$current" = "$safe" ]; then
        echo "INFO: Comment already set"
        return 0
    fi
    
    if usermod -c "$safe" "$username" 2>/dev/null; then
        echo "${ICON_SUCCESS} Comment updated"
        echo "  Old: $current"
        echo "  New: $safe"
        log_audit "UPDATE_COMMENT" "$username" "SUCCESS" "Old: $current, New: $safe"
        return 0
    else
        echo "${ICON_ERROR} Failed to update comment"
        log_audit "UPDATE_COMMENT" "$username" "FAILED" "usermod failed"
        return 1
    fi
}