#!/bin/bash
# =================================================================================================
#
# LIBRARY: user_add
#
# This library contains functions for adding users and groups to the system. It supports
# adding single users, batch additions from text or JSON files, and a comprehensive
# provisioning mode that creates both groups and users from a single JSON file.
#
# It is designed to be sourced and used by other scripts, primarily 'user.sh'.
#
# -------------------------------------------------------------------------------------------------
#
# FUNCTIONS:
#   - _add_user_status_to_array: Helper to build and add user status JSON to an array.
#   - _add_single_user: Core logic for creating a single user.
#   - _add_users_core: Core logic for batch-adding users from a text or JSON file.
#   - _provision_users_and_groups_core: Core logic for provisioning groups and then users.
#   - add_users: Main entry point for all user addition operations.
#
# USAGE:
#   This script is not meant to be executed directly. It should be sourced by other scripts like
#   the main 'user.sh' script.
#
# =================================================================================================

# =================================================================================================
# PRIVATE HELPER FUNCTIONS
# =================================================================================================

# -------------------------------------------------------------------------------------------------
# FUNCTION: _add_user_status_to_array
# DESCRIPTION:
#   A helper function to build a standardized user status JSON object and add it to a
#   specified array. This centralizes JSON construction for user operations.
#
# PARAMETERS:
#   $1 - target_array (nameref): The name of the array to add the JSON object to.
#   $2 - username: The name of the user.
#   $3 - status: The status of the operation (e.g., "success", "skipped", "failed").
#   $4 - For "success": The user's primary group.
#   $5 - For "success": The user's secondary groups.
#   $6 - For "success": The user's shell.
#   $4 - For "skipped" or "failed": The reason for the status.
# -------------------------------------------------------------------------------------------------
_add_user_status_to_array() {
    local -n target_array=$1
    local username=$2
    local status=$3
    local json_obj

    case "$status" in
        "success")
            local primary_group=$4
            local secondary_groups=$5
            local shell=$6
            json_obj=$(jq -n \
                --arg u "$username" \
                --arg pg "$primary_group" \
                --arg sg "$secondary_groups" \
                --arg sh "$shell" \
                '{username: $u, status: "success", details: {primary_group: $pg, secondary_groups: $sg, shell: $sh}}')
            ;;
        "skipped"|"failed")
            local reason=$4
            json_obj=$(jq -n \
                --arg u "$username" \
                --arg s "$status" \
                --arg r "$reason" \
                '{username: $u, status: $s, reason: $r}')
            ;;
    esac
    target_array+=("$json_obj")
}

# =================================================================================================
# CORE FUNCTIONS
# =================================================================================================

# =================================================================================================
# FUNCTION: _add_single_user
# DESCRIPTION:
#   Creates a single user on the system. It validates the username, checks for existing
#   users, and constructs the appropriate useradd command based on provided parameters.
#
# PARAMETERS:
#   $1 - username: The name of the user to create.
#   $2 - primary_group: The primary group for the user. If empty, a group with the same
#        name as the user is created.
#   $3 - secondary_groups: A comma-separated list of secondary groups. Can be empty.
#   $4 - shell_access: The shell to assign to the user. Defaults to "/bin/bash".
#
# GLOBALS:
#   DRY_RUN: If set to "true", logs the intended action instead of executing.
#
# OUTPUTS:
#   Logs the result of the operation.
#
# RETURNS:
#   0 - Success
#   1 - Hard failure (invalid input, command failed)
#   2 - Soft failure (user already exists)
# -------------------------------------------------------------------------------------------------
_add_single_user() {
    local username=$1
    local primary_group=$2
    local secondary_groups=$3
    local shell_access=${4:-"/bin/bash"}

    # Validate username
    if ! validate_name "$username" "user"; then
        echo "Invalid username format"
        log_action "ERROR" "User creation failed: '$username' is not a valid username."
        return 1
    fi

    # Check if user already exists
    if id "$username" &>/dev/null; then
        log_action "INFO" "User '$username' already exists. Skipping."
        return 2
    fi

    # Build useradd command arguments
    local useradd_args=(-m -s "$shell_access")
    if [[ -n "$primary_group" ]]; then
        useradd_args+=(-g "$primary_group")
    else
        useradd_args+=(-g "$username")
    fi
    if [[ -n "$secondary_groups" ]]; then
        useradd_args+=(-G "$secondary_groups")
    fi
    useradd_args+=("$username")

    # Execute or dry-run
    if [[ "$DRY_RUN" == "true" ]]; then
        log_action "DRY-RUN" "Would execute: useradd ${useradd_args[*]}"
        return 0
    else
        log_action "INFO" "Creating user '$username' with command: useradd ${useradd_args[*]}"
        if useradd "${useradd_args[@]}"; then
            log_action "SUCCESS" "User '$username' created successfully."
            return 0
        else
            local error_msg="Failed to create user '$username'."
            log_action "ERROR" "$error_msg"
            echo "$error_msg"
            return 1
        fi
    fi
}

# =================================================================================================
# FUNCTION: _add_users_core
# DESCRIPTION:
#   Processes a list of users from a text file or JSON file, creating them one by one.
#   This function handles both text and JSON formats, delegating to the appropriate
#   parser and creation logic.
#
# PARAMETERS:
#   $1 - input_file: The path to the file containing user definitions.
#   $2 - input_format: The format of the input file ("text" or "json").
#
# GLOBALS:
#   DRY_RUN: Passed to the core creation function.
#
# OUTPUTS:
#   Displays a summary of created, existing, and failed users.
#
# RETURNS:
#   0 - Success (even if some individual operations failed)
# -------------------------------------------------------------------------------------------------
_add_users_core() {
    local input_file=$1
    local input_format=$2
    local created_users=()
    local existing_users=()
    local failed_users=()

    if [[ "$input_format" == "json" ]]; then
        while IFS= read -r user_json; do
            local username=$(echo "$user_json" | jq -r '.username')
            local primary_group=$(echo "$user_json" | jq -r '.primary_group // ""')
            local secondary_groups=$(echo "$user_json" | jq -r '.secondary_groups // ""')
            local shell_access=$(echo "$user_json" | jq -r '.shell // "/bin/bash"')
            local sudo=$(echo "$user_json" | jq -r '.sudo // "no"')

            local error_reason
            error_reason=$(_add_single_user "$username" "$primary_group" "$secondary_groups" "$shell_access")
            local exit_code=$?

            if [[ $exit_code -eq 0 ]]; then
                _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
                # Grant sudo access if specified
                if [[ "$sudo" == "yes" ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        log_action "DRY-RUN" "Would add user '$username' to sudo group."
                    else
                        usermod -aG sudo "$username"
                        if [[ $? -eq 0 ]]; then
                            log_action "SUCCESS" "Added user '$username' to sudo group."
                        else
                            log_action "ERROR" "Failed to add user '$username' to sudo group."
                        fi
                    fi
                fi
            elif [[ $exit_code -eq 2 ]]; then
                _add_user_status_to_array existing_users "$username" "skipped" "User already exists"
            else
                _add_user_status_to_array failed_users "$username" "failed" "$error_reason"
            fi
        done < <(jq -c '.users[]' "$input_file" 2>/dev/null)
    else
        # Text format processing (simplified for single-line usernames)
        while IFS= read -r username; do
            local error_reason
            error_reason=$(_add_single_user "$username")
            local exit_code=$?

            if [[ $exit_code -eq 0 ]]; then
                _add_user_status_to_array created_users "$username" "success" "" "" "/bin/bash"
            elif [[ $exit_code -eq 2 ]]; then
                _add_user_status_to_array existing_users "$username" "skipped" "User already exists"
            else
                _add_user_status_to_array failed_users "$username" "failed" "$error_reason"
            fi
        done < "$input_file"
    fi

    # Display results
    _display_add_users_bash_results "${created_users[@]}" "${existing_users[@]}" "${failed_users[@]}"
}

# =================================================================================================
# FUNCTION: _provision_users_and_groups_core
# DESCRIPTION:
#   Provisions groups and then users from a single JSON file. It first processes all
#   groups defined in the file, then processes all users. This ensures that groups
#   exist before users are created.
#
# PARAMETERS:
#   $1 - json_file: The path to the JSON file containing user and group definitions.
#
# GLOBALS:
#   DRY_RUN: Passed to the core creation functions.
#
# OUTPUTS:
#   Displays a summary of created, existing, and failed users and groups.
#
# RETURNS:
#   0 - Success (even if some individual operations failed)
# -------------------------------------------------------------------------------------------------
_provision_users_and_groups_core() {
    local json_file=$1
    local created_users=()
    local existing_users=()
    local failed_users=()
    local created_groups=()
    local existing_groups=()
    local failed_groups=()
    local -A failed_groups_map=()
    local -A groups_created_in_this_run=()
    local -A users_successfully_created_for_group=()


    # --- 1. Create Groups ---
    log_action "INFO" "Starting group creation phase..."
    while IFS= read -r group_json; do
        local groupname=$(echo "$group_json" | jq -r '.name')
        add_single_group "$groupname"
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            _add_group_status_to_array created_groups "$groupname" "success"
            groups_created_in_this_run["$groupname"]=1
        elif [[ $exit_code -eq 2 ]]; then
            _add_group_status_to_array existing_groups "$groupname" "skipped" "Group already exists"
        else
            _add_group_status_to_array failed_groups "$groupname" "failed" "Failed to create group"
            failed_groups_map["$groupname"]=1
        fi
    done < <(jq -c '.groups[]' "$json_file" 2>/dev/null)

    # --- 2. Create Users ---
    log_action "INFO" "Starting user creation phase..."
    while IFS= read -r user_json; do
        local username=$(echo "$user_json" | jq -r '.username')
        local primary_group=$(echo "$user_json" | jq -r '.primary_group')
        local secondary_groups=$(echo "$user_json" | jq -r '.secondary_groups // ""')
        local shell_access=$(echo "$user_json" | jq -r '.shell // "/bin/bash"')
        local sudo=$(echo "$user_json" | jq -r '.sudo // "no"')

        # Check if the primary group failed to be created
        if [[ ${failed_groups_map["$primary_group"]+abc} ]]; then
            _add_user_status_to_array failed_users "$username" "failed" "Skipped because primary group '$primary_group' creation failed"
            continue
        fi

        local error_reason
        error_reason=$(_add_single_user "$username" "$primary_group" "$secondary_groups" "$shell_access")
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
            users_successfully_created_for_group["$primary_group"]=1
            # Grant sudo access if specified
            if [[ "$sudo" == "yes" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_action "DRY-RUN" "Would add user '$username' to sudo group."
                else
                    usermod -aG sudo "$username"
                    if [[ $? -eq 0 ]]; then
                        log_action "SUCCESS" "Added user '$username' to sudo group."
                    else
                        log_action "ERROR" "Failed to add user '$username' to sudo group."
                    fi
                fi
            fi
        elif [[ $exit_code -eq 2 ]]; then
            _add_user_status_to_array existing_users "$username" "skipped" "User already exists"
        else
            _add_user_status_to_array failed_users "$username" "failed" "$error_reason"
        fi
    done < <(jq -c '.users[]' "$json_file" 2>/dev/null)

    # --- 3. Rollback Orphaned Groups ---
    log_action "INFO" "Starting rollback phase for orphaned groups..."
    for group in "${!groups_created_in_this_run[@]}"; do
        if [[ ! ${users_successfully_created_for_group["$group"]+abc} ]]; then
            log_action "ROLLBACK" "Deleting group '$group' as no users were successfully created for it."
            delete_single_group "$group"
        fi
    done

    # Display results
    _display_add_users_bash_results "${created_users[@]}" "${existing_users[@]}" "${failed_users[@]}"
    _display_add_groups_bash_results "${created_groups[@]}" "${existing_groups[@]}" "${failed_groups[@]}"
}

# =================================================================================================
# PUBLIC FUNCTIONS
# =================================================================================================

# =================================================================================================
# FUNCTION: add_users
# DESCRIPTION:
#   The main entry point for adding users. It handles command-line argument parsing,
#   input validation, and delegates to the appropriate core function based on the
#   specified mode (single user, batch from text, batch from JSON, or provisioning).
#
# PARAMETERS:
#   $@ - All command-line arguments passed to the function.
#
# OUTPUTS:
#   Displays help text if arguments are invalid or if the help flag is provided.
#   Otherwise, delegates to core functions for output.
#
# RETURNS:
#   0 - Success (even if some individual operations failed)
#   1 - Invalid arguments or input validation failure
# -------------------------------------------------------------------------------------------------
add_users() {
    local input_file=""
    local input_format="text"
    local mode="single"
    local provisioning_mode=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file)
                input_file="$2"
                input_format="text"
                mode="batch"
                shift 2
                ;;
            --json)
                input_file="$2"
                input_format="json"
                mode="batch"
                shift 2
                ;;
            --provision)
                input_file="$2"
                input_format="json"
                mode="provision"
                provisioning_mode=true
                shift 2
                ;;
            --help)
                _display_help "add"
                return 0
                ;;
            *)
                # Single user mode
                local username="$1"
                local primary_group="$2"
                local secondary_groups="$3"
                local shell_access="$4"
                local sudo="$5"
                shift $#
                ;;
        esac
    done

    # Input validation for batch/provisioning modes
    if [[ "$mode" != "single" ]]; then
        if [[ -z "$input_file" ]]; then
            log_action "ERROR" "Input file is required for batch or provisioning mode."
            return 1
        fi
        if [[ ! -f "$input_file" ]]; then
            log_action "ERROR" "Input file not found: $input_file"
            return 1
        fi
    fi

    # Batch validation for batch/provisioning modes
    if [[ "$mode" != "single" ]]; then
        log_action "INFO" "Starting batch validation phase..."
        local validation_errors=0

        # Validate usernames
        while IFS= read -r user_json; do
            local username=$(echo "$user_json" | jq -r '.username')
            if [[ -z "$username" ]]; then
                log_action "ERROR" "Validation failed: Missing username in JSON input."
                ((validation_errors++))
            elif ! validate_name "$username" "user"; then
                log_action "ERROR" "Validation failed: Invalid username format: '$username'"
                ((validation_errors++))
            fi
        done < <(jq -c '.users[]' "$input_file" 2>/dev/null)

        # Validate groups if not in provisioning mode
        if [[ "$provisioning_mode" == false ]]; then
            while IFS= read -r user_json; do
                local primary_group=$(echo "$user_json" | jq -r '.primary_group // ""')
                local secondary_groups=$(echo "$user_json" | jq -r '.secondary_groups // ""')

                # Check primary group existence
                if [[ -n "$primary_group" ]] && ! getent group "$primary_group" &>/dev/null; then
                    log_action "ERROR" "Validation failed: Primary group '$primary_group' does not exist on the system."
                    ((validation_errors++))
                fi

                # Check secondary groups existence
                if [[ -n "$secondary_groups" ]]; then
                    IFS=',' read -ra SEC_GROUPS <<< "$secondary_groups"
                    for group in "${SEC_GROUPS[@]}"; do
                        if ! getent group "$group" &>/dev/null; then
                            log_action "ERROR" "Validation failed: Secondary group '$group' does not exist on the system."
                            ((validation_errors++))
                        fi
                    done
                fi
            done < <(jq -c '.users[]' "$input_file" 2>/dev/null)
        else
            # In provisioning mode, check if groups are defined in the same file
            while IFS= read -r user_json; do
                local primary_group=$(echo "$user_json" | jq -r '.primary_group // ""')
                if [[ -n "$primary_group" ]]; then
                    local group_exists_in_file
                    group_exists_in_file=$(jq --arg pg "$primary_group" '.groups[]? | select(.name == $pg) | .name' "$input_file")
                    if [[ -z "$group_exists_in_file" ]]; then
                        log_action "ERROR" "Validation failed: Primary group '$primary_group' for user is not defined in the provisioning file."
                        ((validation_errors++))
                    fi
                fi
            done < <(jq -c '.users[]' "$input_file" 2>/dev/null)
        fi

        if [[ $validation_errors -gt 0 ]]; then
            log_action "ERROR" "Batch validation failed with $validation_errors error(s). Aborting."
            return 1
        fi
        log_action "SUCCESS" "Batch validation completed successfully."
    fi

    # Execute based on mode
    case "$mode" in
        single)
            _display_banner "User Addition"
            local created_users=()
            local existing_users=()
            local failed_users=()

            local error_reason
            error_reason=$(_add_single_user "$username" "$primary_group" "$secondary_groups" "$shell_access")
            local exit_code=$?

            if [[ $exit_code -eq 0 ]]; then
                _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
                if [[ "$sudo" == "yes" ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        log_action "DRY-RUN" "Would add user '$username' to sudo group."
                    else
                        usermod -aG sudo "$username"
                        if [[ $? -eq 0 ]]; then
                            log_action "SUCCESS" "Added user '$username' to sudo group."
                        else
                            log_action "ERROR" "Failed to add user '$username' to sudo group."
                        fi
                    fi
                fi
            elif [[ $exit_code -eq 2 ]]; then
                _add_user_status_to_array existing_users "$username" "skipped" "User already exists"
            else
                _add_user_status_to_array failed_users "$username" "failed" "$error_reason"
            fi

            _display_add_users_bash_results "${created_users[@]}" "${existing_users[@]}" "${failed_users[@]}"
            return $exit_code
            ;;
        batch)
            _display_banner "User Addition"
            _add_users_core "$input_file" "$input_format"
            ;;
        provision)
            _display_banner "User and Group Provisioning"
            _provision_users_and_groups_core "$input_file"
            ;;
    esac
}