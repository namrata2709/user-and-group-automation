#!/usr/bin/env bash

# Load test helpers
source "$(dirname "$0")/test_helper.sh"

# Load the script to be tested
source "$(dirname "$0")/../scripts/lib/user_add.sh"

# =============================================================================
# MOCKS & STUBS
# =============================================================================

# Mock dependencies to avoid actual system changes
_ensure_jq() { return 0; }
_validate_input_file() { return 0; }
_display_banner() { echo "BANNER: $1"; }
_display_add_users_bash_results() { echo "BASH_ADD_RESULTS: $1"; }
_display_provision_bash_results() { echo "BASH_PROVISION_RESULTS: $1"; }

# Mock useradd command to capture its arguments
useradd() {
    echo "useradd_called:$@" >> "$MOCK_LOG"
}

# =============================================================================
# TEST SETUP & TEARDOWN
# =============================================================================

setup() {
    MOCK_LOG=$(mktemp)
}

teardown() {
    rm -f "$MOCK_LOG"
}

# =============================================================================
# TEST CASES
# =============================================================================

test_add_users_from_text_file() {
    local text_file
    text_file=$(mktemp)
    echo "user1" > "$text_file"
    echo "user2" >> "$text_file"

    local output
    output=$(add_users_from_text "$text_file")

    assert_success "add_users_from_text should succeed"
    assert_string_contains "$output" '"users_added":["user1","user2"]' "Should report user1 and user2 as added"

    # Verify useradd was called correctly
    assert_file_contains "$MOCK_LOG" "useradd_called:-m user1" "useradd should be called for user1"
    assert_file_contains "$MOCK_LOG" "useradd_called:-m user2" "useradd should be called for user2"

    rm "$text_file"
}

test_add_users_from_json_file() {
    local json_file
    json_file=$(mktemp)
    cat <<EOF > "$json_file"
{
  "users": [
    { "username": "user3", "shell": "/bin/zsh" },
    { "username": "user4", "groups": ["docker", "dev"] }
  ]
}
EOF

    local output
    output=$(add_users_from_json "$json_file")

    assert_success "add_users_from_json should succeed"
    assert_string_contains "$output" '"users_added":["user3","user4"]' "Should report user3 and user4 as added"

    # Verify useradd was called correctly
    assert_file_contains "$MOCK_LOG" "useradd_called:-m -s /bin/zsh user3" "useradd should be called for user3 with correct shell"
    assert_file_contains "$MOCK_LOG" "useradd_called:-m -G docker,dev user4" "useradd should be called for user4 with correct groups"

    rm "$json_file"
}

test_provision_users_from_json_file() {
    local json_file
    json_file=$(mktemp)
    cat <<EOF > "$json_file"
{
  "roles": {
    "developer": { "groups": ["dev", "docker"], "shell": "/bin/bash" }
  },
  "assignments": [
    { "username": "dev1", "role": "developer" }
  ]
}
EOF

    local output
    output=$(provision_users_from_json "$json_file")

    assert_success "provision_users_from_json should succeed"
    assert_string_contains "$output" '"users_provisioned":["dev1"]' "Should report dev1 as provisioned"

    # Verify useradd was called correctly
    assert_file_contains "$MOCK_LOG" "useradd_called:-m -s /bin/bash -G dev,docker dev1" "useradd should be called for dev1 with role attributes"

    rm "$json_file"
}

test_add_users_handles_invalid_file() {
    local output
    # Mock _validate_input_file to fail
    _validate_input_file() { echo "File not found"; return 1; }
    
    output=$(add_users "nonexistent_file.txt")
    
    assert_failure "add_users should fail for a non-existent file"
    assert_string_contains "$output" "File not found" "Should return the error from _validate_input_file"
}


# =============================================================================
# RUN TESTS
# =============================================================================

run_tests