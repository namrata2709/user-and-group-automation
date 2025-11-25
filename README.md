# User and Group Automation

A comprehensive command-line tool for managing local user and group accounts on Linux systems. It simplifies standard administrative tasks, supports bulk operations with robust error handling, and provides powerful reporting and querying capabilities.

The script is designed with a modular architecture, separating core logic from utility functions, and includes a comprehensive test suite to ensure reliability.

## Features

*   **User Management**: Add, update, delete, lock, and unlock users.
*   **Group Management**: Add, update, and delete groups.
*   **Bulk Operations**: Perform actions on multiple users or groups at once using text or JSON files.
*   **Reporting**: Generate detailed reports on user and group configurations.
*   **Querying**: View and filter users and groups based on various criteria.
*   **Dry Run Mode**: Simulate operations without making any actual changes to the system.
*   **Configuration File**: Customize default behaviors like password policies and logging.
*   **Extensive Testing**: A full suite of unit and integration tests to ensure code quality.

## Installation

1.  Clone the repository:
    ```bash
    git clone <repository-url>
    ```
2.  Run the installer script, which sets up the main `user` command:
    ```bash
    cd user-and-group-automation
    sudo ./scripts/install.sh
    ```

## Usage

The main script is `user.sh`, which is typically symlinked to `/usr/local/bin/user` by the installer.

```bash
sudo user [COMMAND] [SUBCOMMAND] [OPTIONS]
```

### Commands

*   `add user|group`: Add users or groups.
*   `update user|group`: Update existing users or groups.
*   `delete user|group`: Delete users or groups.
*   `lock user`: Lock a user account.
*   `unlock user`: Unlock a user account.
*   `view users|groups`: View users, groups, or system details.
*   `report`: Generate security, activity, and compliance reports.
*   `export`: Export user and group data to CSV or JSON.
*   `help [topic]`: Show the general help message or help for a specific topic.

### Common Options

*   `--dry-run`: Simulate an operation without making system changes.
*   `--config <path>`: Specify a custom configuration file.
*   `--log-file <path>`: Specify a custom log file.
*   `--json`: Output results in JSON format (for `view`, `report`).

### Examples

#### Add a Single User

```bash
sudo user add user --username alice --password random
```

#### Add Multiple Groups from a File

Create a file named `groups.txt` with one group name per line:
developers
testers


Then run the command:
```bash
sudo user add group --file groups.txt
```

#### Add Users and Groups from a JSON File

Use a JSON file for more complex, transactional provisioning:
```json:provision.json
{
  "groups": [
    {"name": "devops", "gid": "5001"},
    {"name": "cloud", "gid": "5002"}
  ],
  "users": [
    {
      "username": "dave",
      "primary_group": "devops",
      "secondary_groups": "cloud,docker",
      "shell": "/bin/bash"
    }
  ]
}
```

```bash
sudo user add --file provision.json
```

#### View Users

```bash
# View all users
sudo user view users

# View a specific user in JSON format
sudo user view user alice --json
```

## Testing

The project includes a comprehensive test suite located in the `tests` directory. The suite is divided into unit and integration tests. For detailed instructions on running the tests, see the `tests/README.md` file.