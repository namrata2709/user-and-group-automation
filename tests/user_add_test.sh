#!/usr/bin/env bash
# =============================================================================
#
#          FILE: user_add_test.sh
#
#         USAGE: ./user_add_test.sh
#
#   DESCRIPTION: Test suite for the user_add.sh library. It covers single
#                user addition, batch processing from files, provisioning
#                with roles, validation, and error handling.
#
# =============================================================================

# --- Test Setup ---
# Load test helpers and the script to be tested
source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../scripts/lib/validation.sh"
source "$(dirname "$0")/../scripts/lib/output_helpers.sh"
source "$(dirname "$0")/../scripts/lib/user_add.sh"

# --- Mocks & Stubs ---

# Mock dependencies to isolate the script and prevent actual system changes
_ensure_jq() { return 0; }
_display_banner() { echo "BANNER: $1"; }
# The real output helpers are sourced, but we can override them in specific tests if needed.

# Global mock log for capturing command calls
MOCK_LOG=""

# Mock system commands to trace their calls and arguments
useradd() { echo "useradd_called: $@" >> "$MOCK_LOG"; return 0; }
groupadd() { echo "groupadd_called: $@" >> "$MOCK_LOG"; return 0; }
groupdel() { echo "groupdel_called: $@" >> "$MOCK_LOG"; return 0; }
getent() {
    case "$1" in
        group)
            # Simulate group existence. Let 'existing_group' exist.
            [[ "$2" == "existing_group" ]] && echo "existing_group:x:1001:" && return 0
            # For rollback tests, simulate group 'new_group_for_rollback' not existing initially
            [[ "$2" == "new_group_for_rollback" ]] && return 1
            # Simulate other groups as non-existent
            return 1
            ;;
        passwd)
            # Simulate user existence. Let 'existing_user' exist.
            [[ "$2" == "existing_user" ]] && echo "existing_user:x:1001:1001::/home/existing_user:/bin/bash" && return 0
            return 1
            ;;
    esac
}
id() { return 0; } # Assume user IDs are valid for simplicity in most tests

# --- Test Suite Setup & Teardown ---

setup() {
    # Create a temporary log file for each test
    MOCK_LOG=$(mktemp)
}

teardown() {
    # Clean up the log file
    rm -f "$MOCK_LOG"
}

# =============================================================================
# TEST CASES
# =============================================================================

test_add_single_user_success() {
    # --- Given ---
    local username="new_user"
    
    # --- When ---
    local output
    output=$(add_users "$username" "single")
    
    # --- Then ---
    assert_contain "$output" '{"status":"success","username":"new_user"}' "JSON output should report success for new_user" "test_add_single_user_success"
    assert_file_contains "$MOCK_LOG" "useradd_called: -m new_user" "useradd should be called for new_user" "test_add_single_user_success"
}

test_add_single_user_already_exists() {
    # --- Given ---
    local username="existing_user"
    
    # --- When ---
    local output
    output=$(add_users "$username" "single")
    
    # --- Then ---
    assert_contain "$output" '{"status":"skipped","username":"existing_user","reason":"User already exists"}' "JSON output should report user as skipped" "test_add_single_user_already_exists"
    assert_file_not_contains "$MOCK_LOG" "useradd_called" "useradd should not be called for an existing user" "test_add_single_user_already_exists"
}

test_add_users_from_text_batch_validation_failure() {
    # --- Given ---
    local text_file
    text_file=$(mktemp)
    # 'invalid-user-' contains a hyphen at the end, which is invalid.
    echo -e "valid_user\\ninvalid-user-" > "$text_file"
    
    # --- When ---
    local output
    output=$(add_users "$text_file" "text")
    
    # --- Then ---
    assert_contain "$output" '{"status":"failed","username":"invalid-user-","reason":"Invalid username format"}' "JSON should report the invalid user as failed" "test_add_users_from_text_batch_validation_failure"
    assert_file_not_contains "$MOCK_LOG" "useradd_called" "useradd should not be called if validation fails" "test_add_users_from_text_batch_validation_failure"
    
    # --- Cleanup ---
    rm "$text_file"
}

test_provisioning_with_non_existent_group_fails_validation() {
    # --- Given ---
    local json_file
    json_file=$(mktemp)
    cat <<EOF > "$json_file"
{
  "users": [
    { "username": "user1", "primary_group": "non_existent_group" }
  ]
}
EOF
    
    # --- When ---
    local output
    output=$(add_users "$json_file" "json")
    
    # --- Then ---
    assert_contain "$output" '{"status":"failed","username":"user1","reason":"Primary group '\''non_existent_group'\'' does not exist."}' "JSON should report failure due to non-existent primary group" "test_provisioning_with_non_existent_group_fails_validation"
    assert_file_not_contains "$MOCK_LOG" "useradd_called" "useradd should not be called on validation failure" "test_provisioning_with_non_existent_group_fails_validation"
    
    # --- Cleanup ---
    rm "$json_file"
}

test_provisioning_rollback_on_user_creation_failure() {
    # --- Given ---
    local json_file
    json_file=$(mktemp)
    cat <<EOF > "$json_file"
{
  "groups": [
    { "groupname": "new_group_for_rollback" }
  ],
  "users": [
    { "username": "user_that_fails", "primary_group": "new_group_for_rollback" }
  ]
}
EOF
    
    # Override useradd to simulate failure for this specific test
    useradd() {
        echo "useradd_called: $@" >> "$MOCK_LOG"
        # Fail only for the specific user in this test
        [[ "$2" == "user_that_fails" ]] && return 1
        return 0
    }
    
    # --- When ---
    local output
    output=$(provision_users_and_groups "$json_file")
    
    # --- Then ---
    assert_file_contains "$MOCK_LOG" "groupadd_called: new_group_for_rollback" "groupadd should be called for the new group" "test_provisioning_rollback_on_user_creation_failure"
    assert_file_contains "$MOCK_LOG" "useradd_called: -m -g new_group_for_rollback user_that_fails" "useradd should be attempted for the user" "test_provisioning_rollback_on_user_creation_failure"
    assert_contain "$output" '{"status":"failed","username":"user_that_fails","reason":"useradd command failed"}' "JSON should report the user creation as failed" "test_provisioning_rollback_on_user_creation_failure"
    assert_file_contains "$MOCK_LOG" "groupdel_called: new_group_for_rollback" "groupdel should be called to roll back the created group" "test_provisioning_rollback_on_user_creation_failure"
    
    # --- Cleanup ---
    rm "$json_file"
    # Restore the original mock
    useradd() { echo "useradd_called: $@" >> "$MOCK_LOG"; return 0; }
}

test_full_provisioning_success_scenario() {
    # --- Given ---
    local json_file
    json_file=$(mktemp)
    cat <<EOF > "$json_file"
{
  "groups": [
    { "groupname": "new_devs" },
    { "groupname": "existing_group" }
  ],
  "users": [
    { "username": "new_developer", "primary_group": "new_devs", "secondary_groups": ["docker", "vpn"], "shell": "/bin/zsh" },
    { "username": "existing_user", "primary_group": "new_devs" }
  ]
}
EOF
    
    # --- When ---
    local output
    output=$(provision_users_and_groups "$json_file")
    
    # --- Then ---
    # Verify group creation
    assert_file_contains "$MOCK_LOG" "groupadd_called: new_devs" "groupadd should be called for new_devs" "test_full_provisioning_success_scenario"
    assert_contain "$output" '{"status":"success","groupname":"new_devs"}' "JSON should report new_devs group created" "test_full_provisioning_success_scenario"
    assert_contain "$output" '{"status":"skipped","groupname":"existing_group","reason":"Group already exists"}' "JSON should report existing_group as skipped" "test_full_provisioning_success_scenario"
    
    # Verify user creation
    assert_file_contains "$MOCK_LOG" "useradd_called: -m -g new_devs -G docker,vpn -s /bin/zsh new_developer" "useradd should be called with all details for new_developer" "test_full_provisioning_success_scenario"
    assert_contain "$output" '{"status":"success","username":"new_developer"' "JSON should report new_developer as created" "test_full_provisioning_success_scenario"
    assert_contain "$output" '{"status":"skipped","username":"existing_user","reason":"User already exists"}' "JSON should report existing_user as skipped" "test_full_provisioning_success_scenario"
    
    # Verify no rollback occurred
    assert_file_not_contains "$MOCK_LOG" "groupdel_called" "groupdel should not be called on success" "test_full_provisioning_success_scenario"
    
    # --- Cleanup ---
    rm "$json_file"
}


# =============================================================================
# --- Run Tests ---
# =============================================================================
run_test_suite