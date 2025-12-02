#!/bin/bash

# Process batch groups
process_batch_groups() {
    local start_time=$(date +%s)
    
    local total=0
    local created=0
    local skipped=0
    local failed=0
    
    declare -a success_groups=()
    declare -a failed_groups=()
    declare -a skipped_groups=()
    
    echo "========================================"
    echo "Batch Group Creation - Starting"
    echo "========================================"
    echo ""
    
    for group_index in "${!BATCH_GROUPS[@]}"; do
        ((total++))
        
        local groupname="${BATCH_GROUPS[$group_index]}"
        
        echo "[$total] Processing: $groupname"
        
        # Check if group exists
        if [ "$(group_exists "$groupname")" = "yes" ]; then
            echo "  └─ SKIPPED: Group already exists"
            ((skipped++))
            skipped_groups+=("$groupname")
            echo ""
            continue
        fi
        
        # Create group
        if add_group "$groupname" >/dev/null 2>&1; then
            echo "  └─ SUCCESS: Group created"
            ((created++))
            success_groups+=("$groupname")
        else
            echo "  └─ FAILED: Creation error"
            ((failed++))
            failed_groups+=("$groupname")
        fi
        
        echo ""
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "========================================"
    echo "Batch Creation Summary"
    echo "========================================"
    echo "Total Processed:  $total"
    echo "Created:          $created"
    echo "Skipped:          $skipped"
    echo "Failed:           $failed"
    echo "Duration:         ${duration}s"
    echo ""
    
    if [ ${#success_groups[@]} -gt 0 ]; then
        echo "Created Groups:"
        for group in "${success_groups[@]}"; do
            echo "  ✓ $group"
        done
        echo ""
    fi
    
    if [ ${#skipped_groups[@]} -gt 0 ]; then
        echo "Skipped Groups (already exist):"
        for group in "${skipped_groups[@]}"; do
            echo "  ⊘ $group"
        done
        echo ""
    fi
    
    if [ ${#failed_groups[@]} -gt 0 ]; then
        echo "Failed Groups:"
        for group in "${failed_groups[@]}"; do
            echo "  ✗ $group"
        done
        echo ""
    fi
    
    echo "========================================"
    
    log_audit "BATCH_ADD_GROUP" "groups" "COMPLETED" "Total: $total, Created: $created, Skipped: $skipped, Failed: $failed"
    
    if [ $failed -eq 0 ]; then
        return 0
    else
        return 1
    fi
}