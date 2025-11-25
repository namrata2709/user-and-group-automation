#!/usr/bin/env bash
# =============================================================================
#          FILE: password.sh
#   DESCRIPTION: Password generation utility.
# =============================================================================

# Generates a cryptographically secure random password.
generate_random_password() {
    local length="${1:-${PASSWORD_LENGTH:-16}}"
    tr -dc 'A-Za-z0-9!@#$%^&*()' < /dev/urandom | head -c "$length"
}