#!/usr/bin/env bash
# ==============================================================================
#
#          FILE: validation.sh
#
#         USAGE: source validation.sh
#
#   DESCRIPTION: Provides a suite of functions for validating common inputs
#                such as usernames, group names, dates, shell paths, UIDs,
#                and GIDs. It also includes functions for normalizing inputs
#                into a standard format.
#
#       OPTIONS: ---
#  REQUIREMENTS: bash, coreutils
#          BUGS: ---
#         NOTES: This library is intended to be sourced by other scripts to
#                ensure consistent validation rules are applied.
#       AUTHOR: Your Name, your.email@example.com
# ORGANIZATION: Your Company
#      CREATED: YYYY-MM-DD
#     REVISION: 1.1.0
#
# ==============================================================================

# ==============================================================================
# SECTION: NAME AND IDENTIFIER VALIDATION
# ==============================================================================\n# SECTION: NAME AND IDENTIFIER VALIDATION\n# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: validate_name()
#
# DESCRIPTION:
#   Validates a username or group name against standard Linux/POSIX naming
#   conventions. This function is critical for preventing the creation of
#   malformed user or group names that could cause issues with system tools
#   or scripts.
#
# ARGUMENTS:
#   $1: name - The username or group name to validate.
#   $2: type - The type of name ("user" or "group"), used for customizing
#       error messages.
#
# RETURNS:
#   0 (true) if the name is valid.
#   1 (false) if the name is invalid, printing a detailed error message to stderr.
#
# RULES:
#   - Length: Must be between 1 and 32 characters. This is a common limit
#     across many Linux distributions.
#   - Start Character: Must begin with a lowercase letter or an underscore.
#     This prevents names that might be misinterpreted as flags or system variables.
#   - Allowed Characters: Subsequent characters can only be lowercase letters,
#     digits, hyphens, or underscores. This avoids special characters that
#     can cause parsing errors in scripts or command-line operations.
# ------------------------------------------------------------------------------
validate_name() {
    local name="$1"
    local type="${2:-name}" # Default to "name" if type not provided
    local max_length="${MAX_USERNAME_LENGTH:-32}"

    # 1. Check for invalid length.
    if [ -z "$name" ] || [ ${#name} -gt "$max_length" ]; then
        echo "Error: Invalid $type name '$name'. Must be 1 to $max_length characters." >&2
        return 1
    fi

    # 2. Check for valid character set and structure.
    #    POSIX standard for user/group names.
    if [[ ! "$name" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "Error: Invalid $type name '$name'. Name must start with a lowercase letter or underscore, followed by letters, digits, hyphens, or underscores." >&2
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------------------
# FUNCTION: _validate_input_file()
#
# DESCRIPTION:
#   Checks if a file exists and is a regular file.
#
# ARGUMENTS:
#   $1: file_path - The path to the file.
#
# RETURNS:
#   0 (true) if the file exists.
#   1 (false) if it does not, printing an error message.
# ------------------------------------------------------------------------------
_validate_input_file() {
    local file_path="$1"
    if [[ ! -f "$file_path" ]]; then
        echo "${ICON_ERROR} Input file not found: $file_path" >&2
        return 1
    fi
    return 0
}

# ==============================================================================
# SECTION: DATA TYPE VALIDATION
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: validate_date()
#
# DESCRIPTION:
#   Validates that a string is a correctly formatted and legitimate date.
#
# ARGUMENTS:
#   $1: date - The date string to validate, expected in "YYYY-MM-DD" format.
#
# RETURNS:
#   0 (true) if the date is valid.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
validate_date() {
    local date="$1"

    # 1. Check for the "YYYY-MM-DD" format.
    if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 1
    fi

    # 2. Use the `date` command to verify it's a real calendar date.
    #    This correctly handles invalid dates like "2023-02-30".
    date -d "$date" &>/dev/null
}


# ------------------------------------------------------------------------------
# FUNCTION: validate_uid()
#
# DESCRIPTION:
#   Checks if a User ID (UID) is within the valid range for regular (non-system)
#   users. The range is defined by MIN_USER_UID and MAX_USER_UID.
#
# ARGUMENTS:
#   $1: uid - The UID to check.
#
# RETURNS:
#   0 (true) if the UID is valid.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
validate_uid() {
    local uid="$1"
    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"

    if ! [[ "$uid" =~ ^[0-9]+$ ]]; then
        return 1 # Not a number
    fi

    if [ "$uid" -ge "$min_uid" ] && [ "$uid" -le "$max_uid" ]; then
        return 0
    else
        return 1
    fi
}


# ------------------------------------------------------------------------------
# FUNCTION: validate_gid()
#
# DESCRIPTION:
#   Checks if a Group ID (GID) is within the valid range for regular (non-system)
#   groups. The range starts from MIN_GROUP_GID.
#
# ARGUMENTS:
#   $1: gid - The GID to check.
#
# RETURNS:
#   0 (true) if the GID is valid.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
validate_gid() {
    local gid="$1"
    local min_gid="${MIN_GROUP_GID:-1000}"

    if ! [[ "$gid" =~ ^[0-9]+$ ]]; then
        return 1 # Not a number
    fi

    # GIDs should be above the system range and below the max system value.
    if [ "$gid" -ge "$min_gid" ] && [ "$gid" -lt 65534 ]; then
        return 0
    else
        return 1
    fi
}

# ==============================================================================
# SECTION: SHELL AND PERMISSION NORMALIZATION
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: validate_shell()
#
# DESCRIPTION:
#   Validates a shell input. The input can be a full path to a shell executable
#   or a predefined shortcut. It checks if the specified shell exists in
#   /etc/shells (if it's not a nologin shell).
#
# ARGUMENTS:
#   $1: shell - The shell path or shortcut to validate.
#
# RETURNS:
#   0 (true) if the shell is valid.
#   1 (false) otherwise, printing an error message to stderr.
# ------------------------------------------------------------------------------
validate_shell() {
    local shell_input="$1"
    local normalized_shell

    normalized_shell=$(normalize_shell "$shell_input")

    # A "denied" shell is always valid.
    if [[ "$normalized_shell" == "/sbin/nologin" || "$normalized_shell" == "/bin/false" ]]; then
        return 0
    fi

    # Check if the shell exists as an executable file.
    if [ ! -f "$normalized_shell" ]; then
        echo "Error: Shell '$normalized_shell' does not exist." >&2
        return 1
    fi

    # Check if the shell is listed in /etc/shells.
    if ! grep -q "^${normalized_shell}$" /etc/shells; then
        echo "Warning: Shell '$normalized_shell' is not a standard login shell listed in /etc/shells." >&2
        # This is a warning, not a hard failure, as custom shells might be intended.
    fi

    return 0
}


# ------------------------------------------------------------------------------
# FUNCTION: normalize_shell()
#
# DESCRIPTION:
#   Converts common shortcuts for shell access into their full, canonical paths.
#   This allows users to specify "allow" or "deny" instead of full paths.
#
# ARGUMENTS:
#   $1: shell_input - The shortcut or path (e.g., "a", "allow", "d", "deny").
#
# OUTPUTS:
#   Prints the normalized shell path (e.g., "/bin/bash", "/sbin/nologin").
#   If the input is not a shortcut, it's returned as-is.
# ------------------------------------------------------------------------------
normalize_shell() {
    case "${1,,}" in
        a|allow|yes)
            echo "/bin/bash"
            ;;
        d|deny|no)
            echo "/sbin/nologin"
            ;;
        *)
            echo "$1" # Return the original value if it's not a shortcut
            ;;
    esac
}


# ------------------------------------------------------------------------------
# FUNCTION: normalize_sudo()
#
# DESCRIPTION:
#   Converts various affirmative/negative inputs into a standard "yes" or "no".
#
# ARGUMENTS:
#   $1: sudo_input - The input to normalize (e.g., "y", "yes", "true").
#
# OUTPUTS:
#   Prints "yes" or "no".
# ------------------------------------------------------------------------------
normalize_sudo() {
    case "${1,,}" in
        yes|y|true|1)
            echo "yes"
            ;;
        *)
            echo "no"
            ;;
    esac
}

is_valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

is_valid_range() {
    local min max
    parse_range "$1" min max
}