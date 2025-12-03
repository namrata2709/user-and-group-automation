#!/bin/bash

process_batch_users() {
    local start_time=$(date +%s)
    
    local total=0
    local created=0
    local skipped=0
    local failed=0
    
    declare -a success_users=()
    declare -a failed_users=()
    declare -a skipped_users=()
    
    declare -A created_groups=()
    declare -A groups_with_users=()
    
    echo "========================================"
    echo "Batch User Creation - Starting"
    echo "========================================"
    echo ""
    
    if [ -n "$GLOBAL_SHELL" ] || [ -n "$GLOBAL_SUDO" ] || [ -n "$GLOBAL_PGROUP" ] || \
       [ -n "$GLOBAL_SGROUPS" ] || [ -n "$GLOBAL_PEXPIRY" ] || [ -n "$GLOBAL_PWARN" ] || \
       [ -n "$GLOBAL_EXPIRE" ] || [ -n "$GLOBAL_RANDOM" ]; then
        echo "Global Parameters Applied:"
        [ -n "$GLOBAL_SHELL" ] && echo "  Shell:            $GLOBAL_SHELL"
        [ -n "$GLOBAL_SUDO" ] && echo "  Sudo Access:      $GLOBAL_SUDO"
        [ -n "$GLOBAL_PGROUP" ] && echo "  Primary Group:    $GLOBAL_PGROUP"
        [ -n "$GLOBAL_SGROUPS" ] && echo "  Secondary Groups: $GLOBAL_SGROUPS"
        [ -n "$GLOBAL_PEXPIRY" ] && echo "  Password Expiry:  $GLOBAL_PEXPIRY days"
        [ -n "$GLOBAL_PWARN" ] && echo "  Password Warning: $GLOBAL_PWARN days"
        [ -n "$GLOBAL_EXPIRE" ] && echo "  Account Expiry:   $GLOBAL_EXPIRE"
        [ -n "$GLOBAL_RANDOM" ] && echo "  Random Password:  yes"
        echo ""
        echo "Note: File values override global parameters"
        echo ""
    fi
    
    for user_index in "${!BATCH_USERS[@]}"; do
        ((total++))
        
        IFS='|' read -r username comment shell sudo pgroup sgroups pexpiry pwarn aexpiry random <<< "${BATCH_USERS[$user_index]}"
        
        [ -z "$shell" ] && shell="$GLOBAL_SHELL"
        [ -z "$sudo" ] && sudo="$GLOBAL_SUDO"
        [ -z "$pgroup" ] && pgroup="$GLOBAL_PGROUP"
        [ -z "$sgroups" ] && sgroups="$GLOBAL_SGROUPS"
        [ -z "$pexpiry" ] && pexpiry="$GLOBAL_PEXPIRY"
        [ -z "$pwarn" ] && pwarn="$GLOBAL_PWARN"
        [ -z "$aexpiry" ] && aexpiry="$GLOBAL_EXPIRE"
        [ "$random" = "no" ] && [ -n "$GLOBAL_RANDOM" ] && random="$GLOBAL_RANDOM"
        
        echo "[$total] Processing: $username"
        
        if ! validate_user_input "$username" "$comment" "$shell" "$sudo" "$pgroup" "$sgroups" "$pexpiry" "$pwarn" "$aexpiry"; then
            echo "  └─ FAILED: Validation errors"
            ((failed++))
            failed_users+=("$username")
            echo ""
            continue
        fi
        
        if [ "$(user_exists "$username")" = "yes" ]; then
            echo "  └─ SKIPPED: User already exists"
            ((skipped++))
            skipped_users+=("$username")
            echo ""
            continue
        fi
        
        if [ -n "$pgroup" ]; then
            if [ "$(group_exists "$pgroup")" = "no" ]; then
                if add_group "$pgroup" "yes" >/dev/null 2>&1; then
                    created_groups["$pgroup"]=1
                else
                    echo "  └─ FAILED: Could not create primary group"
                    ((failed++))
                    failed_users+=("$username")
                    echo ""
                    continue
                fi
            fi
        fi
        
        if [ -n "$sgroups" ]; then
            IFS=',' read -ra GROUP_ARRAY <<< "$sgroups"
            for group in "${GROUP_ARRAY[@]}"; do
                group=$(echo "$group" | xargs)
                
                if [ "$(group_exists "$group")" = "no" ]; then
                    if add_group "$group" "yes" >/dev/null 2>&1; then
                        created_groups["$group"]=1
                    else
                        echo "  └─ FAILED: Could not create secondary group"
                        ((failed++))
                        failed_users+=("$username")
                        echo ""
                        continue 2
                    fi
                fi
            done
        fi
        
        if add_user "$username" "$comment" "$random" "$shell" "$sudo" "$pgroup" "$sgroups" "$pexpiry" "$pwarn" "$aexpiry" "yes" >/dev/null 2>&1; then
            echo "  └─ SUCCESS: User created"
            ((created++))
            success_users+=("$username")
            
            if [ -n "$pgroup" ]; then
                groups_with_users["$pgroup"]=1
            fi
            if [ -n "$sgroups" ]; then
                IFS=',' read -ra GROUP_ARRAY <<< "$sgroups"
                for group in "${GROUP_ARRAY[@]}"; do
                    group=$(echo "$group" | xargs)
                    groups_with_users["$group"]=1
                done
            fi
        else
            echo "  └─ FAILED: Creation error"
            ((failed++))
            failed_users+=("$username")
        fi
        
        echo ""
    done
    
    local orphaned_count=0
    declare -a orphaned_groups=()
    
    if [ ${#created_groups[@]} -gt 0 ]; then
        echo "========================================"
        echo "Checking for orphaned groups..."
        echo "========================================"
        
        for group in "${!created_groups[@]}"; do
            if [ -z "${groups_with_users[$group]}" ]; then
                local members=$(getent group "$group" | awk -F: '{print $4}')
                
                if [ -z "$members" ]; then
                    if groupdel "$group" >/dev/null 2>&1; then
                        echo "Deleted orphaned group: $group"
                        orphaned_groups+=("$group")
                        ((orphaned_count++))
                        log_audit "BATCH_ROLLBACK" "$group" "DELETED" "Orphaned group with no users"
                    fi
                fi
            fi
        done
        
        [ $orphaned_count -eq 0 ] && echo "No orphaned groups found"
        echo ""
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "========================================"
    echo "Batch Creation Summary"
    echo "========================================"
    echo "Total Processed:  $total"
    echo "Created:          $created"
    echo "Skipped:          $skipped"
    echo "Failed:           $failed"
    if [ $orphaned_count -gt 0 ]; then
        echo "Orphaned Groups:  $orphaned_count (deleted)"
    fi
    echo "Duration:         ${duration}s"
    echo ""
    
    if [ ${#success_users[@]} -gt 0 ]; then
        echo "Created Users:"
        for user in "${success_users[@]}"; do
            echo "  ✓ $user"
        done
        echo ""
    fi
    
    if [ ${#skipped_users[@]} -gt 0 ]; then
        echo "Skipped Users (already exist):"
        for user in "${skipped_users[@]}"; do
            echo "  ⊘ $user"
        done
        echo ""
    fi
    
    if [ ${#failed_users[@]} -gt 0 ]; then
        echo "Failed Users:"
        for user in "${failed_users[@]}"; do
            echo "  ✗ $user"
        done
        echo ""
    fi
    
    if [ ${#orphaned_groups[@]} -gt 0 ]; then
        echo "Deleted Orphaned Groups:"
        for group in "${orphaned_groups[@]}"; do
            echo "  🗑 $group"
        done
        echo ""
    fi
    
    echo "========================================"
    
    log_audit "BATCH_ADD" "users" "COMPLETED" "Total: $total, Created: $created, Skipped: $skipped, Failed: $failed, Orphaned: $orphaned_count"
    
    if [ $failed -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

validate_batch_structure() {
    local user_data="$1"
    
    if ! [[ "$user_data" =~ \| ]]; then
        echo "ERROR: Invalid format - missing pipe separator"
        return 1
    fi
    
    IFS='|' read -r username comment _ <<< "$user_data"
    
    if [ -z "$username" ]; then
        echo "ERROR: Username is required"
        return 1
    fi
    
    if [ -z "$comment" ]; then
        echo "ERROR: Comment is required"
        return 1
    fi
    
    return 0
}