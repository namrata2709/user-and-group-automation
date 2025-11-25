#!/usr/bin/env bash
# =================================================
# Test Suite for Group Delete Functionality
# =================================================

# --- Test Setup ---
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
LIB_DIR="$SCRIPT_DIR/../../../scripts/lib"
UTILS_DIR="$LIB_DIR/utils"
TEST_HELPER_PATH="$SCRIPT_DIR/../../test_helper.sh"

source "$TEST_HELPER_PATH"
source "$UTILS_DIR/output.sh"
source "$LIB_DIR/group_delete.sh"

# --- Mocks & Stubs ---
MOCK_LOG=""
_display_banner() { :; }
log_action() { echo "LOG: $*" >> "$MOCK_LOG"; }

# Mock for groupdel command
groupdel() {
    echo "groupdel_called: $*" >> "$MOCK_LOG"
    return 0
}

# Mock for getent command
getent() {
    if [[ "$1" == "group" && ("$2" == "existing_group" || "$2" == "group1" || "$2" == "group2" || "$2" == "devs" || "$2" == "admins") ]]; then
        echo "$2:x:1001:"
        return 0
    fi
    return 1
}

# --- Test Suite Setup & Teardown ---
setup() {
    MOCK_LOG=$(mktemp)
}

teardown() {
    rm -f "$MOCK_LOG"
}

# =================================================
# Test Cases
# =================================================

test_delete_single_group_success() {
    local output
    output=$(delete_groups "existing_group")
    
    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Deleted: 1"
    assert_file_contains "$MOCK_LOG" "groupdel_called: existing_group"
}

test_delete_single_group_does_not_exist() {
    local output
    output=$(delete_groups "nonexistentgroup")

    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Skipped: 1"
    assert_string_contains "$output" "Reason: Group does not exist"
    assert_file_not_contains "$MOCK_LOG" "groupdel_called"
}

test_delete_groups_from_text_file() {
    local text_file
    text_file=$(mktemp)
    printf "group1\ngroup2\n" > "$text_file"

    local output
    output=$(delete_groups --file "$text_file")

    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Deleted: 2"
    assert_file_contains "$MOCK_LOG" "groupdel_called: group1"
    assert_file_contains "$MOCK_LOG" "groupdel_called: group2"

    rm "$text_file"
}

test_delete_groups_from_json_file() {
    local json_file
    json_file=$(mktemp)
    cat > "$json_file" <<EOL
{
  "groups": [
    { "name": "devs" },
    { "name": "admins" },
    { "name": "testers" }
  ]
}
EOL

    local output
    output=$(delete_groups --file "$json_file" --format "json")

    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Deleted: 2"
    assert_string_contains "$output" "Skipped: 1"
    assert_file_contains "$MOCK_LOG" "groupdel_called: devs"
    assert_file_contains "$MOCK_LOG" "groupdel_called: admins"
    assert_file_not_contains "$MOCK_LOG" "groupdel_called: testers"

    rm "$json_file"
}

# =================================================
# Run Tests
# =================================================
run_test_suite