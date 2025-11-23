#!/usr/bin/env bash
# ================================================
# Helper Functions Module
# Version: 2.0.0
# ================================================
# Common utility functions used across modules
# NEW: Pattern matching, range parsing for v2.0.0
# ================================================

# ============================================
# USER/GROUP CHECKS
# ============================================

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

# ============================================
# USER STATUS & INFO
# ============================================

# get_user_status()
# Returns the account status of a user
# Args:
#   $1 - username
# Returns:
#   "LOCKED" if account is locked
#   "ACTIVE" if account is active
get_user_status() {
    local username="$1"
    if passwd -S "$username" 2>/dev/null | grep -q " LK "; then
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

# check_user_sudo()
# Alternative name for is_user_sudo (for compatibility)
check_user_sudo() {
    is_user_sudo "$1"
}

# ============================================
# RESOURCE INFORMATION
# ============================================

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

# get_home_size_bytes()
# Gets the size of a user's home directory in bytes
# Args:
#   $1 - username
# Returns:
#   Size in bytes
get_home_size_bytes() {
    local username="$1"
    local home=$(eval echo ~"$username")
    if [ -d "$home" ]; then
        du -sb "$home" 2>/dev/null | cut -f1
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

# ============================================
# GROUP INFORMATION
# ============================================

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

# ============================================
# USER SESSION INFORMATION
# ============================================

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

# ============================================
# PASSWORD GENERATION
# ============================================

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

# ============================================
# PATTERN MATCHING (NEW in v2.0.0)
# ============================================

# match_pattern()
# Matches value against pattern with wildcards
# Supports: * (any chars), ? (single char)
# Args:
#   $1 - value to match
#   $2 - pattern (with * and ? wildcards)
# Returns:
#   0 if matches, 1 if not
# Examples:
#   match_pattern "alice" "a*"        # Returns 0 (match)
#   match_pattern "developer" "*dev*" # Returns 0 (match)
#   match_pattern "test1" "test?"     # Returns 0 (match)
#   match_pattern "bob" "a*"          # Returns 1 (no match)
match_pattern() {
    local value="$1"
    local pattern="$2"
    
    # Empty pattern matches everything
    [ -z "$pattern" ] && return 0
    
    # Convert wildcards to bash glob pattern
    # Escape special regex chars first
    local regex_pattern=$(echo "$pattern" | sed 's/[.[\^$]/\\&/g')
    
    # Convert wildcards: * -> .*, ? -> .
    regex_pattern=$(echo "$regex_pattern" | sed 's/\*/\.\*/g' | sed 's/?/\./g')
    
    # Case-insensitive match
    [[ "${value,,}" =~ ^${regex_pattern,,}$ ]]
}

# ============================================
# RANGE PARSING (NEW in v2.0.0)
# ============================================

# parse_range()
# Parses a range string (e.g., "1000-2000", "100MB-1GB")
# Args:
#   $1 - range string
#   $2 - variable name for min value
#   $3 - variable name for max value
# Returns:
#   0 if valid range, 1 if invalid
# Examples:
#   parse_range "1000-2000" min max  # min=1000, max=2000
#   parse_range "100MB-1GB" min max  # min=104857600, max=1073741824 (bytes)
parse_range() {
    local range_str="$1"
    local -n min_ref=$2
    local -n max_ref=$3
    
    # Check format: value-value
    if [[ ! "$range_str" =~ ^(.+)-(.+)$ ]]; then
        return 1
    fi
    
    local min_str="${BASH_REMATCH[1]}"
    local max_str="${BASH_REMATCH[2]}"
    
    # Convert to comparable values (handle units)
    min_ref=$(normalize_value "$min_str")
    max_ref=$(normalize_value "$max_str")
    
    # Validate min < max
    [ "$min_ref" -lt "$max_ref" ] 2>/dev/null
}

# normalize_value()
# Normalizes a value with units to base unit
# Args:
#   $1 - value string (e.g., "100MB", "30d", "1500")
# Returns:
#   Normalized value (bytes for sizes, days for time, raw number otherwise)
# Examples:
#   normalize_value "100MB"    # Returns: 104857600
#   normalize_value "30d"      # Returns: 30
#   normalize_value "2w"       # Returns: 14
#   normalize_value "1500"     # Returns: 1500
normalize_value() {
    local value="$1"
    
    # Size units: KB, MB, GB, TB
    if [[ "$value" =~ ^([0-9]+)(KB|MB|GB|TB)$ ]]; then
        local number="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        
        case "$unit" in
            KB) echo $((number * 1024)) ;;
            MB) echo $((number * 1024 * 1024)) ;;
            GB) echo $((number * 1024 * 1024 * 1024)) ;;
            TB) echo $((number * 1024 * 1024 * 1024 * 1024)) ;;
        esac
        return 0
    fi
    
    # Time units: d (days), w (weeks), m (months), y (years)
    if [[ "$value" =~ ^([0-9]+)([dwmy])$ ]]; then
        local number="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        
        case "$unit" in
            d) echo "$number" ;;
            w) echo $((number * 7)) ;;
            m) echo $((number * 30)) ;;
            y) echo $((number * 365)) ;;
        esac
        return 0
    fi
    
    # Plain number
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
        return 0
    fi
    
    # Invalid format
    echo "0"
    return 1
}

# in_range()
# Checks if a value is within a range
# Args:
#   $1 - value to check
#   $2 - range string (e.g., "1000-2000")
# Returns:
#   0 if in range, 1 if not
# Examples:
#   in_range "1500" "1000-2000"        # Returns 0
#   in_range "104857600" "100MB-1GB"   # Returns 0 (value is 100MB)
#   in_range "500" "1000-2000"         # Returns 1
in_range() {
    local value="$1"
    local range_str="$2"
    
    # Empty range = no filtering
    [ -z "$range_str" ] && return 0
    
    local min max
    parse_range "$range_str" min max || return 1
    
    # Normalize value for comparison
    value=$(normalize_value "$value")
    
    # Check if value is in range
    [ "$value" -ge "$min" ] && [ "$value" -le "$max" ]
}

# ============================================
# DATE/TIME UTILITIES (NEW in v2.0.0)
# ============================================

# days_since()
# Calculates days since a date
# Args:
#   $1 - date string (from lastlog, chage, etc.)
# Returns:
#   Number of days, or -1 if invalid/never
# Examples:
#   days_since "Jan 15 2024"   # Returns: N (days since Jan 15)
#   days_since "Never"         # Returns: -1
days_since() {
    local date_str="$1"
    
    # Handle "Never"
    [ "$date_str" = "Never" ] && echo "-1" && return 0
    [ -z "$date_str" ] && echo "-1" && return 0
    
    # Try to parse date
    local date_timestamp=$(date -d "$date_str" +%s 2>/dev/null)
    
    # Invalid date
    [ -z "$date_timestamp" ] && echo "-1" && return 0
    
    # Calculate days
    local current_timestamp=$(date +%s)
    local diff_seconds=$((current_timestamp - date_timestamp))
    local days=$((diff_seconds / 86400))
    
    echo "$days"
}

# date_in_future()
# Checks if a date is in the future
# Args:
#   $1 - date string
# Returns:
#   0 if in future, 1 if past/invalid
date_in_future() {
    local date_str="$1"
    
    [ "$date_str" = "Never" ] && return 0
    [ -z "$date_str" ] && return 1
    
    local date_timestamp=$(date -d "$date_str" +%s 2>/dev/null)
    [ -z "$date_timestamp" ] && return 1
    
    local current_timestamp=$(date +%s)
    [ "$date_timestamp" -gt "$current_timestamp" ]
}

# date_within_days()
# Checks if a date is within N days from now
# Args:
#   $1 - date string
#   $2 - number of days
# Returns:
#   0 if within days, 1 if not
date_within_days() {
    local date_str="$1"
    local days="$2"
    
    local days_until=$(days_since "$date_str")
    [ "$days_until" -ge 0 ] && [ "$days_until" -le "$days" ]
}

# ============================================
# SORTING UTILITIES (NEW in v2.0.0)
# ============================================

# sort_array()
# Sorts an array of values
# Args:
#   $1 - sort type (alpha, numeric)
#   $2 - reverse (true/false)
#   $3+ - array elements
# Returns:
#   Sorted array (one per line)
sort_array() {
    local sort_type="$1"
    local reverse="$2"
    shift 2
    local array=("$@")
    
    local sort_opts=""
    
    case "$sort_type" in
        numeric)
            sort_opts="-n"
            ;;
        alpha|*)
            sort_opts=""
            ;;
    esac
    
    if [ "$reverse" = "true" ]; then
        printf '%s\n' "${array[@]}" | sort $sort_opts -r
    else
        printf '%s\n' "${array[@]}" | sort $sort_opts
    fi
}

# ============================================
# STRING UTILITIES
# ============================================

# trim()
# Trims leading/trailing whitespace
# Args:
#   $1 - string to trim
# Returns:
#   Trimmed string
trim() {
    local str="$1"
    echo "$str" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# join_array()
# Joins array elements with delimiter
# Args:
#   $1 - delimiter
#   $2+ - array elements
# Returns:
#   Joined string
join_array() {
    local delimiter="$1"
    shift
    local array=("$@")
    
    local result=""
    local first=true
    
    for item in "${array[@]}"; do
        if [ "$first" = true ]; then
            result="$item"
            first=false
        else
            result="$result$delimiter$item"
        fi
    done
    
    echo "$result"
}

# ============================================
# VALIDATION UTILITIES
# ============================================

# is_valid_number()
# Checks if string is a valid number
# Args:
#   $1 - string to check
# Returns:
#   0 if valid number, 1 if not
is_valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# is_valid_range()
# Checks if string is a valid range
# Args:
#   $1 - range string
# Returns:
#   0 if valid, 1 if not
is_valid_range() {
    local range_str="$1"
    local min max
    parse_range "$range_str" min max
}

# ============================================
# LOGGING HELPER
# ============================================

# log_debug()
# Logs debug message if DEBUG mode is enabled
# Args:
#   $1 - message
log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "[DEBUG $(date '+%H:%M:%S')] $1" >&2
    fi
}