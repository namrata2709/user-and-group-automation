#!/usr/bin/env bash
# =================================================
# Test Suite for Expression Parser
# =================================================

# Load test helpers and the script to be tested
. "$(dirname "$0")"/test_helpers.sh
. "$(dirname "$0")"/../scripts/lib/expression_parser.sh

# =================================================
# Mock Data
# =================================================
# A sample user data object for testing eval_expression
read -r -d '' SAMPLE_USER_DATA << EOM
username='testuser'
uid='1001'
gid='1001'
groups='testgroup,othergroup'
home_directory='/home/testuser'
shell='/bin/bash'
last_login='2023-10-27 10:00:00'
password_last_set='2023-10-01'
home_size='150M'
EOM

# =================================================
# Test Cases
# =================================================

test_validate_expression() {
    local test_name="test_validate_expression"
    assert_success "validate_expression \"(a == b)\"" "Should pass with balanced parentheses." "$test_name"
    assert_failure "validate_expression \"(a == b))\"" "Should fail with unbalanced parentheses." "$test_name"
    assert_failure "validate_expression \"((a == b)\"" "Should fail with unbalanced parentheses." "$test_name"
}

test_compare_values() {
    local test_name="test_compare_values"
    assert_success "compare_values 10 -eq 10" "Numeric equality" "$test_name"
    assert_failure "compare_values 10 -eq 11" "Numeric inequality" "$test_name"
    assert_success "compare_values 10 -ne 11" "Numeric non-equality" "$test_name"
    assert_success "compare_values 15 -gt 10" "Numeric greater than" "$test_name"
    assert_success "compare_values 5 -lt 10" "Numeric less than" "$test_name"
    assert_success "compare_values 'abc' == 'abc'" "String equality" "$test_name"
    assert_failure "compare_values 'abc' == 'def'" "String inequality" "$test_name"
    assert_success "compare_values 'dev' != 'prod'" "String non-equality" "$test_name"
    assert_success "compare_values 'test-user' LIKE 'test*'" "LIKE operator" "$test_name"
    assert_failure "compare_values 'prod-user' LIKE 'test*'" "LIKE operator mismatch" "$test_name"
    assert_success "compare_values 'my-string' MATCHES 'my-.*'" "MATCHES operator" "$test_name"
    assert_failure "compare_values 'my-string' MATCHES 'your-.*'" "MATCHES operator mismatch" "$test_name"
    assert_success "compare_values 'apple' IN 'apple,banana,cherry'" "IN operator success" "$test_name"
    assert_failure "compare_values 'durian' IN 'apple,banana,cherry'" "IN operator failure" "$test_name"
    assert_success "compare_values 'banana' CONTAINS 'an'" "CONTAINS operator success" "$test_name"
    assert_failure "compare_values 'banana' CONTAINS 'z'" "CONTAINS operator failure" "$test_name"
}

test_convert_to_bytes() {
    local test_name="test_convert_to_bytes"
    assert_equals "1024" "$(convert_to_bytes '1K')" "1K to bytes" "$test_name"
    assert_equals "2097152" "$(convert_to_bytes '2M')" "2M to bytes" "$test_name"
    assert_equals "3221225472" "$(convert_to_bytes '3G')" "3G to bytes" "$test_name"
    assert_equals "123" "$(convert_to_bytes '123')" "Plain number to bytes" "$test_name"
}

test_eval_comparison() {
    local test_name="test_eval_comparison"
    assert_success "eval_comparison \"'testuser'\" \"==\" \"'testuser'\"" "String equality" "$test_name"
    assert_success "eval_comparison \"1001\" \">\" \"1000\"" "Numeric greater than" "$test_name"
    assert_success "eval_comparison \"'my-user'\" \"LIKE\" \"'my-*'\"" "LIKE operator" "$test_name"
    assert_success "eval_comparison \"'dev,test,prod'\" \"CONTAINS\" \"'test'\"" "CONTAINS operator" "$test_name"
}

test_eval_expression() {
    local test_name="test_eval_expression"
    
    # Simple true
    assert_success "eval_expression \"uid > 1000\" \"$SAMPLE_USER_DATA\"" "uid > 1000 should be true" "$test_name"
    
    # Simple false
    assert_failure "eval_expression \"uid < 1000\" \"$SAMPLE_USER_DATA\"" "uid < 1000 should be false" "$test_name"
    
    # AND operator (true)
    assert_success "eval_expression \"uid > 1000 AND shell == '/bin/bash'\" \"$SAMPLE_USER_DATA\"" "AND operator true" "$test_name"
    
    # AND operator (false)
    assert_failure "eval_expression \"uid > 1000 AND shell == '/bin/zsh'\" \"$SAMPLE_USER_DATA\"" "AND operator false" "$test_name"
    
    # OR operator (true)
    assert_success "eval_expression \"uid < 1000 OR shell == '/bin/bash'\" \"$SAMPLE_USER_DATA\"" "OR operator true" "$test_name"
    
    # OR operator (false)
    assert_failure "eval_expression \"uid < 1000 OR shell == '/bin/zsh'\" \"$SAMPLE_USER_DATA\"" "OR operator false" "$test_name"
    
    # Parentheses
    assert_success "eval_expression \"(uid > 1000 AND shell == '/bin/bash') OR username == 'nobody'\" \"$SAMPLE_USER_DATA\"" "Parentheses with OR" "$test_name"
    
    # NOT operator
    assert_success "eval_expression \"NOT uid < 1000\" \"$SAMPLE_USER_DATA\"" "NOT operator true" "$test_name"
    assert_failure "eval_expression \"NOT uid > 1000\" \"$SAMPLE_USER_DATA\"" "NOT operator false" "$test_name"

    # Home size comparison
    assert_success "eval_expression \"home_size > 100M\" \"$SAMPLE_USER_DATA\"" "Home size > 100M" "$test_name"
    assert_failure "eval_expression \"home_size < 100M\" \"$SAMPLE_USER_DATA\"" "Home size < 100M" "$test_name"
}

# =================================================
# Run Tests
# =================================================
run_test_suite