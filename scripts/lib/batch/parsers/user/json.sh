#!/bin/bash

parse_user_json_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "ERROR: File not found: $file_path"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        echo "ERROR: Cannot read file: $file_path"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "ERROR: jq is required for JSON parsing"
        echo "Install: yum install -y jq"
        return 1
    fi
    
    if ! jq empty "$file_path" 2>/dev/null; then
        echo "ERROR: Invalid JSON syntax in file"
        return 1
    fi
    
    declare -g -a BATCH_USERS=()
    
    echo "Parsing JSON file: $file_path"
    echo ""
    
    local users_json=$(jq -c '.users[]' "$file_path" 2>/dev/null)
    
    if [ -z "$users_json" ]; then
        echo "ERROR: No users found in JSON"
        echo "Expected structure:"
        echo '{'
        echo '  "users": ['
        echo '    {'
        echo '      "username": "alice",'
        echo '      "comment": "Alice Smith:Engineering"'
        echo '    }'
        echo '  ]'
        echo '}'
        return 1
    fi
    
    local user_count=0
    
    while IFS= read -r user_json; do
        ((user_count++))
        
        local username=$(echo "$user_json" | jq -r '.username // empty')
        local comment=$(echo "$user_json" | jq -r '.comment // empty')
        local shell=$(echo "$user_json" | jq -r '.shell // empty')
        local sudo=$(echo "$user_json" | jq -r '.sudo // empty')
        local pgroup=$(echo "$user_json" | jq -r '.primary_group // empty')
        local sgroups=$(echo "$user_json" | jq -r '.secondary_groups // empty')
        local pexpiry=$(echo "$user_json" | jq -r '.password_expiry // empty')
        local pwarn=$(echo "$user_json" | jq -r '.password_warning // empty')
        local aexpiry=$(echo "$user_json" | jq -r '.account_expiry // empty')
        local random=$(echo "$user_json" | jq -r '.random // empty')
        
        if [ -z "$username" ]; then
            echo "WARNING: User #$user_count - Missing username, skipping"
            continue
        fi
        
        if [ -z "$comment" ]; then
            echo "WARNING: User #$user_count ($username) - Missing comment, skipping"
            continue
        fi
        
        if [ -z "$random" ]; then
            random="no"
        fi
        
        BATCH_USERS+=("$username|$comment|$shell|$sudo|$pgroup|$sgroups|$pexpiry|$pwarn|$aexpiry|$random")
        
    done <<< "$users_json"
    
    local count=${#BATCH_USERS[@]}
    echo "Parsed $count users from JSON file"
    echo ""
    
    if [ $count -eq 0 ]; then
        echo "ERROR: No valid users found in file"
        return 1
    fi
    
    return 0
}