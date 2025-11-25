#!/usr/bin/env bash
# =============================================================================
#
#          FILE: group_add_test.sh
#
#         USAGE: ./group_add_test.sh
#
#   DESCRIPTION: Test suite for the group_add.sh library. It covers single
#                group addition, batch processing from files, validation,
#                and detailed JSON reporting.
#
# =============================================================================

# --- Test Setup ---
# Load test helpers and the script to be tested
source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../scripts/lib/validation.sh"
source "$(dirname "$0")/../scripts/lib/output_helpers.sh"
source "$(dirname "$0")/../scripts/lib/group_add.sh"

# --- Mocks & Stubs ---

# Mock dependencies to isolate the script
_ensure_jq() { return 0; }
_display_banner() { echo "BANNER: $1"; }

# Global mock log
MOCK_LOG=""

# Mock system commands
groupadd() { echo "groupadd_called: $@" >> "$MOCK_LOG"; return 0; }
getent() {
    # Simulate group 'existing_group' as already existing
    [[ "$1" == "group" && "$2" == "existing_group" ]] && echo "existing_group:x:1001:" && return 0
    return 1
}

# --- Test Suite Setup & Teardown ---

setup() {
    MOCK_LOG=$(mktemp)
}

teardown() {
    rm -f "$MOCK_LOG"
}

# =============================================================================
# TEST CASES
# =============================================================================

test_add_single_group_success() {
    # --- Given ---
    local groupname="new_group"
    
    # --- When ---
    local output
    output=$(add_groups "$groupname" "single")
    
    # --- Then ---
    assert_contain "$output" '{"status":"success","groupname":"new_group"}' "JSON output should report success" "test_add_single_group_success"
    assert_file_contains "$MOCK_LOG" "groupadd_called: new_group" "groupadd should be called for new_group" "test_add_single_group_success"
}

test_add_single_group_already_exists() {
    # --- Given ---
    local groupname="existing_group"
    
    # --- When ---
    local output
    output=$(add_groups "$groupname" "single")
    
    # --- Then ---
    assert_contain "$output" '{"status":"skipped","groupname":"existing_group","reason":"Group already exists"}' "JSON output should report group as skipped" "test_add_single_group_already_exists"
    assert_file_not_contains "$MOCK_LOG" "groupadd_called" "groupadd should not be called for an existing group" "test_add_single_group_already_exists"
}

test_add_groups_from_text_file_with_validation_failure() {
    # --- Given ---
    local text_file
    text_file=$(mktemp)
    # 'InvalidGroup' contains uppercase letters, which is invalid.
    echo -e "valid_group\\nInvalidGroup" > "$text_file"
    
    # --- When ---
    local output
    output=$(add_groups "$text_file" "text")
    
    # --- Then ---
    assert_contain "$output" '{"status":"failed","groupname":"InvalidGroup","reason":"Invalid group name format"}' "JSON should report the invalid group as failed" "test_add_groups_from_text_file_with_validation_failure"
    assert_file_not_contains "$MOCK_LOG" "groupadd_called: InvalidGroup" "groupadd should not be called for the invalid group" "test_add_groups_from_text_file_with_validation_failure"
    # It should still create the valid one
    assert_file_contains "$MOCK_LOG" "groupadd_called: valid_group" "groupadd should be called for the valid group" "test_add_groups_from_text_file_with_validation_failure"
    
    # --- Cleanup ---
    rm "$text_file"
}

test_add_groups_from_json_file_success_and_skipped() {
    # --- Given ---
    local json_file
    json_file=$(mktemp)
    cat <<EOF > "$json_file"
{
  "groups": [
    { "groupname": "new_json_group" },
    { "groupname": "existing_group" }
  ]
}
EOF
    
    # --- When ---
    local output
    output=$(add_groups "$json_file" "json")
    
    # --- Then ---
    assert_contain "$output" '{"status":"success","groupname":"new_json_group"}' "JSON should report new_json_group as created" "test_add_groups_from_json_file_success_and_skipped"
    assert_contain "$output" '{"status":"skipped","groupname":"existing_group","reason":"Group already exists"}' "JSON should report existing_group as skipped" "test_add_groups_from_json_file_success_and_skipped"
    assert_file_contains "$MOCK_LOG" "groupadd_called: new_json_group" "groupadd should be called for new_json_group" "test_add_groups_from_json_file_success_and_skipped"
    assert_file_not_contains "$MOCK_LOG" "groupadd_called: existing_group" "groupadd should not be called for existing_group" "test_add_groups_from_json_file_success_and_skipped"
    
    # --- Cleanup ---
    rm "$json_file"
}

test_add_groups_from_json_with_invalid_name() {
    # --- Given ---
    local json_file
    json_file=$(mktemp)
    cat <<EOF > "$json_file"
{
  "groups": [
    { "groupname": "bad-group-name-" }
  ]
}
EOF
    
    # --- When ---
    local output
    output=$(add_groups "$json_file" "json")
    
    # --- Then ---
    assert_contain "$output" '{"status":"failed","groupname":"bad-group-name-","reason":"Invalid group name format"}' "JSON should report the invalid group as failed" "test_add_groups_from_json_with_invalid_name"
    assert_file_not_contains "$MOCK_LOG" "groupadd_called" "groupadd should not be called if validation fails" "test_add_groups_from_json_with_invalid_name"
    
    # --- Cleanup ---
    rm "$json_file"
}


# =============================================================================
# --- Run Tests ---
# =============================================================================
run_test_suite