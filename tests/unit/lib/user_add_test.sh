#!/usr/bin/env bash
# =============================================================================
#
#          FILE: user_add_test.sh
#
#         USAGE: ./user_add_test.sh
#
#   DESCRIPTION: Test suite for the user_add.sh library.
#
# =============================================================================

# --- Test Setup ---
source "$(dirname "$0")/../../../test_helpers.sh"
source "$(dirname "$0")/../../../../scripts/lib/utils/validation.sh"
source "$(dirname "$0")/../../../../scripts/lib/utils/logging.sh"
source "$(dirname "$0")/../../../../scripts/lib/utils/output.sh"
source "$(dirname "$0")/../../../../scripts/lib/group_add.sh"
source "$(dirname "$0")/../../../../scripts/lib/user_add.sh"

# --- Mocks & Stubs ---
_display_banner() { :; }
log_action() { echo "LOG: $@" >> "$MOCK_LOG"; }

MOCK_LOG=""
CAPTURED_USERS_CREATED=()
CAPTURED_USERS_EXISTING=()
CAPTURED_USERS_FAILED=()
CAPTURED_GROUPS_CREATED=()
CAPTURED_GROUPS_EXISTING=()
CAPTURED_GROUPS_FAILED=()

useradd() { echo "useradd_called: $*" >> "$MOCK_LOG"; return 0; }
usermod() { echo "usermod_called: $*" >> "$MOCK_LOG"; return 0; }
userdel() { echo "userdel_called: $*" >> "$MOCK_LOG"; return 0; }
groupadd() { echo "groupadd_called: $*" >> "$MOCK_LOG"; return 0; }
delete_single_group() { echo "delete_single_group_called: $*" >> "$MOCK_LOG"; return 0; }

getent() {
    case "$1" in
        group)
            [[ "$2" == "existing_group" ]] && return 0
            [[ "$2" == "dev" ]] && return 0
            [[ "$2" == "test" ]] && return 0
            return 1
            ;;
        passwd)
            [[ "$2" == "existing_user" ]] && return 0
            return 1
            ;;
    esac
}

id() {
    [[ "$1" == "existing_user" ]] && return 0
    return 1
}

_display_add_users_bash_results() {
    CAPTURED_USERS_CREATED=("$1")
    CAPTURED_USERS_EXISTING=("$2")
    CAPTURED_USERS_FAILED=("$3")
}
_display_add_groups_bash_results() {
    CAPTURED_GROUPS_CREATED=("$1")
    CAPTURED_GROUPS_EXISTING=("$2")
    CAPTURED_GROUPS_FAILED=("$3")
}

# --- Test Suite Setup & Teardown ---
setup() {
    MOCK_LOG=$(mktemp)
    CAPTURED_USERS_CREATED=()
    CAPTURED_USERS_EXISTING=()
    CAPTURED_USERS_FAILED=()
    CAPTURED_GROUPS_CREATED=()
    CAPTURED_GROUPS_EXISTING=()
    CAPTURED_GROUPS_FAILED=()
}

teardown() {
    rm -f "$MOCK_LOG"
}

# =============================================================================
# TEST CASES
# =============================================================================

test_add_single_user_success_with_all_params() {
    add_users "new_user" "dev" "test" "/bin/zsh" "yes"
    local expected_json='{"username":"new_user","status":"success","details":{"primary_group":"dev","secondary_groups":"test","shell":"/bin/zsh"}}'
    assert_array_contains CAPTURED_USERS_CREATED "$expected_json"
    assert_file_contains "$MOCK_LOG" "useradd_called: -m -s /bin/zsh -g dev -G test new_user"
    assert_file_contains "$MOCK_LOG" "usermod_called: -aG sudo new_user"
}

test_add_users_from_json_file_success() {
    local json_file
    json_file=$(mktemp)
    cat <<EOF > "$json_file"
{
  "users": [
    { "username": "new_json_user", "primary_group": "dev" },
    { "username": "existing_user" }
  ]
}
EOF
    add_users --json "$json_file"
    assert_array_contains CAPTURED_USERS_CREATED '{"username":"new_json_user","status":"success","details":{"primary_group":"dev","secondary_groups":"","shell":"/bin/bash"}}'
    assert_array_contains CAPTURED_USERS_EXISTING '{"username":"existing_user","status":"skipped","reason":"User already exists"}'
    rm "$json_file"
}

# =============================================================================
# --- Run Tests ---
# =============================================================================
run_test_suite