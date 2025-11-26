#!/usr/bin/env bash
# ================================================
# Phase 1 - Comprehensive Test Suite
# Version: 1.0.1
# ================================================
# Tests all major functionality
# Usage: sudo ./test_phase1.sh [test_name|all]
# ================================================

set -euo pipefail

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
TEST_USERS_FILE="/tmp/test_users.txt"
TEST_GROUPS_FILE="/tmp/test_groups.txt"
TEST_JSON_FILE="/tmp/test_users.json"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test user names
TEST_USER1="testuser001"
TEST_USER2="testuser002"
TEST_USER3="testuser003"
TEST_GROUP1="testgroup001"
TEST_GROUP2="testgroup002"

# Print functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${BLUE}→${NC} Testing: $1"
}

print_pass() {
    echo -e "${GREEN}✓${NC} PASS: $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗${NC} FAIL: $1"
    echo "  Error: $2"
    ((TESTS_FAILED++))
}

print_skip() {
    echo -e "${YELLOW}⊘${NC} SKIP: $1"
    ((TESTS_SKIPPED++))
}

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$TEST_LOG"
}

# Cleanup function
cleanup_test_data() {
    echo ""
    print_header "Cleaning Up Test Data"
    
    # Delete test users
    for user in $TEST_USER1 $TEST_USER2 $TEST_USER3; do
        if id "$user" &>/dev/null; then
            sudo userdel -r "$user" &>/dev/null || true
            echo "Removed user: $user"
        fi
    done
    
    # Delete test groups
    for group in $TEST_GROUP1 $TEST_GROUP2; do
        if getent group "$group" &>/dev/null; then
            sudo groupdel "$group" &>/dev/null || true
            echo "Removed group: $group"
        fi
    done
    
    # Remove temp files
    rm -f "$TEST_USERS_FILE" "$TEST_GROUPS_FILE" "$TEST_JSON_FILE"
    rm -f /tmp/test_export_*.{csv,json,tsv,txt}
    
    echo "Cleanup complete"
}

# Pre-flight checks
preflight_checks() {
    print_header "Pre-Flight Checks"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}✗${NC} Must run as root (use sudo)"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Running as root"
    
    # Check if script exists
    if [ ! -f "$USER_SCRIPT" ]; then
        echo -e "${RED}✗${NC} user.sh not found at: $USER_SCRIPT"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} user.sh found"
    
    # Check if script is executable
    if [ ! -x "$USER_SCRIPT" ]; then
        echo -e "${YELLOW}⚠${NC} Making user.sh executable"
        chmod +x "$USER_SCRIPT"
    fi
    echo -e "${GREEN}✓${NC} user.sh is executable"
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} jq not installed (JSON tests will be skipped)"
    else
        echo -e "${GREEN}✓${NC} jq is installed"
    fi
    
    # Create test log
    touch "$TEST_LOG"
    echo -e "${GREEN}✓${NC} Test log: $TEST_LOG"
    
    echo ""
}

# Test: Script version
test_version() {
    print_test "Script version"
    ((TESTS_RUN++))
    
    if sudo "$USER_SCRIPT" --version &>/dev/null; then
        local version=$(sudo "$USER_SCRIPT" --version | head -1)
        print_pass "Version check ($version)"
        log "Version: $version"
    else
        print_fail "Version check" "Command failed"
    fi
}

# Test: Help system
test_help() {
    print_test "Help system"
    ((TESTS_RUN++))
    
    if sudo "$USER_SCRIPT" --help &>/dev/null; then
        print_pass "Help system displays"
    else
        print_fail "Help system" "Help command failed"
    fi
}

# Test: Config loading
test_config() {
    print_test "Configuration loading"
    ((TESTS_RUN++))
    
    # Run any command to trigger config loading
    if sudo "$USER_SCRIPT" --view summary &>/dev/null; then
        print_pass "Config loads without errors"
    else
        print_fail "Config loading" "Config has errors"
    fi
}

# Test: Add user (text file)
test_add_user_text() {
    print_test "Add user from text file"
    ((TESTS_RUN++))
    
    # Create test file
    echo "$TEST_USER1:Test User 1:90:a:no:" > "$TEST_USERS_FILE"
    
    if sudo "$USER_SCRIPT" --add user --names "$TEST_USERS_FILE" &>/dev/null; then
        if id "$TEST_USER1" &>/dev/null; then
            print_pass "User created from text file"
            log "Created user: $TEST_USER1"
        else
            print_fail "Add user (text)" "User not found after creation"
        fi
    else
        print_fail "Add user (text)" "Command failed"
    fi
}

# Test: Add user with random password
test_add_user_random_password() {
    print_test "Add user with random password"
    ((TESTS_RUN++))
    
    echo "$TEST_USER2:Test User 2:::no:random" > "$TEST_USERS_FILE"
    
    if sudo "$USER_SCRIPT" --add user --names "$TEST_USERS_FILE" &>/dev/null; then
        if id "$TEST_USER2" &>/dev/null; then
            # Check if password file was created
            local pwd_files=$(sudo find /var/backups/passwords -name "${TEST_USER2}_*.txt" 2>/dev/null | wc -l)
            if [ "$pwd_files" -gt 0 ]; then
                print_pass "Random password generated and saved"
            else
                print_fail "Random password" "Password file not created"
            fi
        else
            print_fail "Random password" "User not created"
        fi
    else
        print_fail "Random password" "Command failed"
    fi
}

# Test: Add user (JSON)
test_add_user_json() {
    print_test "Add user from JSON"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "JSON test (jq not installed)"
        return
    fi
    
    cat > "$TEST_JSON_FILE" <<EOF
{
  "users": [
    {
      "username": "$TEST_USER3",
      "comment": "Test User 3",
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
    
    if sudo "$USER_SCRIPT" --add user --input "$TEST_JSON_FILE" --format json &>/dev/null; then
        if id "$TEST_USER3" &>/dev/null; then
            print_pass "User created from JSON"
            log "Created user from JSON: $TEST_USER3"
        else
            print_fail "Add user (JSON)" "User not found"
        fi
    else
        print_fail "Add user (JSON)" "Command failed"
    fi
}

# Test: View users
test_view_users() {
    print_test "View users"
    ((TESTS_RUN++))
    
    if sudo "$USER_SCRIPT" --view users &>/dev/null; then
        print_pass "View users command works"
    else
        print_fail "View users" "Command failed"
    fi
}

# Test: View user details
test_view_user_details() {
    print_test "View user details"
    ((TESTS_RUN++))
    
    if id "$TEST_USER1" &>/dev/null; then
        if sudo "$USER_SCRIPT" --view user --name "$TEST_USER1" &>/dev/null; then
            print_pass "View user details works"
        else
            print_fail "View user details" "Command failed"
        fi
    else
        print_skip "View user details (no test user)"
    fi
}

# Test: Search users
test_search_users() {
    print_test "Search users"
    ((TESTS_RUN++))
    
    if sudo "$USER_SCRIPT" --search users --pattern "test" &>/dev/null; then
        print_pass "Search users works"
    else
        print_fail "Search users" "Command failed"
    fi
}

# Test: Lock user
test_lock_user() {
    print_test "Lock user"
    ((TESTS_RUN++))
    
    if id "$TEST_USER1" &>/dev/null; then
        if sudo "$USER_SCRIPT" --lock user --name "$TEST_USER1" &>/dev/null; then
            # Check if actually locked
            if passwd -S "$TEST_USER1" 2>/dev/null | grep -q " L "; then
                print_pass "User locked successfully"
                log "Locked user: $TEST_USER1"
            else
                print_fail "Lock user" "User not actually locked"
            fi
        else
            print_fail "Lock user" "Command failed"
        fi
    else
        print_skip "Lock user (no test user)"
    fi
}

# Test: Unlock user
test_unlock_user() {
    print_test "Unlock user"
    ((TESTS_RUN++))
    
    if id "$TEST_USER1" &>/dev/null; then
        if sudo "$USER_SCRIPT" --unlock user --name "$TEST_USER1" &>/dev/null; then
            # Check if actually unlocked
            if ! passwd -S "$TEST_USER1" 2>/dev/null | grep -q " L "; then
                print_pass "User unlocked successfully"
                log "Unlocked user: $TEST_USER1"
            else
                print_fail "Unlock user" "User still locked"
            fi
        else
            print_fail "Unlock user" "Command failed"
        fi
    else
        print_skip "Unlock user (no test user)"
    fi
}

# Test: Update user password
test_update_password() {
    print_test "Update user password"
    ((TESTS_RUN++))
    
    if id "$TEST_USER1" &>/dev/null; then
        if sudo "$USER_SCRIPT" --update user --name "$TEST_USER1" --reset-password &>/dev/null; then
            print_pass "Password reset works"
            log "Reset password: $TEST_USER1"
        else
            print_fail "Update password" "Command failed"
        fi
    else
        print_skip "Update password (no test user)"
    fi
}

# Test: Add group
test_add_group() {
    print_test "Add group"
    ((TESTS_RUN++))
    
    echo "$TEST_GROUP1" > "$TEST_GROUPS_FILE"
    
    if sudo "$USER_SCRIPT" --add group --names "$TEST_GROUPS_FILE" &>/dev/null; then
        if getent group "$TEST_GROUP1" &>/dev/null; then
            print_pass "Group created"
            log "Created group: $TEST_GROUP1"
        else
            print_fail "Add group" "Group not found"
        fi
    else
        print_fail "Add group" "Command failed"
    fi
}

# Test: Add user to group
test_add_user_to_group() {
    print_test "Add user to group"
    ((TESTS_RUN++))
    
    if id "$TEST_USER1" &>/dev/null && getent group "$TEST_GROUP1" &>/dev/null; then
        if sudo "$USER_SCRIPT" --update user --name "$TEST_USER1" --add-to-groups "$TEST_GROUP1" &>/dev/null; then
            if groups "$TEST_USER1" | grep -q "$TEST_GROUP1"; then
                print_pass "User added to group"
                log "Added $TEST_USER1 to $TEST_GROUP1"
            else
                print_fail "Add user to group" "User not in group"
            fi
        else
            print_fail "Add user to group" "Command failed"
        fi
    else
        print_skip "Add user to group (prerequisites missing)"
    fi
}

# Test: Security report
test_security_report() {
    print_test "Security report"
    ((TESTS_RUN++))
    
    if sudo "$USER_SCRIPT" --report security &>/dev/null; then
        print_pass "Security report generates"
    else
        print_fail "Security report" "Command failed"
    fi
}

# Test: Compliance report
test_compliance_report() {
    print_test "Compliance report"
    ((TESTS_RUN++))
    
    if sudo "$USER_SCRIPT" --report compliance &>/dev/null; then
        print_pass "Compliance report generates"
    else
        print_fail "Compliance report" "Command failed"
    fi
}

# Test: Activity report
test_activity_report() {
    print_test "Activity report"
    ((TESTS_RUN++))
    
    if sudo "$USER_SCRIPT" --report activity --days 30 &>/dev/null; then
        print_pass "Activity report generates"
    else
        print_fail "Activity report" "Command failed"
    fi
}

# Test: Export users (CSV)
test_export_csv() {
    print_test "Export users to CSV"
    ((TESTS_RUN++))
    
    local output="/tmp/test_export_users.csv"
    
    if sudo "$USER_SCRIPT" --export users --output "$output" --format csv &>/dev/null; then
        if [ -f "$output" ] && [ -s "$output" ]; then
            print_pass "Export to CSV works"
            rm -f "$output"
        else
            print_fail "Export CSV" "File not created or empty"
        fi
    else
        print_fail "Export CSV" "Command failed"
    fi
}

# Test: Export users (JSON)
test_export_json() {
    print_test "Export users to JSON"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "Export JSON (jq not installed)"
        return
    fi
    
    local output="/tmp/test_export_users.json"
    
    if sudo "$USER_SCRIPT" --export users --output "$output" --format json &>/dev/null; then
        if [ -f "$output" ] && jq empty "$output" &>/dev/null; then
            print_pass "Export to JSON works"
            rm -f "$output"
        else
            print_fail "Export JSON" "Invalid JSON output"
        fi
    else
        print_fail "Export JSON" "Command failed"
    fi
}

# Test: JSON output
test_json_output() {
    print_test "JSON output flag"
    ((TESTS_RUN++))
    
    if ! command -v jq &> /dev/null; then
        print_skip "JSON output (jq not installed)"
        return
    fi
    
    local output=$(sudo "$USER_SCRIPT" --view summary --json 2>/dev/null)
    
    if echo "$output" | jq empty &>/dev/null; then
        print_pass "JSON output flag works"
    else
        print_fail "JSON output" "Invalid JSON"
    fi
}

# Test: Dry-run mode
test_dry_run() {
    print_test "Dry-run mode"
    ((TESTS_RUN++))
    
    local testuser="dryruntest"
    echo "$testuser:Dry Run Test" > "$TEST_USERS_FILE"
    
    if sudo "$USER_SCRIPT" --add user --names "$TEST_USERS_FILE" --dry-run &>/dev/null; then
        if ! id "$testuser" &>/dev/null; then
            print_pass "Dry-run makes no changes"
        else
            print_fail "Dry-run" "User was actually created"
            sudo userdel -r "$testuser" &>/dev/null || true
        fi
    else
        print_fail "Dry-run" "Command failed"
    fi
}

# Test: Delete check mode
test_delete_check() {
    print_test "Delete check mode"
    ((TESTS_RUN++))
    
    if id "$TEST_USER1" &>/dev/null; then
        if sudo "$USER_SCRIPT" --delete user --name "$TEST_USER1" --check &>/dev/null; then
            if id "$TEST_USER1" &>/dev/null; then
                print_pass "Delete check doesn't delete"
            else
                print_fail "Delete check" "User was deleted"
            fi
        else
            print_fail "Delete check" "Command failed"
        fi
    else
        print_skip "Delete check (no test user)"
    fi
}

# Test: Delete user with backup
test_delete_user_backup() {
    print_test "Delete user with backup"
    ((TESTS_RUN++))
    
    if id "$TEST_USER2" &>/dev/null; then
        local backup_dir="/tmp/test_backup"
        sudo mkdir -p "$backup_dir"
        
        if sudo "$USER_SCRIPT" --delete user --name "$TEST_USER2" --backup --backup-dir "$backup_dir" --force-logout &>/dev/null; then
            # Check if user deleted
            if ! id "$TEST_USER2" &>/dev/null; then
                # Check if backup created
                if [ -d "$backup_dir/${TEST_USER2}_"* ] 2>/dev/null; then
                    print_pass "Delete with backup works"
                    sudo rm -rf "$backup_dir"
                else
                    print_fail "Delete backup" "Backup not created"
                fi
            else
                print_fail "Delete backup" "User not deleted"
            fi
        else
            print_fail "Delete backup" "Command failed"
        fi
    else
        print_skip "Delete backup (no test user)"
    fi
}

# Test: Recent logins
test_recent_logins() {
    print_test "Recent logins"
    ((TESTS_RUN++))
    
    if sudo "$USER_SCRIPT" --view recent-logins --hours 24 &>/dev/null; then
        print_pass "Recent logins displays"
    else
        print_fail "Recent logins" "Command failed"
    fi
}

# Test: System summary
test_system_summary() {
    print_test "System summary"
    ((TESTS_RUN++))
    
    if sudo "$USER_SCRIPT" --view summary &>/dev/null; then
        print_pass "System summary displays"
    else
        print_fail "System summary" "Command failed"
    fi
}

# Run all tests
run_all_tests() {
    print_header "Running All Tests"
    echo "Log file: $TEST_LOG"
    echo ""
    
    # Core tests
    test_version
    test_help
    test_config
    
    # User tests
    test_add_user_text
    test_add_user_random_password
    test_add_user_json
    test_view_users
    test_view_user_details
    test_search_users
    test_lock_user
    test_unlock_user
    test_update_password
    
    # Group tests
    test_add_group
    test_add_user_to_group
    
    # Report tests
    test_security_report
    test_compliance_report
    test_activity_report
    
    # Export tests
    test_export_csv
    test_export_json
    test_json_output
    
    # Safety tests
    test_dry_run
    test_delete_check
    test_delete_user_backup
    
    # View tests
    test_recent_logins
    test_system_summary
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
        echo "Phase 1 is ready for production deployment!"
    else
        echo -e "${RED}✗ SOME TESTS FAILED${NC}"
        echo ""
        echo "Please review the failures above and check:"
        echo "  - Test log: $TEST_LOG"
        echo "  - System log: /var/log/user_mgmt.log"
    fi
    
    echo ""
    echo "Test log saved to: $TEST_LOG"
}

# Main execution
main() {
    local test_name="${1:-all}"
    
    print_header "Phase 1 Test Suite v1.0.1"
    echo ""
    
    # Pre-flight checks
    preflight_checks
    
    # Cleanup any existing test data
    cleanup_test_data
    
    # Run tests
    case "$test_name" in
        all)
            run_all_tests
            ;;
        version)
            test_version
            ;;
        help)
            test_help
            ;;
        config)
            test_config
            ;;
        add-user)
            test_add_user_text
            test_add_user_json
            ;;
        delete-user)
            test_add_user_text
            test_delete_check
            test_delete_user_backup
            ;;
        lock)
            test_add_user_text
            test_lock_user
            test_unlock_user
            ;;
        groups)
            test_add_group
            test_add_user_text
            test_add_user_to_group
            ;;
        reports)
            test_security_report
            test_compliance_report
            test_activity_report
            ;;
        export)
            test_export_csv
            test_export_json
            ;;
        *)
            echo "Unknown test: $test_name"
            echo ""
            echo "Available tests:"
            echo "  all         - Run all tests"
            echo "  version     - Test version command"
            echo "  help        - Test help system"
            echo "  config      - Test config loading"
            echo "  add-user    - Test user creation"
            echo "  delete-user - Test user deletion"
            echo "  lock        - Test lock/unlock"
            echo "  groups      - Test group operations"
            echo "  reports     - Test all reports"
            echo "  export      - Test export functions"
            exit 1
            ;;
    esac
    
    # Show results
    show_results
    
    # Cleanup
    cleanup_test_data
    
    # Exit with appropriate code
    [ $TESTS_FAILED -eq 0 ] && exit 0 || exit 1
}

# Run main
main "$@"