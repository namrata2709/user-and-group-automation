#!/bin/bash

# ================================================
# Sudo Access Manager
# File: lib/utils/sudo_manager.sh
# ================================================

# ================================================
# Grant sudo access to user
# ================================================
# Arguments:
#   $1 - Username
# Returns:
#   0 on success, 1 on failure
# ================================================
grant_sudo_access() {
    local username="$1"
    
    # Check if sudo group exists
    if ! getent group "$SUDO_GROUP" >/dev/null 2>&1; then
        echo "ERROR: Sudo group '$SUDO_GROUP' does not exist on this system"
        return 1
    fi
    
    # Add user to sudo group
    if usermod -aG "$SUDO_GROUP" "$username" >/dev/null 2>&1; then
        echo "INFO: Granted sudo access to user '$username'"
        return 0
    else
        echo "ERROR: Failed to grant sudo access to user '$username'"
        return 1
    fi
}

# ================================================
# Revoke sudo access from user
# ================================================
# Arguments:
#   $1 - Username
# Returns:
#   0 on success, 1 on failure
# ================================================
revoke_sudo_access() {
    local username="$1"
    
    # Check if user is in sudo group
    if ! groups "$username" 2>/dev/null | grep -q "\b$SUDO_GROUP\b"; then
        echo "INFO: User '$username' does not have sudo access"
        return 0
    fi
    
    # Remove user from sudo group
    if gpasswd -d "$username" "$SUDO_GROUP" >/dev/null 2>&1; then
        echo "INFO: Revoked sudo access from user '$username'"
        return 0
    else
        echo "ERROR: Failed to revoke sudo access from user '$username'"
        return 1
    fi
}

# ================================================
# Check if user has sudo access
# ================================================
# Arguments:
#   $1 - Username
# Returns:
#   0 if has sudo, 1 if not
# ================================================
has_sudo_access() {
    local username="$1"
    
    if groups "$username" 2>/dev/null | grep -q "\b$SUDO_GROUP\b"; then
        return 0
    else
        return 1
    fi
}