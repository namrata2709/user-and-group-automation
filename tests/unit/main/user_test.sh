#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define the directories
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
LIB_DIR="$SCRIPT_DIR/../../../scripts/lib"
UTILS_DIR="$LIB_DIR/utils"
TEST_HELPERS_PATH="$SCRIPT_DIR/../../helpers_test.sh"

# Source the necessary files using absolute paths
source "$TEST_HELPERS_PATH"
source "$UTILS_DIR/validation.sh"
source "$UTILS_DIR/logging.sh"
source "$UTILS_DIR/output.sh"
source "$LIB_DIR/group_add.sh"
source "$LIB_DIR/user_add.sh"
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