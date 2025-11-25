#!/usr/bin/env bash
# =================================================
# Test Suite for Main User Script
# =================================================

# Load test helpers
. "$(dirname "$0")"/test_helpers.sh
. "$(dirname "$0")"/../scripts/lib/output_helpers.sh
. "$(dirname "$0")"/../scripts/user.sh

# =================================================
# Test Cases
# =================================================

test_main_routing() {
    # Mock the functions that would be called
    mock_command "handle_view" "echo 'handle_view called'"
    mock_command "handle_add" "echo 'handle_add called'"
    mock_command "handle_delete" "echo 'handle_delete called'"
    mock_command "handle_lock" "echo 'handle_lock called'"
    mock_command "handle_unlock" "echo 'handle_unlock called'"
    mock_command "handle_role" "echo 'handle_role called'"
    mock_command "handle_config" "echo 'handle_config called'"
    mock_command "handle_compliance" "echo 'handle_compliance called'"
    mock_command "show_help" "echo 'show_help called'"

    # Test routing to --view
    main "--view" "users"
    assert_contain "$OUTPUT" "handle_view called" "Should route to handle_view"

    # Test routing to --add
    main "--add" "user"
    assert_contain "$OUTPUT" "handle_add called" "Should route to handle_add"

    # Test routing to --delete
    main "--delete" "user"
    assert_contain "$OUTPUT" "handle_delete called" "Should route to handle_delete"

    # Test routing to --lock
    main "--lock"
    assert_contain "$OUTPUT" "handle_lock called" "Should route to handle_lock"

    # Test routing to --unlock
    main "--unlock"
    assert_contain "$OUTPUT" "handle_unlock called" "Should route to handle_unlock"

    # Test routing to --role
    main "--role" "list"
    assert_contain "$OUTPUT" "handle_role called" "Should route to handle_role"

    # Test routing to --config
    main "--config" "get"
    assert_contain "$OUTPUT" "handle_config called" "Should route to handle_config"

    # Test routing to --compliance
    main "--compliance" "check"
    assert_contain "$OUTPUT" "handle_compliance called" "Should route to handle_compliance"

    # Test routing to --help
    main "--help"
    assert_contain "$OUTPUT" "show_help called" "Should route to show_help"

    # Test routing to help with no arguments
    main
    assert_contain "$OUTPUT" "show_help called" "Should route to show_help with no arguments"

    # Cleanup mocks
    unmock_command "handle_view"
    unmock_command "handle_add"
    unmock_command "handle_delete"
    unmock_command "handle_lock"
    unmock_command "handle_unlock"
    unmock_command "handle_role"
    unmock_command "handle_config"
    unmock_command "handle_compliance"
    unmock_command "show_help"
}

# =================================================
# Run Tests
# =================================================
run_test_suite