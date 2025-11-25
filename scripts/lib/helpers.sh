#!/usr/bin/env bash
# ==============================================================================
#
#          FILE: helpers.sh
#
#         USAGE: source helpers.sh
#
#   DESCRIPTION: A comprehensive library of utility functions for user and
#                group management automation. This module provides a wide
#                range of helpers for checking user/group status, retrieving
#                system information, parsing data, and performing common
#                validation and string operations.
#
#       OPTIONS: ---
#  REQUIREMENTS: bash, standard Linux core utilities (getent, passwd, etc.)
#          BUGS: ---
#         NOTES: This library is designed to be sourced by other scripts.
#                Many functions rely on `sudo` for privileged operations.
#       AUTHOR: Your Name, your.email@example.com
# ORGANIZATION: Your Company
#      CREATED: YYYY-MM-DD
#     REVISION: 2.1.0
#
# ==============================================================================

# =============================================================================
# SECTION: DEPENDENCY CHECKS
# =============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: _ensure_jq()
#
# DESCRIPTION:
#   Checks if 'jq' is installed and executable. If not, it prints an error
#   and exits.
#
# GLOBALS:
#   ICON_ERROR (read)
#
# ARGUMENTS:
#   None
#
# RETURNS:
#   0 if jq is found.
#   Exits with status 1 if jq is not found.
# ------------------------------------------------------------------------------
_ensure_jq() {
    if ! command -v jq &> /dev/null; then
        echo "${ICON_ERROR} 'jq' is not installed or not in PATH. Please install it to process JSON files." >&2
        exit 1
    fi
}

# ==============================================================================
# SECTION: USER AND GROUP IDENTITY CHECKS
# ==============================================================================
# This section contains functions to verify the identity and type of users and
# groups, distinguishing between regular and system accounts based on UID/GID.
# Configuration variables like MIN_USER_UID can be set to alter the thresholds.
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: is_regular_user()
#
# DESCRIPTION:
#   Determines if a user is a "regular" user based on its UID. Regular users
#   are typically human users, as opposed to system or service accounts. The
#   range for regular UIDs is defined by MIN_USER_UID and MAX_USER_UID.
#
# ARGUMENTS:
#   $1: uid - The user ID to check.
#
# RETURNS:
#   0 (true) if the UID is within the regular user range.
#   1 (false) otherwise.
#
# EXAMPLE:
#   if is_regular_user "1001"; then
#     echo "This is a regular user."
#   fi
# ------------------------------------------------------------------------------
is_regular_user() {
# ... existing code ...
#   $1 - UID to check
# Returns:
#   0 if regular user, 1 if system user
is_regular_user() {
    local uid="$1"
    # Use environment variables for min/max UID, with sane defaults.
    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"
    [ "$uid" -ge "$min_uid" ] && [ "$uid" -le "$max_uid" ]
}


# ------------------------------------------------------------------------------
# FUNCTION: is_system_user()
#
# DESCRIPTION:
#   Determines if a user is a "system" user based on its UID. System users
#   are typically non-interactive accounts used for running services.
#
# ARGUMENTS:
#   $1: uid - The user ID to check.
#
# RETURNS:
#   0 (true) if the UID is below the minimum regular user UID.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
is_system_user() {
# ... existing code ...
#   $1 - UID to check
# Returns:
#   0 if system user, 1 if regular user
is_system_user() {
    local uid="$1"
    local min_uid="${MIN_USER_UID:-1000}"
    [ "$uid" -lt "$min_uid" ]
}


# ------------------------------------------------------------------------------
# FUNCTION: is_system_group()
#
# DESCRIPTION:
#   Determines if a group is a "system" group based on its GID.
#
# ARGUMENTS:
#   $1: groupname - The name of the group to check.
#
# RETURNS:
#   0 (true) if the group's GID is below the minimum regular group GID.
#   1 (false) if the group does not exist or is a regular group.
# ------------------------------------------------------------------------------
is_system_group() {
# ... existing code ...
#   $1 - groupname
# Returns:
#   0 if system group, 1 if not
is_system_group() {
    local groupname="$1"
    local gid
    gid=$(get_group_gid "$groupname")
    local min_gid="${MIN_GROUP_GID:-1000}"
    [ -n "$gid" ] && [ "$gid" -lt "$min_gid" ]
}

# ==============================================================================
# SECTION: USER STATUS AND INFORMATION
# ==============================================================================
# Functions for retrieving detailed information about a user account, such as
# its lock status, password expiration, and last login time.
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: get_user_status()
#
# DESCRIPTION:
#   Retrieves the current status of a user's account (Locked or Active).
#   It parses the output of `passwd -S`.
#
# ARGUMENTS:
#   $1: username - The name of the user to query.
#
# OUTPUTS:
#   Prints "LOCKED" or "ACTIVE" to stdout.
# ------------------------------------------------------------------------------
get_user_status() {
# ... existing code ...
#   $1 - username
# Returns:
#   "LOCKED" if account is locked
#   "ACTIVE" if account is active
get_user_status() {
    local username="$1"
    # `passwd -S` output for a locked account contains " LK ".
    if passwd -S "$username" 2>/dev/null | grep -q " LK "; then
        echo "LOCKED"
    else
        echo "ACTIVE"
    fi
}


# ------------------------------------------------------------------------------
# FUNCTION: get_account_expiry()
#
# DESCRIPTION:
#   Gets the expiration date of a user's account from `chage -l`.
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints the expiry date (e.g., "Jan 01, 2030") or "Never".
# ------------------------------------------------------------------------------
get_account_expiry() {
# ... existing code ...
#   $1 - username
# Returns:
#   Expiry date or "Never"
get_account_expiry() {
    local username="$1"
    # `chage -l` provides detailed password and account age information.
    local expiry
    expiry=$(sudo chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    if [ "$expiry" = "never" ]; then
        echo "Never"
    else
        echo "$expiry"
    fi
}


# ------------------------------------------------------------------------------
# FUNCTION: get_last_login()
#
# DESCRIPTION:
#   Retrieves the last login timestamp for a user using the `lastlog` command.
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints the last login date and time (e.g., "Jan 15 10:30") or "Never".
# ------------------------------------------------------------------------------
get_last_login() {
# ... existing code ...
#   $1 - username
# Returns:
#   Last login timestamp or "Never"
get_last_login() {
    local username="$1"
    # `lastlog` shows the most recent login of all users or a given user.
    # The tail and awk combination extracts the relevant fields.
    lastlog -u "$username" 2>/dev/null | tail -1 | awk '{if ($2 == "**") print "Never"; else print $4" "$5" "$6" "$7}'
}


# ------------------------------------------------------------------------------
# FUNCTION: is_user_sudo()
#
# DESCRIPTION:
#   Checks if a user has sudo privileges by checking their group memberships
#   for common administrative groups (e.g., sudo, wheel, admin).
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# RETURNS:
#   0 (true) if the user is in a sudo-equivalent group.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
is_user_sudo() {
# ... existing code ...
#   $1 - username
# Returns:
#   0 if user has sudo, 1 if not
is_user_sudo() {
    local username="$1"
    # Check for membership in 'sudo', 'wheel', or 'admin' groups.
    groups "$username" 2>/dev/null | grep -qE '\\b(sudo|wheel|admin)\\b'
}


# ------------------------------------------------------------------------------
# FUNCTION: check_user_sudo()
#
# DESCRIPTION:
#   An alias for `is_user_sudo()` for backward compatibility or alternative naming.
# ------------------------------------------------------------------------------
check_user_sudo() {
# ... existing code ...
check_user_sudo() {
    is_user_sudo "$1"
}

# ==============================================================================
# SECTION: RESOURCE USAGE INFORMATION
# ==============================================================================
# Functions to gather statistics about resource consumption by users, such as
# home directory size, process count, and cron jobs.
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: get_home_size()
#
# DESCRIPTION:
#   Calculates the size of a user's home directory in a human-readable format
#   (e.g., 12K, 15M, 2G).
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints the human-readable size or "0" if the directory doesn't exist.
# ------------------------------------------------------------------------------
get_home_size() {
# ... existing code ...
#   $1 - username
# Returns:
#   Size in human-readable format
get_home_size() {
    local username="$1"
    local home
    home=$(eval echo ~"$username")
    if [ -d "$home" ]; then
        # du -sh: --summarize, --human-readable
        du -sh "$home" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}


# ------------------------------------------------------------------------------
# FUNCTION: get_home_size_bytes()
#
# DESCRIPTION:
#   Calculates the size of a user's home directory in bytes.
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints the size in bytes or "0" if the directory doesn't exist.
# ------------------------------------------------------------------------------
get_home_size_bytes() {
# ... existing code ...
#   $1 - username
# Returns:
#   Size in bytes
get_home_size_bytes() {
    local username="$1"
    local home
    home=$(eval echo ~"$username")
    if [ -d "$home" ]; then
        # du -sb: --summarize, --bytes
        du -sb "$home" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}


# ------------------------------------------------------------------------------
# FUNCTION: count_user_processes()
#
# DESCRIPTION:
#   Counts the number of active processes owned by a specific user.
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints the total number of processes.
# ------------------------------------------------------------------------------
count_user_processes() {
# ... existing code ...
#   $1 - username
# Returns:
#   Number of processes
count_user_processes() {
    local username="$1"
    # ps -u <user> | wc -l. The header line is included, so it's a raw count.
    ps -u "$username" 2>/dev/null | wc -l
}


# ------------------------------------------------------------------------------
# FUNCTION: count_user_cron_jobs()
#
# DESCRIPTION:
#   Counts the number of active (non-commented) cron jobs for a user.
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints the number of cron jobs.
# ------------------------------------------------------------------------------
count_user_cron_jobs() {
# ... existing code ...
#   $1 - username
# Returns:
#   Number of cron jobs
count_user_cron_jobs() {
    local username="$1"
    # List cron jobs, filter out comments and blank lines, then count.
    sudo crontab -u "$username" -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l
}


# ------------------------------------------------------------------------------
# FUNCTION: get_user_mail_size()
#
# DESCRIPTION:
#   Gets the size of a user's local mail spool file (typically in /var/mail).
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints the human-readable size of the mail file or "0" if not found.
# ------------------------------------------------------------------------------
get_user_mail_size() {
# ... existing code ...
#   $1 - username
# Returns:
#   Size in human-readable format
get_user_mail_size() {
    local username="$1"
    local mail_file="/var/mail/$username"
    [ -f "$mail_file" ] && du -h "$mail_file" | cut -f1 || echo "0"
}

# ==============================================================================
# SECTION: GROUP INFORMATION
# ==============================================================================
# Functions for retrieving details about groups, including GID, members, and
# associated files or processes.
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: get_group_gid()
#
# DESCRIPTION:
#   Retrieves the Group ID (GID) for a given group name.
#
# ARGUMENTS:
#   $1: groupname - The name of the group.
#
# OUTPUTS:
#   Prints the GID or an empty string if the group is not found.
# ------------------------------------------------------------------------------
get_group_gid() {
# ... existing code ...
#   $1 - groupname
# Returns:
#   GID or empty if not found
get_group_gid() {
    local groupname="$1"
    # getent group <group> | cut -d: -f3
    getent group "$groupname" 2>/dev/null | cut -d: -f3
}


# ------------------------------------------------------------------------------
# FUNCTION: get_group_members()
#
# DESCRIPTION:
#   Retrieves a comma-separated list of all members of a given group.
#
# ARGUMENTS:
#   $1: groupname - The name of the group.
#
# OUTPUTS:
#   Prints a comma-separated string of member usernames.
# ------------------------------------------------------------------------------
get_group_members() {
# ... existing code ...
#   $1 - groupname
# Returns:
#   Comma-separated member list
get_group_members() {
    local groupname="$1"
    # getent group <group> | cut -d: -f4
    getent group "$groupname" 2>/dev/null | cut -d: -f4
}


# ------------------------------------------------------------------------------
# FUNCTION: find_users_with_primary_group()
#
# DESCRIPTION:
#   Finds all users who have the specified group as their primary group.
#
# ARGUMENTS:
#   $1: groupname - The name of the group.
#
# OUTPUTS:
#   Prints a list of usernames, one per line.
# ------------------------------------------------------------------------------
find_users_with_primary_group() {
# ... existing code ...
#   $1 - groupname
# Returns:
#   List of usernames (one per line)
find_users_with_primary_group() {
    local groupname="$1"
    local gid
    gid=$(get_group_gid "$groupname")
    [ -z "$gid" ] && return
    # awk through /etc/passwd to find users with matching primary GID (4th field).
    getent passwd | awk -F: -v gid="$gid" '$4 == gid {print $1}'
}


# ------------------------------------------------------------------------------
# FUNCTION: find_files_by_group()
#
# DESCRIPTION:
#   Finds files on the system owned by a specific group. This can be a slow
#   operation. It excludes virtual filesystems like /proc and /sys.
#
# ARGUMENTS:
#   $1: groupname - The name of the group.
#
# OUTPUTS:
#   Prints a list of file paths (up to a limit of 100).
# ------------------------------------------------------------------------------
find_files_by_group() {
# ... existing code ...
#   $1 - groupname
# Returns:
#   List of files (up to 100)
find_files_by_group() {
    local groupname="$1"
    # `find / -group <group>` is a heavy operation.
    sudo find / -group "$groupname" -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | head -100
}


# ------------------------------------------------------------------------------
# FUNCTION: find_processes_by_group()
#
# DESCRIPTION:
#   Finds processes running under the effective group ID of the specified group.
#
# ARGUMENTS:
#   $1: groupname - The name of the group.
#
# OUTPUTS:
#   Prints a list of matching processes (PID, User, Group, Command).
# ------------------------------------------------------------------------------
find_processes_by_group() {
# ... existing code ...
#   $1 - groupname
# Returns:
#   List of processes
find_processes_by_group() {
    local groupname="$1"
    ps -eo pid,user,group,comm 2>/dev/null | grep " $groupname " | grep -v "grep"
}

# ==============================================================================
# SECTION: USER SESSION INFORMATION
# ==============================================================================
# Functions for inspecting active user sessions and related resources.
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: check_user_logged_in()
#
# DESCRIPTION:
#   Checks if a user is currently logged in by inspecting the output of `who`.
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints the line from `who` if the user is logged in.
# ------------------------------------------------------------------------------
check_user_logged_in() {
# ... existing code ...
#   $1 - username
# Returns:
#   Login sessions or empty
check_user_logged_in() {
    local username="$1"
    who | grep "^$username " 2>/dev/null
}


# ------------------------------------------------------------------------------
# FUNCTION: get_user_processes()
#
# DESCRIPTION:
#   Gets a simple list of processes (PID and command) for a given user.
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints a list of "PID Command" pairs, one per line.
# ------------------------------------------------------------------------------
get_user_processes() {
# ... existing code ...
#   $1 - username
# Returns:
#   PID and command list
get_user_processes() {
    local username="$1"
    ps -u "$username" -o pid,comm --no-headers 2>/dev/null
}


# ------------------------------------------------------------------------------
# FUNCTION: get_user_crontab()
#
# DESCRIPTION:
#   Retrieves the full contents of a user's crontab.
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints the crontab content or an empty string if none exists.
# ------------------------------------------------------------------------------
get_user_crontab() {
# ... existing code ...
#   $1 - username
# Returns:
#   Crontab contents or empty
get_user_crontab() {
    local username="$1"
    sudo crontab -u "$username" -l 2>/dev/null || echo ""
}


# ------------------------------------------------------------------------------
# FUNCTION: find_user_files_outside_home()
#
# DESCRIPTION:
#   Finds files owned by a user that are located outside of their home
#   directory. This can be useful for security and cleanup audits.
#
# ARGUMENTS:
#   $1: username - The name of the user.
#
# OUTPUTS:
#   Prints a list of file paths (up to a limit of 20).
# ------------------------------------------------------------------------------
find_user_files_outside_home() {
# ... existing code ...
#   $1 - username
# Returns:
#   List of files (up to 20)
find_user_files_outside_home() {
    local username="$1"
    local home
    home=$(eval echo ~"$username")
    # Find files owned by user, excluding their home, /proc, and /sys.
    sudo find / -user "$username" -not -path "$home/*" -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | head -20
}

# ==============================================================================
# SECTION: PASSWORD GENERATION
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: generate_random_password()
#
# DESCRIPTION:
#   Generates a cryptographically secure random password. It reads from
#   /dev/urandom and filters characters to create the password.
#
# ARGUMENTS:
#   $1: length (optional) - The desired length of the password. Defaults to
#       the value of the PASSWORD_LENGTH environment variable, or 16.
#
# OUTPUTS:
#   Prints the generated password to stdout.
# ------------------------------------------------------------------------------
generate_random_password() {
# ... existing code ...
#   $1 - length (optional, default from config or 16)
# Returns:
#   Random password string
generate_random_password() {
    local length="${1:-${PASSWORD_LENGTH:-16}}"
    # Read from /dev/urandom for entropy, then filter for desired characters.
    tr -dc 'A-Za-z0-9!@#$%^&*()' < /dev/urandom | head -c "$length"
}

# ==============================================================================
# SECTION: PATTERN MATCHING AND RANGES (v2.0.0+)
# ==============================================================================
# Advanced functions for flexible matching, including wildcard patterns and
# numeric/data-size ranges.
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: match_pattern()
#
# DESCRIPTION:
#   Matches a string against a pattern that supports wildcards. This is used
#   for implementing `LIKE` style operators in the `--where` clause.
#   The matching is case-insensitive.
#
# ARGUMENTS:
#   $1: value - The string value to check.
#   $2: pattern - The pattern to match against. Supports:
#       '*' - matches any sequence of characters.
#       '?' - matches any single character.
#
# RETURNS:
#   0 (true) if the value matches the pattern.
#   1 (false) otherwise.
#
# EXAMPLES:
#   match_pattern "alice" "a*"      -> returns 0
#   match_pattern "test1" "test?"   -> returns 0
#   match_pattern "bob"   "a*"      -> returns 1
# ------------------------------------------------------------------------------
match_pattern() {
# ... existing code ...
#   match_pattern \"bob\" \"a*\"          # Returns 1 (no match)
match_pattern() {
    local value="$1"
    local pattern="$2"

    # An empty pattern is a wildcard for everything.
    [ -z "$pattern" ] && return 0

    # We must convert the simple wildcard pattern to a valid regex.
    # 1. Escape any special regex characters in the user's pattern.
    local regex_pattern
    regex_pattern=$(echo "$pattern" | sed 's/[.[\\^$]/\\\\&/g')

    # 2. Convert our wildcards (*, ?) to their regex equivalents (.*, .).
    regex_pattern=$(echo "$regex_pattern" | sed 's/\\*/.*/g' | sed 's/?/./g')

    # 3. Perform a case-insensitive regex match.
    [[ "${value,,}" =~ ^${regex_pattern,,}$ ]]
}


# ------------------------------------------------------------------------------
# FUNCTION: parse_range()
#
# DESCRIPTION:
#   Parses a string representing a range (e.g., "1000-2000", "100MB-1GB")
#   into minimum and maximum values. It uses `normalize_value` to handle
#   units like MB, GB, etc.
#
# ARGUMENTS:
#   $1: range_str - The string defining the range.
#   $2: min_ref - Nameref variable to store the minimum value.
#   $3: max_ref - Nameref variable to store the maximum value.
#
# RETURNS:
#   0 (true) if the range string is valid and min < max.
#   1 (false) otherwise.
#
# EXAMPLE:
#   local min max
#   if parse_range "100MB-1GB" min max; then
#     echo "Min: $min, Max: $max"
#   fi
# ------------------------------------------------------------------------------
parse_range() {
# ... existing code ...
#   parse_range \"100MB-1GB\" min max  # min=104857600, max=1073741824 (bytes)
parse_range() {
    local range_str="$1"
    local -n min_ref=$2
    local -n max_ref=$3

    # The range must be in the format "min-max".
    if [[ ! "$range_str" =~ ^(.+)-(.+)$ ]]; then
        return 1
    fi

    local min_str="${BASH_REMATCH[1]}"
    local max_str="${BASH_REMATCH[2]}"

    # Normalize values to allow comparison (e.g., convert "1GB" to bytes).
    min_ref=$(normalize_value "$min_str")
    max_ref=$(normalize_value "$max_str")

    # A valid range requires min to be less than max.
    [ "$min_ref" -lt "$max_ref" ] 2>/dev/null
}


# ------------------------------------------------------------------------------
# FUNCTION: normalize_value()
#
# DESCRIPTION:
#   Converts a value with a unit (e.g., "100MB", "30d") into a base unit
#   for comparison.
#   - Size units (KB, MB, GB, TB) are converted to bytes.
#   - Time units (d, w, m, y) are converted to days.
#   - Plain numbers are returned as-is.
#
# ARGUMENTS:
#   $1: value - The string value to normalize (e.g., "100MB").
#
# OUTPUTS:
#   Prints the normalized numeric value. Returns 0 and prints "0" on invalid format.
#
# EXAMPLES:
#   normalize_value "100MB" -> 104857600
#   normalize_value "2w"    -> 14
# ------------------------------------------------------------------------------
normalize_value() {
# ... existing code ...
#   normalize_value \"1500\"     # Returns: 1500
normalize_value() {
    local value="$1"

    # Handle standard data size units.
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

    # Handle simple time units. Note: 'm' is ambiguous but treated as 30 days.
    if [[ "$value" =~ ^([0-9]+)([dwmy])$ ]]; then
        local number="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"

        case "$unit" in
            d) echo "$number" ;;
            w) echo $((number * 7)) ;;
            m) echo $((number * 30)) ;; # Approximation for month
            y) echo $((number * 365)) ;; # Approximation for year
        esac
        return 0
    fi

    # Handle plain numbers.
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
        return 0
    fi

    # If format is unrecognized, return 0 and signal failure.
    echo "0"
    return 1
}


# ------------------------------------------------------------------------------
# FUNCTION: in_range()
#
# DESCRIPTION:
#   Checks if a given value falls within a specified range string.
#
# ARGUMENTS:
#   $1: value - The value to check (can have units, e.g., "1500", "120MB").
#   $2: range_str - The range to check against (e.g., "1000-2000", "100MB-1GB").
#
# RETURNS:
#   0 (true) if the value is within the range.
#   1 (false) otherwise, or if the range string is invalid.
# ------------------------------------------------------------------------------
in_range() {
# ... existing code ...
#   in_range \"500\" \"1000-2000\"         # Returns 1
in_range() {
    local value="$1"
    local range_str="$2"

    # An empty range string means no filtering, so it's always a match.
    [ -z "$range_str" ] && return 0

    local min max
    parse_range "$range_str" min max || return 1

    # Normalize the value to be checked so it can be compared to the range.
    value=$(normalize_value "$value")

    # Perform the numeric comparison.
    [ "$value" -ge "$min" ] && [ "$value" -le "$max" ]
}

# ==============================================================================
# SECTION: DATE AND TIME UTILITIES
# ==============================================================================
# Functions for parsing, comparing, and calculating differences in dates.
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: days_since()
#
# DESCRIPTION:
#   Calculates the number of days that have passed since a given date string.
#   Handles date formats from commands like `chage` and `lastlog`.
#
# ARGUMENTS:
#   $1: date_str - The date string to parse (e.g., "Jan 15 2024", "Never").
#
# OUTPUTS:
#   Prints the number of days, or -1 if the date is "Never" or invalid.
# ------------------------------------------------------------------------------
days_since() {
# ... existing code ...
#   days_since \"Never\"         # Returns: -1
days_since() {
    local date_str="$1"

    # Handle special case "Never" or empty string.
    [ "$date_str" = "Never" ] && echo "-1" && return 0
    [ -z "$date_str" ] && echo "-1" && return 0

    # Attempt to convert the date string to a Unix timestamp.
    local date_timestamp
    date_timestamp=$(date -d "$date_str" +%s 2>/dev/null)

    # If conversion fails, the date is invalid.
    [ -z "$date_timestamp" ] && echo "-1" && return 0

    # Calculate the difference in seconds and convert to days.
    local current_timestamp
    current_timestamp=$(date +%s)
    local diff_seconds=$((current_timestamp - date_timestamp))
    local days=$((diff_seconds / 86400))

    echo "$days"
}


# ------------------------------------------------------------------------------
# FUNCTION: date_in_future()
#
# DESCRIPTION:
#   Checks if a given date string is in the future.
#
# ARGUMENTS:
#   $1: date_str - The date string to check.
#
# RETURNS:
#   0 (true) if the date is in the future or "Never".
#   1 (false) if the date is in the past or invalid.
# ------------------------------------------------------------------------------
date_in_future() {
# ... existing code ...
# Returns:
#   0 if in future, 1 if past/invalid
date_in_future() {
    local date_str="$1"

    # An account that "Never" expires is considered to be in the future.
    [ "$date_str" = "Never" ] && return 0
    [ -z "$date_str" ] && return 1

    local date_timestamp
    date_timestamp=$(date -d "$date_str" +%s 2>/dev/null)
    [ -z "$date_timestamp" ] && return 1

    local current_timestamp
    current_timestamp=$(date +%s)
    [ "$date_timestamp" -gt "$current_timestamp" ]
}


# ------------------------------------------------------------------------------
# FUNCTION: date_within_days()
#
# DESCRIPTION:
#   Checks if a date falls within a certain number of days from today.
#
# ARGUMENTS:
#   $1: date_str - The date string to check.
#   $2: days - The number of days from now.
#
# RETURNS:
#   0 (true) if the date is between now and N days from now.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
date_within_days() {
# ... existing code ...
# Returns:
#   0 if within days, 1 if not
date_within_days() {
    local date_str="$1"
    local days="$2"

    local days_until
    days_until=$(days_since "$date_str")
    # A positive number from days_since means the date is in the past.
    # We check if it's between 0 (today) and the specified number of days.
    [ "$days_until" -ge 0 ] && [ "$days_until" -le "$days" ]
}

# ==============================================================================
# SECTION: SORTING UTILITIES
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: sort_array()
#
# DESCRIPTION:
#   A general-purpose function to sort an array of values either
#   alphabetically or numerically, in ascending or descending order.
#
# ARGUMENTS:
#   $1: sort_type - "alpha" or "numeric".
#   $2: reverse - "true" for descending, "false" for ascending.
#   $@: array_elements - The remaining arguments are the elements to be sorted.
#
# OUTPUTS:
#   Prints the sorted elements, one per line.
# ------------------------------------------------------------------------------
sort_array() {
# ... existing code ...
# Returns:
#   Sorted array (one per line)
sort_array() {
    local sort_type="$1"
    local reverse="$2"
    shift 2
    local -a array=("$@")

    local sort_opts=""

    case "$sort_type" in
        numeric)
            sort_opts="-n" # Numeric sort
            ;;
        alpha|*)
            sort_opts="" # Default to alphabetical
            ;;
    esac

    if [ "$reverse" = "true" ]; then
        printf '%s\\n' "${array[@]}" | sort $sort_opts -r # -r for reverse
    else
        printf '%s\\n' "${array[@]}" | sort $sort_opts
    fi
}

# ==============================================================================
# SECTION: STRING UTILITIES
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: trim()
#
# DESCRIPTION:
#   Removes leading and trailing whitespace from a string.
#
# ARGUMENTS:
#   $1: str - The string to trim.
#
# OUTPUTS:
#   Prints the trimmed string.
# ------------------------------------------------------------------------------
trim() {
# ... existing code ...
# Returns:
#   Trimmed string
trim() {
    local str="$1"
    # Use sed to remove space characters from the beginning and end of the line.
    echo "$str" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}


# ------------------------------------------------------------------------------
# FUNCTION: join_array()
#
# DESCRIPTION:
#   Joins the elements of an array into a single string, separated by a
#   specified delimiter.
#
# ARGUMENTS:
#   $1: delimiter - The character or string to place between elements.
#   $@: array_elements - The elements to join.
#
# OUTPUTS:
#   Prints the resulting joined string.
#
# EXAMPLE:
#   join_array "," "apple" "banana" "cherry" -> "apple,banana,cherry"
# ------------------------------------------------------------------------------
join_array() {
# ... existing code ...
# Returns:
#   Joined string
join_array() {
    local delimiter="$1"
    shift
    local -a array=("$@")

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

# ==============================================================================
# SECTION: VALIDATION UTILITIES
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: is_valid_number()
#
# DESCRIPTION:
#   Checks if a string contains only digits (is a valid non-negative integer).
#
# ARGUMENTS:
#   $1: string - The string to check.
#
# RETURNS:
#   0 (true) if the string is a valid number.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
is_valid_number() {
# ... existing code ...
# Returns:
#   0 if valid number, 1 if not
is_valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}


# ------------------------------------------------------------------------------
# FUNCTION: is_valid_range()
#
# DESCRIPTION:
#   Checks if a string is a valid range format by attempting to parse it.
#
# ARGUMENTS:
#   $1: range_str - The range string to validate.
#
# RETURNS:
#   0 (true) if the range is valid.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
is_valid_range() {
# ... existing code ...
# Returns:
#   0 if valid, 1 if not
is_valid_range() {
    local range_str="$1"
    local min max
    # Simply leverage parse_range's return code.
    parse_range "$range_str" min max
}

# ==============================================================================
# SECTION: LOGGING
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: log_debug()
#
# DESCRIPTION:
#   Prints a debug message to stderr, but only if the DEBUG environment
#   variable is set to "true".
#
# ARGUMENTS:
#   $1: message - The debug message to print.
#
# EXAMPLE:
#   DEBUG=true ./myscript.sh
# ------------------------------------------------------------------------------
log_debug() {
# ... existing code ...
# Logs debug message if DEBUG mode is enabled
# Args:
#   $1 - message
log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        # Prepend timestamp and redirect to stderr to separate from normal output.
        echo "[DEBUG $(date '+%H:%M:%S')] $1" >&2
    fi
}


# ------------------------------------------------------------------------------
# FUNCTION: get_recent_logins_for_user()
#
# DESCRIPTION:
#   Parses the `last` command output to find all login sessions for a user
#   within a specified time window. It handles active ("still logged in")
#   and completed sessions, calculating durations in seconds.
#
# ARGUMENTS:
#   $1: username - The user to query.
#   $2: hours (optional) - The number of hours in the past to search.
#       Defaults to 24.
#
# RETURNS:
#   0 (true) if logins are found and prints them.
#   1 (false) if no logins are found or the user is invalid.
#
# OUTPUTS:
#   Prints a pipe-delimited list of sessions, one per line:
#   timestamp|tty|from|status|duration_seconds
# ------------------------------------------------------------------------------
get_recent_logins_for_user() {
# ... existing code ...
get_recent_logins_for_user() {
    local username="$1"
    local hours="${2:-24}"

    # Ensure the user exists before proceeding.
    if ! id "$username" &>/dev/null; then
        return 1
    fi

    # Calculate the cutoff time for filtering logs.
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "$hours hours ago" +%s 2>/dev/null)
    if [ -z "$cutoff_timestamp" ]; then
        # Fallback for systems without `date -d` (e.g., some macOS versions).
        cutoff_timestamp=$(($(date +%s) - (hours * 3600)))
    fi

    local -a results=()

    # Use `last -F -w` for full dates and usernames. Read line by line.
    while read -r line; do
        # Skip header and irrelevant lines.
        [[ "$line" =~ ^reboot ]] && continue
        [[ "$line" =~ ^wtmp ]] && continue
        [[ -z "$line" ]] && continue

        # Parse line components. Awk is good for simple column extraction.
        local user
        user=$(echo "$line" | awk '{print $1}')

        # Process only lines for the target user.
        [ "$user" != "$username" ] && continue

        local tty
        tty=$(echo "$line" | awk '{print $2}')
        local from
        from=$(echo "$line" | awk '{print $3}')
        local login_date
        login_date=$(echo "$line" | awk '{print $4, $5, $7, $6}') # Reorder for `date -d`
        local duration
        duration=$(echo "$line" | grep -oP '\\(.*?\\)' | tr -d '()')

        # Convert login date to a timestamp for comparison.
        local login_timestamp
        login_timestamp=$(date -d "$login_date" +%s 2>/dev/null)

        # Skip if date is invalid or before our time window.
        [ -z "$login_timestamp" ] && continue
        [ "$login_timestamp" -lt "$cutoff_timestamp" ] && continue

        # Clean up the 'from' field for consistency.
        [ "$from" = "-" ] && from="local"
        [ -z "$from" ] && from="local"

        # Calculate session duration in seconds.
        local session_status="logged_out"
        local duration_seconds=0

        if [[ "$duration" =~ still ]]; then
            # Active session: duration is from login time to now.
            session_status="active"
            local current_timestamp
            current_timestamp=$(date +%s)
            duration_seconds=$((current_timestamp - login_timestamp))
        elif [[ "$duration" =~ ([0-9]+):([0-9]+) ]]; then
            # Logged out session with HH:MM duration.
            local dur_hours="${BASH_REMATCH[1]}"
            local dur_mins="${BASH_REMATCH[2]}"
            duration_seconds=$(((dur_hours * 3600) + (dur_mins * 60)))
        elif [[ "$duration" =~ ([0-9]+)\\+([0-9]+):([0-9]+) ]]; then
            # Logged out session with DAYS+HH:MM duration.
            local dur_days="${BASH_REMATCH[1]}"
            local dur_hours="${BASH_REMATCH[2]}"
            local dur_mins="${BASH_REMATCH[3]}"
            duration_seconds=$(((dur_days * 86400) + (dur_hours * 3600) + (dur_mins * 60)))
        fi

        # Store the formatted result.
        results+=("$login_timestamp|$tty|$from|$session_status|$duration_seconds")

    done < <(last -F -w "$username" 2>/dev/null | tail -n +2)

    # Print all found sessions.
    if [ ${#results[@]} -gt 0 ]; then
        printf '%s\\n' "${results[@]}"
        return 0
    else
        return 1 # No recent logins found.
    fi
}

# ==============================================================================
# SECTION: DETAILED SYSTEM STATISTICS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: calculate_detailed_statistics()
#
# DESCRIPTION:
#   A comprehensive function that scans the entire system to generate a wide
#   array of statistics about users, groups, resources, and security policies.
#   This is an expensive operation intended for detailed summary reports.
#   It iterates through /etc/passwd and /etc/group multiple times to gather
#   and aggregate data.
#
# ARGUMENTS:
#   None.
#
# OUTPUTS:
#   Prints a single, pipe-delimited string of key=value pairs containing all
#   the calculated statistics.
# ------------------------------------------------------------------------------
calculate_detailed_statistics() {
# ... existing code ...
#   calculate_detailed_statistics
calculate_detailed_statistics() {
    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"
    local min_gid="${MIN_GROUP_GID:-1000}"

    # --- USER STATISTICS ---
    # Collect all regular user UIDs from /etc/passwd
    local -a uids=()
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        uids+=("$uid")
    done < /etc/passwd

    # Calculate basic UID stats: min, max, average, median
    local uid_count=${#uids[@]}
    local uid_min=999999
    local uid_max=0
    local uid_sum=0

    for uid in "${uids[@]}"; do
        [ "$uid" -lt "$uid_min" ] && uid_min=$uid
        [ "$uid" -gt "$uid_max" ] && uid_max=$uid
        uid_sum=$((uid_sum + uid))
    done

    local uid_avg=0
    [ "$uid_count" -gt 0 ] && uid_avg=$((uid_sum / uid_count))

    # Approximate median by sorting and picking the middle element.
    local uid_median=0
    if [ "$uid_count" -gt 0 ]; then
        local sorted_uids=($(printf '%s\\n' "${uids[@]}" | sort -n))
        local mid=$((uid_count / 2))
        uid_median=${sorted_uids[$mid]}
    fi

    # --- HOME DIRECTORY STATISTICS ---
    # Collect home directory sizes for all regular users.
    local -a home_sizes=()
    local total_home_bytes=0

    while IFS=: read -r username _ uid _ _ home _; do
        is_regular_user "$uid" || continue
        if [ -d "$home" ]; then
            local size
            size=$(du -sb "$home" 2>/dev/null | cut -f1)
            [ -n "$size" ] && home_sizes+=("$size")
            [ -n "$size" ] && total_home_bytes=$((total_home_bytes + size))
        fi
    done < /etc/passwd

    # Calculate home directory size stats: min, max, average (in MB)
    local home_count=${#home_sizes[@]}
    local home_min=0
    local home_max=0
    local home_avg=0

    if [ "$home_count" -gt 0 ]; then
        home_min=${home_sizes[0]}
        home_max=${home_sizes[0]}

        for size in "${home_sizes[@]}"; do
            [ "$size" -lt "$home_min" ] && home_min=$size
            [ "$size" -gt "$home_max" ] && home_max=$size
        done

        home_avg=$((total_home_bytes / home_count))
    fi

    # Convert bytes to megabytes for readability.
    local total_home_mb=$((total_home_bytes / 1048576))
    local home_avg_mb=$((home_avg / 1048576))
    local home_min_mb=$((home_min / 1048576))
    local home_max_mb=$((home_max / 1048576))

    # --- GROUP STATISTICS ---
    # Analyze group memberships from /etc/group.
    local -a member_counts=()
    local empty_groups=0
    local single_member_groups=0
    local large_groups=0  # Groups with >10 members

    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue # Skip system groups

        local member_count=0
        if [ -n "$members" ]; then
            member_count=$(echo "$members" | tr ',' '\\n' | wc -l)
        fi

        member_counts+=("$member_count")

        [ "$member_count" -eq 0 ] && ((empty_groups++))
        [ "$member_count" -eq 1 ] && ((single_member_groups++))
        [ "$member_count" -gt 10 ] && ((large_groups++))

    done < /etc/group

    # Calculate group member stats: average, max.
    local group_count=${#member_counts[@]}
    local member_sum=0
    local member_max=0

    for count in "${member_counts[@]}"; do
        member_sum=$((member_sum + count))
        [ "$count" -gt "$member_max" ] && member_max=$count
    done

    local member_avg=0
    [ "$group_count" -gt 0 ] && member_avg=$((member_sum / group_count))

    # --- SHELL DISTRIBUTION ---
    # Count how many users use each type of shell.
    local bash_count=0
    local sh_count=0
    local zsh_count=0
    local nologin_count=0
    local other_shell_count=0

    while IFS=: read -r username _ uid _ _ _ shell; do
        is_regular_user "$uid" || continue

        case "$shell" in
            /bin/bash) ((bash_count++)) ;;
            /bin/sh) ((sh_count++)) ;;
            /bin/zsh|/usr/bin/zsh) ((zsh_count++)) ;;
            *nologin*|*false*) ((nologin_count++)) ;;
            *) ((other_shell_count++)) ;;
        esac
    done < /etc/passwd

    # --- LOGIN ACTIVITY STATISTICS ---
    # Analyze last login times for all regular users.
    local never_logged_in=0
    local logged_in_last_day=0
    local logged_in_last_week=0
    local logged_in_last_month=0
    local inactive_users=0  # Inactive for >90 days

    local one_day_ago
    one_day_ago=$(date -d "1 day ago" +%s 2>/dev/null || echo $(($(date +%s) - 86400)))
    local one_week_ago
    one_week_ago=$(date -d "7 days ago" +%s 2>/dev/null || echo $(($(date +%s) - 604800)))
    local one_month_ago
    one_month_ago=$(date -d "30 days ago" +%s 2>/dev/null || echo $(($(date +%s) - 2592000)))
    local ninety_days_ago
    ninety_days_ago=$(date -d "90 days ago" +%s 2>/dev/null || echo $(($(date +%s) - 7776000)))

    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue

        local last_login
        last_login=$(get_last_login "$username")

        if [ "$last_login" = "Never" ]; then
            ((never_logged_in++))
            ((inactive_users++))
        else
            local login_timestamp
            login_timestamp=$(date -d "$last_login" +%s 2>/dev/null)

            if [ -n "$login_timestamp" ]; then
                [ "$login_timestamp" -gt "$one_day_ago" ] && ((logged_in_last_day++))
                [ "$login_timestamp" -gt "$one_week_ago" ] && ((logged_in_last_week++))
                [ "$login_timestamp" -gt "$one_month_ago" ] && ((logged_in_last_month++))
                [ "$login_timestamp" -lt "$ninety_days_ago" ] && ((inactive_users++))
            fi
        fi
    done < /etc/passwd

    # --- PASSWORD POLICY COMPLIANCE ---
    # Check password expiration policies for users via `chage`.
    local pwd_never_expires=0
    local pwd_expires_30=0
    local pwd_expires_60=0
    local pwd_expires_90=0
    local pwd_expires_custom=0

    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue

        local max_days
        max_days=$(sudo chage -l "$username" 2>/dev/null | grep "Maximum number of days" | grep -oE '[0-9]+')

        if [ "$max_days" = "99999" ] || [ -z "$max_days" ]; then
            ((pwd_never_expires++))
        elif [ "$max_days" -le 30 ]; then
            ((pwd_expires_30++))
        elif [ "$max_days" -le 60 ]; then
            ((pwd_expires_60++))
        elif [ "$max_days" -le 90 ]; then
            ((pwd_expires_90++))
        else
            ((pwd_expires_custom++))
        fi
    done < /etc/passwd

    # --- ACTIVE PROCESSES & RESOURCES ---
    # Count processes and cron jobs per user.
    local users_with_processes=0
    local total_user_processes=0
    local users_with_cron=0
    local total_cron_jobs=0

    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue

        local proc_count
        proc_count=$(($(count_user_processes "$username") - 1)) # Subtract header line
        [ "$proc_count" -lt 0 ] && proc_count=0

        if [ "$proc_count" -gt 0 ]; then
            ((users_with_processes++))
            total_user_processes=$((total_user_processes + proc_count))
        fi

        local cron_count
        cron_count=$(count_user_cron_jobs "$username")
        if [ "$cron_count" -gt 0 ]; then
            ((users_with_cron++))
            total_cron_jobs=$((total_cron_jobs + cron_count))
        fi
    done < /etc/passwd

    # --- BUILD FINAL RESULT STRING ---
    # Combine all collected metrics into a single, parsable string.
    echo "uid_min=$uid_min|uid_max=$uid_max|uid_avg=$uid_avg|uid_median=$uid_median|total_home_mb=$total_home_mb|home_avg_mb=$home_avg_mb|home_min_mb=$home_min_mb|home_max_mb=$home_max_mb|empty_groups=$empty_groups|single_member_groups=$single_member_groups|large_groups=$large_groups|member_avg=$member_avg|member_max=$member_max|bash_users=$bash_count|sh_users=$sh_count|zsh_users=$zsh_count|nologin_users=$nologin_count|other_shell_users=$other_shell_count|never_logged_in=$never_logged_in|logged_in_last_day=$logged_in_last_day|logged_in_last_week=$logged_in_last_week|logged_in_last_month=$logged_in_last_month|inactive_users=$inactive_users|pwd_never_expires=$pwd_never_expires|pwd_expires_30=$pwd_expires_30|pwd_expires_60=$pwd_expires_60|pwd_expires_90=$pwd_expires_90|pwd_expires_custom=$pwd_expires_custom|users_with_processes=$users_with_processes|total_user_processes=$total_user_processes|users_with_cron=$users_with_cron|total_cron_jobs=$total_cron_jobs"
}