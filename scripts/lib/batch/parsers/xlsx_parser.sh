#!/bin/bash

# ================================================
# XLSX File Parser (Python method)
# File: lib/batch/parsers/xlsx_parser.sh
# Version: 1.0.0
# ================================================
# Dependencies: python3, openpyxl
# Install: pip3 install openpyxl
# ================================================

parse_xlsx_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "ERROR: File not found: $file_path"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        echo "ERROR: Cannot read file: $file_path"
        return 1
    fi
    
    # Check Python3
    if ! command -v python3 &> /dev/null; then
        echo "ERROR: python3 is required for XLSX parsing"
        echo "Install: sudo yum install -y python3"
        return 1
    fi
    
    # Check openpyxl
    if ! python3 -c "import openpyxl" 2>/dev/null; then
        echo "ERROR: openpyxl is required for XLSX parsing"
        echo "Install: sudo pip3 install openpyxl"
        return 1
    fi
    
    declare -g -a BATCH_USERS=()
    
    echo "Parsing XLSX file: $file_path"
    echo ""
    
    # Use Python to convert XLSX to pipe-separated format
    local temp_output=$(mktemp)
    
    python3 << 'PYTHON_SCRIPT' "$file_path" "$temp_output"
import sys
import openpyxl

xlsx_file = sys.argv[1]
output_file = sys.argv[2]

try:
    wb = openpyxl.load_workbook(xlsx_file, data_only=True)
    ws = wb.active
    
    with open(output_file, 'w') as f:
        for row_idx, row in enumerate(ws.iter_rows(values_only=True), start=1):
            # Skip header row if it contains "username"
            if row_idx == 1 and row[0] and str(row[0]).lower() == 'username':
                continue
            
            # Skip empty rows
            if not row[0]:
                continue
            
            # Extract fields (handle None values)
            username = str(row[0]).strip() if row[0] else ""
            comment = str(row[1]).strip() if len(row) > 1 and row[1] else ""
            shell = str(row[2]).strip() if len(row) > 2 and row[2] else ""
            sudo = str(row[3]).strip() if len(row) > 3 and row[3] else ""
            pgroup = str(row[4]).strip() if len(row) > 4 and row[4] else ""
            sgroups = str(row[5]).strip() if len(row) > 5 and row[5] else ""
            pexpiry = str(row[6]).strip() if len(row) > 6 and row[6] else ""
            pwarn = str(row[7]).strip() if len(row) > 7 and row[7] else ""
            aexpiry = str(row[8]).strip() if len(row) > 8 and row[8] else ""
            random = str(row[9]).strip() if len(row) > 9 and row[9] else "no"
            
            # Validate required fields
            if not username or not comment:
                continue
            
            # Write pipe-separated line
            f.write(f"{username}|{comment}|{shell}|{sudo}|{pgroup}|{sgroups}|{pexpiry}|{pwarn}|{aexpiry}|{random}\n")
    
    wb.close()
    sys.exit(0)
    
except Exception as e:
    print(f"ERROR: Failed to parse XLSX: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
    
    if [ $? -ne 0 ]; then
        rm -f "$temp_output"
        return 1
    fi
    
    # Read parsed data
    local user_count=0
    while IFS= read -r line; do
        BATCH_USERS+=("$line")
        ((user_count++))
    done < "$temp_output"
    
    rm -f "$temp_output"
    
    echo "Parsed $user_count users from XLSX file"
    echo ""
    
    if [ $user_count -eq 0 ]; then
        echo "ERROR: No valid users found in file"
        return 1
    fi
    
    return 0
}