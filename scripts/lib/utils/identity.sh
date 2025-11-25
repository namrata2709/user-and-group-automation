#!/usr/bin/env bash
# ==============================================================================
#
#          FILE: identity.sh
#
#         USAGE: source identity.sh
#
#   DESCRIPTION: A library of functions for querying and validating user and
#                group identities. These helpers are used to check for the
#                existence of users/groups, determine their type (system vs.
#                regular), and retrieve membership information.
#
#       OPTIONS: ---
#  REQUIREMENTS: bash, coreutils, getent, awk
#          BUGS: ---\
#         NOTES: These functions are fundamental for ensuring that operations
#                like user/group creation do not conflict with existing
#                identities and adhere to system conventions.
#       AUTHOR: Your Name, your.email@example.com
# ORGANIZATION: Your Company
#      CREATED: YYYY-MM-DD
#     REVISION: 1.1.0
#
# ==============================================================================

# ==============================================================================\n# SECTION: USER AND GROUP TYPE VALIDATION\n# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: is_regular_user()
#
# DESCRIPTION:
#   Determines if a user is a "regular" (non-system) user by checking if their
#   UID falls within the standard range defined for human users. This is
#   important for filtering operations to avoid affecting system accounts.
#
# ARGUMENTS:
#   $1: uid - The User ID to check.
#
# GLOBALS:
#   MIN_USER_UID (read): The minimum UID for regular users (default: 1000).
#   MAX_USER_UID (read): The maximum UID for regular users (default: 60000).
#
# RETURNS:
#   0 (true) if the UID is in the regular user range.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
is_regular_user() {
    local uid="$1"
    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"
    [ "$uid" -ge "$min_uid" ] && [ "$uid" -le "$max_uid" ]
}

# ------------------------------------------------------------------------------
# FUNCTION: is_system_user()
#
# DESCRIPTION:
#   Determines if a user is a "system" user by checking if their UID is below
#   the minimum threshold for regular users. System users are typically
#   service accounts that should not be modified by standard user management.
#
# ARGUMENTS:
#   $1: uid - The User ID to check.
#
# GLOBALS:
#   MIN_USER_UID (read): The minimum UID for regular users (default: 1000).
#
# RETURNS:
#   0 (true) if the UID is in the system user range.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
is_system_user() {
    local uid="$1"
    local min_uid="${MIN_USER_UID:-1000}"
    [ "$uid" -lt "$min_uid" ]
}

# ------------------------------------------------------------------------------
# FUNCTION: get_group_gid()
#
# DESCRIPTION:
#   Retrieves the Group ID (GID) for a given group name using the `getent`
#   command. This is a reliable way to get the GID without parsing /etc/group.
#
# ARGUMENTS:
#   $1: groupname - The name of the group.
#
# OUTPUTS:
#   Prints the GID if the group exists, otherwise prints nothing.
# ------------------------------------------------------------------------------
get_group_gid() {
    local groupname="$1"
    getent group "$groupname" 2>/dev/null | cut -d: -f3
}

# ------------------------------------------------------------------------------
# FUNCTION: is_system_group()
#
# DESCRIPTION:
#   Determines if a group is a "system" group by checking if its GID is below
#   the minimum threshold for regular groups. This prevents accidental
#   modification of critical system groups.
#
# ARGUMENTS:
#   $1: groupname - The name of the group to check.
#
# GLOBALS:
#   MIN_GROUP_GID (read): The minimum GID for regular groups (default: 1000).
#
# RETURNS:
#   0 (true) if the group is a system group.
#   1 (false) otherwise.
# ------------------------------------------------------------------------------
is_system_group() {
    local groupname="$1"
    local gid
    gid=$(get_group_gid "$groupname")
    local min_gid="${MIN_GROUP_GID:-1000}"
    [ -n "$gid" ] && [ "$gid" -lt "$min_gid" ]
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
#   Prints the list of members.
# ------------------------------------------------------------------------------
# Retrieves a comma-separated list of all members of a given group.
get_group_members() {
    local groupname="$1"
    getent group "$groupname" 2>/dev/null | cut -d: -f4
}

# ------------------------------------------------------------------------------
# FUNCTION: find_users_with_primary_group()
#
# DESCRIPTION:
#   Finds all users who have the specified group as their primary group. This is
#   useful for operations that need to identify all users belonging to a
#   particular primary group before modifying or deleting it.
#
# ARGUMENTS:
#   $1: groupname - The name of the primary group to search for.
#
# OUTPUTS:
#   Prints a list of usernames, one per line.
# ------------------------------------------------------------------------------
find_users_with_primary_group() {
    local groupname="$1"
    local gid
    gid=$(get_group_gid "$groupname")
    [ -z "$gid" ] && return
    getent passwd | awk -F: -v gid="$gid" '$4 == gid {print $1}'
}