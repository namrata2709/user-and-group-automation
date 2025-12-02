#!/bin/bash

# ================================================
# Batch User Processor
# File: lib/batch/batch_processor.sh
# Version: 1.0.0
# ================================================

# ================================================
# Generic format structure (for reference):
# ================================================
# declare -A user_data=(
#     [username]="alice"
#     [comment]="Alice Smith:Engineering"
#     [shell]="admin"
#     [sudo]="allow"
#     [primary_group]="developers"
#     [secondary_groups]="docker,sudo"
#     [password_expiry]="90"
#     [password_warning]="7"
#     [account_expiry]="365"
#     [random]="yes"
# )

# ================================================
# Process batch users from generic format
# ================================================
# Input: Array of user data (via global variable BATCH_USERS)
# Output: Summary report
# ================================================
process_batch_users() {
    local start_time=$(date +%s)
    
    # Counters
    local total=0
    local created=0
    local skipped=0
    local failed=0
    
    # Results arrays
    declare -a success_users=()
    declare -a failed_users=()
    declare -a skipped_users=()
    
    echo "========================================"
    echo "Batch User Creation - Starting"
    echo "========================================"
    echo ""
    
    # Process each user
    for user_index in "${!BATCH_USERS[@]}"; do
        ((total++))
        
        # Parse user data (format: "username|comment|shell|sudo|pgroup|sgroups|pexpiry|pwarn|aexpiry|random")
        IFS='|' read -r username comment shell sudo pgroup sgroups pexpiry pwarn aexpiry random <<< "${BATCH_USERS[$user_index]}"
        
        echo "[$total] Processing: $username"
        
        # Validate input
        if ! validate_user_input "$username" "$comment" "$shell" "$sudo" "$pgroup" "$sgroups" "$pexpiry" "$pwarn" "$aexpiry"; then
            echo "  └─ FAILED: Validation errors"
            ((failed++))
            failed_users+=("$username")
            echo ""
            continue
        fi
        
        # Check if user exists (separate from validation for better reporting)
        if [ "$(user_exists "$username")" = "yes" ]; then
            echo "  └─ SKIPPED: User already exists"
            ((skipped++))
            skipped_users+=("$username")
            echo ""
            continue
        fi
        
        # Create user with trusted flag
        if add_user "$username" "$comment" "$random" "$shell" "$sudo" "$pgroup" "$sgroups" "$pexpiry" "$pwarn" "$aexpiry" "yes" >/dev/null 2>&1; then
            echo "  └─ SUCCESS: User created"
            ((created++))
            success_users+=("$username")
        else
            echo "  └─ FAILED: Creation error"
            ((failed++))
            failed_users+=("$username")
        fi
        
        echo ""
    done
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Print summary
    echo "========================================"
    echo "Batch Creation Summary"
    echo "========================================"
    echo "Total Processed:  $total"
    echo "Created:          $created"
    echo "Skipped:          $skipped"
    echo "Failed:           $failed"
    echo "Duration:         ${duration}s"
    echo ""
    
    # Detailed results
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
    
    echo "========================================"
    
    # Log summary
    log_audit "BATCH_ADD" "users" "COMPLETED" "Total: $total, Created: $created, Skipped: $skipped, Failed: $failed"
    
    # Return status
    if [ $failed -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# ================================================
# Validate batch user data structure
# ================================================
validate_batch_structure() {
    local user_data="$1"
    
    # Check format: must have at least username and comment
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

# ================================================
# Test with hardcoded data
# ================================================
test_batch_processor() {
    echo "Testing batch processor with hardcoded data..."
    echo ""
    
    # Global array for batch users
    declare -g -a BATCH_USERS=(
        "alice|Alice Smith:Engineering|admin|allow|developers|docker|90|7|365|yes"
        "bob|Bob Jones:IT|developer|allow|||90|7||no"
        "charlie|Charlie Brown:Support|support|deny|||||180|no"
    )
    
    # Run processor
    process_batch_users
    
    return $?
}