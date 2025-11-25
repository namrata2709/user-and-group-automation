#!/usr/bin/env bash
# =================================================
# Test Suite for Validation Logic
# =================================================

# Load test helpers and the script to be tested
. "$(dirname "$0")"/test_helpers.sh
. "$(dirname "$0")"/../scripts/lib/validation.sh

# =================================================
# Test Cases
# =================================================

test_validate_name() {
    local test_name="test_validate_name"
    assert_success "validate_name 'validuser'" "Should allow valid username." "$test_name"
    assert_failure "validate_name 'Invalid-User'" "Should reject username with uppercase letters." "$test_name"
    assert_failure "validate_name 'user-'" "Should reject username ending with a hyphen." "$test_name"
    assert_failure "validate_name '1user'" "Should reject username starting with a number if not allowed (default)." "$test_name"
}

test_validate_uid() {
    local test_name="test_validate_uid"
    assert_success "validate_uid 1005" "Should allow valid UID." "$test_name"
    assert_failure "validate_uid 999" "Should reject UID below 1000." "$test_name"
    assert_failure "validate_uid 'abc'" "Should reject non-numeric UID." "$test_name"
}

test_validate_gid() {
    local test_name="test_validate_gid"
    assert_success "validate_gid 1005" "Should allow valid GID." "$test_name"
    assert_failure "validate_gid 999" "Should reject GID below 1000." "$test_name"
    assert_failure "validate_gid 'abc'" "Should reject non-numeric GID." "$test_name"
}

test_validate_shell() {
    local test_name="test_validate_shell"
    # Mock /etc/shells
    echo "/bin/bash" > /tmp/shells
    echo "/bin/sh" >> /tmp/shells
    
    assert_success "validate_shell '/bin/bash' '/tmp/shells'" "Should allow valid shell." "$test_name"
    assert_failure "validate_shell '/bin/zsh' '/tmp/shells'" "Should reject invalid shell." "$test_name"
    
    rm /tmp/shells
}

test_normalize_shell() {
    local test_name="test_normalize_shell"
    assert_equals "/bin/bash" "$(normalize_shell 'bash')" "Should normalize 'bash' to '/bin/bash'." "$test_name"
    assert_equals "/usr/bin/zsh" "$(normalize_shell '/usr/bin/zsh')" "Should keep full path for shell." "$test_name"
    assert_equals "" "$(normalize_shell '')" "Should handle empty string." "$test_name"
}

# =================================================
# Run Tests
# =================================================
run_test_suite