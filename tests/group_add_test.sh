#!/usr/bin/env bash
# =================================================
# Test Suite for Group Add Functionality
# =================================================

# Load test helpers
. "$(dirname "$0")"/test_helpers.sh
. "$(dirname "$0")"/../scripts/lib/output_helpers.sh
. "$(dirname "$0")"/../scripts/lib/group_add.sh

# =================================================
# Test Cases
# =================================================

test_add_single_group_success() {
    # Mock groupadd and usermod to simulate success
    mock_command "groupadd" "echo 'Mocked groupadd success'"
    mock_command "usermod" "echo 'Mocked usermod success'"

    # Run the function
    add_single_group "testgroup" "user1,user2"

    # Assertions
    assert_contain "$OUTPUT" "Creating group: testgroup" "Should show creation message"
    assert_contain "$OUTPUT" "Added member: user1" "Should show user1 added"
    assert_contain "$OUTPUT" "Added member: user2" "Should show user2 added"
    assert_not_contain "$OUTPUT" "Failed" "Should not show any failure message"

    # Cleanup mocks
    unmock_command "groupadd"
    unmock_command "usermod"
}

test_add_single_group_already_exists() {
    # Mock getent to simulate group existence
    mock_command "getent" "echo 'testgroup:x:1001:'"

    # Run the function
    add_single_group "testgroup" ""

    # Assertions
    assert_contain "$OUTPUT" "Group 'testgroup' already exists. Skipping..." "Should show skipping message"

    # Cleanup mock
    unmock_command "getent"
}

test_add_groups_from_text_file() {
    # Create a dummy text file
    cat > groups.txt <<EOL
# This is a comment
group1
group2
group3 # Inline comment
EOL

    # Mock groupadd
    mock_command "groupadd" "echo 'Mocked groupadd success'"

    # Run the function
    add_groups "groups.txt" "text"

    # Assertions
    assert_contain "$OUTPUT" "Creating group: group1" "Should process group1"
    assert_contain "$OUTPUT" "Creating group: group2" "Should process group2"
    assert_contain "$OUTPUT" "Creating group: group3" "Should process group3"
    assert_contain "$OUTPUT" "Operation Summary" "Should show summary"
    assert_contain "$OUTPUT" "Created:         3" "Should report 3 created"

    # Cleanup
    unmock_command "groupadd"
    rm groups.txt
}

test_add_groups_from_json_file() {
    # Create a dummy JSON file
    cat > groups.json <<EOL
{
  "groups": [
    {
      "name": "devs",
      "action": "create",
      "members": ["alice", "bob"]
    },
    {
      "name": "admins",
      "action": "create"
    },
    {
      "name": "testers",
      "action": "ignore"
    }
  ]
}
EOL

    # Mocks
    mock_command "jq" "jq" # Use real jq
    mock_command "groupadd" "echo 'Mocked groupadd success'"
    mock_command "usermod" "echo 'Mocked usermod success'"
    mock_command "id" "echo 'mock id success'" # Assume users exist

    # Run the function
    add_groups "groups.json" "json"

    # Assertions
    assert_contain "$OUTPUT" "Creating group: devs" "Should process devs group"
    assert_contain "$OUTPUT" "Added member: alice" "Should add alice to devs"
    assert_contain "$OUTPUT" "Creating group: admins" "Should process admins group"
    assert_contain "$OUTPUT" "Skipping group 'testers'" "Should skip testers group"
    assert_contain "$OUTPUT" "Operation Summary" "Should show summary"
    assert_contain "$OUTPUT" "Created:         2" "Should report 2 created"
    assert_contain "$OUTPUT" "Skipped:         1" "Should report 1 skipped"

    # Cleanup
    unmock_command "jq"
    unmock_command "groupadd"
    unmock_command "usermod"
    unmock_command "id"
    rm groups.json
}

test_add_groups_auto_detect_format() {
    # Create a dummy JSON file
    cat > groups.json <<EOL
{ "groups": [{ "name": "autodetect", "action": "create" }] }
EOL

    # Mocks
    mock_command "jq" "jq"
    mock_command "groupadd" "echo 'Mocked groupadd success'"

    # Run with auto-detection
    add_groups "groups.json" "auto"

    # Assertions
    assert_contain "$OUTPUT" "Format: json" "Should auto-detect JSON format"
    assert_contain "$OUTPUT" "Creating group: autodetect" "Should process the group"

    # Cleanup
    unmock_command "jq"
    unmock_command "groupadd"
    rm groups.json
}


# =================================================
# Run Tests
# =================================================
run_test_suite