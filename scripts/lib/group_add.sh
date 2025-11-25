#!/usr/bin/env bash
# ==============================================================================
#
#          FILE: group_add.sh
#
#         USAGE: source group_add.sh
#
#   DESCRIPTION: A library of functions for adding groups to the system. It
#                supports adding single groups, as well as batch additions from
#                text or JSON files. It is designed to be sourced and used by
#                other scripts, providing a structured way to manage group
#                creation.
#
#       OPTIONS: ---
#  REQUIREMENTS: bash, coreutils, jq, getent
#          BUGS: ---
#         NOTES: This script is not meant to be executed directly.
#       AUTHOR: Your Name, your.email@example.com
# ORGANIZATION: Your Company
#      CREATED: YYYY-MM-DD
#     REVISION: 1.2.0
#
# ==============================================================================

# ==============================================================================
# SECTION: PRIVATE HELPER FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: _add_group_status_to_array()
#
# DESCRIPTION:
#   A private helper to build a standardized group status JSON object and add it
#   to a specified array. This centralizes the creation of structured output
#   for group operations, making it easier to track the status of each
#   addition (success, skipped, or failed).
#
# ARGUMENTS:
#   $1 (nameref): The name of the array to which the JSON object will be added.
#   $2: The name of the group.
#   $3: The status of the operation (e.g., "success", "skipped", "failed").
#   $4: The reason for a "skipped" or "failed" status.
# ------------------------------------------------------------------------------
_add_group_status_to_array() {
    local -n target_array=$1
    local groupname=$2
    local status=$3
    local json_obj

    case "$status" in
        "success")
            json_obj=$(jq -n \
                --arg g "$groupname" \
                '{group: $g, status: "success"}')
            ;;
        "skipped"|"failed")
            local reason=$4
            json_obj=$(jq -n \
                --arg g "$groupname" \
                --arg s "$status" \
                --arg r "$reason" \
                '{group: $g, status: $s, reason: $r}')
            ;;
    esac
    target_array+=("$json_obj")
}

# =================================================================================================
# CORE FUNCTIONS
# =================================================================================================

# ------------------------------------------------------------------------------
# FUNCTION: _add_single_group()
#
# DESCRIPTION:
#   Creates a single group on the system after validating its name and ensuring
#   it does not already exist. This function serves as the fundamental building
#   block for all group creation operations.
#
# ARGUMENTS:
#   $1: The name of the group to create.
#
# GLOBALS:
#   DRY_RUN (read): If set to "true", logs the intended action without making
#                   any actual changes to the system.
#
# RETURNS:
#   0: On success or if in dry-run mode.
#   1: On hard failure (e.g., invalid name, `groupadd` command fails).
#   2: On soft failure (e.g., the group already exists).
# ------------------------------------------------------------------------------
_add_single_group() {
    local groupname=$1

    # Validate group name
    if ! validate_name "$groupname" "group"; then
        log_action "ERROR" "Group creation failed: '$groupname' is not a valid group name."
        return 1
    fi

    # Check if group already exists
    if getent group "$groupname" &>/dev/null; then
        log_action "INFO" "Group '$groupname' already exists. Skipping."
        return 2
    fi

    # Execute or dry-run
    if [[ "$DRY_RUN" == "true" ]]; then
        log_action "DRY-RUN" "Would execute: groupadd $groupname"
        return 0
    else
        log_action "INFO" "Creating group '$groupname'..."
        if groupadd "$groupname"; then
            log_action "SUCCESS" "Group '$groupname' created successfully."
            return 0
        else
            log_action "ERROR" "Failed to create group '$groupname'."
            return 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: _add_groups_core()
#
# DESCRIPTION:
#   A core private function to process a list of group names from a unified
#   input stream (stdin). It handles the entire lifecycle for batch group
#   addition.
#
# ARGUMENTS:
#   None. Reads group names from stdin.
#
# OUTPUTS:
#   Logs the status of the batch operation and the result of each group
#   addition.
# ------------------------------------------------------------------------------
_add_groups_core() {
    local created_groups=()
    local existing_groups=()
    local failed_groups=()

    log_action "INFO" "Starting group creation..."
    while IFS= read -r groupname; do
        if [[ -z "$groupname" ]]; then
            continue
        fi
        _add_single_group "$groupname"
        local exit_code=$?
        case $exit_code in
            0) _add_group_status_to_array created_groups "$groupname" "success" ;;
            1) _add_group_status_to_array failed_groups "$groupname" "failed" "Failed to create group" ;;
            2) _add_group_status_to_array existing_groups "$groupname" "skipped" "Group already exists" ;;
        esac
    done

    _display_add_groups_bash_results "${created_groups[@]}" "${existing_groups[@]}" "${failed_groups[@]}"
}

# =================================================================================================
# PUBLIC FUNCTIONS
# =================================================================================================

# ------------------------------------------------------------------------------
# FUNCTION: add_groups()
#
# DESCRIPTION:
#   The main entry point for adding groups. It handles command-line argument
#   parsing and delegates to the appropriate core function based on the
#   specified mode (single, text file, or JSON file).
#
# ARGUMENTS:
#   $@: All command-line arguments passed to the function.
#
# OUTPUTS:
#   Displays a help banner if no arguments are provided or if --help is passed.
#   Delegates to other functions for detailed output.
# ------------------------------------------------------------------------------
add_groups() {
    _display_banner "Group Addition"

    if [[ $# -eq 0 ]]; then
        _display_help "add_groups"
        return 1
    fi

    local mode="single"
    local input_file=""
    local single_groups=()

    # Argument parsing
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file)
                input_file="$2"
                mode="text"
                shift 2
                ;;
            --json)
                input_file="$2"
                mode="json"
                shift 2
                ;;
            --help)
                _display_help "add_groups"
                return 0
                ;;
            *)
                # Single group mode
                single_groups+=("$1")
                shift
                ;;
        esac
    done

    # --- Batch Validation Phase ---
    if [[ "$mode" == "text" || "$mode" == "json" ]]; then
        if [[ ! -f "$input_file" ]]; then
            log_action "ERROR" "File not found: $input_file"
            return 1
        fi

        log_action "INFO" "Starting batch validation for groups from $mode file..."
        local validation_errors=0
        local group_names

        if [[ "$mode" == "json" ]]; then
            group_names=$(jq -r '.groups[].name' "$input_file")
        else
            group_names=$(cat "$input_file")
        fi

        while IFS= read -r groupname; do
            if [[ -z "$groupname" ]]; then
                if [[ "$mode" == "json" ]]; then
                    log_action "ERROR" "Validation failed: Missing group name in JSON input."
                    ((validation_errors++))
                fi
                continue
            fi
            if ! validate_name "$groupname" "group"; then
                log_action "ERROR" "Validation failed: Invalid group name format: '$groupname'"
                ((validation_errors++))
            fi
        done <<< "$group_names"

        if [[ $validation_errors -gt 0 ]]; then
            log_action "ERROR" "Batch validation failed with $validation_errors error(s). Aborting."
            return 1
        fi
        log_action "SUCCESS" "Batch validation completed successfully."
    fi

    # --- Execution Phase ---
    if [[ "$mode" == "text" ]]; then
        cat "$input_file" | _add_groups_core
    elif [[ "$mode" == "json" ]]; then
        jq -r '.groups[].name' "$input_file" | _add_groups_core
    else
        # Single group(s) mode
        local created_groups=()
        local existing_groups=()
        local failed_groups=()
        for groupname in "${single_groups[@]}"; do
            _add_single_group "$groupname"
            local exit_code=$?
            case $exit_code in
                0) _add_group_status_to_array created_groups "$groupname" "success" ;;
                1) _add_group_status_to_array failed_groups "$groupname" "failed" "Failed to create group" ;;
                2) _add_group_status_to_array existing_groups "$groupname" "skipped" "Group already exists" ;;
            esac
        done
        _display_add_groups_bash_results "${created_groups[@]}" "${existing_groups[@]}" "${failed_groups[@]}"
    fi
}