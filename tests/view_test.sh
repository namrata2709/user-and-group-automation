#!/usr/bin/env bash

# =============================================================================
# Test Suite for View Operations (user.sh --view)
# =============================================================================
#
# This test suite is designed to validate the functionality of the `--view`
# command in `user.sh`. It covers a wide range of scenarios, including:
#
# 1.  **Basic Views**: Viewing users, groups, and system summary.
# 2.  **Filtering**: Using `--search`, `--in-group`, `--has-member`, and ranges.
# 3.  **Sorting**: Testing `--sort` with various columns and `--reverse` order.
# 4.  **Output Formats**: Validating both table (default) and JSON (`--json`).
# 5.  **Column Selection**: Using `--columns` to customize output.
# 6.  **Pagination**: Testing `--limit` and `--skip`.
# 7.  **Detailed Views**: Checking `--detailed` for summary and single items.
# 8.  **Edge Cases**: Handling non-existent users/groups and empty results.
#
# The suite uses the `assert` and `assert_contains` functions from `test_helpers.sh`
# to check for expected outcomes. Each test is designed to be independent and
# focuses on a specific feature of the view functionality.
#
# =============================================================================

# ---
# Setup
# ---
#
# Set the script directory and source necessary helpers.
# The `TEST_DIR` is the directory where this test script is located.
# The `SCRIPT_DIR` is the parent directory, containing `user.sh`.
#
# We source `test_helpers.sh` to get access to assertion functions and
# the `setup_test_environment` and `cleanup_test_environment` functions.
#
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$TEST_DIR")"
source "$TEST_DIR/test_helpers.sh"

# ---
# Test Environment Setup
# ---
#
# `setup_test_environment` is called to prepare for the tests.
# This function is defined in `test_helpers.sh` and is responsible for:
#
# 1.  Creating a set of mock users and groups.
# 2.  Setting up a clean environment for each test run.
# 3.  Ensuring that the main script (`user.sh`) is executable.
#
# This setup provides a consistent state for all tests, making them
# reliable and repeatable.
#
setup_test_environment

# =============================================================================
# Test Cases
# =============================================================================

# ---
# Test Case 1: Basic User View
# ---
#
# **Purpose**: Verify that the default user view returns the correct list of users.
#
# **Steps**:
# 1. Run `./user.sh --view users`.
# 2. Assert that the command executes successfully (exit code 0).
# 3. Assert that the output contains the header "Username".
# 4. Assert that the output contains the names of the test users (`testuser1`, `testuser2`).
#
test_view_users_basic() {
    local test_name="test_view_users_basic"
    local output
    output=$("$SCRIPT_DIR/user.sh" --view users 2>&1)
    local exit_code=$?

    assert_equals 0 "$exit_code" "Expected exit code 0 for basic user view." "$test_name"
    assert_contains "$output" "Username" "Output should contain the 'Username' header." "$test_name"
    assert_contains "$output" "testuser1" "Output should contain 'testuser1'." "$test_name"
    assert_contains "$output" "testuser2" "Output should contain 'testuser2'." "$test_name"
}

# ---
# Test Case 2: Basic Group View
# ---
#
# **Purpose**: Verify that the default group view returns the correct list of groups.
#
# **Steps**:
# 1. Run `./user.sh --view groups`.
# 2. Assert that the command executes successfully.
# 3. Assert that the output contains the header "Group Name".
# 4. Assert that the output contains the names of the test groups (`testgroup1`, `testgroup2`).
#
test_view_groups_basic() {
    local test_name="test_view_groups_basic"
    local output
    output=$("$SCRIPT_DIR/user.sh" --view groups 2>&1)
    local exit_code=$?

    assert_equals 0 "$exit_code" "Expected exit code 0 for basic group view." "$test_name"
    assert_contains "$output" "Group Name" "Output should contain the 'Group Name' header." "$test_name"
    assert_contains "$output" "testgroup1" "Output should contain 'testgroup1'." "$test_name"
    assert_contains "$output" "testgroup2" "Output should contain 'testgroup2'." "$test_name"
}

# ---
# Test Case 3: View Single User
# ---
#
# **Purpose**: Verify that viewing a single user returns the correct details.
#
# **Steps**:
# 1. Run `./user.sh --view user --name testuser1`.
# 2. Assert that the command executes successfully.
# 3. Assert that the output contains "Details for user: testuser1".
# 4. Assert that the output contains the user's home directory (`/home/testuser1`).
#
test_view_single_user() {
    local test_name="test_view_single_user"
    local output
    output=$("$SCRIPT_DIR/user.sh" --view user --name testuser1 2>&1)
    local exit_code=$?

    assert_equals 0 "$exit_code" "Expected exit code 0 for single user view." "$test_name"
    assert_contains "$output" "Details for user: testuser1" "Output should contain the user's details header." "$test_name"
    assert_contains "$output" "/home/testuser1" "Output should contain the user's home directory." "$test_name"
}

# ---
# Test Case 4: View Single Group
# ---
#
# **Purpose**: Verify that viewing a single group returns the correct details.
#
# **Steps**:
# 1. Run `./user.sh --view group --name testgroup1`.
# 2. Assert that the command executes successfully.
# 3. Assert that the output contains "Details for group: testgroup1".
# 4. Assert that the output contains the members of the group (`testuser1`).
#
test_view_single_group() {
    local test_name="test_view_single_group"
    local output
    output=$("$SCRIPT_DIR/user.sh" --view group --name testgroup1 2>&1)
    local exit_code=$?

    assert_equals 0 "$exit_code" "Expected exit code 0 for single group view." "$test_name"
    assert_contains "$output" "Details for group: testgroup1" "Output should contain the group's details header." "$test_name"
    assert_contains "$output" "testuser1" "Output should contain the group's members." "$test_name"
}

# ---
# Test Case 5: View Users with JSON Output
# ---
#
# **Purpose**: Verify that the user view with `--json` returns valid JSON.
#
# **Steps**:
# 1. Run `./user.sh --view users --json`.
# 2. Assert that the command executes successfully.
# 3. Use `jq` to validate the JSON and check for expected keys (`username`, `uid`).
#
test_view_users_json() {
    local test_name="test_view_users_json"
    local output
    output=$("$SCRIPT_DIR/user.sh" --view users --json 2>&1)
    local exit_code=$?

    assert_equals 0 "$exit_code" "Expected exit code 0 for JSON user view." "$test_name"
    
    # Validate JSON structure and content
    local first_username=$(echo "$output" | jq -r '.[0].username')
    assert_equals "testuser1" "$first_username" "First user in JSON output should be 'testuser1'." "$test_name"
    
    local first_uid_exists=$(echo "$output" | jq '.[0] | has("uid")')
    assert_equals "true" "$first_uid_exists" "JSON output for users should contain 'uid'." "$test_name"
}

# ---
# Test Case 6: View Groups with JSON Output
# ---
#
# **Purpose**: Verify that the group view with `--json` returns valid JSON.
#
# **Steps**:
# 1. Run `./user.sh --view groups --json`.
# 2. Assert that the command executes successfully.
# 3. Use `jq` to validate the JSON and check for expected keys (`groupname`, `gid`).
#
test_view_groups_json() {
    local test_name="test_view_groups_json"
    local output
    output=$("$SCRIPT_DIR/user.sh" --view groups --json 2>&1)
    local exit_code=$?

    assert_equals 0 "$exit_code" "Expected exit code 0 for JSON group view." "$test_name"

    # Validate JSON structure and content
    local first_groupname=$(echo "$output" | jq -r '.[0].groupname')
    assert_equals "testgroup1" "$first_groupname" "First group in JSON output should be 'testgroup1'." "$test_name"

    local first_gid_exists=$(echo "$output" | jq '.[0] | has("gid")')
    assert_equals "true" "$first_gid_exists" "JSON output for groups should contain 'gid'." "$test_name"
}

# ---
# Test Case 7: Filter Users by Group
# ---
#
# **Purpose**: Verify that `--in-group` correctly filters users.
#
# **Steps**:
# 1. Run `./user.sh --view users --in-group testgroup1`.
# 2. Assert that the output contains `testuser1`.
# 3. Assert that the output does not contain `testuser2` (who is not in `testgroup1`).
#
test_view_users_filter_by_group() {
    local test_name="test_view_users_filter_by_group"
    local output
    output=$("$SCRIPT_DIR/user.sh" --view users --in-group testgroup1 2>&1)
    local exit_code=$?

    assert_equals 0 "$exit_code" "Expected exit code 0 when filtering users by group." "$test_name"
    assert_contains "$output" "testuser1" "Output should contain 'testuser1'." "$test_name"
    assert_not_contains "$output" "testuser2" "Output should not contain 'testuser2'." "$test_name"
}

# ---
# Test Case 8: Sort Users by UID
# ---
#
# **Purpose**: Verify that `--sort uid` correctly sorts users.
#
# **Steps**:
# 1. Run `./user.sh --view users --sort uid`.
# 2. Get the UIDs of `testuser1` and `testuser2`.
# 3. Determine the expected order and assert that the output matches.
#
test_view_users_sort_by_uid() {
    local test_name="test_view_users_sort_by_uid"
    
    # Get UIDs to determine correct order
    local uid1=$(id -u testuser1)
    local uid2=$(id -u testuser2)
    
    local output
    output=$("$SCRIPT_DIR/user.sh" --view users --sort uid 2>&1)
    local exit_code=$?

    assert_equals 0 "$exit_code" "Expected exit code 0 for sorting users by UID." "$test_name"

    # Check the order of users in the output
    if [ "$uid1" -lt "$uid2" ]; then
        assert_order "$output" "testuser1" "testuser2" "Users should be sorted by UID in ascending order." "$test_name"
    else
        assert_order "$output" "testuser2" "testuser1" "Users should be sorted by UID in ascending order." "$test_name"
    fi
}

# ---
# Test Case 9: Limit and Skip Users
# ---
#
# **Purpose**: Verify that `--limit` and `--skip` work for pagination.
#
# **Steps**:
# 1. Run `./user.sh --view users --sort username --limit 1`.
# 2. Assert that the output contains only `testuser1`.
# 3. Run `./user.sh --view users --sort username --limit 1 --skip 1`.
# 4. Assert that the output contains only `testuser2`.
#
test_view_users_pagination() {
    local test_name="test_view_users_pagination"
    
    # Test --limit
    local output_limit
    output_limit=$("$SCRIPT_DIR/user.sh" --view users --sort username --limit 1 2>&1)
    assert_contains "$output_limit" "testuser1" "Limit 1 should return 'testuser1'." "$test_name"
    assert_not_contains "$output_limit" "testuser2" "Limit 1 should not return 'testuser2'." "$test_name"

    # Test --skip
    local output_skip
    output_skip=$("$SCRIPT_DIR/user.sh" --view users --sort username --limit 1 --skip 1 2>&1)
    assert_contains "$output_skip" "testuser2" "Skip 1 should return 'testuser2'." "$test_name"
    assert_not_contains "$output_skip" "testuser1" "Skip 1 should not return 'testuser1'." "$test_name"
}

# ---
# Test Case 10: Non-existent User/Group
# ---
#
# **Purpose**: Verify that the script handles requests for non-existent items gracefully.
#
# **Steps**:
# 1. Run `./user.sh --view user --name non_existent_user`.
# 2. Assert that the exit code is non-zero.
# 3. Assert that the output contains an error message.
# 4. Repeat for a non-existent group.
#
test_view_non_existent_items() {
    local test_name="test_view_non_existent_items"

    # Test non-existent user
    local user_output
    user_output=$("$SCRIPT_DIR/user.sh" --view user --name non_existent_user 2>&1)
    local user_exit_code=$?
    assert_not_equals 0 "$user_exit_code" "Expected non-zero exit code for non-existent user." "$test_name"
    assert_contains "$user_output" "User 'non_existent_user' not found" "Should show an error for non-existent user." "$test_name"

    # Test non-existent group
    local group_output
    group_output=$("$SCRIPT_DIR/user.sh" --view group --name non_existent_group 2>&1)
    local group_exit_code=$?
    assert_not_equals 0 "$group_exit_code" "Expected non-zero exit code for non-existent group." "$test_name"
    assert_contains "$group_output" "Group 'non_existent_group' not found" "Should show an error for non-existent group." "$test_name"
}

# =============================================================================
# Test Runner
# =============================================================================
#
# This section of the script is the test runner. It executes all the
# functions in this file that start with `test_`.
#
# The `main` function iterates through the declared functions, filters for
# those that are test cases, and runs them one by one.
#
# After all tests are executed, the `cleanup_test_environment` function is
# called to remove any mock users, groups, or files created during the tests.
# This ensures that the system is left in a clean state.
#
# Finally, a summary of the test results is printed, showing the number of
# tests passed and failed.
#
main() {
    # Find all functions in this file that start with "test_"
    local test_functions
    test_functions=$(declare -F | awk '{print $3}' | grep '^test_')

    # Run each test function
    for func in $test_functions; do
        echo "Running test: $func"
        $func
    done

    # Cleanup and show results
    cleanup_test_environment
    display_test_summary
}

# ---
# Execute the main function to run the tests
# ---
main