#!/bin/bash

# ================================================
# XLSX File Parser
# File: lib/batch/parsers/xlsx_parser.sh
# Version: 1.0.0
# ================================================
# Converts XLSX to CSV, then parses to generic format
# Dependencies: ssconvert (from gnumeric package)
# ================================================

# ================================================
# Parse XLSX file to generic format
# ================================================
# Input: $1 - File path
# Output: Populates BATCH_USERS array
# Returns: 0 on success, 1 on failure
# ================================================
# Expected XLSX structure:
# Header row: username, comment, shell, sudo, primary_group, secondary_groups, password_expiry, password_warning, account_expiry, random
# Data rows: alice, "Alice Smith:Engineering", admin, allow, developers, "docker,sudo", 90, 7, 365, yes
# ================================================
parse_xlsx_file() {
    local file_path="$1"
    
    # File validation
    if [ ! -f "$file_path" ]; then
        echo "ERROR: File not found: $file_path"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        echo "ERROR: Cannot read file: $file_path"
        return 1
    fi
    
    # Check for ssconvert (from gnumeric)
    if ! command -v ssconvert &> /dev/null; then
        echo "ERROR: ssconvert is required for XLSX parsing"
        echo "Install on:"
        echo "  Amazon Linux/RHEL/CentOS: sudo yum install -y gnumeric"
        echo "  Ubuntu/Debian: sudo apt install -y gnumeric"
        echo ""
        echo "Alternative: Convert XLSX to CSV manually and use CSV parser"
        return 1
    fi
    
    # Initialize global array
    declare -g -a BATCH_USERS=()
    
    echo "Parsing XLSX file: $file_path"
    echo "Converting XLSX to CSV..."
    
    # Create temp CSV file
    local temp_csv=$(mktemp /tmp/xlsx_parser.XXXXXX.csv)
    
    # Convert XLSX to CSV using ssconvert
    if ! ssconvert -T Gnumeric_stf:stf_csv "$file_path" "$temp_csv" &>/dev/null; then
        echo "ERROR: Failed to convert XLSX to CSV"
        rm -f "$temp_csv"
        return 1
    fi
    
    # Check if temp file was created
    if [ ! -f "$temp_csv" ]; then
        echo "ERROR: Conversion failed - CSV file not created"
        return 1
    fi
    
    echo "Conversion successful, parsing CSV data..."
    echo ""
    
    # Now parse the CSV file
    local line_num=0
    local has_header=0
    local user_count=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))
        
        # Skip empty lines
        if [ -z "$line" ]; then
            continue
        fi
        
        # Trim whitespace
        line=$(echo "$line" | xargs)
        
        # Skip header row (check for "username" in first column)
        if [ $line_num -eq 1 ]; then
            if [[ "$line" =~ ^username, ]] || [[ "$line" =~ ^\"username\", ]]; then
                echo "INFO: Header row detected, skipping"
                has_header=1
                continue
            fi
        fi
        
        # Parse CSV line
        # Format: username,comment,shell,sudo,primary_group,secondary_groups,password_expiry,password_warning,account_expiry,random
        IFS=',' read -r username comment shell sudo pgroup sgroups pexpiry pwarn aexpiry random <<< "$line"
        
        # Remove quotes and trim each field
        username=$(echo "$username" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
        comment=$(echo "$comment" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
        shell=$(echo "$shell" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
        sudo=$(echo "$sudo" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
        pgroup=$(echo "$pgroup" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
        sgroups=$(echo "$sgroups" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
        pexpiry=$(echo "$pexpiry" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
        pwarn=$(echo "$pwarn" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
        aexpiry=$(echo "$aexpiry" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
        random=$(echo "$random" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/')
        
        # Validate required fields
        if [ -z "$username" ]; then
            echo "WARNING: Line $line_num - Empty username, skipping"
            continue
        fi
        
        if [ -z "$comment" ]; then
            echo "WARNING: Line $line_num - Empty comment for user '$username', skipping"
            continue
        fi
        
        # Set default for random
        if [ -z "$random" ]; then
            random="no"
        fi
        
        # Add to batch array (pipe-separated format)
        BATCH_USERS+=("$username|$comment|$shell|$sudo|$pgroup|$sgroups|$pexpiry|$pwarn|$aexpiry|$random")
        ((user_count++))
        
    done < "$temp_csv"
    
    # Cleanup temp file
    rm -f "$temp_csv"
    
    local count=${#BATCH_USERS[@]}
    echo "Parsed $count users from XLSX file"
    echo ""
    
    if [ $count -eq 0 ]; then
        echo "ERROR: No valid users found in file"
        echo ""
        echo "Expected XLSX format (with or without header row):"
        echo "Column A: username"
        echo "Column B: comment (format: \"Firstname Lastname:Department\")"
        echo "Column C: shell (optional)"
        echo "Column D: sudo (optional)"
        echo "Column E: primary_group (optional)"
        echo "Column F: secondary_groups (optional, comma-separated)"
        echo "Column G: password_expiry (optional)"
        echo "Column H: password_warning (optional)"
        echo "Column I: account_expiry (optional)"
        echo "Column J: random (optional, yes/no)"
        return 1
    fi
    
    return 0
}