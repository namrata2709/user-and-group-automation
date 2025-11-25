#!/usr/bin/env bash
# Test suite for: scripts/lib/utils/validation.sh

source "$(dirname "$0")/../../../../test_helpers.sh"
source "$(dirname "$0")/../../../../../scripts/lib/utils/validation.sh"

test_validate_username_valid() {
    assert_success "validate_username 'validuser'" "Should allow valid lowercase username."
    assert_success "validate_username 'user-1'" "Should allow hyphen in username."
}

test_validate_username_invalid() {
    assert_failure "validate_username 'Invalid-User'" "Should reject username with uppercase letters."
    assert_failure "validate_username 'user-'" "Should reject username ending with a hyphen."
    assert_failure "validate_username '-user'" "Should reject username starting with a hyphen."
    assert_failure "validate_username 'us@er'" "Should reject username with special characters."
}

test_validate_group_name_valid() {
    assert_success "validate_group_name 'validgroup'" "Should allow valid lowercase group name."
    assert_success "validate_group_name 'group-1'" "Should allow hyphen in group name."
}

test_validate_group_name_invalid() {
    assert_failure "validate_group_name 'Invalid-Group'" "Should reject group name with uppercase letters."
    assert_failure "validate_group_name 'group-'" "Should reject group name ending with a hyphen."
}

test_validate_shell_path() {
    local mock_shells_file
    mock_shells_file=$(mktemp)
    echo "/bin/bash" > "$mock_shells_file"
    echo "/bin/sh" >> "$mock_shells_file"

    assert_success "validate_shell_path '/bin/bash' '$mock_shells_file'" "Should allow a valid shell from the list."
    assert_failure "validate_shell_path '/bin/zsh' '$mock_shells_file'" "Should reject a shell not in the list."
    assert_failure "validate_shell_path 'bash' '$mock_shells_file'" "Should reject a non-absolute path."

    rm "$mock_shells_file"
}

run_test_suite