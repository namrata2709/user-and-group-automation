# Test Suite

This directory contains the test suite for the User and Group Automation scripts. The tests are written in Bash and use a simple, custom test framework.

## Test Structure

The test suite is organized into two main directories:

*   `unit/`: Contains unit tests that verify individual functions in isolation. These tests mock external commands and dependencies to ensure they only test the logic within a specific script.
*   `integration/`: Contains integration tests that verify the end-to-end functionality of the main `user.sh` script. These tests run actual commands and interact with the system filesystem to confirm that users and groups are created, modified, and deleted correctly.

A central helper script, `test_helpers.sh`, provides common assertion functions (`assert_equals`, `assert_command`, etc.) and setup/teardown logic used by all tests.

## Running Tests

To run all tests, execute the test runner script from the project root directory.

> **Warning**: The integration tests create and delete real users and groups. Do not run them on a production system.

```bash
# Grant execute permissions to all test files
chmod +x tests/run_all_tests.sh
chmod +x tests/unit/lib/*.sh
chmod +x tests/unit/lib/utils/*.sh
chmod +x tests/unit/main/*.sh
chmod +x tests/integration/*.sh

# Run all tests
./tests/run_all_tests.sh
```

You can also run test files individually:
```bash
./tests/unit/lib/user_add_test.sh
./tests/integration/add_test.sh
```

## Test Files

### Unit Tests

*   **`unit/main/user_test.sh`**: Tests the main command routing logic in `scripts/user.sh`.
*   **`unit/lib/group_add_test.sh`**: Tests the group creation logic in `scripts/lib/group_add.sh`.
*   **`unit/lib/user_add_test.sh`**: Tests the user creation logic in `scripts/lib/user_add.sh`.
*   **`unit/lib/user_lock_test.sh`**: Tests the user locking/unlocking logic.
*   **`unit/lib/utils/`**: Contains tests for all utility scripts (validation, logging, output, etc.).

### Integration Tests

*   **`integration/add_test.sh`**: Tests the end-to-end `add` command for creating single users, single groups, and batch provisioning from a JSON file. It verifies that users/groups are correctly created on the system and cleans up after itself.

## Adding New Tests

1.  **Determine the Test Type**: Decide if you are writing a unit test (for a specific function) or an integration test (for an end-to-end feature).
2.  **Create or Open the File**:
    *   For a new **unit test**, create a `_test.sh` file in the appropriate subdirectory of `tests/unit/`.
    *   For a new **integration test**, create a file in `tests/integration/`.
3.  **Source Helpers**: Begin the script by sourcing the test helper: `source ../test_helpers.sh` (adjust path as needed).
4.  **Write Test Functions**: Create functions that start with `test_`. Inside, call the code you want to test and use `assert` functions to verify the outcome.
5.  **Run Tests**: Add a call to your new test function within the script and execute it. If you created a new file, remember to make it executable (`chmod +x`).