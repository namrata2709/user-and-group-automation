#!/usr/bin/env bash
# ================================================
# Helper Functions Module
# Version: 1.0.1
# ================================================
# Common utility functions used across modules
# ================================================

# is_regular_user()
# Checks if UID belongs to a regular user (not system)
# Args:
#   $1 - UID to check
# Returns:
#   0 if regular user, 1 if system user
is_regular_user() {
    local uid="$1"
    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"
    [ "$uid" -ge "$min_uid" ] && [ "$uid" -le "$max_uid" ]
}

# is_system_user()
# Checks if UID belongs to a system user
# Args:
#   $1 - UID to check
# Returns:
#   0 if system user, 1 if regular user
is_system_user() {
    local uid="$1"
    local min_uid="${MIN_USER_UID:-1000}"
    [ "$uid" -lt "$min_uid" ]
}

# get_user_status()
# Returns the account status of a user
# Args:
#   $1 - username
# Returns:
#   "LOCKED" if account is locked
#   "ACTIVE" if account is active
get_user_status() {
    local username="$1"
    if passwd -S "$username" 2>/dev/null | grep -q " L "; then
        echo "LOCKED"
    else
        echo "ACTIVE"
    fi
}

# get_account_expiry()
# Gets the account expiration date
# Args:
#   $1 - username
# Returns:
#   Expiry date or "Never"
get_account_expiry() {
    local username="$1"
    local expiry=$(sudo chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    if [ "$expiry" = "never" ]; then
        echo "Never"
    else
        echo "$expiry"
    fi
}

# get_last_login()
# Gets the last login time for a user
# Args:
#   $1 - username
# Returns:
#   Last login timestamp or "Never"
get_last_login() {
    local username="$1"
    lastlog -u "$username" 2>/dev/null | tail -1 | awk '{if ($2 == "**") print "Never"; else print $4" "$5" "$6" "$7}'
}

# is_user_sudo()
# Checks if user has sudo/admin privileges
# Args:
#   $1 - username
# Returns:
#   0 if user has sudo, 1 if not
is_user_sudo() {
    local username="$1"
    groups "$username" 2>/dev/null | grep -qE '\b(sudo|wheel|admin)\b'
}

# get_home_size()
# Gets the size of a user's home directory
# Args:
#   $1 - username
# Returns:
#   Size in human-readable format
get_home_size() {
    local username="$1"
    local home=$(eval echo ~"$username")
    if [ -d "$home" ]; then
        du -sh "$home" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# count_user_processes()
# Counts active processes for a user
# Args:
#   $1 - username
# Returns:
#   Number of processes
count_user_processes() {
    local username="$1"
    ps -u "$username" 2>/dev/null | wc -l
}

# count_user_cron_jobs()
# Counts cron jobs for a user
# Args:
#   $1 - username
# Returns:
#   Number of cron jobs
count_user_cron_jobs() {
    local username="$1"
    sudo crontab -u "$username" -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l
}

# get_group_gid()
# Gets the GID of a group
# Args:
#   $1 - groupname
# Returns:
#   GID or empty if not found
get_group_gid() {
    local groupname="$1"
    getent group "$groupname" 2>/dev/null | cut -d: -f3
}

# get_group_members()
# Gets comma-separated list of group members
# Args:
#   $1 - groupname
# Returns:
#   Comma-separated member list
get_group_members() {
    local groupname="$1"
    getent group "$groupname" 2>/dev/null | cut -d: -f4
}

# find_users_with_primary_group()
# Finds users who have this group as their primary group
# Args:
#   $1 - groupname
# Returns:
#   List of usernames (one per line)
find_users_with_primary_group() {
    local groupname="$1"
    local gid=$(get_group_gid "$groupname")
    [ -z "$gid" ] && return
    getent passwd | awk -F: -v gid="$gid" '$4 == gid {print $1}'
}

# find_files_by_group()
# Finds files owned by a specific group
# Args:
#   $1 - groupname
# Returns:
#   List of files (up to 100)
find_files_by_group() {
    local groupname="$1"
    sudo find / -group "$groupname" -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | head -100
}

# find_processes_by_group()
# Finds processes running as a specific group
# Args:
#   $1 - groupname
# Returns:
#   List of processes
find_processes_by_group() {
    local groupname="$1"
    ps -eo pid,user,group,comm 2>/dev/null | grep " $groupname " | grep -v "grep"
}

# is_system_group()
# Checks if group is a system group
# Args:
#   $1 - groupname
# Returns:
#   0 if system group, 1 if not
is_system_group() {
    local groupname="$1"
    local gid=$(get_group_gid "$groupname")
    local min_gid="${MIN_GROUP_GID:-1000}"
    [ -n "$gid" ] && [ "$gid" -lt "$min_gid" ]
}

# check_user_logged_in()
# Checks if user is currently logged in
# Args:
#   $1 - username
# Returns:
#   Login sessions or empty
check_user_logged_in() {
    local username="$1"
    who | grep "^$username " 2>/dev/null
}

# get_user_processes()
# Gets list of processes for a user
# Args:
#   $1 - username
# Returns:
#   PID and command list
get_user_processes() {
    local username="$1"
    ps -u "$username" -o pid,comm --no-headers 2>/dev/null
}

# get_user_crontab()
# Gets user's crontab contents
# Args:
#   $1 - username
# Returns:
#   Crontab contents or empty
get_user_crontab() {
    local username="$1"
    sudo crontab -u "$username" -l 2>/dev/null || echo ""
}

# get_user_mail_size()
# Gets size of user's mail file
# Args:
#   $1 - username
# Returns:
#   Size in human-readable format
get_user_mail_size() {
    local username="$1"
    local mail_file="/var/mail/$username"
    [ -f "$mail_file" ] && du -h "$mail_file" | cut -f1 || echo "0"
}

# find_user_files_outside_home()
# Finds files owned by user outside their home directory
# Args:
#   $1 - username
# Returns:
#   List of files (up to 20)
find_user_files_outside_home() {
    local username="$1"
    local home=$(eval echo ~"$username")
    sudo find / -user "$username" -not -path "$home/*" -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | head -20
}

# check_user_sudo()
# Alternative name for is_user_sudo (for compatibility)
# Args:
#   $1 - username
# Returns:
#   0 if user has sudo, 1 if not
check_user_sudo() {
    is_user_sudo "$1"
}

# generate_random_password()
# Generates a random password
# Args:
#   $1 - length (optional, default from config or 16)
# Returns:
#   Random password string
generate_random_password() {
    local length="${1:-${PASSWORD_LENGTH:-16}}"
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length"
}