# =============================================================================
# PUBLIC: update_group
# =============================================================================
update_group() {
    local groupname="$1"
    shift

    if ! group_exists "$groupname"; then
        error_message "Group '$groupname' does not exist. Cannot perform update."
        return 1
    fi

    display_banner "Updating Group: $groupname"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --add-members) _update_group_add_members "$groupname" "$2"; shift 2 ;;
            --remove-members) _update_group_remove_members "$groupname" "$2"; shift 2 ;;
            --new-name) _update_group_rename "$groupname" "$2"; groupname="$2"; shift 2 ;;
            *) error_message "Unknown update option: $1"; return 1 ;;
        esac
    done

    success_message "All updates for '$groupname' processed."
}

# =============================================================================
# PUBLIC: parse_groups_for_update_from_json
# =============================================================================
parse_groups_for_update_from_json() {
    local json_file="$1"

    if ! command_exists "jq"; then
        error_message "jq is not installed. Please install it to process JSON files."
        return 1
    fi

    if ! validate_json_file "$json_file" "groups"; then
        return 1
    fi

    local count=0 updated=0 skipped=0 failed=0
    local start_time=$(date +%s)

    while IFS= read -r group_json; do
        ((count++))
        local groupname=$(echo "$group_json" | jq -r '.groupname')
        local action=$(echo "$group_json" | jq -r '.action // "update"')

        if [[ "$action" != "update" ]]; then
            info_message "Skipping group '$groupname' - action is '$action' (not 'update')."
            ((skipped++))
            continue
        fi

        if ! group_exists "$groupname"; then
            error_message "Group '$groupname' does not exist. Skipping."
            ((failed++))
            continue
        fi

        local updates=()
        while IFS='=' read -r key value; do
            case "$key" in
                add-members|remove-members|new-name)
                    updates+=("--$key" "$value")
                    ;;
            esac
        done < <(echo "$group_json" | jq -r '.updates | to_entries | .[] | "\(.key)=\(.value)"')

        if [[ ${#updates[@]} -gt 0 ]]; then
            if update_group "$groupname" "${updates[@]}"; then
                ((updated++))
            else
                ((failed++))
            fi
        else
            info_message "No valid updates specified for group '$groupname'. Skipping."
            ((skipped++))
        fi
        echo ""
    done < <(jq -c '.groups[]' "$json_file")

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    print_operation_summary "$count" "Updated" "$updated" "$skipped" "$failed" "$duration"
}

# =============================================================================
# PUBLIC: update_groups_from_file
# =============================================================================
update_groups_from_file() {
    local input_file="$1"
    local format="${2:-auto}"

    if [[ ! -f "$input_file" ]]; then
        error_message "Input file not found: $input_file"
        return 1
    fi

    if [[ "$format" = "auto" ]]; then
        format="${input_file##*.}"
    fi

    display_banner "Bulk Group Update"
    info_message "File:    $input_file"
    info_message "Format:  $format"
    echo ""

    case "$format" in
        json)
            parse_groups_for_update_from_json "$input_file"
            ;;
        *)
            error_message "Unsupported format for bulk update: '$format'. Only 'json' is supported."
            return 1
            ;;
    esac
}