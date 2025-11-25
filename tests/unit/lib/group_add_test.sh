#!/usr/bin/env bash
# =============================================================================
#
#          FILE: group_add_test.sh
#
#         USAGE: ./group_add_test.sh
#
#   DESCRIPTION: Test suite for the group_add.sh library.
#
# =============================================================================

# --- Test Setup ---
source "$(dirname "$0")/../../../test_helpers.sh"
source "$(dirname "$0")/../../../../scripts/lib/utils/validation.sh"
source "$(dirname "$0")/../../../../scripts/lib/utils/output.sh"
source "$(dirname "$0")/../../../../scripts/lib/group_add.sh"

# --- Mocks & Stubs ---
_display_banner() { :; }
log_action() { echo "LOG: $*" >> "$MOCK_LOG"; }

MOCK_LOG=""
CAPTURED_GROUPS_CREATED=()
CAPTURED_GROUPS_EXISTING=()
CAPTURED_GROUPS_FAILED=()

groupadd() { echo "groupadd_called: $*" >> "$MOCK_LOG"; return 0; }
getent() {
    [[ "$1" == "group" && "$2" == "existing_group" ]] && return 0
    return 1
}

_display_add_groups_bash_results() {
    CAPTURED_GROUPS_CREATED=("$1")
    CAPTURED_GROUPS_EXISTING=("$2")
    CAPTURED_GROUPS_FAILED=("$3")
}

# --- Test Suite Setup & Teardown ---
setup() {
    MOCK_LOG=$(mktemp)
    CAPTURED_GROUPS_CREATED=()
    CAPTURED_GROUPS_EXISTING=()
    CAPTURED_GROUPS_FAILED=()
}

teardown() {
    rm -f "$MOCK_LOG"
}

# =============================================================================
# TEST CASES
# =============================================================================

test_add_single_group_success() {
    add_groups "new_group"
    local expected_json='{"groupname":"new_group","status":"success"}'
    assert_array_contains CAPTURED_GROUPS_CREATED "$expected_json"
    assert_file_contains "$MOCK_LOG" "groupadd_called: new_group"
}

test_add_single_group_already_exists() {
    add_groups "existing_group"
    local expected_json='{"groupname":"existing_group","status":"skipped","reason":"Group already exists"}'
    assert_array_contains CAPTURED_GROUPS_EXISTING "$expected_json"
    assert_file_not_contains "$MOCK_LOG" "groupadd_called"
}

test_add_groups_from_text_file_aborts_on_validation_failure() {
    local text_file
    text_file=$(mktemp)
    echo "Invalid-Group" > "$text_file"

    local exit_code=0
    add_groups --file "$text_file" || exit_code=$?

    assert_equal "$exit_code" 1 "Function should exit with 1 on validation failure"
    assert_file_contains "$MOCK_LOG" "Validation failed for group 'Invalid-Group'"
    assert_file_not_contains "$MOCK_LOG" "groupadd_called"

    rm "$text_file"
}

# =============================================================================
# --- Run Tests ---
# =============================================================================
run_test_suite