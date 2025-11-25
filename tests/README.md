# Test Suite

This directory contains the test suite for the User and Group Automation scripts. The tests are written in Bash and use a simple, custom test framework defined in `test_helper.sh`.

## Running Tests

To run all tests, execute the individual test files. You may need to grant execute permissions first.

```bash
chmod +x tests/*.sh
./tests/helpers_test.sh
./tests/output_helpers_test.sh
./tests/user_add_test.sh
```

## Test Files

### `test_helper.sh`

This file contains the core testing functions, such as `assert_success`, `assert_failure`, `assert_string_contains`, etc. It is sourced by all other test files.

### `helpers_test.sh`

This file tests the functions in `scripts/lib/helpers.sh`.

**Coverage:**
*   `_ensure_jq`: Tests that the script correctly checks for the `jq` dependency.

### `output_helpers_test.sh`

This file tests the functions in `scripts/lib/output_helpers.sh`.

**Coverage:**
*   `_display_banner`: Tests that banners are displayed correctly.
*   `_display_add_users_bash_results`: Tests the output for adding users in bash mode.
*   `_display_provision_bash_results`: Tests the output for provisioning users in bash mode.

### `user_add_test.sh`

This file tests the functions in `scripts/lib/user_add.sh`.

**Coverage:**
*   `add_users_from_text`: Tests adding users from a plain text file.
*   `add_users_from_json`: Tests adding users from a JSON file.
*   `provision_users_from_json`: Tests provisioning users from a JSON role file.
*   Error handling for invalid input files.

## Adding New Tests

To add a new test:
1.  Open the relevant test file (e.g., `user_add_test.sh`).
2.  Create a new function that starts with `test_`.
3.  Inside the function, call the function you want to test and use the `assert` functions from `test_helper.sh` to check the results.
4.  Add a call to your new test function in the `run_tests` function at the bottom of the file.