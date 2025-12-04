#!/bin/bash

validate_username() {
    local username="$1"

    if [ -z "$username" ]; then
        return 1
    fi
    
    local len=${#username}
    
    if [ "$len" -gt 32 ]; then
        return 1
    fi

    if [[ "$username" =~ ^[0-9] ]]; then
        echo "ERROR: Username cannot start with a digit"
        return 1
    fi

    if ! [[ $username =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        return 1
    fi

    if [[ $username == *- ]]; then
        return 1
    fi

    local reserved_names=("root" "bin" "daemon" "adm" "lp" "sync" "shutdown" "halt" "mail" "operator" "games" "ftp" "nobody" "systemd" "polkitd" "dbus" "rpc" "sshd" "postfix" "chrony" "ec2-user" "centos" "ubuntu" "admin")
    
    for reserved in "${reserved_names[@]}"; do
        if [ "$username" = "$reserved" ]; then
            echo "ERROR: '$username' is a reserved system username"
            return 1
        fi
    done

    return 0
}

validate_shell_path() {
    local shell_path="$1"
    
    [ -z "$shell_path" ] && return 1
    [ -x "$shell_path" ] && return 0
    return 1
}

is_valid_role() {
    local role="$1"
    case "$role" in
        admin|developer|support|intern|manager|contractor)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

validate_comment() {
    local comment="$1"

    if [ -z "$comment" ]; then
        echo "ERROR: Comment is required. Format: 'firstname lastname:department'"
        return 1
    fi

    if ! [[ "$comment" =~ : ]]; then
        echo "ERROR: Invalid comment format. Missing colon separator. Expected 'firstname lastname:department'."
        echo "Example: 'John Doe:Sales'"
        return 1
    fi

    local name_part="${comment%%:*}"
    local dept_part="${comment#*:}"

    if [ -z "$name_part" ] || [ -z "$dept_part" ]; then
        echo "ERROR: Invalid comment format. Name and department parts cannot be empty."
        echo "Example: 'John Doe:Sales'"
        return 1
    fi

    if ! [[ "$name_part" =~ [[:space:]] ]]; then
        echo "ERROR: Invalid comment format. The name part must contain a space (e.g., 'firstname lastname')."
        echo "Example: 'John Doe:Sales'"
        return 1
    fi

    if [[ "$name_part" =~ ^[[:space:]] || "$name_part" =~ [[:space:]]$ ]]; then
        echo "ERROR: Invalid comment format. The name part cannot start or end with a space."
        return 1
    fi

    return 0
}

validate_user_input() {
    local username="$1"
    local comment="$2"
    local shell_value="$3"
    local sudo_access="$4"
    local primary_group="$5"
    local secondary_groups="$6"
    local password_expiry="$7"
    local password_warning="$8"
    local account_expiry="$9"
    
    local has_errors=0
    
    if ! validate_username "$username"; then
        echo "ERROR: Invalid username format: $username"
        has_errors=1
    fi
    
    if ! validate_comment "$comment"; then
        has_errors=1
    fi
    
    if [ "$(user_exists "$username")" = "yes" ]; then
        echo "ERROR: User '$username' already exists"
        has_errors=1
    fi
    
    if [ -n "$shell_value" ]; then
        if ! is_valid_role "$shell_value" && ! validate_shell_path "$shell_value"; then
            echo "ERROR: Invalid shell value: $shell_value"
            echo "Must be a valid role (admin/developer/support/intern/manager/contractor) or valid shell path"
            has_errors=1
        fi
    fi
    
    if [ -n "$sudo_access" ]; then
        if [[ "$sudo_access" != "allow" && "$sudo_access" != "deny" ]]; then
            echo "ERROR: Invalid sudo access value: $sudo_access"
            echo "Must be 'allow' or 'deny'"
            has_errors=1
        fi
    fi
    
    if [ -n "$primary_group" ]; then
        if ! validate_groupname "$primary_group"; then
            echo "ERROR: Invalid primary group name: $primary_group"
            has_errors=1
        fi
    fi
    
    if [ -n "$secondary_groups" ]; then
        IFS=',' read -ra GROUP_ARRAY <<< "$secondary_groups"
        for group in "${GROUP_ARRAY[@]}"; do
            group=$(echo "$group" | xargs)
            if ! validate_groupname "$group"; then
                echo "ERROR: Invalid secondary group name: $group"
                has_errors=1
            fi
        done
    fi
    
    if [ -n "$password_expiry" ]; then
        if ! [[ "$password_expiry" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid password expiry value: $password_expiry"
            echo "Must be a number (days)"
            has_errors=1
        fi
    fi
    
    if [ -n "$password_warning" ]; then
        if ! [[ "$password_warning" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid password warning value: $password_warning"
            echo "Must be a number (days)"
            has_errors=1
        fi
    fi
    
    if [ -n "$account_expiry" ]; then
        if ! [[ "$account_expiry" =~ ^[0-9]+$ ]] && \
           ! [[ "$account_expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && \
           ! is_valid_role "$account_expiry"; then
            echo "ERROR: Invalid account expiry value: $account_expiry"
            echo "Must be: number (days), date (YYYY-MM-DD), or valid role name"
            has_errors=1
        fi
    fi
    
    if [ $has_errors -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

validate_groupname() {
    local groupname="$1"

    if [ -z "$groupname" ]; then
        return 1
    fi
    
    local len=${#groupname}
    if [ "$len" -lt 1 ] || [ "$len" -gt 32 ]; then
        return 1
    fi

    if ! [[ $groupname =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        return 1
    fi

    if [[ $groupname == *- ]]; then
        return 1
    fi

    return 0
}

validate_update_user() {
    local username="$1"
    local operation="$2"
    
    if [ -z "$username" ]; then
        echo "ERROR: Username is required"
        return 1
    fi
    
    if ! validate_username "$username"; then
        echo "ERROR: Invalid username format: $username"
        return 1
    fi
    
    if [ "$(user_exists "$username")" = "no" ]; then
        echo "ERROR: User '$username' does not exist"
        log_audit "$operation" "$username" "FAILED" "User does not exist"
        return 1
    fi
    
    if is_system_user "$username"; then
        echo "ERROR: Cannot modify system user '$username' (UID < $MIN_USER_UID)"
        log_audit "$operation" "$username" "FAILED" "System user modification denied"
        return 1
    fi
    
    return 0
}