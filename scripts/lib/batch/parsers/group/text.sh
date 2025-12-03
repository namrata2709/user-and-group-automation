#!/bin/bash

# Parse text/CSV file for groups
# Format: groupname
# One group per line
parse_group_text_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "ERROR: File not found: $file_path"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        echo "ERROR: Cannot read file: $file_path"
        return 1
    fi
    
    declare -g -a BATCH_GROUPS=()
    local line_num=0
    
    echo "Parsing group file: $file_path"
    echo ""
    
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))
        
        # Skip empty lines
        if [ -z "$line" ]; then
            continue
        fi
        
        # Skip comments
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Trim whitespace
        line=$(echo "$line" | xargs)
        
        # Simple format: just groupname
        groupname="$line"
        
        # Validate groupname is not empty
        if [ -z "$groupname" ]; then
            echo "WARNING: Line $line_num - Empty groupname, skipping"
            continue
        fi
        
        # Add to batch array
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