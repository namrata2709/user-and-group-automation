#!/bin/bash

# ================================================
# Existence Check Functions
# File: lib/helpers/existence_check.sh
# ================================================

# ================================================
# Check if user exists
# ================================================
# Arguments:
#   $1 - Username
# Returns:
#   Echoes "yes" or "no", returns 0 if exists, 1 if not
# ================================================
user_exists() {
    local username="$1"
    
    if id "$username" >/dev/null 2>&1; then
        echo "yes"
        return 0
    fi
    
    echo "no"
    return 1
}

# ================================================
# Check if group exists
# ================================================
# Arguments:
#   $1 - Group name
# Returns:
#   Echoes "yes" or "no", returns 0 if exists, 1 if not
# ================================================
group_exists() {
    local groupname="$1"
    
    if getent group "$groupname" >/dev/null 2>&1; then
        echo "yes"
        return 0
    fi
    
    echo "no"
    return 1
}

is_system_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        return 1
    fi
    
    local uid=$(id -u "$username" 2>/dev/null)
    
    if [ -z "$uid" ]; then
        return 1
    fi
    
    if [ "$uid" -lt "$MIN_USER_UID" ]; then
        return 0
    fi
    
    return 1
}