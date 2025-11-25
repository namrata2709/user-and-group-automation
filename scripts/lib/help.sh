#!/usr/bin/env bash
# =============================================================================
#
#          FILE: help.sh
#
#         USAGE: source help.sh; _display_help [command]
#
#   DESCRIPTION: A centralized library for displaying help and usage
#                information for the user management script. It provides
#                detailed help for each command.
#
# =============================================================================

# Load shared output helpers for consistent styling
source "$LIB_DIR/utils/output.sh"

# =============================================================================
# FUNCTION: show_general_help
# DESCRIPTION:
#   Displays the main help page with a list of all available commands.
# =============================================================================
show_general_help() {
    display_banner "User Management Script - Help"
    echo -e "${BOLD}USAGE:${NORMAL}"
    echo -e "  user <command> [options]"
    echo
    echo -e "${BOLD}AVAILABLE COMMANDS:${NORMAL}"
    echo -e "  ${CYAN}add${NORMAL}              - Add a new user or users from a file."
    echo -e "  ${CYAN}add-group${NORMAL}        - Add a new group or groups from a file."
    echo -e "  ${CYAN}update${NORMAL}           - Update an existing user's attributes."
    echo -e "  ${CYAN}update-group${NORMAL}     - Update an existing group's attributes."
    echo -e "  ${CYAN}delete${NORMAL}           - Delete a user."
    echo -e "  ${CYAN}delete-group${NORMAL}     - Delete a group."
    echo -e "  ${CYAN}lock${NORMAL}             - Lock a user's account."
    echo -e "  ${CYAN}view${NORMAL}             - View users or groups with filters."
    echo -e "  ${CYAN}export${NORMAL}           - Export user or group data."
    echo -e "  ${CYAN}report${NORMAL}           - Generate system reports."
    echo -e "  ${CYAN}compliance${NORMAL}       - Run compliance checks."
    echo -e "  ${CYAN}help${NORMAL}             - Show this help message or help for a specific command."
    echo
    echo -e "For more detailed help on a specific command, run:"
    echo -e "  user help <command>"
}

# =============================================================================
# FUNCTION: _display_help
# DESCRIPTION:
#   Displays detailed help information for a specific command.
#
# PARAMETERS:
#   $1 - The command to show help for (e.g., "add", "add_groups").
# =============================================================================
_display_help() {
    local command="$1"

    case "$command" in
        "add")
            _display_add_help
            ;;
        "add-group")
            display_banner "Help: Add Group(s)"
            echo -e "${BOLD}DESCRIPTION:${NORMAL}"
            echo -e "  Adds one or more groups to the system."
            echo
            echo -e "${BOLD}USAGE:${NORMAL}"
            echo -e "  user add-group [group1] [group2] ..."
            echo -e "  user add-group --file <path/to/groups.txt>"
            echo -e "  user add-group --json <path/to/groups.json>"
            echo
            echo -e "${BOLD}MODES:${NORMAL}"
            echo -e "  ${UNDERLINE}Single/Multiple Group Mode:${NORMAL}"
            echo -e "    Adds one or more groups specified as arguments."
            echo
            echo -e "  ${UNDERLINE}Batch Mode (--file):${NORMAL}"
            echo -e "    Adds groups from a text file (one group per line)."
            echo
            echo -e "  ${UNDERLINE}Batch Mode (--json):${NORMAL}"
            echo -e "    Adds groups from a JSON file."
            echo -e "    See examples/groups.json for the required format."
            echo
            echo -e "${BOLD}EXAMPLES:${NORMAL}"
            echo -e "  ${GREEN}# Add a single group 'newgroup'${NORMAL}"
            echo -e "  user add-group newgroup"
            echo
            echo -e "  ${GREEN}# Add multiple groups at once${NORMAL}"
            echo -e "  user add-group webdev sysadmin dbadmin"
            echo
            echo -e "  ${GREEN}# Add groups from a JSON file${NORMAL}"
            echo -e "  user add-group --json ./group_list.json"
            ;;

        "provision")
            display_banner "Help: Provision Users and Groups"
            echo -e "${BOLD}DESCRIPTION:${NORMAL}"
            echo -e "  Provisions both groups and users from a single JSON file."
            echo -e "  The script creates all groups first, then creates the users."
            echo
            echo -e "${BOLD}USAGE:${NORMAL}"
            echo -e "  user provision --file <path/to/provision.json>"
            echo
            echo -e "${BOLD}ARGUMENTS:${NORMAL}"
            echo -e "  ${YELLOW}--file <file_path>${NORMAL}: (Required) The JSON file containing group and user definitions."
            echo
            echo -e "${BOLD}EXAMPLE:${NORMAL}"
            echo -e "  ${GREEN}# Provision groups and users from a single file${NORMAL}"
            echo -e "  user provision --file ./config/provision.json"
            ;;

        *)
            echo -e "${RED}Error: Unknown help topic '$command'.${NORMAL}" >&2
            ;;
    esac
    return 0
}

_display_add_help() {
    _display_banner "Help: Add User(s)"
    echo -e "DESCRIPTION:"
    echo -e "  Adds a single user or multiple users in batch from a file."
    echo -e ""
    echo -e "${BOLD}USAGE:${NORMAL}"
    echo -e "  user.sh add --name <username> [--group <group>] [--shell <shell>] [--sudo]"
    echo -e "  user.sh add --file <path/to/users.txt> [--format <tsv|csv>]"
    echo -e "  user.sh add --json <path/to/users.json>"
    echo -e ""
    echo -e "${BOLD}MODES:${NORMAL}"
    echo -e "  ${CYAN}Single User Mode:${NORMAL}"
    echo -e "    Adds one user with specified attributes using flags."
    echo -e "    - ${YELLOW}--name <username>${NORMAL}: (Required) The name of the user."
    echo -e "    - ${YELLOW}--group <group>${NORMAL}: (Optional) The user's primary group. Defaults to config value."
    echo -e "    - ${YELLOW}--secondary-groups <groups>${NORMAL}: (Optional) Comma-separated list of additional groups."
    echo -e "    - ${YELLOW}--shell <shell>${NORMAL}: (Optional) The user's login shell. Defaults to config value."
    echo -e "    - ${YELLOW}--sudo${NORMAL}: (Optional) Flag to grant sudo privileges."
    echo -e "    - ${YELLOW}--password <password>${NORMAL}: (Optional) Set the user's password. Use with caution."
    echo -e ""
    echo -e "  ${CYAN}Batch Mode (--file):${NORMAL}"
    echo -e "    Adds users from a text file (one user per line)."
    echo -e "    Default format: username,primary_group,secondary_groups,shell,sudo"
    echo -e ""
    echo -e "  ${CYAN}Batch Mode (--json):${NORMAL}"
    echo -e "    Adds users from a JSON file."
    echo -e "    See examples/users.json for the required format."
    echo -e ""
    echo -e "${BOLD}EXAMPLES:${NORMAL}"
    echo -e "  # Add a single user 'alice' with the default primary group"
    echo -e "  user.sh add --name alice"
    echo -e ""
    echo -e "  # Add user 'bob' to group 'developers' with a zsh shell and sudo rights"
    echo -e "  user.sh add --name bob --group developers --shell /bin/zsh --sudo"
    echo -e ""
    echo -e "  # Add users from a text file"
    echo -e "  user.sh add --file ./user_list.txt"
}