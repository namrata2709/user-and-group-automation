#!/usr/bin/env bash

# Load test helpers
source "$(dirname "$0")/../../../test_helpers.sh"

# Load the script to be tested
source "$(dirname "$0")/../../../../scripts/user.sh"

# =============================================================================
# MOCKS & STUBS
# =============================================================================

# Mock the library functions that would be called by the main script
add_users() { echo "add_users_called: $*"; }
delete_users() { echo "delete_users_called: $*"; }
update_users() { echo "update_users_called: $*"; }
view_users() { echo "view_users_called: $*"; }
lock_users() { echo "lock_users_called: $*"; }
add_groups() { echo "add_groups_called: $*"; }
delete_groups() { echo "delete_groups_called: $*"; }
update_groups() { echo "update_groups_called: $*"; }
show_help() { echo "show_help_called: $*"; }

# =============================================================================
# TEST CASES
# =============================================================================

test_main_add_user_routing() {
    local output
    output=$(main "add" "user" "testuser")
    assert_string_contains "$output" "add_users_called: testuser" "Should route to add_users."
}

test_main_add_group_routing() {
    local output
    output=$(main "add" "group" "testgroup")
    assert_string_contains "$output" "add_groups_called: testgroup" "Should route to add_groups."
}

test_main_delete_user_routing() {
    local output
    output=$(main "delete" "user" "testuser")
    assert_string_contains "$output" "delete_users_called: testuser" "Should route to delete_users."
}

test_main_help_routing() {
    local output
    output=$(main "help")
    assert_string_contains "$output" "show_help_called:" "Should route to show_help."
}

test_main_invalid_command() {
    local output
    output=$(main "fly" "user")
    assert_string_contains "$output" "Invalid command: fly" "Should show an error for invalid commands."
}