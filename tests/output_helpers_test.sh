#!/usr/bin/env bash

# Load test helpers
source "$(dirname "$0")/test_helper.sh"

# Load the script to be tested
source "$(dirname "$0")/../scripts/lib/output_helpers.sh"

# =============================================================================
# MOCKS & STUBS
# =============================================================================

# Mock the banner functions to prevent actual printing during tests
_display_banner() {
    echo "BANNER: $1"
}

print_operation_summary() {
    echo "SUMMARY: Total=$1, Success=$3, Skipped=$4, Failed=$5"
}

# =============================================================================
# TEST CASES
# =============================================================================

test__display_banner() {
    local output
    output="$(_display_banner "Test Operation")"

    assert_string_contains "$output" "BANNER: Test Operation" "The banner should display the correct title."
    assert_success
}

test__display_add_users_bash_results_success() {
    local json_result='{"users_added": ["user1", "user2"], "users_skipped": ["user3"], "users_failed": []}'
    local output
    output="$(_display_add_users_bash_results "$json_result")"

    assert_string_contains "$output" "Adding Users" "Should display the correct banner title."
    assert_string_contains "$output" "SUCCESS: user1" "Should list successfully added users."
    assert_string_contains "$output" "SUCCESS: user2" "Should list successfully added users."
    assert_string_contains "$output" "SKIPPED: user3" "Should list skipped users."
    assert_string_contains "$output" "SUMMARY: Total=3, Success=2, Skipped=1, Failed=0" "Should print a correct summary."
    assert_success
}

test__display_add_users_bash_results_with_failures() {
    local json_result='{"users_added": ["user1"], "users_skipped": [], "users_failed": ["user4"]}'
    local output
    output="$(_display_add_users_bash_results "$json_result")"

    assert_string_contains "$output" "Adding Users" "Should display the correct banner title."
    assert_string_contains "$output" "SUCCESS: user1" "Should list successfully added users."
    assert_string_contains "$output" "FAILURE: user4" "Should list failed users."
    assert_string_contains "$output" "SUMMARY: Total=2, Success=1, Skipped=0, Failed=1" "Should print a correct summary."
    assert_success
}

test__display_provision_bash_results_success() {
    local json_result='{"users_provisioned": ["user1", "user2"], "users_skipped": ["user3"], "users_failed": []}'
    local output
    output="$(_display_provision_bash_results "$json_result")"

    assert_string_contains "$output" "Provisioning Users & Groups" "Should display the correct banner title."
    assert_string_contains "$output" "PROVISIONED: user1" "Should list successfully provisioned users."
    assert_string_contains "$output" "PROVISIONED: user2" "Should list successfully provisioned users."
    assert_string_contains "$output" "SKIPPED: user3" "Should list skipped users."
    assert_string_contains "$output" "SUMMARY: Total=3, Success=2, Skipped=1, Failed=0" "Should print a correct summary."
    assert_success
}

test__display_provision_bash_results_with_failures() {
    local json_result='{"users_provisioned": ["user1"], "users_skipped": [], "users_failed": ["user4"]}'
    local output
    output="$(_display_provision_bash_results "$json_result")"

    assert_string_contains "$output" "Provisioning Users & Groups" "Should display the correct banner title."
    assert_string_contains "$output" "PROVISIONED: user1" "Should list successfully provisioned users."
    assert_string_contains "$output" "FAILURE: user4" "Should list failed users."
    assert_string_contains "$output" "SUMMARY: Total=2, Success=1, Skipped=0, Failed=1" "Should print a correct summary."
    assert_success
}


# Run all tests
run_tests