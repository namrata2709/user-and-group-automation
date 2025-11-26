#!/bin/bash

# ================================================
# Helper Functions
# File: lib/utils/helpers.sh
# ================================================

# ================================================
# Generate random password
# ================================================
# Arguments:
#   $1 - Length (optional, defaults to PASSWORD_LENGTH from config)
# Returns:
#   Random password string
# ================================================
generate_random_password() {
    local length="${1:-$PASSWORD_LENGTH}"
    
    # Generate random password with uppercase, lowercase, digits, and special chars
    # Using /dev/urandom for cryptographically secure randomness
    tr -dc 'A-Za-z0-9!@#$%^&*()_+=' < /dev/urandom | head -c "$length"
}

# ================================================
# Store encrypted password
# ================================================
# Arguments:
#   $1 - Username
#   $2 - Password (plain text)
# Saves encrypted password to backup folder
# ================================================
store_encrypted_password() {
    local username="$1"
    local password="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/passwords/${username}_${timestamp}.enc"
    
    # Create passwords directory if doesn't exist
    mkdir -p "$BACKUP_DIR/passwords"
    
    # Encrypt password using openssl
    # Using AES-256-CBC encryption
    echo "$username:$password" | openssl enc -aes-256-cbc -salt -pbkdf2 -out "$backup_file" -pass pass:"$ENCRYPTION_KEY"
    
    if [ $? -eq 0 ]; then
        # Set restrictive permissions (only root can read)
        chmod 600 "$backup_file"
        echo "INFO: Encrypted password stored at: $backup_file"
        return 0
    else
        echo "WARNING: Failed to store encrypted password"
        return 1
    fi
}

# ================================================
# Decrypt and view stored password
# ================================================
# Arguments:
#   $1 - Encrypted file path
# Outputs decrypted username:password
# ================================================
decrypt_password_file() {
    local enc_file="$1"
    
    if [ ! -f "$enc_file" ]; then
        echo "ERROR: Encrypted file not found: $enc_file"
        return 1
    fi
    
    # Decrypt using openssl
    openssl enc -aes-256-cbc -d -pbkdf2 -in "$enc_file" -pass pass:"$ENCRYPTION_KEY"
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to decrypt password file"
        return 1
    fi
    
    return 0
}