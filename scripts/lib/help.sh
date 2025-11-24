#!/usr/bin/env bash
# ================================================
# Help System Module - ENHANCED
# Version: 1.0.2
# ================================================

show_general_help() {
    cat <<'EOF'
========================================
EC2 User Management Script
========================================

USAGE:
  sudo ./user.sh [OPERATION] [TARGET] [OPTIONS]

OPERATIONS:
  --add          Add users or groups
  --update       Update users or groups
  --delete       Delete users or groups
  --lock         Lock user account
  --unlock       Unlock user account
  --view         View users, groups, or details
  --search       Search users or groups
  --report       Generate audit reports
  --export       Export data to file
  --apply-roles  Apply roles from JSON file (see: --help roles)
  --manage-groups Manage groups from JSON file (see: --help groups-json)
  --help         Show help

TARGETS:
  user           User accounts
  group          Groups
  user-group     Add users to groups
  users          All users (for --view/--export)
  groups         All groups (for --view/--export)
  user-groups    User's groups (for --view)
  summary        System summary (for --view)
  recent-logins  Recent login history (for --view)
  all            Complete system state (for --export)

COMMON OPTIONS:
  --names <file>              File with data (text format)
  --input <file>              Input file (use with --format json)
  --format <fmt>              Input format: text, json
  --name <username|groupname> Single user or group
  --dry-run                   Test mode, no changes
  --password random           Generate unique random passwords
  --json                      Output in JSON format (for --view/--search/--report)

EXAMPLES:
  sudo ./user.sh --add user --names users.txt
  sudo ./user.sh --add user --input users.json --format json
  sudo ./user.sh --apply-roles roles.json
  sudo ./user.sh --manage-groups groups.json
  sudo ./user.sh --delete user --name alice --check
  sudo ./user.sh --view users
  sudo ./user.sh --view users --json
  sudo ./user.sh --view recent-logins --hours 48
  sudo ./user.sh --lock user --name bob
  sudo ./user.sh --report security
  sudo ./user.sh --report security --json
  sudo ./user.sh --export users --output users.csv --format csv
  sudo ./user.sh --search users --pattern "dev" --json

DETAILED HELP:
  ./user.sh --help add
  ./user.sh --help delete
  ./user.sh --help update
  ./user.sh --help view
  ./user.sh --help report
  ./user.sh --help export
  ./user.sh --help json
  ./user.sh --help roles        # Role-based provisioning
  ./user.sh --help groups-json  # JSON group management
  ./user.sh --help config       # Configuration guide

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

JSON OUTPUT (--json):
  Add --json to get machine-readable output
  
  sudo ./user.sh --view users --json
  sudo ./user.sh --report security --json
  sudo ./user.sh --search users --status sudo --json

JSON INPUT (--input <file> --format json):
  Bulk operations from JSON files
  
  sudo ./user.sh --add user --input users.json --format json
  sudo ./user.sh --apply-roles roles.json
  sudo ./user.sh --manage-groups groups.json

JSON FILE FORMATS:

users.json:
{
  "users": [
    {
      "username": "alice",
      "comment": "Alice Smith",
      "groups": ["developers", "sudo"],
      "shell": "/bin/bash",
      "expire_days": 365,
      "password_policy": {
        "type": "random",
        "expiry_days": 90
      }
    }
  ]
}

roles.json:
{
  "roles": {
    "developer": {
      "groups": ["developers", "git"],
      "shell": "/bin/bash",
      "password_expiry_days": 90
    }
  },
  "assignments": [
    {"username": "alice", "role": "developer"}
  ]
}

groups.json:
{
  "groups": [
    {
      "name": "developers",
      "action": "create",
      "members": ["alice", "bob"]
    }
  ]
}

deletions.json:
{
  "deletions": [
    {
      "username": "alice",
      "backup": true,
      "delete_home": true
    }
  ],
  "options": {
    "backup_dir": "/var/backups/users"
  }
}

========================================
EOF
}

show_roles_help() {
    cat <<'EOF'
========================================
Help: Role-Based Provisioning
========================================

OVERVIEW:
  Define roles once, assign them to multiple users.
  Perfect for standardizing permissions across teams.

USAGE:
  sudo ./user.sh --apply-roles <roles.json>

FILE STRUCTURE:
{
  "roles": {
    "role_name": {
      "groups": ["group1", "group2"],
      "shell": "/bin/bash",
      "password_expiry_days": 90,
      "description": "Role description"
    }
  },
  "assignments": [
    {"username": "alice", "role": "role_name"}
  ]
}

WORKFLOW:
  1. Create groups first (if needed):
     sudo ./user.sh --add group --names groups.txt
  
  2. Define roles in roles.json
  
  3. Apply roles:
     sudo ./user.sh --apply-roles roles.json
  
  4. Users are created if they don't exist
  5. Existing users are updated with role settings

EXAMPLES:

Developer Role:
{
  "developer": {
    "groups": ["developers", "git", "docker"],
    "shell": "/bin/bash",
    "password_expiry_days": 90,
    "description": "Software developers"
  }
}

DevOps Role:
{
  "devops": {
    "groups": ["developers", "deploy", "sudo", "docker"],
    "shell": "/bin/bash",
    "password_expiry_days": 30,
    "description": "DevOps engineers"
  }
}

Service Account:
{
  "service_account": {
    "groups": ["services"],
    "shell": "/sbin/nologin",
    "password_expiry_days": 99999,
    "description": "Application service accounts"
  }
}

BENEFITS:
  - Consistent permissions across users
  - Easy to update entire role at once
  - Self-documenting (role descriptions)
  - Reduces errors from manual setup

TEMPLATE:
  See: /opt/admin_dashboard/scripts/examples/roles.json

========================================
EOF
}

show_groups_json_help() {
    cat <<'EOF'
========================================
Help: JSON Group Management
========================================

OVERVIEW:
  Create or delete groups with members in bulk.
  Perfect for project setup or reorganization.

USAGE:
  sudo ./user.sh --manage-groups <groups.json>

FILE STRUCTURE:
{
  "groups": [
    {
      "name": "groupname",
      "action": "create",
      "members": ["user1", "user2"]
    },
    {
      "name": "old_group",
      "action": "delete"
    }
  ]
}

ACTIONS:

CREATE GROUP:
  Creates group and adds members (members must already exist)
  
  {
    "name": "developers",
    "action": "create",
    "members": ["alice", "bob", "charlie"]
  }

CREATE EMPTY GROUP:
  Creates group without members
  
  {
    "name": "new_team",
    "action": "create",
    "members": []
  }

DELETE GROUP:
  Removes group (cannot be used as primary group)
  
  {
    "name": "old_project",
    "action": "delete"
  }

WORKFLOW:
  1. Create groups.json with desired structure
  2. Run: sudo ./user.sh --manage-groups groups.json
  3. Groups are created/deleted in order
  4. Verify: sudo ./user.sh --view groups

EXAMPLE - PROJECT SETUP:
{
  "groups": [
    {
      "name": "backend_team",
      "action": "create",
      "members": ["alice", "bob"]
    },
    {
      "name": "frontend_team",
      "action": "create",
      "members": ["charlie", "diana"]
    },
    {
      "name": "deploy",
      "action": "create",
      "members": ["alice", "charlie"]
    }
  ]
}

RESTRICTIONS:
  - Cannot delete system groups (GID < 1000)
  - Cannot delete groups used as primary group
  - Members must exist before adding to group
  - Groups must exist before deleting

TEMPLATE:
  See: /opt/admin_dashboard/scripts/examples/groups.json

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

EDITING:
  sudo nano /opt/admin_dashboard/config/user_mgmt.conf

KEY SETTINGS:

PASSWORD SETTINGS:
  DEFAULT_PASSWORD="P@ssword1234!"    # Default password for new users
  PASSWORD_LENGTH=16                   # Length for random passwords
  PASSWORD_EXPIRY_DAYS=90             # Days until password must change
  PASSWORD_WARN_DAYS=7                # Warning before expiry

LOGGING:
  LOG_FILE="/var/log/user_mgmt.log"  # Audit log location
  DETAILED_LOGGING="yes"              # Enable verbose logging

BACKUP:
  BACKUP_DIR="/var/backups/users"     # User backup location
  BACKUP_RETENTION_DAYS=90            # Keep backups for N days

USER DEFAULTS:
  DEFAULT_SHELL="a"                   # a=allow, d=deny
  DEFAULT_ACCOUNT_EXPIRY=""           # Empty=never, N=days
  DEFAULT_SUDO="no"                   # Enable sudo by default

SYSTEM LIMITS:
  MAX_USERNAME_LENGTH=32              # Maximum username length
  MIN_USER_UID=1000                   # Regular user UID starts
  MAX_USER_UID=60000                  # Regular user UID ends
  MIN_GROUP_GID=1000                  # Regular group GID starts

DISPLAY:
  USE_UNICODE="yes"                   # Unicode icons (yes/no)
                                      # Set to "no" for ASCII-only

THRESHOLDS:
  INACTIVE_THRESHOLD_DAYS=90          # Flag inactive accounts

CONFIGURATION VALIDATION:
  Config is validated on every script run
  Errors will be shown and script will exit
  Warnings are logged but don't stop execution

CRITICAL SETTINGS TO CHANGE:
  1. DEFAULT_PASSWORD - CHANGE THIS!
     Use a strong, unique password
  
  2. USE_UNICODE - Set based on your terminal:
     - "yes" for modern terminals (macOS, Ubuntu Desktop)
     - "no" for SSH sessions, older terminals
  
  3. DEFAULT_SUDO - Security consideration:
     - "no" is safest (grant sudo explicitly)
     - "yes" only if all users are trusted

EXAMPLE - SECURE DEFAULTS:
  DEFAULT_PASSWORD="$(openssl rand -base64 16)"
  USE_UNICODE="no"
  DEFAULT_SUDO="no"
  PASSWORD_EXPIRY_DAYS=60
  INACTIVE_THRESHOLD_DAYS=30

VALIDATION ERRORS:
  If config has errors, you'll see:
  
  [X] Config Error: DEFAULT_PASSWORD not set
  [!] Config Warning: PASSWORD_LENGTH too short
  
  Fix errors in config file and run again

TEST CONFIG:
  sudo ./user.sh --view summary
  (Will validate config and show any issues)

========================================
EOF
}

show_recent_logins_help() {
    cat <<'EOF'
========================================
Help: Recent Logins Tracking
========================================

OVERVIEW:
  View login history for security auditing and user activity.

USAGE:
  sudo ./user.sh --view recent-logins [OPTIONS]

OPTIONS:
  --hours <N>        Show last N hours (default: 24)
  --days <N>         Show last N days
  --user <username>  Filter to specific user only
  --json             Output in JSON format

EXAMPLES:

Last 24 hours (default):
  sudo ./user.sh --view recent-logins

Last 48 hours:
  sudo ./user.sh --view recent-logins --hours 48

Last 7 days:
  sudo ./user.sh --view recent-logins --days 7

Specific user, last 30 days:
  sudo ./user.sh --view recent-logins --user alice --days 30

JSON output:
  sudo ./user.sh --view recent-logins --json | jq

OUTPUT FORMAT:

Table View:
USERNAME        TIME                 FROM                 DURATION
------------------------------------------------------------------------
ec2-user        2024-01-15 14:30     203.0.113.45        Active (0h 15m)
alice           2024-01-14 09:15     203.0.113.45        Logged out (2h 30m)

JSON View:
[
  {
    "username": "ec2-user",
    "tty": "pts/0",
    "from": "203.0.113.45",
    "login_time": "Mon Jan 15 14:30:00 2024",
    "status": "active",
    "duration_seconds": 900
  }
]

USE CASES:

Security Audit:
  sudo ./user.sh --view recent-logins --days 30
  (Check for unauthorized access)

User Activity Report:
  sudo ./user.sh --view recent-logins --user contractor --days 90
  (Verify contractor worked expected hours)

Failed Login Check:
  (See: sudo ./user.sh --report activity)
  (Includes failed login attempts)

Real-time Monitoring:
  watch -n 60 'sudo ./user.sh --view recent-logins --hours 1'
  (Refresh every minute)

NOTES:
  - Shows successful logins only
  - For failed logins, use: --report activity
  - Active sessions show current duration
  - Time shown in system timezone
  - Local logins show "local" as source

========================================
EOF
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
        groups-json|manage-groups)
            show_groups_json_help
            ;;
        config|configuration)
            show_config_help
            ;;
        recent-logins|logins)
            show_recent_logins_help
            ;;
        add|add-user)
            cat <<'EOF'
========================================
Help: Adding Users
========================================

USAGE:
  sudo ./user.sh --add user --names <file> [OPTIONS]
  sudo ./user.sh --add user --input <file.json> --format json [OPTIONS]

FILE FORMAT (users.txt):
  username:comment:expiry:shell:sudo:password
  
  Examples:
    alice:Alice Smith:90:a:yes:
    bob:Bob Jones::d:no:random
    charlie:::a::MyP@ss123

FILE FORMAT (users.json):
{
  "users": [
    {
      "username": "alice",
      "comment": "Alice Smith",
      "groups": ["developers", "sudo"],
      "shell": "/bin/bash",
      "expire_days": 365,
      "password_policy": {
        "type": "random",
        "expiry_days": 90
      }
    }
  ]
}

OPTIONS:
  --dry-run            Test without changes
  --expire <days>      Default expiration
  --shell <a|d>        Default shell
  --sudo               Grant sudo to all
  --password random    Generate random passwords for all users
  --password-expiry <days>

PASSWORD OPTIONS:
  - Leave blank = use default password
  - "random" = generate unique random password
  - Specific password = use that password

EXAMPLES:
  sudo ./user.sh --add user --names users.txt
  sudo ./user.sh --add user --input users.json --format json
  sudo ./user.sh --add user --names users.txt --password random
  sudo ./user.sh --add user --names users.txt --dry-run
  sudo ./user.sh --add user --names users.txt --sudo

========================================
EOF
            ;;
        delete|delete-user)
            cat <<'EOF'
========================================
Help: Deleting Users
========================================

DELETE MODES:
  --check              Check only (no changes)
  --interactive        Prompt for each step (default)
  --backup             Auto-backup and delete
  --force              Delete without prompts

USAGE:
  sudo ./user.sh --delete user --name <user> [MODE] [OPTIONS]

OPTIONS:
  --backup-dir <path>  Backup location
  --force-logout       Force user logout
  --kill-processes     Terminate processes
  --keep-home          Keep home directory

EXAMPLES:
  sudo ./user.sh --delete user --name alice --check
  sudo ./user.sh --delete user --name bob --interactive
  sudo ./user.sh --delete user --name charlie --backup \
    --backup-dir /backups --force-logout

========================================
EOF
            ;;
        update)
            cat <<'EOF'
========================================
Help: Updating Users
========================================

USER OPERATIONS:
  --reset-password            Reset password
  --shell <a|d|path>          Change shell
  --add-to-groups <groups>    Add to groups
  --remove-from-groups <grps> Remove from groups
  --expire <days|date|never>  Change expiration
  --comment <text>            Update comment
  --primary-group <group>     Change primary group

EXAMPLES:
  sudo ./user.sh --update user --name alice --reset-password
  sudo ./user.sh --update user --name bob --shell d
  sudo ./user.sh --update user --name charlie --add-to-groups "sudo,docker"
  sudo ./user.sh --update user --name dave --expire 90

========================================
EOF
            ;;
        view)
            cat <<'EOF'
========================================
Help: View Operations
========================================

TARGETS:
  users              All users
  groups             All groups
  user --name <n>    User details
  group --name <n>   Group details
  user-groups --name <n>
  summary            System summary
  recent-logins      Recent login history

FILTERS (for users/groups):
  --filter all|locked|active|sudo|empty

RECENT LOGINS OPTIONS:
  --hours <N>        Show last N hours (default: 24)
  --days <N>         Show last N days
  --user <username>  Show specific user only

JSON OUTPUT:
  Add --json flag to get JSON format output
  Works with all view and search operations

EXAMPLES:
  sudo ./user.sh --view users
  sudo ./user.sh --view users --filter locked
  sudo ./user.sh --view user --name alice
  sudo ./user.sh --view user --name alice --json
  sudo ./user.sh --view groups --filter empty
  sudo ./user.sh --view summary
  sudo ./user.sh --view summary --json
  
  # Recent logins
  sudo ./user.sh --view recent-logins
  sudo ./user.sh --view recent-logins --hours 48
  sudo ./user.sh --view recent-logins --days 7
  sudo ./user.sh --view recent-logins --user alice --days 30
  sudo ./user.sh --view recent-logins --json
  
  # JSON examples
  sudo ./user.sh --view users --json | jq
  sudo ./user.sh --view user --name alice --json | jq '.uid'
  sudo ./user.sh --search users --status sudo --json | jq '.[].username'

========================================
EOF
            ;;
        report)
            cat <<'EOF'
========================================
Help: Audit Reports
========================================

USAGE:
  sudo ./user.sh --report <type> [OPTIONS]

REPORT TYPES:

1. SECURITY AUDIT
   sudo ./user.sh --report security
   
   Shows:
   - Users with sudo access
   - Locked accounts
   - Expired passwords
   - Accounts without password expiry
   - Empty groups
   - System group members
   - Users without shell
   - Duplicate UIDs/GIDs

2. COMPLIANCE REPORT
   sudo ./user.sh --report compliance
   
   Shows:
   - Password policy compliance
   - Account expiration compliance
   - Inactive accounts (no login > 90 days)
   - Service accounts (nologin)
   - Privileged accounts

3. ACTIVITY REPORT
   sudo ./user.sh --report activity [--days N]
   
   Options:
   --days <number>  Look back N days (default: 30)
   
   Shows:
   - Login frequency
   - Most active users
   - Inactive users
   - Failed login attempts
   - Account modifications

4. STORAGE REPORT
   sudo ./user.sh --report storage
   
   Shows:
   - Home directory sizes
   - Top 10 largest users
   - Total storage by group
   - Orphaned files (no owner)
   - Large files (>100MB)

EXAMPLES:

  # Security audit
  sudo ./user.sh --report security
  
  # Compliance check
  sudo ./user.sh --report compliance
  
  # Activity last 7 days
  sudo ./user.sh --report activity --days 7
  
  # Activity last 90 days
  sudo ./user.sh --report activity --days 90
  
  # Storage usage
  sudo ./user.sh --report storage

OUTPUT:
  Reports are formatted for terminal display
  Can be redirected to file:
    sudo ./user.sh --report security > security_audit.txt

USE CASES:
  - Weekly security audits
  - Compliance verification
  - Identify inactive accounts for cleanup
  - Storage capacity planning
  - Failed login monitoring

========================================
EOF
            ;;
        export)
            cat <<'EOF'
========================================
Help: Export Data
========================================

USAGE:
  sudo ./user.sh --export <type> --output <file> [--format <fmt>]

EXPORT TYPES:

1. USERS
   sudo ./user.sh --export users --output users.csv --format csv
   
2. GROUPS
   sudo ./user.sh --export groups --output groups.json --format json
   
3. ALL (Complete System State)
   sudo ./user.sh --export all --output system.json --format json

FORMATS:

- csv    Comma-separated values
- json   JSON format
- table  Pretty table (default)
- tsv    Tab-separated values

Note: 'all' export only supports JSON format

EXAMPLES:

  # Export users to CSV
  sudo ./user.sh --export users --output users.csv --format csv
  
  # Export groups to JSON
  sudo ./user.sh --export groups --output groups.json --format json
  
  # Export complete system state
  sudo ./user.sh --export all --output system_$(date +%Y%m%d).json --format json
  
  # Export users as table (default)
  sudo ./user.sh --export users --output users.txt
  
  # Export groups as TSV
  sudo ./user.sh --export groups --output groups.tsv --format tsv

USE CASES:
  - Backup user/group configuration
  - Import to spreadsheets
  - Compliance documentation
  - System migration
  - Integration with other tools

========================================
EOF
            ;;
        *)
            show_general_help
            ;;
    esac
}