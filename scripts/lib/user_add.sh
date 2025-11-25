#!/usr/bin/env bash
# ==============================================================================
#
#          FILE: user_add.sh
#
#         USAGE: source user_add.sh
#                add_users "path/to/users.txt"
#                add_users "path/to/users.json"
#
#   DESCRIPTION: Provides high-level functions to add users individually or in
#                bulk from a text or JSON file. It also handles provisioning
#                users with groups and sudo access. The script is designed with
#                a clear separation between core logic, I/O handling (text vs.
#                JSON), and a public-facing interface for backward compatibility.
#
#       OPTIONS: ---
#  REQUIREMENTS: bash, coreutils, shadow, sudo, jq, and library dependencies.
#          BUGS: ---
#         NOTES: ---
#       AUTHOR: Your Name, your.email@example.com
# ORGANIZATION: Your Company
#      CREATED: YYYY-MM-DD
#     REVISION: 2.0.0
#
# ==============================================================================

# ==============================================================================
# SECTION: CORE LOGIC FUNCTIONS (JSON Out)
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: _add_single_user()
#
# DESCRIPTION:
#   The lowest-level function for creating a single user. It handles the
#   actual 'useradd' command and is intended for internal use by the core
#   functions.
#
# ARGUMENTS:
#   $1: username
#   $2: primary_group (optional)
#   $3: secondary_groups (comma-separated, optional)
#   $4: shell_access (optional)
#
# RETURNS:
#   0 on success, 1 on failure.
# ------------------------------------------------------------------------------
_add_single_user() {
    local username="$1"
    local primary_group="$2"
    local secondary_groups="$3"
    local shell_access="$4"
    local useradd_opts=()

    # Check if user already exists
    if id -u "$username" &>/dev/null; then
        return 1 # User exists
    fi

    [[ -n "$primary_group" ]] && useradd_opts+=("-g" "$primary_group")
    [[ -n "$secondary_groups" ]] && useradd_opts+=("-G" "$secondary_groups")
    [[ -n "$shell_access" ]] && useradd_opts+=("-s" "$shell_access")

    sudo useradd "${useradd_opts[@]}" "$username" &>/dev/null
    return $?
}


# ------------------------------------------------------------------------------
# FUNCTION: _add_users_core()
#
# DESCRIPTION:
#   Core logic for adding multiple users. It takes a pipe-delimited string,
#   iterates through it, and attempts to create each user. It does not read
#   files or print to the console; it only returns a JSON object summarizing
#   the results.
#
# ARGUMENTS:
#   $1: user_data_pipe - A pipe-delimited string ("username|groups|shell").
#
# OUTPUTS:
#   Prints a single JSON string with "created", "existing", and "failed" arrays.
# ------------------------------------------------------------------------------
_add_users_core() {
    local user_data_pipe="$1"
    local created_users=() existing_users=() failed_users=()

    # Process each line from the pipe-delimited string
    while IFS='|' read -r username groups shell; do
        local primary_group=""
        local secondary_groups=""

        # Normalize inputs
        shell=$(normalize_shell "$shell")
        # Split groups into primary and secondary
        if [[ -n "$groups" ]]; then
            primary_group=$(echo "$groups" | cut -d, -f1)
            secondary_groups=$(echo "$groups" | cut -d, -f2-)
        fi

        # Attempt to create the user
        if _add_single_user "$username" "$primary_group" "$secondary_groups" "$shell"; then
            created_users+=("$(jq -n --arg u "$username" '{"username": $u, "status": "success"}')")
        else
            if id -u "$username" &>/dev/null; then
                existing_users+=("$(jq -n --arg u "$username" '{"username": $u, "status": "skipped"}')")
            else
                failed_users+=("$(jq -n --arg u "$username" --arg r "useradd command failed" '{"username": $u, "status": "error", "reason": $r}')")
            fi
        fi
    done <<< "$user_data_pipe"

    # Assemble the final JSON output
    jq -n \
        --argjson created "$(echo "[]" | jq ". + [$(IFS=,; echo "${created_users[*]}")]")" \
        --argjson existing "$(echo "[]" | jq ". + [$(IFS=,; echo "${existing_users[*]}")]")" \
        --argjson failed "$(echo "[]" | jq ". + [$(IFS=,; echo "${failed_users[*]}")]")" \
        '{created: $created, existing: $existing, failed: $failed}'
}


# ------------------------------------------------------------------------------
# FUNCTION: _provision_users_and_groups_core()
#
# DESCRIPTION:
#   Core logic for the end-to-end provisioning process. It creates groups first,
#   then creates users and assigns them to the correct groups and sudo privileges.
#   Returns a single JSON object summarizing all operations.
#
# ARGUMENTS:
#   $1: provisioning_data_pipe - A pipe-delimited string
#       ("username|primary_group|secondary_groups|sudo|shell").
#
# OUTPUTS:
#   Prints a single JSON string with results for groups and users.
# ------------------------------------------------------------------------------
_provision_users_and_groups_core() {
    local provisioning_data_pipe="$1"
    local all_groups user_details
    user_details=$(mktemp)
    # Store details for user processing after group creation
    echo "$provisioning_data_pipe" > "$user_details"

    # --- Group Creation Phase ---
    all_groups=$(cut -d'|' -f2,3 "$user_details" | tr ',' '\n' | sort -u | grep -v '^\s*$')
    local created_groups=() existing_groups=()
    for group in $all_groups; do
        if ! getent group "$group" &>/dev/null; then
            if add_single_group "$group"; then
                created_groups+=("$(jq -n --arg g "$group" '{"groupname": $g, "status": "success"}')")
            fi
        else
            existing_groups+=("$(jq -n --arg g "$group" '{"groupname": $g, "status": "skipped"}')")
        fi
    done

    # --- User Creation Phase ---
    local created_users=() existing_users=() failed_users=()
    while IFS='|' read -r username primary_group secondary_groups sudo shell; do
        shell=$(normalize_shell "$shell")
        sudo=$(normalize_sudo "$sudo")

        if _add_single_user "$username" "$primary_group" "$secondary_groups" "$shell"; then
            created_users+=("$(jq -n --arg u "$username" '{"username": $u, "status": "success"}')")
            # Grant sudo access if specified
            if [[ "$sudo" == "yes" ]]; then
                sudo usermod -aG sudo "$username"
            fi
        else
            if id -u "$username" &>/dev/null; then
                existing_users+=("$(jq -n --arg u "$username" '{"username": $u, "status": "skipped"}')")
            else
                failed_users+=("$(jq -n --arg u "$username" --arg r "useradd command failed" '{"username": $u, "status": "error", "reason": $r}')")
            fi
        fi
    done < "$user_details"
    rm -f "$user_details"

    # --- Assemble Final JSON ---
    jq -n \
        --argjson groups_created "$(echo "[]" | jq ". + [$(IFS=,; echo "${created_groups[*]}")]")" \
        --argjson groups_existing "$(echo "[]" | jq ". + [$(IFS=,; echo "${existing_groups[*]}")]")" \
        --argjson users_created "$(echo "[]" | jq ". + [$(IFS=,; echo "${created_users[*]}")]")" \
        --argjson users_existing "$(echo "[]" | jq ". + [$(IFS=,; echo "${existing_users[*]}")]")" \
        --argjson users_failed "$(echo "[]" | jq ". + [$(IFS=,; echo "${failed_users[*]}")]")" \
        '{
            groups: {created: $groups_created, existing: $groups_existing},
            users: {created: $users_created, existing: $users_existing, failed: $users_failed}
        }'
}


# ==============================================================================
# SECTION: DISPLAY/IO FUNCTIONS (Text and JSON)
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: add_users_from_text()
#
# DESCRIPTION:
#   Reads a simple text file (username per line), calls the core logic,
#   and displays the results in a human-readable format.
# ------------------------------------------------------------------------------
add_users_from_text() {
    local file_path="$1"
    _display_banner "Adding Users" "$file_path"
    # Convert text file to the pipe-delimited format expected by the core function
    local user_data_pipe
    user_data_pipe=$(awk '{print $1"||"}' "$file_path")
    local results
    results=$(_add_users_core "$user_data_pipe")
    _display_add_users_bash_results "$results"
}

# ------------------------------------------------------------------------------
# FUNCTION: add_users_from_json()
#
# DESCRIPTION:
#   Reads a JSON file, transforms it into the internal pipe-delimited format,
#   calls the core logic, and echoes the resulting JSON object.
#   **JSON In -> JSON Out**.
# ------------------------------------------------------------------------------
add_users_from_json() {
    local file_path="$1"
    # Convert JSON to the pipe-delimited format
    local user_data_pipe
    user_data_pipe=$(jq -r '.users[] | "\(.username)|\(.groups // "")|\(.shell // "")"' "$file_path")
    # Call core function and echo its JSON output directly
    _add_users_core "$user_data_pipe"
}

# ------------------------------------------------------------------------------
# FUNCTION: provision_users_from_text()
#
# DESCRIPTION:
#   Reads a detailed text file, calls the core provisioning logic, and
#   displays the results in a human-readable format.
# ------------------------------------------------------------------------------
provision_users_from_text() {
    local file_path="$1"
    _display_banner "Provisioning Users and Groups" "$file_path"
    # Text file format: user|group1,group2|sudo|shell
    local provisioning_data_pipe
    provisioning_data_pipe=$(cat "$file_path")
    local results
    results=$(_provision_users_and_groups_core "$provisioning_data_pipe")
    _display_provision_bash_results "$results"
}

# ------------------------------------------------------------------------------
# FUNCTION: provision_users_from_json()
#
# DESCRIPTION:
#   Reads a detailed JSON file, transforms it to the internal format, calls
#   the core provisioning logic, and echoes the resulting JSON object.
#   **JSON In -> JSON Out**.
# ------------------------------------------------------------------------------
provision_users_from_json() {
    local file_path="$1"
    # Convert JSON to the pipe-delimited format
    local provisioning_data_pipe
    provisioning_data_pipe=$(jq -r '.users[] | "\(.username)|\(.primary_group // "")|\(.secondary_groups // "" | join(","))|\(.sudo // "no")|\(.shell // "/bin/bash")"' "$file_path")
    # Call core function and echo its JSON output directly
    _provision_users_and_groups_core "$provisioning_data_pipe"
}


# ==============================================================================
# SECTION: PUBLIC INTERFACE (Backward Compatibility & Routing)
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: add_users()
#
# DESCRIPTION:
#   A wrapper function that automatically detects if the input file is JSON
#   or a simple text file and calls the appropriate handler.
#
# ARGUMENTS:
#   $1: file_path - Path to the input file.
# ------------------------------------------------------------------------------
add_users() {
    local file_path="$1"
    _ensure_jq
    if ! _validate_input_file "$file_path"; then return 1; fi

    if jq -e . "$file_path" &>/dev/null; then
        add_users_from_json "$file_path"
    else
        add_users_from_text "$file_path"
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: provision_users_with_groups()
#
# DESCRIPTION:
#   A wrapper that detects file type (JSON or text) and routes to the
#   appropriate provisioning function.
#
# ARGUMENTS:
#   $1: file_path - Path to the input file.
# ------------------------------------------------------------------------------
provision_users_with_groups() {
    local file_path="$1"
    _ensure_jq
    if ! _validate_input_file "$file_path"; then return 1; fi

    if jq -e . "$file_path" &>/dev/null; then
        provision_users_from_json "$file_path"
    else
        provision_users_from_text "$file_path"
    fi
}