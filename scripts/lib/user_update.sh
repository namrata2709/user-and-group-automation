#!/usr/bin/env bash
# ===============================================
# User Update Module
# Version: 2.1.0
# ===============================================

# =============================================================================
# PRIVATE: _update_user_password
# =============================================================================
_update_user_password() {
    local username="$1"
    local password="$2"
    
    if [[ "$DRY_RUN" = true ]]; then
        info_message "DRY-RUN: Would change password for user '$username'."
        return 0
    fi

    if echo "$username:$password" | sudo chpasswd; then
        success_message "Password for user '$username' updated successfully."
        log_action "update_password" "$username" "SUCCESS"
    else
        error_message "Failed to update password for user '$username'."
        log_action "update_password" "$username" "FAILURE"
        return 1
    fi
}

# =============================================================================
# PRIVATE: _update_user_shell
# =============================================================================
_update_user_shell() {
    local username="$1"
    local shell="$2"

    if ! is_valid_shell "$shell"; then
        error_message "Invalid shell: '$shell'. Not in /etc/shells."
        return 1
    fi

    if [[ "$DRY_RUN" = true ]]; then
        info_message "DRY-RUN: Would change shell for user '$username' to '$shell'."
        return 0
    fi

    if sudo usermod -s "$shell" "$username"; then
        success_message "Shell for user '$username' updated to '$shell'."
        log_action "update_shell" "$username" "SUCCESS" "New shell: $shell"
    else
        error_message "Failed to update shell for user '$username'."
        log_action "update_shell" "$username" "FAILURE" "Shell: $shell"
        return 1
    fi
}

# =============================================================================
# PRIVATE: _update_user_add_to_groups
# =============================================================================
_update_user_add_to_groups() {
    local username="$1"
    local groups_to_add="$2"

    if [[ "$DRY_RUN" = true ]]; then
        info_message "DRY-RUN: Would add user '$username' to groups: '$groups_to_add'."
        return 0
    fi

    if sudo usermod -aG "$groups_to_add" "$username"; then
        success_message "User '$username' added to groups: '$groups_to_add'."
        log_action "add_to_groups" "$username" "SUCCESS" "Groups: $groups_to_add"
    else
        error_message "Failed to add user '$username' to groups."
        log_action "add_to_groups" "$username" "FAILURE" "Groups: $groups_to_add"
        return 1
    fi
}

# =============================================================================
# PRIVATE: _update_user_remove_from_groups
# =============================================================================
_update_user_remove_from_groups() {
    local username="$1"
    local groups_to_remove="$2"

    if [[ "$DRY_RUN" = true ]]; then
        info_message "DRY-RUN: Would remove user '$username' from groups: '$groups_to_remove'."
        return 0
    fi

    local IFS=','
    for group in $groups_to_remove; do
        if sudo gpasswd -d "$username" "$group"; then
            success_message "User '$username' removed from group '$group'."
            log_action "remove_from_group" "$username" "SUCCESS" "Group: $group"
        else
            error_message "Failed to remove user '$username' from group '$group'."
            log_action "remove_from_group" "$username" "FAILURE" "Group: $group"
            return 1
        fi
    done
}

# =============================================================================
# PRIVATE: _update_user_expiry
# =============================================================================
_update_user_expiry() {
    local username="$1"
    local expiry_date="$2"

    if [[ "$DRY_RUN" = true ]]; then
        info_message "DRY-RUN: Would set account expiry for '$username' to '$expiry_date'."
        return 0
    fi

    if sudo chage -E "$expiry_date" "$username"; then
        success_message "Account expiry for '$username' set to '$expiry_date'."
        log_action "set_expiry" "$username" "SUCCESS" "Expiry: $expiry_date"
    else
        error_message "Failed to set account expiry for '$username'."
        log_action "set_expiry" "$username" "FAILURE" "Expiry: $expiry_date"
        return 1
    fi
}

# =============================================================================
# PRIVATE: _update_user_password_policy
# =============================================================================
_update_user_password_policy() {
    local username="$1"
    local max_days="$2"
    local min_days="$3"
    local warn_days="$4"

    local cmd="sudo chage"
    [[ -n "$max_days" ]] && cmd+=" -M $max_days"
    [[ -n "$min_days" ]] && cmd+=" -m $min_days"
    [[ -n "$warn_days" ]] && cmd+=" -W $warn_days"
    cmd+=" $username"

    if [[ "$DRY_RUN" = true ]]; then
        info_message "DRY-RUN: Would execute: $cmd"
        return 0
    fi

    if eval "$cmd"; then
        success_message "Password policy for '$username' updated."
        log_action "update_password_policy" "$username" "SUCCESS"
    else
        error_message "Failed to update password policy for '$username'."
        log_action "update_password_policy" "$username" "FAILURE"
        return 1
    fi
}

# =============================================================================
# PRIVATE: _update_user_comment
# =============================================================================
_update_user_comment() {
    local username="$1"
    local comment="$2"

    if [[ "$DRY_RUN" = true ]]; then
        info_message "DRY-RUN: Would update comment for '$username' to '$comment'."
        return 0
    fi

    if sudo usermod -c "$comment" "$username"; then
        success_message "Comment for user '$username' updated."
        log_action "update_comment" "$username" "SUCCESS"
    else
        error_message "Failed to update comment for user '$username'."
        log_action "update_comment" "$username" "FAILURE"
        return 1
    fi
}

# =============================================================================
# PRIVATE: _update_user_primary_group
# =============================================================================
_update_user_primary_group() {
    local username="$1"
    local groupname="$2"

    if ! group_exists "$groupname"; then
        error_message "Group '$groupname' does not exist."
        return 1
    fi

    if [[ "$DRY_RUN" = true ]]; then
        info_message "DRY-RUN: Would change primary group for '$username' to '$groupname'."
        return 0
    fi

    if sudo usermod -g "$groupname" "$username"; then
        success_message "Primary group for '$username' changed to '$groupname'."
        log_action "update_primary_group" "$username" "SUCCESS" "Group: $groupname"
    else
        error_message "Failed to change primary group for '$username'."
        log_action "update_primary_group" "$username" "FAILURE" "Group: $groupname"
        return 1
    fi
}

# =============================================================================
# PUBLIC: update_user
# =============================================================================
update_user() {
    local username="$1"
    shift

    if ! user_exists "$username"; then
        error_message "User '$username' does not exist. Cannot perform update."
        return 1
    fi

    display_banner "Updating User: $username"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --password) _update_user_password "$username" "$2"; shift 2 ;;
            --shell) _update_user_shell "$username" "$2"; shift 2 ;;
            --add-groups) _update_user_add_to_groups "$username" "$2"; shift 2 ;;
            --remove-groups) _update_user_remove_from_groups "$username" "$2"; shift 2 ;;
            --expiredate) _update_user_expiry "$username" "$2"; shift 2 ;;
            --max-days) _update_user_password_policy "$username" "$2" "" ""; shift 2 ;;
            --min-days) _update_user_password_policy "$username" "" "$2" ""; shift 2 ;;
            --warn-days) _update_user_password_policy "$username" "" "" "$2"; shift 2 ;;
            --comment) _update_user_comment "$username" "$2"; shift 2 ;;
            --primary-group) _update_user_primary_group "$username" "$2"; shift 2 ;;
            *) error_message "Unknown update option: $1"; return 1 ;;
        esac
    done
    
    success_message "All updates for '$username' processed."
}

# =============================================================================
# PUBLIC: parse_users_for_update_from_json
# =============================================================================
parse_users_for_update_from_json() {
    local json_file="$1"

    if ! command_exists "jq"; then
        error_message "jq is not installed. Please install it to process JSON files."
        return 1
    fi

    if ! validate_json_file "$json_file" "users"; then
        return 1
    fi

    local count=0 updated=0 skipped=0 failed=0
    local start_time=$(date +%s)

    while IFS= read -r user_json; do
        ((count++))
        local username=$(echo "$user_json" | jq -r '.username')
        local action=$(echo "$user_json" | jq -r '.action // "update"')

        if [[ "$action" != "update" ]]; then
            info_message "Skipping user '$username' - action is '$action' (not 'update')."
            ((skipped++))
            continue
        fi

        if ! user_exists "$username"; then
            error_message "User '$username' does not exist. Skipping."
            ((failed++))
            continue
        fi

        local updates=()
        while IFS='=' read -r key value; do
            case "$key" in
                password|shell|add-groups|remove-groups|expiredate|max-days|min-days|warn-days|comment|primary-group)
                    updates+=("--$key" "$value")
                    ;;
            esac
        done < <(echo "$user_json" | jq -r '.updates | to_entries | .[] | "\(.key)=\(.value)"')

        if [[ ${#updates[@]} -gt 0 ]]; then
            if update_user "$username" "${updates[@]}"; then
                ((updated++))
            else
                ((failed++))
            fi
        else
            info_message "No valid updates specified for user '$username'. Skipping."
            ((skipped++))
        fi
        echo ""
    done < <(jq -c '.users[]' "$json_file")

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    print_operation_summary "$count" "Updated" "$updated" "$skipped" "$failed" "$duration"
}

# =============================================================================
# PUBLIC: update_users_from_file
# =============================================================================
update_users_from_file() {
    local input_file="$1"
    local format="${2:-auto}"

    if [[ ! -f "$input_file" ]]; then
        error_message "Input file not found: $input_file"
        return 1
    fi

    if [[ "$format" = "auto" ]]; then
        format="${input_file##*.}"
    fi

    display_banner "Bulk User Update"
    info_message "File:    $input_file"
    info_message "Format:  $format"
    echo ""

    case "$format" in
        json)
            parse_users_for_update_from_json "$input_file"
            ;;
        *)
            error_message "Unsupported format for bulk update: '$format'. Only 'json' is supported."
            return 1
            ;;
    esac
}