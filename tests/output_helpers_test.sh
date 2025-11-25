#!/usr/bin/env bash
# ==============================================================================
#
#          FILE: output_helpers.sh
#
#         USAGE: source output_helpers.sh
#
#   DESCRIPTION: A collection of reusable functions for printing formatted
#                output, such as banners and summaries for various script
#                operations. This helps maintain a consistent look and feel
#                across the toolset.
#
#       OPTIONS: ---
#  REQUIREMENTS: bash
#          BUGS: ---
#         NOTES: These functions often rely on global variables like DRY_RUN
#                and GLOBAL_* settings to display the current context.
#       AUTHOR: Your Name, your.email@example.com
# ORGANIZATION: Your Company
#      CREATED: YYYY-MM-DD
#     REVISION: 1.1.0
#
# ==============================================================================

# ==============================================================================
# SECTION: OPERATION BANNERS
# ==============================================================================
# Functions that print a consistent, informative banner at the start of a
# major operation (e.g., adding users, locking users).
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: print_add_user_banner()
#
# DESCRIPTION:
#   Prints a banner for the user addition operation. It displays the source
#   file and any global settings that will apply to the new users.
#
# ARGUMENTS:
#   $1: user_file - The path to the file being processed.
#   $2: format - The detected format of the input file (e.g., "JSON", "Text").
# ------------------------------------------------------------------------------
print_add_user_banner() {
# ... existing code ...
#   $1 - File being processed
#   $2 - Format of the file
print_add_user_banner() {
    local user_file="$1"
    local format="$2"

    echo "=================================================="
    echo "OPERATION: Add Users"
    echo "=================================================="
    echo "Source File:      $user_file"
    echo "File Format:      $format"
    echo "--------------------------------------------------"
    [ "$DRY_RUN" = true ] && echo "Mode:             DRY-RUN (No changes will be made)"
    [ -n "$GLOBAL_EXPIRE" ] && echo "Global Expiry:    $GLOBAL_EXPIRE days"
    [ -n "$GLOBAL_SHELL" ] && echo "Global Shell:     $GLOBAL_SHELL"
    [ "$GLOBAL_SUDO" = true ] && echo "Global Sudo:      Enabled"
    [ "$GLOBAL_PASSWORD" = "random" ] && echo "Global Password:  Random (unique per user)"
    [ -n "$GLOBAL_PASSWORD_EXPIRY" ] && echo "Password Expiry:  $GLOBAL_PASSWORD_EXPIRY days"
    echo "=================================================="
    echo
}


# ------------------------------------------------------------------------------
# FUNCTION: print_add_group_banner()
#
# DESCRIPTION:
#   Prints a banner for the group addition operation.
#
# ARGUMENTS:
#   $1: group_file - The path to the file being processed.
#   $2: format - The detected format of the input file.
# ------------------------------------------------------------------------------
print_add_group_banner() {
# ... existing code ...
#   $1 - File being processed
#   $2 - Format of the file
print_add_group_banner() {
    local group_file="$1"
    local format="$2"

    echo "=================================================="
    echo "OPERATION: Add Groups"
    echo "=================================================="
    echo "Source File:      $group_file"
    echo "File Format:      $format"
    [ "$DRY_RUN" = true ] && echo "Mode:             DRY-RUN"
    echo "=================================================="
    echo
}


# ------------------------------------------------------------------------------
# FUNCTION: print_lock_user_banner()
#
# DESCRIPTION:
#   Prints a banner for the user lock operation. It distinguishes between
#   locking a single user and locking users from a file.
#
# ARGUMENTS:
#   $1: target - The target of the lock operation (a single username or a file path).
#   $2: format - The file format (if applicable).
#   $3: reason - The reason for the lock, if provided.
# ------------------------------------------------------------------------------
print_lock_user_banner() {
# ... existing code ...
#   $2 - Format of the file
#   $3 - Global reason for lock
print_lock_user_banner() {
    local target="$1"
    local format="$2"
    local reason="$3"

    echo "=================================================="
    echo "OPERATION: Lock User(s)"
    echo "=================================================="
    if [ -f "$target" ]; then
        echo "Source File:      $target"
        echo "File Format:      $format"
    else
        echo "Target User:      $target"
    fi
    [ -n "$reason" ] && [ "$reason" != "No reason provided" ] && echo "Reason:           $reason"
    [ "$DRY_RUN" = true ] && echo "Mode:             DRY-RUN"
    echo "=================================================="
    echo
}


# ------------------------------------------------------------------------------
# FUNCTION: print_unlock_user_banner()
#
# DESCRIPTION:
#   Prints a banner for the user unlock operation.
#
# ARGUMENTS:
#   $1: target - The target of the unlock operation (a single username or a file path).
#   $2: format - The file format (if applicable).
# ------------------------------------------------------------------------------
print_unlock_user_banner() {
# ... existing code ...
#   $1 - Target (file or username)
#   $2 - Format of the file
print_unlock_user_banner() {
    local target="$1"
    local format="$2"

    echo "=================================================="
    echo "OPERATION: Unlock User(s)"
    echo "=================================================="
    if [ -f "$target" ]; then
        echo "Source File:      $target"
        echo "File Format:      $format"
    else
        echo "Target User:      $target"
    fi
    [ "$DRY_RUN" = true ] && echo "Mode:             DRY-RUN"
    echo "=================================================="
    echo
}


# ------------------------------------------------------------------------------
# FUNCTION: print_delete_group_banner()
#
# DESCRIPTION:
#   Prints a banner for the group deletion operation.
#
# ARGUMENTS:
#   $1: group_file - The path to the file being processed.
#   $2: format - The detected format of the input file.
# ------------------------------------------------------------------------------
print_delete_group_banner() {
# ... existing code ...
#   $1 - File being processed
#   $2 - Format of the file
print_delete_group_banner() {
    local group_file="$1"
    local format="$2"

    echo "=================================================="
    echo "OPERATION: Delete Groups"
    echo "=================================================="
    echo "Source File:      $group_file"
    echo "File Format:      $format"
    [ "$DRY_RUN" = true ] && echo "Mode:             DRY-RUN"
    echo "=================================================="
    echo
}


# ------------------------------------------------------------------------------
# FUNCTION: print_delete_user_banner()
#
# DESCRIPTION:
#   Prints a banner for the user deletion operation.
#
# ARGUMENTS:
#   $1: user_file - The path to the file being processed.
#   $2: format - The detected format of the input file.
# ------------------------------------------------------------------------------
print_delete_user_banner() {
# ... existing code ...
#   $1 - File being processed
#   $2 - Format of the file
print_delete_user_banner() {
    local user_file="$1"
    local format="$2"

    echo "=================================================="
    echo "OPERATION: Delete Users"
    echo "=================================================="
    echo "Source File:      $user_file"
    echo "File Format:      $format"
    [ "$DRY_RUN" = true ] && echo "Mode:             DRY-RUN"
    echo "=================================================="
    echo
}


# ------------------------------------------------------------------------------
# FUNCTION: print_provisioning_banner()
#
# DESCRIPTION:
#   Prints a banner for the user-group provisioning (role mapping) operation.
#
# ARGUMENTS:
#   $1: mapping_file - The path to the role mapping file.
# ------------------------------------------------------------------------------
print_provisioning_banner() {
# ... existing code ...
# Prints a banner for the user-group provisioning operation
# Args:
#   $1 - Mapping file being processed
print_provisioning_banner() {
    local mapping_file="$1"

    echo "=================================================="
    echo "OPERATION: User-Group Provisioning"
    echo "=================================================="
    echo "Mapping File:     $mapping_file"
    echo "--------------------------------------------------"
    [ "$DRY_RUN" = true ] && echo "Mode:             DRY-RUN"
    [ -n "$GLOBAL_EXPIRE" ] && echo "Global Expiry:    $GLOBAL_EXPIRE days"
    [ -n "$GLOBAL_SHELL" ] && echo "Global Shell:     $GLOBAL_SHELL"
    [ "$GLOBAL_SUDO" = true ] && echo "Global Sudo:      Enabled"
    [ "$GLOBAL_PASSWORD" = "random" ] && echo "Global Password:  Random"
    [ -n "$GLOBAL_PASSWORD_EXPIRY" ] && echo "Password Expiry:  $GLOBAL_PASSWORD_EXPIRY days"
    echo "=================================================="
    echo
}

# ==============================================================================
# SECTION: OPERATION SUMMARY
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: print_operation_summary()
#
# DESCRIPTION:
#   Prints a standardized summary table at the end of an operation, showing
#   counts for total, successful, skipped, and failed items.
#
# ARGUMENTS:
#   $1: total - The total number of items processed.
#   $2: success_label - The label for the success count (e.g., "Created", "Locked").
#   $3: success_count - The number of successful operations.
#   $4: skipped - The number of items skipped.
#   $5: failed - The number of items that failed.
#   $6: duration (optional) - The total time taken for the operation, in seconds.
# ------------------------------------------------------------------------------
print_operation_summary() {
# ... existing code ...
#   $5 - Items failed
#   $6 - Duration in seconds (optional)
print_operation_summary() {
    local total="$1"
    local success_label="$2"
    local success_count="$3"
    local skipped="$4"
    local failed="$5"
    local duration="$6"

    echo
    echo "=================================================="
    echo "OPERATION SUMMARY"
    echo "=================================================="
    printf "  %-20s %s\\n" "Total Items Processed:" "$total"
    printf "  %-20s %s\\n" "$success_label:" "$success_count"
    printf "  %-20s %s\\n" "Skipped:" "$skipped"
    printf "  %-20s %s\\n" "Failed:" "$failed"
    [ -n "$duration" ] && printf "  %-20s %s\\n" "Duration:" "${duration}s"
    echo "=================================================="
}