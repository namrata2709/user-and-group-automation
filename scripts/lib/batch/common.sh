#!/bin/bash

# Validate batch file exists and is readable
validate_batch_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "ERROR: File not found: $file_path"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        echo "ERROR: Cannot read file: $file_path"
        return 1
    fi
    
    return 0
}

# Check if command dependency exists
check_dependency() {
    local command="$1"
    local install_hint="$2"
    
    if ! command -v "$command" &> /dev/null; then
        echo "ERROR: $command is required"
        if [ -n "$install_hint" ]; then
            echo "Install: $install_hint"
        fi
        return 1
    fi
    
    return 0
}

# Convert XLSX to CSV using Python
convert_xlsx_to_csv() {
    local xlsx_file="$1"
    local entity_type="$2"  # "user" or "group"
    local temp_csv=$(mktemp --suffix=.csv)
    local temp_script=$(mktemp --suffix=.py)
    
    if [ "$entity_type" = "user" ]; then
        # User XLSX conversion script
        cat << 'PYTHON_SCRIPT' > "$temp_script"
import sys
import openpyxl

xlsx_file = sys.argv[1]
csv_file = sys.argv[2]

try:
    wb = openpyxl.load_workbook(xlsx_file, data_only=True)
    ws = wb.active
    
    with open(csv_file, 'w') as f:
        for row_idx, row in enumerate(ws.iter_rows(values_only=True), start=1):
            # Skip header row if present
            if row_idx == 1 and row[0] and str(row[0]).lower() == 'username':
                continue
            
            # Skip empty rows
            if not row[0]:
                continue
            
            # Process up to 10 columns for users
            cells = []
            for cell in row[:10]:
                if cell is None:
                    cells.append('')
                else:
                    cell_str = str(cell).strip()
                    # Escape commas and quotes in CSV
                    if ',' in cell_str or '"' in cell_str:
                        cell_str = '"' + cell_str.replace('"', '""') + '"'
                    cells.append(cell_str)
            
            f.write(','.join(cells) + '\n')
    
    wb.close()
    print(f"Converted XLSX to CSV: {csv_file}", file=sys.stderr)
    sys.exit(0)
    
except Exception as e:
    print(f"ERROR: Failed to convert XLSX: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
    else
        # Group XLSX conversion script
        cat << 'PYTHON_SCRIPT' > "$temp_script"
import sys
import openpyxl

xlsx_file = sys.argv[1]
csv_file = sys.argv[2]

try:
    wb = openpyxl.load_workbook(xlsx_file, data_only=True)
    ws = wb.active
    
    with open(csv_file, 'w') as f:
        for row_idx, row in enumerate(ws.iter_rows(values_only=True), start=1):
            # Skip header row if present
            if row_idx == 1 and row[0] and str(row[0]).lower() == 'groupname':
                continue
            
            # Skip empty rows
            if not row[0]:
                continue
            
            groupname = str(row[0]).strip()
            f.write(groupname + '\n')
    
    wb.close()
    print(f"Converted XLSX to CSV: {csv_file}", file=sys.stderr)
    sys.exit(0)
    
except Exception as e:
    print(f"ERROR: Failed to convert XLSX: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
    fi
    
    # Execute conversion
    if ! python3 "$temp_script" "$xlsx_file" "$temp_csv" 2>&1; then
        rm -f "$temp_csv" "$temp_script"
        return 1
    fi
    
    rm -f "$temp_script"
    
    # Verify output
    if [ ! -s "$temp_csv" ]; then
        echo "ERROR: Conversion resulted in empty CSV"
        rm -f "$temp_csv"
        return 1
    fi
    
    # Return temp file path
    echo "$temp_csv"
    return 0
}