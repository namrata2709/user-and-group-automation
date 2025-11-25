#!/usr/bin/env bash

# =================================================================================================
#
# Group Addition Module
#
# Description:
#   This module is responsible for creating new user groups. It provides a core function for
#   adding a single group, along with parsers for bulk creation from text or JSON files.
#   It is designed to be invoked by the main 'user.sh' script.
#
# =================================================================================================

# =================================================================================================
# FUNCTION: add_single_group
# DESCRIPTION:
#   The core function for creating a single new user group. It validates the group name,
#   constructs and executes the 'groupadd' command, and optionally adds a list of members
#   to the newly created group.
#
# PARAMETERS:
#   $1 - groupname: The name of the group to create.
#   $2 - gid: (Optional) The numeric group ID (GID) for the new group.
#   $3 - members: (Optional) A comma-separated string of usernames to add to the group.
#
# RETURNS:
#   0 if the group is created successfully.
#   1 if there is a failure (e.g., group exists, validation fails, command fails).
#   Returns 1 for partial success (e.g., group created but adding members fails).
# =================================================================================================
add_single_group() {
    local groupname="$1"
    local gid="$2"
    local members="$3"

    # --- Validation ---
    if is_reserved_group "$groupname"; then
        log_action "ERROR" "Group creation failed: '$groupname' is a reserved group name."
        return 1
    fi

    if getent group "$groupname" &>/dev/null; then
        log_action "ERROR" "Group creation failed: Group '$groupname' already exists."
        return 1
    fi

    # --- Build groupadd command ---
    local cmd="sudo groupadd"
    local opts=()
    [ -n "$gid" ] && opts+=("-g" "$gid")

    # --- Execute groupadd ---
    log_action "INFO" "Attempting to create group '$groupname'..."
    if eval "$cmd ${opts[*]} '$groupname'"; then
        log_action "SUCCESS" "Group '$groupname' created successfully."

        # --- Add members if provided ---
        if [ -n "$members" ]; then
            local failed_members=()
            IFS=',' read -ra member_list <<< "$members"
            for member in "${member_list[@]}"; do
                if ! id "$member" &>/dev/null; then
                    log_action "WARNING" "Cannot add member '$member' to group '$groupname': User does not exist."
                    failed_members+=("$member")
                else
                    if ! sudo usermod -a -G "$groupname" "$member"; then
                        log_action "ERROR" "Failed to add member '$member' to group '$groupname'."
                        failed_members+=("$member")
                    fi
                fi
            done

            if [ ${#failed_members[@]} -gt 0 ]; then
                log_action "WARNING" "Group '$groupname' created, but failed to add the following members: ${failed_members[*]}."
                return 1 # Partial success
            else
                log_action "INFO" "All specified members added to group '$groupname'."
            fi
        fi
        return 0
    else
        log_action "ERROR" "Failed to create group '$groupname'."
        return 1
    fi
}

# =================================================================================================
# FUNCTION: parse_groups_from_text
# DESCRIPTION:
#   Parses a simple text file to add multiple groups. Each line in the file is treated as a
#   group name to be created.
#
# INPUT FORMAT (TEXT):
#   One group name per line. Lines starting with '#' are ignored.
#
# PARAMETERS:
#   $1 - group_file: The absolute path to the text file.
#
# RETURNS:
#   0 on completion. Prints a summary of the operation.
# =================================================================================================
parse_groups_from_text() {
    local group_file="$1"
    
    if [[ ! -f "$group_file" ]]; then
        echo "${ICON_ERROR} Group file not found: $group_file"
        return 1
    fi
    
    local count=0 created=0 skipped=0 failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        local groupname="$line"
        count=$((count + 1))
        
        if add_single_group "$groupname" ""; then
            ((created++))
        else
            if getent group "$groupname" >/dev/null 2>&1; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < "$group_file"
    
    print_operation_summary "$count" "Created" "$created" "$skipped" "$failed"
    
    return 0
}

# =================================================================================================
# FUNCTION: parse_groups_from_json
# DESCRIPTION:
#   Parses a JSON file to add multiple groups. It uses 'jq' to process an array of group
#   objects. This function is intended for machine-readable input.
#
# INPUT FORMAT (JSON):
#   A JSON object with a top-level "groups" array. Each object can specify a name, GID,
#   and a list of members.
#   {
#     "groups": [
#       { "name": "developers", "gid": "2001", "members": ["jdoe", "asmith"] },
#       { "name": "testers" }
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
parse_groups_from_json() {
    local json_file="$1"
    
    if ! command -v jq &> /dev/null; then
        echo "${ICON_ERROR} 'jq' is not installed. Please install it to process JSON files."
        return 1
    fi
    
    if ! jq -e '.groups' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure. The file must contain a 'groups' array."
        return 1
    fi
    
    local count=0 created=0 skipped=0 failed=0
    local start_time=$(date +%s)
    
    while IFS= read -r group_json; do
        ((count++))
        
        local groupname=$(echo "$group_json" | jq -r '.name')
        local gid=$(echo "$group_json" | jq -r '.gid // ""')
        local members=$(echo "$group_json" | jq -r '(.members // []) | join(",")')
        
        if add_single_group "$groupname" "$gid" "$members"; then
            ((created++))
        else
            if getent group "$groupname" >/dev/null 2>&1; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < <(jq -c '.groups[]' "$json_file" 2>/dev/null)
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_operation_summary "$count" "Created" "$created" "$skipped" "$failed" "$duration"
    
    return 0
}

# =================================================================================================
# FUNCTION: add_groups
# DESCRIPTION:
#   The main public entry point for the group addition feature. It auto-detects the input
#   file format (text or JSON) and calls the appropriate parser.
#
# PARAMETERS:
#   $1 - group_file: The path to the input file.
#   $2 - format: (Optional) The format of the file ("text" or "json"). Auto-detects if omitted.
#
# RETURNS:
#   0 on success, 1 on failure.
# =================================================================================================
add_groups() {
    local group_file="$1"
    local format="${2:-auto}"
    
    if [[ ! -f "$group_file" ]]; then
        echo "${ICON_ERROR} Group file not found: $group_file"
        return 1
    fi
    
    if [ "$format" = "auto" ]; then
        if [[ "$group_file" =~ \.json$ ]]; then
            format="json"
        else
            format="text"
        fi
    fi
    
    print_add_group_banner "$group_file" "$format"
    
    case "$format" in
        json)
            parse_groups_from_json "$group_file"
            ;;
        text|txt)
            parse_groups_from_text "$group_file"
            ;;
        *)
            echo "${ICON_ERROR} Unknown format: $format. Supported formats: text, json."
            return 1
            ;;
    esac
}

# =================================================================================================
# LEGACY COMPATIBILITY
# =================================================================================================

# Keep old function name for backward compatibility.
add_groups_from_json() {
    parse_groups_from_json "$1"
}