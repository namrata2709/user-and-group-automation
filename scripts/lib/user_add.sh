#!/usr/bin/env bash

# =================================================================================================
#
# User Addition Module
#
# Description:
#   This module handles all aspects of user creation. It provides a core function for adding
#   a single user, along with parsers for adding users in bulk from text or JSON files. It also
#   includes functionality for provisioning users and assigning them to groups simultaneously.
#
#   The module is designed to be called from the main 'user.sh' script and relies on global
#   variables for default settings (e.g., shell, password policies).
#
# =================================================================================================

# =================================================================================================
# FUNCTION: add_single_user
# DESCRIPTION:
#   The core function for creating a single new user account. It validates input, constructs
#   the 'useradd' command, executes it, and sets the user's password if provided.
#
# PARAMETERS:
#   $1 - username: The username for the new user.
#   $2 - password: The user's password. Can be a plaintext string or "RANDOM" to generate one.
#   $3 - primary_group: The primary group for the user.
#   $4 - secondary_groups: A comma-separated string of secondary groups.
#   $5 - full_name: The user's full name or comment (GECOS field).
#   $6 - home_dir: The path to the user's home directory.
#   $7 - shell: The user's login shell.
#   $8 - extra_opts: Any additional options to pass directly to the 'useradd' command.
#
# RETURNS:
#   0 if the user is created successfully.
#   1 if there is a failure (e.g., user exists, group not found, command fails).
#   Returns 1 for partial success (e.g., user created but password setting fails).
# =================================================================================================
add_single_user() {
    local username="$1"
    local password="$2"
    local primary_group="$3"
    local secondary_groups="$4"
    local full_name="$5"
    local home_dir="$6"
    local shell="$7"
    local extra_opts="$8"

    # --- Validation ---
    if is_reserved_user "$username"; then
        log_action "ERROR" "User creation failed: '$username' is a reserved username."
        return 1
    fi

    if id "$username" &>/dev/null; then
        log_action "ERROR" "User creation failed: User '$username' already exists."
        return 1
    fi

    if [ -n "$primary_group" ] && ! getent group "$primary_group" &>/dev/null; then
        log_action "ERROR" "User creation failed for '$username': Primary group '$primary_group' does not exist."
        return 1
    fi

    # --- Build useradd command ---
    local cmd="sudo useradd"
    local opts=()

    [ -n "$primary_group" ] && opts+=("-g" "$primary_group")
    [ -n "$secondary_groups" ] && opts+=("-G" "$secondary_groups")
    [ -n "$full_name" ] && opts+=("-c" "\"$full_name\"")
    [ -n "$home_dir" ] && opts+=("-d" "$home_dir")
    [ -n "$shell" ] && opts+=("-s" "$shell")
    [ -n "$extra_opts" ] && opts+=($extra_opts)

    # --- Execute useradd ---
    log_action "INFO" "Attempting to create user '$username'..."
    if eval "$cmd ${opts[*]} '$username'"; then
        log_action "SUCCESS" "User '$username' created successfully."

        # --- Set password if provided ---
        if [ -n "$password" ]; then
            if [[ "$password" == "RANDOM" ]]; then
                password=$(generate_random_password)
                log_action "INFO" "Generated random password for '$username'."
                echo "$username:$password" >> "new_user_passwords.txt"
            fi
            
            if ! echo "$username:$password" | sudo chpasswd; then
                log_action "ERROR" "Failed to set password for user '$username'. The user was created, but password setting failed."
                return 1 # Partial success
            else
                log_action "INFO" "Password set for user '$username'."
            fi
        fi
        return 0
    else
        log_action "ERROR" "Failed to create user '$username'."
        return 1
    fi
}

# =================================================================================================
# FUNCTION: parse_users_from_text
# DESCRIPTION:
#   Parses a text file to add multiple users. It reads the file line by line, extracts user
#   attributes, and calls 'add_single_user' for each entry.
#
# INPUT FORMAT (TEXT):
#   Each line should be in the format:
#   username:comment:expiry:shell:sudo:password
#   - Lines starting with '#' are ignored.
#
# PARAMETERS:
#   $1 - user_file: The absolute path to the text file containing user data.
#
# RETURNS:
#   0 on completion. Prints a summary of the operation.
# =================================================================================================
parse_users_from_text() {
    local user_file="$1"
    
    if [[ ! -f "$user_file" ]]; then
        echo "${ICON_ERROR} User file not found: $user_file"
        return 1
    fi
    
    local count=0 created=0 skipped=0 failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        count=$((count + 1))
        
        # Parse line: username:comment:expiry:shell:sudo:password
        local username comment expiry shell sudo password
        IFS=':' read -r username comment expiry shell sudo password <<< "$line"
        username=$(echo "$username" | xargs)
        
        # Use global overrides if set
        [ -z "$shell" ] && shell="$GLOBAL_SHELL"
        [ -z "$expiry" ] && expiry="$GLOBAL_EXPIRE"
        [ -z "$sudo" ] && [ "$GLOBAL_SUDO" = true ] && sudo="yes"
        [ -z "$password" ] && [ "$GLOBAL_PASSWORD" = "random" ] && password="random"
        
        # Call core function
        if add_single_user "$username" "$password" "" "" "$comment" "" "$shell" ""; then
            ((created++))
        else
            if id "$username" &>/dev/null 2>&1; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < "$user_file"
    
    print_operation_summary "$count" "Created" "$created" "$skipped" "$failed"
    
    return 0
}

# =================================================================================================
# FUNCTION: parse_users_from_json
# DESCRIPTION:
#   Parses a JSON file to add multiple users. It uses 'jq' to process an array of user
#   objects and calls 'add_single_user' for each. This function is intended for machine-readable
#   input and does not produce JSON output itself, but rather executes system actions.
#
# INPUT FORMAT (JSON):
#   A JSON object with a top-level "users" array. Each object in the array represents a user.
#   {
#     "users": [
#       {
#         "username": "jdoe",
#         "comment": "John Doe",
#         "groups": ["developers", "testers"],
#         "shell": "/bin/bash",
#         ...
#       }
#     ]
#   }
#
# PARAMETERS:
#   $1 - json_file: The absolute path to the JSON file.
#
# RETURNS:
#   0 on completion. Prints a summary of the operation.
#   1 if 'jq' is not installed or the JSON is invalid.
# =================================================================================================
parse_users_from_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        echo "${ICON_ERROR} JSON file not found: $json_file"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "${ICON_ERROR} 'jq' is not installed. Please install it to process JSON files."
        return 1
    fi
    
    # Validate JSON syntax and structure
    if ! jq -e '.users' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure. The file must contain a 'users' array."
        return 1
    fi
    
    local count=0 created=0 skipped=0 failed=0
    local start_time=$(date +%s)
    
    # Process each user object from the 'users' array
    while IFS= read -r user_json; do
        ((count++))
        
        # Extract fields from JSON, providing defaults where necessary
        local username=$(echo "$user_json" | jq -r '.username')
        local full_name=$(echo "$user_json" | jq -r '.comment // ""')
        local primary_group=$(echo "$user_json" | jq -r '.primary_group // ""')
        local secondary_groups=$(echo "$user_json" | jq -r '(.secondary_groups // []) | join(",")')
        local shell=$(echo "$user_json" | jq -r ".shell // \"$GLOBAL_SHELL\"")
        local home_dir=$(echo "$user_json" | jq -r '.home_dir // ""')
        local password=$(echo "$user_json" | jq -r '.password // "RANDOM"')

        # Call core function with extracted data
        if add_single_user "$username" "$password" "$primary_group" "$secondary_groups" "$full_name" "$home_dir" "$shell" ""; then
            ((created++))
        else
            if id "$username" &>/dev/null 2>&1; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < <(jq -c '.users[]' "$json_file" 2>/dev/null)
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_operation_summary "$count" "Created" "$created" "$skipped" "$failed" "$duration"
    
    return 0
}

# =================================================================================================
# FUNCTION: add_users
# DESCRIPTION:
#   The main public entry point for the user addition feature. It detects the input file
#   format (text or JSON) and routes to the appropriate parser function.
#
# PARAMETERS:
#   $1 - user_file: The path to the input file.
#   $2 - format: (Optional) The format of the file ("text" or "json"). Auto-detects if omitted.
#
# RETURNS:
#   0 on success, 1 on failure.
# =================================================================================================
add_users() {
    local user_file="$1"
    local format="${2:-auto}"
    
    if [[ ! -f "$user_file" ]]; then
        echo "${ICON_ERROR} User file not found: $user_file"
        return 1
    fi
    
    # Auto-detect format based on file extension if not specified
    if [ "$format" = "auto" ]; then
        if [[ "$user_file" =~ \.json$ ]]; then
            format="json"
        else
            format="text"
        fi
    fi
    
    print_add_user_banner "$user_file" "$format"
    
    # Route to the correct parser
    case "$format" in
        json)
            parse_users_from_json "$user_file"
            ;;
        text|txt)
            parse_users_from_text "$user_file"
            ;;
        *)
            echo "${ICON_ERROR} Unknown format: $format. Supported formats: text, json."
            return 1
            ;;
    esac
}

# =================================================================================================
# FUNCTION: provision_users_and_groups
# DESCRIPTION:
#   Provisions users and groups from a mapping file. It creates groups if they don't exist,
#   creates users if they don't exist (using global defaults), and adds existing or new
#   users to their specified groups.
#
# INPUT FORMAT:
#   Each line should be in the format:
#   groupname:user1 user2 user3
#
# PARAMETERS:
#   $1 - mapping_file: The path to the user-group mapping file.
#
# RETURNS:
#   0 on completion. Prints a summary of the operation.
# =================================================================================================
provision_users_and_groups() {
    local mapping_file="$1"
    
    if [[ ! -f "$mapping_file" ]]; then
        echo "${ICON_ERROR} Mapping file not found: $mapping_file"
        return 1
    fi
    
    local groups_processed=0 groups_created=0 users_added=0 users_created=0 failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        local group=$(echo "$line" | cut -d':' -f1 | xargs)
        local users=$(echo "$line" | cut -d':' -f2 | xargs)
        
        if [[ -z "$group" || -z "$users" ]]; then
            echo "${ICON_WARNING} Invalid format, skipping line: $line"
            ((failed++))
            continue
        fi
        
        if ! validate_name "$group" "group"; then
            ((failed++))
            continue
        fi
        
        ((groups_processed++))
        echo "Processing group: $group"
        
        # Create group if it doesn't exist
        if ! getent group "$group" >/dev/null 2>&1; then
            if add_single_group "$group" ""; then
                ((groups_created++))
            else
                echo "  ${ICON_ERROR} Failed to create group, skipping users in this group."
                ((failed++))
                continue
            fi
        else
            echo "  ${ICON_INFO} Group '$group' already exists."
        fi
        
        # Process each user for the current group
        for user in $users; do
            if ! validate_name "$user" "user"; then
                ((failed++))
                continue
            fi
            
            if id "$user" &>/dev/null; then
                # User exists, just add to the group
                echo "  ${ICON_USER} Adding existing user '$user' to group '$group'..."
                if sudo usermod -aG "$group" "$user" 2>/dev/null; then
                    ((users_added++))
                    log_action "provision_add_to_group" "$user" "SUCCESS" "Added to group: $group"
                else
                    echo "  ${ICON_ERROR} Failed to add '$user' to '$group'."
                    ((failed++))
                fi
            else
                # User doesn't exist, create them with default settings
                echo "  ${ICON_INFO} User '$user' not found. Creating with default settings..."
                
                local user_shell="${GLOBAL_SHELL:-/bin/bash}"
                local user_password="${GLOBAL_PASSWORD:-RANDOM}"
                
                # Create user and add them to the group in one step
                if add_single_user "$user" "$user_password" "" "$group" "" "" "$user_shell" ""; then
                    ((users_created++))
                    ((users_added++))
                else
                    ((failed++))
                fi
            fi
        done
        echo ""
    done < "$mapping_file"
    
    print_operation_summary "$groups_processed" "Groups Created" "$groups_created" "0" "$failed"
    echo "  Users added to groups: $users_added"
    echo "  New users created: $users_created"
    
    return 0
}

# =================================================================================================
# PUBLIC INTERFACE & LEGACY COMPATIBILITY
# =================================================================================================

# Renamed for clarity, but keeping old names for backward compatibility.
provision_users_with_groups() {
    print_provisioning_banner "$1"
    provision_users_and_groups "$1"
}

add_users_to_groups() {
    provision_users_with_groups "$@"
}

add_users_from_json() {
    parse_users_from_json "$1"
}