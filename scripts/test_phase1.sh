#!/usr/bin/env bash
# ================================================
# Phase 1 - Independent Test Suite
# Version: 1.0.3
# ================================================
# Each test is completely independent with setup/teardown
# Usage: sudo ./test_phase1.sh [test_name|all|--help]
# ================================================



# Show help first if requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat <<'EOF'
========================================
Phase 1 Test Suite Help
========================================

USAGE:
  sudo ./test_phase1.sh [command] [options]

COMMANDS:
  all              - Run all tests (default)
  quick            - Quick smoke test (10 tests)
  user-only        - User management tests only
  group-only       - Group management tests only
  json-only        - JSON operation tests only
  reports-only     - Report generation tests only
  
INDIVIDUAL TESTS:
  version          - Version command
  help             - Help system
  config           - Config validation
  icons            - Icon system
  
  add-user-text    - Add user from text file
  add-user-json    - Add user from JSON
  add-user-random  - Random password generation
  add-user-sudo    - Sudo assignment
  add-user-expiry  - Account expiration
  
  add-group-text   - Add group from text
  add-group-json   - Add group from JSON
  
  view-user        - View single user
  view-users       - View all users
  view-group       - View single group
  view-groups      - View all groups
  view-summary     - System summary
  view-recent      - Recent logins
  
  update-password  - Password reset
  update-shell     - Shell change
  update-groups    - Add/remove groups
  update-comment   - Comment update
  
  lock-unlock      - Lock/unlock user
  
  delete-check     - Pre-deletion check
  delete-backup    - Delete with backup
  delete-batch-text - Batch delete from text
  delete-batch-json - Batch delete from JSON
  
  search-users     - Search users
  search-groups    - Search groups
  search-json      - JSON search output
  
  apply-roles      - Role-based provisioning
  manage-groups-json - JSON group management
  
  report-security  - Security report
  report-compliance - Compliance report
  report-activity  - Activity report
  report-storage   - Storage report
  report-json      - JSON report output
  
  export-csv       - CSV export
  export-json      - JSON export
  export-tsv       - TSV export
  export-all       - Complete export
  
  dry-run          - Dry-run mode test
  validation       - Input validation

OPTIONS:
  --help, -h       - Show this help
  --verbose, -v    - Detailed output
  --stop-on-fail   - Stop on first failure
  --no-cleanup     - Keep test data (debug)

EXAMPLES:
  sudo ./test_phase1.sh all
  sudo ./test_phase1.sh quick
  sudo ./test_phase1.sh add-user-text --verbose
  sudo ./test_phase1.sh user-only --stop-on-fail

REQUIREMENTS:
  - Must run as root
  - jq for JSON tests
  - Phase 1 at /opt/admin_dashboard

========================================
EOF
    exit 0
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_SCRIPT="$SCRIPT_DIR/user.sh"
TEST_LOG="/tmp/phase1_test_$(date +%Y%m%d_%H%M%S).log"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test options
VERBOSE=false
STOP_ON_FAIL=false
NO_CLEANUP=false

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        --verbose|-v) VERBOSE=true; shift ;;
        --stop-on-fail) STOP_ON_FAIL=true; shift ;;
        --no-cleanup) NO_CLEANUP=true; shift ;;
        *) TEST_COMMAND="$1"; shift ;;
    esac
done

TEST_COMMAND="${TEST_COMMAND:-all}"

# Print functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${BLUE}→${NC} Testing: $1"
    $VERBOSE && echo "  [Test: $1]"
}

print_pass() {
    echo -e "${GREEN}✓${NC} PASS: $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗${NC} FAIL: $1"
    echo "  Error: $2"
    ((TESTS_FAILED++))
    
    if $STOP_ON_FAIL; then
        echo ""
        echo "Stopping on first failure"
        exit 1
    fi
}

print_skip() {
    echo -e "${YELLOW}⊘${NC} SKIP: $1"
    echo "  Reason: $2"
    ((TESTS_SKIPPED++))
}

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$TEST_LOG"
}

# Generate unique names
get_test_user() {
    echo "tuser_${1}_$$"
}

get_test_group() {
    echo "tgrp_${1}_$$"
}

# Setup/cleanup for each test
setup_test() {
    local test_name="$1"
    local tmp_dir="/tmp/test_${test_name}_$$"
    mkdir -p "$tmp_dir"
    $VERBOSE && echo "  [Setup: $tmp_dir]"
    echo "$tmp_dir"
}

cleanup_test() {
    local test_name="$1"
    local tmp_dir="/tmp/test_${test_name}_$$"
    
    if $NO_CLEANUP; then
        $VERBOSE && echo "  [Cleanup skipped]"
        return 0
    fi
    
    $VERBOSE && echo "  [Cleanup: $test_name]"
    
    # Remove users from this test
    for user in $(compgen -u); do
        if [[ "$user" =~ ^tuser_${test_name}_ ]]; then
            sudo userdel -r "$user" &>/dev/null || true
        fi
    done
    
    # Remove groups from this test
    while IFS=: read -r groupname _ _ _; do
        if [[ "$groupname" =~ ^tgrp_${test_name}_ ]]; then
            sudo groupdel "$groupname" &>/dev/null || true
        fi
    done < /etc/group
    
    # Remove temp files
    rm -rf "$tmp_dir" 2>/dev/null || true
}

cleanup_all() {
    echo ""
    print_header "Final Cleanup"
    
    # Remove ALL test users
    for user in $(compgen -u); do
        if [[ "$user" =~ ^tuser_ ]]; then
            sudo userdel -r "$user" &>/dev/null || true
        fi
    done
    
    # Remove ALL test groups
    while IFS=: read -r groupname _ _ _; do
        if [[ "$groupname" =~ ^tgrp_ ]]; then
            sudo groupdel "$groupname" &>/dev/null || true
        fi
    done < /etc/group
    
    # Remove temp files
    rm -f /tmp/test_*_$$ 2>/dev/null || true
    rm -f /tmp/test_export_* 2>/dev/null || true
    
    echo "Cleanup complete"
}

# Pre-flight checks
preflight_checks() {
    print_header "Pre-Flight Checks"
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}✗${NC} Must run as root (use sudo)"
        exit 2
    fi
    echo -e "${GREEN}✓${NC} Running as root"
    
    if [ ! -f "$USER_SCRIPT" ]; then
        echo -e "${RED}✗${NC} user.sh not found: $USER_SCRIPT"
        exit 2
    fi
    echo -e "${GREEN}✓${NC} user.sh found"
    
    if [ ! -x "$USER_SCRIPT" ]; then
        chmod +x "$USER_SCRIPT"
    fi
    echo -e "${GREEN}✓${NC} user.sh is executable"
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} jq not installed (JSON tests will be skipped)"
    else
        echo -e "${GREEN}✓${NC} jq is installed"
    fi
    
    touch "$TEST_LOG"
    echo -e "${GREEN}✓${NC} Test log: $TEST_LOG"
    echo ""
}

# ============================================
# INDEPENDENT TEST FUNCTIONS
# ============================================

# Test: Version
test_version() {
    print_test "Version command"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "version")
    
    if sudo "$USER_SCRIPT" --version &>/dev/null; then
        local version=$(sudo "$USER_SCRIPT" --version 2>&1 | head -1)
        print_pass "Version check ($version)"
        log "Version: $version"
    else
        print_fail "Version check" "Command failed"
    fi
    
    cleanup_test "version"
}

# Test: Help
test_help() {
    print_test "Help system"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "help")
    
    local topics=("add" "delete" "update" "view" "report" "export" "json" "roles" "groups-json" "config")
    local failed_topics=""
    
    for topic in "${topics[@]}"; do
        if ! sudo "$USER_SCRIPT" --help "$topic" &>/dev/null; then
            failed_topics="$failed_topics $topic"
        fi
    done
    
    if [ -z "$failed_topics" ]; then
        print_pass "All help topics work"
        log "Help topics: ${topics[*]}"
    else
        print_fail "Help system" "Failed topics:$failed_topics"
    fi
    
    cleanup_test "help"
}

# Test: Config validation
test_config() {
    print_test "Configuration validation"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "config")
    
    if sudo "$USER_SCRIPT" --view summary &>/dev/null; then
        print_pass "Config validates successfully"
    else
        print_fail "Config validation" "Config has errors"
    fi
    
    cleanup_test "config"
}

# Test: Icon system
test_icons() {
    print_test "Icon variable system"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "icons")
    local user=$(get_test_user "icons")
    local file="$tmp_dir/user.txt"
    
    echo "$user:Icon Test" > "$file"
    local output=$(sudo "$USER_SCRIPT" --add user --names "$file" 2>&1)
    
    if echo "$output" | grep -qE "✓|✗|\\[OK\\]|\\[X\\]"; then
        print_pass "Icon system working"
    else
        print_fail "Icon system" "No icons in output"
    fi
    
    cleanup_test "icons"
}

# Test: Add user from text file
test_add_user_text() {
    print_test "Add user from text file"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "addtext")
    local user=$(get_test_user "addtext")
    local file="$tmp_dir/users.txt"
    
    # Create test file with all fields
    echo "$user:Test User:90:a:no:" > "$file"
    
    if sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null; then
        if id "$user" &>/dev/null; then
            # Verify all fields
            local shell=$(getent passwd "$user" | cut -d: -f7)
            local comment=$(getent passwd "$user" | cut -d: -f5)
            
            if [ "$shell" = "/bin/bash" ] && [ "$comment" = "Test User" ]; then
                print_pass "User created with correct fields"
                log "Created: $user"
            else
                print_fail "Add user text" "Fields incorrect (shell=$shell, comment=$comment)"
            fi
        else
            print_fail "Add user text" "User not found after creation"
        fi
    else
        print_fail "Add user text" "Command failed"
    fi
    
    cleanup_test "addtext"
}

# Test: Add user with random password
test_add_user_random() {
    print_test "Random password generation"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "random")
    local user=$(get_test_user "random")
    local file="$tmp_dir/users.txt"
    
    echo "$user:Random Test:::no:random" > "$file"
    
    if sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null; then
        if id "$user" &>/dev/null; then
            local pwd_files=$(sudo find /var/backups/users/passwords -name "${user}_*.txt" 2>/dev/null | wc -l)
            if [ "$pwd_files" -gt 0 ]; then
                print_pass "Random password generated and saved"
                log "Random password: $user"
            else
                print_fail "Random password" "Password file not created"
            fi
        else
            print_fail "Random password" "User not created"
        fi
    else
        print_fail "Random password" "Command failed"
    fi
    
    cleanup_test "random"
}

# Test: Add user with sudo
test_add_user_sudo() {
    print_test "User with sudo access"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "sudo")
    local user=$(get_test_user "sudo")
    local file="$tmp_dir/users.txt"
    
    echo "$user:Sudo Test:::yes:" > "$file"
    
    if sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null; then
        if id "$user" &>/dev/null; then
            if groups "$user" | grep -qE 'sudo|wheel'; then
                print_pass "User created with sudo access"
                log "Sudo user: $user"
            else
                print_fail "Add user sudo" "User not in sudo/wheel group"
            fi
        else
            print_fail "Add user sudo" "User not created"
        fi
    else
        print_fail "Add user sudo" "Command failed"
    fi
    
    cleanup_test "sudo"
}

# Test: Add user with expiry
test_add_user_expiry() {
    print_test "User with account expiration"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "expiry")
    local user=$(get_test_user "expiry")
    local file="$tmp_dir/users.txt"
    
    echo "$user:Expiry Test:90:a:no:" > "$file"
    
    if sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null; then
        if id "$user" &>/dev/null; then
            local expiry=$(sudo chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
            if [ "$expiry" != "never" ]; then
                print_pass "User created with expiration"
                log "Expiry user: $user ($expiry)"
            else
                print_fail "Add user expiry" "Account doesn't expire"
            fi
        else
            print_fail "Add user expiry" "User not created"
        fi
    else
        print_fail "Add user expiry" "Command failed"
    fi
    
    cleanup_test "expiry"
}

# Test: Add user from JSON
test_add_user_json() {
    print_test "Add user from JSON"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "Add user JSON" "jq not installed"
        return
    fi
    
    local tmp_dir=$(setup_test "json")
    local user=$(get_test_user "json")
    local file="$tmp_dir/users.json"
    
    cat > "$file" <<EOF
{
  "users": [
    {
      "username": "$user",
      "comment": "JSON Test User",
      "groups": [],
      "shell": "/bin/bash",
      "expire_days": 0,
      "password_policy": {
        "type": "random",
        "expiry_days": 90
      }
    }
  ]
}
EOF
    
    if sudo "$USER_SCRIPT" --add user --input "$file" --format json &>/dev/null; then
        if id "$user" &>/dev/null; then
            print_pass "User created from JSON"
            log "JSON user: $user"
        else
            print_fail "Add user JSON" "User not found"
        fi
    else
        print_fail "Add user JSON" "Command failed"
    fi
    
    cleanup_test "json"
}

# Test: Add group from text
test_add_group_text() {
    print_test "Add group from text file"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "grptext")
    local group=$(get_test_group "grptext")
    local file="$tmp_dir/groups.txt"
    
    echo "$group" > "$file"
    
    if sudo "$USER_SCRIPT" --add group --names "$file" &>/dev/null; then
        if getent group "$group" &>/dev/null; then
            print_pass "Group created from text"
            log "Group created: $group"
        else
            print_fail "Add group text" "Group not found"
        fi
    else
        print_fail "Add group text" "Command failed"
    fi
    
    cleanup_test "grptext"
}

# Test: Add group from JSON
test_add_group_json() {
    print_test "Add group from JSON"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "Add group JSON" "jq not installed"
        return
    fi
    
    local tmp_dir=$(setup_test "grpjson")
    local group=$(get_test_group "grpjson")
    local file="$tmp_dir/groups.json"
    
    cat > "$file" <<EOF
{
  "groups": [
    {
      "name": "$group",
      "action": "create",
      "members": []
    }
  ]
}
EOF
    
    if sudo "$USER_SCRIPT" --manage-groups "$file" &>/dev/null; then
        if getent group "$group" &>/dev/null; then
            print_pass "Group created from JSON"
            log "JSON group: $group"
        else
            print_fail "Add group JSON" "Group not found"
        fi
    else
        print_fail "Add group JSON" "Command failed"
    fi
    
    cleanup_test "grpjson"
}

# Test: View single user
test_view_user() {
    print_test "View single user details"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "viewuser")
    local user=$(get_test_user "viewuser")
    local file="$tmp_dir/user.txt"
    
    # Create user first
    echo "$user:View Test" > "$file"
    sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null
    
    if sudo "$USER_SCRIPT" --view user --name "$user" &>/dev/null; then
        print_pass "View user details works"
    else
        print_fail "View user" "Command failed"
    fi
    
    cleanup_test "viewuser"
}

# Test: View all users
test_view_users() {
    print_test "View all users"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "viewusers")
    
    if sudo "$USER_SCRIPT" --view users &>/dev/null; then
        print_pass "View users command works"
    else
        print_fail "View users" "Command failed"
    fi
    
    cleanup_test "viewusers"
}

# Test: View single group
test_view_group() {
    print_test "View single group details"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "viewgrp")
    local group=$(get_test_group "viewgrp")
    local file="$tmp_dir/group.txt"
    
    # Create group first
    echo "$group" > "$file"
    sudo "$USER_SCRIPT" --add group --names "$file" &>/dev/null
    
    if sudo "$USER_SCRIPT" --view group --name "$group" &>/dev/null; then
        print_pass "View group details works"
    else
        print_fail "View group" "Command failed"
    fi
    
    cleanup_test "viewgrp"
}

# Test: View all groups
test_view_groups() {
    print_test "View all groups"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "viewgrps")
    
    if sudo "$USER_SCRIPT" --view groups &>/dev/null; then
        print_pass "View groups command works"
    else
        print_fail "View groups" "Command failed"
    fi
    
    cleanup_test "viewgrps"
}

# Test: View summary
test_view_summary() {
    print_test "System summary"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "summary")
    
    if sudo "$USER_SCRIPT" --view summary &>/dev/null; then
        print_pass "System summary displays"
    else
        print_fail "View summary" "Command failed"
    fi
    
    cleanup_test "summary"
}

# Test: View recent logins
test_view_recent() {
    print_test "Recent logins"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "recent")
    
    if sudo "$USER_SCRIPT" --view recent-logins --hours 24 &>/dev/null; then
        print_pass "Recent logins displays"
    else
        print_fail "View recent" "Command failed"
    fi
    
    cleanup_test "recent"
}

# Test: Update password
test_update_password() {
    print_test "Password reset"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "updpwd")
    local user=$(get_test_user "updpwd")
    local file="$tmp_dir/user.txt"
    
    # Create user first
    echo "$user:Update Test" > "$file"
    sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null
    
    if sudo "$USER_SCRIPT" --update user --name "$user" --reset-password &>/dev/null; then
        print_pass "Password reset works"
        log "Password reset: $user"
    else
        print_fail "Update password" "Command failed"
    fi
    
    cleanup_test "updpwd"
}

# Test: Update shell
test_update_shell() {
    print_test "Shell change"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "updshell")
    local user=$(get_test_user "updshell")
    local file="$tmp_dir/user.txt"
    
    # Create user with /bin/bash
    echo "$user:Shell Test:::a" > "$file"
    sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null
    
    # Change to nologin
    if sudo "$USER_SCRIPT" --update user --name "$user" --shell d &>/dev/null; then
        local new_shell=$(getent passwd "$user" | cut -d: -f7)
        if [[ "$new_shell" =~ nologin ]]; then
            print_pass "Shell changed successfully"
            log "Shell changed: $user"
        else
            print_fail "Update shell" "Shell not changed ($new_shell)"
        fi
    else
        print_fail "Update shell" "Command failed"
    fi
    
    cleanup_test "updshell"
}

# Test: Update groups
test_update_groups() {
    print_test "Add/remove groups"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "updgrps")
    local user=$(get_test_user "updgrps")
    local group=$(get_test_group "updgrps")
    local ufile="$tmp_dir/user.txt"
    local gfile="$tmp_dir/group.txt"
    
    # Create user and group
    echo "$user:Group Test" > "$ufile"
    echo "$group" > "$gfile"
    sudo "$USER_SCRIPT" --add user --names "$ufile" &>/dev/null
    sudo "$USER_SCRIPT" --add group --names "$gfile" &>/dev/null
    
    # Add user to group
    if sudo "$USER_SCRIPT" --update user --name "$user" --add-to-groups "$group" &>/dev/null; then
        if groups "$user" | grep -q "$group"; then
            print_pass "User added to group"
            log "Groups updated: $user"
        else
            print_fail "Update groups" "User not in group"
        fi
    else
        print_fail "Update groups" "Command failed"
    fi
    
    cleanup_test "updgrps"
}

# Test: Update comment
test_update_comment() {
    print_test "Comment update"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "updcom")
    local user=$(get_test_user "updcom")
    local file="$tmp_dir/user.txt"
    
    # Create user
    echo "$user:Old Comment" > "$file"
    sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null
    
    # Update comment
    if sudo "$USER_SCRIPT" --update user --name "$user" --comment "New Comment" &>/dev/null; then
        local new_comment=$(getent passwd "$user" | cut -d: -f5)
        if [ "$new_comment" = "New Comment" ]; then
            print_pass "Comment updated successfully"
            log "Comment updated: $user"
        else
            print_fail "Update comment" "Comment not changed ($new_comment)"
        fi
    else
        print_fail "Update comment" "Command failed"
    fi
    
    cleanup_test "updcom"
}

# Test: Lock and unlock
test_lock_unlock() {
    print_test "Lock and unlock user"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "lock")
    local user=$(get_test_user "lock")
    local file="$tmp_dir/user.txt"
    
    # Create user
    echo "$user:Lock Test" > "$file"
    sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null
    
    # Lock user
    if sudo "$USER_SCRIPT" --lock user --name "$user" &>/dev/null; then
        if passwd -S "$user" 2>/dev/null | grep -q " LK "; then
            # Unlock user
            if sudo "$USER_SCRIPT" --unlock user --name "$user" &>/dev/null; then
                if ! passwd -S "$user" 2>/dev/null | grep -q " LK "; then
                    print_pass "Lock and unlock work"
                    log "Lock/unlock: $user"
                else
                    print_fail "Lock unlock" "User still locked"
                fi
            else
                print_fail "Lock unlock" "Unlock failed"
            fi
        else
            print_fail "Lock unlock" "Lock failed"
        fi
    else
        print_fail "Lock unlock" "Command failed"
    fi
    
    cleanup_test "lock"
}

# Test: Delete check
test_delete_check() {
    print_test "Pre-deletion check"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "delchk")
    local user=$(get_test_user "delchk")
    local file="$tmp_dir/user.txt"
    
    # Create user
    echo "$user:Delete Test" > "$file"
    sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null
    
    # Check deletion
    if sudo "$USER_SCRIPT" --delete user --name "$user" --check &>/dev/null; then
        # User should still exist
        if id "$user" &>/dev/null; then
            print_pass "Delete check doesn't delete"
            log "Delete check: $user"
        else
            print_fail "Delete check" "User was deleted"
        fi
    else
        print_fail "Delete check" "Command failed"
    fi
    
    cleanup_test "delchk"
}

# Test: Delete with backup
test_delete_backup() {
    print_test "Delete with backup"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "delbak")
    local user=$(get_test_user "delbak")
    local backup_dir="$tmp_dir/backups"
    local file="$tmp_dir/user.txt"
    
    # Create user
    echo "$user:Backup Test" > "$file"
    sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null
    
    # Delete with backup
    if sudo "$USER_SCRIPT" --delete user --name "$user" --backup --backup-dir "$backup_dir" --force-logout &>/dev/null; then
        # User should be deleted
        if ! id "$user" &>/dev/null; then
            # Backup should exist
            if compgen -G "$backup_dir/${user}_*" > /dev/null; then
                print_pass "Delete with backup works"
                log "Delete backup: $user"
            else
                print_fail "Delete backup" "Backup not created"
            fi
        else
            print_fail "Delete backup" "User not deleted"
        fi
    else
        print_fail "Delete backup" "Command failed"
    fi
    
    cleanup_test "delbak"
}

# Test: Batch delete from text
test_delete_batch_text() {
    print_test "Batch delete from text"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "delbatch")
    local user1=$(get_test_user "delbatch" "1")
    local user2=$(get_test_user "delbatch" "2")
    local create_file="$tmp_dir/create.txt"
    local delete_file="$tmp_dir/delete.txt"
    
    # Create users
    echo -e "$user1:Batch 1\n$user2:Batch 2" > "$create_file"
    sudo "$USER_SCRIPT" --add user --names "$create_file" &>/dev/null
    
    # Delete users
    echo -e "$user1\n$user2" > "$delete_file"
    if sudo "$USER_SCRIPT" --delete user --names "$delete_file" &>/dev/null; then
        if ! id "$user1" &>/dev/null && ! id "$user2" &>/dev/null; then
            print_pass "Batch delete from text works"
            log "Batch delete: $user1, $user2"
        else
            print_fail "Batch delete text" "Users not deleted"
        fi
    else
        print_fail "Batch delete text" "Command failed"
    fi
    
    cleanup_test "delbatch"
}

# Test: Batch delete from JSON
test_delete_batch_json() {
    print_test "Batch delete from JSON"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "Batch delete JSON" "jq not installed"
        return
    fi
    
    local tmp_dir=$(setup_test "deljson")
    local user1=$(get_test_user "deljson" "1")
    local user2=$(get_test_user "deljson" "2")
    local create_file="$tmp_dir/create.txt"
    local delete_file="$tmp_dir/delete.json"
    
    # Create users
    echo -e "$user1:Del JSON 1\n$user2:Del JSON 2" > "$create_file"
    sudo "$USER_SCRIPT" --add user --names "$create_file" &>/dev/null
    
    # Create deletion JSON
    cat > "$delete_file" <<EOF
{
  "deletions": [
    {"username": "$user1", "backup": true, "delete_home": true},
    {"username": "$user2", "backup": true, "delete_home": true}
  ],
  "options": {
    "backup_dir": "$tmp_dir/backups"
  }
}
EOF
    
    if sudo "$USER_SCRIPT" --delete user --input "$delete_file" &>/dev/null; then
        if ! id "$user1" &>/dev/null && ! id "$user2" &>/dev/null; then
            print_pass "Batch delete from JSON works"
            log "JSON delete: $user1, $user2"
        else
            print_fail "Batch delete JSON" "Users not deleted"
        fi
    else
        print_fail "Batch delete JSON" "Command failed"
    fi
    
    cleanup_test "deljson"
}

# Test: Search users
test_search_users() {
    print_test "Search users"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "search")
    local user=$(get_test_user "search")
    local file="$tmp_dir/user.txt"
    
    # Create user with unique pattern
    echo "$user:Search Test" > "$file"
    sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null
    
    if sudo "$USER_SCRIPT" --search users --pattern "search" &>/dev/null; then
        print_pass "Search users works"
        log "Search: $user"
    else
        print_fail "Search users" "Command failed"
    fi
    
    cleanup_test "search"
}

# Test: Search groups
test_search_groups() {
    print_test "Search groups"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "searchgrp")
    local group=$(get_test_group "searchgrp")
    local file="$tmp_dir/group.txt"
    
    # Create group
    echo "$group" > "$file"
    sudo "$USER_SCRIPT" --add group --names "$file" &>/dev/null
    
    if sudo "$USER_SCRIPT" --search groups --pattern "searchgrp" &>/dev/null; then
        print_pass "Search groups works"
        log "Search group: $group"
    else
        print_fail "Search groups" "Command failed"
    fi
    
    cleanup_test "searchgrp"
}

# Test: JSON search output
test_search_json() {
    print_test "JSON search output"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "JSON search" "jq not installed"
        return
    fi
    
    local tmp_dir=$(setup_test "srcjson")
    
    local output=$(sudo "$USER_SCRIPT" --search users --pattern "root" --json 2>/dev/null)
    
    if echo "$output" | jq empty &>/dev/null; then
        print_pass "JSON search output works"
        log "JSON search validated"
    else
        print_fail "Search JSON" "Invalid JSON output"
    fi
    
    cleanup_test "srcjson"
}

# Test: Apply roles
test_apply_roles() {
    print_test "Apply roles from JSON"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "Apply roles" "jq not installed"
        return
    fi
    
    local tmp_dir=$(setup_test "roles")
    local user=$(get_test_user "roles")
    local group1=$(get_test_group "roles" "1")
    local group2=$(get_test_group "roles" "2")
    local gfile="$tmp_dir/groups.txt"
    local rfile="$tmp_dir/roles.json"
    
    # Create groups
    echo -e "$group1\n$group2" > "$gfile"
    sudo "$USER_SCRIPT" --add group --names "$gfile" &>/dev/null
    
    # Create roles file
    cat > "$rfile" <<EOF
{
  "roles": {
    "test_role": {
      "groups": ["$group1", "$group2"],
      "shell": "/bin/bash",
      "password_expiry_days": 90,
      "description": "Test role"
    }
  },
  "assignments": [
    {"username": "$user", "role": "test_role"}
  ]
}
EOF
    
    if sudo "$USER_SCRIPT" --apply-roles "$rfile" &>/dev/null; then
        if id "$user" &>/dev/null && groups "$user" | grep -q "$group1"; then
            print_pass "Role applied successfully"
            log "Role applied: $user"
        else
            print_fail "Apply roles" "User not created or missing groups"
        fi
    else
        print_fail "Apply roles" "Command failed"
    fi
    
    cleanup_test "roles"
}

# Test: Manage groups JSON
test_manage_groups_json() {
    print_test "Manage groups from JSON"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "Manage groups" "jq not installed"
        return
    fi
    
    local tmp_dir=$(setup_test "mggrp")
    local group=$(get_test_group "mggrp")
    local file="$tmp_dir/groups.json"
    
    cat > "$file" <<EOF
{
  "groups": [
    {
      "name": "$group",
      "action": "create",
      "members": []
    }
  ]
}
EOF
    
    if sudo "$USER_SCRIPT" --manage-groups "$file" &>/dev/null; then
        if getent group "$group" &>/dev/null; then
            print_pass "Groups managed from JSON"
            log "JSON group: $group"
        else
            print_fail "Manage groups" "Group not created"
        fi
    else
        print_fail "Manage groups" "Command failed"
    fi
    
    cleanup_test "mggrp"
}

# Test: Security report
test_report_security() {
    print_test "Security report"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "repsec")
    
    if sudo "$USER_SCRIPT" --report security &>/dev/null; then
        print_pass "Security report generates"
        log "Security report OK"
    else
        print_fail "Security report" "Command failed"
    fi
    
    cleanup_test "repsec"
}

# Test: Compliance report
test_report_compliance() {
    print_test "Compliance report"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "repcom")
    
    if sudo "$USER_SCRIPT" --report compliance &>/dev/null; then
        print_pass "Compliance report generates"
        log "Compliance report OK"
    else
        print_fail "Compliance report" "Command failed"
    fi
    
    cleanup_test "repcom"
}

# Test: Activity report
test_report_activity() {
    print_test "Activity report"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "repact")
    
    if sudo "$USER_SCRIPT" --report activity --days 30 &>/dev/null; then
        print_pass "Activity report generates"
        log "Activity report OK"
    else
        print_fail "Activity report" "Command failed"
    fi
    
    cleanup_test "repact"
}

# Test: Storage report
test_report_storage() {
    print_test "Storage report"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "repsto")
    
    if sudo "$USER_SCRIPT" --report storage &>/dev/null; then
        print_pass "Storage report generates"
        log "Storage report OK"
    else
        print_fail "Storage report" "Command failed"
    fi
    
    cleanup_test "repsto"
}

# Test: JSON report output
test_report_json() {
    print_test "JSON report output"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "JSON report" "jq not installed"
        return
    fi
    
    local tmp_dir=$(setup_test "repjson")
    
    local output=$(sudo "$USER_SCRIPT" --report security --json 2>/dev/null)
    
    if echo "$output" | jq empty &>/dev/null; then
        print_pass "JSON report output works"
        log "JSON report validated"
    else
        print_fail "Report JSON" "Invalid JSON output"
    fi
    
    cleanup_test "repjson"
}

# Test: CSV export
test_export_csv() {
    print_test "CSV export"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "expcsv")
    local output="$tmp_dir/export.csv"
    
    if sudo "$USER_SCRIPT" --export users --output "$output" --format csv &>/dev/null; then
        if [ -f "$output" ] && [ -s "$output" ]; then
            # Check CSV header
            if head -1 "$output" | grep -q "username"; then
                print_pass "CSV export works"
                log "CSV export OK"
            else
                print_fail "Export CSV" "Invalid CSV format"
            fi
        else
            print_fail "Export CSV" "File not created or empty"
        fi
    else
        print_fail "Export CSV" "Command failed"
    fi
    
    cleanup_test "expcsv"
}

# Test: JSON export
test_export_json() {
    print_test "JSON export"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "Export JSON" "jq not installed"
        return
    fi
    
    local tmp_dir=$(setup_test "expjson")
    local output="$tmp_dir/export.json"
    
    if sudo "$USER_SCRIPT" --export users --output "$output" --format json &>/dev/null; then
        if [ -f "$output" ] && jq empty "$output" &>/dev/null; then
            print_pass "JSON export works"
            log "JSON export OK"
        else
            print_fail "Export JSON" "Invalid JSON output"
        fi
    else
        print_fail "Export JSON" "Command failed"
    fi
    
    cleanup_test "expjson"
}

# Test: TSV export
test_export_tsv() {
    print_test "TSV export"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "exptsv")
    local output="$tmp_dir/export.tsv"
    
    if sudo "$USER_SCRIPT" --export users --output "$output" --format tsv &>/dev/null; then
        if [ -f "$output" ] && [ -s "$output" ]; then
            print_pass "TSV export works"
            log "TSV export OK"
        else
            print_fail "Export TSV" "File not created or empty"
        fi
    else
        print_fail "Export TSV" "Command failed"
    fi
    
    cleanup_test "exptsv"
}

# Test: Complete export
test_export_all() {
    print_test "Complete system export"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "Export all" "jq not installed"
        return
    fi
    
    local tmp_dir=$(setup_test "expall")
    local output="$tmp_dir/complete.json"
    
    if sudo "$USER_SCRIPT" --export all --output "$output" --format json &>/dev/null; then
        if [ -f "$output" ] && jq empty "$output" &>/dev/null; then
            # Check for both users and groups sections
            if jq -e '.users' "$output" &>/dev/null && jq -e '.groups' "$output" &>/dev/null; then
                print_pass "Complete export works"
                log "Complete export OK"
            else
                print_fail "Export all" "Missing users or groups section"
            fi
        else
            print_fail "Export all" "Invalid JSON output"
        fi
    else
        print_fail "Export all" "Command failed"
    fi
    
    cleanup_test "expall"
}

# Test: Dry-run mode
test_dry_run() {
    print_test "Dry-run mode"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "dryrun")
    local user=$(get_test_user "dryrun")
    local file="$tmp_dir/user.txt"
    
    echo "$user:Dry Run Test" > "$file"
    
    if sudo "$USER_SCRIPT" --add user --names "$file" --dry-run &>/dev/null; then
        # User should NOT be created
        if ! id "$user" &>/dev/null; then
            print_pass "Dry-run makes no changes"
            log "Dry-run verified"
        else
            print_fail "Dry-run" "User was created (should not happen)"
        fi
    else
        print_fail "Dry-run" "Command failed"
    fi
    
    cleanup_test "dryrun"
}

# Test: Input validation
test_validation() {
    print_test "Input validation"
    ((TESTS_RUN++))
    
    local tmp_dir=$(setup_test "valid")
    local file="$tmp_dir/invalid.txt"
    
    # Try invalid username (starts with number)
    echo "123invalid:Invalid User" > "$file"
    
    if ! sudo "$USER_SCRIPT" --add user --names "$file" &>/dev/null; then
        # Command should fail for invalid input
        print_pass "Input validation works"
        log "Validation OK"
    else
        # If it succeeded, check if user was created (shouldn't be)
        if ! id "123invalid" &>/dev/null; then
            print_pass "Input validation works (rejected invalid)"
            log "Validation OK"
        else
            print_fail "Validation" "Invalid user was created"
        fi
    fi
    
    cleanup_test "valid"
}

# ============================================
# TEST SUITES
# ============================================

run_all_tests() {
    print_header "Running All Tests"
    
    # Core tests
    test_version
    test_help
    test_config
    test_icons
    
    # User tests
    test_add_user_text
    test_add_user_json
    test_add_user_random
    test_add_user_sudo
    test_add_user_expiry
    
    # Group tests
    test_add_group_text
    test_add_group_json
    
    # View tests
    test_view_user
    test_view_users
    test_view_group
    test_view_groups
    test_view_summary
    test_view_recent
    
    # Update tests
    test_update_password
    test_update_shell
    test_update_groups
    test_update_comment
    
    # Lock/unlock
    test_lock_unlock
    
    # Delete tests
    test_delete_check
    test_delete_backup
    test_delete_batch_text
    test_delete_batch_json
    
    # Search tests
    test_search_users
    test_search_groups
    test_search_json
    
    # JSON operations
    test_apply_roles
    test_manage_groups_json
    
    # Reports
    test_report_security
    test_report_compliance
    test_report_activity
    test_report_storage
    test_report_json
    
    # Exports
    test_export_csv
    test_export_json
    test_export_tsv
    test_export_all
    
    # Safety
    test_dry_run
    test_validation
}

run_quick_tests() {
    print_header "Quick Smoke Test"
    
    test_version
    test_help
    test_add_user_text
    test_add_group_text
    test_view_users
    test_view_groups
    test_update_password
    test_lock_unlock
    test_delete_check
    test_dry_run
}

run_user_tests() {
    print_header "User Management Tests Only"
    
    test_add_user_text
    test_add_user_json
    test_add_user_random
    test_add_user_sudo
    test_add_user_expiry
    test_view_user
    test_view_users
    test_update_password
    test_update_shell
    test_update_groups
    test_update_comment
    test_lock_unlock
    test_delete_check
    test_delete_backup
    test_delete_batch_text
    test_delete_batch_json
}

run_group_tests() {
    print_header "Group Management Tests Only"
    
    test_add_group_text
    test_add_group_json
    test_view_group
    test_view_groups
    test_manage_groups_json
}

run_json_tests() {
    print_header "JSON Operations Tests Only"
    
    if ! command -v jq &> /dev/null; then
        echo "jq not installed - skipping JSON tests"
        return
    fi
    
    test_add_user_json
    test_add_group_json
    test_delete_batch_json
    test_search_json
    test_apply_roles
    test_manage_groups_json
    test_report_json
    test_export_json
    test_export_all
}

run_report_tests() {
    print_header "Report Generation Tests Only"
    
    test_report_security
    test_report_compliance
    test_report_activity
    test_report_storage
    test_report_json
}

# Show results
show_results() {
    echo ""
    print_header "Test Results"
    
    echo "Tests Run:     $TESTS_RUN"
    echo -e "Tests Passed:  ${GREEN}$TESTS_PASSED${NC}"
    [ $TESTS_FAILED -gt 0 ] && echo -e "Tests Failed:  ${RED}$TESTS_FAILED${NC}" || echo "Tests Failed:  0"
    [ $TESTS_SKIPPED -gt 0 ] && echo -e "Tests Skipped: ${YELLOW}$TESTS_SKIPPED${NC}" || echo "Tests Skipped: 0"
    
    local pass_rate=0
    if [ $TESTS_RUN -gt 0 ]; then
        pass_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    echo ""
    echo "Success Rate: ${pass_rate}%"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
        echo ""
        echo "Phase 1 is production-ready!"
    else
        echo -e "${RED}✗ SOME TESTS FAILED${NC}"
        echo ""
        echo "Review failures above and check:"
        echo "  - Test log: $TEST_LOG"
        echo "  - System log: /var/log/user_mgmt.log"
    fi
    
    echo ""
    echo "Test log: $TEST_LOG"
}

# Main execution
main() {
    print_header "Phase 1 Test Suite v1.0.3"
    echo "Independent Tests - No Dependencies"
    echo ""
    
    preflight_checks
    
    case "$TEST_COMMAND" in
        all)
            run_all_tests
            ;;
        quick)
            run_quick_tests
            ;;
        user-only)
            run_user_tests
            ;;
        group-only)
            run_group_tests
            ;;
        json-only)
            run_json_tests
            ;;
        reports-only)
            run_report_tests
            ;;
        
        # Individual tests
        version) test_version ;;
        help) test_help ;;
        config) test_config ;;
        icons) test_icons ;;
        
        add-user-text) test_add_user_text ;;
        add-user-json) test_add_user_json ;;
        add-user-random) test_add_user_random ;;
        add-user-sudo) test_add_user_sudo ;;
        add-user-expiry) test_add_user_expiry ;;
        
        add-group-text) test_add_group_text ;;
        add-group-json) test_add_group_json ;;
        
        view-user) test_view_user ;;
        view-users) test_view_users ;;
        view-group) test_view_group ;;
        view-groups) test_view_groups ;;
        view-summary) test_view_summary ;;
        view-recent) test_view_recent ;;
        
        update-password) test_update_password ;;
        update-shell) test_update_shell ;;
        update-groups) test_update_groups ;;
        update-comment) test_update_comment ;;
        
        lock-unlock) test_lock_unlock ;;
        
        delete-check) test_delete_check ;;
        delete-backup) test_delete_backup ;;
        delete-batch-text) test_delete_batch_text ;;
        delete-batch-json) test_delete_batch_json ;;
        
        search-users) test_search_users ;;
        search-groups) test_search_groups ;;
        search-json) test_search_json ;;
        
        apply-roles) test_apply_roles ;;
        manage-groups-json) test_manage_groups_json ;;
        
        report-security) test_report_security ;;
        report-compliance) test_report_compliance ;;
        report-activity) test_report_activity ;;
        report-storage) test_report_storage ;;
        report-json) test_report_json ;;
        
        export-csv) test_export_csv ;;
        export-json) test_export_json ;;
        export-tsv) test_export_tsv ;;
        export-all) test_export_all ;;
        
        dry-run) test_dry_run ;;
        validation) test_validation ;;
        
        *)
            echo "Unknown test: $TEST_COMMAND"
            echo ""
            echo "Run: sudo ./test_phase1.sh --help"
            exit 2
            ;;
    esac
    
    show_results
    
    if ! $NO_CLEANUP; then
        cleanup_all
    fi
    
    [ $TESTS_FAILED -eq 0 ] && exit 0 || exit 1
}

# Run main
main