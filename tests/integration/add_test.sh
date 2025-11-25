#!/bin/bash

# --- Test Setup ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
SCRIPTS_DIR="$SCRIPT_DIR/../../scripts"
TEST_HELPER_PATH="$SCRIPT_DIR/../test_helper.sh"
USER_SCRIPT_PATH="$SCRIPTS_DIR/user.sh"

# Source the necessary files using absolute paths
source "$TEST_HELPER_PATH"
source "$SCRIPTS_DIR/lib/utils/logging.sh" # Source any other direct dependencies if needed

# --- Mocks & Stubs ---
# Integration tests typically use fewer mocks, but you can define them here if needed.

# --- Test Suite Setup & Teardown ---
setup() {
    # This function is called before each test.
    # Create dummy files or users needed for tests.
    # Example: Create a dummy user to test duplicate detection.
    if ! id "existinguser" &>/dev/null; then
        useradd "existinguser"
    fi
}

teardown() {
    # This function is called after each test.
    # Clean up any users, groups, or files created during the test.
    userdel "testuser1" &>/dev/null || true
    userdel "testuser2" &>/dev/null || true
    userdel "existinguser" &>/dev/null || true
    rm -rf /tmp/home/testuser2 /tmp/skel_test
}

# =============================================================================
# TEST CASES
# =============================================================================

# Test: Add a single user with basic options
test_add_single_user_basic() {
    # Run the main user script and capture the output.
    local output
    output=$("$USER_SCRIPT_PATH" add --name "testuser1" --uid "1001" --shell "/bin/bash")
    
    # Assertions
    assert_string_contains "$output" "User 'testuser1' created successfully"
    assert_string_contains "$(getent passwd testuser1)" "testuser1:x:1001:"
}

# Test: Add a user with a specified home directory and skeleton directory
test_add_single_user_with_home_and_skel() {
    # Setup for this specific test
    mkdir -p /tmp/skel_test
    echo "test_file" > /tmp/skel_test/test_file

    # Run
    local output
    output=$("$USER_SCRIPT_PATH" add --name "testuser2" --home "/tmp/home/testuser2" --skel "/tmp/skel_test")

    # Assertions
    assert_string_contains "$output" "User 'testuser2' created successfully"
    # A helper function could be added to test_helper.sh for this
    if [ ! -f "/tmp/home/testuser2/test_file" ]; then
        echo "Assertion failed: File /tmp/home/testuser2/test_file does not exist."
        return 1
    fi
}

# Test: Attempt to add a duplicate user
test_add_duplicate_user() {
    # The 'existinguser' is created in the main setup() function.
    local output
    output=$("$USER_SCRIPT_PATH" add --name "existinguser")

    # Assertions
    assert_string_contains "$output" "User 'existinguser' already exists"
}

# =============================================================================
# --- Run Tests ---
# =============================================================================
run_test_suite