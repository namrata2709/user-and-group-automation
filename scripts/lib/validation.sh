#!/usr/bin/env bash
# ================================================
# Validation Module
# Version: 1.0.1
# ================================================
# Provides input validation functions for usernames,
# groups, dates, shells, and other parameters
# ================================================

# validate_name()
# Validates username or group name against Linux naming rules
# Args:
#   $1 - name to validate
#   $2 - type ("user" or "group")
# Returns:
#   0 if valid, 1 if invalid
validate_name() {
    local name="$1"
    local type="$2"
    local max_length="${MAX_USERNAME_LENGTH:-32}"
    
    # Check length
    if [ ${#name} -gt $max_length ]; then
        echo "${ICON_ERROR} INVALID $type NAME: '$name'"
        echo "   Rules: Maximum $max_length characters"
        return 1
    fi
    
    # Check format: must start with a-z or _, then a-z 0-9 _ -
    if [[ ! "$name" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        echo "${ICON_ERROR} INVALID $type NAME: '$name'"
        echo "   Rules: Start with a-z or _, only use a-z 0-9 _ -, max $max_length chars"
        return 1
    fi
    
    return 0
}

# validate_date()
# Validates date format and checks if date is valid
# Args:
#   $1 - date in YYYY-MM-DD format
# Returns:
#   0 if valid, 1 if invalid
validate_date() {
    local date="$1"
    
    # Check format
    [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && return 1
    
    # Check if date command accepts it
    date -d "$date" &>/dev/null
}

# validate_shell()
# Validates shell path or shortcut
# Args:
#   $1 - shell (path or shortcut: a=allow, d=deny)
# Returns:
#   0 if valid, 1 if invalid
validate_shell() {
    local shell="$1"
    
    # Check shortcuts
    case "${shell,,}" in
        a|allow|d|deny) 
            return 0 
            ;;
        *)
            # Check if file exists
            [ -f "$shell" ] && return 0
            echo "${ICON_ERROR} Invalid shell: $shell"
            echo "   Use: a (allow=/bin/bash), d (deny=/sbin/nologin), or full path"
            return 1
            ;;
    esac
}

# normalize_shell()
# Converts shell shortcuts to full paths
# Args:
#   $1 - shell (shortcut or path)
# Returns:
#   Full shell path
normalize_shell() {
    case "${1,,}" in
        a|allow) 
            echo "/bin/bash" 
            ;;
        d|deny) 
            echo "/sbin/nologin" 
            ;;
        *) 
            echo "$1" 
            ;;
    esac
}

# normalize_sudo()
# Normalizes sudo input to yes/no
# Args:
#   $1 - sudo value (yes/y/no/n)
# Returns:
#   "yes" or "no"
normalize_sudo() {
    case "${1,,}" in
        yes|y) 
            echo "yes" 
            ;;
        *) 
            echo "no" 
            ;;
    esac
}

# validate_uid()
# Checks if UID is in valid range for regular users
# Args:
#   $1 - UID to check
# Returns:
#   0 if valid, 1 if invalid
validate_uid() {
    local uid="$1"
    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"
    
    if [ "$uid" -ge "$min_uid" ] && [ "$uid" -le "$max_uid" ]; then
        return 0
    else
        return 1
    fi
}

# validate_gid()
# Checks if GID is in valid range for regular groups
# Args:
#   $1 - GID to check
# Returns:
#   0 if valid, 1 if invalid
validate_gid() {
    local gid="$1"
    local min_gid="${MIN_GROUP_GID:-1000}"
    
    if [ "$gid" -ge "$min_gid" ] && [ "$gid" -lt 65534 ]; then
        return 0
    else
        return 1
    fi
}