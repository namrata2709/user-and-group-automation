#!/usr/bin/env bash
# =================================================
# Test Suite for Group Delete Functionality
# =================================================

# Load test helpers
. "$(dirname "$0")"/../scripts/lib/test_helpers.sh
. "$(dirname "$0")"/../scripts/lib/output_helpers.sh
. "$(dirname "$0")"/../scripts/lib/group_delete.sh

# =================================================
# Test Cases
# =================================================

test_delete_single_group_success() {
    # Mocks
    mock_command "getent" "echo 'testgroup:x:1001:'"
    mock_command "groupdel" "echo 'Mocked groupdel success'"

    # Run the function
    delete_group_auto "testgroup"

    # Assertions
    assert_contain "$OUTPUT" "Group deleted" "Should show deletion message"

    # Cleanup
    unmock_command "getent"
    unmock_command "groupdel"
}

test_delete_single_group_does_not_exist() {
    # Mock getent to simulate group not existing
    mock_command "getent" "return 1"

    # Run the function
    delete_group "nonexistentgroup"

    # Assertions
    assert_contain "$OUTPUT" "Group 'nonexistentgroup' does not exist" "Should show group not found error"

    # Cleanup
    unmock_command "getent"
}

test_delete_groups_from_text_file() {
    # Create a dummy text file
    cat > groups_to_delete.txt <<EOL
group1
group2
EOL

    # Mocks
    mock_command "getent" "echo 'mock getent success'"
    mock_command "groupdel" "echo 'mock groupdel success'"

    # Run the function
    delete_groups "groups_to_delete.txt" "text"

    # Assertions
    assert_contain "$OUTPUT" "Deleting Groups from: groups_to_delete.txt" "Should show correct banner"
    assert_contain "$OUTPUT" "Operation Summary" "Should show summary"
    assert_contain "$OUTPUT" "Deleted:         2" "Should report 2 deleted"

    # Cleanup
    unmock_command "getent"
    unmock_command "groupdel"
    rm groups_to_delete.txt
}

test_delete_groups_from_json_file() {
    # Create a dummy JSON file
    cat > groups_to_delete.json <<EOL
{
  "groups": [
    { "name": "devs", "action": "delete" },
    { "name": "admins", "action": "delete" },
    { "name": "testers", "action": "keep" }
  ]
}
EOL

    # Mocks
    mock_command "jq" "jq" # Use real jq
    mock_command "getent" "echo 'mock getent success'"
    mock_command "groupdel" "echo 'mock groupdel success'"

    # Run the function
    delete_groups "groups_to_delete.json" "json"

    # Assertions
    assert_contain "$OUTPUT" "Deleting Groups from: groups_to_delete.json" "Should show correct banner"
    assert_contain "$OUTPUT" "Skipping group 'testers'" "Should skip testers group"
    assert_contain "$OUTPUT" "Operation Summary" "Should show summary"
    assert_contain "$OUTPUT" "Deleted:         2" "Should report 2 deleted"
    assert_contain "$OUTPUT" "Skipped:         1" "Should report 1 skipped"

    # Cleanup
    unmock_command "jq"
    unmock_command "getent"
    unmock_command "groupdel"
    rm groups_to_delete.json
}

# =================================================
# Run Tests
# =================================================
run_test_suite