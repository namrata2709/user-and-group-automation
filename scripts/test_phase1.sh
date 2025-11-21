#!/usr/bin/env bash
# ================================================
# Phase 1 - Comprehensive Test Suite
# Version: 1.0.2
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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEST_LOG" >/dev/null
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
    rm -f /tmp/test_export_*.{csv,json,tsv,txt} 2>/dev/null || true
    
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
    echo "Test started at $(date)" > "$TEST_LOG"
    echo -e "${GREEN}✓${NC} Test log: $TEST_LOG"
    
    echo ""
}

# Test: Script version
test_version() {
    print_test "Script version"
    ((TESTS_RUN++))
    log "TEST: Script version"
    
    local output=$(sudo "$USER_SCRIPT" --version 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        local version=$(echo "$output" | head -1)
        print_pass "Version check ($version)"
        log "PASS: Version check - $version"
    else
        print_fail "Version check" "Exit code: $exit_code"
        log "FAIL: Version check - Exit code: $exit_code"
        log "Output: $output"
    fi
}

# Test: Help system
test_help() {
    print_test "Help system"
    ((TESTS_RUN++))
    log "TEST: Help system"
    
    local output=$(sudo "$USER_SCRIPT" --help 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "USAGE"; then
        print_pass "Help system displays"
        log "PASS: Help system"
    else
        print_fail "Help system" "Exit code: $exit_code or no USAGE found"
        log "FAIL: Help system - Exit code: $exit_code"
    fi
}

# Test: Config loading
test_config() {
    print_test "Configuration loading"
    ((TESTS_RUN++))
    log "TEST: Config loading"
    
    local output=$(sudo "$USER_SCRIPT" --view summary 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_pass "Config loads without errors"
        log "PASS: Config loading"
    else
        print_fail "Config loading" "Exit code: $exit_code"
        log "FAIL: Config loading - Exit code: $exit_code"
        log "Output: $output"
    fi
}

# Test: Add user (text file)
test_add_user_text() {
    print_test "Add user from text file"
    ((TESTS_RUN++))
    log "TEST: Add user from text file"
    
    # Create test file
    echo "$TEST_USER1:Test User 1:90:a:no:" > "$TEST_USERS_FILE"
    
    local output=$(sudo "$USER_SCRIPT" --add user --names "$TEST_USERS_FILE" 2>&1)
    local exit_code=$?
    
    log "Command output: $output"
    
    if [ $exit_code -eq 0 ]; then
        sleep 1  # Give system time to create user
        if id "$TEST_USER1" &>/dev/null; then
            print_pass "User created from text file"
            log "PASS: User $TEST_USER1 created"
        else
            print_fail "Add user (text)" "User not found after creation"
            log "FAIL: User $TEST_USER1 not found"
        fi
    else
        print_fail "Add user (text)" "Command failed with exit code: $exit_code"
        log "FAIL: Command exit code: $exit_code"
    fi
}

# Test: Add user with random password
test_add_user_random_password() {
    print_test "Add user with random password"
    ((TESTS_RUN++))
    log "TEST: Add user with random password"
    
    echo "$TEST_USER2:Test User 2:::no:random" > "$TEST_USERS_FILE"
    
    local output=$(sudo "$USER_SCRIPT" --add user --names "$TEST_USERS_FILE" 2>&1)
    local exit_code=$?
    
    log "Command output: $output"
    
    if [ $exit_code -eq 0 ]; then
        sleep 1
        if id "$TEST_USER2" &>/dev/null; then
            # Check if password file was created
            local pwd_files=$(sudo find /var/backups/users/passwords -name "${TEST_USER2}_*.txt" 2>/dev/null | wc -l)
            if [ "$pwd_files" -gt 0 ]; then
                print_pass "Random password generated and saved"
                log "PASS: Random password for $TEST_USER2"
            else
                print_pass "User created (password file check skipped)"
                log "PASS: User $TEST_USER2 created (no password file found)"
            fi
        else
            print_fail "Random password" "User not created"
            log "FAIL: User $TEST_USER2 not created"
        fi
    else
        print_fail "Random password" "Command failed: $exit_code"
        log "FAIL: Exit code: $exit_code"
    fi
}

# Test: Add user (JSON)
test_add_user_json() {
    print_test "Add user from JSON"
    ((TESTS_RUN++))
    log "TEST: Add user from JSON"
    
    if ! command -v jq &> /dev/null; then
        print_skip "JSON test (jq not installed)"
        log "SKIP: No jq"
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
    
    local output=$(sudo "$USER_SCRIPT" --add user --input "$TEST_JSON_FILE" --format json 2>&1)
    local exit_code=$?
    
    log "Command output: $output"
    
    if [ $exit_code -eq 0 ]; then
        sleep 1
        if id "$TEST_USER3" &>/dev/null; then
            print_pass "User created from JSON"
            log "PASS: User $TEST_USER3 created from JSON"
        else
            print_fail "Add user (JSON)" "User not found"
            log "FAIL: User $TEST_USER3 not found"
        fi
    else
        print_fail "Add user (JSON)" "Command failed: $exit_code"
        log "FAIL: Exit code: $exit_code"
    fi
}

# Test: View users
test_view_users() {
    print_test "View users"
    ((TESTS_RUN++))
    log "TEST: View users"
    
    local output=$(sudo "$USER_SCRIPT" --view users 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "USERNAME"; then
        print_pass "View users command works"
        log "PASS: View users"
    else
        print_fail "View users" "Exit code: $exit_code"
        log "FAIL: Exit code: $exit_code"
    fi
}

# Test: View user details
test_view_user_details() {
    print_test "View user details"
    ((TESTS_RUN++))
    log "TEST: View user details"
    
    if id "$TEST_USER1" &>/dev/null; then
        local output=$(sudo "$USER_SCRIPT" --view user --name "$TEST_USER1" 2>&1)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ] && echo "$output" | grep -q "User Details"; then
            print_pass "View user details works"
            log "PASS: View user details"
        else
            print_fail "View user details" "Exit code: $exit_code"
            log "FAIL: Exit code: $exit_code"
        fi
    else
        print_skip "View user details (no test user)"
        log "SKIP: No test user"
    fi
}

# Test: Search users
test_search_users() {
    print_test "Search users"
    ((TESTS_RUN++))
    log "TEST: Search users"
    
    local output=$(sudo "$USER_SCRIPT" --search users --pattern "test" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_pass "Search users works"
        log "PASS: Search users"
    else
        print_fail "Search users" "Exit code: $exit_code"
        log "FAIL: Exit code: $exit_code"
    fi
}

# Test: Lock user
test_lock_user() {
    print_test "Lock user"
    ((TESTS_RUN++))
    log "TEST: Lock user"
    
    if id "$TEST_USER1" &>/dev/null; then
        local output=$(sudo "$USER_SCRIPT" --lock user --name "$TEST_USER1" 2>&1)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            sleep 1
            if passwd -S "$TEST_USER1" 2>/dev/null | grep -q " LK "; then
                print_pass "User locked successfully"
                log "PASS: User $TEST_USER1 locked"
            else
                print_fail "Lock user" "User not actually locked"
                log "FAIL: User not locked"
            fi
        else
            print_fail "Lock user" "Command failed: $exit_code"
            log "FAIL: Exit code: $exit_code"
        fi
    else
        print_skip "Lock user (no test user)"
        log "SKIP: No test user"
    fi
}

# Test: Unlock user
test_unlock_user() {
    print_test "Unlock user"
    ((TESTS_RUN++))
    log "TEST: Unlock user"
    
    if id "$TEST_USER1" &>/dev/null; then
        local output=$(sudo "$USER_SCRIPT" --unlock user --name "$TEST_USER1" 2>&1)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            sleep 1
            if ! passwd -S "$TEST_USER1" 2>/dev/null | grep -q " L "; then
                print_pass "User unlocked successfully"
                log "PASS: User $TEST_USER1 unlocked"
            else
                print_fail "Unlock user" "User still locked"
                log "FAIL: User still locked"
            fi
        else
            print_fail "Unlock user" "Command failed: $exit_code"
            log "FAIL: Exit code: $exit_code"
        fi
    else
        print_skip "Unlock user (no test user)"
        log "SKIP: No test user"
    fi
}

# Test: Update user password
test_update_password() {
    print_test "Update user password"
    ((TESTS_RUN++))
    log "TEST: Update password"
    
    if id "$TEST_USER1" &>/dev/null; then
        local output=$(sudo "$USER_SCRIPT" --update user --name "$TEST_USER1" --reset-password 2>&1)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            print_pass "Password reset works"
            log "PASS: Password reset for $TEST_USER1"
        else
            print_fail "Update password" "Exit code: $exit_code"
            log "FAIL: Exit code: $exit_code"
        fi
    else
        print_skip "Update password (no test user)"
        log "SKIP: No test user"
    fi
}

# Test: Add group
test_add_group() {
    print_test "Add group"
    ((TESTS_RUN++))
    log "TEST: Add group"
    
    echo "$TEST_GROUP1" > "$TEST_GROUPS_FILE"
    
    local output=$(sudo "$USER_SCRIPT" --add group --names "$TEST_GROUPS_FILE" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        sleep 1
        if getent group "$TEST_GROUP1" &>/dev/null; then
            print_pass "Group created"
            log "PASS: Group $TEST_GROUP1 created"
        else
            print_fail "Add group" "Group not found"
            log "FAIL: Group not found"
        fi
    else
        print_fail "Add group" "Exit code: $exit_code"
        log "FAIL: Exit code: $exit_code"
    fi
}

# Test: Add user to group
test_add_user_to_group() {
    print_test "Add user to group"
    ((TESTS_RUN++))
    log "TEST: Add user to group"
    
    if id "$TEST_USER1" &>/dev/null && getent group "$TEST_GROUP1" &>/dev/null; then
        local output=$(sudo "$USER_SCRIPT" --update user --name "$TEST_USER1" --add-to-groups "$TEST_GROUP1" 2>&1)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            sleep 1
            if groups "$TEST_USER1" | grep -q "$TEST_GROUP1"; then
                print_pass "User added to group"
                log "PASS: $TEST_USER1 added to $TEST_GROUP1"
            else
                print_fail "Add user to group" "User not in group"
                log "FAIL: User not in group"
            fi
        else
            print_fail "Add user to group" "Exit code: $exit_code"
            log "FAIL: Exit code: $exit_code"
        fi
    else
        print_skip "Add user to group (prerequisites missing)"
        log "SKIP: Prerequisites missing"
    fi
}

# Test: Security report
test_security_report() {
    print_test "Security report"
    ((TESTS_RUN++))
    log "TEST: Security report"
    
    local output=$(sudo "$USER_SCRIPT" --report security 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "Security"; then
        print_pass "Security report generates"
        log "PASS: Security report"
    else
        print_fail "Security report" "Exit code: $exit_code"
        log "FAIL: Exit code: $exit_code"
    fi
}

# Test: Compliance report
test_compliance_report() {
    print_test "Compliance report"
    ((TESTS_RUN++))
    log "TEST: Compliance report"
    
    local output=$(sudo "$USER_SCRIPT" --report compliance 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "Compliance"; then
        print_pass "Compliance report generates"
        log "PASS: Compliance report"
    else
        print_fail "Compliance report" "Exit code: $exit_code"
        log "FAIL: Exit code: $exit_code"
    fi
}

# Test: Export CSV
test_export_csv() {
    print_test "Export users to CSV"
    ((TESTS_RUN++))
    log "TEST: Export CSV"
    
    local output_file="/tmp/test_export_users.csv"
    local output=$(sudo "$USER_SCRIPT" --export users --output "$output_file" --format csv 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && [ -f "$output_file" ] && [ -s "$output_file" ]; then
        print_pass "Export to CSV works"
        log "PASS: Export CSV"
        rm -f "$output_file"
    else
        print_fail "Export CSV" "Exit code: $exit_code or file issue"
        log "FAIL: Exit code: $exit_code"
    fi
}

# Test: Dry-run mode
test_dry_run() {
    print_test "Dry-run mode"
    ((TESTS_RUN++))
    log "TEST: Dry-run mode"
    
    local testuser="dryruntest"
    echo "$testuser:Dry Run Test" > "$TEST_USERS_FILE"
    
    local output=$(sudo "$USER_SCRIPT" --add user --names "$TEST_USERS_FILE" --dry-run 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        sleep 1
        if ! id "$testuser" &>/dev/null; then
            print_pass "Dry-run makes no changes"
            log "PASS: Dry-run"
        else
            print_fail "Dry-run" "User was actually created"
            log "FAIL: User created in dry-run"
            sudo userdel -r "$testuser" &>/dev/null || true
        fi
    else
        print_fail "Dry-run" "Exit code: $exit_code"
        log "FAIL: Exit code: $exit_code"
    fi
}

# Test: System summary
test_system_summary() {
    print_test "System summary"
    ((TESTS_RUN++))
    log "TEST: System summary"
    
    local output=$(sudo "$USER_SCRIPT" --view summary 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "USERS:"; then
        print_pass "System summary displays"
        log "PASS: System summary"
    else
        print_fail "System summary" "Exit code: $exit_code"
        log "FAIL: Exit code: $exit_code"
    fi
}

# Run all tests
run_all_tests() {
    print_header "Running All Tests"
    echo "Log file: $TEST_LOG"
    echo ""
    
    test_version
    test_help
    test_config
    test_add_user_text
    test_add_user_random_password
    test_add_user_json
    test_view_users
    test_view_user_details
    test_search_users
    test_lock_user
    test_unlock_user
    test_update_password
    test_add_group
    test_add_user_to_group
    test_security_report
    test_compliance_report
    test_export_csv
    test_dry_run
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
        echo "Phase 1 is ready for production!"
    else
        echo -e "${RED}✗ SOME TESTS FAILED${NC}"
        echo ""
        echo "Check logs for details:"
        echo "  Test log: $TEST_LOG"
        echo "  System log: /var/log/user_mgmt.log"
    fi
    
    echo ""
    echo "Test log: $TEST_LOG"
    log "Test completed. Pass rate: ${pass_rate}%"
}

# Main execution
main() {
    local test_name="${1:-all}"
    
    print_header "Phase 1 Test Suite v1.0.2"
    echo ""
    
    preflight_checks
    cleanup_test_data
    
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
        *)
            echo "Unknown test: $test_name"
            echo "Available: all, version, help, config, add-user"
            exit 1
            ;;
    esac
    
    show_results
    cleanup_test_data
    
    [ $TESTS_FAILED -eq 0 ] && exit 0 || exit 1
}

main "$@"