#!/usr/bin/env bash
# ==============================================================================
#
#          FILE: user_add.sh
#
#         USAGE: source user_add.sh
#
#   DESCRIPTION: A comprehensive library for adding users and groups. It
#                supports single user creation, batch additions from text or
#                JSON files, and a provisioning mode to create both groups and
#                users from a single JSON file. It is designed to be sourced by
#                other scripts, providing a robust and structured way to manage
#                user creation.
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
# SECTION: CONSTANTS
# ==============================================================================
SUCCESS=0
HARD_FAILURE=1
SOFT_FAILURE=2

# ==============================================================================
# SECTION: PRIVATE HELPER FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: _add_user_status_to_array()
#
# DESCRIPTION:
#   A private helper to build a standardized user status JSON object and add it
#   to a specified array. This centralizes the creation of structured output
#   for user operations, making it easier to track the status of each addition
#   (success, skipped, or failed).
#
# ARGUMENTS:
#   $1 (nameref): The name of the array to which the JSON object will be added.
#   $2: The name of the user.
#   $3: The status of the operation (e.g., "success", "skipped", "failed").
#   $4: For "success", the user's primary group. For "skipped" or "failed",
#       the reason for the status.
#   $5: For "success", the user's secondary groups.
#   $6: For "success", the user's shell.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# FUNCTION: _rollback_user_creation()
#
# DESCRIPTION:
#   A private helper to roll back the creation of a user if a subsequent
#   operation (like adding to sudo) fails. This ensures the system is not left
#   in a partially configured state.
#
# ARGUMENTS:
#   $1: The username to delete.
# ------------------------------------------------------------------------------
_rollback_user_creation() {
    local username=$1
    log_action "ROLLBACK" "Attempting to roll back creation of user '$username'."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_action "DRY-RUN" "Would execute: userdel -r \"$username\""
    else
        if userdel -r "$username"; then
            log_action "SUCCESS" "Successfully rolled back creation of user '$username'."
        else
            log_action "ERROR" "Failed to roll back creation of user '$username'."
        fi
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: _parse_users_from_text()
#
# DESCRIPTION:
#   Parses a text file containing user definitions (one per line) and converts
#   them into a JSON array of user objects. This allows the rest of the script
#   to process text-based batch files as if they were JSON, unifying the
#   processing pipeline.
#
#   The text file can be in a simple format (username only) or a CSV-like
#   format: username,primary_group,secondary_groups,shell,sudo
#
# ARGUMENTS:
#   $1: The path to the text file.
#
# OUTPUTS:
#   Prints a JSON array of user objects to stdout.
# ------------------------------------------------------------------------------
_parse_users_from_text() {
    local input_file=$1
    local json_objects=()

    while IFS=, read -r username primary_group secondary_groups shell sudo; do
        # Trim whitespace from all fields
        username=$(echo "$username" | awk '{$1=$1};1')
        primary_group=$(echo "$primary_group" | awk '{$1=$1};1')
        secondary_groups=$(echo "$secondary_groups" | awk '{$1=$1};1')
        shell=$(echo "$shell" | awk '{$1=$1};1')
        sudo=$(echo "$sudo" | awk '{$1=$1};1')

        # Ignore empty lines or lines starting with #
        if [[ -z "$username" || "$username" == \#* ]]; then
            continue
        fi

        # Build a JSON object for the user
        local user_obj
        user_obj=$(jq -n \
            --arg u "$username" \
            --arg pg "${primary_group:-}" \
            --arg sg "${secondary_groups:-}" \
            --arg sh "${shell:-/bin/bash}" \
            --arg s "${sudo:-no}" \
            '{username: $u, primary_group: $pg, secondary_groups: $sg, shell: $sh, sudo: $s}')
        
        json_objects+=("$user_obj")
    done < "$input_file"

    # Assemble the final JSON array
    jq -n --argjson users "$(printf '%s\n' "${json_objects[@]}" | jq -s '.')" '{"users": $users}'
}

# =================================================================================================
# CORE FUNCTIONS
# =================================================================================================

# ------------------------------------------------------------------------------
# FUNCTION: _add_single_user()
#
# DESCRIPTION:
#   Creates a single user on the system after validating the username and
#   checking for existing users. It constructs the appropriate `useradd`
#   command based on the provided parameters and serves as the fundamental
#   building block for all user creation operations.
#
# ARGUMENTS:
#   $1: The name of the user to create.
#   $2: The primary group for the user. If empty, a group with the same name
#       as the user is created.
#   $3: A comma-separated list of secondary groups (optional).
#   $4: The shell to assign to the user (defaults to "/bin/bash").
#
# GLOBALS:
#   DRY_RUN (read): If set to "true", logs the intended action without making
#                   any actual changes to the system.
#
# RETURNS:
#   SUCCESS (0): On success or if in dry-run mode.
#   HARD_FAILURE (1): On hard failure (e.g., invalid input, `useradd` command fails).
#   SOFT_FAILURE (2): On soft failure (e.g., the user already exists).
# ------------------------------------------------------------------------------
_add_single_user() {
    local username=$1
    local primary_group=$2
    local secondary_groups=$3
    local shell=${4:-"/bin/bash"}

    # Validate username
    if ! validate_name "$username" "user"; then
        echo "Invalid username format"
        log_action "ERROR" "User creation failed: '$username' is not a valid username."
        return $HARD_FAILURE
    fi

    # Check if user already exists
    if id "$username" &>/dev/null; then
        log_action "INFO" "User '$username' already exists. Skipping."
        return $SOFT_FAILURE
    fi

    # Build useradd command arguments
    local useradd_args=(-m -s "$shell")
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
        return $SUCCESS
    else
        log_action "INFO" "Creating user '$username' with command: useradd ${useradd_args[*]}"
        if useradd "${useradd_args[@]}"; then
            log_action "SUCCESS" "User '$username' created successfully."
            return $SUCCESS
        else
            local error_msg="Failed to create user '$username'."
            log_action "ERROR" "$error_msg"
            echo "$error_msg"
            return $HARD_FAILURE
        fi
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: _add_users_core()
#
# DESCRIPTION:
#   Processes a list of users from a JSON input stream (passed as an argument),
#   creating them one by one. This function serves as the unified core for all
#   batch user creation.
#
# ARGUMENTS:
#   $1: A JSON string containing an array of user objects.
#
# GLOBALS:
#   DRY_RUN (read): Passed to the core creation function.
#
# OUTPUTS:
#   Displays a summary of created, existing, and failed users.
# ------------------------------------------------------------------------------
_add_users_core() {
    local created_users=()
    local existing_users=()
    local failed_users=()

    while IFS= read -r user_json; do
        local username=$(echo "$user_json" | jq -r '.username')
        local primary_group=$(echo "$user_json" | jq -r '.primary_group // ""')
        local secondary_groups=$(echo "$user_json" | jq -r '.secondary_groups // ""')
        local shell_access=$(echo "$user_json" | jq -r '.shell // "/bin/bash"')
        local sudo=$(echo "$user_json" | jq -r '.sudo // "no"')

        local error_reason
        _add_single_user "$username" "$primary_group" "$secondary_groups" "$shell_access"
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            # Grant sudo access if specified
            if [[ "$sudo" == "yes" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_action "DRY-RUN" "Would add user '$username' to sudo group."
                    _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
                else
                    usermod -aG sudo "$username"
                    if [[ $? -eq 0 ]]; then
                        log_action "SUCCESS" "Added user '$username' to sudo group."
                        _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
                    else
                        log_action "ERROR" "Failed to add user '$username' to sudo group. Rolling back user creation."
                        _rollback_user_creation "$username"
                        _add_user_status_to_array failed_users "$username" "failed" "Failed to grant sudo privileges."
                    fi
                fi
            else
                _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
            fi
        elif [[ $exit_code -eq 2 ]]; then
            _add_user_status_to_array existing_users "$username" "skipped" "User already exists"
        else
            # The reason is logged by _add_single_user, so we just capture the failure.
            _add_user_status_to_array failed_users "$username" "failed" "Failed during user creation."
        fi
    done < <(jq -c '.users[]')

    # Display results
    _display_add_users_bash_results "${created_users[@]}" "${existing_users[@]}" "${failed_users[@]}"
}

# ------------------------------------------------------------------------------
# FUNCTION: _provision_users_and_groups_core()
#
# DESCRIPTION:
#   Provisions groups and then users from a single JSON file. It first
#   processes all groups, then all users, ensuring that groups exist before
#   users are assigned to them. It also includes a rollback mechanism to
#   delete any newly created groups that have no successfully created users.
#
# ARGUMENTS:
#   $1: The path to the JSON file containing user and group definitions.
#
# GLOBALS:
#   DRY_RUN (read): Passed to the core creation functions.
#
# OUTPUTS:
#   Displays a summary of created, existing, and failed users and groups.
# ------------------------------------------------------------------------------
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
        _add_single_user "$username" "$primary_group" "$secondary_groups" "$shell_access"
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            # Grant sudo access if specified
            if [[ "$sudo" == "yes" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_action "DRY-RUN" "Would add user '$username' to sudo group."
                    # If not a dry run, assume success for status reporting
                    if [[ "$DRY_RUN" != "true" ]]; then
                        users_successfully_created_for_group["$primary_group"]=1
                        _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
                    fi
                else
                    usermod -aG sudo "$username"
                    if [[ $? -eq 0 ]]; then
                        log_action "SUCCESS" "Added user '$username' to sudo group."
                        users_successfully_created_for_group["$primary_group"]=1
                        _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
                    else
                        log_action "ERROR" "Failed to add user '$username' to sudo group. Rolling back user creation."
                        _rollback_user_creation "$username"
                        _add_user_status_to_array failed_users "$username" "failed" "Failed to grant sudo privileges."
                    fi
                fi
            else
                users_successfully_created_for_group["$primary_group"]=1
                _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
            fi
        elif [[ $exit_code -eq 2 ]]; then
            _add_user_status_to_array existing_users "$username" "skipped" "User already exists"
        else
            _add_user_status_to_array failed_users "$username" "failed" "Failed during user creation."
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

# ------------------------------------------------------------------------------
# FUNCTION: add_users()
#
# DESCRIPTION:
#   The main entry point for adding users. It handles command-line argument
#   parsing, input validation, and delegates to the appropriate core function
#   based on the specified mode (single user, batch from text, batch from
#   JSON, or provisioning).
#
# ARGUMENTS:
#   $@: All command-line arguments passed to the function.
#
# RETURNS:
#   0: On success (even if some individual operations failed).
#   1: On invalid arguments or input validation failure.
# ------------------------------------------------------------------------------
add_users() {
    local input_file=""
    local input_format="text"
    local mode="single"
    local provisioning_mode=false
    local json_input_stream=""

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

    # Convert text file to JSON stream if necessary
    if [[ "$mode" == "batch" && "$input_format" == "text" ]]; then
        json_input_stream=$(_parse_users_from_text "$input_file")
        if [[ -z "$json_input_stream" ]]; then
            log_action "ERROR" "Failed to parse text file or file is empty."
            return 1
        fi
        input_file="" # Unset to avoid confusion
    fi

    # Batch validation for batch/provisioning modes
    if [[ "$mode" != "single" ]]; then
        log_action "INFO" "Starting batch validation phase..."
        local validation_errors=0
        local user_source

        if [[ -n "$json_input_stream" ]]; then
            user_source=$(echo "$json_input_stream" | jq -c '.users[]')
        elif [[ -n "$input_file" ]]; then
            user_source=$(jq -c '.users[]' "$input_file" 2>/dev/null)
        fi

        # Validate usernames
        while IFS= read -r user_json; do
            local username=$(echo "$user_json" | jq -r '.username')
            if [[ -z "$username" ]]; then
                log_action "ERROR" "Validation failed: Missing username in input."
                ((validation_errors++))
            elif ! validate_name "$username" "user"; then
                log_action "ERROR" "Validation failed: Invalid username format: '$username'"
                ((validation_errors++))
            fi
        done <<< "$user_source"

        # Validate groups
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
            done <<< "$user_source"
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
            _add_single_user "$username" "$primary_group" "$secondary_groups" "$shell_access"
            local exit_code=$?

            if [[ $exit_code -eq 0 ]]; then
                if [[ "$sudo" == "yes" ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        log_action "DRY-RUN" "Would add user '$username' to sudo group."
                        _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
                    else
                        usermod -aG sudo "$username"
                        if [[ $? -eq 0 ]]; then
                            log_action "SUCCESS" "Added user '$username' to sudo group."
                            _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
                        else
                            log_action "ERROR" "Failed to add user '$username' to sudo group. Rolling back user creation."
                            _rollback_user_creation "$username"
                            _add_user_status_to_array failed_users "$username" "failed" "Failed to grant sudo privileges."
                            exit_code=1 # Ensure the final exit code reflects the failure
                        fi
                    fi
                else
                    _add_user_status_to_array created_users "$username" "success" "$primary_group" "$secondary_groups" "$shell_access"
                fi
            elif [[ $exit_code -eq 2 ]]; then
                _add_user_status_to_array existing_users "$username" "skipped" "User already exists"
            else
                _add_user_status_to_array failed_users "$username" "failed" "Failed during user creation."
            fi

           _display_add_users_bash_results "${created_users[@]}" "${existing_users[@]}" "${failed_users[@]}"
            return $exit_code
            ;;
        batch)
            _display_banner "User Addition"
            if [[ -n "$json_input_stream" ]]; then
                echo "$json_input_stream" | _add_users_core
            else
                cat "$input_file" | _add_users_core
            fi
            ;;
        provision)
            _display_banner "User and Group Provisioning"
            _provision_users_and_groups_core "$input_file"
            ;;
    esac
}