#!/bin/bash

parse_group_json_file() {
    local file_path="$1"
    
    validate_file "$file_path" || return 1
    check_dependency "jq" "yum install -y jq" || return 1
    
    if ! jq empty "$file_path" 2>/dev/null; then
        echo "ERROR: Invalid JSON syntax in file"
        return 1
    fi
    
    declare -g -a BATCH_GROUPS=()
    
    echo "Parsing JSON file: $file_path"
    echo ""
    
    local groups_json=$(jq -c '.groups[]' "$file_path" 2>/dev/null)
    
    if [ -z "$groups_json" ]; then
        echo "ERROR: No groups found in JSON"
        echo "Expected structure:"
        echo '{'
        echo '  "groups": ['
        echo '    {"groupname": "developers"},'
        echo '    {"groupname": "testers"}'
        echo '  ]'
        echo '}'
        return 1
    fi
    
    local group_count=0
    
    while IFS= read -r group_json; do
        ((group_count++))
        
        local groupname=$(echo "$group_json" | jq -r '.groupname // empty')
        
        if [ -z "$groupname" ]; then
            echo "WARNING: Group #$group_count - Missing groupname, skipping"
            continue
        fi
        
        BATCH_GROUPS+=("$groupname")
        
    done <<< "$groups_json"
    
    local count=${#BATCH_GROUPS[@]}
    echo "Parsed $count groups from JSON file"
    echo ""
    
    if [ $count -eq 0 ]; then
        echo "ERROR: No valid groups found in file"
        return 1
    fi
    
    return 0
}