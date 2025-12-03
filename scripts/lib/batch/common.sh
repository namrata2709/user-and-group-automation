#!/bin/bash

validate_file() {
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

check_dependency() {
    local cmd="$1"
    local install_hint="$2"
    
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: $cmd is required"
        echo "Install: $install_hint"
        return 1
    fi
    
    return 0
}

convert_xlsx_to_csv() {
    local xlsx_file="$1"
    local entity_type="$2"
    local temp_csv=$(mktemp --suffix=.csv)
    local temp_script=$(mktemp --suffix=.py)
    
    if [ "$entity_type" = "user" ]; then
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
            if row_idx == 1 and row[0] and str(row[0]).lower() == 'username':
                continue
            
            if not row[0]:
                continue
            
            cells = []
            for cell in row[:10]:
                if cell is None:
                    cells.append('')
                else:
                    cell_str = str(cell).strip()
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
            if row_idx == 1 and row[0] and str(row[0]).lower() == 'groupname':
                continue
            
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
    
    if ! python3 "$temp_script" "$xlsx_file" "$temp_csv" 2>&1; then
        rm -f "$temp_csv" "$temp_script"
        return 1
    fi
    
    rm -f "$temp_script"
    
    if [ ! -s "$temp_csv" ]; then
        echo "ERROR: Conversion resulted in empty CSV"
        rm -f "$temp_csv"
        return 1
    fi
    
    echo "$temp_csv"
    return 0
}