#!/bin/bash
# =================================================================================================
#
# LIBRARY: group_add
#
# This library contains functions for adding groups to the system. It supports adding
# single groups, as well as batch additions from text or JSON files.
#
# It is designed to be sourced and used by other scripts.
#
# -------------------------------------------------------------------------------------------------
#
# FUNCTIONS:
#   - add_single_group: Core logic for creating a single group.
#   - parse_groups_from_text: Parses and adds groups from a text file.
#   - parse_groups_from_json: Parses and adds groups from a JSON file.
#   - add_groups: Main entry point for all group addition operations.
#
# USAGE:
#   This script is not meant to be executed directly. It should be sourced by other scripts.
#
# =================================================================================================

# =================================================================================================
# PRIVATE HELPER FUNCTIONS
# =================================================================================================

# -------------------------------------------------------------------------------------------------
# FUNCTION: _add_group_status_to_array
# DESCRIPTION:
#   A helper function to build a standardized group status JSON object and add it to a
#   specified array. This centralizes JSON construction for group operations.
#
# PARAMETERS:
#   $1 - target_array (nameref): The name of the array to add the JSON object to.
#   $2 - groupname: The name of the group.
#   $3 - status: The status of the operation (e.g., "success", "skipped", "failed").
#   $4 - For "skipped" or "failed": The reason for the status.
# -------------------------------------------------------------------------------------------------
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

# =================================================================================================
# FUNCTION: add_single_group
# DESCRIPTION:
#   Creates a single group on the system. It validates the group name and checks if the
#   group already exists.
#
# PARAMETERS:
#   $1 - groupname: The name of the group to create.
#
# GLOBALS:
#   DRY_RUN: If set to "true", logs the intended action instead of executing.
#
# OUTPUTS:
#   Logs the result of the operation.
#
# RETURNS:
#   0 - Success
#   1 - Hard failure (invalid name, command failed)
#   2 - Soft failure (group already exists)
# -------------------------------------------------------------------------------------------------
add_single_group() {
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

# =================================================================================================
# PRIVATE HELPER FUNCTIONS
# =================================================================================================

# -------------------------------------------------------------------------------------------------
# FUNCTION: parse_groups_from_text
# DESCRIPTION:
#   Parses a text file where each line is a group name and adds each group.
#
# PARAMETERS:
#   $1 - filename: The path to the text file.
#
# OUTPUTS:
#   Logs the status of each group addition.
# -------------------------------------------------------------------------------------------------
parse_groups_from_text() {
    local filename=$1
    local created_groups=()
    local existing_groups=()
    local failed_groups=()

    # Batch Validation Phase
    log_action "INFO" "Starting batch validation for groups from text file..."
    local validation_errors=0
    while IFS= read -r groupname || [[ -n "$groupname" ]]; do
        if [[ -z "$groupname" ]]; then
            continue
        fi
        if ! validate_name "$groupname" "group"; then
            log_action "ERROR" "Validation failed: Invalid group name format: '$groupname'"
            ((validation_errors++))
        fi
    done < "$filename"

    if [[ $validation_errors -gt 0 ]]; then
        log_action "ERROR" "Batch validation failed with $validation_errors error(s). Aborting."
        return 1
    fi
    log_action "SUCCESS" "Batch validation completed successfully."

    # Execution Phase
    log_action "INFO" "Starting group creation..."
    while IFS= read -r groupname || [[ -n "$groupname" ]]; do
        add_single_group "$groupname"
        local exit_code=$?
        case $exit_code in
            0) _add_group_status_to_array created_groups "$groupname" "success" ;;
            1) _add_group_status_to_array failed_groups "$groupname" "failed" "Failed to create group" ;;
            2) _add_group_status_to_array existing_groups "$groupname" "skipped" "Group already exists" ;;
        esac
    done < "$filename"

    _display_add_groups_bash_results "${created_groups[@]}" "${existing_groups[@]}" "${failed_groups[@]}"
}

# -------------------------------------------------------------------------------------------------
# FUNCTION: parse_groups_from_json
# DESCRIPTION:
#   Parses a JSON file for a list of groups and adds each one.
#
# PARAMETERS:
#   $1 - filename: The path to the JSON file.
#
# OUTPUTS:
#   Logs the status of each group addition.
# -------------------------------------------------------------------------------------------------
parse_groups_from_json() {
    local filename=$1
    local created_groups=()
    local existing_groups=()
    local failed_groups=()

    # Batch Validation Phase
    log_action "INFO" "Starting batch validation for groups from JSON file..."
    local validation_errors=0
    while IFS= read -r groupname; do
        if [[ -z "$groupname" ]]; then
            log_action "ERROR" "Validation failed: Missing group name in JSON input."
            ((validation_errors++))
        elif ! validate_name "$groupname" "group"; then
            log_action "ERROR" "Validation failed: Invalid group name format: '$groupname'"
            ((validation_errors++))
        fi
    done < <(jq -r '.groups[].name' "$filename")

    if [[ $validation_errors -gt 0 ]]; then
        log_action "ERROR" "Batch validation failed with $validation_errors error(s). Aborting."
        return 1
    fi
    log_action "SUCCESS" "Batch validation completed successfully."

    # Execution Phase
    log_action "INFO" "Starting group creation..."
    while IFS= read -r groupname; do
        add_single_group "$groupname"
        local exit_code=$?
        case $exit_code in
            0) _add_group_status_to_array created_groups "$groupname" "success" ;;
            1) _add_group_status_to_array failed_groups "$groupname" "failed" "Failed to create group" ;;
            2) _add_group_status_to_array existing_groups "$groupname" "skipped" "Group already exists" ;;
        esac
    done < <(jq -r '.groups[].name' "$filename")

    _display_add_groups_bash_results "${created_groups[@]}" "${existing_groups[@]}" "${failed_groups[@]}"
}

# =================================================================================================
# PUBLIC FUNCTIONS
# =================================================================================================

# =================================================================================================
# FUNCTION: add_groups
# DESCRIPTION:
#   The main entry point for adding groups. It handles command-line argument parsing and
#   delegates to the appropriate core function based on the specified mode.
#
# PARAMETERS:
#   $@ - All command-line arguments passed to the function.
#
# OUTPUTS:
#   Displays help text or delegates to other functions for output.
# -------------------------------------------------------------------------------------------------
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

    # Execute based on mode
    if [[ "$mode" == "text" ]]; then
        if [[ ! -f "$input_file" ]]; then
            log_action "ERROR" "File not found: $input_file"
            return 1
        fi
        parse_groups_from_text "$input_file"
    elif [[ "$mode" == "json" ]]; then
        if [[ ! -f "$input_file" ]]; then
            log_action "ERROR" "File not found: $input_file"
            return 1
        fi
        parse_groups_from_json "$input_file"
    else
        # Single group(s) mode
        local created_groups=()
        local existing_groups=()
        local failed_groups=()
        for groupname in "${single_groups[@]}"; do
            add_single_group "$groupname"
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