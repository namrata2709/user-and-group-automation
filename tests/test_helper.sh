#!/usr/bin/env bash

# =============================================================================
#
#          FILE: test_helper.sh
#
#   DESCRIPTION: A robust test helper library for Bash scripts.
#                Provides assertion functions and a test suite runner.
#
# =============================================================================

# --- State and Configuration ---
declare -a TEST_RESULTS
PASSED_COUNT=0
FAILED_COUNT=0
CURRENT_TEST_NAME=""

# ANSI Color Codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Test Runner ---

# Runs a single test function, handling setup, teardown, and result tracking.
run_test() {
    local test_name=$1
    CURRENT_TEST_NAME=$test_name
    
    # Run setup, the test, and teardown in a subshell to isolate them.
    (
        # If setup exists, run it.
        if declare -F | grep -q "setup"; then
            setup
        fi
        
        # Run the actual test function.
        $test_name
    )
    local result=$?
    
    # If teardown exists, run it.
    if declare -F | grep -q "teardown"; then
        teardown
    fi

    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✔ PASSED:${NC} $test_name"
        TEST_RESULTS+=("PASSED: $test_name")
        ((PASSED_COUNT++))
    else
        echo -e "${RED}✖ FAILED:${NC} $test_name (Exit code: $result)"
        TEST_RESULTS+=("FAILED: $test_name")
        ((FAILED_COUNT++))
    fi
    
    CURRENT_TEST_NAME=""
    return $result
}

# Discovers and runs all functions in the calling script that start with "test_".
run_test_suite() {
    local test_functions
    test_functions=$(declare -F | awk '{print $3}' | grep '^test_')
    
    for func in $test_functions; do
        run_test "$func"
    done

    echo -e "\n--- Test Summary ---"
    for result in "${TEST_RESULTS[@]}"; do
        if [[ $result == FAILED* ]]; then
            echo -e "${RED}✖ $result${NC}"
        else
            echo -e "${GREEN}✔ $result${NC}"
        fi
    done
    echo "--------------------"
    echo -e "Total: $((PASSED_COUNT + FAILED_COUNT)), ${GREEN}Passed: $PASSED_COUNT${NC}, ${RED}Failed: $FAILED_COUNT${NC}"
    echo "--------------------"

    # Exit with a non-zero status if any tests failed.
    if [ $FAILED_COUNT -ne 0 ]; then
        exit 1
    fi
    exit 0
}

# --- Assertion Functions ---

# Generic assertion function to reduce boilerplate.
_assert() {
    local condition=$1
    local message=$2
    
    if ! eval "$condition"; then
        echo "Assertion failed in test '$CURRENT_TEST_NAME': $message."
        return 1
    fi
    return 0
}

assert_equal() {
    _assert "[ \"$1\" == \"$2\" ]" "Expected '$2', but got '$1'" || return 1
}

assert_not_equal() {
    _assert "[ \"$1\" != \"$2\" ]" "Did not expect '$2', but got it" || return 1
}

assert_string_contains() {
    # Use [[ ]] for more robust pattern matching.
    _assert "[[ \"$1\" == *\"$2\"* ]]" "Expected to find '$2' in '$1'" || return 1
}

assert_string_not_contains() {
    _assert "[[ \"$1\" != *\"$2\"* ]]" "Did not expect to find '$2' in '$1'" || return 1
}

assert_file_contains() {
    _assert "grep -q -- \"$2\" \"$1\"" "Expected file '$1' to contain '$2'" || return 1
}

assert_file_not_contains() {
    _assert "! grep -q -- \"$2\" \"$1\"" "Expected file '$1' not to contain '$2'" || return 1
}

assert_success() {
    # This assertion must be used immediately after the command it's testing.
    local exit_code=$?
    _assert "[ $exit_code -eq 0 ]" "$1 (Command failed with exit code $exit_code)" || return 1
}

assert_failure() {
    # This assertion must be used immediately after the command it's testing.
    local exit_code=$?
    _assert "[ $exit_code -ne 0 ]" "$1 (Command succeeded but was expected to fail)" || return 1
}

assert_array_contains() {
    local array_name=$1
    local needle=$2
    eval "local arr_values=\"\${$array_name[@]}\""
    _assert "[[ \" ${arr_values[*]} \" =~ \" ${needle} \" ]]" "Expected to find '$needle' in array '$array_name'" || return 1
}