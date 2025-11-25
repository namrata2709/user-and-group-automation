# User and Group Automation

A comprehensive command-line tool for managing user and group accounts on EC2 instances. It simplifies standard administrative tasks, supports bulk operations, and provides powerful reporting and querying capabilities.

## Features

*   **User Management**: Add, update, delete, lock, and unlock users.
*   **Group Management**: Add, update, and delete groups.
*   **Bulk Operations**: Perform actions on multiple users or groups at once using text or JSON files.
*   **Role-Based Provisioning**: Standardize user configurations using roles.
*   **Reporting**: Generate reports on user activity, security, and compliance.
*   **Querying**: Filter and view users and groups based on various criteria.
*   **Dry Run Mode**: Simulate operations without making any actual changes.

## Installation

1.  Clone the repository:
    ```bash
    git clone <repository-url>
    ```
2.  Run the installer script:
    ```bash
    cd user-and-group-automation
    sudo ./scripts/install.sh
    ```

## Usage

The main script is `user.sh`. It is located in the `scripts` directory.

```bash
sudo ./scripts/user.sh [OPERATION] [OPTIONS]
```

### Operations

*   `--add`: Add users or groups.
*   `--update`: Update existing users or groups.
*   `--delete`: Delete users or groups.
*   `--lock`: Lock a user account.
*   `--unlock`: Unlock a user account.
*   `--view`: View users, groups, or system details.
*   `--report`: Generate security, activity, and compliance reports.
*   `--export`: Export user and group data to CSV or JSON.
*   `--apply-roles`: Provision users and apply configurations from a role file.
*   `--compliance`: Run system compliance and security checks.
*   `--help [topic]`: Show the general help message or help for a specific topic.

### Common Options

*   `--dry-run`: Simulate an operation without making system changes.
*   `--config <path>`: Specify a custom configuration file.
*   `--log-level <level>`: Set the logging level (e.g., `info`, `debug`, `error`).
*   `--json`: Output results in JSON format (for `--view`, `--report`).

### Examples

#### Add a Single User

```bash
sudo ./scripts/user.sh --add user --name alice --password random
```

#### Add Multiple Users from a File

Create a file named `users.txt` with one username per line:
bob 
charlie


Then run the command:
```bash
sudo ./scripts/user.sh --add user --file users.txt
```

You can also use a JSON file for more complex user creation:
```json:users.json
{
  "users": [
    {
      "username": "dave",
      "comment": "Dave, The Intern",
      "groups": ["interns", "docker"],
      "shell": "/bin/bash"
    }
  ]
}
```

```bash
sudo ./scripts/user.sh --add user --file users.json
```

#### View Users

```bash
# View all users
sudo ./scripts/user.sh --view users

# View a specific user
sudo ./scripts/user.sh --view user alice

# View users with a home directory larger than 1GB
sudo ./scripts/user.sh --view users --where "home_size > '1GB'"
```

## Testing

The test suite is located in the `tests` directory. To run the tests, see the instructions in `tests/README.md`.