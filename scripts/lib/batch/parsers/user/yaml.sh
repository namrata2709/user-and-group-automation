#!/bin/bash

# ================================================
# YAML File Parser
# File: lib/batch/parsers/yaml_parser.sh
# Version: 1.0.0
# ================================================
# Parses simple YAML user definitions without requiring yq
# ================================================

# ================================================
# Parse YAML file to generic format
# ================================================
# Input: $1 - File path
# Output: Populates BATCH_USERS array
# Returns: 0 on success, 1 on failure
# ================================================
# Expected YAML structure:
# users:
#   - username: alice
#     comment: "Alice Smith:Engineering"
#     shell: admin
#     sudo: allow
#     primary_group: developers
#     secondary_groups: docker,sudo
#     password_expiry: 90
#     password_warning: 7
#     account_expiry: 365
#     random: yes
#   - username: bob
#     comment: "Bob Jones:Sales"
#     ...
# ================================================
parse_user_yaml_file() {
    local file_path="$1"
    
    # File validation
    validate_batch_file "$file_path" || return 1
    
    # Initialize global array
    declare -g -a BATCH_USERS=()
    
    echo "Parsing YAML file: $file_path"
    echo ""
    
    # State variables
    local in_users_section=0
    local in_user_block=0
    local username=""
    local comment=""
    local shell=""
    local sudo=""
    local pgroup=""
    local sgroups=""
    local pexpiry=""
    local pwarn=""
    local pmin=""
    local aexpiry=""
    local random=""
    local user_count=0
    
    # Read file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Check for "users:" section start
        if [[ "$line" =~ ^users:[[:space:]]*$ ]]; then
            in_users_section=1
            continue
        fi
        
        # If not in users section, skip
        if [ $in_users_section -eq 0 ]; then
            continue
        fi
        
        # Check for new user entry (starts with "  - " or "- ")
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(username:[[:space:]]*(.+))$ ]]; then
            # Save previous user if exists
            if [ -n "$username" ]; then
                ((user_count++))
                
                # Validate required fields
                if [ -z "$comment" ]; then
                    echo "WARNING: User #$user_count ($username) - Missing comment, skipping"
                    username=""
                    continue
                fi
                
                # Set default for random
                if [ -z "$random" ]; then
                    random="no"
                fi
                
                # Add to batch array
                BATCH_USERS+=("$username|$comment|$shell|$sudo|$pgroup|$sgroups|$pexpiry|$pmin|$pwarn|$aexpiry|$random")
                
                # Reset variables
                username=""
                comment=""
                shell=""
                sudo=""
                pgroup=""
                sgroups=""
                pexpiry=""
                pwarn=""
                pmin=""
                aexpiry=""
                random=""
            fi
            
            # Extract username from current line
            username="${BASH_REMATCH[2]}"
            username=$(echo "$username" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
            in_user_block=1
            continue
        fi
        
        # If in user block, parse key-value pairs
        if [ $in_user_block -eq 1 ]; then
            # Extract key and value
            if [[ "$line" =~ ^[[:space:]]+(username|comment|shell|sudo|primary_group|secondary_groups|password_expiry|password_min|password_warning|account_expiry|random):[[:space:]]*(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                
                # Remove quotes and trim
                value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
                
                case "$key" in
                    username)
                        # Only set if username is empty (handles "- username:" format)
                        if [ -z "$username" ]; then
                            username="$value"
                        fi
                        ;;
                    comment)
                        comment="$value"
                        ;;
                    shell)
                        shell="$value"
                        ;;
                    sudo)
                        sudo="$value"
                        ;;
                    primary_group)
                        pgroup="$value"
                        ;;
                    secondary_groups)
                        sgroups="$value"
                        ;;
                    password_expiry)
                        pexpiry="$value"
                        ;;
                    password_min)
                        pmin="$value"
                        ;;
                    password_warning)
                        pwarn="$value"
                        ;;
                    account_expiry)
                        aexpiry="$value"
                        ;;
                    random)
                        random="$value"
                        ;;
                esac
            fi
        fi
        
    done < "$file_path"
    
    # Save last user if exists
    if [ -n "$username" ]; then
        ((user_count++))
        
        # Validate required fields
        if [ -z "$comment" ]; then
            echo "WARNING: User #$user_count ($username) - Missing comment, skipping"
        else
            # Set default for random
            if [ -z "$random" ]; then
                random="no"
            fi
            
            # Add to batch array
            BATCH_USERS+=("$username|$comment|$shell|$sudo|$pgroup|$sgroups|$pexpiry|$pmin|$pwarn|$aexpiry|$random")
        fi
    fi
    
    local count=${#BATCH_USERS[@]}
    echo "Parsed $count users from YAML file"
    echo ""
    
    if [ $count -eq 0 ]; then
        echo "ERROR: No valid users found in file"
        echo ""
        echo "Expected YAML format:"
        echo "users:"
        echo "  - username: alice"
        echo "    comment: \"Alice Smith:Engineering\""
        echo "  - username: bob"
        echo "    comment: \"Bob Jones:Sales\""
        return 1
    fi
    
    return 0
}