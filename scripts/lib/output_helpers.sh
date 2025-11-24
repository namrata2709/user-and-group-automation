#!/usr/bin/env bash
# ===============================================
# Output Helpers
# Reusable functions for banners and summaries
# ===============================================

# print_add_user_banner()
# Prints a banner for the user add operation, including global settings
# Args:
#   $1 - File being processed
#   $2 - Format of the file
print_add_user_banner() {
    local user_file="$1"
    local format="$2"

    echo "============================================"
    echo "Adding Users from: $user_file"
    echo "Format: $format"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    [ -n "$GLOBAL_EXPIRE" ] && echo "📅 Global Expiration: $GLOBAL_EXPIRE days"
    [ -n "$GLOBAL_SHELL" ] && echo "🐚 Global Shell: $GLOBAL_SHELL"
    [ "$GLOBAL_SUDO" = true ] && echo "🔐 Global Sudo: enabled"
    [ "$GLOBAL_PASSWORD" = "random" ] && echo "🔑 Global Password: random (unique per user)"
    [ -n "$GLOBAL_PASSWORD_EXPIRY" ] && echo "⏱️  Password expiry: $GLOBAL_PASSWORD_EXPIRY days"
    echo "============================================"
    echo ""
}

# print_lock_user_banner()
# Prints a banner for the user lock operation
# Args:
#   $1 - Target (file or username)
#   $2 - Format of the file
#   $3 - Global reason for lock
print_lock_user_banner() {
    local target="$1"
    local format="$2"
    local reason="$3"

    echo "============================================"
    if [ -f "$target" ]; then
        echo "Locking Users from: $target"
        echo "Format: $format"
    else
        echo "Locking User: $target"
    fi
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    [ -n "$reason" ] && [ "$reason" != "No reason provided" ] && echo "Reason: $reason"
    echo "============================================"
    echo ""
}

# print_unlock_user_banner()
# Prints a banner for the user unlock operation
# Args:
#   $1 - Target (file or username)
#   $2 - Format of the file
print_unlock_user_banner() {
    local target="$1"
    local format="$2"

    echo "============================================"
    if [ -f "$target" ]; then
        echo "Unlocking Users from: $target"
        echo "Format: $format"
    else
        echo "Unlocking User: $target"
    fi
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    echo "============================================"
    echo ""
}

# print_operation_summary()
# Prints a standardized summary for a script operation
# Args:
#   $1 - Total items processed
#   $2 - Label for success count (e.g., "Created", "Deleted")
#   $3 - Success count
#   $4 - Items skipped
#   $5 - Items failed
#   $6 - Duration in seconds (optional)
print_operation_summary() {
    local total="$1"
    local success_label="$2"
    local success_count="$3"
    local skipped="$4"
    local failed="$5"
    local duration="$6"

    echo "============================================"
    echo "Operation Summary:"
    printf "  %-15s %s\\n" "Total Processed:" "$total"
    printf "  %-15s %s\\n" "$success_label:" "$success_count"
    printf "  %-15s %s\\n" "Skipped:" "$skipped"
    printf "  %-15s %s\\n" "Failed:" "$failed"
    [ -n "$duration" ] && printf "  %-15s %s\\n" "Duration:" "${duration}s"
    echo "============================================"
}

