#!/bin/bash

# Parse YAML file for groups
# Expected format:
# groups:
#   - groupname: developers
#   - groupname: testers
parse_group_yaml_file() {
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
    
    echo "Parsing YAML file: $file_path"
    echo ""
    
    local in_groups_section=0
    local groupname=""
    local group_count=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Check for "groups:" section start
        if [[ "$line" =~ ^groups:[[:space:]]*$ ]]; then
            in_groups_section=1
            continue
        fi
        
        if [ $in_groups_section -eq 0 ]; then
            continue
        fi
        
        # Check for new group entry (starts with "  - " or "- ")
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(groupname:[[:space:]]*(.+))$ ]]; then
            # Save previous group if exists
            if [ -n "$groupname" ]; then
                BATCH_GROUPS+=("$groupname")
                ((group_count++))
            fi
            
            # Extract groupname from current line
            groupname="${BASH_REMATCH[2]}"
            groupname=$(echo "$groupname" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
            continue
        fi
        
        # Parse key-value pairs
        if [[ "$line" =~ ^[[:space:]]+(groupname):[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes and trim
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
            
            if [ "$key" = "groupname" ]; then
                if [ -z "$groupname" ]; then
                    groupname="$value"
                fi
            fi
        fi
        
    done < "$file_path"
    
    # Save last group if exists
    if [ -n "$groupname" ]; then
        BATCH_GROUPS+=("$groupname")
        ((group_count++))
    fi
    
    local count=${#BATCH_GROUPS[@]}
    echo "Parsed $count groups from YAML file"
    echo ""
    
    if [ $count -eq 0 ]; then
        echo "ERROR: No valid groups found in file"
        echo ""
        echo "Expected YAML format:"
        echo "groups:"
        echo "  - groupname: developers"
        echo "  - groupname: testers"
        return 1
    fi
    
    return 0
}