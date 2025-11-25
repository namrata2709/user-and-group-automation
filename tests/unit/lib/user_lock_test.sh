#!/usr/bin/env bash

# =================================================================
# Test Suite for User Lock/Unlock Functionality
# =================================================================

# --- Test Setup ---
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
LIB_DIR="$SCRIPT_DIR/../../../scripts/lib"
UTILS_DIR="$LIB_DIR/utils"
TEST_HELPER_PATH="$SCRIPT_DIR/../../test_helper.sh"

source "$TEST_HELPER_PATH"
source "$UTILS_DIR/output.sh"
source "$LIB_DIR/user_lock.sh"

# --- Mocks & Stubs ---
MOCK_LOG=""
_display_banner() { :; }
log_action() { echo "LOG: $*" >> "$MOCK_LOG"; }

# Mock for usermod command
usermod() {
    echo "usermod_called: $*" >> "$MOCK_LOG"
    return 0
}

# Mock for passwd command
passwd() {
    echo "passwd_called: $*" >> "$MOCK_LOG"
    return 0
}

# Mock for getent command
getent() {
    case "$2" in
        existing_user|locked_user|unlocked_user|user1|user2)
            echo "$2:x:1001:"
            return 0
        ;;
        *)
            return 1
        ;;
    esac
}

# Mock for passwd -S command
_get_user_lock_status() {
    case "$1" in
        locked_user)
            echo "$1 LK" # Locked
        ;;
        unlocked_user|existing_user|user1|user2)
            echo "$1 PS" # Has a password
        ;;
        *)
            echo "NP" # No password
        ;;
    esac
}


# --- Test Suite Setup & Teardown ---
setup() {
    MOCK_LOG=$(mktemp)
}

teardown() {
    rm -f "$MOCK_LOG"
}

# =================================================
# Test Cases
# =================================================

test_lock_single_user_success() {
    local output
    output=$(lock_users "unlocked_user" --reason "Security audit")
    
    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Locked: 1"
    assert_file_contains "$MOCK_LOG" "usermod_called: -L unlocked_user"
    assert_file_contains "$MOCK_LOG" "LOG: Locked user 'unlocked_user'. Reason: Security audit"
}

test_lock_already_locked_user() {
    local output
    output=$(lock_users "locked_user")

    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Skipped: 1"
    assert_string_contains "$output" "Reason: User is already locked"
    assert_file_not_contains "$MOCK_LOG" "usermod_called"
}

test_lock_non_existent_user() {
    local output
    output=$(lock_users "nonexistentuser")

    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Failed: 1"
    assert_string_contains "$output" "Reason: User does not exist"
}

test_unlock_single_user_success() {
    local output
    output=$(unlock_users "locked_user")
    
    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Unlocked: 1"
    assert_file_contains "$MOCK_LOG" "usermod_called: -U locked_user"
    assert_file_contains "$MOCK_LOG" "LOG: Unlocked user 'locked_user'"
}

test_unlock_already_unlocked_user() {
    local output
    output=$(unlock_users "unlocked_user")

    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Skipped: 1"
    assert_string_contains "$output" "Reason: User is already unlocked"
    assert_file_not_contains "$MOCK_LOG" "usermod_called"
}

test_lock_users_from_text_file() {
    local text_file
    text_file=$(mktemp)
    printf "user1:Reason one\nuser2\n" > "$text_file"

    local output
    output=$(lock_users --file "$text_file")

    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Locked: 2"
    assert_file_contains "$MOCK_LOG" "LOG: Locked user 'user1'. Reason: Reason one"
    assert_file_contains "$MOCK_LOG" "LOG: Locked user 'user2'. Reason: No reason provided"

    rm "$text_file"
}

test_unlock_users_from_json_file() {
    local json_file
    json_file=$(mktemp)
    cat > "$json_file" <<EOL
{
  "users": [
    { "username": "locked_user" },
    { "username": "unlocked_user" }
  ]
}
EOL
    # Mock _get_user_lock_status for this specific test case
    _get_user_lock_status() {
        case "$1" in
            locked_user) echo "$1 LK" ;;
            unlocked_user) echo "$1 PS" ;;
        esac
    }

    local output
    output=$(unlock_users --file "$json_file" --format "json")

    assert_string_contains "$output" "Summary"
    assert_string_contains "$output" "Unlocked: 1"
    assert_string_contains "$output" "Skipped: 1"
    assert_file_contains "$MOCK_LOG" "LOG: Unlocked user 'locked_user'"
    assert_file_not_contains "$MOCK_LOG" "LOG: Unlocked user 'unlocked_user'"

    rm "$json_file"
}


# =================================================
# Run Tests
# =================================================
run_test_suite