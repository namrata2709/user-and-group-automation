#!/usr/bin/env bash
# =============================================================================
# Test Suite for View Operations (user.sh --view)
# =============================================================================

# Load test helpers and the main script
. "$(dirname "$0")/test_helpers.sh"
. "$(dirname "$0")/../scripts/user.sh"

# =================================================
# Test Setup and Teardown
# =================================================

# Creates mock users and groups for testing view operations
setup() {
    echo "Setting up test environment for view tests..."
    sudo groupadd testgroup1 &>/dev/null || true
    sudo groupadd testgroup2 &>/dev/null || true
    sudo useradd -m -s /bin/bash -g testgroup1 testuser1 &>/dev/null || true
    sudo useradd -m -s /bin/sh -g testgroup2 testuser2 &>/dev/null || true
    sudo usermod -aG testgroup2 testuser1 &>/dev/null || true
    echo "Test environment setup complete."
}

# Removes all mock users and groups
teardown() {
    echo "Cleaning up test environment for view tests..."
    sudo userdel -r testuser1 &>/dev/null || true
    sudo userdel -r testuser2 &>/dev/null || true
    sudo groupdel testgroup1 &>/dev/null || true
    sudo groupdel testgroup2 &>/dev/null || true
    echo "Test environment cleanup complete."
}

# =============================================================================
# Test Cases
# =============================================================================

test_view_users_basic() {
    local test_name="test_view_users_basic"
    local output
    output=$(main "--view" "users" 2>&1)
    
    assert_success "echo '$output'" "Basic user view should succeed." "$test_name"
    assert_contain "$output" "testuser1" "Output should contain 'testuser1'." "$test_name"
    assert_contain "$output" "testuser2" "Output should contain 'testuser2'." "$test_name"
}

test_view_groups_basic() {
    local test_name="test_view_groups_basic"
    local output
    output=$(main "--view" "groups" 2>&1)

    assert_success "echo '$output'" "Basic group view should succeed." "$test_name"
    assert_contain "$output" "testgroup1" "Output should contain 'testgroup1'." "$test_name"
    assert_contain "$output" "testgroup2" "Output should contain 'testgroup2'." "$test_name"
}

test_view_single_user_details() {
    local test_name="test_view_single_user_details"
    local output
    output=$(main "--view" "user" "--name" "testuser1" 2>&1)

    assert_success "echo '$output'" "Single user view should succeed." "$test_name"
    assert_contain "$output" "Details for user: testuser1" "Output should contain the user's details header." "$test_name"
    assert_contain "$output" "/home/testuser1" "Output should contain the user's home directory." "$test_name"
}

test_view_users_with_json_output() {
    local test_name="test_view_users_with_json_output"
    local output
    output=$(main "--view" "users" "--json" 2>&1)

    assert_success "echo '$output' | jq ." "JSON output should be valid." "$test_name"
    
    local username
    username=$(echo "$output" | jq -r '.[] | select(.username=="testuser1") | .username')
    assert_equals "testuser1" "$username" "JSON output should contain 'testuser1'." "$test_name"
}

test_view_users_filter_with_where() {
    local test_name="test_view_users_filter_with_where"
    local output
    output=$(main "--view" "users" "--where" "groups CONTAINS 'testgroup2'" 2>&1)

    assert_success "echo '$output'" "Filtering with --where should succeed." "$test_name"
    assert_contain "$output" "testuser1" "Output should contain 'testuser1' (member of testgroup2)." "$test_name"
    assert_not_contain "$output" "testuser2" "Output should not contain 'testuser2' (not member of testgroup2)." "$test_name"
}

test_view_users_custom_columns() {
    local test_name="test_view_users_custom_columns"
    local output
    output=$(main "--view" "users" "--columns" "username,uid" 2>&1)

    assert_success "echo '$output'" "Custom columns view should succeed." "$test_name"
    assert_contain "$output" "Username" "Output should contain 'Username' column." "$test_name"
    assert_contain "$output" "UID" "Output should contain 'UID' column." "$test_name"
    assert_not_contain "$output" "Home Directory" "Output should not contain 'Home Directory' column." "$test_name"
}

test_view_non_existent_user_fails() {
    local test_name="test_view_non_existent_user_fails"
    local output
    output=$(main "--view" "user" "--name" "non_existent_user" 2>&1)
    
    assert_contain "$output" "not found" "Should show an error for non-existent user." "$test_name"
}

# =============================================================================
# Run Tests
# =============================================================================
run_test_suite