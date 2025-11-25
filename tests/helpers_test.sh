#!/usr/bin/env bash

# Load test helpers
source "$(dirname "$0")/test_helper.sh"

# Load the script to be tested
source "$(dirname "$0")/../scripts/lib/helpers.sh"

# =============================================================================
# TEST CASES for _ensure_jq
# =============================================================================

test__ensure_jq_found() {
    # Mock command to simulate jq being found
    command() { [[ "$1" == "-v" && "$2" == "jq" ]] && return 0; }

    # Run the function and capture output
    local output
    output="$(_ensure_jq)"

    # Assert that there is no output and the exit code is 0
    assert_empty "$output" "Expected no output when jq is found"
    assert_success "_ensure_jq should succeed when jq is found"
}

test__ensure_jq_not_found() {
    # Mock command to simulate jq not being found
    command() { [[ "$1" == "-v" && "$2" == "jq" ]] && return 1; }

    # Run the function and capture output
    local output
    output="$(_ensure_jq)"
    local exit_code=$?

    # Assert that an error message is printed and the exit code is 1
    assert_not_empty "$output" "Expected an error message when jq is not found"
    assert_string_contains "$output" "jq is not installed" "The error message should mention that jq is missing"
    assert_failure "_ensure_jq should fail when jq is not found"
    assert_equal "$exit_code" "1" "Exit code should be 1 when jq is not found"
}

# Run all tests
run_tests