#!/usr/bin/env bash

# Source the function to be tested
source ../../../../scripts/lib/utils/logging.sh
# Source the test helpers
source ../../../../test_helpers.sh

# Mock the 'date' command to return a fixed timestamp
date() {
    echo "2023-10-27 10:00:00"
}

# Test case: INFO log
test_log_action_info() {
    local expected_output="[2023-10-27 10:00:00] [INFO] This is an info message."
    local actual_output
    actual_output=$(log_action "INFO" "This is an info message.")
    assert_equals "$expected_output" "$actual_output" "INFO log message should be formatted correctly."
}

# Test case: WARNING log
test_log_action_warning() {
    local expected_output="[2023-10-27 10:00:00] [WARNING] This is a warning message."
    local actual_output
    actual_output=$(log_action "WARNING" "This is a warning message.")
    assert_equals "$expected_output" "$actual_output" "WARNING log message should be formatted correctly."
}

# Test case: SUCCESS log
test_log_action_success() {
    local expected_output="[2023-10-27 10:00:00] [SUCCESS] This is a success message."
    local actual_output
    actual_output=$(log_action "SUCCESS" "This is a success message.")
    assert_equals "$expected_output" "$actual_output" "SUCCESS log message should be formatted correctly."
}

# Test case: ERROR log
test_log_action_error() {
    local expected_output="[2023-10-27 10:00:00] [ERROR] This is an error message."
    local actual_output
    actual_output=$(log_action "ERROR" "This is an error message.")
    assert_equals "$expected_output" "$actual_output" "ERROR log message should be formatted correctly."
}

# Test case: FATAL log
test_log_action_fatal() {
    # The function should exit with 1, so we test this behavior.
    ( log_action "FATAL" "This is a fatal error." )
    local exit_code=$?
    assert_equals "1" "$exit_code" "FATAL log should cause the script to exit with status 1."
}

# Test case: DRY_RUN log
test_log_action_dry_run() {
    local expected_output="[2023-10-27 10:00:00] [DRY-RUN] This is a dry-run message."
    local actual_output
    actual_output=$(log_action "DRY-RUN" "This is a dry-run message.")
    assert_equals "$expected_output" "$actual_output" "DRY-RUN log message should be formatted correctly."
}

# Run all tests
run_test_suite