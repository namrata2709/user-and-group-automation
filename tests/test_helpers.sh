#!/usr/bin/env bash
# =================================================
# Test Helper Functions
# =================================================
#
# This script provides a simple set of assertion functions and a test runner
# to facilitate testing of shell scripts.
#
# To use it, source this file in your test script and then define test
# functions with names starting with `test_`. Call `run_test_suite` at the end.
#

# --- Color Codes ---
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_RESET='\033[0m'

# --- Test Counters ---
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# =================================================
# Assertion Functions
# =================================================

# assert_equals <expected> <actual> <message> <test_name>
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    local test_name="$4"
    ((TESTS_RUN++))

    if [ "$expected" == "$actual" ]; then
        ((TESTS_PASSED++))
        echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} $test_name: $message"
    else
        ((TESTS_FAILED++))
        echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} $test_name: $message"
        echo -e "  - Expected: '$expected'"
        echo -e "  - Actual:   '$actual'"
    fi
}

# assert_not_equals <unexpected> <actual> <message> <test_name>
assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="$3"
    local test_name="$4"
    ((TESTS_RUN++))

    if [ "$unexpected" != "$actual" ]; then
        ((TESTS_PASSED++))
        echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} $test_name: $message"
    else
        ((TESTS_FAILED++))
        echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} $test_name: $message"
        echo -e "  - Did not expect: '$unexpected'"
    fi
}

# assert_contain <string> <substring> <message> <test_name>
assert_contain() {
    local string="$1"
    local substring="$2"
    local message="$3"
    local test_name="$4"
    ((TESTS_RUN++))

    if [[ "$string" == *"$substring"* ]]; then
        ((TESTS_PASSED++))
        echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} $test_name: $message"
    else
        ((TESTS_FAILED++))
        echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} $test_name: $message"
        echo -e "  - Expected string to contain: '$substring'"
        echo -e "  - Actual string: '$string'"
    fi
}

# assert_not_contain <string> <substring> <message> <test_name>
assert_not_contain() {
    local string="$1"
    local substring="$2"
    local message="$3"
    local test_name="$4"
    ((TESTS_RUN++))

    if [[ "$string" != *"$substring"* ]]; then
        ((TESTS_PASSED++))
        echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} $test_name: $message"
    else
        ((TESTS_FAILED++))
        echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} $test_name: $message"
        echo -e "  - Expected string to not contain: '$substring'"
    fi
}

# assert_success <command> <message> <test_name>
assert_success() {
    local command="$1"
    local message="$2"
    local test_name="$3"
    ((TESTS_RUN++))

    eval "$command" &> /dev/null
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        ((TESTS_PASSED++))
        echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} $test_name: $message"
    else
        ((TESTS_FAILED++))
        echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} $test_name: $message"
        echo -e "  - Command failed with exit code $exit_code: $command"
    fi
}

# assert_failure <command> <message> <test_name>
assert_failure() {
    local command="$1"
    local message="$2"
    local test_name="$3"
    ((TESTS_RUN++))

    eval "$command" &> /dev/null
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        ((TESTS_PASSED++))
        echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} $test_name: $message"
    else
        ((TESTS_FAILED++))
        echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} $test_name: $message"
        echo -e "  - Command succeeded but was expected to fail: $command"
    fi
}

# =================================================
# Mocking Functions
# =================================================

# mock_command <command_name> <mock_implementation>
mock_command() {
    local command_name="$1"
    local mock_implementation="$2"
    
    # Store the original path if it exists
    if command -v "$command_name" &>/dev/null; then
        eval "ORIGINAL_$(echo $command_name | tr '-' '_')_PATH=$(command -v "$command_name")"
    fi

    # Create a function that acts as the mock
    eval "${command_name}() { ${mock_implementation}; }"
}

# unmock_command <command_name>
unmock_command() {
    local command_name="$1"
    unset -f "$command_name"
    
    # Restore the original path if it was stored
    local original_path_var="ORIGINAL_$(echo $command_name | tr '-' '_')_PATH"
    if [ ! -z "${!original_path_var}" ]; then
        # This part is tricky and often not needed if the original command is in the PATH
        # For simplicity, we'll just unset the function, allowing the shell to find the original command again.
        :
    fi
}

# =================================================
# Test Runner
# =================================================

# display_test_summary
display_test_summary() {
    echo -e "\n--- Test Summary ---"
    echo -e "Total tests: $TESTS_RUN"
    echo -e "${COLOR_GREEN}Passed: $TESTS_PASSED${COLOR_RESET}"
    echo -e "${COLOR_RED}Failed: $TESTS_FAILED${COLOR_RESET}"
    echo "--------------------"

    if [ "$TESTS_FAILED" -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# run_test_suite
run_test_suite() {
    echo "================================================="
    echo "Starting Test Suite: $(basename "$0")"
    echo "================================================="

    # Find all functions in this file that start with "test_"
    local test_functions
    test_functions=$(declare -F | awk '{print $3}' | grep '^test_')

    # Run each test function
    for func in $test_functions; do
        $func
    done

    display_test_summary
}