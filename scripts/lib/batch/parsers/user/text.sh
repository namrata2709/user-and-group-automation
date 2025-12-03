#!/bin/bash

# ================================================
# Text File Parser
# File: lib/batch/parsers/text_parser.sh
# Version: 1.0.0
# ================================================
# Supported formats:
# 1. Simple: username (one per line)
# 2. Full: username,comment,shell,sudo,pgroup,sgroups,pexpiry,pwarn,aexpiry,random
# ================================================

# ================================================
# Parse text file to generic format
# ================================================
# Input: $1 - File path
# Output: Populates BATCH_USERS array
# Returns: 0 on success, 1 on failure
# ================================================
parse_user_text_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "ERROR: File not found: $file_path"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        echo "ERROR: Cannot read file: $file_path"
        return 1
    fi
    
    declare -g -a BATCH_USERS=()
    local line_num=0
    
    echo "Parsing text file: $file_path"
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
        
        if [[ "$line" =~ , ]]; then
            # CSV format: username,comment[,shell,sudo,pgroup,sgroups,pexpiry,pwarn,aexpiry,random]
            # Minimum: username,comment
            # Full: username,comment,shell,sudo,pgroup,sgroups,pexpiry,pwarn,aexpiry,random
            IFS=',' read -r username comment shell sudo pgroup sgroups pexpiry pwarn aexpiry random <<< "$line"
            
            # Trim each field
            username=$(echo "$username" | xargs)
            comment=$(echo "$comment" | xargs)
            shell=$(echo "$shell" | xargs)
            sudo=$(echo "$sudo" | xargs)
            pgroup=$(echo "$pgroup" | xargs)
            sgroups=$(echo "$sgroups" | xargs)
            pexpiry=$(echo "$pexpiry" | xargs)
            pwarn=$(echo "$pwarn" | xargs)
            aexpiry=$(echo "$aexpiry" | xargs)
            random=$(echo "$random" | xargs)
            
            # Validate required fields
            if [ -z "$username" ]; then
                echo "WARNING: Line $line_num - Empty username, skipping"
                continue
            fi
            
            if [ -z "$comment" ]; then
                echo "WARNING: Line $line_num - Empty comment for user '$username', skipping"
                continue
            fi
            
            # Optional fields default to empty (add_user will use config defaults)
            # If random is empty, default to "no"
            if [ -z "$random" ]; then
                random="no"
            fi
            
       else
            # No comma found - invalid format
            echo "WARNING: Line $line_num - Invalid format, skipping"
            echo "         Expected: username,comment[,optional fields]"
            echo "         Example: alice,Alice Smith:Engineering"
            echo "         Example: bob,Bob Jones:IT,developer,allow,devs,docker,90,7,365,yes"
            continue
        fi
        
        # Add to batch array (pipe-separated format)
        BATCH_USERS+=("$username|$comment|$shell|$sudo|$pgroup|$sgroups|$pexpiry|$pwarn|$aexpiry|$random")
        
    done < "$file_path"
    
    local count=${#BATCH_USERS[@]}
    echo "Parsed $count users from text file"
    echo ""
    
    if [ $count -eq 0 ]; then
        echo "ERROR: No valid users found in file"
        return 1
    fi
    
    return 0
}