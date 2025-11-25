#!/usr/bin/env bash
# =================================================================
# Test Suite for User Lock/Unlock Functionality
# =================================================================

# Load test helpers and the script to be tested
. "$(dirname "$0")/test_helpers.sh"
. "$(dirname "$0")/../scripts/lib/user_lock.sh"
. "$(dirname "$0")/../scripts/lib/validation.sh"
. "$(dirname "$0")/../scripts/lib/helpers.sh"
. "$(dirname "$0")/../scripts/lib/output_helpers.sh"

# =================================================
# Mocks and Test Data
# =================================================

# Create a mock user for testing
setup() {
    sudo useradd test_lock_user &>/dev/null || true
}

# Clean up the mock user
teardown() {
    sudo userdel -r test_lock_user &>/dev/null || true
}

# =================================================
# Test Cases
# =================================================

test_lock_single_user_success() {
    local test_name="test_lock_single_user_success"
    # Ensure user is unlocked before test
    sudo usermod -U test_lock_user

    assert_success "lock_user 'test_lock_user' 'Security reason'" "Should successfully lock a user." "$test_name"
    
    local lock_status
    lock_status=$(sudo passwd -S test_lock_user | awk '{print $2}')
    assert_equals "L" "$lock_status" "User should have a 'L' status after locking." "$test_name"
}

test_lock_already_locked_user() {
    local test_name="test_lock_already_locked_user"
    # Ensure user is locked before test
    sudo usermod -L test_lock_user

    local output
    output=$(lock_user 'test_lock_user' 'Another reason' 2>&1)
    assert_contain "$output" "already locked" "Should report that the user is already locked." "$test_name"
}

test_unlock_single_user_success() {
    local test_name="test_unlock_single_user_success"
    # Ensure user is locked before test
    sudo usermod -L test_lock_user

    assert_success "unlock_user 'test_lock_user'" "Should successfully unlock a user." "$test_name"

    local lock_status
    lock_status=$(sudo passwd -S test_lock_user | awk '{print $2}')
    assert_not_equals "L" "$lock_status" "User should not have a 'L' status after unlocking." "$test_name"
}

test_lock_non_existent_user() {
    local test_name="test_lock_non_existent_user"
    assert_failure "lock_user 'non_existent_user_123' 'Reason'" "Should fail to lock a non-existent user." "$test_name"
}

# =================================================
# Run Tests
# =================================================
run_test_suite