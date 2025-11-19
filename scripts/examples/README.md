# JSON Templates - Examples & Documentation

This directory contains ready-to-use JSON templates for bulk user and group management operations.

---

## 📁 Available Templates

| Template | Purpose | Usage |
|----------|---------|-------|
| **users.json** | Bulk user creation | Create multiple users at once with custom settings |
| **roles.json** | Role-based provisioning | Define roles once, assign to many users |
| **groups.json** | Group management | Create/delete groups and manage memberships |
| **deletions.json** | Batch deletions | Safely delete multiple users with backup |

---

## 🚀 Quick Start

### 1. Copy Template
```bash
cd /opt/admin_dashboard/scripts
cp examples/users.json my_users.json
```

### 2. Edit Template
```bash
nano my_users.json
# Modify usernames, groups, settings
```

### 3. Test First (Dry-Run)
```bash
# Always test with dry-run first!
sudo ./user.sh --add user --input my_users.json --dry-run
```

### 4. Execute
```bash
sudo ./user.sh --add user --input my_users.json --format json
```

---

## 📖 Template Details

### 1️⃣ users.json - Bulk User Creation

**Use When:**
- Onboarding multiple new employees
- Setting up project team members
- Creating service accounts
- Migrating users from another system

**Features:**
- Custom password per user (random or default)
- Multiple group memberships
- Account expiration dates
- Shell customization
- Password expiry policies

**Example Command:**
```bash
sudo ./user.sh --add user --input users.json --format json
```

**Sample Entry:**
```json
{
  "username": "alice",
  "comment": "Alice Johnson - Developer",
  "groups": ["developers", "git", "docker"],
  "shell": "/bin/bash",
  "expire_days": 365,
  "password_policy": {
    "type": "random",
    "expiry_days": 90
  }
}
```

---

### 2️⃣ roles.json - Role-Based Provisioning

**Use When:**
- Your organization has standard roles (developer, tester, manager)
- Need consistency across user configurations
- Want to easily update role permissions
- Managing large teams with similar access needs

**Features:**
- Define roles once, use many times
- Consistent permissions across role members
- Easy to update entire role at once
- Self-documenting (role descriptions)

**Example Command:**
```bash
sudo ./user.sh --apply-roles roles.json
```

**How It Works:**
1. Define roles in `roles` section with groups, shell, password policy
2. Assign users to roles in `assignments` section
3. Script creates users if they don't exist
4. Script applies role settings to all assigned users

**Sample Role:**
```json
"developer": {
  "groups": ["developers", "git", "docker"],
  "shell": "/bin/bash",
  "password_expiry_days": 90,
  "description": "Software developers"
}
```

**Sample Assignment:**
```json
{
  "username": "alice",
  "role": "developer"
}
```

---

### 3️⃣ groups.json - Group Management

**Use When:**
- Setting up new project teams
- Reorganizing group structure
- Cleaning up old groups
- Migrating from another system

**Features:**
- Create groups with members in one operation
- Delete obsolete groups
- Document group purposes
- Batch operations

**Example Command:**
```bash
sudo ./user.sh --manage-groups groups.json
```

**Operations:**

**Create Group:**
```json
{
  "name": "developers",
  "action": "create",
  "members": ["alice", "bob", "charlie"]
}
```

**Delete Group:**
```json
{
  "name": "old_team",
  "action": "delete"
}
```

---

### 4️⃣ deletions.json - Batch Deletions

**Use When:**
- Offboarding contractors/interns after project ends
- Removing test accounts
- Employee departures
- Security incidents (compromised accounts)
- Periodic cleanup of unused accounts

**Features:**
- Automatic backup creation
- Selective home directory preservation
- Reason documentation
- Batch processing

**⚠️ WARNING:** This is a destructive operation! Always:
1. Lock accounts first
2. Wait 24-48 hours
3. Run `--check` mode first
4. Always enable backups for production users

**Example Command:**
```bash
# Step 1: Check what will happen
sudo ./user.sh --delete user --name testuser --check

# Step 2: Run batch deletion
sudo ./user.sh --delete user --input deletions.json --format json
```

**Sample Entry:**
```json
{
  "username": "contractor1",
  "backup": true,
  "delete_home": true,
  "reason": "Contract ended"
}
```

---

## 🎯 Common Workflows

### New Employee Onboarding
```bash
# 1. Create groups if needed
sudo ./user.sh --manage-groups groups.json

# 2. Create users with roles
sudo ./user.sh --apply-roles roles.json

# 3. Verify
sudo ./user.sh --view users
```

### Project Team Setup
```bash
# 1. Define project team in users.json
# 2. Create all team members
sudo ./user.sh --add user --input project_team.json --format json

# 3. Verify group memberships
sudo ./user.sh --view group --name project_alpha
```

### Contractor Offboarding
```bash
# 1. Lock accounts immediately
sudo ./user.sh --lock user --name contractor1
sudo ./user.sh --lock user --name contractor2

# 2. Wait 24-48 hours, verify no active processes
sudo ./user.sh --delete user --name contractor1 --check

# 3. Delete with backup
sudo ./user.sh --delete user --input contractor_offboard.json
```

### Security Incident Response
```bash
# 1. Immediately lock compromised account
sudo ./user.sh --lock user --name compromised_user --reason "Security incident"

# 2. Check for active processes
sudo ./user.sh --delete user --name compromised_user --check

# 3. Kill processes if needed, then delete with backup
sudo ./user.sh --delete user --input security_incident.json
```

---

## 💡 Best Practices

### Planning
- [ ] Document your role/group structure before creating templates
- [ ] Test with a single user before bulk operations
- [ ] Keep templates in version control (git)
- [ ] Add comments to document business logic

### Security
- [ ] Always use `"type": "random"` for passwords
- [ ] Set appropriate password expiry (30-90 days)
- [ ] Limit sudo access to necessary roles only
- [ ] Regular audits: `sudo ./user.sh --report security`

### Operations
- [ ] Use `--dry-run` to preview changes
- [ ] Keep backups of all JSON files before executing
- [ ] Document reasons for changes
- [ ] Test on non-production systems first

### Maintenance
- [ ] Review and update role definitions quarterly
- [ ] Clean up old groups: `sudo ./user.sh --view groups --filter empty`
- [ ] Check for inactive accounts: `sudo ./user.sh --report compliance`
- [ ] Archive old JSON files with dates

---

## 🔍 Validation & Testing

### Validate JSON Syntax
```bash
# Install jq if not present
sudo apt install jq  # Ubuntu/Debian
sudo yum install jq  # Amazon Linux/RHEL

# Validate JSON file
jq empty users.json && echo "Valid JSON" || echo "Invalid JSON"
```

### Test Mode
```bash
# ALWAYS test first!
sudo ./user.sh --add user --input users.json --dry-run
```

### Verify Results
```bash
# Check user was created
id alice

# Check groups
groups alice

# Check password policy
sudo chage -l alice

# View all users
sudo ./user.sh --view users

# Generate report
sudo ./user.sh --report security
```

---

## 🐛 Troubleshooting

### "jq: command not found"
```bash
# Install jq
sudo apt install jq    # Ubuntu/Debian
sudo yum install jq    # Amazon Linux/RHEL
```

### "Invalid JSON format"
```bash
# Validate JSON syntax
jq empty your_file.json

# Common issues:
# - Missing comma between objects
# - Trailing comma after last object
# - Unescaped quotes in strings
# - Comments not in _comment fields
```

### "User already exists"
```bash
# Check if user exists
id username

# Remove user first, or skip in JSON
sudo ./user.sh --delete user --name username --check
```

### "Group does not exist"
```bash
# Create groups first
sudo ./user.sh --manage-groups groups.json

# Or create groups before adding users
```

### "Permission denied"
```bash
# Must run as root
sudo ./user.sh --add user --input users.json
```

---

## 📚 Additional Resources

### Learn More
- Main help: `sudo ./user.sh --help`
- Operation-specific help: `sudo ./user.sh --help add`
- View examples: `cat examples/*.json`

### Get System Information
```bash
# View all users
sudo ./user.sh --view users

# View all groups
sudo ./user.sh --view groups

# System summary
sudo ./user.sh --view summary

# Security audit
sudo ./user.sh --report security
```

### Export Current Configuration
```bash
# Export users to JSON for backup
sudo ./user.sh --export users --output backup_users.json --format json

# Export groups
sudo ./user.sh --export groups --output backup_groups.json --format json

# Export complete system state
sudo ./user.sh --export all --output system_backup.json --format json
```

---

## 🎓 Advanced Examples

### Complex Role Hierarchy
```json
{
  "roles": {
    "junior_dev": {
      "groups": ["developers"],
      "password_expiry_days": 90
    },
    "senior_dev": {
      "groups": ["developers", "deploy"],
      "password_expiry_days": 60
    },
    "tech_lead": {
      "groups": ["developers", "deploy", "sudo"],
      "password_expiry_days": 30
    }
  }
}
```

### Conditional Access
```json
{
  "username": "contractor",
  "expire_days": 90,
  "comment": "90-day contractor - access expires automatically"
}
```

### Service Account Setup
```json
{
  "username": "svc_webapp",
  "shell": "/sbin/nologin",
  "groups": ["services"],
  "password_policy": {
    "type": "random",
    "expiry_days": 99999
  }
}
```

---

## 📞 Support

### Check Logs
```bash
# View recent actions
sudo tail -f /var/log/user_mgmt.log

# Search logs
sudo grep "alice" /var/log/user_mgmt.log
```

### Get Help
- Main documentation: `/opt/admin_dashboard/README.md`
- Built-in help: `sudo ./user.sh --help`
- Configuration: `/opt/admin_dashboard/config/user_mgmt.conf`

---

## ✅ Quick Reference

| Operation | Command |
|-----------|---------|
| Create users | `sudo ./user.sh --add user --input users.json` |
| Apply roles | `sudo ./user.sh --apply-roles roles.json` |
| Manage groups | `sudo ./user.sh --manage-groups groups.json` |
| Delete users | `sudo ./user.sh --delete user --input deletions.json` |
| View users | `sudo ./user.sh --view users` |
| Security report | `sudo ./user.sh --report security` |
| Test mode | Add `--dry-run` to any command |

---

**Last Updated:** January 2024  
**Version:** 1.0.1