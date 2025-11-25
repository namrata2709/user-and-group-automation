#!/usr/bin/env bash
# =============================================================================
#
#          FILE: help.sh
#
#         USAGE: source help.sh; show_help [command]
#
#   DESCRIPTION: A centralized library for displaying help and usage
#                information for the user management script. It provides
#                a main help page and detailed help for each command.
#
# =============================================================================

# Load shared output helpers for consistent styling
source "$(dirname "$0")/output_helpers.sh"

# =============================================================================
# FUNCTION: show_help
# DESCRIPTION:
#   Displays detailed help information for the script and its commands.
#
# PARAMETERS:
#   $1 - (Optional) The command to show help for (e.g., "add", "view").
# =============================================================================
show_help() {
    local command="$1"
    
    echo -e "${BOLD}User & Group Management Script v2.5.0${NORMAL}"
    echo -e "A comprehensive tool for managing system users and groups."
    echo -e "----------------------------------------------------------"

    if [[ -z "$command" ]]; then
        echo -e "\n${UNDERLINE}USAGE:${NORMAL}"
        echo -e "  ${CYAN}./user.sh ${YELLOW}<command> <action> ${MAGENTA}[options]${NORMAL}"

        echo -e "\n${UNDERLINE}AVAILABLE COMMANDS:${NORMAL}"
        echo -e "  ${YELLOW}--add${NORMAL}         Add a new user or group."
        echo -e "  ${YELLOW}--delete${NORMAL}      Delete an existing user or group."
        echo -e "  ${YELLOW}--update${NORMAL}      Update attributes of a user or group."
        echo -e "  ${YELLOW}--view${NORMAL}        View detailed information about users or groups."
        echo -e "  ${YELLOW}--provision${NORMAL}   Provision users and groups from a single JSON file."
        echo -e "  ${YELLOW}--help${NORMAL}        Show this help message or help for a specific command."

        echo -e "\n${UNDERLINE}EXAMPLES:${NORMAL}"
        echo -e "  ./user.sh --add user myuser"
        echo -e "  ./user.sh --view groups --sort-by member_count"
        echo -e "  ./user.sh --provision --from-file ./config/provision.json"
        echo -e "  ./user.sh --help add"
        exit 0
    fi

    case "$command" in
        add)
            echo -e "\n${BOLD}COMMAND: --add${NORMAL}"
            echo -e "Adds a new user or group."
            echo -e "\n  ${UNDERLINE}ACTIONS:${NORMAL}"
            echo -e "    ${CYAN}user <username>${NORMAL}      - Add a single user."
            echo -e "    ${CYAN}group <groupname>${NORMAL}     - Add a single group."
            echo -e "    ${CYAN}users <file_path>${NORMAL}    - Add users in batch from a text or JSON file."
            echo -e "    ${CYAN}groups <file_path>${NORMAL}   - Add groups in batch from a text or JSON file."
            echo -e "\n  ${UNDERLINE}OPTIONS:${NORMAL}"
            echo -e "    ${MAGENTA}--shell <path>${NORMAL}         - Specify the user's login shell."
            echo -e "    ${MAGENTA}--primary-group <grp>${NORMAL}  - Set the user's primary group."
            echo -e "    ${MAGENTA}--secondary-groups <list>${NORMAL}- Add user to comma-separated secondary groups."
            echo -e "    ${MAGENTA}--json${NORMAL}                - Output results in JSON format."
            ;;
        provision)
            echo -e "\n${BOLD}COMMAND: --provision${NORMAL}"
            echo -e "Provisions users and groups from a single configuration file."
            echo -e "This command creates groups first, then users, with transactional rollback if user creation fails."
            echo -e "\n  ${UNDERLINE}OPTIONS:${NORMAL}"
            echo -e "    ${MAGENTA}--from-file <file_path>${NORMAL} - ${BOLD}Required.${NORMAL} The JSON file containing group and user definitions."
            echo -e "    ${MAGENTA}--json${NORMAL}                   - Output results in JSON format."
            ;;
        delete|update|view)
            echo -e "\n${BOLD}COMMAND: --$command${NORMAL}"
            echo -e "Help for '--$command' is not yet implemented in this new format."
            echo -e "Please refer to the old documentation or script source for now."
            ;;
        *)
            echo -e "${RED}Error: Unknown help topic '$command'.${NORMAL}" >&2
            echo -e "Run './user.sh --help' to see all available commands."
            exit 1
            ;;
    esac
    exit 0
}