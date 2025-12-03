#!/bin/bash

parse_group_text_file() {
    local file_path="$1"
    
    validate_batch_file "$file_path" || return 1
    
    declare -g -a BATCH_GROUPS=()
    local line_num=0
    
    echo "Parsing group file: $file_path"
    echo ""
    
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))
        
        [ -z "$line" ] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        line=$(echo "$line" | xargs)
        
        groupname="$line"
        
        if [ -z "$groupname" ]; then
            echo "WARNING: Line $line_num - Empty groupname, skipping"
            continue
        fi
        
        BATCH_GROUPS+=("$groupname")
        
    done < "$file_path"
    
    local count=${#BATCH_GROUPS[@]}
    echo "Parsed $count groups from file"
    echo ""
    
    if [ $count -eq 0 ]; then
        echo "ERROR: No valid groups found in file"
        return 1
    fi
    
    return 0
}