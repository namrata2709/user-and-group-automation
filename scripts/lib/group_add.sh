#!/usr/bin/env bash
# ================================================
# Group Add Module
# Version: 1.0.1
# ================================================

add_groups() {
    local group_file="$1"
    
    if [[ ! -f "$group_file" ]]; then
        echo "${ICON_ERROR} Group file not found: $group_file"
        return 1
    fi
    
    echo "=========================================="
    echo "Adding Groups from: $group_file"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    echo "=========================================="
    echo ""
    
    local count=0 created=0 skipped=0 failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        local groupname="$line"
        count=$((count + 1))
        
        if ! validate_name "$groupname" "group"; then
            failed=$((failed + 1))
            continue
        fi
        
        if getent group "$groupname" >/dev/null 2>&1; then
            echo "${ICON_WARNING} Group '$groupname' already exists. Skipping..."
            skipped=$((skipped + 1))
            continue
        fi
        
        if [ "$DRY_RUN" = true ]; then
            echo "${ICON_SEARCH} [DRY-RUN] Would create group: $groupname"
            created=$((created + 1))
            continue
        fi
        
        echo "${ICON_GROUP} Creating group: $groupname"
        if sudo groupadd "$groupname" 2>/dev/null; then
            log_action "add_group" "$groupname" "SUCCESS" "Group created"
            created=$((created + 1))
        else
            echo "   ${ICON_ERROR} Failed to create group: $groupname"
            failed=$((failed + 1))
        fi
        echo ""
    done < "$group_file"
    
    echo "=========================================="
    echo "Summary:"
    echo "  Total processed: $count"
    echo "  Created: $created"
    echo "  Skipped: $skipped"
    echo "  Failed: $failed"
    echo "=========================================="
}