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

update_user_password() {
    local username="$1"
    
    validate_update_user "$username" "UPDATE_PASSWORD" || return 1
    
    local new_password=$(generate_random_password)
    echo "INFO: Generated random password"
    
    if echo "$username:$new_password" | chpasswd 2>/dev/null; then
        echo "${ICON_SUCCESS} Password updated"
        
        if store_encrypted_password "$username" "$new_password"; then
            echo "${ICON_SUCCESS} Random password encrypted and stored"
        else
            echo "${ICON_WARNING} Failed to store encrypted password"
        fi
        
        log_audit "UPDATE_PASSWORD" "$username" "SUCCESS" "Random password generated"
        return 0
    else
        echo "${ICON_ERROR} Failed to update password"
        log_audit "UPDATE_PASSWORD" "$username" "FAILED" "chpasswd failed"
        return 1
    fi
}

update_user_add_groups() {
    local username="$1"
    local groups_to_add="$2"
    
    validate_update_user "$username" "ADD_GROUPS" || return 1
    
    if [ -z "$groups_to_add" ]; then
        echo "ERROR: Groups to add are required"
        return 1
    fi
    
    local current_groups=$(id -Gn "$username" | tr ' ' ',')
    local added_groups=""
    local failed_groups=""
    
    IFS=',' read -ra GROUP_ARRAY <<< "$groups_to_add"
    for group in "${GROUP_ARRAY[@]}"; do
        group=$(echo "$group" | xargs)
        
        if [ "$(group_exists "$group")" = "no" ]; then
            echo "WARNING: Group '$group' does not exist, creating..."
            if ! add_group "$group" "yes"; then
                failed_groups="$failed_groups,$group"
                continue
            fi
        fi
        
        if groups "$username" | grep -qw "$group"; then
            echo "INFO: User already in group '$group'"
            continue
        fi
        
        if usermod -aG "$group" "$username" 2>/dev/null; then
            added_groups="$added_groups,$group"
        else
            failed_groups="$failed_groups,$group"
        fi
    done
    
    added_groups="${added_groups#,}"
    failed_groups="${failed_groups#,}"
    
    if [ -n "$added_groups" ]; then
        echo "${ICON_SUCCESS} Added to groups: $added_groups"
    fi
    
    if [ -n "$failed_groups" ]; then
        echo "${ICON_ERROR} Failed to add to groups: $failed_groups"
        log_audit "ADD_GROUPS" "$username" "PARTIAL" "Added: $added_groups, Failed: $failed_groups"
        return 1
    fi
    
    log_audit "ADD_GROUPS" "$username" "SUCCESS" "Groups: $added_groups"
    return 0
}

update_user_remove_groups() {
    local username="$1"
    local groups_to_remove="$2"
    
    validate_update_user "$username" "REMOVE_GROUPS" || return 1
    
    if [ -z "$groups_to_remove" ]; then
        echo "ERROR: Groups to remove are required"
        return 1
    fi
    
    local removed_groups=""
    local failed_groups=""
    local not_member=""
    
    IFS=',' read -ra GROUP_ARRAY <<< "$groups_to_remove"
    for group in "${GROUP_ARRAY[@]}"; do
        group=$(echo "$group" | xargs)
        
        if [ "$(group_exists "$group")" = "no" ]; then
            echo "WARNING: Group '$group' does not exist"
            not_member="$not_member,$group"
            continue
        fi
        
        if ! groups "$username" | grep -qw "$group"; then
            echo "INFO: User not in group '$group'"
            not_member="$not_member,$group"
            continue
        fi
        
        if gpasswd -d "$username" "$group" >/dev/null 2>&1; then
            removed_groups="$removed_groups,$group"
        else
            failed_groups="$failed_groups,$group"
        fi
    done
    
    removed_groups="${removed_groups#,}"
    failed_groups="${failed_groups#,}"
    not_member="${not_member#,}"
    
    if [ -n "$removed_groups" ]; then
        echo "${ICON_SUCCESS} Removed from groups: $removed_groups"
    fi
    
    if [ -n "$failed_groups" ]; then
        echo "${ICON_ERROR} Failed to remove from groups: $failed_groups"
        log_audit "REMOVE_GROUPS" "$username" "PARTIAL" "Removed: $removed_groups, Failed: $failed_groups"
        return 1
    fi
    
    log_audit "REMOVE_GROUPS" "$username" "SUCCESS" "Groups: $removed_groups"
    return 0
}

update_user_primary_group() {
    local username="$1"
    local new_primary_group="$2"
    
    validate_update_user "$username" "UPDATE_PRIMARY_GROUP" || return 1
    
    if [ -z "$new_primary_group" ]; then
        echo "ERROR: Primary group is required"
        return 1
    fi
    
    if ! validate_groupname "$new_primary_group"; then
        echo "ERROR: Invalid group name: $new_primary_group"
        return 1
    fi
    
    if [ "$(group_exists "$new_primary_group")" = "no" ]; then
        echo "WARNING: Group '$new_primary_group' does not exist, creating..."
        if ! add_group "$new_primary_group" "yes"; then
            echo "ERROR: Failed to create group"
            return 1
        fi
    fi
    
    local current_primary=$(id -gn "$username")
    
    if [ "$current_primary" = "$new_primary_group" ]; then
        echo "INFO: Primary group already set to: $new_primary_group"
        return 0
    fi
    
    if usermod -g "$new_primary_group" "$username" 2>/dev/null; then
        echo "${ICON_SUCCESS} Primary group updated"
        echo "  Old: $current_primary"
        echo "  New: $new_primary_group"
        log_audit "UPDATE_PRIMARY_GROUP" "$username" "SUCCESS" "Old: $current_primary, New: $new_primary_group"
        return 0
    else
        echo "${ICON_ERROR} Failed to update primary group"
        log_audit "UPDATE_PRIMARY_GROUP" "$username" "FAILED" "usermod failed"
        return 1
    fi
}

update_user_password_policy() {
    local username="$1"
    local max_days="$2"
    local min_days="$3"
    local warn_days="$4"
    
    validate_update_user "$username" "UPDATE_PASSWORD_POLICY" || return 1
    
    if [ -z "$max_days" ] && [ -z "$min_days" ] && [ -z "$warn_days" ]; then
        echo "ERROR: At least one policy parameter required"
        echo "  --pexpiry <days>   Max days before password expires"
        echo "  --pmin <days>      Min days before password can be changed"
        echo "  --pwarn <days>     Warning days before expiry"
        return 1
    fi
    
    local chage_cmd="chage"
    local policy_changes=""
    
    if [ -n "$max_days" ]; then
        if ! [[ "$max_days" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid max days: $max_days"
            return 1
        fi
        chage_cmd="$chage_cmd -M $max_days"
        policy_changes="$policy_changes, MaxDays: $max_days"
    fi
    
    if [ -n "$min_days" ]; then
        if ! [[ "$min_days" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid min days: $min_days"
            return 1
        fi
        chage_cmd="$chage_cmd -m $min_days"
        policy_changes="$policy_changes, MinDays: $min_days"
    fi
    
    if [ -n "$warn_days" ]; then
        if ! [[ "$warn_days" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid warn days: $warn_days"
            return 1
        fi
        chage_cmd="$chage_cmd -W $warn_days"
        policy_changes="$policy_changes, WarnDays: $warn_days"
    fi
    
    policy_changes="${policy_changes#, }"
    
    if $chage_cmd "$username" 2>/dev/null; then
        echo "${ICON_SUCCESS} Password policy updated"
        [ -n "$max_days" ] && echo "  Max days: $max_days"
        [ -n "$min_days" ] && echo "  Min days: $min_days"
        [ -n "$warn_days" ] && echo "  Warn days: $warn_days"
        log_audit "UPDATE_PASSWORD_POLICY" "$username" "SUCCESS" "$policy_changes"
        return 0
    else
        echo "${ICON_ERROR} Failed to update password policy"
        log_audit "UPDATE_PASSWORD_POLICY" "$username" "FAILED" "chage failed"
        return 1
    fi
}