#!/usr/bin/env bash
# ================================================
# Help System Module - REFACTORED
# Version: 2.0.0
# ================================================

show_general_help() {
    cat <<'EOF'
========================================
User and Group Management Script
========================================

USAGE:
  sudo ./main.sh [OPERATION] [ACTION] [OPTIONS]

OPERATIONS:
  --add          Add users or groups
  --update       Update users or groups
  --delete       Delete users or groups
  --lock         Lock a user account
  --unlock       Unlock a user account
  --view         View users, groups, or system details
  --search       Search for users or groups
  --report       Generate audit and activity reports
  --export       Export user and group data
  --apply-roles  Apply role-based configurations from a JSON file
  --help         Show this help message or help for a specific topic

ACTIONS (for --add, --delete, --update):
  user           Target a single user
  group          Target a single group

INPUTS:
  --name <name>       Specify a single user or group name.
  --names <file>      Provide a text file containing a list of names.
  --input <file.json> Provide a JSON file for bulk operations.

COMMON OPTIONS:
  --dry-run      Simulate the operation without making any changes.
  --format <fmt> Specify the input format (text, json). Auto-detected by default.
  --json         Output results in JSON format (for --view, --search, --report).

EXAMPLES:
  # Add users from a text file
  sudo ./main.sh --add user --names users.txt

  # Add groups from a JSON file
  sudo ./main.sh --add group --input groups.json

  # Delete a single user interactively
  sudo ./main.sh --delete user --name alice

  # Lock a user with a reason
  sudo ./main.sh --lock --name bob --reason "Security review"

  # View all users in JSON format
  sudo ./main.sh --view users --json

  # Generate a security report
  sudo ./main.sh --report security

DETAILED HELP:
  ./main.sh --help add
  ./main.sh --help delete
  ./main.sh --help lock
  ./main.sh --help view
  ./main.sh --help json
  ./main.sh --help roles

CONFIG: /opt/admin_dashboard/config/user_mgmt.conf
LOG: /var/log/user_mgmt.log
========================================
EOF
}

show_json_help() {
    cat <<'EOF'
========================================
JSON Operations Help
========================================

JSON is supported for both input (bulk operations) and output (viewing data).

----------------------------------------
JSON INPUT (--input <file>)
----------------------------------------
Use a JSON file to add or delete users and groups in bulk.

  # Add users from a JSON file
  sudo ./main.sh --add user --input users.json

  # Add groups from a JSON file
  sudo ./main.sh --add group --input groups.json

  # Delete groups from a JSON file
  sudo ./main.sh --delete group --input groups_to_delete.json

JSON FILE FORMATS:

  groups.json (for adding groups):
  {
    "groups": [
      {
        "name": "developers",
        "action": "create",
        "members": ["alice", "bob"]
      },
      {
        "name": "testers",
        "action": "create"
      }
    ]
  }

  groups_to_delete.json (for deleting groups):
  {
    "groups": [
      { "name": "old_project", "action": "delete" },
      { "name": "temp_team", "action": "delete" }
    ]
  }

  (See './main.sh --help add' and './main.sh --help delete' for more examples)

----------------------------------------
JSON OUTPUT (--json)
----------------------------------------
Get machine-readable output for viewing, searching, and reporting.

  # View all users in JSON
  sudo ./main.sh --view users --json

  # Search for users with 'dev' in their name
  sudo ./main.sh --search users --pattern "dev" --json

  # Get a security report in JSON
  sudo ./main.sh --report security --json | jq

========================================
EOF
}

show_roles_help() {
    cat <<'EOF'
========================================
Help: Role-Based Provisioning
========================================

OVERVIEW:
  Define roles with specific permissions (groups, shell, etc.) and assign them
  to users. This is ideal for standardizing user setups.

USAGE:
  sudo ./main.sh --apply-roles <roles.json>

FILE STRUCTURE:
{
  "roles": {
    "developer": {
      "groups": ["developers", "git", "docker"],
      "shell": "/bin/bash",
      "password_expiry_days": 90,
      "description": "For software developers"
    }
  },
  "assignments": [
    {"username": "alice", "role": "developer"},
    {"username": "new_dev", "role": "developer"}
  ]
}

WORKFLOW:
  1. Define your roles and assignments in a JSON file.
  2. If a user in 'assignments' does not exist, they will be created.
  3. If a user exists, their account will be updated to match the role settings.

  sudo ./main.sh --apply-roles roles.json

BENEFITS:
  - Ensures consistent permissions for users in the same role.
  - Simplifies onboarding and permission updates.
  - Provides a clear, self-documenting source of truth for user roles.

TEMPLATE:
  See: scripts/examples/roles.json

========================================
EOF
}

show_config_help() {
    cat <<'EOF'
========================================
Help: Configuration Guide
========================================

LOCATION:
  /opt/admin_dashboard/config/user_mgmt.conf

This file controls default behaviors of the script.

KEY SETTINGS:

  PASSWORD_LENGTH=16
  # Length of auto-generated random passwords.

  LOG_FILE="/var/log/user_mgmt.log"
  # Path to the main audit log file.

  BACKUP_DIR="/var/backups/users"
  # Default directory for user deletion backups.

  DEFAULT_SHELL="/bin/bash"
  # Default shell for new users if not specified.

  USE_UNICODE="yes"
  # Use 'yes' for modern terminals, 'no' for basic SSH/TTY.

VALIDATION:
  The configuration is validated on every run. If critical errors are
  found, the script will exit. Fix the errors and run again.

========================================
EOF
}

show_view_help() {
    cat <<'EOF'
========================================
Help: --view
========================================

Displays detailed information about users, groups, and system resources.

USAGE:
  sudo ./main.sh --view <TARGET> [OPTIONS]

TARGETS:
  users          View a list of users.
  groups         View a list of groups.
  user <name>    View detailed information for a single user.
  group <name>   View detailed information for a single group.
  system         View a summary of system user and group statistics.

OPTIONS FOR `users` and `groups`:

  --filter <f>   Filter results. Examples:
                 - users: 'active', 'locked', 'sudo', 'inactive:90' (days)
                 - groups: 'empty', 'large'
  --search <p>   Search by name with a pattern (e.g., 'dev*').
  --sort <by>    Sort results. 
                 - users: 'username', 'uid', 'home-size'
                 - groups: 'groupname', 'gid', 'member-count'
  --limit <n>    Limit the number of results.
  --skip <n>     Skip a number of results for pagination.
  --columns <c>  Comma-separated list of columns to display.
  --json         Output in JSON format.

EXAMPLES:

  # View all active users with sudo access
  sudo ./main.sh --view users --filter 'active,sudo'

  # View top 5 largest home directories
  sudo ./main.sh --view users --sort 'home-size' --limit 5

  # View details for a specific user
  sudo ./main.sh --view user alice

  # View all empty groups in JSON format
  sudo ./main.sh --view groups --filter 'empty' --json

  # View a detailed system summary
  sudo ./main.sh --view system --detailed

========================================
EOF
}


# ---
# Function: show_compliance_help()
# Description: Displays detailed help for the --compliance operation.
# ---
show_compliance_help() {
    echo "Usage: user.sh --compliance"
    echo ""
    echo "The --compliance operation runs a series of automated checks to validate"
    echo "system users and groups against a predefined set of security and"
    echo "consistency rules."
    echo ""
    echo "Description:"
    echo "  This command scans all regular users and groups, reporting any"
    echo "  violations found. It is useful for periodic security audits and"
    echo "  maintaining system health."
    echo ""
    echo "Checks Performed:"
    echo "  Users:"
    echo "    - Password Expiry: Ensures passwords expire within 90 days."
    echo "    - Account Expiry: Checks for expired user accounts."
    echo "    - Inactive Accounts: Flags users inactive for over 90 days."
    echo "    - Sudo Password Policy: Enforces a 30-day password expiry for sudo users."
    echo "    - Service Account Shell: Verifies service accounts have a non-login shell."
    echo ""
    echo "  Groups:"
    echo "    - Empty Groups: Identifies groups with no members that are not a primary group for any user."
    echo "    - Orphaned Primary Groups: Checks for groups assigned as a primary group to non-existent users."
    echo ""
    echo "Examples:"
    echo "  Run all compliance checks:"
    echo "    sudo ./user.sh --compliance"
    echo ""
}


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
        view|view-*)
            show_view_help
            ;;
        compliance) 
            show_compliance_help 
            ;;
        add|add-*)
            cat <<'EOF'
========================================
Help: --add user | group
========================================

Adds new users or groups to the system.

----------------------------------------
ADD USER
----------------------------------------

USAGE:
  sudo ./main.sh --add user --name <username> [OPTIONS]
  sudo ./main.sh --add user --names <file.txt>
  sudo ./main.sh --add user --input <file.json>

OPTIONS:
  --comment <text>     Set the user's full name or description.
  --groups <list>      Comma-separated list of groups to join.
  --shell <path>       Specify the user's login shell.
  --password <pass>    Set a specific password. Use 'random' for auto-generation.

TEXT FILE FORMAT (--names):
  Each line contains one username.

JSON FILE FORMAT (--input):
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
  sudo ./main.sh --add group --name <groupname>
  sudo ./main.sh --add group --names <file.txt>
  sudo ./main.sh --add group --input <file.json>

TEXT FILE FORMAT (--names):
  Each line contains one group name.

JSON FILE FORMAT (--input):
{
  "groups": [
    {
      "name": "developers",
      "action": "create",
      "members": ["alice", "bob"] // Members must exist
    }
  ]
}

========================================
EOF
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
  sudo ./main.sh --delete user --name <username> [MODE]
  sudo ./main.sh --delete user --names <file.txt>
  sudo ./main.sh --delete user --input <file.json>

MODES (for single user deletion):
  --check        Perform a dry-run and show potential issues.
  --interactive  Prompt for confirmation before each destructive action.
  --auto         Delete automatically (default for file-based deletion).
  --force        Attempt to delete even if warnings are present.

JSON FILE FORMAT (--input):
{
  "deletions": [
    {
      "username": "unwanted_user",
      "backup": true,
      "delete_home": true
    }
  ]
}

----------------------------------------
DELETE GROUP
----------------------------------------

USAGE:
  sudo ./main.sh --delete group --name <groupname>
  sudo ./main.sh --delete group --names <file.txt>
  sudo ./main.sh --delete group --input <file.json>

NOTE: By default, groups are deleted automatically. System groups (GID < 1000)
and groups that are the primary group for any user cannot be deleted.

JSON FILE FORMAT (--input):
{
  "groups": [
    { "name": "old_project", "action": "delete" },
    { "name": "temp_team", "action": "delete" }
  ]
}

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
  sudo ./main.sh --lock --name <username> [OPTIONS]
  sudo ./main.sh --lock --input <file.json>

OPTIONS:
  --reason <text>  Record a reason for the lock in the audit log.

JSON FILE FORMAT (--input):
{
  "users": [
    {
      "username": "alice",
      "reason": "Account compromised."
    },
    { "username": "bob" }
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

Unlocks a user account, allowing them to log in again.

USAGE:
  sudo ./main.sh --unlock --name <username>
  sudo ./main.sh --unlock --input <file.json>

JSON FILE FORMAT (--input):
{
  "users": [
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