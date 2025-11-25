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
            _display_banner "Help: Add User(s)"
            echo -e "${BOLD}DESCRIPTION:${NORMAL}"
            echo -e "  Adds a single user or multiple users in batch from a file."
            echo
            echo -e "${BOLD}USAGE:${NORMAL}"
            echo -e "  ${CYAN}add_users [username] [primary_group] [secondary_groups] [shell] [sudo]${NORMAL}"
            echo -e "  ${CYAN}add_users --file <path/to/users.txt>${NORMAL}"
            echo -e "  ${CYAN}add_users --json <path/to/users.json>${NORMAL}"
            echo
            echo -e "${BOLD}MODES:${NORMAL}"
            echo -e "  ${UNDERLINE}Single User Mode:${NORMAL}"
            echo -e "    Adds one user with specified attributes."
            echo -e "    - ${YELLOW}username${NORMAL}: (Required) The name of the user."
            echo -e "    - ${YELLOW}primary_group${NORMAL}: (Optional) The user's primary group."
            echo -e "    - ${YELLOW}secondary_groups${NORMAL}: (Optional) Comma-separated list of groups."
            echo -e "    - ${YELLOW}shell${NORMAL}: (Optional) The user's login shell. Defaults to /bin/bash."
            echo -e "    - ${YELLOW}sudo${NORMAL}: (Optional) Set to 'yes' to grant sudo privileges."
            echo
            echo -e "  ${UNDERLINE}Batch Mode (--file):${NORMAL}"
            echo -e "    Adds users from a text file (one user per line)."
            echo -e "    Format: ${CYAN}username,primary_group,secondary_groups,shell,sudo${NORMAL}"
            echo
            echo -e "  ${UNDERLINE}Batch Mode (--json):${NORMAL}"
            echo -e "    Adds users from a JSON file."
            echo -e "    See examples/users.json for the required format."
            echo
            echo -e "${BOLD}EXAMPLES:${NORMAL}"
            echo -e "  ${GREEN}# Add a single user 'testuser' with default settings${NORMAL}"
            echo -e "  add_users testuser"
            echo
            echo -e "  ${GREEN}# Add user 'jane' to group 'developers' with a zsh shell and sudo rights${NORMAL}"
            echo -e "  add_users jane developers dev,www /bin/zsh yes"
            echo
            echo -e "  ${GREEN}# Add users from a text file${NORMAL}"
            echo -e "  add_users --file ./user_list.txt"
            ;;

        "add_groups")
            _display_banner "Help: Add Group(s)"
            echo -e "${BOLD}DESCRIPTION:${NORMAL}"
            echo -e "  Adds one or more groups to the system."
            echo
            echo -e "${BOLD}USAGE:${NORMAL}"
            echo -e "  ${CYAN}add_groups [group1] [group2] ...${NORMAL}"
            echo -e "  ${CYAN}add_groups --file <path/to/groups.txt>${NORMAL}"
            echo -e "  ${CYAN}add_groups --json <path/to/groups.json>${NORMAL}"
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
            echo -e "  add_groups newgroup"
            echo
            echo -e "  ${GREEN}# Add multiple groups at once${NORMAL}"
            echo -e "  add_groups webdev sysadmin dbadmin"
            echo
            echo -e "  ${GREEN}# Add groups from a JSON file${NORMAL}"
            echo -e "  add_groups --json ./group_list.json"
            ;;

        "provision")
            _display_banner "Help: Provision Users and Groups"
            echo -e "${BOLD}DESCRIPTION:${NORMAL}"
            echo -e "  Provisions both groups and users from a single JSON file."
            echo -e "  The script creates all groups first, then creates the users."
            echo -e "  It includes rollback for newly created groups if no users are successfully assigned to them."
            echo
            echo -e "${BOLD}USAGE:${NORMAL}"
            echo -e "  ${CYAN}add_users --provision <path/to/provision.json>${NORMAL}"
            echo
            echo -e "${BOLD}ARGUMENTS:${NORMAL}"
            echo -e "  ${YELLOW}--provision <file_path>${NORMAL}: (Required) The JSON file containing group and user definitions."
            echo
            echo -e "${BOLD}EXAMPLE:${NORMAL}"
            echo -e "  ${GREEN}# Provision groups and users from a single file${NORMAL}"
            echo -e "  add_users --provision ./config/provision.json"
            ;;

        *)
            echo -e "${RED}Error: Unknown help topic '$command'.${NORMAL}" >&2
            ;;
    esac
    return 0
}