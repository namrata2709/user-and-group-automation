#!/bin/bash

parse_user_xlsx_file() {
    local file_path="$1"
    
    validate_file "$file_path" || return 1
    check_dependency "python3" "sudo yum install -y python3" || return 1
    
    if ! python3 -c "import openpyxl" 2>/dev/null; then
        echo "ERROR: openpyxl is required for XLSX parsing"
        echo "Install: sudo pip3 install openpyxl"
        return 1
    fi
    
    echo "Parsing XLSX file: $file_path"
    echo ""
    
    local temp_csv=$(convert_xlsx_to_csv "$file_path" "user")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    echo "INFO: XLSX converted to temporary CSV"
    echo ""
    
    if ! parse_user_text_file "$temp_csv"; then
        rm -f "$temp_csv"
        return 1
    fi
    
    rm -f "$temp_csv"
    return 0
}