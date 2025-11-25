#!/usr/bin/env bash
# Test suite for: scripts/lib/utils/output.sh

source "$(dirname "$0")/../../../../test_helpers.sh"
source "$(dirname "$0")/../../../../../scripts/lib/utils/output.sh"

# --- Mocks & Stubs ---
_display_banner() { echo "BANNER: $1"; }
_print_operation_summary() { echo "SUMMARY: $*"; }

test__display_results_with_success_and_skipped() {
    local created_json='{"username":"new_user","status":"success","details":{"primary_group":"dev"}}'
    local existing_json='{"username":"existing_user","status":"skipped","reason":"User already exists"}'
    local created_array=("$created_json")
    local existing_array=("$existing_json")
    local failed_array=()

    local output
    output="$(_display_results "Test Operation" "$(declare -p created_array)" "$(declare -p existing_array)" "$(declare -p failed_array)")"

    assert_string_contains "$output" "BANNER: Test Operation"
    assert_string_contains "$output" "SUCCESS: new_user (Primary Group: dev)"
    assert_string_contains "$output" "SKIPPED: existing_user (Reason: User already exists)"
    assert_string_not_contains "$output" "FAILURE:"
    assert_string_contains "$output" "SUMMARY: Total: 2, Success: 1, Skipped: 1, Failed: 0"
}

test__display_results_with_failures() {
    local failed_json='{"username":"bad_user","status":"failed","reason":"Invalid username"}'
    local created_array=()
    local existing_array=()
    local failed_array=("$failed_json")

    local output
    output="$(_display_results "Test Operation" "$(declare -p created_array)" "$(declare -p existing_array)" "$(declare -p failed_array)")"

    assert_string_contains "$output" "BANNER: Test Operation"
    assert_string_not_contains "$output" "SUCCESS:"
    assert_string_not_contains "$output" "SKIPPED:"
    assert_string_contains "$output" "FAILURE: bad_user (Reason: Invalid username)"
    assert_string_contains "$output" "SUMMARY: Total: 1, Success: 0, Skipped: 0, Failed: 1"
}

run_test_suite