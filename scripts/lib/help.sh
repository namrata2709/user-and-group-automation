#!/usr/bin/env bash
# ===============================================-
# Help System Module
# Version: 2.1.0
# ===============================================-
# This module provides functions to display detailed help messages for the
# EC2 User Management System. It covers general usage, specific operations
# like --add, --view, and --report, and advanced topics such as JSON input/output,
# role-based provisioning, and configuration. Each function is designed to
# provide clear, actionable information to the user.
# ===============================================-

# =================================================================================================
# FUNCTION: show_general_help
# DESCRIPTION:
#   Displays the main help message, providing a comprehensive overview of the script's
#   capabilities, including primary operations, common options, and usage examples.
#   It serves as the entry point for users seeking guidance on how to use the script.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   None
# =================================================================================================
show_general_help() {
    cat <<'EOF'
========================================
EC2 User Management System
========================================

DESCRIPTION:
  A comprehensive command-line tool for managing user and group accounts
  on EC2 instances. It simplifies standard administrative tasks, supports
  bulk operations, and provides powerful reporting and querying capabilities.

USAGE:
  sudo ./user.sh [OPERATION] [OPTIONS]

OPERATIONS:
  --add                Add users or groups.
  --update             Update existing users or groups.
  --delete             Delete users or groups.
  --lock               Lock a user account.
  --unlock             Unlock a user account.
  --view               View users, groups, or system details.
  --report             Generate security, activity, and compliance reports.
  --export             Export user and group data to CSV or JSON.
  --apply-roles        Provision users and apply configurations from a role file.
  --compliance         Run system compliance and security checks.
  --help [topic]       Show this message or help for a specific topic.

COMMON OPTIONS:
  --dry-run            Simulate an operation without making system changes.
  --config <path>      Specify a custom configuration file.
  --log-level <level>  Set the logging level (e.g., info, debug, error).
  --json               Output results in JSON format (for --view, --report).

EXAMPLES:
  # Add a single user with an automatically generated password.
  sudo ./user.sh --add user --name alice --password random

  # Add multiple groups from a text file.
  sudo ./user.sh --add group --names groups.txt

  # Lock a user account with a recorded reason.
  sudo ./user.sh --lock --name bob --reason "Security audit"

  # View all users with a home directory larger than 1GB.
  sudo ./user.sh --view users --where "home_size > '1GB'"

  # Generate a security report in JSON format.
  sudo ./user.sh --report security --json

DETAILED HELP:
  ./user.sh --help view
  ./user.sh --help add
  ./user.sh --help delete
  ./user.sh --help json
  ./user.sh --help roles
  ./user.sh --help config

----------------------------------------
Script Version: 3.0.0
Configuration: /etc/user-automation/config.conf
Log File: /var/log/user-automation.log
========================================
EOF
}

# =================================================================================================
# FUNCTION: show_json_help
# DESCRIPTION:
#   Provides detailed guidance on using JSON for both input and output. It explains
#   the file structure for bulk operations (--add, --delete, --update) and how to
#   request JSON output for data retrieval commands (--view, --report).
#
# PARAMETERS:
#   None
#
# RETURNS:
#   None
# =================================================================================================
show_json_help() {
    cat <<'EOF'
========================================
JSON Operations Help
========================================

JSON is a powerful format for both input (bulk operations) and output (data retrieval).

----------------------------------------
JSON INPUT (--input <file.json>)
----------------------------------------
Use a JSON file to perform bulk operations for adding, updating, or deleting users and groups.

  # Add multiple users from a JSON file.
  sudo ./user.sh --add user --input new_users.json

  # Update user attributes from a JSON file.
  sudo ./user.sh --update user --input user_updates.json

  # Delete groups defined in a JSON file.
  sudo ./user.sh --delete group --input old_groups.json

JSON FILE FORMATS:

  users_add.json (for --add user):
  {
    "users": [
      {
        "username": "alice",
        "comment": "Alice Smith, Developer",
        "groups": ["developers", "docker"],
        "shell": "/bin/bash",
        "password_policy": { "type": "random" }
      }
    ]
  }

  groups_add.json (for --add group):
  {
    "groups": [
      {
        "name": "developers",
        "gid": "2000",
        "members": ["alice", "bob"]
      }
    ]
  }

  (See './user.sh --help add' and './user.sh --help update' for more examples.)

----------------------------------------
JSON OUTPUT (--json)
----------------------------------------
Enable JSON output to get machine-readable data from --view and --report commands.
This is ideal for scripting, automation, or integration with other tools like 'jq'.

  # View all users in JSON format.
  sudo ./user.sh --view users --json

  # Get a security report in JSON and pretty-print it with jq.
  sudo ./user.sh --report security --json | jq

========================================
EOF
}

# =================================================================================================
# FUNCTION: show_roles_help
# DESCRIPTION:
#   Explains the role-based provisioning feature (--apply-roles). It details the
#   JSON file structure for defining roles and assigning them to users, providing
#   a clear workflow for standardizing user configurations.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   None
# =================================================================================================
show_roles_help() {
    cat <<'EOF'
========================================
Help: Role-Based Provisioning
========================================

OVERVIEW:
  The --apply-roles operation allows you to define standardized user configurations
  (roles) and apply them to users. This is perfect for ensuring consistency and
  simplifying user onboarding and management.

USAGE:
  sudo ./user.sh --apply-roles <roles.json>

FILE STRUCTURE:
  The JSON file must contain a "roles" object and an "assignments" array.

  {
    "roles": {
      "developer": {
        "groups": ["developers", "git", "docker"],
        "shell": "/bin/bash",
        "sudo": "yes",
        "description": "Standard developer role"
      },
      "analyst": {
        "groups": ["analysts", "readonly"],
        "shell": "/bin/bash",
        "description": "Standard analyst role"
      }
    },
    "assignments": [
      { "username": "alice", "role": "developer" },
      { "username": "bob", "role": "analyst" }
    ]
  }

WORKFLOW:
  1. Define roles with desired attributes (groups, shell, sudo access, etc.).
  2. Assign roles to users in the "assignments" section.
  3. Run the script with --apply-roles.
     - If a user does not exist, they will be created with the specified role.
     - If a user exists, their account will be updated to match the role definition.

BENEFITS:
  - Enforces consistent configurations for different user types.
  - Simplifies onboarding new team members.
  - Provides a self-documenting source of truth for user permissions.

EXAMPLE TEMPLATE:
  See 'scripts/examples/roles_example.json' for a sample file.

========================================
EOF
}

# =================================================================================================
# FUNCTION: show_config_help
# DESCRIPTION:
#   Details the script's configuration file, including its location and key settings.
#   It helps administrators customize the script's default behavior, such as log paths,
#   password policies, and validation rules.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   None
# =================================================================================================
show_config_help() {
    cat <<'EOF'
========================================
Help: Configuration Guide
========================================

LOCATION:
  /etc/user-automation/config.conf

This file controls the default behavior and settings of the script.

KEY SETTINGS:

  LOG_FILE="/var/log/user-automation.log"
  # Path to the main log file.

  CACHE_DIR="/var/cache/user-automation"
  # Directory to store cached user and group data for faster --view operations.

  CACHE_TTL=3600
  # Time-to-live for cache files in seconds (e.g., 3600 = 1 hour).

  DEFAULT_SHELL="/bin/bash"
  # Default shell for new users if not specified.

  MIN_USER_UID=1000
  # Minimum UID for regular users.

  PASSWORD_EXPIRY_DAYS=90
  # Default password expiry for new users.

  USE_ICONS="true"
  # Set to "false" to disable icons for terminals that don't support them.

VALIDATION:
  The configuration is loaded at runtime. If the file or critical settings
  are missing, the script will fall back to default values and issue a warning.

========================================
EOF
}

# =================================================================================================
# FUNCTION: show_view_help
# DESCRIPTION:
#   Provides a detailed guide to the --view operation, covering all available targets
#   (users, groups, system) and options for filtering, sorting, pagination, and
#   output formatting. It places special emphasis on the powerful --where clause.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   None
# =================================================================================================
show_view_help() {
    cat <<'EOF'
========================================
Help: --view
========================================

Displays detailed information about users, groups, and system resources.
This command is read-only and does not make any changes to the system.

USAGE:
  sudo ./user.sh --view <TARGET> [OPTIONS]

TARGETS:
  users                View a list of all users.
  groups               View a list of all groups.
  user <name>          View detailed information for a single user.
  group <name>         View detailed information for a single group.
  system               View a summary of system user and group statistics.
  validate             Run validation checks on user/group configurations.

----------------------------------------
QUERYING WITH --where
----------------------------------------
The --where option provides a powerful way to filter results using logical expressions.

  --where "EXPRESSION"

EXPRESSION SYNTAX:
  - Comparisons: =, !=, >, <, >=, <=
  - Pattern Matching: LIKE (wildcard), MATCHES (regex)
  - Logical Operators: AND, OR, NOT
  - Parentheses for grouping: ( )

AVAILABLE FIELDS for 'users':
  username, uid, gid, comment, home, shell, status, last_login, home_size,
  password_status, password_expiry_date, is_sudoer

AVAILABLE FIELDS for 'groups':
  groupname, gid, member_count, members

EXAMPLES:

  # View users who are locked OR have an expired password.
  sudo ./user.sh --view users --where "status = 'locked' OR password_status = 'expired'"

  # View users with a UID greater than 2000 AND who are sudoers.
  sudo ./user.sh --view users --where "uid > 2000 AND is_sudoer = 'true'"

  # View groups with 'admin' in the name and more than 5 members.
  sudo ./user.sh --view groups --where "groupname LIKE '%admin%' AND member_count > 5"

----------------------------------------
OTHER OPTIONS
----------------------------------------
  --sort <field>       Sort results by a specific field (e.g., 'uid', 'home_size').
  --limit <n>          Limit the number of results returned.
  --skip <n>           Skip the first 'n' results for pagination.
  --columns <list>     Specify which columns to display (e.g., 'username,uid,shell').
  --json               Output results in JSON format.
  --no-cache           Bypass the cache and fetch live data.

CACHING:
  To improve performance, --view operations use a cache. Data is refreshed
  automatically based on the CACHE_TTL setting in the config file.
  Use --no-cache to force a refresh and get live, real-time data.

========================================
EOF
}

# =================================================================================================
# FUNCTION: show_view_validate_help
# DESCRIPTION:
#   Explains the --view validate command, which runs a series of diagnostic checks
#   to identify potential inconsistencies in the system's user and group configurations,
#   such as orphaned users or groups.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   None
# =================================================================================================
show_view_validate_help() {
    cat <<'EOF'
========================================
Help: --view validate
========================================

Runs a series of checks to find inconsistencies and potential problems
in the user and group configuration of the system.

USAGE:
  sudo ./user.sh --view validate [OPTIONS]

OPTIONS:
  --json         Output the validation report in JSON format.

DESCRIPTION:
  This command helps administrators identify common configuration issues, such as:
  - Users whose primary group does not exist.
  - Users with a login shell that is not listed in /etc/shells.
  - Users with a home directory that does not exist or has incorrect permissions.
  - Groups containing members that are not valid users.
  - Duplicate User IDs (UIDs) or Group IDs (GIDs).

EXAMPLE:
  # Run the validation checks and display a human-readable report.
  sudo ./user.sh --view validate

========================================
EOF
}

# =================================================================================================
# FUNCTION: show_compliance_help
# DESCRIPTION:
#   Details the --compliance operation, which runs automated security and
#   consistency checks against a predefined set of rules. It outlines the specific
#   checks performed for both users and groups.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   None
# =================================================================================================
show_compliance_help() {
    cat <<'EOF'
========================================
Help: --compliance
========================================

Runs automated checks to validate system users and groups against a
predefined set of security and consistency rules.

USAGE:
  sudo ./user.sh --compliance [OPTIONS]

OPTIONS:
  --json         Output the compliance report in JSON format.

DESCRIPTION:
  This command scans all regular users and groups, reporting any violations
  found. It is useful for periodic security audits and maintaining system health.

CHECKS PERFORMED:
  Users:
    - Password Expiry: Ensures passwords expire within the configured policy (e.g., 90 days).
    - Account Expiry: Checks for user accounts that have already expired.
    - Inactive Accounts: Flags users who have not logged in recently.
    - Sudo Password Policy: Enforces a stricter password expiry for sudo users.
    - Invalid Shell: Verifies that user shells are valid and secure.

  Groups:
    - Empty Groups: Identifies groups with no members.
    - Orphaned Groups: Finds groups that are not a primary group for any user.

EXAMPLE:
  # Run all compliance checks and view the report.
  sudo ./user.sh --compliance

========================================
EOF
}

show_add_help() {
    cat <<'EOF'
========================================
Help: --add user | group
========================================

Adds new users or groups to the system.

----------------------------------------
ADD USER
----------------------------------------

USAGE:
  sudo ./user.sh --add user --file <file>

The file can be a simple text file with one username per line, or a JSON
file for more complex scenarios. The script automatically detects the file
type.

TEXT FILE FORMAT:
  A simple text file with one username per line. Comments starting with #
  are ignored.

  # This is a comment
  user1
  user2

JSON FILE FORMAT:
{
  "users": [
    {
      "username": "alice",
      "comment": "Alice Smith, Developer",
      "groups": ["developers", "sudo"],
      "shell": "/bin/bash",
      "password_policy": { "type": "random" }
    }
  ]
}

----------------------------------------
ADD GROUP
----------------------------------------

USAGE:
  sudo ./user.sh --add group --file <file>

The file can be a simple text file with one group name per line, or a
JSON file.

JSON FILE FORMAT:
{
  "groups": [
    {
      "name": "developers",
      "gid": 2000,
      "members": ["alice", "bob"]
    }
  ]
}

========================================
EOF
}

# =================================================================================================
# FUNCTION: show_specific_help
# DESCRIPTION:
#   Acts as a router, calling the appropriate help function based on the topic
#   provided by the user. It handles various aliases (e.g., 'role', 'roles') and
#   defaults to the general help message for unknown topics.
#
# PARAMETERS:
#   $1 - topic: The help topic requested by the user (e.g., 'add', 'view').
#
# RETURNS:
#   None
# =================================================================================================
show_specific_help() {
    local topic="$1"
    case "$topic" in
        json)
            show_json_help
            ;;
        roles|role|apply-roles)
            show_roles_help
            ;;
        config|configuration)
            show_config_help
            ;;
        view)
            show_view_help
            ;;
        view-validate)
            show_view_validate_help
            ;;
        compliance)
            show_compliance_help
            ;;
        add|add-*)
            show_add_help
            ;;
        delete|delete-*)
            cat <<'EOF'
========================================
Help: --delete user | group
========================================

Deletes users or groups from the system.

----------------------------------------
DELETE USER
----------------------------------------

USAGE:
  sudo ./user.sh --delete user --name <username> [OPTIONS]
  sudo ./user.sh --delete user --names <file.txt>
  sudo ./user.sh --delete user --input <file.json>

OPTIONS:
  --backup             Create a backup of the user's home directory before deletion.
  --force              Attempt to delete the user even if they are logged in.
  --remove-home        Delete the user's home directory and mail spool.

JSON FILE FORMAT (--input):
{
  "deletions": [
    {
      "username": "unwanted_user",
      "backup": true,
      "remove_home": true
    }
  ]
}

----------------------------------------
DELETE GROUP
----------------------------------------

USAGE:
  sudo ./user.sh --delete group --name <groupname>
  sudo ./user.sh --delete group --names <file.txt>

NOTE: By default, groups are not deleted if they are the primary group for any user.
System groups (GID < 1000) are protected from deletion.

========================================
EOF
            ;;
        lock|lock-user)
            cat <<'EOF'
========================================
Help: --lock
========================================

Locks a user account, preventing them from logging in.

USAGE:
  sudo ./user.sh --lock --name <username> [OPTIONS]
  sudo ./user.sh --lock --names <file.txt>
  sudo ./user.sh --lock --input <file.json>

OPTIONS:
  --reason <text>      Record a reason for the lock in the audit log.
  --unlock-after <T>   Schedule an automatic unlock after a duration (e.g., '1h', '30m').

JSON FILE FORMAT (--input):
{
  "locks": [
    {
      "username": "alice",
      "reason": "Account compromised.",
      "unlock_after": "24h"
    }
  ]
}

========================================
EOF
            ;;
        unlock|unlock-user)
            cat <<'EOF'
========================================
Help: --unlock
========================================

Unlocks a user account, re-enabling login access.

USAGE:
  sudo ./user.sh --unlock --name <username>
  sudo ./user.sh --unlock --names <file.txt>
  sudo ./user.sh --unlock --input <file.json>

JSON FILE FORMAT (--input):
{
  "unlocks": [
    { "username": "alice" },
    { "username": "bob" }
  ]
}

========================================
EOF
            ;;
        *)
            show_general_help
            ;;
    esac
}