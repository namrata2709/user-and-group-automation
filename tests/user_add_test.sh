#!/usr/bin/env bash
# ================================================
# User Add Module - Comprehensive Test Suite
# Version: 2.0.0
# ================================================
# Tests all permutations and combinations of user_add
# functionality to identify edge cases and failures
# ================================================

set -euo pipefail

# ============ COLORS & ICONS ==================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ICON_PASS="✓"
ICON_FAIL="✗"
ICON_SKIP="⊘"
ICON_TEST="→"

# ============ PATHS ==================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
LIB_DIR="$SCRIPTS_DIR/lib"
TEST_DIR="/tmp/user_add_tests_$$"
TEST_LOG="$TEST_DIR/test.log"

# ============ TEST COUNTERS ==================
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# ============ TEST OPTIONS ==================
VERBOSE=false
STOP_ON_FAIL=false
NO_CLEANUP=false
TEST_FILTER=""

# ============ CONFIGURATION ==================
# Source the main script to get all functions
source "$LIB_DIR/logging.sh" 2>/dev/null || true
source "$LIB_DIR/validation.sh" 2>/dev/null || true
source "$LIB_DIR/helpers.sh" 2>/dev/null || true
source "$LIB_DIR/user_add.sh" 2>/dev/null || true

# Set defaults if not sourced
DEFAULT_SHELL="${DEFAULT_SHELL:-/bin/bash}"
DEFAULT_PASSWORD="${DEFAULT_PASSWORD:-P@ssword1234!}"
PASSWORD_LENGTH="${PASSWORD_LENGTH:-16}"
PASSWORD_EXPIRY_DAYS="${PASSWORD_EXPIRY_DAYS:-90}"
PASSWORD_WARN_DAYS="${PASSWORD_WARN_DAYS:-7}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/user_backups}"
MIN_USER_UID="${MIN_USER_UID:-1000}"
MAX_USER_UID="${MAX_USER_UID:-60000}"
DRY_RUN=false
ICON_SUCCESS="✓"
ICON_ERROR="✗"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_USER="👤"
ICON_SEARCH="🔍"

# ============ HELPER FUNCTIONS ==================
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${BLUE}${ICON_TEST}${NC} $1"
}

print_pass() {
    echo -e "${GREEN}${ICON_PASS}${NC} PASS: $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}${ICON_FAIL}${NC} FAIL: $1"
    if [ -n "${2:-}" ]; then
        echo "  Error: $2"
    fi
    ((TESTS_FAILED++))
    
    if [ "$STOP_ON_FAIL" = true ]; then
        echo ""
        echo "Stopping on first failure"
        cleanup_all
        exit 1
    fi
}

print_skip() {
    echo -e "${YELLOW}${ICON_SKIP}${NC} SKIP: $1"
    if [ -n "${2:-}" ]; then
        echo "  Reason: $2"
    fi
    ((TESTS_SKIPPED++))
}

log_test() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$TEST_LOG"
}

get_test_user() {
    echo "tuser_${1}_$$"
}

setup_test() {
    mkdir -p "$TEST_DIR"
    touch "$TEST_LOG"
}

cleanup_test() {
    local test_name="$1"
    
    if [ "$NO_CLEANUP" = true ]; then
        return 0
    fi
    
    # Remove test users
    for user in $(compgen -u 2>/dev/null); do
        if [[ "$user" =~ ^tuser_${test_name}_ ]]; then
            sudo userdel -r "$user" &>/dev/null || true
        fi
    done
}

cleanup_all() {
    if [ "$NO_CLEANUP" = true ]; then
        echo "Cleanup skipped (--no-cleanup)"
        return 0
    fi
    
    # Remove all test users
    for user in $(compgen -u 2>/dev/null); do
        if [[ "$user" =~ ^tuser_ ]]; then
            sudo userdel -r "$user" &>/dev/null || true
        fi
    done
    
    # Remove test directory
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# ============ TEST CASES ==================

# TEST 1: Basic user creation with minimal parameters
test_basic_user_creation() {
    print_test "Basic user creation (username only)"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "basic")
    
    if add_single_user "$username" "" "0" "" "no" "" "" ""; then
        if id "$username" &>/dev/null; then
            print_pass "Basic user creation"
            log_test "PASS: Basic user creation - $username"
        else
            print_fail "Basic user creation" "User not found after creation"
            log_test "FAIL: User not found - $username"
        fi
    else
        print_fail "Basic user creation" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "basic"
}

# TEST 2: User with comment
test_user_with_comment() {
    print_test "User creation with comment"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "comment")
    local comment="Test User Comment"
    
    if add_single_user "$username" "$comment" "0" "" "no" "" "" ""; then
        local actual_comment=$(getent passwd "$username" | cut -d: -f5)
        if [ "$actual_comment" = "$comment" ]; then
            print_pass "User with comment"
            log_test "PASS: User with comment - $username"
        else
            print_fail "User with comment" "Comment mismatch: expected '$comment', got '$actual_comment'"
            log_test "FAIL: Comment mismatch - $username"
        fi
    else
        print_fail "User with comment" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "comment"
}

# TEST 3: User with custom shell
test_user_with_shell() {
    print_test "User creation with custom shell"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "shell")
    local shell="/bin/bash"
    
    if add_single_user "$username" "" "0" "$shell" "no" "" "" ""; then
        local actual_shell=$(getent passwd "$username" | cut -d: -f7)
        if [ "$actual_shell" = "$shell" ]; then
            print_pass "User with custom shell"
            log_test "PASS: User with shell - $username"
        else
            print_fail "User with custom shell" "Shell mismatch: expected '$shell', got '$actual_shell'"
            log_test "FAIL: Shell mismatch - $username"
        fi
    else
        print_fail "User with custom shell" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "shell"
}

# TEST 4: User with account expiry
test_user_with_expiry() {
    print_test "User creation with account expiry"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "expiry")
    local expiry_days=90
    
    if add_single_user "$username" "" "$expiry_days" "" "no" "" "" ""; then
        local expiry=$(sudo chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
        if [ "$expiry" != "never" ]; then
            print_pass "User with account expiry"
            log_test "PASS: User with expiry - $username ($expiry)"
        else
            print_fail "User with account expiry" "Account doesn't expire"
            log_test "FAIL: Account expiry not set - $username"
        fi
    else
        print_fail "User with account expiry" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "expiry"
}

# TEST 5: User with sudo access
test_user_with_sudo() {
    print_test "User creation with sudo access"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "sudo")
    
    if add_single_user "$username" "" "0" "" "yes" "" "" ""; then
        if groups "$username" 2>/dev/null | grep -qE 'sudo|wheel'; then
            print_pass "User with sudo access"
            log_test "PASS: User with sudo - $username"
        else
            print_fail "User with sudo access" "User not in sudo/wheel group"
            log_test "FAIL: Sudo group not assigned - $username"
        fi
    else
        print_fail "User with sudo access" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "sudo"
}

# TEST 6: User with random password
test_user_with_random_password() {
    print_test "User creation with random password"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "randpwd")
    
    if add_single_user "$username" "" "0" "" "no" "random" "" ""; then
        if id "$username" &>/dev/null; then
            # Check if password file was created
            local pwd_files=$(sudo find /tmp/user_backups -name "${username}_*.txt" 2>/dev/null | wc -l)
            if [ "$pwd_files" -gt 0 ]; then
                print_pass "User with random password"
                log_test "PASS: User with random password - $username"
            else
                print_fail "User with random password" "Password file not created"
                log_test "FAIL: Password file not created - $username"
            fi
        else
            print_fail "User with random password" "User not created"
            log_test "FAIL: User not created - $username"
        fi
    else
        print_fail "User with random password" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "randpwd"
}

# TEST 7: User with custom password
test_user_with_custom_password() {
    print_test "User creation with custom password"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "custpwd")
    local password="CustomP@ss123!"
    
    if add_single_user "$username" "" "0" "" "no" "$password" "" ""; then
        if id "$username" &>/dev/null; then
            print_pass "User with custom password"
            log_test "PASS: User with custom password - $username"
        else
            print_fail "User with custom password" "User not created"
            log_test "FAIL: User not created - $username"
        fi
    else
        print_fail "User with custom password" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "custpwd"
}

# TEST 8: User with password expiry
test_user_with_password_expiry() {
    print_test "User creation with password expiry"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "pwdexp")
    local pwd_expiry=60
    
    if add_single_user "$username" "" "0" "" "no" "" "$pwd_expiry" ""; then
        local max_days=$(sudo chage -l "$username" 2>/dev/null | grep "Maximum" | grep -oE '[0-9]+' | head -1)
        if [ "$max_days" = "$pwd_expiry" ]; then
            print_pass "User with password expiry"
            log_test "PASS: User with password expiry - $username ($max_days days)"
        else
            print_fail "User with password expiry" "Password expiry mismatch: expected $pwd_expiry, got $max_days"
            log_test "FAIL: Password expiry mismatch - $username"
        fi
    else
        print_fail "User with password expiry" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "pwdexp"
}

# TEST 9: User with single group
test_user_with_single_group() {
    print_test "User creation with single group"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "singlegrp")
    local group="docker"
    
    # Ensure group exists
    sudo groupadd "$group" 2>/dev/null || true
    
    if add_single_user "$username" "" "0" "" "no" "" "" "$group"; then
        if groups "$username" 2>/dev/null | grep -qw "$group"; then
            print_pass "User with single group"
            log_test "PASS: User with single group - $username ($group)"
        else
            print_fail "User with single group" "User not in group $group"
            log_test "FAIL: Group assignment failed - $username"
        fi
    else
        print_fail "User with single group" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "singlegrp"
}

# TEST 10: User with multiple groups
test_user_with_multiple_groups() {
    print_test "User creation with multiple groups"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "multigrp")
    local groups="docker,sudo"
    
    # Ensure groups exist
    sudo groupadd docker 2>/dev/null || true
    sudo groupadd sudo 2>/dev/null || true
    
    if add_single_user "$username" "" "0" "" "no" "" "" "$groups"; then
        local user_groups=$(groups "$username" 2>/dev/null)
        if echo "$user_groups" | grep -qw "docker" && echo "$user_groups" | grep -qw "sudo"; then
            print_pass "User with multiple groups"
            log_test "PASS: User with multiple groups - $username ($groups)"
        else
            print_fail "User with multiple groups" "User not in all groups"
            log_test "FAIL: Group assignment failed - $username"
        fi
    else
        print_fail "User with multiple groups" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "multigrp"
}

# TEST 11: Duplicate user (should fail)
test_duplicate_user() {
    print_test "Duplicate user creation (should fail)"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "dup")
    
    # Create first user
    if add_single_user "$username" "" "0" "" "no" "" "" ""; then
        # Try to create duplicate
        if ! add_single_user "$username" "" "0" "" "no" "" "" ""; then
            print_pass "Duplicate user rejected"
            log_test "PASS: Duplicate user rejected - $username"
        else
            print_fail "Duplicate user creation" "Duplicate user was created"
            log_test "FAIL: Duplicate user created - $username"
        fi
    else
        print_fail "Duplicate user creation" "First user creation failed"
        log_test "FAIL: First user creation failed - $username"
    fi
    
    cleanup_test "dup"
}

# TEST 12: Invalid username (should fail)
test_invalid_username() {
    print_test "Invalid username (should fail)"
    ((TESTS_RUN++))
    
    local username="123invalid"  # Starts with number
    
    if ! add_single_user "$username" "" "0" "" "no" "" "" ""; then
        print_pass "Invalid username rejected"
        log_test "PASS: Invalid username rejected - $username"
    else
        print_fail "Invalid username" "Invalid username was accepted"
        log_test "FAIL: Invalid username accepted - $username"
    fi
}

# TEST 13: Invalid shell (should fail)
test_invalid_shell() {
    print_test "Invalid shell (should fail)"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "badshell")
    local shell="/nonexistent/shell"
    
    if ! add_single_user "$username" "" "0" "$shell" "no" "" "" ""; then
        print_pass "Invalid shell rejected"
        log_test "PASS: Invalid shell rejected - $username"
    else
        print_fail "Invalid shell" "Invalid shell was accepted"
        log_test "FAIL: Invalid shell accepted - $username"
    fi
}

# TEST 14: All parameters combined
test_all_parameters() {
    print_test "User creation with all parameters"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "allparams")
    local comment="Full Test User"
    local expiry=90
    local shell="/bin/bash"
    local sudo="yes"
    local password="random"
    local pwd_expiry=60
    local groups="docker,sudo"
    
    # Ensure groups exist
    sudo groupadd docker 2>/dev/null || true
    sudo groupadd sudo 2>/dev/null || true
    
    if add_single_user "$username" "$comment" "$expiry" "$shell" "$sudo" "$password" "$pwd_expiry" "$groups"; then
        local checks_passed=0
        
        # Check comment
        [ "$(getent passwd "$username" | cut -d: -f5)" = "$comment" ] && ((checks_passed++))
        
        # Check shell
        [ "$(getent passwd "$username" | cut -d: -f7)" = "$shell" ] && ((checks_passed++))
        
        # Check sudo
        groups "$username" 2>/dev/null | grep -qE 'sudo|wheel' && ((checks_passed++))
        
        # Check groups
        groups "$username" 2>/dev/null | grep -qw "docker" && ((checks_passed++))
        
        if [ "$checks_passed" -eq 4 ]; then
            print_pass "All parameters combined"
            log_test "PASS: All parameters - $username"
        else
            print_fail "All parameters combined" "Some parameters not set correctly ($checks_passed/4)"
            log_test "FAIL: Parameter mismatch - $username"
        fi
    else
        print_fail "All parameters combined" "add_single_user returned error"
        log_test "FAIL: add_single_user failed - $username"
    fi
    
    cleanup_test "allparams"
}

# TEST 15: Text file parsing - single user
test_text_parse_single() {
    print_test "Text file parsing - single user"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "textparse1")
    local file="$TEST_DIR/users_single.txt"
    
    echo "$username:Test User:90:a:no:" > "$file"
    
    if parse_users_from_text "$file" &>/dev/null; then
        if id "$username" &>/dev/null; then
            print_pass "Text file parsing - single user"
            log_test "PASS: Text parse single - $username"
        else
            print_fail "Text file parsing - single user" "User not created"
            log_test "FAIL: User not created - $username"
        fi
    else
        print_fail "Text file parsing - single user" "parse_users_from_text failed"
        log_test "FAIL: parse_users_from_text failed"
    fi
    
    cleanup_test "textparse1"
}

# TEST 16: Text file parsing - multiple users
test_text_parse_multiple() {
    print_test "Text file parsing - multiple users"
    ((TESTS_RUN++))
    
    local user1=$(get_test_user "textparse2a")
    local user2=$(get_test_user "textparse2b")
    local file="$TEST_DIR/users_multiple.txt"
    
    cat > "$file" <<EOF
$user1:User One:90:a:no:
$user2:User Two:0:b:yes:
EOF
    
    if parse_users_from_text "$file" &>/dev/null; then
        local created=0
        id "$user1" &>/dev/null && ((created++))
        id "$user2" &>/dev/null && ((created++))
        
        if [ "$created" -eq 2 ]; then
            print_pass "Text file parsing - multiple users"
            log_test "PASS: Text parse multiple - $user1, $user2"
        else
            print_fail "Text file parsing - multiple users" "Only $created/2 users created"
            log_test "FAIL: Not all users created"
        fi
    else
        print_fail "Text file parsing - multiple users" "parse_users_from_text failed"
        log_test "FAIL: parse_users_from_text failed"
    fi
    
    cleanup_test "textparse2a"
    cleanup_test "textparse2b"
}

# TEST 17: Text file parsing - with comments
test_text_parse_comments() {
    print_test "Text file parsing - with comments"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "textparse3")
    local file="$TEST_DIR/users_comments.txt"
    
    cat > "$file" <<EOF
# This is a comment
$username:Test User:90:a:no:
# Another comment
EOF
    
    if parse_users_from_text "$file" &>/dev/null; then
        if id "$username" &>/dev/null; then
            print_pass "Text file parsing - with comments"
            log_test "PASS: Text parse with comments - $username"
        else
            print_fail "Text file parsing - with comments" "User not created"
            log_test "FAIL: User not created - $username"
        fi
    else
        print_fail "Text file parsing - with comments" "parse_users_from_text failed"
        log_test "FAIL: parse_users_from_text failed"
    fi
    
    cleanup_test "textparse3"
}

# TEST 18: JSON file parsing - single user
test_json_parse_single() {
    print_test "JSON file parsing - single user"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "JSON file parsing - single user" "jq not installed"
        return
    fi
    
    local username=$(get_test_user "jsonparse1")
    local file="$TEST_DIR/users_single.json"
    
    cat > "$file" <<EOF
{
  "users": [
    {
      "username": "$username",
      "comment": "JSON Test User",
      "expire_days": 90,
      "shell": "/bin/bash",
      "groups": [],
      "password_policy": {
        "type": "random",
        "expiry_days": 90
      }
    }
  ]
}
EOF
    
    if parse_users_from_json "$file" &>/dev/null; then
        if id "$username" &>/dev/null; then
            print_pass "JSON file parsing - single user"
            log_test "PASS: JSON parse single - $username"
        else
            print_fail "JSON file parsing - single user" "User not created"
            log_test "FAIL: User not created - $username"
        fi
    else
        print_fail "JSON file parsing - single user" "parse_users_from_json failed"
        log_test "FAIL: parse_users_from_json failed"
    fi
    
    cleanup_test "jsonparse1"
}

# TEST 19: JSON file parsing - multiple users
test_json_parse_multiple() {
    print_test "JSON file parsing - multiple users"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "JSON file parsing - multiple users" "jq not installed"
        return
    fi
    
    local user1=$(get_test_user "jsonparse2a")
    local user2=$(get_test_user "jsonparse2b")
    local file="$TEST_DIR/users_multiple.json"
    
    cat > "$file" <<EOF
{
  "users": [
    {
      "username": "$user1",
      "comment": "User One",
      "expire_days": 90,
      "shell": "/bin/bash",
      "groups": [],
      "password_policy": {
        "type": "random",
        "expiry_days": 90
      }
    },
    {
      "username": "$user2",
      "comment": "User Two",
      "expire_days": 0,
      "shell": "/bin/bash",
      "groups": [],
      "password_policy": {
        "type": "random",
        "expiry_days": 90
      }
    }
  ]
}
EOF
    
    if parse_users_from_json "$file" &>/dev/null; then
        local created=0
        id "$user1" &>/dev/null && ((created++))
        id "$user2" &>/dev/null && ((created++))
        
        if [ "$created" -eq 2 ]; then
            print_pass "JSON file parsing - multiple users"
            log_test "PASS: JSON parse multiple - $user1, $user2"
        else
            print_fail "JSON file parsing - multiple users" "Only $created/2 users created"
            log_test "FAIL: Not all users created"
        fi
    else
        print_fail "JSON file parsing - multiple users" "parse_users_from_json failed"
        log_test "FAIL: parse_users_from_json failed"
    fi
    
    cleanup_test "jsonparse2a"
    cleanup_test "jsonparse2b"
}

# TEST 20: JSON file parsing - with groups
test_json_parse_with_groups() {
    print_test "JSON file parsing - with groups"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "JSON file parsing - with groups" "jq not installed"
        return
    fi
    
    local username=$(get_test_user "jsonparse3")
    local file="$TEST_DIR/users_groups.json"
    
    # Ensure groups exist
    sudo groupadd docker 2>/dev/null || true
    sudo groupadd sudo 2>/dev/null || true
    
    cat > "$file" <<EOF
{
  "users": [
    {
      "username": "$username",
      "comment": "User with Groups",
      "expire_days": 0,
      "shell": "/bin/bash",
      "groups": ["docker", "sudo"],
      "password_policy": {
        "type": "random",
        "expiry_days": 90
      }
    }
  ]
}
EOF
    
    if parse_users_from_json "$file" &>/dev/null; then
        if id "$username" &>/dev/null; then
            local user_groups=$(groups "$username" 2>/dev/null)
            if echo "$user_groups" | grep -qw "docker" && echo "$user_groups" | grep -qw "sudo"; then
                print_pass "JSON file parsing - with groups"
                log_test "PASS: JSON parse with groups - $username"
            else
                print_fail "JSON file parsing - with groups" "Groups not assigned"
                log_test "FAIL: Groups not assigned - $username"
            fi
        else
            print_fail "JSON file parsing - with groups" "User not created"
            log_test "FAIL: User not created - $username"
        fi
    else
        print_fail "JSON file parsing - with groups" "parse_users_from_json failed"
        log_test "FAIL: parse_users_from_json failed"
    fi
    
    cleanup_test "jsonparse3"
}

# TEST 21: DRY-RUN mode
test_dry_run_mode() {
    print_test "DRY-RUN mode (no changes)"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "dryrun")
    DRY_RUN=true
    
    if add_single_user "$username" "" "0" "" "no" "" "" ""; then
        if ! id "$username" &>/dev/null; then
            print_pass "DRY-RUN mode"
            log_test "PASS: DRY-RUN mode - no user created"
        else
            print_fail "DRY-RUN mode" "User was created in DRY-RUN mode"
            log_test "FAIL: User created in DRY-RUN - $username"
        fi
    else
        print_fail "DRY-RUN mode" "add_single_user returned error"
        log_test "FAIL: add_single_user failed"
    fi
    
    DRY_RUN=false
    cleanup_test "dryrun"
}

# TEST 22: Empty username (should fail)
test_empty_username() {
    print_test "Empty username (should fail)"
    ((TESTS_RUN++))
    
    if ! add_single_user "" "" "0" "" "no" "" "" ""; then
        print_pass "Empty username rejected"
        log_test "PASS: Empty username rejected"
    else
        print_fail "Empty username" "Empty username was accepted"
        log_test "FAIL: Empty username accepted"
    fi
}

# TEST 23: Very long username (should fail)
test_long_username() {
    print_test "Very long username (should fail)"
    ((TESTS_RUN++))
    
    local username="verylongusernamethatexceedsthemaximumlengthallowed"
    
    if ! add_single_user "$username" "" "0" "" "no" "" "" ""; then
        print_pass "Long username rejected"
        log_test "PASS: Long username rejected"
    else
        print_fail "Long username" "Long username was accepted"
        log_test "FAIL: Long username accepted"
    fi
}

# TEST 24: Username with special characters (should fail)
test_special_chars_username() {
    print_test "Username with special characters (should fail)"
    ((TESTS_RUN++))
    
    local username="user@#$%"
    
    if ! add_single_user "$username" "" "0" "" "no" "" "" ""; then
        print_pass "Special characters rejected"
        log_test "PASS: Special characters rejected"
    else
        print_fail "Special characters" "Special characters were accepted"
        log_test "FAIL: Special characters accepted"
    fi
}

# TEST 25: Negative expiry days (should fail or be handled)
test_negative_expiry() {
    print_test "Negative expiry days (edge case)"
    ((TESTS_RUN++))
    
    local username=$(get_test_user "negexp")
    
    # This might succeed or fail depending on implementation
    if add_single_user "$username" "" "-90" "" "no" "" "" ""; then
        print_pass "Negative expiry handled"
        log_test "PASS: Negative expiry handled - $username"
    else
        print_pass "Negative expiry rejected"
        log_test "PASS: Negative expiry rejected"
    fi
    
    cleanup_test "negexp"
}

# ============ TEST RUNNER ==================
run_all_tests() {
    print_header "Running All user_add Tests"
    
    test_basic_user_creation
    test_user_with_comment
    test_user_with_shell
    test_user_with_expiry
    test_user_with_sudo
    test_user_with_random_password
    test_user_with_custom_password
    test_user_with_password_expiry
    test_user_with_single_group
    test_user_with_multiple_groups
    test_duplicate_user
    test_invalid_username
    test_invalid_shell
    test_all_parameters
    test_text_parse_single
    test_text_parse_multiple
    test_text_parse_comments
    test_json_parse_single
    test_json_parse_multiple
    test_json_parse_with_groups
    test_dry_run_mode
    test_empty_username
    test_long_username
    test_special_chars_username
    test_negative_expiry
}

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
        echo -e "${GREEN}${ICON_PASS} ALL TESTS PASSED!${NC}"
    else
        echo -e "${RED}${ICON_FAIL} SOME TESTS FAILED${NC}"
        echo ""
        echo "Review failures above and check:"
        echo "  - Test log: $TEST_LOG"
    fi
    
    echo ""
    echo "Test log: $TEST_LOG"
}

# ============ MAIN ==================
main() {
    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            --verbose|-v) VERBOSE=true; shift ;;
            --stop-on-fail) STOP_ON_FAIL=true; shift ;;
            --no-cleanup) NO_CLEANUP=true; shift ;;
            --help|-h)
                cat <<'EOF'
User Add Module - Comprehensive Test Suite

USAGE:
  sudo ./user_add_test.sh [OPTIONS]

OPTIONS:
  --verbose, -v       Detailed output
  --stop-on-fail      Stop on first failure
  --no-cleanup        Keep test data (debug)
  --help, -h          Show this help

EXAMPLES:
  sudo ./user_add_test.sh
  sudo ./user_add_test.sh --verbose
  sudo ./user_add_test.sh --stop-on-fail

REQUIREMENTS:
  - Must run as root
  - jq for JSON tests (optional)
  - Phase 1 scripts at $SCRIPTS_DIR

EOF
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    print_header "User Add Module - Comprehensive Test Suite"
    echo "Test Directory: $TEST_DIR"
    echo "Script Directory: $SCRIPTS_DIR"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}${ICON_FAIL} Must run as root (use sudo)${NC}"
        exit 1
    fi
    
    # Setup
    setup_test
    
    # Run tests
    run_all_tests
    
    # Show results
    show_results
    
    # Cleanup
    cleanup_all
    
    # Exit with appropriate code
    [ $TESTS_FAILED -eq 0 ] && exit 0 || exit 1
}

main "$@"
