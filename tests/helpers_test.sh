#!/usr/bin/env bash
# =================================================
# Test Suite for Helper Functions
# =================================================

# Load test helpers and the script to be tested
. "$(dirname "$0")"/test_helpers.sh
. "$(dirname "$0")"/../scripts/lib/helpers.sh

# =================================================
# Test Cases
# =================================================

test_user_exists() {
    local test_name="test_user_exists"
    # This relies on the test environment having a 'root' user
    assert_success "user_exists 'root'" "Should return true for an existing user." "$test_name"
    assert_failure "user_exists 'non_existent_user_12345'" "Should return false for a non-existent user." "$test_name"
}

test_group_exists() {
    local test_name="test_group_exists"
    # This relies on the test environment having a 'root' group
    assert_success "group_exists 'root'" "Should return true for an existing group." "$test_name"
    assert_failure "group_exists 'non_existent_group_12345'" "Should return false for a non-existent group." "$test_name"
}

test_get_user_groups() {
    local test_name="test_get_user_groups"
    # Create a test user and group for this test
    sudo useradd test_helper_user
    sudo groupadd test_helper_group
    sudo usermod -aG test_helper_group test_helper_user

    local groups
    groups=$(get_user_groups "test_helper_user")
    
    assert_contain "$groups" "test_helper_group" "Should list the user's groups." "$test_name"

    # Cleanup
    sudo userdel test_helper_user
    sudo groupdel test_helper_group
}

# =================================================
# Run Tests
# =================================================
run_test_suite