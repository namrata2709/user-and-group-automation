#!/usr/bin/env bash
# Test suite for: scripts/lib/utils/dependency.sh

source "$(dirname "$0")/../../../../test_helpers.sh"
source "$(dirname "$0")/../../../../../scripts/lib/utils/dependency.sh"

test__ensure_jq_found() {
    # Mock command to simulate jq being found
    command() { [[ "$1" == "-v" && "$2" == "jq" ]] && return 0; }
    local output
    output="$(_ensure_jq)"
    assert_empty "$output" "Expected no output when jq is found"
    assert_success
}

test__ensure_jq_not_found() {
    # Mock command to simulate jq not being found
    command() { [[ "$1" == "-v" && "$2" == "jq" ]] && return 1; }
    local output
    output="$(_ensure_jq)"
    local exit_code=$?
    assert_not_empty "$output" "Expected an error message when jq is not found"
    assert_string_contains "$output" "jq is not installed" "The error message should mention that jq is missing"
    assert_equal "$exit_code" "1" "Exit code should be 1 when jq is not found"
}

run_test_suite