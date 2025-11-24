#!/bin/bash

# =================================================================
#
# Library: compliance.sh
#
# Description: Centralized compliance checks for user and group management.
#
# =================================================================

# ---
#
# Function: run_all_compliance_checks()
#
# Description:
#   Orchestrates the execution of all enabled compliance checks against
#   all regular users and groups on the system.
#
# ---
run_all_compliance_checks() {
    echo "Running User Compliance Checks..."
    run_user_compliance_checks
    echo ""
    echo "Running Group Compliance Checks..."
    run_group_compliance_checks
}


# ---
#
# Function: run_user_compliance_checks()
#
# Description:
#   Runs all user-related compliance checks.
#
# ---
run_user_compliance_checks() {
    local min_uid="${MIN_USER_UID:-1000}"
    local all_users_valid=true

    while IFS=: read -r username _ uid _; do
        if [ "$uid" -ge "$min_uid" ]; then
            local issues
            issues=$(check_user_compliance "$username")
            if [ -n "$issues" ]; then
                all_users_valid=false
                echo "User '$username' has compliance issues: $issues"
            fi
        fi
    done < /etc/passwd

    if [ "$all_users_valid" = true ]; then
        echo "All users are compliant."
        return 0
    else
        return 1
    fi
}

# ---
#
# Function: check_user_compliance()
#
# Description:
#   Runs all individual compliance checks for a single user.
#
# ---
check_user_compliance() {
    local username="$1"
    local issues=""

    if ! check_password_expiry "$username"; then
        issues="${issues}PasswordExpiry,"
    fi
    if ! check_account_expiry "$username"; then
        issues="${issues}AccountExpired,"
    fi
    if ! check_inactive_account "$username"; then
        issues="${issues}InactiveAccount,"
    fi
    if ! check_sudo_password_policy "$username"; then
        issues="${issues}SudoPasswordPolicy,"
    fi
    if ! check_service_account_shell "$username"; then
        issues="${issues}ServiceAccountShell,"
    fi

    echo "${issues%,}"
}

# ---
#
# Function: run_group_compliance_checks()
#
# Description:
#   Runs all group-related compliance checks.
#
# ---
run_group_compliance_checks() {
    local min_gid="${MIN_GROUP_GID:-1000}"
    local all_groups_valid=true

    while IFS=: read -r groupname _ gid _; do
        if [ "$gid" -ge "$min_gid" ]; then
            local issues
            issues=$(check_group_compliance "$groupname")
            if [ -n "$issues" ]; then
                all_groups_valid=false
                echo "Group '$groupname' has compliance issues: $issues"
            fi
        fi
    done < /etc/group

    if [ "$all_groups_valid" = true ]; then
        echo "All groups are compliant."
        return 0
    else
        return 1
    fi
}

# ---
#
# Function: check_group_compliance()
#
# Description:
#   Runs all individual compliance checks for a single group.
#
# ---
check_group_compliance() {
    local groupname="$1"
    local issues=""

    if ! check_empty_group "$groupname"; then
        issues="${issues}EmptyGroup,"
    fi
    if ! check_orphaned_primary_group "$groupname"; then
        issues="${issues}OrphanedPrimaryGroup,"
    fi

    echo "${issues%,}"
}


# --- Rule 1: Password Expiry Compliance ---
check_password_expiry() {
    local username="$1"
    local shell
    shell=$(getent passwd "$username" | cut -d: -f7)
    if [[ "$shell" == *"/sbin/nologin"* || "$shell" == *"/bin/false"* ]]; then
        return 0
    fi
    local max_days
    max_days=$(sudo chage -l "$username" 2>/dev/null | grep "Maximum number of days" | grep -oE '[0-9]+')
    if [ -z "$max_days" ] || [ "$max_days" = "99999" ] || [ "$max_days" -gt 90 ]; then
        return 1
    fi
    return 0
}

# --- Rule 2: Account Expiry Check ---
check_account_expiry() {
    local username="$1"
    local expiry_date
    expiry_date=$(sudo chage -l "$username" 2>/dev/null | grep "Account expires" | awk -F: '{print $2}' | sed 's/^[ \t]*//')
    if [ -z "$expiry_date" ] || [ "$expiry_date" = "never" ]; then
        return 0
    fi
    if date_in_future "$expiry_date"; then
        return 0
    else
        return 1
    fi
}

# --- Rule 3: Inactive Account Check ---
check_inactive_account() {
    local username="$1"
    local ninety_days_ago
    ninety_days_ago=$(date -d "90 days ago" +%s)
    local shell
    shell=$(getent passwd "$username" | cut -d: -f7)
    if [[ "$shell" == *"/sbin/nologin"* || "$shell" == *"/bin/false"* ]]; then
        return 0
    fi
    local last_login
    last_login=$(get_last_login "$username")
    if [ "$last_login" = "Never" ]; then
        local home_dir
        home_dir=$(getent passwd "$username" | cut -d: -f6)
        if [ -d "$home_dir" ]; then
            local home_dir_creation_time
            home_dir_creation_time=$(stat -c %Y "$home_dir")
            if [ "$home_dir_creation_time" -gt "$ninety_days_ago" ]; then
                return 0
            fi
        fi
        return 1
    fi
    local last_login_timestamp
    last_login_timestamp=$(date -d "$last_login" +%s)
    if [ "$last_login_timestamp" -lt "$ninety_days_ago" ]; then
        return 1
    fi
    return 0
}

# --- Rule 4: Sudo User Password Policy ---
check_sudo_password_policy() {
    local username="$1"
    local max_allowed="${SUDO_PASSWORD_EXPIRY_DAYS:-30}"
    if ! is_user_sudo "$username"; then
        return 0
    fi
    local max_days
    max_days=$(sudo chage -l "$username" 2>/dev/null | grep "Maximum number of days" | grep -oE '[0-9]+')
    if [ "$max_days" = "99999" ] || [ -z "$max_days" ]; then
        return 1
    elif [ "$max_days" -gt "$max_allowed" ]; then
        return 1
    fi
    return 0
}

# --- Rule 5: Service Account Shell Check ---
check_service_account_shell() {
    local username="$1"
    local is_service=false
    [[ "$username" =~ ^(svc_|service_|app_) ]] && is_service=true
    groups "$username" 2>/dev/null | grep -qw "services" && is_service=true
    local comment
    comment=$(getent passwd "$username" | cut -d: -f5)
    [[ "$comment" =~ \[SERVICE\]|\[APP\] ]] && is_service=true
    local max_days
    max_days=$(sudo chage -l "$username" 2>/dev/null | grep "Maximum" | grep -oE '[0-9]+')
    [ "$max_days" = "99999" ] && is_service=true
    [ "$is_service" = false ] && return 0
    local shell
    shell=$(getent passwd "$username" | cut -d: -f7)
    [[ "$shell" =~ nologin|false ]] && return 0
    return 1
}

# --- Rule 6: Empty Group Check ---
check_empty_group() {
    local groupname="$1"
    local members
    members=$(get_group_members "$groupname")
    [ -n "$members" ] && return 0
    local primary_users
    primary_users=$(find_users_with_primary_group "$groupname")
    [ -n "$primary_users" ] && return 0
    return 1
}

# --- Rule 7: Orphaned Primary Group Check ---
check_orphaned_primary_group() {
    local groupname="$1"
    local primary_users
    primary_users=$(find_users_with_primary_group "$groupname")
    [ -z "$primary_users" ] && return 0
    local has_orphans=false
    while read -r username; do
        [ -z "$username" ] && continue
        if ! id "$username" &>/dev/null; then
            has_orphans=true
            break
        fi
    done <<< "$primary_users"
    [ "$has_orphans" = true ] && return 1
    return 0
}